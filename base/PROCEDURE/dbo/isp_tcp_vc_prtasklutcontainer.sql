SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store Procedure:  isp_TCP_VC_prTaskLUTContainer                      */      
/* Creation Date: 12-Mar-2013                                           */      
/* Copyright: IDS                                                       */      
/* Written by: ChewKP                                                   */      
/*                                                                      */      
/* Purposes: prTaskLutContainer                                         */      
/*                                                                      */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author    Purposes                                      */      
/************************************************************************/      
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTContainer] (      
    @c_TranDate            NVARCHAR(20)      
   ,@c_DevSerialNo         NVARCHAR(20)      
   ,@c_OperatorID          NVARCHAR(20)      
   ,@c_GroupID             NVARCHAR(10)      
   ,@c_AssignmentID        NVARCHAR(10)     
   ,@c_TargetContainer     NVARCHAR(20)  -- Target Container  
   ,@c_SysGenContainerID   NVARCHAR(20)  -- System-Generated Container ID   
   ,@c_OprtSpecifContainer NVARCHAR(20)  -- Operator-Specified Container ID   
   ,@c_Operation           NVARCHAR(1)   -- 1 - Close , 2 - Open , 3 - Pre-Created    
   ,@n_NoOfLabels          INT    
   ,@n_SerialNo            INT     
   ,@c_RtnMessage          NVARCHAR(4000) OUTPUT   
   ,@b_Success             INT = 1 OUTPUT      
   ,@n_Error               INT = 0 OUTPUT      
   ,@c_ErrMsg              NVARCHAR(255) = '' OUTPUT       
      
)      
AS      
BEGIN      
   DECLARE @c_ErrorCode         NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.      
                                            -- 98: Critical error. If this error is received,       
                                            --     the VoiceApplication speaks the error message, and forces the operator to sign off.       
                                            -- 99: Informational error. The VoiceApplication speaks the informational error message,       
                                            --     but does not force the operator to sign off.      
         , @c_Message            NVARCHAR(400)      
         , @c_SysContainerID     NVARCHAR(20)      
         , @c_ScanContainerID    NVARCHAR(20)    
         , @c_SpokenContainerID  NVARCHAR(20)    
         , @c_TaskDescr          NVARCHAR(50)    
         , @c_ContainerStatus    NVARCHAR(1)    
         , @c_Printed            NVARCHAR(1)    
         , @c_FromLoc            NVARCHAR(10)    
         , @n_Counter            INT    
         , @c_PalletID           NVARCHAR(18)   
         , @c_VoiceProfileNo     NVARCHAR(10)        
         , @c_PrintLabel         NVARCHAR(50)               
       
   SET @c_RtnMessage = ''      
   SET @c_FromLoc = ''    
   SET @n_Counter = 1    
   SET @c_SysContainerID = ''  
   SET @c_SpokenContainerID = ''  
   SET @c_Printed = '0'    
  
   SELECT @c_VoiceProfileNo = VoiceProfileNo   
   FROM   RDT.RDTUser WITH (NOLOCK)   
   WHERE  UserName = @c_OperatorID  
  
   -- 0 = 'Do Not Print'             
   -- 1 = 'When Container Open'      
   -- 2 = 'When Container Closed'    
   SELECT @c_PrintLabel = VC.ParameterValue   
   FROM VoiceConfig VC WITH (NOLOCK)  
   JOIN CODELKUP AS C_MODULE WITH (NOLOCK) ON C_MODULE.ListName = 'VOICEMODUL' AND C_MODULE.SHORT = VC.ModuleNo   
   JOIN CODELKUP AS C_Parm WITH (NOLOCK) ON C_Parm.LISTNAME = C_MODULE.UDF01 AND vc.ParameterCode = C_Parm.Code   
   WHERE C_MODULE.Code = 'PICKING'   
   AND   VC.ProfileNo = @c_VoiceProfileNo   
   AND   VC.ParameterCode = '07'  
        
   IF @c_Operation  = '2' -- Open Container   
   BEGIN    
      IF ISNULL(RTRIM(@c_TargetContainer),'') <> ''    
      BEGIN     
           
         SET @c_TaskDescr = @c_OprtSpecifContainer  
  
         UPDATE rdt.rdtMobRec       
            SET  V_CaseID =  @c_TargetContainer   
         WHERE UserName = @c_OperatorID       
         AND DeviceID = @c_DevSerialNo  
                                     
         SET @c_ContainerStatus = 'O'    
                   
         IF NOT EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @c_TargetContainer )  
         BEGIN                   
            INSERT INTO dbo.DropID ( DropID, DropLoc, AdditionalLoc, DropIDType, LabelPrinted, ManifestPrinted, Status )     
            VALUES ( @c_TargetContainer, '', '', 'C', '0', '0', '0')     
         END      
           
         SET @c_ErrorCode = 0       
         SET @c_Message = ''      
            
         SET @c_SpokenContainerID = @c_TargetContainer   
                        
         SET @c_RtnMessage = ISNULL(@c_SysContainerID,'') + ',' +      
                             ISNULL(@c_ScanContainerID,'') + ',' +    -- Scanned Container Validation    
                             ISNULL(@c_SpokenContainerID,'') + ',' +  -- Spoken Container Validation    
                             ISNULL(@c_AssignmentID,'') + ',' +      
                             ISNULL(@c_TaskDescr,'') + ',' +      
                             ISNULL(@c_TargetContainer,'') + ',' +      
                             ISNULL(@c_ContainerStatus    ,'') + ',' +      
                             ISNULL(@c_Printed,'') + ',' +      
                             ISNULL(@c_ErrorCode,'0') + ',' +      
                             ISNULL(@c_ErrMsg,'')      
      END      
      ELSE  
      BEGIN  
  
         EXECUTE nspg_getkey    
         'PALLETID',    
         9,    
         @c_PalletID OUTPUT,    
         @b_success OUTPUT,    
         @n_error OUTPUT,    
         @c_errmsg OUTPUT   
    
         SET @c_PalletID = 'P' + RTRIM(@c_PalletID)  
  
         IF NOT EXISTS(SELECT 1 FROM DROPID WHERE Dropid = @c_PalletID)  
         BEGIN  
            INSERT INTO DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey )    
            VALUES (@c_PalletID , '' , 'PALLETID', '0' , @c_GroupID)               
         END  
  
           
         -- Generate Container ID after Job Assigned  
--         IF @c_PrintLabel = 'When Container Closed'  
--         BEGIN  
--            UPDATE TASKDETAIL   
--               SET DropID = @c_PalletID, TrafficCop = NULL   
--            FROM TASKDETAIL   
--            JOIN VoiceAssignmentDetail AS vad WITH (NOLOCK) ON vad.TaskDetailKey = TASKDETAIL.TaskDetailKey  
--            WHERE vad.AssignmentID = @c_AssignmentID   
--            AND   vad.LabelPrinted <> 'Y'   
--            AND   DropID = ''   
--              
--            UPDATE PICKDETAIL   
--              SET DropID =  @c_PalletID, TrafficCop = NULL  
--            FROM PickDetail   
--            JOIN VoiceAssignmentDetail AS vad WITH (NOLOCK) ON vad.TaskDetailKey = PickDetail.TaskDetailKey   
--            WHERE vad.AssignmentID = @c_AssignmentID   
--            AND   vad.LabelPrinted <> 'Y'   
--            AND   DropID = ''   
--              
--            UPDATE VoiceAssignmentDetail  
--               SET  LabelPrinted = 'Y'             
--            WHERE AssignmentID = @c_AssignmentID   
--            AND   LabelPrinted <> 'Y'   
--         END  
--         ELSE  
         BEGIN  
            UPDATE rdt.rdtMobRec       
               SET  V_CaseID =  @c_PalletID   
            WHERE UserName = @c_OperatorID       
            AND DeviceID = @c_DevSerialNo              
         END  
  
  
         SET @c_SysContainerID = @c_PalletID   
         SET @c_SpokenContainerID = @c_SysContainerID  
         SET @c_TargetContainer = @c_SysContainerID   
         SET @c_RtnMessage = ISNULL(@c_SysContainerID,'') + ',' +      
                             ISNULL(@c_ScanContainerID,'') + ',' +    -- Scanned Container Validation    
                             ISNULL(@c_SpokenContainerID,'') + ',' +  -- Spoken Container Validation    
             ISNULL(@c_AssignmentID,'') + ',' +      
                             ISNULL(@c_TaskDescr,'') + ',' +      
                             ISNULL(@c_TargetContainer,'') + ',' +      
                             ISNULL(@c_ContainerStatus    ,'') + ',' +      
                             ISNULL(@c_Printed            ,'') + ',' +      
                             ISNULL(@c_ErrorCode          ,'0') + ',' +      
                             ISNULL(@c_ErrMsg             ,'')             
      END  
   END -- IF @c_Operation  = '2'         
   ELSE IF @c_Operation = '0'  -- 0 = Return a list of containers for the specified group ID  
   BEGIN    
      --SET @c_SpokenContainerID = '0'    
  
      SET @c_SysContainerID = ''  
      SET @c_TargetContainer         = ''  
      SET @c_TaskDescr      = ''  
      SET @c_ContainerStatus= '1'  
        
        
      SET @c_RtnMessage = ISNULL(@c_SysContainerID  ,'') + ',' +      
                       ISNULL(@c_TargetContainer             ,'') + ',' +      
                       ISNULL(@c_TargetContainer             ,'') + ',' +      
                       ISNULL(@c_AssignmentID      ,'') + ',' +      
                       ISNULL(@c_TaskDescr     ,'') + ',' +      
                       ISNULL(@c_TargetContainer             ,'') + ',' +      
                       ISNULL(@c_ContainerStatus    ,'') + ',' +      
                       ISNULL(@c_Printed            ,'') + ',' +      
                       ISNULL(@c_ErrorCode          ,'0') + ',' +      
                       ISNULL(@c_ErrMsg             ,'')      
          
--      DECLARE CursorLutContainer CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
--      SELECT DISTINCT TD.DropID,   
--      CASE WHEN ISNULL(D.LabelPrinted,'N') = 'Y' THEN '1'   
--           ELSE '0'  
--      END,   
--      CASE WHEN ISNULL(D.[Status],'0') = '9' THEN 'C'   
--           WHEN D.[Status] = '0' THEN 'A'  
--           ELSE 'O'  
--      END     
--      FROM VoiceAssignment AS va WITH (NOLOCK)            
--      JOIN VoiceAssignmentDetail AS vad WITH (NOLOCK) ON vad.AssignmentID = va.AssignmentID   
--      JOIN TaskDetail AS TD WITH (NOLOCK) ON TD.TaskDetailKey = vad.TaskDetailKey   
--      LEFT OUTER JOIN Dropid AS d WITH (NOLOCK) ON d.DropID = TD.DropID   
--      WHERE va.GroupID = @c_GroupID   
--      AND   TD.[Status] = '3'               
--      AND   TD.DropID <> ''    
--      Order By TD.DropID  
--          
--      OPEN CursorLutContainer                
--          
--      FETCH NEXT FROM CursorLutContainer INTO @c_TargetContainer, @c_Printed, @c_ContainerStatus  
--          
--      WHILE @@FETCH_STATUS <> -1         
--      BEGIN    
--         SELECT @c_ContainerStatus = CASE WHEN Status = '9' THEN 'C' ELSE 'O' END     
--         FROM dbo.DropID WITH (NOLOCK)   
--         WHERE DropID = @c_TargetContainer  
--                    
--         IF @n_Counter = '1'    
--         BEGIN    
--            SET @c_RtnMessage = ISNULL(@c_SysContainerID  ,'') + ',' +      
--                             ISNULL(@c_TargetContainer             ,'') + ',' +      
--                             ISNULL(@c_TargetContainer             ,'') + ',' +      
--                             ISNULL(@c_AssignmentID      ,'') + ',' +      
--                             ISNULL(@c_TaskDescr     ,'') + ',' +      
--                             ISNULL(@c_TargetContainer             ,'') + ',' +      
--                             ISNULL(@c_ContainerStatus    ,'') + ',' +      
--                             ISNULL(@c_Printed            ,'') + ',' +      
--                             ISNULL(@c_ErrorCode          ,'0') + ',' +      
--                             ISNULL(@c_ErrMsg             ,'')      
--                                           
--         END    
--         ELSE    
--         BEGIN    
--             SET @c_RtnMessage = @c_RtnMessage + '<CR><LF>' +     
--                             ISNULL(@c_SysContainerID     ,'') + ',' +      
--                             ISNULL(@c_ScanContainerID    ,'') + ',' +      
--                             ISNULL(@c_SpokenContainerID  ,'') + ',' +      
--                             ISNULL(@c_AssignmentID      ,'') + ',' +      
--                             ISNULL(@c_TaskDescr     ,'') + ',' +      
--                             ISNULL(@c_TargetContainer             ,'') + ',' +      
--                             ISNULL(@c_ContainerStatus    ,'') + ',' +      
--                             ISNULL(@c_Printed            ,'') + ',' +      
--                             ISNULL(@c_ErrorCode          ,'0') + ',' +      
--                             ISNULL(@c_ErrMsg             ,'')                                        
--         END    
--             
--         SET @n_Counter = @n_Counter + 1    
--             
--        FETCH NEXT FROM CursorLutContainer INTO @c_TargetContainer, @c_Printed, @c_ContainerStatus  
--             
--      END    
--      CLOSE CursorLutContainer                
--      DEALLOCATE CursorLutContainer       
   END    
   ELSE    
   BEGIN    
         SET @c_RtnMessage = ',,,,,,,,0,'   -- If New Container No List to Sent    
   END    
       
       
                                                    
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0       
   BEGIN      
      SET @c_RtnMessage = ',,,,,,,,0,'       
   END      
     
      
END

GO