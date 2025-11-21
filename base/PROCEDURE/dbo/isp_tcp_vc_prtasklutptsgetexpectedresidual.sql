SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
 /* Store Procedure:  isp_TCP_VC_prTaskLUTPtsGetExpectedResidual         */  
 /* Creation Date: 08-May-2013                                           */  
 /* Copyright: IDS                                                       */  
 /* Written by: Shong                                                    */  
 /*                                                                      */  
 /* Purposes: prTaskLUTPtsGetExpectedResidual                            */  
 /*                                                                      */  
 /*                                                                      */  
 /* Updates:                                                             */  
 /* Date         Author    Purposes                                      */  
 /************************************************************************/  
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTPtsGetExpectedResidual] (  
    @c_TranDate            NVARCHAR(20)  
   ,@c_DevSerialNo         NVARCHAR(20)  
   ,@c_OperatorID          NVARCHAR(20)  
   ,@c_GroupID             NVARCHAR(30)   
   ,@n_SerialNo            INT 
   ,@c_RtnMessage          NVARCHAR(500) OUTPUT      
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

         
           
   SET @c_RtnMessage = ''  
   
  
   
   SET @c_RtnMessage = ISNULL(@c_ErrorCode          ,'0') + ',' +  
                       ISNULL(@c_ErrMsg             ,'')  
                                                
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0   
   BEGIN  
      SET @c_RtnMessage = '00052006,130989,WRIG EXTRA POLAR ICE T-PA,0,N,0,'   
   END  
   

END

GO