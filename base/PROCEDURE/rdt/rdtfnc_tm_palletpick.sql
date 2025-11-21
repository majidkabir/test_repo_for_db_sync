SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/******************************************************************************/    
/* Store procedure: rdtfnc_TM_PalletPick                                      */    
/* Copyright      : LFLogistics                                               */    
/*                                                                            */    
/* Modifications log:                                                         */    
/* Date       Rev  Author     Purposes                                        */    
/* 2014-07-02 1.0  Ung        SOS311415 Created                               */    
/* 2014-10-08 1.1  Ung        SOS322481 Add DefaultFromLOC                    */    
/* 2015-02-06 1.2  Ung        SOS327467 Add ExtendedInfo for step 0           */    
/* 2016-09-30 1.3  Ung        Performance tuning                              */    
/* 2018-02-05 1.4  Ung        WMS-3007 Add FPK1                               */    
/* 2019-03-05 1.5  YeeKung    WMS-8212 Add loc prefix (yeekung01)             */    
/* 2019-03-11 1.6  Ung        WMS-8244 Fix ExtendedInfo                       */    
/*                            Performance tuning                              */    
/* 2020-03-24 1.7  YeeKung    WMS-12510 Fix RDTiSvalidate (yeekung02)         */ 
/* 2021-02-11 1.8  LZG        INC1427876 - Reset @cSKUDesc variable (ZG01)    */   
/* 2021-03-08 1.9  Chermaine  WMS-16385 - Add storerConfig to lookup SKU(cc01)*/
/* 2024-04-10 2.0  Deenis     UWP-16910 - Check Digit                         */
/* 2024-05-27 2.1  NLT03      FCR-229 - Increase the max length of            */
/*                            qty text box to 7 digit                         */
/* 2024-05-30 2.2 NLT03       UWP-20091 Exception happens while shor pick     */
/* 2024-07-08 2.3 JHU151      FCR-330 SSCC code generator                     */
/* 2024-10-12 2.4 Dennis      FCR-775 For VLT (DE01)                          */
/******************************************************************************/    
    
CREATE PROC [RDT].[rdtfnc_TM_PalletPick](    
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
   @b_success           INT,    
   @cFromLOC            NVARCHAR(10),    
   @cToLOC              NVARCHAR(10),    
   @cFromID             NVARCHAR(18),    
   @c_outstring         NVARCHAR(255),    
   @cNextTaskDetailKey  NVARCHAR(10),    
   @cReasonCode         NVARCHAR(10),    
   @cUCC                NVARCHAR(20),    
   @cSKU                NVARCHAR(20),    
   @cPQTY               NVARCHAR(7),    
   @cMQTY               NVARCHAR(7),    
   @cSQL                NVARCHAR(1000),    
   @cSQLParam           NVARCHAR(1000),    
   @cExtendedScreenSP   NVARCHAR( 20),
   @cExtScnSP           NVARCHAR( 20),
   @nAction             INT,
   @nAfterScn           INT,
   @nAfterStep          INT,
   @cLocNeedCheck       NVARCHAR( 20),
   @cDefaultFromLOC     NVARCHAR(1)    
    
-- Define variable on mobrec    
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
    
   @cSuggSKU            NVARCHAR(20),    
   @cSKUDesc            NVARCHAR(60),    
   @cSuggLOT            NVARCHAR(10),    
   @cSuggFromLOC        NVARCHAR(10),    
   @cSuggID             NVARCHAR(18),    
   @cPUOM               NVARCHAR( 1), -- Prefer UOM    
   @cLottable01         NVARCHAR(18),    
   @cLottable02         NVARCHAR(18),    
   @cLottable03         NVARCHAR(18),    
   @dLottable04         DATETIME,
   @dLottable05         DATETIME,
   @cLottable06         NVARCHAR( 30),
   @cLottable07         NVARCHAR( 30), 
   @cLottable08         NVARCHAR( 30),
   @cLottable09         NVARCHAR( 30), 
   @cLottable10         NVARCHAR( 30), 
   @cLottable11         NVARCHAR( 30),
   @cLottable12         NVARCHAR( 30),
   @dLottable13         DATETIME, 
   @dLottable14         DATETIME,
   @dLottable15         DATETIME,    
    
   @cTaskDetailKey      NVARCHAR(10),    
   @cTaskStorer         NVARCHAR(15),    
   @cDropID             NVARCHAR(20),    
   @cSuggToLOC          NVARCHAR(10),    
   @cListKey            NVARCHAR(10),    
   @cEnableField        NVARCHAR(20),    
   @cCustomLottableSP   NVARCHAR(20),    
   @cPUOM_Desc          NCHAR( 5),    
   @cMUOM_Desc          NCHAR( 5),    
   @nPUOM_Div           INT, -- UOM divider    
   @nPQTY_PK            INT,    
   @nMQTY_PK            INT,    
   @nQTY_PK             INT,    
   @nPQTY               INT,    
   @nMQTY               INT,    
   @nQTY                INT,    
   @nFromStep           INT,    
   @nFromScn            INT,
   @cDecodeLabelNo      NVARCHAR( 20),    
   @cExtendedUpdateSP   NVARCHAR( 20),    
   @cDefaultToLOC       NVARCHAR( 10),    
   @cDefaultQTY         NVARCHAR( 1),    
   @nSKUValidated       NVARCHAR( 1),    
   @cDefaultFromID      NVARCHAR( 1),    
   @cExtendedInfoSP     NVARCHAR(20),    
   @cExtendedInfo1      NVARCHAR(20),    
   @cSwapTaskSP         NVARCHAR(20),    
   @cDefaultDropID      NVARCHAR(20),    
   @cExtendedValidateSP NVARCHAR(20),    
   @cOverwriteToLOC     NVARCHAR(1),    
    
   @cAreaKey            NVARCHAR(10),    
   @cTTMStrategykey     NVARCHAR(10),    
   @cTTMTaskType        NVARCHAR(10),    
   @cRefKey01           NVARCHAR(20),    
   @cRefKey02           NVARCHAR(20),    
   @cRefKey03           NVARCHAR(20),    
   @cRefKey04           NVARCHAR(20),    
   @cRefKey05           NVARCHAR(20),    
   @cLOCLookupSP        NVARCHAR(20),  --(yeekung01)    
   @cSkuInfoFromLLI     NVARCHAR(1),  --(cc01)    
   @tExtScnData			VariableTable, --(JHU151)
   @cHUSQGRPPICK        NVARCHAR(1), --(DE01)

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
   @cFieldAttr15 NVARCHAR( 1),    
    
   @cUDF01  NVARCHAR( 250), @cUDF02 NVARCHAR( 250), @cUDF03 NVARCHAR( 250),
   @cUDF04  NVARCHAR( 250), @cUDF05 NVARCHAR( 250), @cUDF06 NVARCHAR( 250),
   @cUDF07  NVARCHAR( 250), @cUDF08 NVARCHAR( 250), @cUDF09 NVARCHAR( 250),
   @cUDF10  NVARCHAR( 250), @cUDF11 NVARCHAR( 250), @cUDF12 NVARCHAR( 250),
   @cUDF13  NVARCHAR( 250), @cUDF14 NVARCHAR( 250), @cUDF15 NVARCHAR( 250),
   @cUDF16  NVARCHAR( 250), @cUDF17 NVARCHAR( 250), @cUDF18 NVARCHAR( 250),
   @cUDF19  NVARCHAR( 250), @cUDF20 NVARCHAR( 250), @cUDF21 NVARCHAR( 250),
   @cUDF22  NVARCHAR( 250), @cUDF23 NVARCHAR( 250), @cUDF24 NVARCHAR( 250),
   @cUDF25  NVARCHAR( 250), @cUDF26 NVARCHAR( 250), @cUDF27 NVARCHAR( 250),
   @cUDF28  NVARCHAR( 250), @cUDF29 NVARCHAR( 250), @cUDF30 NVARCHAR( 250)
-- Getting Mobile information    
SELECT    
   @nFunc           = Func,    
   @nScn            = Scn,    
   @nStep           = Step,    
   @nInputKey       = InputKey,    
   @cLangCode       = Lang_code,    
   @nMenu           = Menu,    
    
   @cPrinter        = Printer,    
   @cUserName       = UserName,    
   @cFacility       = Facility,    
   @cStorerKey      = StorerKey,    
    
   @nFromScn        = V_FromScn,     
   @nFromStep       = V_FromStep,     
   @cTaskDetailKey  = V_TaskDetailKey,    
   @cSuggSKU        = V_SKU,    
   @cSKUDesc        = V_SKUDescr,    
   @cSuggLOT        = V_LOT,    
   @cSuggFromLOC    = V_LOC,    
   @cSuggID         = V_ID,    
   @cPUOM           = V_UOM,    
   @cLottable01     = V_Lottable01,    
   @cLottable02     = V_Lottable02,    
   @cLottable03     = V_Lottable03,    
   @dLottable04     = V_Lottable04,    
   @nPUOM_Div       = V_PUOM_Div,     
   @nPQTY_PK        = V_PTaskQTY,     
   @nMQTY_PK        = V_MTaskQTY,     
   @nQTY_PK         = V_TaskQTY,     
   @nPQTY           = V_PQTY,     
   @nMQTY           = V_MQTY,     
   @nQTY            = V_QTY,     
    
   @cAreaKey           = V_String1,    
   @cTaskStorer        = V_String2,    
   @cDropID            = V_String3,    
   @cSuggToloc         = V_String5,    
   @cReasonCode        = V_String6,    
   @cListKey           = V_String7,    
   @cEnableField       = V_String8,    
   @cCustomLottableSP  = V_String9,    
   @cMUOM_Desc         = V_String10,    
   @cPUOM_Desc         = V_String11,    
    
   @cDecodeLabelNo     = V_String21,    
   @cExtendedUpdateSP  = V_String22,    
   @cDefaultToLOC      = V_String23,    
   @cDefaultQTY        = V_String24,    
   @nSKUValidated      = V_String25,    
   @cDefaultFromID     = V_String26,    
   @cExtendedInfoSP    = V_String27,    
   @cExtendedInfo1     = V_String28,    
   @cSwapTaskSP        = V_String29,    
   @cDefaultDropID     = V_String30,    
   @cExtendedValidateSP= V_String31,    
   @cOverwriteToLOC    = V_String40,    
    
   @cAreakey           = V_String32,    
   @cTTMStrategykey    = V_String33,    
   @cTTMTaskType       = V_String34,    
   @cRefKey01          = V_String35,    
   @cRefKey02          = V_String36,    
   @cRefKey03          = V_String37,    
   @cRefKey04          = V_String38,    
   @cRefKey05          = V_String39,    
   @cLOCLookupSP       = V_String41, --(yeekung01)    
   @cSkuInfoFromLLI    = V_String42, --(cc01)
   @cExtScnSP          = V_string43,
   @cHUSQGRPPICK       = V_String44,

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
    
FROM   RDT.RDTMOBREC WITH (NOLOCK)    
WHERE  Mobile = @nMobile    
    
-- Redirect to respective screen    
IF @nFunc = 1770    
BEGIN    
   IF @nStep = 0 GOTO Step_0   -- Initialize    
   IF @nStep = 1 GOTO Step_1   -- Scn = 3700 FromLOC    
   IF @nStep = 2 GOTO Step_2   -- Scn = 3701 FromID    
   IF @nStep = 3 GOTO Step_3   -- Scn = 3702 SKU, QTY    
   IF @nStep = 4 GOTO Step_4   -- Scn = 3703 To LOC    
   IF @nStep = 5 GOTO Step_5   -- Scn = 3704 Next task / Exit TM    
   IF @nStep = 6 GOTO Step_6   -- Scn = 3705 Reason code    
END    
    
RETURN -- Do nothing if incorrect step    
    
    
/********************************************************************************    
Step 0. Initialize    
********************************************************************************/    
Step_0:    
BEGIN    
   -- Get task manager data    
   SET @cTaskDetailKey  = @cOutField06    
   SET @cAreaKey        = @cOutField07    
   SET @cTTMStrategyKey = @cOutField08    
    
   -- Get task info    
   SELECT    
      @cTTMTaskType = TaskType,    
      @cStorerKey   = Storerkey,    
      @cSuggID      = FromID,    
      @cSuggLOT     = LOT,    
      @cSuggFromLOC = FromLOC,    
      @cSuggToLOC   = ToLOC,    
      @cSuggSKU     = SKU,    
      @nQTY_PK      = QTY,    
      @cDropID      = DropID,    
      @cListKey     = ListKey    
   FROM dbo.TaskDetail WITH (NOLOCK)    
   WHERE TaskDetailKey = @cTaskDetailKey    
    
   -- Initial var    
   SET @cReasonCode = ''    
   SET @cExtendedInfo1 = ''    
    
   -- Get preferred UOM    
   SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName    
    
   -- Get storer configure    
   SET @cDefaultFromID = rdt.rdtGetConfig( @nFunc, 'DefaultFromID', @cStorerKey)    
   SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)    
   SET @cOverwriteToLOC = rdt.rdtGetConfig( @nFunc, 'OverwriteToLOC', @cStorerKey)    
   SET @cDefaultFromLOC = rdt.rdtGetConfig( @nFunc, 'DefaultFromLOC', @cStorerKey)    
   SET @cDefaultToLOC = rdt.rdtGetConfig( @nFunc, 'DefaultToLOC', @cStorerKey)    
   SET @cDefaultDropID = rdt.RDTGetConfig( @nFunc, 'DefaultDropID', @cStorerKey)    
   SET @cEnableField = rdt.RDTGetConfig( @nFunc, 'EnableField', @cStorerKey)    
   SET @cLOCLookupSP = rdt.rdtGetConfig(@nFunc,'LOCLookupSP',@cStorerKey)     --(yeekung01)    
   SET @cSkuInfoFromLLI = rdt.rdtGetConfig(@nFunc,'SkuInfoFromLLI',@cStorerKey) --(cc01) 
   SET @cHUSQGRPPICK = rdt.rdtGetConfig(@nFunc,'HUSQGRPPICK',@cStorerKey) --(DE01) 
   IF @cHUSQGRPPICK = '1'
      SET @cOverwriteToLOC = '1'
   SET @cCustomLottableSP = rdt.RDTGetConfig( @nFunc, 'CustomLottableSP', @cStorerKey)    
   IF @cCustomLottableSP = '0'    
      SET @cCustomLottableSP = ''    
   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)    
   IF @cDecodeLabelNo = '0'    
      SET @cDecodeLabelNo = ''    
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)    
   IF @cExtendedInfoSP = '0'    
      SET @cExtendedInfoSP = ''    
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)    
   IF @cExtendedValidateSP = '0'    
      SET @cExtendedValidateSP = ''    
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)    
   IF @cExtendedUpdateSP = '0'    
      SET @cExtendedUpdateSP = ''    
   SET @cSwapTaskSP = rdt.RDTGetConfig( @nFunc, 'SwapTaskSP', @cStorerKey)    
   IF @cSwapTaskSP = '0'    
      SET @cSwapTaskSP = ''    
   
   SET @cExtScnSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtScnSP = '0'
      SET @cExtScnSP = ''

   --lookup SKU from loxlotxid   --(cc01)
   IF @cSkuInfoFromLLI = '1'
   BEGIN
   	IF @cSuggSKU = ''
   	BEGIN
   		SELECT TOP 1 @cSuggSKU = SKU FROM LOTxLOCxID WITH (NOLOCK) WHERE storerKey = @cStorerKey AND ID = @cSuggID AND QTY > 0
   	END
   END 
   -- Extended update    
   IF @cExtendedUpdateSP <> ''    
   BEGIN    
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @nQTY, @cToLOC, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
         SET @cSQLParam =    
            '@nMobile         INT,           ' +    
            '@nFunc           INT,           ' +    
            '@cLangCode       NVARCHAR( 3),  ' +    
            '@nStep           INT,           ' +    
            '@nInputKey       INT,           ' +    
            '@cTaskdetailKey  NVARCHAR( 10), ' +    
            '@nQTY            INT,           ' +    
            '@cToLOC          NVARCHAR( 10), ' +    
            '@cDropID         NVARCHAR( 20), ' +    
            '@nErrNo          INT OUTPUT,    ' +    
            '@cErrMsg         NVARCHAR( 20) OUTPUT '    
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @nQTY, @cToLOC, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
         IF @nErrNo <> 0    
            GOTO Quit    
      END    
   END    
    
   -- Sign-in    
   EXEC RDT.rdt_STD_EventLog    
      @cActionType     = '1', -- Sign in function    
      @cUserID         = @cUserName,    
      @nMobileNo       = @nMobile,    
      @nFunctionID     = @nFunc,    
      @cFacility       = @cFacility,    
      @cStorerKey      = @cStorerKey,    
      @cLocation       = @cSuggFromLoc,    
      @cToLocation    =  @cSuggToLoc,    
      @cID             = @cSuggID,    
      @cRefNo2         = @cAreaKey,    
      @cRefNo3         = @cTTMStrategyKey,    
      @cRefNo4         = '',    
      @cRefNo5         = '',    
      @cTaskdetailKey  = @cTaskdetailKey    
    
   -- Enable all fields    
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
    
   -- Set the entry point    
   SET @nScn  = 3700    
   SET @nStep = 1    
    
   -- Prepare next screen var    
   SET @cOutField01 = @cSuggFromLOC    
   SET @cOutField02 = CASE WHEN @cDefaultFromLOC = '1' THEN @cSuggFromLOC ELSE '' END -- FromLOC    
   SET @cOutField10 = '' -- ExtendedInfo    
    
   -- Extended info    
   IF @cExtendedInfoSP <> ''    
   BEGIN    
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
      BEGIN    
         SET @cExtendedInfo1 = ''    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'    
         SET @cSQLParam =    
            '@nMobile         INT,           ' +    
            '@nFunc           INT,           ' +    
            '@cLangCode       NVARCHAR( 3),  ' +    
            '@nStep           INT,           ' +    
            '@nInputKey       INT,           ' +    
            '@cTaskdetailKey  NVARCHAR( 10), ' +    
            '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +    
            '@nErrNo          INT           OUTPUT, ' +    
            '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +    
            '@nAfterStep      INT '    
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
            @nMobile, @nFunc, @cLangCode, 0, @nInputKey, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep    
    
         SET @cOutField10 = @cExtendedInfo1    
      END    
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 1. Screen = 3700. From LOC screen    
    SUGG LOC (Field01)    
    FROM LOC (Field02, input)    
    EXTINFO  (Field10)    
********************************************************************************/    
Step_1:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cFromLOC = @cInField02    
      SET @cLocNeedCheck = @cInField02 
      -- Check blank FromLOC    
      IF @cFromLOC = ''    
      BEGIN    
         SET @nErrNo = 90751    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FromLOC needed    
         GOTO Step_1_Fail    
      END   

      SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '1770ExtendedScreenSP', @cStorerKey), '')
      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_1770ExtScnEntry] 
               @cExtendedScreenSP,
               @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @cLocNeedCheck OUTPUT,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT, 
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT, 
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
               @nAction, 
               @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
               @nErrNo   OUTPUT, 
               @cErrMsg  OUTPUT
            
            IF @nErrNo <> 0
               GOTO Step_1_Fail
            
            SET @cFromLOC = @cLocNeedCheck
         END
      END

      -- add loc prefix (yeekung01)    
      IF @cLOCLookupSP = '1'    
      BEGIN    
         EXEC rdt.rdt_LOCLookup @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,    
            @cFromLOC   OUTPUT,    
            @nErrNo     OUTPUT,    
            @cErrMsg    OUTPUT    
         IF @nErrNo <> 0    
            GOTO Step_1_Fail    
      END    
    
      -- Check if FromLOC match    
      IF @cFromLOC <> @cSuggFromLOC    
      BEGIN    
         SET @nErrNo = 90752    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FromLOC Diff    
        GOTO Step_1_Fail    
      END    

      SET @cSKUDesc = ''   -- ZG01
    
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
      SET @cLottable01 = ''    
      SET @cLottable02 = ''    
      SET @cLottable03 = ''    
      SET @dLottable04 = 0    
      SELECT    
         @cLottable01 = LA.Lottable01,    
         @cLottable02 = LA.Lottable02,    
         @cLottable03 = LA.Lottable03,    
         @dLottable04 = LA.Lottable04    
      FROM dbo.LOTAttribute LA WITH (NOLOCK)    
      WHERE LOT = @cSuggLOT -- Might be blank    
    
      -- Custom lottable    
      IF @cCustomLottableSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCustomLottableSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCustomLottableSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, ' +    
               ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,           ' +    
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@cLottable01     NVARCHAR( 18) OUTPUT, ' +    
               '@cLottable02     NVARCHAR( 18) OUTPUT, ' +    
               '@cLottable03     NVARCHAR( 18) OUTPUT, ' +    
               '@dLottable04     DATETIME      OUTPUT, ' +    
               '@nErrNo        INT           OUTPUT, ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey,    
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    
         END    
      END    
    
      -- Convert to prefer UOM QTY    
      SET @nPQTY = 0    
      SET @nMQTY = 0    
      IF @cPUOM = '6' OR -- When preferred UOM = master unit    
         @nPUOM_Div = 0  -- UOM not setup    
      BEGIN    
         SET @cPUOM_Desc = ''    
         SET @nPQTY_PK = 0    
         SET @nMQTY_PK = @nQTY_PK    
      END    
      ELSE    
      BEGIN    
         SET @nPQTY_PK = @nQTY_PK / @nPUOM_Div -- Calc QTY in preferred UOM    
         SET @nMQTY_PK = @nQTY_PK % @nPUOM_Div -- Calc the remaining in master unit    
      END    
    
      -- Extended update    
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @nQTY, @cToLOC, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,           ' +    
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@nQTY            INT,           ' +    
               '@cToLOC          NVARCHAR( 10), ' +    
               '@cDropID         NVARCHAR( 20), ' +    
               '@nErrNo          INT OUTPUT,    ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @nQTY, @cToLOC, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    
         END    
      END    
    
      -- Prepare Next Screen    
      SET @cOutField01 = @cSuggID    
      SET @cOutField02 = CASE WHEN @cDefaultFromID = '1' THEN @cSuggID ELSE '' END -- FromID    
      SET @cOutField03 = @cSuggSKU    
      SET @cOutField04 = SUBSTRING( @cSKUDesc, 1, 20)    
      SET @cOutField05 = SUBSTRING( @cSKUDesc, 21, 20)    
      SET @cOutField06 = @cLottable01    
      SET @cOutField07 = @cLottable02    
      SET @cOutField08 = @cLottable03    
      SET @cOutField09 = rdt.rdtFormatDate( @dLottable04)    
      SET @cOutField10 = '1:' + CAST( @nPUOM_Div AS NCHAR( 7)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc    
      SET @cOutField11 = CASE WHEN @cPUOM_Desc = '' THEN '' ELSE CAST( @nPQTY_PK AS NVARCHAR( 7)) END    
      SET @cOutField12 = CAST( @nMQTY_PK AS NVARCHAR( 7))
    
      SET @nScn = @nScn + 1    
      SET @nStep = @nStep + 1    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Go to Reason Code Screen    
      SET @cOutField01 = ''    
      SET @cOutField02 = ''    
      SET @cOutField03 = ''    
      SET @cOutfield04 = ''    
      SET @cOutField05 = ''    
      SET @cOutField09 = ''    
    
      SET @nFromScn = @nScn    
      SET @nFromStep = @nStep    
      SET @nScn  = 2109    
      SET @nStep = @nStep + 5 -- Step 6    
   END    
   GOTO Quit    
    
   Step_1_Fail:    
   BEGIN    
      SET @cFromLOC = ''    
      SET @cOutfield02 = '' -- FromLOC    
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 2. Screen = 3701. FromID screen    
    SUGG ID    (Field01)    
    FROM ID    (Field02, input)    
    SKU        (Field03)    
    SKUDESCR   (Field04)    
    SKUDESCR   (Field05)    
    Lottable01 (Field06)    
    Lottable02 (Field07)    
    Lottable03 (Field08)    
    Lottable04 (Field09)    
    UOM ratio  (Field10)    
    PUOM       (Field10)    
 MUOM       (Field10)    
    PQTY_PK    (Field11)    
    MQTY_PK    (Field12)    
********************************************************************************/    
Step_2:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cFromID  = @cInField02    
    
      -- Check FromID match    
      IF @cFromID <> @cSuggID    
      BEGIN    
         IF @cSwapTaskSP = ''    
         BEGIN    
            SET @nErrNo = 90753    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID not match    
            GOTO Step_2_Fail    
         END    
    
         -- Swap ID    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSwapTaskSP AND type = 'P')    
         BEGIN    
            DECLARE @cNewTaskDetailKey NVARCHAR( 10)    
            SET @cNewTaskDetailKey = ''    
    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSwapTaskSP) +    
               ' @nMobile, @nFunc, @cLangCode, @cTaskdetailKey, @cFromID, @cNewTaskDetailKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile            INT,           ' +    
               '@nFunc              INT,           ' +    
               '@cLangCode          NVARCHAR( 3),  ' +    
               '@cTaskdetailKey     NVARCHAR( 10), ' +    
               '@cFromID            NVARCHAR( 18), ' +    
               '@cNewTaskDetailKey  NVARCHAR( 10)  OUTPUT, ' +    
               '@nErrNo             INT            OUTPUT, ' +    
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @cTaskdetailKey, @cFromID, @cNewTaskDetailKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    
    
            -- New task    
            IF @cNewTaskDetailKey <> ''    
               SET @cTaskDetailKey = @cNewTaskDetailKey    
    
            -- Reload task    
            SELECT    
               @cTTMTaskType = TaskType,    
               @cStorerKey   = Storerkey,    
               @cSuggID      = FromID,    
               @cSuggLOT     = LOT,    
               @cSuggFromLOC = FromLOC,    
               @cSuggToLOC   = ToLOC,    
               @cSuggSKU     = SKU,    
               @nQTY_PK      = QTY,    
               @cDropID      = DropID,    
               @cListKey     = ListKey    
            FROM dbo.TaskDetail WITH (NOLOCK)    
            WHERE TaskDetailKey = @cTaskDetailKey    
    
            -- Get lottable    
            SET @cLottable01 = ''    
            SET @cLottable02 = ''    
            SET @cLottable03 = ''    
            SET @dLottable04 = 0    
            SELECT    
               @cLottable01 = LA.Lottable01,    
               @cLottable02 = LA.Lottable02,    
               @cLottable03 = LA.Lottable03,    
               @dLottable04 = LA.Lottable04    
            FROM dbo.LOTAttribute LA WITH (NOLOCK)    
            WHERE LOT = @cSuggLOT -- Might be blank    
    
            -- Custom lottable    
            IF @cCustomLottableSP <> ''    
            BEGIN    
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCustomLottableSP AND type = 'P')    
               BEGIN    
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cCustomLottableSP) +    
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, ' +    
                     ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
                  SET @cSQLParam =    
                     '@nMobile         INT,           ' +    
                     '@nFunc           INT,           ' +    
                     '@cLangCode       NVARCHAR( 3),  ' +    
                     '@nStep           INT,           ' +    
                     '@nInputKey       INT,           ' +    
                     '@cTaskdetailKey  NVARCHAR( 10), ' +    
                     '@cLottable01     NVARCHAR( 18) OUTPUT, ' +    
                     '@cLottable02     NVARCHAR( 18) OUTPUT, ' +    
                     '@cLottable03     NVARCHAR( 18) OUTPUT, ' +    
               '@dLottable04     DATETIME      OUTPUT, ' +    
                     '@nErrNo          INT           OUTPUT, ' +    
                     '@cErrMsg         NVARCHAR( 20) OUTPUT  '    
    
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey,    
                     @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
                  IF @nErrNo <> 0    
                     GOTO Quit    
               END    
            END    
    
            -- Convert to prefer UOM QTY    
            SET @nPQTY = 0    
            SET @nMQTY = 0    
            IF @cPUOM = '6' OR -- When preferred UOM = master unit    
               @nPUOM_Div = 0  -- UOM not setup    
            BEGIN    
               SET @cPUOM_Desc = ''    
               SET @nPQTY_PK = 0    
               SET @nMQTY_PK = @nQTY_PK    
            END    
            ELSE    
            BEGIN    
               SET @nPQTY_PK = @nQTY_PK / @nPUOM_Div -- Calc QTY in preferred UOM    
               SET @nMQTY_PK = @nQTY_PK % @nPUOM_Div -- Calc the remaining in master unit    
            END    
         END    
      END    
    
      -- Default DropID    
      IF @cDefaultDropID = '1' AND @cDropID = '' AND @cSuggID <> ''    
         SET @cDropID = @cSuggID    
    
      -- Extended update    
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @nQTY, @cToLOC, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,           ' +    
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@nQTY            INT,           ' +    
               '@cToLOC          NVARCHAR( 10), ' +    
               '@cDropID         NVARCHAR( 20), ' +    
               '@nErrNo          INT OUTPUT,    ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @nQTY, @cToLOC, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    
         END    
      END    
    
      -- Go to SKU QTY screen    
      IF @cTTMTaskType = 'FPK' AND    
         (CHARINDEX( 'S', @cEnableField) <> 0 OR -- SKU    
          CHARINDEX( 'Q', @cEnableField) <> 0)   -- QTY    
      BEGIN    
         -- Restore scanned carton QTY    
         DECLARE @nCartonQTY INT    
         SELECT @nCartonQTY = ISNULL( SUM( QTY), 0)    
         FROM rdt.rdtFPKLog WITH (NOLOCK)    
         WHERE TaskDetailKey = @cTaskDetailKey    
    
         -- Decide whether need to validate SKU    
         IF @nCartonQTY = 0    
            SET @nSKUValidated = 0    
         ELSE    
            SET @nSKUValidated = 1    
    
         -- Disabled SKU field    
         IF CHARINDEX( 'S', @cEnableField) = 0    
         BEGIN    
            SET @cFieldAttr08 = 'O'  -- SKU    
            SET @nSKUValidated = 1    
         END    
    
         -- Convert to prefer UOM QTY    
         IF @cPUOM = '6' OR -- When preferred UOM = master unit    
            @nPUOM_Div = 0  -- UOM not setup    
         BEGIN    
            SET @cPUOM_Desc = ''    
            SET @nPQTY_PK = 0    
            SET @nPQTY = 0    
            SET @nMQTY = @nCartonQTY    
            SET @nMQTY_PK = @nQTY_PK    
            SET @cFieldAttr14 = 'O' -- @nPQTY_PK    
         END    
         ELSE    
         BEGIN    
            SET @nPQTY = 0    
            SET @nMQTY = @nCartonQTY    
    
            SET @nPQTY = @nCartonQTY / @nPUOM_Div -- Calc QTY in preferred UOM    
            SET @nMQTY = @nCartonQTY % @nPUOM_Div -- Calc the remaining in master unit    
    
            SET @nPQTY_PK = @nQTY_PK / @nPUOM_Div -- Calc QTY in preferred UOM    
            SET @nMQTY_PK = @nQTY_PK % @nPUOM_Div -- Calc the remaining in master unit    
         END    
    
         -- Default QTY    
         IF @cDefaultQTY = '1' AND @nPQTY = 0 AND @nMQTY = 0    
         BEGIN    
           SET @nPQTY = @nPQTY_PK    
            SET @nMQTY = @nMQTY_PK    
         END    
    
         -- Disabled QTY field    
         IF CHARINDEX( 'Q', @cEnableField) = 0    
         BEGIN    
            SET @cFieldAttr14 = 'O' -- @nPQTY_PK    
            SET @cFieldAttr15 = 'O' -- @nMQTY_PK    
         END    
    
         -- Prepare next screen variable    
         SET @cOutField01 = @cSuggSKU    
         SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)    
         SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)    
         SET @cOutField04 = @cLottable01    
         SET @cOutField05 = @cLottable02    
         SET @cOutField06 = @cLottable03    
         SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)    
         SET @cOutField08 = '' -- SKU    
         SET @cOutField09 = ''    
         SET @cOutField10 = '' -- ExtendedInfo    
         SET @cOutField11 = '1:' + CAST( @nPUOM_Div AS NCHAR( 7)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc    
         SET @cOutField12 = CASE WHEN @cPUOM_Desc = '' THEN '' ELSE CAST( @nPQTY_PK AS NVARCHAR( 7)) END    
         SET @cOutField13 = CAST( @nMQTY_PK AS NVARCHAR( 7))    
         SET @cOutField14 = CASE WHEN @cPUOM_Desc = '' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 7)) END -- PQTY    
         SET @cOutField15 = CAST( @nMQTY AS NVARCHAR( 7)) -- MQTY    
    
         -- Cursor position    
         IF @cFieldAttr08 = '' EXEC rdt.rdtSetFocusField @nMobile, 8 -- SKU    
         ELSE IF @cFieldAttr14 = '' EXEC rdt.rdtSetFocusField @nMobile, 14 -- PQTY    
         ELSE IF @cFieldAttr15 = '' EXEC rdt.rdtSetFocusField @nMobile, 15 -- MQTY    
    
         SET @nScn = @nScn + 1    
         SET @nStep = @nStep + 1    
      END    
    
      -- Go to ToLOC screen    
      ELSE    
      BEGIN    
         -- Full pick    
         SET @nQTY = @nQTY_PK    
    
         -- Prepare next screen var    
         SET @cOutField01 = @cSuggFromLOC    
         SET @cOutField02 = @cSuggToLOC    
         SET @cOutField03 = '' -- ToLOC    
         SET @cOutField04 = @cDropID    
         SET @cOutField10 = '' -- ExtendedInfo    
    
         -- Disable DropID    
         IF CHARINDEX( 'D', @cEnableField) = 0 OR @cTTMTaskType <> 'FPK'    
            SET @cFieldAttr04 = 'O'    
    
         SET @nScn = @nScn + 2    
         SET @nStep = @nStep + 2    
      END    
    
      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo1 = ''    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,           ' +    
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +    
               '@nErrNo          INT           OUTPUT, ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +    
               '@nAfterStep      INT '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, 3, @nInputKey, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep    
    
            SET @cOutField10 = @cExtendedInfo1    
         END    
      END    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Prepare prev screen var    
      SET @cFromLOC = ''    
      SET @cOutField01 = @cSuggFromLOC    
      SET @cOutField02 = CASE WHEN @cDefaultFromLOC = '1' THEN @cSuggFromLOC ELSE '' END -- FromLOC    
      SET @cOutField10 = '' -- ExtendedInfo    
    
      SET @nScn = @nScn - 1    
      SET @nStep = @nStep - 1    
    
      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo1 = ''    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,           ' +    
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +    
               '@nErrNo          INT           OUTPUT, ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +    
               '@nAfterStep      INT '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, 3, @nInputKey, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep    
    
            SET @cOutField10 = @cExtendedInfo1    
         END    
      END    
   END

   IF @cExtScnSP = '0'
   BEGIN
      SET @cExtScnSP = ''
   END
   IF @cExtScnSP <> ''
   BEGIN
      GOTO Step_99
   END
   
   GOTO Quit    
    
   Step_2_Fail:    
   BEGIN    
      SET @cFromID = ''    
      SET @cOutField02 = '' -- FromID    
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 3. screen = 3702    
    SKU        (Field01)    
    SKUDESCR   (Field02)    
    SKUDESCR   (Field03)    
    Lottable01 (Field04)    
    Lottable02 (Field05)    
    Lottable03 (Field06)    
    Lottable04 (Field07)    
    SKU/UPC    (Field08, input)    
    UOM ratio  (Field11)    
    PUOM       (Field11)    
    MUOM       (Field11)    
    PQTY_PK    (Field12)    
    MQTY_PK    (Field13)    
    PQTY       (Field14, input)    
    MQTY       (Field15, input)    
********************************************************************************/    
Step_3:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      DECLARE @cLabelNo NVARCHAR( 32)    
      DECLARE @nUCCQTY  INT    
    
      SET @nUCCQTY = 0    
    
      -- Screen mapping    
      SET @cLabelNo = CASE WHEN @cFieldAttr08 = 'O' THEN @cOutField08 ELSE @cInField08 END    
      SET @cSKU     = CASE WHEN @cFieldAttr08 = 'O' THEN @cOutField08 ELSE @cInField08 END    
      SET @cPQTY    = CASE WHEN @cFieldAttr14 = 'O' THEN @cOutField14 ELSE @cInField14 END    
      SET @cMQTY    = CASE WHEN @cFieldAttr15 = 'O' THEN @cOutField15 ELSE @cInField15 END    
    
      -- Retain value    
      SET @cOutField14 = CASE WHEN @cFieldAttr14 = 'O' THEN @cOutField14 ELSE @cInField14 END -- PQTY    
      SET @cOutField15 = CASE WHEN @cFieldAttr15 = 'O' THEN @cOutField15 ELSE @cInField15 END -- MQTY    
    
      -- Check SKU blank    
      IF @cLabelNo = '' AND @nSKUValidated = 0 -- False    
      BEGIN    
         SET @nErrNo = 90754    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need SKU    
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- SKU    
         GOTO Step_3_Fail    
      END    
    
      -- Validate SKU    
      IF @cLabelNo <> ''    
      BEGIN    
         -- Mark SKU as validated.    
         -- Note: put at top due to short pick with 0 QTY, had nothing to scan.    
         --       cannot key-in SKU as per display, coz if under piece pick (QTY field disable), it will increase QTY    
         SET @nSKUValidated = 1 --(yeekung02)    
    
         -- Decode label    
         IF @cDecodeLabelNo <> ''    
         BEGIN    
            DECLARE    
               @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),    
               @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),    
               @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),    
               @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),    
               @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)    
    
            SET @c_oFieled09 = @cDropID    
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
               GOTO Step_3_Fail    
    
            SET @cSKU    = ISNULL( @c_oFieled01, '')    
            SET @nUCCQTY = CAST( ISNULL( @c_oFieled05, '') AS INT)    
            SET @cUCC    = ISNULL( @c_oFieled08, '')    
         END    
    
         -- Get SKU barcode count    
         DECLARE @nSKUCnt INT    
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
            SET @nErrNo = 90755    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU    
            SET @nSKUValidated=0    
            EXEC rdt.rdtSetFocusField @nMobile, 8 -- SKU    
            GOTO Step_3_Fail    
         END    
    
         -- Check multi SKU barcode    
         IF @nSKUCnt > 1    
         BEGIN    
            SET @nErrNo = 90756    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod    
            EXEC rdt.rdtSetFocusField @nMobile, 8 -- SKU    
            SET @nSKUValidated=0    
            GOTO Step_3_Fail    
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
            SET @nErrNo = 90757    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Different SKU    
            EXEC rdt.rdtSetFocusField @nMobile, 8 -- SKU    
            SET @nSKUValidated=0    
            GOTO Step_3_Fail    
         END    
      END    
    
      -- Validate PQTY    
      IF @cPQTY <> '' AND RDT.rdtIsValidQTY( @cPQTY, 0) = 0    
      BEGIN    
         SET @nErrNo = 90758    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY    
         EXEC rdt.rdtSetFocusField @nMobile, 14 -- PQTY    
         GOTO Step_3_Fail    
      END    
      SET @nPQTY = CAST( @cPQTY AS INT)    
    
      -- Validate MQTY    
      IF @cMQTY <> '' AND RDT.rdtIsValidQTY( @cMQTY, 0) = 0    
      BEGIN    
         SET @nErrNo = 90759    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY    
         EXEC rdt.rdtSetFocusField @nMobile, 15 -- MQTY    
         GOTO Step_3_Fail    
      END    
      SET @nMQTY = CAST( @cMQTY AS INT)    
        -- Calc total QTY in master UOM    
      SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSuggSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM    
      SET @nQTY = @nQTY + @nMQTY    
    
      -- Top up QTY    
      IF NOT (@cDefaultQTY = '1' AND CHARINDEX( 'Q', @cEnableField) = 0)    
      BEGIN    
         IF @nUCCQTY > 0    
            SET @nQTY = @nQTY + @nUCCQTY    
         ELSE    
            IF @cSKU <> '' AND CHARINDEX( 'Q', @cEnableField) = 0 -- QTY field enabled    
               SET @nQTY = @nQTY + 1    
      END    
    
      -- Check over pick    
      IF @nQTY > @nQTY_PK    
      BEGIN    
         SET @nErrNo = 90760    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Over pick    
         GOTO Step_3_Fail    
      END    
    
      -- UCC scanned    
      IF @nUCCQTY > 0 AND @cUCC <> ''    
      BEGIN    
         -- Mark UCC scanned    
         INSERT INTO rdt.rdtFPKLog (TaskDetailKey, DropID, UCCNo, QTY) VALUES (@cTaskDetailKey, @cDropID, @cUCC, @nUCCQTY)    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 90761    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RPFLogFail    
            GOTO Quit    
         END    
      END    
    
      -- Top up MQTY, PQTY    
      IF NOT (@cDefaultQTY = '1' AND CHARINDEX( 'Q', @cEnableField) = 0)    
      BEGIN    
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
            IF @cSKU <> '' AND CHARINDEX( 'Q', @cEnableField) = 0  -- QTY field disabled    
               SET @nMQTY = @nMQTY + 1    
         END    
      END    
      SET @cOutField14 = CASE WHEN @cPUOM_Desc = '' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 7)) END -- PQTY    
      SET @cOutField15 = CAST( @nMQTY AS NVARCHAR( 7)) -- MQTY    
    
      -- SKU scanned, PK QTY is default and QTY field disable, remain in current screen    
      IF @cLabelNo <> '' AND NOT (@cDefaultQTY = '1' AND CHARINDEX( 'Q', @cEnableField) = 0)    
      BEGIN    
         IF CHARINDEX( 'Q', @cEnableField) = 0    -- QTY field disabled    
            EXEC rdt.rdtSetFocusField @nMobile, 8 -- SKU    
         ELSE    
            IF @cFieldAttr14 = ''    
               EXEC rdt.rdtSetFocusField @nMobile, 14 -- PQTY    
            ELSE    
               EXEC rdt.rdtSetFocusField @nMobile, 15 -- MQTY    
      END    
    
      -- QTY short    
      ELSE IF @nQTY < @nQTY_PK    
      BEGIN    
         -- Go to Reason Code Screen    
         SET @cOutField01 = ''    
         SET @cOutField02 = ''    
         SET @cOutField03 = ''    
         SET @cOutfield04 = ''    
         SET @cOutField05 = ''    
         SET @cOutField09 = ''    
    
         SET @nFromScn = @nScn    
         SET @nFromStep = @nStep    
         SET @nScn  = 2109    
         SET @nStep = @nStep + 3 -- Step 6    
      END    
      ELSE    
      BEGIN    
         -- Prepare next screen var    
         SET @cOutField01 = @cSuggFromLOC    
         SET @cOutField02 = @cSuggToLOC    
         SET @cOutField03 = '' -- ToLOC    
         SET @cOutField04 = @cDropID    
         SET @cOutField10 = '' -- ExtendedInfo    
    
         -- Disable DropID    
         IF CHARINDEX( 'D', @cEnableField) = 0    
            SET @cFieldAttr04 = 'O'    
    
         -- Go to ToLOC screen    
         SET @nScn = @nScn + 1    
         SET @nStep = @nStep + 1    
    
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- ToLOC    
      END    
    
      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo1 = ''    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,           ' +    
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +    
               '@nErrNo          INT           OUTPUT, ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +    
               '@nAfterStep      INT '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, 3, @nInputKey, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep    
    
            SET @cOutField10 = @cExtendedInfo1    
         END    
      END    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Prepare Next Screen    
      SET @cOutField01 = @cSuggID    
      SET @cOutField02 = CASE WHEN @cDefaultFromID = '1' THEN @cSuggID ELSE '' END -- FromID    
      SET @cOutField03 = @cSuggSKU    
      SET @cOutField04 = SUBSTRING( @cSKUDesc, 1, 20)    
      SET @cOutField05 = SUBSTRING( @cSKUDesc, 21, 20)    
      SET @cOutField06 = @cLottable01    
      SET @cOutField07 = @cLottable02    
      SET @cOutField08 = @cLottable03    
      SET @cOutField09 = rdt.rdtFormatDate( @dLottable04)    
      SET @cOutField10 = '1:' + CAST( @nPUOM_Div AS NCHAR( 7)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc    
      SET @cOutField11 = CASE WHEN @cPUOM_Desc = '' THEN '' ELSE CAST( @nPQTY_PK AS NVARCHAR( 7)) END    
      SET @cOutField12 = CAST( @nMQTY_PK AS NVARCHAR( 7))
    
      -- Go to FromID screen    
      SET @nScn = @nScn - 1    
      SET @nStep = @nStep - 1    
   END

   IF @cExtScnSP = '0'
   BEGIN
      SET @cExtScnSP = ''
   END
   IF @cExtScnSP <> ''
   BEGIN
      GOTO Step_99
   END

   GOTO Quit    
    
   Step_3_Fail:    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 4. screen = 3703. To LOC screen    
    FROM LOC (Field01)    
    SUGG LOC (Field02)    
    TO LOC   (Field03, input)    
    DROP ID  (Field04, input)    
    EXTINFO  (Field10)    
********************************************************************************/    
Step_4:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cToLOC = @cInField03    
      SET @cDropID   = @cInField04    
      SET @cLocNeedCheck = @cInField03
      -- Check blank FromLOC    
      IF @cToLOC = ''    
      BEGIN    
         SET @nErrNo = 90762    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLOC needed    
         GOTO Step_4_Fail    
      END    

      SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '1770ExtendedScreenSP', @cStorerKey), '')
      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_1770ExtScnEntry] 
               @cExtendedScreenSP,
               @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @cLocNeedCheck OUTPUT,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT, 
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT, 
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
               @nAction, 
               @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
               @nErrNo   OUTPUT, 
               @cErrMsg  OUTPUT
            
            IF @nErrNo <> 0
               GOTO Step_4_Fail
            
            SET @cToLOC = @cLocNeedCheck
         END
      END

      -- add loc prefix (yeekung01)    
      IF @cLOCLookupSP = '1'    
      BEGIN    
         EXEC rdt.rdt_LOCLookup @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,    
            @cToLOC     OUTPUT,    
            @nErrNo     OUTPUT,    
            @cErrMsg    OUTPUT    
         IF @nErrNo <> 0    
            GOTO Step_4_Fail    
      END    
    
      -- Check if FromLOC match    
      IF @cToLOC <> @cSuggToLOC    
      BEGIN    
         IF @cOverwriteToLOC = '0'    
         BEGIN    
            SET @nErrNo = 90763    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLOC Diff    
            GOTO Step_4_Fail    
         END    
    
         -- Check ToLOC valid    
         IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC)    
         BEGIN    
            SET @nErrNo = 90776    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC    
            GOTO Step_4_Fail    
         END    
      END    
      SET @cOutField03 = @cToLOC    

      -- Extended validate    
      IF @cExtendedValidateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @nQTY, @cToLOC, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,           ' +    
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@nQTY            INT,           ' +    
               '@cToLOC          NVARCHAR( 10), ' +    
               '@cDropID         NVARCHAR( 20), ' +    
               '@nErrNo          INT OUTPUT,    ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @nQTY, @cToLOC, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    
         END    
      END    
    
      -- Confirm    
      EXEC rdt.rdt_TM_PalletPick_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey,    
         @cTaskDetailKey,    
         @cDropID,    
         @nQTY,    
         @cToLOC,    
         @cReasonCode,    
         @cListKey,    
         @nErrNo  OUTPUT,    
         @cErrMsg OUTPUT    
      IF @nErrNo <> 0    
         GOTO Quit    
    
      -- Extended update    
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @nQTY, @cToLOC, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,           ' +    
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@nQTY            INT,           ' +    
               '@cToLOC          NVARCHAR( 10), ' +    
               '@cDropID  NVARCHAR( 20), ' +    
               '@nErrNo          INT OUTPUT,    ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @nQTY, @cToLOC, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    
         END    
      END    
    
      -- Prepare next screen var    
      SET @cOutField01 = @cToLOC    
      SET @cOutField10 = '' -- ExtInfo    
    
      SET @nScn = @nScn + 1    
      SET @nStep = @nStep + 1    
    
      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo1 = ''    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,           ' +    
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +    
               '@nErrNo          INT           OUTPUT, ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +    
               '@nAfterStep      INT '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, 4, @nInputKey, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep    
    
            SET @cOutField10 = @cExtendedInfo1    
         END    
      END    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Go to SKU QTY screen    
      IF @cTTMTaskType = 'FPK' AND    
         (CHARINDEX( 'S', @cEnableField) <> 0 OR -- SKU    
          CHARINDEX( 'Q', @cEnableField) <> 0)   -- QTY    
      BEGIN    
         -- Prepare next screen variable    
         SET @cOutField01 = @cSuggSKU    
         SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)    
         SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)    
         SET @cOutField04 = @cLottable01    
         SET @cOutField05 = @cLottable02    
         SET @cOutField06 = @cLottable03    
         SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)    
         SET @cOutField08 = '' -- SKU    
         SET @cOutField09 = ''    
         SET @cOutField10 = @cExtendedInfo1    
         SET @cOutField11 = '1:' + CAST( @nPUOM_Div AS NCHAR( 7)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc    
         SET @cOutField12 = CASE WHEN @cPUOM_Desc = '' THEN '' ELSE CAST( @nPQTY_PK AS NVARCHAR( 7)) END    
         SET @cOutField13 = CAST( @nMQTY_PK AS NVARCHAR( 7))
         SET @cOutField14 = CASE WHEN @cPUOM_Desc = '' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 7)) END    
         SET @cOutField15 = CAST( @nMQTY AS NVARCHAR( 7))
    
         -- Cursor position    
         IF @cFieldAttr08 = '' EXEC rdt.rdtSetFocusField @nMobile, 8 -- SKU    
         ELSE IF @cFieldAttr14 = '' EXEC rdt.rdtSetFocusField @nMobile, 14 -- PQTY    
         ELSE IF @cFieldAttr15 = '' EXEC rdt.rdtSetFocusField @nMobile, 15 -- MQTY    
    
         SET @nScn = @nScn - 1    
         SET @nStep = @nStep - 1    
      END    
    
      -- Go to FromID screen    
      ELSE    
      BEGIN    
         -- Prepare next screen variable    
         SET @cOutField01 = @cSuggID    
         SET @cOutField02 = CASE WHEN @cDefaultFromID = '1' THEN @cSuggID ELSE '' END -- FromID    
         SET @cOutField03 = @cSuggSKU    
         SET @cOutField04 = SUBSTRING( @cSKUDesc, 1, 20)    
         SET @cOutField05 = SUBSTRING( @cSKUDesc, 21, 20)    
         SET @cOutField06 = @cLottable01    
         SET @cOutField07 = @cLottable02    
         SET @cOutField08 = @cLottable03    
         SET @cOutField09 = rdt.rdtFormatDate( @dLottable04)    
         SET @cOutField10 = '1:' + CAST( @nPUOM_Div AS NCHAR( 7)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc    
         SET @cOutField11 = CASE WHEN @cPUOM_Desc = '' THEN '' ELSE CAST( @nPQTY_PK AS NVARCHAR( 7)) END    
         SET @cOutField12 = CAST( @nMQTY_PK AS NVARCHAR( 7))
    
         SET @nScn = @nScn - 2    
         SET @nStep = @nStep - 2    
      END    
   END    
   GOTO Quit    
    
   Step_4_Fail:    
   BEGIN    
      SET @cToLOC = ''    
      SET @cOutField03 = '' -- To LOC    
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- ToLOC    
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 5. screen = 3704. Message screen    
   Pallet is Close    
   ENTER = Next Task    
   ESC   = Exit TM    
   LAST LOC (Field01)    
   EXTINFO  (Field10)    
********************************************************************************/    
Step_5:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      DECLARE @cNextTaskType NVARCHAR(10)    
    
      SET @cErrMsg = ''    
      SET @cNextTaskDetailKey = ''    
      SET @cNextTaskType = ''    
    
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
         ,@c_StorerKey     = @cStorerkey
      IF @b_Success = 0 OR @nErrNo <> 0    
         GOTO Step_5_Fail    
    
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
    
      DECLARE @nToFunc INT    
      DECLARE @nToScn  INT    
      DECLARE @nToStep INT    
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
         SET @nErrNo = 90768    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr    
         GOTO Step_5_Fail    
      END    
    
      -- Check if screen setup    
      SELECT TOP 1 @nToScn = Scn FROM RDT.RDTScn WITH (NOLOCK) WHERE Func = @nToFunc ORDER BY Scn    
      IF @nToScn = 0    
      BEGIN    
         SET @nErrNo = 90769    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr    
         GOTO Step_5_Fail    
      END    
    
      -- Enable field    
      SET @cFieldAttr04 = '' -- @cDropID    
      SET @cFieldAttr08 = '' -- @nSKU    
      SET @cFieldAttr14 = '' -- @nPQTY    
      SET @cFieldAttr15 = '' -- @nMQTY    
    
      -- Logging    
      EXEC RDT.rdt_STD_EventLog    
         @cActionType = '9', -- Sign Out function    
         @cUserID     = @cUserName,    
         @nMobileNo   = @nMobile,    
         @nFunctionID = @nFunc,    
         @cFacility   = @cFacility,    
         @cStorerKey  = @cStorerKey    
    
      SET @nFunc = @nToFunc    
      SET @nScn  = @nToScn    
      SET @nStep = @nToStep    
    
      IF @cTTMTaskType IN ('FPK', 'FPK1')    
         GOTO Step_0    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      EXEC RDT.rdt_STD_EventLog    
       @cActionType = '9', -- Sign Out function    
       @cUserID     = @cUserName,    
       @nMobileNo   = @nMobile,    
       @nFunctionID = @nFunc,    
       @cFacility  = @cFacility,    
       @cStorerKey  = @cStorerKey    

      -- Extended update    
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @nQTY, @cToLOC, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,           ' +    
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@nQTY            INT,           ' +    
               '@cToLOC          NVARCHAR( 10), ' +    
               '@cDropID         NVARCHAR( 20), ' +    
               '@nErrNo          INT OUTPUT,    ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @nQTY, @cToLOC, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    
         END    
      END 

      -- Enable field    
      SET @cFieldAttr04 = '' -- @cDropID    
      SET @cFieldAttr08 = '' -- @nSKU    
      SET @cFieldAttr14 = '' -- @nPQTY    
      SET @cFieldAttr15 = '' -- @nMQTY    
    
      -- Go back to Task Manager Main Screen    
      SET @nFunc = 1756    
      SET @nScn = 2100    
      SET @nStep = 1    
    
      SET @cAreaKey = ''    
      SET @cOutField01 = ''  -- Area    
   END    
   GOTO Quit    
    
   Step_5_Fail:    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 6. screen = 2109. Reason code screen    
REASON CODE (Field01, input)    
********************************************************************************/    
Step_6:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      DECLARE @nShortQTY INT    
      SET @cReasonCode = @cInField01    
    
      -- Check blank reason    
      IF @cReasonCode = ''    
      BEGIN    
        SET @nErrNo = 90770    
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Reason needed    
        GOTO Step_6_Fail    
      END    
    
      IF NOT EXISTS( SELECT TOP 1 1    
         FROM CodeLKUP WITH (NOLOCK)    
         WHERE ListName = 'RDTTASKRSN'    
            AND StorerKey = @cStorerKey    
            AND Code = @cTTMTaskType    
            AND @cReasonCode IN (UDF01, UDF02, UDF03, UDF04, UDF05))    
      BEGIN    
        SET @nErrNo = 90771    
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Reason    
        GOTO Step_6_Fail    
      END    
    
      -- Update ReasonCode    
      SET @nShortQTY = @nQTY_PK - @nQTY    
      EXEC dbo.nspRFRSN01    
          @c_sendDelimiter = NULL    
         ,@c_ptcid         = 'RDT'    
         ,@c_userid        = @cUserName    
         ,@c_taskId        = 'RDT'    
         ,@c_databasename  = NULL    
         ,@c_appflag       = NULL    
         ,@c_recordType    = NULL    
         ,@c_server        = NULL    
         ,@c_ttm           = NULL    
         ,@c_TaskDetailKey = @cTaskDetailKey    
         ,@c_fromloc       = @cSuggFromLOC    
         ,@c_fromid        = @cSuggID    
         ,@c_toloc         = @cSuggToloc    
         ,@c_toid = @cDropID    
         ,@n_qty           = @nShortQTY    
         ,@c_PackKey       = ''    
         ,@c_uom           = ''    
         ,@c_reasoncode    = @cReasonCode    
         ,@c_outstring     = @c_outstring    OUTPUT    
         ,@b_Success       = @b_Success      OUTPUT    
         ,@n_err           = @nErrNo         OUTPUT    
         ,@c_errmsg        = @cErrMsg        OUTPUT    
         ,@c_userposition  = '1' -- 1=at from LOC    
      IF @@ERROR <> 0 OR @b_Success = 0 OR @nErrNo <> 0
      BEGIN
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP' )
         END
         ELSE
         BEGIN
            SET @nErrNo = 90777
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP' )
         END
         GOTO Step_6_Fail
      END
    
      -- Get task reason info    
      DECLARE @cContinueProcess         NVARCHAR(10)    
      DECLARE @cRemoveTaskFromUserQueue NVARCHAR(10)    
      DECLARE @cTaskStatus              NVARCHAR(10)    
      SELECT    
         @cContinueProcess = ContinueProcessing,    
         @cRemoveTaskFromUserQueue = RemoveTaskFromUserQueue,    
         @cTaskStatus = TaskStatus    
      FROM dbo.TaskManagerReason WITH (NOLOCK)    
      WHERE TaskManagerReasonKey = @cReasonCode    
    
      IF @cRemoveTaskFromUserQueue = '1'    
      BEGIN    
         INSERT INTO TaskManagerSkipTasks (UserID, TaskDetailKey, TaskType, LOT, FromLOC, ToLOC, FromID, ToID, CaseID)    
         SELECT UserKey, TaskDetailKey, TaskType, LOT, FromLOC, ToLOC, FromID, ToID, CaseID    
         FROM dbo.TaskDetail WITH (NOLOCK)    
         WHERE TaskDetailKey = @cTaskdetailKey    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 90772    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsSkipTskFail    
            GOTO Step_6_Fail    
         END    
      END    
    
      -- Update TaskDetail.Status    
      IF @cTaskStatus <> ''    
      BEGIN    
         -- Skip task    
         IF @cTaskStatus = '0'    
         BEGIN    
            UPDATE dbo.TaskDetail SET    
                UserKey = ''    
               ,ReasonKey = ''    
               ,Status = '0'    
               ,EditDate = GETDATE()    
           ,EditWho  = SUSER_SNAME()    
               ,TrafficCop = NULL    
            WHERE TaskDetailKey = @cTaskDetailKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 90773    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskdetFail    
               GOTO Step_6_Fail    
            END    
         END    
    
         -- Cancel task    
         IF @cTaskStatus = 'X'    
         BEGIN    
            UPDATE dbo.TaskDetail SET    
                Status = 'X'    
               ,EditDate = GETDATE()    
               ,EditWho  = SUSER_SNAME()    
               ,TrafficCop = NULL    
            WHERE TaskDetailKey = @cTaskDetailKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 90774    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskdetFail    
               GOTO Step_6_Fail    
            END    
         END    
    
         -- Cancel picked UCC    
         IF EXISTS( SELECT 1 FROM rdt.rdtFPKLog WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey)    
         BEGIN    
            DELETE rdt.rdtFPKLog WHERE TaskDetailKey = @cTaskDetailKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 90775    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelRPFLogFail    
               GOTO Step_6_Fail    
            END    
         END    
      END    
    
      -- Extended update    
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @nQTY, @cToLOC, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,           ' +    
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@nQTY            INT,           ' +    
               '@cToLOC          NVARCHAR( 10), ' +    
               '@cDropID         NVARCHAR( 20), ' +    
               '@nErrNo          INT OUTPUT,    ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @nQTY, @cToLOC, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    
         END    
      END    
    
      -- Continue process current task    
      IF @cContinueProcess = '1'    
      BEGIN    
         -- Back to FromLOC screen    
         IF @nFromStep = 1    
         BEGIN    
            SET @cOutField01 = @cSuggFromLOC    
            SET @cOutField02 = CASE WHEN @cDefaultFromLOC = '1' THEN @cSuggFromLOC ELSE '' END -- FromLOC    
            SET @nScn = @nFromScn    
            SET @nStep = @nFromStep    
         END    
    
         -- Go to ToLOC screen    
         IF @nFromStep = 3 -- SKU QTY screen    
         BEGIN    
            SET @cOutField01 = @cSuggFromLOC    
            SET @cOutField02 = @cSuggToLOC    
            SET @cOutField03 = '' -- ToLOC    
            SET @cOutField04 = @cDropID    
    
            -- Disable DropID    
            IF CHARINDEX( 'D', @cEnableField) = 0 OR @cTTMTaskType <> 'FPK'    
               SET @cFieldAttr04 = 'O'    
    
            SET @nScn = @nFromScn + 1    
            SET @nStep = @nFromStep + 1    
         END    
      END    
      ELSE    
      BEGIN    
         -- Setup RDT storer config ContProcNotUpdTaskStatus, to avoid nspRFRSN01 set TaskDetail.Status = '9', when ContinueProcess <> 1    
    
         -- Go to next task/exit TM screen    
         SET @nScn  = CASE WHEN @nFromStep = 1 THEN @nFromScn + 4    
                           WHEN @nFromStep = 3 THEN @nFromScn + 2    
                      END    
      SET @nStep = 5    
      END    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Go to FromLOC screen    
      IF @nFromStep = 1    
      BEGIN    
         -- Prepare next screen variable    
      SET @cFromLOC = ''    
         SET @cOutField01 = @cSuggFromLOC    
         SET @cOutField02 = CASE WHEN @cDefaultFromLOC = '1' THEN @cSuggFromLOC ELSE '' END -- FromLOC    
      END    
    
      -- Go to SKU QTY screen    
      IF @nFromStep = 3    
      BEGIN    
         -- Prepare next screen variable    
         SET @cOutField01 = @cSuggSKU    
         SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)    
         SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)    
         SET @cOutField04 = @cLottable01    
         SET @cOutField05 = @cLottable02    
         SET @cOutField06 = @cLottable03    
         SET @cOutField07 = rdt.rdtFormatDate( @dLottable04)    
         SET @cOutField08 = '' -- SKU    
         SET @cOutField09 = ''    
         SET @cOutField10 = @cExtendedInfo1    
         SET @cOutField11 = '1:' + CAST( @nPUOM_Div AS NCHAR( 7)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc
         SET @cOutField12 = CASE WHEN @cPUOM_Desc = '' THEN '' ELSE CAST( @nPQTY_PK AS NVARCHAR( 7)) END
         SET @cOutField13 = CAST( @nMQTY_PK AS NVARCHAR( 7))
         SET @cOutField14 = CASE WHEN @cPUOM_Desc = '' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 7)) END
         SET @cOutField15 = CAST( @nMQTY AS NVARCHAR( 7))
    
         -- Cursor position    
         IF @cFieldAttr08 = '' EXEC rdt.rdtSetFocusField @nMobile, 8 -- SKU    
         ELSE IF @cFieldAttr14 = '' EXEC rdt.rdtSetFocusField @nMobile, 14 -- PQTY    
         ELSE IF @cFieldAttr15 = '' EXEC rdt.rdtSetFocusField @nMobile, 15 -- MQTY    
      END    
    
      -- Back to prev screen    
      SET @nScn = @nFromScn    
      SET @nStep = @nFromStep    
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
    
Step_99:
BEGIN
   IF @cExtScnSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
      BEGIN      

         EXECUTE [RDT].[rdt_ExtScnEntry] 
         @cExtScnSP, 
         @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @tExtScnData ,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,  
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,  
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,  
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,  
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,  
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT, 
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT, 
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT, 
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT, 
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT, 
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nAction, 
         @nScn     OUTPUT,  @nStep OUTPUT,
         @nErrNo   OUTPUT, 
         @cErrMsg  OUTPUT,
         @cUDF01   OUTPUT, @cUDF02 OUTPUT, @cUDF03 OUTPUT,
         @cUDF04   OUTPUT, @cUDF05 OUTPUT, @cUDF06 OUTPUT,
         @cUDF07   OUTPUT, @cUDF08 OUTPUT, @cUDF09 OUTPUT,
         @cUDF10   OUTPUT, @cUDF11 OUTPUT, @cUDF12 OUTPUT,
         @cUDF13   OUTPUT, @cUDF14 OUTPUT, @cUDF15 OUTPUT,
         @cUDF16   OUTPUT, @cUDF17 OUTPUT, @cUDF18 OUTPUT,
         @cUDF19   OUTPUT, @cUDF20 OUTPUT, @cUDF21 OUTPUT,
         @cUDF22   OUTPUT, @cUDF23 OUTPUT, @cUDF24 OUTPUT,
         @cUDF25   OUTPUT, @cUDF26 OUTPUT, @cUDF27 OUTPUT,
         @cUDF28   OUTPUT, @cUDF29 OUTPUT, @cUDF30 OUTPUT

         IF @nErrNo <> 0
            GOTO Step_99_Fail
      END
   END

   GOTO Quit

Step_99_Fail:
   BEGIN
      GOTO Quit
   END
END
GOTO Quit

    
/********************************************************************************    
Quit. Update back to I/O table, ready to be pick up by JBOSS    
********************************************************************************/    
Quit:    
BEGIN    
   UPDATE RDTMOBREC WITH (ROWLOCK) SET    
      EditDate     = GETDATE(),    
      ErrMsg       = @cErrMsg,    
      Func         = @nFunc,    
      Step         = @nStep,    
      Scn          = @nScn,    
    
      StorerKey    = @cStorerKey,    
      Facility     = @cFacility,    
      Printer      = @cPrinter,    
      -- UserName     = @cUserName,    
    
      V_FromScn    = @nFromScn,    
      V_FromStep   = @nFromStep,    
      V_TaskDetailKey = @cTaskDetailKey,    
      V_SKU        = @cSuggSKU,    
      V_SKUDescr   = @cSKUDesc,    
      V_LOT        = @cSuggLOT,    
      V_LOC        = @cSuggFromLOC,    
      V_ID         = @cSuggID,    
      V_UOM        = @cPUOM,    
      V_Lottable01 = @cLottable01,    
      V_Lottable02 = @cLottable02,    
      V_Lottable03 = @cLottable03,    
      V_Lottable04 = @dLottable04,    
    
      V_PUOM_Div   = @nPUOM_Div ,    
      V_PTaskQTY   = @nPQTY_PK ,    
      V_MTaskQTY   = @nMQTY_PK ,    
      V_TaskQTY    = @nQTY_PK,    
      V_PQTY       = @nPQTY,    
      V_MQTY       = @nMQTY,    
      V_QTY        = @nQTY,    
    
      V_String1    = @cAreaKey,    
      V_String2    = @cTaskStorer,    
      V_String3    = @cDropID,    
      V_String5    = @cSuggToloc,    
      V_String6    = @cReasonCode,    
      V_String7    = @cListKey,    
      V_String8    = @cEnableField,    
      V_String9    = @cCustomLottableSP,    
      V_String10   = @cMUOM_Desc,    
      V_String11   = @cPUOM_Desc,    
    
      V_String21   = @cDecodeLabelNo,    
      V_String22   = @cExtendedUpdateSP,    
      V_String23   = @cDefaultToLOC,    
      V_String24   = @cDefaultQTY,    
      V_String25   = @nSKUValidated,    
      V_String26   = @cDefaultFromID,    
      V_String27   = @cExtendedInfoSP,    
      V_String28   = @cExtendedInfo1,    
      V_String29   = @cSwapTaskSP,    
      V_String30   = @cDefaultDropID,    
      V_String31   = @cExtendedValidateSP,
      V_String32   = @cAreakey,    
      V_String33   = @cTTMStrategykey,    
      V_String34   = @cTTMTaskType,    
      V_String35   = @cRefKey01,    
      V_String36   = @cRefKey02,    
      V_String37   = @cRefKey03,    
      V_String38   = @cRefKey04,    
      V_String39   = @cRefKey05,    
      V_String40   = @cOverwriteToLOC,
      V_String41   = @cLOCLookupSP,  --(yeekung01)    
      V_String42   = @cSkuInfoFromLLI,  --(cc01)
      V_String43   = @cExtScnSP,
      V_String44   = @cHUSQGRPPICK,

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
   IF (@nFunc <> 1770 AND @nStep = 0) AND -- Other module that begin with step 0    
      (@nFunc <> @nMenu)                  -- Not ESC from screen to menu    
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