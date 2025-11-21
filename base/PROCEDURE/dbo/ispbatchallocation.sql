SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Procedure: ispBatchAllocation                                    */
/* Creation Date: 2002-05-08                                               */
/* Copyright: IDS                                                          */
/* Written by: IDS                                                         */
/*                                                                         */
/* Purpose: Batch Allocation                                               */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/* PVCS Version: 1.2                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author         Purposes                                     */
/* 2007-07-30  ONG01          Allow Loadkey, Orderkey, Wavekey             */
/* 2009-07-09  SHONG          Add Email Alert                              */
/* 2013-02-25  Leong          Revise Email Alert.                          */
/* 2014-01-28  Leong          Remove Default Email Address (Leong01).      */
/*                            (standardize with isp_SOADDLOG_BackEndAlloc) */
/* 2014-11-11  Shong          Added Extern Parameter for SP                */
/* 2019-10-04  Shong          Filter RecipientList By BckEndAloc           */  
/* 2020-01-21  Wan01          Added Wavekey, AllocateCmd For WM/SCE        */
/* 2021-04-19  Wan02          Fixed not to check pickheader                */
/***************************************************************************/

CREATE PROCEDURE [dbo].[ispBatchAllocation]
   @b_debug INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_SourceKey       NVARCHAR(10)
         , @c_SourceType      NVARCHAR(1)
         , @c_ComputerName    NVARCHAR(18)
         , @c_UserName        NVARCHAR(18)
         , @n_Continue        INT
         , @n_cnt             INT
         , @n_err             INT
         , @c_ErrMsg          CHAR (255)
         , @b_success         INT
         , @c_trmlogkey       NVARCHAR(10)
         , @c_OrderStatus     NVARCHAR(1)
         , @c_LoadPlanStatus  NVARCHAR(1)
         , @c_Command         sysname
         , @c_StorerKey       NVARCHAR(15)
         , @n_StartCnt        INT
         , @c_UniqueKey       UNIQUEIDENTIFIER
         , @cExecStatements   NVARCHAR(4000)
         , @c_UpStatus        NVARCHAR(1)
         , @c_EmailMsg        NVARCHAR(max)
         , @c_SuperOrderFlag  NVARCHAR(10)
         , @c_OrderKey        NVARCHAR(10)
         , @cRecipientList    NVARCHAR(215)
         , @cEmailSubject     NVARCHAR(80)
         , @cSQLSelect        NVARCHAR(max)
         , @n_RecCount        INT
         , @c_ExtendParms     NVARCHAR(250) 
         
         , @c_Wavekey         NVARCHAR(10) = ''    --Wan01
         , @c_AllocateCmd     NVARCHAR(1024) = ''  --Wan01
         , @c_WaveStatus      NVARCHAR(10) = ''    --Wan01    

   IF ISNULL(OBJECT_ID('tempdb..#B'),'') <> ''
   BEGIN
      DROP TABLE #B
   END

   CREATE TABLE #B ( SeqNo  INT IDENTITY(1,1) NOT NULL
                   , ErrMsg NVARCHAR(1000) NULL )

   -- Set parameter values
   SELECT @n_StartCnt = @@TRANCOUNT

   CREATE TABLE #ALLOC ( UniqueKey UNIQUEIDENTIFIER )

   BEGIN TRAN

   INSERT INTO #ALLOC
   SELECT ip.AllocPoolId 
   FROM IDSAllocationPool AS ip WITH (NOLOCK)
   WHERE STATUS = '0' 
     AND DATEDIFF(MI, AddDate, GETDATE()) >= 1  


   UPDATE IDSAllocationPool WITH (ROWLOCK)  
      SET STATUS = '1'
   FROM IDSAllocationPool
   JOIN #ALLOC AL ON IDSAllocationPool.AllocPoolId = Al.UniqueKey  
    WHERE IDSAllocationPool.STATUS = '0'  
      AND DATEDIFF(MI, AddDate, GETDATE()) >= 1  
  
   SELECT @n_cnt = @@ROWCOUNT
   COMMIT TRAN

   IF @b_debug = 1
   BEGIN
      SELECT CAST(@n_cnt AS CHAR) 'Processing IDSAllocationPool'
   END

   SELECT @n_Continue = 1

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      SELECT @c_SourceKey = SPACE(10)

      DECLARE C_Current_Sourcekey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT AllocPoolId, Sourcekey
            , SourceType = CASE WHEN SourceType IN ('W', 'WP') THEN 'W'                                        --Wan01
                                WHEN SourceType IN ('L', 'LP') THEN 'L'                                        --Wan01
                                WHEN SourceType IN ('O', 'DC') THEN 'O'                                        --Wan01
                                END                                                                            --Wan01
            , WinComputerName, AddWho
            , '' AS ExtendParms 
            , Wavekey, AllocateCmd                                                                             --Wan01
          FROM IDSAllocationPool WITH (NOLOCK)
         JOIN #ALLOC AL ON IDSAllocationPool.AllocPoolId = Al.UniqueKey          
         WHERE IDSAllocationPool.Status = '1'
      ORDER BY Priority, AddDate

      OPEN C_Current_Sourcekey
      FETCH NEXT FROM C_Current_Sourcekey INTO @c_UniqueKey, @c_SourceKey, @c_SourceType, @c_ComputerName, @c_UserName, @c_ExtendParms 
                  ,  @c_Wavekey, @c_AllocateCmd                                                                --Wan01

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @b_Success  = 1     --(Wan01)
         SET @c_EmailMsg = ''
         SET @cSQLSelect = ''
         SET @cEmailSubject = ''

         SELECT @c_UpStatus = '9' , @c_ErrMsg = ''

         IF @b_debug = 1
         BEGIN
            SELECT @c_SourceType '@c_SourceType', @c_SourceKey '@c_SourceKey'
         END

         -- Checking Order Existence and its Status
         IF @c_SourceType = 'L' 
         BEGIN
            SET @c_OrderStatus = ''
            SET @n_RecCount = 0
            SET @cExecStatements = N'SELECT @c_OrderStatus = LOADPLAN.Status '
                                   +'FROM LOADPLAN WITH (NOLOCK) ' + CHAR(13)
                                   +'WHERE LOADPLAN.Loadkey = @c_SourceKey ' + CHAR(13)

            SET @cEmailSubject = 'Batch Allocation Alert For LoadKey: ' + @c_SourceKey
                               + CASE WHEN @c_Wavekey = '' THEN '' ELSE ', Wavekey: ' + @c_Wavekey END      --(Wan01)

            SET @cSQLSelect = N'SELECT @n_RecCount = COUNT(1) FROM PICKHEADER WITH (NOLOCK) ' +
                               'WHERE ExternOrderKey = @c_SourceKey '
         END
         Else IF @c_SourceType = 'W'
         BEGIN
            SET @c_OrderStatus = ''
            SET @n_RecCount = 0
            --(Wan01) - START
            SET @cExecStatements =''
            --SET @c_OrderStatus = dbo.fnc_GetWaveStatus(@c_SourceKey)
            BEGIN TRY
               SET @b_Success = 1
               EXEC [isp_GetWaveStatus]
                     @c_WaveKey     = @c_WaveKey 
                  ,  @b_UpdateWave  = 0   --1 => yes, 0 => No
                  ,  @c_Status      = @c_OrderStatus  OUTPUT
                  ,  @b_Success     = @b_Success      OUTPUT
                  ,  @n_Err         = @n_Err          OUTPUT
                  ,  @c_ErrMsg      = @c_ErrMsg       OUTPUT
            END TRY
            BEGIN CATCH
               SET @c_OrderStatus = '0' -- Proceed to allocation if GetWaveStatus fail.
            END CATCH
            --(Wan01) - END

            SET @cEmailSubject = 'Batch Allocation Alert For WaveKey: ' + @c_SourceKey

            SET @cSQLSelect = N'SELECT @n_RecCount = COUNT(1) FROM PICKHEADER WITH (NOLOCK) ' +
                               'JOIN WAVEDETAIL WITH (NOLOCK) ON WAVEDETAIL.OrderKey = PICKHEADER.OrderKey ' +
                               'WHERE WAVEDETAIL.WaveKey = @c_SourceKey '
         END
         Else IF @c_SourceType = 'O'
         BEGIN
            SET @c_OrderStatus = ''
            SET @n_RecCount = 0
            SET @cExecStatements = N'SELECT @c_OrderStatus = ORDERS.Status '
                                   +'FROM ORDERS WITH (NOLOCK) ' + CHAR(13)
                                   +'WHERE Orderkey = @c_SourceKey '

            SET @cEmailSubject = 'Batch Allocation Alert For OrderKey: ' + @c_SourceKey
                               + CASE WHEN @c_Wavekey = '' THEN '' ELSE ', Wavekey: ' + @c_Wavekey END      --(Wan01)

            SET @cSQLSelect = N'SELECT @n_RecCount = COUNT(1) FROM PICKHEADER WITH (NOLOCK) ' +
                               'WHERE Orderkey = @c_SourceKey '
         END

         IF @b_debug = 1
         BEGIN
            SELECT @cExecStatements
         END

         --(Wan02) - START
         --EXEC sp_executesql @cSQLSelect, N'@n_RecCount INT OUTPUT, @c_SourceKey NVARCHAR(10) ',
         --                   @n_RecCount OUTPUT, @c_SourceKey
         --(Wan02) - END
    
         IF @cExecStatements <> ''              --(Wan01)   
         BEGIN                                  --(Wan01)  
            EXEC sp_executesql @cExecStatements, N'@c_OrderStatus NVARCHAR(1) OUTPUT, @c_SourceKey NVARCHAR(10) ',
                               @c_OrderStatus OUTPUT, @c_SourceKey
         END                                    --(Wan01)  

         IF ISNULL(RTRIM(@c_OrderStatus),'') = ''
         BEGIN
            SELECT @c_UpStatus = '5' ,
                   @c_ErrMsg = CASE @c_SourceType WHEN 'W' THEN 'Wave: '
                                                  WHEN 'O' THEN 'Shipment Order: '
                                                  WHEN 'L' THEN 'Load Plan: '
                               END + RTRIM(@c_SourceKey) + '. The Order Lines not exist! '
            SELECT @c_EmailMsg = @c_ErrMsg
         END
         --ELSE               --(Wan02) -START
         --IF ISNULL(@n_RecCount, 0) > 0
         --BEGIN
         --   SELECT @c_UpStatus = '9' ,
         --          @c_ErrMsg = CASE @c_SourceType WHEN 'W' THEN 'Wave: '
         --                                         WHEN 'O' THEN 'Shipment Order: '
         --                                         WHEN 'L' THEN 'Load Plan: '
         --                      END + RTRIM(@c_SourceKey) + '. Pick Slip Printed, No Allocation Allow.'
         --   SELECT @c_EmailMsg = @c_ErrMsg
         --END                --(Wan02) -END
         ELSE  -- @c_OrderStatus >= 2 No Require Allocation
         IF ISNULL(RTRIM(@c_OrderStatus),'') = '2'
         BEGIN
            SELECT @c_UpStatus = '9' ,
                   @c_ErrMsg = CASE @c_SourceType WHEN 'W' THEN 'Wave: '
                                                  WHEN 'O' THEN 'Shipment Order: '
                                                  WHEN 'L' THEN 'Load Plan: '
                               END + RTRIM(@c_SourceKey) + ' is Fully Allocated!'
            SELECT @c_EmailMsg = @c_ErrMsg
         END
         ELSE  -- @c_OrderStatus >= 2 No Require Allocation
         IF ISNULL(RTRIM(@c_OrderStatus),'') IN ('3','4')
         BEGIN
            SELECT @c_UpStatus = '9',
                   @c_ErrMsg = CASE @c_SourceType WHEN 'W' THEN 'Wave: '
                                                  WHEN 'O' THEN 'Shipment Order: '
                                                  WHEN 'L' THEN 'Load Plan: '
                               END + RTRIM(@c_SourceKey) + ' is Pick In Progress!'
            SELECT @c_EmailMsg = @c_ErrMsg
         END
         ELSE  -- @c_OrderStatus >= 2 No Require Allocation
         IF ISNULL(RTRIM(@c_OrderStatus),'') IN ('5','6','7','8')
         BEGIN
            SELECT @c_UpStatus = '9',
                   @c_ErrMsg = CASE @c_SourceType WHEN 'W' THEN 'Wave: '
                                                  WHEN 'O' THEN 'Shipment Order: '
                                                  WHEN 'L' THEN 'Load Plan: '
                               END + RTRIM(@c_SourceKey) + ' already Pick Confirmed!'
            SELECT @c_EmailMsg = @c_ErrMsg
         END
         ELSE
         IF ISNULL(RTRIM(@c_OrderStatus),'') = '9'
         BEGIN
            SELECT @c_UpStatus = '9',
                   @c_ErrMsg = CASE @c_SourceType WHEN 'W' THEN 'Wave: '
                                                  WHEN 'O' THEN 'Shipment Order: '
                                                  WHEN 'L' THEN 'Load Plan: '
                               END + RTRIM(@c_SourceKey) + ' already Shipped!'
            SELECT @c_EmailMsg = @c_ErrMsg
         END
         ELSE  -- @c_OrderStatus <= 1 and Require Allocation
         BEGIN
            --(Wan01) - START
            IF @c_AllocateCmd <> ''
            BEGIN

               EXEC (@c_AllocateCmd)

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3

                  IF @b_debug = 1
                  BEGIN
                     SELECT @c_SourceKey 'Allocation Load Failed'
                  END
                  -- Update Status to Failed

                  SET @c_ErrMsg = 'Allocation Failed! '  

                  SET @c_UpStatus = '5'
               END
               ELSE
               BEGIN
                  IF @c_SourceType = 'L' 
                  BEGIN
                     SET @c_OrderStatus = ''

                     SET @cExecStatements = N'SELECT @c_OrderStatus = LOADPLAN.Status '
                                          +'FROM LOADPLAN WITH (NOLOCK) ' + CHAR(13)
                                          +'WHERE LOADPLAN.Loadkey = @c_SourceKey ' + CHAR(13)
                  END
                  ELSE IF @c_SourceType = 'W'
                  BEGIN
                     SET @cExecStatements = ''

                     BEGIN TRY
                     SET @b_Success = 1
                     EXEC [isp_GetWaveStatus]
                              @c_WaveKey     = @c_WaveKey 
                           ,  @b_UpdateWave  = 0   --1 => yes, 0 => No
                           ,  @c_Status      = @c_WaveStatus   OUTPUT
                           ,  @b_Success     = @b_Success      OUTPUT
                           ,  @n_Err         = @n_Err          OUTPUT
                           ,  @c_ErrMsg      = @c_ErrMsg       OUTPUT
                     END TRY
                     BEGIN CATCH
                        SET @c_OrderStatus = '' 
                     END CATCH

                     SET @c_OrderStatus = @c_WaveStatus

                     IF @c_OrderStatus >= '5'
                     BEGIN
                        SET @c_OrderStatus = ''
                     END
                  END
                  ELSE IF @c_SourceType = 'O'
                  BEGIN
                     SET @c_OrderStatus = ''
                     SET @cExecStatements = N'SELECT @c_OrderStatus = ORDERS.[Status] '
                                          +'FROM ORDERS WITH (NOLOCK) ' + CHAR(13)
                                          +'WHERE Orderkey = @c_SourceKey '
                  END

                  IF @b_debug = 1
                  BEGIN
                     SELECT @cExecStatements
                  END

                  IF @cExecStatements <> ''
                  BEGIN
                     EXEC sp_executesql @cExecStatements, N'@c_OrderStatus NVARCHAR(1) OUTPUT, @c_SourceKey NVARCHAR(10) ',
                                        @c_OrderStatus OUTPUT, @c_SourceKey
                  END

                  SET @c_UpStatus = '9' 
                  IF @c_OrderStatus = '1'
                  BEGIN
                     SET @c_ErrMsg = 'Partial Allocated!' 
                  END
                  ELSE IF @c_OrderStatus = '2'
                  BEGIN
                     SET @c_ErrMsg = 'Fully Allocated!' 
                  END
                  ELSE IF @c_OrderStatus = '0'
                  BEGIN
                     SET @c_ErrMsg = 'Not Allocated.'  
                  END 
                  ELSE
                  BEGIN
                     SET @c_UpStatus = 'E'  
                     SET @c_ErrMsg = 'Allocation Failed with un-known reason. Please check with Administrator'  
                  END

               END
               SET @c_EmailMsg = CASE WHEN ISNULL(@c_Wavekey,'') = '' THEN '' ELSE 'Wave No: ' + @c_Wavekey END

               SET @c_EmailMsg = @c_EmailMsg
                               + CASE WHEN @c_SourceType = 'W' AND ISNULL(@c_Wavekey,'') = '' THEN 'Wave No: ' 
                                      WHEN @c_SourceType = 'L' THEN 'Loadplan No: ' 
                                      WHEN @c_SourceType = 'O' THEN 'Order No: '
                                      END
                               + RTRIM(@c_SourceKey)
                               + '. ' + @c_ErrMsg + CHAR(13)

               GOTO FETCH_NEXT
            END --  @c_AllocateCmd <> ''
            --(Wan01) - END

            IF @c_SourceType = 'L'     -- Loadplan
            BEGIN
               SET @c_SuperOrderFlag = ''
               SELECT @c_SuperOrderFlag = SuperOrderFlag
               FROM   LOADPLAN WITH (NOLOCK)
               WHERE  LoadKey = @c_SourceKey

               IF ISNULL(RTRIM(@c_SuperOrderFlag),'') = 'Y'
               BEGIN
                  IF @b_debug = 1
                  BEGIN
                     SELECT @c_SourceKey 'Allocating Load'
                  END

                  SET @c_ExtendParms = ISNULL(RTRIM(@c_ExtendParms), '') 
                  IF @b_debug = 1
                  BEGIN
                     EXEC nsp_OrderProcessing_Wrapper '', @c_SourceKey, 'N', 'N', 'DS1', @c_ExtendParms   
                  END
                  ELSE
                     EXEC nsp_OrderProcessing_Wrapper '', @c_SourceKey, 'N', 'N', 'BEA', @c_ExtendParms
                   
                  IF @@ERROR <> 0
                  BEGIN
                     SELECT @n_Continue = 3

                     IF @b_debug = 1
                     BEGIN
                        SELECT @c_SourceKey 'Allocation Load Failed'
                     END
                     -- Update Status to Failed

                     SELECT @c_UpStatus = '5'

                     IF PATINDEX('%No Orders To Process%', @c_errmsg) > 0
                     BEGIN
                        SELECT @c_EmailMsg = 'Loadplan No: ' +  RTRIM(@c_SourceKey) + '. No Orders To Process! ' + RTRIM(@c_errmsg)
                     END
                     ELSE
                        SELECT @c_EmailMsg = 'Loadplan No: ' +  RTRIM(@c_SourceKey) + '. Allocation Failed! ' + RTRIM(@c_errmsg)
                  END
                  ELSE -- IF @@ERROR = 0 --This parameter is nor pass out to this calling
                  BEGIN
                     SET @c_LoadPlanStatus = ''
                     SELECT @c_LoadPlanStatus = Status
                     FROM   LOADPLAN WITH (NOLOCK)
                     WHERE  LoadKey = @c_SourceKey

                     SET @c_StorerKey = ''
                     SELECT TOP 1 @c_StorerKey = StorerKey
                     FROM ORDERS WITH (NOLOCK)
                     WHERE LoadKey = @c_SourceKey

                     SELECT @c_UpStatus = '9'

                     IF @c_LoadPlanStatus IN ('0','1')
                     BEGIN
                        SELECT @c_EmailMsg = 'Loadplan No: ' +  RTRIM(@c_SourceKey) + ' Partial Allocation Detected.' + CHAR(13) + CHAR(13)

                        DECLARE CUR_ORDERDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                           SELECT OrderKey FROM LOADPLANDETAIL WITH (NOLOCK)
                           WHERE LOADKEY = @c_SourceKey
                           ORDER BY LoadLineNumber

                        OPEN CUR_ORDERDETAIL

                        FETCH NEXT FROM CUR_ORDERDETAIL INTO @c_OrderKey
                        WHILE @@FETCH_STATUS <> -1
                        BEGIN
                           SET @c_OrderStatus = ''
                           SELECT @c_OrderStatus = Status
                           FROM   ORDERS WITH (NOLOCK)
                           WHERE  OrderKey = @c_OrderKey

                           IF @c_OrderStatus = '1'
                           BEGIN
                              SET @c_EmailMsg = @c_EmailMsg + 'Order No: ' +  RTRIM(@c_OrderKey)
                                                + ' Partial Allocation Detected' + CHAR(13)
                           END
                           ELSE IF @c_OrderStatus = '0'
                           BEGIN
                              SET @c_EmailMsg = @c_EmailMsg + 'Order No: ' +  RTRIM(@c_OrderKey) +
                                                + ' Not Allocated.' + CHAR(13)
                           END

                           FETCH NEXT FROM CUR_ORDERDETAIL INTO @c_OrderKey
                        END   -- While
                        CLOSE CUR_ORDERDETAIL
                        DEALLOCATE CUR_ORDERDETAIL
                     END -- @c_LoadPlanStatus IN ('0','1')
                     ELSE
                        SELECT @c_EmailMsg = 'Loadplan No: ' +  RTRIM(@c_SourceKey) + ' For Storer ' + RTRIM(@c_StorerKey) + '. Allocation Failed with un-known reason. Please check with Administrator'
                  END   -- @@ERROR = 0
                  GOTO FETCH_NEXT
               END -- @c_SuperOrderFlag = 'Y'
            END   -- @c_SourceType = 'L'

            IF @c_SourceType = 'L'     -- Loadplan
            BEGIN
               DECLARE CUR_ORDERDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT OrderKey FROM LOADPLANDETAIL WITH (NOLOCK)
                  WHERE LOADKEY = @c_SourceKey
                  ORDER BY LoadLineNumber
            END
            ELSE IF @c_SourceType = 'O' -- CASE Order
            BEGIN
               DECLARE CUR_ORDERDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT OrderKey FROM ORDERS WITH (NOLOCK)
                  WHERE OrderKey = @c_SourceKey
            END
            ELSE IF @c_SourceType = 'W' -- Wave
            BEGIN
               DECLARE CUR_WAVEDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT OrderKey FROM WAVEDETAIL WITH (NOLOCK)
                  WHERE WaveKey = @c_SourceKey
                  ORDER BY WaveDetailKey
            END

            OPEN CUR_ORDERDETAIL

            FETCH NEXT FROM CUR_ORDERDETAIL INTO @c_OrderKey
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT @c_OrderKey 'Allocating Orderkey'
               END

               SET @c_ExtendParms = ISNULL(RTRIM(@c_ExtendParms), '') 
               IF @b_debug = 1
               BEGIN
                  EXEC nsp_OrderProcessing_Wrapper @c_OrderKey, '', 'N', 'N', 'DS1', @c_ExtendParms   
               END
               ELSE               
                  EXEC nsp_OrderProcessing_Wrapper @c_OrderKey, '', 'N', 'N', 'BEA', @c_ExtendParms 
  
               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_Continue = 3

                  IF @b_debug = 1
                  BEGIN
                     SELECT @c_OrderKey 'Allocation Orders Failed'
                  END
                  -- Update Status to Failed

                  SELECT @c_UpStatus = '5'

                  IF PATINDEX('%No Orders To Process%', @c_errmsg) > 0
                  BEGIN
                     SELECT @c_EmailMsg = 'Order No: ' +  RTRIM(@c_OrderKey) + '. No Orders To Process! ' + RTRIM(@c_errmsg) + CHAR(13)
                  END
                  ELSE
                     SELECT @c_EmailMsg = 'Order No: ' +  RTRIM(@c_OrderKey) + '. Allocation Failed! ' + RTRIM(@c_errmsg) + CHAR(13)
               END
               ELSE -- IF @@ERROR = 0 --This parameter is nor pass out to this calling
               BEGIN
                  SET @c_StorerKey = ''
                  SET @c_OrderStatus = ''
                  SELECT @c_OrderStatus = Status
                       , @c_StorerKey = StorerKey
                  FROM   ORDERS WITH (NOLOCK)
                  WHERE  OrderKey = @c_OrderKey

                  IF @c_OrderStatus = '1'
                  BEGIN
                     SELECT @c_UpStatus = '9' ,@c_ErrMsg = 'OrderKey: ' +  RTRIM(@c_OrderKey) + ': Partial Allocated!' + CHAR(13)
                  END
                  ELSE IF @c_OrderStatus = '2'
                  BEGIN
                     SELECT @c_UpStatus = '9' ,@c_ErrMsg = 'OrderKey: ' +  RTRIM(@c_OrderKey) + ': Fully Allocated!' + CHAR(13)
                  END
                  ELSE IF @c_OrderStatus = '0'
                  BEGIN
                     SELECT @c_UpStatus = '5' ,@c_ErrMsg = 'OrderKey: ' +  RTRIM(@c_OrderKey) + ': Not Allocated!' + CHAR(13)
                  END
                  ELSE
                  BEGIN
                     SELECT @c_UpStatus = 'E' ,@c_ErrMsg = 'OrderKey: ' +  RTRIM(@c_OrderKey) 
                           + ': Allocation Failed with un-known reason. Please check with Administrator!' + CHAR(13)  

                  END
                  SELECT @c_EmailMsg = @c_EmailMsg + 'StorerKey: ' + RTRIM(@c_StorerKey) + ', ' + RTRIM(@c_ErrMsg)
               END   -- @@ERROR = 0

               FETCH NEXT FROM CUR_ORDERDETAIL INTO @c_OrderKey
            END
            CLOSE CUR_ORDERDETAIL
            DEALLOCATE CUR_ORDERDETAIL
         END

         FETCH_NEXT:
         -- UPdate IDSAllocationPool Status
         BEGIN TRAN
         --(Wan01) - START
         SET @b_Success = 1
         IF @c_Wavekey <> ''
         BEGIN
            BEGIN TRY
               EXEC [isp_GetWaveStatus]         -- Get Update Wave always if Allocate from Wave Control
                        @c_WaveKey     = @c_WaveKey 
                     ,  @b_UpdateWave  = 1   --1 => yes, 0 => No
                     ,  @c_Status      = @c_WaveStatus   OUTPUT
                     ,  @b_Success     = @b_Success      OUTPUT
                     ,  @n_Err         = @n_Err          OUTPUT
                     ,  @c_ErrMsg      = @c_ErrMsg       OUTPUT
            END TRY
            BEGIN CATCH
               SET @b_Success = 0
            END CATCH
         END

         IF @b_Success = 1
         BEGIN
            UPDATE IDSAllocationPool WITH (ROWLOCK)
            SET STATUS = @c_UpStatus
               ,MsgText = @c_ErrMsg
            WHERE AllocPoolId = @c_UniqueKey

            IF @@ERROR <> 0
            BEGIN              
               SET @b_Success = 0
            END 
         END                   

         IF @b_Success = 0
         BEGIN                
            ROLLBACK TRAN      
            BREAK
         END                            
         --(Wan01) - END

         COMMIT TRAN

         IF LEN(@c_EmailMsg) > 0
         BEGIN
            INSERT INTO #B (ErrMsg)
            VALUES (@c_EmailMsg)
            -- SET @cRecipientList = ''
            --
            -- SELECT @cRecipientList = ISNULL(LONG,'')
            -- FROM   CODELKUP WITH (NOLOCK)
            -- WHERE  LISTNAME = 'USEREMAIL'
            --   AND  CODE = @c_UserName
            --
            -- IF @c_UpStatus IN ('5', 'E') AND LEN(@cRecipientList) = 0
            --    SET @cRecipientList = 'mindy.lin@idsgroup.com;waifai.leong@idsgroup.com'
            --
            -- IF LEN(@cRecipientList) > 0
            -- BEGIN
            --    IF @b_debug = 1
            --    BEGIN
            --       SELECT @c_EmailMsg 'Send Email'
            --    END
            --
            --    EXEC msdb.dbo.sp_send_dbmail
            --        @recipients  = @cRecipientList,
            --        @subject     = @cEmailSubject, --'Batch Allocation Alert',
            --        @body        = @c_EmailMsg,
            --        @body_format = 'TEXT';
            -- END
         END

         FETCH NEXT FROM C_Current_Sourcekey INTO @c_UniqueKey, @c_SourceKey, @c_SourceType, @c_ComputerName, @c_UserName, @c_ExtendParms
                  ,  @c_Wavekey, @c_AllocateCmd                                                                --Wan01
      END   -- While C_Current_Sourcekey CURSOR
      CLOSE C_Current_Sourcekey
      DEALLOCATE C_Current_Sourcekey

      IF EXISTS (SELECT 1 FROM #B WITH (NOLOCK)
                 WHERE ISNULL(RTRIM(ErrMsg),'') <> '')
      BEGIN
         SET @cRecipientList = ''

         SELECT TOP 1 @cRecipientList = ISNULL(LONG,'')
         FROM   CODELKUP WITH (NOLOCK)
         WHERE  LISTNAME = 'USEREMAIL'
         AND    CODE = 'BckEndAloc'  
         ORDER BY Code

         IF LEN(@cRecipientList) = 0
         BEGIN
            SET @cRecipientList = '' -- Leong01
         END

         IF LEN(@cRecipientList) > 0
         BEGIN
            DECLARE @tableHTML NVARCHAR(MAX);
            SET @tableHTML =
                N'<STYLE TYPE="text/css"> ' + CHAR(13) +
                N'<!--' + CHAR(13) +
                N'TR{font-family: Arial; font-size: 10pt;}' + CHAR(13) +
                N'TD{font-family: Arial; font-size: 9pt;}' + CHAR(13) +
                N'H3{font-family: Arial; font-size: 12pt;}' + CHAR(13) +
                N'BODY{font-family: Arial; font-size: 9pt;}' + CHAR(13) +
                N'--->' + CHAR(13) +
                N'</STYLE>' + CHAR(13) +
                N'<H3>Batch Allocation Alert</H3>' +
                N'<BODY><P ALIGN="LEFT">Please check the following records:</P></BODY>' +
                N'<TABLE BORDER="1" CELLSPACING="0" CELLPADDING="3">' +
                N'<TR BGCOLOR=#3BB9FF><TH>No</TH><TH>Error Message</TH></TR>' +
                CAST ( ( SELECT TD = SeqNo, '',
                                'TD/@align' = 'Left',
                                TD = ErrMsg, ''
                         FROM #B WITH (NOLOCK)
                    FOR XML PATH('TR'), TYPE
                ) AS NVARCHAR(MAX) ) +
                N'</TABLE>' ;

            SET @cEmailSubject = 'Batch Allocation Alert - Server (' + @@SERVERNAME + ') Database (' + DB_NAME() + ').'  
            
            EXEC msdb.dbo.sp_send_dbmail
                 @recipients  = @cRecipientList,
                 @subject     = @cEmailSubject,
                 @body        = @tableHTML,
                 @body_format = 'HTML';
         END
      END

      IF ISNULL(OBJECT_ID('tempdb..#B'),'') <> ''
      BEGIN
         DROP TABLE #B
      END
   END   -- IF @n_Continue = 1 OR @n_Continue=2
END

GO