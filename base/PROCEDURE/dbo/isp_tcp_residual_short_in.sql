SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_TCP_RESIDUAL_SHORT_IN                          */
/* Creation Date: 11-11-2011                                            */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Picking from Bulk to Induction                              */
/*          RedWerks to WMS Exceed                                      */
/*                                                                      */
/* Input Parameters:  @c_MessageNum    - Unique no for Incoming data     */
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
/* 2012-03-31   Ung       1.1   Remove ItrnAddMove                      */
/* 2012-04-02   James     1.2   SOS237850 - Enhance Supervisor Alert    */
/*                              (james01)                               */
/* 2012-04-15   Ung       1.3   Defination changed, short become actual */
/* 2012-04-17   Shong     1.4   Cannot Get Area Key Target Loc          */
/* 2012-06-29   ChewKP    1.5   TM CycleCount Task Standardization      */
/*                              (ChewKP01)                              */
/* 2012-07-09   ChewKP    1.6   SOS#249039 - AutoConfirm ShortPick      */
/*                              (ChewKP02)                              */                
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_TCP_RESIDUAL_SHORT_IN]
                @c_MessageNum  NVARCHAR(10)
              , @b_Debug       INT
              , @b_Success     INT           OUTPUT
              , @n_Err         INT        OUTPUT
              , @c_ErrMsg      NVARCHAR(250)  OUTPUT

AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue           INT
         , @n_StartTCnt          INT

   DECLARE @n_SystemQty INT

   DECLARE @n_SerialNo         INT
          ,@c_Status           NVARCHAR(1)
          ,@c_DataString       NVARCHAR(4000)
          ,@c_CCKey            NVARCHAR(10)

   DECLARE @c_NewLineChar NVARCHAR(2)
   SET @c_NewLineChar =  master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10)

   SELECT @n_Continue = 1, @b_Success = 1, @n_Err = 0
   SET @n_StartTCnt = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN WCS_RESIDUAL_SHORT

   SELECT @n_SerialNo   = SerialNo,
          @c_DataString = [Data]
   FROM   dbo.TCPSocket_INLog WITH (NOLOCK)
   WHERE  MessageNum     = @c_MessageNum
   AND    MessageType   = 'RECEIVE'
   AND    Status        = '0'

   IF ISNULL(RTRIM(@n_SerialNo),'') = ''
   BEGIN
      IF @b_Debug = 1
      BEGIN
         SELECT 'Nothing to process. MessageNum = ' + @c_MessageNum
      END

      GOTO QUIT_SP
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '@n_SerialNo : ' + CONVERT(VARCHAR, @n_SerialNo)
           + ', @c_Status : '     + @c_Status
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
      SET @c_ErrMsg = 'Data String is empty. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_RESIDUAL_SHORT_IN)'
      GOTO QUIT_SP
   END

   DECLARE
 --   @c_MessageNum       NVARCHAR(10),
    @c_MessageType      NVARCHAR(15),
    @c_StorerKey        NVARCHAR(15),
    @c_Facility         NVARCHAR(5),
    @c_TargetLoc        NVARCHAR(10),
    @c_SKU              NVARCHAR(20),
    @n_QtyExpected      INT        ,
    @n_QtyActual        INT        ,
    @c_ReconcilLoc      NVARCHAR(10),
    @c_TransCode        NVARCHAR(10),
    @c_ReasonCode       NVARCHAR(10),
    @n_Qty              INT,
    @c_ToLoc            NVARCHAR(10), -- (ChewKP02)
    @c_PackKey          NVARCHAR(10), -- (ChewKP02)
    @c_PackUOM3         NVARCHAR(10), -- (ChewKP02)
    @c_LOT              NVARCHAR(10), -- (ChewKP02)
    @c_ID               NVARCHAR(18), -- (ChewKP02)
    @c_ItrnKey          NVARCHAR(10)  -- (ChewKP02)

   SET @c_ErrMsg           = ''
   SET @c_Status           = '9'
   SET @n_QtyActual        = 0
   SET @c_MessageType      = ''
   SET @c_MessageNum       = ''
   SET @c_StorerKey        = ''
   SET @c_Facility         = ''
   SET @c_ReconcilLoc  = ''
   SET @c_TransCode        = ''
   SET @c_SKU              = ''
   SET @c_ReasonCode       = ''
   SET @c_TargetLoc        = ''
   SET @n_QtyExpected      = 0
   SET @n_Qty              = 0
   SET @c_ToLoc            = ''  -- (ChewKP02)
   SET @c_PackKey          = ''  -- (ChewKP02)
   SET @c_PackUOM3         = ''  -- (ChewKP02)
   SET @c_LOT              = ''  -- (ChewKP02)
   SET @c_ID               = ''  -- (ChewKP02)
   SET @c_ItrnKey          = ''  -- (ChewKP02)

   SELECT @c_MessageNum = MessageNum
         ,@c_MessageType = MessageType
         ,@c_StorerKey = StorerKey
         ,@c_Facility = Facility
         ,@c_TargetLoc = TargetLoc
         ,@c_SKU = SKU
         ,@n_QtyExpected = QtyExpected
         ,@n_QtyActual = QtyActual
         ,@c_ReconcilLoc = ReconcilLoc
         ,@c_TransCode = TransCode
         ,@c_ReasonCode = ReasonCode
   FROM fnc_GetTCPResidualShort( @n_SerialNo )

   IF @b_Debug = 1
   BEGIN
      SELECT MessageNum = MessageNum
            ,MessageType = MessageType
            ,StorerKey = StorerKey
            ,Facility = Facility
            ,TargetLoc = TargetLoc
            ,SKU = SKU
            ,QtyExpected = QtyExpected
            ,QtyActual = QtyActual
            ,ReconcilLoc = ReconcilLoc
            ,TransCode = TransCode
            ,ReasonCode = ReasonCode
      FROM fnc_GetTCPResidualShort( @n_SerialNo )
   END

   IF @c_MessageType <> 'RESIDUALDISC'
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Wrong Message Type' + @c_MessageType + '. (isp_TCP_RESIDUAL_SHORT_IN)'
      GOTO QUIT_SP
   END


   IF @n_QtyActual < 0
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Qty Actual Should Greater then ZERO. Qty Actual = ' + CAST(@n_QtyActual AS NVARCHAR(10)) + '. (isp_TCP_RESIDUAL_SHORT_IN)'
      GOTO QUIT_SP
   END

   -- Check recon LOC valid, if provide
   IF ISNULL(RTRIM(@c_ReconcilLoc),'') <> '' AND NOT EXISTS(SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @c_ReconcilLoc)
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Invalid Sin Bin Location. Location=' + @c_ReconcilLoc + '. (isp_TCP_RESIDUAL_SHORT_IN)'
      GOTO QUIT_SP
   END

   DECLARE @c_LogicalLocation NVARCHAR(10),
           @c_AreaKey         NVARCHAR(10),
           @c_TaskDetailKey   NVARCHAR(10),
           @c_FromLoc         NVARCHAR(10)

   SET @c_FromLoc = ''

   
   SELECT @c_FromLoc = ISNULL(Short,'')
   FROM CodeLkUp WITH (NOLOCK)
   WHERE LISTNAME = 'WCSROUTE'
   AND   CODE = 'CASE'

   IF ISNULL(RTRIM(@c_TargetLoc),'') =''
   BEGIN
   	SET @c_TargetLoc = @c_FromLoc 
   END

   IF ISNULL(RTRIM(@c_FromLoc),'') = '' OR
      NOT EXISTS(SELECT 1 FROM LOC (NOLOCK) WHERE LOC = @c_FromLoc)
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Bad Code Location ' + @c_FromLoc + ', Check LOC Master OR CodeLKUP Table. ListName = WCSROUTE. (isp_TCP_RESIDUAL_SHORT_IN)'
      GOTO QUIT_SP
   END
   
   
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
      SET @c_ErrMsg = 'Get PickDetail Key Failed (isp_TCP_RESIDUAL_SHORT_IN).'
      GOTO QUIT_SP
   END

   SET @c_LogicalLocation = ''
   SET @c_AreaKey = ''
   
   SELECT @c_LogicalLocation = LogicalLocation,
          @c_AreaKey         = ISNULL(ad.AreaKey, '')
   FROM   LOC WITH (NOLOCK)
   LEFT OUTER JOIN AreaDetail ad WITH (NOLOCK) ON ad.PutawayZone = LOC.PutawayZone
   WHERE  LOC = @c_TargetLoc 

   IF ISNULL(RTRIM(@c_TargetLoc),'') <>''
   BEGIN
      SET @n_SystemQty = 0 
      SELECT @n_SystemQty = ISNULL(SUM(QTY - QtyPicked),0)
      FROM   SKUxLOC sl WITH (NOLOCK)
      WHERE  sl.StorerKey = @c_StorerKey
      AND    sl.Sku = @c_SKU
      AND    sl.Loc = @c_TargetLoc   	
   END
   
   -- (ChewKP02) 
   -- Move to Virtual Loc set up in CodeLKup 'WCSROUTE'
   IF @c_TransCode = 'PTWY' 
   BEGIN
         
         SELECT @c_ToLoc = ISNULL(Short,'')
         FROM CodeLkUp WITH (NOLOCK)
         WHERE LISTNAME = 'WCSROUTE'
         AND   CODE = 'VSHORTLOC'
         
         IF @c_ToLoc = ''
         BEGIN
            SET @n_Continue = 3
            SET @c_Status = '5'
            SET @c_ErrMsg = 'Virtual Location needed. Check LOC Master OR CodeLKUP Table. ListName = WCSROUTE. (isp_TCP_RESIDUAL_SHORT_IN)'
            GOTO QUIT_SP
         END
         
         
         DECLARE CUR_RESIDUAL_SHORT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT L.LOT, L.ID, L.Qty - (L.QtyPicked + L.QtyAllocated)
         FROM   LOTxLOCxID L WITH (NOLOCK)
         WHERE  L.Storerkey = @c_StorerKey
         AND    L.SKU = @c_SKU
         AND    L.LOC = @c_FromLoc
         --AND    L.Qty - (L.QtyPicked + L.QtyAllocated) > 0
      
         OPEN CUR_RESIDUAL_SHORT
      
         FETCH NEXT FROM CUR_RESIDUAL_SHORT INTO @c_LOT, @c_ID, @n_Qty
      
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            
            IF @n_Qty > @n_QtyExpected
            BEGIN
              SET @n_Qty = @n_QtyExpected
            END
      
            SELECT @c_PackKey = P.PackKey,
                   @c_PackUOM3  = P.PackUOM3
            FROM PACK p (NOLOCK)
            JOIN SKU S (NOLOCK) ON S.PackKey = p.PackKey
            WHERE S.StorerKey = @c_StorerKey
            AND   S.SKU = @c_SKU
      
            EXEC nspItrnAddMove
             @n_ItrnSysId              = null,
             @c_StorerKey              = @c_StorerKey,
             @c_Sku                    = @c_SKU,
             @c_Lot                    = @c_LOT,
             @c_FromLoc                = @c_FromLOC,
             @c_FromID                 = @c_ID,
             @c_ToLoc                  = @c_ToLoc,
             @c_ToID                   = @c_ID,
             @c_Status                 = '0',
             @c_lottable01             = '',
             @c_lottable02             = '',
             @c_lottable03             = '',
             @d_lottable04             = null,
             @d_lottable05             = null,
             @n_casecnt                = 0,
             @n_innerpack              = 0,
             @n_qty                    = @n_Qty,
             @n_pallet                 = 0,
             @f_cube                   = 0,
             @f_grosswgt               = 0,
             @f_netwgt                 = 0,
             @f_otherunit1             = 0,
             @f_otherunit2             = 0,
             @c_SourceKey              = @c_MessageNum,
             @c_SourceType             = 'isp_TCP_RESIDUAL_SHORT_I',
             @c_PackKey                = @c_PackKey,
             @c_UOM                    = @c_PackUOM3,
             @b_UOMCalc                = 0,
             @d_EffectiveDate          = NULL,
             @c_itrnkey                = @c_ItrnKey OUTPUT,
             @b_Success                = @b_Success OUTPUT,
             @n_err                    = @n_Err OUTPUT,
             @c_errmsg                 = @c_ErrMsg OUTPUT
      
            IF @b_Success <> 1
            BEGIN
               SET @n_Continue = 3
               SET @c_Status = '5'
               SET @c_ErrMsg = 'Move Failed (isp_TCP_RESIDUAL_SHORT_IN).'
               GOTO QUIT_SP
            END
      
            SET @n_QtyExpected = @n_QtyExpected - @n_Qty
      
            IF @n_QtyExpected = 0
               BREAK
      
          FETCH NEXT FROM CUR_RESIDUAL_SHORT INTO @c_LOT, @c_ID, @n_Qty
         END
         CLOSE CUR_RESIDUAL_SHORT
         DEALLOCATE CUR_RESIDUAL_SHORT
         
         
   END
   

   -- If not outstanding cycle count task, then insert new cycle count task
   IF NOT EXISTS(SELECT 1 FROM TaskDetail td (NOLOCK) WHERE td.TaskType = 'CC' AND td.FromLoc = @c_TargetLoc
                 AND td.[Status] IN ('0','3') AND td.Storerkey = @c_StorerKey AND td.Sku = @c_SKU)
   BEGIN
      
      -- (ChewKP01)
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
            SET @c_ErrMsg = 'GetKey Failed (isp_TCP_RESIDUAL_SHORT_IN).'
            GOTO QUIT_SP  
      END  
         
      INSERT INTO dbo.TaskDetail
        (TaskDetailKey,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,Qty,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc
        ,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide
        ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey
        ,Message01,Message02,Message03,RefTaskKey,LoadKey,AreaKey,DropID, SystemQty)
        VALUES
        (@c_TaskDetailKey
         ,'CC' -- TaskType
         ,@c_Storerkey
         ,@c_Sku
         ,'' -- Lot
         ,'' -- UOM
         ,0  -- UOMQty
         ,0  -- Qty
         ,@c_TargetLoc
         ,ISNULL(@c_LogicalLocation,'')
         ,'' -- FromID
         ,'' -- ToLoc
         ,'' -- LogicalToLoc
         ,'' -- ToID
         ,'' -- Caseid
         ,'SKU' -- PickMethod -- (ChewKP01)
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
         ,'RESIDUALSHORT'   -- SourceType 
         ,@c_CCKey -- SourceKey -- (ChewKP01)
         ,'' -- PickDetailKey
         ,'' -- OrderKey
         ,'' -- OrderLineNumber
         ,'' -- ListKey
         ,'' -- WaveKey
         ,'' -- ReasonKey
         ,@c_ReasonCode -- Message01
         ,'' -- Message02
         ,'' -- Message03
         ,'' -- RefTaskKey
         ,'' -- LoadKey
         ,@c_AreaKey
         ,'' -- DropID
         ,@n_SystemQty)

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_Status = '5'
            SET @c_ErrMsg = 'Insert TaskDetail Failed (isp_TCP_RESIDUAL_SHORT_IN).'
            GOTO QUIT_SP
         END

   END

   -- Create Alert for Supervisor
   DECLARE @c_AlertMessage NVARCHAR(512)
   SET @c_AlertMessage = 'Residual Short: ' + @c_NewLineChar
   SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' TaskDetailKey: ' + @c_TaskDetailKey + @c_NewLineChar
   SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Task Type: CC ReasonCode: ' + @c_ReasonCode + @c_NewLineChar
   SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' LOC: ' + @c_TargetLoc + @c_NewLineChar
   SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' SKU: ' + @c_Sku + @c_NewLineChar
   SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Expected QTY: ' + CAST(@n_QtyExpected AS NVARCHAR(10)) + @c_NewLineChar
   SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Actual QTY: ' + CAST(@n_QtyActual AS NVARCHAR(10)) + @c_NewLineChar
   SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' DateTime: ' + CONVERT(VARCHAR(20), GETDATE()) + @c_NewLineChar

   SET @b_Success = 1
-- (ChewKP01)   
--   EXEC nspLogAlert
--    @c_modulename   = 'isp_TCP_RESIDUAL_SHORT_IN',
--    @c_AlertMessage = @c_AlertMessage,
--    @n_Severity = 0,
--    @b_success  = @b_Success OUTPUT,
--    @n_err      = @n_Err    OUTPUT,
--    @c_errmsg   = @c_ErrMsg OUTPUT

-- (ChewKP01) 
   EXEC nspLogAlert
        @c_modulename       = 'TCP_RESIDUALSHORT'     
      , @c_AlertMessage     = @c_AlertMessage   
      , @n_Severity         = '5'       
      , @b_success          = @b_success     OUTPUT       
      , @n_err              = @n_Err         OUTPUT         
      , @c_errmsg           = @c_Errmsg      OUTPUT      
      , @c_Activity	       = 'TCP_RESIDUALSHORT'
      , @c_Storerkey	       = @c_Storerkey	   
      , @c_SKU	             = @c_Sku	         
      , @c_UOM	             = ''	         
      , @c_UOMQty	          = ''	      
      , @c_Qty	             = @n_QtyActual
      , @c_Lot	             = ''         
      , @c_Loc	             = @c_TargetLoc	         
      , @c_ID	             = ''            
      , @c_TaskDetailKey	 = @c_MessageNum
      , @c_UCCNo	          = ''

   IF @b_Success <> 1
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Create Alert Fail. ' + @c_errmsg + ' (isp_TCP_RESIDUAL_SHORT_IN).'
      GOTO QUIT_SP
    END

   QUIT_SP:

   IF @b_Debug = 1
   BEGIN
      SELECT 'Update TCPSocket_INLog >> @c_Status : ' + @c_Status
           + ', @c_ErrMsg : ' + @c_ErrMsg
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      ROLLBACK TRAN WCS_RESIDUAL_SHORT
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_TCP_RESIDUAL_SHORT_IN'
   END

   UPDATE dbo.TCPSocket_INLog WITH (ROWLOCK)
   SET STATUS   = @c_Status
     , ErrMsg   = @c_ErrMsg
     , Editdate = GETDATE()
     , EditWho  = SUSER_SNAME()
   WHERE SerialNo = @n_SerialNo

   WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started
      COMMIT TRAN WCS_RESIDUAL_SHORT

   RETURN
END

GO