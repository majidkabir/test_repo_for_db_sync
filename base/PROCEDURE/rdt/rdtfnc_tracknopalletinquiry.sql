SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_TrackNoPalletInquiry                               */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2018-03-20 1.0  Ung      WMS-4225 Created                                  */
/* 2018-10-01 1.1  Ung      WMS-4225 Fix multi page issue                     */
/* 2018-10-10 1.2  Gan      Performance tuning                                */
/* 2022-10-07 1.3  Ung      WMS-20952 Add PalletNotLinkMBOL                   */
/*                          Add PalletDetailTrackingNo                        */
/******************************************************************************/

CREATE   PROC [RDT].[rdtfnc_TrackNoPalletInquiry](
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
   @bSuccess            INT, 
   @nTranCount          INT, 
   @nRowCount           INT, 
   @cSQL                NVARCHAR(MAX), 
   @cSQLParam           NVARCHAR(MAX), 
   @cOption             NVARCHAR(1), 
   @cChkStorerKey       NVARCHAR(15), 
   @cChkFacility        NVARCHAR(5), 
   @cChkStatus          NVARCHAR(10), 
   @tVar                VariableTable    

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),
   @cPrinter            NVARCHAR(10),
   @cPrinter_Paper      NVARCHAR(10),
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cPalletKey          NVARCHAR(20),
   @cMBOLKey            NVARCHAR(10),
   @cTrackNo            NVARCHAR(20),
   @cTotalCarton        NVARCHAR(5),
   @cInvalidCarton      NVARCHAR(5),
   @cCurrentPage        NVARCHAR(2),
   @cTotalPage          NVARCHAR(2),

   @cExtendedInfoSP     NVARCHAR(20),
   @cExtendedInfo       NVARCHAR(20),
   @cExtendedUpdateSP   NVARCHAR(20),
   @cExtendedValidateSP NVARCHAR(20),
   @cPalletNotLinkMBOL  NVARCHAR(1),
   @cPalletDetailTrackingNo NVARCHAR(1),

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
   @cLangCode        = Lang_code,
   @nMenu            = Menu,

   @cFacility        = Facility,
   @cStorerKey       = StorerKey,
   @cPrinter         = Printer,
   @cPrinter_Paper   = Printer_Paper,
   @cUserName        = UserName,

   @cPalletKey          = V_String1,
   @cMBOLKey            = V_String2,
   @cTrackNo            = V_String3,
   @cTotalCarton        = V_String4,
   @cInvalidCarton      = V_String5,
   @cCurrentPage        = V_String6,
   @cTotalPage          = V_String7,

   @cExtendedInfoSP     = V_String11,
   @cExtendedInfo       = V_String12,
   @cExtendedUpdateSP   = V_String13,
   @cExtendedValidateSP = V_String14,
   @cPalletNotLinkMBOL  = V_String15,  
   @cPalletDetailTrackingNo  = V_String16,  

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
   @nStep_Start         INT,  
   @nStep_PalletID      INT,  @nScn_PalletID       INT,
   @nStep_Statistic     INT,  @nScn_Statistic      INT,
   @nStep_TrackNo       INT,  @nScn_TrackNo        INT,
   @nStep_RemoveCarton  INT,  @nScn_RemoveCarton   INT,
   @nStep_RemoveAll     INT,  @nScn_RemoveAll      INT

SELECT
   @nStep_PalletID      = 1,  @nScn_PalletID       = 5120,
   @nStep_Statistic     = 2,  @nScn_Statistic      = 5121,
   @nStep_TrackNo       = 3,  @nScn_TrackNo        = 5122,
   @nStep_RemoveCarton  = 4,  @nScn_RemoveCarton   = 5123, 
   @nStep_RemoveAll     = 5,  @nScn_RemoveAll      = 5124

-- Redirect to respective screen
IF @nFunc = 1665
BEGIN
   IF @nStep = 0 GOTO Step_Start        -- Menu. Func = 1665
   IF @nStep = 1 GOTO Step_PalletID     -- Scn = 5120 Pallet ID
   IF @nStep = 2 GOTO Step_Statistic    -- Scn = 5121 Statistic
   IF @nStep = 3 GOTO Step_TrackNo      -- Scn = 5122 Track No
   IF @nStep = 4 GOTO Step_RemoveCarton -- Scn = 5123 Remove carton?
   IF @nStep = 5 GOTO Step_RemoveAll    -- Scn = 5124 Remove all?
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu (func = 1665)
********************************************************************************/
Step_Start:
BEGIN
   -- Storer config
   SET @cPalletDetailTrackingNo = rdt.rdtGetConfig( @nFunc, 'PalletDetailTrackingNo', @cStorerKey)
   SET @cPalletNotLinkMBOL = rdt.rdtGetConfig( @nFunc, 'PalletNotLinkMBOL', @cStorerKey)
   
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''

   -- Prep next screen var
   SET @cOutField01 = ''

   -- Set the entry point
   SET @nScn = @nScn_PalletID
   SET @nStep = @nStep_PalletID
END
GOTO Quit


/********************************************************************************
Step 1. screen = 5120
   Pallet ID  (field01, input)
********************************************************************************/
Step_PalletID:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPalletKey = @cInField01

      -- Check blank
      IF @cPalletKey = ''
      BEGIN
         SET @nErrNo = 121451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need pallet
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         SET @nErrNo = 0
         SET @cErrMsg = ''
         GOTO Quit
      END

      -- Check format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'PalletKey', @cPalletKey) = 0
      BEGIN
         SET @nErrNo = 121452
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         SET @nErrNo = 0
         SET @cErrMsg = ''
         GOTO Quit
      END

      -- Pallet linkage to MBOL
      IF @cPalletNotLinkMBOL = '0' -- 0=link, 1=Not link
      BEGIN
         -- Get MBOL info
         SELECT 
            @cMBOLKey = MBOLKey, 
            @cChkStatus = Status, 
            @cChkFacility = Facility
         FROM MBOL WITH (NOLOCK)
         WHERE ExternMbolKey = @cPalletKey

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 121453
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Pallet
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            SET @nErrNo = 0
            SET @cErrMsg = ''
            GOTO Quit
         END

         -- Check MBOL status
         IF @cChkStatus = '9'
         BEGIN
            SET @nErrNo = 121454
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL shipped
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            SET @nErrNo = 0
            SET @cErrMsg = ''
            GOTO Quit
         END

         -- Check MBOL facility
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 121455
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL FAC Diff
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            SET @nErrNo = 0
            SET @cErrMsg = ''
            GOTO Quit
         END
      END

      -- Get pallet info
      SELECT
         @cChkStatus = Status, 
         @cChkStorerKey = StorerKey
      FROM Pallet WITH (NOLOCK)
      WHERE PalletKey = @cPalletKey
      
      -- Check storer 
      IF @cChkStorerKey <> @cStorerKey
      BEGIN
         SET @nErrNo = 121456
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PL Diff storer
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         SET @nErrNo = 0
         SET @cErrMsg = ''
         GOTO Quit
      END

      -- Get stat
      EXEC rdt.rdt_TrackNoPalletInquiry_GetList @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'STAT', 
         @cPalletKey,
         @cMBOLKey, 
         @cTrackNo,
         @cTotalCarton   = @cTotalCarton   OUTPUT, 
         @cInvalidCarton = @cInvalidCarton OUTPUT

      -- Prepare next screen var
      SET @cOutField01 = @cPalletKey
      SET @cOutField02 = @cInvalidCarton
      SET @cOutField03 = '' -- Option
      SET @cOutField04 = @cTotalCarton
   
      -- Go to track no screen
      SET @nScn = @nScn_Statistic
      SET @nStep = @nStep_Statistic
   END

   IF @nInputKey = 0 -- ESC
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
END
GOTO Quit


/********************************************************************************
Step 2. screen = 5121
   PalletKey      (Field01)
   Invalid carton (Field02)
   Option         (Field03, input)
   Total carton   (Field04)
********************************************************************************/
Step_Statistic:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField03
      
      -- Check valid option
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 121461
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         SET @nErrNo = 0
         SET @cErrMsg = ''
         GOTO Quit
      END
      
      -- Remove all
      IF @cOption = '1'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- Option

         -- Go to track no screen
         SET @nScn = @nScn_RemoveAll
         SET @nStep = @nStep_RemoveAll
         
         GOTO Quit
      END
      
      -- List track no
      IF @cOption = '2'
      BEGIN
         SET @cCurrentPage = '1'
         EXEC rdt.rdt_TrackNoPalletInquiry_GetList @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'LIST', 
            @cPalletKey,
            @cMBOLKey, 
            @cTrackNo,
            @cInvalidCarton = @cInvalidCarton OUTPUT, 
            @cOutField01    = @cOutField01    OUTPUT, 
            @cOutField02    = @cOutField02    OUTPUT, 
            @cOutField03    = @cOutField03    OUTPUT, 
            @cOutField04    = @cOutField04    OUTPUT, 
            @cOutField05    = @cOutField05    OUTPUT, 
            @cOutField06    = @cOutField06    OUTPUT, 
            @cOutField07    = @cOutField07    OUTPUT, 
            @cOutField08    = @cOutField08    OUTPUT, 
            @cOutField09    = @cOutField09    OUTPUT, 
            @cOutField10    = @cOutField10    OUTPUT, 
            @cCurrentPage   = @cCurrentPage   OUTPUT, 
            @cTotalPage     = @cTotalPage     OUTPUT, 
            @nErrNo         = @nErrNo         OUTPUT, 
            @cErrMsg        = @cErrMsg        OUTPUT
            
         -- Prepare next screen var
         SET @cOutField11 = '' -- TrackNo
         SET @cOutField12 = @cInvalidCarton
         SET @cOutField13 = @cCurrentPage + '/' + @cTotalPage

         -- Go to track no screen
         SET @nScn = @nScn_TrackNo
         SET @nStep = @nStep_TrackNo

         GOTO Quit
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- @cPalletKey

      -- Go to pallet ID screen
      SET @nScn = @nScn_PalletID
      SET @nStep = @nStep_PalletID
   END
END
GOTO Quit


/********************************************************************************
Step 3. screen = 5122
   TrackNo1...10  (Field01..10)
   TrackNo        (Field11, input)
   Total carton   (Field12)
   Page           (Field13)
********************************************************************************/
Step_TrackNo:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cTrackNo = @cInField11

      -- Check blank
      IF @cTrackNo = ''
      BEGIN
         IF CAST( @cCurrentPage AS INT) < CAST( @cTotalPage AS INT)
         BEGIN
            SET @cCurrentPage = CAST( @cCurrentPage AS INT) + 1
            EXEC rdt.rdt_TrackNoPalletInquiry_GetList @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'LIST', 
               @cPalletKey,
               @cMBOLKey, 
               @cTrackNo,
               @cInvalidCarton = @cInvalidCarton OUTPUT, 
               @cOutField01    = @cOutField01    OUTPUT, 
               @cOutField02    = @cOutField02    OUTPUT, 
               @cOutField03    = @cOutField03    OUTPUT, 
               @cOutField04    = @cOutField04    OUTPUT, 
               @cOutField05    = @cOutField05    OUTPUT, 
               @cOutField06    = @cOutField06    OUTPUT, 
               @cOutField07    = @cOutField07    OUTPUT, 
               @cOutField08    = @cOutField08    OUTPUT, 
               @cOutField09    = @cOutField09    OUTPUT, 
               @cOutField10    = @cOutField10    OUTPUT, 
               @cCurrentPage   = @cCurrentPage   OUTPUT, 
               @cTotalPage     = @cTotalPage     OUTPUT, 
               @nErrNo         = @nErrNo         OUTPUT, 
               @cErrMsg        = @cErrMsg        OUTPUT
               
            -- Prepare next screen var
            SET @cOutField11 = '' -- TrackNo
            SET @cOutField12 = @cInvalidCarton
            SET @cOutField13 = @cCurrentPage + '/' + @cTotalPage
         END
         ELSE
         BEGIN
            SET @nErrNo = 121457
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need TrackNo
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            SET @nErrNo = 0
            SET @cErrMsg = ''
         END
         GOTO Quit
      END

      -- Check trackno on pallet
      SET @nRowCount = 0
      IF @cPalletDetailTrackingNo = '1'
         SELECT @nRowCount = 1 FROM PalletDetail WITH (NOLOCK) WHERE PalletKey = @cPalletKey AND TrackingNo = @cTrackNo
      ELSE
         SELECT @nRowCount = 1 FROM PalletDetail WITH (NOLOCK) WHERE PalletKey = @cPalletKey AND CaseID = @cTrackNo
      
      IF @nRowCount <> 1
      BEGIN
         SET @nErrNo = 121458
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidTrackNo
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         SET @nErrNo = 0
         SET @cErrMsg = ''
         GOTO Quit
      END
      
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletKey, @cMBOLKey, @cTrackNo, @cOption, ' + 
               ' @tVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPalletKey      NVARCHAR( 20), ' + 
               '@cMBOLKey        NVARCHAR( 10), ' + 
               '@cTrackNo        NVARCHAR( 20), ' + 
               '@cOption         NVARCHAR( 1),  ' + 
               '@tVar            VariableTable  READONLY, ' + 
               '@nErrNo          INT            OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cPalletKey, @cMBOLKey, @cTrackNo, @cOption, 
               @tVar, @nErrNo OUTPUT, @cErrMsg OUTPUT 

            IF @nErrNo <> 0 
            BEGIN
               IF @nErrNo = -1 -- Warning
                  GOTO Quit
               ELSE
               BEGIN
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
                  GOTO Quit
               END
            END
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = @cTrackNo 
      SET @cOutField02 = '' -- ExtendedInfo
      SET @cOutField03 = '' -- OPTION

      -- Go to statistic screen
      SET @nScn = @nScn_RemoveCarton
      SET @nStep = @nStep_RemoveCarton

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +    
               ' @cPalletKey, @cMBOLKey, @cTrackNo, @cOption, ' + 
               ' @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nAfterStep      INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPalletKey      NVARCHAR( 20), ' + 
               '@cMBOLKey        NVARCHAR( 10), ' + 
               '@cTrackNo        NVARCHAR( 20), ' + 
               '@cOption         NVARCHAR( 1),  ' + 
               '@tVar            VariableTable  READONLY, ' + 
               '@cExtendedInfo   NVARCHAR( 20)  OUTPUT,   ' + 
               '@nErrNo          INT            OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_TrackNo, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cPalletKey, @cMBOLKey, @cTrackNo, @cOption, 
               @tVar, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 

            IF @nErrNo <> 0
               GOTO Quit
               
            IF @nStep = @nStep_RemoveCarton                      
               SET @cOutField02 = @cExtendedInfo
         END
      END

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF CAST( @cCurrentPage AS INT) > 1
      BEGIN
         SET @cCurrentPage = CAST( @cCurrentPage AS INT) - 1
         EXEC rdt.rdt_TrackNoPalletInquiry_GetList @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'LIST', 
            @cPalletKey,
            @cMBOLKey, 
            @cTrackNo,
            @cInvalidCarton = @cInvalidCarton OUTPUT, 
            @cOutField01    = @cOutField01    OUTPUT, 
            @cOutField02    = @cOutField02    OUTPUT, 
            @cOutField03    = @cOutField03    OUTPUT, 
            @cOutField04    = @cOutField04    OUTPUT, 
            @cOutField05    = @cOutField05    OUTPUT, 
            @cOutField06    = @cOutField06    OUTPUT, 
            @cOutField07    = @cOutField07    OUTPUT, 
            @cOutField08    = @cOutField08    OUTPUT, 
            @cOutField09    = @cOutField09    OUTPUT, 
            @cOutField10    = @cOutField10    OUTPUT, 
            @cCurrentPage   = @cCurrentPage   OUTPUT, 
            @cTotalPage     = @cTotalPage     OUTPUT, 
            @nErrNo         = @nErrNo         OUTPUT, 
            @cErrMsg        = @cErrMsg        OUTPUT
            
         -- Prepare next screen var
         SET @cOutField11 = '' -- TrackNo
         SET @cOutField12 = @cInvalidCarton
         SET @cOutField13 = @cCurrentPage + '/' + @cTotalPage
      END
      ELSE
      BEGIN
         -- Get stat
         EXEC rdt.rdt_TrackNoPalletInquiry_GetList @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'STAT', 
            @cPalletKey,
            @cMBOLKey, 
            @cTrackNo,
            @cTotalCarton   = @cTotalCarton   OUTPUT, 
            @cInvalidCarton = @cInvalidCarton OUTPUT
         
         -- Prepare next screen var
         SET @cOutField01 = @cPalletKey
         SET @cOutField02 = @cInvalidCarton
         SET @cOutField03 = '' -- Option
         SET @cOutField04 = @cTotalCarton

         -- Go to statistic screen
         SET @nScn = @nScn_Statistic
         SET @nStep = @nStep_Statistic
      END
   END
END
GOTO Quit


/********************************************************************************
Step 4. screen = 5123 Remove carton?
   TrackNo  (Field01)
   ExtInfo  (Field02)
   Option   (Field03, input)
********************************************************************************/
Step_RemoveCarton:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField03

      -- Check valid option
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 121459
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         SET @nErrNo = 0
         SET @cErrMsg = ''
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletKey, @cMBOLKey, @cTrackNo, @cOption, ' + 
               ' @tVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPalletKey      NVARCHAR( 20), ' + 
               '@cMBOLKey        NVARCHAR( 10), ' + 
               '@cTrackNo        NVARCHAR( 20), ' + 
               '@cOption         NVARCHAR( 1),  ' + 
               '@tVar            VariableTable  READONLY, ' + 
               '@nErrNo          INT            OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cPalletKey, @cMBOLKey, @cTrackNo, @cOption, 
               @tVar, @nErrNo OUTPUT, @cErrMsg OUTPUT 

            IF @nErrNo <> 0
            BEGIN
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
               GOTO Quit
            END
         END
      END

      IF @cOption = '1' -- Yes
      BEGIN
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdtfnc_TrackNoPalletInquiry -- For rollback or commit only our own transaction
   
         -- Remove carton
         EXEC rdt.rdt_TrackNoPalletInquiry_Delete @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cPalletKey,
            @cMBOLKey, 
            @cTrackNo,
            @nErrNo  OUTPUT, 
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN rdtfnc_TrackNoPalletInquiry
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            GOTO Quit
         END
   
         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
                  ' @cPalletKey, @cMBOLKey, @cTrackNo, @cOption, ' + 
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile         INT,           ' +
                  '@nFunc           INT,           ' +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,           ' +
                  '@nInputKey       INT,           ' +
                  '@cFacility       NVARCHAR( 5),  ' +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cPalletKey      NVARCHAR( 20), ' + 
                  '@cMBOLKey        NVARCHAR( 10), ' + 
                  '@cTrackNo        NVARCHAR( 20), ' + 
                  '@cOption         NVARCHAR( 1),  ' + 
                  '@tVar            VariableTable  READONLY, ' + 
                  '@nErrNo          INT            OUTPUT,   ' +
                  '@cErrMsg         NVARCHAR( 20)  OUTPUT    '
   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar, 
                  @cPalletKey, @cMBOLKey, @cTrackNo, @cOption, 
                  @nErrNo OUTPUT, @cErrMsg OUTPUT 
   
               IF @nErrNo <> 0
               BEGIN
                  ROLLBACK TRAN rdtfnc_TrackNoPalletInquiry
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
                  GOTO Quit
               END
            END
         END
   
         COMMIT TRAN rdtfnc_TrackNoPalletInquiry
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
      END
   END
   
   -- List track no
   EXEC rdt.rdt_TrackNoPalletInquiry_GetList @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'LIST', 
      @cPalletKey,
      @cMBOLKey, 
      @cTrackNo,
      @cInvalidCarton = @cInvalidCarton OUTPUT, 
      @cOutField01    = @cOutField01    OUTPUT, 
      @cOutField02    = @cOutField02    OUTPUT, 
      @cOutField03    = @cOutField03    OUTPUT, 
      @cOutField04    = @cOutField04    OUTPUT, 
      @cOutField05    = @cOutField05    OUTPUT, 
      @cOutField06    = @cOutField06    OUTPUT, 
      @cOutField07    = @cOutField07    OUTPUT, 
      @cOutField08    = @cOutField08    OUTPUT, 
      @cOutField09    = @cOutField09    OUTPUT, 
      @cOutField10    = @cOutField10    OUTPUT, 
      @cCurrentPage   = @cCurrentPage   OUTPUT, 
      @cTotalPage     = @cTotalPage     OUTPUT, 
      @nErrNo         = @nErrNo         OUTPUT, 
      @cErrMsg        = @cErrMsg        OUTPUT
      
   -- Prepare next screen var
   SET @cOutField11 = '' -- TrackNo
   SET @cOutField12 = @cInvalidCarton
   SET @cOutField13 = @cCurrentPage + '/' + @cTotalPage

   -- Go to track no screen
   SET @nScn = @nScn_TrackNo
   SET @nStep = @nStep_TrackNo
END
GOTO Quit


/********************************************************************************
Step 5. screen = 5124 Remove all carton?
   Option (Field01, input)
********************************************************************************/
Step_RemoveAll:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check valid option
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 121460
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         SET @nErrNo = 0
         SET @cErrMsg = ''
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletKey, @cMBOLKey, @cTrackNo, @cOption, ' + 
               ' @tVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPalletKey      NVARCHAR( 20), ' + 
               '@cMBOLKey        NVARCHAR( 10), ' + 
               '@cTrackNo        NVARCHAR( 20), ' + 
               '@cOption         NVARCHAR( 1),  ' + 
               '@tVar            VariableTable  READONLY, ' + 
               '@nErrNo          INT            OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cPalletKey, @cMBOLKey, @cTrackNo, @cOption, 
               @tVar, @nErrNo OUTPUT, @cErrMsg OUTPUT 

            IF @nErrNo <> 0
            BEGIN
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
               GOTO Quit
            END
         END
      END

      IF @cOption = '1' -- Yes
      BEGIN
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdtfnc_TrackNoPalletInquiry -- For rollback or commit only our own transaction
   
         -- Remove carton
         EXEC rdt.rdt_TrackNoPalletInquiry_DeleteAll @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cPalletKey,
            @cMBOLKey, 
            @cTrackNo,
            @nErrNo  OUTPUT, 
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN rdtfnc_TrackNoPalletInquiry
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            GOTO Quit
         END
   
         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cPalletKey, @cMBOLKey, @cTrackNo, @cOption, ' + 
                  ' @tVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile         INT,           ' +
                  '@nFunc           INT,           ' +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,           ' +
                  '@nInputKey       INT,           ' +
                  '@cFacility       NVARCHAR( 5),  ' +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cPalletKey      NVARCHAR( 20), ' + 
                  '@cMBOLKey        NVARCHAR( 10), ' + 
                  '@cTrackNo        NVARCHAR( 20), ' + 
                  '@cOption         NVARCHAR( 1),  ' + 
                  '@tVar            VariableTable  READONLY, ' + 
                  '@nErrNo          INT            OUTPUT,   ' +
                  '@cErrMsg         NVARCHAR( 20)  OUTPUT    '
   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
                  @cPalletKey, @cMBOLKey, @cTrackNo, @cOption, 
                  @tVar, @nErrNo OUTPUT, @cErrMsg OUTPUT 
   
               IF @nErrNo <> 0
               BEGIN
                  ROLLBACK TRAN rdtfnc_TrackNoPalletInquiry
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
                  GOTO Quit
               END
            END
         END
   
         COMMIT TRAN rdtfnc_TrackNoPalletInquiry
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
      END
   END
      
   -- Prepare next screen var
   SET @cOutField01 = '' -- @cPalletKey

   -- Go to pallet ID screen
   SET @nScn = @nScn_PalletID
   SET @nStep = @nStep_PalletID
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate   = GETDATE(),
      ErrMsg     = @cErrMsg,
      Func       = @nFunc,
      Step       = @nStep,
      Scn        = @nScn,

      V_String1  = @cPalletKey,
      V_String2  = @cMBOLKey,
      V_String3  = @cTrackNo,
      V_String4  = @cTotalCarton,
      V_String5  = @cInvalidCarton, 
      V_String6  = @cCurrentPage,
      V_String7  = @cTotalPage,

      V_String11 = @cExtendedInfoSP,
      V_String12 = @cExtendedInfo,
      V_String13 = @cExtendedUpdateSP,
      V_String14 = @cExtendedValidateSP,
      V_String15 = @cPalletNotLinkMBOL, 
      V_String16 = @cPalletDetailTrackingNo,

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