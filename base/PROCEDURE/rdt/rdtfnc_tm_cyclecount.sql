SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/*****************************************************************************/
/* Store procedure: rdtfnc_TM_CycleCount                                     */
/* Copyright      : MAERSK                                                   */
/*                                                                           */
/* Purpose: SOS#227151  -TM Cycle Count                                      */
/*                     - Called By rdtfnc_TaskManager                        */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2011-11-08 1.0  ChewKP   Created                                          */
/* 2012-10-30 1.1  James    SOS257258 - Indicate a TM CC supervisor count by */
/*                          putting '(s)' besides suggested loc (james01)    */
/* 2013-09-26 1.2  James    Pallet ID is required for LOC with loseid = 0    */
/*                          Put pallet ID check SP (james02)                 */
/* 2015-04-06 1.3  ChewKP   SOS#333693 - After Input Reason Code Goto Step 6 */
/*                          (ChewKP01)                                       */
/* 2014-06-25 1.4  James    Bug fix (james03)                                */
/* 2015-05-25 1.5  James    SOS316401 - Add PI pickmethod (james04)          */
/* 2015-06-09 1.6  James    If UCC config not turn on then bypass option     */
/*                          screen and goto count by sku (james05)           */
/* 2016-09-30 1.7  Ung      Performance tuning                               */
/* 2018-04-25 1.8  James    WMS4083-Add ExtendedUpdateSP (james06)           */
/* 2018-10-19 1.9  TungGH   Performance                                      */
/* 2019-04-29 2.0  TungGH   WMS8136-Add ExtendedUpdateSP @ STEP 4 (james07)  */
/* 2019-06-13 2.1  Shong    Performance Tuning (SWT01)                       */
/* 2019-06-14 2.2  James    Performance Tuning (james08)                     */
/* 2019-12-03 2.3  James    WMS-11350 Add output areakey nsptmtm01 (james09) */
/* 2020-01-06 2.4  James    WMS-11550 Add ExtendedInfoSP (james10)           */
/* 2021-04-26 2.5  James    WMS-16634 Direct Go screen 2 TMCC SKU (james11)  */
/* 2021-05-07 2.6  James    WMS-16965 Add empty loc default opt (james12)    */
/* 2021-06-02 2.7  James    WMS-16634 Add update loc.lastcyclecount (james13)*/
/* 2023-09-09 2.8  James    WMS-23249 Add ID count (james14)                 */
/*                          Add BypassScanIDSP config                        */
/* 2023-11-17 2.9  James    WMS-23429 Sort task by logicalloc, loc (james14) */
/* 2024-04-19 3.0  James    WMS-25276 Skip scn 3 based on Loc setup(james16) */
/* 2024-11-27 3.1  JHU151   UWP-27583.Fn1768 St1 TTL QTY is not cleared when */
/*                                       scanning a new loc                  */
/* 2025-02-11 3.2  JCH507   FCR-1917 Add ext upd entry                       */
/*****************************************************************************/

CREATE   PROC [RDT].[rdtfnc_TM_CycleCount](
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
   @cTaskDetailKey      NVARCHAR(10),
   @cLoc                NVARCHAR(10),
   @cID                 NVARCHAR(18),
   @cSKU                NVARCHAR(20),
   @cSuggFromLoc        NVARCHAR(10),
   @cSuggID             NVARCHAR(18),
   @cSuggSKU            NVARCHAR(20),
   @cUCC                NVARCHAR(20),
   @cCommodity          NVARCHAR(20),
   @c_outstring         NVARCHAR(255),
   @cContinueProcess    NVARCHAR(10),
   @cReasonStatus       NVARCHAR(10),
   @cAreakey            NVARCHAR(10),
   @cUserPosition       NVARCHAR(10),
   @nFromScn            INT,
   @nFromStep           INT,
   @cTMCCSingleScan     NVARCHAR(1),
   @nToFunc             INT,
   @nToScn              INT,
   @cTTMStrategykey     NVARCHAR(10),
   @cRefKey01           NVARCHAR(20),
   @cRefKey02           NVARCHAR(20),
   @cRefKey03           NVARCHAR(20),
   @cRefKey04           NVARCHAR(20),
   @cRefKey05           NVARCHAR(20),
   @cTTMTasktype        NVARCHAR(10),
   @cReasonCode         NVARCHAR(10),
   @cNextTaskdetailkey  NVARCHAR(10),
   @nPrevStep           INT,
   @cOptions            NVARCHAR(1),
   @nToStep             INT,
   @cCCKey              NVARCHAR(10),
   @c_CCDetailKey       NVARCHAR(10),
   @cLottable01         NVARCHAR( 18),
   @cLottable02         NVARCHAR( 18),
   @cLottable03         NVARCHAR( 18),
   @cLottable04         NVARCHAR( 16),
   @cLottable05         NVARCHAR( 16),
   @cSKUDescr           NVARCHAR(60),
   @nUCCQty             INT,
   @nQtyAval            INT,
   @nPQty               INT,
   @nMQty               INT,
   @cMUOM_Desc          NVARCHAR(5),
   @cPUOM               NVARCHAR(1),
   @cPUOM_Desc          NVARCHAR(5),
   @nPUOM_Div           INT,
   @nRowID              INT,
   @dLottable04         DATETIME,
   @dLottable05         DATETIME,
   @cLotLabel01         NVARCHAR( 20),
   @cLotLabel02         NVARCHAR( 20),
   @cLotLabel03         NVARCHAR( 20),
   @cLotLabel04         NVARCHAR( 20),
   @cLotLabel05         NVARCHAR( 20),
   @cHasLottable        NVARCHAR( 1),
   @cLottable01_Code    NVARCHAR( 30),
   @cLottable02_Code    NVARCHAR( 30),
   @cLottable03_Code    NVARCHAR( 30),
   @cLottable04_Code    NVARCHAR( 30),
   @cLottable05_Code    NVARCHAR( 30),
   @nCountLot           INT,
   @cListName           NVARCHAR( 20),
   @cLottableLabel      NVARCHAR( 20),
   @cShort              NVARCHAR( 10),
   @cStoredProd         NVARCHAR( 250),
   @cSourcekey          NVARCHAR(15),
   @nPrevScreen         INT,
   @cPickMethod         NVARCHAR(10),
   @c_NewLineChar       NVARCHAR(2),
   @c_AlertMessage      NVARCHAR( 255),
   @c_Activity          NVARCHAR(10),
   @c_modulename        NVARCHAR(30),
   @cOverrideLOC        NVARCHAR(1),
   @cDefaultCCOption    NVARCHAR(1),
   @cCCType             NVARCHAR( 10),
   @c_CCSheetNo         NVARCHAR( 10),
   @cSKUDescr1          NVARCHAR( 20),
   @cSKUDescr2          NVARCHAR( 20),
   @cCCDetailKey        NVARCHAR( 10),
   @cPalletIDChkSP      NVARCHAR( 20),    -- (james02)
   @cSQL                NVARCHAR( 1000),  -- (james02)
   @cSQLParam           NVARCHAR( 1000),  -- (james02)
   @cOtherPickMethod    NVARCHAR( 10),    -- (james04)
   @cTaskStorer         NVARCHAR( 15),
   @cExtendedUpdateSP   NVARCHAR( 20),
   
   @nAction             INT,
   @cExtendedScreenSP   NVARCHAR( 20), --(JHU151)
   @tExtScnData			VariableTable, --(JHU151)

   @cRemoveTaskFromUserQueue  NVARCHAR( 10),
   @cTaskStatus               NVARCHAR( 10),
   @nQtyOnLoc           INT,

   @cExtendedInfoSP         NVARCHAR( 20),   -- (james10)
   @cExtendedInfo           NVARCHAR( 20),   -- (james10)
   @tExtInfo                VariableTable,   -- (james10)
   @cTMCCSKUSkipScreen1     NVARCHAR( 1),
   @cEmptyLocDefaultOption  NVARCHAR( 1),
   @cDefaultCCOptionSP      NVARCHAR( 20),
   @cBypassScanIDSP         NVARCHAR( 20),
   @nBypassScanID           INT,
   @tBypassScanID           VariableTable,
   @cFlowThruScreen         NVARCHAR( 10),

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

DECLARE @cStorerConfig_UCC  NVARCHAR( 1)     -- (james05)

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
   @cPUOM            = V_UOM,
   @cTaskDetailKey   = V_TaskDetailKey,
   @cSuggFromLoc     = V_Loc,
   @cID              = V_ID,
   @cSKU             = V_SKU,

   @cLottable01      = V_Lottable01,
   @cLottable02      = V_Lottable02,
   @cLottable03      = V_Lottable03,
   @dLottable04      = V_Lottable04,
   @dLottable05      = V_Lottable05,

   @cLotLabel01      = V_LottableLabel01,
   @cLotLabel02      = V_LottableLabel02,
   @cLotLabel03      = V_LottableLabel03,
   @cLotLabel04      = V_LottableLabel04,
   @cLotLabel05      = V_LottableLabel05,

   @cCCKey           = V_String1,
   @cSuggID          = V_String2,
   @cCommodity       = V_String3,
   @cUCC             = V_String4,
   @cTMCCSKUSkipScreen1 = V_String5,
   @cUserPosition    = V_String6,
   @cDefaultCCOptionSP = V_String7,
   @cFlowThruScreen    = V_String8,

   @cLoc             = V_String10,
   @cSuggSKU         = V_String13,
   @cPickMethod      = V_String14,
   @cSKUDescr1       = V_String15,
   @cSKUDescr2       = V_String16,
   @cCCDetailKey     = V_String17,
   @cExtendedUpdateSP= V_String18,
   @cExtendedInfoSP  = V_String19,

   @nPrevStep        = V_FromStep,
   @nPrevScreen      = V_FromScn,

   -- Module SP Variable V_String 20 - 26 --

   -- Start of Common Variable use by UCC, SKU, SingleScan CC
   --@nActQTY          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String28, 5), 0) = 1 THEN LEFT( V_String28, 5) ELSE 0 END,

   @nUCCQty          = V_Integer1,
   @nRowID           = V_Integer2,

   @nFromScn         = V_String30,
   @nFromStep        = V_String31,
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

FROM   RDT.RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc IN (1766, 1794, 1795)
BEGIN
   DECLARE @nStepID INT,
           @nScnID  INT

    SET @nStepID = 2
    SET @nScnID  = 2871

   IF @nStep = 1 GOTO Step_1   -- Menu. Func = 1766, Scn = 2870 -- Loc (SCN1)
   IF @nStep = 2 GOTO Step_2   -- Scn = 2871 = ID
   IF @nStep = 3 GOTO Step_3   -- Scn = 2872 = Options
   IF @nStep = 4 GOTO Step_4   -- Scn = 2873 = Loc Empty ? Options
   --IF @nStep = 5 GOTO Step_5   -- Scn = 2874 = Message
   IF @nStep = 6 GOTO Step_6   -- Scn = 2875 = NEXT TASK / EXIT TM
   IF @nStep = 7 GOTO Step_7   -- Scn = 2109 = Reason Code
   --IF @nStep = 8 GOTO Step_8   -- Scn = 2876 = Options ( End Loc, End ID, Recount, Continue)
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 1. Called from Task Manager Main Screen (func = 1766)
    Screen = 2870
    Suggested Loc (field10)
    Loc (input, field02)
********************************************************************************/
Step_1:
BEGIN

   SET @cUserPosition = '1'

   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLoc   = ISNULL(RTRIM(@cInField02),'')
      SET @cID = ''  -- (james02)

      SET @nPrevStep = 0
      SET @nPrevScreen  = 0

      /****************************
       VALIDATION
      ****************************/
      --When Loc is blank
      IF @cLoc = ''
      BEGIN
         SET @nErrNo = 74401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Loc Req
         GOTO Step_1_Fail
      END

      SET @cOverrideLOC = ''
      SET @cOverrideLOC = rdt.RDTGetConfig( @nFunc, 'OverrideLOC', @cStorerkey)

      IF @cLoc <> @cSuggFromLoc
      BEGIN
         SET @nErrNo = 74402
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Loc
         GOTO Step_1_Fail
      END

      SELECT
         @cTaskStorer  = Storerkey,
         @cSuggID      = FromID,
         @cSuggFromLoc = FromLOC,
         @cSuggSKU     = SKU,
         @cPickMethod  = PickMethod,
         @cSourceKey   = SourceKey
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskdetailkey

      IF ISNULL( @cTaskStorer, '') <> ''
         SET @cStorerKey = @cTaskStorer

      -- (james06)
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''

      -- (james10)
      SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
      IF @cExtendedInfoSP = '0'
         SET @cExtendedInfoSP = ''

      SET @cTMCCSKUSkipScreen1 = rdt.RDTGetConfig( @nFunc, 'TMCCSKUSkipScreen1', @cStorerKey)

      SET @cDefaultCCOption = rdt.RDTGetConfig( @nFunc, 'DefaultCCOption', @cStorerkey)

      SET @cDefaultCCOptionSP = rdt.RDTGetConfig( @nFunc, 'DefaultCCOptionSP', @cStorerKey)
      IF @cDefaultCCOptionSP = '0'
         SET @cDefaultCCOptionSP = ''

      SET @cBypassScanIDSP = rdt.RDTGetConfig( @nFunc, 'BypassScanIDSP', @cStorerKey)
      IF @cBypassScanIDSP = '0'
         SET @cBypassScanIDSP = ''

      SET @cFlowThruScreen = rdt.RDTGetConfig( @nFunc, 'FlowThruScreen', @cStorerKey)

      -- (james04)
      -- If TM CC task is generated from daily PI task then pickmethod
      -- is different from those generated from frontend. To make it consistent
      -- then need to define a codelkup to refer them to either for LOC or SKU
      IF @cPickMethod NOT IN ('SKU', 'LOC')
      BEGIN
         SET @cOtherPickMethod = ''
         SELECT @cOtherPickMethod = Short
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'PIPICKMTD'
         AND Code = @cPickMethod
         AND StorerKey = CASE WHEN ISNULL( @cStorerKey, '') = '' THEN StorerKey ELSE @cStorerkey END

         IF ISNULL( @cOtherPickMethod, '') <> ''
            SET @cPickMethod = @cOtherPickMethod
      END

      -- When Get the first Task Update EditDate
      UPDATE dbo.TaskDetail With (ROWLOCK)
      SET StartTime = GETDATE(),
          EditDate = GETDATE(),
          EditWho = @cUserName,
          Trafficcop = NULL
      WHERE TaskDetailkey = @cTaskdetailkey

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 74403
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
         GOTO Step_1_Fail
      END

      SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
      FROM RDT.rdtMobRec M (NOLOCK)
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)
      WHERE M.Mobile = @nMobile

      SET @cCCKey = @cSourceKey

      SELECT @nQtyOnLoc = ISNULL( SUM(QTY - QTYPICKED), 0)
      FROM dbo.LotxLocxID LLI WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.Loc = @cLoc
      AND   LOC.Facility = @cFacility

      --v3.2 start
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cFromLoc, @cID, @cPickMethod, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 15), ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cTaskdetailkey  NVARCHAR( 20),  ' +
               '@cFromLoc        NVARCHAR( 20),  ' +
               '@cID             NVARCHAR( 20),  ' +
               '@cPickMethod     NVARCHAR( 20),  ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cSuggFromLoc, @cID, @cPickMethod,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END
      --V3.2 end

      IF @nQtyOnLoc = 0
      BEGIN
         -- (james12)
         SET @cEmptyLocDefaultOption = rdt.RDTGetConfig( @nFunc, 'EmptyLocDefaultOption', @cStorerKey)

         SET @cOutField01 = @cLoc
         SET @cOutField02 = CASE WHEN @cEmptyLocDefaultOption NOT IN ( '', '0') THEN @cEmptyLocDefaultOption ELSE '' END

         -- GOTO Loc Not Empty Script
         SET @nScn = @nScn + 3
         SET @nStep = @nStep + 3

         GOTO QUIT
      END

      EXEC RDT.rdt_STD_EventLog
         @cActionType = '1', -- Sign in function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep

      /****************************
       prepare next screen variable
      ****************************/

      -- (james14)
      -- BypassScanIDSP
      IF @cBypassScanIDSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cBypassScanIDSP AND type = 'P')
         BEGIN
            SET @nBypassScanID = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cBypassScanIDSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cFromLoc, @cID, @cPickMethod, ' +
               ' @tBypassScanID, @nBypassScanID OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 15), ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cTaskdetailkey  NVARCHAR( 20),  ' +
               '@cFromLoc        NVARCHAR( 20),  ' +
               '@cID             NVARCHAR( 20),  ' +
               '@cPickMethod     NVARCHAR( 20),  ' +
               '@tBypassScanID   VariableTable READONLY, ' +
               '@nBypassScanID   INT OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cSuggFromLoc, @cID, @cPickMethod,
                  @tBypassScanID, @nBypassScanID OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END

      -- If loc.loseid = 1 then no need scan pallet id. Skip the screen (james02)
      -- If BypassScanID = 1 also no need scan pallet id. Skip the screen (james14)
      IF EXISTS (SELECT 1
                 FROM LOC WITH (NOLOCK)
                 WHERE LOC = @cLoc
                 AND   LoseId = '1') OR
                 @nBypassScanID = 1
      BEGIN
         -- If turn on UCC config then goto option screen to let user choose
         -- whether they want count by UCC or SKU. Else by default is SKU
         SET @cStorerConfig_UCC = '0' -- Default Off
         SELECT @cStorerConfig_UCC = CASE WHEN SValue = '1' THEN '1' ELSE '0' END
         FROM dbo.StorerConfig (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND ConfigKey = 'UCC'

         IF @cStorerConfig_UCC <> '1'
         BEGIN
             -- (james01)
            IF EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                       WHERE Facility = @cFacility
                       AND   LOC = @cSuggFromLoc
                       AND   LoseUCC = '0')
            BEGIN
               SET @nErrNo = 74450
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC X LOSEUCC
               SET @cOutField02 = ''
               GOTO Quit
            END

            EXEC rdt.rdt_TM_CycleCount_InsertCCDetail
               @nMobile          = @nMobile
              ,@c_TaskDetailKey  = @cTaskdetailkey
              ,@nErrNo           = @nErrNo
              ,@cErrMsg          = @cErrMsg
              ,@cLangCode        = @cLangCode
              ,@c_StorerKey      = @cStorerKey
              ,@c_Loc            = @cSuggFromLoc
              ,@c_Facility       = @cFacility
              ,@c_PickMethod     = @cPickMethod
              ,@c_CCOptions      = '2'
              ,@c_SourceKey      = @cCCKey

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               SET @cOutField02 = ''
               GOTO Quit
            END

         -- (james10)
         -- Extended info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''
               SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cFromLoc, @cID, @cPickMethod, ' +
                  ' @tExtInfo, @cExtendedInfo OUTPUT '
               SET @cSQLParam =
                  '@nMobile         INT,           ' +
                  '@nFunc           INT,           ' +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,           ' +
                  '@nInputKey       INT,           ' +
                  '@cFacility       NVARCHAR( 15), ' +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cTaskdetailkey  NVARCHAR( 20),  ' +
                  '@cFromLoc        NVARCHAR( 20),  ' +
                  '@cID             NVARCHAR( 20),  ' +
                  '@cPickMethod     NVARCHAR( 20),  ' +
                  '@tExtInfo        VariableTable READONLY, ' +
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cSuggFromLoc, @cID, @cPickMethod,
                  @tExtInfo, @cExtendedInfo OUTPUT

               SET @cOutField15 = @cExtendedInfo
            END
         END

            SET @nToFunc = 1768

            SET @cOutField01 = @cLoc
            SET @cOutField02 = @cID
            SET @cOutField03 = ''

      SET @cOutField04 = ''
            SET @cOutField05 = ''

            SET @cFieldAttr04 = 'O'
            SET @cFieldAttr05 = 'O'


            IF @cPickMethod = 'SKU'
            BEGIN
               SET @cOutField06 =  ISNULL(@cSuggSKU,'')
            END
            ELSE
            BEGIN
               SET @cOutField06 = ''
            END

            SET @cOutField07 = @cPickMethod

            SET @nPrevStep = 0
            SET @nPrevScreen = 0

            IF @cTMCCSKUSkipScreen1 = '1'
            BEGIN
               SELECT @cPUOM = V_UOM,
                      @cStorerKey = StorerKey
               FROM RDT.RDTMOBREC WITH (NOLOCK)
               WHERE Mobile = @nMobile

               DECLARE @cSkipLottable NVARCHAR( 1)
               DECLARE @cDecodeSP NVARCHAR( 20)
               DECLARE @nQty INT
               DECLARE @cCCGroupExLottable05 NVARCHAR( 1)
               DECLARE @nLottableCountTotal INT
               DECLARE @cCounted NVARCHAR( 5)
               DECLARE @nLottableCount INT
               DECLARE @nDefaultQty INT
               DECLARE @cDefaultQty NVARCHAR( 5)
               DECLARE @cNewSKUorLottable NVARCHAR( 1)
               DECLARE @cSkipLottable01 NVARCHAR(1)
               DECLARE @cSkipLottable02 NVARCHAR(1)
               DECLARE @cSkipLottable03 NVARCHAR(1)
               DECLARE @cSkipLottable04 NVARCHAR(1)
               DECLARE @nActQTY INT
               DECLARE @cLottable06 NVARCHAR( 30)
               DECLARE @cLottable07 NVARCHAR( 30)
               DECLARE @cLottable08 NVARCHAR( 30)
               DECLARE @cLottable09 NVARCHAR( 30)
               DECLARE @cLottable10 NVARCHAR( 30)
               DECLARE @cLottable11 NVARCHAR( 30)
               DECLARE @cLottable12 NVARCHAR( 30)
               DECLARE @dLottable13 DATETIME
               DECLARE @dLottable14 DATETIME
               DECLARE @dLottable15 DATETIME

               INSERT INTO traceinfo(TraceName, TimeIn, Col1, Col2) VALUES ('123', GETDATE(), @cSuggSKU, @cTaskDetailKey)
               SET @cSKU = @cSuggSKU
               SET @cSkipLottable = rdt.RDTGetConfig( @nFunc, 'SkipLottable', @cStorerKey)

               -- Get stored proc name for extended info (james40)
               SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
               IF @cExtendedInfoSP = '0'
                  SET @cExtendedInfoSP = ''

               -- (james03)
               SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
               IF @cDecodeSP = '0'
                  SET @cDecodeSP = ''


               SET @cSKUDescr = ''
               SET @cMUOM_Desc = ''
               SET @cPUOM_Desc = ''

               SET @nQtyAval = 0
               SET @nQty = 0
               SET @nPUOM_Div = 0
               SET @nMQTY = 0
               SET @nPQTY = 0

               SET @cLottable01 = ''
               SET @cLottable02 = ''
               SET @cLottable03 = ''
               SET @dLottable04 = NULL
               SET @dLottable05 = NULL

               SELECT
                    @cSKUDescr = SKU.DESCR
                  , @cMUOM_Desc  = Pack.PackUOM3
                  , @cPUOM_Desc  =
                  CASE @cPUOM
                     WHEN '2' THEN Pack.PackUOM1 -- Case
                     WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                     WHEN '6' THEN Pack.PackUOM3 -- Master unit
                     WHEN '1' THEN Pack.PackUOM4 -- Pallet
                     WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                     WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
                  END
                  ,  @nPUOM_Div  = CAST( IsNULL(
                  CASE @cPUOM
                     WHEN '2' THEN Pack.CaseCNT
                     WHEN '3' THEN Pack.InnerPack
                     WHEN '6' THEN Pack.QTY
                     WHEN '1' THEN Pack.Pallet
                     WHEN '4' THEN Pack.OtherUnit1
                     WHEN '5' THEN Pack.OtherUnit2
                  END, 1) AS INT)
               FROM dbo.SKU SKU WITH (NOLOCK)
               INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
               WHERE SKU.SKU = @cSKU
                 AND SKU.StorerKey = @cStorerKey

               SET @cCCDetailKey = ''

               SET @cCCGroupExLottable05 = ''
               SET @cCCGroupExLottable05 = rdt.RDTGetConfig( @nFunc, 'CCGroupExLottable05', @cStorerkey)

               IF @cCCGroupExLottable05 = '1'
               BEGIN
                  SELECT TOP 1
                           @cLottable01 = CC.Lottable01
                         , @cLottable02 = CC.Lottable02
                         , @cLottable03 = CC.Lottable03
                         , @dLottable04 = CC.Lottable04  --yeekung01
                         , @nQtyAval    =  SUM(CC.SystemQty)
                         , @cCCDetailKey = MIN(CC.CCDetailKey)
                         , @nQty        = SUM(CC.Qty)
                  FROM dbo.CCDetail CC WITH (NOLOCK)
                  WHERE CC.SKU = @cSKU
                  AND CC.CCKey = @cCCKey
                  AND CC.Loc   = @cLoc
                  AND CC.ID    = @cID
                  AND Status < '9'
                  AND CC.CCSheetNo = @cTaskDetailKey
                  GROUP BY CC.Lottable01, CC.Lottable02, CC.Lottable03, CC.Lottable04
                  ORDER BY MIN(CC.CCDetailKey)

                  SET @nLottableCountTotal = 0
                  SELECT @nLottableCountTotal =  COUNT(1)
                  FROM dbo.CCDetail CC WITH (NOLOCK)
                  WHERE CC.SKU = @cSKU
                  AND CC.CCKey = @cCCKey
                  AND CC.Loc   = @cLoc
                  AND CC.ID    = @cID
                  AND Status < '9'
                  AND CC.CCSheetNo = @cTaskDetailKey
                  GROUP BY CC.Lottable01, CC.Lottable02, CC.Lottable03, CC.Lottable04
               END
               ELSE
               BEGIN
                  SELECT TOP 1
                           @cLottable01 = CC.Lottable01
                         , @cLottable02 = CC.Lottable02
                         , @cLottable03 = CC.Lottable03
  							         , @dLottable04 = CC.Lottable04  --yeekung01
                         , @dLottable05 = CC.Lottable05  --yeekung01
                         , @nQtyAval    =  CC.SystemQty
                         , @cCCDetailKey = CC.CCDetailKey
                         , @nQty        = CC.Qty
                  FROM dbo.CCDetail CC WITH (NOLOCK)
                  WHERE CC.SKU = @cSKU
                  AND CC.CCKey = @cCCKey
                  AND CC.Loc   = @cLoc
                  AND CC.ID    = @cID
                  AND Status < '9'
                  AND CC.CCSheetNo = @cTaskDetailKey
                  ORDER BY CCDetailKey

                  SET @nLottableCountTotal = 0
                  SELECT @nLottableCountTotal = COUNT(1)
                  FROM dbo.CCDetail CC WITH (NOLOCK)
                  WHERE CC.SKU = @cSKU
                  AND CC.CCKey = @cCCKey
                  AND CC.Loc   = @cLoc
                  AND CC.ID    = @cID
                  AND Status < '9'
                  AND CC.CCSheetNo = @cTaskDetailKey
               END

               SET @cCounted = ''

               IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                           WHERE CCKey = @cCCKey
                           AND SKU = @cSKU
                           AND Loc = @cLoc
                           AND ID  = @cID
                           AND Status < '9'
                           AND Qty > 0
                           AND CCSheetNo = @cTaskDetailKey
                           AND CCdetailKey = @cCCDetailKey)
               BEGIN
                  SET @nQtyAval = @nQty
                  SET @cCounted = '1'
               END

               -- Convert to prefer UOM QTY
               IF @cPUOM = '6' OR -- When preferred UOM = master unit
                  @nPUOM_Div = 0  -- UOM not setup
               BEGIN
                  SET @cPUOM_Desc = ''
                  SET @nPQTY = 0
                  SET @nMQTY = @nQtyAval
               END
               ELSE
               BEGIN
                  SET @nPQTY = @nQtyAval / @nPUOM_Div  -- Calc QTY in preferred UOM
                  SET @nMQTY = @nQtyAval % @nPUOM_Div  -- Calc the remaining in master unit
               END

               -- Prepare Next Screen Variable
               SET @cSKUDescr1 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
		         SET @cSKUDescr2 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 1

               SET @cOutField01 = @cSKU
               SET @cOutField02 = @cSKUDescr1
               SET @cOutField03 = @cSKUDescr2

               SET @nLottableCount = 0
               SET @cOutField13 = CASE WHEN @cSkipLottable = '1' THEN ''
                                       ELSE RTRIM(CAST(@nLottableCount AS NVARCHAR(4))) +  '/' +
                                            RTRIM(CAST(@nLottableCountTotal AS NVARCHAR(4)))
                                       END

               IF @cPUOM_Desc = ''
               BEGIN
                  SET @cOutField04 = ''
                  SET @cOutField06 = ''
                  SET @cFieldAttr06 = 'O'
               END
               ELSE
               BEGIN
                  SET @cOutField04 = @cPUOM_Desc
                  IF @cCounted = '1'
                  BEGIN
                     SET @cOutField06 = CAST( @nPQTY AS NVARCHAR( 5))
                  END
                  ELSE
                  BEGIN
                     SET @cOutField06 = ''
                  END
               END

               IF @nPQTY <= 0
               BEGIN
                  --SET @cOutField04 = ''
                  SET @cOutField06 = ''
                  SET @cOutField06 = ''
                  SET @cFieldAttr06 = 'O'
               END

               SET @cOutField05 = @cMUOM_Desc

               IF @cCounted = '1'
               BEGIN
                  SET @cOutField07 = CAST( @nMQTY AS NVARCHAR( 5))
               END
               ELSE
               BEGIN
                  SET @cOutField07 = ''
               END

               SET @cFieldAttr07 = ''

               IF @nPQTY > 0
                  EXEC rdt.rdtSetFocusField @nMobile, 06
               ELSE
                  EXEC rdt.rdtSetFocusField @nMobile, 07

               SET @cFieldAttr08 = 'O'
               SET @cFieldAttr09 = 'O'
               SET @cFieldAttr10 = 'O'
               SET @cFieldAttr11 = 'O'

               IF @cSkipLottable = '1'
               BEGIN
                  SET @cOutField08 = ''
                  SET @cOutField09 = ''
                  SET @cOutField10 = ''
                  SET @cOutField11 = ''
               END
               ELSE
               BEGIN
                  SET @cOutField08 = @cLottable01
                  SET @cOutField09 = @cLottable02
                  SET @cOutField10 = @cLottable03
                  SET @cOutField11 = rdt.rdtFormatDate( @dLottable04)
               END

               SET @cFieldAttr06 = ''
               SET @cFieldAttr07 = ''
               SET @cFieldAttr12 = ''

               SET @nDefaultQty = 0

               -- if default qty turned on then overwrite the actual MQty (james02)
		         SET @cDefaultQty = rdt.RDTGetConfig( @nFunc, 'TMCCDefaultQty', @cStorerkey)
               IF RDT.rdtIsValidQTY( @cDefaultQty, 1) = 1
                  SET @nDefaultQty = CAST( @cDefaultQty AS INT)
               ELSE
                  SET @nDefaultQty = 0

               IF @nDefaultQty > 0
               BEGIN
                  SET @cFieldAttr12 = ''
                  SET @cOutField12 = ''
                  SET @cFieldAttr06 = 'O'
                  SET @cFieldAttr07 = 'O'

                  -- Convert to prefer UOM QTY
                  IF @cPUOM = '6' OR -- When preferred UOM = master unit
                     @nPUOM_Div = 0  -- UOM not setup
                     SET @cOutField07 = @nDefaultQty
                  ELSE
                  BEGIN
                     IF @nDefaultQty > @nPUOM_Div
                     BEGIN
                        SET @cOutField06 = @nDefaultQty / @nPUOM_Div  -- Calc QTY in preferred UOM
                        SET @cOutField07 = @nDefaultQty % @nPUOM_Div  -- Calc the remaining in master unit
                     END
                     ELSE
                        SET @cOutField07 = @nDefaultQty
                  END
               END
               ELSE
               BEGIN
                  SET @cFieldAttr12 = 'O'
                  SET @cOutField12 = ''
               END

               SET @cNewSKUorLottable = ''

               IF NOT EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
	                            WHERE CCKey = @cCCKey
	                            AND Loc     = @cLoc
	                            AND ID      = @cID
	                            AND SKU     = @cSKU
	                            AND Status  < '9'
	                            AND CCSheetNo = @cTaskDetailKey  )
               BEGIN
                     -- SET to 1 for New Found SKU or Lottables
                     SET @cNewSKUorLottable = '1'

                     SET @cFieldAttr08 = ''
                     SET @cFieldAttr09 = ''
                     SET @cFieldAttr10 = ''
                     SET @cFieldAttr11 = ''
                     SET @cFieldAttr12 = ''
                     SET @cFieldAttr13 = ''
                     SET @cFieldAttr14 = ''
                     SET @cFieldAttr15 = ''

                     -- (james02)
                     SELECT
                        @cLotLabel01 = IsNULL(( SELECT TOP 1 C.[Description]
                                                FROM dbo.CodeLKUP C WITH (NOLOCK)
                                                WHERE C.Code = S.Lottable01Label
                                                AND C.ListName = 'LOTTABLE01'
                                                AND C.Code <> ''
                                                AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                                ORDER By C.StorerKey DESC), ''),
                        @cLotLabel02 = IsNULL(( SELECT TOP 1 C.[Description]
                                                FROM dbo.CodeLKUP C WITH (NOLOCK)
                                                WHERE C.Code = S.Lottable02Label
                                                AND C.ListName = 'LOTTABLE02' AND C.Code <> ''
                                                AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                                ORDER By C.StorerKey DESC), ''),
                        @cLotLabel03 = IsNULL(( SELECT TOP 1 C.[Description]
                                                FROM dbo.CodeLKUP C WITH (NOLOCK)
                                                WHERE C.Code = S.Lottable03Label
                                                AND C.ListName = 'LOTTABLE03' AND C.Code <> ''
                                                AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                                ORDER By C.StorerKey DESC), ''),
                        @cLotLabel04 = IsNULL(( SELECT TOP 1 C.[Description]
                                                FROM dbo.CodeLKUP C WITH (NOLOCK)
                                                WHERE C.Code = S.Lottable04Label
                                                AND C.ListName = 'LOTTABLE04' AND C.Code <> ''
                                                AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                                ORDER By C.StorerKey DESC), ''),
                        @cLotLabel05 = IsNULL(( SELECT TOP 1 C.[Description]
                                                FROM dbo.CodeLKUP C WITH (NOLOCK)
                                                WHERE C.Code = S.Lottable05Label
                                                AND C.ListName = 'LOTTABLE05' AND C.Code <> ''
                                                AND (C.StorerKey = @cStorerKey OR C.Storerkey = '')
                                                ORDER By C.StorerKey DESC), ''),
                        @cLottable05_Code = IsNULL( S.Lottable05Label, ''),
                        @cLottable01_Code = IsNULL(S.Lottable01Label, ''),
                        @cLottable02_Code = IsNULL(S.Lottable02Label, ''),
                        @cLottable03_Code = IsNULL(S.Lottable03Label, ''),
                        @cLottable04_Code = IsNULL(S.Lottable04Label, '')
                     FROM dbo.SKU S WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND SKU = @cSKU

                     -- Turn on lottable flag (use later)
                     SET @cHasLottable = '0'
                     IF (@cLotLabel01 <> '' AND @cLotLabel01 IS NOT NULL) OR
                        (@cLotLabel02 <> '' AND @cLotLabel02 IS NOT NULL) OR
                        (@cLotLabel03 <> '' AND @cLotLabel03 IS NOT NULL) OR
                        (@cLotLabel04 <> '' AND @cLotLabel04 IS NOT NULL) OR
                        (@cLotLabel05 <> '' AND @cLotLabel05 IS NOT NULL)
                     BEGIN
                        SET @cHasLottable = '1'
                     END

                     /********************************************************************************************************************/
                     /*  - Start                                                                                                         */
                     /* Generic Lottables Computation (PRE): To compute Lottables before going to Lottable Screen                        */
                     /* Setup spname in CODELKUP.Long where ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05'  */
                     /* 1. Setup RDT.Storerconfigkey = <Lottable01/02/03/04/05> , sValue = <Lottable01/02/03/04/05Label>                 */
                     /* 2. Setup Codelkup.Listname = ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05' and     */
                     /*    Codelkup.Short = 'PRE' and Codelkup.Long = <SP Name>                                                          */
                     /********************************************************************************************************************/

                     IF (IsNULL(@cLottable01_Code, '') <> '') OR (IsNULL(@cLottable02_Code, '') <> '') OR (IsNULL(@cLottable03_Code, '') <> '') OR
                        (IsNULL(@cLottable04_Code, '') <> '') OR (IsNULL(@cLottable05_Code, '') <> '')
                     BEGIN

                        --initiate @nCounter = 1
                        SET @nCountLot = 1

                        --retrieve value for pre lottable01 - 05
                        WHILE @nCountLot <=5 --break the loop when @nCount >5
                        BEGIN
                           IF @nCountLot = 1
                           BEGIN
                              SET @cListName = 'Lottable01'
                              SET @cLottableLabel = @cLottable01_Code
                           END
                           ELSE
                           IF @nCountLot = 2
                           BEGIN
                              SET @cListName = 'Lottable02'
                              SET @cLottableLabel = @cLottable02_Code
                           END
                           ELSE
                           IF @nCountLot = 3
                           BEGIN
                              SET @cListName = 'Lottable03'
                              SET @cLottableLabel = @cLottable03_Code
                           END
                           ELSE
                           IF @nCountLot = 4
                           BEGIN
                              SET @cListName = 'Lottable04'
                              SET @cLottableLabel = @cLottable04_Code
                           END
                           ELSE
                           IF @nCountLot = 5
                           BEGIN
                              SET @cListName = 'Lottable05'
                              SET @cLottableLabel = @cLottable05_Code
                           END

                           --get short, store procedure and lottablelable value for each lottable
                           SET @cShort = ''
                           SET @cStoredProd = ''
                           SELECT @cShort = ISNULL(RTRIM(C.Short),''),
                                  @cStoredProd = IsNULL(RTRIM(C.Long), '')
                           FROM dbo.CodeLkUp C WITH (NOLOCK)
                           JOIN RDT.StorerConfig S WITH (NOLOCK) ON (C.ListName = S.ConfigKey AND C.Code = S.SValue)
                           WHERE C.ListName = @cListName
                           AND   C.Code = @cLottableLabel

                           IF @cShort = 'PRE' AND @cStoredProd <> ''
                           BEGIN

                              IF @cListName = 'Lottable01'
                                 SET @cLottable01 = ''
                              ELSE IF @cListName = 'Lottable02'
                                 SET @cLottable02 = ''
                              ELSE IF @cListName = 'Lottable03'
                                 SET @cLottable03 = ''
                              ELSE IF @cListName = 'Lottable04'
                                 SET @dLottable04 = ''
                              ELSE IF @cListName = 'Lottable05'
                                 SET @dLottable05 = ''

                              EXEC dbo.ispLottableRule_Wrapper
                                 @c_SPName            = @cStoredProd,
                                 @c_ListName          = @cListName,
                                 @c_Storerkey         = @cStorerKey,
                                 @c_Sku               = @cSKU,
                                 @c_LottableLabel     = @cLottableLabel,
                                 @c_Lottable01Value   = '',
                                 @c_Lottable02Value   = '',
                                 @c_Lottable03Value   = '',
                                 @dt_Lottable04Value  = '',
                                 @dt_Lottable05Value  = '',
                                 @c_Lottable01        = @cLottable01 OUTPUT,
                                 @c_Lottable02        = @cLottable02 OUTPUT,
                                 @c_Lottable03        = @cLottable03 OUTPUT,
                                 @dt_Lottable04       = @dLottable04 OUTPUT,
                                 @dt_Lottable05       = @dLottable05 OUTPUT,
                                 @b_Success           = @b_Success   OUTPUT,
                                 @n_Err               = @nErrNo      OUTPUT,
                                 @c_Errmsg            = @cErrMsg     OUTPUT,
                                 @c_Sourcekey         = @cSourcekey,
                                 @c_Sourcetype        = 'RDTRECEIPT'

                              --IF @b_success <> 1
                              IF ISNULL(@cErrMsg, '') <> ''
                              BEGIN
                                 SET @cErrMsg = @cErrMsg
                                 GOTO Step_1_Fail
                              END

                              SET @cLottable01 = IsNULL( @cLottable01, '')
                              SET @cLottable02 = IsNULL( @cLottable02, '')
                              SET @cLottable03 = IsNULL( @cLottable03, '')
                              SET @dLottable04 = IsNULL( @dLottable04, 0)
                              SET @dLottable05 = IsNULL( @dLottable05, 0)

                              IF @dLottable04 > 0
                              BEGIN
                                 SET @cLottable04 = RDT.RDTFormatDate(@dLottable04)
                              END

                              IF @dLottable05 > 0
                              BEGIN
                                 SET @cLottable05 = RDT.RDTFormatDate(@dLottable05)
                              END
                           END

                           -- increase counter by 1
                           SET @nCountLot = @nCountLot + 1
                        END -- nCount
                     END -- Lottable <> ''

                     /********************************************************************************************************************/
                     /* - End                                                                                                            */
                     /* Generic Lottables Computation (PRE): To compute Lottables before going to Lottable Screen                        */
                     /********************************************************************************************************************/

                     IF @cSkipLottable = '1'
                     BEGIN
                        SET @cSkipLottable01 = '1'
                        SET @cSkipLottable02 = '1'
                        SET @cSkipLottable03 = '1'
                        SET @cSkipLottable04 = '1'
                        SET @cHasLottable = '0'
                     END
                     ELSE
                     BEGIN
                        SET @cSkipLottable01 = rdt.RDTGetConfig( @nFunc, 'SkipLottable01', @cStorerKey)
                        SET @cSkipLottable02 = rdt.RDTGetConfig( @nFunc, 'SkipLottable02', @cStorerKey)
                        SET @cSkipLottable03 = rdt.RDTGetConfig( @nFunc, 'SkipLottable03', @cStorerKey)
                        SET @cSkipLottable04 = rdt.RDTGetConfig( @nFunc, 'SkipLottable04', @cStorerKey)
                     END

                     IF @cSkipLottable01 = '1' SELECT @cFieldAttr08 = 'O', @cInField08 = '', @cLottable01 = ''
                     IF @cSkipLottable02 = '1' SELECT @cFieldAttr09 = 'O', @cInField09 = '', @cLottable02 = ''
                     IF @cSkipLottable03 = '1' SELECT @cFieldAttr10 = 'O', @cInField10 = '', @cLottable03 = ''
                     IF @cSkipLottable04 = '1' SELECT @cFieldAttr11 = 'O', @cInField11 = '', @dLottable04 = 0

                     IF @cHasLottable = '1'
                     BEGIN

                        -- Disable lot label and lottable field
                        IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
                        BEGIN
                           SET @cFieldAttr08 = 'O'
                           SET @cOutField08 = ''
                        END
                        ELSE
                        BEGIN
                           -- Populate lot label and lottable
                           SELECT @cOutField08 = ISNULL(@cLottable01, '')
                        END

                        IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
                        BEGIN
                           SET @cFieldAttr09 = 'O'
                           SET @cOutField09 = ''
                        END
                        ELSE
                        BEGIN
                           SELECT @cOutField09 = ISNULL(@cLottable02, '')
                        END

                        IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
                        BEGIN
                           SET @cFieldAttr10 = 'O'
                           SET @cOutField10 = ''
                        END
                        ELSE
                        BEGIN
                           SELECT @cOutField10 = ISNULL(@cLottable03, '')
                        END

                        IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
                        BEGIN
                           SET @cFieldAttr11 = 'O'
                           SET @cOutField11 = ''
                        END
                        ELSE
                        BEGIN
                           SELECT @cOutField11 = RDT.RDTFormatDate(ISNULL(@cLottable04, ''))

                           -- Check if lottable04 is blank/is 01/01/1900 then no need to default anything and let user to scan (james07)
                           IF ISNULL(@cLottable04, '') = '' OR RDT.RDTFormatDate(@cLottable04) = '01/01/1900' OR RDT.RDTFormatDate(@cLottable04) = '1900/01/01'
                              SET @cOutField08 = ''
                        END
                     END

                     IF @cHasLottable = '0'
                     BEGIN
                        -- Not Lottable
                        SET @cLottable01 = ''
                        SET @cLottable02 = ''
                        SET @cLottable03 = ''
                        SET @cLottable04 = ''
                     END
               END

               -- Extended info
               IF @cExtendedInfoSP <> ''
               BEGIN
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
                  BEGIN
                     SET @cExtendedInfo = ''

                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY, ' +
                        ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                        ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                        ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                        ' @cExtendedInfo OUTPUT '

                     SET @cSQLParam =
                        '@nMobile         INT, ' +
                        '@nFunc           INT, ' +
                        '@cLangCode       NVARCHAR( 3), ' +
                        '@nStep           INT, ' +
                        '@nInputKey       INT, ' +
                        '@cStorerKey      NVARCHAR( 15), ' +
                        '@cTaskDetailKey  NVARCHAR( 10), ' +
                        '@cCCKey          NVARCHAR( 10), ' +
                        '@cCCDetailKey    NVARCHAR( 10), ' +
                        '@cLoc            NVARCHAR( 10), ' +
                        '@cID             NVARCHAR( 18), ' +
                        '@cSKU            NVARCHAR( 20), ' +
                        '@nActQTY         INT, ' +
                        '@cLottable01     NVARCHAR( 18), ' +
                        '@cLottable02     NVARCHAR( 18), ' +
                        '@cLottable03     NVARCHAR( 18), ' +
                        '@dLottable04     DATETIME, ' +
                        '@dLottable05     DATETIME, ' +
                        '@cLottable06     NVARCHAR( 30), ' +
                        '@cLottable07     NVARCHAR( 30), ' +
                        '@cLottable08     NVARCHAR( 30), ' +
                        '@cLottable09     NVARCHAR( 30), ' +
                        '@cLottable10     NVARCHAR( 30), ' +
                        '@cLottable11     NVARCHAR( 30), ' +
                        '@cLottable12     NVARCHAR( 30), ' +
                        '@dLottable13     DATETIME, ' +
                        '@dLottable14     DATETIME, ' +
                        '@dLottable15     DATETIME, ' +
                        '@cExtendedInfo   NVARCHAR( 20) OUTPUT '

                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                        @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY,
                        @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                        @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                        @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                        @cExtendedInfo OUTPUT

                     SET @cOutField15 = @cExtendedInfo
                  END
               END
               SET @cOutField14 = @cLoc
               SET @cOutField15 = CASE WHEN @cExtendedInfo <> '' THEN @cExtendedInfo ELSE '' END

               SET @cFieldAttr08 = 'O'
               SET @cFieldAttr09 = 'O'
               SET @cFieldAttr10 = 'O'
               SET @cFieldAttr11 = 'O'

		         -- Prepare Next Screen Variable
		         SET @cInField05 = ''
               SET @cInField06 = '' --SOS278025
               SET @cInField07 = '' --SOS278025

               IF @cFieldAttr12 = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 12
               ELSE
               BEGIN
                  IF @nPQTY > 0
                     EXEC rdt.rdtSetFocusField @nMobile, 06
                  ELSE
                     EXEC rdt.rdtSetFocusField @nMobile, 07
               END

               -- Set the entry point
               SET @nFunc = @nToFunc
               SET @nScn = 2941
               SET @nStep = 2

               GOTO QUIT
            END
            --ELSE
            --BEGIN
            --   -- Set the entry point
            --   SET @nFunc = @nToFunc
            --   SET @nScn = 2940
            --   SET @nStep = 1
            --END
         END

         IF @cDefaultCCOptionSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDefaultCCOptionSP AND type = 'P')
            BEGIN
               SET @cDefaultCCOption = ''
               SET @cSQL = 'EXEC rdt.' + RTRIM(@cDefaultCCOptionSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cDefaultCCOption OUTPUT '
               SET @cSQLParam =
                  '@nMobile            INT,           ' +
                  '@nFunc              INT,           ' +
                  '@cLangCode          NVARCHAR( 3),  ' +
                  '@nStep              INT,           ' +
                  '@nInputKey          INT,           ' +
                  '@cFacility          NVARCHAR( 15), ' +
                  '@cStorerKey         NVARCHAR( 15), ' +
                  '@cTaskdetailkey     NVARCHAR( 20),  ' +
                  '@cDefaultCCOption   NVARCHAR( 20)  OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cDefaultCCOption OUTPUT
            END
         END
         ELSE
         BEGIN
            IF EXISTS( SELECT 1 FROM STRING_SPLIT( @cFlowThruScreen, ',') WHERE TRIM( value) = '3') -- Statistic screen
            BEGIN
            	IF EXISTS ( SELECT 1
            	            FROM dbo.LOC WITH (NOLOCK)
            	            WHERE Facility = @cFacility
            	            AND   Loc = @cLoc
            	            AND   LoseUCC = '0')
                  SET @cInField03 = '1' -- UCC
               ELSE
               	SET @cInField03 = '2' -- SKU

               SET @cOutField01 = @cLoc
               SET @cOutField02 = ''

               SET @nScn = @nScn + 2
               SET @nStep = @nStep + 2
               GOTO Step_3
            END
         END

         -- prepare next screen variable
         SET @cOutField01 = @cLoc
         SET @cOutField02 = ''
         SET @cOutField03 = CASE WHEN @cDefaultCCOption = '' OR @cDefaultCCOption = '0' THEN '' ELSE @cDefaultCCOption END

         -- Go to CC option Screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2

         GOTO Quit
      END

      SET @cOutField01 = @cLoc
      SET @cOutField02 = ''


      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutfield04 = ''
      SET @cOutField05 = ''
      SET @cOutField09 = ''

      SET @nFromScn = @nScn
      SET @nFromStep = @nStep


      SET @nScn  = 2109
      SET @nStep = @nStep + 6 -- Step 7
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField02 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 2.
    Screen = 2871
    Loc (field01)
    ID (input, field02)
********************************************************************************/
Step_2:
BEGIN

   IF @nInputKey = 1 -- ENTER
   BEGIN

      -- Screen mapping
      SET @cID   = ISNULL(RTRIM(@cInField02),'')

      SET @nPrevStep = 0
      SET @nPrevScreen  = 0

      -- (james02)
      IF ISNULL(@cID, '') = '' AND
         EXISTS (SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cLoc AND LoseId = '0')
      BEGIN
         SET @nErrNo = 74447
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --pltid Req
         SET @cOutField02 = ''
         GOTO Quit
      END

      IF ISNULL( @cStorerKey, '') = '' OR @cStorerKey = 'ALL'
      BEGIN
         SELECT TOP 1 @cStorerKey = StorerKey
         FROM dbo.LotxLocxID WITH (NOLOCK)
         WHERE LOC = @cLoc
         AND ( Qty - QtyAllocated - QtyPicked) > 0
      END

      -- Pallet ID format check SP (james02)
      SET @cPalletIDChkSP = rdt.RDTGetConfig( @nFunc, 'PalletIDChkSP', @cStorerKey)
      IF @cPalletIDChkSP = '0'
         SET @cPalletIDChkSP = ''

      -- If pallet id check sp is setup then check format for pallet id keyed in (james02)
      IF ISNULL(@cPalletIDChkSP, '') <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPalletIDChkSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC ' + RTRIM( @cPalletIDChkSP) +
               ' @nMobile, @nFunc, @cLangCode, @cID, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,        ' +
               '@nFunc         INT,        ' +
               '@cLangCode     NVARCHAR( 3), ' +
               '@cID           NVARCHAR( 18), ' +
               '@nErrNo        INT OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @cID, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 74448
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Plt ID
               SET @cOutField02 = ''
               GOTO Quit
            END
         END
      END

      -- If turn on UCC config then goto option screen to let user choose
      -- whether they want count by UCC or SKU. Else by default is SKU
      SET @cStorerConfig_UCC = '0' -- Default Off
      SELECT @cStorerConfig_UCC = CASE WHEN SValue = '1' THEN '1' ELSE '0' END
      FROM dbo.StorerConfig (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ConfigKey = 'UCC'

      IF @cStorerConfig_UCC <> '1'
      BEGIN
          -- (james01)
         IF EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                    WHERE Facility = @cFacility
                    AND   LOC = @cSuggFromLoc
                    AND   LoseUCC = '0')
         BEGIN
            SET @nErrNo = 74450
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC X LOSEUCC
       SET @cOutField02 = ''
            GOTO Quit
         END

         EXEC rdt.rdt_TM_CycleCount_InsertCCDetail
            @nMobile          = @nMobile
           ,@c_TaskDetailKey  = @cTaskdetailkey
           ,@nErrNo           = @nErrNo
           ,@cErrMsg          = @cErrMsg
           ,@cLangCode        = @cLangCode
           ,@c_StorerKey      = @cStorerKey
           ,@c_Loc            = @cSuggFromLoc
           ,@c_Facility       = @cFacility
           ,@c_PickMethod     = @cPickMethod
           ,@c_CCOptions      = '2'
           ,@c_SourceKey      = @cCCKey

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            SET @cOutField02 = ''
            GOTO Quit
         END

         -- (james10)
         -- Extended info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''
               SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cFromLoc, @cID, @cPickMethod, ' +
                  ' @tExtInfo, @cExtendedInfo OUTPUT '
               SET @cSQLParam =
                  '@nMobile         INT,           ' +
                  '@nFunc           INT,           ' +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,           ' +
                  '@nInputKey       INT,           ' +
                  '@cFacility       NVARCHAR( 15), ' +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cTaskdetailkey  NVARCHAR( 20),  ' +
                  '@cFromLoc        NVARCHAR( 20),  ' +
                  '@cID             NVARCHAR( 20),  ' +
                  '@cPickMethod     NVARCHAR( 20),  ' +
                  '@tExtInfo        VariableTable READONLY, ' +
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cSuggFromLoc, @cID, @cPickMethod,
                  @tExtInfo, @cExtendedInfo OUTPUT

               SET @cOutField15 = @cExtendedInfo
            END
         END

         SET @nToFunc = 1768

         SET @cOutField01 = @cLoc
         SET @cOutField02 = @cID
         SET @cOutField03 = ''

         SET @cOutField04 = ''
         SET @cOutField05 = ''

         SET @cFieldAttr04 = 'O'
         SET @cFieldAttr05 = 'O'


         IF @cPickMethod = 'SKU'
         BEGIN
            SET @cOutField06 =  ISNULL(@cSuggSKU,'')
         END
         ELSE
         BEGIN
            SET @cOutField06 = ''
         END

         SET @cOutField07 = @cPickMethod

         SET @nPrevStep = 0
         SET @nPrevScreen = 0

         -- Set the entry point
         SET @nFunc = @nToFunc
         SET @nScn = 2940
         SET @nStep = 1

         GOTO QUIT
      END

      /****************************
       prepare next screen variable
      ****************************/
      IF @cDefaultCCOptionSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDefaultCCOptionSP AND type = 'P')
         BEGIN
            SET @cDefaultCCOption = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cDefaultCCOptionSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cDefaultCCOption OUTPUT '
            SET @cSQLParam =
               '@nMobile            INT,           ' +
               '@nFunc              INT,           ' +
               '@cLangCode          NVARCHAR( 3),  ' +
               '@nStep              INT,           ' +
               '@nInputKey          INT,           ' +
               '@cFacility          NVARCHAR( 15), ' +
               '@cStorerKey         NVARCHAR( 15), ' +
               '@cTaskdetailkey     NVARCHAR( 20),  ' +
               '@cDefaultCCOption   NVARCHAR( 20)  OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cDefaultCCOption OUTPUT
         END
      END
      ELSE
      BEGIN
         IF EXISTS( SELECT 1 FROM STRING_SPLIT( @cFlowThruScreen, ',') WHERE TRIM( value) = '3') -- Statistic screen
         BEGIN
            IF EXISTS ( SELECT 1
            	         FROM dbo.LOC WITH (NOLOCK)
            	         WHERE Facility = @cFacility
            	         AND   Loc = @cLoc
            	         AND   LoseUCC = '0')
               SET @cInField03 = '1' -- UCC
            ELSE
               SET @cInField03 = '2' -- SKU

            SET @cOutField01 = @cLoc
            SET @cOutField02 = @cID

            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
            GOTO Step_3
         END
      END

      -- prepare next screen variable
      SET @cOutField01 = @cLoc
      SET @cOutField02 = @cID
      SET @cOutField03 = CASE WHEN @cDefaultCCOption = '' OR @cDefaultCCOption = '0' THEN '' ELSE @cDefaultCCOption END

      -- Go to CC option Screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      GOTO Quit

      --SET @cDefaultCCOption = ''
      --SET @cDefaultCCOption = rdt.RDTGetConfig( @nFunc, 'DefaultCCOption', @cStorerkey)

      --IF @cDefaultCCOption <> ''  AND @cDefaultCCOption <> '0'
      --BEGIN
      --   SET @cOutField03 = @cDefaultCCOption
      --END
      --ELSE
      --BEGIN
      --   SET @cOutField03 = ''
      --END

      --SET @cOutField01 = @cLoc
      --SET @cOutField02 = @cID

      ---- Go to SKU / UPC Screen
      --SET @nScn = @nScn + 1
      --SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField10 = @cSuggFromLoc
      SET @cOutField11 = CASE WHEN @cTTMTasktype = 'CCSUP' THEN '(S)' ELSE '' END   -- (james01)
      SET @cOutField01 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField02 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 3.
    Screen = 2872
    Loc (field01)
    ID  (field02)
    Options  (input, field03)
********************************************************************************/
Step_3:
BEGIN

   IF @nInputKey = 1 -- ENTER
   BEGIN

      -- Screen mapping
      SET @cOptions   = ISNULL(RTRIM(@cInField03),'')

      /****************************
       VALIDATION
      ****************************/
      --When Options is blank
      IF @cOptions = ''
      BEGIN
         SET @nErrNo = 74416
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Req
         GOTO Step_3_Fail
      END

      IF @cOptions NOT IN ('1', '2', '3')
      BEGIN
         SET @nErrNo = 74417
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Option
         GOTO Step_3_Fail
      END



      IF @cOptions = '1'
      BEGIN
         -- (james01)
         IF EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                    WHERE Facility = @cFacility
                    AND   LOC = @cSuggFromLoc
                    AND   LoseUCC = '1')
         BEGIN
            SET @nErrNo = 74444
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC IS LOSEUCC
            GOTO Step_3_Fail
         END

         EXEC rdt.rdt_TM_CycleCount_InsertCCDetail
            @nMobile          = @nMobile
           ,@c_TaskDetailKey  = @cTaskdetailkey
           ,@nErrNo           = @nErrNo
           ,@cErrMsg          = @cErrMsg
           ,@cLangCode        = @cLangCode
           ,@c_StorerKey      = @cStorerKey
           ,@c_Loc            = @cSuggFromLoc
           ,@c_Facility       = @cFacility
           ,@c_PickMethod     = @cPickMethod
           ,@c_CCOptions      = '1'
           ,@c_SourceKey      = @cCCKey

        IF @nErrNo <> 0
        BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Step_3_Fail
        END

         SET @nToFunc = 1767

         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cOutField11 = ''
         SET @cOutField15 = ''

         EXEC rdt.rdtSetFocusField @nMobile, 1

         SET @nPrevStep = 0
         SET @nPrevScreen = 0

         -- Set the entry point
         SET @nFunc = @nToFunc
         SET @nScn = 2930
         SET @nStep = 1

         GOTO QUIT
      END
      ELSE IF @cOptions = '2'
      BEGIN
          -- (james01)
         IF EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                    WHERE Facility = @cFacility
                    AND   LOC = @cSuggFromLoc
                    AND   LoseUCC = '0')
         BEGIN
            SET @nErrNo = 74445
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC X LOSEUCC
            GOTO Step_3_Fail
         END

         EXEC rdt.rdt_TM_CycleCount_InsertCCDetail
            @nMobile          = @nMobile
           ,@c_TaskDetailKey  = @cTaskdetailkey
           ,@nErrNo           = @nErrNo
           ,@cErrMsg          = @cErrMsg
           ,@cLangCode        = @cLangCode
           ,@c_StorerKey      = @cStorerKey
           ,@c_Loc            = @cSuggFromLoc
           ,@c_Facility       = @cFacility
           ,@c_PickMethod     = @cPickMethod
           ,@c_CCOptions      = '2'
           ,@c_SourceKey      = @cCCKey

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Step_3_Fail
         END

         SET @nToFunc = 1768

         SET @cOutField01 = @cLoc
         SET @cOutField02 = @cID
         SET @cOutField03 = ''

         SET @cOutField04 = ''
         SET @cOutField05 = ''

         SET @cFieldAttr04 = 'O'
         SET @cFieldAttr05 = 'O'


         IF @cPickMethod = 'SKU'
         BEGIN
            SET @cOutField06 =  ISNULL(@cSuggSKU,'')
         END
         ELSE
         BEGIN
            SET @cOutField06 = ''
         END

         SET @cOutField07 = @cPickMethod

         SET @nPrevStep = 0
         SET @nPrevScreen = 0

         ---- Set the entry point
         --SET @nFunc = @nToFunc
         ----SET @nScn = 2940
         ----SET @nStep = 1

         IF @cTMCCSKUSkipScreen1 = '1'
         BEGIN
            /*************************************/
            SELECT @cPUOM = V_UOM,
                   @cStorerKey = StorerKey
            FROM RDT.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile



            INSERT INTO traceinfo(TraceName, TimeIn, Col1, Col2) VALUES ('123', GETDATE(), @cSuggSKU, @cTaskDetailKey)
            SET @cSKU = @cSuggSKU
            SET @cSkipLottable = rdt.RDTGetConfig( @nFunc, 'SkipLottable', @cStorerKey)

            -- Get stored proc name for extended info (james40)
            SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
            IF @cExtendedInfoSP = '0'
               SET @cExtendedInfoSP = ''

            -- (james03)
            SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
            IF @cDecodeSP = '0'
               SET @cDecodeSP = ''


            SET @cSKUDescr = ''
            SET @cMUOM_Desc = ''
            SET @cPUOM_Desc = ''

            SET @nQtyAval = 0
            SET @nQty = 0
            SET @nPUOM_Div = 0
            SET @nMQTY = 0
            SET @nPQTY = 0

            SET @cLottable01 = ''
            SET @cLottable02 = ''
            SET @cLottable03 = ''
            SET @dLottable04 = NULL
            SET @dLottable05 = NULL

            SELECT
                 @cSKUDescr = SKU.DESCR
               , @cMUOM_Desc  = Pack.PackUOM3
               , @cPUOM_Desc  =
               CASE @cPUOM
                  WHEN '2' THEN Pack.PackUOM1 -- Case
                  WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                  WHEN '6' THEN Pack.PackUOM3 -- Master unit
                  WHEN '1' THEN Pack.PackUOM4 -- Pallet
                  WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                  WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
               END
               ,  @nPUOM_Div  = CAST( IsNULL(
               CASE @cPUOM
                  WHEN '2' THEN Pack.CaseCNT
                  WHEN '3' THEN Pack.InnerPack
                  WHEN '6' THEN Pack.QTY
                  WHEN '1' THEN Pack.Pallet
                  WHEN '4' THEN Pack.OtherUnit1
                  WHEN '5' THEN Pack.OtherUnit2
               END, 1) AS INT)
            FROM dbo.SKU SKU WITH (NOLOCK)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE SKU.SKU = @cSKU
              AND SKU.StorerKey = @cStorerKey

            SET @cCCDetailKey = ''

            SET @cCCGroupExLottable05 = ''
            SET @cCCGroupExLottable05 = rdt.RDTGetConfig( @nFunc, 'CCGroupExLottable05', @cStorerkey)

            IF @cCCGroupExLottable05 = '1'
            BEGIN
               SELECT TOP 1
                        @cLottable01 = CC.Lottable01
                      , @cLottable02 = CC.Lottable02
                      , @cLottable03 = CC.Lottable03
                      , @dLottable04 = CC.Lottable04  --yeekung01
                      , @nQtyAval    =  SUM(CC.SystemQty)
                      , @cCCDetailKey = MIN(CC.CCDetailKey)
                      , @nQty        = SUM(CC.Qty)
               FROM dbo.CCDetail CC WITH (NOLOCK)
               WHERE CC.SKU = @cSKU
               AND CC.CCKey = @cCCKey
               AND CC.Loc   = @cLoc
               AND CC.ID    = @cID
               AND Status < '9'
               AND CC.CCSheetNo = @cTaskDetailKey
               GROUP BY CC.Lottable01, CC.Lottable02, CC.Lottable03, CC.Lottable04
               ORDER BY MIN(CC.CCDetailKey)

               SET @nLottableCountTotal = 0
               SELECT @nLottableCountTotal =  COUNT(1)
               FROM dbo.CCDetail CC WITH (NOLOCK)
               WHERE CC.SKU = @cSKU
               AND CC.CCKey = @cCCKey
               AND CC.Loc   = @cLoc
               AND CC.ID    = @cID
               AND Status < '9'
               AND CC.CCSheetNo = @cTaskDetailKey
               GROUP BY CC.Lottable01, CC.Lottable02, CC.Lottable03, CC.Lottable04
            END
            ELSE
            BEGIN
               SELECT TOP 1
                        @cLottable01 = CC.Lottable01
                      , @cLottable02 = CC.Lottable02
                      , @cLottable03 = CC.Lottable03
  							      , @dLottable04 = CC.Lottable04  --yeekung01
                      , @dLottable05 = CC.Lottable05  --yeekung01
                      , @nQtyAval    =  CC.SystemQty
                      , @cCCDetailKey = CC.CCDetailKey
                      , @nQty        = CC.Qty
               FROM dbo.CCDetail CC WITH (NOLOCK)
               WHERE CC.SKU = @cSKU
               AND CC.CCKey = @cCCKey
               AND CC.Loc   = @cLoc
               AND CC.ID    = @cID
               AND Status < '9'
               AND CC.CCSheetNo = @cTaskDetailKey
               ORDER BY CCDetailKey

               SET @nLottableCountTotal = 0
               SELECT @nLottableCountTotal = COUNT(1)
               FROM dbo.CCDetail CC WITH (NOLOCK)
               WHERE CC.SKU = @cSKU
               AND CC.CCKey = @cCCKey
               AND CC.Loc   = @cLoc
               AND CC.ID    = @cID
               AND Status < '9'
               AND CC.CCSheetNo = @cTaskDetailKey
            END

            SET @cCounted = ''

            IF EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                        WHERE CCKey = @cCCKey
                        AND SKU = @cSKU
                        AND Loc = @cLoc
                        AND ID  = @cID
                        AND Status < '9'
                        AND Qty > 0
                        AND CCSheetNo = @cTaskDetailKey
                        AND CCdetailKey = @cCCDetailKey)
            BEGIN
               SET @nQtyAval = @nQty
               SET @cCounted = '1'
            END

            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
               SET @nPQTY = 0
               SET @nMQTY = @nQtyAval
            END
            ELSE
            BEGIN
               SET @nPQTY = @nQtyAval / @nPUOM_Div  -- Calc QTY in preferred UOM
               SET @nMQTY = @nQtyAval % @nPUOM_Div  -- Calc the remaining in master unit
            END

            -- Prepare Next Screen Variable
            SET @cSKUDescr1 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
		      SET @cSKUDescr2 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 1

            SET @cOutField01 = @cSKU
            SET @cOutField02 = @cSKUDescr1
            SET @cOutField03 = @cSKUDescr2

            SET @nLottableCount = 0
            SET @cOutField13 = CASE WHEN @cSkipLottable = '1' THEN ''
                                    ELSE RTRIM(CAST(@nLottableCount AS NVARCHAR(4))) +  '/' +
                                         RTRIM(CAST(@nLottableCountTotal AS NVARCHAR(4)))
                                    END

            IF @cPUOM_Desc = ''
            BEGIN
               SET @cOutField04 = ''
               SET @cOutField06 = ''
               SET @cFieldAttr06 = 'O'
            END
            ELSE
            BEGIN
               SET @cOutField04 = @cPUOM_Desc
               IF @cCounted = '1'
               BEGIN
                  SET @cOutField06 = CAST( @nPQTY AS NVARCHAR( 5))
               END
               ELSE
               BEGIN
                  SET @cOutField06 = ''
               END
            END

            IF @nPQTY <= 0
            BEGIN
               --SET @cOutField04 = ''
               SET @cOutField06 = ''
               SET @cOutField06 = ''
               SET @cFieldAttr06 = 'O'
            END

            SET @cOutField05 = @cMUOM_Desc

            IF @cCounted = '1'
            BEGIN
               SET @cOutField07 = CAST( @nMQTY AS NVARCHAR( 5))
            END
            ELSE
            BEGIN
               SET @cOutField07 = ''
            END

            SET @cFieldAttr07 = ''

            IF @nPQTY > 0
               EXEC rdt.rdtSetFocusField @nMobile, 06
            ELSE
               EXEC rdt.rdtSetFocusField @nMobile, 07

            SET @cFieldAttr08 = 'O'
            SET @cFieldAttr09 = 'O'
            SET @cFieldAttr10 = 'O'
            SET @cFieldAttr11 = 'O'

            IF @cSkipLottable = '1'
            BEGIN
               SET @cOutField08 = ''
               SET @cOutField09 = ''
               SET @cOutField10 = ''
               SET @cOutField11 = ''
            END
            ELSE
            BEGIN
               SET @cOutField08 = @cLottable01
               SET @cOutField09 = @cLottable02
               SET @cOutField10 = @cLottable03
               SET @cOutField11 = rdt.rdtFormatDate( @dLottable04)
            END

            SET @cFieldAttr06 = ''
            SET @cFieldAttr07 = ''
            SET @cFieldAttr12 = ''

            SET @nDefaultQty = 0

            -- if default qty turned on then overwrite the actual MQty (james02)
		      SET @cDefaultQty = rdt.RDTGetConfig( @nFunc, 'TMCCDefaultQty', @cStorerkey)
            IF RDT.rdtIsValidQTY( @cDefaultQty, 1) = 1
               SET @nDefaultQty = CAST( @cDefaultQty AS INT)
            ELSE
               SET @nDefaultQty = 0

            IF @nDefaultQty > 0
            BEGIN
               SET @cFieldAttr12 = ''
               SET @cOutField12 = ''
               SET @cFieldAttr06 = 'O'
               SET @cFieldAttr07 = 'O'

               -- Convert to prefer UOM QTY
               IF @cPUOM = '6' OR -- When preferred UOM = master unit
                  @nPUOM_Div = 0  -- UOM not setup
                  SET @cOutField07 = @nDefaultQty
               ELSE
               BEGIN
                  IF @nDefaultQty > @nPUOM_Div
                  BEGIN
                     SET @cOutField06 = @nDefaultQty / @nPUOM_Div  -- Calc QTY in preferred UOM
                     SET @cOutField07 = @nDefaultQty % @nPUOM_Div  -- Calc the remaining in master unit
                  END
                  ELSE
                     SET @cOutField07 = @nDefaultQty
               END
            END
            ELSE
            BEGIN
               SET @cFieldAttr12 = 'O'
               SET @cOutField12 = ''
            END

            SET @cNewSKUorLottable = ''

            IF NOT EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
	                         WHERE CCKey = @cCCKey
	                         AND Loc     = @cLoc
	                         AND ID      = @cID
	                         AND SKU     = @cSKU
	                         AND Status  < '9'
	                         AND CCSheetNo = @cTaskDetailKey  )
            BEGIN
                  -- SET to 1 for New Found SKU or Lottables
                  SET @cNewSKUorLottable = '1'

                  SET @cFieldAttr08 = ''
                  SET @cFieldAttr09 = ''
                  SET @cFieldAttr10 = ''
                  SET @cFieldAttr11 = ''
                  SET @cFieldAttr12 = ''
                  SET @cFieldAttr13 = ''
                  SET @cFieldAttr14 = ''
                  SET @cFieldAttr15 = ''

                  -- (james02)
                  SELECT
                     @cLotLabel01 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable01Label AND C.ListName = 'LOTTABLE01' AND C.Code <> '' AND (C.StorerKey = @cStorerKey OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),
                     @cLotLabel02 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> '' AND (C.StorerKey = @cStorerKey OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),
                     @cLotLabel03 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> '' AND (C.StorerKey = @cStorerKey OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),
                     @cLotLabel04 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> '' AND (C.StorerKey = @cStorerKey OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),
                     @cLotLabel05 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable05Label AND C.ListName = 'LOTTABLE05' AND C.Code <> '' AND (C.StorerKey = @cStorerKey OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),
                     @cLottable05_Code = IsNULL(S.Lottable05Label, ''),
                     @cLottable01_Code = IsNULL(S.Lottable01Label, ''),
                     @cLottable02_Code = IsNULL(S.Lottable02Label, ''),
                     @cLottable03_Code = IsNULL(S.Lottable03Label, ''),
                     @cLottable04_Code = IsNULL(S.Lottable04Label, '')
                  FROM dbo.SKU S WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND SKU = @cSKU

                  -- Turn on lottable flag (use later)
                  SET @cHasLottable = '0'
                  IF (@cLotLabel01 <> '' AND @cLotLabel01 IS NOT NULL) OR
                     (@cLotLabel02 <> '' AND @cLotLabel02 IS NOT NULL) OR
                     (@cLotLabel03 <> '' AND @cLotLabel03 IS NOT NULL) OR
                     (@cLotLabel04 <> '' AND @cLotLabel04 IS NOT NULL) OR
                     (@cLotLabel05 <> '' AND @cLotLabel05 IS NOT NULL)
                  BEGIN
                     SET @cHasLottable = '1'
                  END

                  /********************************************************************************************************************/
                  /*  - Start                                                                                                         */
                  /* Generic Lottables Computation (PRE): To compute Lottables before going to Lottable Screen                        */
                  /* Setup spname in CODELKUP.Long where ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05'  */
                  /* 1. Setup RDT.Storerconfigkey = <Lottable01/02/03/04/05> , sValue = <Lottable01/02/03/04/05Label>                 */
                  /* 2. Setup Codelkup.Listname = ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05' and     */
                  /*    Codelkup.Short = 'PRE' and Codelkup.Long = <SP Name>                                                          */
                  /********************************************************************************************************************/

                  IF (IsNULL(@cLottable01_Code, '') <> '') OR (IsNULL(@cLottable02_Code, '') <> '') OR (IsNULL(@cLottable03_Code, '') <> '') OR
                     (IsNULL(@cLottable04_Code, '') <> '') OR (IsNULL(@cLottable05_Code, '') <> '')
                  BEGIN

                     --initiate @nCounter = 1
                     SET @nCountLot = 1

                     --retrieve value for pre lottable01 - 05
                     WHILE @nCountLot <=5 --break the loop when @nCount >5
                     BEGIN
                        IF @nCountLot = 1
                        BEGIN
                           SET @cListName = 'Lottable01'
                           SET @cLottableLabel = @cLottable01_Code
                        END
                        ELSE
                        IF @nCountLot = 2
                        BEGIN
                           SET @cListName = 'Lottable02'
                           SET @cLottableLabel = @cLottable02_Code
                        END
                        ELSE
                        IF @nCountLot = 3
                        BEGIN
                           SET @cListName = 'Lottable03'
                           SET @cLottableLabel = @cLottable03_Code
                        END
                        ELSE
                        IF @nCountLot = 4
                        BEGIN
                           SET @cListName = 'Lottable04'
                           SET @cLottableLabel = @cLottable04_Code
                        END
                        ELSE
                        IF @nCountLot = 5
                        BEGIN
                           SET @cListName = 'Lottable05'
                           SET @cLottableLabel = @cLottable05_Code
                        END

                        --get short, store procedure and lottablelable value for each lottable
                        SET @cShort = ''
                        SET @cStoredProd = ''
                        SELECT @cShort = ISNULL(RTRIM(C.Short),''),
                               @cStoredProd = IsNULL(RTRIM(C.Long), '')
                        FROM dbo.CodeLkUp C WITH (NOLOCK)
                        JOIN RDT.StorerConfig S WITH (NOLOCK) ON (C.ListName = S.ConfigKey AND C.Code = S.SValue)
                        WHERE C.ListName = @cListName
                        AND   C.Code = @cLottableLabel

                        IF @cShort = 'PRE' AND @cStoredProd <> ''
                        BEGIN

                           IF @cListName = 'Lottable01'
                              SET @cLottable01 = ''
                           ELSE IF @cListName = 'Lottable02'
                              SET @cLottable02 = ''
                           ELSE IF @cListName = 'Lottable03'
                              SET @cLottable03 = ''
                           ELSE IF @cListName = 'Lottable04'
                              SET @dLottable04 = ''
                           ELSE IF @cListName = 'Lottable05'
                              SET @dLottable05 = ''

                           EXEC dbo.ispLottableRule_Wrapper
                              @c_SPName            = @cStoredProd,
                              @c_ListName          = @cListName,
                              @c_Storerkey         = @cStorerKey,
                              @c_Sku               = @cSKU,
                              @c_LottableLabel     = @cLottableLabel,
                              @c_Lottable01Value   = '',
                              @c_Lottable02Value   = '',
                              @c_Lottable03Value   = '',
                              @dt_Lottable04Value  = '',
                              @dt_Lottable05Value  = '',
                              @c_Lottable01        = @cLottable01 OUTPUT,
                              @c_Lottable02        = @cLottable02 OUTPUT,
                              @c_Lottable03        = @cLottable03 OUTPUT,
                              @dt_Lottable04       = @dLottable04 OUTPUT,
                              @dt_Lottable05       = @dLottable05 OUTPUT,
                              @b_Success           = @b_Success   OUTPUT,
                              @n_Err               = @nErrNo      OUTPUT,
                              @c_Errmsg            = @cErrMsg     OUTPUT,
                              @c_Sourcekey         = @cSourcekey,
                              @c_Sourcetype        = 'RDTRECEIPT'

                           --IF @b_success <> 1
                           IF ISNULL(@cErrMsg, '') <> ''
                           BEGIN
                              SET @cErrMsg = @cErrMsg
                              GOTO Step_1_Fail
                           END

                           SET @cLottable01 = IsNULL( @cLottable01, '')
                           SET @cLottable02 = IsNULL( @cLottable02, '')
                           SET @cLottable03 = IsNULL( @cLottable03, '')
                           SET @dLottable04 = IsNULL( @dLottable04, 0)
                           SET @dLottable05 = IsNULL( @dLottable05, 0)

                           IF @dLottable04 > 0
                           BEGIN
                              SET @cLottable04 = RDT.RDTFormatDate(@dLottable04)
                           END

                           IF @dLottable05 > 0
                           BEGIN
                              SET @cLottable05 = RDT.RDTFormatDate(@dLottable05)
                           END
                        END

                        -- increase counter by 1
                        SET @nCountLot = @nCountLot + 1
                     END -- nCount
                  END -- Lottable <> ''

                  /********************************************************************************************************************/
                  /* - End                                        */
                  /* Generic Lottables Computation (PRE): To compute Lottables before going to Lottable Screen                        */
                  /********************************************************************************************************************/

                  IF @cSkipLottable = '1'
                  BEGIN
                     SET @cSkipLottable01 = '1'
                     SET @cSkipLottable02 = '1'
                     SET @cSkipLottable03 = '1'
                     SET @cSkipLottable04 = '1'
                     SET @cHasLottable = '0'
                  END
                  ELSE
                  BEGIN
                     SET @cSkipLottable01 = rdt.RDTGetConfig( @nFunc, 'SkipLottable01', @cStorerKey)
                     SET @cSkipLottable02 = rdt.RDTGetConfig( @nFunc, 'SkipLottable02', @cStorerKey)
                     SET @cSkipLottable03 = rdt.RDTGetConfig( @nFunc, 'SkipLottable03', @cStorerKey)
                     SET @cSkipLottable04 = rdt.RDTGetConfig( @nFunc, 'SkipLottable04', @cStorerKey)
                  END

                  IF @cSkipLottable01 = '1' SELECT @cFieldAttr08 = 'O', @cInField08 = '', @cLottable01 = ''
                  IF @cSkipLottable02 = '1' SELECT @cFieldAttr09 = 'O', @cInField09 = '', @cLottable02 = ''
                  IF @cSkipLottable03 = '1' SELECT @cFieldAttr10 = 'O', @cInField10 = '', @cLottable03 = ''
                  IF @cSkipLottable04 = '1' SELECT @cFieldAttr11 = 'O', @cInField11 = '', @dLottable04 = 0

                  IF @cHasLottable = '1'
                  BEGIN

                     -- Disable lot label and lottable field
                     IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
                     BEGIN
                        SET @cFieldAttr08 = 'O'
                        SET @cOutField08 = ''
                     END
                     ELSE
                     BEGIN
                        -- Populate lot label and lottable
                        SELECT @cOutField08 = ISNULL(@cLottable01, '')
                     END

                     IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
                     BEGIN
                        SET @cFieldAttr09 = 'O'
                        SET @cOutField09 = ''
                     END
                     ELSE
                     BEGIN
                        SELECT @cOutField09 = ISNULL(@cLottable02, '')
                     END

                     IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
                     BEGIN
                        SET @cFieldAttr10 = 'O'
                        SET @cOutField10 = ''
                     END
                     ELSE
                     BEGIN
                        SELECT @cOutField10 = ISNULL(@cLottable03, '')
                     END

                     IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
                     BEGIN
                        SET @cFieldAttr11 = 'O'
                        SET @cOutField11 = ''
                     END
                     ELSE
                     BEGIN
                        SELECT @cOutField11 = RDT.RDTFormatDate(ISNULL(@cLottable04, ''))

                        -- Check if lottable04 is blank/is 01/01/1900 then no need to default anything and let user to scan (james07)
                        IF ISNULL(@cLottable04, '') = '' OR RDT.RDTFormatDate(@cLottable04) = '01/01/1900' OR RDT.RDTFormatDate(@cLottable04) = '1900/01/01'
                           SET @cOutField08 = ''
                     END
                  END

                  IF @cHasLottable = '0'
                  BEGIN
                     -- Not Lottable
                     SET @cLottable01 = ''
                     SET @cLottable02 = ''
                     SET @cLottable03 = ''
                     SET @cLottable04 = ''
                  END
            END

            -- Extended info
            IF @cExtendedInfoSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
               BEGIN
                  SET @cExtendedInfo = ''

                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY, ' +
                     ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                     ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                     ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                     ' @cExtendedInfo OUTPUT '

                  SET @cSQLParam =
                     '@nMobile         INT, ' +
                     '@nFunc           INT, ' +
                     '@cLangCode       NVARCHAR( 3), ' +
                     '@nStep           INT, ' +
                     '@nInputKey       INT, ' +
                     '@cStorerKey      NVARCHAR( 15), ' +
                     '@cTaskDetailKey  NVARCHAR( 10), ' +
                     '@cCCKey          NVARCHAR( 10), ' +
                     '@cCCDetailKey    NVARCHAR( 10), ' +
                     '@cLoc            NVARCHAR( 10), ' +
                     '@cID             NVARCHAR( 18), ' +
                     '@cSKU            NVARCHAR( 20), ' +
                     '@nActQTY         INT, ' +
                     '@cLottable01     NVARCHAR( 18), ' +
                     '@cLottable02     NVARCHAR( 18), ' +
                     '@cLottable03     NVARCHAR( 18), ' +
                     '@dLottable04     DATETIME, ' +
                     '@dLottable05     DATETIME, ' +
                     '@cLottable06     NVARCHAR( 30), ' +
                     '@cLottable07     NVARCHAR( 30), ' +
                     '@cLottable08     NVARCHAR( 30), ' +
                     '@cLottable09     NVARCHAR( 30), ' +
                     '@cLottable10     NVARCHAR( 30), ' +
                     '@cLottable11     NVARCHAR( 30), ' +
                     '@cLottable12     NVARCHAR( 30), ' +
                     '@dLottable13     DATETIME, ' +
                     '@dLottable14     DATETIME, ' +
                     '@dLottable15     DATETIME, ' +
                     '@cExtendedInfo   NVARCHAR( 20) OUTPUT '

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cTaskDetailKey, @cCCKey, @cCCDetailKey, @cLoc, @cID, @cSKU, @nActQTY,
                     @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                     @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                     @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                     @cExtendedInfo OUTPUT

                  SET @cOutField15 = @cExtendedInfo
               END
            END
            SET @cOutField14 = @cLoc
            SET @cOutField15 = CASE WHEN @cExtendedInfo <> '' THEN @cExtendedInfo ELSE '' END

		      -- Prepare Next Screen Variable
		      SET @cInField05 = ''
            SET @cInField06 = '' --SOS278025
            SET @cInField07 = '' --SOS278025

		      -- GOTO Next Screen
		      --SET @nScn = @nScn + 1
	       --  SET @nStep = @nStep + 1
                  --SET @nScn = 2941
                  --SET @nStep = 2

            IF @cFieldAttr12 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 12
            ELSE
            BEGIN
               IF @nPQTY > 0
                  EXEC rdt.rdtSetFocusField @nMobile, 06
               ELSE
                  EXEC rdt.rdtSetFocusField @nMobile, 07
            END

            -- Set the entry point
            SET @nFunc = @nToFunc
            SET @nScn = 2941
            SET @nStep = 2
         END
         ELSE
         BEGIN
            -- Set the entry point
            SET @nFunc = @nToFunc
            SET @nScn = 2940
            SET @nStep = 1
         END
      END
      ELSE IF @cOptions = '3'
      BEGIN
         -- Count by ID must only count Loc with have LoseID set to value other than '1'
         IF EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                    WHERE LOC = @cLOC
                    AND   Facility = @cFacility
                    AND   LoseID = '1')
         BEGIN
            SET @nErrNo = 57954
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'LOC LOSEID'
            GOTO Step_3_Fail
         END

         EXEC rdt.rdt_TM_CycleCount_InsertCCDetail
            @nMobile          = @nMobile
           ,@c_TaskDetailKey  = @cTaskdetailkey
           ,@nErrNo           = @nErrNo
           ,@cErrMsg          = @cErrMsg
           ,@cLangCode        = @cLangCode
           ,@c_StorerKey      = @cStorerKey
           ,@c_Loc            = @cSuggFromLoc
           ,@c_Facility       = @cFacility
           ,@c_PickMethod     = @cPickMethod
           ,@c_CCOptions      = '1'
           ,@c_SourceKey      = @cCCKey

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Step_3_Fail
         END

         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cOutField11 = ''
         SET @cOutField15 = ''

         -- Prepare next screen var
         SET @cOutField01 = @cID
         SET @cOutField02 = ''

         SET @nPrevStep = 0
         SET @nPrevScreen = 0

         SET @nToFunc = 1769

         -- Set the entry point
         SET @nFunc = @nToFunc
         SET @nScn = 2950
         SET @nStep = 1

         GOTO QUIT
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN

      -- If loc.loseid = 1 then no need scan pallet id. Skip the screen (james02)
      IF EXISTS (SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cLoc AND LoseId = '1')
      BEGIN
         -- prepare next screen variable
         SET @cOutField10 = @cSuggFromLoc
         SET @cOutField11 = CASE WHEN @cTTMTasktype = 'CCSUP' THEN '(S)' ELSE '' END   -- (james01)
         SET @cOutField01 = ''

         -- Go to Loc Screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2

         GOTO Quit
      END

      SET @cOutField01 = @cLoc
      SET @cOutField02 = ''


      -- Go to ID Screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   SET @nAction = 3 --Prepare output fields
   SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScreenSP = '0'
   BEGIN
      SET @cExtendedScreenSP = ''
   END
   
   IF @cExtendedScreenSP <> ''
   Begin
      GOTO Step_99
   END

   GOTO Quit

   Step_3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField03 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 4.
    Screen = 2873
    Option (input, field01)
********************************************************************************/
Step_4:
BEGIN

   IF @nInputKey = 1 -- ENTER
   BEGIN

      -- Screen mapping
      SET @cOptions  = ISNULL(RTRIM(@cInField02),'')

      /****************************
       VALIDATION
      ****************************/
      --When Options is blank
      IF @cOptions = ''
      BEGIN
         SET @nErrNo = 74405
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Req
         GOTO Step_4_Fail
      END

      IF @cOptions NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 74414
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Option
         GOTO Step_4_Fail
      END

      IF @cOptions = '1'
      BEGIN
         -- NO , Get Next Task
         -- Update TaskDetail Status = '9'
         Update dbo.TaskDetail
         SET Status = '9'
               ,EditDate = GetDate()
               ,EditWho  = @cUserName
               ,TrafficCop = NULL
         WHERE TaskDetailKey = @cTaskDetailKey

         IF @@Error <> 0
         BEGIN
            SET @nErrNo = 74415
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDTaskDetFail
            GOTO Step_4_Fail
         END

         -- (james13)
         UPDATE dbo.Loc WITH (ROWLOCK) SET
            LastCycleCount = GETDATE(),
            EditWho = @cUserName,
            EditDate = GETDATE()
         WHERE Loc = @cLoc

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 57953
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- Upd LastCC Err
            GOTO Step_4_Fail
         END

         -- (JAMES07)
         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cFromLoc, @cID, @cPickMethod, ' +
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile         INT,           ' +
                  '@nFunc           INT,           ' +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,           ' +
                  '@nInputKey       INT,           ' +
                  '@cFacility       NVARCHAR( 15), ' +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cTaskdetailkey  NVARCHAR( 20),  ' +
                  '@cFromLoc        NVARCHAR( 20),  ' +
                  '@cID             NVARCHAR( 20),  ' +
                  '@cPickMethod     NVARCHAR( 20),  ' +
                  '@nErrNo          INT           OUTPUT, ' +
                  '@cErrMsg         NVARCHAR( 20) OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cSuggFromLoc, @cID, @cPickMethod,
                  @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END

         SET @nPrevStep = 0
         SET @nPrevScreen  = 0

         -- Go to ENTER / EXIT TM Task Screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2

         GOTO QUIT
      END

      IF @cOptions = '2'
      BEGIN
         SET @cOutField01 = @cLoc
         SET @cOutField02 = ''

         -- If loc.loseid = 1 then no need scan pallet id. Skip the screen (james02)
         IF EXISTS (SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cLoc AND LoseId = '1')
         BEGIN
            IF @cDefaultCCOptionSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDefaultCCOptionSP AND type = 'P')
               BEGIN
                  SET @cDefaultCCOption = ''
                  SET @cSQL = 'EXEC rdt.' + RTRIM(@cDefaultCCOptionSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cDefaultCCOption OUTPUT '
                  SET @cSQLParam =
                     '@nMobile            INT,           ' +
                     '@nFunc              INT,           ' +
                     '@cLangCode          NVARCHAR( 3),  ' +
                     '@nStep              INT,           ' +
                     '@nInputKey          INT,           ' +
                     '@cFacility          NVARCHAR( 15), ' +
                     '@cStorerKey         NVARCHAR( 15), ' +
                     '@cTaskdetailkey     NVARCHAR( 20),  ' +
                     '@cDefaultCCOption   NVARCHAR( 20)  OUTPUT  '

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cDefaultCCOption OUTPUT
               END
            END
            ELSE
            BEGIN
               IF EXISTS( SELECT 1 FROM STRING_SPLIT( @cFlowThruScreen, ',') WHERE TRIM( value) = '3') -- Statistic screen
               BEGIN
            	   IF EXISTS ( SELECT 1
            	               FROM dbo.LOC WITH (NOLOCK)
            	               WHERE Facility = @cFacility
            	               AND   Loc = @cLoc
            	               AND   LoseUCC = '0')
                     SET @cInField03 = '1' -- UCC
                  ELSE
               	   SET @cInField03 = '2' -- SKU

                  SET @cOutField01 = @cLoc
                  SET @cOutField02 = ''

                  SET @nScn = @nScn - 1
                  SET @nStep = @nStep - 1
                  GOTO Step_3
               END
            END

            -- prepare next screen variable
            SET @cOutField01 = @cLoc
            SET @cOutField02 = ''
            SET @cOutField03 = CASE WHEN @cDefaultCCOption = '' OR @cDefaultCCOption = '0' THEN '' ELSE @cDefaultCCOption END

            -- Go to CC option Screen
            SET @nScn = @nScn - 1
            SET @nStep = @nStep - 1

            GOTO Quit
         END

         -- Go to ID Screen
         SET @nScn = @nScn -  2
         SET @nStep = @nStep - 2
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @nPrevStep = '1'
      BEGIN
         SET @cOutField10 = @cLoc
         SET @cOutField11 = CASE WHEN @cTTMTasktype = 'CCSUP' THEN '(S)' ELSE '' END   -- (james04)
         SET @cOutField02 = ''

         -- Go to Loc Screen
         SET @nScn = @nPrevScreen
         SET @nStep = @nPrevStep
      END

      IF @nPrevStep = '2'
      BEGIN
         -- If loc.loseid = 1 then no need scan pallet id. Skip the screen (james02)
         IF EXISTS (SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cLoc AND LoseId = '1')
         BEGIN
            SET @cOutField10 = @cSuggFromLoc
            SET @cOutField11 = CASE WHEN @cTTMTasktype = 'CCSUP' THEN '(S)' ELSE '' END   -- (james01)
            SET @cOutField01 = ''

            -- Go to Loc Screen
            SET @nScn = @nPrevScreen
            SET @nStep = @nPrevStep

            GOTO Quit
         END

         SET @cOutField01 = @cLoc
         SET @cOutField02 = ''

         -- Go to id Screen
         SET @nScn = @nPrevScreen
         SET @nStep = @nPrevStep
      END

   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField04 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 6.
    Screen = 2875
    ENTER / EXIT TM
********************************************************************************/
Step_6:
BEGIN
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

      -- Search for next task and redirect screen
      SELECT @cErrMsg = '', @cNextTaskdetailkey = '', @cTTMTasktype = ''

      -- Performance tuning SWT01
      SELECT TOP 1 @cNextTaskdetailkey = td.TaskDetailKey, @cTTMTasktype = td.TaskType, @cSuggFromLoc = FromLoc
      FROM TaskDetail AS td WITH(NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( td.FromLoc = LOC.LOC)
      JOIN AreaDetail AD WITH (NOLOCK) ON ( LOC.PutawayZone = AD.PutawayZone)
      WHERE td.UserKey = @cUserName
      AND td.TaskType IN ('CC', 'CCSUP', 'CCSV')     --AND td.TaskType = 'CC'
      AND td.[Status] = '3'
      AND AD.AreaKey = @cAreakey
      ORDER BY td.Priority, LOC.LogicalLocation, LOC, td.TaskDetailKey  -- (james14)

      --( james08)
      IF @@ROWCOUNT > 0
         SET @cRefKey01 = @cSuggFromLoc

      IF ISNULL(RTRIM(@cNextTaskdetailkey), '') = ''
      BEGIN
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
         ,  @c_areakey01     = @cAreaKey     OUTPUT   -- (james09)
         ,  @c_areakey02     = ''
         ,  @c_areakey03     = ''
         ,  @c_areakey04     = ''
         ,  @c_areakey05     = ''
         ,  @c_lastloc       = ''
         ,  @c_lasttasktype  = 'TCC'
         ,  @c_outstring     = @c_outstring    OUTPUT
         ,  @b_Success       = @b_Success      OUTPUT
         ,  @n_err           = @nErrNo         OUTPUT
         ,  @c_errmsg        = @cErrMsg        OUTPUT
         ,  @c_taskdetailkey = @cNextTaskdetailkey OUTPUT
         ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT
         ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func
         ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func
         ,  @c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func
         ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func
         ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func
         ,  @n_Mobile        = @nMobile     -- (james09)
         ,  @n_Func          = @nFunc       -- (james09)
         ,  @c_StorerKey     = @cStorerKey  -- (james09)
      END

      IF ISNULL(RTRIM(@cNextTaskdetailkey), '') = ''--@nErrNo = 67804 -- Nothing to do!
      BEGIN
          -- EventLog - Sign In Function
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

         SET @cErrMsg = 'No More Task'
         --SET @cAreaKey = ''

         SET @cOutField01 = @cAreaKey  -- Area
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''

         SET @nPrevStep = 0

         GOTO QUIT
      END

      IF ISNULL(@cErrMsg, '') <> ''
      BEGIN
         SET @cErrMsg = @cErrMsg
         GOTO Step_6_Fail
      END


      IF ISNULL(@cNextTaskdetailkey, '') <> ''
      BEGIN
        SET @cTaskdetailkey = @cNextTaskdetailkey
      END

      IF @cTTMTasktype IN ( 'CC' , 'CCSV' , 'CCSUP')
      BEGIN
         SET @cSuggFromLoc = @cRefKey01
         SET @cOutField10 = @cSuggFromLoc
         SET @cOutField11 = CASE WHEN @cTTMTasktype = 'CCSUP' THEN '(S)' ELSE '' END   -- (james01)
         SET @cOutField02 = ''
      END

      SET @nToFunc = 0
      SET @nToScn = 0



      SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
      FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
      WHERE TaskType = RTRIM(@cTTMTasktype)

      IF @nFunc = 0
      BEGIN
         SET @nErrNo = 74429
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskFncErr
         GOTO Step_6_Fail
      END

      IF @cTTMTasktype IN ( 'CC', 'CCSUP', 'CCSV') -- (ChewKP05)
      BEGIN
         SELECT TOP 1 @nToScn = Scn
         FROM RDT.RDTScn WITH (NOLOCK)
         WHERE Func = 1766
         ORDER BY Scn
      END
      ELSE
      BEGIN
         SELECT TOP 1 @nToScn = Scn
         FROM RDT.RDTScn WITH (NOLOCK)
         WHERE Func = @nToFunc
         ORDER BY Scn
      END

      IF @nToScn = 0
      BEGIN
         SET @nErrNo = 74429
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr
         GOTO Step_6_Fail
      END

      SET @cOutField01 = @cRefKey01
      SET @cOutField02 = @cRefKey02
      SET @cOutField03 = @cRefKey03
      SET @cOutField04 = @cRefKey04
      SET @cOutField05 = @cRefKey05
      SET @cOutField06 = @cTaskdetailkey
      SET @cOutField07 = @cAreaKey
      SET @cOutField08 = @cTTMStrategykey

      -- RESET V_STRING
      UPDATE rdt.rdtMOBREC
      SET V_Loc               = ''
      ,V_ID                   = ''
      ,V_SKU                  = ''

      ,V_Lottable01           = ''
      ,V_Lottable02           = ''
      ,V_Lottable03           = ''
      ,V_Lottable04           = ''
      ,V_Lottable05           = ''

      ,V_LottableLabel01      = ''
      ,V_LottableLabel02      = ''
      ,V_LottableLabel03      = ''
      ,V_LottableLabel04      = ''
      ,V_LottableLabel05      = ''

      ,V_String1              = ''
      ,V_String2              = ''
      ,V_String3              = ''
      ,V_String4              = ''
      ,V_String5              = ''
      ,V_String6              = ''
      ,V_String10             = ''
      ,V_String11             = ''
      ,V_String12             = ''
      ,V_String13             = ''
      ,V_String14             = ''

      ,V_String27             = ''

      ,V_String29             = ''
      ,V_String30             = ''
      ,V_String31             = ''
      WHERE MOBILE = @nMOBILE




      -- EventLog - Sign In Function
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep

      SET @nFunc = @nToFunc
      SET @nScn = @nToScn
      SET @nStep = 1

      SET @nPrevStep = 0
   END

   IF @nInputKey = 0    --ESC
   BEGIN
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cFromLoc, @cID, @cPickMethod, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 15), ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cTaskdetailkey  NVARCHAR( 20),  ' +
               '@cFromLoc        NVARCHAR( 20),  ' +
               '@cID             NVARCHAR( 20),  ' +
               '@cPickMethod     NVARCHAR( 20),  ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cSuggFromLoc, @cID, @cPickMethod,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- EventLog - Sign Out Function
     EXEC RDT.rdt_STD_EventLog
      @cActionType = '9', -- Sign Out function
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
     SET @nPrevStep   = 0
     SET @nPrevScreen = 0

     SET @cOutField01 = ''  -- Area
     SET @cOutField02 = ''
     SET @cOutField03 = ''
     SET @cOutField04 = ''
     SET @cOutField05 = ''
     SET @cOutField06 = ''
     SET @cOutField07 = ''
     SET @cOutField08 = ''
   END
   GOTO Quit

   Step_6_Fail:
END
GOTO QUIT



/********************************************************************************
Step 7.
    Screen = 2901
     REASON CODE  (Field01, input)
********************************************************************************/
Step_7:
BEGIN

   IF @nInputKey = 1 -- ENTER
   BEGIN

      -- Screen mapping
      SET @cReasonCode   = ISNULL(RTRIM(@cInField01),'')

      /****************************
       VALIDATION
      ****************************/

      IF @cReasonCode = ''
      BEGIN
         SET @nErrNo = 74406
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Reason Req
         GOTO Step_7_Fail
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
           ,  @c_fromloc       = @cLoc
           ,  @c_fromid        = @cID
           ,  @c_toloc         = ''
           ,  @c_toid          = ''
           ,  @n_qty           = 0
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
        GOTO Step_7_Fail
      END

      SET @cContinueProcess = ''
      SELECT @cContinueProcess = ContinueProcessing,
             @cReasonStatus = TaskStatus,
             @cRemoveTaskFromUserQueue = RemoveTaskFromUserQueue
      FROM dbo.TASKMANAGERREASON WITH (NOLOCK)
      WHERE TaskManagerReasonKey = @cReasonCode

      BEGIN TRAN

      IF @cRemoveTaskFromUserQueue = '1'
      BEGIN
         INSERT INTO TaskManagerSkipTasks (UserID, TaskDetailKey, TaskType, LOT, FromLOC, ToLOC, FromID, ToID, CaseID)
         SELECT @cUserName AS UserKey, TaskDetailKey, TaskType, LOT, FromLOC, ToLOC, FromID, ToID, CaseID
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskdetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 57951
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsSkipTskFail
            GOTO Step_7_Fail
         END
      END

      -- Update TaskDetail.Status
      IF @cReasonStatus <> ''
      BEGIN
         -- Skip task
         IF @cReasonStatus = '0'
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
               ROLLBACK TRAN
               SET @nErrNo = 74407
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
               GOTO Step_7_Fail
            END
         END

         -- Cancel task
         IF @cReasonStatus = 'X'
         BEGIN
            UPDATE dbo.TaskDetail SET
                Status = 'X'
               ,EditDate = GETDATE()
               ,EditWho  = SUSER_SNAME()
               ,TrafficCop = NULL
            WHERE TaskDetailKey = @cTaskDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 57952
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskdetFail
               GOTO Step_7_Fail
            END
         END
      END  --ISNULL(@cContinueProcess, '') = '1'
      ELSE
      BEGIN
         UPDATE dbo.TaskDetail WITH (ROWLOCK)
         SET Status = @cReasonStatus ,
             UserKey = '', TrafficCOP = NULL
         WHERE Taskdetailkey = @cTaskdetailkey

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 74408
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
            GOTO Step_7_Fail
         END
      END

      -- (james06)
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
           SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cFromLoc, @cID, @cPickMethod, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 15), ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cTaskdetailkey  NVARCHAR( 20),  ' +
               '@cFromLoc        NVARCHAR( 20),  ' +
               '@cID             NVARCHAR( 20),  ' +
               '@cPickMethod     NVARCHAR( 20),  ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cTaskdetailkey, @cSuggFromLoc, @cID, @cPickMethod,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      COMMIT TRAN

      -- Continue process current task
      IF @cContinueProcess = '1'
      BEGIN
         -- (ChewKP01)
         /*
         -- GET NEXT TASK
         SELECT @cErrMsg = '', @cNextTaskdetailkey = '', @cTTMTasktype = ''

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
         ,  @c_areakey05     = ''
         ,  @c_lastloc       = @cLoc
         ,  @c_lasttasktype  = 'TCC'
         ,  @c_outstring     = @c_outstring    OUTPUT
         ,  @b_Success       = @b_Success      OUTPUT
         ,  @n_err           = @nErrNo         OUTPUT
         ,  @c_errmsg        = @cErrMsg       OUTPUT
         ,  @c_taskdetailkey = @cNextTaskdetailkey OUTPUT
         ,  @c_ttmtasktype   = @cTTMTasktype   OUTPUT
         ,  @c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func
         ,  @c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func
         ,  @c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func
         ,  @c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func
         ,  @c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func

         IF ISNULL(RTRIM(@cNextTaskdetailkey), '') = ''--@nErrNo = 67804 -- Nothing to do!
         BEGIN
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

            SET @nPrevStep = 0 -- (ChewKP01)

            GOTO QUIT
         END

         IF ISNULL(@cErrMsg, '') <> ''
         BEGIN
            SET @cErrMsg = @cErrMsg
            GOTO Step_7_Fail
         END

         IF ISNULL(@cNextTaskdetailkey, '') <> ''
         BEGIN
            SET @cTaskdetailkey = @cNextTaskdetailkey
         END

         -- RESET V_STRING
         UPDATE rdt.rdtMOBREC
         SET V_Loc               = ''
         ,V_ID                   = ''
         ,V_SKU                  = ''

         ,V_Lottable01           = ''
         ,V_Lottable02           = ''
         ,V_Lottable03           = ''
         ,V_Lottable04           = ''
         ,V_Lottable05           = ''

         ,V_LottableLabel01      = ''
         ,V_LottableLabel02      = ''
         ,V_LottableLabel03      = ''
         ,V_LottableLabel04      = ''
         ,V_LottableLabel05      = ''

         ,V_String1              = ''
         ,V_String2              = ''
         ,V_String3              = ''
         ,V_String4              = ''
         ,V_String5              = ''
         ,V_String6              = ''
         ,V_String10             = ''
         ,V_String11             = ''
         ,V_String12             = ''
         ,V_String13             = ''
      ,V_String14             = ''

         ,V_String27             = ''

         ,V_String29             = ''
         ,V_String30             = ''
         ,V_String31             = ''
         WHERE MOBILE = @nMOBILE

         IF @cTTMTasktype IN ('CC', 'CCSV', 'CCSUP')
         BEGIN
            SET @cSuggFromLoc = @cRefKey01
            SET @cOutField10 = @cSuggFromLoc
            SET @cOutField11 = CASE WHEN @cTTMTasktype = 'CCSUP' THEN '(S)' ELSE '' END   -- (james01)
            SET @cOutField02 = ''
         END

         SET @nToFunc = 0
         SET @nToScn = 0

         SELECT @nToFunc = ISNULL(FUNCTION_ID, 0)
         FROM RDT.rdtTaskManagerConfig WITH (NOLOCK)
         WHERE TaskType = RTRIM(@cTTMTasktype)

         IF @nFunc = 0
         BEGIN
            SET @nErrNo = 74409
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskFncErr
            GOTO Step_6_Fail
         END

         IF @cTTMTasktype IN ( 'CC' , 'CCSV' , 'CCSUP')
         BEGIN
            SELECT TOP 1 @nToScn = Scn
            FROM RDT.RDTScn WITH (NOLOCK)
            WHERE Func = 1766
            ORDER BY Scn
     END
         ELSE
         BEGIN
            SELECT TOP 1 @nToScn = Scn
            FROM RDT.RDTScn WITH (NOLOCK)
            WHERE Func = @nToFunc
            ORDER BY Scn
         END
         IF @nToScn = 0
         BEGIN
            SET @nErrNo = 74410
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr
            GOTO Step_7_Fail
         END
         */
         -- EventLog - Sign In Function
         EXEC RDT.rdt_STD_EventLog
            @cActionType = '9', -- Sign out function
            @cUserID     = @cUserName,
            @nMobileNo   = @nMobile,
            @nFunctionID = @nFunc,
            @cFacility   = @cFacility,
            @cStorerKey  = @cStorerKey,
            @nStep       = @nStep


         SET @nScn = 2875
         SET @nStep = 6

         SET @nPrevStep = 0
      END
      ELSE
      BEGIN
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

         SET @nPrevStep = 0 -- (ChewKP01)

         GOTO QUIT
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN

      SET @cOutField01 = @cLoc
      SET @cOutField02 = ''

      SET @nScn = @nFromScn
      SET @nStep = @nFromStep
   END
   GOTO Quit

   Step_7_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = ''
   END
END
GOTO Quit



Step_99:
BEGIN
   SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScreenSP = '0'
   BEGIN
      SET @cExtendedScreenSP = ''
   END
   IF @cExtendedScreenSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
      BEGIN
         
         EXECUTE [RDT].[rdt_ExtScnEntry] 
            @cExtendedScreenSP, 
            @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @tExtScnData,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT, @cLottable01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT, @cLottable02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT, @cLottable03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT, @dLottable04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT, @dLottable05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT, @cLottable06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT, @cLottable07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT, @cLottable08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT, @cLottable09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT, @cLottable10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT, @cLottable11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, @cLottable12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT, @dLottable13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, @dLottable14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, @dLottable15 OUTPUT,
            @nAction, 
            @nScn OUTPUT,  @nStep OUTPUT,
            @nErrNo   OUTPUT, 
            @cErrMsg  OUTPUT,
            @cUDF01 OUTPUT, @cUDF02 OUTPUT, @cUDF03 OUTPUT,
            @cUDF04 OUTPUT, @cUDF05 OUTPUT, @cUDF06 OUTPUT,
            @cUDF07 OUTPUT, @cUDF08 OUTPUT, @cUDF09 OUTPUT,
            @cUDF10 OUTPUT, @cUDF11 OUTPUT, @cUDF12 OUTPUT,
            @cUDF13 OUTPUT, @cUDF14 OUTPUT, @cUDF15 OUTPUT,
            @cUDF16 OUTPUT, @cUDF17 OUTPUT, @cUDF18 OUTPUT,
            @cUDF19 OUTPUT, @cUDF20 OUTPUT, @cUDF21 OUTPUT,
            @cUDF22 OUTPUT, @cUDF23 OUTPUT, @cUDF24 OUTPUT,
            @cUDF25 OUTPUT, @cUDF26 OUTPUT, @cUDF27 OUTPUT,
            @cUDF28 OUTPUT, @cUDF29 OUTPUT, @cUDF30 OUTPUT

         IF @nErrNo <> 0
            GOTO Step_99_Fail

         GOTO Quit
      END
   END -- Ext scn sp <> ''

   Step_99_Fail:
      GOTO Quit
END

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

      V_UOM         = @cPUOM,
      V_SKU         = @cSKU,
      V_TaskDetailKey = @cTaskDetailKey,
      V_LOC         = @cSuggFromLoc,
      V_ID          = @cID,

      V_Lottable01  = @cLottable01,
      V_Lottable02  = @cLottable02,
      V_Lottable03  = @cLottable03,
      V_Lottable04  = @dLottable04,
      V_Lottable05  = @dLottable05,

      V_LottableLabel01 = @cLotLabel01,
      V_LottableLabel02 = @cLotLabel02,
      V_LottableLabel03 = @cLotLabel03,
      V_LottableLabel04 = @cLotLabel04,
      V_LottableLabel05 = @cLotLabel05,

      V_String1 = @cCCKey,
      V_String2 = @cSuggID,
      V_String3 = @cCommodity,
      V_String4 = @cUCC,
      V_String5 = @cTMCCSKUSkipScreen1,
      V_String6 = @cUserPosition,
      V_String7 = @cDefaultCCOptionSP,
      V_String8 = @cFlowThruScreen,

      V_FromStep = @nPrevStep,
      V_FromScn  = @nPrevScreen,

      V_String10 = @cLoc,
      V_String13 = @cSuggSKU,
      V_String14 = @cPickMethod,
      V_String15 = @cSKUDescr1,
      V_String16 = @cSKUDescr2,
      V_String17 = @cCCDetailKey,
      V_String18 = @cExtendedUpdateSP,
      V_String19 = @cExtendedInfoSP,
      -- Module SP Variable V_String 20 - 26 --
      --V_String28 = @nActQTY,

      V_Integer1 = @nUCCQty,
      V_Integer2 = @nRowID,

      V_String30 = @nFromScn,
      V_String31 = @nFromStep,
      V_String32 = @cAreakey,
      V_String33 = @cTTMStrategykey,
      V_String34 = @cTTMTasktype,
      V_String35 = @cRefKey01,
      V_String36 = @cRefKey02,
      V_String37 = @cRefKey03,
      V_String38 = @cRefKey04,
      V_String39 = @cRefKey05,

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