SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
 /* Store Procedure:  isp_TCP_VC_prTaskODRUpdateStatus                   */  
 /* Creation Date: 18-Apr-2013                                           */  
 /* Copyright: IDS                                                       */  
 /* Written by: ChewKP                                                   */  
 /*                                                                      */  
 /* Purposes: The message returns the regions where the operator is      */  
 /*           allowed to perform the selection function.                 */  
 /*                                                                      */  
 /* Updates:                                                             */  
 /* Date         Author    Purposes                                      */  
/************************************************************************/  
CREATE PROC [dbo].[isp_TCP_VC_prTaskODRUpdateStatus] (  
    @c_TranDate       NVARCHAR(20)  
   ,@c_DevSerialNo    NVARCHAR(20)  
   ,@c_OperatorID     NVARCHAR(20)  
   ,@c_TaskDetailKey  NVARCHAR(10)  
   ,@c_Loc            NVARCHAR(10)  
   ,@n_UpdateInfo     INT  
   ,@c_UpdateStatus   NVARCHAR(1)  
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

   
   -- Update TaskDetail to ReasonCode to SKIP
   IF @c_UpdateStatus = 'S'
   BEGIN
      Update TaskDetail
      Set   Status = '9'   
          , ReasonKey = 'SKIP'
          , Trafficcop = NULL
      Where WaveKey = @c_TaskDetailKey
      AND FromLoc = @c_Loc
      AND Status = '3'
      AND UserKey = @c_OperatorID
      
   END
   
     
QUIT_SP:     
   SET @c_RtnMessage = ''  
   
     
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0   
   BEGIN  
      SET @c_RtnMessage = "0,"   
   END  
   

  
END

GO