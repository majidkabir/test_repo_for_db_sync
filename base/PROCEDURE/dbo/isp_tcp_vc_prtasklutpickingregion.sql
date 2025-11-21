SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
 /* Store Procedure:  isp_TCP_VC_prTaskLUTPickingRegion                  */      
 /* Creation Date: 26-Feb-2013                                           */      
 /* Copyright: IDS                                                       */      
 /* Written by: Shong                                                    */      
 /*                                                                      */      
 /* Purposes: The message returns the regions where the operator is      */      
 /*           allowed to perform the selection function.                 */      
 /*                                                                      */      
 /* Updates:                                                             */      
 /* Date         Author    Purposes                                      */     
 /* 27-03-2013   ChewKP    Revise (ChewKP01)                             */   
 /* 24-10-2014   AlexKeoh  Added VoiceProfileNo                          */        
/************************************************************************/      
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTPickingRegion] (      
    @c_TranDate     NVARCHAR(20)      
   ,@c_DevSerialNo  NVARCHAR(20)      
   ,@c_OperatorID   NVARCHAR(20)      
   ,@c_RegionNo     NVARCHAR(5)  -- OperatorG├ç├┐s response to picking region prompt.      
   ,@c_SelectedFunc NVARCHAR(2)  -- Type of work the operator selected, 3 = Normal Assignments      
                                -- 4 = Chase Assignments, 6 = Normal and Chase Assignments      
   ,@n_SerialNo     INT      
   ,@c_RtnMessage   NVARCHAR(500) OUTPUT          
   ,@b_Success      INT = 1 OUTPUT      
   ,@n_Error        INT = 0 OUTPUT      
   ,@c_ErrMsg       NVARCHAR(255) = '' OUTPUT       
      
)      
AS      
BEGIN      
   SET NOCOUNT ON  
  
   DECLARE @c_ErrorCode         NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.      
                                            -- 98: Critical error. If this error is received,       
                                            --     the VoiceApplication speaks the error message, and forces the operator to sign off.       
                                            -- 99: Informational error. The VoiceApplication speaks the informational error message,       
                                            --     but does not force the operator to sign off.      
         , @c_Message            NVARCHAR(400)      
         , @c_RegionName         NVARCHAR(100)       
         , @c_AssignmentType     NVARCHAR(1)      
         , @c_AutoAssign         NVARCHAR(1)      
         , @c_MaxAssignAllow     NVARCHAR(2)      
         , @c_SkipAisleAllow     NVARCHAR(1)      
         , @c_SkipSlotAllow      NVARCHAR(1)      
         , @c_RePickSkip         NVARCHAR(1)      
         , @c_PrintLabel         NVARCHAR(1)      
         , @c_PrintChaseLabel    NVARCHAR(1)      
         , @c_PickPrompt         NVARCHAR(1)      
         , @c_SignOffAllow       NVARCHAR(1)      
         , @c_ContainerType      NVARCHAR(1)      
         , @c_DlvContnAtClose    NVARCHAR(1)      
         , @c_PassAssignment     NVARCHAR(1)      
         , @c_Delivery           NVARCHAR(1)      
         , @c_QtyVerify          NVARCHAR(1)      
         , @c_WorkIDLength       NVARCHAR(2)      
         , @c_GoBackForShort     NVARCHAR(1)      
         , @c_AllowReversePicking NVARCHAR(1)      
         , @c_UseLUT             NVARCHAR(1)      
         , @c_CurrPreAisle       NVARCHAR(10)    
         , @c_CurrAisle          NVARCHAR(10)      
         , @c_CurrPostAisle      NVARCHAR(10)      
         , @c_CurrSlot           NVARCHAR(18)      
         , @c_PreCreateCartnz    NVARCHAR(1)      
         , @c_PromptCtnID        NVARCHAR(1)      
         , @c_AllowMultipCtn     NVARCHAR(1)      
         , @c_CtnValidLength     NVARCHAR(2)      
         , @c_PickByPickMd       NVARCHAR(1)  
         , @c_VoiceProfileNo     NVARCHAR(10)       
  
         -- (ChewKP01)  
         , @n_Mobile          INT              
         , @n_Func            INT  
         , @c_Facility        NVARCHAR(5)  
         , @c_StorerKey       NVARCHAR(15)  
               
         -- (AlexKeoh)   
         , @c_ParameterCode   NVARCHAR(5)  
         , @c_ParameterValue  NVARCHAR(22)  
        
   SET @c_Facility = ''  
   SET @c_StorerKey = ''  
   SET @n_Func = 750  
   SET @n_Mobile = 0   
   SET @c_RtnMessage = ''      
         
       
   SELECT @c_VoiceProfileNo = VoiceProfileNo   
   FROM   RDT.RDTUser WITH (NOLOCK)   
   WHERE  UserName = @c_OperatorID  
  
   UPDATE rdt.rdtMobRec       
      SET  Func      = @n_Func  
          ,V_String1 = @c_RegionNo        
          ,V_String2 = @c_VoiceProfileNo   
   WHERE UserName = @c_OperatorID       
     AND DeviceID = @c_DevSerialNo  
  
         
   SET @c_RegionName = 'Area ' + @c_RegionNo      
   SET @c_AssignmentType     = '1'  -- 1 = Normal assignments, 2 = Chase assignments    
   SET @c_AutoAssign         = '1'  -- Determines whether operators may choose their own work when starting     
                                    -- an assignment or the work is automatically given to them.    
   SET @c_MaxAssignAllow     = '1'  -- Sets the maximum number of assignments on which an operator can work at one time.    
   SET @c_SkipAisleAllow     = '0'  -- Determines whether an operator can choose to skip an aisle    
   SET @c_SkipSlotAllow      = '1'  -- Determines whether an operator can choose to skip an slot    
   SET @c_RePickSkip         = '0'  -- Determines whether an operator can choose to pick skipped items     
                                    -- at any time during an assignment.    
                                    -- 0 = operators cannot use the repick skips command    
                                    -- 1 = operators can use the repick skips command    
                                        
   SET @c_PrintLabel         = '0'  -- Determines whether the WMS prints labels for an assignment or     
                                    -- a specific container at the beginning of the assignment or container,     
                                    -- at the end of the assignment or container, or not at all.    
                                    -- 0 = device never prompts the operator to print container labels,     
                                    --     even if the pre-create containers    
                                    -- 1 = device prompts the operator to print container labels     
                                    --     at the beginning of the assignment or upon opening a new container    
                                    -- 2 = device prompts the operator to print container labels at the end     
                                    --     of the assignment or upon closing a container    
                                        
   SET @c_PrintChaseLabel    = '0'  -- Determines whether the host system prints labels for chase assignments.     
                                    -- 0 = device never prompts the operator to print chase item labels    
                                    -- 1 = device prompts the operator to print chase item labels    
   SET @c_PickPrompt         = '2'  -- Determines the pick prompt that will be spoken by the device:    
                                    -- 0 = Single Prompt. The device prompts the operator with the location and     
                                    --     the quantity to pick in one prompt.    
                                    -- 1 = Single Pick Prompt, Suppress Quantity 1.    
                                    -- 2 = Multiple Prompts. The device prompts the operator with the location and waits     
                                    --     for the operator to respond with the appropriate response to confirm     
                                    --     the pick location.    
                                        
   SET @c_SignOffAllow       = '1'  -- Determines whether an operator can choose to sign off an assignment before     
                                    -- completing and delivering the assignment.    
   SET @c_ContainerType      = '0'  -- Specifies whether the operator is picking to containers or not.    
                                    -- 0 = pick to no container    
                                    -- 1 = pick to variable full quantity containers     
   SET @c_DlvContnAtClose    = '0'  -- Determines whether to prompt the operator to deliver the container when it is closed.    
                                    -- 0 = device does not prompt the operator with delivery information at container closing    
                                    -- 1 = device prompts the operator with delivery information at container closing    
   SET @c_PassAssignment     = '0'  -- Determines whether an operator can choose to stop working on an assignment in the middle     
                                    -- of it and pass the rest of that assignment on to another operator for completion.    
   SET @c_Delivery           = '0'  -- Determines the type of delivery prompt for that region. Prompt Delivery Location means     
                                    -- the device prompts the operator with the delivery location and waits for the operator     
                                    -- to say,"ready"    
                                    -- 0 = device prompts with delivery location    
                                    -- 1 = device prompts with and confirms delivery location    
                                    -- 2 = none    
                                        
   SET @c_QtyVerify          = '1'  -- Determines whether the operator is required to verify the quantity picked or not    
       
   SET @c_WorkIDLength       = '3'  -- It is used to specify how many digits of the work ID must be spoken for the     
                                    -- operator to manually request an assignment.    
                                        
   SET @c_GoBackForShort     = '0'  -- Determines whether an operator is directed to go back and pick shorted items or not.    
       
   SET @c_AllowReversePicking = '0' -- Indicates whether the operator will be asked to choose the order of picking, forward or reverse.      
       
   SET @c_UseLUT             = '0'  -- Determines whether the device should send one-way or two-way messages while picking.     
                                    -- One-way messages may be preferred if RF coverage is not sufficient in picking areas.    
                                    -- 0 = always use Picked, Update Status, and Failed Lot one-way messages    
                                    -- 1 = use Picked, Update Status, and Failed Lot two-way messages,     
                                    --     unless a failure is received, then send as one-way messages    
                                    -- 2 = always use Picked, Update Status, and Failed Lot two-way messages   
                                        
   SET @c_CurrPreAisle       = 'XX' -- Sets the maximum length for the Pre-aisle Direction field in the Get Picks message.    
   SET @c_CurrAisle          = 'XX' -- Sets the maximum length for the Aisle field in the Get Picks message.    
   SET @c_CurrPostAisle      = 'XX' -- Sets the maximum length for the Post Aisle Direction field in the Get Picks message.     
   SET @c_CurrSlot           = 'XXXXXX' -- Sets the maximum length for the Slot field in the Get Picks message.     
       
   SET @c_PreCreateCartnz    = '0'  -- Flag to inform VoiceApplication whether or not the VoiceApplication should pre-create containers,     
                                    -- and if so, how many should be pre-created. The VoiceApplication prints a label for each pre-created container.     
                                    -- 0 = DonG├ç├┐t prompt for number of labels    
                                    -- 1 = prompt for number of labels    
                                        
   SET @c_PromptCtnID        = '0' -- Should prompt the operator for the container ID when a new container is opened?    
   SET @c_AllowMultipCtn     = '0' -- Specifies whether the operator is allowed to open a new container without     
                                   -- closing the current container.    
                                   -- 0 = VoiceApplication allows only one container to be open at a time for each assignment    
                                   -- 1 = VoiceApplication allows multiple containers to be open at a time for each assignment     
   SET @c_CtnValidLength     = '0' -- Specifies the number of digits an operator must speak when validating a container to put,     
                                   -- close, or reprint labels.    
                                       
   SET @c_PickByPickMd       = '0' -- Indicates whether the task will operate in pick-by-pick mode or in the normal, full pick list mode.    
                                   -- 0 = Full pick list sent to task    
                                   -- 1 = Pick by pick mode      
         
     
   DECLARE Cur_Parameter_Value CURSOR LOCAL FAST_FORWARD READ_ONLY  FOR  
   SELECT VC.ParameterCode, VC.ParameterValue   
   FROM VoiceConfig VC WITH (NOLOCK)  
   JOIN CODELKUP AS C_MODULE WITH (NOLOCK) ON C_MODULE.ListName = 'VOICEMODUL' AND C_MODULE.SHORT = VC.ModuleNo   
   JOIN CODELKUP AS C_Parm WITH (NOLOCK) ON C_Parm.LISTNAME = C_MODULE.UDF01 AND vc.ParameterCode = C_Parm.Code   
   WHERE C_MODULE.Code = 'PICKING'  
   AND   VC.ProfileNo = @c_VoiceProfileNo  
  
   OPEN Cur_Parameter_Value   
  
   FETCH NEXT FROM Cur_Parameter_Value  
   INTO @c_ParameterCode, @c_ParameterValue  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      IF @c_ParameterCode = '01'   
      BEGIN  
         SET @c_AssignmentType    = CASE WHEN @c_ParameterValue = 'Normal' THEN '1'   
                                         WHEN @c_ParameterValue = 'Chase'  THEN '2'   
                                         ELSE '1'  
                                      END  
      END   
      ELSE IF @c_ParameterCode = '02'   
      BEGIN  
         SET @c_AutoAssign        = CASE WHEN @c_ParameterValue = 'Manual'     THEN '0'   
                                         WHEN @c_ParameterValue = 'Automatic'  THEN '1'   
                                         ELSE '1'  
                                      END  
      END   
      ELSE IF @c_ParameterCode = '03'   
      BEGIN  
         IF ISNULL(RTRIM(@c_ParameterValue), '') = '' OR ISNUMERIC(@c_ParameterValue) <> 1  
            SET @c_MaxAssignAllow = '1'  
         ELSE  
            SET @c_MaxAssignAllow = @c_ParameterValue   
      END   
      ELSE IF @c_ParameterCode = '04'   
      BEGIN  
         SET @c_SkipAisleAllow     = CASE WHEN @c_ParameterValue = 'No'   THEN '0'  
                                          WHEN @c_ParameterValue = 'Yes'  THEN '1'  
                                        ELSE '1'          
                                      END  
      END  
      ELSE IF @c_ParameterCode = '05'   
      BEGIN  
         SET @c_SkipSlotAllow      = CASE WHEN @c_ParameterValue = 'No'   THEN '0'  
                                          WHEN @c_ParameterValue = 'Yes'  THEN '1'  
                                        ELSE '1'          
                                      END  
      END  
      ELSE IF @c_ParameterCode = '06'   
      BEGIN  
         SET @c_RePickSkip         = CASE WHEN @c_ParameterValue = 'No'   THEN '0'  
                                          WHEN @c_ParameterValue = 'Yes'  THEN '1'  
                                        ELSE '1'          
                                      END  
      END  
      ELSE IF @c_ParameterCode = '07'  
      BEGIN  
         SET @c_PrintLabel        = CASE WHEN @c_ParameterValue = 'Do Not Print'           THEN '0'   
                                         WHEN @c_ParameterValue = 'When Container Open'    THEN '1'  
                                         WHEN @c_ParameterValue = 'When Container Closed'  THEN '2'    
                                         ELSE '1'  
                                      END  
      END   
      ELSE IF @c_ParameterCode = '08'   
      BEGIN  
         SET @c_PrintChaseLabel   = CASE WHEN @c_ParameterValue = 'No'   THEN '0'   
                                         WHEN @c_ParameterValue = 'Yes'  THEN '1'   
                                         ELSE '1'  
                                      END  
      END  
      ELSE IF @c_ParameterCode = '09'   
      BEGIN  
         SET @c_PickPrompt        = CASE WHEN @c_ParameterValue = 'Single'    THEN '0'   
                                         WHEN @c_ParameterValue = 'Multiple'  THEN '2'   
                                         ELSE '1'          
                                      END  
      END  
      ELSE IF @c_ParameterCode = '10'   
      BEGIN  
         SET @c_SignOffAllow       = CASE WHEN @c_ParameterValue = 'No'   THEN '0'  
                                          WHEN @c_ParameterValue = 'Yes'  THEN '1'  
                                        ELSE '1'         
                                      END  
      END  
      ELSE IF @c_ParameterCode = '11'   
      BEGIN  
         SET @c_ContainerType     = CASE WHEN @c_ParameterValue = 'No Containers' THEN '0'   
                                         WHEN @c_ParameterValue = 'Containers'    THEN '1'   
                                         ELSE '1'          
                                      END  
      END  
      ELSE IF @c_ParameterCode = '12'   
      BEGIN  
         SET @c_DlvContnAtClose   = CASE WHEN @c_ParameterValue = 'No'    THEN '0'  
                                         WHEN @c_ParameterValue = 'Yes'   THEN '1'  
                                       ELSE '1'          
                                      END  
      END  
      ELSE IF @c_ParameterCode = '13'   
      BEGIN  
         SET @c_PassAssignment    = CASE WHEN @c_ParameterValue = 'No'    THEN '0'  
                                         WHEN @c_ParameterValue = 'Yes'   THEN '1'  
                                       ELSE '1'          
                                      END  
      END  
      ELSE IF @c_ParameterCode = '14'   
      BEGIN  
         SET @c_Delivery          = CASE WHEN @c_ParameterValue = 'Prompts'            THEN '0'  
                                         WHEN @c_ParameterValue = 'Prompts & Confirms' THEN '1'  
                                         WHEN @c_ParameterValue = 'None'               THEN '2'  
                                       ELSE '1'          
                                      END  
      END  
      ELSE IF @c_ParameterCode = '15'   
      BEGIN  
         SET @c_QtyVerify         = CASE WHEN @c_ParameterValue = 'No'    THEN '0'  
                                         WHEN @c_ParameterValue = 'Yes'   THEN '1'  
                                       ELSE '1'          
                                      END  
      END  
      ELSE IF @c_ParameterCode  = '16'   
      BEGIN  
         SET @c_GoBackForShort     = CASE WHEN @c_ParameterValue = 'Never'            THEN '0'  
                                          WHEN @c_ParameterValue = 'Always'           THEN '1'  
                                          WHEN @c_ParameterValue = 'When Replenished' THEN '2'  
                                        ELSE '1'  
                                      END    
      END  
       ELSE IF @c_ParameterCode = '17'   
      BEGIN  
         SET @c_AllowReversePicking= CASE WHEN @c_ParameterValue = 'No'   THEN '0'  
                                          WHEN @c_ParameterValue = 'Yes'  THEN '1'  
                                        ELSE '1'          
                                      END  
      END  
      ELSE IF @c_ParameterCode = '18'   
      BEGIN  
         SET @c_PreCreateCartnz   = CASE WHEN @c_ParameterValue = 'No'    THEN '0'  
                                         WHEN @c_ParameterValue = 'Yes'   THEN '1'  
                                       ELSE '1'          
             END  
      END  
      ELSE IF @c_ParameterCode = '19'   
      BEGIN  
         SET @c_PromptCtnID       = CASE WHEN @c_ParameterValue = 'No'    THEN '0'  
                                         WHEN @c_ParameterValue = 'Yes'   THEN '1'  
                                       ELSE '1'          
                                      END  
      END  
      ELSE IF @c_ParameterCode = '20'   
      BEGIN  
         SET @c_AllowMultipCtn    = CASE WHEN @c_ParameterValue = 'No'    THEN '0'  
                                         WHEN @c_ParameterValue = 'Yes'   THEN '1'  
                                       ELSE '1'          
                                      END  
      END  
      FETCH NEXT FROM Cur_Parameter_Value  
      INTO @c_ParameterCode, @c_ParameterValue  
   END   
   CLOSE Cur_Parameter_Value  
   DEALLOCATE Cur_Parameter_Value   
  
       
   SET @c_ErrorCode = 0       
   SET @c_Message = ''      
         
   SET @c_RtnMessage = ISNULL(@c_RegionNo           ,'') + ',' +      
                       ISNULL(@c_RegionName         ,'') + ',' +      
                       ISNULL(@c_AssignmentType     ,'') + ',' +      
                       ISNULL(@c_AutoAssign         ,'') + ',' +      
                       ISNULL(@c_MaxAssignAllow     ,'') + ',' +      
                       ISNULL(@c_SkipAisleAllow     ,'') + ',' +      
                       ISNULL(@c_SkipSlotAllow      ,'') + ',' +      
                       ISNULL(@c_RePickSkip         ,'') + ',' +      
                       ISNULL(@c_PrintLabel         ,'') + ',' +      
                       ISNULL(@c_PrintChaseLabel    ,'') + ',' +      
                       ISNULL(@c_PickPrompt         ,'') + ',' +      
                       ISNULL(@c_SignOffAllow       ,'') + ',' +      
                       ISNULL(@c_ContainerType      ,'') + ',' +      
                       ISNULL(@c_DlvContnAtClose    ,'') + ',' +      
                       ISNULL(@c_PassAssignment     ,'') + ',' +      
                       ISNULL(@c_Delivery           ,'') + ',' +      
                       ISNULL(@c_QtyVerify          ,'') + ',' +      
                       ISNULL(@c_WorkIDLength       ,'') + ',' +      
                       ISNULL(@c_GoBackForShort     ,'') + ',' +      
                       ISNULL(@c_AllowReversePicking,'') + ',' +      
                       ISNULL(@c_UseLUT             ,'') + ',' +      
                       ISNULL(@c_CurrPreAisle       ,'') + ',' +  -- (ChewKP01)    
                       ISNULL(@c_CurrAisle          ,'') + ',' +      
                       ISNULL(@c_CurrPostAisle      ,'') + ',' +      
                       ISNULL(@c_CurrSlot           ,'') + ',' +      
                       ISNULL(@c_PreCreateCartnz    ,'') + ',' +      
                       ISNULL(@c_PromptCtnID        ,'') + ',' +      
                       ISNULL(@c_AllowMultipCtn     ,'') + ',' +      
                       ISNULL(@c_CtnValidLength     ,'') + ',' +      
                       ISNULL(@c_PickByPickMd       ,'') + ',' +      
                       ISNULL(@c_ErrorCode          ,'0') + ',' +      
                       ISNULL(@c_ErrMsg             ,'')      
     
      -- (ChewKP01)  
      --Add to RDT.RDTEventLog  
        
        
        
      EXEC RDT.rdt_STD_EventLog  
           @cActionType      = '1',   
           @cUserID          = @c_OperatorID,  
           @nMobileNo        = @n_Mobile,  
           @nFunctionID      = @n_Func,  
           @cFacility        = @c_Facility,  
           @cStorerKey       = @c_StorerKey,  
           @cRefNo1          = @c_DevSerialNo  
                                                               
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0       
   BEGIN      
      SET @c_RtnMessage = "101,Region 101,1,1,1,1,1,0,0,0,0,1,0,0,1,2,1,-1,0,0,0,'XX','XX','XX','XX',0,0,0,2,0,0,"      
   END      
     
  
      
END

GO