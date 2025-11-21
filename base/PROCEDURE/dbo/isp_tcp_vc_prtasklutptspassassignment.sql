SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_TCP_VC_prTaskLUTPtsPassAssignment               */  
/* Creation Date: 26-Feb-2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purposes: This message sent when the operator finishes selecting     */
/*           licenses.                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */  
/************************************************************************/  
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTPtsPassAssignment] (  
    @c_TranDate      VARCHAR(20)  
   ,@c_DevSerialNo   VARCHAR(20)  
   ,@c_OperatorID    VARCHAR(20)  
   ,@c_GrooupID      VARCHAR(20)
   ,@n_SerialNo     INT  
   ,@c_RtnMessage   NVARCHAR(500) OUTPUT      
   ,@b_Success      INT = 1 OUTPUT  
   ,@n_Error        INT = 0 OUTPUT  
   ,@c_ErrMsg       NVARCHAR(255) = '' OUTPUT   
  
)  
AS  
BEGIN  
   DECLARE @c_ErrorCode         VARCHAR(20) --  0: No error. The VoiceApplication proceeds.  
                                            -- 98: Critical error. If this error is received,   
                                            --     the VoiceApplication speaks the error message, and forces the operator to sign off.   
                                            -- 99: Informational error. The VoiceApplication speaks the informational error message,   
                                            --     but does not force the operator to sign off.  
         , @c_Message               NVARCHAR(400)  
         , @c_GroupID               NVARCHAR(100)           
         , @c_TotalSlots            NVARCHAR(10) -- 0 = not a chase assignment, 1 = is a chase assignment  
         , @c_TotalItems            NVARCHAR(10) -- Number of unique item numbers for this assignment.
         , @c_TotExpectedResidual   NVARCHAR(10) -- Total residual quantity for each item expected for this assignment
         , @c_UnExpReturnLoc        NVARCHAR(10) -- Location where unexpected residuals should be returned.
         , @c_UnExpReturnLocChkDig  NVARCHAR(10) -- Goal time in minutes for the work ID.  
         , @c_ReturnLoc             NVARCHAR(10) -- Location where expected residuals should be returned. If defined, 
                                                 -- this value is spoken to the operator at the end of the assignment 
                                                 -- when residuals are expected 
         , @c_ReturnLocChkDig       NVARCHAR(10) 
         , @c_PerformanceLast       NVARCHAR(10) -- Performance for last assignment. This value is spoken at the assignment 
                                                 -- summary prompt if requested. 
         , @c_PerformanceDaily      NVARCHAR(10) -- Performance for day. This value is spoken at the assignment summary prompt 
                                                 -- if requested.

         , @c_PickSlipNo            NVARCHAR(10)
         , @c_Loadkey               NVARCHAR(10)
         , @c_DropID                NVARCHAR(20)
         , @c_Status                NVARCHAR(5)
         
                      
   SET @c_PickSlipNo    = ''
   SET @c_Loadkey       = ''
   SET @c_DropID        = ''
   SET @c_Status        = '9'       
     
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0   
   BEGIN  
      SET @c_RtnMessage = '0,'
   END  
   
   -- Update TCPSocket_Inlog 
   UPDATE dbo.TCPSocket_InLog
   SET Status = @c_Status
   WHERE SerialNo = @n_SerialNo  
  
END

GO