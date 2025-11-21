SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*******************************************************************************/
 /* Store Procedure:  isp_TCP_VC_prTaskLUTPtsGetRegionConfiguration             */
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
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTPtsGetRegionConfiguration] (
    @c_TranDate     NVARCHAR(20)
   ,@c_DevSerialNo  NVARCHAR(20)
   ,@c_OperatorID   NVARCHAR(20)
   ,@c_Region       NVARCHAR(10)
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
         , @c_AllowSkipAisle     NVARCHAR(1)   
         , @c_AllowSkipSlot      NVARCHAR(1)   -- Determines whether an operator can choose to skip a slot
         , @c_RepickSkips        NVARCHAR(1)   -- Determines if the operator can choose to return to skipped items 
                                               -- at any time during an assignment.                                            --          
         , @c_AllowSignOff       NVARCHAR(1)   -- Allow operator can sign off in the middle of an assignment
         , @c_AllowPassAssignmnt NVARCHAR(1)   -- Operator is allowed to pass the assignment
         , @c_AllowMultipleCtns  NVARCHAR(1)   -- Allow Multiple Open Containers
         , @c_MaxLPN             NVARCHAR(10)  -- Determines the maximum number of licenses that can be grouped. 
                                               -- Sets the maximum number of licenses on which an operator can work at one time.
         , @c_SysCartonID        NVARCHAR(1)   -- Determines whether the operator is prompted for the container ID when opening a new container 
                                               -- or if the system generates the container ID
         , @c_NoOfLPNDigitUserSpeak NVARCHAR(2) -- # of License Digits Operator Speaks
         , @c_ConfirmSpokeLPN       NVARCHAR(1) -- Determines if the operator is prompted to confirm the spoke license plate number during license induction.

         , @c_ValidateCtn           NVARCHAR(1)  -- # Determines when an operator must validate the container number
         , @c_NoOfCtnDigitUserSpeak NVARCHAR(2)  -- # digits the operator must speak to confirm a container

         , @c_ConfirmSpokeLoc       NVARCHAR(1)  -- Determines if the operator will be prompted to confirm the spoken location at the location prompt
         , @c_NoOfLocDigitUserSpeak NVARCHAR(2)  -- The number of digits the operator must speak to confirm a location.  
                                                
         , @c_UseLUT                NVARCHAR(1)  -- Determines if the voice application should send status updates using a LUT versus an ODR.
         , @c_CurrentPreAisle       NVARCHAR(50) -- Task variable. Sets the maximum length for the pre-aisle in the Get Puts message.
         , @c_CurrentAisle          NVARCHAR(50) -- Task variable. Sets the maximum length for the current aisle in the Get Puts message.
         , @c_CurrentPostAisle      NVARCHAR(50) -- Task variable. Sets the maximum length for the post-aisle in the Get Puts message.
         , @c_CurrentSlot           NVARCHAR(50) -- Task variable. Sets the maximum length for the slot in the Get Puts message.        
         
         , @c_PrtExceptnLabel       NVARCHAR(1)  -- Determines if a label will be printed when un-expected residual items remain when an assignment is complete


   
   SET @c_RtnMessage = ''
   
   SET @c_RegionalNo = N''      
   SET @c_RegionName = N''
   

   SET @c_RegionalNo         			= ''
   SET @c_RegionName               = ''
   SET @c_AllowSkipAisle           = '1'
   SET @c_AllowSkipSlot            = '1'
   SET @c_RepickSkips              = '1'
   SET @c_AllowSignOff             = '1'
   SET @c_AllowPassAssignmnt       = '1'
   SET @c_AllowMultipleCtns        = '1'
   SET @c_MaxLPN                   = '1'
   SET @c_SysCartonID              = '0'
   SET @c_NoOfLPNDigitUserSpeak    = '3'
   SET @c_ConfirmSpokeLPN          = '1'
   SET @c_ValidateCtn              = '0'
   SET @c_NoOfCtnDigitUserSpeak    = '3'
   SET @c_ConfirmSpokeLoc          = '1'
   SET @c_NoOfLocDigitUserSpeak    = '3'
   SET @c_UseLUT                   = '0'
   SET @c_CurrentPreAisle          = 'X'
   SET @c_CurrentAisle             = 'X'
   SET @c_CurrentPostAisle         = 'X'
   SET @c_CurrentSlot              = 'X'
   SET @c_PrtExceptnLabel          = '0'
   
   SET @c_ErrorCode = '0'
   SET @c_Message   = ''
   
   SELECT  @c_RegionalNo = V_String1  
   FROM    rdt.rdtMobRec WITH (NOLOCK) 
   WHERE   UserName = @c_OperatorID
   AND     DeviceID = @c_DevSerialNo
      
   SET @c_RtnMessage =  
      ISNULL(RTRIM(@c_RegionalNo           ) ,'') + ',' + 
      ISNULL(RTRIM(@c_RegionName           ) ,'') + ',' + 
      ISNULL(RTRIM(@c_AllowSkipAisle       ) ,'') + ',' + 
      ISNULL(RTRIM(@c_AllowSkipSlot        ) ,'') + ',' + 
      ISNULL(RTRIM(@c_RepickSkips          ) ,'') + ',' + 
      ISNULL(RTRIM(@c_AllowSignOff         ) ,'') + ',' + 
      ISNULL(RTRIM(@c_AllowPassAssignmnt   ) ,'') + ',' + 
      ISNULL(RTRIM(@c_AllowMultipleCtns    ) ,'') + ',' + 
      ISNULL(RTRIM(@c_MaxLPN               ) ,'') + ',' + 
      ISNULL(RTRIM(@c_SysCartonID          ) ,'') + ',' + 
      ISNULL(RTRIM(@c_NoOfLPNDigitUserSpeak) ,'') + ',' + 
      ISNULL(RTRIM(@c_ConfirmSpokeLPN      ) ,'') + ',' + 
      ISNULL(RTRIM(@c_ValidateCtn          ) ,'') + ',' + 
      ISNULL(RTRIM(@c_NoOfCtnDigitUserSpeak) ,'') + ',' + 
      ISNULL(RTRIM(@c_ConfirmSpokeLoc      ) ,'') + ',' + 
      ISNULL(RTRIM(@c_NoOfLocDigitUserSpeak) ,'') + ',' + 
      ISNULL(RTRIM(@c_UseLUT               ) ,'') + ',' + 
      ISNULL(RTRIM(@c_CurrentPreAisle      ) ,'') + ',' + 
      ISNULL(RTRIM(@c_CurrentAisle         ) ,'') + ',' + 
      ISNULL(RTRIM(@c_CurrentPostAisle     ) ,'') + ',' + 
      ISNULL(RTRIM(@c_CurrentSlot          ) ,'') + ',' + 
      ISNULL(RTRIM(@c_PrtExceptnLabel      ) ,'') + ',' + 

      @c_ErrorCode  + ',' +                     
      @c_Message                                   
                                              
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0 
   BEGIN
      SET @c_RtnMessage = '1,region 1,1,1,1,1,0,1,1,1,0,1,0,3,1,0,2,0,X ,X ,X ,X ,0,0,'
   END
   


END

GO