SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_TCP_VC_prTaskLUTPtsVerifyLicense              */  
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
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTPtsVerifyLicense] (  
    @c_TranDate      NVARCHAR(20)  
   ,@c_DevSerialNo   NVARCHAR(20)  
   ,@c_OperatorID    NVARCHAR(20)  
   ,@c_LPN           NVARCHAR(20)
   ,@c_IsPartialLicenseNumber NVARCHAR(1)  -- 0 = License is a full license number
                                          -- 1 = License is a partial license number
   ,@n_SerialNo      INT  
   ,@c_RtnMessage    NVARCHAR(500) OUTPUT      
   ,@b_Success       INT = 1 OUTPUT  
   ,@n_Error         INT = 0 OUTPUT  
   ,@c_ErrMsg        NVARCHAR(255) = '' OUTPUT   
  
)  
AS  
BEGIN  
   DECLARE @c_ErrorCode      NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.  
                                         -- 98: Critical error. If this error is received,   
                                         --     the VoiceApplication speaks the error message, and forces the operator to sign off.   
                                         -- 99: Informational error. The VoiceApplication speaks the informational error message,   
                                         --     but does not force the operator to sign off.  
         , @c_Message         NVARCHAR(400)
         , @c_AreaKey         NVARCHAR(10)
         , @c_FromLOC         NVARCHAR(10)
         , @c_DropID          NVARCHAR(18)
         , @c_Status          NVARCHAR(1)

   SET @c_Status = '9'           
   SET @c_ErrorCode = '0'
   SET @c_Message = ''
   SET @c_RtnMessage = ''
   
   SELECT @c_AreaKey   = r.V_String1, 
          @c_FromLOC    = r.V_Loc  
   FROM RDT.RDTMOBREC r WITH (NOLOCK)
   WHERE r.UserName = @c_OperatorID 
   AND   r.DeviceID = @c_DevSerialNo
   
   SET @c_DropID = ''
   
   IF @c_IsPartialLicenseNumber = '1' 
   BEGIN
      SELECT TOP 1 @c_DropID = DI.Dropid
      FROM DROPID DI WITH (NOLOCK)
      WHERE RIGHT(RTRIM(DI.Dropid), 3) = @c_LPN       
   END
   ELSE
   BEGIN
      
      SELECT TOP 1 @c_DropID = DI.Dropid
      FROM DROPID DI WITH (NOLOCK)
      WHERE DI.Dropid = @c_LPN       
   END
      
   
   IF ISNULL(RTRIM(@c_DropID), '') = ''
   BEGIN
      SET @c_ErrorCode = '89'
      SET @c_Status = '5'
      SET @c_Message =  RTRIM(@c_LPN) + ' License not found  Try again' 
   END      
   ELSE
   BEGIN
      UPDATE RDT.RDTMOBREC
         SET V_CaseID = @c_DropID 
      WHERE UserName = @c_OperatorID
      AND   DeviceID = @c_DevSerialNo 
   END

QUIT_SP:   
   -- Return Error Message If Batch No Not match 
   SET @c_RtnMessage = @c_LPN + ',' + @c_ErrorCode + ',' + RTRIM(@c_Message) + '' 
        
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0   
   BEGIN  
      SET @c_RtnMessage = ',0,'   
   END  
   
   -- Update TCPSocket_Inlog 
   UPDATE dbo.TCPSocket_InLog
   SET Status = @c_Status
   WHERE SerialNo = @n_SerialNo  
  
END

GO