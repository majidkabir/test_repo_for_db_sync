SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_TrackNoToPallet                                    */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2017-06-07 1.0  Ung      WMS-2016 Migrated from TrackNoMBOL_Creation       */
/* 2017-08-15 1.1  Ung      WMS-2692                                          */
/*                          Add check PACK&HOLD order.                        */
/*                          Add Orders.SOStatus blocking in code lookup       */
/*                          Add Pallet LOC                                    */
/*                          Add Carton type barcode                           */
/*                          Change ExtendedValidateSP, ExtendedUpdateSP param */
/* 2017-10-16 1.2  Ung      Performance tuning (remove @tVar)                 */
/* 2017-11-01 1.3  Ung      WMS-3327 Add MaxTrackNoInPallet                   */
/* 2018-03-19 1.4  Ung      WMS-4304 Add Orders.PreSaleFlag                   */
/* 2018-08-27 1.5  Ung      WMS-6128 Add ExtendedUpdateSP @ pallet key screen */
/* 2018-10-08 1.6  James    Perfomance tuning. Remove isvalidqty during       */
/*                          loading rdtmobrec                                 */
/* 2018-10-15 1.7  James    WMS-6669 Add rdtformat @ screen 2 (james01)       */
/* 2018-10-02 1.8  Ung      WMS-6516 Add Orders.TrackingNo                    */
/*                          Add TrackNoOnOrder                                */
/*                          Add DecodeTrackNoSP                               */
/*                          Add SkipCheckPalletSameShipper                    */
/* 2018-10-02 1.9  Ung      INC0442606 Fix post CartonType field focus        */
/* 2018-11-01 2.0  Ung      WMS-6883 DecodeTrackNoSP output TrackNo           */
/* 2018-10-02 2.1  Ung      INC0442606 ReFix post CartonType field focus      */
/* 2019-04-24 2.2  James    WMS-8751 Add TrackOrderWeight with svalue 6 to    */
/*                          show weight screen (james02)                      */
/* 2019-07-16 2.3  Ung      Fix pallet closed                                 */
/* 2019-08-14 2.4  James    WMS-10127 Add custom sp to check sostatus(james03)*/
/* 2019-11-12 2.5  Shong    Set Remarks=ECOM when insert into MBOL            */
/* 2020-03-20 2.6  James    WMS-12486 Allow screen to accept track no as 40   */
/*                          chars and decode (james03)                        */
/* 2020-09-08 2.7  YeeKung  WMS-15056 Add Extendedvalidatesp(yeekung01)       */
/* 2023-05-08 2.8  Ung      WMS-22422 Add DefaultCartonTypeSP                 */
/* 2023-07-14 2.9  James    WMS-23121 Extend TrackingNo to 40 chars (james04) */
/******************************************************************************/

CREATE    PROC [RDT].[rdtfnc_TrackNoToPallet](
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
   @cSQL                NVARCHAR(MAX),
   @cSQLParam           NVARCHAR(MAX),
   @cOption             NVARCHAR(1),
   @cChkStorerKey       NVARCHAR(15),
   @cChkFacility        NVARCHAR(5),
   @cChkStatus          NVARCHAR(10),
   @cCartonTypeBarcode  NVARCHAR(30),
   @nTotalTrackNo       INT, 
   @tValidateSOStatus   VariableTable

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

   @cOrderKey           NVARCHAR(10),
   @cSKU                NVARCHAR(20),

   @cPalletKey          NVARCHAR(20),
   @cMBOLKey            NVARCHAR(10),
   @cTrackNo            NVARCHAR(40),
   @cWeight             NVARCHAR(10),
   @cCartonType         NVARCHAR(10),
   @cUseSequence        NVARCHAR(10),
   @cCube               NVARCHAR(10),
   @cShipperKey         NVARCHAR(15),
   @cFromStep           NVARCHAR(1),

   @cTrackCartonType    NVARCHAR(1),
   @cTrackOrderCube     NVARCHAR(1),
   @cTrackOrderWeight   NVARCHAR(1),
   @cTrackActualCarton  NVARCHAR(1),
   @cExtendedInfoSP     NVARCHAR(20),
   @cExtendedUpdateSP   NVARCHAR(20),
   @cExtendedValidateSP NVARCHAR(20),
   @cPalletLOC          NVARCHAR(10),
   @cClosePallet        NVARCHAR(1),
   @cMaxTrackNoInPallet NVARCHAR(5),
   @cTrackNoOnOrder     NVARCHAR(1),
   @cDecodeTrackNoSP    NVARCHAR(20),
   @cSkipCheckPalletSameShipper  NVARCHAR(1),
   @cSkipCheckPalletSamePresale  NVARCHAR(20),
   @cExtendedCheckSOStatusSP     NVARCHAR(20),
   @cDefaultCartonTypeSP         NVARCHAR(20),

   @cTrackNoBarcode     NVARCHAR( 60),

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

   @cOrderKey           = V_OrderKey,
   @cSKU                = V_SKU,

   @cPalletKey          = V_String1,
   @cMBOLKey            = V_String2,
   @cWeight             = V_String4,
   @cCartonType         = V_String5,
   @cUseSequence        = V_String6,
   @cCube               = V_String7,
   @cShipperKey         = V_String8,
   @cFromStep           = V_FromStep,

   @cTrackCartonType    = V_String21,
   @cTrackOrderCube     = V_String22,
   @cTrackOrderWeight   = V_String23,
   @cTrackActualCarton  = V_String24,
   @cExtendedInfoSP     = V_String25,
   @cExtendedUpdateSP   = V_String26,
   @cExtendedValidateSP = V_String27,
   @cPalletLOC          = V_String28,
   @cClosePallet        = V_String29,
   @cMaxTrackNoInPallet = V_String30,
   @cTrackNoOnOrder     = V_String31,
   @cDecodeTrackNoSP    = V_String32,
   @cSkipCheckPalletSameShipper  = V_String33,
   @cSkipCheckPalletSamePresale  = V_String34,
   @cExtendedCheckSOStatusSP     = V_String35,
   @cDefaultCartonTypeSP         = V_String36,
   
   @cTrackNoBarcode     = V_String41,
   @cTrackNo            = V_String42,
   
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
   @nStep_Start            INT,
   @nStep_PalletID         INT,  @nScn_PalletID       INT,
   @nStep_PreCartonType    INT,  @nScn_PreCartonType  INT,
   @nStep_TrackNo          INT,  @nScn_TrackNo        INT,
   @nStep_Weight           INT,  @nScn_Weight         INT,
   @nStep_PostCartonType   INT,  @nScn_PostCartonType INT,
   @nStep_ClosePallet      INT,  @nScn_ClosePallet    INT

SELECT
   @nStep_PalletID         = 1,  @nScn_PalletID       = 4930,
   @nStep_PreCartonType    = 2,  @nScn_PreCartonType  = 4931,
   @nStep_TrackNo          = 3,  @nScn_TrackNo        = 4932,
   @nStep_Weight           = 4,  @nScn_Weight         = 4933,
   @nStep_PostCartonType   = 5,  @nScn_PostCartonType = 4934,
   @nStep_ClosePallet      = 6,  @nScn_ClosePallet    = 4935


-- Redirect to respective screen
IF @nFunc = 1663
BEGIN
   IF @nStep = 0 GOTO Step_Start            -- Menu. Func = 1663
   IF @nStep = 1 GOTO Step_PalletID         -- Scn = 4930 Pallet ID
   IF @nStep = 2 GOTO Step_PreCartonType    -- Scn = 4931 Carton type
   IF @nStep = 3 GOTO Step_TrackNo          -- Scn = 4932 Track No
   IF @nStep = 4 GOTO Step_Weight           -- Scn = 4933 Weight
   IF @nStep = 5 GOTO Step_PostCartonType   -- Scn = 4934 CartonType, Act ctn
   IF @nStep = 6 GOTO Step_ClosePallet      -- Scn = 4935 Close pallet?
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu (func = 1663)
********************************************************************************/
Step_Start:
BEGIN
   -- Storer config
   SET @cClosePallet = rdt.rdtGetConfig( @nFunc, 'ClosePallet', @cStorerKey)
   SET @cDecodeTrackNoSP = rdt.rdtGetConfig( @nFunc, 'DecodeTrackNoSP', @cStorerKey)
   SET @cTrackActualCarton = rdt.rdtGetConfig( @nFunc, 'TrackActualCarton', @cStorerKey)
   SET @cTrackCartonType = rdt.rdtGetConfig( @nFunc, 'TrackCartonType', @cStorerKey)
   SET @cTrackOrderCube = rdt.RDTGetConfig( @nFunc, 'TrackOrderCube', @cStorerkey)
   SET @cTrackOrderWeight = rdt.rdtGetConfig( @nFunc, 'TrackOrderWeight', @cStorerKey)
   SET @cTrackNoOnOrder = rdt.rdtGetConfig( @nFunc, 'TrackNoOnOrder', @cStorerKey)
   SET @cSkipCheckPalletSameShipper = rdt.rdtGetConfig( @nFunc, 'SkipCheckPalletSameShipper', @cStorerKey)
   SET @cSkipCheckPalletSamePresale = rdt.rdtGetConfig( @nFunc, 'SkipCheckPalletSamePresale', @cStorerKey)

   SET @cDefaultCartonTypeSP = rdt.rdtGetConfig( @nFunc, 'DefaultCartonTypeSP', @cStorerKey)
   IF @cDefaultCartonTypeSP = '0'
      SET @cDefaultCartonTypeSP = ''
   SET @cExtendedCheckSOStatusSP = rdt.RDTGetConfig( @nFunc, 'ExtendedCheckSOStatusSP', @cStorerKey)
   IF @cExtendedCheckSOStatusSP = '0'
      SET @cExtendedCheckSOStatusSP = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cMaxTrackNoInPallet = rdt.rdtGetConfig( @nFunc, 'MaxTrackNoInPallet', @cStorerKey)
   IF rdt.rdtIsValidQTY( @cMaxTrackNoInPallet, 0) = 0
      SET @cMaxTrackNoInPallet = '0'
   SET @cPalletLOC = rdt.rdtGetConfig( @nFunc, 'PalletLOC', @cStorerKey)
   IF @cPalletLOC = '0'
      SET @cPalletLOC = ''

   -- Prep next screen var
   SET @cOutField01 = ''
   SET @cOutField02 = @cPalletLOC

   -- Set the entry point
   SET @nScn = @nScn_PalletID
   SET @nStep = @nStep_PalletID
END
GOTO Quit


/********************************************************************************
Step 1. screen = 4930
   Pallet ID  (field01, input)
   Pallet LOC (field02, input)
********************************************************************************/
Step_PalletID:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPalletKey = @cInField01
      SET @cPalletLOC = @cInField02

      -- Check blank
      IF @cPalletKey = ''
      BEGIN
         SET @nErrNo = 111251
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need pallet
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Check format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'PalletKey', @cPalletKey) = 0
      BEGIN
         SET @nErrNo = 111252
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Pallet
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END
      SET @cOutField01 = @cPalletKey

      -- Check pallet LOC
      IF @cPalletLOC = ''
      BEGIN
         SET @nErrNo = 111253
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PalletLOC
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      -- Get LOC info
      SELECT @cChkFacility = Facility
      FROM LOC WITH (NOLOCK)
      WHERE LOC = @cPalletLOC

      -- Check pallet LOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 111285
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      -- Check pallet LOC
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 111287
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Facility
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END
      SET @cOutField02 = @cPalletLOC

      -- Get MBOL info
      SELECT
         @cMBOLKey = MBOLKey,
         @cChkStatus = Status,
         @cChkFacility = Facility
      FROM MBOL WITH (NOLOCK)
      WHERE ExternMbolKey = @cPalletKey

      -- Create MBOL
      IF @@ROWCOUNT = 0
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
            SET @nErrNo = 111254
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            GOTO Quit
         END

         -- Insert MBOL
         --INSERT INTO MBOL (MBOLKey, ExternMBOLKey, Facility, Status) VALUES (@cMBOLKey, @cPalletKey, @cFacility, '0')
         INSERT INTO MBOL (MBOLKey, ExternMBOLKey, Facility, STATUS, Remarks) VALUES (@cMBOLKey, @cPalletKey, @cFacility, '0', 'ECOM')
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 111255
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBOL Fail
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         -- Check MBOL status
         IF @cChkStatus = '9'
         BEGIN
            SET @nErrNo = 111256
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL shipped
           EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            SET @nErrNo = 0
            SET @cErrMsg = ''
            GOTO Quit
         END

         -- Check MBOL facility
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 111257
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

      -- Create pallet
      IF @@ROWCOUNT = 0
      BEGIN
         INSERT INTO Pallet (PalletKey, StorerKey, Status)
         VALUES (@cPalletKey, @cStorerKey, '0')
       IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 111258
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PalletFail
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            SET @nErrNo = 0
            SET @cErrMsg = ''
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         -- Check pallet status
         IF @cChkStatus = '9'
         BEGIN
            SET @nErrNo = 111259
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet closed
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            SET @nErrNo = 0
            SET @cErrMsg = ''
            GOTO Quit
         END

         -- Check storer
         IF @cChkStorerKey <> @cStorerKey
         BEGIN
            SET @nErrNo = 111260
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PL Diff storer
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            SET @nErrNo = 0
            SET @cErrMsg = ''
            GOTO Quit
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''     --(yeekung01)
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption, ' +
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
               '@cPalletLOC      NVARCHAR( 10), ' +
               '@cMBOLKey        NVARCHAR( 10), ' +
               '@cTrackNo        NVARCHAR( 20), ' +
               '@cOrderKey       NVARCHAR( 10), ' +
               '@cShipperKey     NVARCHAR( 15), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo          INT            OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
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
               ' @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption, ' +
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
               '@cPalletLOC      NVARCHAR( 10), ' +
               '@cMBOLKey        NVARCHAR( 10), ' +
               '@cTrackNo        NVARCHAR( 20), ' +
               '@cOrderKey       NVARCHAR( 10), ' +
               '@cShipperKey     NVARCHAR( 15), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo          INT            OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      IF @cTrackCartonType = '2' --Pre carton type
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cPalletKey
         SET @cOutField02 = '' -- CartonType

         -- Go to carton type screen
         SET @nScn = @nScn_PreCartonType
         SET @nStep = @nStep_PreCartonType
      END
      ELSE
      BEGIN
         -- Get pallet info
         SELECT @nTotalTrackNo = COUNT( 1) FROM PalletDetail WITH (NOLOCK) WHERE PalletKey = @cPalletKey

         -- Prepare next screen var
         SET @cOutField01 = @cPalletKey
         SET @cOutField02 = @cMBOLKey
         SET @cOutField03 = '' -- TrackNo
         SET @cOutField04 = CAST( @nTotalTrackNo AS NVARCHAR(5))

         -- Go to track no screen
         SET @nScn = @nScn_TrackNo
         SET @nStep = @nStep_TrackNo
      END
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
         @cStorerKey  = @cStorerKey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Step 2. screen = 4931
   PalletKey  (Field01)
   CartonType (Field02, input)
********************************************************************************/
Step_PreCartonType:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cCartonType = LEFT( @cInField02, 10)
      SET @cCartonTypeBarcode = @cInField02

      -- Check blank
      IF @cCartonType = ''
      BEGIN
         SET @nErrNo = 111261
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedCartonType
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      -- Get carton type info
      SELECT
         @cUseSequence = UseSequence,
         @cCube = Cube
      FROM Cartonization C WITH (NOLOCK)
         JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)
      WHERE S.StorerKey = @cStorerKey
         AND C.CartonType = @cCartonType

      -- Check carton type valid
      IF @@ROWCOUNT = 0
      BEGIN
         SELECT
            @cCartonType = CartonType,
            @cUseSequence = UseSequence,
            @cCube = Cube
         FROM Cartonization C WITH (NOLOCK)
            JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)
         WHERE S.StorerKey = @cStorerKey
            AND C.Barcode = @cCartonTypeBarcode

         -- Check carton barcode
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 111262
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CartonType
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            EXEC rdt.rdtSetFocusField @nMobile, 2
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
               ' @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption, ' +
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
               '@cPalletLOC      NVARCHAR( 10), ' +
               '@cMBOLKey        NVARCHAR( 10), ' +
               '@cTrackNo        NVARCHAR( 20), ' +
               '@cOrderKey       NVARCHAR( 10), ' +
               '@cShipperKey     NVARCHAR( 15), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo          INT            OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
               GOTO Quit
            END
         END
      END

      -- Get pallet info
      SELECT @nTotalTrackNo = COUNT( 1) FROM PalletDetail WITH (NOLOCK) WHERE PalletKey = @cPalletKey

      -- Prepare next screen var
      SET @cOutField01 = @cPalletKey
      SET @cOutField02 = @cMBOLKey
      SET @cOutField03 = '' -- TrackNo
      SET @cOutField04 = CAST( @nTotalTrackNo AS NVARCHAR(5))

      SET @nScn = @nScn_TrackNo
      SET @nStep = @nStep_TrackNo
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @cClosePallet = '1'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- Option

         SET @cFromStep = @nStep_PreCartonType

         -- Go to close pallet screen
         SET @nScn = @nScn_ClosePallet
         SET @nStep = @nStep_ClosePallet
      END
      ELSE
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- @cPalletKey
         SET @cOutField02 = @cPalletLOC

         -- Go to pallet ID screen
         SET @nScn = @nScn_PalletID
         SET @nStep = @nStep_PalletID
      END
   END
END
GOTO Quit


/********************************************************************************
Step 3. screen = 4932
   Pallet   (Field01)
   MBOL     (Field02)
   Track no (Field03, input)
   Total    (Field04)
********************************************************************************/
Step_TrackNo:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cTrackNo = @cInField03
      SET @cTrackNoBarcode = @cInField03  -- (james03)

      -- Check blank
      IF @cTrackNo = ''
      BEGIN
         SET @nErrNo = 111263
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need TrackNo
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         GOTO Quit
      END

      -- Check format (james01)
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'TrackNo', @cTrackNoBarcode) = 0
      BEGIN
         SET @nErrNo = 111290
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Track#
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         GOTO Quit
      END

      SET @cOrderKey = ''

      -- Extended validate
      IF @cDecodeTrackNoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeTrackNoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeTrackNoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo OUTPUT, @cOrderKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPalletKey      NVARCHAR( 20), ' +
               '@cPalletLOC      NVARCHAR( 10), ' +
               '@cMBOLKey        NVARCHAR( 10), ' +
               '@cTrackNo        NVARCHAR( 60)  OUTPUT, ' +
               '@cOrderKey       NVARCHAR( 10)  OUTPUT, ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNoBarcode OUTPUT, @cOrderKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
               GOTO Quit
            END

            -- (james03)
            SET @cTrackNo = LEFT( @cTrackNoBarcode, 40)
         END
      END

      -- Get order
      IF @cOrderKey = ''
      BEGIN
         IF @cTrackNoOnOrder = '1'
            SELECT @cOrderKey = OrderKey FROM Orders WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND TrackingNo = @cTrackNo
         ELSE
            SELECT @cOrderKey = LabelNo FROM CartonTrack WITH (NOLOCK) WHERE TrackingNo = @cTrackNo

         -- Check track no valid
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 111264
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidTrackNo
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            GOTO Quit
         END
      END

      -- Check order
      IF @cOrderKey = ''
      BEGIN
         SET @nErrNo = 111265
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No order
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         GOTO Quit
      END

      -- Get order info
      DECLARE @cStatus NVARCHAR(10)
      DECLARE @cSOStatus NVARCHAR(10)
      DECLARE @cPreSaleFlag NVARCHAR(2)
      SELECT
         @cChkStorerKey = StorerKey,
         @cShipperKey = ShipperKey,
         @cStatus = Status,
         @cSOStatus = SOStatus,
         @cPreSaleFlag = ECOM_PRESALE_FLAG
      FROM dbo.Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      -- Check order valid
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 111266
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order NotFound
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         GOTO Quit
      END

      -- Check order status
      IF @cStatus < '5'
      BEGIN
         SET @nErrNo = 111267
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderNotPick
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         GOTO Quit
      END

      -- Extended validate sostatus
      IF @cExtendedCheckSOStatusSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedCheckSOStatusSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedCheckSOStatusSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption, ' +
               ' @cSOStatus, @tValidateSOStatus, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPalletKey      NVARCHAR( 20), ' +
               '@cPalletLOC      NVARCHAR( 10), ' +
               '@cMBOLKey        NVARCHAR( 10), ' +
               '@cTrackNo        NVARCHAR( 20), ' +
               '@cOrderKey       NVARCHAR( 10), ' +
               '@cShipperKey     NVARCHAR( 15), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cSOStatus       NVARCHAR( 10), ' +
               '@tValidateSOStatus VariableTable   READONLY, ' +
               '@nErrNo          INT               OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20)     OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption,
               @cSOStatus, @tValidateSOStatus, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
               GOTO Quit
            END
         END
      END
      ELSE
      BEGIN
         -- Check extern status
         IF @cSOStatus = 'HOLD'
         BEGIN
            SET @nErrNo = 111268
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order on HOLD
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            GOTO Quit
         END

         ELSE IF @cSOStatus = 'PENDPACK'
         BEGIN
            SET @nErrNo = 111269
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pending Update
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            GOTO Quit
         END

         ELSE IF @cSOStatus = 'PENDCANC'
         BEGIN
            SET @nErrNo = 111270
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pending CANC
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            GOTO Quit
         END

         IF @cSOStatus = 'CANC'
         BEGIN
            SET @nErrNo = 111271
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            GOTO Quit
         END

         IF @cSOStatus = 'PACK&HOLD'
         BEGIN
            SET @nErrNo = 111284
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderPACK&HOLD
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            GOTO Quit
         END

         -- Check SOStatus blocked
         IF EXISTS( SELECT TOP 1 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'SOSTSBLOCK' AND Code = @cSOStatus AND StorerKey = @cStorerKey AND Code2 = @nFunc)
         BEGIN
            SET @nErrNo = 111286
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Status blocked
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            GOTO Quit
         END
      END

      -- Check trackno scanned
      IF EXISTS( SELECT 1 FROM PalletDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND CaseID = @cTrackNo)
      BEGIN
         SET @nErrNo = 111272
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackNoScanned
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         GOTO Quit
      END

      -- Check order populated into MBOL
      IF EXISTS( SELECT 1 FROM MBOLDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND MBOLKey <> @cMBOLKey)
      BEGIN
         SET @nErrNo = 111273
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderInDiffPLT
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         GOTO Quit
      END

      -- Get random track no on pallet
      DECLARE @nRowCount   INT
      DECLARE @cChkOrderKey NVARCHAR(10)
      -- DECLARE @cChkTrackNo NVARCHAR(20)
      SELECT
         @cChkOrderKey = UserDefine01
         -- @cChkTrackNo = CaseID
      FROM PalletDetail WITH (NOLOCK)
      WHERE PalletKey = @cPalletKey

      SET @nRowCount = @@ROWCOUNT

      -- Pallet level checking
      IF @nRowCount > 0
      BEGIN
         -- Check max track no in pallet
         IF @cMaxTrackNoInPallet <> '0' AND  (@nRowCount + 1) > CAST( @cMaxTrackNoInPallet AS INT)
         BEGIN
            SET @nErrNo = 111288
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OverMaxTrackNo
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            GOTO Quit
         END

         /*
         -- Get OrderKey
         DECLARE @cChkOrderKey NVARCHAR(10)
         IF @cTrackNoOnOrder = '1'
            SELECT @cChkOrderKey = OrderKey FROM Orders WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND TrackingNo = @cChkTrackNo
         ELSE
            SELECT @cChkOrderKey = LabelNo FROM CartonTrack WITH (NOLOCK) WHERE TrackingNo = @cChkTrackNo
         */

         -- Get order info
         DECLARE @cChkShipperKey NVARCHAR(15)
         DECLARE @cChkPreSaleFlag NVARCHAR(2)
         SELECT
            @cChkShipperKey = ShipperKey,
            @cChkPreSaleFlag = ECOM_PRESALE_FLAG
         FROM Orders WITH (NOLOCK)
         WHERE OrderKey = @cChkOrderKey

         -- Check different ShipperKey
         IF @cSkipCheckPalletSameShipper <> '1'
         BEGIN
            IF @cChkShipperKey <> @cShipperKey
            BEGIN
               SET @nErrNo = 111274
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Carrier
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
               GOTO Quit
            END
         END

         -- Check different PreSaleFlag
         IF @cChkPreSaleFlag <> @cPreSaleFlag
         BEGIN
            IF @cSkipCheckPalletSamePresale <> '1'
            BEGIN
               SET @nErrNo = 111289
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff PreSale
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
               GOTO Quit
            END
         END
      END

      --Get SKU (random SKU in order)
      SET @cSKU = ''
      SELECT TOP 1
         @cSKU = SKU
      FROM PickDetail WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      --Check SKU
      IF @cSKU = ''
      BEGIN
         SET @nErrNo = 111275
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order no SKU
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption, ' +
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
               '@cPalletLOC      NVARCHAR( 10), ' +
               '@cMBOLKey        NVARCHAR( 10), ' +
               '@cTrackNo        NVARCHAR( 20), ' +
               '@cOrderKey       NVARCHAR( 10), ' +
               '@cShipperKey     NVARCHAR( 15), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo          INT            OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
               GOTO Quit
            END
         END
      END

      -- Track weight
      IF @cTrackOrderWeight IN ( '1', '6') -- (james02)
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- Weight

         -- Go to weight screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit
      END

      -- Track carton type
      IF @cTrackCartonType = '1'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = ''  -- Carton type
         SET @cOutField02 = ''  -- Act Carton
         SET @cOutField03 = '0' -- Scanned

         -- Track actual carton
         IF @cTrackActualCarton = '1'
         BEGIN
            SET @cOutField02 = '1' -- Act Carton
            SET @cFieldAttr02 = ''

            EXEC rdt.rdtSetFocusField @nMobile, 1 -- Carton type
         END
         ELSE
         BEGIN
            SET @cOutField02 = '' -- Act Carton
            SET @cFieldAttr02 = 'O'
         END

         -- Go to carton type screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2

         GOTO Quit
      END

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_TrackNoToPallet -- For rollback or commit only our own transaction

      -- Confirm
      EXEC rdt.rdt_TrackNoToPallet_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cPalletKey
         ,@cMBOLKey
         ,@cTrackNo
         ,@cOrderKey
         ,@cShipperKey
         ,@cCartonType
         ,@cWeight
         ,@cCube
         ,@cUseSequence
         ,@cTrackCartonType
         ,@cTrackOrderWeight
         ,@cTrackOrderCube
         ,@cPalletLOC
         ,@cSKU
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdtfnc_TrackNoToPallet
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
               ' @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption, ' +
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
               '@cPalletLOC      NVARCHAR( 10), ' +
               '@cMBOLKey        NVARCHAR( 10), ' +
               '@cTrackNo        NVARCHAR( 20), ' +
               '@cOrderKey       NVARCHAR( 10), ' +
               '@cShipperKey     NVARCHAR( 15), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo          INT            OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_TrackNoToPallet
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
               GOTO Quit
            END
         END
      END

      COMMIT TRAN rdt_Pack_Confirm
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Get pallet info
      SELECT @nTotalTrackNo = COUNT( 1) FROM PalletDetail WITH (NOLOCK) WHERE PalletKey = @cPalletKey

      -- Prepare next screen var
      SET @cOutField01 = @cPalletKey
      SET @cOutField02 = @cMBOLKey
      SET @cOutField03 = '' -- TrackNo
      SET @cOutField04 = CAST( @nTotalTrackNo AS NVARCHAR(5))
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @cTrackCartonType = '2' --Pre carton type
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cPalletKey
         SET @cOutField02 = '' -- CartonType

         -- Go to carton type screen
         SET @nScn = @nScn_PreCartonType
         SET @nStep = @nStep_PreCartonType
      END

      ELSE IF @cClosePallet = '1'
      BEGIN
         -- Prepare next screen var
       SET @cOutField01 = '' -- Option

         SET @cFromStep = @nStep_TrackNo

         -- Go to close pallet screen
         SET @nScn = @nScn_ClosePallet
         SET @nStep = @nStep_ClosePallet
      END
      ELSE
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- PalletKey
         SET @cOutField02 = @cPalletLOC

         -- Go to pallet ID screen
         SET @nScn = @nScn_PalletID
         SET @nStep = @nStep_PalletID
      END
   END
END
GOTO Quit


/********************************************************************************
Step 4. screen = 4933
   Weight (Field01, input)
********************************************************************************/
Step_Weight:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cWeight = @cInField01

      -- Check format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'Weight', @cWeight) = 0
      BEGIN
         SET @nErrNo = 111276
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Weight
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Check valid
      IF rdt.rdtIsValidQTY( @cWeight, 21) = 0
      BEGIN
         SET @nErrNo = 111277
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Weight
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption, ' +
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
               '@cPalletLOC      NVARCHAR( 10), ' +
               '@cMBOLKey        NVARCHAR( 10), ' +
               '@cTrackNo        NVARCHAR( 20), ' +
               '@cOrderKey       NVARCHAR( 10), ' +
               '@cShipperKey     NVARCHAR( 15), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo          INT            OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
               GOTO Quit
            END
         END
      END

      -- Track carton type
      IF @cTrackCartonType = '1'
      BEGIN
         -- Default carton type
         DECLARE @cDefaultCartonType NVARCHAR( 10) = ''
         IF @cDefaultCartonTypeSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDefaultCartonTypeSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDefaultCartonTypeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cWeight, @cOption, ' +
                  ' @cDefaultCartonType OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile         INT,           ' +
                  '@nFunc           INT,           ' +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,           ' +
                  '@nInputKey       INT,           ' +
                  '@cFacility       NVARCHAR( 5),  ' +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cPalletKey      NVARCHAR( 20), ' +
                  '@cPalletLOC      NVARCHAR( 10), ' +
                  '@cMBOLKey        NVARCHAR( 10), ' +
                  '@cTrackNo        NVARCHAR( 20), ' +
                  '@cOrderKey       NVARCHAR( 10), ' +
                  '@cShipperKey     NVARCHAR( 15), ' +
                  '@cWeight         NVARCHAR( 10), ' +
                  '@cOption         NVARCHAR( 1),  ' +
                  '@cDefaultCartonType NVARCHAR( 10)  OUTPUT, ' +
                  '@nErrNo             INT            OUTPUT, ' +
                  '@cErrMsg            NVARCHAR( 20)  OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cWeight, @cOption,
                  @cDefaultCartonType OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
            END
            ELSE
               SET @cDefaultCartonType = @cDefaultCartonTypeSP
         END
         
         -- Prepare next screen var
         SET @cOutField01 = @cDefaultCartonType  -- Carton type
         SET @cOutField02 = ''  -- Act Carton
         SET @cOutField03 = '0' -- Scanned

         -- Track actual carton
         IF @cTrackActualCarton = '1'
         BEGIN
            SET @cOutField02 = '1'
            SET @cFieldAttr02 = ''

            EXEC rdt.rdtSetFocusField @nMobile, 1 -- Carton type
         END
         ELSE
         BEGIN
            SET @cOutField02 = ''
            SET @cFieldAttr02 = 'O'
         END

         -- Go to carton type screen
         SET @nScn = @nScn_PostCartonType
         SET @nStep = @nStep_PostCartonType

         GOTO Quit
      END

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_TrackNoToPallet -- For rollback or commit only our own transaction

      -- Confirm
      EXEC rdt.rdt_TrackNoToPallet_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cPalletKey
         ,@cMBOLKey
         ,@cTrackNo
         ,@cOrderKey
         ,@cShipperKey
         ,@cCartonType
         ,@cWeight
         ,@cCube
         ,@cUseSequence
         ,@cTrackCartonType
         ,@cTrackOrderWeight
         ,@cTrackOrderCube
         ,@cPalletLOC
         ,@cSKU
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdtfnc_TrackNoToPallet
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
               ' @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption, ' +
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
               '@cPalletLOC      NVARCHAR( 10), ' +
               '@cMBOLKey        NVARCHAR( 10), ' +
               '@cTrackNo        NVARCHAR( 20), ' +
               '@cOrderKey       NVARCHAR( 10), ' +
               '@cShipperKey     NVARCHAR( 15), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo          INT            OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_TrackNoToPallet
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
               GOTO Quit
            END
         END
      END

      COMMIT TRAN rdt_Pack_Confirm
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Get pallet info
      SELECT @nTotalTrackNo = COUNT( 1) FROM PalletDetail WITH (NOLOCK) WHERE PalletKey = @cPalletKey

      -- Prepare next screen var
      SET @cOutField01 = @cPalletKey
      SET @cOutField02 = @cMBOLKey
      SET @cOutField03 = '' -- TrackNo
      SET @cOutField04 = CAST( @nTotalTrackNo AS NVARCHAR(5))

      SET @nScn = @nScn_TrackNo
      SET @nStep = @nStep_TrackNo
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Get pallet info
      SELECT @nTotalTrackNo = COUNT( 1) FROM PalletDetail WITH (NOLOCK) WHERE PalletKey = @cPalletKey

      -- Prepare next screen var
      SET @cOutField01 = @cPalletKey
      SET @cOutField02 = @cMBOLKey
      SET @cOutField03 = '' -- TrackNo
      SET @cOutField04 = CAST( @nTotalTrackNo AS NVARCHAR(5))

      SET @nScn = @nScn_TrackNo
      SET @nStep = @nStep_TrackNo
   END
END
GOTO Quit


/********************************************************************************
Step 5. screen = 4934
   CartonType (Field01, input)
********************************************************************************/
Step_PostCartonType:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cActCTN  NVARCHAR(5)
      DECLARE @cScanned NVARCHAR(5)

      -- Screen mapping
      SET @cCartonType = LEFT( @cInField01, 10)
      SET @cCartonTypeBarcode = @cInField01
      SET @cActCTN = CASE WHEN @cFieldAttr02 = 'O' THEN @cOutField02 ELSE @cInField02 END
      SET @cScanned = @cOutField03

      -- Check blank
      IF @cCartonType = ''
      BEGIN
         SET @nErrNo = 111278
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedCartonType
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      -- Get carton type info
      SELECT
         @cUseSequence = UseSequence,
         @cCube = Cube
      FROM Cartonization C WITH (NOLOCK)
         JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)
      WHERE S.StorerKey = @cStorerKey
         AND C.CartonType = @cCartonType

      -- Check carton type valid
      IF @@ROWCOUNT = 0
      BEGIN
         SELECT
            @cCartonType = CartonType,
            @cUseSequence = UseSequence,
            @cCube = Cube
         FROM Cartonization C WITH (NOLOCK)
            JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)
         WHERE S.StorerKey = @cStorerKey
            AND C.Barcode = @cCartonTypeBarcode

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 111279
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CartonType
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END
      END

      -- Check actual carton valid
      IF @cFieldAttr02 = ''
      BEGIN
         IF rdt.rdtIsValidQTY( @cActCTN, 0) = 0
         BEGIN
            SET @nErrNo = 111280
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CartonType
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END
      END
      SET @cOutField02 = @cActCTN

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPalletKey      NVARCHAR( 20), ' +
               '@cPalletLOC      NVARCHAR( 10), ' +
               '@cMBOLKey        NVARCHAR( 10), ' +
               '@cTrackNo        NVARCHAR( 20), ' +
               '@cOrderKey       NVARCHAR( 10), ' +
               '@cShipperKey     NVARCHAR( 15), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo          INT            OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
               GOTO Quit
            END
         END
      END

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_TrackNoToPallet -- For rollback or commit only our own transaction

      -- Confirm
      EXEC rdt.rdt_TrackNoToPallet_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cPalletKey
         ,@cMBOLKey
         ,@cTrackNo
         ,@cOrderKey
         ,@cShipperKey
         ,@cCartonType
         ,@cWeight
         ,@cCube
         ,@cUseSequence
         ,@cTrackCartonType
         ,@cTrackOrderWeight
         ,@cTrackOrderCube
         ,@cPalletLOC
         ,@cSKU
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdtfnc_TrackNoToPallet
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
               ' @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption, ' +
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
               '@cPalletLOC      NVARCHAR( 10), ' +
               '@cMBOLKey        NVARCHAR( 10), ' +
               '@cTrackNo        NVARCHAR( 20), ' +
               '@cOrderKey       NVARCHAR( 10), ' +
               '@cShipperKey     NVARCHAR( 15), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo          INT            OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
         @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_TrackNoToPallet
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
               GOTO Quit
            END
         END
      END

      COMMIT TRAN rdt_Pack_Confirm
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Top up
      SET @cScanned = CAST( CAST( @cScanned AS INT) + 1 AS NVARCHAR(5))

      -- Check actual carton matched scanned
      IF @cTrackActualCarton = '1'
      BEGIN
         IF @cScanned <> @cActCTN
         BEGIN
            SET @cOutField01 = '' -- CartonType
            SET @cOutField03 = @cScanned

            EXEC rdt.rdtSetFocusField @nMobile, 1 -- CartonType

            GOTO Quit
         END
      END

      -- Get pallet info
      SELECT @nTotalTrackNo = COUNT( 1) FROM PalletDetail WITH (NOLOCK) WHERE PalletKey = @cPalletKey

      -- Prepare next screen var
      SET @cOutField01 = @cPalletKey
      SET @cOutField02 = @cMBOLKey
      SET @cOutField03 = '' -- TrackNo
      SET @cOutField04 = CAST( @nTotalTrackNo AS NVARCHAR(5))

      SET @cFieldAttr02 = '' -- Actual carton

      SET @nScn = @nScn_TrackNo
      SET @nStep = @nStep_TrackNo
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Get pallet info
      SELECT @nTotalTrackNo = COUNT( 1) FROM PalletDetail WITH (NOLOCK) WHERE PalletKey = @cPalletKey

      -- Prepare next screen var
      SET @cOutField01 = @cPalletKey
      SET @cOutField02 = @cMBOLKey
      SET @cOutField03 = '' -- TrackNo
      SET @cOutField04 = CAST( @nTotalTrackNo AS NVARCHAR(5))

      SET @cFieldAttr02 = '' -- Actual carton

      SET @nScn = @nScn_TrackNo
      SET @nStep = @nStep_TrackNo
   END
END
GOTO Quit


/********************************************************************************
Step 6. screen = 4935 Close pallet?
   Option (Field01, input)
********************************************************************************/
Step_ClosePallet:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check valid option
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 111281
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption, ' +
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
               '@cPalletLOC      NVARCHAR( 10), ' +
               '@cMBOLKey        NVARCHAR( 10), ' +
               '@cTrackNo        NVARCHAR( 20), ' +
               '@cOrderKey       NVARCHAR( 10), ' +
               '@cShipperKey     NVARCHAR( 15), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo          INT            OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               IF @nErrNo <> 1   -- Msgqueue not displayed in ExtendedValidateSP before
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
               GOTO Quit
            END
         END
      END

      IF @cOption = '1' -- Yes
      BEGIN
         -- Check pallet closed (temporary workaround, instead of changing ntrPalletHeaderUpdate trigger)
         IF EXISTS( SELECT 1 FROM Pallet WITH (NOLOCK) WHERE PalletKey = @cPalletKey AND Status = '9')
         BEGIN
            SET @nErrNo = 111291
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet closed
            GOTO Quit
         END

         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdtfnc_TrackNoToPallet -- For rollback or commit only our own transaction

         -- Close pallet
         UPDATE Pallet SET
            Status = '9',
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE()
         WHERE PalletKey = @cPalletKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 111282
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PalletFail
            GOTO Quit
         END

         -- Submit for MBOL validation (backend job)
         UPDATE MBOL SET
            Status = '5',
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE(),
            TrafficCop = NULL
         WHERE MBOLKey = @cMBOLKey
            AND Status = '0'
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 111283
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD MBOL Fail
            GOTO Quit
         END

         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption, ' +
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
                  '@cPalletLOC      NVARCHAR( 10), ' +
                  '@cMBOLKey        NVARCHAR( 10), ' +
                  '@cTrackNo        NVARCHAR( 20), ' +
                  '@cOrderKey       NVARCHAR( 10), ' +
                  '@cShipperKey     NVARCHAR( 15), ' +
                  '@cCartonType     NVARCHAR( 10), ' +
                  '@cWeight         NVARCHAR( 10), ' +
                  '@cOption         NVARCHAR( 1),  ' +
                  '@nErrNo          INT            OUTPUT,   ' +
                  '@cErrMsg         NVARCHAR( 20)  OUTPUT    '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption,
                  @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  ROLLBACK TRAN rdtfnc_TrackNoToPallet
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
                  GOTO Quit
               END
            END
         END

         COMMIT TRAN rdt_Pack_Confirm
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
      END

      -- Prepare next screen var
      SET @cOutField01 = '' -- PalletKey
      SET @cOutField02 = @cPalletLOC

      -- Go to pallet ID screen
      SET @nScn = @nScn_PalletID
      SET @nStep = @nStep_PalletID
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Go to track no screen
      IF @cFromStep = @nStep_TrackNo
      BEGIN
         -- Get pallet info
         SELECT @nTotalTrackNo = COUNT( 1) FROM PalletDetail WITH (NOLOCK) WHERE PalletKey = @cPalletKey

         -- Prepare next screen var
         SET @cOutField01 = @cPalletKey
         SET @cOutField02 = @cMBOLKey
         SET @cOutField03 = '' -- TrackNo
         SET @cOutField04 = CAST( @nTotalTrackNo AS NVARCHAR(5))

         SET @nScn = @nScn_TrackNo
         SET @nStep = @nStep_TrackNo
      END

      -- Go to pre carton type screen
      IF @cFromStep = @nStep_PreCartonType
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cPalletKey
         SET @cOutField02 = '' -- Pre carton type

         SET @nScn = @nScn_PreCartonType
         SET @nStep = @nStep_PreCartonType
      END
   END
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

      V_OrderKey = @cOrderKey,
      V_SKU      = @cSKU,

      V_String1  = @cPalletKey,
      V_String2  = @cMBOLKey,
      V_String4  = @cWeight,
      V_String5  = @cCartonType,
      V_String6  = @cUseSequence,
      V_String7  = @cCube,
      V_String8  = @cShipperKey,
      V_FromStep = @cFromStep,

      V_String21 = @cTrackCartonType,
      V_String22 = @cTrackOrderCube,
      V_String23 = @cTrackOrderWeight,
      V_String24 = @cTrackActualCarton,
      V_String25 = @cExtendedInfoSP,
      V_String26 = @cExtendedUpdateSP,
      V_String27 = @cExtendedValidateSP,
      V_String28 = @cPalletLOC,
      V_String29 = @cClosePallet,
      V_String30 = @cMaxTrackNoInPallet,
      V_String31 = @cTrackNoOnOrder,
      V_String32 = @cDecodeTrackNoSP,
      V_String33 = @cSkipCheckPalletSameShipper,
      V_String34 = @cExtendedCheckSOStatusSP,
      V_String35 = @cSkipCheckPalletSamePresale,
      V_String36 = @cDefaultCartonTypeSP,
      
      V_String41 = @cTrackNoBarcode,
      V_String42 = @cTrackNo,
      
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