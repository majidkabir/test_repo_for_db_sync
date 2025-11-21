SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/              
/* Store procedure: isp_WSITF_GeekPlusRBT_Order_Inbound_Batch           */              
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
/************************************************************************/    
CREATE PROC [dbo].[isp_WSITF_GeekPlusRBT_Order_Inbound_Batch](
     @b_Debug                 INT
   , @c_OrderType             NVARCHAR(32)
   , @c_RequestString         NVARCHAR(MAX)  
   , @b_Success               INT            = 0   OUTPUT
   , @n_ErrNo                 INT            = 0   OUTPUT
   , @c_ErrMsg                NVARCHAR(250)  = ''  OUTPUT
   , @c_ResponseString        NVARCHAR(MAX)  = ''  OUTPUT


   --  @b_Debug           INT            = 0
   --, @n_OrderAmount     INT
   --, @c_OrderType       NVARCHAR(32)
   --, @c_RequestKey      NVARCHAR(32)
   --, @c_DropId          NVARCHAR(32)
   --, @c_SKU             NVARCHAR(32)
   --, @n_RequestAmount   INT
   --, @c_RequestString   NVARCHAR(MAX)  = ''
   --, @b_Success         INT            = 0   OUTPUT
   --, @n_ErrNo           INT            = 0   OUTPUT
   --, @c_ErrMsg          NVARCHAR(250)  = ''  OUTPUT
   --, @c_ResponseString  NVARCHAR(MAX)  = ''  OUTPUT
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

   DECLARE --@c_OrderType                   NVARCHAR(32)
           @c_RequestKey                  NVARCHAR(32)
         , @c_DropId                      NVARCHAR(32)
         , @c_SKU                         NVARCHAR(32)
         , @n_Amount                      INT
         , @n_PickDetAmount               INT
         , @c_Orderkey                    NVARCHAR(20)
         , @c_PickDetailKey               NVARCHAR(10)
         , @n_RequestAmount               INT
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
   
   SET @c_Application                     = 'GEEK+_ORDER_RESPONSE_IN_BATCHTYPE'
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

   --SET @c_OrderType                       = ''
   SET @c_RequestKey                         = ''
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
   --   pallet_code       NVARCHAR(18),
   --   transaction_id    NVARCHAR(32),
   --   sku_code          NVARCHAR(20),
   --   [status]          NVARCHAR(5),
   --   owner_code        NVARCHAR(16),
   --   amount            INT
   --)

   --INSERT INTO #TEMP_SelectedOrder ( pallet_code, transaction_id, sku_code, [status], owner_code, amount )

   DECLARE GEEKPLUS_ORDIN_JSON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT order_list.revervation1, LSKU.out_order_code, LSKU.container_code, LSKU.sku_code, LSKU.amount
   FROM OPENJSON(@c_RequestString, '$.body')
   WITH (
      order_amount         NVARCHAR(50)      '$.order_amount',
      [order_list]         NVARCHAR(MAX) As JSON-- '$.order_list'
   ) As body_List
   CROSS APPLY   
   OPENJSON(body_List.order_list)
   WITH (
      revervation1         NVARCHAR(50)      '$.revervation1',
      [container_list]     NVARCHAR(MAX) As JSON,-- '$.sku_list'
      [sku_list]           NVARCHAR(MAX) As JSON-- '$.sku_list'
   ) As order_list
   CROSS APPLY 
   OPENJSON (order_list.container_list)
   with
   (
      [sku_list]     NVARCHAR(MAX) As JSON-- '$.sku_list'
   ) as container_list
    CROSS APPLY 
   OPENJSON (container_list.sku_list)
   with
   (
      out_order_code       NVARCHAR(32)      '$.out_order_code',
      container_code       NVARCHAR(32)      '$.container_code',
      sku_code             NVARCHAR(32)      '$.sku_code',
      amount               INT               '$.amount'
   ) as LSKU WHERE order_list.revervation1 = @c_OrderType

   OPEN GEEKPLUS_ORDIN_JSON
   FETCH NEXT FROM GEEKPLUS_ORDIN_JSON INTO @c_OrderType, @c_RequestKey, @c_DropId, @c_SKU, @n_Amount
   WHILE @@FETCH_STATUS = 0 
   BEGIN
      SET @n_RequestAmount = @n_Amount

      --BEGIN TRAN

      DECLARE GEEKPLUS_ORDIN_Upd CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      --SUM Amount based on orderey using loadkey
      SELECT QTY
            , OrderKey  
            , [STATUS]
            , PickDetailKey
            , Loc
      FROM PickDetail WITH (NOLOCK) 
      WHERE OrderKey IN (SELECT OrderKey 
                           FROM PackTask WITH (NOLOCK) 
                           WHERE TaskBatchNo = @c_RequestKey)
      AND [STATUS] = '0'
      AND LOC IN (SELECT LOC FROM Loc WITH (NOLOCK) WHERE LocationCategory = 'ROBOT')
      AND SKU = @c_SKU

      OPEN GEEKPLUS_ORDIN_Upd  
      FETCH NEXT FROM GEEKPLUS_ORDIN_Upd INTO @n_PickDetAmount, @c_Orderkey, @c_Status, @c_PickDetailKey, @c_PickLoc
      WHILE @@FETCH_STATUS = 0 
      BEGIN
            
      --when Qty more than ROBOT Request (Update Qty, DropId using SKU, OrderKey, Status, PickDetailKey)
      IF @n_PickDetAmount <= @n_RequestAmount
      BEGIN
         UPDATE dbo.PickDetail WITH (ROWLOCK)
         SET DropId = @c_DropId
            ,[STATUS] = @c_FULLPick
         WHERE SKU = @c_SKU
         AND Orderkey = @c_Orderkey
         AND PickDetailKey = @c_PickDetailKey
         AND LOC = @c_PickLoc


         IF @@ERROR <> 0                                                                                             
         BEGIN
            ROLLBACK TRAN
            SET @n_ErrNo = 230401                                                                                      
            SET @c_ErrMsg = 'FAILD TO UPDATE PickDetail.QTY and PickDetail.DropId and PickDetail.Status'
                           + '. (isp_WSITF_GeekPlusRBT_Order_Inbound_Batch)'    
         GOTO QUIT                                                                                          
         END  --IF @@ERROR <> 0
      END
      --when Qty less than ROBOT Request
      ELSE IF @n_PickDetAmount > @n_RequestAmount AND @n_RequestAmount > 0
      BEGIN      
               
         --Update first record with ROBOT remaining amount
         UPDATE dbo.PickDetail WITH (ROWLOCK)
         SET QTY = @n_RequestAmount
            , DropId = @c_DropId
            ,[STATUS] = @c_FULLPick
            ,TrafficCop = NULL --KCY01
            ,EditDate = GETDATE() --KCY01
            ,EditWho  = SUSER_SNAME() --KCY01
         WHERE SKU = @c_SKU
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
            SET @n_ErrNo = 230401                                                                       
            SET @c_ErrMsg = 'FAILD TO GET PickDetail KEY'
                           + '. (isp_WSITF_GeekPlusRBT_Order_Inbound_Batch)'    
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
            @n_PickDetAmount - @n_RequestAmount , -- QTY
            NULL, -- TrafficCop
            '1'   -- OptimizeCop
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE SKU = @c_SKU
         AND Orderkey = @c_Orderkey
         AND PickDetailKey = @c_PickDetailKey
         AND LOC = @c_PickLoc
         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @n_ErrNo = 230401                                                                       
            SET @c_ErrMsg = 'FAILD TO SPLIT PickDetail RECORD'
                           + '. (isp_WSITF_GeekPlusRBT_Order_Inbound_Batch)'   
         END
                    
      END

      SET @n_RequestAmount = @n_RequestAmount - @n_PickDetAmount

      FETCH NEXT FROM GEEKPLUS_ORDIN_Upd INTO @n_PickDetAmount, @c_Orderkey, @c_Status, @c_PickDetailKey, @c_PickLoc
      END
      CLOSE GEEKPLUS_ORDIN_Upd  
      DEALLOCATE GEEKPLUS_ORDIN_Upd  

      --WHILE @@TRANCOUNT > 0
      --         COMMIT TRAN

     FETCH NEXT FROM GEEKPLUS_ORDIN_JSON INTO @c_OrderType, @c_RequestKey, @c_DropId, @c_SKU, @n_Amount
   END
   CLOSE GEEKPLUS_ORDIN_JSON  
   DEALLOCATE GEEKPLUS_ORDIN_JSON  

   IF CURSOR_STATUS('LOCAL' , 'GEEKPLUS_ORDIN_JSON') in (0 , 1)  
   BEGIN  
      CLOSE GEEKPLUS_ORDIN_JSON  
      DEALLOCATE GEEKPLUS_ORDIN_JSON  
   END

   --Update Remaing PickDetail to ShortPick
   DECLARE GEEKPLUS_ORDIN_JSON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT LSKU.out_order_code, LSKU.container_code, LSKU.sku_code
   FROM OPENJSON(@c_RequestString, '$.body')
   WITH (
      order_amount         NVARCHAR(50)      '$.order_amount',
      [order_list]         NVARCHAR(MAX) As JSON-- '$.order_list'
   ) As body_List
   CROSS APPLY   
   OPENJSON(body_List.order_list)
   WITH (
      revervation1         NVARCHAR(50)      '$.revervation1',
      [container_list]     NVARCHAR(MAX) As JSON,-- '$.sku_list'
      [sku_list]           NVARCHAR(MAX) As JSON-- '$.sku_list'
   ) As order_list
   CROSS APPLY 
   OPENJSON (order_list.container_list)
   with
   (
      [sku_list]     NVARCHAR(MAX) As JSON-- '$.sku_list'
   ) as container_list
    CROSS APPLY 
   OPENJSON (container_list.sku_list)
   with
   (
      out_order_code       NVARCHAR(32)      '$.out_order_code',
      container_code       NVARCHAR(32)      '$.container_code',
      sku_code             NVARCHAR(32)      '$.sku_code',
      amount               INT               '$.amount'
   ) as LSKU WHERE order_list.revervation1 = @c_OrderType

   OPEN GEEKPLUS_ORDIN_JSON
   FETCH NEXT FROM GEEKPLUS_ORDIN_JSON INTO @c_RequestKey, @c_DropId, @c_SKU
   WHILE @@FETCH_STATUS = 0 
   BEGIN

      DECLARE GEEKPLUS_ORDIN_Upd_Remain CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      --SUM Amount based on orderey using loadkey
      SELECT OrderKey  
            , [STATUS]
            , PickDetailKey
            , Loc
      FROM PickDetail WITH (NOLOCK) 
      WHERE OrderKey IN (SELECT OrderKey 
                           FROM PackTask WITH (NOLOCK) 
                           WHERE TaskBatchNo = @c_RequestKey)
      AND [STATUS] = '0'
      AND LOC IN (SELECT LOC FROM Loc WITH (NOLOCK) WHERE LocationCategory = 'ROBOT')
      AND SKU = @c_SKU

      OPEN GEEKPLUS_ORDIN_Upd_Remain  
      FETCH NEXT FROM GEEKPLUS_ORDIN_Upd_Remain INTO @c_Orderkey, @c_Status, @c_PickDetailKey, @c_PickLoc
      WHILE @@FETCH_STATUS = 0 
      BEGIN
         --Update remaining Orderkey
         UPDATE dbo.PickDetail WITH (ROWLOCK)
         SET DropId = @c_DropId
            ,[STATUS] = @c_ShortPick
         WHERE PickDetailKey = @c_PickDetailKey
         AND Orderkey = @c_Orderkey
         AND SKU = @c_SKU
         AND LOC = @c_PickLoc
         AND [Status] = @c_Status

         FETCH NEXT FROM GEEKPLUS_ORDIN_Upd_Remain INTO @c_Orderkey, @c_Status, @c_PickDetailKey, @c_PickLoc
      END
      CLOSE GEEKPLUS_ORDIN_Upd_Remain  
      DEALLOCATE GEEKPLUS_ORDIN_Upd_Remain 

      FETCH NEXT FROM GEEKPLUS_ORDIN_JSON INTO @c_RequestKey, @c_DropId, @c_SKU
   END
   CLOSE GEEKPLUS_ORDIN_JSON  
   DEALLOCATE GEEKPLUS_ORDIN_JSON   
         
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

   ----Insert log to TCPSocket_INLog
   --INSERT INTO dbo.TCPSOCKET_INLOG ( [Application], MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] )
   --VALUES ( @c_Application, @c_MessageType, @c_ErrMsg, @c_RequestString, '', @c_StorerKey, @c_ResponseString, '9' )

   --Build Custom Response
   SELECT @n_ErrNo = 0, @b_Success = 1, @c_ErrMsg = ''
   RETURN
END -- Procedure  

GO