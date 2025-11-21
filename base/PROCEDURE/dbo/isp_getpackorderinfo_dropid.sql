SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_GetPackOrderInfo_DropID                                 */
/* Creation Date: 10-APR-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-1466 - CN & SG Logitech - Packing                       */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 04-JUL-2017 Wan01    1.1   WMS-2332 - Changes to Logitech Packing    */
/* 16-OCT-2019 CSCHONG  1.2   WMS-10859 - revised logic (CS01)          */
/* 28-Nov-2019 CSCHONG  1.3   WMS-10992 - revised logic (CS02)          */
/* 14-JUL-2020 Wan02    1.4   WMS-13830 - SG- Logitech - Packing [CR]   */
/************************************************************************/
CREATE PROC [dbo].[isp_GetPackOrderInfo_DropID] 
            @c_DropID      NVARCHAR(20)     
         ,  @c_Storerkey   NVARCHAR(15)      OUTPUT 
         ,  @c_PickSlipNo  NVARCHAR(10)      OUTPUT
         ,  @b_SampleOrder INT = 0           OUTPUT                                             
         ,  @b_Success     INT = 0           OUTPUT 
         ,  @n_err         INT = 0           OUTPUT 
         ,  @c_errmsg      NVARCHAR(4000) = ''OUTPUT
         ,  @c_Facility    NVARCHAR(5)    = ''OUTPUT     --(Wan02) 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT
         , @n_Exists          INT

         , @n_RecCnt          INT

         , @c_Orderkey        NVARCHAR(10) 
         , @c_OrderGroup      NVARCHAR(10) 

         --, @c_Facility        NVARCHAR(10)                   --(Wan01)--(Wan02)
         , @c_Wavekey         NVARCHAR(10)                     --(Wan01)
         , @c_LogitechRules   NVARCHAR(30)                     --(Wan01)
         , @c_Option1         NVARCHAR(50)                     --(Wan01)
         , @c_Option2         NVARCHAR(50)                     --(Wan01)
         , @c_Option3         NVARCHAR(50)                     --(Wan01)
         , @c_Option4         NVARCHAR(50)                     --(Wan01)    
         , @c_Option5         NVARCHAR(4000)                   --(Wan01)
         , @c_OrderMsg        NVARCHAR(255)                    --(Wan01)
         , @c_DisplayMsg      NVARCHAR(4000)                   --(Wan01)
         

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @b_SampleOrder  = 0

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN;  
   END 

   --(Wan01) - START
   IF CURSOR_STATUS( 'LOCAL', 'CUR_ORD') in (0 , 1)  
   BEGIN
      CLOSE CUR_ORD           
      DEALLOCATE CUR_ORD      
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_INVLDORD') in (0 , 1)  
   BEGIN
      CLOSE CUR_INVLDORD           
      DEALLOCATE CUR_INVLDORD      
   END


   CREATE TABLE #TMP_INVLDORD
      ( RowRef    INT      IDENTITY(1,1) PRIMARY KEY
      , Orderkey  NVARCHAR(10)   NOT NULL 
      , OrderMsg  NVARCHAR(255)  NULL
      )  ;

   CREATE INDEX IDX_Orderkey ON #TMP_INVLDORD (Orderkey)
 
   SELECT TOP 1 @c_Wavekey  = Wavekey
               ,@c_Storerkey= Storerkey 
               ,@c_Orderkey = Orderkey
   FROM dbo.fnc_GetWaveOrder_DropID(@c_DropID)

   SELECT @c_Facility = ORDERS.Facility
   FROM ORDERS WITH (NOLOCK) 
   WHERE Orderkey = @c_Orderkey

   SET @c_DisplayMsg = ''
   SET @c_LogitechRules = ''
   SET @c_Option1       = ''

   EXEC nspGetRight      
         @c_Facility  = @c_Facility      
      ,  @c_StorerKey = @c_StorerKey      
      ,  @c_sku       = NULL      
      ,  @c_ConfigKey = 'LogitechRules'      
      ,  @b_Success   = @b_Success           OUTPUT      
      ,  @c_authority = @c_LogitechRules     OUTPUT      
      ,  @n_err       = @n_err               OUTPUT      
      ,  @c_errmsg    = @c_errmsg            OUTPUT 
      ,  @c_Option1   = @c_Option1           OUTPUT
      ,  @c_Option2   = @c_Option2           OUTPUT
      ,  @c_Option3   = @c_Option3           OUTPUT
      ,  @c_Option4   = @c_Option4           OUTPUT
      ,  @c_Option5   = @c_Option5           OUTPUT

   IF @c_LogitechRules = '1'  
   BEGIN
      INSERT INTO #TMP_INVLDORD (Orderkey, OrderMsg)
      SELECT DISTINCT OH.Orderkey 
            ,CASE WHEN (ISNULL(ST.notes2,'') = 'MRP' AND OH.UserDefine06 IS NULL) THEN 'Empty Orders UserDefine06' 
             --  WHEN ISNULL(ST.notes2,'') <> 'MRP' THEN  'Not MRP Orders ' 
              WHEN (ISNULL(ST.notes2,'') = 'MRP' AND OH.UserDefine06 IS NOT NULL 
                   AND (OH.UserDefine06 >= DATEADD(day,60,getdate()) OR OH.UserDefine06 <= DATEADD(day,-60,getdate()))) 
                  THEN 'Wrong shipment ETA date ' ELSE '' END
      FROM PICKDETAIL PD WITH (NOLOCK)
      JOIN ORDERS OH WITH (NOLOCK) ON (PD.Orderkey = OH.Orderkey)
      LEFT JOIN STORER ST (NOLOCK) ON ST.Storerkey = OH.Consigneekey   --CS01
      WHERE PD.DropID    = @c_DropID
      AND   OH.UserDefine09 = @c_Wavekey
      --AND   OH.C_Country = 'IN'       --CS02
      --AND   OH.UserDefine06 IS NULL   --CS01 

      IF @c_Option1 = '1'
      BEGIN
         INSERT INTO #TMP_INVLDORD (Orderkey, OrderMsg)
         SELECT DISTINCT OH.Orderkey 
               ,'Empty SkuInfo '
         FROM PICKDETAIL PD WITH (NOLOCK)
         JOIN ORDERS OH WITH (NOLOCK) ON (PD.Orderkey = OH.Orderkey)
		 LEFT JOIN STORER ST (NOLOCK) ON ST.Storerkey = OH.Consigneekey   --CS02
         WHERE PD.DropID    = @c_DropID
         AND   OH.UserDefine09 = @c_Wavekey
         --AND   OH.C_Country = 'IN'                              --CS02
		 AND ISNULL(ST.notes2,'') = 'MRP'                         --CS02
         --AND   OH.UserDefine10 <> 'N'                           --CS02
         AND   0 = (SELECT EmptySkuInfo = ISNULL(SUM(CASE WHEN ISNULL(extendedfield03,'') = '' THEN 0  
                                                          WHEN ISNULL(extendedfield21,'') = '' THEN 0 
                                                          WHEN ISNULL(extendedfield22,'') = '' THEN 0
                                                          ELSE 1
                                                          END)
                                                ,0)
                    FROM SKUINFO WITH (NOLOCK)
                    WHERE Storerkey = PD.Storerkey   
                    AND   Sku = PD.Sku
                   ) 
      END
   END
   --(Wan01) - END

   SET @n_RecCnt = 0

   DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Storerkey
         ,Orderkey
         ,OrderGroup   
   FROM   dbo.Fnc_GetWaveOrder_DropID( @c_DropID )
   ORDER BY Orderkey
   
   OPEN CUR_ORD
   
   FETCH NEXT FROM CUR_ORD INTO @c_Storerkey
                              , @c_Orderkey
                              , @c_OrderGroup
   WHILE @@FETCH_STATUS <> -1  AND @n_RecCnt <= 1
   BEGIN
      SET @n_RecCnt = @n_RecCnt + 1

      IF @n_RecCnt <= 1 AND @c_OrderGroup = 'S01' 
      BEGIN
         SET @b_SampleOrder = 1

         SELECT @c_PickSlipNo = PickSlipNo 
         FROM PACKHEADER WITH (NOLOCK)
         WHERE Orderkey = @c_Orderkey
      END

      --(Wan01) - START
      DECLARE CUR_INVLDORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderMsg = ISNULL(OrderMsg,'')
      FROM #TMP_INVLDORD
      WHERE Orderkey = @c_Orderkey
      AND OrderMsg <> ''
      ORDER BY RowRef

      OPEN CUR_INVLDORD

      FETCH NEXT FROM CUR_INVLDORD INTO @c_OrderMsg
      WHILE @@FETCH_STATUS <> -1  
      BEGIN
         SET @c_DisplayMsg = @c_DisplayMsg + CHAR(13) + Char (10) + @c_Orderkey + '-' + @c_OrderMsg

         FETCH NEXT FROM CUR_INVLDORD INTO @c_OrderMsg
      END
      CLOSE CUR_INVLDORD
      DEALLOCATE CUR_INVLDORD 
      --(Wan01) - END

      FETCH NEXT FROM CUR_ORD INTO @c_Storerkey
                                 , @c_Orderkey
                                 , @c_OrderGroup
   END
   CLOSE CUR_ORD
   DEALLOCATE CUR_ORD 

   IF @n_RecCnt = 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 50010
      SET @c_ErrMsg = 'NSQL' +  CONVERT(CHAR(5),@n_Err)  + ':'  
                    + 'DropID Not Found.(isp_GetPackOrderInfo_DropID)'
      GOTO QUIT_SP
   END  

   --(Wan01) - START
   IF @c_DisplayMsg <> ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 50020
      SET @c_ErrMsg = 'NSQL' +  CONVERT(CHAR(5),@n_Err)  + ': Dropid''s Orders with issue as below: '   
                    + ' (isp_GetPackOrderInfo_DropID)'  
                    + @c_DisplayMsg
      GOTO QUIT_SP
   END
   --(Wan01) - END

   IF @n_RecCnt > 1 -- IF Multi Orderkey per dropid
   BEGIN
      SET @b_SampleOrder = 0
      SET @c_PickSlipNo  = ''
   END

QUIT_SP:
   --(Wan01) - START
   IF OBJECT_ID('tempdb..#TMP_INVLDORD','u') IS NOT NULL
   BEGIN
      DROP TABLE #TMP_INVLDORD;
   END
   --(Wan01) - END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      --EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetPackOrderInfo_DropID'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   WHILE @@TRANCOUNT < @n_StartTCnt 
   BEGIN
      BEGIN TRAN; 
   END  
END -- procedure

GO