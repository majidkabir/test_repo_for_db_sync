SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
 /* Store Procedure:  isp_TCP_VC_prTaskLUTGetDeliveryLocation            */      
 /* Creation Date: 01-Apr-2013                                           */      
 /* Copyright: IDS                                                       */      
 /* Written by: ChewKP                                                   */      
 /*                                                                      */      
 /* Purposes: The message returns the regions where the operator is      */      
 /*           allowed to perform the selection function.                 */      
 /*                                                                      */      
 /* Updates:                                                             */      
 /* Date         Author    Purposes                                      */      
/************************************************************************/      
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTGetDeliveryLocation] (      
    @c_TranDate       NVARCHAR(20)      
   ,@c_DevSerialNo    NVARCHAR(20)      
   ,@c_OperatorID     NVARCHAR(20)      
   ,@c_GroupID        NVARCHAR(20)  
   ,@c_AssignmentID   NVARCHAR(10)      
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
         , @c_DeliveryLoc     NVARCHAR(10)  
         , @n_DeliveryLocCheckDigit INT  
         , @n_DirectLoad      INT   -- 0 - Not a Direct Load  
                                            -- 1 - Direct Load  
         , @n_AllowedOverride NVARCHAR(1)   -- 0 - Not Override  
                                            -- 1 - Allow Override  
         , @c_License         NVARCHAR(10)      
         , @c_LangCode        NVARCHAR(10)      
         , @c_PickMessage     NVARCHAR(250)  
         , @c_TaskDetailKey  NVARCHAR(10)             
  
   SET @c_LangCode = 'ENG'                  
   SET @c_DeliveryLoc = ''  
   SET @n_DeliveryLocCheckDigit = 0  
   SET @n_DirectLoad = 0  
   SET @n_AllowedOverride = 0  
   SET @c_License =''  
   SET @c_PickMessage =''  
     
   SELECT @c_LangCode = r.DefaultLangCode          
   FROM rdt.RDTUser r (NOLOCK)          
   WHERE r.UserName = @c_OperatorID     
     
     
   SELECT TOP 1   
         @c_DeliveryLoc = ToLoc  
   FROM VoiceAssignment AS va WITH (NOLOCK)      
   JOIN VoiceAssignmentDetail AS vad WITH (NOLOCK) ON vad.AssignmentID = va.AssignmentID  
   JOIN TaskDetail td WITH (NOLOCK)ON vad.TaskDetailKey = td.TaskDetailKey                    
   WHERE va.GroupID  = @c_GroupID            
   AND   vad.AssignmentID = @c_AssignmentID   
     
   IF @c_DeliveryLoc = ''  
   BEGIN  
      SET @c_PickMessage = [dbo].[fnc_GetVC_Message](@c_LangCode, 'vc_prTaskLUTGetDeliveryLocation_01', N'Delivery Location Not Found','','','','','')            
      SET @c_RtnMessage =  ',,0,0,,0,' + @c_PickMessage  
      GOTO QUIT   
   END  
     
   SET @c_RtnMessage = ISNULL(RTRIM(@c_DeliveryLoc)                     ,'') + ',' +    
                       ISNULL(RTRIM(@n_DeliveryLocCheckDigit)           ,'') + ',' +    
                       ISNULL(RTRIM(@n_DirectLoad)                      ,'') + ',' +    
                       ISNULL(RTRIM(@n_AllowedOverride)                 ,'') + ',' +    
                       ISNULL(RTRIM(@c_License)                         ,'') + ',' +    
                       ISNULL(@c_ErrorCode                              ,'0') + ',' +    
                       ISNULL(@c_ErrMsg                                 ,'')    
     
     
   QUIT:  
         
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0       
   BEGIN      
      SET @c_RtnMessage = ",,0,0,,0,"       
   END      
     
   
      
END

GO