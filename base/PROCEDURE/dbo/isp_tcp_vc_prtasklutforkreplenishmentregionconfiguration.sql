SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*******************************************************************************/  
 /* Store Procedure:  isp_TCP_VC_prTaskLUTForkReplenishmentRegionConfiguration  */  
 /* Creation Date: 26-Feb-2013                                                  */  
 /* Copyright: IDS                                                              */  
 /* Written by: Shong                                                           */  
 /*                                                                             */  
 /* Purposes: The message returns the regions where the operator is             */  
 /*           allowed to perform the selection function.                        */  
 /*                                                                             */  
 /* Updates:                                                                    */  
 /* Date         Author    Purposes                                             */  
 /*******************************************************************************/  
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTForkReplenishmentRegionConfiguration] (  
    @c_TranDate     NVARCHAR(20)  
   ,@c_DevSerialNo  NVARCHAR(20)  
   ,@c_OperatorID   NVARCHAR(20)  
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
         , @c_Message            NVARCHAR(400)  
         , @c_RegionalNo         NVARCHAR(20)  -- 1st Col  
         , @c_RegionName         NVARCHAR(100) -- 2nd Col           
         , @c_AllowCancelLPN     NVARCHAR(1)   -- Determines if the operator can use the cancel license plate command  
         , @c_AllowOverrideLoc   NVARCHAR(1)   -- Determines if the operator can use the override location command.  
         , @c_AllowOverrideQty   NVARCHAR(1)   -- Determines if the operator can override a quantity they were told to pick up  
         , @c_AllowPartialPut    NVARCHAR(1)   -- Determines if the operator can use the partial command  
         , @c_AskPickUpQty       NVARCHAR(1)   -- Determines if the VoiceApplication prompts the operator to enter the quantity picked up.  
         , @c_AskQtyReplen       NVARCHAR(1)   -- Determines if the VoiceApplication prompts the operator to enter the quantity replenished.  
         , @c_LPNDigit2Ask       NVARCHAR(2)   -- determines how many digits of the license plate are spoken to the user   
                                               -- whenever the device says the license plate.  
         , @c_LOCDigit2Ask       NVARCHAR(2)   -- Determines how many digits the operator must speak when specifying the start   
                                               -- location or put away location.  
         , @c_NoCheckDigit       NVARCHAR(2)   -- How many digits the operator must speak when specifying the location check digits.  
         , @c_ExceptnLoc         NVARCHAR(100) -- spoken to direct the operator to the exception location during the   
                                               -- cancel license plate process.  
         , @c_ConfirmLoc         NVARCHAR(1)   -- Determines if the VoiceApplication asks the operator to confirm spoken location values.  
           
  
     
   SET @c_RtnMessage = ''  
     
   SET @c_RegionalNo = N''        
   SET @c_RegionName = N''  
     
   SELECT  @c_RegionalNo = V_String1    
   FROM    rdt.rdtMobRec WITH (NOLOCK)   
   WHERE   UserName = @c_OperatorID  
   AND     DeviceID = @c_DevSerialNo  
     
   SET @c_AllowCancelLPN    = '0'  
   SET @c_AllowOverrideLoc  = '1'  
   SET @c_AllowOverrideQty  = '1'  
   SET @c_AllowPartialPut   = '0'  
   SET @c_AskPickUpQty      = '0'  
   SET @c_AskQtyReplen      = '1'  
   SET @c_LPNDigit2Ask      = '03'  
   SET @c_LOCDigit2Ask      = '03'   
     
   SET @c_NoCheckDigit      = '02'  
   SET @c_ExceptnLoc        = 'Overflow Location'  
   SET @c_ConfirmLoc        = '0'  
     
   SET @c_ErrorCode = '0'  
   SET @c_Message   = ''  
     
   SET @c_RtnMessage =  @c_RegionalNo + ',' +   
                        @c_RegionName + ',' +  
                        @c_AllowCancelLPN   + ',' +                       
                        @c_AllowOverrideLoc + ',' +                       
                        @c_AllowOverrideQty + ',' +                  
                        @c_AllowPartialPut  + ',' +                       
                        @c_AskPickUpQty     + ',' +                       
                        @c_AskQtyReplen     + ',' +                       
                        @c_LPNDigit2Ask     + ',' +                       
                        @c_LOCDigit2Ask     + ',' +                       
                        @c_NoCheckDigit     + ',' +                       
                        @c_ExceptnLoc       + ',' +  
                        @c_ConfirmLoc       + ',' +                       
                        @c_ErrorCode        + ',' +                       
                        @c_Message                                     
   
                                                
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0   
   BEGIN  
      SET @c_RtnMessage = "0000000001,Freezer,0,0,0,0,0,0,04,04,05,Exception area,0,0,"   
   END  
   

  
END

GO