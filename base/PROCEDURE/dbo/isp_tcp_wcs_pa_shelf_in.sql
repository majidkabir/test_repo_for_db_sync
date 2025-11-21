SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure:  isp_TCP_WCS_PA_SHELF_IN                            */  
/* Creation Date: 05-Jul-2010                                           */  
/* Copyright: IDS                                                       */  
/* Written by: MCTang                                                   */  
/*                                                                      */  
/* Purpose: Residual  Move                                              */  
/*          RedWerks to WMS Exceed                                      */  
/*                                                                      */  
/* Input Parameters:  @c_MessageNum    - Unique no for Incoming data    */  
/*                                                                      */  
/* Output Parameters: @b_Success       - Success Flag  = 0              */  
/*                    @n_Err           - Error Code    = 0              */  
/*                    @c_ErrMsg        - Error Message = ''             */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 21-01-2012   ChewKP    1.1   Bug Fixes (ChewKP01)                    */  
/* 05-04-2012   James     1.2   Check if LOC exists (james01)           */  
/* 16-04-2012   Shong     1.3   Update WCS_ResidualMoveLog When PU      */  
/* 17-04-2012   Shong     1.4   Cater Residual Qty Move To WCS01        */  
/* 18-06-2012   Shong     1.5   Cater for Last Carton Scenario          */  
/* 29-06-2012   ChewKP    1.6   Update Status = '1' before process      */  
/*                              (ChewKP02)                              */  
/* 23-07-2012   ChewKP    1.7   SOS#250950 - CC Task CommingleSKU being */  
/*                              put to Location (ChewKP03)              */  
/* 02-08-2012   Shong     1.8   Cater for Phase 1 Pickdetail/RefKeylk   */  
/* 07-09-2012   Leong     1.9   SOS# 255550 - Insert RefKeyLookUp with  */  
/*                              EditWho                                 */  
/* 18-10-2012   Leong     1.9   SOS# 258940 - Add TraceInfo for ItrnMove*/  
/* 15-10-2012   Shong     2.0   Update WCS_ResidualMoveLog For Last     */
/*                              Carton                                  */ 
/* 05-10-2013   Shong     2.1   Change Declare Cursor to LOCAL          */
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_TCP_WCS_PA_SHELF_IN]  
     @c_MessageNum NVARCHAR(10)  
   , @b_debug      INT  
   , @b_Success    INT        OUTPUT  
   , @n_Err        INT        OUTPUT  
   , @c_ErrMsg     NVARCHAR(250)  OUTPUT  
  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @c_ExecStatements     NVARCHAR(4000)  
         , @c_ExecArguments      NVARCHAR(4000)  
         , @n_Continue           INT  
         , @n_StartTCnt          INT  
  
   DECLARE @n_SerialNo           INT  
         , @c_Status             NVARCHAR(1)  
         , @c_ListName           NVARCHAR(10)  
         , @c_CodelkupCode       NVARCHAR(30)  
  
         , @c_DataString         NVARCHAR(4000)  
         , @c_InMsgType          NVARCHAR(15)  
         , @c_StorerKey          NVARCHAR(15)  
         , @c_Facility           NVARCHAR(5)  
         , @c_SKU                NVARCHAR(20)  
         , @n_Qty_Expected       INT  
         , @n_Qty_Actual         INT  
         , @c_PutawayLoc         NVARCHAR(10)  
         , @c_TXCODE             NVARCHAR(5)  
  
         , @n_FromQtyToTake      INT  
         , @c_FromLoc            NVARCHAR(10)  
         , @c_FromLot            NVARCHAR(10)  
         , @c_FromID             NVARCHAR(18)  
         , @n_FromQty            INT  
         , @n_AvailableQty       INT  
         , @c_PackKey            NVARCHAR(10)  
         , @c_UOM                NVARCHAR(10)  
  
         , @n_RSSerialNo         INT  
         , @c_LOC                NVARCHAR(10)  
         , @n_OutStdQty          INT  
         , @n_TotPutawayQty      INT  
         , @n_PutawayQty         INT  
  
         , @n_NonReleaseQtyAlloc       INT  
         , @c_PickDetailKey            NVARCHAR(10)  
         , @c_LOT                      NVARCHAR(10)  
         , @n_PickDetQty               INT  
         , @n_UnAllocateQty            INT  
         , @n_TotUnAllocateQty         INT  
         , @c_OrderKey                 NVARCHAR(10)  
         , @c_OrderLineNumber          NVARCHAR(5)  
         , @c_PreAllocatePickDetailKey NVARCHAR(10)  
         , @n_Cnt                      INT  
         , @n_QtyToAllocate            INT  
         , @c_LoadKey                  NVARCHAR(10)  
         , @c_PickSlipNo               NVARCHAR(20)  
         , @c_Runkey                   NVARCHAR(10)  
         , @c_ToSKU                    NVARCHAR(20) -- (ChewKP03)  
         , @c_LogicalLocation          NVARCHAR(10) -- (ChewKP03)  
         , @c_AreaKey                  NVARCHAR(10) -- (ChewKP03)  
         , @c_TaskDetailKey            NVARCHAR(10) -- (ChewKP03)  
         , @c_CCKey                    NVARCHAR(10)    -- (ChewKP03)  
         , @c_AlertMessage             NVARCHAR( 255)  -- (ChewKP03)  
         , @c_ModuleName               NVARCHAR(30)    -- (ChewKP03)  
  

	DECLARE @n_TotQtyToMove INT 
	      , @n_QtyToMove    INT 
	      , @n_RMvLogSerNo  INT
         	        
   DECLARE @c_TraceFlag               NVARCHAR(1)  
   SET @c_TraceFlag = '1' -- 1 - turn on; 0 - turn off  
  
   DECLARE @c_NewLineChar NVARCHAR(2)  
   SET @c_NewLineChar =  CHAR(13) + CHAR(10) -- (ChewKP01)  
  
   SELECT @n_Continue = 1, @b_Success = 1, @n_Err = 0  
  
   SET @n_StartTCnt = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN WCS_BULK_PICK  
  
   SET @c_ListName         = 'WCSROUTE'  
   SET @c_CodelkupCode     = 'CASE'  
   SET @c_ErrMsg           = ''  
   SET @c_Status           = '9'  
  
   SET @n_SerialNo         = 0  
   SET @c_DataString       = ''  
   SET @c_InMsgType        = ''  
   SET @c_StorerKey        = ''  
   SET @c_Facility         = ''  
   SET @c_SKU              = ''  
   SET @n_Qty_Expected     = 0  
   SET @n_Qty_Actual       = 0  
   SET @c_PutawayLoc       = ''  
   SET @c_TXCODE           = ''  
  
   SET @n_FromQtyToTake    = 0  
   SET @c_FromLoc          = ''  
   SET @c_FromLot          = ''  
   SET @c_FromID           = ''  
   SET @n_FromQty          = 0  
   SET @n_AvailableQty     = 0  
   SET @c_PackKey          = ''  
   SET @c_UOM              = ''  
  
   SET @c_ToSKU                   = '' -- (ChewKP03)  
   SET @c_LogicalLocation         = '' -- (ChewKP03)  
   SET @c_AreaKey                 = '' -- (ChewKP03)  
   SET @c_TaskDetailKey           = '' -- (ChewKP03)  
   SET @c_CCKey                   = '' -- (ChewKP03)  
   SET @c_AlertMessage            = '' -- (ChewKP03)  
   SET @c_ModuleName              = '' -- (ChewKP03)  
  
   SELECT @n_SerialNo   = SerialNo  
        , @c_DataString = ISNULL(RTRIM(DATA), '')  
   FROM   dbo.TCPSocket_INLog WITH (NOLOCK)  
   WHERE  MessageNum    = @c_MessageNum  
   AND    MessageType   = 'RECEIVE'  
   AND    Status        = '0'  
  
   IF ISNULL(RTRIM(@n_SerialNo),'') = ''  
   BEGIN  
      IF @b_debug = 1  
      BEGIN  
         SELECT 'Nothing to process. MessageNo = ' + @c_MessageNum  
      END  
      RETURN  
   END  
  
   IF @b_debug = 1  
   BEGIN  
      SELECT '@n_SerialNo : ' + CONVERT(NVARCHAR, @n_SerialNo)  
           + ', @c_Status : ' + @c_Status  
           + ', @c_DataString : ' + @c_DataString  
   END  
  
   -- (ChewKP02)  
   UPDATE dbo.TCPSOCKET_INLOG WITH (ROWLOCK)  
   SET Status = '1'  
   WHERE SerialNo = @n_SerialNo  
  
   IF ISNULL(RTRIM(@c_DataString),'') = ''  
   BEGIN  
      SET @n_Continue = 3  
      SET @c_Status = '5'  
      SET @c_ErrMsg = 'Data String is empty. Seq#: ' + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
      GOTO QUIT_SP  
   END  
  
   SELECT @c_InMsgType        = MessageType  
        , @c_StorerKey        = StorerKey  
        , @c_Facility         = Facility  
        , @c_SKU              = SKU  
        , @n_Qty_Expected     = Qty_Expected  
        , @n_Qty_Actual       = Qty_Actual  
        , @c_PutawayLoc       = PutawayLOC  
        , @c_TXCODE           = TransCode  
   FROM fnc_GetTCPPASHELF( @n_SerialNo )  
  
   IF @b_debug = 1  
   BEGIN  
      SELECT '@c_InMsgType : '      + @c_InMsgType  
           + ', @c_StorerKey : '    + @c_StorerKey  
           + ', @c_Facility : '     + @c_Facility  
           + ', @c_SKU : '          + @c_SKU  
           + ', @n_Qty_Expected : ' + CONVERT(NVARCHAR, @n_Qty_Expected)  
           + ', @n_Qty_Actual : '   + CONVERT(NVARCHAR, @n_Qty_Actual)  
           + ', @c_PutawayLoc : '   + @c_PutawayLoc  
           + ', @c_TXCODE : '       + @c_TXCODE  
   END  
  
   IF ISNULL(RTRIM(@c_InMsgType),'') <> 'RESIDUALMV'  
   BEGIN  
      SET @n_Continue = 3  
      SET @c_Status = '5'  
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Invalid MessageType:' + ISNULL(RTRIM(@c_InMsgType), '') + ' for process. Seq#: '  
                    + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
      GOTO QUIT_SP  
   END  
  
   IF ISNULL(RTRIM(@c_StorerKey),'') = ''  
   BEGIN  
      SET @n_Continue = 3  
      SET @c_Status = '5'  
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. StorerKey is empty. Seq#: '  
                    + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
      GOTO QUIT_SP  
   END  
  
   IF ISNULL(RTRIM(@c_SKU),'') = ''  
   BEGIN  
      SET @n_Continue = 3  
      SET @c_Status = '5'  
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Sku is empty. Seq#: '  
                    + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
      GOTO QUIT_SP  
   END  
  
   IF ISNULL(RTRIM(@c_PutawayLoc),'') = ''  
   BEGIN  
      SET @n_Continue = 3  
      SET @c_Status = '5'  
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. PutawayLOC is empty. Seq#: '  
                    + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
      GOTO QUIT_SP  
   END  
  
   -- (james01)  
   IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)  
                  WHERE LOC = @c_PutawayLoc  
                  AND Facility = @c_Facility)  
   BEGIN  
      SET @n_Continue = 3  
      SET @c_Status = '5'  
      SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. PutawayLOC NOT exists. Seq#: '  
                    + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
      GOTO QUIT_SP  
   END  
  
   -- (ChewKP03) If it is > 1 SKU in Location create Alert and Generate TM CC Task  
   IF ISNULL(RTRIM(@c_TXCODE), '') = 'PTWY'  
   BEGIN  
      IF EXISTS (SELECT 1 FROM dbo.LOC LOC WITH (NOLOCK)  
                 WHERE LOC.LOC = @c_PutawayLoc  
                 AND   LOC.CommingleSKU = '0')  
      BEGIN  
         SET @c_ToSKU = ''  
  
         SELECT DISTINCT @c_ToSKU = LLI.SKU  
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
           INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.Storerkey AND LLI.SKU = SKU.SKU)  
           INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
         WHERE LLI.StorerKey = @c_StorerKey  
           AND LLI.LOC = @c_PutawayLoc  
           GROUP BY LLI.Storerkey, LLI.SKU  
           HAVING SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0  
  
         IF ISNULL(RTRIM(@c_ToSKU),'') <> ''  
         BEGIN  
            IF ISNULL(RTRIM(@c_ToSKU),'') <> @c_SKU  
            BEGIN  
               ------------ Create task for cycle count   ---------------------------  
               -- Create Cycle Count Task  
               SET @b_Success = 1  
  
               EXECUTE dbo.nspg_getkey  
                  'TaskDetailKey'  
                  , 10  
                  , @c_TaskDetailKey OUTPUT  
                  , @b_Success OUTPUT  
                  , @n_Err     OUTPUT  
                  , @c_ErrMsg  OUTPUT  
  
               IF @b_Success <> 1  
               BEGIN  
                  SET @n_Continue = 3  
                  SET @c_Status = '5'  
                  SET @c_ErrMsg = 'Get TaskDetailKey Key Failed (isp_TCP_WCS_PA_SHELF_IN).'  
                  GOTO QUIT_SP  
               END  
  
               -- (ChewKP12)  
               EXECUTE nspg_getkey  
                  'CCKey'  
                  , 10  
                  , @c_CCKey OUTPUT  
                  , @b_success OUTPUT  
                  , @n_Err OUTPUT  
                  , @c_Errmsg OUTPUT  
  
               IF NOT @b_success = 1  
               BEGIN  
                  SET @n_Continue = 3  
                  SET @c_Status = '5'  
                  SET @c_ErrMsg = 'GetKey Failed (isp_TCP_WCS_PA_SHELF_IN).'  
                  GOTO QUIT_SP  
               END  
  
               SET @c_LogicalLocation = ''  
               SET @c_AreaKey = ''  
  
               SELECT TOP 1  
                      @c_LogicalLocation = LogicalLocation,  
                      @c_AreaKey         = ISNULL(ad.AreaKey, '')  
               FROM   LOC WITH (NOLOCK)  
               LEFT OUTER JOIN AreaDetail ad WITH (NOLOCK) ON ad.PutawayZone = LOC.PutawayZone  
               WHERE  LOC = @c_PutawayLoc  
  
               -- If NOT outstanding cycle count task, then insert new cycle count task  
               IF NOT EXISTS(SELECT 1 FROM TaskDetail td WITH (NOLOCK)  
                             WHERE td.TaskType = 'CC'  
                             AND td.FromLoc = @c_PutawayLoc  
                             AND td.[Status] IN ('0','3')  
                             AND td.Storerkey = @c_StorerKey  
                             AND td.Sku = @c_SKU)  
               BEGIN  
                  INSERT INTO dbo.TaskDetail  
                     (TaskDetailKey,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,Qty,FromLoc,LogicalFromLoc  
                     ,FromID,ToLoc,LogicalToLoc,ToID,Caseid,PickMethod,Status,StatusMsg  
                     ,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide  
                     ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber  
                     ,ListKey,WaveKey,ReasonKey,Message01,Message02,Message03,RefTaskKey,LoadKey  
                     ,AreaKey,DropID, SystemQty)  
                  VALUES  
                     (@c_TaskDetailKey  
                     ,'CC' -- TaskType  
                     ,@c_Storerkey  
                     ,@c_Sku  
                     ,'' -- Lot  
                     ,'' -- UOM  
                     ,0  -- UOMQty  
                     ,0  -- Qty  
                     ,@c_PutawayLoc  
                     ,ISNULL(@c_LogicalLocation,'')  
                     ,'' -- FromID  
                     ,'' -- ToLoc  
                     ,'' -- LogicalToLoc  
                     ,'' -- ToID  
                     ,'' -- Caseid  
                     ,'SKU' -- PickMethod -- (ChewKP12)  
                     ,'0' -- STATUS  
                     ,''  -- StatusMsg  
                     ,'5' -- Priority  
                     ,''  -- SourcePriority  
                     ,''  -- Holdkey  
                     ,''  -- UserKey  
                     ,''  -- UserPosition  
                     ,''  -- UserKeyOverRide  
                     ,GETDATE() -- StartTime  
                     ,GETDATE() -- EndTime  
                     ,'RESIDUALMV'   -- SourceType  
                     ,@c_CCKey -- SourceKey -- (ChewKP12)  
                     ,'' -- PickDetailKey  
                     ,'' -- OrderKey  
                     ,'' -- OrderLineNumber  
                     ,'' -- ListKey  
                     ,'' -- WaveKey  
                     ,'' -- ReasonKey  
                     ,'' -- Message01  
                     ,'' -- Message02  
                     ,'' -- Message03  
                     ,'' -- RefTaskKey  
                     ,'' -- LoadKey  
                     ,@c_AreaKey  
                     ,'' -- DropID  
                     ,0)  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @n_Continue = 3  
                     SET @c_Status = '5'  
                     SET @c_ErrMsg = 'Insert TaskDetail Failed (isp_TCP_WCS_PA_SHELF_IN).'  
                     GOTO QUIT_SP  
                  END  
               END -- If NOT exists in TaskDetail  
               ------------ End Cycle count task          ---------------------------  
  
               -- Generating Alert --  
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' WCS MessageNumber : ' + @c_MessageNum  +  @c_NewLineChar  
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Loc: ' + @c_PutawayLoc  + ' CommingleSKU ' +  @c_NewLineChar  
  
               SELECT @c_ModuleName = 'RESIDUALMV'  
  
               SELECT @b_Success = 1  
  
               EXEC nspLogAlert  
                    @c_modulename       = @c_ModuleName  
                  , @c_AlertMessage     = @c_AlertMessage  
                  , @n_Severity         = '5'  
                  , @b_success          = @b_success     OUTPUT  
                  , @n_err              = @n_Err         OUTPUT  
                  , @c_errmsg           = @c_Errmsg      OUTPUT  
                  , @c_Activity        = 'RESIDUALMV'  
                  , @c_Storerkey        = @c_StorerKey  
                  , @c_SKU              = @c_SKU  
                  , @c_UOM              = ''  
                  , @c_UOMQty           = ''  
                  , @c_Qty              = @n_Qty_Actual  
                  , @c_Lot              = ''  
                  , @c_Loc              = @c_PutawayLoc  
                  , @c_ID               = ''  
                  , @c_TaskDetailKey    = @c_TaskDetailKey  
                  , @c_UCCNo            = ''  
  
               IF NOT @b_Success = 1  
               BEGIN  
                  SELECT @n_continue = 3  
               END  
            END  
         END  
    --END  
      END -- If exists commingle  
   END  
  
   /***************************************************/  
   /* Perform MOVE                                    */  
   /***************************************************/  
   IF @n_Qty_Actual > 0  
   BEGIN  
      SELECT @c_PackKey = SKU.PackKey  
           , @c_UOM     = PACK.PACKUOM3  
      FROM   dbo.SKU  WITH (NOLOCK)  
      JOIN   dbo.PACK WITH (NOLOCK) ON SKU.PACKKEY = PACK.PackKey  
      WHERE  StorerKey = @c_StorerKey  
      AND    SKU = @c_SKU  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT '@c_PackKey : ' + ISNULL(RTRIM(@c_PackKey),'')  
              + ', @c_UOM : ' + ISNULL(RTRIM(@c_UOM),'')  
      END  
  
      IF ISNULL(RTRIM(@c_PackKey),'') = ''  
      BEGIN  
         SET @n_Continue = 3  
         SET @c_Status = '5'  
         SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Packkey NOT found. Seq#: '  
                       + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
         GOTO QUIT_SP  
      END  
  
      -- TXCODE = PICK (Pick from Bulk) 
      -- The To Loc Going to be WCS01 which configure in Code LookUp table
      -- The Putaway Location going to be the From Location 
      IF ISNULL(RTRIM(@c_TXCODE), '') = 'PICK'  
      BEGIN  
         SET @c_FromLoc = @c_PutawayLoc  
  
         SELECT @c_PutawayLoc = Short  
         FROM   dbo.CodeLkUp WITH (NOLOCK)  
         WHERE  ListName   = @c_ListName  
         AND    Code       = @c_CodelkupCode  
  
         IF ISNULL(RTRIM(@c_PutawayLoc),'') = ''  
         BEGIN  
            SET @n_Continue = 3  
            SET @c_Status = '5'  
            SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. From Loc NOT found. Seq#: '  
                          + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
            GOTO QUIT_SP  
         END  
      END  
      ELSE  
      BEGIN  
         SELECT @c_FromLoc = Short  
         FROM   dbo.CodeLkUp WITH (NOLOCK)  
         WHERE  ListName   = @c_ListName  
         AND    Code       = @c_CodelkupCode  
  
         IF ISNULL(RTRIM(@c_FromLoc),'') = ''  
         BEGIN  
            SET @n_Continue = 3  
            SET @c_Status = '5'  
            SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. From Loc NOT found. Seq#: '  
                          + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
            GOTO QUIT_SP  
         END  
      END  
  
      IF NOT EXISTS(SELECT 1 FROM dbo.LOC WITH (NOLOCK)  
                    WHERE LOC = @c_FromLoc)  
      BEGIN  
         SET @n_Continue = 3  
         SET @c_Status = '5'  
         SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. From Loc ' + @c_FromLoc + ' NOT found. Seq#: '  
                       + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
         GOTO QUIT_SP  
      END  
  
      EXECUTE_MOVE:  
  
      SET @n_AvailableQty = 0  
      SELECT @n_AvailableQty = SUM(LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED -  
               (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))  
      FROM   dbo.LOTxLOCxID LLI WITH (NOLOCK)  
      WHERE  LLI.StorerKey = @c_StorerKey  
      AND    LLI.SKU       = @c_SKU  
      AND    LLI.LOC       = @c_FromLoc  
      AND    QTY - QtyPicked - QtyAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) > 0  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT @n_AvailableQty '@n_AvailableQty', @c_StorerKey '@c_StorerKey', @c_SKU '@c_SKU', @c_FromLoc '@c_FromLoc'  
      END  
  
      IF ISNULL(@n_AvailableQty,0) < @n_Qty_Actual -- (ChewKP01)  
      BEGIN  
         -- getting allocated qty from orders that NOT yet release to WCS  
         SET @n_NonReleaseQtyAlloc = 0  
  
         IF ISNULL(RTRIM(@c_TXCODE), '') = 'PICK'  
         BEGIN
  
            SELECT @n_NonReleaseQtyAlloc = SUM(Qty)  
            FROM PICKDETAIL p WITH (NOLOCK)  
            JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.OrderKey = p.OrderKey  
            JOIN LOC WITH (NOLOCK) ON LOC.Loc = P.Loc  
            LEFT OUTER JOIN TRANSMITLOG3 T3 WITH (NOLOCK) ON T3.key1 = WD.WaveKey AND T3.tablename = 'WAVERESLOG'  
            WHERE T3.transmitlogkey IS NULL  
            AND   P.[Status]  < 5  
            AND   P.Storerkey = @c_StorerKey  
            AND   P.SKU       = @c_SKU  
            AND   P.LOC       = @c_FromLoc  
            AND   LOC.LocationType NOT IN ('SHELVING','GOH')  
  
  
            IF @n_NonReleaseQtyAlloc + @n_AvailableQty < @n_Qty_Actual  
            BEGIN  
               SET @n_Continue = 3  
               SET @c_Status = '5'  
               SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Insufficient Non Wave-Released Allocated Qty to move. Seq#: '  
                             + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
               GOTO QUIT_SP  
            END  
  
            IF @n_NonReleaseQtyAlloc > 0  
            BEGIN  
               SET @n_TotUnAllocateQty = @n_Qty_Actual  
  
               DECLARE CUR_NonReleasePD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                  SELECT p.PickDetailKey, p.Lot, p.Qty  
                  FROM PICKDETAIL p WITH (NOLOCK)  
                  JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.OrderKey = p.OrderKey  
                  JOIN LOC WITH (NOLOCK) ON LOC.Loc = P.Loc  
                  LEFT OUTER JOIN TRANSMITLOG3 T3 WITH (NOLOCK) ON T3.key1 = WD.WaveKey AND T3.tablename = 'WAVERESLOG'  
                  WHERE T3.transmitlogkey IS NULL  
                  AND   P.[Status]  < 5  
                  AND   P.Storerkey = @c_StorerKey  
                  AND   P.SKU       = @c_SKU  
                  AND   P.LOC       = @c_FromLoc  
                  AND   LOC.LocationType NOT IN ('SHELVING','GOH')  
                  ORDER BY p.PickDetailKey  
  
               OPEN CUR_NonReleasePD  
               FETCH NEXT FROM CUR_NonReleasePD INTO @c_PickDetailKey, @c_LOT, @n_PickDetQty  
               WHILE @@FETCH_STATUS <> -1  
               BEGIN  
                  IF @n_PickDetQty <= @n_TotUnAllocateQty  
                  BEGIN  
                     SET @n_UnAllocateQty = @n_PickDetQty  
                     SET @c_PickSlipNo = ''  
  
                     SELECT @c_OrderKey        = p.OrderKey,  
                            @c_OrderLineNumber = p.OrderLineNumber,  
                            @c_PackKey         = p.PackKey,  
                            @c_PickSlipNo      = p.PickSlipNo  
                     FROM PICKDETAIL p WITH (NOLOCK)  
                     WHERE p.PickDetailKey = @c_PickDetailKey  
  
                     IF @c_TraceFlag = '1'  
                     BEGIN  
                        INSERT TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col5) -- SOS# 255550  
                        VALUES ('isp_TCP_WCS_PA_SHELF_IN', GetDate(), @c_OrderKey, @c_OrderLineNumber, @n_PickDetQty, @c_PickSlipNo, @c_PickDetailKey, '*1*')  
                     END  
  
                     -- Unallocate Whole PickDetail  
                     DELETE FROM PICKDETAIL  
                     WHERE PickDetailKey = @c_PickDetailKey  
  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @n_Continue = 3  
                        SET @c_Status = '5'  
                        SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Delete PickDetail Failed. Seq#: '  
                                      + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
                        GOTO QUIT_SP  
                     END  
                     ELSE  
                     BEGIN  
                        IF EXISTS (SELECT 1 FROM dbo.RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey)  
                        BEGIN  
                           DELETE FROM dbo.RefKeyLookup WHERE PickDetailKey = @c_PickDetailKey  
                           IF @@ERROR <> 0  
                           BEGIN  
                              SET @n_Continue = 3  
                              SET @c_Status = '5'  
                              SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Delete RefKeyLookup Failed. Seq#: '  
                                            + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
                              GOTO QUIT_SP  
                           END  
                        END  
  
                        SELECT @b_Success = 0  
                        EXECUTE nspg_getkey  
                           'PreAllocatePickDetailKey',  
                           10,  
                           @c_PreAllocatePickDetailKey OUTPUT,  
                           @b_Success OUTPUT,  
                           @n_Err     OUTPUT,  
                           @c_ErrMsg  OUTPUT  
  
                        IF @b_Success = 1  
                        BEGIN  
                           IF ISNULL(RTRIM(@c_PickSlipNo),'') = ''  
                              SET @c_Runkey = @c_PickDetailKey  
                           ELSE  
                              SET @c_Runkey = @c_PickSlipNo  
  
                           INSERT PREALLOCATEPICKDETAIL  
                              (PreAllocatePickDetailKey, OrderKey, OrderLineNumber, PreAllocateStrategyKey,  
                               PreAllocatePickCode, Lot, StorerKey, Sku, Qty, UOMQty, UOM, PackKey, DOCartonize, Runkey, PickMethod)  
                           VALUES  (@c_PreAllocatePickDetailKey, @c_Orderkey, @c_OrderLineNumber, 'STD', 'TCP',  
                                    @c_Lot, @c_StorerKey, @c_Sku, @n_UnAllocateQty, @n_UnAllocateQty, '6',  
                                    @c_PackKey, 'N', @c_Runkey, '')  
  
                           SELECT @n_Err = @@ERROR  
  
                           SELECT @n_Cnt = COUNT(*)  
                           FROM PREALLOCATEPICKDETAIL WITH (NOLOCK)  
                           WHERE preallocatePickDetailKey = @c_PreAllocatePickDetailKey  
  
                           IF NOT (@n_Err = 0 AND @n_Cnt = 1)  
                           BEGIN  
                              SET @n_Continue = 3  
                              SET @c_Status = '5'  
                              SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Insert PreAllocatePickDetail Failed. Seq#: '  
                                            + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
                              GOTO QUIT_SP  
                           END  
                        END  -- IF @b_sucess = 1  
                     END  
                  END -- @n_PickDetQty <= @n_TotUnAllocateQty  
                  ELSE  
                  BEGIN  
                     SET @n_UnAllocateQty = @n_TotUnAllocateQty  
  
                     -- Unallocate Whole PickDetail  
                     UPDATE PICKDETAIL  
                        SET Qty = Qty - @n_UnAllocateQty  
                     WHERE PickDetailKey = @c_PickDetailKey  
  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @n_Continue = 3  
                        SET @c_Status = '5'  
                        SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Update PickDetail Failed. Seq#: '  
                                      + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
                        GOTO QUIT_SP  
                     END  
                     ELSE  
                     BEGIN  
                        SET @c_PickSlipNo = ''  
  
                        SELECT @c_OrderKey        = p.OrderKey,  
                               @c_OrderLineNumber = p.OrderLineNumber,  
                               @c_PackKey         = p.PackKey,  
                               @c_PickSlipNo      = p.PickSlipNo  
                        FROM PICKDETAIL p WITH (NOLOCK)  
                        WHERE p.PickDetailKey = @c_PickDetailKey  
  
                        IF @c_TraceFlag = '1'  
                        BEGIN  
                           INSERT TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col5) -- SOS# 255550  
                           VALUES ('isp_TCP_WCS_PA_SHELF_IN', GetDate(), @c_OrderKey, @c_OrderLineNumber, @n_UnAllocateQty, @c_PickSlipNo, @c_PickDetailKey, '*2*')  
                        END  
  
                        IF ISNULL(RTRIM(@c_PickSlipNo),'') = ''  
                           SET @c_Runkey = @c_PickDetailKey  
                        ELSE  
                           SET @c_Runkey = @c_PickSlipNo  
  
                        SELECT @b_Success = 0  
                        EXECUTE nspg_getkey  
                           'PreAllocatePickDetailKey',  
                           10,  
                           @c_PreAllocatePickDetailKey OUTPUT,  
                           @b_Success OUTPUT,  
                           @n_Err     OUTPUT,  
                           @c_ErrMsg  OUTPUT  
  
                        IF @b_Success = 1  
                        BEGIN  
                           INSERT PREALLOCATEPICKDETAIL  
                              (PreAllocatePickDetailKey, OrderKey, OrderLineNumber, PreAllocateStrategyKey,  
                               PreAllocatePickCode, Lot, StorerKey, Sku, Qty, UOMQty, UOM, PackKey, DOCartonize, Runkey, PickMethod)  
                           VALUES  (@c_PreAllocatePickDetailKey, @c_Orderkey, @c_OrderLineNumber, 'STD', 'TCP',  
                                    @c_Lot, @c_StorerKey, @c_Sku, @n_UnAllocateQty, @n_UnAllocateQty, '6',  
                                    @c_PackKey, 'N', @c_Runkey, '')  
  
                           SELECT @n_Err = @@ERROR  
  
                           SELECT @n_Cnt = COUNT(*)  
                           FROM PREALLOCATEPICKDETAIL WITH (NOLOCK)  
                           WHERE preallocatePickDetailKey = @c_PreAllocatePickDetailKey  
  
                           IF NOT (@n_Err = 0 AND @n_Cnt = 1)  
                           BEGIN  
                              SET @n_Continue = 3  
                              SET @c_Status = '5'  
                              SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Insert PreAllocatePickDetail Failed. Seq#: '  
                                            + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
                              GOTO QUIT_SP  
                           END  
                        END  -- IF @b_sucess = 1  
                     END  
                  END  
  
                  SET @n_TotUnAllocateQty = @n_TotUnAllocateQty - @n_UnAllocateQty  
                  IF @n_TotUnAllocateQty = 0  
                     BREAK  
  
                  FETCH NEXT FROM CUR_NonReleasePD INTO @c_PickDetailKey, @c_LOT, @n_PickDetQty  
               END  
               CLOSE CUR_NonReleasePD  
               DEALLOCATE CUR_NonReleasePD  
  
               GOTO EXECUTE_MOVE  
            END -- @n_NonReleaseQtyAlloc > 0  
            ELSE
            BEGIN
         	   -- Offset the WCS_ResidualMoveLog ActualMoveQty with Pre-moved qty
            	
         	   SET @n_TotQtyToMove = @n_Qty_Actual 
         	   DECLARE CUR_ResidualMoveLog_Update CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         	   SELECT SerialNo, 
         	          WRML.PreMoveQty - WRML.ActualMoveQty 
         	   FROM WCS_ResidualMoveLog WRML WITH (NOLOCK)
         	   WHERE WRML.PreMoveQty - WRML.ActualMoveQty > 0 
         	   AND   WRML.StorerKey = @c_StorerKey 
         	   AND   WRML.SKU = @c_SKU
         	   AND   WRML.Loc = @c_FromLoc
         	   ORDER BY WRML.SerialNo 
            	
         	   OPEN CUR_ResidualMoveLog_Update 
            	
         	   FETCH NEXT FROM CUR_ResidualMoveLog_Update INTO @n_RMvLogSerNo, @n_QtyToMove
            	
         	   WHILE @@FETCH_STATUS <> -1
         	   BEGIN
         		   IF @n_TotQtyToMove < @n_QtyToMove 
         		      SET @n_QtyToMove = @n_TotQtyToMove
            		   
         		   UPDATE WCS_ResidualMoveLog
         		   SET ActualMoveQty = ActualMoveQty + @n_QtyToMove
         		   WHERE SerialNo = @n_RMvLogSerNo 
            		
         		   SET @n_TotQtyToMove = @n_TotQtyToMove - @n_QtyToMove
            		
         		   IF @n_TotQtyToMove <= 0 
         		      BREAK
            		
         		   FETCH NEXT FROM CUR_ResidualMoveLog_Update INTO @n_RMvLogSerNo, @n_QtyToMove 
         	   END
         	   CLOSE CUR_ResidualMoveLog_Update
         	   DEALLOCATE CUR_ResidualMoveLog_Update
            	
         	   IF  @n_TotQtyToMove > 0 
         	   BEGIN
                  SET @n_Continue = 3  
                  SET @c_Status = '5'  
                  SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Insufficient FromQty to move. Seq#: '  
                                + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
                  GOTO QUIT_SP           		
         	   END
            	
            END -- @n_NonReleaseQtyAlloc < 0
         END -- IF ISNULL(RTRIM(@c_TXCODE), '') = 'PICK'  
         ELSE  
         BEGIN
            SET @n_Continue = 3  
            SET @c_Status = '5'  
            SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. Insufficient FromQty to move. Seq#: '  
                          + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
            GOTO QUIT_SP           		         	
         END  
      END -- IF ISNULL(@n_AvailableQty,0) < @n_Qty_Actual  
      -- Completed the Un-allocate and pre-allocated orders.
  
      -- rdt_TMDynamicPick_MoveCase  
      DECLARE CUR_LOTxLOCxID_MOVE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT LOT,  
                ID,  
                LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED -  
                (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)  
         FROM   dbo.LOTxLOCxID LLI WITH (NOLOCK)  
         WHERE  LLI.StorerKey = @c_StorerKey  
         AND    LLI.SKU       = @c_SKU  
         AND    LLI.LOC       = @c_FromLoc  
         AND    QTY - QtyPicked - QtyAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)  > 0  
         ORDER BY LLI.Lot  
  
      OPEN CUR_LOTxLOCxID_MOVE  
      FETCH NEXT FROM CUR_LOTxLOCxID_MOVE INTO @c_FromLot, @c_FromID, @n_FromQty  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         IF @b_debug = 1  
         BEGIN  
            SELECT '@n_Qty_Actual : '    + CONVERT(NVARCHAR,@n_Qty_Actual)  
                 + ', @c_FromLot : ' + ISNULL(RTRIM(@c_FromLot),'')  
                 + ', @c_FromID : '  + ISNULL(RTRIM(@c_FromID),'')  
                 + ', @n_FromQty : ' + CONVERT(NVARCHAR, @n_FromQty)  
         END  

         IF @c_TraceFlag = '1'  
         BEGIN  
            INSERT TraceInfo ( TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5  
                             , Col1, Col2, Col3, Col4, Col5 ) -- SOS# 258940  
            VALUES ( 'isp_TCP_WCS_PA_SHELF_IN', GetDate(), @c_StorerKey, @c_SKU, @c_FromLot, @c_FromLoc, @c_FromID  
                   , @n_FromQty, @n_Qty_Actual, @c_MessageNum, CAST(@n_SerialNo AS NVARCHAR(10)), '*4*' )  
         END  
           
         SET @n_FromQtyToTake = 0  
  
         IF @n_FromQty < 0  
         BEGIN  
            SET @n_Continue = 3  
            SET @c_Status = '5'  
            SET @c_ErrMsg = 'Import ' + RTRIM(@c_InMsgType) + ' Failed. FromQty < 0. Seq#: '  
                          + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
            GOTO QUIT_SP  
         END  
         ELSE  
         BEGIN  
            IF @n_FromQty >= @n_Qty_Actual  
            BEGIN  
               SET @n_FromQtyToTake = @n_Qty_Actual  
            END  
            ELSE --IF @n_FromQty < @n_Qty_Actual  
            BEGIN  
               SET @n_FromQtyToTake = @n_FromQty  
            END  
         END  
  
         IF @b_debug = 1  
         BEGIN  
            SELECT '@n_FromQtyToTake : ' + CONVERT(NVARCHAR,@n_FromQtyToTake)  
         END  
  
         IF @n_FromQtyToTake > 0  
         BEGIN  
            EXECUTE nspItrnAddMove  
               @n_ItrnSysId      = NULL,  
               @c_itrnkey        = NULL,  
               @c_Storerkey      = @c_StorerKey,  
               @c_SKU            = @c_SKU,  
               @c_Lot            = @c_FromLot,  
               @c_FromLoc        = @c_FromLoc,  
               @c_FromID         = @c_FromID,  
               @c_ToLoc          = @c_PutawayLoc,  
               @c_ToID           = '',  
               @c_Status         = '',  
               @c_Lottable01     = '',  
               @c_Lottable02     = '',  
               @c_Lottable03     = '',  
               @d_Lottable04     = NULL,  
               @d_Lottable05     = NULL,  
               @n_casecnt        = 0,  
               @n_innerpack      = 0,  
               @n_Qty            = @n_FromQtyToTake,  
               @n_Pallet         = 0,  
               @f_Cube           = 0,  
               @f_GrossWgt       = 0,  
               @f_NetWgt    = 0,  
               @f_OtherUnit1     = 0,  
               @f_OtherUnit2     = 0,  
               @c_SourceKey      = @c_MessageNum,  
               @c_SourceType     = 'isp_TCP_WCS_PA_SHELF_IN',  
               @c_PackKey        = @c_PackKey,  
               @c_UOM            = @c_UOM,  
               @b_UOMCalc        = 1,  
               @d_EffectiveDate  = NULL,  
               @b_Success        = @b_Success   OUTPUT,  
               @n_Err            = @n_Err       OUTPUT,  
               @c_errmsg         = @c_Errmsg    OUTPUT  
  
            IF ISNULL(RTRIM(@c_ErrMsg),'') <> ''  
            BEGIN  
               SET @n_Continue = 3  
               SET @n_Err      = @n_Err  
               SET @c_ErrMsg   = @c_ErrMsg  
               GOTO QUIT_SP  
            END  
--            BEGIN -- Update WCS_ResidualMoveLog  
--               SET @n_TotPutawayQty = @n_FromQtyToTake  
--  
--               IF EXISTS(SELECT 1 FROM WCS_ResidualMoveLog wrml WITH (NOLOCK)  
--                         WHERE wrml.StorerKey = @c_StorerKey  
--                         AND wrml.SKU = @c_SKU  
--                         AND wrml.PreMoveQty > wrml.ActualMoveQty)  
--               BEGIN  
--                  DECLARE CUR_ResidualMoveLog CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
--                     SELECT wrml.SerialNo, wrml.Loc, (wrml.PreMoveQty - wrml.ActualMoveQty)  
--                     FROM WCS_ResidualMoveLog wrml WITH (NOLOCK)  
--                     WHERE wrml.StorerKey = @c_StorerKey  
--                       AND wrml.SKU = @c_SKU  
--                       AND wrml.PreMoveQty > wrml.ActualMoveQty  
--                     ORDER BY SerialNo  
--  
--                  OPEN CUR_ResidualMoveLog  
--                  FETCH NEXT FROM CUR_ResidualMoveLog INTO @n_RSSerialNo, @c_LOC, @n_OutStdQty  
--                  WHILE @@FETCH_STATUS <> -1  
--                  BEGIN  
--                     IF @n_TotPutawayQty < @n_OutStdQty  
--                        SET @n_PutawayQty = @n_TotPutawayQty  
--                     ELSE  
--                        SET @n_PutawayQty = @n_OutStdQty  
--  
--                     --SELECT @n_TotPutawayQty '@n_TotPutawayQty', @n_PutawayQty '@n_PutawayQty',  
--                     --@n_OutStdQty '@n_OutStdQty', @n_RSSerialNo '@n_RSSerialNo'  
--  
--                     UPDATE WCS_ResidualMoveLog  
--                        SET ActualMoveQty = ActualMoveQty + @n_PutawayQty  
--                     WHERE SerialNo = @n_RSSerialNo  
--                     IF @@ERROR <> 0  
--                     BEGIN  
--                        SET @n_Continue = 3  
--                        SET @c_Status = '5'  
--                        SET @c_ErrMsg = 'Update WCS_ResidualMoveLog Failed.'  
--                                      + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
--                        GOTO QUIT_SP  
--                     END  
--  
--                     SET @n_TotPutawayQty = @n_TotPutawayQty - @n_PutawayQty  
--  
--                     IF @n_TotPutawayQty = 0  
--                        BREAK  
--  
--                     FETCH NEXT FROM CUR_ResidualMoveLog INTO @n_RSSerialNo, @c_LOC, @n_OutStdQty  
--                  END  
--                  CLOSE CUR_ResidualMoveLog  
--                  DEALLOCATE CUR_ResidualMoveLog  
--               END  
--            END -- Update WCS_ResidualMoveLog Complete  
  
            SET @n_QtyToAllocate = @n_FromQtyToTake  
            -- Allocate Reserved LOT for Orders  
            IF ISNULL(RTRIM(@c_TXCODE), '') = 'PTWY'  
            BEGIN  
               DECLARE CUR_PREALLOCATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                  SELECT papd.PreAllocatePickDetailKey, papd.OrderKey, papd.OrderLineNumber, papd.Qty, papd.RunKey  
                  FROM PreAllocatePickDetail papd WITH (NOLOCK)  
                  JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.OrderKey = papd.OrderKey  
                  LEFT OUTER JOIN TRANSMITLOG3 T3 WITH (NOLOCK) ON T3.key1 = WD.WaveKey AND T3.tablename = 'WAVERESLOG'  
                  WHERE papd.Storerkey = @c_StorerKey  
                  AND   papd.Sku = @c_SKU  
              AND   papd.Lot = @c_FromLot  
                  AND   papd.Qty > 0  
                  AND   T3.transmitlogkey IS NULL  
                  ORDER BY papd.PreAllocatePickDetailKey  
  
               OPEN CUR_PREALLOCATE  
               FETCH NEXT FROM CUR_PREALLOCATE INTO @c_PreAllocatePickDetailKey, @c_OrderKey, @c_OrderLineNumber, @n_PickDetQty, @c_PickSlipNo  
               WHILE @@FETCH_STATUS <> -1  
               BEGIN  
                  IF @n_PickDetQty > @n_QtyToAllocate  
                     SET @n_PickDetQty = @n_QtyToAllocate  
  
                  IF @c_TraceFlag = '1'  
                  BEGIN  
                     INSERT TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col5) -- SOS# 255550  
                     VALUES ('isp_TCP_WCS_PA_SHELF_IN', GetDate(), @c_OrderKey, @c_OrderLineNumber, @n_PickDetQty, @c_PickSlipNo, @c_PreAllocatePickDetailKey, '*3*')  
                  END  
  
                  IF ISNULL(RTRIM(@c_PickSlipNo),'') <> ''  
                  BEGIN  
                     IF LEFT(@c_PickSlipNo,1) <> 'P'  
                     BEGIN  
                        SET @c_PickSlipNo = ''  
                     END  
                  END  
  
                  SELECT @b_Success = 1  
                  EXECUTE nspg_getkey  
                     'PickDetailKey'  
                     , 10  
                     , @c_PickDetailKey OUTPUT  
                     , @b_Success OUTPUT  
                     , @n_err OUTPUT  
                     , @c_errmsg OUTPUT  
  
                  IF @b_Success = 1  
                  BEGIN  
                     INSERT PICKDETAIL (PickDetailKey, PickHeaderKey, OrderKey, OrderLineNumber,  
                                        Lot, Storerkey, Sku, Qty, Loc, Id, UOMQty,  
                                        UOM, CaseID, PackKey, CartonGroup, DoReplenish, ReplenishZone,  
                                        DoCartonize, TrafficCop, PickMethod, PickSlipNO)  
                     VALUES ( @c_PickDetailKey, '', @c_OrderKey,@c_OrderLineNumber,  
                              @c_FromLOT, @c_StorerKey, @c_SKU, @n_PickDetQty, @c_PutawayLoc, @c_FromID, @n_PickDetQty,  
                              '6', '', @c_PackKey,'', 'N', '',  
                              'N', 'U', '3', @c_PickSlipNo)  
  
                     SELECT @n_err = @@ERROR  
                     SELECT @n_cnt = COUNT(1) FROM PICKDETAIL WITH (NOLOCK)  
                     WHERE PickDetailKey = @c_PickDetailKey  
  
                     IF NOT (@n_Err = 0 AND @n_Cnt = 1)  
                     BEGIN  
                        SET @n_Continue = 3  
                        SET @c_Status = '5'  
                        SET @c_ErrMsg = 'Insert PickDetail Failed.'  
                                      + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
                        GOTO QUIT_SP  
                     END  
                     -- Shouldn't have RefKeyLookup for Pickdetail NOT yet release to WCS,  
                     -- the RefKeyLookup is insert from WCS TCP Message  
                     -- Cater for Phase 1 which already have PickSlipNo 02-08-2012 By Shong  
                     IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey AND ISNULL(RTRIM(@c_PickSlipNo),'') <> '' )  
                     BEGIN  
                        SET @c_LoadKey = ''  
  
                        SELECT TOP 1 @c_LoadKey = LoadKey  
                        FROM ORDERS WITH (NOLOCK)  
                        WHERE OrderKey = @c_OrderKey  
  
                        SELECT @c_PickSlipNo = PickSlipNo -- SOS# 255550  
                        FROM PickDetail WITH (NOLOCK)  
                        WHERE PickDetailKey = @c_PickDetailKey  
  
                        INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey, EditWho) -- SOS# 255550  
                        VALUES (@c_PickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @c_LoadKey, 'TCP05a.' + sUser_sName())  
  
                        SET @n_Err = @@ERROR  
                        IF @n_Err <> 0  
                        BEGIN  
                           SET @n_Continue = 3  
                           SET @c_Status = '5'  
                           SET @c_ErrMsg = 'Insert RefKeyLookup Failed.'  
                                         + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
                           GOTO QUIT_SP  
                        END  
                     END  
                  END -- @b_Success = 1  
                  ELSE  
                  BEGIN  
                     SET @n_Continue = 3  
                     SET @c_Status = '5'  
                     SET @c_ErrMsg = 'Get PickDetailKey Failed.'  
                                   + CONVERT(NVARCHAR, @n_SerialNo) + '. (isp_TCP_WCS_PA_SHELF_IN)'  
                     GOTO QUIT_SP  
                  END  
  
                  SET @n_QtyToAllocate = @n_QtyToAllocate - @n_PickDetQty  
  
                  IF @n_QtyToAllocate <= 0  
                     BREAK  
  
                  FETCH NEXT FROM CUR_PREALLOCATE INTO @c_PreAllocatePickDetailKey, @c_OrderKey, @c_OrderLineNumber, @n_PickDetQty, @c_PickSlipNo  
               END  
               CLOSE CUR_PREALLOCATE  
               DEALLOCATE CUR_PREALLOCATE  
            END  
  
            SET @n_Qty_Actual = @n_Qty_Actual - @n_FromQtyToTake  
  
            IF @n_Qty_Actual = 0  
            BEGIN  
               BREAK  
            END  
         END -- IF @n_FromQtyToTake > 0  
  
         FETCH NEXT FROM CUR_LOTxLOCxID_MOVE INTO @c_FromLot, @c_FromID, @n_FromQty  
      END  
      CLOSE CUR_LOTxLOCxID_MOVE  
      DEALLOCATE CUR_LOTxLOCxID_MOVE  
   END --IF @n_Qty_Actual > 0  
  
   QUIT_SP:  
  
   IF @b_debug = 1  
   BEGIN  
      SELECT 'Update TCPSocket_INLog >> @c_Status : ' + @c_Status  
           + ', @c_ErrMsg : ' + @c_ErrMsg  
   END  
  
   IF @n_Continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      ROLLBACK TRAN WCS_BULK_PICK  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_TCP_WCS_PA_SHELF_IN'  
   END  
  
   UPDATE dbo.TCPSocket_INLog WITH (ROWLOCK)  
   SET STATUS   = @c_Status  
     , ErrMsg   = @c_ErrMsg  
     , Editdate = GETDATE()  
     , EditWho  = SUSER_SNAME()  
   WHERE SerialNo = @n_SerialNo  
  
   WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started  
      COMMIT TRAN WCS_BULK_PICK  
   RETURN  
END

GO