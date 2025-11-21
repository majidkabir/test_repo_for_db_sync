SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
 /* Store Procedure:  isp_TCP_VC_prTaskODRCoreSendBreakInfo              */    
 /* Creation Date: 15-Mar-2013                                           */    
 /* Copyright: IDS                                                       */    
 /* Written by: ChewKP                                                   */    
 /*                                                                      */    
 /* Purposes: The message returns the regions where the operator is      */    
 /*           allowed to perform the selection function.                 */    
 /*                                                                      */    
 /* Updates:                                                             */    
 /* Date         Author    Purposes                                      */    
/************************************************************************/    
CREATE PROC [dbo].[isp_TCP_VC_prTaskODRCoreSendBreakInfo] (    
    @c_TranDate       NVARCHAR(20)    
   ,@c_DevSerialNo    NVARCHAR(20)    
   ,@c_OperatorID     NVARCHAR(20)    
   ,@c_ReasonCode     NVARCHAR(1)
   ,@c_StarEndFlag    NVARCHAR(1)    
   ,@c_Descr          NVARCHAR(60)    
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
         , @n_Mobile          INT
         , @n_Func            INT
         , @c_Facility        NVARCHAR(5)
         , @c_StorerKey       NVARCHAR(15)
         
    
   SELECT @n_Mobile = Mobile
         ,@n_Func   = Func
         ,@c_Facility = Facility
         ,@c_StorerKey = StorerKey
   FROM rdt.rdtMobRec WITH (NOLOCK)   
   WHERE DeviceID = @c_DevSerialNo   
    
   --Add to RDT.RDTEventLog
   
   IF @c_StarEndFlag = '0'
   BEGIN
      EXEC RDT.rdt_STD_EventLog
           @cActionType = '3', 
           @cUserID     = @c_OperatorID,
           @nMobileNo   = @n_Mobile,
           @nFunctionID = @n_Func,
           @cFacility   = @c_Facility,
           @cStorerKey  = @c_StorerKey,
           @cRefNo1     = @c_ReasonCode, -- BreakType TaskManager.ReasonCode
           @cRefNo2     = 'Start Break'
   END    
   ELSE IF @c_StarEndFlag = '1'
   BEGIN
      EXEC RDT.rdt_STD_EventLog
           @cActionType = '3', 
           @cUserID     = @c_OperatorID,
           @nMobileNo   = @n_Mobile,
           @nFunctionID = @n_Func,
           @cFacility   = @c_Facility,
           @cStorerKey  = @c_StorerKey,
           @cRefNo1     = @c_ReasonCode, -- BreakType TaskManager.ReasonCode
           @cRefNo2     = 'End Break'
   END
    

   SET @c_RtnMessage = ''    
       
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0     
   BEGIN    
      SET @c_RtnMessage = "0,"     
   END    
   

    
END

GO