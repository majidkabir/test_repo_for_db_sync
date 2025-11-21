SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*******************************************************************************/
 /* Store Procedure:  isp_TCP_VC_prTaskLUTForkPutAwayRegionConfiguration        */
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
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTForkPutAwayRegionConfiguration] (
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
         , @c_CaptureStartLoc    NVARCHAR(1)   -- 1 = Once before specifying license(s) for the first time
                                               -- 2 = Every time before specifying license(s)
                                               -- 3 = Every time before each license is put away
                                               -- Any other value = never
         , @c_AllowReleaseLPN    NVARCHAR(1)   -- Determines if the operator can use the release license plate command.
         , @c_AllowCancelLPN     NVARCHAR(1)   -- Determines if the operator can use the cancel license plate command.
         , @c_AllowOverrideLoc   NVARCHAR(1)   -- Allow Override Put Location
         , @c_AllowOverrideQty   NVARCHAR(1)   -- Allow Override Quantity Picked Up
         , @c_AllowPartialPut    NVARCHAR(1)   -- Allow Partial Put
         , @c_CapturePickupQty   NVARCHAR(1)   -- Capture Pick-up Quantity
         , @c_CapturePutQty      NVARCHAR(1)   -- prompts the operator to enter the quantity put.
         , @c_NoOfLPNDigitSystemSpeak   NVARCHAR(2) -- # of License Digits VoiceApplication Speaks
         , @c_NoOfLPNDigitUserSpeak     NVARCHAR(2) -- # of License Digits Operator Speaks
         , @c_NoOfLocDigitUserSpeak     NVARCHAR(2) -- # of Location Digits Operator Speaks
         , @c_NoOfChkDigitUserSpeak     NVARCHAR(2) -- # of Check Digits Operator Speaks
         , @c_MaxLPNNumber              NVARCHAR(3) -- Maximum Number of Licenses
         , @c_ExceptionLoc              NVARCHAR(100) -- This value is spoken to direct the operator to the exception location 
                                                      -- during the cancel license plate process.
         , @c_ConfirmLPNxLoc            NVARCHAR(1)   -- Confirm Spoken Licenses and Locations

   
   SET @c_RtnMessage = ''
   
   SET @c_RegionalNo = N''      
   SET @c_RegionName = N''
   
   SELECT  @c_RegionalNo = V_String1  
   FROM    rdt.rdtMobRec WITH (NOLOCK) 
   WHERE   UserName = @c_OperatorID
   AND     DeviceID = @c_DevSerialNo
   
   SET @c_CaptureStartLoc  = '1'
   SET @c_AllowReleaseLPN  = '1'
   SET @c_AllowCancelLPN   = '1'
   SET @c_AllowOverrideLoc = '1'
   SET @c_AllowOverrideQty = '0'
   SET @c_AllowPartialPut  = '0'
   SET @c_CapturePickupQty = '0'
   SET @c_CapturePutQty    = '1' 
   
   SET @c_NoOfLPNDigitSystemSpeak  = '3'
   SET @c_NoOfLPNDigitUserSpeak    = '3'
   SET @c_NoOfLocDigitUserSpeak    = '3'
   
   SET @c_ErrorCode = '0'
   SET @c_Message   = ''
   
   SET @c_RtnMessage =  
      ISNULL(RTRIM(@c_RegionalNo             ),'') + ',' + 
      ISNULL(RTRIM(@c_RegionName             ),'') + ',' + 
      ISNULL(RTRIM(@c_CaptureStartLoc        ),'') + ',' + 
      ISNULL(RTRIM(@c_AllowReleaseLPN        ),'') + ',' + 
      ISNULL(RTRIM(@c_AllowCancelLPN         ),'') + ',' + 
      ISNULL(RTRIM(@c_AllowOverrideLoc       ),'') + ',' + 
      ISNULL(RTRIM(@c_AllowOverrideQty       ),'') + ',' + 
      ISNULL(RTRIM(@c_AllowPartialPut        ),'') + ',' + 
      ISNULL(RTRIM(@c_CapturePickupQty       ),'') + ',' + 
      ISNULL(RTRIM(@c_CapturePutQty          ),'') + ',' + 
      ISNULL(RTRIM(@c_NoOfLPNDigitSystemSpeak),'') + ',' +   
      ISNULL(RTRIM(@c_NoOfLPNDigitUserSpeak  ),'') + ',' +   
      ISNULL(RTRIM(@c_NoOfLocDigitUserSpeak  ),'') + ',' +   
      ISNULL(RTRIM(@c_NoOfChkDigitUserSpeak  ),'') + ',' +   
      ISNULL(RTRIM(@c_MaxLPNNumber           ),'') + ',' +   
      ISNULL(RTRIM(@c_ExceptionLoc           ),'') + ',' +   
      ISNULL(RTRIM(@c_ConfirmLPNxLoc         ),'') + ',' +                    
      @c_ErrorCode  + ',' +                     
      @c_Message                                   
                                              
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0 
   BEGIN
      SET @c_RtnMessage = "000000001,Freezer,0,1,1,0,0,0,1,0,4,4,3,2,3,Exception area,1,0," 
   END
   
   
   
   

END

GO