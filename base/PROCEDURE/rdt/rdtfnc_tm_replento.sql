SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*******************************************************************************/    
/* Store procedure: rdtfnc_TM_ReplenTo                                         */    
/* Copyright      : IDS                                                        */    
/*                                                                             */    
/* Purpose: RDT Task Manager - Move                                            */    
/*          Called By rdtfnc_TaskManager                                       */    
/*                                                                             */    
/* Modifications log:                                                          */    
/*                                                                             */    
/* Date        Rev   Author   Purposes                                         */    
/* 12-04-2011  1.0   ChewKP   Created                                          */    
/* 29-08-2014  1.1   Chee     Fix wrong screen display on next task (Chee01)   */    
/* 05-09-2014  1.2   Chee     Fix user getting task from other pallet (Chee02) */    
/* 10-09-2014  1.3   Chee     Add DisableQTYFieldSP (Chee03)                   */    
/* 11-06-2015  1.4   ChewKP   Remove TraceInfo -- (ChewKP01)                   */    
/* 23-03-2016  1.5   ChewKP   SOS#366906 Allow Swap Task -- (ChewKP02)         */    
/* 30-09-2016  1.6   Ung      Performance tuning                               */    
/* 06-04-2017  1.7   ChewKP   WMS-1580 Add StorerConfig OverrideLoc (ChewKP03) */    
/* 16-03-2018  1.8   Ung      WMS-3935 Add SwapUCC                             */    
/* 24-07-2018  1.9   Ung      WMS-5766 Add DefaultFromLOC                      */    
/* 30-08-2018  2.0   James    WMS-6146 Add rdt_decode (james01)                */    
/* 30-10-2018  2.1   ChewKP   WMS-6505 - Bug Fixes (ChewKP04)                  */       
/* 27-03-2019  2.2   James    Add DecodeIDSP, DecodeSKUSP and remove           */    
/*                            DecodeSP (james02)                               */    
/* 03-01-2019  2.3   ChewKP   WMS-8496 Add Storerconfig SuggestedLocSP         */    
/*                            (ChewKP05)                                       */    
/* 17-07-2019  2.4   James    WMS9860 Add loc prefix (james03)                 */     
/* 11-11-2019  2.5   Chermaine WMS-11077 Add EventLog (cc01)                   */   
/* 18-08-2020  2.6   James    WMS-14152 Add ExtendedvalidateSP @ step4(james01)*/  
/* 25-09-2020  2.7   LZG      INC1297036 - Fixed incorrect FromLoc from prev   */
/*                            task (ZG01)                                      */
/* 16-11-2020  2.8   James    WMS-15573 Add extra param to nspTMTM01 (james02) */
/*                            Exit module if switch task                       */
/*******************************************************************************/    
CREATE  PROC [RDT].[rdtfnc_TM_ReplenTo](    
   @nMobile    INT,    
   @nErrNo     INT  OUTPUT,    
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max    
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
   @cSuggSKU            NVARCHAR(20),    
   @cTaskdetailkey      NVARCHAR(10),    
   @cID                 NVARCHAR(18),    
   @cSuggID             NVARCHAR(18),    
   @cUOM                NVARCHAR(5),   -- Display NVARCHAR(5)    
   @cReasonCode         NVARCHAR(10),    
   @cSKU                NVARCHAR(20),    
    
   @cFromFacility NVARCHAR(5),    
   @c_outstring         NVARCHAR(255),    
   @cUserPosition       NVARCHAR(10),    
   @cPrevTaskdetailkey  NVARCHAR(10),    
   @cQTY                NVARCHAR(5),    
   @cPackkey            NVARCHAR(10),    
    
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
   @nToScn              INT,    
    
   @nOn_HandQty         INT,    
   @nTTL_Alloc_Qty      INT,    
   @nTaskDetail_Qty     INT,    
   @cLoc                NVARCHAR( 10),    
    
    
   @cAltSKU             NVARCHAR( 20),    
   @cPUOM               NVARCHAR( 1), -- Prefer UOM    
   @cPUOM_Desc          NVARCHAR( 5),    
   @cMUOM_Desc          NVARCHAR( 5),    
   @cSuggestPQTY        NVARCHAR( 5),    
   @cSuggestMQTY        NVARCHAR( 5),    
   @cPQTY               NVARCHAR( 5),    
   @cMQTY               NVARCHAR( 5),    
   @cPrepackByBOM       NVARCHAR(1),    
    
   @nSum_PalletQty      INT,    
   @nSUMBOM_Qty         INT,    
   @nPUOM_Div           INT, -- UOM divider    
   @nPQTY               INT, -- Preferred UOM QTY    
   @nMQTY               INT, -- Master unit QTY    
   @nActQTY             INT, -- Actual QTY    
   @nActMQTY            INT, -- Actual keyed in master QTY    
   @nActPQTY            INT, -- Actual keyed in prefered QTY    
   @nSuggestPQTY        INT, -- Suggested master QTY    
   @nSuggestMQTY        INT, -- Suggested prefered QTY    
   @nSuggestQTY         INT, -- Suggetsed QTY    
    
   @cSQL                NVARCHAR(1000),    
   @cSQLParam           NVARCHAR(1000),    
   @cExtendedValidateSP NVARCHAR(30),    
   @cExtendedUpdateSP   NVARCHAR(30),    
    
   -- (Chee03)    
   @cDisableQTYField    NVARCHAR(1),    
   @cDisableQTYFieldSP  NVARCHAR(20),    
    
   @cAisle              NVARCHAR(10),    
   @cNextTaskDetailKeyR NVARCHAR(10),    
   @cNextFromLOC        NVARCHAR(10),    
   @cNextToID           NVARCHAR(10),    
   @cNextLoadKey        NVARCHAR(10),    
   @cNextStorerkey      NVARCHAR(15),    
   @cRPDLot             NVARCHAR(10),    
   @cRPDID              NVARCHAR(18),    
   @cRPDSKU             NVARCHAR(20),    
   @nRPDQTY             INT,    
   @nTranCount          INT,    
    
   @nTrace              INT,    
   @cRefNo1             NVARCHAR(20),    
   @cTraceReason        NVARCHAR(20),    
   @cTMPASKU            NVARCHAR(1),    
   @cInSKU              NVARCHAR(20),    
   @cContinueProcess    NVARCHAR(10),    
   @cReasonStatus       NVARCHAR(10),    
   @nSKULength          NVARCHAR(10),    
   @nRowRef             INT,    
   @cRSKU               NVARCHAR(20),    
   @cRFromLoc           NVARCHAR(10),    
   @cRFromID            NVARCHAR(18),    
   @nRQtyMove           INT,    
   @cLot                NVARCHAR(10),    
   @cSourceKey          NVARCHAR(10),    
   @cNextTaskdetailkeyS NVARCHAR(10),    
   @cLoadKey            NVARCHAR(10),    
   @nSKUCnt             INT,    
   @cNextTaskType       NVARCHAR(10),    
   @cDecodeLabelNo      NVARCHAR(20),    
   @cSKUDesc            NVARCHAR(60),    
   @nPQTY_RPL           INT,    
   @nUCCQTY             INT,    
    
   @cLottable01         NVARCHAR(18),    
   @cLottable02         NVARCHAR(18),    
   @cLottable03         NVARCHAR(18),    
   @dLottable04         DATETIME,    
   @nQTY_RPL            INT,    
   @nMQTY_RPL           INT,    
   @cDropID             NVARCHAR(20),    
   @cUCC                NVARCHAR(20),    
   @cNextTaskDetailKey  NVARCHAR(10),    
    
   @nToStep             INT,    
   @cCaseID             NVARCHAR(20),    
   @nSKUValidated       INT,    
   @cLabelNo            NVARCHAR( 32),    
   @cGetNextTaskSP      NVARCHAR(20),    
   @cExtendedInfoSP     NVARCHAR(20),    
   @cExtendedInfo1      NVARCHAR(20),    
   @cExtendedLabel      NVARCHAR(20),    
   @cExtendedInfo2      NVARCHAR(20),    
   @cSwapTask           NVARCHAR(1),    
   @cSwapTaskDetailKey  NVARCHAR(10),    
   @cOverrideLOC        NVARCHAR(1),    
   @cBarcode            NVARCHAR( 60),                           
   @cDefaultFromLOC     NVARCHAR(1),    
   @cDecodeIDSP         NVARCHAR( 20),    
   @cDecodeSKUSP        NVARCHAR( 20),    
   @cSuggestedLocSP     NVARCHAR( 20),    
   @cCustomSuggToLoc    NVARCHAR( 10),    
   @cLOCLookupSP        NVARCHAR( 20),  
   @cContinueTask       NVARCHAR( 1),
    
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),    
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),    
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),    
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),    
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),    
    
    
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
   @nQTY             = V_QTY,  
   @cTaskdetailkey   = V_TaskDetailKey,    
   @cLot             = V_Lot,    
   @cLabelNo         = V_UCC,    
    
   @cLottable01      = V_Lottable01,    
   @cLottable02      = V_Lottable02,    
   @cLottable03      = V_Lottable03,    
   @dLottable04      = V_Lottable04,    
    
   @cToLoc           = V_String1,    
   @cReasonCode      = V_String2,    
   @cDecodeLabelNo   = V_String3,    
    
   @cSuggFromloc     = V_String4,    
   @cSuggToloc       = V_String5,    
   @cSuggID          = V_String6,    
   @cLOCLookupSP     = V_String7,  
   @cUserPosition    = V_String8,    
   @cExtendedValidateSP = V_String9,    
   @cExtendedUpdateSP   = V_String10,    
   @cCaseID             = V_String11,    
   @cSuggSKU            = V_String12,    
   @cContinueTask       = V_String13,
    
   @nSuggQTY            = V_Integer1,  
   @nPQTY_RPL           = V_Integer2,  
   @nMQTY_RPL           = V_Integer3,  
   @nQTY_RPL            = V_Integer4,  
   @nPQTY               = V_Integer5,  
   @nMQTY               = V_Integer6,  
   @nSuggQTY            = V_Integer7,  
   @nPQTY_RPL           = V_Integer8,  
   @nFromstep           = V_FromStep,  
  
   @cGetNextTaskSP    = V_String20,    
   @cExtendedInfoSP   = V_String21,    
    
   -- (Chee03)    
   @cDisableQTYField   = V_String22,    
   @cDisableQTYFieldSP = V_String23,    
   @cSwapTask          = V_String24,    
   @cOverrideLOC       = V_String25,    
   @cDefaultFromLOC    = V_String26,    
   @cDecodeIDSP        = V_String27,    
   @cDecodeSKUSP       = V_String28,    
   @cSuggestedLocSP    = V_String29,    
    
   @cAreakey         = V_String32,    
   @cTTMStrategykey  = V_String33,    
   @cTTMTasktype     = V_String34,    
   @cRefKey01        = V_String35,    
   @cRefKey02        = V_String36,    
   @cRefKey03        = V_String37,    
   @cRefKey04        = V_String38,    
   @cRefKey05        = V_String39,    
    
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
    
   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,    
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,    
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,    
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,    
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,    
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,    
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,    
   @cFieldAttr15 =  FieldAttr15    
    
FROM   RDTMOBREC (NOLOCK)    
WHERE  Mobile = @nMobile    
    
-- Redirect to respective screen    
IF @nFunc = 1765    
BEGIN    
   DECLARE @nStepSKU INT    
   ,@nScnSKU          INT    
   ,@nStepToLoc       INT    
   ,@nScnToLoc        INT    
   ,@nStepID          INT    
   ,@nScnID           INT    
   ,@nStepFromLoc     INT    
   ,@nScnFromLoc      INT    
   ,@nStepReason      INT    
   ,@nScnReason       INT    
   ,@nStepSuccessMsg  INT    
   ,@nScnSuccessMsg   INT    
    
    
   SET @nStepSKU        = 4    
   SET @nScnSKU         = 2783    
   SET @nStepToLoc      = 3    
   SET @nScnToLoc       = 2782    
   SET @nStepID         = 2    
   SET @nScnID          = 2781    
   SET @nStepFromLoc    = 1    
   SET @nScnFromLoc     = 2780    
   SET @nStepReason     = 6    
   SET @nScnReason      = 2109    
   SET @nStepSuccessMsg = 5    
   SET @nScnSuccessMsg  = 2784    
    
    
    
   IF @nStep = 0 GOTO Step_0   -- Initialize    
   IF @nStep = 1 GOTO Step_1   -- Menu. Func = 1765, Scn = 2780 -- FromLOC    
   IF @nStep = 2 GOTO Step_2   -- Scn = 2781   ID    
   IF @nStep = 3 GOTO Step_3   -- Scn = 2782   ToLoc    
   IF @nStep = 4 GOTO Step_4   -- Scn = 2783   SKU , Qty    
   --IF @nStep = 5 GOTO Step_5   -- Scn = 2787   Qty    
   IF @nStep = 5 GOTO Step_5   -- Scn = 2784   Sucess Msg    
   IF @nStep = 6 GOTO Step_6   -- Scn = 2109   Reason Code    
    
    
    
END    
    
RETURN -- Do nothing if incorrect step    
    
/********************************************************************************    
Step 0. Called from Task Manager Main Screen (func = 1765)    
    Screen = 2786    
    GET EMPTY PALLET SCREEN    
********************************************************************************/    
Step_0:    
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
    
   
    
--      SET @cTaskDetailKey  = @cOutField06    
--      SET @cAreaKey        = @cOutField07    
--      SET @cTTMStrategyKey = @cOutField08    
    
      SELECT @cStorerKey   = RTRIM(Storerkey),    
             @cSuggSKU     = RTRIM(SKU),    
             @cSuggID      = RTRIM(FromID),    
             @cSuggToLoc   = RTRIM(ToLOC),    
             @cLot         = RTRIM(Lot),    
             @cSourceKey   = RTRIM(SourceKey),    
             @cSuggFromLoc = RTRIM(FromLoc),    
             @nQTY_RPL     = Qty,    
             @cCaseID      = CaseID    
      FROM dbo.TaskDetail WITH (NOLOCK)    
      WHERE TaskDetailKey = @cTaskdetailkey    
    
      SET @cDefaultFromLOC = rdt.RDTGetConfig( @nFunc, 'DefaultFromLOC', @cStorerKey)    
      SET @cOverrideLOC = rdt.RDTGetConfig( @nFunc, 'OverrideLOC', @cStorerKey)    
    
      SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)    
      IF @cDecodeLabelNo = '0'    
         SET @cDecodeLabelNo = ''    
      SET @cDisableQTYFieldSP = rdt.RDTGetConfig( @nFunc, 'DisableQTYFieldSP', @cStorerKey)    
      IF @cDisableQTYFieldSP = '0'    
         SET @cDisableQTYFieldSP = ''    
      SET @cGetNextTaskSP = rdt.RDTGetConfig( @nFunc, 'GetNextTaskSP', @cStorerKey)    
      IF @cGetNextTaskSP = '0'    
         SET @cGetNextTaskSP = ''    
      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)    
      IF @cExtendedValidateSP = '0'    
         SET @cExtendedValidateSP = ''    
      SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)    
      IF @cExtendedInfoSP = '0'    
         SET @cExtendedInfoSP = ''    
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)    
      IF @cExtendedUpdateSP = '0'    
         SET @cExtendedUpdateSP = ''    
      SET @cSwapTask = rdt.RDTGetConfig( @nFunc, 'SwapTask', @cStorerKey)    
      IF @cSwapTask = '0'    
         SET @cSwapTask = ''    
    
      -- (james02)    
      SET @cDecodeIDSP = rdt.RDTGetConfig( @nFunc, 'DecodeIDSP', @cStorerKey)    
      IF @cDecodeIDSP = '0'    
         SET @cDecodeIDSP = ''    
    
      -- (james02)    
      SET @cDecodeSKUSP = rdt.RDTGetConfig( @nFunc, 'DecodeSKUSP', @cStorerKey)    
      IF @cDecodeSKUSP = '0'    
         SET @cDecodeSKUSP = ''    
          
      -- (james03)  
      SET @cLOCLookupSP = rdt.rdtGetConfig( @nFunc, 'LOCLookupSP', @cStorerKey)  
    
      -- Disable QTY field    
      IF @cDisableQTYFieldSP <> ''    
      BEGIN    
         IF @cDisableQTYFieldSP = '1'    
            SET @cDisableQTYField = @cDisableQTYFieldSP    
         ELSE    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')    
            BEGIN    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
               SET @cSQLParam =    
                  '@nMobile            INT,           ' +    
                  '@nFunc              INT,           ' +    
                  '@cLangCode          NVARCHAR( 3),  ' +    
                  '@nStep              INT,           ' +    
                  '@cTaskdetailKey     NVARCHAR( 10), ' +    
                  '@cDisableQTYField   NVARCHAR( 1)   OUTPUT, ' +    
                  '@nErrNo             INT            OUTPUT, ' +    
                  '@cErrMsg            NVARCHAR( 20)  OUTPUT'    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
               IF @nErrNo <> 0    
                  GOTO Quit    
            END    
         END    
      END    
          
      -- (ChewKP05)    
      SET @cSuggestedLocSP = rdt.RDTGetConfig( @nFunc, 'SuggestedLocSP', @cStorerKey)    
      IF @cSuggestedLocSP = '0'    
         SET @cSuggestedLocSP = ''    
          
      SET @cContinueTask = rdt.RDTGetConfig( @nFunc, 'ContinueALLTaskWithinAisle', @cStorerKey)
          
      -- Get prefer UOM    
      SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA    
      FROM RDT.rdtMobRec M (NOLOCK)    
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)    
      WHERE M.Mobile = @nMobile    
    
      SELECT @cUOM = '', @cPackkey = ''    
      SELECT @cUOM = PACK.PACKUOM3,    
             @cPackkey = RTRIM(PACK.Packkey)    
      FROM dbo.PACK PACK WITH (NOLOCK)    
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)    
      WHERE SKU.Storerkey = @cStorerKey    
      AND   SKU.SKU = @cSuggSKU    
    
      -- prepare next screen    
      SET @cOutField01 = @cSuggFromLoc    
      SET @cOutField02 = CASE WHEN @cDefaultFromLOC = '1' THEN @cSuggFromLoc ELSE '' END    
      SET @cOutField03 = ''    
      SET @cOutField04 = ''    
      SET @cOutField05 = ''    
    
      -- Go to next screen    
      SET @nScn = 2780    
      SET @nStep = 1    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 1. Called from Task Manager Main Screen (func = 1765)    
    Screen = 2780    
    FROM LOC (Field02, input)    
********************************************************************************/    
Step_1:    
BEGIN    
    
    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
    
      SET @cFromLoc = @cInField02    
    
      IF @cFromloc = ''    
      BEGIN    
         SET @nErrNo = 78551    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FromLoc Req    
         GOTO Step_1_Fail    
      END    
  
  -- (james03)          
  IF @cLOCLookupSP = 1                
  BEGIN                
   EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,                 
      @cFromloc   OUTPUT,                 
      @nErrNo     OUTPUT,                 
      @cErrMsg    OUTPUT                
  
   IF @nErrNo <> 0                
    GOTO Step_1_Fail                
  END   
  
      IF @cFromLoc <> @cSuggFromLoc    
      BEGIN    
         SET @nErrNo = 78552    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC    
         GOTO Step_1_Fail    
      END    
    
    
      EXEC RDT.rdt_STD_EventLog    
         @cActionType     = '1', -- Sign in function    
         @cUserID         = @cUserName,    
         @nMobileNo       = @nMobile,    
         @nFunctionID     = @nFunc,    
         @cFacility       = @cFacility,    
         @cStorerKey      = @cStorerKey,    
         @cLocation       = @cSuggFromLoc,    
         @cToLocation    =  @cSuggToLoc,    
         @cPutawayZone    = '',    
         @cPickZone       = '',    
         @cID             = @cSuggID,    
         @cToID           = @cID,    
         @cSKU            = @cSKU,    
         @cComponentSKU   = '',    
         @cUOM            = @cUOM,    
         @nQTY            = @nActQTY,    
         @cLot            = '',    
         @cToLot          = '',    
         @cRefNo1         = @cTaskdetailkey,    
         @cRefNo2         = @cAreaKey,    
         @cRefNo3         = @cTTMStrategykey,    
         @cRefNo4         = '',    
         @cRefNo5         = '',    
         @cTaskDetailKey  = @cTaskDetailKey    
    
      -- prepare next screen    
      SET @cOutField01 = @cFromLoc    
      SET @cOutField02 = @cSuggID    
      SET @cOutField03 = ''    
      SET @cOutField04 = ''    
      SET @cOutField05 = ''    
    
      -- Go to next screen    
      SET @nScn = @nScn + 1    
      SET @nStep = @nStep + 1    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
    
      SET @cOutField01 = ''    
      SET @nFromStep = 1    
    
      -- Go to Reason Code Screen    
      SET @nScn  = 2109    
      SET @nStep = @nStep + 5 -- Step 7    
    
   END    
   GOTO Quit    
    
   Step_1_Fail:    
   BEGIN    
      -- Reset this screen var    
      SET @cFromLoc = ''    
    
      SET @cOutField01 = @cSuggFromLoc -- Suggested FromLOC    
      SET @cOutField02 = ''    
    
    
  END    
END    
GOTO Quit    
    
    
    
    
/********************************************************************************    
Step 2. screen = 2781    
   FROM LOC (Field01)    
   ID       (Field02)    
   ID       (Field03, input)    
********************************************************************************/    
Step_2:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
    
      -- Screen mapping    
      SET @cID = @cInField03    
      SET @cBarcode = @cInField03    
    
      -- Decode    
      IF @cDecodeIDSP <> ''    
      BEGIN    
         -- Standard decode    
         IF @cDecodeIDSP = '1'    
         BEGIN    
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,     
               @cID     = @cID     OUTPUT,     
               @nErrNo  = @nErrNo  OUTPUT,     
               @cErrMsg = @cErrMsg OUTPUT,    
               @cType   = 'ID'    
         END    
    
         -- Customize decode    
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeIDSP AND type = 'P')    
         BEGIN    
  SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeIDSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cBarcode, ' +     
               ' @cID OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '     
            SET @cSQLParam =    
               ' @nMobile        INT,           ' +    
               ' @nFunc          INT,           ' +    
               ' @cLangCode      NVARCHAR( 3),  ' +    
               ' @nStep          INT,           ' +    
               ' @nInputKey      INT,           ' +    
               ' @cTaskdetailKey NVARCHAR( 10), ' +    
               ' @cBarcode       NVARCHAR( 60), ' +        
               ' @cID            NVARCHAR( 18)  OUTPUT, ' +    
               ' @nErrNo         INT            OUTPUT, ' +    
               ' @cErrMsg        NVARCHAR( 20)  OUTPUT'    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cBarcode,     
               @cID OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
         END    
    
         IF @nErrNo <> 0    
            GOTO Step_2_Fail    
      END    
    
      IF @cSuggID <> '' AND @cID = ''    
      BEGIN    
         SET @nErrNo = 78553    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID Req    
         GOTO Step_2_Fail    
      END    
    
    
      -- Enter ID <> Suggested ID, go taskdetail to retrieve the ID to work on    
      IF @cSuggID <> @cID    
      BEGIN    
             IF @cSwapTask = '1'    
             BEGIN    
                     SELECT TOP 1 @cStorerKey   = RTRIM(Storerkey),    
                            @cSuggSKU     = RTRIM(SKU),    
                            --@cSuggID      = RTRIM(FromID),    
                            @cSuggToLoc   = RTRIM(ToLOC),    
                            @cLot         = RTRIM(Lot),    
                            @cSourceKey   = RTRIM(SourceKey),    
                            @cSuggFromLoc = RTRIM(FromLoc),    
                            @nQTY_RPL     = Qty,    
                            @cCaseID      = CaseID,    
                            @cSwapTaskDetailKey = TaskDetailKey    
                     FROM dbo.TaskDetail WITH (NOLOCK)    
                     WHERE TaskType = 'RPT'    
                     AND FromID = @cID    
                     AND FromLoc = @cFromLoc    
                     AND Status = '0'    
    
    
                     IF ISNULL(@cSwapTaskDetailKey,'')  = ''    
                     BEGIN    
    
                          SET @nErrNo = 78586    
                          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidSwapID    
                          GOTO Step_2_Fail    
    
                     END    
    
                     -- LOCK NEW ID Records    
                     UPDATE TaskDetail    
                     SET    STATUS = '3'    
                           ,[UserKey] = @cUserName    
                           ,[ReasonKey] = ''    
                           ,[EditDate] = GetDate()    
                           ,[EditWho]  = sUSER_sNAME()    
                           ,[TrafficCop] = NULL    
                     WHERE  Storerkey = @cStorerKey    
                       AND TaskType = 'RPT'    
                       AND FromLoc  = @cFromLoc    
                       AND UserKey  = ''    
                       AND [Status] = '0'    
                       AND FromID   = @cID    
    
                     IF @@ERROR <> 0    
                     BEGIN    
                          SET @nErrNo = 78587    
                          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskDetFail    
                          GOTO Step_2_Fail    
                     END    
    
                     -- RLEASE Current ID Records    
                     UPDATE TaskDetail    
                     SET    STATUS = '0'    
                           ,[UserKey] = ''    
                           ,[ReasonKey] = ''    
                           ,[EditDate] = GetDate()    
                           ,[EditWho]  = sUSER_sNAME()    
                           ,[TrafficCop] = NULL    
                     WHERE  Storerkey = @cStorerKey    
                       AND TaskType = 'RPT'    
                       AND FromLoc  = @cFromLoc    
                       AND UserKey  = @cUserName    
                       AND [Status] = '3'    
                       AND FromID   = @cSuggID    
    
                     IF @@ERROR <> 0    
                     BEGIN    
                          SET @nErrNo = 78588    
                          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskDetFail    
                          GOTO Step_2_Fail    
                     END    
    
                     SET @cTaskDetailKey = @cSwapTaskDetailKey    
                     SET @cSuggID = @cID    
    
    
                     SELECT @cUOM = '', @cPackkey = ''    
                     SELECT @cUOM = PACK.PACKUOM3,    
                            @cPackkey = RTRIM(PACK.Packkey)    
                     FROM dbo.PACK PACK WITH (NOLOCK)    
                     JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)    
                     WHERE SKU.Storerkey = @cStorerKey    
                     AND   SKU.SKU = @cSuggSKU    
    
    
             END    
             ELSE    
             BEGIN    
                SET @nErrNo = 78554    
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID    
                GOTO Step_2_Fail    
             END    
      END    
    
      --      -- Extended info    
    
    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo1 = ''    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cExtendedLabel OUTPUT, @cExtendedInfo1 OUTPUT, @cExtendedInfo2 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@cExtendedLabel  NVARCHAR( 20) OUTPUT, ' +    
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +    
               '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +    
               '@nErrNo INT           OUTPUT, ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +    
               '@nAfterStep      INT '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cExtendedLabel OUTPUT, @cExtendedInfo1 OUTPUT, @cExtendedInfo2 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep    
    
            IF @nStep = 2    
            BEGIN    
    
    
               SET @cOutField05 = @cExtendedLabel    
               SET @cOutField06 = @cExtendedInfo1    
               SET @cOutField07 = @cExtendedInfo2    
            END    
         END    
      END    
      ELSE    
      BEGIN    
         SET @cOutField05 = ''    
         SET @cOutField06 = ''    
      END    
    
      IF @cSuggestedLocSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSuggestedLocSP AND type = 'P')    
         BEGIN    
    
             SET @cSQL = 'EXEC rdt.' + RTRIM( @cSuggestedLocSP) +    
                ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cLabelNo, @nStep, @cTaskDetailKey, @nQty, @cCustomSuggToLoc OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
             SET @cSQLParam =    
                '@nMobile        INT, ' +    
                '@nFunc          INT, ' +    
                '@cLangCode      NVARCHAR( 3),  ' +    
                '@cUserName      NVARCHAR( 18), ' +    
                '@cFacility      NVARCHAR( 5),  ' +    
                '@cStorerKey     NVARCHAR( 15), ' +    
                '@cLabelNo        NVARCHAR( 20), ' +    
                '@nStep          INT,           ' +    
                '@cTaskDetailKey NVARCHAR( 10), ' +    
                '@nQty           INT,           ' +    
                '@cCustomSuggToLoc  NVARCHAR( 20) OUTPUT, ' +    
                '@nErrNo         INT           OUTPUT, ' +    
                '@cErrMsg        NVARCHAR( 20) OUTPUT'    
    
    
             EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cLabelNo, @nStep, @cTaskDetailKey , @nQty, @cCustomSuggToLoc OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
             IF @nErrNo <> 0    
                GOTO Step_2_Fail    
                    
             SET @cSuggToLoc = @cCustomSuggToLoc       
    
         END    
              
      END    
          
    
      SET @cOutField01 = @cFromLoc    
      SET @cOutField02 = @cID    
      SET @cOutField03 = @cSuggToLoc    
      SET @cOutField04 = ''    
      --SET @cOutField05 = ''    
    
      -- Go to ToLoc screen    
      SET @nScn = @nScnToLoc    
      SET @nStep = @nStepToLoc    
    
    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      SET @cOutField01 = @cSuggFromLoc    
      SET @cOutField02 = ''    
      SET @cOutField03 = ''    
      SET @cOutField04 = ''    
      SET @cOutField05 = ''    
    
      -- go to previous screen    
      SET @nScn = @nScn - 1    
      SET @nStep = @nStep - 1    
   END    
   GOTO Quit    
    
   Step_2_Fail:    
   BEGIN    
      SET @cID = ''    
    
      -- Reset this screen var    
      SET @cOutField01 = @cFromLoc    
      SET @cOutField02 = @cSuggID    
      SET @cOutField03 = ''  -- ID    
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 3. screen = 2782    
   FROM LOC        (Field01)    
   ID              (Field02)    
   SUGGESTED TOLOC (Field03)    
   TO LOC          (Field04, input)    
********************************************************************************/    
Step_3:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
    
      -- Screen mapping    
      SET @cToLoc = @cInField04    
    
      IF @cToLoc = ''    
      BEGIN    
         SET @nErrNo = 78560    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLOC Req    
         GOTO Step_3_Fail    
      END    
  
  -- (james03)          
  IF @cLOCLookupSP = 1       
  BEGIN                
   EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,                 
      @cToLoc     OUTPUT,                 
      @nErrNo     OUTPUT,                 
      @cErrMsg    OUTPUT                
  
   IF @nErrNo <> 0                
    GOTO Step_3_Fail                
  END   
  
      IF @cExtendedValidateSP <> ''    
      BEGIN    
    
          IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
          BEGIN    
             -- (ChewKP01)    
             --INSERT INTO TraceInfo (TraceName , TimeIn , col1 , col2, Col3, Col4, col5, step1 )    
             --VALUES ( 'RPT', GetDATE(), @cTaskDetailKey, @cLabelNo, '', '' , '', '0' )    
    
             SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
                ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cLabelNo, @nStep, @cTaskDetailKey, @nQty, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
             SET @cSQLParam =    
                '@nMobile        INT, ' +    
                '@nFunc          INT, ' +    
                '@cLangCode      NVARCHAR( 3),  ' +    
                '@cUserName      NVARCHAR( 18), ' +    
                '@cFacility      NVARCHAR( 5),  ' +    
                '@cStorerKey     NVARCHAR( 15), ' +    
                '@cLabelNo        NVARCHAR( 20), ' +    
                '@nStep          INT,           ' +    
                '@cTaskDetailKey NVARCHAR( 10), ' +    
                '@nQty           INT,           ' +    
                '@nErrNo         INT           OUTPUT, ' +    
                '@cErrMsg        NVARCHAR( 20) OUTPUT'    
    
    
             EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cLabelNo, @nStep, @cTaskDetailKey , @nQty, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
             IF @nErrNo <> 0    
                GOTO Step_3_Fail    
    
          END    
      END    
      ELSE    
      BEGIN    
             IF @cToLoc <> @cSuggToLoc    
             BEGIN    
             -- (ChewKP03)    
                IF ISNULL(@cOverrideLoc,'') <> '1'    
                BEGIN    
                 SET @nErrNo = 78561    
                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Loc    
                 GOTO Step_3_Fail    
                END    
 END    
      END    
    
      -- Get SKU info    
      SELECT    
         @cSKUDesc = S.Descr,    
         @cMUOM_Desc = Pack.PackUOM3,    
         @cPUOM_Desc =    
            CASE @cPUOM    
               WHEN '2' THEN Pack.PackUOM1 -- Case    
               WHEN '3' THEN Pack.PackUOM2 -- Inner pack    
               WHEN '6' THEN Pack.PackUOM3 -- Master unit    
               WHEN '1' THEN Pack.PackUOM4 -- Pallet    
               WHEN '4' THEN Pack.PackUOM8 -- Other unit 1    
               WHEN '5' THEN Pack.PackUOM9 -- Other unit 2    
            END,    
         @nPUOM_Div = CAST(    
            CASE @cPUOM    
               WHEN '2' THEN Pack.CaseCNT    
               WHEN '3' THEN Pack.InnerPack    
               WHEN '6' THEN Pack.QTY    
               WHEN '1' THEN Pack.Pallet    
               WHEN '4' THEN Pack.OtherUnit1    
               WHEN '5' THEN Pack.OtherUnit2    
            END AS INT)    
      FROM dbo.SKU S WITH (NOLOCK)    
         INNER JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)    
      WHERE StorerKey = @cStorerKey    
         AND SKU = @cSuggSKU    
    
      -- Get lottable    
      SELECT    
         @cLottable01 = LA.Lottable01,    
         @cLottable02 = LA.Lottable02,    
         @cLottable03 = LA.Lottable03,    
         @dLottable04 = LA.Lottable04    
      FROM dbo.LOTAttribute LA WITH (NOLOCK)    
      WHERE LOT = @cLOT    
    
      -- Disable QTY field    
      SET @cFieldAttr14 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- PQTY    
      SET @cFieldAttr15 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- MQTY    
    
      -- Convert to prefer UOM QTY    
      IF @cPUOM = '6' OR -- When preferred UOM = master unit    
         @nPUOM_Div = 0 -- UOM not setup    
      BEGIN    
         SET @cPUOM_Desc = ''    
         SET @nPQTY_RPL = 0    
         SET @nPQTY = 0    
         SET @nMQTY = @nQTY_RPL    
         SET @nMQTY_RPL = @nQTY_RPL    
         SET @cFieldAttr14 = 'O' -- @nPQTY_PWY    
      END    
      ELSE    
      BEGIN    
         SET @nPQTY = 0    
         SET @nMQTY = @nQTY_RPL    
    
         SET @nPQTY = @nQTY_RPL / @nPUOM_Div -- Calc QTY in preferred UOM    
         SET @nMQTY = @nQTY_RPL % @nPUOM_Div -- Calc the remaining in master unit    
    
         SET @nPQTY_RPL = @nQTY_RPL / @nPUOM_Div -- Calc QTY in preferred UOM    
         SET @nMQTY_RPL = @nQTY_RPL % @nPUOM_Div -- Calc the remaining in master unit    
      END    
    
      -- Prepare next screen variable    
      SET @cOutField01 = @cToLoc    
      SET @cOutField02 = @cSuggSKU    
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 1, 20)    
      SET @cOutField04 = SUBSTRING( @cSKUDesc, 21, 20)    
      SET @cOutField05 = @cLottable01    
      SET @cOutField06 = @cLottable02    
      SET @cOutField07 = @cLottable03    
      SET @cOutField08 = rdt.rdtFormatDate( @dLottable04)    
      SET @cOutField09 = @cCaseID    
      SET @cOutField10 = ''    
      SET @cOutField11 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc    
      SET @cOutField12 = CASE WHEN @cFieldAttr14 = 'O' AND @cPUOM = '6' THEN '' ELSE rdt.rdtRightAlign( CAST( @nPQTY_RPL AS NVARCHAR( 5)), 5) END    
      SET @cOutField13 = rdt.rdtRightAlign( CAST( @nMQTY_RPL AS NVARCHAR( 5)), 5)   
      SET @cOutField14 = CASE WHEN @cFieldAttr14 = 'O' AND @cPUOM = '6' THEN '' ELSE rdt.rdtRightAlign( CAST( @nPQTY_RPL AS NVARCHAR( 5)), 5) END    
      SET @cOutField15 = rdt.rdtRightAlign( CAST( @nMQTY AS NVARCHAR( 5)), 5) -- MQTY    
      EXEC rdt.rdtSetFocusField @nMobile, 10 -- SKU    
    
    
--      SET @nScn = @nScn + 1    
-- SET @nStep = @nStep + 1    
    
    
      -- Go to SKU screen    
      SET @nScn = @nScnSKU    
      SET @nStep = @nStepSKU    
    
    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
    
      SET @cOutField01 = @cFromloc    
      SET @cOutField02 = @cSuggID    
      SET @cOutField03 = ''    
      SET @cOutField04 = ''    
      SET @cOutField05 = ''    
      SET @cOutField06 = ''    
    
      SET @nScn = @nScn - 1    
      SET @nStep = @nStep - 1    
    
    
   END    
   GOTO Quit    
    
   Step_3_Fail:    
   BEGIN    
      SET @cToLoc = ''    
    
      -- Reset this screen var    
      SET @cOutField01 = @cFromloc    
      SET @cOutField02 = @cID    
      SET @cOutField03 = @cSuggToLoc    
      SET @cOutField04 = ''    
    
    
  END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 4. screen = 2683    
    SKU        (Field01)    
    SKUDESCR   (Field02)    
    SKUDESCR   (Field03)    
    Lottable01 (Field04)    
    Lottable02 (Field05)    
    Lottable03 (Field06)    
    Lottable04 (Field07)    
    SKU/UPC    (Field08, input)    
    UOM ratio  (Field09)    
    PUOM       (Field10)    
    MUOM       (Field11)    
    PQTY_RPL   (Field12)    
    PQTY       (Field13, input)    
    MQTY_RPL   (Field14)    
    MQTY       (Field15, input)    
********************************************************************************/    
Step_4:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      SET @nUCCQTY = 0    
    
      -- Screen mapping    
      SET @cLabelNo = @cInField10    
      SET @cSKU = @cInField10    
      SET @cPQTY = CASE WHEN @cFieldAttr14 = 'O' AND @cPUOM = '6' THEN '' ELSE CASE WHEN @cFieldAttr14 = 'O' THEN @cOutField14 ELSE @cInField14 END END    
      SET @cMQTY = @cInField15    
      SET @cBarcode = @cLabelNo    
    
      -- Retain value    
      SET @cOutField14 = @cInField14 -- PQTY    
      SET @cOutField15 = @cInField15 -- MQTY    
    
      -- Check SKU blank    
      IF @cLabelNo = '' AND @nSKUValidated = 0 -- False    
      BEGIN    
         SET @nErrNo = 78557    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU Req    
         EXEC rdt.rdtSetFocusField @nMobile, 10 -- SKU    
         GOTO Step_4_Fail    
      END    
    
      -- Validate SKU    
      IF @cLabelNo <> ''    
      BEGIN    
         DECLARE @cDecodeSKU  NVARCHAR( 20)    
         DECLARE @nDecodeQTY  INT    
         SET @cDecodeSKU = @cSKU    
         SET @nDecodeQTY = @nUCCQTY    
         -- Standard decode    
         IF @cDecodeSKUSP = '1'    
         BEGIN    
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,     
               @cUPC    = @cDecodeSKU  OUTPUT,     
               @nQTY    = @nDecodeQTY  OUTPUT,     
               @nErrNo  = @nErrNo      OUTPUT,     
               @cErrMsg = @cErrMsg     OUTPUT,    
               @cType   = 'UPC'    
     
            IF @nErrNo <> 0    
               GOTO Step_4_Fail    
            ELSE    
            BEGIN    
               SET @cSKU = @cDecodeSKU    
               IF ISNULL( @nDecodeQTY, 0) <> 0    
                  SET @nUCCQTY = CAST( @nDecodeQTY AS NVARCHAR( 5))    
            END    
         END    
         -- Customize decode    
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSKUSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSKUSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cBarcode, ' +     
               ' @cSKU OUTPUT, @nQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '     
            SET @cSQLParam =    
               ' @nMobile        INT,           ' +    
               ' @nFunc          INT,           ' +    
               ' @cLangCode      NVARCHAR( 3),  ' +    
               ' @nStep          INT,           ' +    
               ' @nInputKey      INT,           ' +    
               ' @cTaskdetailKey NVARCHAR( 10),  ' +    
               ' @cBarcode       NVARCHAR( 60),  ' +    
               ' @cSKU           NVARCHAR( 20)  OUTPUT, ' +    
               ' @nQTY           INT            OUTPUT, ' +    
               ' @nErrNo         INT            OUTPUT, ' +    
               ' @cErrMsg        NVARCHAR( 20)  OUTPUT'    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cBarcode,     
               @cDecodeSKU OUTPUT, @nDecodeQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
            IF @nErrNo <> 0    
               GOTO Step_4_Fail    
            ELSE    
            BEGIN    
               SET @cSKU = @cDecodeSKU    
               IF ISNULL( @nDecodeQTY, 0) <> 0    
                  SET @nUCCQTY = CAST( @nDecodeQTY AS NVARCHAR( 5))    
            END    
         END    
         ELSE    
         BEGIN    
            -- Decode label    
            IF @cDecodeLabelNo <> ''    
            BEGIN    
               --SET @c_oFieled09 = @cDropID    
               SET @c_oFieled10 = @cTaskDetailKey    
    
               SET @cErrMsg = ''    
               SET @nErrNo = 0    
               EXEC dbo.ispLabelNo_Decoding_Wrapper    
                   @c_SPName     = @cDecodeLabelNo    
                  ,@c_LabelNo    = @cLabelNo    
                  ,@c_Storerkey  = @cStorerKey    
                  ,@c_ReceiptKey = ''    
                  ,@c_POKey      = ''    
                  ,@c_LangCode   = @cLangCode    
                  ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU    
                  ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE    
                  ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR    
                  ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE    
                  ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY    
                  ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- LOT    
            ,@c_oFieled07  = @c_oFieled07 OUTPUT   -- Label Type    
                  ,@c_oFieled08  = @c_oFieled08 OUTPUT   -- UCC    
                  ,@c_oFieled09  = @c_oFieled09 OUTPUT    
                  ,@c_oFieled10  = @c_oFieled10 OUTPUT    
                  ,@b_Success    = @b_Success   OUTPUT    
                  ,@n_ErrNo      = @nErrNo      OUTPUT    
                  ,@c_ErrMsg     = @cErrMsg     OUTPUT    
    
               IF @nErrNo <> 0    
                  GOTO Step_4_Fail    
    
               SET @cSKU    = ISNULL( @c_oFieled01, '')    
               SET @nUCCQTY = CAST( ISNULL( @c_oFieled05, '') AS INT)    
               SET @cUCC    = ISNULL( @c_oFieled08, '')    
    
               -- Reload task    
               IF @c_oFieled10 <> @cTaskDetailKey    
               BEGIN    
                  SET @cSwapTaskDetailKey = @c_oFieled10    
    
                  -- Get new task info    
                  SELECT    
                     @cStorerKey   = RTRIM(Storerkey),    
                     @cSuggSKU     = RTRIM(SKU),    
                     @cSuggToLoc   = RTRIM(ToLOC),    
                     @cLot         = RTRIM(Lot),    
                     @cSourceKey   = RTRIM(SourceKey),    
                     @nQTY_RPL     = QTY,    
                     @cCaseID      = CaseID    
                  FROM dbo.TaskDetail WITH (NOLOCK)    
                  WHERE TaskDetailKey = @cSwapTaskDetailKey    
    
-- (ChewKP04)     
--                  SET @nTranCount = @@TRANCOUNT    
--                  BEGIN TRAN  -- Begin our own transaction    
--                  SAVE TRAN rdtfnc_TM_ReplenTo -- For rollback or commit only our own transaction    
--    
--                  -- Lock new task    
--                  UPDATE TaskDetail SET    
--                      Status = '3'    
--                     ,UserKey = @cUserName    
--                     ,ReasonKey = ''    
--                     ,EditDate = GETDATE()    
--                     ,EditWho  = SUSER_SNAME()    
--                     ,TrafficCop = NULL    
--                  WHERE TaskDetailKey = @cSwapTaskDetailKey    
--                  IF @@ERROR <> 0    
--                  BEGIN    
--                     ROLLBACK TRAN rdtfnc_TM_ReplenTo -- Only rollback change made here    
--                     WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
--                        COMMIT TRAN    
--    
--                     SET @nErrNo = 78589    
--                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskDetFail    
--                     GOTO Step_4_Fail    
--                  END    
--    
--                  -- Release current task    
--                  UPDATE TaskDetail SET    
--                      Status = '0'    
--                     ,UserKey = ''    
--                     ,ReasonKey = ''    
--                     ,EditDate = GETDATE()    
--                     ,EditWho  = SUSER_SNAME()    
--                     ,TrafficCop = NULL    
--                  WHERE TaskDetailKey = @cTaskDetailKey    
--                  IF @@ERROR <> 0    
--                  BEGIN    
--                     ROLLBACK TRAN rdtfnc_TM_ReplenTo -- Only rollback change made here    
--                     WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
--                        COMMIT TRAN    
--    
--                     SET @nErrNo = 78590    
--                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskDetFail    
--                     GOTO Step_4_Fail    
--                  END    
--    
--                  COMMIT TRAN rdtfnc_TM_ReplenTo -- Only rollback change made here    
--                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
--                     COMMIT TRAN    
    
                  SET @cTaskDetailKey = @cSwapTaskDetailKey    
    
                  -- Get SKU info    
                  SELECT    
                     @cUOM = Pack.PackUOM3,    
   @cPackkey = Pack.PackKey,    
                     @cSKUDesc = S.Descr,    
                     @cMUOM_Desc = Pack.PackUOM3,    
                     @cPUOM_Desc =    
                        CASE @cPUOM    
                           WHEN '2' THEN Pack.PackUOM1 -- Case    
                           WHEN '3' THEN Pack.PackUOM2 -- Inner pack    
                           WHEN '6' THEN Pack.PackUOM3 -- Master unit    
                           WHEN '1' THEN Pack.PackUOM4 -- Pallet    
                           WHEN '4' THEN Pack.PackUOM8 -- Other unit 1    
                           WHEN '5' THEN Pack.PackUOM9 -- Other unit 2    
                        END,    
                     @nPUOM_Div = CAST(    
                        CASE @cPUOM    
                           WHEN '2' THEN Pack.CaseCNT    
                           WHEN '3' THEN Pack.InnerPack    
                           WHEN '6' THEN Pack.QTY    
                           WHEN '1' THEN Pack.Pallet    
                           WHEN '4' THEN Pack.OtherUnit1    
                           WHEN '5' THEN Pack.OtherUnit2    
                        END AS INT)    
                  FROM dbo.SKU S WITH (NOLOCK)    
                     INNER JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)    
                  WHERE StorerKey = @cStorerKey    
                     AND SKU = @cSuggSKU    
    
                  -- Get lottable    
                  SELECT    
                     @cLottable01 = LA.Lottable01,    
                     @cLottable02 = LA.Lottable02,    
                     @cLottable03 = LA.Lottable03,    
                     @dLottable04 = LA.Lottable04    
                  FROM dbo.LOTAttribute LA WITH (NOLOCK)    
                  WHERE LOT = @cLOT    
    
                  -- Disable QTY field    
                  SET @cFieldAttr14 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- PQTY    
                  SET @cFieldAttr15 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- MQTY    
    
                  -- Convert to prefer UOM QTY    
                  IF @cPUOM = '6' OR -- When preferred UOM = master unit    
                     @nPUOM_Div = 0 -- UOM not setup    
                  BEGIN    
                     SET @cPUOM_Desc = ''    
                     SET @nPQTY_RPL = 0    
                     SET @nPQTY = 0    
                     SET @nMQTY = @nQTY_RPL    
                     SET @nMQTY_RPL = @nQTY_RPL    
                     SET @cFieldAttr14 = 'O' -- @nPQTY_PWY    
                  END    
                  ELSE    
                  BEGIN    
                     SET @nPQTY = 0    
                     SET @nMQTY = @nQTY_RPL    
    
                     SET @nPQTY = @nQTY_RPL / @nPUOM_Div -- Calc QTY in preferred UOM    
                     SET @nMQTY = @nQTY_RPL % @nPUOM_Div -- Calc the remaining in master unit    
    
                     SET @nPQTY_RPL = @nQTY_RPL / @nPUOM_Div -- Calc QTY in preferred UOM    
                     SET @nMQTY_RPL = @nQTY_RPL % @nPUOM_Div -- Calc the remaining in master unit    
                  END    
  
                  -- Disable QTY field    
                  SET @cFieldAttr14 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- PQTY    
                  SET @cFieldAttr15 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- MQTY    
           
                  -- Prepare next screen variable    
                  SET @cOutField01 = @cToLoc    
                  SET @cOutField02 = @cSuggSKU    
                  SET @cOutField03 = SUBSTRING( @cSKUDesc, 1, 20)    
                  SET @cOutField04 = SUBSTRING( @cSKUDesc, 21, 20)    
                  SET @cOutField05 = @cLottable01    
                  SET @cOutField06 = @cLottable02    
                  SET @cOutField07 = @cLottable03    
                  SET @cOutField08 = rdt.rdtFormatDate( @dLottable04)    
                  SET @cOutField09 = @cCaseID    
                  SET @cOutField10 = ''    
                  SET @cOutField11 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc    
                  SET @cOutField12 = CASE WHEN @cFieldAttr14 = 'O' AND @cPUOM = '6' THEN '' ELSE rdt.rdtRightAlign( CAST( @nPQTY_RPL AS NVARCHAR( 5)), 5) END    
                  SET @cOutField13 = rdt.rdtRightAlign( CAST( @nMQTY_RPL AS NVARCHAR( 5)), 5)   
                  SET @cOutField14 = CASE WHEN @cFieldAttr14 = 'O' AND @cPUOM = '6' THEN '' ELSE rdt.rdtRightAlign( CAST( @nPQTY_RPL AS NVARCHAR( 5)), 5) END    
                  SET @cOutField15 = rdt.rdtRightAlign( CAST( @nMQTY AS NVARCHAR( 5)), 5) -- MQTY    
               END    
            END    
         END    
    
         -- Get SKU barcode count    
         SET @nSKUCnt = 0    
         EXEC rdt.rdt_GETSKUCNT    
             @cStorerKey  = @cStorerKey    
            ,@cSKU        = @cSKU    
            ,@nSKUCnt     = @nSKUCnt       OUTPUT    
            ,@bSuccess    = @b_Success     OUTPUT    
            ,@nErr        = @nErrNo        OUTPUT    
            ,@cErrMsg     = @cErrMsg       OUTPUT    
    
         -- Check SKU/UPC    
         IF @nSKUCnt = 0    
         BEGIN    
            SET @nErrNo = 78581    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU    
            EXEC rdt.rdtSetFocusField @nMobile, 8 -- SKU    
            GOTO Step_4_Fail    
         END    
    
         -- Check multi SKU barcode    
         IF @nSKUCnt > 1    
         BEGIN    
            SET @nErrNo = 78582    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod    
            EXEC rdt.rdtSetFocusField @nMobile, 8 -- SKU    
            GOTO Step_4_Fail    
         END    
    
         -- Get SKU code    
         EXEC rdt.rdt_GETSKU    
             @cStorerKey  = @cStorerKey    
            ,@cSKU        = @cSKU          OUTPUT    
            ,@bSuccess    = @b_Success     OUTPUT    
            ,@nErr        = @nErrNo        OUTPUT    
            ,@cErrMsg     = @cErrMsg       OUTPUT    
    
         -- Check SKU same as suggested    
         IF @cSKU <> @cSuggSKU    
         BEGIN    
            SET @nErrNo = 78557    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Different SKU    
            EXEC rdt.rdtSetFocusField @nMobile, 8 -- SKU    
            GOTO Step_4_Fail    
         END    
    
         -- Mark SKU as validated    
         SET @nSKUValidated = 1    
      END    
    
      -- Validate PQTY    
      IF @cPQTY <> '' AND RDT.rdtIsValidQTY( @cPQTY, 0) = 0    
      BEGIN    
         SET @nErrNo = 78563    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY    
         EXEC rdt.rdtSetFocusField @nMobile, 14 -- PQTY    
         GOTO Step_4_Fail    
      END    
      SET @nPQTY = CAST( @cPQTY AS INT)    
    
      -- Validate MQTY    
      IF @cMQTY <> '' AND RDT.rdtIsValidQTY( @cMQTY, 0) = 0    
      BEGIN    
         SET @nErrNo = 78564    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY    
         EXEC rdt.rdtSetFocusField @nMobile, 15 -- MQTY    
         GOTO Step_4_Fail    
      END    
      SET @nMQTY = CAST( @cMQTY AS INT)    
    
      -- Decode label with QTY    
      IF @nUCCQTY > 0    
      BEGIN    
         -- Top up decoded QTY    
         IF @cPUOM = '6' OR -- When preferred UOM = master unit    
            @nPUOM_Div = 0 -- UOM not setup    
         BEGIN    
            SET @nMQTY = @nMQTY + @nUCCQTY    
         END    
         ELSE    
         BEGIN    
            SET @nPQTY = @nPQTY + (@nUCCQTY / @nPUOM_Div) -- Calc QTY in preferred UOM    
            SET @nMQTY = @nMQTY + (@nUCCQTY % @nPUOM_Div) -- Calc the remaining in master unit    
         END    
      END    
      ELSE    
      BEGIN    
         -- Scan SKU / decode label without QTY    
         IF @cPQTY = '' AND @cMQTY = ''    
         BEGIN    
            -- Go to QTY field    
            IF @cFieldAttr14 = 'O'    
           EXEC rdt.rdtSetFocusField @nMobile, 15 -- MQTY    
            ELSE    
               EXEC rdt.rdtSetFocusField @nMobile, 14 -- PQTY    
            GOTO Quit    
         END    
      END    
    
      -- Calc total QTY in master UOM    
      SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSuggSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM    
      SET @nQTY = @nQTY + @nMQTY    
    
      IF @cExtendedValidateSP <> ''    
      BEGIN    
          IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
          BEGIN    
             SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
                ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cLabelNo, @nStep, @cTaskDetailKey, @nQty, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
             SET @cSQLParam =    
                '@nMobile        INT, ' +    
                '@nFunc          INT, ' +    
                '@cLangCode      NVARCHAR( 3),  ' +    
                '@cUserName      NVARCHAR( 18), ' +    
                '@cFacility      NVARCHAR( 5),  ' +    
                '@cStorerKey     NVARCHAR( 15), ' +    
                '@cLabelNo        NVARCHAR( 20), ' +    
                '@nStep          INT,           ' +    
                '@cTaskDetailKey NVARCHAR( 10), ' +    
                '@nQty           INT,           ' +    
                '@nErrNo         INT           OUTPUT, ' +    
                '@cErrMsg        NVARCHAR( 20) OUTPUT'    
    
    
             EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cLabelNo, @nStep, @cTaskDetailKey , @nQty, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
             IF @nErrNo <> 0    
                GOTO Step_4_Fail    
          END    
      END    
      -- Check QTY available    
--      DECLARE @nQTYAllowToMove INT    
--      IF @cMoveQTYAlloc = '1'    
--         SELECT @nQTYAllowToMove = ISNULL( SUM( QTY - QTYPicked), 0)    
--         FROM dbo.LOTxLOCxID (NOLOCK)    
--         WHERE StorerKey = @cStorerKey    
--            AND LOC = @cSuggFromLOC    
--            AND ID = @cSuggID    
--            AND SKU = @cSuggSKU    
--            AND LOT = @cSuggLOT    
--      ELSE    
--         SELECT @nQTYAllowToMove = ISNULL( SUM( QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)), 0)    
--         FROM dbo.LOTxLOCxID (NOLOCK)    
--         WHERE StorerKey = @cStorerKey    
--            AND LOC = @cSuggFromLOC    
--            AND ID = @cSuggID    
--            AND SKU = @cSuggSKU    
--            AND LOT = @cSuggLOT    
--      IF @nQTYAllowToMove < @nQTY    
--      BEGIN    
--         SET @nErrNo = 78585    
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- QTYAVLNotEnuf    
--         GOTO Step_4_Fail    
--      END    
    
      -- Decode label have QTY, remain in current screen    
    
      IF @nUCCQTY > 0    
      BEGIN    
         -- Mark UCC scanned    
--         IF @cUCC <> ''    
--         BEGIN    
--            INSERT INTO rdt.rdtRPFLog (TaskDetailKey, DropID, UCCNo, QTY) VALUES (@cTaskDetailKey, @cDropID, @cUCC, @nUCCQTY)    
--            IF @@ERROR <> 0    
--            BEGIN    
--               SET @nErrNo = 72298    
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RPFLogFail    
--               GOTO Quit    
--            END    
--         END    
    
    
    
         -- QTY fulfill    
         IF @nQTY >= @nQTY_RPL    
         BEGIN    
    
            IF @cExtendedUpdateSP <> ''    
            BEGIN    
    
                IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
                BEGIN    
                   -- (ChewKP01)    
                   --INSERT INTO TraceInfo (TraceName , TimeIn , col1 , col2, Col3, Col4, col5, step1 )    
                   --VALUES ( 'RPT', GetDATE(), @cTaskDetailKey, @cLabelNo, '', '' , '', '0' )    
    
          SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
                      ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cLabelNo, @nStep, @cTaskDetailKey, @nQty, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
                   SET @cSQLParam =    
                      '@nMobile        INT, ' +    
                      '@nFunc          INT, ' +    
                      '@cLangCode      NVARCHAR( 3),  ' +    
                      '@cUserName      NVARCHAR( 18), ' +    
                      '@cFacility      NVARCHAR( 5),  ' +    
                      '@cStorerKey     NVARCHAR( 15), ' +    
                      '@cLabelNo        NVARCHAR( 20), ' +    
                      '@nStep          INT,           ' +    
                      '@cTaskDetailKey NVARCHAR( 10), ' +    
                      '@nQty           INT,           ' +    
                      '@nErrNo         INT           OUTPUT, ' +    
                      '@cErrMsg        NVARCHAR( 20) OUTPUT'    
    
    
                   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                      @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cLabelNo, @nStep, @cTaskDetailKey , @nQty, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
                   IF @nErrNo <> 0    
                      GOTO Step_4_Fail    
    
                END    
            END    
              
            -- EventLog - QTY  --(cc01)  
            EXEC RDT.rdt_STD_EventLog    
               @cActionType   = '4', -- Move    
               @cUserID       = @cUserName,    
               @nMobileNo     = @nMobile,    
               @nFunctionID   = @nFunc,    
               @cFacility     = @cFacility,    
               @cStorerKey    = @cStorerKey,    
               @cLocation     = @cSuggFromLoc,    
               @cToLocation   = @cToLOC,    
               @cID           = @cID,    
               @cToID         = @cID,    
               @cSKU          = @cSKU,    
               @cUOM          = @cUOM,    
               @nQTY          = @nQTY,    
               @cLot          = @cLot,    
               @cRefNo1       = @cTaskdetailkey    
           
            -- Prepare next screen var    
            SET @nScn = @nScn + 1    
            SET @nStep = @nStep + 1    
         END    
         ELSE    
         BEGIN    
               -- Remain in current screen    
               SET @cOutField14 = CASE WHEN @cFieldAttr14 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END    
               SET @cOutField15 = CAST( @nMQTY AS NVARCHAR( 5))    
               EXEC rdt.rdtSetFocusField @nMobile, 8 -- SKU    
         END    
      END    
      ELSE    
      BEGIN    
         -- QTY short    
         IF @nQTY < @nQTY_RPL    
         BEGIN    
            -- Prepare next screen var    
--            SET @cOption = ''    
--            SET @cOutField01 = '' -- Option    
    
--            SET @nScn = @nScn + 3    
--            SET @nStep = @nStep + 3    
              SET @cOutField01 = ''    
              SET @nFromStep = 4    
    
              -- Go to Reason Code Screen    
              SET @nScn  = 2109    
              SET @nStep = @nStep + 2 -- Step 6    
    
         END    
    
         -- QTY fulfill    
         IF @nQTY >= @nQTY_RPL    
         BEGIN    
    
            IF @cExtendedUpdateSP <> ''    
            BEGIN    
    
                IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
                BEGIN    
    
                   SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
                      ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cLabelNo, @nStep, @cTaskDetailKey, @nQty, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
                   SET @cSQLParam =    
                      '@nMobile        INT, ' +    
                      '@nFunc          INT, ' +    
                      '@cLangCode      NVARCHAR( 3),  ' +    
                      '@cUserName      NVARCHAR( 18), ' +    
    '@cFacility      NVARCHAR( 5),  ' +    
                      '@cStorerKey     NVARCHAR( 15), ' +    
                      '@cLabelNo        NVARCHAR( 20), ' +    
                      '@nStep          INT,           ' +    
                      '@cTaskDetailKey NVARCHAR( 10), ' +    
                      '@nQty           INT,           ' +    
                      '@nErrNo         INT           OUTPUT, ' +    
                      '@cErrMsg        NVARCHAR( 20) OUTPUT'    
    
    
                   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                      @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cLabelNo, @nStep, @cTaskDetailKey, @nQty, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
                   IF @nErrNo <> 0    
                      GOTO Step_4_Fail    
    
                END    
            END    
    
            -- Prepare next screen var    
            -- EventLog - QTY  --(cc01)  
            EXEC RDT.rdt_STD_EventLog    
               @cActionType   = '4', -- Move    
               @cUserID       = @cUserName,    
               @nMobileNo     = @nMobile,    
               @nFunctionID   = @nFunc,    
               @cFacility     = @cFacility,    
               @cStorerKey    = @cStorerKey,    
               @cLocation     = @cSuggFromLoc,    
               @cToLocation   = @cToLOC,    
               @cID           = @cID,    
               @cToID         = @cID,    
               @cSKU          = @cSKU,    
               @cUOM          = @cUOM,    
               @nQTY          = @nQTY,    
               @cLot          = @cLot,    
               @cRefNo1       = @cTaskdetailkey   
                 
            SET @nScn = @nScn + 1    
            SET @nStep = @nStep + 1    
         END    
      END    
    
--      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo1 = ''    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cExtendedLabel OUTPUT, @cExtendedInfo1 OUTPUT, @cExtendedInfo2 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@cExtendedLabel  NVARCHAR( 20) OUTPUT, ' +    
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +    
               '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +    
               '@nErrNo          INT           OUTPUT, ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +    
               '@nAfterStep      INT '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cExtendedLabel OUTPUT, @cExtendedInfo1 OUTPUT, @cExtendedInfo2 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep    
    
            IF @nStep = 4    
               SET @cOutField09 = @cExtendedInfo1    
         END    
      END    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
--      SET @cOutField01 = @cSuggFromLoc    
--      SET @cOutField02 = @cID    
--      SET @cOutField03 = @cSuggToLoc    
--      --SET @cOutField03 = @cToLoc    
--      SET @cOutField04 = ''    
--    
--      -- go to previous screen    
--      SET @nScn = @nScnToLoc    
--      SET @nStep = @nStepToLoc    
    
      SET @cOutField01 = ''    
      SET @nFromStep = 4    
    
      -- Go to Reason Code Screen    
      SET @nScn  = 2109    
      SET @nStep = @nStep + 2 -- Step 6    
    
   END    
   GOTO Quit    
    
   Step_4_Fail:    
END    
GOTO Quit    
    
    
    
/********************************************************************************    
Step 5. screen = 2784    
     Success Message    
********************************************************************************/    
Step_5:    
BEGIN    
   IF @nInputKey = 1 --OR @nInputKey = 0 -- ENTER / ESC    
   BEGIN    
    
      SET @cErrMsg = ''    
      SET @cNextTaskDetailKey = ''    
      SET @cNextTaskType = ''    
    
      -- Check if still exists RPT Task, if not call nspTMTM01 (Chee02) -- (ChewKP02)    
      SELECT TOP 1 @cNextTaskDetailKey  = TD.TaskDetailkey    
            ,@cNextTaskType       = TD.TaskType    
      FROM TaskDetail TD WITH (NOLOCK)    
      JOIN Loc ToLoc WITH (NOLOCK) ON (TD.ToLoc = ToLoc.Loc)    
      WHERE TD.Storerkey = @cStorerKey    
        AND TD.TaskType  = 'RPT'    
        AND TD.UserKey   = @cUserName    
        AND TD.[Status]  = '3'    
      ORDER BY ToLoc.LogicalLocation, TD.ToLoc    
    
    
      IF @cNextTaskDetailKey = ''    
      BEGIN    
         -- Get next task    
         EXEC dbo.nspTMTM01    
             @c_sendDelimiter = null    
            ,@c_ptcid         = 'RDT'    
            ,@c_userid        = @cUserName    
            ,@c_taskId        = 'RDT'    
            ,@c_databasename  = NULL    
            ,@c_appflag       = NULL    
            ,@c_recordType    = NULL    
            ,@c_server        = NULL    
            ,@c_ttm           = NULL    
            ,@c_areakey01     = @cAreaKey    
            ,@c_areakey02     = ''    
            ,@c_areakey03  = ''    
            ,@c_areakey04     = ''    
            ,@c_areakey05     = ''    
            ,@c_lastloc       = @cSuggToLOC    
            ,@c_lasttasktype  = @cTTMTaskType    
            ,@c_outstring     = @c_outstring    OUTPUT    
            ,@b_Success       = @b_Success      OUTPUT    
            ,@n_err           = @nErrNo         OUTPUT    
            ,@c_errmsg        = @cErrMsg        OUTPUT    
            ,@c_TaskDetailKey = @cNextTaskDetailKey OUTPUT    
            ,@c_ttmtasktype   = @cNextTaskType  OUTPUT    
            ,@c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func    
            ,@c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func    
            ,@c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func    
            ,@c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func    
            ,@c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func    
            ,@n_Mobile        = @nMobile
            ,@n_Func          = @nFunc
            ,@c_StorerKey     = @cStorerKey

         IF @b_Success = 0 OR @nErrNo <> 0    
         BEGIN
            IF @cContinueTask = '1'
            BEGIN
               EXEC dbo.nspTMTM01    
                   @c_sendDelimiter = null    
                  ,@c_ptcid         = 'RDT'    
                  ,@c_userid        = @cUserName    
                  ,@c_taskId        = 'RDT'    
                  ,@c_databasename  = NULL    
                  ,@c_appflag       = NULL    
                  ,@c_recordType    = NULL    
                  ,@c_server        = NULL    
                  ,@c_ttm           = NULL    
                  ,@c_areakey01     = @cAreaKey    
                  ,@c_areakey02     = ''    
                  ,@c_areakey03     = ''    
                  ,@c_areakey04     = ''    
                  ,@c_areakey05     = ''    
                  ,@c_lastloc       = ''    
                  ,@c_lasttasktype  = ''    
                  ,@c_outstring     = @c_outstring    OUTPUT    
                  ,@b_Success       = @b_Success      OUTPUT    
                  ,@n_err           = @nErrNo         OUTPUT    
                  ,@c_errmsg        = @cErrMsg        OUTPUT    
                  ,@c_taskdetailkey = @cNextTaskDetailKey OUTPUT    
                  ,@c_ttmtasktype   = @cNextTaskType   OUTPUT    
                  ,@c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func    
                  ,@c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func    
                  ,@c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func    
                  ,@c_RefKey04      = @cRefKey04  OUTPUT -- this is the field value to parse to 1st Scn in func    
                  ,@c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func                   
                  ,@n_Mobile        = @nMobile
                  ,@n_Func          = @nFunc
                  ,@c_StorerKey     = @cStorerKey
            END
            ELSE
               GOTO Quit
         END
      END    
    
      -- No task    
      IF @cNextTaskDetailKey = ''    
      BEGIN    
         -- Logging    
         EXEC RDT.rdt_STD_EventLog    
             @cActionType = '9', -- Sign out function    
             @cUserID     = @cUserName,    
             @nMobileNo   = @nMobile,    
             @nFunctionID = @nFunc,    
             @cFacility   = @cFacility,    
             @cStorerKey  = @cStorerKey    
    
         -- Go back to Task Manager Main Screen    
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
    
         SET @nFunc = 1756    
         SET @nScn = 2100    
         SET @nStep = 1    
         GOTO QUIT    
      END    
    
      -- Have next task    
      IF @cNextTaskDetailKey <> ''    
      BEGIN    
         SET @cPrevTaskDetailKey = @cTaskDetailKey    
         SET @cTaskDetailKey = @cNextTaskDetailKey    
         SET @cTTMTaskType = @cNextTaskType    
         SET @cOutField01 = @cRefKey01    
         SET @cOutField02 = @cRefKey02    
         SET @cOutField03 = @cRefKey03    
         SET @cOutField04 = @cRefKey04    
         SET @cOutField05 = @cRefKey05             
         SET @cOutField06 = @cTaskDetailKey    
         SET @cOutField07 = @cAreaKey    
         SET @cOutField08 = @cTTMStrategykey    
         SET @cOutField09 = ''    
         SET @nFromStep = '0'    
      END    
    
      SET @nToFunc = 0    
      SET @nToScn  = 0    
      SET @nToStep = 0    
    
      -- Check if function setup    
      SELECT    
         @nToFunc = Function_ID,    
         @nToStep = Step    
      FROM rdt.rdtTaskManagerConfig WITH (NOLOCK)    
      WHERE TaskType = @cTTMTaskType    
    
    
      IF @nToFunc = 0    
      BEGIN    
         SET @nErrNo = 78572    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr    
         GOTO QUIT    
      END    
    
      -- Check if screen setup    
      SELECT TOP 1 @nToScn = Scn FROM RDT.RDTScn WITH (NOLOCK) WHERE Func = @nToFunc ORDER BY Scn    
      IF @nToScn = 0    
      BEGIN    
         SET @nErrNo = 78573    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr    
         GOTO QUIT    
      END    
    
--      -- Logging    
--      EXEC RDT.rdt_STD_EventLog    
--         @cActionType = '9', -- Sign Out function    
--         @cUserID     = @cUserName,    
--         @nMobileNo   = @nMobile,    
--         @nFunctionID = @nFunc,    
--         @cFacility   = @cFacility,    
--         @cStorerKey  = @cStorerKey    
    
--      SET @nFunc = @nToFunc    
--      SET @nScn  = @nToScn    
--      SET @nStep = @nToStep    
    
      IF @cTTMTaskType IN ('RPT')    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetNextTaskSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetNextTaskSP) +    
               ' @nMobile, @nFunc, @cLangCode, @cUserName, @cAreaKey, @cPrevTaskDetailKey, @cTaskDetailKey, @nStep OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile            INT,           ' +    
               '@nFunc              INT,           ' +    
               '@cLangCode          NVARCHAR( 3),  ' +    
               '@cUserName          NVARCHAR( 18), ' +    
               '@cAreaKey           NVARCHAR( 10), ' +    
               '@cPrevTaskDetailKey NVARCHAR( 10), ' +    
               '@cTaskDetailKey     NVARCHAR( 10), ' +    
               '@nStep              INT OUTPUT, ' +    
               '@nErrNo             INT           OUTPUT, ' +    
               '@cErrMsg            NVARCHAR( 20) OUTPUT  '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @cUserName, @cAreaKey, @cPrevTaskDetailKey, @cTaskDetailKey , @nStep OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO QUIT    
    
            SELECT @cStorerKey   = RTRIM(Storerkey),    
                @cSuggSKU     = RTRIM(SKU),    
                @cSuggID      = RTRIM(FromID),    
                @cSuggToLoc   = RTRIM(ToLOC),    
                @cLot         = RTRIM(Lot),    
                @cSourceKey   = RTRIM(SourceKey),    
                @cSuggFromLoc = RTRIM(FromLoc),    
                @nQTY_RPL     = Qty,    
                @cCaseID      = CaseID    
            FROM dbo.TaskDetail WITH (NOLOCK)    
            WHERE TaskDetailKey = @cTaskdetailkey    
    
            IF @nStep = 0    
            BEGIN    
               GOTO Step_0    
            END    
            ELSE IF @nStep = 1    
            BEGIN    
               -- prepare next screen    
               SET @cOutField01 = @cSuggFromLoc    
               SET @cOutField02 = ''    
               SET @cOutField03 = ''    
               SET @cOutField04 = ''    
               SET @cOutField05 = ''    
    
               -- Go to next screen    
               SET @nScn = @nScnFromLoc    
               SET @nStep = @nStepFromLoc    
    
            END    
            ELSE IF @nStep = 2    
            BEGIN    
               -- prepare next screen    
               SET @cOutField01 = @cFromLoc    
       SET @cOutField02 = @cSuggID    
               SET @cOutField03 = ''    
               SET @cOutField04 = ''    
               SET @cOutField05 = ''    
    
               -- Go to next screen    
               SET @nScn = @nScnID    
               SET @nStep = @nStepID    
            END    
            ELSE IF @nStep = 3    
            BEGIN    
               -- (Chee01)    
               IF @cExtendedInfoSP <> ''    
               BEGIN    
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
                  BEGIN    
                     SET @nStep = @nStep - 1    
                     SET @cExtendedInfo1 = ''    
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cExtendedLabel OUTPUT, @cExtendedInfo1 OUTPUT, @cExtendedInfo2 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'    
                     SET @cSQLParam =    
                        '@nMobile         INT,           ' +    
                        '@nFunc           INT,           ' +    
                        '@cLangCode       NVARCHAR( 3),  ' +    
                        '@nStep           INT,           ' +    
                        '@cTaskdetailKey  NVARCHAR( 10), ' +    
                        '@cExtendedLabel  NVARCHAR( 20) OUTPUT, ' +    
                        '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +    
                        '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +    
                        '@nErrNo          INT           OUTPUT, ' +    
                        '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +    
                        '@nAfterStep      INT '    
    
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                        @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cExtendedLabel OUTPUT, @cExtendedInfo1 OUTPUT, @cExtendedInfo2 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep    
    
                     IF @nStep = 2    
                     BEGIN    
                        SET @cOutField05 = @cExtendedLabel    
                        SET @cOutField06 = @cExtendedInfo1    
                        SET @cOutField07 = @cExtendedInfo2    
                     END    
                  END    
               END    
               ELSE    
               BEGIN    
                  SET @cOutField05 = ''    
                  SET @cOutField06 = ''    
               END    
                   
               IF @cSuggestedLocSP <> ''    
               BEGIN    
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSuggestedLocSP AND type = 'P')    
                  BEGIN    
    
                      SET @cSQL = 'EXEC rdt.' + RTRIM( @cSuggestedLocSP) +    
                         ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cLabelNo, @nStep, @cTaskDetailKey, @nQty, @cCustomSuggToLoc OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
                      SET @cSQLParam =    
                         '@nMobile        INT, ' +    
                         '@nFunc          INT, ' +    
                         '@cLangCode      NVARCHAR( 3),  ' +    
                         '@cUserName      NVARCHAR( 18), ' +    
                         '@cFacility      NVARCHAR( 5),  ' +    
                         '@cStorerKey     NVARCHAR( 15), ' +    
                         '@cLabelNo        NVARCHAR( 20), ' +    
                         '@nStep          INT,           ' +    
                         '@cTaskDetailKey NVARCHAR( 10), ' +    
                         '@nQty           INT,           ' +    
                         '@cCustomSuggToLoc  NVARCHAR( 20) OUTPUT, ' +    
                         '@nErrNo         INT           OUTPUT, ' +    
                         '@cErrMsg        NVARCHAR( 20) OUTPUT'    
    
    
                      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                         @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cLabelNo, @nStep, @cTaskDetailKey , @nQty, @cCustomSuggToLoc OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
                      IF @nErrNo <> 0    
                         GOTO Step_4_Fail    
                             
                      SET @cSuggToLoc = @cCustomSuggToLoc       
    
                  END    
                       
               END    
    
               SET @cOutField01 = @cSuggFromLoc       -- ZG01
               SET @cOutField02 = @cSuggID    
               SET @cOutField03 = @cSuggToLoc    
               SET @cOutField04 = ''    
               --SET @cOutField05 = ''    
    
               -- Go to ToLoc screen    
               SET @nScn = @nScnToLoc    
               SET @nStep = @nStepToLoc    
            END    
            ELSE IF @nStep = 4    
            BEGIN    
            -- Get SKU info    
                  SELECT    
                     @cSKUDesc = S.Descr,    
                     @cMUOM_Desc = Pack.PackUOM3,    
                     @cPUOM_Desc =    
                        CASE @cPUOM    
                           WHEN '2' THEN Pack.PackUOM1 -- Case    
                           WHEN '3' THEN Pack.PackUOM2 -- Inner pack    
                           WHEN '6' THEN Pack.PackUOM3 -- Master unit    
                           WHEN '1' THEN Pack.PackUOM4 -- Pallet    
                           WHEN '4' THEN Pack.PackUOM8 -- Other unit 1    
                           WHEN '5' THEN Pack.PackUOM9 -- Other unit 2    
                        END,    
                     @nPUOM_Div = CAST(    
                        CASE @cPUOM    
                           WHEN '2' THEN Pack.CaseCNT    
                           WHEN '3' THEN Pack.InnerPack    
                           WHEN '6' THEN Pack.QTY    
                           WHEN '1' THEN Pack.Pallet    
                           WHEN '4' THEN Pack.OtherUnit1    
                           WHEN '5' THEN Pack.OtherUnit2    
                        END AS INT)    
                  FROM dbo.SKU S WITH (NOLOCK)    
                     INNER JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)    
                  WHERE StorerKey = @cStorerKey    
                     AND SKU = @cSuggSKU    
    
                  -- Get lottable    
                  SELECT    
                               @cLottable01 = LA.Lottable01,    
                     @cLottable02 = LA.Lottable02,    
                     @cLottable03 = LA.Lottable03,    
                     @dLottable04 = LA.Lottable04    
                  FROM dbo.LOTAttribute LA WITH (NOLOCK)    
                  WHERE LOT = @cLOT    
    
                  -- Convert to prefer UOM QTY    
                  IF @cPUOM = '6' OR -- When preferred UOM = master unit    
                     @nPUOM_Div = 0 -- UOM not setup    
                  BEGIN    
                     SET @cPUOM_Desc = ''    
                     SET @nPQTY_RPL = 0    
                     SET @nPQTY = 0    
                     SET @nMQTY = @nQTY_RPL    
                     SET @nMQTY_RPL = @nQTY_RPL    
                     SET @cFieldAttr14 = 'O' -- @nPQTY_PWY    
                  END    
                  ELSE    
                  BEGIN    
                     SET @nPQTY = 0    
                     SET @nMQTY = @nQTY_RPL    
    
                     SET @nPQTY = @nQTY_RPL / @nPUOM_Div -- Calc QTY in preferred UOM    
                     SET @nMQTY = @nQTY_RPL % @nPUOM_Div -- Calc the remaining in master unit    
    
                     SET @nPQTY_RPL = @nQTY_RPL / @nPUOM_Div -- Calc QTY in preferred UOM    
                     SET @nMQTY_RPL = @nQTY_RPL % @nPUOM_Div -- Calc the remaining in master unit    
                  END    
    
                  -- Disable QTY field    
                  SET @cFieldAttr14 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- PQTY    
                  SET @cFieldAttr15 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- MQTY    
   
                  -- Prepare next screen variable    
                SET @cOutField01 = @cToLoc    
                  SET @cOutField02 = @cSuggSKU    
                  SET @cOutField03 = SUBSTRING( @cSKUDesc, 1, 20)    
                  SET @cOutField04 = SUBSTRING( @cSKUDesc, 21, 20)    
                  SET @cOutField05 = @cLottable01    
                  SET @cOutField06 = @cLottable02    
                  SET @cOutField07 = @cLottable03    
                  SET @cOutField08 = rdt.rdtFormatDate( @dLottable04)    
                  SET @cOutField09 = @cCaseID    
                  SET @cOutField10 = ''    
                  SET @cOutField11 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc    
                  SET @cOutField12 = CASE WHEN @cFieldAttr14 = 'O' AND @cPUOM = '6' THEN '' ELSE rdt.rdtRightAlign( CAST( @nPQTY_RPL AS NVARCHAR( 5)), 5) END    
                  SET @cOutField13 = rdt.rdtRightAlign( CAST( @nMQTY_RPL AS NVARCHAR( 5)), 5)   
                  SET @cOutField14 = CASE WHEN @cFieldAttr14 = 'O' AND @cPUOM = '6' THEN '' ELSE rdt.rdtRightAlign( CAST( @nPQTY_RPL AS NVARCHAR( 5)), 5) END    
                  SET @cOutField15 = rdt.rdtRightAlign( CAST( @nMQTY AS NVARCHAR( 5)), 5) -- MQTY    
                  EXEC rdt.rdtSetFocusField @nMobile, 10 -- SKU    
    
    
            --      SET @nScn = @nScn + 1    
            --      SET @nStep = @nStep + 1    
    
    
                  -- Go to SKU screen    
                  SET @nScn = @nScnSKU    
                  SET @nStep = @nStepSKU    
            END    
         END    
         ELSE    
         BEGIN    
            GOTO QUIT    
         END    
      END    
      ELSE
      BEGIN
         SET @cOutField09 = @cTTMTasktype      
         SET @cOutField10 = @cFromLoc 
         SET @cOutField11 = ''   
         SET @cOutField12 = ''   
         SET @nInputKey = 3 -- NOT to auto ENTER when it goes to first screen of next task    
         SET @nFunc = @nToFunc    
         SET @nScn = @nToScn    
         SET @nStep = @nToStep 
      END
   END    
    
   IF @nInputKey = 0    --ESC    
   BEGIN    
     -- (ChewKP02)    
     IF @cExtendedUpdateSP <> ''    
     BEGIN    
        IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
        BEGIN    
           SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
              ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cLabelNo, @nStep, @cTaskDetailKey, @nQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
           SET @cSQLParam =    
              '@nMobile        INT, ' +    
              '@nFunc          INT, ' +    
              '@cLangCode      NVARCHAR( 3),  ' +    
              '@cUserName      NVARCHAR( 18), ' +    
              '@cFacility      NVARCHAR( 5),  ' +    
              '@cStorerKey     NVARCHAR( 15), ' +    
              '@cLabelNo       NVARCHAR( 20), ' +    
              '@nStep          INT,           ' +    
              '@cTaskDetailKey NVARCHAR( 20), ' +    
              '@nQty           INT,           ' +    
              '@nErrNo         INT         OUTPUT, ' +    
              '@cErrMsg        NVARCHAR( 20) OUTPUT'    
    
           EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
              @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cLabelNo, @nStep, @cTaskDetailKey, @nQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
           IF @nErrNo <> 0    
              GOTO Step_5_Fail    
        END    
     END    
    
    
     SET @cOutField01 = ''    
    
     -- EventLog - Sign Out Function    
     EXEC RDT.rdt_STD_EventLog    
          @cActionType = '9', -- Sign Out function    
          @cUserID     = @cUserName,    
          @nMobileNo   = @nMobile,    
          @nFunctionID = @nFunc,    
          @cFacility   = @cFacility,    
          @cStorerKey  = @cStorerKey    
    
     -- Go back to Task Manager Main Screen    
     SET @nFunc = 1756    
     SET @nScn = 2100    
     SET @nStep = 1    
   END    
   GOTO Quit    
    
    
   Step_5_Fail:    
   BEGIN    
    
      -- Reset this screen var    
      SET @cOutField01 = ''    
   END    
    
END    
GOTO Quit    
    
/********************************************************************************    
Step 6. screen = 2109    
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
        SET @nErrNo = 78583    
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Reason Req    
        GOTO Step_6_Fail    
      END    
    
--       IF NOT EXISTS( SELECT TOP 1 1    
--                      FROM CodeLKUP WITH (NOLOCK)    
--                      WHERE ListName = 'RDTTASKRSN'    
--                      AND StorerKey = @cStorerKey    
--                      AND Code = @cTTMTaskType    
--                      AND @cReasonCode IN (UDF01, UDF02, UDF03, UDF04, UDF05))    
--      BEGIN    
--        SET @nErrNo = 78584    
--        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Reason    
--        GOTO Step_6_Fail    
--      END    
    
      -- Update ReasonCode    
      EXEC dbo.nspRFRSN01    
              @c_sendDelimiter = NULL    
           , @c_ptcid         = 'RDT'    
           ,  @c_userid        = @cUserName    
           ,  @c_taskId        = 'RDT'    
           ,  @c_databasename  = NULL    
           ,  @c_appflag       = NULL    
           ,  @c_recordType    = NULL    
           ,  @c_server        = NULL    
           ,  @c_ttm           = NULL    
           ,  @c_taskdetailkey = @cTaskdetailkey    
           ,  @c_fromloc       = @cFromLoc    
           ,  @c_fromid        = @cSuggID    
           ,  @c_toloc         = @cToLOC    
           ,  @c_toid          = @cSuggID    
           ,  @n_qty           = @nQTY    
           ,  @c_PackKey       = ''    
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
    
      SET @cContinueProcess = ''    
      SELECT @cContinueProcess = ContinueProcessing,    
             @cReasonStatus = TaskStatus    
      FROM dbo.TASKMANAGERREASON WITH (NOLOCK)    
      WHERE TaskManagerReasonKey = @cReasonCode    
    
      IF ISNULL(@cContinueProcess, '') = '1' AND @nQTY > 0    
      BEGIN    
         IF @cExtendedUpdateSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
            BEGIN    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cLabelNo, @nStep, @cTaskDetailKey, @nQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
               SET @cSQLParam =    
                  '@nMobile        INT, ' +    
                  '@nFunc          INT, ' +    
                  '@cLangCode      NVARCHAR( 3),  ' +    
                  '@cUserName      NVARCHAR( 18), ' +    
                  '@cFacility      NVARCHAR( 5),  ' +    
                  '@cStorerKey     NVARCHAR( 15), ' +    
                  '@cLabelNo       NVARCHAR( 20), ' +    
                  '@nStep          INT,           ' +    
                  '@cTaskDetailKey NVARCHAR( 20), ' +    
                  '@nQty           INT,           ' +    
                  '@nErrNo         INT           OUTPUT, ' +    
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cLabelNo, @nStep, @cTaskDetailKey, @nQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
               IF @nErrNo <> 0    
                  GOTO Step_6_Fail    
            END    
         END    
    
         -- Goto ToLoc Screen    
--         SET @cOutField01 = @cFromLoc    
--         SET @cOutField02 = @cID    
--         SET @cOutField04 = ''    
--         SET @cOutField05 = ''    
--         SET @cOutField06 = ''    
--    
--         SET @cOutField03 = @cSuggToLoc    
--    
--         SET @nScn = @nScnToLoc    
--         SET @nStep = @nStepToLoc    
    
         SET @nScn = @nScnSuccessMsg    
         SET @nStep = @nStepSuccessMsg    
    
         GOTO QUIT    
    
      END  --ISNULL(@cContinueProcess, '') = '1' AND @nActQTY > 0    
      ELSE --    
      BEGIN    
         UPDATE dbo.TaskDetail WITH (ROWLOCK)    
            SET Status = @cReasonStatus    
               ,EditDate = GETDATE()    
               ,EditWho  = SUSER_SNAME()    
               ,TrafficCOP = NULL    
         WHERE Taskdetailkey = @cTaskdetailkey    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 78574    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail    
            GOTO Step_6_Fail    
         END    
      END    
    
      UPDATE dbo.TaskManagerUser WITH (ROWLOCK) SET    
         LastLoc = @cToLOC    
      WHERE UserKey = @cUserName    
    
      -- EventLog - QTY    
      EXEC RDT.rdt_STD_EventLog    
         @cActionType   = '4', -- Move    
         @cUserID       = @cUserName,    
         @nMobileNo     = @nMobile,    
         @nFunctionID   = @nFunc,    
         @cFacility     = @cFacility,    
         @cStorerKey    = @cStorerKey,    
         @cLocation     = @cSuggFromLoc,    
         @cToLocation   = @cToLOC,    
         @cID           = @cID,    
         @cToID         = @cID,    
         @cSKU          = '',    
         @cUOM          = @cUOM,    
         @nQTY          = @nQTY,    
         @cLot          = '',    
         @cRefNo1       = @cTaskdetailkey    
    
       SET @nScn = @nScnSuccessMsg    
       SET @nStep = @nStepSuccessMsg    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      IF @nFromStep = 4    
      BEGIN    
         -- Disable QTY field    
         SET @cFieldAttr14 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- PQTY    
         SET @cFieldAttr15 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- MQTY    
  
         SET @cOutField01 = @cToLoc    
         SET @cOutField02 = @cSuggSKU    
         SET @cOutField03 = SUBSTRING( @cSKUDesc, 1, 20)    
         SET @cOutField04 = SUBSTRING( @cSKUDesc, 21, 20)    
         SET @cOutField05 = @cLottable01    
         SET @cOutField06 = @cLottable02    
         SET @cOutField07 = @cLottable03    
         SET @cOutField08 = rdt.rdtFormatDate( @dLottable04)    
         SET @cOutField09 = @cCaseID    
         SET @cOutField10 = ''    
         SET @cOutField11 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc    
         SET @cOutField12 = CASE WHEN @cFieldAttr14 = 'O' AND @cPUOM = '6' THEN '' ELSE rdt.rdtRightAlign( CAST( @nPQTY_RPL AS NVARCHAR( 5)), 5) END    
         SET @cOutField13 = rdt.rdtRightAlign( CAST( @nMQTY_RPL AS NVARCHAR( 5)), 5)   
         SET @cOutField14 = CASE WHEN @cFieldAttr14 = 'O' AND @cPUOM = '6' THEN '' ELSE rdt.rdtRightAlign( CAST( @nPQTY_RPL AS NVARCHAR( 5)), 5) END    
         SET @cOutField15 = rdt.rdtRightAlign( CAST( @nMQTY AS NVARCHAR( 5)), 5) -- MQTY    
         EXEC rdt.rdtSetFocusField @nMobile, 10 -- SKU    
    
         SET @nScn  = @nScnSKU    
         SET @nStep = @nStepSKU    
      END    
      ELSE IF @nFromStep = 1    
      BEGIN    
         SET @cOutField01 = ''    
         SET @cOutField02 = ''    
         SET @cOutField03 = ''    
         SET @cOutField04 = ''    
    
         SET @nScn  =  @nScnFromLoc    
         SET @nStep =  @nStepFromLoc    
      END    
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
      V_QTY         = @nQTY,    
      V_TaskDetailKey = @cTaskdetailkey,    
      V_Lot         = @cLot,    
      V_UCC         = @cLabelNo,    
    
      V_Lottable01  = @cLottable01,    
      V_Lottable02  = @cLottable02,    
      V_Lottable03  = @cLottable03,    
      V_Lottable04  = @dLottable04,    
    
      V_String1     = @cToLoc,    
      V_String2     = @cReasonCode,    
      V_String3     = @cDecodeLabelNo,    
                        
      V_String4     = @cSuggFromloc,    
      V_String5     = @cSuggToloc,    
      V_String6     = @cSuggID,    
      V_String7     = @cLOCLookupSP,    
      V_String8     = @cUserPosition,    
      V_String9     = @cExtendedValidateSP,    
      V_String10    = @cExtendedUpdateSP,    
      V_String11    = @cCaseID,    
      V_String12    = @cSuggSKU,    
      V_String13    = @cContinueTask,
                              
      V_Integer1    = @nSuggQTY,  
      V_Integer2    = @nPQTY_RPL,  
      V_Integer3    = @nMQTY_RPL,  
      V_Integer4    = @nQTY_RPL,  
      V_Integer5    = @nPQTY,  
      V_Integer6    = @nMQTY,  
      V_Integer7    = @nSuggQTY,  
      V_Integer8    = @nPQTY_RPL,  
      V_FromStep    = @nFromstep,  
    
      V_String20    = @cGetNextTaskSP,    
      V_String21    = @cExtendedInfoSP,    
      V_String22    = @cDisableQTYField,    
      V_String23    = @cDisableQTYFieldSP,    
      V_String24    = @cSwapTask,    
      V_String25    = @cOverrideLOC,    
      V_String26    = @cDefaultFromLOC,    
      V_String27    = @cDecodeIDSP,                       
      V_String28    = @cDecodeSKUSP,          
      V_String29    = @cSuggestedLocSP,                 
                        
      V_String32    = @cAreakey,    
      V_String33    = @cTTMStrategykey,    
      V_String34    = @cTTMTasktype,    
      V_String35    = @cRefKey01,    
      V_String36    = @cRefKey02,    
      V_String37    = @cRefKey03,    
      V_String38    = @cRefKey04,    
      V_String39    = @cRefKey05,    
    
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

   -- Execute TM module initialization (ung01)    
   IF (@nFunc <> 1756 AND @nStep = 0) AND     
      (@nFunc <> @nMenu) -- ESC from AREA screen to menu    
   BEGIN    
      -- Get the stor proc to execute    
      DECLARE @cStoredProcName NVARCHAR( 1024)    
      SELECT @cStoredProcName = StoredProcName    
      FROM RDT.RDTMsg WITH (NOLOCK)    
      WHERE Message_ID = @nFunc    
    
      -- Execute the stor proc    
      SELECT @cStoredProcName = N'EXEC RDT.' + RTRIM(@cStoredProcName)    
      SELECT @cStoredProcName = RTRIM(@cStoredProcName) + ' @InMobile, @nErrNo OUTPUT,  @cErrMsg OUTPUT'    
      EXEC sp_executesql @cStoredProcName , N'@InMobile int, @nErrNo int OUTPUT,  @cErrMsg NVARCHAR(125) OUTPUT',    
         @nMobile,    
         @nErrNo OUTPUT,    
         @cErrMsg OUTPUT    
               
   END    
END    

GO