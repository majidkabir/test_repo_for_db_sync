SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_TM_Assist_Move                               */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Move pallet from induct out to lane                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2015-03-05 1.0  Ung      Created SOS335049                           */
/* 2015-05-08 1.1  James    Add default value for FinalLOC (james01)    */
/* 2015-05-19 1.2  James    Clear variable ExtendedInfo (james02)       */
/* 2016-09-30 1.3  Ung      Performance tuning                          */   
/* 2018-10-25 1.4  TungGH   Performance                                 */   
/* 2019-10-03 1.5  James    WMS-10316 Clear Case ID when esc (james01)  */
/* 2021-05-12 1.6  James    WMS-16966-Add verify sku (james02)          */
/* 2025-01-20 1.7.0Dennis   FCR-1344 Ext Val on step 0                  */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_TM_Assist_Move] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- Misc variable
DECLARE
   @bSuccess            INT, 
   @cAreaKey            NVARCHAR( 10),
   @cTTMStrategykey     NVARCHAR( 10), 
   @cSQL                NVARCHAR( MAX), 
   @cSQLParam           NVARCHAR( MAX),
   @cFinalLOC           NVARCHAR( 10)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,

   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @cPrinter            NVARCHAR( 10),
   @cUserName           NVARCHAR( 18),

   @cFromID             NVARCHAR( 20), 
   @cFromLOC            NVARCHAR( 10), 
   @cTaskDetailKey      NVARCHAR( 10),

   @cTTMTaskType        NVARCHAR( 10), 
   @cSuggToLOC          NVARCHAR( 10), 
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cOverwriteToLOC     NVARCHAR( 1),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cDefaultToLoc       NVARCHAR( 20),
   @cASTMVVerifySKU     NVARCHAR( 1),
   @cSuggSKU            NVARCHAR( 20),
   @cSKU                NVARCHAR( 20),
   @cSourceKey          NVARCHAR( 10),
   @cBarcode            NVARCHAR( 60),
   @cDecodeSP           NVARCHAR( 20),
   @cToLOC              NVARCHAR( 10),
   @cToID               NVARCHAR( 18),
   @cDecodeQty          NVARCHAR( 5),
   @cDecodeLabelNo      NVARCHAR( 20),
   @cMultiSKUBarcode    NVARCHAR( 1),
   @cSKUDescr           NVARCHAR( 60),
   @cPUOM               NVARCHAR( 1), -- Pref UOM
   @cPUOM_Desc          NVARCHAR( 5), -- Pref UOM desc
   @cMUOM_Desc          NVARCHAR( 5), -- Master UOM desc
   @c_errmsg            NVARCHAR( 20),
   @cAvlQTY             NVARCHAR( 5),
   @cDefaultQTY         NVARCHAR( 1),
   @cPrePackIndicator   NVARCHAR( 30),
   @cLottableCode       NVARCHAR( 30),
   @cLot                NVARCHAR( 10),
   @cLottable01         NVARCHAR( 18),  
   @cLottable02         NVARCHAR( 18),  
   @cLottable03         NVARCHAR( 18),  
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
   
   @nQTY                INT,
   @nPQTY               INT,      -- QTY to move, in pref UOM
   @nMQTY               INT,      -- Remining QTY to move, in master UOM
   @nPUOM_Div           INT,
   @nQTY_Avail          INT,
   @nPQTY_Avail         INT,
   @nMQTY_Avail         INT,
   @nPackQtyIndicator   INT,
   @b_Success           INT,
   @nSKUCnt             INT,
   @nFromScn            INT,
   @nFromStep           INT,
   @n_Err               INT,
   @nMorePage           INT,
   
   @cNewTask            NVARCHAR( 10),
   @cActSKU             NVARCHAR( 20),

   @c_oField01 NVARCHAR(20),     @c_oField02 NVARCHAR(20),
   @c_oField03 NVARCHAR(20),     @c_oField04 NVARCHAR(20),
   @c_oField05 NVARCHAR(20),     @c_oField06 NVARCHAR(20),
   @c_oField07 NVARCHAR(20),     @c_oField08 NVARCHAR(20),
   @c_oField09 NVARCHAR(20),     @c_oField10 NVARCHAR(20),
   @c_oField11 NVARCHAR(20),     @c_oField12 NVARCHAR(20),   
   @c_oField13 NVARCHAR(20),     @c_oField14 NVARCHAR(20),   
   @c_oField15 NVARCHAR(20),                          
   
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

-- Load RDT.RDTMobRec
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cFacility        = Facility,
   @cUserName        = UserName,
   @cPrinter         = Printer,

   @cStorerKey       = V_StorerKey,
   @cFromID          = V_ID,
   @cFromLOC         = V_LOC,
   @cTaskDetailKey   = V_TaskDetailKey,
   @cSKUDescr        = V_SKUDescr,
   @cPUOM            = V_UOM,      
   @nPQTY            = V_PQTY,     
   @nMQTY            = V_MQTY,     
   @nPUOM_Div        = V_PUOM_Div, 
   @cLottable01      = V_Lottable01,  
   @cLottable02      = V_Lottable02,  
   @cLottable03      = V_Lottable03,  
   @dLottable04      = V_Lottable04,  
   @dLottable05      = V_Lottable05,  
   @cLottable06      = V_Lottable06,  
   @cLottable07      = V_Lottable07,  
   @cLottable08      = V_Lottable08,  
   @cLottable09      = V_Lottable09,  
   @cLottable10      = V_Lottable10,  
   @cLottable11      = V_Lottable11,  
   @cLottable12      = V_Lottable12,  
   @dLottable13      = V_Lottable13,  
   @dLottable14      = V_Lottable14,  
   @dLottable15      = V_Lottable15,  
   
   @nQTY_Avail          = V_Integer1,
   @nPQTY_Avail         = V_Integer2,
   @nMQTY_Avail         = V_Integer3,
   @nQTY                = V_Integer4,
   @nPackQtyIndicator   = V_Integer5,
   
   @nFromStep           = V_FromStep,
   @nFromScn            = V_FromScn,
   
   @cAreakey            = V_String1,
   @cTTMStrategykey     = V_String2,
   @cTTMTaskType        = V_String3,
   @cSuggToLOC          = V_String4,
   @cExtendedValidateSP = V_String5,
   @cExtendedUpdateSP   = V_String6,
   @cOverwriteToLOC     = V_String7,
   @cExtendedInfoSP     = V_String8,
   @cExtendedInfo       = V_String9,
   @cDefaultToLoc       = V_String10,
   @cASTMVVerifySKU     = V_String11,
   @cSourceKey          = V_String12,
   @cDecodeSP           = V_String13,
   @cMultiSKUBarcode    = V_String14,
   @cPrePackIndicator   = V_String15,
   @cLottableCode       = V_String16,
   @cDefaultQTY         = V_String17,
   
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

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1816
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1816
   IF @nStep = 1 GOTO Step_1   -- Scn = 4080. From ID
   IF @nStep = 2 GOTO Step_2   -- Scn = 4081. Message. Next task type
   IF @nStep = 3 GOTO Step_3   -- Scn = 4082. SKU
   IF @nStep = 4 GOTO Step_4   -- Scn = 4083. Lottable, Qty
   IF @nStep = 5 GOTO Step_5   -- 3570 Multi SKU selection
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
      @cFromID      = FromID,
      @cFromLOC     = FromLOC,
      @cSuggToLOC   = ToLOC,
      @cSuggSKU     = Sku,
      @cSourceKey   = SourceKey
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey

   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''

   -- Extended validate
   IF @cExtendedValidateSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' + 
            '@cTaskdetailKey  NVARCHAR( 10), ' +
            '@cFinalLOC       NVARCHAR( 10), ' +
            '@nErrNo          INT OUTPUT,    ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

         
         IF @nErrNo <> 0
         BEGIN
            SET @nFunc = 1814
            SET @nStep = 0  
            GOTO QUIT
         END
      END
   END

   -- Get storer configure
   SET @cOverwriteToLOC = rdt.rdtGetConfig( @nFunc, 'OverwriteToLOC', @cStorerKey)
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   -- (james01)
   SET @cDefaultToLoc = rdt.rdtGetConfig( @nFunc, 'DefaultToLoc', @cStorerKey)
   IF @cDefaultToLoc = '0'
      SET @cDefaultToLoc = ''

   -- (james02)
   SET @cASTMVVerifySKU = rdt.rdtGetConfig( @nFunc, 'ASTMVVerifySKU', @cStorerKey)

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   IF @cASTMVVerifySKU = '1'
   BEGIN
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromId
      SET @cOutField03 = ''

      -- Set the entry point
      SET @nScn  = 4082
      SET @nStep = 3
   END
   ELSE
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cFromID
      SET @cOutField02 = @cSuggToLOC
      SET @cOutField03 = CASE WHEN @cDefaultToLoc = '1' THEN @cSuggToLOC ELSE '' END   -- FinalLOC
      
      -- Set the entry point
      SET @nScn  = 4080
      SET @nStep = 1
   END
   
   -- Extended info
   SET @cOutField15 = ''
   SET @cExtendedInfo = '' -- (james02)
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nAfterStep      INT,           ' +
            '@nInputKey       INT,           ' + 
            '@cTaskdetailKey  NVARCHAR( 10), ' +
            '@cFinalLOC       NVARCHAR( 10), ' +
            '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo          INT           OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 0, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         SET @cOutField15 = @cExtendedInfo
      END
   END
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 4080
   ID           (Field01)
   SUGGEST LOC  (Field02)
   FINAL LOC    (Field03, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFinalLOC = @cInField03

      -- Check blank
      IF @cFinalLOC = ''
      BEGIN
         SET @nErrNo = 52151
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TO LOC needed
         GOTO Step_1_Fail
      END

      -- Check if FromLOC match
      IF @cFinalLOC <> @cSuggToLOC AND @cSuggToLOC <> ''
      BEGIN
         IF @cOverwriteToLOC = '0'
         BEGIN
            SET @nErrNo = 52152
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different LOC 
            GOTO Step_1_Fail
         END
         
         -- Check ToLOC valid
         IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cFinalLOC)
         BEGIN
            SET @nErrNo = 52153
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
            GOTO Step_1_Fail
         END
      END
      SET @cOutField03 = @cFinalLOC

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END

      -- Confirm (move by ID, update task status = 9)
      EXEC rdt.rdt_TM_Assist_Move_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cTaskdetailKey  
         ,@cFinalLOC       
         ,@nErrNo   OUTPUT
         ,@cErrMsg  OUTPUT
      IF @nErrNo <> 0
         GOTO Step_1_Fail
      
      -- Extended validate
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END
      
      -- Get next task
      DECLARE @cNextTaskDetailKey NVARCHAR(10)
      SET @cNextTaskDetailKey = ''
      SELECT TOP 1 
         @cNextTaskDetailKey = TaskDetailKey,
         @cTTMTasktype = TaskType
      FROM dbo.TaskDetail WITH (NOLOCK)
         JOIN CodeLKUP WITH (NOLOCK) ON (ListName = 'RDTAstTask' AND Code = TaskType AND Code2 = @cFacility)
      WHERE FromID = @cFromID
         AND Status = '0'
      ORDER BY TaskDetailKey
      
      -- No task
      IF @cNextTaskDetailKey = ''
      BEGIN
         -- EventLog
         EXEC RDT.rdt_STD_EventLog
            @cActionType = '9', -- Sign-out
            @cUserID     = @cUserName,
            @nMobileNo   = @nMobile,
            @nFunctionID = @nFunc,
            @cFacility   = @cFacility,
            @cStorerKey  = @cStorerKey,
            @nStep       = @nStep
         
         -- Go back to assist task manager
         SET @nFunc = 1814
         SET @nScn = 4060
         SET @nStep = 1

         SET @cOutField01 = ''  -- From ID
         SET @cOutField02 = ''  -- Case ID

         GOTO QUIT
      END
      
      -- Have next task
      IF @cNextTaskDetailKey <> ''
      BEGIN
         SET @cTaskDetailKey = @cNextTaskDetailKey

         IF @cASTMVVerifySKU = '1'
         BEGIN
            SET @cOutField01 = @cFromLOC
            SET @cOutField02 = @cFromId
            SET @cOutField03 = ''

            -- Set the entry point
            SET @nScn  = 4082
            SET @nStep = 3
         END
         ELSE
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = @cTTMTasktype

            -- Go to next task
            SET @nScn  = @nScn + 1
            SET @nStep = @nStep + 1
         END
         
         GOTO Quit
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-out
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep

      -- Go back to assist task manager
      SET @nFunc = 1814
      SET @nScn = 4060
      SET @nStep = 1

      SET @cOutField01 = ''  -- From ID
      SET @cOutField02 = ''  -- Case ID
      GOTO QUIT
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cFinalLOC = ''
      SET @cOutField03 = '' -- FinalLOC
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen 4081. Next task
   Next task type (field01)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
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
         SET @nErrNo = 52154
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr
         GOTO Quit
      END

      -- Check if screen setup
      SELECT TOP 1 @nToScn = Scn FROM RDT.RDTScn WITH (NOLOCK) WHERE Func = @nToFunc ORDER BY Scn
      IF @nToScn = 0
      BEGIN
         SET @nErrNo = 52155
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr
         GOTO Quit
      END

      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep
      
      SET @cOutField06 = @cTaskDetailKey
      SET @cOutField07 = @cAreaKey
      SET @cOutField08 = @cTTMStrategykey

      SET @nFunc = @nToFunc
      SET @nScn  = @nToScn
      SET @nStep = @nToStep

      IF @cTTMTaskType IN ('ASTNMV')
         GOTO Step_0
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-out
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep

      -- Go back to assist task manager
      SET @nFunc = 1814
      SET @nScn = 4060
      SET @nStep = 1

      SET @cOutField01 = ''  -- From ID
      SET @cOutField02 = ''  -- Case ID
   END
END
GOTO Quit

/********************************************************************************
Step 3. scn = 1032. SKU screen
   FromLOC (field01)
   FromID  (field02)
   SKU     (field03, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cBarcode = @cInField03
      SET @cSKU = LEFT( @cInField03, 30)

      -- Validate blank
      IF @cSKU = '' OR @cSKU IS NULL
      BEGIN
         SET @nErrNo = 52156
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU needed'
         GOTO Step_3_Fail
      END

		--INC0448387
  		SET @nQTY = 0 
  		
      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cUPC    = @cSKU    OUTPUT,
               @nQTY    = @nQTY    OUTPUT,
               @cType   = 'UPC'
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +
               ' @cFromLOC    OUTPUT, @cFromID     OUTPUT, ' +
               ' @cSKU        OUTPUT, @nQTY        OUTPUT, ' +
               ' @cToLOC      OUTPUT, @cToID       OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cFromLOC     NVARCHAR( 10)  OUTPUT, ' +
               ' @cFromID      NVARCHAR( 18)  OUTPUT, ' +
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
               ' @nQTY         INT            OUTPUT, ' +
               ' @cToLOC       NVARCHAR( 10)  OUTPUT, ' +
               ' @cToID        NVARCHAR( 18)  OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode,
               @cFromLOC    OUTPUT, @cFromID     OUTPUT,
               @cSKU        OUTPUT, @nQTY        OUTPUT,
               @cToLOC      OUTPUT, @cToID       OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_3_Fail
         END
      END
      ELSE
      BEGIN
         SET @cDecodeQty = ''    
         SET @cAvlQTY = ''       

         SET @cDecodeLabelNo = ''
         SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerkey)

         IF ISNULL(@cDecodeLabelNo,'') NOT IN ('','0')   
         BEGIN
            EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @cSKU
            ,@c_Storerkey  = @cStorerkey
            ,@c_ReceiptKey = @nMobile
            ,@c_POKey      = ''
            ,@c_LangCode   = @cLangCode
            ,@c_oFieled01  = @c_oField01 OUTPUT   -- SKU
            ,@c_oFieled02  = @c_oField02 OUTPUT   -- STYLE
            ,@c_oFieled03  = @c_oField03 OUTPUT   -- COLOR
            ,@c_oFieled04  = @c_oField04 OUTPUT   -- SIZE
            ,@c_oFieled05  = @c_oField05 OUTPUT   -- QTY
            ,@c_oFieled06  = @c_oField06 OUTPUT   -- CO#
            ,@c_oFieled07  = @c_oField07 OUTPUT
            ,@c_oFieled08  = @c_oField08 OUTPUT
            ,@c_oFieled09  = @c_oField09 OUTPUT
            ,@c_oFieled10  = @c_oField10 OUTPUT
            ,@b_Success    = @b_Success   OUTPUT
            ,@n_ErrNo      = @nErrNo      OUTPUT
            ,@c_ErrMsg     = @cErrMsg     OUTPUT   -- AvlQTY

            IF ISNULL(@cErrMsg, '') <> ''
            BEGIN
               SET @cErrMsg = @cErrMsg
               GOTO Step_3_Fail
            END

            SET @cSKU = @c_oField01
            SET @nQTY = @c_oField05
         END
      END

      -- Get SKU count
      EXEC [RDT].[rdt_GETSKUCNT]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 52157
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_3_Fail
      END

      -- Validate barcode return multiple SKU      
      IF @nSKUCnt > 1      
      BEGIN      
         IF @cMultiSKUBarcode IN ('1', '2')    
         BEGIN      
            IF (@cFromID <>'')      
            BEGIN      
               EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,      
                  @cInField01 OUTPUT,  @cOutField01 OUTPUT,      
                  @cInField02 OUTPUT,  @cOutField02 OUTPUT,      
                  @cInField03 OUTPUT,  @cOutField03 OUTPUT,      
                  @cInField04 OUTPUT,  @cOutField04 OUTPUT,      
                  @cInField05 OUTPUT,  @cOutField05 OUTPUT,      
                  @cInField06 OUTPUT,  @cOutField06 OUTPUT,      
                  @cInField07 OUTPUT,  @cOutField07 OUTPUT,      
                  @cInField08 OUTPUT,  @cOutField08 OUTPUT,      
                  @cInField09 OUTPUT,  @cOutField09 OUTPUT,      
                  @cInField10 OUTPUT,  @cOutField10 OUTPUT,      
                  @cInField11 OUTPUT,  @cOutField11 OUTPUT,      
                  @cInField12 OUTPUT,  @cOutField12 OUTPUT,      
                  @cInField13 OUTPUT,  @cOutField13 OUTPUT,      
                  @cInField14 OUTPUT,  @cOutField14 OUTPUT,      
                  @cInField15 OUTPUT,  @cOutField15 OUTPUT,      
                  'POPULATE',      
                  @cMultiSKUBarcode,      
                  @cStorerKey,      
                  @cSKU         OUTPUT,      
                  @nErrNo       OUTPUT,      
                  @cErrMsg      OUTPUT,      
                  'LOTXLOCXID.ID',    -- DocType      
                  @cFromID    
            END      
            ELSE      
            BEGIN      
               EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,      
                  @cInField01 OUTPUT,  @cOutField01 OUTPUT,      
                  @cInField02 OUTPUT,  @cOutField02 OUTPUT,      
                  @cInField03 OUTPUT,  @cOutField03 OUTPUT,      
                  @cInField04 OUTPUT,  @cOutField04 OUTPUT,      
                  @cInField05 OUTPUT,  @cOutField05 OUTPUT,      
                  @cInField06 OUTPUT,  @cOutField06 OUTPUT,      
                  @cInField07 OUTPUT,  @cOutField07 OUTPUT,      
                  @cInField08 OUTPUT,  @cOutField08 OUTPUT,      
                  @cInField09 OUTPUT,  @cOutField09 OUTPUT,      
                  @cInField10 OUTPUT,  @cOutField10 OUTPUT,      
                  @cInField11 OUTPUT,  @cOutField11 OUTPUT,      
                  @cInField12 OUTPUT,  @cOutField12 OUTPUT,      
                  @cInField13 OUTPUT,  @cOutField13 OUTPUT,      
                  @cInField14 OUTPUT,  @cOutField14 OUTPUT,      
                  @cInField15 OUTPUT,  @cOutField15 OUTPUT,      
                  'POPULATE',      
                  @cMultiSKUBarcode,      
                  @cStorerKey,      
                  @cSKU         OUTPUT,      
                  @nErrNo       OUTPUT,      
                  @cErrMsg      OUTPUT,      
                  '',    -- DocType      
                  ''      
            END      
      
            IF @nErrNo = 0 -- Populate multi SKU screen      
            BEGIN      
               -- Go to Multi SKU screen      
               SET @nFromScn = @nScn      
               SET @nFromStep = @nStep      
               SET @nScn = 3570      
               SET @nStep = @nStep + 2      
               GOTO Quit      
            END      
            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen      
               SET @nErrNo = 0      
         END      
         ELSE      
         BEGIN      
            SET @nErrNo = 52158      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SameBarCodeSKU'      
            GOTO Step_3_Fail      
         END      
      END       

      -- Get SKU
      EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU          OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT


      Skip_ValidateSKU:
      -- Get SKU info
      SELECT
         @cSKUDescr = S.DescR,
         @cPrePackIndicator = PrePackIndicator,
         @nPackQtyIndicator = ISNULL( PackQtyIndicator, 0),
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
            END AS INT), 
         @cLottableCode = S.LottableCode
      FROM dbo.SKU S (NOLOCK)
         INNER JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      SET @cNewTask = ''

      SELECT TOP 1 
             @cNewTask = TaskDetailKey,
             @nQTY_Avail = Qty
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE Sku = @cSKU
      AND   FromLoc = @cFromLOC
      AND   FromID = @cFromID
      AND   [Status] = '0'
      AND   TaskType = @cTTMTaskType
      ORDER BY TaskDetailKey

      -- Validate not QTY
      IF @nQTY_Avail = 0 OR @nQTY_Avail IS NULL OR @cNewTask = ''
      BEGIN
         SET @nErrNo = 52159
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No QTY to move'
         GOTO Step_3_Fail
      END

      SET @cTaskDetailKey = @cNewTask

      -- Get task info after get new taskdetailkey (refresh task info)
      SELECT
         @cTTMTaskType = TaskType,
         @cStorerKey   = Storerkey,
         @cFromID      = FromID,
         @cFromLOC     = FromLOC,
         @cSuggToLOC   = ToLOC,
         @cSuggSKU     = Sku,
         @cSourceKey   = SourceKey
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskDetailKey
      
      -- Extended update
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR(  5), ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cFromID         NVARCHAR( 18), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cToID           NVARCHAR( 18), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      SELECT @cLot = Lot
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cSourceKey
      
      SELECT @cLottable01 = Lottable01,
             @cLottable02 = Lottable02,
             @cLottable03 = Lottable03,
             @dLottable04 = Lottable04,
             @dLottable05 = Lottable05,
             @cLottable06 = Lottable06,
             @cLottable07 = Lottable07,
             @cLottable08 = Lottable08,
             @cLottable09 = Lottable09,
             @cLottable10 = Lottable10,
             @cLottable11 = Lottable11,
             @cLottable12 = Lottable12,
             @dLottable13 = Lottable13,
             @dLottable14= Lottable14,
             @dLottable15 = Lottable15
      FROM DBO.LOTATTRIBUTE WITH (NOLOCK)
      WHERE Lot = @cLot
      
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 4, 
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',      -- SourceKey
         @nFunc   -- SourceType

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY_Avail = 0
         SET @nMQTY_Avail = @nQTY_Avail
         SET @nPQTY = 0
         SET @nMQTY = @nQTY
      END
      ELSE
      BEGIN
         SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
         SET @nPQTY = @nQTY / @nPUOM_Div
         SET @nMQTY = @nQTY % @nPUOM_Div
      END

      -- Extended update
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nAfterStep      INT,           ' +
               '@nInputKey       INT,           ' + 
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 0, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END


      EXEC RDT.rdt_STD_EventLog
       @cActionType = '3',
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey,
       @cLocation   = @cFromLOC,
       @cID         = @cFromID,
       @cSKU        = @cSKU,
       @nStep       = @nStep

      -- Prep next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField08 = '' -- @cPUOM_Desc
         SET @cOutField09 = '' -- @nPQTY_Avail
         SET @cOutField10 = '' -- @nPQTY

         SET @cFieldAttr10 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField08 = @cPUOM_Desc
         SET @cOutField09 = CAST( @nPQTY_Avail AS NVARCHAR( 7))
         SET @cOutField10 = CASE WHEN @nPQTY = 0 THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 7)) END
      END
      SET @cOutField11 = @cMUOM_Desc
      SET @cOutField12 = CAST( @nMQTY_Avail AS NVARCHAR( 7))
      SET @cOutField13 = CASE WHEN @cDefaultQTY <> ''  THEN @cDefaultQTY
                              WHEN @nMQTY = 0 THEN '' 
                              ELSE CAST( @nMQTY AS NVARCHAR( 7)) 
                         END
      SET @cOutField14 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
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
      -- (Vicky02) - End

      -- Go back to assist task manager
      SET @nFunc = 1814
      SET @nScn = 4060
      SET @nStep = 1

      SET @cOutField01 = ''  -- From ID
      SET @cOutField02 = ''  -- Case ID
      GOTO QUIT
   END

   GOTO Quit

   Step_3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cSKU = ''
      SET @cOutField03 = '' -- SKU
   END
END
GOTO Quit


/********************************************************************************
Step 4. Scn = 1033. QTY screen
   FromLOC (field01)
   FromID  (field02)
   SKU     (field03)
   Desc1   (field04)
   Desc2   (field05)
   UOM     (field06, field09)
   QTY AVL (field07, field10)
   QTY MV  (field08, field11, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cPQTY NVARCHAR( 7)
      DECLARE @cMQTY NVARCHAR( 7)

      -- Screen mapping
      SET @cPQTY = @cInField10
      SET @cMQTY = @cInField13

      -- Retain the key-in value
      SET @cOutField08 = @cInField10 -- Pref QTY
      SET @cOutField11 = @cInField13 -- Master QTY

      -- Validate PQTY
      IF ISNULL(@cPQTY, '') = '' SET @cPQTY = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 52160
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 10 -- PQTY
         GOTO Step_4_Fail
      END

      -- Validate MQTY
      IF ISNULL(@cMQTY, '')  = '' SET @cMQTY  = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 52161
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 13 -- MQTY
         GOTO Step_4_Fail
      END

      -- Calc total QTY in master UOM
      SET @nPQTY = CAST( @cPQTY AS INT)
      SET @nMQTY = CAST( @cMQTY AS INT)
      SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM

      SET @nQTY = @nQTY + @nMQTY

      -- Calc prepack QTY
      IF @cPrePackIndicator = '2'
         IF @nPackQtyIndicator > 1
            SET @nQTY = @nQTY * @nPackQtyIndicator

      -- Validate QTY
      IF @nQTY = 0
      BEGIN
         SET @nErrNo = 52162
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY needed'
         GOTO Step_4_Fail
      END

      -- Validate QTY to move more than QTY avail
      IF @nQTY > @nQTY_Avail
      BEGIN
         SET @nErrNo = 52163
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTYAVL NotEnuf'
         GOTO Step_4_Fail
      END

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

      -- Prepare next screen var
      SET @cOutField01 = @cFromID
      SET @cOutField02 = @cSuggToLOC
      SET @cOutField03 = CASE WHEN @cDefaultToLoc = '1' THEN @cSuggToLOC ELSE '' END   -- FinalLOC
      
      -- Set the entry point
      SET @nScn  = 4080
      SET @nStep = 1
   END

   IF @nInputKey = 0 -- Esc or No
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

      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cFromId
      SET @cOutField03 = ''

      -- Set the entry point
      SET @nScn  = 4082
      SET @nStep = 3
   END

   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cFieldAttr10 = ''

      IF @cPUOM_Desc = ''
         -- Pref QTY is always enable (as screen defination). When reach error, it will quit directly and forgot
         -- to disable the Pref QTY field. So centralize disable it here for all fail condition
         -- Disable pref QTY field
         SET @cFieldAttr10 = 'O' 


      SET @cOutField10 = '' -- ActPQTY
      SET @cOutField13 = '' -- ActMQTY
   END
END
GOTO Quit

/********************************************************************************
Step 5. Screen = 3125. Multi SKU
   SKU         (Field01)
   SKUDesc1    (Field02)
   SKUDesc2    (Field03)
   SKU         (Field04)
   SKUDesc1    (Field05)
   SKUDesc2    (Field06)
   SKU         (Field07)
   SKUDesc1    (Field08)
   SKUDesc2    (Field09)
   Option      (Field10, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,
         'CHECK',
         @cMultiSKUBarcode,
         @cStorerKey,
         @cActSKU  OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
      END

      SET @cSKU = @cActSKU
   END

   -- Get SKU info
   SELECT
      @cSKUDescr = S.DescR,
      @cPrePackIndicator = PrePackIndicator,
      @nPackQtyIndicator = ISNULL( PackQtyIndicator, 0),
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
         END AS INT), 
      @cLottableCode = S.LottableCode
   FROM dbo.SKU S (NOLOCK)
      INNER JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)
   WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

   SET @cNewTask = ''

   SELECT TOP 1 
            @cNewTask = TaskDetailKey,
            @nQTY_Avail = Qty
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE Sku = @cSKU
   AND   FromLoc = @cFromLOC
   AND   FromID = @cFromID
   AND   [Status] = '0'
   AND   TaskType = @cTTMTaskType
   ORDER BY TaskDetailKey

   -- Validate not QTY
   IF @nQTY_Avail = 0 OR @nQTY_Avail IS NULL OR @cNewTask = ''
   BEGIN
      SET @nErrNo = 52164
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No QTY to move'
      GOTO Quit
   END

   SET @cTaskDetailKey = @cNewTask

   -- Get task info after get new taskdetailkey (refresh task info)
   SELECT
      @cTTMTaskType = TaskType,
      @cStorerKey   = Storerkey,
      @cFromID      = FromID,
      @cFromLOC     = FromLOC,
      @cSuggToLOC   = ToLOC,
      @cSuggSKU     = Sku,
      @cSourceKey   = SourceKey
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey
      
   -- Extended update
   IF @cExtendedValidateSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' +
            '@cStorerKey      NVARCHAR( 15), ' +
            '@cFacility       NVARCHAR(  5), ' +
            '@cFromLOC        NVARCHAR( 10), ' +
            '@cFromID         NVARCHAR( 18), ' +
            '@cSKU            NVARCHAR( 20), ' +
            '@nQTY            INT,           ' +
            '@cToID           NVARCHAR( 18), ' +
            '@cToLOC          NVARCHAR( 10), ' +
            '@nErrNo          INT OUTPUT,    ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cFromLOC, @cFromID, @cSKU, @nQTY, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END
   END

   SELECT @cLot = Lot
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cSourceKey
      
   SELECT @cLottable01 = Lottable01,
            @cLottable02 = Lottable02,
            @cLottable03 = Lottable03,
            @dLottable04 = Lottable04,
            @dLottable05 = Lottable05,
            @cLottable06 = Lottable06,
            @cLottable07 = Lottable07,
            @cLottable08 = Lottable08,
            @cLottable09 = Lottable09,
            @cLottable10 = Lottable10,
            @cLottable11 = Lottable11,
            @cLottable12 = Lottable12,
            @dLottable13 = Lottable13,
            @dLottable14= Lottable14,
            @dLottable15 = Lottable15
   FROM DBO.LOTATTRIBUTE WITH (NOLOCK)
   WHERE Lot = @cLot
      
   -- Dynamic lottable
   EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 4, 4, 
      @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
      @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
      @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
      @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
      @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
      @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
      @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
      @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
      @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
      @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
      @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
      @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
      @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
      @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
      @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
      @nMorePage   OUTPUT,
      @nErrNo      OUTPUT,
      @cErrMsg     OUTPUT,
      '',      -- SourceKey
      @nFunc   -- SourceType

   -- Convert to prefer UOM QTY
   IF @cPUOM = '6' OR -- When preferred UOM = master unit
      @nPUOM_Div = 0 -- UOM not setup
   BEGIN
      SET @cPUOM_Desc = ''
      SET @nPQTY_Avail = 0
      SET @nMQTY_Avail = @nQTY_Avail
      SET @nPQTY = 0
      SET @nMQTY = @nQTY
   END
   ELSE
   BEGIN
      SET @nPQTY_Avail = @nQTY_Avail / @nPUOM_Div -- Calc QTY in preferred UOM
      SET @nMQTY_Avail = @nQTY_Avail % @nPUOM_Div -- Calc the remaining in master unit
      SET @nPQTY = @nQTY / @nPUOM_Div
      SET @nMQTY = @nQTY % @nPUOM_Div
   END

   -- Extended update
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nAfterStep      INT,           ' +
            '@nInputKey       INT,           ' + 
            '@cTaskdetailKey  NVARCHAR( 10), ' +
            '@cFinalLOC       NVARCHAR( 10), ' +
            '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo          INT           OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 0, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         SET @cOutField15 = @cExtendedInfo
      END
   END


   EXEC RDT.rdt_STD_EventLog
      @cActionType = '3',
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @cLocation   = @cFromLOC,
      @cID         = @cFromID,
      @cSKU        = @cSKU,
      @nStep       = @nStep

   -- Prep next screen var
   SET @cOutField01 = @cSKU
   SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1
   SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2
   IF @cPUOM_Desc = ''
   BEGIN
      SET @cOutField08 = '' -- @cPUOM_Desc
      SET @cOutField09 = '' -- @nPQTY_Avail
      SET @cOutField10 = '' -- @nPQTY

      SET @cFieldAttr10 = 'O'
   END
   ELSE
   BEGIN
      SET @cOutField08 = @cPUOM_Desc
      SET @cOutField09 = CAST( @nPQTY_Avail AS NVARCHAR( 7))
      SET @cOutField10 = CASE WHEN @nPQTY = 0 THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 7)) END
   END
   SET @cOutField11 = @cMUOM_Desc
   SET @cOutField12 = CAST( @nMQTY_Avail AS NVARCHAR( 7))
   SET @cOutField13 = CASE WHEN @cDefaultQTY <> ''  THEN @cDefaultQTY
                           WHEN @nMQTY = 0 THEN '' 
                           ELSE CAST( @nMQTY AS NVARCHAR( 7)) 
                        END
   SET @cOutField14 = CASE WHEN @cPrePackIndicator = '2' THEN CAST( @nPackQtyIndicator AS NVARCHAR( 3)) ELSE '' END

   -- Go to Qty screen
   SET @nScn = @nScn - 1
   SET @nStep = @nStep - 1
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      Facility  = @cFacility,
      -- UserName  = @cUserName,

      V_StorerKey = @cStorerKey,
      V_ID        = @cFromID,
      V_LOC       = @cFromLOC,
      V_TaskDetailKey = @cTaskDetailKey,
      V_SKUDescr  = @cSKUDescr,
      V_UOM       = @cPUOM,
      V_PQTY      = @nPQTY,
      V_MQTY      = @nMQTY,
      V_PUOM_Div  = @nPUOM_Div,
      V_Lottable01 = @cLottable01,  
      V_Lottable02 = @cLottable02,  
      V_Lottable03 = @cLottable03,  
      V_Lottable04 = @dLottable04,  
      V_Lottable05 = @dLottable05,  
      V_Lottable06 = @cLottable06,  
      V_Lottable07 = @cLottable07,  
      V_Lottable08 = @cLottable08,  
      V_Lottable09 = @cLottable09,  
      V_Lottable10 = @cLottable10,  
      V_Lottable11 = @cLottable11,  
      V_Lottable12 = @cLottable12,  
      V_Lottable13 = @dLottable13,  
      V_Lottable14 = @dLottable14,  
      V_Lottable15 = @dLottable15,  
      
      V_Integer1 = @nQTY_Avail,
      V_Integer2 = @nPQTY_Avail,
      V_Integer3 = @nMQTY_Avail,
      V_Integer4 = @nQTY,
      V_Integer5 = @nPackQtyIndicator,
      
      V_FromStep = @nFromStep,
      V_FromScn  = @nFromScn,

      V_String1  = @cAreakey,
      V_String2  = @cTTMStrategykey,
      V_String3  = @cTTMTaskType,      
      V_String4  = @cSuggToLOC,
      V_String5  = @cExtendedValidateSP,
      V_String6  = @cExtendedUpdateSP,
      V_String7  = @cOverwriteToLOC,
      V_String8  = @cExtendedInfoSP,
      V_String9  = @cExtendedInfo,
      V_String10 = @cDefaultToLoc,
      V_String11 = @cASTMVVerifySKU,
      V_String12 = @cSourceKey,
      V_String13 = @cDecodeSP,
      V_String14 = @cMultiSKUBarcode,
      V_String15 = @cPrePackIndicator,
      V_String16 = @cLottableCode,
      V_String17 = @cDefaultQTY,

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
   IF (@nFunc <> 1816 AND @nStep = 0) AND -- Other module that begin with step 0
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