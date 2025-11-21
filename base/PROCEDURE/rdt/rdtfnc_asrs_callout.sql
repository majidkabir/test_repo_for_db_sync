SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_ASRS_CallOut                                      */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#315031 - Call ASRS pallet to do Cycle Count/Inspection       */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2015-04-20 1.0  James    Created                                          */
/* 2016-09-30 1.1  Ung      Performance tuning                               */
/* 2018-10-26 1.2  Gan      Performance tuning                               */
/*****************************************************************************/

CREATE PROC [RDT].[rdtfnc_ASRS_CallOut](
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
   @cLangCode           NVARCHAR( 3),
   @nMenu               INT,
   @nInputKey           NVARCHAR( 3),
   @cPrinter            NVARCHAR( 10),
   @cUserName           NVARCHAR( 18),

   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),

   @cTOLoc              NVARCHAR( 10),
   @cCCRefNo            NVARCHAR( 10),
   @cCCSheetNo          NVARCHAR( 10),
   @cPrevCCSheetNo      NVARCHAR( 10),
   @cExtendedUpdateSP   NVARCHAR( 20), 
   @cLOCCategory        NVARCHAR( 10), 
   @cExistingLOC        NVARCHAR( 10), 
   @cSQL                NVARCHAR( 1000), 
   @cSQLParam           NVARCHAR( 1000), 
   @nCCCnt              INT,
   @nCCCountNo          INT,
   @cStorerGroup        NVARCHAR( 20),
   @cChkStorerKey       NVARCHAR( 15),
   @nFinalizeStage      INT,
   @cTaskStatus         NVARCHAR( 10), 
   @cTaskCountNo        NVARCHAR( 10),

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

   @cStorerGroup     = StorerGroup, 
   @cFacility        = Facility,
   @cPrinter         = Printer,
   @cUserName        = UserName,

   @cStorerKey       = V_StorerKey,
   @cTOLoc           = V_LOC,
   
   @nCCCnt           = V_Integer1,
   @nCCCountNo       = V_Integer2,

   @cCCSheetNo       = V_String1,
  -- @nCCCnt           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String2, 5), 0) = 1 THEN LEFT( V_String2, 5) ELSE 0 END,
   @cCCRefNo         = V_String3,
   @cPrevCCSheetNo   = V_String4,
  -- @nCCCountNo       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 5), 0) = 1 THEN LEFT( V_String5, 5) ELSE 0 END,

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
IF @nFunc = 1820
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1820
   IF @nStep = 1 GOTO Step_1   -- Scn = 4170   TO LOC, CCREF
   IF @nStep = 2 GOTO Step_2   -- Scn = 4171   CC SHEET #
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1642)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 4170
   SET @nStep = 1

   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- initialise all variable
   SET @cTOLoc = ''
   SET @cPrevCCSheetNo = ''

   -- Prep next screen var
   SET @cOutField01 = ''
END
GOTO Quit

/********************************************************************************
Step 1. screen = 4170
   TO LOC      (Field01, input)
   CCREF NO    (Field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cTOLoc = @cInField01
      SET @cCCRefNo = @cInField02

      --When PalletID is blank
      IF ISNULL( @cTOLoc, '') = ''
      BEGIN
         SET @nErrNo = 53701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TO LOC req
         GOTO TOLoc_Fail
      END

      --TO LOC Not Exists
      IF NOT EXISTS (SELECT 1 
                     FROM dbo.LOC WITH (NOLOCK) 
                     WHERE Facility = @cFacility
                     AND   LOC = @cTOLoc)
      BEGIN
         SET @nErrNo = 53702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid To Loc
         GOTO TOLoc_Fail
      END

      SELECT @cLOCCategory = LocationCategory
      FROM dbo.LOC WITH (NOLOCK) 
      WHERE Facility = @cFacility
      AND   LOC = @cTOLoc

      IF ISNULL( @cCCRefNo, '') = ''
      BEGIN
         SET @nErrNo = 53704
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CCREF is req
         GOTO CCREF_Fail
      END

      -- Check storer group
      IF @cStorerGroup <> ''
      BEGIN
         SELECT TOP 1 @cChkStorerKey = StorerKey
         FROM dbo.CCDETAIL WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo

         -- Check storer not in storer group
         IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cChkStorerKey)
         BEGIN
            SET @nErrNo = 53712
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- LOC
            SET @cOutField01 = '' -- LOC
            SET @cOutField02 = '' -- LOC
            SET @cTOLoc = ''
            SET @cCCRefNo = ''
            GOTO Quit
         END

         -- Set session storer
         SET @cStorerKey = @cChkStorerKey
      END

      IF NOT EXISTS ( SELECT 1 
                      FROM dbo.CODELKUP CL WITH (NOLOCK) 
                      JOIN dbo.LOC LOC WITH (NOLOCK) ON CL.CODE = LOC.LocationCategory
                      WHERE CL.ListName = 'CALLOUTLOC'
                      AND   CL.Code2 = @cFacility
                      --AND   CL.Storerkey = @cStorerKey
                      AND   LOC.LOC = @cTOLoc)
      BEGIN
         SET @nErrNo = 53703
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid To Loc
         GOTO TOLoc_Fail
      END

      -- Validate with CCDETAIL
      IF NOT EXISTS (SELECT 1 --TOP 1 CCKey
                     FROM dbo.CCDETAIL WITH (NOLOCK)
                     WHERE CCKey = @cCCRefNo)
      BEGIN
         SET @nErrNo = 53705
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid CCREF
         GOTO CCRef_Fail
      END

      IF EXISTS ( SELECT 1 
                  FROM dbo.StockTakeSheetParameters WITH (NOLOCK)
                  WHERE StockTakeKey = @cCCRefNo
                  AND [PASSWORD] = 'POSTED')
      BEGIN
         SET @nErrNo = 53716
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Setup CCREF
         GOTO CCRef_Fail
      END

      -- Validate with StockTakeSheetParameters
      IF NOT EXISTS (SELECT TOP 1 StockTakeKey
                     FROM dbo.StockTakeSheetParameters WITH (NOLOCK)
                     WHERE StockTakeKey = @cCCRefNo)
      BEGIN
         SET @nErrNo = 53706
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Setup CCREF
         GOTO CCRef_Fail
      END

      SET @nCCCountNo=1
      SELECT @nCCCountNo = CASE WHEN ISNULL(FinalizeStage,0) = 0 THEN 1
                                WHEN FinalizeStage = 1 THEN 2
                                WHEN FinalizeStage = 2 THEN 3
                           END, 
             @nFinalizeStage = FinalizeStage 
      FROM dbo.StockTakeSheetParameters WITH (NOLOCK)
      WHERE StockTakeKey = @cCCRefNo

      IF ISNULL(@nCCCountNo,0) = 0
      BEGIN
         SET @nErrNo = 53707
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid count#
         GOTO CCRef_Fail
      END

      -- Already counted 3 times, not allow to count again
      IF @nFinalizeStage = 3
      BEGIN
         SET @nErrNo = 53713
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Finalized Cnt3'
         GOTO CCRef_Fail
      END

      -- Entered CountNo must equal to FinalizeStage + 1, ie. if cnt1 not finalized, cannot go to cnt2
      IF @nCCCountNo <> @nFinalizeStage + 1
      BEGIN
         SET @nErrNo = 53714
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Wrong CNT NO'
         GOTO CCRef_Fail
      END

      SET @cCCSheetNo = ''
      SET @nCCCnt = 0

      --prepare next screen variable
      SET @cOutField01 = @cTOLoc
      SET @cOutField02 = @cCCRefNo
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = '0'

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog - Sign Out Function
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cOutField01 = ''
   END
   GOTO Quit

   TOLoc_Fail:
   BEGIN
      SET @cTOLoc = ''
      SET @cOutField01 = ''
      SET @cOutField02 = @cCCRefNo
      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   GOTO Quit

   CCREF_Fail:
   BEGIN
      SET @cCCRefNo = ''
      SET @cOutField01 = @cTOLoc
      SET @cOutField02 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 2
   END
END
GOTO Quit

/********************************************************************************
Step 2. (screen = 4171)
   TO LOC:           (Field01)
   CCREF:            (Field02)
   CC SHEET #:       (Field03, input)
   LAST SCAN:        (Field04)
   # OF COUNT        (Field05)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cCCSheetNo = @cInField03

      --When CCSheet # is blank
      IF ISNULL( @cCCSheetNo, '') = ''
      BEGIN
         SET @nErrNo = 53708
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CCSheetNo req
         GOTO Step_2_Fail
      END

      -- Validate with CCDETAIL
      IF NOT EXISTS ( SELECT 1 
                      FROM dbo.CCDETAIL CCD WITH (NOLOCK)
                      JOIN dbo.StockTakeSheetParameters STK (NOLOCK) ON ( STK.StockTakeKey = CCD.CCKEY)
                      WHERE CCD.CCKey = @cCCRefNo
                      AND   CCD.CCSheetNo = @cCCSheetNo)
      BEGIN
         SET @nErrNo = 53709
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid CCSheet'
         GOTO Step_2_Fail
      END

      -- 1 CCSheet # can only scanned to 1 TOLoc
      IF EXISTS ( SELECT 1 
                  FROM dbo.TaskDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND   TaskType = 'ASRSCC'
                  AND   Status IN ('0', '3')
                  AND   DropID = @cCCRefNo
                  AND   SourceKey = @cCCSheetNo
                  AND   FinalLOC <> @cTOLoc)
      BEGIN
         SET @nErrNo = 53710
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Sheet LOC Diff'
         GOTO Step_2_Fail
      END

      -- If any pallet already call out then cannot scan the same ccsheet #
      SET @cTaskStatus = ''
      SET @cTaskCountNo = ''
      SELECT TOP 1 
             @cTaskStatus = [Status], 
             @cTaskCountNo = TransitCount
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   TaskType = 'ASRSCC'
      --AND   Status IN ('3', '9')
      AND   DropID = @cCCRefNo
      AND   SourceKey = @cCCSheetNo
      ORDER BY TransitCount DESC -- Last count come first

      IF @@ROWCOUNT > 0
      BEGIN
         IF ISNULL( @cTaskStatus, '') <> '9'
         BEGIN
            SET @nErrNo = 53711
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Sheet Call Out'
            GOTO Step_2_Fail
         END

         IF ISNULL( @cTaskStatus, '') = '9'
         BEGIN
            IF CAST( @cTaskCountNo AS INT) + 1 <> @nCCCountNo
            BEGIN
               SET @nErrNo = 53715
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Wrong count no'
               GOTO Step_2_Fail
            END
         END
      END

      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''

      IF @cUserName = 'james'
         set @cExtendedUpdateSP = 'rdt_1820ExtUpd02'

      IF ISNULL( @cExtendedUpdateSP, '') <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cToLOC, @cCCRefNo, @cCCSheetNo, @nCCCountNo, @nAfterStep, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' + 
            '@cLangCode       NVARCHAR( 3),  ' +
            '@cStorerkey      NVARCHAR( 15), ' +
            '@cToLOC          NVARCHAR( 10), ' +
            '@cCCRefNo        NVARCHAR( 10), ' +
            '@cCCSheetNo      NVARCHAR( 10), ' +
            '@nCCCountNo      INT,           ' + 
            '@nAfterStep      INT,           ' + 
            '@nErrNo          INT           OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cToLOC, @cCCRefNo, @cCCSheetNo, @nCCCountNo, @nStep,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Step_2_Fail
      END

      SET @cPrevCCSheetNo = @cCCSheetNo

      -- insert to Eventlog
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerkey,
         @cToLocation   = @cTOLoc,
         @cRefNo1       = @cCCRefNo,
         @cCCSheetNo    = cCCSheetNo,
         --@cRefNo2       = @cCCSheetNo,
         @nStep         = @nStep

      SET @nCCCnt = @nCCCnt + 1

      SET @cOutField01 = @cToLoc
      SET @cOutField02 = @cCCRefNo
      SET @cOutField03 = ''
      SET @cOutField04 = @cCCSheetNo
      SET @cOutField05 = @nCCCnt
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --prepare prev screen variable
      SET @cTOLoc = ''
      SET @cCCRefNo = ''

      SET @cOutField01 = ''
      SET @cOutField02 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cCCSheetNo = ''

      -- Reset this screen var
      SET @cOutField01 = @cToLoc
      SET @cOutField02 = @cCCRefNo
      SET @cOutField03 = ''
      SET @cOutField04 = @cPrevCCSheetNo
      SET @cOutField05 = @nCCCnt
  END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      EditDate      = GETDATE(), 
      ErrMsg        = @cErrMsg,
      Func          = @nFunc,
      Step          = @nStep,
      Scn           = @nScn,

      Facility      = @cFacility,
      Printer       = @cPrinter,
      -- UserName      = @cUserName,

      V_StorerKey   = @cStorerKey, 
      V_LOC         = @cTOLoc,
      
      V_Integer1    = @nCCCnt,
      V_Integer2    = @nCCCountNo,

      V_String1     = @cCCSheetNo,
      --V_String2     = @nCCCnt,
      V_String3     = @cCCRefNo,
      V_String4     = @cPrevCCSheetNo,
      --V_String5     = @nCCCountNo,

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