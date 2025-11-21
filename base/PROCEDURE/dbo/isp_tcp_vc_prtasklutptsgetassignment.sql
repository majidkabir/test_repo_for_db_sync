SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_TCP_VC_prTaskLUTPtsGetAssignment               */  
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
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTPtsGetAssignment] (  
    @c_TranDate      NVARCHAR(20)  
   ,@c_DevSerialNo   NVARCHAR(20)  
   ,@c_OperatorID    NVARCHAR(20)  
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
            

   SET @c_GroupID               = '342'
   SET @c_TotalSlots            = '60'
   SET @c_TotalItems            = '10'
   SET @c_TotExpectedResidual   = '0'
   SET @c_UnExpReturnLoc        = '1 4 B'
   SET @c_UnExpReturnLocChkDig  = '12'
   SET @c_ReturnLoc             = '1 2 4 C'
   SET @c_ReturnLocChkDig       = '14'
   SET @c_PerformanceLast       = '125.4'
   SET @c_PerformanceDaily      = '125.5'
   SET @c_ErrorCode             = '0'
   SET @c_Message               = ''

     
   SET @c_RtnMessage = @c_GroupID + ',' + 
      @c_TotalSlots            + ',' + 
      @c_TotalItems            + ',' + 
      @c_TotExpectedResidual   + ',' + 
      @c_UnExpReturnLoc        + ',' + 
      @c_UnExpReturnLocChkDig  + ',' + 
      @c_ReturnLoc             + ',' + 
      @c_ReturnLocChkDig       + ',' + 
      @c_PerformanceLast       + ',' + 
      @c_PerformanceDaily      + ',' + 
      @c_ErrorCode             + ',' + 
      @c_Message              
                                             
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0   
   BEGIN  
      SET @c_RtnMessage = '342,60,2489507,0,1 4 B, 1 2 4 C,23,125.4,120.5,0,1,0,'
   END  
   

  
END

GO