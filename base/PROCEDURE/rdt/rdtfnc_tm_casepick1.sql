SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/********************************************************************************/
/* Store procedure: rdtfnc_TM_CasePick                                          */
/* Copyright      : Maersk                                                      */
/*                                                                              */
/* Purpose: case pick                                                           */
/*                                                                              */
/* Modifications log:                                                           */
/*                                                                              */
/* Date       Rev    Author     Purposes                                        */
/* 2014-12-17 1.0    Ung        SOS327467 Created                               */
/* 2016-09-30 1.1    Ung        Performance tuning                              */
/* 2017-07-31 1.2    Ung        WMS-2475 DropID add RDTFormat                   */
/* 2018-07-10 1.3    Ung        WMS-4221 Fix ExtendedUpdateSP param             */
/* 2018-08-31 1.4    Ung        WMS-5943 Add ExtendedInfo at screen 1, 2        */
/* 2018-11-21 1.5    Ung        WMS-3273 Add fully short                        */
/* 2019-02-27 1.6    Ung        WMS-8058 Add SwapUCCSP, LOCLookupSP             */
/*                              Fix PQTY not shown if DisableQTYField           */
/* 2020-02-21 1.7    YeeKung    WMS-12082 Add ExtendedValidate(yeekung01)       */
/* 2019-05-14 1.8    James      WMS-9920 Add MultiSKUBarcode (james01)          */
/* 2022-09-09 1.9    YeeKung    WMS-20712 Add overwritetoloc (Yeekung02)        */
/* 2023-03-24 2.0    Ung        WMS-22020 Add dynamic lottable                  */
/* 2023-05-16 2.1    Ung        WMS-22435 Add DecodeSP                          */
/*                              Expand SKU field to max                         */
/* 2023-06-20 2.2    Ung        WMS-22834 Add DispStyleColorSize                */
/* 2024-03-12 2.3    CYU027     UWP-15734 Add Extended Print SP                 */
/* 2024-04-10 2.4    Dennis     UWP-16909 Check Digit                           */
/* 2024-07-08 2.5    JHU151     FCR-330 SSCC code generator                     */
/* 2024-10-08 2.6    PXL009     FCR-872 Auto Generated Dropid                   */
/* 2024-10-24 2.7    YYS027     FCR-989 Min Max Replenishment                   */
/*            2.7.1  YYS027     move new screen to rdt_1812ExtScn04             */
/********************************************************************************/

CREATE   PROC [RDT].[rdtfnc_TM_CasePick1](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF
DECLARE @cReplenFlag    NVARCHAR(20)

-- Misc variable
DECLARE
   @b_success           INT,
   @cFromLOC            NVARCHAR(10),
   @cToLOC              NVARCHAR(10),
   @cFromID             NVARCHAR(18),
   @cUserPosition       NVARCHAR(1),
   @nTotPickQty         INT,
   @c_outstring         NVARCHAR(255),
   @cOption             NVARCHAR(1),
   @cNextTaskDetailKey  NVARCHAR(10),
   @cReasonCode         NVARCHAR(10),
   @nRowRef             INT,
   @nCurrentTranCount   INT,
   @cUCC                NVARCHAR( 20),
   @cSKU                NVARCHAR(20),
   @cPQTY               NVARCHAR( 5),
   @cMQTY               NVARCHAR( 5),
   @cSQL                NVARCHAR(MAX),
   @cSQLParam           NVARCHAR(MAX),
   @cExtendedScreenSP   NVARCHAR( 20),
   @cExtScnSP           NVARCHAR( 20),
   @nAction             INT,
   @nAfterScn           INT,
   @nAfterStep          INT,
   @cLocNeedCheck       NVARCHAR( 20),
   @nMorePage           INT

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

   @cTaskDetailKey      NVARCHAR(10),
   @cTaskStorer         NVARCHAR(15),
   @cDropID             NVARCHAR(20),
   @cPickMethod         NVARCHAR(10),
   @cSuggToLOC          NVARCHAR(10),
   @cListKey            NVARCHAR(10),
   @cDisableQTYField    NVARCHAR(1),
   @cSwapTaskSP         NVARCHAR(20),
   @cOverwriteToLOC     NVARCHAR(1),    --(yeekung02)

   @cPUOM_Desc          NCHAR( 5),
   @cMUOM_Desc          NCHAR( 5),
   @nPUOM_Div           INT, -- UOM divider
   @nPQTY_RPL           INT,
   @nMQTY_RPL           INT,
   @nQTY_RPL            INT,
   @nPQTY               INT,
   @nMQTY               INT,
   @nQTY                INT,
   @nFromStep           INT,
   @nFromScn            INT,
   @cBarcode            NVARCHAR( MAX),
   @cLottableCode       NVARCHAR( 20),
   @cDecodeLabelNo      NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cDefaultToLOC       NVARCHAR( 10),
   @cMoveQTYAlloc       NVARCHAR( 1),
   @cSKUValidated       NVARCHAR( 2),
   @cDefaultFromID      NVARCHAR( 1),
   @cExtendedInfoSP     NVARCHAR(20),
   @cExtendedInfo1      NVARCHAR(20),
   @cExtendedPrintSP    NVARCHAR(20),
   @cGetNextTaskSP      NVARCHAR(20),
   @cDisableQTYFieldSP  NVARCHAR(20),
   @cExtendedValidateSP NVARCHAR(20),
   @cSwapUCCSP          NVARCHAR(20),
   @cLOCLookupSP        NVARCHAR(20),
   @cDecodeSP           NVARCHAR(20),
   @cDispStyleColorSize NVARCHAR( 1),
   @cAutoGenDROPIDSP    NVARCHAR(20),
   @tExtData            VariableTable,
   @cAutoID             NVARCHAR( 18),

   @cAreaKey            NVARCHAR(10),
   @cTTMStrategykey     NVARCHAR(10),
   @cTTMTaskType        NVARCHAR(10),
   @cRefKey01           NVARCHAR(20),
   @cRefKey02           NVARCHAR(20),
   @cRefKey03           NVARCHAR(20),
   @cRefKey04           NVARCHAR(20),
   @cRefKey05           NVARCHAR(20),
   @cMultiSKUBarcode    NVARCHAR( 1),  -- (james01)
   @tExtScnData         VariableTable, --(JHU151)

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),    @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),    @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),    @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),    @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),    @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),    @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),    @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),    @cFieldAttr08 NVARCHAR( 1),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),    @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),    @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),    @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),    @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),    @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),    @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1),    
    
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

   @cTaskDetailKey  = V_TaskDetailKey,
   @cBarcode        = V_Barcode,
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
   @dLottable05     = V_Lottable05,
   @cLottable06     = V_Lottable06,
   @cLottable07     = V_Lottable07,
   @cLottable08     = V_Lottable08,
   @cLottable09     = V_Lottable09,
   @cLottable10     = V_Lottable10,
   @cLottable11     = V_Lottable11,
   @cLottable12     = V_Lottable12,
   @dLottable13     = V_Lottable13,
   @dLottable14     = V_Lottable14,
   @dLottable15     = V_Lottable15,
   @nQTY            = V_QTY,
   @nPQTY           = V_PQTY,
   @nMQTY           = V_MQTY,
   @nQTY_RPL        = V_TaskQTY,
   @nPQTY_RPL       = V_PTaskQTY,
   @nMQTY_RPL       = V_MTaskQTY,
   @nPUOM_Div       = V_PUOM_Div,
   @nFromScn        = V_FromScn,
   @nFromStep       = V_FromStep,

   @cAreaKey           = V_String1,
   @cTaskStorer        = V_String2,
   @cDropID            = V_String3,
   @cPickMethod        = V_String4,
   @cSuggToloc         = V_String5,
   @cReasonCode        = V_String6,
   @cListKey           = V_String7,
   @cDisableQTYField   = V_String8,
   @cSwapTaskSP        = V_String9,
   @cMUOM_Desc         = V_String10,
   @cPUOM_Desc         = V_String11,
   @cMultiSKUBarcode   = V_String12,
   @cLottableCode      = V_String13,

   @cDispStyleColorSize= V_String17,
   @cDecodeSP          = V_String18,
   @cLOCLookupSP       = V_String19,
   @cSwapUCCSP         = V_String20,
   @cDecodeLabelNo     = V_String21,
   @cExtendedUpdateSP  = V_String22,
   @cDefaultToLOC      = V_String23,
   @cMoveQTYAlloc      = V_String24,
   @cSKUValidated      = V_String25,
   @cDefaultFromID     = V_String26,
   @cExtendedInfoSP    = V_String27,
   @cExtendedInfo1     = V_String28,
   @cGetNextTaskSP     = V_String29,
   @cDisableQTYFieldSP = V_String30,
   @cExtendedValidateSP= V_String31,
   @cExtendedPrintSP   = V_String41,

   @cAreakey           = V_String32,
   @cTTMStrategykey    = V_String33,
   @cTTMTaskType       = V_String34,
   @cRefKey01          = V_String35,
   @cRefKey02          = V_String36,
   @cRefKey03          = V_String37,
   @cRefKey04          = V_String38,
   @cRefKey05          = V_String39,
   @cOverwriteToLOC    = V_String40,
   @cExtScnSP          = V_String42,
   @cAutoGenDROPIDSP   = V_String43,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01  = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02  = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03  = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04  = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05  = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06  = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07  = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08  = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09  = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10  = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11  = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12  = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13  = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14  = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15  = FieldAttr15

FROM   RDT.RDTMOBREC WITH (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1812
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Initialize
   IF @nStep = 1 GOTO Step_1   -- Scn = 4020 DropID
   IF @nStep = 2 GOTO Step_2   -- Scn = 4021 FromLOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 4022 FromID
   IF @nStep = 4 GOTO Step_4   -- Scn = 4023 SKU, QTY
   IF @nStep = 5 GOTO Step_5   -- Scn = 4024 Cont next replen task / Close pallet
   IF @nStep = 6 GOTO Step_6   -- Scn = 4025 To LOC
   IF @nStep = 7 GOTO Step_7   -- Scn = 4026 Pallet is close. Next task / Exit
   IF @nStep = 8 GOTO Step_8   -- Scn = 4027 Short pick / Close pallet
   IF @nStep = 9 GOTO Step_9   -- Scn = 2100 Reason code
   IF @nStep = 99  GOTO Step_99  -- Scn = Extended Screen   -- Scn = 4028 Is the location completely empty?
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
   DECLARE @nTransit INT
   SELECT
      @cTTMTaskType = TaskType,
      @cStorerKey   = Storerkey,
      @cSuggID      = FromID,
      @cSuggLOT     = LOT,
      @cSuggFromLOC = FromLOC,
      @cSuggToLOC   = ToLOC,
      @cSuggSKU     = SKU,
      @nQTY_RPL     = QTY,
      @cPickMethod  = PickMethod,
      @nTransit     = TransitCount,
      @cDropID      = DropID,
      @cListKey     = ListKey
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey

   -- Initial var
   SET @cUserPosition = '1'
   SET @cDropID = ''
   SET @cReasonCode = ''
   SET @cDisableQTYField = ''

   -- Get preferred UOM
   SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName

   -- Get storer configure
   SET @cDefaultFromID = rdt.rdtGetConfig( @nFunc, 'DefaultFromID', @cStorerKey)
   SET @cDispStyleColorSize = rdt.RDTGetConfig( @nFunc, 'DispStyleColorSize', @cStorerKey)
   SET @cLOCLookupSP = rdt.RDTGetConfig( @nFunc, 'LOCLookupSP', @cStorerKey)
   SET @cMoveQTYAlloc = rdt.RDTGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)
   SET @cOverwriteToLOC = rdt.rdtGetConfig( @nFunc, 'OverwriteToLOC', @cStorerKey) --(yeekung02)

   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedPrintSP = rdt.RDTGetConfig( @nFunc, 'ExtendedPrintSP', @cStorerKey)
   IF @cExtendedPrintSP = '0'
      SET @cExtendedPrintSP = ''
   SET @cGetNextTaskSP = rdt.RDTGetConfig( @nFunc, 'GetNextTaskSP', @cStorerKey)
   IF @cGetNextTaskSP = '0'
      SET @cGetNextTaskSP = ''
   SET @cDefaultToLOC = rdt.rdtGetConfig( @nFunc, 'DefaultToLOC', @cStorerKey)
   IF @cDefaultToLOC = '0'
      SET @cDefaultToLOC = ''
   SET @cDisableQTYFieldSP = rdt.RDTGetConfig( @nFunc, 'DisableQTYFieldSP', @cStorerKey)
   IF @cDisableQTYFieldSP = '0'
      SET @cDisableQTYFieldSP = ''
   SET @cSwapTaskSP = rdt.RDTGetConfig( @nFunc, 'SwapTaskSP', @cStorerKey)
   IF @cSwapTaskSP = '0'
      SET @cSwapTaskSP = ''
   SET @cSwapUCCSP = rdt.RDTGetConfig( @nFunc, 'SwapUCCSP', @cStorerKey)
   IF @cSwapUCCSP = '0'
      SET @cSwapUCCSP = ''

   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)

   SET @cExtScnSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtScnSP = '0'
      SET @cExtScnSP = ''

   SET @cAutoGenDROPIDSP = [rdt].[RDTGetConfig]( @nFunc, 'AutoGenDropID', @cStorerKey)
   IF @cAutoGenDROPIDSP = '0'
      SET @cAutoGenDROPIDSP = ''

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

   -- Extended update
   IF @cExtendedUpdateSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cDropID, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep '
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' +
            '@cTaskdetailKey  NVARCHAR( 10), ' +
            '@cDropID         NVARCHAR( 20), ' +
            '@nQTY            INT,           ' +
            '@cToLOC          NVARCHAR( 10), ' +
            '@nErrNo          INT OUTPUT,    ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
            '@nAfterStep      INT            '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cDropID, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

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
   SET @nScn  = 4020
   SET @nStep = 1

   -- Prompt DropID only if partial pallet replen and initial task
   IF @cPickMethod = 'PP' AND @nTransit = 0
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cDropID

      -- Remain in same screen
      -- SET @nScn = @nScn + 1
      -- SET @nStep = @nStep + 1
   END
   ELSE
   BEGIN
      SET @nQTY = @nQTY_RPL

      -- Prepare next screen var
      SET @cOutField01 = @cPickMethod
      SET @cOutField02 = @cDropID
      SET @cOutField03 = @cSuggFromLOC
      SET @cOutField04 = '' -- FromLOC
      SET @cOutField10 = '' -- ExtendedInfo

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @cAutoGenDROPIDSP <> '' AND @nStep = 1
   BEGIN
      -- Auto generate DROPID
      EXEC rdt.rdt_AutoGenID @nMobile, @nFunc, @nStep, @cLangCode
         ,@cAutoGenDROPIDSP
         ,@tExtData
         ,@cAutoID  OUTPUT
         ,@nErrNo   OUTPUT
         ,@cErrMsg  OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      SET @cOutField01 = @cAutoID
   END

   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo1 = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@cTaskdetailKey  NVARCHAR( 10), ' +
            '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo          INT           OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
            '@nAfterStep      INT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 0, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

         SET @cOutField10 = @cExtendedInfo1
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


END
GOTO Quit


/********************************************************************************
Step 1. Screen = 4020. Please take an empty pallet
    DROPID   (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cDropID   = @cInField01

      -- Check blank DropID
      IF @cDropID = ''
      BEGIN
         SET @nErrNo = 51351
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID needed
         GOTO Step_1_Fail
      END

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DROPID', @cDropID) = 0
      BEGIN
         SET @nErrNo = 51383
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_1_Fail
      END

      -- Check if DropID is use by others
      IF EXISTS( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE DropID = @cDropID
            AND Status NOT IN ('9','X')
            AND UserKey <> @cUserName)
      BEGIN
         SET @nErrNo = 51352
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID in used
         GOTO Step_1_Fail
      END

      -- Check if DropID already exist
      IF EXISTS( SELECT 1
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            INNER JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND LLI.ID = @cDropID
            AND LLI.QTY > 0)
      BEGIN
         SET @nErrNo = 51353
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID in used
         GOTO Step_1_Fail
      END

      -- Check DropID exist
      IF EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cDropID)
      BEGIN
         SET @nErrNo = 51354
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID used
         GOTO Step_1_Fail
      END

/*
      BEGIN TRAN

      -- Delete used DropID
      IF EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cDropID AND Status = '9')
      BEGIN
         -- Delete DropIDDetail
         DELETE dbo.DropIDDetail WHERE DropID = @cDropID
         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 51355
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelDropIDFail
            GOTO Step_1_Fail
         END

         -- Delete used DropID
         DELETE dbo.DropID WHERE DropID = @cDropID AND Status = '9'
         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 51356
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelDropIDFail
            GOTO Step_1_Fail
         END
      END

      COMMIT TRAN
*/

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cDropID, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cDropID, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cDropID, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
               '@nAfterStep      INT            '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cDropID, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Prepare next screen variable
      SET @cOutField01 = @cPickMethod
      SET @cOutField02 = @cDropID
      SET @cOutField03 = @cSuggFromLOC
      SET @cOutField04 = '' -- FromLOC
      SET @cOutField10 = '' -- ExtendedInfo

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo1 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
               '@nAfterStep      INT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 1, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

            SET @cOutField10 = @cExtendedInfo1
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      /*
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
      */
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
      SET @nStep = @nStep + 8 -- Step 9

   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cDropID = ''
      SET @cOutField01 = '' -- DropID
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen = 4021. From LOC screen
    PICKTYPE (Field01)
    DROP ID  (Field02)
    SUGG LOC (Field03)
    FROM LOC (Field04, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromLOC = @cInField04
      SET @cLocNeedCheck = @cInField04

      -- Check blank FromLOC
      IF @cFromLOC = ''
      BEGIN
         SET @nErrNo = 51357
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FromLOC needed
         GOTO Step_2_Fail
      END

      SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '1812ExtendedScreenSP', @cStorerKey), '')
      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_1812ExtScnEntry] 
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
               GOTO Step_2_Fail
            
            SET @cFromLOC = @cLocNeedCheck
         END
      END

      -- LOC lookup
      IF @cLOCLookupSP = '1'
      BEGIN
         EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
            @cFromLOC OUTPUT,
            @nErrNo   OUTPUT,
            @cErrMsg  OUTPUT
         IF @nErrNo <> 0
            GOTO Step_2_Fail
      END

      -- Check if FromLOC match
      IF @cFromLOC <> @cSuggFromLOC
      BEGIN
         SET @nErrNo = 51358
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FromLOC Diff
        GOTO Step_2_Fail
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cDropID, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
               '@nAfterStep      INT            '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cDropID, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Prepare Next Screen
      SET @cOutField01 = @cPickMethod
      SET @cOutField02 = @cDropID
      SET @cOutField03 = @cSuggFromLOC
      SET @cOutField04 = @cSuggID
      SET @cOutField05 = CASE WHEN @cDefaultFromID = '1' THEN @cSuggID ELSE '' END -- FromID
      SET @cOutField10 = '' -- ExtendedInfo

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo1 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
               '@nAfterStep      INT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 2, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

            SET @cOutField10 = @cExtendedInfo1
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
/*
      SET @cDropID = ''
      SET @cOutField01 = '' -- DropID

      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
*/
      -- Partial pallet
      IF @cPickMethod = 'PP'
      BEGIN
         -- Not yet picked anything
         IF NOT EXISTS( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) WHERE DropID = @cDropID AND UserKey = @cUserName AND Status = '5')
         BEGIN
            -- Prepare prev screen var
            SET @cDropID = ''
            SET @cOutField01 = '' -- DropID

            IF @cAutoGenDROPIDSP <> ''
            BEGIN
               -- Auto generate DROPID
               EXEC rdt.rdt_AutoGenID @nMobile, @nFunc, @nStep, @cLangCode
                  ,@cAutoGenDROPIDSP
                  ,@tExtData
                  ,@cAutoID  OUTPUT
                  ,@nErrNo   OUTPUT
                  ,@cErrMsg  OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit

               SET @cOutField01 = @cAutoID
            END

            SET @nScn  = @nScn - 1
            SET @nStep = @nStep - 1

            GOTO Quit
         END
      END

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
      SET @nStep = @nStep + 7 -- Step 9
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cFromLOC = ''
      SET @cOutfield04 = '' -- FromLOC
   END
END
GOTO Quit

/********************************************************************************
Step 3. Screen = 4022. FromID screen
    PICKTYPE (Field01)
    DROP ID  (Field02)
    FROM LOC (Field03)
    SUGG ID  (Field04)
    FROM ID  (Field05, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromID  = @cInField05

      -- Check FromID match
      IF @cFromID <> @cSuggID
      BEGIN
         IF @cSwapTaskSP = ''
         BEGIN
            SET @nErrNo = 51359
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID not match
            GOTO Step_3_Fail
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
               @nQTY_RPL     = QTY,
               @cPickMethod  = PickMethod,
               @nTransit     = TransitCount,
               @cDropID      = CASE WHEN ISNULL(DROPID,'')='' THEN @cDropID ELSE DROPID END , --(yeekung02)
               @cListKey     = ListKey
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE TaskDetailKey = @cTaskDetailKey

         END
      END

      -- Check QTYAlloc, QTYReplen
      IF @cPickMethod = 'FP'
      BEGIN
         IF EXISTS( SELECT 1
            FROM dbo.LOTxLOCxID WITH (NOLOCK)
            WHERE LOC = @cFromLOC
               AND ID = @cFromID
               AND (QTYReplen > 0 OR
                    QTYAllocated > (CASE WHEN @cMoveQTYAlloc = '1' THEN QTYAllocated ELSE 0 END)))
         BEGIN
            SET @nErrNo = 51360
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYALC/QTYRPL
            GOTO Step_3_Fail
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cDropID, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
               '@nAfterStep      INT            '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cDropID, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Full pallet
      IF @cPickMethod = 'FP'
      BEGIN
         -- Prepare next screen var
         SET @cToLOC = ''
         SET @cOutField01 = @cSuggFromLOC
         SET @cOutField02 = @cSuggToLOC
         SET @cOutField03 = CASE WHEN @cDefaultToLOC = '1' THEN @cSuggToLOC ELSE '' END

         -- Go to ToLOC screen
         SET @nFromScn = @nScn
         SET @nFromStep = @nStep
         SET @nScn = @nScn + 3
         SET @nStep = @nStep + 3
      END

      -- Partial pallet
      IF @cPickMethod = 'PP'
      BEGIN
         -- Get SKU info
         SELECT
            @cSKUDesc = 
               CASE WHEN @cDispStyleColorSize = '0'
                    THEN ISNULL( S.Descr, '')
                    ELSE CAST( S.Style AS NCHAR(20)) +
                         CAST( S.Color AS NCHAR(10)) +
                         CAST( S.Size  AS NCHAR(10))
               END,
            @cLottableCode = S.LottableCode, 
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

         SELECT 
            @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL,  @dLottable05 = NULL,
            @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',    @cLottable10 = '',
            @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL,  @dLottable15 = NULL

         -- Get lottable
         SELECT
            @cLottable01 = LA.Lottable01,
            @cLottable02 = LA.Lottable02,
            @cLottable03 = LA.Lottable03,
            @dLottable04 = LA.Lottable04,
            @dLottable05 = LA.Lottable05,
            @cLottable06 = LA.Lottable06,
            @cLottable07 = LA.Lottable07,
            @cLottable08 = LA.Lottable08,
            @cLottable09 = LA.Lottable09,
            @cLottable10 = LA.Lottable10,
            @cLottable11 = LA.Lottable11,
            @cLottable12 = LA.Lottable12,
            @dLottable13 = LA.Lottable13,
            @dLottable14 = LA.Lottable14,
            @dLottable15 = LA.Lottable15
         FROM dbo.LOTAttribute LA WITH (NOLOCK)
         WHERE LOT = @cSuggLOT

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

         -- Restore scanned carton QTY
         DECLARE @nCartonQTY INT
         SELECT @nCartonQTY = ISNULL( SUM( QTY), 0)
         FROM rdt.rdtFCPLog WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey

         IF @nCartonQTY = 0
            SET @cSKUValidated = '0'
         ELSE
            SET @cSKUValidated = '1'

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
            SET @nMQTY = @nCartonQTY
            SET @nMQTY_RPL = @nQTY_RPL
            SET @cFieldAttr14 = 'O' -- @nPQTY_PWY
         END
         ELSE
         BEGIN
            SET @nPQTY = 0
            SET @nMQTY = @nCartonQTY

            SET @nPQTY = @nCartonQTY / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY = @nCartonQTY % @nPUOM_Div -- Calc the remaining in master unit

            SET @nPQTY_RPL = @nQTY_RPL / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY_RPL = @nQTY_RPL % @nPUOM_Div -- Calc the remaining in master unit
         END

         -- Prepare next screen variable
         SET @cOutField01 = @cSuggSKU
         SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)
         SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)
         SET @cBarcode    = '' -- SKU
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cOutField11 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc
         SET @cOutField12 = CASE WHEN (@cPUOM = '6' OR @nPUOM_Div = 0) THEN '' ELSE CAST( @nPQTY_RPL AS NVARCHAR( 5)) END
         SET @cOutField13 = CAST( @nMQTY_RPL AS NVARCHAR( 5))
         SET @cOutField14 = CASE WHEN (@cPUOM = '6' OR @nPUOM_Div = 0) THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END -- PQTY
         SET @cOutField15 = CAST( @nMQTY AS NVARCHAR( 5)) -- MQTY
         EXEC rdt.rdtSetFocusField @nMobile, 'V_Barcode' -- SKU

         SET @nFromScn = @nScn
         SET @nFromStep = @nStep
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo1 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
               '@nAfterStep      INT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 3, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

            SET @cOutField10 = @cExtendedInfo1
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cFromLOC = ''
      SET @cOutField01 = @cPickMethod
      SET @cOutField02 = @cDropID
      SET @cOutField03 = @cSuggFromLOC
      SET @cOutField04 = '' -- FromLOC
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
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
               '@nAfterStep      INT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 3, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

            SET @cOutField10 = @cExtendedInfo1
         END
      END
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cFromID = ''
      SET @cOutField05 = '' -- FromID
   END
END
GOTO Quit


/********************************************************************************
Step 4. screen = 4023
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
    MQTY_RPL   (Field13)
    PQTY       (Field14, input)
    MQTY       (Field15, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cLabelNo NVARCHAR( 60)
      DECLARE @nUCCQTY  INT

      SET @nUCCQTY = 0

      -- Screen mapping
      SET @cLabelNo = LEFT( @cBarcode, 60) -- @cInField08
      SET @cSKU = LEFT( @cBarcode, 20) --@cInField08
      SET @cPQTY = CASE WHEN @cFieldAttr14 = 'O' THEN @cOutField14 ELSE @cInField14 END
      SET @cMQTY = CASE WHEN @cFieldAttr15 = 'O' THEN @cOutField15 ELSE @cInField15 END

      -- Retain value
      SET @cOutField14 = CASE WHEN @cFieldAttr14 = 'O' THEN @cOutField14 ELSE @cInField14 END -- PQTY
      SET @cOutField15 = CASE WHEN @cFieldAttr15 = 'O' THEN @cOutField15 ELSE @cInField15 END -- MQTY

      -- Check SKU blank
      IF @cLabelNo = '' AND @cSKUValidated = '0' -- False
      BEGIN
         SET @nErrNo = 51361
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need SKU
         EXEC rdt.rdtSetFocusField @nMobile, 'V_Barcode' -- SKU
         GOTO Step_4_Fail
      END

      -- Validate SKU
      IF @cLabelNo <> ''
      BEGIN
         IF @cLabelNo = '99' -- Fully short
         BEGIN
            SET @cSKUValidated = '99'
            SET @cPQTY = ''
            SET @cMQTY = '0'
            SET @cOutField14 = ''
            SET @cOutField15 = '0'
         END
         ELSE
         BEGIN
            DECLARE @cDecodeSKU  NVARCHAR( 20)
            DECLARE @nDecodeQTY  INT
            
            SET @cDecodeSKU = @cSKU
            SET @nDecodeQTY = @nUCCQTY
            
            -- Standard decode
            IF @cDecodeSP = '1'
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
            ELSE IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailKey, @cBarcode, ' +
                  ' @cFromID OUTPUT, @cSKU OUTPUT, @nQTY OUTPUT, @cUCC OUTPUT, @cDropID OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  ' @nMobile        INT,           ' +
                  ' @nFunc          INT,           ' +
                  ' @cLangCode      NVARCHAR( 3),  ' +
                  ' @nStep          INT,           ' +
                  ' @nInputKey      INT,           ' +
                  ' @cFacility      NVARCHAR( 5),  ' +
                  ' @cStorerKey     NVARCHAR( 15), ' +
                  ' @cTaskdetailKey NVARCHAR( 10),  ' +
                  ' @cBarcode       NVARCHAR( MAX), ' +
                  ' @cFromID        NVARCHAR( 18)  OUTPUT, ' +
                  ' @cSKU           NVARCHAR( 20)  OUTPUT, ' +
                  ' @nQTY           INT            OUTPUT, ' +
                  ' @cUCC           NVARCHAR( 20)  OUTPUT, ' +
                  ' @cDropID        NVARCHAR( 20)  OUTPUT, ' +
                  ' @nErrNo         INT            OUTPUT, ' +
                  ' @cErrMsg        NVARCHAR( 20)  OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailKey, @cBarcode,
                  @cFromID OUTPUT, @cDecodeSKU OUTPUT, @nDecodeQTY OUTPUT, @cUCC OUTPUT, @cDropID OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

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
                     GOTO Step_4_Fail

                  SET @cSKU    = ISNULL( @c_oFieled01, '')
                  SET @nUCCQTY = CAST( ISNULL( @c_oFieled05, '') AS INT)
                  SET @cUCC    = ISNULL( @c_oFieled08, '')
               END
            END

            -- Swap UCC (must be same FromLOC, FromID, SKU, QTY)
            IF @cSwapUCCSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cSwapUCCSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cSwapUCCSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cLabelNo, ' +
                     ' @cSKU OUTPUT, @cUCC OUTPUT, @nUCCQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                  SET @cSQLParam =
                     '@nMobile            INT,           ' +
                     '@nFunc              INT,           ' +
                     '@cLangCode          NVARCHAR( 3),  ' +
                     '@nStep              INT,           ' +
                     '@nInputKey          INT,           ' +
                     '@cTaskdetailKey     NVARCHAR( 10), ' +
                     '@cLabelNo           NVARCHAR( 60), ' +
                     '@cSKU               NVARCHAR( 20)  OUTPUT, ' +
                     '@cUCC               NVARCHAR( 20)  OUTPUT, ' +
                     '@nUCCQTY            INT            OUTPUT, ' +
                     '@nErrNo             INT            OUTPUT, ' +
                     '@cErrMsg            NVARCHAR( 20)  OUTPUT  '

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cLabelNo,
                     @cSKU OUTPUT, @cUCC OUTPUT, @nUCCQTY OUTPUT,  @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Quit

                  -- Reload task
                  SELECT
                     @cSuggLOT     = LOT,
                     @nQTY_RPL     = QTY
                  FROM dbo.TaskDetail WITH (NOLOCK)
                  WHERE TaskDetailKey = @cTaskDetailKey
               END
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
               SET @nErrNo = 51362
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
               EXEC rdt.rdtSetFocusField @nMobile, 'V_Barcode' -- SKU
               GOTO Step_4_Fail
            END

            -- Check multi SKU barcode
            IF @nSKUCnt > 1
            BEGIN
               IF @cMultiSKUBarcode IN ('1', '2')
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
                     'TASKDETAIL',    -- DocType
                     @cTaskdetailKey

                  -- No need display multi sku screen coz 1 taskdetail only 1 sku
                  IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
                     SET @nErrNo = 0

                  IF @nErrNo <> 0
                  BEGIN
                     GOTO Step_4_Fail
                     EXEC rdt.rdtSetFocusField @nMobile, 'V_Barcode' -- SKU
                  END
               END
               ELSE
               BEGIN
                  SET @nErrNo = 51363
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod
                  EXEC rdt.rdtSetFocusField @nMobile, 'V_Barcode' -- SKU
                  GOTO Step_4_Fail
               END
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
               SET @nErrNo = 51364
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Different SKU
               EXEC rdt.rdtSetFocusField @nMobile, 'V_Barcode' -- SKU
               GOTO Step_4_Fail
            END

            -- Mark SKU as validated
            SET @cSKUValidated = '1'
         END
      END

      -- Validate PQTY
      IF @cPQTY <> '' AND RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 51365
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 14 -- PQTY
         GOTO Step_4_Fail
      END
      SET @nPQTY = CAST( @cPQTY AS INT)

      -- Validate MQTY
      IF @cMQTY <> '' AND RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 51366
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 15 -- MQTY
         GOTO Step_4_Fail
      END
      SET @nMQTY = CAST( @cMQTY AS INT)

      -- Check full short with QTY
      IF @cSKUValidated = '99' AND
         ((@cMQTY <> '0' AND @cMQTY <> '') OR
         (@cPQTY <> '0' AND @cPQTY <> ''))
      BEGIN
         SET @nErrNo = 51384
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- FullShortNoQTY
         GOTO Step_4_Fail
      END

      -- Calc total QTY in master UOM
      SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSuggSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nQTY = @nQTY + @nMQTY

      -- Top up QTY
      IF @cSKUValidated = '99' -- Fully short
         SET @nQTY = 0
      ELSE IF @nUCCQTY > 0
         SET @nQTY = @nQTY + @nUCCQTY
      ELSE
         IF @cSKU <> '' AND @cDisableQTYField = '1'
            SET @nQTY = @nQTY + 1

      -- Check over pick
      IF @nQTY > @nQTY_RPL
      BEGIN
         SET @nErrNo = 51367
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- QTY Over Pick
         GOTO Step_4_Fail
      END

      -- UCC scanned
      IF @nUCCQTY > 0 AND @cUCC <> ''
      BEGIN
         -- Mark UCC scanned
         INSERT INTO rdt.rdtFCPLog (TaskDetailKey, DropID, UCCNo, QTY) VALUES (@cTaskDetailKey, @cDropID, @cUCC, @nUCCQTY)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 51368
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RPFLogFail
            GOTO Quit
         END
      END

      -- Top up MQTY, PQTY
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
         IF @cSKU <> '' AND @cDisableQTYField = '1' -- QTY field disabled
            SET @nMQTY = @nMQTY + 1
      END
      SET @cOutField14 = CASE WHEN (@cPUOM = '6' OR @nPUOM_Div = 0) THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END -- PQTY
      SET @cOutField15 = CAST( @nMQTY AS NVARCHAR( 5)) -- MQTY

       -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cDropID, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cDropID, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo1 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
               '@nAfterStep      INT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 4, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

            SET @cOutField10 = @cExtendedInfo1
         END
      END

      -- SKU scanned, remain in current screen
      IF @cLabelNo <> ''
      BEGIN
         SET @cBarcode = '' -- SKU

         IF @cDisableQTYField = '1'
            EXEC rdt.rdtSetFocusField @nMobile, 'V_Barcode' -- SKU
         ELSE
         BEGIN
            IF @cFieldAttr14 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 14 -- PQTY
            ELSE
               EXEC rdt.rdtSetFocusField @nMobile, 15 -- MQTY
         END
         GOTO Quit
      END
      --A new screen will  require the user to confirm the option . This will be prompted immediately after the user has entered the SKU Quantity on Step 4. 
      --   If the user presses escape then he can be taken to quantity entry screen. Act as a popup Window
      SET @cReplenFlag = rdt.rdtGetConfig( @nFunc, 'ReplenFlag', @cStorerKey)
      IF @cReplenFlag = '0'
         SET @cReplenFlag = ''
      
      IF @cReplenFlag = '1' AND ISNULL(@cExtScnSP,'')<>'' AND EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
      BEGIN
         -- if @cReplenFlag=1 and @cExtScnSP is ready, Goto 99 to 
         SET @nAction =0
         Goto Step_99
      END

      -- QTY short
      IF @nQTY < @nQTY_RPL
      BEGIN
         -- Prepare next screen var
         SET @cOption = ''
         SET @cOutField01 = '' -- Option

         SET @nScn = @nScn + 4
         SET @nStep = @nStep + 4
      END

      -- QTY fulfill
      IF @nQTY >= @nQTY_RPL
      BEGIN
         -- Prepare next screen var
         SET @cOption = ''
         SET @cOutField01 = '' -- Option

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Enable field
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''

      -- Prepare next screen var
      SET @cFromID = ''
      SET @cOutField01 = @cPickMethod
      SET @cOutField02 = @cDropID
      SET @cOutField03 = @cSuggFromLOC
      SET @cOutField04 = @cSuggID
      SET @cOutField05 = '' -- FromID
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
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
               '@nAfterStep      INT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 4, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

            SET @cOutField10 = @cExtendedInfo1
         END
      END
   END
   GOTO Quit

   Step_4_Fail:
      SET @cBarcode = ''
      EXEC rdt.rdtSetFocusField @nMobile, 'V_Barcode'
END
GOTO Quit


/********************************************************************************
Step 5. screen = 4024.
    1 = CONT NEXT TASK
    9 = CLOSE PALLET
    Option (Field01, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check blank option
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 51369
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option needed
         GOTO Step_5_Fail
      END

      -- Check option is valid
      IF @cOption <> '1' AND @cOption <> '9'
      BEGIN
         SET @nErrNo = 51370
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_5_Fail
      END

      -- New replen task
      IF @cOption = '1'
      BEGIN
         -- Confirm current pick task (update TaskDetail to status 5)
         EXEC rdt.rdt_TM_CasePick_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey,
            @cTaskDetailKey,
            @cDropID,
            @nQTY,
            @cToLoc,
            @cReasonCode,
            @cListKey,
            @nErrNo             OUTPUT,
            @cErrMsg            OUTPUT
         IF @nErrNo <> 0
            GOTO Step_5_Fail

         -- Save current task and get new replen task
         SET @cNextTaskDetailKey = ''

         -- Get next task
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetNextTaskSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetNextTaskSP) +
               ' @nMobile, @nFunc, @cLangCode, @cUserName, @cAreaKey, @cListKey, @cDropID, @cNextTaskDetailKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile            INT,           ' +
               '@nFunc              INT,           ' +
               '@cLangCode          NVARCHAR( 3),  ' +
               '@cUserName          NVARCHAR( 18), ' +
               '@cAreaKey           NVARCHAR( 10), ' +
               '@cListKey           NVARCHAR( 10), ' +
               '@cDropID            NVARCHAR( 20), ' +
               '@cNextTaskDetailKey NVARCHAR( 10) OUTPUT, ' +
               '@nErrNo             INT           OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @cUserName, @cAreaKey, @cListKey, @cDropID, @cNextTaskDetailKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_5_Fail
         END
         ELSE
            GOTO Step_5_Fail

         SET @cTaskDetailKey = @cNextTaskDetailKey
/*
         EXEC rdt.rdt_TM_CasePick_GetNextTask @nMobile, @nFunc, @cLangCode,
            @cUserName,
            @cAreaKey,
            @cListKey,
            @cDropID,
            @cNextTaskDetailKey OUTPUT,
            @nErrNo             OUTPUT,
            @cErrMsg            OUTPUT
         IF @nErrNo <> 0
            GOTO Step_5_Fail
*/

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
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cDisableQTYField, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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

         -- Remember last task setting
         SET @cFromLOC = @cSuggFromLOC
         SET @cFromID = @cSuggID

         -- Get task info
         SELECT
            @cTaskStorer  = StorerKey,
            @cSuggID      = FromID,
            @cSuggLOT     = LOT,
            @cSuggFromLOC = FromLOC,
            @cSuggToloc   = ToLoc,
            @cSuggSKU     = SKU,
            @nQTY_RPL     = QTY,
            @cReasonCode  = ''
            -- @cListKey     = ListKey,
            -- @nTransit     = TransitCount,
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey

         -- Go to DropID screen
         IF @cDropID = '' -- 1st PP task ESC from DropID screen that clear DropID
         BEGIN
            -- Prepare next screen var
            SET @cDropID = ''
            SET @cOutField01 = '' -- @cDropID
            
            IF @cAutoGenDROPIDSP <> ''
            BEGIN
               -- Auto generate DROPID
               EXEC rdt.rdt_AutoGenID @nMobile, @nFunc, @nStep, @cLangCode
                  ,@cAutoGenDROPIDSP
                  ,@tExtData
                  ,@cAutoID  OUTPUT
                  ,@nErrNo   OUTPUT
                  ,@cErrMsg  OUTPUT
               IF @nErrNo <> 0
                  GOTO Step_5_Fail

               SET @cOutField01 = @cAutoID
            END

            SET @nScn = @nScn - 4
            SET @nStep = @nStep - 4
         END

         -- Go to SKU screen
         ELSE IF @cSuggFromLOC = @cFromLOC AND @cSuggID = @cFromID
         BEGIN
            -- Mark SKU not yet validate
            SET @cSKUValidated = '0'

            -- Get SKU info
            SELECT
               @cSKUDesc = 
                  CASE WHEN @cDispStyleColorSize = '0'
                       THEN ISNULL( S.Descr, '')
                       ELSE CAST( S.Style AS NCHAR(20)) +
                            CAST( S.Color AS NCHAR(10)) +
                            CAST( S.Size  AS NCHAR(10))
                  END,
               @cLottableCode = S.LottableCode, 
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

            SELECT 
               @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL,  @dLottable05 = NULL,
               @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',    @cLottable10 = '',
               @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL,  @dLottable15 = NULL

            -- Get lottable
            SELECT
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = LA.Lottable04,
               @dLottable05 = LA.Lottable05,
               @cLottable06 = LA.Lottable06,
               @cLottable07 = LA.Lottable07,
               @cLottable08 = LA.Lottable08,
               @cLottable09 = LA.Lottable09,
               @cLottable10 = LA.Lottable10,
               @cLottable11 = LA.Lottable11,
               @cLottable12 = LA.Lottable12,
               @dLottable13 = LA.Lottable13,
               @dLottable14 = LA.Lottable14,
               @dLottable15 = LA.Lottable15
            FROM dbo.LOTAttribute LA WITH (NOLOCK)
            WHERE LOT = @cSuggLOT

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

            -- Disable QTY field
            SET @cFieldAttr14 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- PQTY
            SET @cFieldAttr15 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END -- MQTY

            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0 -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
               SET @nPQTY_RPL = 0
               SET @nPQTY  = 0
               SET @nMQTY_RPL = @nQTY_RPL
               SET @cFieldAttr14 = 'O' -- @nPQTY_PWY
            END
            ELSE
            BEGIN
               SET @nPQTY_RPL = @nQTY_RPL / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMQTY_RPL = @nQTY_RPL % @nPUOM_Div -- Calc the remaining in master unit
            END

            -- Prepare next screen var
            SET @cOutField01 = @cSuggSKU
            SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)
            SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)
            SET @cBarcode    = '' -- SKU
            SET @cOutField09 = ''
            SET @cOutField10 = ''
            SET @cOutField11 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc
            SET @cOutField12 = CASE WHEN (@cPUOM = '6' OR @nPUOM_Div = 0) THEN '' ELSE CAST( @nPQTY_RPL AS NVARCHAR( 5)) END
            SET @cOutField13 = CAST( @nMQTY_RPL AS NVARCHAR( 5))
            SET @cOutField14 = '' -- PQTY
            SET @cOutField15 = '' -- MQTY
            EXEC rdt.rdtSetFocusField @nMobile, 'V_Barcode' -- SKU

            SET @nScn = @nScn - 1
            SET @nStep = @nStep - 1
         END

         -- Go to ID screen
         ELSE IF @cSuggFromLOC = @cFromLOC
         BEGIN
            -- Prepare next screen var
            SET @cFromID = ''
            SET @cOutField01 = @cPickMethod
            SET @cOutField02 = @cDropID
            SET @cOutField03 = @cSuggFromLOC
            SET @cOutField04 = @cSuggID
            SET @cOutField05 = '' -- FromID

            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2
         END

         -- Go to LOC screen
         ELSE IF @cSuggFromLOC <> @cFromLOC
         BEGIN
            -- Prepare next screen var
            SET @cFromLOC = ''
            SET @cOutField01 = @cPickMethod
            SET @cOutField02 = @cDropID
            SET @cOutField03 = @cSuggFromLOC
            SET @cOutField04 = '' -- FromLOC

            SET @nScn = @nScn - 3
            SET @nStep = @nStep - 3
         END
      END

      -- Close pallet
      IF @cOption = '9'
      BEGIN
         -- Prepare next screen var
         SET @cToLOC = ''
         SET @cOutField01 = @cSuggFromLOC
         SET @cOutField02 = @cSuggToLOC
         SET @cOutField03 = CASE WHEN @cDefaultToLOC = '1' THEN @cSuggToLOC ELSE '' END

         SET @nFromScn = @nScn
         SET @nFromStep = @nStep
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo1 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
               '@nAfterStep      INT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 5, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

            SET @cOutField10 = @cExtendedInfo1
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cDropID, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
               '@nAfterStep      INT            '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 5, @nInputKey, @cTaskdetailKey, @cDropID, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

            IF @nErrNo <> 0
               GOTO Quit
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Current task confirmed/SKIP/CANCEL, cannot go back
      IF EXISTS( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey AND Status IN ('5', '0', 'X'))
         GOTO Quit

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

      -- Prepare next screen variable
      SET @cOutField01 = @cSuggSKU
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)
      SET @cBarcode    = '' -- SKU
      SET @cOutField09 = ''
      SET @cOutField10 = @cExtendedInfo1
      SET @cOutField11 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc
      SET @cOutField12 = CASE WHEN (@cPUOM = '6' OR @nPUOM_Div = 0) THEN '' ELSE CAST( @nPQTY_RPL AS NVARCHAR( 5)) END
      SET @cOutField13 = CAST( @nMQTY_RPL AS NVARCHAR( 5))
      SET @cOutField14 = CASE WHEN (@cPUOM = '6' OR @nPUOM_Div = 0) THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END
      SET @cOutField15 = CAST( @nMQTY AS NVARCHAR( 5))
      EXEC rdt.rdtSetFocusField @nMobile, 'V_Barcode' -- SKU

      -- Go to SKU screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 6. screen = 4025. To LOC screen
    FROM LOC (Field01)
    SUGG LOC (Field02)
    TO LOC   (Field03, input)
    EXT INFO (Field010)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToLOC = @cInField03
      SET @cLocNeedCheck = @cInField03

      -- Check blank FromLOC
      IF @cToLOC = ''
      BEGIN
         SET @nErrNo = 51371
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLOC needed
         GOTO Step_6_Fail
      END

      SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '1812ExtendedScreenSP', @cStorerKey), '')
      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_1812ExtScnEntry] 
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
               GOTO Step_6_Fail
            
            SET @cToLOC = @cLocNeedCheck
         END
      END
      
      -- LOC lookup
      IF @cLOCLookupSP = '1'
      BEGIN
         EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
            @cToLOC   OUTPUT,
            @nErrNo   OUTPUT,
            @cErrMsg  OUTPUT
         IF @nErrNo <> 0
            GOTO Step_6_Fail
      END

      -- Check if FromLOC match
      IF @cToLOC <> @cSuggToLOC
      BEGIN
         IF @cOverwriteToLOC = '0'    
         BEGIN    
            SET @nErrNo = 51372    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLOC Diff    
            GOTO Step_4_Fail    
         END    
    
         -- Check ToLOC valid    
         IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC)    
         BEGIN    
            SET @nErrNo = 51385    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC    
            GOTO Step_4_Fail    
         END   
      END

      -- Confirm (TaskDetail to status 5, PickDetail to status 5)
      EXEC rdt.rdt_TM_CasePick_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey,
         @cTaskDetailKey,
         @cDropID,
         @nQTY,
         @cToLoc,
         @cReasonCode,
         @cListKey,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Close pallet (TaskDetail to status 9)
      EXEC rdt.rdt_TM_CasePick_ClosePallet @nMobile, @nFunc, @cLangCode,
         @cUserName,
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
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cDropID, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep '
            SET @cSQLParam =
                       '@nMobile         INT,           ' +
                       '@nFunc           INT,           ' +
                       '@cLangCode       NVARCHAR( 3),  ' +
                       '@nStep           INT,           ' +
                       '@nInputKey       INT,           ' +
                       '@cTaskdetailKey  NVARCHAR( 10), ' +
                       '@cDropID         NVARCHAR( 20), ' +
                       '@nQTY            INT,           ' +
                       '@cToLOC          NVARCHAR( 10), ' +
                       '@nErrNo          INT OUTPUT,    ' +
                       '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
                       '@nAfterStep      INT            '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cDropID, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Extende print, only 'Partiel Pick'
      IF @cExtendedPrintSP <> '' AND @cPickMethod = 'PP'
      BEGIN
         IF @cExtendedPrintSP NOT IN ('0', '') AND
         EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cExtendedPrintSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPrintSP) +
                        ' @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cOption, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5,' +
                        ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
                       '@nMobile                   INT,                   '   +
                       '@nFunc                     INT,                   '   +
                       '@nStep                     INT,                   '   +
                       '@cLangCode                 NVARCHAR( 3),          '   +
                       '@cStorerKey                NVARCHAR( 15),         '   +
                       '@cOption                   NVARCHAR( 1),          '   +
                       '@cParam1                   NVARCHAR( 20),         '   +        -- Label No
                       '@cParam2                   NVARCHAR( 20),         '   +
                       '@cParam3                   NVARCHAR( 20),         '   +
                       '@cParam4                   NVARCHAR( 20),         '   +
                       '@cParam5                   NVARCHAR( 20),         '   +
                       '@nErrNo                    INT           OUTPUT,  '   +
                       '@cErrMsg                   NVARCHAR( 20) OUTPUT   '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                 @nMobile, @nFunc, @nStep, @cLangCode, @cStorerkey, @cOption, @cDropID, '', '', '', '',
                 @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               BEGIN
                  EXEC rdt.rdtSetFocusField @nMobile, 4
                  GOTO Quit
               END
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = @cToLOC

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo1 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
               '@nAfterStep      INT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 6, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

            SET @cOutField10 = @cExtendedInfo1
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back to FromID screen (full pallet)
      IF @nFromStep = 3
      BEGIN
         -- Prepare next screen variable
         SET @cFromID = ''
         SET @cOutField01 = @cPickMethod
         SET @cOutField02 = @cDropID
         SET @cOutField03 = @cSuggFromLOC
         SET @cOutField04 = @cSuggID
         SET @cOutField05 = '' -- FromID
      END

      -- Back to close pallet screen
      IF @nFromStep = 5
      BEGIN
         -- Prepare next screen variable
         SET @cOption = ''
         SET @cOutField01 = '' -- Option
      END

      -- Back to short pick screen
      IF @nFromStep = 8
      BEGIN
         -- Prepare next screen variable
         SET @cOption = ''
         SET @cOutField01 = '' -- Option
      END

      -- Back to prev screen
      SET @nScn = @nFromScn
      SET @nStep = @nFromStep
   END
   GOTO Quit

   Step_6_Fail:
   BEGIN
      SET @cToLOC = ''
      SET @cOutField03 = '' -- To LOC
   END
END
GOTO Quit


/********************************************************************************
Step 7. screen = 4026. Message screen
   Pallet is Close
   ENTER = Next Task
   ESC   = Exit TM

   LAST LOC (field01)
   EXT INFO (field10)
********************************************************************************/
Step_7:
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

      IF @b_Success = 0 OR @nErrNo <> 0
         GOTO Step_7_Fail

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
         SET @nErrNo = 51373
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr
         GOTO Step_7_Fail
      END

      -- Check if screen setup
      SELECT TOP 1 @nToScn = Scn FROM RDT.RDTScn WITH (NOLOCK) WHERE Func = @nToFunc ORDER BY Scn
      IF @nToScn = 0
      BEGIN
         SET @nErrNo = 51374
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr
         GOTO Step_7_Fail
      END

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

      IF @cTTMTaskType IN ('FCP', 'FCP1')
         GOTO Step_0
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerKey

      -- Enable field
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

   Step_7_Fail:
END
GOTO Quit


/********************************************************************************
Step 8. screen = 4027. Short pick screen
    1 = SHORT PICK
    9 = CLOSE PALLET
    Option (Field01, input)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check blank option
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 51375
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option needed
         GOTO Step_8_Fail
      END

      -- Check option is valid
      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 51376
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_8_Fail
      END

      -- Short pick
      IF @cOption = '1'
      BEGIN
         -- Prev next screen var
         SET @cOutField01 = '' -- Reason code

         -- Go to reason code screen
         SET @nFromScn = @nScn
         SET @nFromStep = @nStep
         SET @nScn  = 2109
         SET @nStep = @nStep + 1 -- Step 10
      END

      -- Close pallet
      IF @cOption = '9'
      BEGIN
         -- Close pallet with QTY
         IF @nQTY > 0
         BEGIN
            -- Prepare next screen var
            SET @cToLOC = ''
            SET @cOutField01 = @cSuggFromLOC
            SET @cOutField02 = @cSuggToLOC
            SET @cOutField03 = CASE WHEN @cDefaultToLOC = '1' THEN @cSuggToLOC ELSE '' END

            -- Go to To LOC screen
            SET @nFromScn = @nScn
            SET @nFromStep = @nStep
            SET @nScn  = @nScn - 2
            SET @nStep = @nStep - 2
         END
      END

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo1 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
               '@nAfterStep      INT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 8, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

            SET @cOutField10 = @cExtendedInfo1
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
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
      
      -- Prepare next screen variable
      SET @cOutField01 = @cSuggSKU
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)
      SET @cBarcode    = '' -- SKU
      SET @cOutField09 = ''
      SET @cOutField10 = @cExtendedInfo1
      SET @cOutField11 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc
      SET @cOutField12 = CASE WHEN (@cPUOM = '6' OR @nPUOM_Div = 0) THEN '' ELSE CAST( @nPQTY_RPL AS NVARCHAR( 5)) END
      SET @cOutField13 = CAST( @nMQTY_RPL AS NVARCHAR( 5))
      SET @cOutField14 = CASE WHEN (@cPUOM = '6' OR @nPUOM_Div = 0) THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END
      SET @cOutField15 = CAST( @nMQTY AS NVARCHAR( 5))
      EXEC rdt.rdtSetFocusField @nMobile, 'V_Barcode' -- SKU

      -- Go to SKU screen
      SET @nScn = @nScn - 4
      SET @nStep = @nStep - 4
   END
   GOTO Quit

   Step_8_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = '' -- Option
   END

END
GOTO Quit


/********************************************************************************
Step 9. screen = 2100. Reason code screen
     REASON CODE (Field01, input)
********************************************************************************/
Step_9:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      DECLARE @nShortQTY INT
      SET @cReasonCode = @cInField01

      -- Check blank reason
      IF @cReasonCode = ''
      BEGIN
        SET @nErrNo = 51377
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Reason needed
        GOTO Step_9_Fail
      END

      IF NOT EXISTS( SELECT TOP 1 1
         FROM CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RDTTASKRSN'
            AND StorerKey = @cStorerKey
            AND Code = @cTTMTaskType
            AND @cReasonCode IN (UDF01, UDF02, UDF03, UDF04, UDF05))
      BEGIN
        SET @nErrNo = 51378
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Reason
        GOTO Step_9_Fail
      END

      -- Update ReasonCode
      SET @nShortQTY = @nQTY_RPL - @nQTY
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
         ,@c_toid          = @cDropID
         ,@n_qty           = @nShortQTY
         ,@c_PackKey       = ''
         ,@c_uom           = ''
         ,@c_reasoncode    = @cReasonCode
         ,@c_outstring     = @c_outstring    OUTPUT
         ,@b_Success       = @b_Success      OUTPUT
         ,@n_err           = @nErrNo         OUTPUT
         ,@c_errmsg        = @cErrMsg        OUTPUT
         ,@c_userposition  = '1' -- 1=at from LOC
      IF @b_Success = 0 OR @nErrNo <> 0
         GOTO Step_9_Fail

      -- Confirm (update TaskDetail to status 5)
      IF @nFromStep = 8 --Short pick
      BEGIN
         EXEC rdt.rdt_TM_CasePick_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey,
            @cTaskDetailKey,
            @cDropID,
            @nQTY,
            @cToLoc,
            @cReasonCode,
            @cListKey,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
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
            SET @nErrNo = 51379
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsSkipTskFail
            GOTO Step_9_Fail
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
               SET @nErrNo = 51380
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskdetFail
               GOTO Step_9_Fail
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
               SET @nErrNo = 51381
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskdetFail
               GOTO Step_9_Fail
            END
         END

         -- Cancel picked UCC
         IF EXISTS( SELECT 1 FROM rdt.rdtFCPLog WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey)
         BEGIN
            DELETE rdt.rdtFCPLog WHERE TaskDetailKey = @cTaskDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 51382
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelRPFLogFail
               GOTO Step_9_Fail
            END
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cDropID, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
               '@nAfterStep      INT            '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cDropID, @nQTY, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Continue process current task
      IF @cContinueProcess = '1'
      BEGIN
         -- Back to DropID screen
         IF @nFromStep = 1
         BEGIN
            SET @cOutField01 = '' -- DropID
            SET @nScn = @nFromScn
            SET @nStep = @nFromStep
         END

         -- Back to FromLOC screen
         IF @nFromStep = 2
         BEGIN
            SET @cOutField01 = @cPickMethod
            SET @cOutField02 = @cDropID
            SET @cOutField03 = '' -- FromLOC
            SET @nScn = @nFromScn
            SET @nStep = @nFromStep
         END

         -- Go to next task screen
         IF @nFromStep = 8 -- Short pick screen
         BEGIN
            SET @cOption = ''
            SET @cOutField01 = '' -- Option
            SET @nScn = @nFromScn - 3
            SET @nStep = @nFromStep - 3
         END
      END
      ELSE
      BEGIN
         -- Setup RDT storer config ContProcNotUpdTaskStatus, to avoid nspRFRSN01 set TaskDetail.Status = '9', when ContinueProcess <> 1

         -- Go to next task/exit TM screen
         IF @cPickMethod = 'FP'
         BEGIN
            SET @nScn  = CASE WHEN @nFromStep = 1 THEN @nFromScn + 6
                              WHEN @nFromStep = 2 THEN @nFromScn + 5
                              WHEN @nFromStep = 8 THEN @nFromScn - 1
                         END
            SET @nStep = 7
         END

         -- Go to next task screen
         IF @cPickMethod = 'PP'
         BEGIN
            SET @cOption = ''
            SET @cOutField01 = '' -- Option
            SET @nScn  = CASE WHEN @nFromStep = 1 THEN @nFromScn + 4
                              WHEN @nFromStep = 2 THEN @nFromScn + 3
                              WHEN @nFromStep = 8 THEN @nFromScn - 3
                         END
            SET @nStep = 5
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Go to DropID screen
      IF @nFromStep = 1
      BEGIN
         -- Prepare next screen variable
         SET @cDropID = ''
         SET @cOutField01 = '' -- DropID

         IF @cAutoGenDROPIDSP <> ''
         BEGIN
            -- Auto generate DROPID
            EXEC rdt.rdt_AutoGenID @nMobile, @nFunc, @nStep, @cLangCode
               ,@cAutoGenDROPIDSP
               ,@tExtData
               ,@cAutoID  OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT
            IF @nErrNo <> 0
               GOTO Quit

            SET @cOutField01 = @cAutoID
         END
      END

      -- Go to FromLOC screen
      IF @nFromStep = 2
      BEGIN
         -- Prepare next screen variable
         SET @cFromLOC = ''
         SET @cOutField01 = @cPickMethod
         SET @cOutField02 = @cDropID
         SET @cOutField03 = @cSuggFromLOC
         SET @cOutField04 = '' -- FromLOC
         SET @cOutField10 = '' -- ExtendedInfo
      END

      -- Go to short pick screen
      IF @nFromStep = 8
      BEGIN
         -- Prepare next screen variable
         SET @cOption = ''
         SET @cOutField01 = '' -- Option
      END

      -- Back to prev screen
      SET @nScn = @nFromScn
      SET @nStep = @nFromStep

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo1 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nAfterStep'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@cTaskdetailKey  NVARCHAR( 10), ' +
               '@cExtendedInfo1  NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +
               '@nAfterStep      INT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 9, @cTaskdetailKey, @cExtendedInfo1 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nStep

            SET @cOutField10 = @cExtendedInfo1
         END
      END
   END
   GOTO Quit

   Step_9_Fail:
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
         DECLARE @nStepBak INT
         DECLARE @nScnBak INT
         SELECT @nStepBak = @nStep, @nScnBak = @nScn, @nErrNo=0, @cErrMsg=''
         DELETE FROM @tExtScnData
         INSERT INTO @tExtScnData (Variable, Value) VALUES    
         ('@cTaskDetailKey',  @cTaskDetailKey),
         ('@cListKey',        @cListKey),
         ('@cDropID',         @cDropID),
         ('@cSuggSKU',        @cSuggSKU),
         ('@cSuggFromLOC',    @cSuggFromLOC),
         ('@cSuggLOT',        @cSuggLOT),
         ('@cSuggID',         @cSuggID),
         ('@cQTY',            CONVERT(Nvarchar(20),@nQTY)),
         ('@cQTY_RPL',        CONVERT(Nvarchar(20),@nQTY_RPL))

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

         IF @nScnBak = 99 AND @nScnBak = 4028 AND @nInputKey=0
         BEGIN
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
            -- Prepare next screen variable
            SET @cOutField01 = @cSuggSKU
            SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)
            SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)
            SET @cBarcode    = '' -- SKU    --barcode is nvarchar(max), can't be passed as parameter
            SET @cOutField09 = ''
            SET @cOutField10 = @cExtendedInfo1
            SET @cOutField11 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc
            SET @cOutField12 = CASE WHEN (@cPUOM = '6' OR @nPUOM_Div = 0) THEN '' ELSE CAST( @nPQTY_RPL AS NVARCHAR( 5)) END
            SET @cOutField13 = CAST( @nMQTY_RPL AS NVARCHAR( 5))
            SET @cOutField14 = CASE WHEN (@cPUOM = '6' OR @nPUOM_Div = 0) THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END
            SET @cOutField15 = CAST( @nMQTY AS NVARCHAR( 5))
            EXEC rdt.rdtSetFocusField @nMobile, 'V_Barcode' -- SKU         
         END

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
      V_QTY        = @nQTY,
      V_PQTY       = @nPQTY,
      V_MQTY       = @nMQTY,
      V_TaskQTY    = @nQTY_RPL,
      V_PTaskQTY   = @nPQTY_RPL,
      V_MTaskQTY   = @nMQTY_RPL,
      V_PUOM_Div   = @nPUOM_Div,
      V_FromScn    = @nFromScn,
      V_FromStep   = @nFromStep,
      V_Barcode    = @cBarcode,

      V_String1    = @cAreaKey,
      V_String2    = @cTaskStorer,
      V_String3    = @cDropID,
      V_String4    = @cPickMethod,
      V_String5    = @cSuggToloc,
      V_String6    = @cReasonCode,
      V_String7    = @cListKey,
      V_String8    = @cDisableQTYField,
      V_String9    = @cSwapTaskSP,
      V_String10   = @cMUOM_Desc,
      V_String11   = @cPUOM_Desc,
      V_String12   = @cMultiSKUBarcode,
      V_String13   = @cLottableCode,

      V_String17   = @cDispStyleColorSize,
      V_String18   = @cDecodeSP, 
      V_String19   = @cLOCLookupSP,
      V_String20   = @cSwapUCCSP,
      V_String21   = @cDecodeLabelNo,
      V_String22   = @cExtendedUpdateSP,
      V_String23   = @cDefaultToLOC,
      V_String24   = @cMoveQTYAlloc,
      V_String25   = @cSKUValidated,
      V_String26   = @cDefaultFromID,
      V_String27   = @cExtendedInfoSP,
      V_String28   = @cExtendedInfo1,
      V_String29   = @cGetNextTaskSP,
      V_String30   = @cDisableQTYFieldSP,
      V_String31   = @cExtendedValidateSP,
      V_String41   = @cExtendedPrintSP,

      V_String32   = @cAreakey,
      V_String33   = @cTTMStrategykey,
      V_String34   = @cTTMTaskType,
      V_String35   = @cRefKey01,
      V_String36   = @cRefKey02,
      V_String37   = @cRefKey03,
      V_String38   = @cRefKey04,
      V_String39   = @cRefKey05,
      V_String40   = @cOverwriteToLOC,   
      V_String42   = @cExtScnSP,
      V_String43   = @cAutoGenDROPIDSP,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile

   -- Execute TM module initialization (ung01)
   IF (@nFunc <> 1812 AND @nStep = 0) AND -- Other module that begin with step 0
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