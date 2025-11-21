SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: LF Logistics                                              */
/* Purpose: ChangeASNStorer                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2014-03-28 1.0  Roy He   SOS307109 Created                           */
/* 2016-09-30 1.1  Ung      Performance tuning                          */
/* 2018-10-30 1.2  Gan      Performance tuning                          */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtfnc_ChangeASNStorer] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- RDT.RDTMobRec variable
DECLARE
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5),
   @cUserName  NVARCHAR( 18),

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

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
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

IF @nFunc = 546 -- Change ASN Storer
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Change ASN Storer
   IF @nStep = 1 GOTO Step_1   -- Scn = 3810. ReceiptKey Scn
END

RETURN --Do nothing if uncorrect step

/********************************************************************************
Step 0. Fun 546 Menu
********************************************************************************/
Step_0:
BEGIN
   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- Set the entry point
   SET @nScn = 3810
   SET @nStep = 1

   -- Initialize var
   -- Init screen
END
GOTO Quit

/********************************************************************************
Step 1. Screen 3810 ReceiptKey Scn
   ReceiptKey  (field01,input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
   	  -- Declare Var
   	  DECLARE
   	     @cReceiptKey   NVARCHAR( 10),
   	     @cRStorerKey   NVARCHAR( 15),
   	     @cRDStorerKey  NVARCHAR( 15),
   	     @cRASNStatus   NVARCHAR( 10), 
   	     @cUserDefine01 NVARCHAR( 30)

      -- Screen mapping
      SET @cReceiptKey = @cInField01

      -- Validate ReceiptKey blank
      IF @cReceiptKey = ''
      BEGIN
         SET @nErrNo = 86301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NeedReceiptKey
         GOTO Step_1_Fail
      END

      -- Validate ReceiptKey in ReceiptTable
      IF NOT EXISTS(SELECT 1 FROM dbo.Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey)
      BEGIN
         SET @nErrNo = 86302
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Bad ReceiptKey
         GOTO Step_1_Fail
      END

      -- Get Vars
      SELECT
         @cRStorerKey = R.StorerKey,
         @cRASNStatus = R.ASNStatus,
         @cRDStorerKey = RD.StorerKey, 
         @cUserDefine01 = R.UserDefine01
      FROM dbo.Receipt R WITH (NOLOCK)
      JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
      WHERE R.ReceiptKey = @cReceiptKey

      -- Validate ASNStatus
      IF @cRASNStatus = '9'
      BEGIN
         SET @nErrNo = 86303
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ASN finalized
         GOTO Step_1_Fail
      END
      
      -- Validate ReceiptDetail.Storerkey = cStorerKey
      IF @cRDStorerKey <> @cStorerKey
      BEGIN
         SET @nErrNo = 86304
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Storer
         GOTO Step_1_Fail
      END

      -- Validate ReceiptDetail.Storerkey = Receipt.Storerkey
      IF @cRDStorerKey = @cRStorerKey
      BEGIN
         SET @nErrNo = 86305
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoNeedToUpdate
         GOTO Step_1_Fail
      END

      -- Check UserDefine01
      IF @cUserDefine01 <> ''
      BEGIN
         SET @nErrNo = 86306
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UDF01 NotBlank
         GOTO Step_1_Fail
      END

      DECLARE @nTranCount INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdtfnc_ChangeASNStorer

      -- Update storer
      UPDATE dbo.Receipt SET
         UserDefine01 = @cRStorerKey,
         StorerKey    = @cRDStorerKey
      WHERE ReceiptKey = @cReceiptKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 86307
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPDReceiptFail
         ROLLBACK TRAN rdtfnc_ChangeASNStorer
         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN
         GOTO Step_1_Fail
      END

      COMMIT TRAN rdtfnc_ChangeASNStorer
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN

      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '1', -- Receive
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @cReceiptKey = @cReceiptKey,
         @cRefNo1     = @cRStorerKey, 
         @cRefNo2     = @cRDStorerKey,
         @nStep       = @nStep

      -- Remain in current screen
      SET @cOutField01 = '' -- ReceiptKey 
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-Out
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
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOutField01 = '' -- ReceiptKey
   END
END
GOTO Quit

-- Load RDT.RDTMobRec
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
      -- UserName  = @cUserName,

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