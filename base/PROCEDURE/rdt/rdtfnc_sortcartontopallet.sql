SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdtfnc_SortCartonToPallet                              */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Purpose: sort carton to pallet                                          */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Rev  Author   Purposes                                     */
/* 2023-07-18   1.0  Ung      WMS-22855 Based on rdtfnc_PostPackSort       */
/***************************************************************************/

CREATE   PROC [RDT].[rdtfnc_SortCartonToPallet](
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
   @nTranCount    INT,
   @cOption       NVARCHAR( 1), 
   @cSQL          NVARCHAR(MAX), 
   @cSQLParam     NVARCHAR(MAX),
   @tExtValidate  VariableTable, 
   @tExtUpdate    VariableTable, 
   @tExtInfo      VariableTable, 
   @tValidate     VariableTable, 
   @tConfirm      VariableTable, 
   @tClosePallet  VariableTable

-- RDT.RDTMobRec variables
DECLARE
   @nFunc          INT,
   @nScn           INT,
   @nStep          INT,
   @cLangCode      NVARCHAR( 3),
   @nInputKey      INT,
   @nMenu          INT,

   @cStorerKey     NVARCHAR( 15),
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cLabelPrinter  NVARCHAR( 10),
   @cPaperPrinter  NVARCHAR( 10),

   @cSuggLOC            NVARCHAR( 10),
   @cSuggID             NVARCHAR( 18),
   @cSKU                NVARCHAR( 20),
   @nQTY                INT, 

   @cCartonID           NVARCHAR( 20),
   @cPalletID           NVARCHAR( 20),

   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cUpdateTable        NVARCHAR( 20), 
   @cPalletManifest     NVARCHAR( 10), 
   @cOverrideSuggestID  NVARCHAR( 1),
   
   @cCartonUDF01        NVARCHAR( 30), 
   @cCartonUDF02        NVARCHAR( 30), 
   @cCartonUDF03        NVARCHAR( 30), 
   @cCartonUDF04        NVARCHAR( 30), 
   @cCartonUDF05        NVARCHAR( 30), 
   
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),  @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),  @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),  @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),  @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),  @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),  @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),  @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),  @cFieldAttr08 NVARCHAR( 1), 
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),  @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),  @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),  @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),  @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),  @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),  @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),  @cFieldAttr15 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cLabelPrinter    = Printer,
   @cPaperPrinter    = Printer_Paper, 

   @cSuggLOC         = V_LOC,
   @cSuggID          = V_ID, 
   @cSKU             = V_SKU, 
   @nQTY             = V_QTY, 
   
   @cCartonID           = V_String1,
   @cPalletID           = V_String2,

   @cExtendedInfo       = V_String21,
   @cExtendedInfoSP     = V_String22,
   @cExtendedUpdateSP   = V_String23,
   @cExtendedValidateSP = V_String24,
   @cUpdateTable        = V_String25,
   @cOverrideSuggestID  = V_String26,
   @cPalletManifest     = V_String27,

   @cCartonUDF01        = V_String41,
   @cCartonUDF02        = V_String42,
   @cCartonUDF03        = V_String43,
   @cCartonUDF04        = V_String44,
   @cCartonUDF05        = V_String45,
        
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
   @nStep_FromCarton    INT,  @nScn_FromCarton     INT,
   @nStep_ToPallet      INT,  @nScn_ToPallet       INT,
   @nStep_ClosePallet   INT,  @nScn_ClosePallet    INT

SELECT
   @nStep_FromCarton  = 1,  @nScn_FromCarton   = 6280,
   @nStep_ToPallet    = 2,  @nScn_ToPallet     = 6281,
   @nStep_ClosePallet = 3,  @nScn_ClosePallet  = 6282

IF @nFunc = 1655
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start         -- Menu. Func = 1655
   IF @nStep = 1  GOTO Step_FromCarton    -- Scn = 6280. Carton ID, Pallet ID
   IF @nStep = 2  GOTO Step_ToPallet      -- Scn = 6281. Pallet ID
   IF @nStep = 3  GOTO Step_ClosePallet   -- Scn = 6282. Close Pallet

END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step_Start. Func = 1655
********************************************************************************/
Step_Start:
BEGIN
   -- Get storer config
   SET @cOverrideSuggestID = rdt.rdtGetConfig( @nFunc, 'OverrideSuggestID', @cStorerKey)
   
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'  
      SET @cExtendedUpdateSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'  
      SET @cExtendedValidateSP = ''
   SET @cPalletManifest = rdt.RDTGetConfig( @nFunc, 'PalletManifest', @cStorerKey)
   IF @cPalletManifest = '0'
      SET @cPalletManifest = ''
   SET @cUpdateTable = rdt.RDTGetConfig( @nFunc, 'UpdateTable', @cStorerKey)
   IF @cUpdateTable NOT IN ('DROPID', 'PALLET')
      SET @cUpdateTable = 'DROPID'
      
   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType     = '1', -- Sign-in
      @cUserID         = @cUserName,
      @nMobileNo       = @nMobile,
      @nFunctionID     = @nFunc,
      @cFacility       = @cFacility,
      @cStorerKey      = @cStorerKey
              
   -- Prepare next screen var
   SET @cOutField01 = '' -- Carton ID
   SET @cOutField02 = '' -- Pallet ID

   EXEC rdt.rdtSetFocusField @nMobile, 1 -- Carton ID

   -- Go to next screen
   SET @nScn = @nScn_FromCarton
   SET @nStep = @nStep_FromCarton
END
GOTO Quit


/************************************************************************************
Scn = 5590. Scan Carton, Pallet
   Carton ID (field01, input)
   Pallet ID (field02, input)
************************************************************************************/
Step_FromCarton:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cCartonID = @cInField01
      SET @cPalletID = @cInField02

      -- Check blank
      IF @cCartonID = '' AND @cPalletID = ''
      BEGIN
         SET @nErrNo = 203951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Value
         GOTO Quit
      END

      -- Check both not blank
      IF @cCartonID <> '' AND @cPalletID <> ''
      BEGIN
         SET @nErrNo = 203952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CTN or PLT
         GOTO Quit
      END

      -- Carton
      IF @cCartonID <> '' 
      BEGIN
         -- Check format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CartonID', @cCartonID) = 0
         BEGIN
            SET @nErrNo = 203953
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 1
            SET @cOutField01 = ''
            GOTO Quit
         END
         
         -- Carton ID valid
         EXEC rdt.rdt_SortCartonToPallet_Validate @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CartonID', 
            @cUpdateTable  = @cUpdateTable, 
            @cPalletID     = @cPalletID, 
            @cCartonID     = @cCartonID, 
            @cSKU          = @cSKU         OUTPUT, 
            @nQTY          = @nQTY         OUTPUT, 
            @cCartonUDF01  = @cCartonUDF01 OUTPUT, 
            @cCartonUDF02  = @cCartonUDF02 OUTPUT, 
            @cCartonUDF03  = @cCartonUDF03 OUTPUT, 
            @cCartonUDF04  = @cCartonUDF04 OUTPUT, 
            @cCartonUDF05  = @cCartonUDF05 OUTPUT, 
            @nErrNo        = @nErrNo       OUTPUT, 
            @cErrMsg       = @cErrMsg      OUTPUT
         IF @nErrNo <> 0
         BEGIN
            EXEC rdt.rdtSetFocusField @nMobile, 1
            SET @cOutField01 = ''
            GOTO Quit
         END
      END

      -- Pallet
      IF @cPalletID <> ''
      BEGIN
         -- Check format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'PalletID', @cPalletID) = 0
         BEGIN
            SET @nErrNo = 203954
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 2
            SET @cOutField02 = ''
            GOTO Quit
         END
                  
         -- Get pallet info
         DECLARE @cStatus NVARCHAR( 10) = ''
         IF @cUpdateTable = 'DROPID'
            SELECT @cStatus = Status FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cPalletID
         ELSE
            SELECT @cStatus = Status FROM dbo.Pallet WITH (NOLOCK) WHERE PalletKey = @cPalletID
            
         -- Check pallet valid
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 203955
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid pallet
            EXEC rdt.rdtSetFocusField @nMobile, 2
            SET @cOutField02 = ''
            GOTO Quit
         END

         -- Check pallet closed
         IF @cStatus = '9'
         BEGIN
            SET @nErrNo = 203956
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet closed
            EXEC rdt.rdtSetFocusField @nMobile, 2
            SET @cOutField02 = ''
            GOTO Quit
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cCartonID, @cPalletID, @cSuggID, @cSuggLOC, @cOption, @tExtValidate, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cPalletID      NVARCHAR( 20), ' +
               ' @cSuggID        NVARCHAR( 18), ' +
               ' @cSuggLOC       NVARCHAR( 10), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtValidate   VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cCartonID, @cPalletID, @cSuggID, @cSuggLOC, @cOption, @tExtValidate, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Quit
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cCartonID, @cPalletID, @cSuggID, @cSuggLOC, @cOption, @tExtUpdate, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cPalletID      NVARCHAR( 20), ' +
               ' @cSuggID        NVARCHAR( 18), ' +
               ' @cSuggLOC       NVARCHAR( 10), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtUpdate     VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cCartonID, @cPalletID, @cSuggID, @cSuggLOC, @cOption, @tExtUpdate, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Quit
         END
      END
      
      -- Suggest pallet
      IF @cCartonID <> '' 
      BEGIN
         -- Suggest LOC ID
         SET @cSuggID = ''
         SET @cSuggLOC = ''
         EXEC rdt.rdt_SortCartonToPallet_SuggestLOCID @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cUpdateTable  = @cUpdateTable, 
            @cPalletID     = @cPalletID, 
            @cCartonID     = @cCartonID, 
            @cCartonUDF01  = @cCartonUDF01, 
            @cCartonUDF02  = @cCartonUDF02, 
            @cCartonUDF03  = @cCartonUDF03, 
            @cCartonUDF04  = @cCartonUDF04, 
            @cCartonUDF05  = @cCartonUDF05, 
            @cSuggID       = @cSuggID  OUTPUT, 
            @cSuggLOC      = @cSuggLOC OUTPUT, 
            @nErrNo        = @nErrNo   OUTPUT, 
            @cErrMsg       = @cErrMsg  OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
         
         -- Prepare next screen var
         SET @cOutField01 = @cCartonID
         SET @cOutField02 = @cSuggLOC
         SET @cOutField03 = @cSuggID
         SET @cOutField04 = '' -- Pallet ID
         SET @cOutField05 = '' -- ExtendedInfo

         -- Go to next screen
         SET @nScn = @nScn_ToPallet
         SET @nStep = @nStep_ToPallet 
      END

      -- Close pallet
      IF @cPalletID <> ''
      BEGIN
         SET @cOutField01 = ''

         -- Go to next screen
         SET @nScn = @nScn_ClosePallet
         SET @nStep = @nStep_ClosePallet
      END      
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey
      
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      -- Reset all variables
      SET @cOutField01 = '' 
      GOTO Quit
   END

   -- Extended Info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' + 
            ' @cCartonID, @cPalletID, @cSuggID, @cSuggLOC, @cOption, @tExtValidate, ' +
            ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @cCartonID      NVARCHAR( 20), ' +
            ' @cPalletID      NVARCHAR( 20), ' +
            ' @cSuggID        NVARCHAR( 18), ' +
            ' @cSuggLOC       NVARCHAR( 10), ' +
            ' @cOption        NVARCHAR( 1), ' +
            ' @tExtValidate   VariableTable READONLY, ' + 
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep_FromCarton, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cCartonID, @cPalletID, @cSuggID, @cSuggLOC, @cOption, @tExtValidate, 
            @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nStep = 2 
            SET @cOutField05 = @cExtendedInfo
      END
      GOTO Quit
   END
END
GOTO Quit


/***********************************************************************************
Scn = 5591. Carton ID/LoadKey/Loc/Pallet ID screen
   Carton ID      (field01)
   Sugg LOC       (field02)
   Sugg ID        (field03)
   Pallet ID      (field04, input)
   ExtendedInfo   (field05)
***********************************************************************************/
Step_ToPallet:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPalletID = @cInField04 

      -- Check blank
      IF @cPalletID = ''
      BEGIN
         SET @nErrNo = 203957
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Value
         GOTO Quit  
      END

      -- Check format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'PalletID', @cPalletID) = 0  
      BEGIN
         SET @nErrNo = 203958
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Quit  
      END

      -- Check different pallet
      IF @cSuggID <> '' AND @cPalletID <> @cSuggID
      BEGIN
         -- Not allow override
         IF @cOverrideSuggestID <> '1'
         BEGIN
            SET @nErrNo = 203959
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff pallet
            GOTO Quit  
         END
      END
      
      -- Pallet ID valid
      EXEC rdt.rdt_SortCartonToPallet_Validate @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'PalletID', 
         @cUpdateTable  = @cUpdateTable, 
         @cPalletID     = @cPalletID, 
         @cCartonID     = @cCartonID, 
         @cCartonUDF01  = @cCartonUDF01, 
         @cCartonUDF02  = @cCartonUDF02, 
         @cCartonUDF03  = @cCartonUDF03, 
         @cCartonUDF04  = @cCartonUDF04, 
         @cCartonUDF05  = @cCartonUDF05, 
         @nErrNo        = @nErrNo   OUTPUT, 
         @cErrMsg       = @cErrMsg  OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
      
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cCartonID, @cPalletID, @cSuggID, @cSuggLOC, @cOption, @tExtValidate, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cPalletID      NVARCHAR( 20), ' +
               ' @cSuggID        NVARCHAR( 18), ' +
               ' @cSuggLOC       NVARCHAR( 10), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtValidate   VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cCartonID, @cPalletID, @cSuggID, @cSuggLOC, @cOption, @tExtValidate, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Quit
         END
      END

		SET @nTranCount = @@TRANCOUNT
		BEGIN TRAN
		SAVE TRAN SortCartonToPallet_Confirm

      -- Confirm
      EXEC rdt.rdt_SortCartonToPallet_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cUpdateTable  = @cUpdateTable, 
         @cCartonID     = @cCartonID, 
         @cPalletID     = @cPalletID, 
         @cSuggLOC      = @cSuggLOC, 
         @cSuggID       = @cSuggID, 
         @cSKU          = @cSKU, 
         @nQTY          = @nQTY, 
         @cUDF01        = @cCartonUDF01, 
         @cUDF02        = @cCartonUDF02, 
         @cUDF03        = @cCartonUDF03, 
         @cUDF04        = @cCartonUDF04, 
         @cUDF05        = @cCartonUDF05, 
         @nErrNo        = @nErrNo  OUTPUT,    
         @cErrMsg       = @cErrMsg OUTPUT    
      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN SortCartonToPallet_Confirm
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Quit
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cCartonID, @cPalletID, @cSuggID, @cSuggLOC, @cOption, @tExtUpdate, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cPalletID      NVARCHAR( 20), ' +
               ' @cSuggID        NVARCHAR( 18), ' +
               ' @cSuggLOC       NVARCHAR( 10), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtUpdate     VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cCartonID, @cPalletID, @cSuggID, @cSuggLOC, @cOption, @tExtUpdate, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN SortCartonToPallet_Confirm
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Quit
            END
         END
      END

      COMMIT TRAN SortCartonToPallet_Confirm
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Prepare next screen var
      SET @cOutField01 = '' -- Carton ID
      SET @cOutField02 = '' -- Pallet ID

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- Carton ID

      -- Go to next screen
      SET @nScn = @nScn_FromCarton
      SET @nStep = @nStep_FromCarton
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- Carton ID
      SET @cOutField02 = '' -- Pallet ID

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to next screen
      SET @nScn = @nScn_FromCarton
      SET @nStep = @nStep_FromCarton
   END

   -- Extended Info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' + 
            ' @cCartonID, @cPalletID, @cSuggID, @cSuggLOC, @cOption, @tExtValidate, ' +
            ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @cCartonID      NVARCHAR( 20), ' +
            ' @cPalletID      NVARCHAR( 20), ' +
            ' @cSuggID        NVARCHAR( 18), ' +
            ' @cSuggLOC       NVARCHAR( 10), ' +
            ' @cOption        NVARCHAR( 1), ' +
            ' @tExtValidate   VariableTable READONLY, ' + 
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep_ToPallet, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cCartonID, @cPalletID, @cSuggID, @cSuggLOC, @cOption, @tExtValidate, 
            @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nStep = 2 
            SET @cOutField05 = @cExtendedInfo
      END
      GOTO Quit
   END
END
GOTO Quit


/********************************************************************************
Scn = 5592. Close Pallet?
   Option (field01, input)
********************************************************************************/
Step_ClosePallet:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 203960
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionRequired
         GOTO Quit
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 203961
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Quit
      END

      -- Pallet ID valid
      EXEC rdt.rdt_SortCartonToPallet_Validate @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'PalletID', 
         @cUpdateTable  = @cUpdateTable,  
         @cPalletID     = @cPalletID, 
         @nErrNo        = @nErrNo   OUTPUT, 
         @cErrMsg       = @cErrMsg  OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

		SET @nTranCount = @@TRANCOUNT
		BEGIN TRAN
		SAVE TRAN ClosePallet

      IF @cOption = '1'  -- YES
      BEGIN
         -- Close pallet
         EXEC rdt.rdt_SortCartonToPallet_ClosePallet @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cUpdateTable  = @cUpdateTable, 
            @cPalletID     = @cPalletID, 
            @nErrNo        = @nErrNo  OUTPUT,    
            @cErrMsg       = @cErrMsg OUTPUT    
         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN ClosePallet
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
            GOTO Quit
         END
         
         -- Pallet manifest
         IF @cPalletManifest <> ''
         BEGIN
            -- Common params
            DECLARE @tPalletManifest AS VariableTable
            INSERT INTO @tPalletManifest (Variable, Value) VALUES
               ( '@cStorerKey',     @cStorerKey),
               ( '@cPalletID',      @cPalletID)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               @cPalletManifest, -- Report type
               @tPalletManifest, -- Report params
               'rdtfnc_SortCartonToPallet',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN ClosePallet
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Quit
            END
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cCartonID, @cPalletID, @cSuggID, @cSuggLOC, @cOption, @tExtUpdate, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cCartonID      NVARCHAR( 20), ' +
               ' @cPalletID      NVARCHAR( 20), ' +
               ' @cSuggID        NVARCHAR( 18), ' +
               ' @cSuggLOC       NVARCHAR( 10), ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @tExtUpdate     VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cCartonID, @cPalletID, @cSuggID, @cSuggLOC, @cOption, @tExtUpdate, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN ClosePallet
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Quit
            END
         END
      END

      COMMIT TRAN ClosePallet
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Prepare next screen var
      SET @cOutField01 = '' -- Carton ID
      SET @cOutField02 = '' -- Pallet ID

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Pallet ID

      -- Go to next screen
      SET @nScn = @nScn_FromCarton
      SET @nStep = @nStep_FromCarton
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 

      EXEC rdt.rdtSetFocusField @nMobile, 2

      -- Go to next screen
      SET @nScn = @nScn_FromCarton
      SET @nStep = @nStep_FromCarton
   END

   -- Extended Info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' + 
            ' @cCartonID, @cPalletID, @cSuggID, @cSuggLOC, @cOption, @tExtValidate, ' +
            ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @cCartonID      NVARCHAR( 20), ' +
            ' @cPalletID      NVARCHAR( 20), ' +
            ' @cSuggID        NVARCHAR( 18), ' +
            ' @cSuggLOC       NVARCHAR( 10), ' +
            ' @cOption        NVARCHAR( 1), ' +
            ' @tExtValidate   VariableTable READONLY, ' + 
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep_ClosePallet, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cCartonID, @cPalletID, @cSuggID, @cSuggLOC, @cOption, @tExtValidate, 
            @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nStep = 2 
            SET @cOutField05 = @cExtendedInfo
      END
   END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.rdtMobRec WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      V_LOC      = @cSuggLOC,
      V_ID       = @cSuggID, 
      V_SKU      = @cSKU, 
      V_QTY      = @nQTY,

      V_String1  = @cCartonID,
      V_String2  = @cPalletID,

      V_String21 = @cExtendedInfo,
      V_String22 = @cExtendedInfoSP,
	   V_String23 = @cExtendedUpdateSP,
      V_String24 = @cExtendedValidateSP,
      V_String25 = @cUpdateTable,
      V_String26 = @cOverrideSuggestID,
      V_String27 = @cPalletManifest,

      V_String41 = @cCartonUDF01,
      V_String42 = @cCartonUDF02,
      V_String43 = @cCartonUDF03,
      V_String44 = @cCartonUDF04,
      V_String45 = @cCartonUDF05,

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