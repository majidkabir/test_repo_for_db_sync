SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdtfnc_TM_CycleCount_ID                                   */
/* Copyright      : MAERSK                                                    */
/*                                                                            */
/* Purpose: Carton count on Pallet                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2023-09-09 1.0  James      WMS-23249. Created                              */
/******************************************************************************/

CREATE   PROC [RDT].[rdtfnc_TM_CycleCount_ID] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cOption     NVARCHAR( 1),
   @nCount      INT,
   @nRowCount   INT,
   @cSQL        NVARCHAR( MAX),
   @cSQLParam   NVARCHAR( MAX)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,


   @cPrinter   NVARCHAR( 20),
   @cUserName  NVARCHAR( 18),


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
   @cCCKey              NVARCHAR(10),
   @c_CCDetailKey       NVARCHAR(10),
   @b_Success           INT,
	@cSKUDescr           NVARCHAR(60),
	@nUCCQty             INT,
	@cQty                INT,
	@cOptions            NVARCHAR( 1),
	@cInSKU              NVARCHAR(20),
	@nSKUCnt             INT,
	@nCountLot           INT,
	@cSourcekey          NVARCHAR(15),
   @nRowID              INT,
   @nActQTY             INT, -- Actual QTY
   @nPrevScreen         INT,
   @cInUCCCount         NVARCHAR( 5),
   @nSumUCCQty          INT,
	@nSumUCCCount        INT,
	@nUCCCounter         NVARCHAR( 5),
	@c_modulename        NVARCHAR( 30),
	@c_Activity          NVARCHAR( 10),
	@cCCType             NVARCHAR( 10),
	@cPickMethod         NVARCHAR( 10),
	@cSKUDescr1          NVARCHAR( 20),
	@cSKUDescr2          NVARCHAR( 20),
	@cCCDetailKey        NVARCHAR( 10),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cSkipAlertScreen    NVARCHAR( 1),
   @cDefaultOption      NVARCHAR( 1),
   @cNewUCC             NVARCHAR( 20),
   @cStatus             NVARCHAR( 10),
   @cNewSKU             NVARCHAR( 20),
   @cNewSKUDescr        NVARCHAR( 60),
   @nNewUCCQTY          INT,
   @cNewSKUDescr1       NVARCHAR( 20),
   @cNewSKUDescr2       NVARCHAR( 20),
   @cLottableCode       NVARCHAR( 30),
   @nMorePage           INT,
   @nNoOfTry            INT,
   @nSYSQTY             INT,
   @nCtnCount           INT,
   @cCtnCount           NVARCHAR( 5),
   @nPltCtnCount        INT,
   @cSYSID              NVARCHAR( 18),

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
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cPrinter   = Printer,
   @cUserName  = UserName,

   @cTaskDetailKey   = V_TaskDetailKey,
   @cSuggFromLoc     = V_Loc,
   @cID              = V_ID,
   @cSKU             = V_SKU,

   @nFromStep        = V_FromStep,
   @nFromScn         = V_FromScn,

   @nNoOfTry         = V_Integer1,
   @nPrevStep        = V_Integer2,
   @nPrevScreen      = V_Integer3,
   @nSumUCCCount     = V_Integer4,
   @nUCCCounter      = V_Integer5,
   @nActQTY          = V_Integer6,
   @nRowID           = V_Integer7,
   @nNewUCCQTY       = V_Integer8,

   @cCCKey           = V_String1,
   @cSuggID          = V_String2,
   @cCommodity       = V_String3,
   @cUCC             = V_String4,
   @cExtendedInfoSP  = V_String5,
   @cExtendedInfo    = V_String6,
   @cSkipAlertScreen = V_String7,
   @cDefaultOption   = V_String8,
   @cNewUCC          = V_String9,
   @cLoc             = V_String10,
   @cLottableCode    = V_String11,
   @cNewSKU          = V_String12,
   @cSuggSKU         = V_String13,
   @cPickMethod      = V_String14,
   @cSKUDescr1       = V_String15,
   @cSKUDescr2       = V_String16,
   @cCCDetailKey     = V_String17,



   -- Module SP Variable V_String 20 - 26 --
   @cInUCCCount      = V_String20,
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
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04  = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

Declare @n_debug INT

SET @n_debug = 0

-- Screen constant
DECLARE
   @nStep_CartonCount   INT,  @nScn_CartonCount INT

SELECT
   @nStep_CartonCount   = 1,  @nScn_CartonCount = 2950

IF @nFunc = 1769  -- TM CC - ID
BEGIN
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   SET @cSkipAlertScreen = rdt.RDTGetConfig( @nFunc, 'SkipAlertScreen', @cStorerkey)

   SET @cDefaultOption = rdt.RDTGetConfig( @nFunc, 'DefaultOption', @cStorerkey)
   IF @cDefaultOption = '0'
      SET @cDefaultOption = ''

   -- Redirect to respective screen
   IF @nStep = 1 GOTO Step_CartonCount -- Scn = 2930. UCC
END

/************************************************************************************
Step_ID_CartonCount. Scn = 3260. Screen 24.
   Pallet ID      (field02)
   Carton Count   (field02, input)
************************************************************************************/
Step_CartonCount:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cCtnCount = @cInField02

      IF ISNULL(@cCtnCount, '') = ''
      BEGIN
         SET @nErrNo = 139801
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'CTN COUNT req'
         GOTO CartonCount_Fail
      END

      -- not check for 0 qty because if empty loc then user put 0 as empty loc indicator
      IF RDT.rdtIsValidQTY( @cCtnCount, 0) = 0
      BEGIN
         SET @nErrNo = 139802
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'BAD CTN COUNT'
         GOTO CartonCount_Fail
      END

      -- If not empty pallet count then must have id to confirm
      IF CAST(@cCtnCount AS INT) <> 0
      BEGIN
         -- Count by ID must have key in pallet ID
         IF ISNULL(@cID, '') = ''
         BEGIN
            SET @nErrNo = 139803
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'ID required'
            GOTO CartonCount_Fail
         END
      END

      -- Get Pallet carton count
      SELECT @nPltCtnCount = COUNT(1)
      FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ID = @cID
      AND   [Status] = '1'

      SET @nCtnCount = CAST(@cCtnCount AS INT)

      -- Empty loc
      IF @nCtnCount = 0
      BEGIN
         WHILE @nPltCtnCount > 0
         BEGIN
            -- Get CCDETAIL
            SELECT TOP 1
               @cStorerKey = StorerKey,
               @cSKU = SKU,
               @cStatus = Status,
               @nSYSQTY = SystemQty,
               @cSYSID = @cID,
               @cCCDetailKey = CCDetailKey
            FROM dbo.CCDETAIL WITH (NOLOCK)
            WHERE CCKey = @cCCKey
            AND   CCSheetNo = @cTaskDetailKey
            AND   LOC = @cLOC
            AND   ID = @cID
            AND   Status < '9'

            -- If nothing found, prompt error
            IF @@ROWCOUNT = 0 OR ISNULL(@cCCDetailKey, '') = ''
            BEGIN
               SET @nErrNo = 139804
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NO CCD FOUND'
               GOTO CartonCount_Fail
            END

            -- If found, update CCDETAIL
            SET @nErrNo = 0
            SET @cErrMsg = ''
            EXECUTE rdt.rdt_CycleCount_UpdateCCDetail
               @cCCKey,
               @cTaskDetailKey,
               1,
               @cCCDetailKey,
               0,               -- empty loc
               @cUserName,
               @cLangCode,
               @nErrNo       OUTPUT,
               @cErrMsg      OUTPUT    -- screen limitation, 20 char max

            IF @nErrNo <> 0
               GOTO CartonCount_Fail

            SET @nPltCtnCount = @nPltCtnCount - 1
         END
      END

      IF @nPltCtnCount <> @nCtnCount AND @nCtnCount > 0
      BEGIN
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

         GOTO Quit
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

      -- EventLog - Sign In Function
      EXEC RDT.rdt_STD_EventLog
        @cActionType = '9', -- Sign in function
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @nStep       = @nStep

      SET @cOutField01 = @cLoc
      SET @cOutField02 = ''

      --go to main TM sp, ID screen
      SET @nFunc = 1766
      SET @nScn  = 2871
      SET @nStep = 2
   END

   IF @nInputKey = 0 -- Esc
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

      -- EventLog - Sign In Function
      EXEC RDT.rdt_STD_EventLog
        @cActionType = '9', -- Sign in function
        @cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @nStep       = @nStep

      SET @cOutField01 = @cLoc
      SET @cOutField02 = ''

      --go to main TM sp, ID screen
      SET @nFunc = 1766
      SET @nScn  = 2871
      SET @nStep = 2
   END
END
GOTO Quit

CartonCount_Fail:
BEGIN
	SET @cOutField02 = ''
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

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      Printer   = @cPrinter,
		InputKey  =	@nInputKey,


      V_TaskDetailKey  = @cTaskDetailKey,
      V_Loc            = @cSuggFromLoc,
      V_ID             = @cID,
      V_SKU            = @cSKU,

      V_FromStep     = @nFromStep,
      V_FromScn      = @nFromScn,

      V_Integer1     = @nNoOfTry,
      V_Integer2     = @nPrevStep,
      V_Integer3     = @nPrevScreen,
      V_Integer4     = @nSumUCCCount,
      V_Integer5     = @nUCCCounter,
      V_Integer6     = @nActQTY,
      V_Integer7     = @nRowID,
      V_Integer8     = @nNewUCCQTY,

      V_String1        = @cCCKey,
      V_String2        = @cSuggID,
      V_String3        = @cCommodity,
      V_String4        = @cUCC,
      V_String5        = @cExtendedInfoSP,
      V_String6        = @cExtendedInfo,
      V_String7        = @cSkipAlertScreen,
      V_String8        = @cDefaultOption,
      V_String9        = @cNewUCC,
      V_String10       = @cLoc,
      V_String11       = @cLottableCode,
      V_String12       = @cNewSKU,
      V_String13       = @cSuggSKU,
      V_String14       = @cPickMethod,
      V_String15       = @cSKUDescr1,
      V_String16       = @cSKUDescr2,
      V_String17       = @cCCDetailKey,

      -- Module SP Variable V_String 20 - 26 --
      V_String20       = @cInUCCCount,

      V_String32       = @cAreakey,
      V_String33       = @cTTMStrategykey,
      V_String34       = @cTTMTasktype,
      V_String35       = @cRefKey01,
      V_String36       = @cRefKey02,
      V_String37       = @cRefKey03,
      V_String38       = @cRefKey04,
      V_String39       = @cRefKey05,

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