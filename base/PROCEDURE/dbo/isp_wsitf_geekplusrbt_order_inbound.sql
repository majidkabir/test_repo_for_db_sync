SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/              
/* Store procedure: isp_WSITF_GeekPlusRBT_Order_Inbound                 */              
/* Creation Date: 21-JUN-2018                                           */
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
/* 2018-06-21  KCY      Initial - Jira Ticket #WMS-5291                 */
/************************************************************************/    
CREATE PROC [dbo].[isp_WSITF_GeekPlusRBT_Order_Inbound](
     @b_Debug           INT            = 0
   , @c_Format          VARCHAR(10)    = ''
   , @c_UserID          NVARCHAR(256)  = ''
   , @c_OperationType   NVARCHAR(60)   = ''
   , @c_RequestString   NVARCHAR(MAX)  = ''
   , @b_Success         INT            = 0   OUTPUT
   , @n_ErrNo           INT            = 0   OUTPUT
   , @c_ErrMsg          NVARCHAR(250)  = ''  OUTPUT
   , @c_ResponseString  NVARCHAR(MAX)  = ''  OUTPUT
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
         , @c_StorerKey                   NVARCHAR(15)

         , @c_pallet_code                 NVARCHAR(18)
         , @c_transaction_id              NVARCHAR(32)
         , @c_sku_code                    NVARCHAR(20)
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

   DECLARE @c_OrderType                   NVARCHAR(32)
         , @c_RequestKey                  NVARCHAR(32)
         , @c_DropId                      NVARCHAR(32)
         , @c_SKU                         NVARCHAR(32)
         , @n_Amount                      INT
         , @n_PickDetAmount                  INT
         , @c_Orderkey                    NVARCHAR(20)
         , @c_PickDetailKey               NVARCHAR(10)
         , @n_RequestAmount                 INT
         , @c_ShortPick                   NVARCHAR(20)
         , @c_FULLPick                    NVARCHAR(20)
         , @c_PickLoc                     NVARCHAR(10)
         , @n_OrderAmount                 INT
         , @n_ChckLastRqt                 INT
         , @cNewPickDetailKey             NVARCHAR( 10)

   SET @n_Continue                        = 1
   SET @n_StartCnt                        = @@TRANCOUNT
   SET @b_Success                         = 1
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = ''
   
   SET @c_Application                     = 'GEEK+_ORDER_RESPONSE_IN'
   SET @c_MessageType                     = 'WS_IN'

   SET @c_Facility                        = ''
   SET @c_StorerKey                       = ''

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

   SET @c_OrderType                       = ''
   SET @c_RequestKey                      = ''
   SET @c_DropId                          = ''
   SET @c_SKU                             = ''
   SET @n_Amount                          = 0
   SET @n_RequestAmount                     = 0
   SET @c_Orderkey                        = ''
   SET @c_PickDetailKey                   = ''
   SET @c_ShortPick                       = '4'
   SET @c_FULLPick                        = '3'
   SET @c_PickLoc                         = ''
   SET @n_OrderAmount                     = 0
   SET @n_ChckLastRqt                     = 0


   --IF OBJECT_ID('tempdb..#TEMP_Geek_PalletList') IS NOT NULL
   --DROP TABLE #TEMP_Geek_PalletList

   --CREATE TABLE #TEMP_Geek_PalletList(
   --   receipt_code      NVARCHAR(32),
   --   pallet_id         NVARCHAR(18),
   --   [status]          INT
   --)

   IF NOT ISJSON(@c_RequestString) > 0
   BEGIN
      SET @n_Continue = 3
      SET @n_ErrNo = 210000
      SET @c_ErrMsg = CONVERT(NVARCHAR, @n_ErrNo) + ' - invalid JSON request..'
      GOTO QUIT
   END

   BEGIN TRAN
   --IF OBJECT_ID('tempdb..#TEMP_SelectedOrder') IS NOT NULL
   --DROP TABLE #TEMP_SelectedOrder

   --CREATE TABLE #TEMP_SelectedOrder(
   --   OrderKey          NVARCHAR(10),
   --   SKU               NVARCHAR(32),
   --   OrderLineNumber   NVARCHAR(20),
   --   Storerkey         NVARCHAR(15),
   --   Loc               NVARCHAR(10)
   --)

   --INSERT INTO #TEMP_SelectedOrder ( pallet_code, transaction_id, sku_code, [status], owner_code, amount )
   
   DECLARE GEEKPLUS_ORDIN_JSON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT order_list.revervation1
   FROM OPENJSON(@c_RequestString, '$.body.order_list')
   WITH (
      revervation1         NVARCHAR(50)      '$.revervation1'
   ) As order_list

   --SELECT body_List.order_amount,order_list.revervation1, LSKU.out_order_code, LSKU.container_code, LSKU.sku_code, LSKU.amount
   --FROM OPENJSON(@c_RequestString, '$.body')
   --WITH (
   --   order_amount         NVARCHAR(50)      '$.order_amount',
   --   [order_list]         NVARCHAR(MAX) As JSON-- '$.order_list'
   --) As body_List
   --CROSS APPLY   
   --OPENJSON(body_List.order_list)
   --WITH (
   --   revervation1         NVARCHAR(50)      '$.revervation1',
   --   [container_list]     NVARCHAR(MAX) As JSON,-- '$.sku_list'
   --   [sku_list]           NVARCHAR(MAX) As JSON-- '$.sku_list'
   --) As order_list
   --CROSS APPLY 
   --OPENJSON (order_list.container_list)
   --with
   --(
   --   [sku_list]     NVARCHAR(MAX) As JSON-- '$.sku_list'
   --) as container_list
   -- CROSS APPLY 
   --OPENJSON (container_list.sku_list)
   --with
   --(
   --   out_order_code       NVARCHAR(32)      '$.out_order_code',
   --   container_code       NVARCHAR(32)      '$.container_code',
   --   sku_code             NVARCHAR(32)      '$.sku_code',
   --   amount               INT               '$.amount'
   --) as LSKU

   OPEN GEEKPLUS_ORDIN_JSON  
   --FETCH NEXT FROM GEEKPLUS_ORDIN_JSON INTO @c_OrderType, @c_RequestKey, @c_DropId, @c_SKU, @n_Amount
   FETCH NEXT FROM GEEKPLUS_ORDIN_JSON INTO @c_OrderType
   WHILE @@FETCH_STATUS = 0 
   BEGIN
     
      IF @c_OrderType = 'LOAD'
      BEGIN
         --SET @n_RequestAmount = @n_Amount

         --BEGIN TRAN

         EXEC dbo.isp_WSITF_GeekPlusRBT_Order_Inbound_Load
           @b_Debug 
         , @c_OrderType        
         , @c_RequestString 
         , @b_Success        OUTPUT
         , @n_ErrNo          OUTPUT
         , @c_ErrMsg         OUTPUT
         , @c_ResponseString OUTPUT
         IF @b_Success <> 1
         BEGIN
            ROLLBACK TRAN
            SET @n_ErrNo = 230401                                                                       
            SET @c_ErrMsg = 'FAILD TO Exec '
                           + '. (isp_WSITF_GeekPlusRBT_Order_Inbound)'    
         END

         --DECLARE GEEKPLUS_ORDIN_Upd CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         ----SUM Amount based on orderey using loadkey
         --SELECT QTY
         --      , OrderKey  
         --      , [STATUS]
         --      , PickDetailKey
         --      , LOC
         --FROM PickDetail WITH (NOLOCK) 
         --WHERE OrderKey IN (SELECT OrderKey 
         --                     FROM LoadPlanDetail WITH (NOLOCK) 
         --                     WHERE LoadKey = @c_RequestKey)
         --AND [STATUS] = '0'
         --AND LOC IN (SELECT LOC FROM Loc WITH (NOLOCK) WHERE LocationCategory = 'ROBOT')
         --AND SKU = @c_SKU

         --OPEN GEEKPLUS_ORDIN_Upd  
         --FETCH NEXT FROM GEEKPLUS_ORDIN_Upd INTO @n_PickDetAmount, @c_Orderkey, @c_Status, @c_PickDetailKey, @c_PickLoc
         --WHILE @@FETCH_STATUS = 0 
         --BEGIN
            
         ----when Qty more than ROBOT Request (Update Qty, DropId using SKU, OrderKey, Status, PickDetailKey)
         --IF @n_PickDetAmount >= @n_RequestAmount
         --BEGIN
         --   UPDATE dbo.PickDetail WITH (ROWLOCK)
         --   SET DropId = @c_DropId
         --      ,[STATUS] = @c_FULLPick
         --   WHERE SKU = @c_SKU
         --   AND Orderkey = @c_Orderkey
         --   AND PickDetailKey = @c_PickDetailKey
         --   AND LOC = @c_PickLoc


         --   IF @@ERROR <> 0                                                                                             
         --   BEGIN
         --      ROLLBACK TRAN
         --      SET @n_ErrNo = 230401                                                                                      
         --      SET @c_ErrMsg = 'FAILD TO UPDATE PickDetail.QTY and PickDetail.DropId and PickDetail.Status'
         --                     + '. (isp_WSITF_GeekPlusRBT_Order_Inbound)'    
         --   GOTO QUIT                                                                                          
         --   END  --IF @@ERROR <> 0
         --END
         ----when Qty less than ROBOT Request
         --ELSE IF @n_PickDetAmount < @n_RequestAmount
         --BEGIN
         --   --ROBOT remaining reuqest qty still not 0
         --   IF @n_RequestAmount <> 0
         --   BEGIN            
         --      --GET PickDetailKey
         --      EXECUTE dbo.nspg_GetKey
         --         'PICKDETAILKEY', 
         --         10 ,
         --         @cNewPickDetailKey OUTPUT,
         --         @bSuccess          OUTPUT,
         --         @nErrNo            OUTPUT,
         --         @cErrMsg           OUTPUT
         --      IF @bSuccess <> 1
         --      BEGIN
         --         ROLLBACK TRAN
         --         SET @n_ErrNo = 230401                                                                       
         --         SET @c_ErrMsg = 'FAILD TO GET PickDetail KEY'
         --                        + '. (isp_WSITF_GeekPlusRBT_Order_Inbound)'    
         --      END
                       
         --      --split shortpick record
         --      INSERT INTO dbo.PickDetail (
         --         CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, 
         --         UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, 
         --         ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
         --         EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
         --         PickDetailKey, 
         --         QTY, 
         --         TrafficCop,
         --         OptimizeCop)
         --      SELECT
         --         CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, 
         --         UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 
         --         CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
         --         EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
         --         @cNewPickDetailKey, 
         --         @n_RequestAmount - @n_PickDetAmount , -- QTY
         --         NULL, -- TrafficCop
         --         '1'   -- OptimizeCop
         --      FROM dbo.PickDetail WITH (NOLOCK) 
         --   	WHERE SKU = @c_SKU
         --      AND Orderkey = @c_Orderkey
         --      AND PickDetailKey = @c_PickDetailKey
         --      AND LOC = @c_PickLoc
         --      IF @@ERROR <> 0
         --      BEGIN
         --   		SET @n_ErrNo = 230401                                                                       
         --         SET @c_ErrMsg = 'FAILD TO SPLIT PickDetail RECORD'
         --                        + '. (isp_WSITF_GeekPlusRBT_Order_Inbound)'   
         --      END

         --      --Update first record with ROBOT remaining amount
         --      UPDATE dbo.PickDetail WITH (ROWLOCK)
         --      SET DropId = @c_DropId
         --         ,[STATUS] = @c_ShortPick
         --      WHERE SKU = @c_SKU
         --      AND Orderkey = @c_Orderkey
         --      AND PickDetailKey = @c_PickDetailKey
         --      AND LOC = @c_PickLoc

         --   END         
         --END

         --SET @n_RequestAmount = @n_RequestAmount - @n_PickDetAmount

         --FETCH NEXT FROM GEEKPLUS_ORDIN_Upd INTO @n_PickDetAmount, @c_Orderkey, @c_Status, @c_PickDetailKey, @c_PickLoc
         --END
         --CLOSE GEEKPLUS_ORDIN_Upd  
         --DEALLOCATE GEEKPLUS_ORDIN_Upd  

         --WHILE @@TRANCOUNT > 0
         --      COMMIT TRAN
         
      END   --IF @c_OrderType = 'LOAD'
      ELSE IF @c_OrderType = 'BATCH'
      BEGIN
         
         --SET @n_RequestAmount = @n_Amount

         --BEGIN TRAN

         EXEC dbo.isp_WSITF_GeekPlusRBT_Order_Inbound_Batch
           @b_Debug 
         , @c_OrderType        
         , @c_RequestString 
         , @b_Success        OUTPUT
         , @n_ErrNo          OUTPUT
         , @c_ErrMsg         OUTPUT
         , @c_ResponseString OUTPUT
         IF @b_Success <> 1
         BEGIN
            ROLLBACK TRAN
            SET @n_ErrNo = 230401                                                                       
            SET @c_ErrMsg = 'FAILD TO Exec '
                           + '. (isp_WSITF_GeekPlusRBT_Order_Inbound)'    
         END

         --DECLARE GEEKPLUS_ORDIN_Upd CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         ----SUM Amount based on orderey using loadkey
         --SELECT QTY
         --      , OrderKey  
         --      , [STATUS]
         --      , PickDetailKey
         --      , Loc
         --FROM PickDetail WITH (NOLOCK) 
         --WHERE OrderKey IN (SELECT OrderKey 
         --                   FROM PackTask WITH (NOLOCK) 
         --                   WHERE TaskBatchNo = @c_RequestKey)
         --AND [STATUS] = '0'
         --AND LOC IN (SELECT LOC FROM Loc WITH (NOLOCK) WHERE LocationCategory = 'ROBOT')
         --AND SKU = @c_SKU

         --OPEN GEEKPLUS_ORDIN_Upd  
         --FETCH NEXT FROM GEEKPLUS_ORDIN_Upd INTO @n_PickDetAmount, @c_Orderkey, @c_Status, @c_PickDetailKey, @c_PickLoc
         --WHILE @@FETCH_STATUS = 0 
         --BEGIN

         --   --when Qty more than ROBOT Request (Update Qty, DropId using SKU, OrderKey, Status, PickDetailKey)
         --   IF @n_PickDetAmount >= @n_RequestAmount
         --   BEGIN
         --      UPDATE dbo.PickDetail WITH (ROWLOCK)
         --      SET DropId = @c_DropId
         --         ,[STATUS] = @c_FULLPick
         --      WHERE SKU = @c_SKU
         --      AND Orderkey = @c_Orderkey
         --      AND PickDetailKey = @c_PickDetailKey
         --      AND LOC = @c_PickLoc

         --      SET @n_RequestAmount = @n_RequestAmount - @n_PickDetAmount

         --      IF @@ERROR <> 0                                                                                             
         --      BEGIN
         --         ROLLBACK TRAN
         --         SET @n_ErrNo = 230401                                                                                      
         --         SET @c_ErrMsg = 'FAILD TO UPDATE PickDetail.QTY and PickDetail.DropId and PickDetail.Status'
         --                        + '. (isp_WSITF_GeekPlusRBT_Order_Inbound)'    
         --      GOTO QUIT                                                                                          
         --      END  --IF @@ERROR <> 0
         --   END
         --   ELSE IF @n_PickDetAmount < @n_RequestAmount
         --   BEGIN
         --      --ROBOT remaining reuqest qty still not 0
         --      IF @n_RequestAmount <> 0
         --      BEGIN            
         --         --GET PickDetailKey
         --         EXECUTE dbo.nspg_GetKey
         --            'PICKDETAILKEY', 
         --            10 ,
         --            @cNewPickDetailKey   OUTPUT,
         --            @b_Success           OUTPUT,
         --            @n_ErrNo             OUTPUT,
         --            @c_ErrMsg            OUTPUT
         --         IF @b_Success <> 1
         --         BEGIN
         --            ROLLBACK TRAN
         --            SET @n_ErrNo = 230401                                                                       
         --            SET @c_ErrMsg = 'FAILD TO GET PickDetail KEY'
         --                           + '. (isp_WSITF_GeekPlusRBT_Order_Inbound)'    
         --         END
                       
         --         --split shortpick record
         --         INSERT INTO dbo.PickDetail (
         --            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, 
         --            UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, 
         --            ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
         --            EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
         --            PickDetailKey, 
         --            QTY, 
         --            TrafficCop,
         --            OptimizeCop)
         --         SELECT
         --            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, 
         --            UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 
         --            CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
         --            EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
         --            @cNewPickDetailKey, 
         --            @n_RequestAmount - @n_PickDetAmount , -- QTY
         --            NULL, -- TrafficCop
         --            '1'   -- OptimizeCop
         --         FROM dbo.PickDetail WITH (NOLOCK) 
         --   	   WHERE SKU = @c_SKU
         --         AND Orderkey = @c_Orderkey
         --         AND PickDetailKey = @c_PickDetailKey
         --         AND LOC = @c_PickLoc
         --         IF @@ERROR <> 0
         --         BEGIN
         --   		   SET @n_ErrNo = 230401                                                                       
         --            SET @c_ErrMsg = 'FAILD TO SPLIT PickDetail RECORD'
         --                           + '. (isp_WSITF_GeekPlusRBT_Order_Inbound)'   
         --         END

         --         --Update first record with ROBOT remaining amount
         --         UPDATE dbo.PickDetail WITH (ROWLOCK)
         --         SET DropId = @c_DropId
         --            ,[STATUS] = @c_ShortPick
         --         WHERE SKU = @c_SKU
         --         AND Orderkey = @c_Orderkey
         --         AND PickDetailKey = @c_PickDetailKey
         --         AND LOC = @c_PickLoc

         --      END         
         --   END

         --   SET @n_RequestAmount = @n_RequestAmount - @n_PickDetAmount

         --   FETCH NEXT FROM GEEKPLUS_ORDIN_Upd INTO @n_PickDetAmount, @c_Orderkey, @c_Status, @c_PickDetailKey, @c_PickLoc
         --END
         --CLOSE GEEKPLUS_ORDIN_Upd  
         --DEALLOCATE GEEKPLUS_ORDIN_Upd  
         
         --WHILE @@TRANCOUNT > 0
         --      COMMIT TRAN

      END   --IF @c_OrderType = 'BATCH'
      ELSE IF @c_OrderType = 'ORDER'
      BEGIN
         --SET @n_RequestAmount = @n_Amount

         --BEGIN TRAN

         EXEC dbo.isp_WSITF_GeekPlusRBT_Order_Inbound_Order
           @b_Debug   
         , @c_OrderType      
         , @c_RequestString 
         , @b_Success        OUTPUT
         , @n_ErrNo          OUTPUT
         , @c_ErrMsg         OUTPUT
         , @c_ResponseString OUTPUT
         IF @b_Success <> 1
         BEGIN
            ROLLBACK TRAN
            SET @n_ErrNo = 230401                                                                       
            SET @c_ErrMsg = 'FAILD TO Exec '
                           + '. (isp_WSITF_GeekPlusRBT_Order_Inbound)'    
         END

         --DECLARE GEEKPLUS_ORDIN_Upd CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         ----SUM Amount based on orderey using loadkey
         --SELECT QTY
         --      , OrderKey  
         --      , [STATUS]
         --      , PickDetailKey
         --      , Loc
         --FROM PickDetail WITH (NOLOCK) 
         --WHERE OrderKey = @c_RequestKey
         --AND [STATUS] = '0'
         --AND LOC IN (SELECT LOC FROM Loc WITH (NOLOCK) WHERE LocationCategory = 'ROBOT')
         --AND SKU = @c_SKU

         --OPEN GEEKPLUS_ORDIN_Upd  
         --FETCH NEXT FROM GEEKPLUS_ORDIN_Upd INTO @n_PickDetAmount, @c_Orderkey, @c_Status, @c_PickDetailKey, @c_PickLoc
         --WHILE @@FETCH_STATUS = 0 
         --BEGIN

         --   --Update Qty, DropId using SKU, OrderKey, Status, PickDetailKey
         --   IF @n_PickDetAmount <= @n_RequestAmount
         --   BEGIN
         --      UPDATE dbo.PickDetail WITH (ROWLOCK)
         --      SET DropId = @c_DropId
         --         ,[STATUS] = @c_FULLPick
         --      WHERE SKU = @c_SKU
         --      AND Orderkey = @c_Orderkey
         --      AND PickDetailKey = @c_PickDetailKey

         --      SET @n_RequestAmount = @n_RequestAmount - @n_PickDetAmount

         --      IF @@ERROR <> 0                                                                                             
         --      BEGIN
         --         ROLLBACK TRAN
         --         SET @n_ErrNo = 230401                                                                                      
         --         SET @c_ErrMsg = 'FAILD TO UPDATE PickDetail.QTY and PickDetail.DropId'
         --                        + '. (isp_WSITF_GeekPlusRBT_Order_Inbound)'    
         --      GOTO QUIT                                                                                          
         --      END  --IF @@ERROR <> 0
         --   END
         --   ELSE IF @n_PickDetAmount > @n_RequestAmount
         --   BEGIN

         --      SET @n_PickDetAmount = 0

         --      UPDATE dbo.PickDetail WITH (ROWLOCK)
         --      SET DropId = @c_DropId
         --         ,[STATUS] = @c_ShortPick
         --      WHERE SKU = @c_SKU
         --      AND Orderkey = @c_Orderkey
         --      --AND [STATUS] = @c_Status
         --      AND PickDetailKey = @c_PickDetailKey
               
         --      IF @@ERROR <> 0                                                                                             
         --      BEGIN
         --         ROLLBACK TRAN
         --         SET @n_ErrNo = 230401                                                                                      
         --         SET @c_ErrMsg = 'FAILD TO UPDATE PickDetail.QTY and PickDetail.DropId and PickDetail.Status'
         --                        + '. (isp_WSITF_GeekPlusRBT_Order_Inbound)'    
         --      GOTO QUIT                                                                                          
         --      END  --IF @@ERROR <> 0
         --   END

         --   FETCH NEXT FROM GEEKPLUS_ORDIN_Upd INTO @n_PickDetAmount, @c_Orderkey, @c_Status, @c_PickDetailKey
         --END
         --CLOSE GEEKPLUS_ORDIN_Upd  
         --DEALLOCATE GEEKPLUS_ORDIN_Upd  

         --WHILE @@TRANCOUNT > 0
         --      COMMIT TRAN

      END   --IF @c_OrderType = 'ORDER'

      --FETCH NEXT FROM GEEKPLUS_ORDIN_JSON INTO @c_OrderType, @c_RequestKey, @c_DropId, @c_SKU, @n_Amount 
      FETCH NEXT FROM GEEKPLUS_ORDIN_JSON INTO @c_OrderType
   END
   CLOSE GEEKPLUS_ORDIN_JSON  
   DEALLOCATE GEEKPLUS_ORDIN_JSON  

   --IF NOT EXISTS ( SELECT 1 FROM #TEMP_SelectedOrder WHERE ISNULL(RTRIM(pallet_code), '') <> '')
   --BEGIN
   --   SET @n_Continue = 3
   --   SET @n_ErrNo = 210001
   --   SET @c_ErrMsg = CONVERT(NVARCHAR, @n_ErrNo) + ' - must submit at least one pallet_code..'
   --   GOTO QUIT
   --END

   --IF @n_Continue = 1 OR @n_Continue = 2
   --BEGIN
   --   BEGIN TRAN
   --   -- Loop each pallet
   --   DECLARE GEEKPLUS_RECEIVEIN_PALLETLIST CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   --      SELECT pallet_code,  transaction_id, [status]
   --      FROM #TEMP_SelectedOrder
   --      WHERE ISNULL(RTRIM(pallet_code), '') <> ''
   --      GROUP BY pallet_code, transaction_id, [status]
   --   OPEN GEEKPLUS_RECEIVEIN_PALLETLIST
      
   --   FETCH NEXT FROM GEEKPLUS_RECEIVEIN_PALLETLIST INTO @c_pallet_code, @c_transaction_id, @c_status
   --   WHILE @@FETCH_STATUS <> -1
   --   BEGIN
   --      -- Loop each pallet's sku
   --      DECLARE GEEKPLUS_RECEIVEIN_SKULIST CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   --         SELECT sku_code, amount
   --         FROM #TEMP_SelectedOrder
   --         WHERE ISNULL(RTRIM(pallet_code), '') = @c_pallet_code
   --      OPEN GEEKPLUS_RECEIVEIN_SKULIST
         
   --      FETCH NEXT FROM GEEKPLUS_RECEIVEIN_SKULIST INTO @c_sku_code, @n_sku_receive_amount, @c_owner_code
   --      WHILE @@FETCH_STATUS <> -1
   --      BEGIN
   --         SELECT @c_StorerKey = '', @n_Exists = 0
   --         SELECT @n_Exists = (1), @c_StorerKey = Code
   --         FROM dbo.Codelkup WITH (NOLOCK)
   --         WHERE ListName = @c_ListName_ROBOTSTR
   --         AND Short = @c_owner_code

   --         IF @n_Exists = 0
   --         BEGIN
   --            SET @n_Continue = 3
   --            SET @n_ErrNo = 210002
   --            SET @c_ErrMsg = CONVERT(NVARCHAR, @n_ErrNo) + ' - cannot lookup storerkey with owner_code(' + @c_owner_code + ')..'
   --            GOTO QUIT
   --         END

   --         SELECT @n_Exists = 0, @c_Lot = '', @c_FromLoc = '', @n_CurrentLLIQTY = 0, @c_Facility = '', @c_FromLocPickZone = ''
   --         SELECT @n_Exists = (1)
   --              , @c_Lot = LLI.Lot
   --              , @c_FromLoc = LLI.Loc
   --              , @n_CurrentLLIQTY = LLI.Qty
   --              , @c_Facility = L.Facility
   --              , @c_FromLocPickZone = L.PickZone
   --         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   --         INNER JOIN dbo.Loc L WITH (NOLOCK) ON ( L.Loc = LLI.Loc AND L.LocationType = 'ROBOTSTG' )
   --         WHERE LLI.Id = @c_pallet_code 
   --         AND LLI.StorerKey = @c_StorerKey 
   --         AND LLI.SKU = @c_sku_code
   --         AND LLI.Qty > 0
            
   --         IF @n_Exists = 0
   --         BEGIN
   --            SET @n_Continue = 3
   --            SET @n_ErrNo = 210003
   --            SET @c_ErrMsg = CONVERT(NVARCHAR, @n_ErrNo) + ' - no LOTxLOCxID found Id(' + @c_pallet_code + ')..'
   --            GOTO QUIT
   --         END

   --         --Get ROBOT Location
   --         SELECT @c_ToRobotLoc = Loc
   --         FROM [dbo].[LOC] WITH (NOLOCK)
   --         WHERE Facility = @c_Facility
   --         AND LocationCategory='ROBOT' 
   --         AND LocationType='DYNPPICK'
   --         And PickZone = @c_FromLocPickZone

   --         IF ISNULL(RTRIM(@c_ToRobotLoc), '') = ''
   --         BEGIN
   --            SET @n_Continue = 3
   --            SET @n_ErrNo = 210004
   --            SET @c_ErrMsg = CONVERT(NVARCHAR, @n_ErrNo) + ' - Robot Location is not setup..'
   --            GOTO QUIT
   --         END

   --         SELECT @n_QtyNotReceived = 0, @n_QtyNotReceived = 0
   --         SET @n_QtyReceived = CASE WHEN (@n_sku_receive_amount >= @n_CurrentLLIQTY) THEN @n_CurrentLLIQTY
   --                              ELSE @n_sku_receive_amount END

   --         SET @n_QtyNotReceived = CASE WHEN (@n_sku_receive_amount >= @n_CurrentLLIQTY) THEN 0
   --                                 ELSE (@n_CurrentLLIQTY - @n_sku_receive_amount) END
            
   --         EXEC nspItrnAddMove
   --            @n_ItrnSysId      = NULL                                       
   --          , @c_StorerKey      = @c_StorerKey                         -- @c_StorerKey   
   --          , @c_Sku            = @c_sku_code                          -- @c_Sku         
   --          , @c_Lot            = @c_Lot                               -- @c_Lot         
   --          , @c_FromLoc        = @c_FromLoc                           -- @c_FromLoc     
   --          , @c_FromID         = @c_pallet_code                       -- @c_FromID      
   --          , @c_ToLoc          = @c_ToRobotLoc                        -- @c_ToLoc       
   --          , @c_ToID           = ''                                   -- @c_ToID        
   --          , @c_Status         = '0'                                  -- @c_Status      
   --          , @c_lottable01     = ''                                   -- @c_lottable01  
   --          , @c_lottable02     = ''                                   -- @c_lottable02  
   --          , @c_lottable03     = ''                                   -- @c_lottable03  
   --          , @d_lottable04     = NULL                                 -- @d_lottable04  
   --          , @d_lottable05     = NULL                                 -- @d_lottable05  
   --          , @c_lottable06     = ''                                   -- @c_lottable06  
   --          , @c_lottable07     = ''                                   -- @c_lottable07  
   --          , @c_lottable08     = ''                                   -- @c_lottable08  
   --          , @c_lottable09     = ''                                   -- @c_lottable09  
   --          , @c_lottable10     = ''                                   -- @c_lottable10  
   --          , @c_lottable11     = ''                                   -- @c_lottable11  
   --          , @c_lottable12     = ''                                   -- @c_lottable12  
   --          , @d_lottable13     = NULL                                 -- @d_lottable13  
   --          , @d_lottable14     = NULL                                 -- @d_lottable14  
   --          , @d_lottable15     = NULL                                 -- @d_lottable15  
   --          , @n_casecnt        = 0                                    -- @n_casecnt     
   --          , @n_innerpack      = 0                                    -- @n_innerpack   
   --          , @n_qty            = @n_QtyReceived                       -- @n_qty         
   --          , @n_pallet         = 0                                    -- @n_pallet      
   --          , @f_cube           = 0                                    -- @f_cube        
   --          , @f_grosswgt       = 0                                    -- @f_grosswgt    
   --          , @f_netwgt         = 0                                    -- @f_netwgt      
   --          , @f_otherunit1     = 0                                    -- @f_otherunit1  
   --          , @f_otherunit2     = 0                                    -- @f_otherunit2  
   --          , @c_SourceKey      = @c_transaction_id                    -- @c_SourceKey
   --          , @c_SourceType     = 'Robot Geek+ RECEIVING IN Move'      -- @c_SourceType
   --          , @c_PackKey        = ''                                   -- @c_PackKey     
   --          , @c_UOM            = ''                                   -- @c_UOM         
   --          , @b_UOMCalc        = 0                                    -- @b_UOMCalc     
   --          , @d_EffectiveDate  = NULL                                 -- @d_EffectiveD  
   --          , @c_itrnkey        = ''                                   -- @c_itrnkey     
   --          , @b_Success        = @b_Success   OUTPUT                  -- @b_Success   
   --          , @n_ErrNo            = @n_ErrNo     OUTPUT                -- @n_ErrNo       
   --          , @c_errmsg         = @c_ErrMsg    OUTPUT                  -- @c_errmsg    
   --          , @c_MoveRefKey     = ''                                   -- @c_MoveRefKey  
            
   --         IF @b_Success <> 1
   --         BEGIN
   --            SET @n_Continue = 3
   --            SET @n_ErrNo = 210005
   --            SET @c_ErrMsg = 'Failed to move inventory to ROBOT Location..'
   --            GOTO QUIT
   --         END

   --         -- Move all receive amount to robot location
   --         IF @n_QtyNotReceived > 0
   --         BEGIN
   --            --Get ROBOT HOLD Location
   --            SELECT @c_ToRobotHOLDLoc = Loc
   --            FROM [dbo].[LOC] WITH (NOLOCK)
   --            WHERE Facility = @c_Facility
   --            AND LocationCategory='ROBOT' 
   --            AND LocationType='ROBOTHOLD'
   --            AND PickZone = @c_FromLocPickZone

   --            IF ISNULL(RTRIM(@c_ToRobotHOLDLoc), '') = ''
   --            BEGIN
   --               SET @n_Continue = 3
   --               SET @n_ErrNo = 210006
   --               SET @c_ErrMsg = CONVERT(NVARCHAR, @n_ErrNo) + ' - Robot HOLD Location is not setup..'
   --               GOTO QUIT
   --            END

   --            --Move received amount to ROBOT LOC
   --            EXEC nspItrnAddMove
   --               @n_ItrnSysId      = NULL                                       
   --             , @c_StorerKey      = @c_StorerKey                         -- @c_StorerKey   
   --             , @c_Sku            = @c_sku_code                          -- @c_Sku         
   --             , @c_Lot            = @c_Lot                               -- @c_Lot         
   --             , @c_FromLoc        = @c_FromLoc                           -- @c_FromLoc     
   --             , @c_FromID         = @c_pallet_code                       -- @c_FromID      
   --             , @c_ToLoc          = @c_ToRobotHOLDLoc                    -- @c_ToLoc       
   --             , @c_ToID           = @c_pallet_code                       -- @c_ToID        
   --             , @c_Status         = '0'                                  -- @c_Status      
   --             , @c_lottable01     = ''                                   -- @c_lottable01  
   --             , @c_lottable02     = ''                                   -- @c_lottable02  
   --             , @c_lottable03     = ''                                   -- @c_lottable03  
   --             , @d_lottable04     = NULL                                 -- @d_lottable04  
   --             , @d_lottable05     = NULL                                 -- @d_lottable05  
   --             , @c_lottable06     = ''                                   -- @c_lottable06  
   --             , @c_lottable07     = ''                                   -- @c_lottable07  
   --             , @c_lottable08     = ''                                   -- @c_lottable08  
   --             , @c_lottable09     = ''                                   -- @c_lottable09  
   --             , @c_lottable10     = ''                                   -- @c_lottable10  
   --             , @c_lottable11     = ''                                   -- @c_lottable11  
   --             , @c_lottable12     = ''                                   -- @c_lottable12  
   --             , @d_lottable13     = NULL                                 -- @d_lottable13  
   --             , @d_lottable14     = NULL                                 -- @d_lottable14  
   --             , @d_lottable15     = NULL                                 -- @d_lottable15  
   --             , @n_casecnt        = 0                                    -- @n_casecnt     
   --             , @n_innerpack      = 0                                    -- @n_innerpack   
   --             , @n_qty            = @n_QtyNotReceived                    -- @n_qty         
   --             , @n_pallet         = 0                                    -- @n_pallet      
   --             , @f_cube           = 0                                    -- @f_cube        
   --             , @f_grosswgt       = 0                                    -- @f_grosswgt    
   --             , @f_netwgt         = 0                                    -- @f_netwgt      
   --             , @f_otherunit1     = 0                                    -- @f_otherunit1  
   --             , @f_otherunit2     = 0                                    -- @f_otherunit2  
   --             , @c_SourceKey      = @c_transaction_id                    -- @c_SourceKey
   --             , @c_SourceType     = 'Robot Geek+ RECEIVING IN Move'      -- @c_SourceType
   --             , @c_PackKey        = ''                                   -- @c_PackKey     
   --             , @c_UOM            = ''                                   -- @c_UOM         
   --             , @b_UOMCalc        = 0                                    -- @b_UOMCalc     
   --             , @d_EffectiveDate  = NULL                                 -- @d_EffectiveD  
   --             , @c_itrnkey        = ''                                   -- @c_itrnkey     
   --             , @b_Success        = @b_Success   OUTPUT                  -- @b_Success   
   --             , @n_ErrNo            = @n_ErrNo     OUTPUT                  -- @n_ErrNo       
   --             , @c_errmsg         = @c_ErrMsg    OUTPUT                  -- @c_errmsg    
   --             , @c_MoveRefKey     = ''                                   -- @c_MoveRefKey  
               
   --            IF @b_Success <> 1
   --            BEGIN
   --               SET @n_Continue = 3
   --               SET @n_ErrNo = 210007
   --               SET @c_ErrMsg = 'Failed to move inventory to ROBOT HOLD Location..'
   --               GOTO QUIT
   --            END
   --         END --IF @n_QtyNotReceived > 0

   --         FETCH NEXT FROM GEEKPLUS_RECEIVEIN_SKULIST INTO @c_sku_code, @n_sku_receive_amount, @c_owner_code
   --      END
   --      CLOSE GEEKPLUS_RECEIVEIN_SKULIST
   --      DEALLOCATE GEEKPLUS_RECEIVEIN_SKULIST

   --      FETCH NEXT FROM GEEKPLUS_RECEIVEIN_PALLETLIST INTO @c_pallet_code, @c_status
   --   END
   --   CLOSE GEEKPLUS_RECEIVEIN_PALLETLIST
   --   DEALLOCATE GEEKPLUS_RECEIVEIN_PALLETLIST
   --END
   
   QUIT:

   --WHILE @@TRANCOUNT > 0
   --   COMMIT TRAN

   IF CURSOR_STATUS('LOCAL' , 'GEEKPLUS_ORDIN_Upd') in (0 , 1)  
   BEGIN  
      CLOSE GEEKPLUS_ORDIN_Upd  
      DEALLOCATE GEEKPLUS_ORDIN_Upd  
   END

   IF CURSOR_STATUS('LOCAL' , 'GEEKPLUS_ORDIN_JSON') in (0 , 1)  
   BEGIN  
      CLOSE GEEKPLUS_ORDIN_JSON  
      DEALLOCATE GEEKPLUS_ORDIN_JSON  
   END

   IF @n_Continue = 3 AND @n_ErrNo <> 0
   BEGIN
      --SET @b_Success = 0      
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
      --RETURN      
   END      
   ELSE      
   BEGIN      
      --SELECT @b_Success = 1      
      WHILE @@TRANCOUNT > @n_StartCnt      
      BEGIN      
         COMMIT TRAN      
      END      
      --RETURN      
   END

   SET @c_ResponseString = ISNULL(RTRIM(
      (
         SELECT 
            CASE WHEN @n_ErrNo > 0 THEN '400' ELSE '200' END As 'header.msgCode'
          , CASE WHEN @n_ErrNo > 0 THEN 'Error : ' + @c_ErrMsg 
               ELSE N'Process with Success' END As 'header.message'
          , CONVERT(BIT, CASE WHEN @n_ErrNo > 0 THEN 0 ELSE 1 END) As 'body.success'
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
      )
   ), '')

   --Insert log to TCPSocket_INLog
   INSERT INTO dbo.TCPSOCKET_INLOG ( [Application], MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] )
   VALUES ( @c_Application, @c_MessageType, @c_MessageType, @c_RequestString, '', @c_StorerKey, @c_ResponseString, '9' )

   --Build Custom Response
   SELECT @n_ErrNo = 0, @b_Success = 1, @c_ErrMsg = ''
   RETURN
END -- Procedure  

GO