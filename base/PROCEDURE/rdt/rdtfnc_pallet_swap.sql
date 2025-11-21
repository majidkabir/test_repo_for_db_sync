SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_Pallet_Swap                                       */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#316871 - Transfer goods from old pallet to a new pallet      */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2015-04-16 1.0  James    Created                                          */
/* 2016-09-30 1.1  Ung      Performance tuning                               */
/* 2018-10-26 1.2  TungGH   Performance                                      */
/*****************************************************************************/

CREATE PROC [RDT].[rdtfnc_Pallet_Swap](
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

   @cFromLOC            NVARCHAR( 10),
   @cFromID             NVARCHAR( 18),
   @cToID               NVARCHAR( 18),
   @cStorerGroup        NVARCHAR( 20),
   @cChkStorerKey       NVARCHAR( 15),
   @nStorer_Cnt         INT,

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
   @cFromLOC         = V_LOC,

   @cStorerKey       = V_StorerKey,
   @cFromID          = V_String1,
   @cToID            = V_String2,

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
IF @nFunc = 961
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 961
   IF @nStep = 1 GOTO Step_1   -- Scn = 4160   From ID
   IF @nStep = 2 GOTO Step_2   -- Scn = 4161   To ID
   IF @nStep = 3 GOTO Step_3   -- Scn = 4162   Message
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1642)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 4160
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
   SET @cFromID = ''

   -- Prep next screen var
   SET @cOutField01 = ''
END
GOTO Quit

/********************************************************************************
Step 1. screen = 4160
   From ID (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromID = @cInField01

      --When PalletID is blank
      IF ISNULL( @cFromID, '') = ''
      BEGIN
         SET @nErrNo = 53551
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FROM ID req
         GOTO Step_1_Fail
      END
      /*
      --ID Not Exists
      IF NOT EXISTS (SELECT 1
                     FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                     WHERE Facility = @cFacility
                     AND   ID = @cFromID
                     AND   Qty > 0)
      BEGIN
         SET @nErrNo = 53552
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID ID
         GOTO Step_1_Fail
      END
      */
      -- Check if pallet exists and with inventory
      SET @nStorer_Cnt = 0
      SELECT @nStorer_Cnt = COUNT( DISTINCT StorerKey)
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LLI.ID = @cFromID
      AND   LOC.Facility = @cFacility
      AND   Qty > 0

      IF @nStorer_Cnt = 0
      BEGIN
         SET @nErrNo = 53552
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
         GOTO Step_1_Fail
      END

      -- 1 pallet only 1 storer
      IF @nStorer_Cnt > 1
      BEGIN
         SET @nErrNo = 53554
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID mix storer
         GOTO Step_1_Fail
      END

      -- Check storer group
      IF @cStorerGroup <> ''
      BEGIN
         SELECT TOP 1 @cChkStorerKey = StorerKey
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         WHERE LLI.ID = @cFromID
         AND   LOC.Facility = @cFacility
         AND   Qty > 0

         -- Check storer not in storer group
         IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cChkStorerKey)
         BEGIN
            SET @nErrNo = 53555
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
            GOTO Step_1_Fail
         END

         -- Set session storer
         SET @cStorerKey = @cChkStorerKey
      END

      SELECT TOP 1 @cFromLOC = LLI.LOC
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
      AND   LLI.ID = @cFromID
      AND   LLI.Qty > 0

      --prepare next screen variable
      SET @cOutField01 = @cFromID
      SET @cOutField02 = ''

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

   Step_1_Fail:
   BEGIN
      SET @cFromID = ''
      SET @cOutField01 = ''
    END
END
GOTO Quit

/********************************************************************************
Step 2. (screen = 4161)
   From ID:    (Field01)
   To ID:      (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToID = @cInField02

      --When Door is blank
      IF ISNULL( @cToID, '') = ''
      BEGIN
         SET @nErrNo = 53553
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TO ID req
         GOTO Step_2_Fail
      END

      -- Check if to id is empty pallet
      SET @nErrNo = 0
      EXEC rdt.rdt_CheckEmptyPallet
         @nMobile,
         @nFunc,
         @cLangCode,
         @cFacility,
         @cStorerKey,
         @cFromID,
         @cToID,
         @cFromLOC,
         '',
         0,
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT

      IF @nErrNo <> 0
         GOTO Step_2_Fail

      EXEC [RDT].[rdt_Pallet_Swap]
         @nMobile,
         @nFunc,
         @cLangCode,
         @cFacility,
         @cStorerKey,
         @cFromID,
         @cToID,
         @cFromLOC,
         '',
         0,
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT -- screen limitation, 20 char max

      IF @nErrNo <> 0
         GOTO Step_2_Fail

      -- insert to Eventlog
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerkey,
         @cID           = @cFromID,
         @cToID         = @cToID,
         @nStep         = @nStep

      -- Go back next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --prepare prev screen variable
      SET @cFromID = ''
      SET @cOutField01 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cToID = ''

      -- Reset this screen var
      SET @cOutField01 = @cFromID
      SET @cOutField02 = ''
  END
END
GOTO Quit



/********************************************************************************
Step 3. (screen = 4161)
   Message
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cFromID = ''
      SET @cOutField01 = ''

      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END
   GOTO Quit
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

       V_StorerKey   = @cStorerKey,
       Facility      = @cFacility,
       Printer       = @cPrinter,
       -- UserName      = @cUserName,
       V_LOC         = @cFromLOC,

       V_String1     = @cFromID,
       V_String2     = @cToID,

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