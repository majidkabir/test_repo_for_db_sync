SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_Ecom_GetPackTaskOrders_M                                */
/* Creation Date: 19-APR-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#361901 - New ECOM Packing                               */
/*        :                                                             */
/* Called By: d_ds_ecom_packtaskorders_m (Multi Order Mode)             */
/*          : nep_n_cst_packheader_ecom ue_packconfirm                  */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 18-08-2016  Wan01    1.1   SOS#375635 - CR for ECOM Packing          */
/* 21-SEP-2016 Wan02    1.2   Performance Tune                          */
/* 20-OCT-2016 Wan03    1.3   Fixed                                     */
/* 09-OCT-2017 Wan04    1.4   Performance Tune                          */
/* 25-OCT-2017 Wan05    1.5   Orderkey Seq in Device Position fixed     */
/* 03-NOV-2017 Wan06    1.6   Fixed.Auto Pack Confirm Full Match Orderkeys*/
/* 13-NOV-2017 Wan07    1.7   Fixed. User '_' instead of 'X' for devicechar*/
/* 04-Apr-2019 NJOW01   1.8   WMS-8741 Add DropId parameter             */
/* 24-JUN-2019 Wan08    1.9   Performance Tune                          */ 
/************************************************************************/
CREATE PROC [dbo].[isp_Ecom_GetPackTaskOrders_M]
            @c_TaskBatchNo    NVARCHAR(10)
         ,  @c_PickSlipNo     NVARCHAR(10)
         ,  @c_Orderkey       NVARCHAR(10)   OUTPUT
         ,  @b_packcomfirm    INT            = 0
         ,  @c_DropID         NVARCHAR(20)   = '' --NJOW01
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_InProgOrderkey  NVARCHAR(10)  

   DECLARE @n_Index        INT
         , @n_Row          INT

         , @n_ColPerRow    INT
         , @n_RowPerPage   INT

         , @n_NoOfPage     INT
         , @n_NoOfRec      INT
         , @n_PendingRow   INT

         , @n_RecPerPage   FLOAT

         , @c_DeviceChar   NVARCHAR(2)          --(Wan01)           
         , @c_DevPos       NVARCHAR(10)        

         , @n_StatusMatch     INT               --(Wan02)
         , @b_NewPackByOrder  INT               --(Wan02)
         , @n_RowRef          BIGINT            --(Wan02)

         , @c_PTD_Orderkey    NVARCHAR(10)      --(Wan02)
         , @c_PTD_PickSlipNo  NVARCHAR(10)      --(Wan02)
         , @c_PTD_Status      NVARCHAR(10)      --(Wan02)
         , @c_PH_Orderkey     NVARCHAR(10)      --(Wan02)

         , @c_PTD_LogicalName NVARCHAR(10)      --(Wan04)
         , @c_PTD_OrigStatus  NVARCHAR(10)      --(Wan04)


         , @b_Build_DvcPos    BIT               --(Wan04)
         , @n_DvcRefKey       INT               --(Wan04)
         , @n_PTD_FetchNext   INT               --(Wan04)
         , @n_NoOfStatus1     INT               --(Wan04)
         , @n_NoOfStatus2     INT               --(Wan04)
         , @n_DvcCol          INT               --(Wan04)
         , @n_MaxCol          INT               --(Wan04)
         , @cur_FINDORD       CURSOR            --(Wan04)
         , @cur_PTD           CURSOR            --(Wan04)

         , @b_Debug           INT               --(Wan04)

         , @c_Orderkey_FullMatch          NVARCHAR(10)         --(Wan06) 
         , @c_Storerkey                   NVARCHAR(15) = ''    --(Wan08)
         , @c_Facility                    NVARCHAR(5) = ''     --(Wan08)
         , @c_EpackForceMultiPackByOrd    NVARCHAR(30) = ''    --(Wan08) 

   SET @b_Debug = 0                              
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue  = 1
   SET @n_RecPerPage = 36.00
   SET @n_RowPerPage = 6
   SET @n_ColPerRow  = 6

   SET @c_Orderkey = ISNULL(RTRIM(@c_Orderkey),'')
     
   -- (Wan02) - START
   DECLARE @TMP_DVCPOS TABLE
      (  IdxNo          INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
      ,  DVCPOS         NVARCHAR(10)   NOT NULL
      )

   DECLARE @TMP_PACKTASKDETAIL TABLE
      (  RowRef         INT            NOT NULL IDENTITY(1,1) PRIMARY KEY     --(Wan04)
      ,  TaskBatchNo    NVARCHAR(10)   NOT NULL 
      ,  LogicalName    NVARCHAR(10)   NOT NULL -- (Wan03)PRIMARY KEY Fixed issue if logicalname empty for multiple orderkey
      ,  Orderkey       NVARCHAR(10)   NOT NULL -- PRIMARY KEY -- (Wan04)Fixed issue if logicalname empty for multiple orderkey
      ,  PickSlipNo     NVARCHAR(10)   NOT NULL -- (Wan03)
      ,  Status         NVARCHAR(10)   NOT NULL
      ,  DvcRefKey      INT            NOT NULL
      )

   --(Wan04) - START
   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
   --(Wan04) - END

   IF RTRIM(@c_TaskBatchNo) = '' OR @c_TaskBatchNo IS NULL
   BEGIN
      GOTO DISPLAY_ORDERS 
   END

   --(Wan08) - START
   IF @c_Orderkey <> ''
   BEGIN
      SELECT @c_Storerkey = Storerkey 
            ,@c_Facility  = Facility
      FROM ORDERS WITH (NOLOCK)
      WHERE Orderkey = @c_Orderkey

      SET @c_EpackForceMultiPackByOrd = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'EpackForceMultiPackByOrd')
 
      IF @c_EpackForceMultiPackByOrd = '1' AND 
         --@c_Storerkey = 'DOTERRA' AND
         EXISTS ( SELECT 1 FROM PACKTASKDETAIL PTD (NOLOCK)
                  WHERE Orderkey = @c_Orderkey
                  AND Status >= '3' 
                  ) 
      BEGIN
         SELECT DISTINCT
               TaskBatchNo  = ISNULL(PTD.TaskBatchNo,'') 
            ,  Orderkey     = ISNULL(PTD.Orderkey,'')  
            ,  DeviceOrderkey = ISNULL(PTD.Orderkey,'')
            ,  Status         = ISNULL(PTD.Status,'') 
            ,  InProgOrderkey = @c_Orderkey 
            ,  Color = CASE  ISNULL(PTD.Status,'') 
                        WHEN ''  THEN 16777215     -- WHITE
                        WHEN 'X' THEN 8421504      -- GREY (CANC, HOLD)
                        WHEN '9' THEN 32768        -- GREEN(0,128,0)    (PACKCONFIRM)
                        WHEN '3' THEN 16711680     -- BLUE(0,0,255)     (Assigned Orderkey)
                        WHEN '2' THEN 16711680     -- BLUE(0,0,255)     (Full Match without orderkey)
                        WHEN '1' THEN 16711680     -- BLUE(0,0,255)     (Partial Match without orderkey)
                        WHEN '0' THEN 255          -- RED (255,0,0)     (Open)
                        END
         FROM PACKTASKDETAIL PTD  WITH (NOLOCK)
         WHERE TaskBatchNo = @c_TaskBatchNo

         GOTO QUIT_SP
      END
   END
   --(Wan08) - END
   
   EXECUTE isp_Ecom_GetPackTaskOrderStatus
      @c_TaskBatchNo = @c_TaskBatchNo 
   ,  @c_PickSlipNo  = @c_PickSlipNo 
   ,  @c_Orderkey    = @c_Orderkey           --(WAN08)   

   SET @b_NewPackByOrder = 0
   SET @c_PH_Orderkey = ''
   SET @c_Orderkey_FullMatch = ''      -- (Wan06)

   SET @n_Index = 0                    -- (Wan05)
   SET @n_Row   = 0                    -- (Wan05)
   SET @b_Build_DvcPos = 0
   SET @c_DeviceChar   = ''
   SET @n_NoOfStatus1  = 0 
   SET @n_NoOfStatus2  = 0
   SET @c_InProgOrderkey = ''
   SET @cur_FINDORD = CURSOR FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT
            PTD.LogicalName   
         ,  PTD.Orderkey 
         ,  PTD.PickSlipNo
         ,  PTD.[Status]                                 
   FROM PACKTASKDETAIL PTD WITH (NOLOCK)
   WHERE PTD.TaskBatchNo = @c_TaskBatchNo
   ORDER BY PTD.LogicalName

   OPEN @cur_FINDORD

   FETCH NEXT FROM @cur_FINDORD INTO   @c_PTD_LogicalName
                                    ,  @c_PTD_Orderkey
                                    ,  @c_PTD_PickSlipNo 
                                    ,  @c_PTD_OrigStatus

   SET @n_PTD_FetchNext = @@FETCH_STATUS
   WHILE @n_PTD_FetchNext = 0
   BEGIN
      SET @c_PTD_Status = @c_PTD_OrigStatus

      IF @c_Orderkey = @c_PTD_Orderkey 
      BEGIN
         SET @c_InProgOrderkey = @c_Orderkey

         IF @c_PTD_OrigStatus < '9' 
         BEGIN
            SET @c_PTD_Status = '3'
         END
      END

      IF @c_PTD_OrigStatus < '3' 
      BEGIN
         IF @c_PTD_Status < '3' 
         BEGIN 
            SET @c_PTD_Status = '0'

            SET @c_PTD_Status = dbo.fnc_ECOM_GetPackOrderStatus (@c_TaskBatchNo, @c_PickSlipNo, @c_PTD_Orderkey)

            IF @c_Orderkey = '' 
            BEGIN
               IF @c_PTD_Status = '1'
               BEGIN
                  SET @n_NoOfStatus1 = @n_NoOfStatus1 + 1
               END

               IF @c_PTD_Status = '2'
               BEGIN
                  SET @n_NoOfStatus2 = @n_NoOfStatus2 + 1
                  SET @c_InProgOrderkey = @c_PTD_Orderkey

                  --(Wan06) - START
                  IF @c_Orderkey_FullMatch = ''
                  BEGIN
                     SET @c_Orderkey_FullMatch = @c_InProgOrderkey
                  END
                  --(Wan06) - END

                  IF @b_packcomfirm = 1 
                  BEGIN
                     SET @c_Orderkey = @c_PTD_Orderkey  
                     SET @c_PTD_Status = '3'                                            
                  END
               END
            END
         END

         IF @c_PTD_Status = '3' 
         BEGIN 
            SET @c_PTD_PickSlipNo = @c_PickSlipNo
         END

         IF @c_PTD_Status IN ( '3', '9', 'X' ) AND @c_PickSlipNo <> ''
         BEGIN 
            UPDATE_PTD:
            SET @cur_PTD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PTD.RowRef
            FROM PACKTASKDETAIL PTD WITH (NOLOCK)
            WHERE PTD.TaskBatchNo = @c_TaskBatchNo
            AND   PTD.Orderkey = @c_PTD_Orderkey
                  
            OPEN @cur_PTD
   
            FETCH NEXT FROM @cur_PTD INTO @n_RowRef

            BEGIN TRAN                       --(Wan04)
            WHILE @@FETCH_STATUS <> -1  
            BEGIN
               UPDATE PACKTASKDETAIL WITH (ROWLOCK)
               SET [Status]   = @c_PTD_Status
                  ,PickSlipNo = @c_PTD_PickSlipNo
                  ,EditWho    = SUSER_NAME()
                  ,EditDate   = GETDATE()
                  ,TrafficCop = NULL
               WHERE RowRef = @n_RowRef 
               AND Status < '3'

               IF @@ERROR <> 0
               BEGIN
                  SET @c_InProgOrderkey = ''
                  --(Wan04) - START
                  IF @@TRANCOUNT > 0            
                  BEGIN 
                     ROLLBACK TRAN             
                  END
                  --(Wan04) - END
                  BREAK
               END
         
               FETCH NEXT FROM @cur_PTD INTO @n_RowRef
            END
            
            --(Wan04) - START
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END
            --(Wan04) - END

            IF @n_PTD_FetchNext = -1
            BEGIN 
               GOTO UPDATE_PTD_RETURN
            END
         END

         IF @c_InProgOrderkey <> '' AND @b_packcomfirm = 1 
         BEGIN
            GOTO QUIT_SP
         END
      END

      IF @c_InProgOrderkey <> @c_PTD_Orderkey AND @c_PTD_Status = '3'  -- show red if it is not pack orderkey for those orders status from function = '3' 
      BEGIN
         SET @c_PTD_Status = '0' 
      END

      SET @n_DvcCol = 0
      IF LEN(@c_PTD_LogicalName) = 3   
      BEGIN
         SET @c_DeviceChar = SUBSTRING(@c_PTD_LogicalName,1,2)
         SET @n_DvcCol     = SUBSTRING(@c_PTD_LogicalName,3,1)
  
         IF  @n_Index + 1 < @n_DvcCol AND @n_DvcCol <= @n_ColPerRow  -- (Wan05)
         BEGIN
            SET @n_MaxCol = @n_DvcCol - 1                            -- (Wan05)
            SET @b_Build_DvcPos = 1
            GOTO BUILD_DVCPOS
            BUILD_DVCPOS_RETURN:
            SET @b_Build_DvcPos = 0
         END
      END
   
      SET @n_DvcRefKey = 0
      IF @n_DvcCol BETWEEN 1 AND 6 
      BEGIN
         INSERT INTO @TMP_DVCPOS 
            (  DVCPOS )
         VALUES 
            (  @c_PTD_LogicalName )

         SET @n_DvcRefKey = SCOPE_IDENTITY()  
         
         IF @b_Debug = 1
         BEGIN      
            select @c_PTD_LogicalName '@c_PTD_LogicalName', @n_MaxCol '@n_MaxCol'
         END

         SET @n_Index = @n_Index + 1         -- (Wan05)
      END


      IF @b_Debug = 1
      BEGIN      
         select @n_Index, @n_MaxCol, @n_DvcRefKey
      END

      INSERT INTO @TMP_PACKTASKDETAIL
            (  TaskBatchNo
            ,  LogicalName
            ,  Orderkey
            ,  PickSlipNo              
            ,  [Status]
            ,  DvcRefKey
            )
      VALUES 
            (  @c_TaskBatchNo
            ,  @c_PTD_LogicalName
            ,  @c_PTD_Orderkey
            ,  @c_PTD_PickSlipNo
            ,  @c_PTD_Status
            ,  @n_DvcRefKey
            )

      -- (Wan05) - START
      --SET @n_Index = @n_Index + 1

      --IF @n_Index > @n_ColPerRow 
      --BEGIN
      --   SET @n_Index = 1
      --END
      -- (Wan05) - END

      NEXT_RECORD:

      FETCH NEXT FROM @cur_FINDORD INTO   @c_PTD_LogicalName
                                       ,  @c_PTD_Orderkey
                                       ,  @c_PTD_PickSlipNo
                                       ,  @c_PTD_OrigStatus 
      SET @n_PTD_FetchNext = @@FETCH_STATUS

      SET @n_DvcCol = SUBSTRING(@c_PTD_LogicalName,3,1)

      IF @b_Debug = 1
      BEGIN      
         select @n_DvcCol '@n_MaxCol'
      END

      -- (Wan05) - START
      IF @n_Index > 0               
      BEGIN
         IF @n_PTD_FetchNext = -1 AND @n_Index <= @n_ColPerRow  
         BEGIN
            SET @b_Build_DvcPos = 1
         END

         IF @b_Build_DvcPos = 0 AND @n_DvcCol BETWEEN 1 AND 6
         BEGIN
            IF LEN(@c_PTD_LogicalName) = 3 AND @n_Index < @n_ColPerRow AND SUBSTRING(@c_PTD_LogicalName,1,2) <> @c_DeviceChar
            BEGIN
               SET @b_Build_DvcPos = 1
            END
         END

         IF @b_Debug = 1
         BEGIN      
            select @b_Build_DvcPos '@b_Build_DvcPos'
         END

         IF @b_Build_DvcPos = 1
         BEGIN
            SET @n_MaxCol = @n_ColPerRow --+ 1

            SET @b_Build_DvcPos = 1
            GOTO BUILD_DVCPOS
            BUILD_DVCPOS_RETURN_ENDCOL:
            SET @b_Build_DvcPos = 0
         END

         --IF @b_Build_DvcPos = 0
         --BEGIN
         --   IF @n_DvcCol = 1 AND @n_Index > 1
         --   BEGIN
         --      SET @n_Index = 1
         --   END
         --END

         IF @b_Debug = 1
         BEGIN      
            select @n_Index,@n_MaxCol '@n_MaxCol', @n_PTD_FetchNext
         END

         IF @n_Index = 0 --AND @n_PTD_FetchNext = 0 --AND @n_DvcCol BETWEEN 1 AND 6
         BEGIN
            SET @n_Row = @n_Row + 1

            IF @n_Row >= @n_RowPerPage
            BEGIN
               SET @n_Row = 0
            END
         END
      END

      IF @n_Index >= @n_ColPerRow 
      BEGIN
         SET @n_Index = 0

         SET @n_Row = @n_Row + 1

         IF @n_Row >= @n_RowPerPage
         BEGIN
            SET @n_Row = 0
         END
      END
      -- (Wan05) - END
   END

   WHILE @n_Row < @n_RowPerPage
   BEGIN 
      SET @n_Index = 0                                               -- (Wan05)      
      SET @n_MaxCol= @n_ColPerRow --+  1                             -- (Wan05)  

      SET @c_DeviceChar = '_' + RTRIM(CONVERT(CHAR(1), @n_Row + 1))  -- (Wan05) -- (Wan07)
      SET @b_Build_DvcPos = 1

      GOTO BUILD_DVCPOS
      BUILD_DVCPOS_RETURN_ENDROW:
      SET @b_Build_DvcPos = 0 

      IF @n_Index = 0                                                -- (Wan05)
      BEGIN
         SET @n_Row = @n_Row + 1
      END
   END

   IF @c_Orderkey = '' 
   BEGIN
      IF @n_NoOfStatus1 = 0 AND @n_NoOfStatus2 >= 1               --(Wan06)
      BEGIN
         SET @c_InProgOrderkey = @c_Orderkey_FullMatch            --(Wan06)
         SET @c_PTD_Status     = '3' 
         SET @c_PTD_PickSlipNo = @c_PickSlipNo
         SET @c_PTD_Orderkey   = @c_InProgOrderkey 
         GOTO UPDATE_PTD 
         UPDATE_PTD_RETURN:
      END

      --(Wan06) - START      
      IF @n_NoOfStatus1 > 0  
      BEGIN
         IF @n_NoOfStatus1 + @n_NoOfStatus2 > 1 
         BEGIN
            SET @c_InProgOrderkey = ''
         END
      END
      --(Wan06) - END
   END

   /*-------------------------------*/
   /*  BUILD Dummy Device Position  */
   /*-------------------------------*/
   BUILD_DVCPOS:
   IF @b_Build_DvcPos = 1
   BEGIN
      WHILE @n_Index < @n_MaxCol
      BEGIN

         INSERT INTO @TMP_DVCPOS 
            (  DVCPOS )
         VALUES 
            (  RTRIM(@c_DeviceChar) + RTRIM(CONVERT(NCHAR(1), @n_Index + 1)) )      -- (Wan05)

         SET @n_DvcRefKey = SCOPE_IDENTITY()  

         INSERT INTO @TMP_PACKTASKDETAIL
               (  TaskBatchNo
               ,  LogicalName
               ,  Orderkey
               ,  PickSlipNo              
               ,  [Status]
               ,  DvcRefKey
   
               )
         VALUES 
               (  @c_TaskBatchNo
        ,  RTRIM(@c_DeviceChar) + RTRIM(CONVERT(NCHAR(1), @n_Index + 1))     -- (Wan05)
               ,  ''
               ,  ''
               ,  ''
               ,  @n_DvcRefKey 
               )

         SET @n_Index = @n_Index + 1
      END

      IF @n_Index >= @n_ColPerRow                                                   -- (Wan05)
      BEGIN
         SET @n_Index = 0                                                           -- (Wan05)
      END

      IF LEFT(@c_DeviceChar,1) = '_'                                                -- (Wan07)
      BEGIN
         GOTO BUILD_DVCPOS_RETURN_ENDROW
      END
      ELSE IF SUBSTRING(@c_PTD_LogicalName,1,2) = @c_DeviceChar AND @@FETCH_STATUS = 0 
      BEGIN
         GOTO BUILD_DVCPOS_RETURN 
      END
      ELSE
      BEGIN
         GOTO BUILD_DVCPOS_RETURN_ENDCOL
      END
   END

   IF @b_Debug = 1
   BEGIN      
      select * from @TMP_DVCPOS
      select * from @TMP_PACKTASKDETAIL
   END

   DISPLAY_ORDERS:
   SELECT 
         TaskBatchNo  = ISNULL(PTD.TaskBatchNo,'') 
      ,  Orderkey     = ISNULL(PTD.Orderkey,'')  
      ,  DeviceOrderkey = CASE WHEN ISNULL(PTD.Orderkey,'') = '' THEN '' ELSE LEFT(ISNULL(RTRIM(PTD.LogicalName),''),3) + '-' END
                        + ISNULL(RTRIM(PTD.Orderkey),'') 
      ,  Status         = ISNULL(PTD.Status,'') 
      ,  InProgOrderkey = @c_InProgOrderkey 
      ,  Color = CASE  ISNULL(PTD.Status,'') 
                  WHEN ''  THEN 16777215     -- WHITE
                  WHEN 'X' THEN 8421504      -- GREY (CANC, HOLD)
                  WHEN '9' THEN 32768        -- GREEN(0,128,0)    (PACKCONFIRM)
                  WHEN '3' THEN 16711680     -- BLUE(0,0,255)     (Assigned Orderkey)
                  WHEN '2' THEN 16711680     -- BLUE(0,0,255)     (Full Match without orderkey)
                  WHEN '1' THEN 16711680     -- BLUE(0,0,255)     (Partial Match without orderkey)
                  WHEN '0' THEN 255          -- RED (255,0,0)     (Open)
                  END
   FROM @TMP_DVCPOS DVC
   JOIN @TMP_PACKTASKDETAIL PTD ON (DVC.IdxNo = PTD.DvcRefKey)
   ORDER BY DVC.IDXNO

QUIT_SP:
  
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   --(Wan04) - END
END -- procedure

GO