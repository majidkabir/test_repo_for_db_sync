SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_Scan_Pallet_To_Mbol                                */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author      Purposes                                     */
/* 2019-06-27   1.0  James       WMS9541 Created                              */
/* 2019-07-31   1.1  James       INC0797983 - Fix display how many pallet     */
/*                               scanned based on mbolkey (james01)           */
/* 2021-11-09   1.2  Chermaine   WMS-18206 Add AutoGen mbolKey in st1         */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_Scan_Pallet_To_Mbol] (
   @nMobile    INT,
   @nErrNo     INT          OUTPUT,
   @cErrMsg    NVARCHAR(20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @bSuccess   INT,
   @nTranCount INT,
   @nRowCount  INT,
   @cOption    NVARCHAR( 1),
   @cSQL       NVARCHAR( MAX),
   @cSQLParam  NVARCHAR( MAX)

-- RDT.RDTMobRec variables
DECLARE
   @nFunc          INT,
   @nScn           INT,
   @nStep          INT,
   @cLangCode      NVARCHAR( 3),
   @nInputKey      INT,
   @nMenu          INT,
   @nTaskUpdated   INT,

   @cStorerGroup   NVARCHAR( 20),
   @cStorerKey     NVARCHAR( 15),
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cMbolKey       NVARCHAR( 10),
   @cPalletID      NVARCHAR( 30),
   @nScanned       INT,

   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cGroupKey           NVARCHAR( 10),    
   @cTaskDetailKey      NVARCHAR( 10),    
   @cStatus             NVARCHAR( 10),    
   @cChkStorerKey       NVARCHAR( 15),    
   @cPrevMbolKey        NVARCHAR( 10),    
   @cGenMbol            NVARCHAR( 1),  --(cc01)
   @cCreateMbol         NVARCHAR( 1),  --(cc01)
   @tExtUpdate          VariableTable, 
   @tExtValidate        VariableTable, 
   @tExtInfo            VariableTable, 
   @tScanPalletToMBOL   VariableTable, 

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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerGroup     = StorerGroup,
   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,

   @nScanned            = V_Integer1,

   @cMbolKey            = V_String1,
   @cExtendedValidateSP = V_String2,
   @cExtendedUpdateSP   = V_String3,
   @cExtendedInfoSP     = V_String4,
   @cExtendedInfo       = V_String5,
   @cPrevMbolKey        = V_String6,
   @cGenMbol            = V_String7,   --(cc01)
   @cCreateMbol         = V_String8,   --(cc01)

   @cPalletID           = V_String41,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01 = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_MbolKey       INT,  @nScn_MbolKey        INT,
   @nStep_PalletID      INT,  @nScn_PalletID       INT

SELECT
   @nStep_MbolKey       = 1,  @nScn_MbolKey     = 5540,
   @nStep_PalletID      = 2,  @nScn_PalletID    = 5541   

IF @nFunc = 1666 -- Scan Pallet To Mbol
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0  -- Menu. Func = 1822
   IF @nStep = 1  GOTO Step_MbolKey   -- Scn = 5530. GroupKey
   IF @nStep = 2  GOTO Step_PalletID  -- Scn = 5530. Pallet ID
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step_0. Func = 1666
********************************************************************************/
Step_0:
BEGIN
	-- Get storer configure
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
	SET @cGenMbol = rdt.rdtGetConfig( @nFunc, 'GenMbol', @cStorerKey)  --(cc01)
   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep

   SET @cMbolKey = ''
   SET @cPrevMbolKey = ''
   SET @cPalletID = ''
   SET @nScanned = 0

   IF @cGenMbol = '1'
   BEGIN
   	SET @cFieldAttr02 = ''
   END
   ELSE
   BEGIN
   	SET @cFieldAttr02 = 'O'
   END
   -- Prepare next screen var
   SET @cOutField01 = '' -- MbolKey

   -- Go to PickSlipNo screen
   SET @nScn = @nScn_MbolKey
   SET @nStep = @nStep_MbolKey
END
GOTO Quit


/************************************************************************************
Scn = 5540. MbolKey screen
   MbolKey    (field01, input)
   CreateMbol (field02, input)
************************************************************************************/
Step_MbolKey:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cMbolKey = @cInField01
      SET @cCreateMbol = @cInField02
      
      IF @cCreateMbol = 'Y' AND @cMbolKey <> ''
      BEGIN
      	SET @nErrNo = 141308
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NeedBlankMBOL
         GOTO Step_MBOL_Fail
      END

      -- Check blank
      IF @cMbolKey = '' AND @cCreateMbol <> 'Y'
      BEGIN
         SET @nErrNo = 141301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MbolKey req
         GOTO Step_MBOL_Fail
      END

      --(cc01)
      IF @cGenMbol = '1' AND @cCreateMbol = 'Y'
      BEGIN
      	-- Get MBOLKey    
         EXECUTE nspg_GetKey    
            'MBOL',    
            10,    
            @cMBOLKey   OUTPUT,    
            @bSuccess   OUTPUT,    
            @nErrNo     OUTPUT,    
            @cErrMsg    OUTPUT    
         IF @bSuccess <> 1    
         BEGIN    
            SET @nErrNo = 141309    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenMBOLKeyFail  
            GOTO Step_MBOL_Fail    
         END    
             
         -- Insert MBOL    
         INSERT INTO MBOL (MBOLKey, Facility, STATUS) VALUES (@cMBOLKey, @cFacility, '0')    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 141310    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBOL Fail    
            GOTO Step_MBOL_Fail    
         END   
      END
      
      SELECT @cStatus = Status
      FROM dbo.MBOL WITH (NOLOCK)
      WHERE MbolKey = @cMbolKey

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 141302
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mbol Not Exists
         GOTO Step_MBOL_Fail
      END

      IF @cStatus = '9'
      BEGIN
         SET @nErrNo = 141303
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mbol Shipped
         GOTO Step_MBOL_Fail
      END

      -- Check storer group
      IF @cStorerGroup <> ''
      BEGIN
         SELECT TOP 1 @cStorerKey = StorerKey
         FROM dbo.StorerGroup WITH (NOLOCK) 
         WHERE @cStorerGroup = StorerGroup
         ORDER BY 1 DESC   -- with storerkey value come first (storerkey can blank)

         IF @cStorerKey = ''
         BEGIN
            SET @nErrNo = 141304
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No StorerKey
            GOTO Step_MBOL_Fail
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         INSERT INTO @tExtValidate (Variable, Value) VALUES 
         ('@cMbolKey',       @cMbolKey)

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @tExtValidate, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tExtValidate   VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @tExtValidate, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Step_MBOL_Fail
         END
      END

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         INSERT INTO @tExtInfo (Variable, Value) VALUES 
         ('@cMbolKey',       @cMbolKey)

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @tExtInfo, @cExtendedInfo OUTPUT' 

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tExtInfo       VariableTable READONLY, ' + 
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @tExtInfo, @cExtendedInfo OUTPUT

            IF @cExtendedInfo <> '' 
               SET @cOutField15 = @cExtendedInfo
         END
      END

      -- (james01)
      IF @cPrevMbolKey <> @cMbolKey
      BEGIN
         SET @cPrevMbolKey = @cMbolKey
         SET @nScanned = 0
      END

      SET @cOutField01 = @cMbolKey
      SET @cOutField02 = ''
      SET @cOutField03 = CAST( @nScanned AS NVARCHAR( 3))
      SET @cFieldAttr02 = ''

      -- Go to Message screen
      SET @nScn = @nScn_PalletID
      SET @nStep = @nStep_PalletID
   END

   IF @nInputKey = 0 -- Esc or No
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

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
   GOTO Quit

   Step_MBOL_Fail:
   BEGIN
      SET @cOutField01 = '' -- MbolKey
   END
END
GOTO Quit

/********************************************************************************
Scn = 5541. Pallet ID
   MbolKey      (field01)
   Pallet ID    (field02, input)
********************************************************************************/
Step_PalletID:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Prepare next screen var
      SET @cPalletID = @cInField02 -- Pallet id

      IF @cPalletID = ''
      BEGIN
         SET @nErrNo = 141305
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PalletID req
         GOTO Step_PalletID_Fail
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.PALLET WITH (NOLOCK) WHERE PalletKey = @cPalletID)
      BEGIN
         SET @nErrNo = 141306
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Pallet
         GOTO Step_PalletID_Fail
      END

     SET @cStatus = ''
      SELECT TOP 1 
         @cStatus = Status
      FROM dbo.PALLET WITH (NOLOCK)
      WHERE PalletKey = @cPalletID
      ORDER BY 1 

      IF @cStatus <> '9'
      BEGIN
         SET @nErrNo = 141307
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Plt Not Close
         GOTO Step_PalletID_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         INSERT INTO @tExtValidate (Variable, Value) VALUES 
         ('@cMbolKey',       @cMbolKey),
         ('@cPalletID',      @cPalletID)

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @tExtValidate, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tExtValidate   VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @tExtValidate, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Step_PalletID_Fail
         END
      END

      INSERT INTO @tScanPalletToMBOL (Variable, Value) VALUES 
      ('@cMbolKey',       @cMbolKey),
      ('@cPalletID',      @cPalletID)

      SET @nErrNo = 0
      EXEC rdt.rdt_ScanPalletToMBOL_Confirm
         @nMobile       = @nMobile,
         @nFunc         = @nFunc,
         @cLangCode     = @cLangCode,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility, 
         @tScanPalletToMBOL = @tScanPalletToMBOL,
         @nErrNo        = @nErrNo            OUTPUT,
         @cErrMsg       = @cErrMsg           OUTPUT

      IF @nErrNo = 0
         SET @nScanned = @nScanned + 1

      SET @cOutField01 = @cMbolKey
      SET @cOutField02 = ''
      SET @cOutField03 = CAST( @nScanned AS NVARCHAR( 3))
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
   	--(cc01)
   	IF @cGenMbol = '1'
      BEGIN
   	   SET @cFieldAttr02 = ''
      END
      ELSE
      BEGIN
   	   SET @cFieldAttr02 = 'O'
      END
      -- Prepare next screen var
      SET @cOutField01 = '' -- MbolKey

      -- Go to PickSlipNo screen
      SET @nScn = @nScn_MbolKey
      SET @nStep = @nStep_MbolKey
   END

   GOTO Quit

   Step_PalletID_Fail:
   BEGIN
      SET @cOutField01 = @cMBOLKey  -- MBOLKey
      SET @cOutField02 = ''         -- Pallet ID
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

      StorerGroup    = @cStorerGroup,
      StorerKey      = @cStorerKey,
      Facility       = @cFacility,

      V_Integer1     = @nScanned,

      V_String1      = @cMbolKey,
      V_String2      = @cExtendedValidateSP,
      V_String3      = @cExtendedUpdateSP,
      V_String4      = @cExtendedInfoSP,
      V_String5      = @cExtendedInfo,
      V_String6      = @cPrevMbolKey,
      V_String7      = @cGenMbol,      --(cc01)
      V_String8      = @cCreateMbol,   --(cc01)

      V_String41     = @cPalletID,

      I_Field01 = '',  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,
      I_Field02 = '',  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,
      I_Field03 = '',  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,
      I_Field04 = '',  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,
      I_Field05 = '',  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,
      I_Field06 = '',  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,
      I_Field07 = '',  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,
      I_Field08 = '',  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08,
      I_Field09 = '',  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,
      I_Field10 = '',  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,
      I_Field11 = '',  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,
      I_Field12 = '',  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,
      I_Field13 = '',  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,
      I_Field14 = '',  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,
      I_Field15 = '',  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile
END

GO