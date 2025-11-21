SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/              
/* Store procedure: isp_WSITF_GEEKPLUSRBT_GENERIC_ORDER_INBOUND_POST    */              
/* Creation Date: 23-JUL-2018                                           */
/* Copyright: IDS                                                       */
/* Written by: KCY                                                      */
/*                                                                      */
/* Purpose: Pass Incoming Request String For Interface                  */
/*                                                                      */
/* Input Parameters:  @b_Debug            - 0                           */
/*                    @c_Format           - 'JSON'                      */
/*                    @c_UserID           - 'UserName'                  */
/*                    @c_OperationType    - 'Operation'                 */
/*                    @c_RequestString    - ''                          */
/*                    @b_Debug            - 0                           */
/*                                                                      */
/* Output Parameters: @b_Success          - Success Flag    = 0         */
/*                    @c_ErrNo            - Error No        = 0         */
/*                    @c_ErrMsg           - Error Message   = ''        */
/*                    @c_ResponseString   - ResponseString  = ''        */
/*                                                                      */
/* Called By: LeafAPIServer - isp_Generic_WebAPI_Request                */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Purposes														*/
/* 2018-10-23  KCY      Initial - Jira Ticket #WMS-5291                 */
/* 2018-08-20  KCY      1.0      Add Update TrafficCop (KCY01)          */
/* 2020-07-14  Alex     Jira Ticket #WMS-13309                          */
/************************************************************************/    
CREATE PROC [dbo].[isp_WSITF_GEEKPLUSRBT_GENERIC_ORDER_INBOUND_POST](
     @b_Debug                 INT
   , @c_OrderType             NVARCHAR(32)
   , @c_OwnerCode             NVARCHAR(32)
   , @c_StorerKey             NVARCHAR(15)
   , @c_RequestString         NVARCHAR(MAX)  
   , @b_Success               INT            = 0   OUTPUT
   , @n_ErrNo                 INT            = 0   OUTPUT
   , @c_ErrMsg                NVARCHAR(250)  = ''  OUTPUT
   , @c_ResponseString        NVARCHAR(MAX)  = ''  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue                    INT
         , @n_StartCnt                    INT
         , @c_ExecStatements              NVARCHAR(MAX)
         , @c_ExecArguments               NVARCHAR(2000)

         , @c_Application                 NVARCHAR(50)
         , @c_MessageType                 NVARCHAR(10)

         , @c_Facility                    NVARCHAR(5)

         , @c_pallet_code                 NVARCHAR(18)
         , @c_transaction_id              NVARCHAR(32)
         , @c_status                      NVARCHAR(5)
         , @c_owner_code                  NVARCHAR(16)
         , @n_sku_receive_amount          INT

         , @c_Lot                         NVARCHAR(10)
         , @c_FromLoc                     NVARCHAR(10)
         , @c_FromLocPickZone             NVARCHAR(10)
         , @c_ToRobotLoc                  NVARCHAR(10)
         , @c_ToRobotHOLDLoc              NVARCHAR(10)
         , @n_CurrentLLIQTY               INT
         , @c_ListName_ROBOTSTR           NVARCHAR(10)
         , @n_Exists                      INT
         , @n_QtyNotReceived              INT
         , @n_QtyReceived                 INT

   DECLARE --@c_OrderType                   NVARCHAR(32)
           @n_PickDetAmount               INT
         , @c_Orderkey                    NVARCHAR(20)
         , @c_PickDetailKey               NVARCHAR(10)
         , @n_RequestAmount               INT
         , @c_ShortPick                   NVARCHAR(20)
         , @c_FULLPick                    NVARCHAR(20)
         , @c_PickLoc                     NVARCHAR(10)
         , @n_OrderAmount                 INT
         , @n_ChckLastRqt                 INT
         , @cNewPickDetailKey             NVARCHAR( 10)

         , @c_ReservedSQLQuery1           NVARCHAR(MAX)
         , @c_ReservedSQLQuery2           NVARCHAR(MAX)
         , @c_SQLQuery                    NVARCHAR(MAX)
         , @c_SQLParams                   NVARCHAR(2000)

         , @c_out_order_code              NVARCHAR(32)
         , @c_container_code              NVARCHAR(32)
         , @c_sku_code                    NVARCHAR(32)
         , @n_amount                      INT
         , @c_reservedkey1                NVARCHAR(50)
         , @c_reservedkey2                NVARCHAR(50)
         , @c_reservedkey3                NVARCHAR(50)
         , @c_reservedkey4                NVARCHAR(50)
         , @c_reservedkey5                NVARCHAR(50)
         , @c_reservedkey6                NVARCHAR(50)
         , @c_reservedkey7                NVARCHAR(50)
         , @c_reservedkey8                NVARCHAR(50)
         , @c_reservedkey9                NVARCHAR(50)
         , @c_reservedkey10               NVARCHAR(50)
         , @c_reservedkey11               NVARCHAR(50)
         , @c_reservedkey12               NVARCHAR(50)
         , @c_reservedkey13               NVARCHAR(50)
         , @c_reservedkey14               NVARCHAR(50)
         , @c_reservedkey15               NVARCHAR(50)
         , @c_reservedkey16               NVARCHAR(50)
         , @c_reservedkey17               NVARCHAR(50)
         , @c_reservedkey18               NVARCHAR(50)
         , @c_reservedkey19               NVARCHAR(50)
         , @c_reservedkey20               NVARCHAR(50)

   SET @n_Continue                        = 1
   SET @n_StartCnt                        = @@TRANCOUNT
   SET @b_Success                         = 1
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = ''
   
   SET @c_Application                     = 'GEEK+_ORDER_RESPONSE_IN_LOADTYPE'
   SET @c_MessageType                     = 'WS_IN'

   SET @c_Facility                        = ''

   SET @c_pallet_code                     = ''
   SET @c_sku_code                        = ''
   SET @c_owner_code                      = ''
   SET @n_sku_receive_amount              = 0

   SET @c_Lot                             = ''
   SET @c_FromLoc                         = ''
   SET @c_ToRobotLoc                      = ''
   SET @c_ToRobotHOLDLoc                  = ''
   SET @n_CurrentLLIQTY                   = 0
   SET @c_ListName_ROBOTSTR               = 'ROBOTSTR'
   SET @n_QtyNotReceived                  = 0 
   SET @n_QtyReceived                     = 0 

   SET @n_Amount                          = 0
   SET @n_RequestAmount                   = 0
   SET @c_Orderkey                        = ''
   SET @c_PickDetailKey                   = ''
   SET @c_ShortPick                       = '4'
   SET @c_FULLPick                        = '3'
   SET @c_PickLoc                         = ''
   SET @n_OrderAmount                     = 0
   SET @n_ChckLastRqt                     = 0

   SET @n_Exists                          = 0 
   SET @c_ReservedSQLQuery1               = ''
   SET @c_ReservedSQLQuery2               = ''

   IF OBJECT_ID('tempdb..#TEMP_GEEK_ORDIN') IS NOT NULL
   DROP TABLE #TEMP_GEEK_ORDIN

   CREATE TABLE #TEMP_GEEK_ORDIN(
      out_order_code    NVARCHAR(32)   NULL,
      container_code    NVARCHAR(32)   NULL,
      sku_code          NVARCHAR(32)   NULL,
      amount            INT            NULL,
      [reservedkey1]    NVARCHAR(50)   NULL,
      [reservedkey2]    NVARCHAR(50)   NULL,
      [reservedkey3]    NVARCHAR(50)   NULL,
      [reservedkey4]    NVARCHAR(50)   NULL,
      [reservedkey5]    NVARCHAR(50)   NULL,
      [reservedkey6]    NVARCHAR(50)   NULL,
      [reservedkey7]    NVARCHAR(50)   NULL,
      [reservedkey8]    NVARCHAR(50)   NULL,
      [reservedkey9]    NVARCHAR(50)   NULL,
      [reservedkey10]   NVARCHAR(50)   NULL,
      [reservedkey11]   NVARCHAR(50)   NULL,
      [reservedkey12]   NVARCHAR(50)   NULL,
      [reservedkey13]   NVARCHAR(50)   NULL,
      [reservedkey14]   NVARCHAR(50)   NULL,
      [reservedkey15]   NVARCHAR(50)   NULL,
      [reservedkey16]   NVARCHAR(50)   NULL,
      [reservedkey17]   NVARCHAR(50)   NULL,
      [reservedkey18]   NVARCHAR(50)   NULL,
      [reservedkey19]   NVARCHAR(50)   NULL,
      [reservedkey20]   NVARCHAR(50)   NULL
   )

   SELECT @n_Exists = (1)
         ,@c_ReservedSQLQuery1 = ISNULL(RTRIM(ReservedSQLQuery1), '')
         ,@c_ReservedSQLQuery2 = ISNULL(RTRIM(ReservedSQLQuery2), '')
   FROM dbo.[GEEKPBOT_INTEG_CONFIG] WITH (NOLOCK)
   WHERE [InterfaceName] = ('ORD_INBOUND_' + @c_OrderType)
   AND [StorerKey] = @c_StorerKey

   IF @n_Exists = 0
   BEGIN
      SET @n_Continue = 3
      SET @n_ErrNo = 230411                                                                       
      SET @c_ErrMsg = '[GEEKPBOT_INTEG_CONFIG](ORD_INBOUND_' + @c_OrderType + ', ' + @c_StorerKey + ') is not setup'
      GOTO QUIT
   END

   IF @c_ReservedSQLQuery1 = '' OR @c_ReservedSQLQuery2 = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_ErrNo = 230412                                                                       
      SET @c_ErrMsg = '[GEEKPBOT_INTEG_CONFIG](ORD_INBOUND_' + @c_OrderType + ') ReservedSQLQuery1 & ReservedSQLQuery2 is empty.'
      GOTO QUIT
   END

   --Import data into temp table (begin)
   BEGIN TRY
      SET @c_SQLQuery = @c_ReservedSQLQuery1
      SET @c_SQLParams = '@c_RequestString NVARCHAR(MAX), @c_OrderType NVARCHAR(32)'

      IF @b_Debug = 1
      BEGIN
         PRINT '>==================================================>'
         PRINT '>>>> Full ReservedSQLQuery1 (BEGIN)'
         PRINT @c_SQLQuery
         PRINT '>>>> Full ReservedSQLQuery1 (END)'
         PRINT '>==================================================>'
      END
   
      EXEC sp_ExecuteSql @c_SQLQuery, @c_SQLParams, @c_RequestString, @c_OrderType
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @n_ErrNo = 230413
   	SET @c_ErrMsg = CONVERT(NVARCHAR(6),@n_ErrNo) + ' - ReservedSQLQuery1 Error - ' + ERROR_MESSAGE()
      GOTO QUIT

      IF @b_Debug = 1
      BEGIN
         PRINT '>>> GEN REQUEST QUERY CATCH EXCEPTION - ' + @c_ErrMsg
      END
   END CATCH
   --Import data into temp table (end)

   --Update PickDetail Status (Begin)
   DECLARE GEEKPLUS_ORDIN_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT 
      out_order_code, container_code, sku_code, amount, 
      [reservedkey1], [reservedkey2], [reservedkey3], 
      [reservedkey4], [reservedkey5], [reservedkey6], 
      [reservedkey7], [reservedkey8], [reservedkey9], 
      [reservedkey10], [reservedkey11], [reservedkey12], 
      [reservedkey13], [reservedkey14], [reservedkey15], 
      [reservedkey16], [reservedkey17], [reservedkey18], 
      [reservedkey19], [reservedkey20]
   FROM #TEMP_GEEK_ORDIN

   OPEN GEEKPLUS_ORDIN_LOOP
   FETCH NEXT FROM GEEKPLUS_ORDIN_LOOP INTO @c_out_order_code, @c_container_code, @c_sku_code, @n_amount, 
      @c_reservedkey1, @c_reservedkey2 , @c_reservedkey3 , @c_reservedkey4 , @c_reservedkey5 , 
      @c_reservedkey6 , @c_reservedkey7 , @c_reservedkey8 , @c_reservedkey9 , @c_reservedkey10, 
      @c_reservedkey11, @c_reservedkey12, @c_reservedkey13, @c_reservedkey14, @c_reservedkey15, 
      @c_reservedkey16, @c_reservedkey17, @c_reservedkey18, @c_reservedkey19, @c_reservedkey20
   WHILE @@FETCH_STATUS = 0 
   BEGIN
      SET @n_RequestAmount = @n_amount

      --Execute ReservedSQLQuery2 for GEEKPLUS_ORDIN_UPD Cursor BEGIN
      BEGIN TRY
         SET @c_SQLQuery = @c_ReservedSQLQuery2
         SET @c_SQLParams = '@c_out_order_code NVARCHAR(32), @c_container_cod NVARCHAR(32), @c_sku_code NVARCHAR(32), @n_amount INT, '
                          + '@c_reservedkey1  NVARCHAR(50), @c_reservedkey2  NVARCHAR(50), @c_reservedkey3  NVARCHAR(50), @c_reservedkey4  NVARCHAR(50), '
                          + '@c_reservedkey5  NVARCHAR(50), @c_reservedkey6  NVARCHAR(50), @c_reservedkey7  NVARCHAR(50), @c_reservedkey8  NVARCHAR(50), '
                          + '@c_reservedkey9  NVARCHAR(50), @c_reservedkey10 NVARCHAR(50), @c_reservedkey11 NVARCHAR(50), @c_reservedkey12 NVARCHAR(50), '
                          + '@c_reservedkey13 NVARCHAR(50), @c_reservedkey14 NVARCHAR(50), @c_reservedkey15 NVARCHAR(50), @c_reservedkey16 NVARCHAR(50), '
                          + '@c_reservedkey17 NVARCHAR(50), @c_reservedkey18 NVARCHAR(50), @c_reservedkey19 NVARCHAR(50), @c_reservedkey20 NVARCHAR(50), '
                          + '@c_StorerKey NVARCHAR(15)'

         IF @b_Debug = 1
         BEGIN
            PRINT '>==================================================>'
            PRINT '>>>> Full ReservedSQLQuery2 (BEGIN)'
            PRINT @c_SQLQuery
            PRINT '>>>> Full ReservedSQLQuery2 (END)'
            PRINT '>==================================================>'
         END

         EXEC sp_ExecuteSql @c_SQLQuery, @c_SQLParams, @c_out_order_code, @c_container_code, @c_sku_code, @n_amount, 
            @c_reservedkey1, @c_reservedkey2 , @c_reservedkey3 , @c_reservedkey4 , @c_reservedkey5 , 
            @c_reservedkey6 , @c_reservedkey7 , @c_reservedkey8 , @c_reservedkey9 , @c_reservedkey10, 
            @c_reservedkey11, @c_reservedkey12, @c_reservedkey13, @c_reservedkey14, @c_reservedkey15, 
            @c_reservedkey16, @c_reservedkey17, @c_reservedkey18, @c_reservedkey19, @c_reservedkey20, 
            @c_StorerKey

         IF CURSOR_STATUS('GLOBAL' , 'GEEKPLUS_ORDIN_UPD') <> -1
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 230413
      	   SET @c_ErrMsg = 'No Cursor(GEEKPLUS_ORDIN_UPD) Fonud after ReservedSQLQuery2 execution.'
            GOTO QUIT
         END

         OPEN GEEKPLUS_ORDIN_UPD
      END TRY
      BEGIN CATCH
         SET @n_Continue = 3
         SET @n_ErrNo = 230414
      	SET @c_ErrMsg = CONVERT(NVARCHAR(6),@n_ErrNo) + ' - ReservedSQLQuery2 Error - ' + ERROR_MESSAGE()
      
         IF @b_Debug = 1
         BEGIN
            PRINT '>>> GEN REQUEST QUERY CATCH EXCEPTION - ' + @c_ErrMsg
         END
         GOTO QUIT
      END CATCH
      --Execute ReservedSQLQuery2 for GEEKPLUS_ORDIN_UPD Cursor END

      FETCH NEXT FROM GEEKPLUS_ORDIN_UPD INTO @n_PickDetAmount, @c_Orderkey, @c_Status, @c_PickDetailKey, @c_PickLoc
      WHILE @@FETCH_STATUS = 0 
      BEGIN
            
      --when Qty more than ROBOT Request (Update Qty, DropId using SKU, OrderKey, Status, PickDetailKey)
      IF @n_PickDetAmount <= @n_RequestAmount
      BEGIN
         UPDATE dbo.PickDetail WITH (ROWLOCK)
         SET DropId = @c_container_code
            ,[STATUS] = @c_FULLPick
         WHERE SKU = @c_sku_code
         AND Orderkey = @c_Orderkey
         AND PickDetailKey = @c_PickDetailKey
         AND LOC = @c_PickLoc


         IF @@ERROR <> 0                                                                                             
         BEGIN
            ROLLBACK TRAN
            SET @n_ErrNo = 230415                                                                                      
            SET @c_ErrMsg = 'FAILD TO UPDATE PickDetail.QTY and PickDetail.DropId and PickDetail.Status'
                           + '. (isp_WSITF_GEEKPLUSRBT_GENERIC_ORDER_INBOUND_POST)'    
         GOTO QUIT                                                                                          
         END  --IF @@ERROR <> 0
      END
      --when Qty less than ROBOT Request
      ELSE IF @n_PickDetAmount > @n_RequestAmount AND @n_RequestAmount > 0
      BEGIN   
           
         --Update first record with ROBOT remaining amount
         UPDATE dbo.PickDetail WITH (ROWLOCK)
         SET QTY = @n_RequestAmount
            , DropId = @c_container_code
            ,[STATUS] = @c_FULLPick
            ,TrafficCop = NULL --KCY01
            ,EditDate = GETDATE() --KCY01
            ,EditWho  = SUSER_SNAME() --KCY01
         WHERE SKU = @c_sku_code
         AND Orderkey = @c_Orderkey
         AND PickDetailKey = @c_PickDetailKey
         AND LOC = @c_PickLoc
                       
         --GET PickDetailKey
         EXECUTE dbo.nspg_GetKey
            'PICKDETAILKEY', 
            10 ,
            @cNewPickDetailKey   OUTPUT,
            @b_Success           OUTPUT,
            @n_ErrNo             OUTPUT,
            @c_ErrMsg            OUTPUT
         IF @b_Success <> 1
         BEGIN
            ROLLBACK TRAN
            SET @n_ErrNo = 230416                                                                       
            SET @c_ErrMsg = 'FAILD TO GET PickDetail KEY'
                           + '. (isp_WSITF_GEEKPLUSRBT_GENERIC_ORDER_INBOUND_POST)'    
         END
                       
         --split shortpick record with New PickDetailkey
         INSERT INTO dbo.PickDetail (
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, 
            UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, 
            ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
            EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
            PickDetailKey, 
            QTY, 
            TrafficCop,
            OptimizeCop)
         SELECT
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, 
            --UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 
            UOMQTY, QTYMoved, '0', DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, --KCY01
            CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
            EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
            @cNewPickDetailKey, 
            --@n_RequestAmount - @n_PickDetAmount , -- QTY
            @n_PickDetAmount - @n_RequestAmount , -- QTY
            NULL, -- TrafficCop
            '1'   -- OptimizeCop
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE SKU = @c_sku_code
         AND Orderkey = @c_Orderkey
         AND PickDetailKey = @c_PickDetailKey
         AND LOC = @c_PickLoc
         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @n_ErrNo = 230417                                                                       
            SET @c_ErrMsg = 'FAILD TO SPLIT PickDetail RECORD'
                           + '. (isp_WSITF_GEEKPLUSRBT_GENERIC_ORDER_INBOUND_POST)'   
         END

      END

      SET @n_RequestAmount = @n_RequestAmount - @n_PickDetAmount

      FETCH NEXT FROM GEEKPLUS_ORDIN_UPD INTO @n_PickDetAmount, @c_Orderkey, @c_Status, @c_PickDetailKey, @c_PickLoc
      END
      CLOSE GEEKPLUS_ORDIN_UPD  
      DEALLOCATE GEEKPLUS_ORDIN_UPD  

     FETCH NEXT FROM GEEKPLUS_ORDIN_LOOP INTO @c_out_order_code, @c_container_code, @c_sku_code, @n_amount, 
         @c_reservedkey1, @c_reservedkey2 , @c_reservedkey3 , @c_reservedkey4 , @c_reservedkey5 , 
         @c_reservedkey6 , @c_reservedkey7 , @c_reservedkey8 , @c_reservedkey9 , @c_reservedkey10, 
         @c_reservedkey11, @c_reservedkey12, @c_reservedkey13, @c_reservedkey14, @c_reservedkey15, 
         @c_reservedkey16, @c_reservedkey17, @c_reservedkey18, @c_reservedkey19, @c_reservedkey20  
   END
   CLOSE GEEKPLUS_ORDIN_LOOP  
   DEALLOCATE GEEKPLUS_ORDIN_LOOP
   --Update PickDetail Status (END)

   --Update Remaing PickDetail to ShortPick
   DECLARE GEEKPLUS_ORDIN_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT 
      out_order_code, container_code, sku_code, amount, 
      [reservedkey1], [reservedkey2], [reservedkey3], 
      [reservedkey4], [reservedkey5], [reservedkey6], 
      [reservedkey7], [reservedkey8], [reservedkey9], 
      [reservedkey10], [reservedkey11], [reservedkey12], 
      [reservedkey13], [reservedkey14], [reservedkey15], 
      [reservedkey16], [reservedkey17], [reservedkey18], 
      [reservedkey19], [reservedkey20]
   FROM #TEMP_GEEK_ORDIN

   OPEN GEEKPLUS_ORDIN_LOOP
   FETCH NEXT FROM GEEKPLUS_ORDIN_LOOP INTO @c_out_order_code, @c_container_code, @c_sku_code, @n_amount, 
      @c_reservedkey1, @c_reservedkey2 , @c_reservedkey3 , @c_reservedkey4 , @c_reservedkey5 , 
      @c_reservedkey6 , @c_reservedkey7 , @c_reservedkey8 , @c_reservedkey9 , @c_reservedkey10, 
      @c_reservedkey11, @c_reservedkey12, @c_reservedkey13, @c_reservedkey14, @c_reservedkey15, 
      @c_reservedkey16, @c_reservedkey17, @c_reservedkey18, @c_reservedkey19, @c_reservedkey20
   WHILE @@FETCH_STATUS = 0 
   BEGIN
      --Execute ReservedSQLQuery2 for GEEKPLUS_ORDIN_UPD Cursor BEGIN
      BEGIN TRY
         SET @c_SQLQuery = @c_ReservedSQLQuery2
         SET @c_SQLParams = '@c_out_order_code NVARCHAR(32), @c_container_cod NVARCHAR(32), @c_sku_code NVARCHAR(32), @n_amount INT, '
                          + '@c_reservedkey1  NVARCHAR(50), @c_reservedkey2  NVARCHAR(50), @c_reservedkey3  NVARCHAR(50), @c_reservedkey4  NVARCHAR(50), '
                          + '@c_reservedkey5  NVARCHAR(50), @c_reservedkey6  NVARCHAR(50), @c_reservedkey7  NVARCHAR(50), @c_reservedkey8  NVARCHAR(50), '
                          + '@c_reservedkey9  NVARCHAR(50), @c_reservedkey10 NVARCHAR(50), @c_reservedkey11 NVARCHAR(50), @c_reservedkey12 NVARCHAR(50), '
                          + '@c_reservedkey13 NVARCHAR(50), @c_reservedkey14 NVARCHAR(50), @c_reservedkey15 NVARCHAR(50), @c_reservedkey16 NVARCHAR(50), '
                          + '@c_reservedkey17 NVARCHAR(50), @c_reservedkey18 NVARCHAR(50), @c_reservedkey19 NVARCHAR(50), @c_reservedkey20 NVARCHAR(50), '
                          + '@c_StorerKey NVARCHAR(15)'

         IF @b_Debug = 1
         BEGIN
            PRINT '>==================================================>'
            PRINT '>>>> Full ReservedSQLQuery2 (BEGIN)'
            PRINT @c_SQLQuery
            PRINT '>>>> Full ReservedSQLQuery2 (END)'
            PRINT '>==================================================>'
         END

         EXEC sp_ExecuteSql @c_SQLQuery, @c_SQLParams, @c_out_order_code, @c_container_code, @c_sku_code, @n_amount, 
            @c_reservedkey1, @c_reservedkey2 , @c_reservedkey3 , @c_reservedkey4 , @c_reservedkey5 , 
            @c_reservedkey6 , @c_reservedkey7 , @c_reservedkey8 , @c_reservedkey9 , @c_reservedkey10, 
            @c_reservedkey11, @c_reservedkey12, @c_reservedkey13, @c_reservedkey14, @c_reservedkey15, 
            @c_reservedkey16, @c_reservedkey17, @c_reservedkey18, @c_reservedkey19, @c_reservedkey20, 
            @c_StorerKey

         IF CURSOR_STATUS('GLOBAL' , 'GEEKPLUS_ORDIN_UPD') <> -1
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 230418
      	   SET @c_ErrMsg = 'No Cursor(GEEKPLUS_ORDIN_UPD) Fonud after ReservedSQLQuery2 execution.'
            GOTO QUIT
         END

         OPEN GEEKPLUS_ORDIN_UPD
      END TRY
      BEGIN CATCH
         SET @n_Continue = 3
         SET @n_ErrNo = 230419
      	SET @c_ErrMsg = CONVERT(NVARCHAR(6),@n_ErrNo) + ' - ReservedSQLQuery2 Error - ' + ERROR_MESSAGE()
      
         IF @b_Debug = 1
         BEGIN
            PRINT '>>> GEN REQUEST QUERY CATCH EXCEPTION - ' + @c_ErrMsg
         END
         GOTO QUIT
      END CATCH
      --Execute ReservedSQLQuery2 for GEEKPLUS_ORDIN_UPD Cursor END

      FETCH NEXT FROM GEEKPLUS_ORDIN_UPD INTO @n_PickDetAmount, @c_Orderkey, @c_Status, @c_PickDetailKey, @c_PickLoc
      WHILE @@FETCH_STATUS = 0 
      BEGIN
         --Update remaining Orderkey
         UPDATE dbo.PickDetail WITH (ROWLOCK)
         SET DropId = @c_container_code
            ,[STATUS] = @c_ShortPick
         WHERE PickDetailKey = @c_PickDetailKey
         AND Orderkey = @c_Orderkey
         AND SKU = @c_sku_code
         AND LOC = @c_PickLoc
         AND [Status] = @c_Status

         FETCH NEXT FROM GEEKPLUS_ORDIN_UPD INTO @n_PickDetAmount, @c_Orderkey, @c_Status, @c_PickDetailKey, @c_PickLoc
      END
      CLOSE GEEKPLUS_ORDIN_UPD  
      DEALLOCATE GEEKPLUS_ORDIN_UPD 

      FETCH NEXT FROM GEEKPLUS_ORDIN_LOOP INTO @c_out_order_code, @c_container_code, @c_sku_code, @n_amount, 
         @c_reservedkey1, @c_reservedkey2 , @c_reservedkey3 , @c_reservedkey4 , @c_reservedkey5 , 
         @c_reservedkey6 , @c_reservedkey7 , @c_reservedkey8 , @c_reservedkey9 , @c_reservedkey10, 
         @c_reservedkey11, @c_reservedkey12, @c_reservedkey13, @c_reservedkey14, @c_reservedkey15, 
         @c_reservedkey16, @c_reservedkey17, @c_reservedkey18, @c_reservedkey19, @c_reservedkey20
   END
   CLOSE GEEKPLUS_ORDIN_LOOP  
   DEALLOCATE GEEKPLUS_ORDIN_LOOP   

   QUIT:

   IF CURSOR_STATUS('GLOBAL' , 'GEEKPLUS_ORDIN_UPD') in (0 , 1)  
   BEGIN  
      CLOSE GEEKPLUS_ORDIN_UPD  
      DEALLOCATE GEEKPLUS_ORDIN_UPD  
   END
   IF CURSOR_STATUS('LOCAL' , 'GEEKPLUS_ORDIN_LOOP') in (0 , 1)  
   BEGIN  
      CLOSE GEEKPLUS_ORDIN_LOOP  
      DEALLOCATE GEEKPLUS_ORDIN_LOOP  
   END

   IF @n_Continue = 3 AND @n_ErrNo <> 0
   BEGIN
      SET @b_Success = 0      
      IF @@TRANCOUNT > @n_StartCnt AND @@TRANCOUNT = 1 
      BEGIN               
         ROLLBACK TRAN      
      END      
      ELSE      
      BEGIN      
         WHILE @@TRANCOUNT > @n_StartCnt      
         BEGIN      
            COMMIT TRAN      
         END      
      END   
      RETURN      
   END      
   ELSE      
   BEGIN      
      SELECT @b_Success = 1      
      WHILE @@TRANCOUNT > @n_StartCnt      
      BEGIN      
         COMMIT TRAN      
      END      
      RETURN      
   END
END -- Procedure  

GO