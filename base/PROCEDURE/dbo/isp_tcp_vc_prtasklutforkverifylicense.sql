SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_TCP_VC_prTaskLUTForkVerifyLicense              */  
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
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTForkVerifyLicense] (  
    @c_TranDate      NVARCHAR(20)  
   ,@c_DevSerialNo   NVARCHAR(20)  
   ,@c_OperatorID    NVARCHAR(20)  
   ,@c_LPN           NVARCHAR(20)
   ,@c_SpokenScanned NVARCHAR(1)  -- 0 = license was spoken by the operator
                                 -- 1 = license was scanned by the operator
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
         , @c_ID              NVARCHAR(18)
         
           
   SET @c_ErrorCode = '0'
   SET @c_Message = ''
   SET @c_RtnMessage = ''
   
   SELECT @c_AreaKey   = r.V_String1, 
          @c_FromLOC    = r.V_Loc  
   FROM RDT.RDTMOBREC r WITH (NOLOCK)
   WHERE r.UserName = @c_OperatorID 
   AND   r.DeviceID = @c_DevSerialNo
   
   SET @c_ID = ''
   
   SELECT TOP 1 @c_ID = ID 
   FROM LOTxLOCxID lli WITH (NOLOCK)
   WHERE lli.Loc = @c_FromLoc 
   AND  RIGHT(RTRIM(lli.ID), 3) = @c_LPN 
   
   IF ISNULL(RTRIM(@c_ID), '') = ''
   BEGIN
      SET @c_ErrorCode = '89'
      SET @c_Message =  RTRIM(@c_LPN) + ' ID not found  Try again' 
   END      
   ELSE
   BEGIN
      UPDATE RDT.RDTMOBREC
         SET V_ID = @c_ID 
      WHERE UserName = @c_OperatorID
      AND   DeviceID = @c_DevSerialNo 
   END

QUIT_SP:   
   -- Return Error Message If Batch No Not match 
   SET @c_RtnMessage = @c_ErrorCode + ',' + RTRIM(@c_Message) + '' 
        
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0   
   BEGIN  
      SET @c_RtnMessage = '0,'   
   END  
   

  
END

GO