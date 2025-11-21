SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: ChangePassWord                                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2014-06-18 1.0  Roy He   ChangePassWord                              */
/* 2016-09-30 1.1  Ung      Performance tuning                          */
/* 2018-10-30 1.2  TungGH   Performance                                 */
/* 2024-07-26 1.3  Jackc    UWP-21905 Encrypt password                  */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtfnc_ChangePassWord] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON 
SET QUOTED_IDENTIFIER OFF 
SET ANSI_NULLS OFF

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

IF @nFunc = 800 -- Change PassWord
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Change Change PassWord  
   IF @nStep = 1 GOTO Step_1   -- Scn = 900. Enter Old PassWord Scn
   IF @nStep = 2 GOTO Step_2   -- Scn = 901. Change Successfully Scn
END

RETURN --Do nothing if uncorrect step

/********************************************************************************
Step 0. Fun 800 Menu
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
   SET @nScn = 900
   SET @nStep = 1
    
   -- Initialize var
   -- Init screen  
END  
GOTO Quit  

/********************************************************************************
Step 1. Screen 900 Enter Old PassWord Scn
User    Name(field01,output) 
Old     PassWord(field01,input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Declare Var
      DECLARE 
         @cUserCount    INT,
         @cUser         NVARCHAR(15),
         @cNewPas       NVARCHAR(15),
         @cConfirmPas   NVARCHAR(15),
         @cEncryptPaw   NVARCHAR(32)
         
      -- Screen mapping
      SET @cUser = @cInField01
      SET @cNewPas = @cInField02
      SET @cConfirmPas = @cInField03
      
      -- Validate User Blank
      IF ISNULL(RTRIM(@cUser),'') = ''
      BEGIN
         SET @nErrNo = 90301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UserName Needed
         GOTO QUIT
      END
      
      -- Validate Old PassWord Blank
      IF ISNULL(RTRIM(@cNewPas),'') = ''
      BEGIN
         SET @nErrNo = 90302
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NewPas Needed
         GOTO QUIT
      END
      
      -- Validate ConfirmPas Blank
      IF ISNULL(RTRIM(@cConfirmPas),'') = ''
      BEGIN
         SET @nErrNo = 90303
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ConfirmPas Needed
         GOTO QUIT
      END
      
      -- Get User Count
      SELECT @cUserCount = COUNT(1) 
      FROM rdt.RDTUser r WITH (NOLOCK)
      WHERE UserName = @cUser 
   
      -- Validate User Exists
      IF @cUserCount = 0
      BEGIN
         SET @nErrNo = 90304
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid UserName
         GOTO QUIT
      END
        
      -- Validate Record Number In Rdt User Table
      IF @cUserCount > 1
      BEGIN
         SET @nErrNo = 90305
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Multiple Records Found
         GOTO QUIT
      END
      
      -- Validate ConfirmPas And New PassWord
      IF NOT ISNULL(RTRIM(@cNewPas),'') = ISNULL(RTRIM(@cConfirmPas),'')
      BEGIN
         SET @nErrNo = 90306
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NewPas Not Match
         GOTO QUIT
      END

      --V1.3 Jackc
      SET @cEncryptPaw = rdt.rdt_RDTUserEncryption(@cUser, @cNewPas)
      --V1.3 Jackc End
      
      -- Update in backend
      UPDATE rdt.RdtUser WITH (ROWLOCK) SET
         PASSWORD = ISNULL(RTRIM(@cEncryptPaw),'')
      WHERE UserName = @cUser
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 90307  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPDRDTUser Record
         GOTO QUIT 
      END
         
      -- Set the entry point
      SET @nScn = 901
      SET @nStep = 2
    
      -- Initialize var
      -- Init screen
      
      -- Go to next screen
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
END
GOTO Quit

/********************************************************************************
Step 2. Screen 901 Change Successfully Msg
********************************************************************************/
Step_2:
BEGIN
   -- Set the entry point
      SET @nScn = 900
      SET @nStep = 1
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