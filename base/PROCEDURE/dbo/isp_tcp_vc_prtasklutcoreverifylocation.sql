SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_TCP_VC_prTaskLUTCoreVerifyLocation              */  
/* Creation Date: 26-Feb-2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purposes: This message is sent when the operator is performing put   */
/*           away and specifies a license plate.                        */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */  
/************************************************************************/  
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTCoreVerifyLocation] (  
    @c_TranDate         NVARCHAR(20)  
   ,@c_DevSerialNo      NVARCHAR(20)  
   ,@c_OperatorID       NVARCHAR(20)  
   ,@c_SpokenScanned    NVARCHAR(1)  -- 0 = license was spoken by the operator
                                    -- 1 = license was scanned by the operator
   ,@c_SpokenLOC        NVARCHAR(10)
   ,@c_CheckDigit       NVARCHAR(10)
   ,@c_VerifyStartLoc   NVARCHAR(1)
   ,@n_SerialNo         INT  
   ,@c_RtnMessage       NVARCHAR(500) OUTPUT      
   ,@b_Success          INT = 1 OUTPUT  
   ,@n_Error            INT = 0 OUTPUT  
   ,@c_ErrMsg           NVARCHAR(255) = '' OUTPUT   
)  
AS  
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF   
     
   -- prTaskLUTCoreVerifyLocation('03-21-13 16:25:22','572517055','shong','0','123','2412324','1')
   
   DECLARE @c_ErrorCode      NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.  
                                         -- 98: Critical error. If this error is received,   
                                         --     the VoiceApplication speaks the error message, and forces the operator to sign off.   
                                         -- 99: Informational error. The VoiceApplication speaks the informational error message,   
                                         --     but does not force the operator to sign off.  
         , @c_Message         NVARCHAR(400)
         , @c_SystemLoc       NVARCHAR(10)
         , @c_Status          NVARCHAR(1)
         
   SET @c_Status = '9'           
   SET @c_ErrorCode = '0'
   SET @c_Message = ''
   SET @c_RtnMessage = ''
   SET @c_SystemLoc = ''
   
   SELECT @c_SystemLoc = ISNULL(LOC, '')
   FROM   LOC l WITH (NOLOCK) 
   WHERE  RIGHT(RTRIM(l.LOC), 3) = @c_SpokenLOC 
   AND    l.LocCheckDigit = RTRIM(@c_CheckDigit) 
   -- AND l.LocPosition  = @c_SpokenLOC 
       
   
   IF ISNULL(RTRIM(@c_SystemLoc),'') = ''
   BEGIN
      SET @c_ErrorCode = '89'
      SET @c_Status = '5'
      SET @c_Message = 'Wrong Location Code ' + RTRIM(@c_SpokenLOC) + ' Check Digit ' + RTRIM(@c_CheckDigit)
   END
   ELSE
   BEGIN
      UPDATE RDT.RDTMOBREC 
         SET V_String2 = @c_SpokenLOC,
             V_LOC = @c_SystemLoc 
      WHERE UserName = @c_OperatorID
      AND   DeviceID = @c_DevSerialNo      
   END
   

QUIT_SP:   
   -- Return Error Message If Batch No Not match 
   SET @c_RtnMessage = ISNULL(RTRIM(@c_SystemLoc), '') + ',' + @c_ErrorCode + ',' + RTRIM(@c_Message)  
        
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0   
   BEGIN  
      SET @c_RtnMessage = '0,'   
   END  
   

END

GO