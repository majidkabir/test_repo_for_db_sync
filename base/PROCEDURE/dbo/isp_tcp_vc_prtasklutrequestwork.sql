SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
-- prTaskLUTRequestWork('10-31-14 16:45:27.000','572517055','alexkeoh','888','1','1')
/************************************************************************/    
/* Store Procedure:  isp_TCP_VC_prTaskLUTRequestWork                    */    
/* Creation Date: 12-Mar-2013                                           */    
/* Copyright: IDS                                                       */    
/* Written by: Shong                                                    */    
/*                                                                      */    
/* Purposes: Request Work Message Sent to Host System                   */    
/*                                                                      */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Purposes                                      */    
/************************************************************************/    
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTRequestWork] (    
    @c_TranDate            NVARCHAR(20)    
   ,@c_DevSerialNo         NVARCHAR(20)    
   ,@c_OperatorID          NVARCHAR(20)    
   ,@c_WorkID              NVARCHAR(10)    
   ,@n_PartialWorkFlag     INT -- 0 = the operator specified the whole work identifier value
                               -- 1 = the operator specified a partial work identifier value   
   ,@n_AssignmentType      INT -- 1 = Normal Assignments
                               -- 2 = Chase Assignments
   ,@n_SerialNo            INT   
   ,@c_RtnMessage          NVARCHAR(4000) OUTPUT        
   ,@b_Success             INT = 1 OUTPUT    
   ,@n_Error               INT = 0 OUTPUT    
   ,@c_ErrMsg              NVARCHAR(255) = '' OUTPUT     
    
)    
AS    
BEGIN    
   DECLARE @c_ErrorCode         NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.    
                                             --  2 = This error has the same effect as error code 99.
                                             --  3 = This error informs VoiceApplication to quit prompting for additional work IDs. 
                                             --      On receiving this error, the VoiceApplication will send the Get Assignment message.
                                             --  4 = This error code is returned when the spoken/scanned work ID sent to the host 
                                             --  matches to multiple work IDs in the host system. On receiving this error, 
                                             --  the operator can select one of the returned matches or specify a different work ID.
         , @c_Message            NVARCHAR(400)    
         , @c_SysContainerID     NVARCHAR(20)    
         , @c_TaskDetaikey       NVARCHAR(10)  
         , @c_SpokenContainerID  NVARCHAR(20)  
         , @n_AssignMntSeqNo     INT
         , @c_NextTaskdetailkey  NVARCHAR(10)  
         , @c_Printed            NVARCHAR(1)  
         , @c_FromLoc            NVARCHAR(10)  
         , @n_Counter            INT
         , @c_GroupID            NVARCHAR(20) 
         , @c_OrderKey           NVARCHAR(10) 
         , @c_LangCode           NVARCHAR(10)     
         , @c_StorerKey          NVARCHAR(15)  
         , @c_TTMTasktype        NVARCHAR(10)   
         , @c_AssignMntID        NVARCHAR(10)    
         , @c_AssignMntDesc      NVARCHAR(60)
         , @c_AreaKey            NVARCHAR(10)

   SET @c_LangCode = 'ENG'       
   SET @c_RtnMessage = ''    
   SET @c_FromLoc = ''  
   SET @n_Counter = 1  
   SET @c_SysContainerID = ''
   SET @c_SpokenContainerID = ''
   SET @c_Printed = '0'  
   
   SET @c_ErrorCode = 0   
   SET @c_Message = ''  

   SELECT @c_LangCode = r.DefaultLangCode          
   FROM rdt.RDTUser r (NOLOCK)          
   WHERE r.UserName = @c_OperatorID   

   SELECT @c_AreaKey   = r.V_String1 
   FROM RDT.RDTMOBREC r WITH (NOLOCK)  
   WHERE r.UserName = @c_OperatorID   
   AND   r.DeviceID = @c_DevSerialNo  
           
   UPDATE RDT.rdtMobRec   
      SET V_TaskDetailKey = ''  
   WHERE UserName = @c_OperatorID   
   AND   DeviceID = @c_DevSerialNo  
  
   SELECT TOP 1 @c_NextTaskdetailkey = TaskDetail.TaskDetailKey 
   FROM TaskDetail WITH (NOLOCK)
   INNER JOIN LOC WITH (NOLOCK)       
            ON TaskDetail.FromLoc = Loc.Loc                           
   INNER JOIN AREADETAIL WITH (NOLOCK)       
            ON AreaDetail.Putawayzone = Loc.PutAwayZone                    
   INNER JOIN TaskManagerUserDetail WITH (NOLOCK)       
            ON TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey       
   WHERE  TaskManagerUserDetail.UserKey = @c_OperatorID AND      
          TaskManagerUserDetail.PermissionType = 'VNPK' AND      
          TaskManagerUserDetail.Permission = '1' AND      
          TaskDetail.TASKTYPE = 'VNPK' AND      
          TaskDetail.STATUS = '0' AND       
          TaskDetail.Userkey = '' AND       
          TaskManagerUserDetail.AreaKey =       
            CASE WHEN ISNULL(RTRIM(@c_AreaKey),'') = '' THEN AreaDetail.AreaKey ELSE @c_AreaKey END AND  
          TaskDetail.OrderKey LIKE N'%' + RTRIM(@c_WorkID) AND 
          NOT EXISTS(SELECT 1 FROM TaskDetail AS TD2 WITH (NOLOCK)
                    WHERE TD2.OrderKey = TaskDetail.OrderKey 
                    AND   TD2.[Status] = '3'
                    AND   TD2.UserKey <> @c_OperatorID)
   
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
         ( AssignmentID, SeqNo, TaskDetailKey, [Status], AddWho, EditWho )
         VALUES
         ( @c_AssignMntID,  @n_AssignMntSeqNo, @c_TaskDetaikey, '0', @c_OperatorID, @c_OperatorID)
            
         FETCH NEXT FROM CursorGetPicks INTO @c_TaskDetaikey
      END
      CLOSE CursorGetPicks
      DEALLOCATE CursorGetPicks
            
      UPDATE rdt.RDTMOBREC  
         SET V_TaskDetailKey =  CAST(@c_AssignMntID AS NVARCHAR(10))  
      FROM RDT.RDTMOBREC WITH (NOLOCK)  
      WHERE UserName = @c_OperatorID   
      AND   DeviceID = @c_DevSerialNo  
      
      SET @c_RtnMessage = RTRIM(@c_RtnMessage) +     
          ISNULL(RTRIM(@c_GroupID), '') + 
          ',0,'       
   END  
   ELSE  
   BEGIN  
      SET @c_ErrorCode = '2'  
      SET @c_Message   = [dbo].[fnc_GetVC_Message](@c_LangCode, 'vc_prTaskLUTRequestWork_01', N'Work ID Not Found' ,'','','','','') 
   END       
        
      SET @c_RtnMessage = ISNULL(RTRIM(@c_WorkID),'') + ',' +   
                          ISNULL(@c_ErrorCode,'') + ',' +  
                          ISNULL(@c_Message,'') 
                                          
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0     
   BEGIN    
      SET @c_RtnMessage = ',0,'     
   END    
   

     
     
    
END

GO