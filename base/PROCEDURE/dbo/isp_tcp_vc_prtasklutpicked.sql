SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_TCP_VC_prTaskLUTPicked                         */  
/* Creation Date: 26-Feb-2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purposes: The message returns the regions where the operator is      */  
/*           allowed to perform the selection function.                 */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */ 
/* 09-02-2015   Shong     Update StartTime and EndTime for TaskDetail   */ 
/************************************************************************/  
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTPicked] (  
    @c_TranDate       NVARCHAR(20)  
   ,@c_DevSerialNo    NVARCHAR(20)  
   ,@c_OperatorID     NVARCHAR(20) 

   ,@c_GroupID        NVARCHAR(20)  
   ,@c_AssignmentID   NVARCHAR(10)  
   ,@c_Loc            NVARCHAR(10)  
   ,@n_QtyPicked      INT  
   ,@c_PickStatus     NVARCHAR(10)   -- 1 = picked, 0 = not picked
   ,@c_CartonID       NVARCHAR(20)  
   ,@c_Sequence       NVARCHAR(10)  
   ,@c_BatchNo        NVARCHAR(20)  
   ,@c_VariableWeight NVARCHAR(20)  
   ,@c_SerialNoCapt   NVARCHAR(20)  
   ,@n_SerialNo       INT  
   ,@c_RtnMessage     NVARCHAR(500) OUTPUT      
   ,@b_Success        INT = 1 OUTPUT  
   ,@n_Error          INT = 0 OUTPUT  
   ,@c_ErrMsg         NVARCHAR(255) = '' OUTPUT   
  
)  
AS  
BEGIN  
   DECLARE @c_ErrorCode         NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.  
                                            -- 98: Critical error. If this error is received,   
                                            --     the VoiceApplication speaks the error message, and forces the operator to sign off.   
                                            -- 99: Informational error. The VoiceApplication speaks the informational error message,   
                                            --     but does not force the operator to sign off.  
         , @c_Message         NVARCHAR(400)  
         , @c_RegionNo        NVARCHAR(5)  -- Operator's response to picking region prompt.           
         , @c_RegionName      NVARCHAR(100)  
         , @c_StorerKey       NVARCHAR(15)  
         , @c_SKU             NVARCHAR(20)  
         , @n_TaskQty         INT  
         , @c_CaptureLottable NVARCHAR(10)  
         , @c_LOT             NVARCHAR(10)  
         , @c_ListName        NVARCHAR(10)  
         , @c_SysLottable     NVARCHAR(20)  
         , @d_Lottable04      DATETIME   
         , @d_Lottable05      DATETIME   
         , @c_PickDetailKey   NVARCHAR(10)  
         , @n_PickDetailQty   INT   
         , @n_QtyToTake       INT   
         , @c_NewPickDetailKey NVARCHAR(10)  
         , @n_Continue        INT   
         , @c_Status          NVARCHAR(1)  
         , @b_LotFound        INT   
         
         -- (ChewKP01)
         , @n_Mobile          INT            
         , @n_Func            INT
         , @c_Facility        NVARCHAR(5)
         , @c_FromLoc         NVARCHAR(10)
         , @c_FromID          NVARCHAR(18)
         , @c_ToLoc           NVARCHAR(10)
         , @c_ToID            NVARCHAR(18)
         , @c_TaskDetailKey   NVARCHAR(10)
         , @c_PrintLabel      NVARCHAR(5)
         , @c_DropID          NVARCHAR(20)  
         , @n_QtyRemain       INT
         , @c_ReasonCode      NVARCHAR(20) 
         , @c_NextTaskDetKey  NVARCHAR(10)     
           
   -- Sample prTaskLUTPicked('03-12-13 15:29:59.990','572517045','shong','0000038538','0000038538','A1AH009A5','4','1','','1','','','')  
   SET @c_StorerKey = ''
   SET @c_Facility = ''
   SET @n_Func = 0 
   SET @n_Mobile = 0 
   
   SET @n_QtyRemain = @n_QtyPicked
   SET @c_ReasonCode = ''
   
   
   SELECT @n_Mobile   = Mobile
         ,@n_Func     = Func
         ,@c_Facility = Facility
         ,@c_DropID   = V_CaseID 
   FROM rdt.rdtMobRec WITH (NOLOCK)   
   WHERE DeviceID = @c_DevSerialNo  
   AND UserName = @c_OperatorID

   SET @c_TaskDetailKey = ''
   SELECT @c_TaskDetailKey = vad.TaskDetailKey 
   FROM   VoiceAssignmentDetail AS vad WITH (NOLOCK)
   WHERE  vad.AssignmentID = @c_AssignmentID 
   AND    vad.SeqNo = @c_Sequence
   
   IF ISNULL(RTRIM(@c_TaskDetailKey), '') = ''
      GOTO QUIT_SP      

   IF NOT EXISTS(SELECT 1 FROM TaskDetail AS td WITH (NOLOCK) 
                 WHERE td.TaskDetailKey = @c_TaskDetailKey)
   BEGIN
      GOTO QUIT_SP 
   END
   
   SELECT @c_StorerKey = td.Storerkey  
         ,@c_SKU = td.Sku  
         ,@n_TaskQty = td.Qty   
         ,@c_FromLoc = FromLoc
         ,@c_FromID  = FromId
         ,@c_ToLoc   = ToLoc
         ,@c_ToID    = ToID
   FROM TaskDetail td WITH (NOLOCK)  
   WHERE td.TaskDetailKey = @c_TaskDetailKey   
        
  
   SET @c_CaptureLottable = '0'  
   SELECT @c_CaptureLottable = ISNULL(sc.SValue,'0')    
   FROM StorerConfig sc WITH (NOLOCK)   
   WHERE sc.StorerKey = @c_StorerKey  
   AND   sc.ConfigKey = 'VoicePK_CaptureLottable'  
  
   --IF @c_CaptureLottable = '0'  
   BEGIN  
      DECLARE CUR_PickDetail_Records CURSOR FAST_FORWARD READ_ONLY FOR   
      SELECT P.PickDetailKey, P.Qty, P.LOT   
      FROM PICKDETAIL p WITH (NOLOCK)   
      JOIN LOTATTRIBUTE l WITH (NOLOCK) ON p.Lot = l.Lot    
      WHERE  p.TaskDetailKey = @c_TaskDetailKey   
      AND    p.Storerkey = @c_StorerKey   
      AND    p.SKU = @c_SKU   
      AND    p.[Status] < '5'   
        
      OPEN CUR_PickDetail_Records  
        
      FETCH NEXT FROM CUR_PickDetail_Records INTO @c_PickDetailKey, @n_PickDetailQty, @c_LOT   
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         IF @n_QtyRemain <= 0   
         BEGIN  
            BREAK  
         END   
         SET @n_QtyToTake = 0   
           
         IF @n_PickDetailQty > @n_QtyRemain  
            SET @n_QtyToTake = @n_QtyRemain  
         ELSE  
            SET @n_QtyToTake = @n_PickDetailQty  
           
         IF @n_QtyToTake < @n_PickDetailQty  
         BEGIN  
            SET @c_ReasonCode = 'SHORT'
            
            -- split line   
            EXECUTE dbo.nspg_GetKey  
            'PICKDETAILKEY',  
            10 ,  
            @c_NewPickDetailKey OUTPUT,  
            @b_Success          OUTPUT,  
            @n_Error            OUTPUT,  
            @c_ErrMsg           OUTPUT  
  
            IF @b_Success <> 1  
            BEGIN  
               SET @n_Continue = 3  
               SET @c_ErrMsg = 'Get PickDetail Key Failed (isp_TCP_VC_prTaskLUTPicked).'  
               GOTO QUIT_SP  
            END  
              
            INSERT INTO dbo.PICKDETAIL (  
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,  
               Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,  
               DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,  
               QTY, TaskDetailKey,   
               TrafficCop,  
               OptimizeCop)  
            SELECT  
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,  
               (@n_PickDetailQty - @n_QtyToTake),   
               QTYMoved,  
               '4', -- Status  
               @c_DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,  
               DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @c_NewPickDetailKey,  
               (@n_PickDetailQty - @n_QtyToTake), -- QTY  
               TaskDetailKey,   
               NULL, --TrafficCop,  
               '1'   --OptimizeCop  
            FROM dbo.PickDetail WITH (NOLOCK)  
            WHERE PickDetailKey = @c_PickDetailKey                 
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_Continue = 3  
               SET @c_ErrMsg = 'Insert PickDetail Failed (isp_TCP_VC_prTaskLUTPicked).'  
               GOTO QUIT_SP  
            END  
            
            UPDATE dbo.PickDetail WITH (ROWLOCK)  
            SET QTY        = @n_QtyToTake,  
                Trafficcop = NULL
            WHERE PickDetailKey = @c_PickDetailKey  
     
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_Continue = 3  
               SET @c_ErrMsg = 'Update PickDetail Failed (isp_TCP_VC_prTaskODRPicked).'  
               GOTO QUIT_SP  
            END
            
         END  
         
         UPDATE dbo.PickDetail WITH (ROWLOCK)  
            SET [STATUS]   = '5', 
             DropID = @c_DropID    
         WHERE PickDetailKey = @c_PickDetailKey  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Continue = 3  
            SET @c_ErrMsg = 'Update PickDetail Failed (isp_TCP_VC_prTaskLUTPicked).'  
            GOTO QUIT_SP  
         END  
         
         -- (ChewKP01)
         --Add to RDT.RDTEventLog
         EXEC RDT.rdt_STD_EventLog
              @cActionType      = '3', 
              @cUserID          = @c_OperatorID,
              @nMobileNo        = @n_Mobile,
              @nFunctionID      = @n_Func,
              @cFacility        = @c_Facility,
              @cStorerKey       = @c_StorerKey,
              @cLocation        = @c_FromLoc,  
              @cToLocation      = @c_ToLoc,  
              @cID              = @c_FromID,  
              @cToID            = @c_ToID,  
              @cSKU             = @c_SKU,  
              @nQTY             = @n_QtyRemain,
              @cLot             = @c_LOT,  
              @cRefNo1          = @c_DevSerialNo,
              @cTaskDetailKey   = @c_TaskDetailKey
              
                
         SET @n_QtyRemain = @n_QtyRemain - @n_QtyToTake  
           
  
         GET_NEXT_Pickdetail:           
         FETCH NEXT FROM CUR_PickDetail_Records INTO @c_PickDetailKey, @n_PickDetailQty, @c_LOT   
      END  
      CLOSE CUR_PickDetail_Records  
      DEALLOCATE CUR_PickDetail_Records              
   END   
   
      UPDATE TASKDETAIL   
         SET [Status] = '9' 
            ,Trafficcop = NULL
            ,DropID = @c_DropID
            ,Qty = CASE WHEN @n_TaskQty > @n_QtyPicked THEN @n_QtyPicked ELSE Qty END 
            ,ReasonKey = @c_ReasonCode
            ,EndTime = GETDATE() 
      WHERE TaskDetailKey = @c_TaskDetailKey   
      AND   UserKey = @c_OperatorID   
      AND   [Status] = '3'    
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET @c_ErrMsg = 'Update TASKDETAIL Failed (isp_TCP_VC_prTaskODRPicked).'  
         GOTO QUIT_SP  
      END  
                      
      UPDATE VoiceAssignmentDetail
      SET [Status] = '9', EditDate = GETDATE(), EditWho = @c_OperatorID, 
          LabelPrinted = CASE WHEN ISNULL(RTRIM(@c_DropID), '') <> '' THEN 'Y' ELSE 'N' END,  
          Qty = @n_QtyPicked  
      WHERE AssignmentID = @c_AssignmentID 
      AND   SeqNo = @c_Sequence 
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET @c_ErrMsg = 'Update Voice Assignment Detail Failed (isp_TCP_VC_prTaskODRPicked).'  
         GOTO QUIT_SP  
      END             
      
      IF NOT EXISTS (SELECT 1 FROM VoiceAssignmentDetail WITH (NOLOCK) WHERE AssignmentID = @c_AssignmentID AND [Status] = '0')
      BEGIN
         UPDATE VoiceAssignment
         SET
             [Status] = '9', EditDate = GETDATE()
         WHERE AssignmentID = @c_AssignmentID
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Continue = 3  
            SET @c_ErrMsg = 'Update Voice Assignment Failed (isp_TCP_VC_prTaskODRPicked).'  
            GOTO QUIT_SP  
         END             
      END
      
      SET @c_NextTaskDetKey = ''
      SELECT TOP 1 
             @c_NextTaskDetKey = vad.TaskDetailKey 
      FROM   VoiceAssignmentDetail AS vad WITH (NOLOCK)
      WHERE  vad.AssignmentID = @c_AssignmentID 
      AND    vad.[Status] = '0'
      AND    vad.SeqNo > @c_Sequence 
      ORDER BY vad.SeqNo
      IF ISNULL(RTRIM(@c_NextTaskDetKey), '') <> '' 
      BEGIN
         UPDATE TASKDETAIL WITH (ROWLOCK)
         SET StartTime = GETDATE(), 
             EditDate  = GETDATE(),
             TrafficCop = NULL
         WHERE TaskDetailKey = @c_NextTaskDetKey 
      END

QUIT_SP:     
   SET @c_RtnMessage = ''  
     
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0   
   BEGIN   
      SET @c_RtnMessage = "0,"   
   END  
   

  
END

GO