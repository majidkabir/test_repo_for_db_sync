SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure:  isp_TCP_VC_prTaskLUTGetAssignment                  */    
/* Creation Date: 26-Feb-2013                                           */    
/* Copyright: IDS                                                       */    
/* Written by: Shong                                                    */    
/*                                                                      */    
/* Purposes: The device uses this message to retrieve the assignment    */    
/*           information from the host system                           */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Purposes                                      */    
/* 27-03-2013   ChewKP    Revise (ChewKP01)                             */  
/* 09-02-2015   Shong     Update TaskDetail.StartTime                   */  
/************************************************************************/    
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTGetAssignment] (    
    @c_TranDate      NVARCHAR(20)    
   ,@c_DevSerialNo   NVARCHAR(20)    
   ,@c_OperatorID    NVARCHAR(20)    
   ,@c_MaxNoAssgnmnt NVARCHAR(5)  -- Operator's response to picking region prompt.     
   ,@c_AssignMntType NVARCHAR(2)  -- Type of Assignment, 1 = Normal Assignments, 2 = Chase Assignments    
   ,@n_SerialNo     INT    
   ,@c_RtnMessage   NVARCHAR(500) OUTPUT        
   ,@b_Success      INT = 1 OUTPUT    
   ,@n_Error        INT = 0 OUTPUT    
   ,@c_ErrMsg       NVARCHAR(255) = '' OUTPUT     
    
)    
AS    
BEGIN    
   DECLARE @c_ErrorCode         NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.    
                                            -- 98: Critical error. If this error is received,     
                                            --     the VoiceApplication speaks the error message, and forces the operator to sign off.     
                                            -- 99: Informational error. The VoiceApplication speaks the informational error message,     
                                            --     but does not force the operator to sign off.    
         , @c_Message            NVARCHAR(400)    
         , @c_GroupID            NVARCHAR(100)             
         , @c_IsChase            NVARCHAR(1) -- 0 = not a chase assignment, 1 = is a chase assignment    
         , @c_AssignMntID        NVARCHAR(10)    
         , @c_AssignMntDesc      NVARCHAR(100)    
         , @c_Position           NVARCHAR(10) -- Numeric position where items for the work ID should be placed.    
         , @c_GoalTime           NVARCHAR(10) -- Goal time in minutes for the work ID.    
         , @c_Route              NVARCHAR(10) -- Route number for the work ID.    
         , @c_ActiveTargetCtn    NVARCHAR(2)    
         , @c_PassAssignment     NVARCHAR(1)    
         , @c_SummPromptType     NVARCHAR(1)     -- Identifies what assignment summary to speak, Default=0    
                                             -- 0 = Default task prompt    
                                             -- 1 = No prompt    
                                             -- 2 = Override prompt    
         , @c_OverridePrompt     NVARCHAR(4)  -- The prompt to be spoken for assignment summary if Summary Prompt Type = 2    
         , @c_AreaKey            NVARCHAR(10)    
         , @c_SuggToLoc          NVARCHAR(10)    
         , @c_outstring          NVARCHAR(255)    
         , @c_NextTaskdetailkey  NVARCHAR(10)    
         , @c_TTMTasktype        NVARCHAR(20)    
         , @c_RefKey01           NVARCHAR(20)    
         , @c_RefKey02           NVARCHAR(20)    
         , @c_RefKey03           NVARCHAR(20)    
         , @c_RefKey04           NVARCHAR(20)    
         , @c_RefKey05           NVARCHAR(20)    
         , @c_OrderKey           NVARCHAR(10)  
         , @c_LangCode           NVARCHAR(10)  
         , @c_TaskDetaikey       NVARCHAR(10)  
         , @n_AssignMntSeqNo     INT       
         , @c_StorerKey          NVARCHAR(15)  
                      
    
   SELECT @c_AreaKey   = r.V_String1,     
          @c_SuggToLoc = r.V_Loc    
   FROM RDT.RDTMOBREC r WITH (NOLOCK)    
   WHERE r.UserName = @c_OperatorID     
   AND   r.DeviceID = @c_DevSerialNo    
  
   SELECT @c_LangCode = r.DefaultLangCode             
   FROM rdt.RDTUser r WITH (NOLOCK)   
   WHERE r.UserName = @c_OperatorID    
       
   SELECT @c_ErrMsg = '', @c_NextTaskdetailkey = '', @c_TTMTasktype = ''    
   SET @n_AssignMntSeqNo = 0   
     
   IF EXISTS(SELECT 1   
             FROM VoiceAssignment AS va WITH (NOLOCK)  
             WHERE va.[Status] = '0' AND va.UserName = @c_OperatorID  
               AND va.TableName = 'ORDERS')  
   BEGIN  
      UPDATE VAD  
         SET [Status] = 'X'   
      FROM VoiceAssignmentDetail VAD   
      JOIN VoiceAssignment AS va ON va.AssignmentID = VAD.AssignmentID  
      WHERE va.UserName = @c_OperatorID   
      AND   va.[Status] = '0'   
        
      UPDATE VoiceAssignment  
         SET [Status] = 'X'  
      WHERE [Status] = '0'   
      AND UserName = @c_OperatorID   
      AND TableName = 'ORDERS'  
   END  
  
   EXEC dbo.nspTMTM01    
    @c_sendDelimiter = null    
   ,  @c_ptcid         = 'VOICE'    
   ,  @c_userid        = @c_OperatorID    
   ,  @c_taskId        = 'VOICE'    
   ,  @c_databasename  = NULL    
   ,  @c_appflag       = NULL    
   ,  @c_recordType    = NULL    
   ,  @c_server        = NULL    
   ,  @c_ttm           = NULL    
   ,  @c_areakey01     = @c_AreaKey    
   ,  @c_areakey02     = ''    
   ,  @c_areakey03     = ''    
   ,  @c_areakey04     = ''    
   ,  @c_areakey05     = ''    
   ,  @c_lastloc       = @c_SuggToLoc    
   ,  @c_lasttasktype  = 'VNPK'    
   ,  @c_outstring     = @c_outstring     OUTPUT    
   ,  @b_Success       = @b_Success       OUTPUT    
   ,  @n_err           = @n_Error         OUTPUT    
   ,  @c_errmsg        = @c_ErrMsg        OUTPUT    
   ,  @c_taskdetailkey = @c_NextTaskdetailkey OUTPUT    
   ,  @c_ttmtasktype   = @c_TTMTasktype   OUTPUT    
   ,  @c_RefKey01      = @c_RefKey01      OUTPUT      
   ,  @c_RefKey02      = @c_RefKey02      OUTPUT      
   ,  @c_RefKey03      = @c_RefKey03      OUTPUT      
   ,  @c_RefKey04      = @c_RefKey04      OUTPUT      
   ,  @c_RefKey05      = @c_RefKey05      OUTPUT      
    
   SET @c_ErrorCode = 0     
   SET @c_Message = ''    
       
   UPDATE RDT.rdtMobRec     
      SET V_TaskDetailKey = ''    
   WHERE UserName = @c_OperatorID     
   AND   DeviceID = @c_DevSerialNo    
    
   IF ISNULL(RTRIM(@c_NextTaskdetailkey),'') <> ''    
   BEGIN    
      --SET @c_GroupID  = @c_NextTaskdetailkey  -- (ChewKP01)  
      SELECT   
             @c_GroupID = OrderKey  
           , @c_OrderKey = OrderKey  
           , @c_StorerKey = Storerkey  
      FROM dbo.TaskDetail WITH (NOLOCK)   
      WHERE TaskDetailKey = @c_NextTaskdetailkey  
        
      SET @c_AssignMntDesc = @c_TTMTasktype  
        
      INSERT INTO VoiceAssignment  
      (  GroupID,   DocNo,     TableName,  
         UserName,  [Status],  Storerkey )  
      VALUES  
      (  @c_GroupID, @c_OrderKey, 'ORDERS',  
         @c_OperatorID, '0', @c_StorerKey )    
        
      SELECT @c_AssignMntID = @@IDENTITY  
  
      DECLARE CursorGetPicks CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT td.TaskDetailKey           
      FROM TaskDetail td WITH (NOLOCK)               
      JOIN SKU WITH (NOLOCK) ON SKU.Storerkey = td.Storerkey AND SKU.Sku = td.Sku               
      JOIN LOC l WITH (NOLOCK) ON td.FromLoc = l.Loc              
      JOIN FACILITY f WITH (NOLOCK) ON f.Facility = l.Facility               
      WHERE td.UserKey = @c_OperatorID              
      AND   td.[Status] = '3'               
      Order by l.LocAisle, l.logicallocation, td.sku     
        
      OPEN CursorGetPicks  
        
      FETCH NEXT FROM CursorGetPicks INTO @c_TaskDetaikey   
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         SET @n_AssignMntSeqNo = @n_AssignMntSeqNo + 1  
         INSERT INTO VoiceAssignmentDetail  
         ( AssignmentID, SeqNo, TaskDetailKey, [Status], AddWho, EditWho, LabelPrinted )  
         VALUES  
         ( @c_AssignMntID,  @n_AssignMntSeqNo, @c_TaskDetaikey, '0', @c_OperatorID, @c_OperatorID, 'N')  
  
         UPDATE TASKDETAIL WITH (ROWLOCK)  
         SET StartTime = GETDATE(),   
             EditDate = GETDATE(),   
             TrafficCop = NULL   
         WHERE TaskDetailKey = @c_TaskDetaikey  
           
         FETCH NEXT FROM CursorGetPicks INTO @c_TaskDetaikey  
      END  
      CLOSE CursorGetPicks  
      DEALLOCATE CursorGetPicks  
              
      UPDATE rdt.RDTMOBREC    
         SET V_TaskDetailKey =  CAST(@c_AssignMntID AS NVARCHAR(10))    
      FROM RDT.RDTMOBREC WITH (NOLOCK)    
      WHERE UserName = @c_OperatorID     
      AND   DeviceID = @c_DevSerialNo           
   END    
   ELSE    
   BEGIN    
      SET @c_ErrorCode = '89'    
      --SET @c_Message   = 'No Pick Task'    
      SET @c_Message   = [dbo].[fnc_GetVC_Message](@c_LangCode, 'vc_prTaskLUTGetAssignment_01', N'No Pick Task' ,'','','','','')   
          
   END    
   SET @c_RtnMessage = ''    
       
     
   SET @c_IsChase         = '0'    
   SET @c_Position        = '10.00'    
   SET @c_GoalTime        = '0'    
   SET @c_Route           = ''    
   SET @c_ActiveTargetCtn = '00'    
   SET @c_PassAssignment  = '0'  -- 0 - Np Pass Assignment  
                                 -- 1 - Pass Assignment  
   SET @c_SummPromptType  = '1'    
   SET @c_OverridePrompt  = ''    
          
       
   SET @c_RtnMessage = ISNULL(RTRIM(@c_GroupID),'') + ',' +     
                       ISNULL(@c_IsChase,'') + ',' +    
                       ISNULL(@c_AssignMntID,'') + ',' +    
                       ISNULL(@c_AssignMntDesc,'') + ',' +    
                       ISNULL(@c_Position,'10.00') + ',' +    
                       ISNULL(@c_GoalTime,'1') + ',' +    
                       ISNULL(@c_Route,'1') + ',' +    
                       ISNULL(@c_ActiveTargetCtn,'1') + ',' +    
                       ISNULL(@c_PassAssignment,'1') + ',' +    
                       ISNULL(@c_SummPromptType,'1') + ',' +    
                       ISNULL(@c_OverridePrompt,'0') + ',' +    
                       ISNULL(@c_ErrorCode, 0) + ',' +     
                       ISNULL(@c_Message,'')    
                                                  
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0     
   BEGIN    
      SET @c_RtnMessage = "1,0,42,1030000,1,10.00,0,'00',0,0,,0,"    
   END    
     
  
    
END

GO