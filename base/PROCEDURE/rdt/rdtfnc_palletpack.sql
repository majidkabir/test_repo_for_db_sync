SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdtfnc_PalletPack                                      */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose: Pallet packing. Scan carton count/ucc/sku/qty                  */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Rev  Author   Purposes                                     */
/* 2019-04-22   1.0  James    WMS8709. Created                             */
/* 2019-07-18   1.1  James    Fix ext validate param mismatch (james01)    */
/* 2021-06-03   1.2  James    WMS-17164 Cater pack for UCC (james02)       */
/* 2021-06-29   1.3  James    Add set focus when go back step2 (james03)   */
/* 2021-09-07   1.4  James    WMS17874-Add capture packinfo (james04)      */
/***************************************************************************/

CREATE PROC [RDT].[rdtfnc_PalletPack](
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE 
   @cSQL           NVARCHAR(MAX), 
   @cSQLParam      NVARCHAR(MAX), 
   @nCnt           INT, 
   @cReport        NVARCHAR( 20),
   @curLabelReport CURSOR

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

   @cSKU                NVARCHAR( 20), 
   @cSKUDescr           NVARCHAR( 60), 
   @cDecodeSP           NVARCHAR( 20), 
   @cPickSlipNo         NVARCHAR( 10), 
   @cDropID             NVARCHAR( 20), 
   @cCaseID             NVARCHAR( 20), 
   @cSerialNo           NVARCHAR( 50), 
   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cMax                NVARCHAR( MAX), 
   @cBarcode            NVARCHAR( Max), 
   @cSrSerialNo         NVARCHAR( Max), 
   @cUPC                NVARCHAR( 30),
   @cTemp_UPC           NVARCHAR( 30),
   @cTemp_DropID        NVARCHAR( 20), 
   @cTemp_CaseID        NVARCHAR( 20), 
   @cUserDefine01       NVARCHAR( 60), 
   @cUserDefine02       NVARCHAR( 60), 
   @cClosePallet        NVARCHAR( 1), 
   @cPrintManifest      NVARCHAR( 1), 
   @cOption             NVARCHAR( 1), 
   @cDelNotes           NVARCHAR( 10), 
   @nSKUCnt             INT,
   @bSuccess            INT,
   @cErrType            nvarchar( 20),
   @cWaveKey            nvarchar( 10),
   @cPalletID           NVARCHAR( 20),
   @cUCC                NVARCHAR( 20),
   @cQty                NVARCHAR( 5),
   @cPackOption         NVARCHAR( 1),
   @cOrderKey           NVARCHAR( 10),
   @cLoadKey            NVARCHAR( 10),
   @cPickConfirmStatus  NVARCHAR( 1),
   @cCartonCount        NVARCHAR( 5),
   @cPackByPickDetailDropID   NVARCHAR( 1),
   @cPackByPickDetailID       NVARCHAR( 1),
   @cCartonCountCfg     NVARCHAR( 1),
   @cPallet             NVARCHAR( 5),
   @cPackKey            NVARCHAR( 10),
   @cPackList           NVARCHAR( 10),
   @cShipLabel          NVARCHAR( 10),
   @cCartonManifest     NVARCHAR( 10),
   @cDocLabel           NVARCHAR( 20),
   @cDocValue           NVARCHAR( 20),
   @cPltLabel           NVARCHAR( 20),
   @cPltValue           NVARCHAR( 20),
   @nIDCtnCount         INT,
   @fPallet             FLOAT,
   @tExtValidate        VariableTable, 
   @tExtUpdate          VariableTable, 
   @tExtInfo            VariableTable, 
   @tPackCfm            VariableTable, 
   @tPackList           VariableTable,
   @tPackInfo           VariableTable,
   @cPrintPackList      NVARCHAR( 1),
   @nCartonValidated    INT,
   @nUCCCount           INT,
   @nTranCount          INT,
   @cCapturePackInfoSP  NVARCHAR( 20),
   @cPackInfo           NVARCHAR( 10),   
   @cCartonType         NVARCHAR( 10),  
   @cCube               NVARCHAR( 10),  
   @cWeight             NVARCHAR( 10),  
   @cRefNo              NVARCHAR( 20),  
   @cLength             NVARCHAR( 10), 
   @cWidth              NVARCHAR( 10), 
   @cHeight             NVARCHAR( 10), 
   @cDefaultCartonType  NVARCHAR( 20), 
   @cAllowWeightZero    NVARCHAR( 1),  
   @cAllowCubeZero      NVARCHAR( 1),  
   @cAllowLengthZero    NVARCHAR( 1),  
   @cAllowWidthZero     NVARCHAR( 1),  
   @cAllowHeightZero    NVARCHAR( 1),  
   
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

   @cWaveKey         = V_WaveKey,
   @cUCC             = V_UCC,
   @cPickSlipNo      = V_PickSlipNo,
   @cSKU             = V_SKU,
   @cSKUDescr        = V_SKUDescr,
   @cCaseID          = V_CaseID, 
   @cPalletID        = V_Dropid,
   @cMax             = V_Max,

   @cExtendedUpdateSP   = V_String1,
   @cExtendedValidateSP = V_String2,
   @cExtendedInfoSP     = V_String3,
   @cClosePallet        = V_String4,
   @cPrintManifest      = V_String5,
   @cPackOption         = V_String6,
   @cPickConfirmStatus  = V_String7,
   @cPackByPickDetailDropID = V_String8,
   @cPackByPickDetailID     = V_String9,
   @cDocLabel           = V_String10,
   @cDocValue           = V_String11,
   @cPltLabel           = V_String12,
   @cPltValue           = V_String13,
   @cCartonCountCfg     = V_String14,
   @nCartonValidated    = V_String15,
   @cCapturePackInfoSP  = V_String16,
   @cPackInfo           = V_String17,  
   @cCartonType         = V_String18,  
   @cCube               = V_String19,  
   @cWeight             = V_String20,  
   @cRefNo              = V_String21,  
   @cLength             = V_String22, 
   @cWidth              = V_String23, 
   @cHeight             = V_String24, 
   @cDefaultCartonType  = V_String25,
   @cAllowWeightZero    = V_String26,  
   @cAllowCubeZero      = V_String27,  
   @cAllowLengthZero    = V_String28,
   @cAllowWidthZero     = V_String29,
   @cAllowHeightZero    = V_String30,
   
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
   @nStep_Doc           INT,  @nScn_Doc            INT,
   @nStep_PalletID      INT,  @nScn_PalletID       INT,
   @nStep_PrintPackList INT,  @nScn_PrintPackList  INT,
   @nStep_PackInfo      INT,  @nScn_PackInfo       INT

SELECT
   @nStep_Doc           = 1,  @nScn_Doc            = 5400,
   @nStep_PalletID      = 2,  @nScn_PalletID       = 5401,
   @nStep_PrintPackList = 3,  @nScn_PrintPackList  = 5402,
   @nStep_PackInfo      = 4,  @nScn_PackInfo       = 5403
  

IF @nFunc = 835
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start         -- Menu. Func = 835
   IF @nStep = 1  GOTO Step_Doc           -- Scn = 5400. Input Doc
   IF @nStep = 2  GOTO Step_PalletID      -- Scn = 5401. Pallet id
   IF @nStep = 3  GOTO Step_PrintPackList -- Scn = 5402. Print packing list
   IF @nStep = 4  GOTO Step_PackInfo      -- Scn = 5403. Packinfo
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 835
********************************************************************************/
Step_Start:
BEGIN
   -- Get storer config
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'  
      SET @cExtendedValidateSP = ''

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'  
      SET @cExtendedUpdateSP = ''

   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   SET @cPackByPickDetailDropID = rdt.RDTGetConfig( @nFunc, 'PackByPickDetailDropID', @cStorerKey)
   IF @cPackByPickDetailDropID = '0'
      SET @cPackByPickDetailID = '1'
   ELSE
      SET @cPackByPickDetailID = '0'

   SET @cCartonCountCfg = rdt.RDTGetConfig( @nFunc, 'CartonCountCfg', @cStorerKey)

   SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PackList', @cStorerKey)
   IF @cPackList = '0'
      SET @cPackList = ''

   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
   IF @cShipLabel = '0'
      SET @cShipLabel = ''

   SET @cCapturePackInfoSP = rdt.RDTGetConfig( @nFunc, 'CapturePackInfoSP', @cStorerKey)
   IF @cCapturePackInfoSP = '0'
      SET @cCapturePackInfoSP = ''

   SET @cDefaultCartonType = rdt.RDTGetConfig( @nFunc, 'DefaultCartonType', @cStorerKey)
   IF @cDefaultCartonType = '0'    
      SET @cDefaultCartonType = ''   

   -- Prepare next screen var
   SET @cOutField01 = '' 

   -- Initialise variable
   SET @cDocLabel = ''
   SET @cDocValue = ''

   SELECT @cDocLabel = Long
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE ListName = 'PalletPack'
   AND   Code = 'Doc'
   AND   StorerKey = @cStorerKey
   AND   code2 = @nFunc

   -- Initialise variable
   SET @cPickSlipNo = ''
   SET @cPalletID = ''
   SET @cUCC = ''
   SET @cSKU = ''
   SET @cQty = ''
   SET @cPackOption = ''
   SET @nCartonValidated = 0

   IF ISNULL( @cDocLabel, '') <> ''
   BEGIN
      SET @cOutField01 = @cDocLabel + ':'
      
      -- Go to next screen
      SET @nScn = @nScn_Doc
      SET @nStep = @nStep_Doc
   END
   ELSE
   BEGIN
      SET @cPltLabel = ''
      SET @cPltValue = ''

      SELECT @cPltLabel = Long
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE ListName = 'PalletPack'
      AND   Code = 'PalletID'
      AND   StorerKey = @cStorerKey
      AND   code2 = @nFunc

      IF ISNULL( @cPltLabel, '') <> ''
      BEGIN
         SET @cOutField01 = @cPltLabel + ': '
      END
      ELSE
      BEGIN
         -- Default use Pallet ID packing
         SET @cOutField01 = 'Pallet ID :'
      END

      -- Prepare next screen var
      SET @cOutField02 = ''

      -- Go to next screen
      SET @nScn = @nScn_PalletID
      SET @nStep = @nStep_PalletID
   END

   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType     = '1', -- Sign-in
      @cUserID         = @cUserName,
      @nMobileNo       = @nMobile,
      @nFunctionID     = @nFunc,
      @cFacility       = @cFacility,
      @cStorerKey      = @cStorerKey,
      @nStep           = @nStep
END
GOTO Quit

/************************************************************************************
Scn = 5400. Doc input
   Pickslip No   (field01, input)
************************************************************************************/
Step_Doc:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cDocValue = @cInField02

      -- Check blank
      IF ISNULL( @cDocValue, '') = ''
      BEGIN
         SET @nErrNo = 137101
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Value req
         GOTO Step_Doc_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         INSERT INTO @tExtValidate (Variable, Value) VALUES 
         ('@cDocLabel',       @cDocLabel),
         ('@cDocValue',       @cDocValue)

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
            GOTO Step_Doc_Fail
      END

      SET @cPltLabel = ''
      SET @cPltValue = ''

      SELECT @cPltLabel = Long
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE ListName = 'PalletPack'
      AND   Code = 'PalletID'
      AND   StorerKey = @cStorerKey
      AND   code2 = @nFunc

      IF ISNULL( @cPltLabel, '') <> ''
      BEGIN
         SET @cOutField01 = @cPltLabel + ': '
      END
      ELSE
      BEGIN
         -- Default use Pallet ID packing
         SET @cOutField01 = 'Pallet ID:'
      END

      -- Prepare next screen var
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      -- Go to next screen
      SET @nScn = @nScn_PalletID
      SET @nStep = @nStep_PalletID 
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Logging
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

      -- Reset all variables
      SET @cOutField01 = '' 
   END
   GOTO Quit

   Step_Doc_Fail:
   BEGIN
      SET @cOutField01 = @cDocLabel + ':'
      SET @cOutField02 = ''
      SET @cPickSlipNo = ''
   END
   GOTO Quit

END
GOTO Quit

/************************************************************************************
Scn = 5401. Pallet ID
   Pallet ID   (field01, input)
   Option      (field02, input)
************************************************************************************/
Step_PalletID:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPltValue = @cInField02 
      SET @cCartonCount = @cInField03

      SET @cPalletID = @cPltValue

      -- Check blank
      IF ISNULL( @cPalletID, '') = ''
      BEGIN
         SET @nErrNo = 137102
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet ID req
         GOTO Step_PalletID_Fail
      END

      -- Check valid WaveKey
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                      WHERE StorerKey = @cStorerKey
                      AND   ( ( @cPackByPickDetailDropID = '1' AND DropID = @cPalletID) OR 
                            ( @cPackByPickDetailID = '1' AND ID = @cPalletID))
                      AND   Qty > 0
                      AND   Status < @cPickConfirmStatus)
      BEGIN
         SET @nErrNo = 137103
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PLT ID
         GOTO Step_PalletID_Fail
      END
      SET @cOutField02 = @cPalletID

      IF @cCartonCountCfg > 0 
      BEGIN
         IF @cCartonCount = ''
         BEGIN
            IF @nCartonValidated = 1
            BEGIN
               SET @nErrNo = 137104
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NEED CTN COUNT
               GOTO Step_Ctn_Fail
            END
            ELSE 
            BEGIN
               SET @nCartonValidated = 1
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Quit
            END
         END

         IF rdt.rdtIsValidQty( @cCartonCount, 0) = 0
         BEGIN
            SET @nErrNo = 137105
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INV CTN COUNT
            GOTO Step_Ctn_Fail
         END

         -- Check pallet count
         IF @cCartonCountCfg = '1'
         BEGIN
            IF @cPackByPickDetailDropID = '1'
               SELECT @nIDCtnCount = COUNT ( DISTINCT CaseID)
               FROM dbo.PickDetail PD WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   DropID = @cPalletID
               AND   Qty > 0
               AND   Status < @cPickConfirmStatus
            ELSE
               SELECT @nIDCtnCount = COUNT ( DISTINCT DropID)
               FROM dbo.PickDetail PD WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   ID = @cPalletID
               AND   Qty > 0
               AND   Status < @cPickConfirmStatus

            IF @cCartonCount <> @nIDCtnCount
            BEGIN
               SET @nErrNo = 137106
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- COUNT X MATCH
               GOTO Step_Ctn_Fail
            END
         END

         -- Check pallet count using pack configuration
         IF @cCartonCountCfg = '2'
         BEGIN
            SELECT TOP 1 @cPackKey = PackKey
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND   ( ( @cPackByPickDetailDropID = '1' AND DropID = @cPalletID) OR 
                  ( @cPackByPickDetailID = '1' AND ID = @cPalletID))
            AND   Qty > 0
            AND   Status < @cPickConfirmStatus
            ORDER BY 1

            SELECT @cPallet = Pallet
            FROM dbo.Pack WITH (NOLOCK)
            WHERE PackKey = @cPackKey

            IF @cCartonCount <> @cPallet
            BEGIN
               SET @nErrNo = 137107
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- COUNT X MATCH
               GOTO Step_Ctn_Fail
            END
         END
         
         IF @cCartonCountCfg = '3'
         BEGIN
            SELECT @nUCCCount = COUNT ( DISTINCT UCCNo)
            FROM dbo.UCC WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   Id = @cPalletID
            AND   [Status] > '0'
            AND   [Status] < '6'

            IF CAST( @cCartonCount AS INT) <> @nUCCCount
            BEGIN
               SET @nErrNo = 137110
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- COUNT X MATCH
               GOTO Step_Ctn_Fail
            END
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> '' AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
      BEGIN
         INSERT INTO @tExtValidate (Variable, Value) VALUES 
            ('@cDocLabel',       @cDocLabel),
            ('@cDocValue',       @cDocValue),
            ('@cPltLabel',       @cPltLabel),
            ('@cPltValue',       @cPltValue),
            ('@cCartonCount',    @cCartonCount) 

         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @tExtValidate, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cFacility    NVARCHAR( 5),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@tExtValidate VARIABLETABLE READONLY, ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @tExtValidate, 
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0 
            GOTO Step_PalletID_Fail
      END

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN PalletPack_Confirm

      INSERT INTO @tPackCfm (Variable, Value) VALUES 
         ('@cDocLabel',       @cDocLabel),
         ('@cDocValue',       @cDocValue),
         ('@cPltLabel',       @cPltLabel),
         ('@cPltValue',       @cPltValue),
         ('@cCartonCount',             @cCartonCount),
         ('@cPackByPickDetailDropID',  @cPackByPickDetailDropID),
         ('@cPackByPickDetailID',      @cPackByPickDetailID) 

      -- Pack confirm
      EXEC rdt.rdt_PalletPack_Confirm
         @nMobile       = @nMobile,
         @nFunc         = @nFunc,
         @cLangCode     = @cLangCode,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility, 
         @tPackCfm      = @tPackCfm,
         @cPrintPackList= @cPrintPackList OUTPUT,
         @nErrNo        = @nErrNo         OUTPUT,
         @cErrMsg       = @cErrMsg        OUTPUT

      IF @nErrNo <> 0
      BEGIN
         SET @cOutField02 = ''
         SET @cOutField03 = ''

         IF ISNULL( @cPltLabel, '') <> ''
         BEGIN
            SET @cOutField01 = @cPltLabel + ': '
         END
         ELSE
         BEGIN
            -- Default use Pallet ID packing
            SET @cOutField01 = 'Pallet ID:'
         END

         SET @cOutField02 = ''
         SET @cPalletID = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
      
         GOTO Step_1_RollBackTran
      END

      -- Extended validate
      IF @cExtendedUpdateSP <> '' AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
      BEGIN
         INSERT INTO @tExtUpdate (Variable, Value) VALUES 
            ('@cDocLabel',       @cDocLabel),
            ('@cDocValue',       @cDocValue),
            ('@cPltLabel',       @cPltLabel),
            ('@cPltValue',       @cPltValue),
            ('@cCartonCount',    @cCartonCount) 

         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @tExtUpdate, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cFacility    NVARCHAR( 5),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@tExtUpdate   VARIABLETABLE READONLY, ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @tExtUpdate, 
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0 
            GOTO Step_1_RollBackTran
      END
      
      GOTO Step_1_CfmQuit

      Step_1_RollBackTran:
         ROLLBACK TRAN PalletPack_Confirm

      Step_1_CfmQuit:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN PalletPack_Confirm

      -- Custom PackInfo field setup  
      SET @cPackInfo = ''  
      IF @cCapturePackInfoSP <> ''  
      BEGIN  
         -- Custom SP to get PackInfo setup  
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCapturePackInfoSP AND type = 'P')  
         BEGIN  
            INSERT INTO @tPackInfo (Variable, Value) VALUES 
            ('@cDocLabel',       @cDocLabel),
            ('@cDocValue',       @cDocValue)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @tPackInfo, ' +
               ' @cWeight OUTPUT, @cCube OUTPUT, @cRefNo OUTPUT, @cCartonType OUTPUT, ' + 
               ' @cLength OUTPUT, @cWidth OUTPUT, @cHeight OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tPackInfo      VariableTable READONLY, ' + 
               ' @cPackInfo      NVARCHAR( 7)  OUTPUT, ' +  
               ' @cWeight        NVARCHAR( 10) OUTPUT, ' +  
               ' @cCube          NVARCHAR( 10) OUTPUT, ' +  
               ' @cRefNo         NVARCHAR( 20) OUTPUT, ' +  
               ' @cCartonType    NVARCHAR( 10) OUTPUT, ' +
               ' @cLength        NVARCHAR( 10) OUTPUT, ' +
               ' @cWidth         NVARCHAR( 10) OUTPUT, ' +
               ' @cHeight        NVARCHAR( 10) OUTPUT, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @tPackInfo, 
               @cWeight OUTPUT, @cCube OUTPUT, @cRefNo OUTPUT, @cCartonType OUTPUT, 
               @cLength OUTPUT, @cWidth OUTPUT, @cHeight OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         END  
         ELSE  
            -- Setup is non SP  
            SET @cPackInfo = @cCapturePackInfoSP  
      END  
     
      -- Capture pack info  
      IF @cPackInfo <> ''  
      BEGIN  
         -- Get PackInfo  
         SET @cCartonType = ''  
         SET @cWeight = ''  
         SET @cCube = ''  
         SET @cRefNo = ''  
         SET @cLength = ''  
         SET @cWidth = ''  
         SET @cHeight = ''  
              
         -- Prepare LOC screen var  
         SET @cOutField01 = CASE WHEN ISNULL(@cCartonType ,'') ='' AND ISNULL(@cDefaultCartonType,'')<>''  THEN @cDefaultCartonType ELSE @cCartonType end
         SET @cOutField02 = @cWeight  
         SET @cOutField03 = @cCube  
         SET @cOutField04 = @cRefNo  
         SET @cOutField05 = @cLength  
         SET @cOutField06 = @cWidth  
         SET @cOutField07 = @cHeight  
        
         -- Enable disable field  
         SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'T', @cPackInfo) = 0 THEN 'O' ELSE '' END  
         SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cPackInfo) = 0 THEN 'O' ELSE '' END  
         SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cPackInfo) = 0 THEN 'O' ELSE '' END  
         SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cPackInfo) = 0 THEN 'O' ELSE '' END  
         SET @cFieldAttr05 = CASE WHEN CHARINDEX( 'L', @cPackInfo) = 0 THEN 'O' ELSE '' END  
         SET @cFieldAttr06 = CASE WHEN CHARINDEX( 'D', @cPackInfo) = 0 THEN 'O' ELSE '' END  
         SET @cFieldAttr07 = CASE WHEN CHARINDEX( 'H', @cPackInfo) = 0 THEN 'O' ELSE '' END  
        
         -- Position cursor  
         IF @cFieldAttr01 = '' AND @cOutField01 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE  
         IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE  
         IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE  
         IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4 ELSE  
         IF @cFieldAttr05 = '' AND @cOutField05 = '0'  EXEC rdt.rdtSetFocusField @nMobile, 5 ELSE  
         IF @cFieldAttr06 = '' AND @cOutField06 = '0'  EXEC rdt.rdtSetFocusField @nMobile, 6 ELSE  
         IF @cFieldAttr07 = '' AND @cOutField07 = '0'  EXEC rdt.rdtSetFocusField @nMobile, 7 
                 
        
         -- Go to next screen  
         SET @nScn = @nScn_PackInfo 
         SET @nStep = @nStep_PackInfo  
              
         GOTO Quit  
      END
         
      IF @cPrintPackList = 'Y'
      BEGIN
         SET @cOutField01 = ''

         SET @nScn = @nScn_PrintPackList
         SET @nStep = @nStep_PrintPackList

         GOTO Quit
      END

      -- Prepare next screen var
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @nCartonValidated = 0

      EXEC rdt.rdtSetFocusField @nMobile, 2
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      IF ISNULL( @cDocLabel, '') <> ''
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cDocLabel + ':'

         -- Go to next screen
         SET @nScn = @nScn_Doc
         SET @nStep = @nStep_Doc
      END
      ELSE
      BEGIN
         -- Logging
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

         -- Reset all variables
         SET @cOutField01 = '' 

         -- Enable field
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
      END
   END
   GOTO Quit

   Step_PalletID_Fail:
   BEGIN
      IF ISNULL( @cPltLabel, '') <> ''
      BEGIN
         SET @cOutField01 = @cPltLabel + ': '
      END
      ELSE
      BEGIN
         -- Default use Pallet ID packing
         SET @cOutField01 = 'Pallet ID:'
      END

      SET @cOutField02 = ''
      SET @cPalletID = ''
      EXEC rdt.rdtSetFocusField @nMobile, 2
   END
   GOTO Quit

   Step_Ctn_Fail:
   BEGIN
      IF ISNULL( @cPltLabel, '') <> ''
      BEGIN
         SET @cOutField01 = @cPltLabel + ': '
      END
      ELSE
      BEGIN
         -- Default use Pallet ID packing
         SET @cOutField01 = 'Pallet ID :'
      END

      SET @cOutField03 = ''
      SET @cCartonCount = ''
      EXEC rdt.rdtSetFocusField @nMobile, 3
   END
END
GOTO Quit

/***********************************************************************************
Scn = 5402. Print Packing List screen
   Option      (field01, input)
***********************************************************************************/
Step_PrintPackList:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 137108
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionRequired
         GOTO Quit
      END

      -- Validate option
      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 137109
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         SET @cOutField01 = ''
         GOTO Quit
      END

      IF @cOption = '1'  -- Yes
      BEGIN
         IF @cPackList <> ''
         BEGIN
            -- Get report param
            INSERT INTO @tPackList (Variable, Value) VALUES 
               ( '@cDocLabel',    @cDocLabel),
               ( '@cDocValue',    @cDocValue),
               ( '@cPltLabel',    @cPltLabel),
               ( '@cPltValue',    @cPltValue)

            -- Print packing list
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, '', @cPaperPrinter, 
               @cPackList, -- Report type
               @tPackList, -- Report params
               'rdtfnc_PalletPack', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      IF ISNULL( @cDocLabel, '') <> ''
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' 

         -- Go to next screen
         SET @nScn = @nScn_Doc
         SET @nStep = @nStep_Doc
      END
      ELSE
      BEGIN
         IF ISNULL( @cPltLabel, '') <> ''
         BEGIN
            SET @cOutField01 = @cPltLabel + ': '
         END
         ELSE
         BEGIN
            -- Default use Pallet ID packing
            SET @cOutField01 = 'Pallet ID :'
         END

         -- Prepare next screen var
         SET @cOutField02 = ''

         -- Go to next screen
         SET @nScn = @nScn_PalletID
         SET @nStep = @nStep_PalletID
         
         EXEC rdt.rdtSetFocusField @nMobile, 2
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF ISNULL( @cDocLabel, '') <> ''
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' 

         -- Go to next screen
         SET @nScn = @nScn_Doc
         SET @nStep = @nStep_Doc
      END
      ELSE
      BEGIN
         IF ISNULL( @cPltLabel, '') <> ''
         BEGIN
            SET @cOutField01 = @cPltLabel + ': '
         END
         ELSE
         BEGIN
            -- Default use Pallet ID packing
            SET @cOutField01 = 'Pallet ID :'
         END

         -- Prepare next screen var
         SET @cOutField02 = ''

         -- Go to next screen
         SET @nScn = @nScn_PalletID
         SET @nStep = @nStep_PalletID
      END
   END
END
GOTO Quit

/********************************************************************************  
Scn = 5403. Capture pack info  
   Carton Type (field01, input)  
   Cube        (field02, input)  
   Weight      (field03, input)  
   RefNo       (field04, input)  
   Length      (field05, input)
   Width       (field06, input)
   Height      (field07, input)
********************************************************************************/  
Step_PackInfo:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cCartonType     = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END  
      SET @cWeight         = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END  
      SET @cCube           = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END  
      SET @cRefNo          = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END  
      SET @cLength         = CASE WHEN @cFieldAttr05 = '' THEN @cInField05 ELSE @cOutField05 END  
      SET @cWidth          = CASE WHEN @cFieldAttr06 = '' THEN @cInField06 ELSE @cOutField06 END  
      SET @cHeight         = CASE WHEN @cFieldAttr07 = '' THEN @cInField07 ELSE @cOutField07 END  
        
      -- Carton type  
      IF @cFieldAttr01 = ''  
      BEGIN  
         -- Check blank  
         IF @cCartonType = ''  
         BEGIN  
            SET @nErrNo = 137111  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedCartonType  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            GOTO Quit  
         END  
           
         -- Check if valid  
         IF NOT EXISTS ( SELECT 1  
                         FROM Cartonization CZ WITH (NOLOCK)  
                         JOIN Storer ST WITH (NOLOCK) ON (ST.CartonGroup = CZ.CartonizationGroup)  
                         WHERE ST.StorerKey = @cStorerKey  
                         AND    CZ.CartonType = @cCartonType)  
         BEGIN  
            SET @nErrNo = 137112  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CTN TYPE  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            GOTO Quit  
         END  
      END  
  
      -- Weight  
      IF @cFieldAttr02 = ''  
      BEGIN  
         -- Check blank  
         IF @cWeight = ''  
         BEGIN  
            SET @nErrNo = 137113  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Weight  
            EXEC rdt.rdtSetFocusField @nMobile, 2  
            GOTO Quit  
         END  
         
         -- Check format    --(cc04)
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'Weight', @cWeight) = 0    
         BEGIN    
            SET @nErrNo = 137114   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format    
            EXEC rdt.rdtSetFocusField @nMobile, 2    
            GOTO Quit    
         END   
  
         -- Check weight valid  
         IF @cAllowWeightZero = '1'  
            SET @nErrNo = rdt.rdtIsValidQty( @cWeight, 20)  
         ELSE  
            SET @nErrNo = rdt.rdtIsValidQty( @cWeight, 21)  
  
         IF @nErrNo = 0  
         BEGIN  
            SET @nErrNo = 137115  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid weight  
            EXEC rdt.rdtSetFocusField @nMobile, 2  
            SET @cOutField02 = ''  
            GOTO QUIT  
         END  
         SET @nErrNo = 0  
         SET @cOutField02 = @cWeight  
      END  
  
      -- Cube  
      IF @cFieldAttr03 = ''  
      BEGIN  
         -- Check blank  
         IF @cCube = ''  
         BEGIN  
            SET @nErrNo = 137116  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Cube  
            EXEC rdt.rdtSetFocusField @nMobile, 3  
            GOTO Quit  
         END  
  
         -- Check cube valid  
         IF @cAllowCubeZero = '1'  
            SET @nErrNo = rdt.rdtIsValidQty( @cCube, 20)  
         ELSE  
            SET @nErrNo = rdt.rdtIsValidQty( @cCube, 21)  
  
         IF @nErrNo = 0  
         BEGIN  
            SET @nErrNo = 137117  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid cube  
            EXEC rdt.rdtSetFocusField @nMobile, 3  
            SET @cOutField03 = ''  
            GOTO QUIT  
         END  
         SET @nErrNo = 0  
         SET @cOutField03 = @cCube  
      END  
        
      -- RefNo    
      IF @cFieldAttr04 = ''  
      BEGIN  
         -- Check blank  
         IF @cRefNo = ''  
         BEGIN  
            SET @nErrNo = 137118  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need RefNo  
            EXEC rdt.rdtSetFocusField @nMobile, 4  
            GOTO Quit  
         END  
      END  
  
      -- Length  
      IF @cFieldAttr05 = ''   
      BEGIN  
         -- Check blank  
         IF @cLength = ''  
         BEGIN  
            SET @nErrNo = 137119  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Length  
            EXEC rdt.rdtSetFocusField @nMobile, 4  
            GOTO Quit  
         END  
  
         -- Check cube valid  
         IF @cAllowLengthZero = '1'  
            SET @nErrNo = rdt.rdtIsValidQty( @cLength, 20)  
         ELSE  
            SET @nErrNo = rdt.rdtIsValidQty( @cLength, 21)  
  
         IF @nErrNo = 0  
         BEGIN  
            SET @nErrNo = 137120  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Length  
            EXEC rdt.rdtSetFocusField @nMobile, 4  
            SET @cOutField04 = ''  
            GOTO QUIT  
         END  
         SET @nErrNo = 0  
         SET @cOutField04 = @cLength  
      END  
  
      -- Width  
      --IF @cFieldAttr05 = ''  
      IF @cFieldAttr06 = ''   -- ZG03
      BEGIN  
         -- Check blank  
         IF @cWidth = ''  
         BEGIN  
            SET @nErrNo = 137121  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Width  
            EXEC rdt.rdtSetFocusField @nMobile, 5  
            GOTO Quit  
         END  
  
         -- Check cube valid  
         IF @cAllowWidthZero = '1'  
            SET @nErrNo = rdt.rdtIsValidQty( @cWidth, 20)  
         ELSE  
            SET @nErrNo = rdt.rdtIsValidQty( @cWidth, 21)  
  
         IF @nErrNo = 0  
         BEGIN  
            SET @nErrNo = 137122  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Width  
            EXEC rdt.rdtSetFocusField @nMobile, 5  
            SET @cOutField05 = ''  
            GOTO QUIT  
         END  
         SET @nErrNo = 0  
         SET @cOutField05 = @cWidth  
      END  
  
      -- Height  
      --IF @cFieldAttr06 = ''  
      IF @cFieldAttr07 = ''   
      BEGIN  
         -- Check blank  
         IF @cHeight = ''  
         BEGIN  
            SET @nErrNo = 137123  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Height  
            EXEC rdt.rdtSetFocusField @nMobile, 6  
            GOTO Quit  
         END  
  
         -- Check cube valid  
         IF @cAllowHeightZero = '1'  
            SET @nErrNo = rdt.rdtIsValidQty( @cHeight, 20)  
         ELSE  
            SET @nErrNo = rdt.rdtIsValidQty( @cHeight, 21)  
  
         IF @nErrNo = 0  
         BEGIN  
            SET @nErrNo = 137124  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Height  
            EXEC rdt.rdtSetFocusField @nMobile, 6  
            SET @cOutField06 = ''  
            GOTO QUIT  
         END  
         SET @nErrNo = 0  
         SET @cOutField06 = @cHeight  
      END  
        
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         INSERT INTO @tExtValidate (Variable, Value) VALUES 
         ('@cDocLabel',       @cDocLabel),
         ('@cDocValue',       @cDocValue)

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
            GOTO Quit
      END

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN PalletPack_InsPackInfo

      INSERT INTO @tPackInfo (Variable, Value) VALUES 
         ('@cPltValue',       @cPltValue),
         ('@cPackByPickDetailDropID',  @cPackByPickDetailDropID),
         ('@cPackByPickDetailID',      @cPackByPickDetailID), 
         ('@cCartonType',     @cCartonType),
         ('@cWeight',         @cWeight),
         ('@cCube',           @cCube),
         ('@cRefNo',          @cRefNo),
         ('@cLength',         @cLength),
         ('@cWidth',          @cWidth),
         ('@cHeight',         @cHeight) 

      -- PackInfo
      EXEC rdt.rdt_PalletPack_PackInfo
         @nMobile       = @nMobile,
         @nFunc         = @nFunc,
         @cLangCode     = @cLangCode,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility, 
         @tPackInfo     = @tPackInfo,
         @nErrNo        = @nErrNo         OUTPUT,
         @cErrMsg       = @cErrMsg        OUTPUT

      IF @nErrNo <> 0
         GOTO Step_4_RollBackTran

      -- Extended validate
      IF @cExtendedUpdateSP <> '' AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
      BEGIN
         INSERT INTO @tExtUpdate (Variable, Value) VALUES 
            ('@cDocLabel',       @cDocLabel),
            ('@cDocValue',       @cDocValue),
            ('@cPltLabel',       @cPltLabel),
            ('@cPltValue',       @cPltValue),
            ('@cCartonCount',    @cCartonCount) 

         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @tExtUpdate, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cFacility    NVARCHAR( 5),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@tExtUpdate   VARIABLETABLE READONLY, ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @tExtUpdate, 
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0 
            GOTO Step_4_RollBackTran
      END
      
      GOTO Step_4_CfmQuit

      Step_4_RollBackTran:
         ROLLBACK TRAN PalletPack_Confirm

      Step_4_CfmQuit:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN PalletPack_Confirm
            
      -- Extended update      
      IF @cExtendedUpdateSP <> '' AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
      BEGIN
         INSERT INTO @tExtUpdate (Variable, Value) VALUES 
            ('@cDocLabel',       @cDocLabel),
            ('@cDocValue',       @cDocValue),
            ('@cPltLabel',       @cPltLabel),
            ('@cPltValue',       @cPltValue),
            ('@cCartonCount',    @cCartonCount) 

         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @tExtUpdate, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cFacility    NVARCHAR( 5),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@tExtUpdate   VARIABLETABLE READONLY, ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @tExtUpdate, 
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0 
            GOTO Step_1_RollBackTran
      END

      -- Enable field  
      SET @cFieldAttr01 = '' -- CartonType  
      SET @cFieldAttr02 = '' -- Weight  
      SET @cFieldAttr03 = '' -- Cube  
      SET @cFieldAttr04 = '' -- RefNo  
      SET @cFieldAttr05 = '' -- Length  
      SET @cFieldAttr06 = '' -- Width  
      SET @cFieldAttr07 = '' -- Height  

      IF @cPrintPackList = 'Y'
      BEGIN
         SET @cOutField01 = ''

         SET @nScn = @nScn_PrintPackList
         SET @nStep = @nStep_PrintPackList

         GOTO Quit
      END

      SET @cPltLabel = ''
      SET @cPltValue = ''

      SELECT @cPltLabel = Long
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE ListName = 'PalletPack'
      AND   Code = 'PalletID'
      AND   StorerKey = @cStorerKey
      AND   code2 = @nFunc

      IF ISNULL( @cPltLabel, '') <> ''
      BEGIN
         SET @cOutField01 = @cPltLabel + ': '
      END
      ELSE
      BEGIN
         -- Default use Pallet ID packing
         SET @cOutField01 = 'Pallet ID:'
      END

      -- Prepare next screen var
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      -- Go to next screen
      SET @nScn = @nScn_PalletID
      SET @nStep = @nStep_PalletID 
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Enable field  
      SET @cFieldAttr01 = '' -- CartonType  
      SET @cFieldAttr02 = '' -- Weight  
      SET @cFieldAttr03 = '' -- Cube  
      SET @cFieldAttr04 = '' -- RefNo  
      SET @cFieldAttr05 = '' -- Length  
      SET @cFieldAttr06 = '' -- Width  
      SET @cFieldAttr07 = '' -- Height  
         
      SET @cPltLabel = ''
      SET @cPltValue = ''

      SELECT @cPltLabel = Long
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE ListName = 'PalletPack'
      AND   Code = 'PalletID'
      AND   StorerKey = @cStorerKey
      AND   code2 = @nFunc

      IF ISNULL( @cPltLabel, '') <> ''
      BEGIN
         SET @cOutField01 = @cPltLabel + ': '
      END
      ELSE
      BEGIN
         -- Default use Pallet ID packing
         SET @cOutField01 = 'Pallet ID:'
      END

      -- Prepare next screen var
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      -- Go to next screen
      SET @nScn = @nScn_PalletID
      SET @nStep = @nStep_PalletID 
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

      StorerKey     = @cStorerKey,      
      Facility      = @cFacility,      
      Printer       = @cLabelPrinter,      
      Printer_Paper = @cPaperPrinter,   

      V_WaveKey   = @cWaveKey,
      V_PickSlipNo= @cPickSlipNo,
      V_SKU       = @cSKU,
      V_SKUDescr  = @cSKUDescr,
      V_CaseID    = @cCaseID, 
      V_Dropid    = @cPalletID,
      V_Max       = @cMax,

	   V_String1  = @cExtendedUpdateSP,
      V_String2  = @cExtendedValidateSP,
      V_String3  = @cExtendedInfoSP,
      V_String4  = @cClosePallet,
      V_String5  = @cPrintManifest,
      V_String6  = @cPackOption,
      V_String7  = @cPickConfirmStatus,
      V_String8  = @cPackByPickDetailDropID,
      V_String9  = @cPackByPickDetailID,
      V_String10  = @cDocLabel,
      V_String11  = @cDocValue,
      V_String12  = @cPltLabel,
      V_String13  = @cPltValue,
      V_String14  = @cCartonCountCfg,
      V_String15  = @nCartonValidated,
      V_String16  = @cCapturePackInfoSP,
      V_String17  = @cPackInfo,
  
      V_String18  = @cCartonType,  
      V_String19  = @cCube,  
      V_String20  = @cWeight,  
      V_String21  = @cRefNo,  
      V_String22  = @cLength, 
      V_String23  = @cWidth, 
      V_String24  = @cHeight,
      V_String25  = @cDefaultCartonType,
      V_String26  = @cAllowWeightZero,  
      V_String27  = @cAllowCubeZero,
      V_String28  = @cAllowLengthZero,
      V_String29  = @cAllowWidthZero,
      V_String30  = @cAllowHeightZero,


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