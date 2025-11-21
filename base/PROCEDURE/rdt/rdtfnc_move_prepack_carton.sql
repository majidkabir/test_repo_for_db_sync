SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_Move_PrePack_Carton                          */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2022-07-28 1.0  Ung      WMS-20345 Created                           */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtfnc_Move_PrePack_Carton] (
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @nRowCount    INT,
   @cChkFacility NVARCHAR( 5),
   @cSQL         NVARCHAR( MAX),
   @cSQLParam    NVARCHAR( MAX), 
   @tExtInfo     VariableTable,
   @tExtUpd      VariableTable,
   @tExtVal      VariableTable

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,

   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cPaperPrinter NVARCHAR( 10),
   @cLabelPrinter NVARCHAR( 10),


   @cFromLOC      NVARCHAR( 10),
   @nQTY          INT, 

   @cToLOC              NVARCHAR( 10),
   @cToID               NVARCHAR( 18),
   @cFromLOCLoseID      NVARCHAR( 1),

   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cDefaultToIDAsRefNo NVARCHAR( 1),
   @cPalletManifest     NVARCHAR( 10),

   @cRefNo      NVARCHAR( 60),

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

-- Load RDT.RDTMobRec
SELECT
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @nMenu       = Menu,
   @cLangCode   = Lang_code,

   @cStorerKey    = StorerKey,
   @cFacility     = Facility,
   @cPaperPrinter = Printer_Paper,
   @cLabelPrinter = Printer,

   @cFromLOC      = V_LOC,
   @nQTY          = V_QTY,

   @cToLOC              = V_String1,
   @cToID               = V_String2,
   @cFromLOCLoseID      = V_String3,

   @cExtendedInfoSP     = V_String20,
   @cExtendedInfo       = V_String21,
   @cExtendedUpdateSP   = V_String22,
   @cExtendedValidateSP = V_String23,
   @cDefaultToIDAsRefNo = V_String24,
   @cPalletManifest     = V_String25,
   
   @cRefNo              = V_String41, 

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
   @nStep_FromLOC    INT,  @nScn_FromLOC     INT,  
   @nStep_RefNo      INT,  @nScn_RefNo       INT,  
   @nStep_QTY        INT,  @nScn_QTY         INT,  
   @nStep_ToIDLOC    INT,  @nScn_ToIDLOC     INT,   
   @nStep_Message    INT,  @nScn_Message     INT
  
SELECT  
   @nStep_FromLOC    = 1,  @nScn_FromLOC     = 6080,  
   @nStep_RefNo      = 2,  @nScn_RefNo       = 6081,  
   @nStep_QTY        = 3,  @nScn_QTY         = 6082,  
   @nStep_ToIDLOC    = 4,  @nScn_ToIDLOC     = 6083,  
   @nStep_Message    = 5,  @nScn_Message     = 6084

IF @nFunc = 651 -- Move PrePack Carton
BEGIN
   -- Redirect to respective screen  
   IF @nStep = 0 GOTO Step_Start       -- Func = Move prepack carton  
   IF @nStep = 1 GOTO Step_FromLOC     -- Scn = 6080. FromLOC    
   IF @nStep = 2 GOTO Step_RefNo       -- Scn = 6081. RefNo
   IF @nStep = 3 GOTO Step_QTY         -- Scn = 6082. QTY  
   IF @nStep = 4 GOTO Step_ToIDLOC     -- Scn = 6083. ToID, ToLOC 
   IF @nStep = 5 GOTO Step_Message     -- Scn = 6084. Message
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 651. Menu
********************************************************************************/
Step_Start:
BEGIN
   -- Set the entry point
   SET @nScn = 6080
   SET @nStep = 1

   SET @cDefaultToIDAsRefNo = rdt.rdtGetConfig( @nFunc, 'DefaultToIDAsRefNo', @cStorerKey)

   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cPalletManifest = rdt.rdtGetConfig( @nFunc, 'PalletManifest', @cStorerKey)
   IF @cPalletManifest = '0'
      SET @cPalletManifest = ''

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 6080. FromLOC
   FromLOC (field01, input)
********************************************************************************/
Step_FromLOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFromLOC = @cInField01

      -- Check blank
      IF @cFromLOC = ''
      BEGIN
         SET @nErrNo = 188901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC needed
         SET @cOutField01 = '' -- @cFromLOC
         GOTO Quit
      END

      -- Get LOC info
      SELECT
         @cChkFacility = Facility,
         @cFromLOCLoseID = LoseID
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cFromLOC

      -- Check LOC valid
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 188902
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         SET @cOutField01 = '' -- @cFromLOC
         GOTO Quit
      END

      -- Check facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 188903
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         SET @cOutField01 = '' -- @cFromLOC
         GOTO Quit
      END

      -- Get StorerConfig 'UCC'
      DECLARE @cUCCStorerConfig NVARCHAR( 1)
      SELECT @cUCCStorerConfig = SValue
      FROM dbo.StorerConfig (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ConfigKey = 'UCC'

      -- Check UCC exists
      IF @cUCCStorerConfig = '1'
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.UCC (NOLOCK)
            WHERE Storerkey = @cStorerKey
               AND LOC = @cFromLOC
               AND ISNULL(LOT,'') <> ''
               AND Status = 1) -- 1=Received
         BEGIN
            SET @nErrNo = 188904
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC have UCC
         SET @cOutField01 = '' -- @cFromLOC
         GOTO Quit
         END
      END

      -- Go to next screen
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = '' --@cRefNo

      SET @nScn = @nScn_RefNo
      SET @nStep = @nStep_RefNo
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     -- EventLog
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 2. scn = 6081. RefNo screen
   FromLOC (field01)
   RefNo   (field02, input)
********************************************************************************/
Step_RefNo:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cRefNo = @cInField02

      -- Check blank
      IF @cRefNo = ''
      BEGIN
         SET @nErrNo = 188905
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need REFNO
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' + 
               ' @cFromLOC, @cRefNo, @nQTY, @cToID, @cToLOC, @tExtVal, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR(  5), ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cToID           NVARCHAR( 18), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@tExtVal         VariableTable READONLY, ' + 
               '@nErrNo          INT           OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
               @cFromLOC, @cRefNo, @nQTY, @cToID, @cToLOC, @tExtVal,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Prep next screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = '' -- QTY

      -- Go to next screen
      SET @nScn = @nScn_QTY
      SET @nStep = @nStep_QTY
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = '' -- @cFromLOC

      SET @nScn = @nScn_FromLOC
      SET @nStep = @nStep_FromLOC
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 6082. QTY screen
   FromLOC (field01)
   RefNo   (field02)
   QTY     (field03, input)
********************************************************************************/
Step_QTY:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cQTY NVARCHAR( 5)
      
      -- Screen mapping
      SET @cQTY = @cInField03

      -- Check QTY
      IF RDT.rdtIsValidQTY( @cQTY, 0) = 0
      BEGIN
         SET @nErrNo = 188906
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         GOTO Quit
      END
      SET @nQTY = @cQTY

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' + 
               ' @cFromLOC, @cRefNo, @nQTY, @cToID, @cToLOC, @tExtVal, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR(  5), ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cToID           NVARCHAR( 18), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@tExtVal         VariableTable READONLY, ' + 
               '@nErrNo          INT           OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
               @cFromLOC, @cRefNo, @nQTY, @cToID, @cToLOC, @tExtVal, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      IF @cDefaultToIDAsRefNo = '1' 
         SET @cToID = @cRefNo

      -- Prep SKU screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = CAST( @nQTY AS NVARCHAR( 5))
      SET @cOutField04 = @cToID
      SET @cOutField05 = '' -- @cToLOC

      IF @cToID = ''
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- ToID
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToLOC
      
      -- Go to TOID, TOLOC screen
      SET @nScn = @nScn_ToIDLOC
      SET @nStep = @nStep_ToIDLOC
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep SKU screen var
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = '' -- @cRefNo
      
      -- Go to prev screen
      SET @nScn = @nScn_RefNo
      SET @nStep = @nStep_RefNo
   END
END
GOTO Quit


/********************************************************************************
Step 4. Scn = 6084. ToID, ToLOC
   FromID  (field01)
   RefNo   (field02)
   QTY     (field03)
   ToID    (field04, input)
   ToID    (field05, input)
********************************************************************************/
Step_ToIDLOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToID = @cInField04
      SET @cToLOC = @cInField05

      IF @cToID <> ''
      BEGIN
         -- Check format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'TOID', @cToID) = 0
         BEGIN
            SET @nErrNo = 188907
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- To ID
            SET @cOutField04 = '' -- To ID
            GOTO Quit
         END
         SET @cOutField04 = @cToID
      END

      -- Check blank
      IF @cToLOC = ''
      BEGIN
         SET @nErrNo = 188908
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLOC needed
         GOTO Step_ToIDLOC_Fail_ToLOC
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE LOC = @cToLOC

      -- Check LOC valid
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 188909
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         GOTO Step_ToIDLOC_Fail_ToLOC
      END

      -- Check facility
      IF NOT (rdt.rdtGetConfig( 0, 'MoveToLOCNotCheckFacility', @cStorerKey) = '1')
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 188910
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
            GOTO Step_ToIDLOC_Fail_ToLOC
         END

      -- Check FromLOC same as ToLOC
      IF @cFromLOC = @cToLOC
      BEGIN
         IF rdt.rdtGetConfig(@nFunc, 'MoveNotCheckSameFromToLoc', @cStorerKey) <> '1'
         BEGIN
            SET @nErrNo = 188911
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Same FromToLOC
            GOTO Step_ToIDLOC_Fail_ToLOC
         END
      END

      -- Confirm
      EXEC rdt.rdt_Move_PrePack_Carton_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
         @cFromLOC = @cFromLOC, 
         @cRefNo   = @cRefNo, 
         @nQTY     = @nQTY, 
         @cToID    = @cToID, 
         @cToLOC   = @cToLOC, 
         @nErrNo   = @nErrNo  OUTPUT,
         @cErrMsg  = @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Pallet manifest
      IF @cPalletManifest <> ''
      BEGIN
         -- Common params
         DECLARE @tPalletManifest AS VariableTable
         INSERT INTO @tPalletManifest (Variable, Value) VALUES
            ( '@cFromLOC',    @cFromLOC),
            ( '@cRefNo',      @cRefNo),
            ( '@nQTY',        CAST( @nQTY AS NVARCHAR(10))), 
            ( '@cToID',       @cToID),
            ( '@cToLOC',      @cToLOC)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
            @cPalletManifest, -- Report type
            @tPalletManifest, -- Report params
            'rdtfnc_Move_PrePack_Carton',
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
         -- IF @nErrNo <> 0
         --    GOTO Quit
      END

      -- Go to next screen
      SET @nScn = @nScn_Message
      SET @nStep = @nStep_Message
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cFromLOC
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = '' -- @nQTY
      
      -- Go to QTY screen
      SET @nScn = @nScn_QTY
      SET @nStep = @nStep_QTY
   END
   GOTO Quit
   
   Step_ToIDLOC_Fail_ToLOC:
   BEGIN
      EXEC rdt.rdtSetFocusField @nMobile, 5 -- To ID
      SET @cOutField05 = '' -- To LOC
   END
END
GOTO Quit


/********************************************************************************
Step 6. Scn = 6085. Message
********************************************************************************/
Step_Message:
BEGIN
   -- Prepare next screen
   SET @cOutField01 = @cFromLOC
   SET @cOutField02 = '' -- @cRefNo

   -- Go to RefNo screen
   SET @nScn = @nScn_RefNo
   SET @nStep = @nStep_RefNo
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

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,
      Printer_Paper  = @cPaperPrinter,
      Printer        = @cLabelPrinter,

      V_LOC          = @cFromLOC,
      V_QTY          = @nQTY,
                     
      V_String1      = @cToLOC,
      V_String2      = @cToID,
      V_String3      = @cFromLOCLoseID,
                     
      V_String20     = @cExtendedInfoSP,
      V_String21     = @cExtendedInfo,
      V_String22     = @cExtendedUpdateSP,
      V_String23     = @cExtendedValidateSP,
      V_String24     = @cDefaultToIDAsRefNo,
      V_String25     = @cPalletManifest,
                     
      V_String41     = @cRefNo,

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

END

GO