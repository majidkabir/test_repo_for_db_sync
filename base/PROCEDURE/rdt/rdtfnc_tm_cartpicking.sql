SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/  
/* Store procedure: rdtfnc_TM_CartPicking                                    */  
/* Copyright      : IDS                                                      */  
/*                                                                           */  
/* Purpose: RDT Task Manager - Putaway                                       */  
/*          Called By rdtfnc_TaskManager                                     */  
/*                                                                           */  
/* Modifications log:                                                        */  
/*                                                                           */  
/* Date        Rev  Author   Purposes                                        */  
/* 28-Jan-2014 1.0  James    SOS296464 Created                               */
/* 02-May-2014 1.1  ChewKP   Various changes (ChewKP01)                      */
/* 12-May-2014 1.2  James    Add eventlog (james01)                          */
/* 20-May-2014 1.3  ChewKP   Close Whole Cart when No Task in the Area       */
/*                           (ChewKP02)                                      */
/* 28-May-2014 1.4  Chee     Allow user to rescan SKU to relight in case of  */
/*                           deadlock issue                                  */
/*                           Add filter PTLTran.Status = 0 (Chee01)          */
/* 07-Nov-2014 1.5  James    Add (nolock) (james02)                          */
/* 30-Sep-2016 1.6  Ung      Performance tuning                              */
/* 01-Oct-2018 1.7  TungGH   Performance                                     */   
/*****************************************************************************/  
  
CREATE PROC [RDT].[rdtfnc_TM_CartPicking](  
   @nMobile    INT,  
   @nErrNo     INT  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max  
) AS  
    SET NOCOUNT ON  
    SET QUOTED_IDENTIFIER OFF  
    SET ANSI_NULLS OFF  
    SET CONCAT_NULL_YIELDS_NULL OFF  
  
-- Misc variable  
DECLARE  
   @b_success           INT  
  
-- Define a variable  
DECLARE  
   @nFunc               INT,  
   @nScn                INT,  
   @nStep               INT,  
   @cLangCode           NVARCHAR(3),  
   @nMenu               INT,  
   @nInputKey           NVARCHAR(3),  
   @cPrinter            NVARCHAR(10),  
   @cUserName           NVARCHAR(18),  
  
   @cStorerKey          NVARCHAR(15),  
   @cFacility           NVARCHAR(5),  
  
   @cAreaKey            NVARCHAR(10),  
   @cStrategykey        NVARCHAR(10),  
   @cTTMStrategykey     NVARCHAR(10),  
   @cTTMTasktype        NVARCHAR(10),  
   @cFromLoc            NVARCHAR(10),  
   @cSuggFromLoc        NVARCHAR(10),  
   @cToLoc              NVARCHAR(10),  
   @cSuggToLoc          NVARCHAR(10),  
   @cTaskdetailkey      NVARCHAR(10),  
   @cID                 NVARCHAR(18),  
   @cSuggID             NVARCHAR(18),  
   @cUOM                NVARCHAR(5),   -- Display NVARCHAR(5)  
   @cReasonCode         NVARCHAR(10),  
   @cSKU                NVARCHAR(20),  
   @cTaskStorer         NVARCHAR(15),  
   @cFromFacility       NVARCHAR(5),  
   @c_outstring         NVARCHAR(255),  
   @cUserPosition       NVARCHAR(10),  
   @cQTY                NVARCHAR(5),  
   @cPackkey            NVARCHAR(10),  
   @cNextTaskdetailkeyS NVARCHAR(10),  
  
   @cRefKey01           NVARCHAR(20),  
   @cRefKey02           NVARCHAR(20),  
   @cRefKey03           NVARCHAR(20),  
   @cRefKey04           NVARCHAR(20),  
   @cRefKey05           NVARCHAR(20),  
  
   @nQTY                INT,  
   @nToFunc             INT,  
   @nSuggQTY            INT,  
   @nPrevStep           INT,  
   @nFromStep           INT,  
   @nFromScn            INT,  
   @nToScn     INT,  
  
   @nOn_HandQty         INT,  
   @nTTL_Alloc_Qty      INT,  
   @nTaskDetail_Qty     INT,  
   @cLoc                NVARCHAR( 10),  
   @cDescr              NVARCHAR( 60),  
  
   @cPUOM               NVARCHAR( 1), -- Prefer UOM  
   @cSuggestPQTY        NVARCHAR( 5),  
   @cSuggestMQTY        NVARCHAR( 5),  
   @cActPQTY            NVARCHAR( 5),  
   @cActMQTY            NVARCHAR( 5),  
   @cPrepackByBOM       NVARCHAR( 1),  
  
   @nSum_PalletQty      INT,  
   @nActQTY             INT, -- Actual QTY  
   @nSuggestPQTY        INT, -- Suggested master QTY  
   @nSuggestMQTY        INT, -- Suggested prefered QTY  
   @nSuggestQTY         INT, -- Suggetsed QTY  
   @cCaseID             NVARCHAR(10),  
   @cInToteID           NVARCHAR(18),  
   @cInSKU              NVARCHAR(20),  
   @cLot                NVARCHAR(10),  
   @cComponentSKU       NVARCHAR(20),  
   @n_CaseCnt           INT,  
   @n_TotalPalletQTY    INT,  
   @n_TotalBOMQTY       INT,  
   @c_BOMSKU            NVARCHAR(20),  
   @c_VirtualLoc        NVARCHAR(10),  
   @c_PickMethod        NVARCHAR(10),  
   @c_ToteNo            NVARCHAR(18),  
   @cDescr1             NVARCHAR(20),  
   @cDescr2             NVARCHAR(20),  
   @nScanQty            INT,  
   @cSHTOption          NVARCHAR(1),  
   @cLoadkey            NVARCHAR(10),  
   @cContinueProcess    NVARCHAR(10),  
   @c_TaskDetailKeyPK   NVARCHAR(10),  
   @nRemainQty          INT,  
   @c_QCLOC             NVARCHAR(10),  
   @c_CurrPutawayzone   NVARCHAR(10),  
   @c_RTaskDetailkey    NVARCHAR(10),  
   @c_FinalPutawayzone  NVARCHAR(10),  
   @c_PPAZone           NVARCHAR(10),  
   @nTranCount          INT,  
   @cOrderkey           NVARCHAR(10),  
   @nTotalToteQTY       INT, -- (vicky03)  
   @cActionFlag         NVARCHAR(1), -- (shong01)  
   @cNewToteNo          NVARCHAR(18), -- (shong03)  
   @cShortPickFlag      NVARCHAR(1), -- (shong04)  
   @cRemoveTaskFromUserQueue  NVARCHAR(1),  -- (ChewKP13)  
   @c_CurrAREA          NVARCHAR(10),  
   @cPA_AreaKey         NVARCHAR(10),  
   @c_TMAutoShortPick   NVARCHAR(1), -- (ChewKP23)  
   @cAlertMessage       NVARCHAR( 255),       -- (james06)  
   @nStep_ConfirmTote   INT,              -- (james06)  
   @nScn_ConfirmTote    INT,              -- (james06)  
   @cModuleName         NVARCHAR( 45),     -- (james06)  
   @cOption             NVARCHAR( 1),         -- (james06)  
   @bSuccess            INT,              -- (james06)  
   @cDefaultToteLength  NVARCHAR( 1),         -- (james06)  
   @cDeviceID           NVARCHAR( 20), 
   @cSuggSKU            NVARCHAR( 20), 
   @cWaveKey            NVARCHAR( 10), 
   @cChangeToteID       NVARCHAR( 20), 
   @cOldToteID          NVARCHAR( 20), 
   @cNewToteID          NVARCHAR( 20), 
   @cNewTaskdetailkey   NVARCHAR( 10), 
   @cDeviceProfileLogKey NVARCHAR(10), -- (ChewKP01)
   @cRegExpression       NVARCHAR(60), -- (ChewKP01)
   @cAssignDropID        NVARCHAR(20), -- (ChewKP02)
  
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),  
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),  
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),  
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),  
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),  
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),  
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),  
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),  
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),  
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),  
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),  
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),  
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),  
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),  
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),  
  
   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),  
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),  
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),  
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),  
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),  
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),  
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),  
   @cFieldAttr15 NVARCHAR( 1)  
  
  
-- Getting Mobile information  
SELECT  
   @nFunc            = Func,  
   @nScn             = Scn,  
   @nStep            = Step,  
   @nInputKey        = InputKey,  
   @cLangCode        = Lang_code,  
   @nMenu            = Menu,  
  
   @cFacility        = Facility,  
   @cStorerKey       = StorerKey,  
   @cPrinter         = Printer,  
   @cUserName        = UserName,  
  
   @cSKU             = V_SKU,  
   @cFromLoc         = V_LOC,  
   @cID              = V_ID,  
   @cPUOM            = V_UOM,    
   @cLot             = V_Lot,  
   @cCaseID          = V_CaseID,  
   @cLoadKey         = V_LoadKey, -- (ChewKP01)
  
   @cWaveKey         = V_String1,  
   @c_PickMethod     = V_String2,  
   @cToLoc           = V_String3,  
   @cReasonCode      = V_String4,  
   @cTaskdetailkey   = V_String5,  
  
   @cSuggFromloc     = V_String6,  
   @cSuggToloc       = V_String7,  
   @cSuggID          = V_String8,    
   @cUserPosition    = V_String10,  
    
   @cNextTaskdetailkeyS = V_String12,  
   @cPackkey         = V_String13,    
   @cTaskStorer      = V_String16,  
   @cDescr1          = V_String17,  
   @cDescr2          = V_String18,    
   @cDeviceProfileLogKey  = V_String20,  -- (ChewKP01)
   @c_TaskDetailKeyPK  = V_String21,  
   @c_CurrPutawayzone  = V_String22,  
   @c_FinalPutawayzone = V_String23,  
   @c_PPAZone          = V_String24,  
   @cUOM               = V_String25,  
   @cOrderkey          = V_String26,  
   @cPUOM            = V_String27,  
   @cPrepackByBOM    = V_String28,    
   @cNewToteNo       = V_String30,  
   @cShortPickFlag   = V_String31,  
   
   @nQTY             = V_QTY,
   @nSuggQTY         = V_Integer1,
   @nScanQty         = V_Integer2,
   @nTotalToteQTY    = V_Integer3, -- (vicky03)
   
   @nPrevStep        = V_FromStep,
   --@nFromStep        = V_FromStep,  
   @nFromScn         = V_FromScn,
  
   @cAreakey         = V_String32,  
   @cTTMStrategykey  = V_String33,  
   @cTTMTasktype     = V_String34,  
   @cRefKey01        = V_String37,  
   @cRefKey02        = V_String38,  
   @cRefKey03        = V_String37,  
   @cRefKey04        = V_String38,  
   @cRefKey05        = V_String39,  
   @cDeviceID        = V_String40,  
  
   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  
  
   @cFieldAttr01 = FieldAttr01,    @cFieldAttr02   = FieldAttr02,  
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,  
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,  
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,  
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,  
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,  
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,  
   @cFieldAttr15 =  FieldAttr15  
FROM   RDT.RDTMOBREC (NOLOCK)  
WHERE  Mobile = @nMobile  
  
-- (Shong01)  
DECLARE @nStepShortPickCloseTote INT,  
        @nStepEmptyTote          INT,  
        @nStepFromLoc   INT,  
        @nStepReasonCode         INT,  
        @nStepDiffTote           INT,  
        @nStepWithToteNo         INT,  
        @nScnShortPickCloseTote  INT,  
        @nScnFromLoc           INT,  
        @nScnToteNo            INT,  
        @nScnEmptyTote         INT,  
        @nScnDiffTote          INT,  
        @nScnSKU               INT,  
        @nScnWithToteNo        INT  
  
  
-- Redirect to respective screen  
IF @nFunc = 1806  
BEGIN  
   IF @nStep = 1 GOTO Step_1   -- Menu. Func = 1760, Scn = 3740 -- TOTE ID ID (NEW TOTE)  
   IF @nStep = 2 GOTO Step_2   -- Scn = 3741   SKU  
   IF @nStep = 3 GOTO Step_3   -- Scn = 3742   CONFIRM/ CHANGE TOTE  
   IF @nStep = 4 GOTO Step_4   -- Scn = 3743   OLD TOTE / NEW TOTE  
   IF @nStep = 5 GOTO Step_5   -- Scn = 3744   ENTER FOR NEXT TASK / ESC FOR EXIT TM  
   IF @nStep = 6 GOTO Step_6   -- Scn = 3745   REASON Screen  
END  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 1. Called from Task Manager Main Screen (func = 1760)  
    Screen = 3740   
    CART ID:   (Field12)  
    FROM LOC:  (Field13, input)  
********************************************************************************/  
Step_1:  
BEGIN  
   -- Set all variable for 1st record - records are from rdtfnc_TaskManager  
   IF @nPrevStep = 0  
   BEGIN  
      SET @cTaskdetailkey = @cOutField06  
      SET @cAreaKey = @cOutField07  
      SET @cTTMStrategykey = @cOutField08  
      SET @c_PickMethod = @cOutField04  
      SET @cTTMTasktype = @cOutField09
      SET @cDeviceID = @cOutField12
  
      -- (Shong01)  
      SELECT @cTaskStorer = RTRIM(Storerkey),  
             @cSKU        = RTRIM(SKU),  
             @cSuggID     = RTRIM(FromID),  
             @cSuggToLoc  = RTRIM(ToLOC),  
             @cLot        = RTRIM(Lot),  
             @cSuggFromLoc  = RTRIM(FromLoc),  
             @nSuggQTY    = Qty,  
             @cLoadkey    = RTRIM(Loadkey),  
             @cWaveKey    = RTRIM(WaveKey) 
      FROM dbo.TaskDetail WITH (NOLOCK)  
      WHERE TaskDetailKey = @cTaskdetailkey  
  
      SELECT @c_CurrPutawayzone = Putawayzone  
      FROM LOC WITH (NOLOCK)  
      WHERE LOC = @cSuggFromLoc  
      AND Facility = @cFacility  
  
      SELECT @c_FinalPutawayzone = Putawayzone  
      FROM LOC WITH (NOLOCK)  
      WHERE LOC = @cSuggToLoc  
      AND Facility = @cFacility  

      -- (james02) EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '1', -- Sign in function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep

      -- TaskdetailKey missing if ESC FROMLOC screen (Chee01)
      SET @nPrevStep = 1 
   END  
  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      SET @cFieldAttr01 = ''  
      SET @cFieldAttr02 = ''  
      SET @cFieldAttr03 = ''  
      SET @cFieldAttr04 = ''  
      SET @cFieldAttr05 = ''  
      SET @cFieldAttr06 = ''  
      SET @cFieldAttr07 = ''  
      SET @cFieldAttr08 = ''  
      SET @cFieldAttr09 = ''  
      SET @cFieldAttr10 = ''  
      SET @cFieldAttr11 = ''  
      SET @cFieldAttr12 = ''  
      SET @cFieldAttr13 = ''  
      SET @cFieldAttr14 = ''  
      SET @cFieldAttr15 = ''  
  
        -- Screen mapping    
      SET @cFromLoc = @cInField13    
      
      IF ISNULL(@cFromLoc, '') = ''    
      BEGIN    
         SET @nErrNo = 84401    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FROMLOC req    
         GOTO Step_1_Fail    
      END    

      IF ISNULL( @cSuggFromLoc, '') <> ISNULL(@cFromLoc, '')     
      BEGIN    
         SET @nErrNo = 84402    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC NOT MATCH    
         GOTO Step_1_Fail    
      END    

      SET @nErrNo = 0
      EXEC [RDT].[rdt_CartPicking_InsertPTLTran] 
          @nMobile          =  @nMobile
         ,@nFunc            =  @nFunc
         ,@cFacility        =  @cFacility
         ,@cStorerKey       =  @cTaskStorer
         ,@cDeviceID        =  @cDeviceID
         ,@cFromLOC         =  @cFromLOC
         ,@cSKU             =  @cSKU
         ,@cWaveKey         =  @cWaveKey
         ,@cTaskDetailKey   =  @cTaskDetailKey
         ,@cLangCode        =  @cLangCode
         ,@nErrNo           =  @nErrNo       OUTPUT
         ,@cErrMsg          =  @cErrMsg      OUTPUT

      IF @nErrNo <> 0
         GOTO Step_1_Fail
         
      -- Get DeviceProfileLogKey -- (ChewKP01)
      SET @cDeviceProfileLogKey = ''
      SELECT Top 1 @cDeviceProfileLogKey = DeviceProfileLogKey
      FROM dbo.PTLTran WITH (NOLOCK)
      WHERE SourceKey = @cWaveKey
      AND SKU         = @cSKU 
      AND StorerKEy   = @cStorerKey
      AND Loc         = @cFromLoc
      AND PTL_Type     = 'Pick2Cart'
      AND Status       = '0'  -- else will get completed deviceprofilelogkey (Chee01)
      
      SET @cOutField01 = @cDeviceID        -- CART ID
      SET @cOutField02 = @cFromLoc        -- FROMLOC
      SET @cOutField03 = @cSKU            -- SUGGESTED SKU
      SET @cOutField04 = ''               -- DISPLAY 
      --SET @cOutField05 = @cTTMTasktype    -- TAKSTYPE
      SET @cOutField05 = @c_PickMethod    -- PICKMETHOD

      -- Go to next screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      
      IF @cUserPosition = ''  
      BEGIN  
         SET @cUserPosition = '1'  
      END  
  
      --SET @cOutField09 = @cOutField01  
      SET @cOutField01 = ''  
      --SET @cOutField02 = @cTTMTasktype  
      SET @cOutField02 = @c_PickMethod    -- PICKMETHOD
  
      SET @nFromScn  = @nScn  
      --SET @nFromStep = @nStep  
      SET @nPrevStep = @nStep
  
      -- Go to Reason Code Screen  
      SET @nScn  = @nScn + 5  
      SET @nStep = @nStep + 5 -- Step 6  
   END  
   GOTO Quit  
  
   Step_1_Fail:  
   BEGIN  
      -- Reset this screen var  
      SET @cFromLoc = ''  
  
      SET @cOutField01 = @cSuggFromLoc -- Suggested FromLOC  
      --SET @cOutField09 = @cTTMTasktype -- Task Type  
      SET @cOutField09 = @c_PickMethod    -- PICKMETHOD
      SET @cOutField12 = @cDeviceID    -- Cart ID
      SET @cOutField13 = ''            -- Display
  END  
END  
GOTO Quit  

/********************************************************************************  
Step 2.  
    Screen = 3741   
    CART ID:   (Field12)  
    FROM LOC:  (Field01)  
    SKU/UPC:   (Field05, input)  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping    
      SET @cSuggSKU = @cInField04    
      
      IF ISNULL(@cSuggSKU, '') = ''    
      BEGIN    
         SET @nErrNo = 84403    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU req    
         GOTO Step_2_Fail    
      END    

      IF ISNULL( @cSKU, '') <> ISNULL(@cSuggSKU, '')     
      BEGIN    
         SET @nErrNo = 84404    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NOT MATCH    
         GOTO Step_2_Fail    
      END    

      -- Get SKU count    
      DECLARE @nSKUCnt INT    
      EXEC [RDT].[rdt_GETSKUCNT]    
          @cStorerKey  = @cTaskStorer    
         ,@cSKU        = @cSKU    
         ,@nSKUCnt     = @nSKUCnt       OUTPUT    
         ,@bSuccess    = @bSuccess      OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
    
      -- Validate SKU/UPC    
      IF @nSKUCnt = 0    
      BEGIN    
         SET @nErrNo = 84405    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU    
         GOTO Step_2_Fail    
      END    
    
      -- Validate barcode return multiple SKU    
      IF @nSKUCnt > 1    
      BEGIN    
         SET @nErrNo = 84406    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameBarCodeSKU    
         GOTO Step_2_Fail    
      END    
    
      -- Get SKU    
      EXEC [RDT].[rdt_GETSKU]    
          @cStorerKey  = @cTaskStorer    
         ,@cSKU        = @cSKU          OUTPUT    
         ,@bSuccess    = @bSuccess      OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
         
      SELECT @cDescr1 = SUBSTRING(DESCR, 1, 20),  
             @cDescr2 = SUBSTRING(DESCR,21, 20)   
      FROM dbo.SKU WITH (NOLOCK)  
      WHERE  SKU = @cSKU  
      AND    Storerkey = @cTaskStorer 
      
      --To ReLight (ChewKP01)
      IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK) -- (james02)
                  WHERE SourceKey = @cWaveKey 
                  AND SKU         = @cSKU
                  AND Status      = '1'
                  AND PTL_Type     = 'Pick2Cart'
                  AND DeviceProfileLogKey = @cDeviceProfileLogKey )   
      BEGIN
         UPDATE dbo.PTLTran WITH (ROWLOCK)   
           SET Status = '0'  
         WHERE DeviceProfileLogKey = @cDeviceProfileLogKey  
         AND SKU = @cSKU
         AND SourceKey = @cWaveKey
         AND Status = '1'  
         AND PTL_Type     = 'Pick2Cart'
     
         IF @@ERROR <> 0   
         BEGIN  
            SET @nErrNo = 84426 -- 83840 (Chee01)  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTLTranFail'    
            GOTO Step_2_Fail   
         END  
      END
      
      SET @nErrNo = 0
      EXEC [RDT].[rdt_CartrPicking_LightUp] 
           @nMobile          = @nMobile
          ,@nFunc            = @nFunc
          ,@cFacility        = @cFacility
          ,@cStorerKey       = @cTaskStorer
          ,@cCartID          = @cDeviceID
          ,@cLoc             = @cFromLOC
          ,@cSKU             = @cSKU
          ,@cWaveKey         = @cWaveKey
          ,@cLangCode        = @cLangCode
          ,@nErrNo           = @nErrNo       OUTPUT
          ,@cErrMsg          = @cErrMsg      OUTPUT -- screen limitation, 20 char max

      IF @nErrNo <> 0
         GOTO Step_2_Fail

      SET @cOutField01 = @cDeviceID        -- CART ID
      SET @cOutField02 = @cFromLoc        -- FROMLOC
      SET @cOutField03 = @cSKU            -- SUGGESTED SKU
      SET @cOutField04 = @cDescr1         -- DESCR
      SET @cOutField05 = @cDescr2         -- DESCR
      SET @cOutField06 = ''               -- CHANGE TOTE ID
      --SET @cOutField07 = @cTTMTasktype    -- TAKSTYPE
      SET @cOutField07 = @c_PickMethod    -- PICKMETHOD
      
      -- Go to next screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  

   IF @nInputKey = 0 -- ESC  
   BEGIN  
      
      IF @cUserPosition = ''  
      BEGIN  
         SET @cUserPosition = '1'  
      END  
  
      -- Reset this screen var  
      SET @cFromLoc = ''  
  
      SET @cOutField01 = @cSuggFromLoc -- Suggested FromLOC  
      --SET @cOutField09 = @cTTMTasktype -- Task Type  
      SET @cOutField09 = @c_PickMethod    -- PICKMETHOD
      SET @cOutField12 = @cDeviceID    -- Cart ID
      SET @cOutField13 = ''            -- Display
  
      -- Go to Prev Screen  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1 
   END  
   GOTO Quit  
  
   Step_2_Fail:  
   BEGIN  
      -- Reset this screen var  
      SET @cSuggSKU = ''  
  
      SET @cOutField01 = @cDeviceID        -- CART ID
      SET @cOutField02 = @cFromLoc        -- FROMLOC
      SET @cOutField03 = @cSKU            -- SUGGESTED SKU
      SET @cOutField04 = ''               -- DISPLAY 
      --SET @cOutField09 = @cTTMTasktype    -- TAKSTYPE
      SET @cOutField09 = @c_PickMethod    -- PICKMETHOD
  END  
END  
GOTO Quit  

/********************************************************************************  
Step 3.  
    Screen = 3741   
    CART ID:            (Field01)  
    FROM LOC:           (Field02)  
    SKU:                (Field03)  
    DESCR:              (Field04)  
    DESCR:              (Field05)  
    CHANGE TOTE ID:     (Field06, input)  
********************************************************************************/  
Step_3:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      SET @cChangeToteID = @cInfield06

      -- Check if existing tote
      IF ISNULL( @cChangeToteID, '') <> ''
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.DevicEProfileLog DL WITH (NOLOCK) 
                         JOIN dbo.DeviceProfile D WITH (NOLOCK) ON (DL.DeviceProfileKey = D.DeviceProfileKey )
                         WHERE D.DeviceID = @cDeviceID
                         AND   D.Status = '3'
                         AND   D.DeviceType = 'CART'
                         AND   DL.Status = '3'
                         AND   DL.DropID = @cChangeToteID)
         BEGIN
            SET @nErrNo = 84411
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID TOTE'
            GOTO Step_3_Fail
         END
         
         SET @cOutField01 = @cChangeToteID
         SET @cOutField02 = ''
         --SET @cOutField03 = @cTTMTasktype
         SET @cOutField03 = @c_PickMethod    -- PICKMETHOD
         
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO QUIT  
      END
      
      -- Check If All Pick Done before Proceed to Next Location / Action
      IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)
                  WHERE DeviceID = @cDeviceID
                  AND   Loc      = @cFromLOC
                  AND   SKU      = @cSKU
                  -- Encounter situation where PTLTran.Status remain at 0 even light up,  
                  -- user press light but hit Record Not Found - isp_DPC_Inbound.
                  -- Block user here to let them esc and rescan sku to redo else taskdetail will update to 9  (Chee01)  
                  --AND   Status = '1' )
                  AND Status IN ('0', '1') )
      BEGIN
         SET @nErrNo = 84406
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PickNotComplete'
         GOTO Step_3_Fail
      END      
      ELSE
      BEGIN
         SET @nTranCount = @@TRANCOUNT

         BEGIN TRAN
         SAVE TRAN PTL_Cart_ConfirmTask

         -- Confirm the task for the loc and sku
         UPDATE TD WITH (ROWLOCK) 
         SET  TD.STATUS = '9'  
             ,TD.UserKey = @cUserName  
             ,TD.ReasonKey = ''
             ,TD.EditDate = GetDate()     
             ,TD.EditWho  = sUSER_sNAME() 
             ,TD.TrafficCop = NULL 
         FROM dbo.TaskDetail TD 
         JOIN dbo.LOC LOC ON (TD.FROMLOC = LOC.LOC)
         JOIN dbo.AREADETAIL AD ON (LOC.PutawayZone = AD.PutawayZone)
         WHERE TD.Storerkey = @cTaskStorer  
         AND   TD.TaskType = 'SPK'  
         AND   TD.UserKey = @cUserName  
         AND   TD.Status = '3'  
         AND   TD.WaveKey = @cWaveKey  
         AND   TD.FromLOC = @cFromLOC
         AND   TD.SKU = @cSKU
         AND   AD.AreaKey = @cAreaKey

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN PTL_Cart_ConfirmTask    
            WHILE @@TRANCOUNT > @nTranCount    
               COMMIT TRAN    
            SET @nErrNo = 84407
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD TASK FAIL'
            GOTO Step_3_Fail
         END
            
         -- Terminate all light
         EXEC [dbo].[isp_DPC_TerminateAllLight] 
             @c_StorerKey   = @cTaskStorer
            ,@c_DeviceID    = @cDeviceID
            ,@b_Success     = @b_Success    OUTPUT  
            ,@n_Err         = @nErrNo       OUTPUT
            ,@c_ErrMsg      = @cErrMsg      OUTPUT

         IF @nErrNo <> 0 
         BEGIN
            ROLLBACK TRAN PTL_Cart_ConfirmTask    
            WHILE @@TRANCOUNT > @nTranCount    
               COMMIT TRAN    
            SET @cErrMsg = LEFT(@cErrMsg,1024) 
            GOTO Step_3_Fail
         END

         WHILE @@TRANCOUNT > @nTranCount    
            COMMIT TRAN    
               
         -- Check if exists same LOC but diff SKU to pick
         SET @cNewTaskdetailkey = ''
         SELECT @cNewTaskdetailkey = Taskdetailkey FROM dbo.TaskDetail WITH (NOLOCK) 
         WHERE FromLOC = @cFromLOC
         AND   SKU <> @cSKU
         AND   Status = '3'
         AND   UserKey = @cUserName
         AND   StorerKey = @cTaskStorer

         IF ISNULL( @cNewTaskdetailkey, '') <> ''
         BEGIN
            SET @cTaskdetailkey = @cNewTaskdetailkey
            SELECT @cTaskStorer = RTRIM(Storerkey),  
                   @cSKU        = RTRIM(SKU),  
                   @cSuggID     = RTRIM(FromID),  
                   @cSuggToLoc  = RTRIM(ToLOC),  
                   @cLot        = RTRIM(Lot),  
                   @cSuggFromLoc  = RTRIM(FromLoc),  
                   @nSuggQTY    = Qty,  
                   @cLoadkey    = RTRIM(Loadkey),  
                   @cWaveKey    = RTRIM(WaveKey) 
            FROM dbo.TaskDetail WITH (NOLOCK)  
            WHERE TaskDetailKey = @cTaskdetailkey  
      
            SET @cOutField01 = @cDeviceID        -- CART ID
            SET @cOutField02 = @cFromLoc        -- FROMLOC
            SET @cOutField03 = @cSKU            -- SUGGESTED SKU
            SET @cOutField04 = ''               -- DISPLAY 
            --SET @cOutField05 = @cTTMTasktype    -- TAKSTYPE
            SET @cOutField05 = @c_PickMethod    -- PICKMETHOD

            -- Go to next screen  
            SET @nScn = @nScn - 1  
            SET @nStep = @nStep - 1  
         END
         ELSE
         BEGIN
            --SET @cOutField05 = @cTTMTasktype
            SET @cOutField05 = @c_PickMethod    -- PICKMETHOD
            
            -- Go to ENTER/ESC TM screen  
            SET @nScn = @nScn + 2  
            SET @nStep = @nStep + 2  
         END
      END
   END  

   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Allow user to rescan SKU to relight in case of deadlock issue (Chee01)
      IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)
                  WHERE DeviceProfileLogKey = @cDeviceProfileLogKey  
                    AND DeviceID  = @cDeviceID
                    AND SourceKey = @cWaveKey
                    AND StorerKey = @cStorerKey
                    AND SKU       = @cSKU
                    AND Loc       = @cFromLOC
                    AND Status    = '1'
                    AND PTL_Type  = 'Pick2Cart' )   
      BEGIN
         UPDATE dbo.PTLTran WITH (ROWLOCK)   
           SET Status = '0'  
         WHERE DeviceProfileLogKey = @cDeviceProfileLogKey  
           AND DeviceID  = @cDeviceID
           AND SourceKey = @cWaveKey
           AND StorerKey = @cStorerKey
           AND SKU       = @cSKU
           AND Loc       = @cFromLOC
           AND Status    = '1'
           AND PTL_Type  = 'Pick2Cart'

         IF @@ERROR <> 0   
         BEGIN  
            SET @nErrNo = 84427  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTLTranFail'    
            GOTO Step_3_Fail   
         END  
      END

      -- Terminate all light
      EXEC [dbo].[isp_DPC_TerminateAllLight] 
          @c_StorerKey   = @cTaskStorer
         ,@c_DeviceID    = @cDeviceID
         ,@b_Success     = @b_Success    OUTPUT  
         ,@n_Err         = @nErrNo       OUTPUT
         ,@c_ErrMsg      = @cErrMsg      OUTPUT

      IF @nErrNo <> 0 
      BEGIN
         SET @cErrMsg = LEFT(@cErrMsg,1024) 
         GOTO Step_3_Fail
      END
  
      -- Reset this screen var  
      SET @cSuggSKU = ''  
  
      SET @cOutField01 = @cDeviceID        -- CART ID
      SET @cOutField02 = @cFromLoc        -- FROMLOC
      SET @cOutField03 = @cSKU            -- SUGGESTED SKU
      SET @cOutField04 = ''               -- DISPLAY 
      SET @cOutField05 = @cTTMTasktype    -- TAKSTYPE
  
      -- Go to Prev Screen  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1 

/* (Chee01)
      -- Check If All Pick Done before Proceed to Next Location / Action
      IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)
                  WHERE DeviceID = @cDeviceID
                  AND   Loc      = @cFromLOC
                  AND   SKU      = @cSKU
                  AND   Status = '1' )
      BEGIN
         SET @nErrNo = 84417
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PickNotComplete'
         GOTO Step_3_Fail
      END      
      ELSE
      BEGIN
         SET @nTranCount = @@TRANCOUNT

         BEGIN TRAN
         SAVE TRAN PTL_Cart_ConfirmTask

         -- Confirm the task for the loc and sku
         UPDATE TD WITH (ROWLOCK) 
         SET  TD.STATUS = '9'  
             ,TD.UserKey = @cUserName  
             ,TD.ReasonKey = ''
             ,TD.EditDate = GetDate()     
             ,TD.EditWho  = sUSER_sNAME() 
             ,TD.TrafficCop = NULL 
         FROM dbo.TaskDetail TD 
         JOIN dbo.LOC LOC ON (TD.FROMLOC = LOC.LOC)
         JOIN dbo.AREADETAIL AD ON (LOC.PutawayZone = AD.PutawayZone)
         WHERE TD.Storerkey = @cTaskStorer  
         AND   TD.TaskType = 'SPK'  
         AND   TD.UserKey = @cUserName  
         AND   TD.Status = '3'  
         AND   TD.WaveKey = @cWaveKey  
         AND   TD.FromLOC = @cFromLOC
         AND   TD.SKU = @cSKU
         AND   AD.AreaKey = @cAreaKey

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN PTL_Cart_ConfirmTask    
            WHILE @@TRANCOUNT > @nTranCount    
               COMMIT TRAN    
            SET @nErrNo = 84418
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD TASK FAIL'
            GOTO Step_3_Fail
         END
            
         -- Terminate all light
         EXEC [dbo].[isp_DPC_TerminateAllLight] 
             @c_StorerKey   = @cTaskStorer
            ,@c_DeviceID    = @cDeviceID
            ,@b_Success     = @b_Success    OUTPUT  
            ,@n_Err         = @nErrNo       OUTPUT
            ,@c_ErrMsg      = @cErrMsg      OUTPUT

         IF @nErrNo <> 0 
         BEGIN
            ROLLBACK TRAN PTL_Cart_ConfirmTask    
            WHILE @@TRANCOUNT > @nTranCount    
               COMMIT TRAN    
            SET @cErrMsg = LEFT(@cErrMsg,1024) 
            GOTO Step_3_Fail
         END

         WHILE @@TRANCOUNT > @nTranCount    
            COMMIT TRAN    
               
         -- Check if exists same LOC but diff SKU to pick
         SET @cNewTaskdetailkey = ''
         SELECT @cNewTaskdetailkey = Taskdetailkey FROM dbo.TaskDetail WITH (NOLOCK) 
         WHERE FromLOC = @cFromLOC
         AND   SKU <> @cSKU
         AND   Status = '3'
         AND   UserKey = @cUserName
         AND   StorerKey = @cTaskStorer

         IF ISNULL( @cNewTaskdetailkey, '') <> ''
         BEGIN
            SET @cTaskdetailkey = @cNewTaskdetailkey
            SELECT @cTaskStorer = RTRIM(Storerkey),  
                   @cSKU        = RTRIM(SKU),  
                   @cSuggID     = RTRIM(FromID),  
                   @cSuggToLoc  = RTRIM(ToLOC),  
                   @cLot        = RTRIM(Lot),  
                   @cSuggFromLoc  = RTRIM(FromLoc),  
                   @nSuggQTY    = Qty,  
                   @cLoadkey    = RTRIM(Loadkey),  
                   @cWaveKey    = RTRIM(WaveKey) 
            FROM dbo.TaskDetail WITH (NOLOCK)  
            WHERE TaskDetailKey = @cTaskdetailkey  
      
            SET @cOutField01 = @cDeviceID        -- CART ID
            SET @cOutField02 = @cFromLoc        -- FROMLOC
            SET @cOutField03 = @cSKU            -- SUGGESTED SKU
            SET @cOutField04 = ''               -- DISPLAY 
            --SET @cOutField05 = @cTTMTasktype    -- TAKSTYPE
            SET @cOutField05 = @c_PickMethod    -- PICKMETHOD

            -- Go to next screen  
            SET @nScn = @nScn - 1  
            SET @nStep = @nStep - 1  
         END
         ELSE
         BEGIN
            --SET @cOutField05 = @cTTMTasktype
            SET @cOutField05 = @c_PickMethod    -- PICKMETHOD
            -- Go to ENTER/ESC TM screen  
            SET @nScn = @nScn + 2  
            SET @nStep = @nStep + 2  
         END
      END
*/

      /*
      -- (ChewKP01)  
      IF @cUserPosition = ''  
      BEGIN  
         SET @cUserPosition = '1'  
      END  
  
      -- Reset this screen var  
      SET @cSuggSKU = ''  
  
      SET @cOutField01 = @cDeviceID        -- CART ID
      SET @cOutField02 = @cFromLoc        -- FROMLOC
      SET @cOutField03 = @cSKU            -- SUGGESTED SKU
      SET @cOutField04 = ''               -- DISPLAY 
      SET @cOutField05 = @cTTMTasktype    -- TAKSTYPE
  
      -- Go to Prev Screen  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1 
      */
   END  
   GOTO Quit  

   Step_3_Fail:  
   BEGIN  
      -- Reset this screen var  
      SET @cSuggSKU = ''  
  
      SET @cOutField01 = @cDeviceID        -- CART ID
      SET @cOutField02 = @cFromLoc        -- FROMLOC
      SET @cOutField03 = @cSKU            -- SUGGESTED SKU
      SET @cOutField04 = @cDescr1         -- DESCR
      SET @cOutField05 = @cDescr2         -- DESCR
      SET @cOutField06 = ''               -- CHANGE TOTE ID
      --SET @cOutField07 = @cTTMTasktype    -- TAKSTYPE
      SET @cOutField07 = @c_PickMethod    -- PICKMETHOD
  END  
END  
GOTO Quit  

/********************************************************************************  
Step 4.  
    Screen = 3743   
    OLD TOTE ID:        (Field01)  
    NEW TOTE ID:        (Field02, input)  
********************************************************************************/  
Step_4:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN 
      -- Field mapping 
      SET @cOldToteID = @cOutField01
      SET @cNewToteID = @cInfield02

      IF ISNULL (@cNewToteID, '') = ''
      BEGIN
         SET @nErrNo = 84412  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TOTE ID REQ  
         GOTO Step_4_Fail  
      END

      IF EXISTS ( SELECT 1 FROM dbo.DevicEProfileLog DL WITH (NOLOCK) 
                  JOIN dbo.DeviceProfile D WITH (NOLOCK) ON (DL.DeviceProfileKey = D.DeviceProfileKey )
                  WHERE D.DeviceID = @cDeviceID
                  AND   D.Status = '3'
                  AND   D.DeviceType = 'CART'
                  AND   DL.Status = '3'
                  AND   DL.DropID = @cNewToteID)
      BEGIN
         SET @nErrNo = 84413
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TOTE ID EXISTS'
         GOTO Step_4_Fail
      END

      IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cNewToteID AND [Status] < '9')
      BEGIN
         SET @nErrNo = 84419
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TOTE ID EXISTS'
         GOTO Step_4_Fail
      END

      IF EXISTS (SELECT 1 FROM dbo.CodeLkUp WITH (NOLOCK)    
                 WHERE Listname = 'XValidTote'    
                 AND Code = SUBSTRING(RTRIM(@cNewToteID), 1, 1))    
      BEGIN    
         SET @nErrNo = 84420    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvToteNo    
         GOTO Step_4_Fail    
      END   
      
      -- (ChewKP01)
      SET @cRegExpression = ''
      SELECT TOP 1 @cRegExpression = UDF01 
      FROM dbo.Codelkup WITH (NOLOCK) 
      WHERE ListName = 'XValidTote'
      
      IF ISNULL(RTRIM(@cRegExpression),'')  <> ''
      BEGIN
         IF master.dbo.RegExIsMatch(@cRegExpression, RTRIM( @cNewToteID), 1) <> 1   -- (ChewKP01)  
         BEGIN
            SET @nErrNo = 84421    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidCartonID    
            GOTO STEP_4_FAIL  
         END 
      END        

      -- Process change tote
      SET @nErrNo = 0
      EXEC [RDT].[rdt_CartPicking_ChangeTote]  
         @nMobile    = @nMobile
        ,@nFunc      = @nFunc
        ,@cDeviceID  = @cDeviceID
        ,@cOldToteID = @cOldToteID
        ,@cNewToteID = @cNewToteID
        ,@cLangCode  = @cLangCode
        ,@nErrNo     = @nErrNo       OUTPUT  
        ,@cErrMsg    = @cErrMsg      OUTPUT -- screen limitation, 20 char max  

      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 84414
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CHG TOTE FAIL'
         GOTO Step_4_Fail
      END

      SET @cOutField01 = @cDeviceID        -- CART ID
      SET @cOutField02 = @cFromLoc        -- FROMLOC
      SET @cOutField03 = @cSKU            -- SUGGESTED SKU
      SET @cOutField04 = @cDescr1         -- DESCR
      SET @cOutField05 = @cDescr2         -- DESCR
      SET @cOutField06 = ''               -- CHANGE TOTE ID
      --SET @cOutField07 = @cTTMTasktype    -- TAKSTYPE
      SET @cOutField07 = @c_PickMethod    -- PICKMETHOD

      -- Go to Prev Screen  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1 
   END

   IF @nInputKey = 0 -- ESC  
   BEGIN  
      SET @cOutField01 = @cDeviceID        -- CART ID
      SET @cOutField02 = @cFromLoc        -- FROMLOC
      SET @cOutField03 = @cSKU            -- SUGGESTED SKU
      SET @cOutField04 = @cDescr1         -- DESCR
      SET @cOutField05 = @cDescr2         -- DESCR
      SET @cOutField06 = ''               -- CHANGE TOTE ID
      --SET @cOutField07 = @cTTMTasktype    -- TAKSTYPE
      SET @cOutField07 = @c_PickMethod    -- PICKMETHOD

      -- Go to Prev Screen  
      SET @nScn  = @nScn - 1  
      SET @nStep = @nStep - 1 
   END
   GOTO Quit
   
   Step_4_Fail:
   BEGIN
      SET @cNewToteID = ''

      SET @cOutField01 = @cOldToteID
      SET @cOutfield02 = ''
      --SET @cOutfield03 = @cTTMTasktype
      SET @cOutField03 = @c_PickMethod    -- PICKMETHOD
   END
END
GOTO Quit

/********************************************************************************  
Step 5. screen = 2434 Close Tote  
     Success Message    ENTER = Next Task  
     ESC  = Exit TM  
********************************************************************************/  
Step_5:  
BEGIN  
   IF @nInputKey = 1 --OR @nInputKey = 0 -- ENTER / ESC  
   BEGIN  
      SET @nTranCount = @@TRANCOUNT

      BEGIN TRAN
      SAVE TRAN PTL_Cart_ConfirmTask

      -- GETNEXTTASK:  
      -- Search for next task and redirect screen  
      EXEC dbo.nspTMTM01  
          @c_sendDelimiter = null  
       ,  @c_ptcid         = 'RDT'  
       ,  @c_userid        = @cUserName  
       ,  @c_taskId        = 'RDT'  
       ,  @c_databasename  = NULL  
       ,  @c_appflag       = NULL  
       ,  @c_recordType    = NULL  
       ,  @c_server        = NULL  
       ,  @c_ttm           = NULL  
       ,  @c_areakey01     = @cAreaKey  
       ,  @c_areakey02     = ''  
       ,  @c_areakey03     = ''  
       ,  @c_areakey04     = ''  
       ,  @c_areakey05    = ''  
       ,  @c_lastloc       = @cSuggToLoc  
       ,  @c_lasttasktype  = 'TPK'  
       ,  @c_outstring     = @c_outstring    OUTPUT  
       ,  @b_Success       = @b_Success      OUTPUT  
       ,  @n_err           = @nErrNo         OUTPUT  
       ,  @c_errmsg        = @cErrMsg        OUTPUT  
       ,  @c_taskdetailkey = @cNextTaskdetailkeyS OUTPUT  
       ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT  
       ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func  
       ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func  
       ,  @c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func  
       ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func  
       ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func  

      IF ISNULL(RTRIM(@cNextTaskdetailkeyS), '') = '' --@nErrNo = 67804 -- Nothing to do!  
      BEGIN  
         -- (ChewKP02)
         -- Close Whole Cart When No more Task in this area
         DECLARE curCloseCart CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         
         SELECT DL.DropID
         FROM dbo.DeviceProfileLog DL WITH (NOLOCK) 
         INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey
         INNER JOIN dbo.DropID DR WITH (NOLOCK) ON DR.DropID = DL.DropID
         WHERE D.DeviceID = @cDeviceID
         AND D.Status = '1'
         AND DR.DropIDType = 'CART'
         AND DR.Status = '1' 
         
         
         OPEN curCloseCart
         FETCH NEXT FROM curCloseCart INTO @cAssignDropID
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            
            --DropID Not Picked 
            Update dbo.DropID
            SET Status = '9'
            WHERE DropID = @cAssignDropID
            AND Status = '1'
            
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 84424
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDPLogFailed'
               GOTO Step_5_Fail
            END
            
            FETCH NEXT FROM curCloseCart INTO @cAssignDropID
         END
         CLOSE curCloseCart
         DEALLOCATE curCloseCart
         
         -- UPDATE DeviceProfileLog.Status = 9
         UPDATE dbo.DeviceProfileLog
            SET Status = '9', ConsigneeKey = ''
         FROM dbo.DeviceProfileLog DL WITH (NOLOCK) 
         INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey
         WHERE D.DeviceID = @cDeviceID
         --AND D.Status = '3' -- (ChewKP02) 
         
         IF @@ERROR <> 0 
         BEGIN
            ROLLBACK TRAN PTL_Cart_ConfirmTask    
            WHILE @@TRANCOUNT > @nTranCount    
               COMMIT TRAN    
            SET @nErrNo = 84408
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDPLogFailed'
            GOTO Step_5_Fail
         END
         
         -- UPDATE DeviceProfile.Status = 9
         UPDATE dbo.DeviceProfile
         SET Status = '9', DeviceProfileLogKey = ''
         WHERE DeviceID = @cDeviceID
          -- AND Status = '3' -- (ChewKP02)
            
         IF @@ERROR <> 0 
         BEGIN
            ROLLBACK TRAN PTL_Cart_ConfirmTask    
            WHILE @@TRANCOUNT > @nTranCount    
               COMMIT TRAN    
            SET @nErrNo = 84409
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDPFailed'
            GOTO Step_5_Fail
         END
         
         -- Go back to Task Manager Main Screen  
         SET @nFunc = 1756  
         SET @nScn = 2100  
         SET @nStep = 1  

         SET @cErrMsg = 'No More Task'  
         SET @cAreaKey = ''  

         SET @cOutField01 = ''  -- Area  
         SET @cOutField02 = ''  
         SET @cOutField03 = ''  
         SET @cOutField04 = ''  
         SET @cOutField05 = ''  
         SET @cOutField06 = ''  
         SET @cOutField07 = ''  
         SET @cOutField08 = ''  
         SET @cOutField09 = ''  

       -- EventLog - Sign In Function  (james01)
       EXEC RDT.rdt_STD_EventLog
          @cActionType = '9', -- Sign out function
          @cUserID     = @cUserName,
          @nMobileNo   = @nMobile,
          @nFunctionID = @nFunc,
          @cFacility   = @cFacility,
          @cStorerKey  = @cStorerKey,
          @nStep       = @nStep
             
         -- Commit before we quit
         WHILE @@TRANCOUNT > @nTranCount    
         COMMIT TRAN    
            
         GOTO QUIT  
      END  

      IF ISNULL(@cErrMsg, '') <> ''  
      BEGIN  
         ROLLBACK TRAN PTL_Cart_ConfirmTask    
         WHILE @@TRANCOUNT > @nTranCount    
            COMMIT TRAN    
         SET @cErrMsg = @cErrMsg  
         GOTO Step_5_Fail  
      END  
  
      IF ISNULL(@cNextTaskdetailkeyS, '') <> ''  
      BEGIN  
         SELECT @cRefKey03 = CASE WHEN TaskType = 'PA' THEN CaseID ELSE DropID END,  
                @cRefkey04 = PickMethod,  
                @c_PickMethod = PickMethod,  
                @cTTMTasktype = TaskType  
         From dbo.TaskDetail WITH (NOLOCK)  
         WHERE TaskDetailkey = @cNextTaskdetailkeyS  

         SET @cTaskdetailkey = @cNextTaskdetailkeyS  

         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)  
                     WHERE TaskDetailKey = @cTaskdetailkey  
                     AND STATUS <> '9' )  
         BEGIN  
            UPDATE dbo.TaskDetail WITH (ROWLOCK) SET  
               Starttime = GETDATE(),  
               Editdate = GETDATE(),  
               EditWho = @cUserName,  
               TrafficCOP = NULL 
            WHERE TaskDetailKey = @cTaskdetailkey  
            AND STATUS <> '9'  

            IF @@ERROR <> 0  
            BEGIN  
               ROLLBACK TRAN PTL_Cart_ConfirmTask    
               WHILE @@TRANCOUNT > @nTranCount    
                  COMMIT TRAN    
               SET @nErrNo = 84410  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD TASK FAIL'  
               GOTO Step_5_Fail  
            END  
         END  

        WHILE @@TRANCOUNT > @nTranCount    
         COMMIT TRAN    
                     
         SET @cOutField01 = @cRefKey01  
         SET @cOutField02 = @cRefKey02  
         SET @cOutField03 = @cRefKey03  
         SET @cOutField04 = @cRefKey04  
         SET @cOutField05 = @cRefKey05  
         SET @cOutField06 = @cTaskdetailkey  
         SET @cOutField07 = @cAreaKey  
         SET @cOutField08 = @cTTMStrategykey  
         --SET @cOutField09 = @cTTMTasktype 
         SET @cOutField09 = @c_PickMethod    -- PICKMETHOD
            
         SET @nToFunc = 0  
         SET @nToScn = 0  
         SET @nPrevStep = 0  

         SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)  
         FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)  
         WHERE TaskType = RTRIM(@cTTMTasktype)  

         IF @nFunc = 0  
         BEGIN  
            SET @nErrNo = 70238  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr  
            GOTO Step_5_Fail  
         END  

         SELECT TOP 1 @nToScn = Scn  
         FROM RDT.RDTScn WITH (NOLOCK)  
         WHERE Func = @nToFunc  
         ORDER BY Scn  

         IF @nToScn = 0  
         BEGIN  
            SET @nErrNo = 70239  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr  
            GOTO Step_5_Fail  
         END  

         SET @nScn = @nToScn  
         SET @nFunc = @nToFunc  
         SET @nStep = 1  

         GOTO QUIT  
      END  
   END
   
   IF @nInputKey = 0    --ESC  
   BEGIN  
      -- (ChewKP01) 
      -- IF No More Task Close DeviceProfileLog and DeviceProfile 
      -- GETNEXTTASK:  
      -- Search for next task and redirect screen  
      EXEC dbo.nspTMTM01  
          @c_sendDelimiter = null  
       ,  @c_ptcid         = 'RDT'  
       ,  @c_userid        = @cUserName  
       ,  @c_taskId        = 'RDT'  
       ,  @c_databasename  = NULL  
       ,  @c_appflag       = NULL  
       ,  @c_recordType    = NULL  
       ,  @c_server        = NULL  
       ,  @c_ttm           = NULL  
       ,  @c_areakey01     = @cAreaKey  
       ,  @c_areakey02     = ''  
       ,  @c_areakey03     = ''  
       ,  @c_areakey04     = ''  
       ,  @c_areakey05    = ''  
       ,  @c_lastloc       = @cSuggToLoc  
       ,  @c_lasttasktype  = 'TPK'  
       ,  @c_outstring     = @c_outstring    OUTPUT  
       ,  @b_Success       = @b_Success      OUTPUT  
       ,  @n_err           = @nErrNo         OUTPUT  
       ,  @c_errmsg        = @cErrMsg        OUTPUT  
       ,  @c_taskdetailkey = @cNextTaskdetailkeyS OUTPUT  
       ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT  
       ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func  
       ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func  
       ,  @c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func  
       ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func  
       ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func  
       
      IF ISNULL(RTRIM(@cNextTaskdetailkeyS), '') = '' --@nErrNo = 67804 -- Nothing to do!  
      BEGIN  
         -- (ChewKP02)
         -- Close Whole Cart When No more Task in this area
         DECLARE curCloseCart CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         
         SELECT DL.DropID
         FROM dbo.DeviceProfileLog DL WITH (NOLOCK) 
         INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey
         INNER JOIN dbo.DropID DR WITH (NOLOCK) ON DR.DropID = DL.DropID
         WHERE D.DeviceID = @cDeviceID
         AND D.Status = '1'
         AND DR.DropIDType = 'CART'
         AND DR.Status = '1' 
         
         
         OPEN curCloseCart
         FETCH NEXT FROM curCloseCart INTO @cAssignDropID
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            
            --DropID Not Picked 
            Update dbo.DropID
            SET Status = '9'
            WHERE DropID = @cAssignDropID
            AND Status = '1'
            
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 84425
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDPLogFailed'
               GOTO Step_5_Fail
            END
            
            FETCH NEXT FROM curCloseCart INTO @cAssignDropID
            
         END
         CLOSE curCloseCart
         DEALLOCATE curCloseCart
         
         -- UPDATE DeviceProfileLog.Status = 9
         UPDATE dbo.DeviceProfileLog
            SET Status = '9', ConsigneeKey = ''
         FROM dbo.DeviceProfileLog DL WITH (NOLOCK) 
         INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey
         WHERE D.DeviceID = @cDeviceID
         --AND D.Status = '3' -- (ChewKP02) 
         
         IF @@ERROR <> 0 
         BEGIN
            SET @nErrNo = 84422
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDPLogFailed'
            GOTO Step_5_Fail
         END
         
         -- UPDATE DeviceProfile.Status = 9
         UPDATE dbo.DeviceProfile
         SET Status = '9', DeviceProfileLogKey = ''
         WHERE DeviceID = @cDeviceID
         --  AND Status = '3' -- (ChewKP02)
            
         IF @@ERROR <> 0 
         BEGIN
            SET @nErrNo = 84423
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDPFailed'
            GOTO Step_5_Fail
         END
      END
      
      IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)  
                     WHERE Userkey = @cUserName  
                     AND Status = '3'  )  
      BEGIN  
         BEGIN TRAN  
         -- Release ALL Task from Users when EXIT TM --  
         Update dbo.TaskDetail WITH (ROWLOCK)  
            SET Status = '0' , Userkey = '', DropID = '' --, Message03 = '' -- (vicky03) -- should also update DropID for Close Tote  -- (ChewKP01)
             ,TrafficCop = NULL  
             ,EditDate = GETDATE()  
             ,EditWho = SUSER_SNAME()  
         WHERE Userkey = @cUserName  
         AND Status = '3'  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 70060  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'  
            ROLLBACK TRAN  
            GOTO Step_5_Fail  
         END  
         ELSE  
         BEGIN  
            COMMIT TRAN  
         END  
      END  

      -- EventLog - Sign In Function  (james01)
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep
             
     -- Go back to Task Manager Main Screen  
     SET @nFunc = 1756  
     SET @nScn = 2100  
     SET @nStep = 1  
  
     SET @cAreaKey = ''  
     SET @nPrevStep = '0'  
  
     SET @cOutField01 = ''  -- Area  
     SET @cOutField02 = ''  
     SET @cOutField03 = ''  
     SET @cOutField04 = ''  
     SET @cOutField05 = ''  
     SET @cOutField06 = ''  
     SET @cOutField07 = ''  
     SET @cOutField08 = ''  
     SET @cOutField09 = ''  
   END  
      
   GOTO Quit
   
   Step_5_Fail:
END

/********************************************************************************  
Step 6. screen = 3745  
     REASON CODE  (Field01, input)  
********************************************************************************/  
Step_6:  
BEGIN  
  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cReasonCode = @cInField01  
  
      IF @cReasonCode = ''  
      BEGIN  
        SET @nErrNo = 84415  
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Reason Req  
        GOTO Step_6_Fail  
      END  
  
      IF NOT EXISTS ( SELECT 1 FROM dbo.TaskManagerReason WITH (NOLOCK) 
                      WHERE TaskManagerReasonKey = @cReasonCode)
      BEGIN  
        SET @nErrNo = 84416  
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV REASON CODE  
        GOTO Step_6_Fail  
      END  
      
      -- Update ReasonCode  
      EXEC dbo.nspRFRSN01  
              @c_sendDelimiter = NULL  
           ,  @c_ptcid         = 'RDT'  
           ,  @c_userid        = @cUserName  
           ,  @c_taskId        = 'RDT'  
           ,  @c_databasename  = NULL  
           ,  @c_appflag       = NULL  
           ,  @c_recordType    = NULL  
           ,  @c_server        = NULL  
           ,  @c_ttm           = NULL  
           ,  @c_taskdetailkey = @cTaskdetailkey  
           ,  @c_fromloc       = @cFromLoc  
           ,  @c_fromid        = ''  
           ,  @c_toloc         = @cSuggToloc  
           ,  @c_toid          = ''  
           ,  @n_qty           = @nScanQty--0  
           ,  @c_packkey       = ''  
           ,  @c_uom           = ''  
           ,  @c_reasoncode    = @cReasonCode  
           ,  @c_outstring     = @c_outstring    OUTPUT  
           ,  @b_Success       = @b_Success      OUTPUT  
           ,  @n_err           = @nErrNo         OUTPUT  
           ,  @c_errmsg        = @cErrMsg        OUTPUT  
           ,  @c_userposition  = @cUserPosition  
  
      IF ISNULL(@cErrMsg, '') <> ''  
      BEGIN  
         SET @cErrMsg = @cErrMsg  
         GOTO Step_6_Fail  
      END  

      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET 
         [Status] = '9',  
         ReasonKey = @cReasonCode, 
         EndTime = GETDATE(), --CURRENT_TIMESTAMP , -- (Vicky02)  
         EditDate = GETDATE(), --CURRENT_TIMESTAMP , -- (Vicky02)  
         EditWho = @cUserName, -- (ChewKP05)  
         TrafficCop = NULL       -- tlting01  
      WHERE TaskDetailkey = @cTaskdetailkey  
  
      SET @nStep = @nStep - 1
      SET @nScn  = @nScn - 1  
   END  

   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Reset this screen var  
      SET @cFromLoc = ''  
  
      SET @cOutField01 = @cSuggFromLoc -- Suggested FromLOC  
      --SET @cOutField09 = @cTTMTasktype -- Task Type  
      SET @cOutField09 = @c_PickMethod    -- PICKMETHOD
      SET @cOutField12 = @cDeviceID    -- Cart ID
      SET @cOutField13 = ''            -- Display

      SET @nStep = @nStep - 5
      SET @nScn  = @nScn - 5
   END
   GOTO Quit

   Step_6_Fail:  
   BEGIN  
      SET @cReasonCode = ''  
  
      -- Reset this screen var  
      SET @cOutField01 = ''  
  
   END  
END  
GOTO Quit  

/********************************************************************************  
Quit. Update back to I/O table, ready to be pick up by JBOSS  
********************************************************************************/  
Quit:  
BEGIN  
   UPDATE RDTMOBREC WITH (ROWLOCK) SET  
       EditDate      = GETDATE(), 
       ErrMsg        = @cErrMsg,  
       Func          = @nFunc,  
       Step          = @nStep,  
       Scn           = @nScn,  
  
       StorerKey     = @cStorerKey,  
       Facility      = @cFacility,  
       Printer       = @cPrinter,  
       -- UserName      = @cUserName,  
  
       V_SKU         = @cSKU,  
       V_LOC         = @cFromloc,  
       V_ID          = @cID,  
       V_UOM         = @cPUOM,    
       V_Lot         = @cLot,  
       V_CaseID      = @cCaseID,  
       V_LoadKey     = @cLoadKey, -- (ChewKP01)
  
       V_String1     = @cWaveKey,  
       V_String2     = @c_PickMethod,  
       V_String3     = @cToloc,  
       V_String4     = @cReasonCode,  
       V_String5     = @cTaskdetailkey,  
  
       V_String6     = @cSuggFromloc,  
       V_String7     = @cSuggToloc,  
       V_String8     = @cSuggID,    
       V_String10    = @cUserPosition,    
       V_String12    = @cNextTaskdetailkeyS,  
       V_String13    = @cPackkey,    
       V_String16    = @cTaskStorer,  
       V_String17    = @cDescr1,  
       V_String18    = @cDescr2,    
       V_String20    = @cDeviceProfileLogKey,  -- (ChewKP01)
       V_String21    = @c_TaskDetailKeyPK,  
       V_String22    = @c_CurrPutawayzone,  
       V_String23    = @c_FinalPutawayzone,  
       V_String24    = @c_PPAZone,  
       V_String25    = @cUOM,  
       V_String26    = @cOrderkey,  
       --V_String18    = @cMUOM_Desc,  
       --V_String19    = @cPUOM_Desc,  
       --V_String20    = @nPUOM_Div,  
       --V_String21    = @nMQTY,  
       --V_String22    = @nPQTY,  
       --V_String23    = @nActMQTY,  
       --V_String24    = @nActPQTY,  
       --V_String25    = @nSUMBOM_Qty,  
       --V_STRING26 = @cAltSKU,  
       V_STRING27    = @cPUOM,  
       V_String28    = @cPrepackByBOM,    
       V_String30    = @cNewToteNo,      -- (shong03)  
       V_String31    =  @cShortPickFlag, -- (SHONG06)  
  
       V_QTY         = @nQTY,
       V_Integer1    = @nSuggQTY,
       V_Integer2    = @nScanQty,
       V_Integer3    = @nTotalToteQTY,   -- (vicky03)
       
       V_FromStep    = @nPrevStep,
       --V_FromStep    = @nFromStep,  
       V_FromScn     = @nFromScn,
  
       V_String32    =  @cAreakey,  
       V_String33    =  @cTTMStrategykey,  
       V_String34    =  @cTTMTasktype,  
       V_String35    =  @cRefKey01,  
       V_String36    =  @cRefKey02,  
       V_String37    =  @cRefKey03,  
       V_String38    =  @cRefKey04,  
       V_String39    =  @cRefKey05,  
       V_String40    =  @cDeviceID,  
  
      I_Field01 = @cInField01,  O_Field01 = @cOutField01,  
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,  
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,  
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,  
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,  
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,  
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,  
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,  
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,  
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,  
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,  
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,  
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,  
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,  
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,  
  
      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,  
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,  
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,  
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,  
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,  
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,  
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,  
      FieldAttr15  = @cFieldAttr15  
  
   WHERE Mobile = @nMobile  
END

GO