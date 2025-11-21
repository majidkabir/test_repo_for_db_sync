SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure:  isp_TCP_VC_prTaskLUTCoreSignOff                    */    
/* Creation Date: 26-Feb-2013                                           */    
/* Copyright: IDS                                                       */    
/* Written by: Shong                                                    */    
/*                                                                      */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Purposes                                      */   
/* 01-04-2013   ChewKP    Revise (ChewKP01)                             */       
/************************************************************************/    
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTCoreSignOff] (    
    @c_TranDate     NVARCHAR(20)    
   ,@c_DevSerialNo  NVARCHAR(20)    
   ,@c_OperatorID   NVARCHAR(20)    
   ,@n_SerialNo     INT    
   ,@c_RtnMessage   NVARCHAR(500) = '' OUTPUT        
   ,@b_Success      INT = 1 OUTPUT    
   ,@n_Error        INT = 0 OUTPUT    
   ,@c_ErrMsg       NVARCHAR(255) = '' OUTPUT        
)    
AS    
BEGIN    
   -- Return Message    
   DECLARE @c_VehicleTypeDesc   NVARCHAR(100) -- A descriptive name for the vehicle type    
         , @c_CaptureVehType    NVARCHAR(1)    
         , @c_ErrorCode         NVARCHAR(20)    
         , @c_Message           NVARCHAR(400)    
    
         -- (ChewKP01)  
         , @n_Mobile          INT              
         , @n_Func            INT  
         , @c_Facility        NVARCHAR(5)  
         , @c_StorerKey       NVARCHAR(15)  
           
   SET @c_ErrorCode = '0'    
   SET @c_Message = ''    
   SET @c_StorerKey = ''  
   SET @c_Facility = ''  
   SET @n_Func = 0   
   SET @n_Mobile = 0   
     
   SELECT @n_Mobile = Mobile  
         ,@n_Func   = Func  
         ,@c_Facility = Facility  
         ,@c_StorerKey = StorerKey   
   FROM rdt.rdtMobRec WITH (NOLOCK)     
   WHERE DeviceID = @c_DevSerialNo   
   AND UserName = @c_OperatorID  
     
   -- (ChewKP01)  
   --Add to RDT.RDTEventLog  
   EXEC RDT.rdt_STD_EventLog  
        @cActionType      = '9',   
        @cUserID          = @c_OperatorID,  
        @nMobileNo        = @n_Mobile,  
        @nFunctionID      = @n_Func,  
        @cFacility        = @c_Facility,  
        @cStorerKey       = @c_StorerKey,  
        @cRefNo1          = @c_DevSerialNo  
          
      
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK)      
       SET Func = 0, ErrMsg = 'Logged Off'     
   WHERE Username = @c_OperatorID        
   AND DeviceID = @c_DevSerialNo    
   IF @@ERROR <> 0     
   BEGIN    
      SET @c_ErrorCode = '89'    
      SET @c_Message = 'Update Mobile Records Failed'    
   END    
     
     
       
   -- Not using now, send back dummy data    
   SET @c_RtnMessage = @c_ErrorCode + ',' + @c_Message    
     
  
       
END

GO