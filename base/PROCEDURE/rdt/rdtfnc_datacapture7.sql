SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_DataCapture7                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Ad-hoc data capturing in warehouse                          */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 29-Sep-2015 1.0  James      SOS352057 Created                        */
/* 07-Jan-2016 1.1  James      Disallow same Plt id in same seal no     */
/*                             Allow error no from rdtmove (james01)    */
/* 30-Sep-2016 1.2  Ung        Performance tuning                       */
/* 26-Oct-2018 1.3  Gan        Performance tuning                       */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_DataCapture7] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF  

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

   @cStorer       NVARCHAR( 15),
   @cLoc          NVARCHAR( 10),
	@cPalletID     NVARCHAR( 18),
	@cSealNo       NVARCHAR( 20),
   @cUserName     NVARCHAR( 18), 
   @cLottable06   NVARCHAR( 30), 
   @nCount        INT,
   @nTranCount    INT,

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

   @cSealNo    = V_String1,    
  -- @nCount     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String2, 5), 0) = 1 THEN LEFT( V_String2, 5) ELSE 0 END, 
  
   @nCount     = V_Integer1,

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
FROM rdt.RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 822 -- Data capture
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Data capture
   IF @nStep = 1 GOTO Step_1   -- 4280 SEAL NO
   IF @nStep = 2 GOTO Step_2   -- 4281 SEAL NO, PALLET ID, COUNT #
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 880. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 4280
   SET @nStep = 1

   -- Initiate var
   SET @cSealNo = ''
   SET @cStorerKey = ''
   SET @cPalletID = ''
   SET @nCount = 0

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

   EXEC rdt.rdtSetFocusField @nMobile, 1

   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 4280
   SEAL NO       (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSealNo = @cInField01

      -- Validate location
      IF ISNULL( @cSealNo, '') = '' 
      BEGIN
         SET @nErrNo = 56951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Seal# required'
         GOTO Step_1_Fail
      END

      SELECT @nCount = COUNT( DISTINCT V_ID) 
      FROM rdt.rdtDataCapture WITH (NOLOCK)
      WHERE V_String1 = 'OTW2BULIM'
      AND   V_String2 = @cSealNo

      SET @cPalletID = ''      

      SET @cOutField01 = @cSealNo 
      SET @cOutField02 = '' 
      SET @cOutField03 = @nCount 

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
      SET @cOutField01 = '' -- Clean up for menu option
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cSealNo = ''
      SET @cInfield01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 1. Screen = 4281
   SEAL NO       (Field01)
   PALLET ID     (Field03, input)
   COUNT #       (Field01) 
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPalletID = @cInField02

       -- Validate location
      IF ISNULL( @cPalletID, '') = '' 
      BEGIN
         SET @nErrNo = 56952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Plt ID req'
         GOTO Step_2_Fail
      END

      SELECT TOP 1 @cLoc = LLI.Loc, 
                   @cLottable06 = LA.Lottable06, 
                   @cStorer = LLI.StorerKey 
      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
      JOIN dbo.LotAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)
      WHERE LLI.ID = @cPalletID
      AND   ( LLI.Qty - LLI.QtyPicked) > 0

      IF ISNULL( @cLoc, '') = ''
      BEGIN
         SET @nErrNo = 56953
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Plt ID'
         GOTO Step_2_Fail
      END

      IF EXISTS ( SELECT 1 FROM rdt.rdtDataCapture WITH (NOLOCK) 
                  WHERE V_String1 = 'OTW2BULIM'
                  AND   V_ID = @cPalletID
                  AND   Facility = @cFacility
                  AND   V_String2 = @cSealNo)   -- (james01)
      BEGIN
         SET @nErrNo = 56954
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Plt ID Exists'
         GOTO Step_2_Fail
      END

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdtDataCapture7

      INSERT INTO rdt.rdtDataCapture 
      (StorerKey, Facility, V_Loc, V_ID, V_String1, V_String2, V_Lottable06) VALUES 
      (@cStorer, @cFacility, @cLoc, @cPalletID, 'OTW2BULIM', @cSealNo, @cLottable06)

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 56955
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Insert Error'
         ROLLBACK TRAN rdtDataCapture7
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Quit
      END

      SET @nErrNo = 0
      EXECUTE rdt.rdt_Move
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode, 
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
         @cSourceType = 'rdtfnc_DataCapture7', 
         @cStorerKey  = @cStorer,
         @cFacility   = @cFacility, 
         @cFromLOC    = @cLoc, 
         @cToLOC      = 'OTW2BULIM',
         @cFromID     = @cPalletID, 
         @cToID       = NULL  -- NULL means not changing ID

      IF @nErrNo <> 0
      BEGIN
         --SET @nErrNo = 56956   (james01)
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Move Error'
         ROLLBACK TRAN rdtDataCapture7
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Quit
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
      END

      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '9', -- Activity tracking
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorer,
         @cLocation     = @cLoc,
         @cID           = @cPalletID,
         @cLottable06   = @cLottable06,
         @cRefNo1       = 'OTW2BULIM',
         --@cRefNo2       = @cSealNo,
         @cSealNo       = @cSealNo,
         @nStep         = @nStep

      SET @nCount = @nCount + 1

      -- Reset everything and prepare next scan
      SET @cInfield02 = ''
      SET @cPalletID = ''
      SET @cOutfield03 = @nCount
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cSealNo = ''
      SET @cOutField01 = '' 

      -- Go back screen 1
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cPalletID = ''
      SET @cOutField02 = ''
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility,

      V_String1 = @cSealNo, 
      --V_String2 = @nCount, 
      
      V_Integer1 = @nCount,

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