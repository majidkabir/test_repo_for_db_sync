SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_ResetUser                                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Reset user session                                          */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2011-07-21 1.0  Ung        Created                                   */
/* 2016-09-30 1.1  Ung        Performance tuning                        */ 
/* 2016-11-16 1.2  ChewKP     Update with Func = 0 (ChewKP01)           */
/* 2018-10-05 1.3  TungGH     Performance                               */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_ResetUser] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cUser         NVARCHAR(10)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc         INT,
   @nScn          INT,
   @nStep         INT,
   @cLangCode     NVARCHAR( 3),
   @nInputKey     INT,
   @nMenu         INT,

   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cPrinter      NVARCHAR(10),
   @cUserName     NVARCHAR(18), 

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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60)
   
-- Load RDT.RDTMobRec
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cFacility  = Facility,
   @cStorerKey = StorerKey,
   @cPrinter   = Printer,
   @cUserName  = UserName,
   
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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15
   
FROM RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 1786 -- Reset user
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Reset user
   IF @nStep = 1 GOTO Step_1   -- Scn = 750. User
   IF @nStep = 2 GOTO Step_2   -- Scn = 751. Message
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 1786. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 750
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 750. User
   User (input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUser = @cInField01

      -- Validate blank
      IF @cUser = ''
      BEGIN
         SET @nErrNo = 73501
         SET @cErrMsg = rdt.rdtgetmessage( 73501, @cLangCode, 'DSP') --User required
         GOTO Step_1_Fail
      END

      -- Check if user exists
      IF NOT EXISTS( SELECT 1 FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUser)
      BEGIN
         SET @nErrNo = 73502
         SET @cErrMsg = rdt.rdtgetmessage( 73502, @cLangCode, 'DSP') --Invalid user
         GOTO Step_1_Fail
      END

      -- Check if same user
      IF @cUserName = @cUser
      BEGIN
         SET @nErrNo = 73503
         SET @cErrMsg = rdt.rdtgetmessage( 73503, @cLangCode, 'DSP') --CantSelfReset
         GOTO Step_1_Fail
      END

      -- Check if user login
      IF NOT EXISTS( SELECT 1 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = @cUser)
      BEGIN
         SET @nErrNo = 73504
         SET @cErrMsg = rdt.rdtgetmessage( 73504, @cLangCode, 'DSP') --User not login
         GOTO Step_1_Fail
      END

      -- Reset user
      UPDATE rdt.rdtMobRec SET
         UserName = 'RESET'
         , Func = 0 -- (ChewKP01) 
         , EditDate = GetDate() -- (ChewKP01) 
      WHERE UserName = @cUser
      
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 73505
         SET @cErrMsg = rdt.rdtgetmessage( 73505, @cLangCode, 'DSP') --UPD MobRecFail
         GOTO Step_1_Fail
      END
      
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cUser = ''
      SET @cOutField01 = '' --User
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 751. User
   Message
********************************************************************************/
Step_2:
BEGIN
   -- Go to prev screen
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

      StorerKey     = @cStorerKey,
      Facility      = @cFacility,
      Printer       = @cPrinter,
      -- UserName      = @cUserName,

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
      I_Field15 = @cInField15,  O_Field15 = @cOutField15

   WHERE Mobile = @nMobile
END

GO