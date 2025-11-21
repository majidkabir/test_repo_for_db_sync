SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************************************/
/* Store procedure: rdtfnc_pack_LVSUSA                                                          */
/* Copyright      : Maersk                                                                      */
/*                                                                                              */
/* Purpose: New Pack function for LVSUSA Only                                                   */
/*                                                                                              */
/* Date         Rev  Author     Purposes                                                        */
/* 2024-10-16   1.0  JCH507     FCR-946 New Pack for LVSUSA                                     */
/************************************************************************************************/

CREATE   PROC [RDT].[rdtfnc_pack_LVSUSA] (
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @bSuccess       INT,
   @cOption        NVARCHAR( 2),
   @cCurrLOC       NVARCHAR( 10),
   @cSQL           NVARCHAR( MAX),
   @cSQLParam      NVARCHAR( MAX),
   @cUCCNo         NVARCHAR( 20),
   @cType          NVARCHAR( 10),
   @cPrintPackList NVARCHAR( 1),
   @cCustomID      NVARCHAR( 20),
   @nTotalUCC      INT,
   @cSerialNo      NVARCHAR( 30) = '',
   @nSerialQTY     INT,
   @nMoreSNO       INT,
   @nBulkSNO       INT,
   @nBulkSNOQTY    INT,
   @tVar                VariableTable, 
   @tVarDisableQTYField VARIABLETABLE

-- RDT.RDTMobRec variables
DECLARE
   @nFunc            INT,
   @nScn             INT,
   @nStep            INT,
   @cLangCode        NVARCHAR( 3),
   @nInputKey        INT,
   @nMenu            INT,
   @cFlowThruScreen  NVARCHAR( 1), 

   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cUserName        NVARCHAR( 18),
   @cPaperPrinter    NVARCHAR( 10),
   @cLabelPrinter    NVARCHAR( 10),

   @cPickSlipNo      NVARCHAR( 10),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cSKUDescr        NVARCHAR( 60),
   @nFromScn         INT,
   @nFromStep        INT,

   @cPackDtlRefNo       NVARCHAR( 20),
   @cPackDtlRefNo2      NVARCHAR( 20),
   @cLabelNo            NVARCHAR( 20),
   @cCartTrkLabelNo     NVARCHAR( 20),
   @cCartonType         NVARCHAR( 10),
   @cCube               NVARCHAR( 10),
   @cWeight             NVARCHAR( 10),
   @cRefNo              NVARCHAR( 20),
   @cLabelLine          NVARCHAR( 5),
   @cPackDtlDropID      NVARCHAR( 20),
   @cUCCCounter         NVARCHAR( 5),
   @cFromLabelNo        NVARCHAR( 20),
   @cFromCartTrkLabelNo NVARCHAR( 20),
   @cNewLabelNo         NVARCHAR( 20),
   @cMasterLabelNo      NVARCHAR( 20),
                     
   @nCartonNo        INT,
   @nCartonSKU       INT,
   @nCartonQTY       INT,
   @nTotalCarton     INT,
   @nTotalPick       INT,
   @nTotalPack       INT,
   @nTotalShort      INT,
   @nPackedQTY       INT,
   @nAction          INT, --(JHU151)   
   @nEnter           INT, --(cc01)
   @nSKURank         INT, -- fcr-946
   @fCartonWeight    FLOAT, -- fcr-946
   @fCartonLength    FLOAT, -- fcr-946 
   @fCartonWidth    FLOAT, -- fcr-946 
   @fCartonHeight    FLOAT, -- fcr-946  

   @cDefaultPrintLabelOption     NVARCHAR( 1),
   @cDefaultPrintPackListOption  NVARCHAR( 1),
   @cDefaultWeight      NVARCHAR( 1),
   @cFromDropID         NVARCHAR( 20),

   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cDecodeSP           NVARCHAR( 20),
   @cDisableQTYField    NVARCHAR( 1),
   @cCapturePackInfoSP  NVARCHAR( 20),
   @cPackInfo           NVARCHAR( 10),
   @cAllowWeightZero    NVARCHAR( 1),
   @cAllowCubeZero      NVARCHAR( 1),
   @cAutoScanIn         NVARCHAR( 1),
   @cDefaultOption      NVARCHAR( 1),
   @cDisableOption      NVARCHAR( 10),    -- ZG01
   @cSerialNoCapture    NVARCHAR( 1),
   @cPackList           NVARCHAR( 10),
   @cShipLabel          NVARCHAR( 10),
   @cCartonManifest     NVARCHAR( 10),
   @cCustomCartonNo     NVARCHAR( 1),
   @cCustomNo           NVARCHAR( 5),
   @cDataCaptureSP      NVARCHAR( 20),
   @cPackDtlUPC         NVARCHAR( 30),
   @cPrePackIndicator   NVARCHAR( 30),
   @cPackQtyIndicator   NVARCHAR( 3),
   @cPackData1          NVARCHAR( 30),
   @cPackData2          NVARCHAR( 30),
   @cPackData3          NVARCHAR( 30),
   @cPackLabel1         NVARCHAR( 20),
   @cPackLabel2         NVARCHAR( 20),
   @cPackLabel3         NVARCHAR( 20),
   @cPackAttr1          NVARCHAR( 1),
   @cPackAttr2          NVARCHAR( 1),
   @cPackAttr3          NVARCHAR( 1),
   @cMultiSKUBarcode    NVARCHAR( 1),
   @cPQTY               NVARCHAR( 5),
   @cMQTY               NVARCHAR( 5),
   @cPUOM               NVARCHAR( 1),
   @cPUOM_Desc          NCHAR( 5),
   @cMUOM_Desc          NCHAR( 5),
   @nPUOM_Div           INT,
   @nPQTY               INT,
   @nMQTY               INT,
   @cShowPickSlipNo     NVARCHAR( 1),
   @cDisableQTYFieldSP  NVARCHAR(20),
   @cDefaultQTY         NVARCHAR( 1), --(cc01)
   @cLength             NVARCHAR( 10), -- (james20)
   @cWidth              NVARCHAR( 10), -- (james20)
   @cHeight             NVARCHAR( 10), -- (james20)
   @cAllowLengthZero    NVARCHAR( 1),  -- (james20)
   @cAllowWidthZero     NVARCHAR( 1),  -- (james20)
   @cAllowHeightZero    NVARCHAR( 1),  -- (james20)
   @cDefaultcartontype  NVARCHAR( 20),  --(yeekung01)
   @cExtendedScreenSP   NVARCHAR( 20), --(JHU151)
   @cJumpType           NVARCHAR( 10), --(JHU151) Forward/Back
   @tExtScnData			VariableTable, --(JHU151)
   @cPackByFromDropID   NVARCHAR( 1),
   @nTranCount          INT, --JCH507 FCR946 temp

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),   @cFieldAttr01 NVARCHAR( 1), @cLottable01  NVARCHAR( 18),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),   @cFieldAttr02 NVARCHAR( 1), @cLottable02  NVARCHAR( 18),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),   @cFieldAttr03 NVARCHAR( 1), @cLottable03  NVARCHAR( 18),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),   @cFieldAttr04 NVARCHAR( 1), @dLottable04  DATETIME,
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),   @cFieldAttr05 NVARCHAR( 1), @dLottable05  DATETIME,
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),   @cFieldAttr06 NVARCHAR( 1), @cLottable06  NVARCHAR( 30),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),   @cFieldAttr07 NVARCHAR( 1), @cLottable07  NVARCHAR( 30),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),   @cFieldAttr08 NVARCHAR( 1), @cLottable08  NVARCHAR( 30),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),   @cFieldAttr09 NVARCHAR( 1), @cLottable09  NVARCHAR( 30),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),   @cFieldAttr10 NVARCHAR( 1), @cLottable10  NVARCHAR( 30),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),   @cFieldAttr11 NVARCHAR( 1), @cLottable11  NVARCHAR( 30),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),   @cFieldAttr12 NVARCHAR( 1), @cLottable12  NVARCHAR( 30),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),   @cFieldAttr13 NVARCHAR( 1), @dLottable13  DATETIME,
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),   @cFieldAttr14 NVARCHAR( 1), @dLottable14  DATETIME,
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),   @cFieldAttr15 NVARCHAR( 1), @dLottable15  DATETIME,

   @cUDF01  NVARCHAR( 250), @cUDF02 NVARCHAR( 250), @cUDF03 NVARCHAR( 250),
   @cUDF04  NVARCHAR( 250), @cUDF05 NVARCHAR( 250), @cUDF06 NVARCHAR( 250),
   @cUDF07  NVARCHAR( 250), @cUDF08 NVARCHAR( 250), @cUDF09 NVARCHAR( 250),
   @cUDF10  NVARCHAR( 250), @cUDF11 NVARCHAR( 250), @cUDF12 NVARCHAR( 250),
   @cUDF13  NVARCHAR( 250), @cUDF14 NVARCHAR( 250), @cUDF15 NVARCHAR( 250),
   @cUDF16  NVARCHAR( 250), @cUDF17 NVARCHAR( 250), @cUDF18 NVARCHAR( 250),
   @cUDF19  NVARCHAR( 250), @cUDF20 NVARCHAR( 250), @cUDF21 NVARCHAR( 250),
   @cUDF22  NVARCHAR( 250), @cUDF23 NVARCHAR( 250), @cUDF24 NVARCHAR( 250),
   @cUDF25  NVARCHAR( 250), @cUDF26 NVARCHAR( 250), @cUDF27 NVARCHAR( 250),
   @cUDF28  NVARCHAR( 250), @cUDF29 NVARCHAR( 250), @cUDF30 NVARCHAR( 250)

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cFacility        = Facility,
   @cStorerKey       = StorerKey,
   @cUserName        = UserName,
   @cPaperPrinter    = Printer_Paper,
   @cLabelPrinter    = Printer,

   @cPickSlipNo      = V_PickSlipNo,
   @cSKU             = V_SKU,
   @nQTY             = V_QTY,
   @cSKUDescr        = V_SKUDescr,
   @cCustomID        = V_CaseID,
   @nFromScn         = V_FromScn,
   @nFromStep        = V_FromStep,
   @cPUOM            = V_UOM,

   @cPackDtlRefNo       = V_String1,
   @cPackDtlRefNo2      = V_String2,
   @cMasterLabelNo      = V_String3, -- fcr946
   @cCartonType         = V_String4,
   @cCube               = V_String5,
   @cWeight             = V_String6,
   @cRefNo              = V_String7,
   @cLabelLine          = V_String8,
   @cPackDtlDropID      = V_String9,
   @cUCCCounter         = V_String10,
   @cMUOM_Desc          = V_String11,
   @cPUOM_Desc          = V_String12,
   @cDisableQTYFieldSP  = V_String13,
   @cFlowThruScreen     = V_String14,

   @nCartonNo           = V_CartonNo,
   @nCartonSKU          = V_Integer1,
   @nCartonQTY          = V_Integer2,
   @nTotalCarton        = V_Integer3,
   @nTotalPick          = V_Integer4,
   @nTotalPack          = V_Integer5,
   @nTotalShort         = V_Integer6,
   @nPackedQTY          = V_Integer7,
   @nPUOM_Div           = V_Integer8,
   @nPQTY               = V_Integer9,
   @nMQTY               = V_Integer10,
   @nEnter              = V_Integer11,  --(cc01)
   @nSKURank            = V_Integer12, --fcr-946  

   @cShowPickSlipNo     = V_String15,
   @cDefaultPrintLabelOption    = V_String16,
   @cDefaultPrintPackListOption = V_String17,
   @cDefaultWeight      = V_String18,
   @cUCCNo              = V_String19,
   @cFromLabelNo        = V_String20,
   @cExtendedValidateSP = V_String21,
   @cExtendedUpdateSP   = V_String22,
   @cExtendedInfoSP     = V_String23,
   @cExtendedInfo       = V_String24,
   @cDecodeSP           = V_String25,
   @cDisableQTYField    = V_String26,
   @cCapturePackInfoSP  = V_String27,
   --@cPackInfo           = V_String28,
   @cAllowWeightZero    = V_String29,
   @cAllowCubeZero      = V_String30,
   --@cAutoScanIn         = V_String31,
   @cDefaultOption      = V_String32,
   @cDisableOption      = V_String33,
   --@cSerialNoCapture    = V_String34,
   @cPackList           = V_String35,
   @cShipLabel          = V_String36,
   @cCartonManifest     = V_String37,
   --@cCustomCartonNo     = V_String38,
   --@cCustomNo           = V_String39,
   @cDataCaptureSP      = V_String40,
   @cPackDtlUPC         = V_String41,
   --@cPrePackIndicator   = V_String42,
   --@cPackQtyIndicator   = V_String43,
   @cPackData1          = V_String44,
   @cPackData2          = V_String45,
   @cPackData3          = V_String46,
   @cFromLabelNo        = V_String47, --fcr946
   @cDefaultQTY         = V_String48, --(cc01)
   @cDefaultcartontype  = V_String49,
   @cNewLabelNo         = V_String50, -- fcr946

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

IF @nFunc = 993 -- Pack_LVSUSA
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0  -- Menu. Func = 993
   IF @nStep = 1  GOTO Step_1  -- Scn = 6490. PickSlipNo, FromDropID, ToDropID
   IF @nStep = 2  GOTO Step_2  -- Scn = 6491. Statistic
   IF @nStep = 3  GOTO Step_3  -- Scn = 6492. SKU QTY
   IF @nStep = 4  GOTO Step_4  -- Scn = 6493. From Carton
   IF @nStep = 5  GOTO Step_5  -- Scn = 6494. New Carton Type
   IF @nStep = 6  GOTO Step_6  -- Scn = 6495. Print label?

END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step_0. Func = 993
********************************************************************************/
Step_0:
BEGIN
   -- Get default UOM
   SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName
   
   -- Get storer configure
   --SET @cAllowCubeZero = rdt.rdtGetConfig( @nFunc, 'AllowCubeZero', @cStorerKey)
   --SET @cAllowWeightZero = rdt.rdtGetConfig( @nFunc, 'AllowWeightZero', @cStorerKey)
   --SET @cAutoScanIn = rdt.rdtGetConfig( @nFunc, 'AutoScanIn', @cStorerKey)
   --SET @cCustomCartonNo = rdt.rdtGetConfig( @nFunc, 'CustomCartonNo', @cStorerKey)
   --SET @cDefaultWeight = rdt.RDTGetConfig( @nFunc, 'DefaultWeight', @cStorerKey)
   SET @cDisableOption = rdt.rdtGetConfig( @nFunc, 'DisableOption', @cStorerKey)
   SET @cDisableQTYField = rdt.rdtGetConfig( @nFunc, 'DisableQTYField', @cStorerKey)
   --SET @cFlowThruScreen = rdt.RDTGetConfig( @nFunc, 'FlowThruScreen', @cStorerKey)
   --SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)
   -- SET @cSerialNoCapture = rdt.RDTGetConfig( @nFunc, 'SerialNoCapture', @cStorerKey)
   --SET @cShowPickSlipNo = rdt.RDTGetConfig( @nFunc, 'ShowPickSlipNo', @cStorerKey)
   SET @cDisableQTYFieldSP = rdt.RDTGetConfig( @nFunc, 'DisableQTYFieldSP', @cStorerKey)
   IF @cDisableQTYFieldSP = '0'
      SET @cDisableQTYFieldSP = ''
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cDecodeSP = rdt.rdtGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cDataCaptureSP = rdt.RDTGetConfig( @nFunc, 'DataCaptureSP', @cStorerKey)
   IF @cDataCaptureSP = '0'
      SET @cDataCaptureSP = ''
   SET @cDefaultcartontype=rdt.RDTGetConfig( @nFunc, 'DefaultCartonType', @cStorerKey)  --(cc01)
   IF @cDefaultcartontype = '0'
      SET @cDefaultcartontype = '' 
   SET @cCartonManifest = rdt.RDTGetConfig( @nFunc, 'CartonManifest', @cStorerKey)
   IF @cCartonManifest = '0'
      SET @cCartonManifest = ''
   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
   IF @cShipLabel = '0'
      SET @cShipLabel = '' 

   /*SET @cCapturePackInfoSP = rdt.RDTGetConfig( @nFunc, 'CapturePackInfoSP', @cStorerKey)
   IF @cCapturePackInfoSP = '0'
      SET @cCapturePackInfoSP = ''
   
   SET @cDefaultcartontype=rdt.RDTGetConfig( @nFunc, 'DefaultCartonType', @cStorerKey)  --(cc01)
   IF @cDefaultcartontype = '0'
      SET @cDefaultcartontype = ''
   SET @cDefaultOption = rdt.rdtGetConfig( @nFunc, 'DefaultOption', @cStorerKey)
   IF @cDefaultOption = '0'
      SET @cDefaultOption = ''
   SET @cDefaultPrintLabelOption = rdt.rdtGetConfig( @nFunc, 'DefaultPrintLabelOption', @cStorerKey)
   IF @cDefaultPrintLabelOption = '0'
      SET @cDefaultPrintLabelOption = ''
   SET @cDefaultPrintPackListOption = rdt.rdtGetConfig( @nFunc, 'DefaultPrintPackListOption', @cStorerKey)
   IF @cDefaultPrintPackListOption = '0'
      SET @cDefaultPrintPackListOption = ''
   SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)  --(cc01)
   IF @cDefaultQTY = '0'
      SET @cDefaultQTY = ''
   SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PackList', @cStorerKey)
   IF @cPackList = '0'
      SET @cPackList = ''
   */
   

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep

   -- Prepare next screen var
   SET @cOutField01 = '' -- LabelNo

   EXEC rdt.rdtSetFocusField @nMobile, 1 -- LabelNo

   -- Go to Carton screen
   SET @nScn = 6490
   SET @nStep = 1

END
GOTO Quit


/************************************************************************************
Scn = 6490. LabelNo screen
   LabelNo    (field01, input)
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLabelNo = @cInField01

      -- Check blank
      IF @cLabelNo = ''
      BEGIN
         SET @nErrNo = 226451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Carton
         GOTO Quit
      END

      --Scanned value could be LabelNo or TrackingNo, get exact LabelNo
      IF NOT EXISTS (SELECT 1 FROM PackDetail WITH (NOLOCK)
                           WHERE StorerKey = @cStorerKey
                              AND LabelNo = @cLabelNo
                     )
      BEGIN
         -- Check if user scan the tracking no
         SELECT  TOP 1 @cCartTrkLabelNo = LabelNo 
         FROM CartonTrack WITH (NOLOCK)
         WHERE TrackingNo = @cLabelNo
            AND KeyName = @cStorerKey       

         IF NOT EXISTS (SELECT 1 FROM PackDetail WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                           AND LabelNo = @cCartTrkLabelNo)             
         BEGIN

            SET @nErrNo = 226452
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartNotExist
            GOTO Quit

         END -- end not in CartonTrack
         ELSE
            SET @cLabelNo = @cCartTrkLabelNo -- retrieve label 
      END

      SET @cMasterLabelNo = @cLabelNo

      -- Check LabelNo
      EXEC rdt.rdt_Pack_LVSUSA_Validate @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'LabelNo'
         ,'' -- @cPickSlipNo
         ,'' --@cFromDropID
         ,'' --@cPackDtlDropID
         ,@cLabelNo --@cLabelNo
         ,'' --@cSKU
         ,0  --@nQTY
         ,0  --@nCartonNo
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- LabelNo
         SET @cOutField01 = ''
         GOTO Quit
      END
      SET @cOutField01 = @cLabelNo

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      --Since PickHeader is closed before packing, needs to reopen PackHeader
      UPDATE PKH SET Status = 0 
      FROM PACKHEADER PKH JOIN PackDetail PKD WITH(ROWLOCK)
         ON PKH.StorerKey = PKD.StorerKey
         AND PKH.PickSlipNo = PKD.PickSlipNo
      WHERE PKH.StorerKey = @cStorerKey
         AND PKD.LabelNo = @cLabelNo

      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 226453
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- Failed to reopen PKH
         SET @cOutField01 = ''
         GOTO Quit
      END

      --Pass LabelNo, CartonNo to screen 2
      --SET @nCartonNo    = 0
      --SET @cLabelNo     = ''
      SET @cCustomNo    = ''
      SET @cCustomID    = ''
      SET @nCartonSKU   = 0
      SET @nCartonQTY   = 0
      SET @nTotalCarton = 0
      SET @nTotalPick   = 0
      SET @nTotalPack   = 0
      SET @nTotalShort  = 0

      -- Get task
      EXEC rdt.rdt_Pack_LVSUSA_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CURRENT'
         ,@cPickSlipNo
         ,@cFromDropID
         ,@cPackDtlDropID
         ,@nCartonNo       OUTPUT
         ,@cMasterLabelNo  OUTPUT
         ,@cCustomNo       OUTPUT
         ,@cCustomID       OUTPUT
         ,@nCartonSKU      OUTPUT
         ,@nCartonQTY      OUTPUT
         ,@nTotalCarton    OUTPUT
         ,@nTotalPick      OUTPUT
         ,@nTotalPack      OUTPUT
         ,@nTotalShort     OUTPUT
         ,@nErrNo          OUTPUT
         ,@cErrMsg         OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Prepare next screen var
      SET @cOutField01 = @cMasterLabelNo
      SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(8))  
      SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(8))  
      SET @cOutField04 = CAST( @nTotalShort AS NVARCHAR(8)) 
      SET @cOutField05 = CAST( @nCartonSKU AS NVARCHAR(5))
      SET @cOutField06 = CAST( @nCartonQTY AS NVARCHAR(5))
      SET @cOutField09 = @cDefaultOption

      /*
      SET @cOutField05 = ''--RTRIM( @cCustomNo) + '/' + CAST( @nTotalCarton AS NVARCHAR(5))
      SET @cOutField06 = ''--@cCustomID
      SET @cOutField07 = CAST( @nCartonSKU AS NVARCHAR(5))
      SET @cOutField08 = CAST( @nCartonQTY AS NVARCHAR(5))
      SET @cOutField09 = @cDefaultOption
      */

      -- Go to statistic screen
      SET @nScn = 6491
      SET @nStep = 2
      
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

      --Clear MasterLabelNo
      SET @cMasterLabelNo = ''

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Scn = 6491. Statistic screen
   OPTION    (field09, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField09
      SET @cLabelNo = @cMasterLabelNo

      -- Need option
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 226454
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option
         SET @cOutField08 = '' -- Option
         GOTO Quit
      END

      -- Validate option
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 226455
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         SET @cOutField09 = '' -- Option
         GOTO Quit
      END

      -- Check disable option
      IF @cDisableOption <> ''
      BEGIN
         IF CHARINDEX( @cOption, @cDisableOption) > 0
         BEGIN
            SET @nErrNo = 226456
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DisabledOption
            SET @cOutField09 = '' -- Option
            GOTO Quit
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,    ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Disable QTY field
      IF @cDisableQTYFieldSP <> ''
      BEGIN
         IF @cDisableQTYFieldSP = '1'
         BEGIN
            SET @cDisableQTYField = @cDisableQTYFieldSP
         END
         ELSE
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @tVarDisableQTYField, @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
               '@nMobile            INT,           ' +
               '@nFunc              INT,           ' +
               '@cLangCode          NVARCHAR( 3),  ' +
               '@nStep              INT,           ' +
               '@nInputKey          INT,           ' +
               '@cFacility          NVARCHAR( 5),  ' +
               '@cStorerKey         NVARCHAR( 15), ' +
               '@cPickSlipNo        NVARCHAR( 10), ' +
               '@cFromDropID        NVARCHAR( 20), ' +
               '@nCartonNo          INT,           ' +
               '@cLabelNo           NVARCHAR( 20), ' +
               '@cSKU               NVARCHAR( 20), ' +
               '@nQTY               INT,           ' +
               '@cUCCNo             NVARCHAR( 20), ' +
               '@cCartonType        NVARCHAR( 10), ' +
               '@cCube              NVARCHAR( 10), ' +
               '@cWeight            NVARCHAR( 10), ' +
               '@cRefNo             NVARCHAR( 20), ' +
               '@cSerialNo          NVARCHAR( 30), ' +
               '@nSerialQTY         INT,           ' +
               '@cOption            NVARCHAR( 1),  ' +
               '@cPackDtlRefNo      NVARCHAR( 20), ' +
               '@cPackDtlRefNo2     NVARCHAR( 20), ' +
               '@cPackDtlUPC        NVARCHAR( 30), ' +
               '@cPackDtlDropID     NVARCHAR( 20), ' +
               '@cPackData1         NVARCHAR( 30), ' +
               '@cPackData2         NVARCHAR( 30), ' +
               '@cPackData3         NVARCHAR( 30), ' +
               '@tVarDisableQTYField VariableTable READONLY, ' +
               '@cDisableQTYField   NVARCHAR( 1)   OUTPUT, ' +
               '@nErrNo             INT            OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
                  @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
                  @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
                  @tVarDisableQTYField, @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
      END

      SET @cUCCNo = ''

      -- New carton
      IF @cOption = '1'
      BEGIN
         SET @nCartonNo = 0
         SET @cNewLabelNo = '' -- JCH507, FCR946
         SET @cSKU = ''
         SET @nPackedQTY = 0
         SET @nCartonSKU = 0
         SET @nCartonQTY = 0

         -- Prepare next screen var
         SET @cOutField01 = 'NEW'
         SET @cOutField02 = '0/0'
         SET @cOutField03 = ''  -- SKU
         SET @cOutField04 = ''  -- SKU
         SET @cOutField05 = ''  -- Desc 1
         SET @cOutField06 = ''  -- Desc 2
         SET @cOutField07 = '0' -- Packed
         SET @cOutField08 = @cDefaultQTY  -- QTY --(cc01)
         SET @cOutField09 = '0' -- CartonQTY
         SET @cOutField11 = '' -- UOM
         SET @cOutField12 = '' -- PUOM
         SET @cOutField13 = '' -- MUOM
         SET @cOutField14 = '' -- PQTY
         SET @cOutField15 = '' -- ExtendedInfo

         -- Enable field
         SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END
         SET @cFieldAttr14 = 'O'
         SET @nEnter = 0 --(cc01)  

         EXEC rdt.rdtSetFocusField @nMobile, 6  -- SKU

         -- Go to SKU QTY screen
         SET @nScn = 6492
         SET @nStep = 3
      END -- Option 1
      -- Merge Carton
      ELSE IF @cOption = '2'
      BEGIN
         -- Check UCC
         IF EXISTS( SELECT 1 FROM PackInfo PI WITH (NOLOCK) 
                     JOIN PackDetail PD WITH (NOLOCK)
                     ON PI.PickSlipNo = PD.PickSlipNo
                        AND PI.CartonNo = PD.CartonNo
                     WHERE PD.LabelNo = @cMasterLabelNo 
                        AND UCCNo <> '')
         BEGIN
            SET @nErrNo = 226457
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cannot EditUCC
            GOTO Quit
         END

         SET @cOutField01 = @cMasterLabelNo
         SET @cOutField02 = ''

         EXEC rdt.rdtSetFocusField @nMobile, 2  -- From Carton

         -- Go to From Carton screen
         SET @nScn = 6493
         SET @nStep = 4

      END

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cPickSlipNo',     @cPickSlipNo),
               ('@cFromDropID',     @cFromDropID),
               ('@nCartonNo',       CAST( @nCartonNo AS NVARCHAR( 10))),
               ('@cLabelNo',        @cLabelNo),
               ('@cSKU',            @cSKU),
               ('@nQTY',            CAST( @nQTY AS NVARCHAR( 10))),
               ('@cUCCNo',          @cUCCNo),
               ('@cCartonType',     @cCartonType),
               ('@cCube',           @cCube),
               ('@cWeight',         @cWeight),
               ('@cRefNo',          @cRefNo),
               ('@cSerialNo',       @cSerialNo),
               ('@nSerialQTY',      CAST( @nSerialQTY AS NVARCHAR( 10))),
               ('@cOption',         @cOption),
               ('@cPackDtlRefNo',   @cPackDtlRefNo),
               ('@cPackDtlRefNo2',  @cPackDtlRefNo2),
               ('@cPackDtlUPC',     @cPackDtlUPC),
               ('@cPackDtlDropID',  @cPackDtlDropID),
               ('@cPackData1',      @cPackData1),
               ('@cPackData2',      @cPackData2),
               ('@cPackData3',      @cPackData3)

            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
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
               ' @tVar           VariableTable READONLY, ' +
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 2, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
             @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            IF @nStep = 3
               SET @cOutField15 = @cExtendedInfo
         END
      END --Extended info
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cPrintPackList = ''
      SET @cLabelNo = @cMasterLabelNo

      EXEC rdt.rdt_Pack_LVSUSA_PackConfirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cPickSlipNo
         ,@cFromDropID
         ,@cPackDtlDropID
         ,@cLabelNo
         ,@cPrintPackList OUTPUT
         ,@nErrNo         OUTPUT
         ,@cErrMsg        OUTPUT

      IF @nErrNo <> 0
         GOTO Quit

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT
         END
      END -- ExtUpd

      /* -- skip packlist logic
      IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status = '9') OR @cPrintPackList = 'Y'
      BEGIN
         -- Print packing list
         IF @cPackList <> ''
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = @cDefaultPrintPackListOption --Option

            -- Go to print packing list screen
            SET @nScn = @nScn + 4
            SET @nStep = @nStep + 4

            GOTO Quit
         END
      END
      */

      -- Go to print label screen
      SET @cOutField01 = 'CURRENT CARTON ID: ' + @cMasterLabelNo
      SET @cOutField02 = ''

      SET @nFromScn = 6491
      SET @nFromStep = 2
      
      SET @nScn = 6495
      SET @nStep = 6
   END -- Inputkey = 0

END -- step 2

GOTO Quit


/********************************************************************************
Scn = 4692. SKU QTY screen
   CARTON NO   (field01)
   SKUCount    (field02)
   CartonSKU   (field02)
   SKU/UPC     (field03, input)
   SKU         (field04)
   DESCR1      (field05)
   DESCR2      (field06)
   PACKED      (field07)
   QTY         (field08, input)
   CARTON QTY  (field09)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cBarcode NVARCHAR( 60)
      DECLARE @cUPC     NVARCHAR( 30)
      DECLARE @cQTY     NVARCHAR( 5)
      DECLARE @nDecodeQTY INT
      DECLARE @cPackDtlDropID_Decode NVARCHAR(20)
      DECLARE @cSKUDataCapture       NVARCHAR(1)
      DECLARE @cDataCapture          NVARCHAR(1)

      SET @nQTY = 0
      SET @nDecodeQTY = 0
      SET @cQTY = ''

      -- Screen mapping
      SET @cBarcode = @cInField03 -- SKU
      SET @cUPC = LEFT( @cInField03, 30) -- SKU
      SET @cMQTY = CASE WHEN @cFieldAttr08 = 'O' THEN '' ELSE @cInField08 END
      SET @cPQTY = CASE WHEN @cFieldAttr14 = 'O' THEN '' ELSE @cInField14 END

      -- if outfield01=NEW means it is the 1st SKYQty screen after select New
      IF @cOutField01 = 'NEW'
         SET @cLabelNo = ''
      ELSE
         SET @cLabelNo = @cOutField01

      SET @cNewLabelNo = @cLabelNo

      -- Retain value
      SET @cOutField08 = CASE WHEN @cFieldAttr08 = 'O' THEN @cOutField08 ELSE @cInField08 END -- PQTY
      SET @cOutField14 = CASE WHEN @cFieldAttr14 = 'O' THEN @cOutField14 ELSE @cInField14 END -- MQTY

      -- Loop SKU
      IF @cBarcode = '' AND @cMQTY = '' AND @cPQTY = ''
      BEGIN
         IF @nCartonQTY > 0
         BEGIN
            -- Get carton info
            SELECT TOP 1
               @cSKU = SKU
            FROM PackDetail WITH (NOLOCK)
            WHERE LabelNo = @cLabelNo
               AND SKU > @cSKU
            ORDER BY SKU

            IF @@ROWCOUNT = 0
               SELECT TOP 1
                  @cSKU = SKU
               FROM PackDetail WITH (NOLOCK)
               WHERE LabelNo = @cLabelNo
               ORDER BY SKU

            -- Get SKU info
            SELECT
               @cSKUDescr = Descr,
               @cPrePackIndicator = ISNULL( PrePackIndicator, ''),
               @cPackQtyIndicator = LEFT( ISNULL( PackQtyIndicator, '0'), 3),
               @cMUOM_Desc = Pack.PackUOM3,
               @cPUOM_Desc =
                  CASE @cPUOM
                     WHEN '2' THEN Pack.PackUOM1 -- Case
                     WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                     WHEN '6' THEN Pack.PackUOM3 -- Master unit
                     WHEN '1' THEN Pack.PackUOM4 -- Pallet
                     WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                     WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
                  END,
                  @nPUOM_Div = CAST( IsNULL(
                  CASE @cPUOM
                     WHEN '2' THEN Pack.CaseCNT
                     WHEN '3' THEN Pack.InnerPack
                     WHEN '6' THEN Pack.QTY
                     WHEN '1' THEN Pack.Pallet
                     WHEN '4' THEN Pack.OtherUnit1
                     WHEN '5' THEN Pack.OtherUnit2
                  END, 1) AS INT)
            FROM dbo.SKU SKU WITH (NOLOCK)
               INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE SKU.StorerKey = @cStorerKey
               AND SKU.SKU = @cSKU

            -- Disable QTY field (cc03)
            IF @cDisableQTYFieldSP <> ''
            BEGIN
               IF @cDisableQTYFieldSP = '1'
               BEGIN
                  SET @cDisableQTYField = @cDisableQTYFieldSP
               END
               ELSE
               BEGIN
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')
                  BEGIN
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
                     ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
                     ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
                     ' @tVarDisableQTYField, @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                     SET @cSQLParam =
                     '@nMobile            INT,           ' +
                     '@nFunc              INT,           ' +
                     '@cLangCode          NVARCHAR( 3),  ' +
                     '@nStep              INT,           ' +
                     '@nInputKey          INT,           ' +
                     '@cFacility          NVARCHAR( 5),  ' +
                     '@cStorerKey         NVARCHAR( 15), ' +
                     '@cPickSlipNo        NVARCHAR( 10), ' +
                     '@cFromDropID        NVARCHAR( 20), ' +
                     '@nCartonNo          INT,           ' +
                     '@cLabelNo           NVARCHAR( 20), ' +
                     '@cSKU               NVARCHAR( 20), ' +
                     '@nQTY               INT,           ' +
                     '@cUCCNo             NVARCHAR( 20), ' +
                     '@cCartonType        NVARCHAR( 10), ' +
                     '@cCube              NVARCHAR( 10), ' +
                     '@cWeight            NVARCHAR( 10), ' +
                     '@cRefNo             NVARCHAR( 20), ' +
                     '@cSerialNo          NVARCHAR( 30), ' +
                     '@nSerialQTY         INT,           ' +
                     '@cOption            NVARCHAR( 1),  ' +
                     '@cPackDtlRefNo      NVARCHAR( 20), ' +
                     '@cPackDtlRefNo2     NVARCHAR( 20), ' +
                     '@cPackDtlUPC        NVARCHAR( 30), ' +
                     '@cPackDtlDropID     NVARCHAR( 20), ' +
                     '@cPackData1         NVARCHAR( 30), ' +
                     '@cPackData2         NVARCHAR( 30), ' +
                     '@cPackData3         NVARCHAR( 30), ' +
                     '@tVarDisableQTYField VariableTable READONLY, ' +
                     '@cDisableQTYField   NVARCHAR( 1)   OUTPUT, ' +
                     '@nErrNo             INT            OUTPUT, ' +
                     '@cErrMsg            NVARCHAR( 20)  OUTPUT'

                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                        @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
                        @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
                        @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
                        @tVarDisableQTYField, @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

                     IF @nErrNo <> 0
                        GOTO Quit
                  END
               END
            END

            -- Get PackDetail info
            ;WITH RankedSKUs AS (
               SELECT 
                  LabelNo,
                  SKU,
                  SUM(Qty) AS Total_Qty,
                  ROW_NUMBER() OVER (PARTITION BY LabelNo ORDER BY SKU) AS SKU_Rank
               FROM 
                  PackDetail PD
               WHERE PD.LabelNo = @cNewLabelNo
               GROUP BY 
                  LabelNo, SKU
            )
            SELECT 
               @nPackedQty = Total_Qty,
               @nSKURank = SKU_Rank
            FROM 
               RankedSKUs
            WHERE SKU = @cSKU
            ORDER BY 
               SKU;

            -- Prepare next screen var
            SET @cOutField01 = CASE WHEN ISNULL(RTRIM( @cNewLabelNo),'') = '' THEN 'NEW' ELSe RTRIM( @cNewLabelNo) END -- fcr-946
            SET @cOutField02 = CAST( @nSKURank AS NVARCHAR(5)) + '/' + CAST( @nCartonSKU AS NVARCHAR(5))
            SET @cOutField03 = '' -- SKU
            SET @cOutField04 = @cSKU
            SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
            SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
            SET @cOutField07 = CAST( @nPackedQTY AS NVARCHAR( 8))    -- ZG02
            SET @cOutField08 = @cDefaultQTY -- QTY --(cc01)
            SET @cOutField09 = CAST( @nCartonQTY AS NVARCHAR( 5))
            SET @cOutField10 = CASE WHEN @cPrePackIndicator = '2' THEN @cPackQtyIndicator ELSE '' END
            SET @cOutField11 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
            SET @cOutField12 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
            SET @cOutField13 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
            SET @cOutField14 = '' -- PQTY

            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
               SET @nPQTY = 0
               SET @cFieldAttr14 = 'O' -- @nPQTY
            END
            ELSE
            BEGIN
               SET @cFieldAttr14 = '' -- @nPQTY
            END

            -- Extended info
            IF @cExtendedInfoSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
               BEGIN
                  INSERT INTO @tVar (Variable, Value) VALUES
                     ('@cPickSlipNo',     @cPickSlipNo),
                     ('@cFromDropID',     @cFromDropID),
                     ('@nCartonNo',       CAST( @nCartonNo AS NVARCHAR( 10))),
                     ('@cLabelNo',        @cLabelNo),
                     ('@cSKU',            @cSKU),
                     ('@nQTY',            CAST( @nQTY AS NVARCHAR( 10))),
                     ('@cUCCNo',          @cUCCNo),
                     ('@cCartonType',     @cCartonType),
                     ('@cCube',           @cCube),
                     ('@cWeight',         @cWeight),
                     ('@cRefNo',          @cRefNo),
                     ('@cSerialNo',       @cSerialNo),
                     ('@nSerialQTY',      CAST( @nSerialQTY AS NVARCHAR( 10))),
                     ('@cOption',         @cOption),
                     ('@cPackDtlRefNo',   @cPackDtlRefNo),
                     ('@cPackDtlRefNo2',  @cPackDtlRefNo2),
                     ('@cPackDtlUPC',     @cPackDtlUPC),
                     ('@cPackDtlDropID',  @cPackDtlDropID),
                     ('@cPackData1',      @cPackData1),
                     ('@cPackData2',      @cPackData2),
                     ('@cPackData3',      @cPackData3)

                  SET @cExtendedInfo = ''
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
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
                     ' @tVar           VariableTable READONLY, ' +
                     ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +
                     ' @nErrNo         INT           OUTPUT,   ' +
                     ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
                     @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Quit

                  IF @nStep = 3
                     SET @cOutField15 = @cExtendedInfo
               END
            END

            GOTO Quit
         END
      END

      -- Check SKU blank
      IF @cBarcode = ''
      BEGIN
         SET @nErrNo = 100206
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need SKU
         GOTO Step_3_Fail
      END

      -- Validate SKU
      IF @cBarcode <> ''
      BEGIN
         -- Decode
         IF @cDecodeSP <> ''
         BEGIN
            SET @cPackDtlRefNo  = ''
            SET @cPackDtlRefNo2 = ''
            SET @cPackDtlUPC    = ''
            SET @cPackDtlDropID_Decode = ''

            -- Standard decode
            IF @cDecodeSP = '1'
            BEGIN
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
                  @cUPC          = @cUPC           OUTPUT,
                  @nQTY          = @nDecodeQTY     OUTPUT,
                  @cUserDefine01 = @cPackDtlRefNo  OUTPUT,
                  @cUserDefine02 = @cPackDtlRefNo2 OUTPUT,
                  @cUserDefine03 = @cPackDtlUPC    OUTPUT,
                  @cUserDefine04 = @cPackDtlDropID_Decode OUTPUT,
                  @cSerialNo     = @cSerialNo      OUTPUT,
                  @nErrNo        = 0, --@nErrNo     OUTPUT,
                  @cErrMsg       = '' --@cErrMsg    OUTPUT
            END

            -- Customize decode
            ELSE IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cBarcode, ' +
                  ' @cSKU OUTPUT, @nQTY OUTPUT, @cPackDtlRefNo OUTPUT, @cPackDtlRefNo2 OUTPUT, @cPackDtlUPC OUTPUT, @cPackDtlDropID OUTPUT, @cSerialNo OUTPUT, ' +
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  ' @nMobile        INT,           ' +
                  ' @nFunc          INT,           ' +
                  ' @cLangCode      NVARCHAR( 3),  ' +
                  ' @nStep          INT,           ' +
                  ' @nInputKey      INT,           ' +
                  ' @cFacility      NVARCHAR( 5),  ' +
                  ' @cStorerKey     NVARCHAR( 15), ' +
                  ' @cPickSlipNo    NVARCHAR( 10), ' +
                  ' @cFromDropID    NVARCHAR( 20), ' +
                  ' @cBarcode       NVARCHAR( 60), ' +
                  ' @cSKU           NVARCHAR( 20)  OUTPUT, ' +
                  ' @nQTY           INT            OUTPUT, ' +
                  ' @cPackDtlRefNo  NVARCHAR( 20)  OUTPUT, ' +
                  ' @cPackDtlRefNo2 NVARCHAR( 20)  OUTPUT, ' +
                  ' @cPackDtlUPC    NVARCHAR( 30)  OUTPUT, ' +
                  ' @cPackDtlDropID NVARCHAR( 20)  OUTPUT, ' +
                  ' @cSerialNo      NVARCHAR( 30)  OUTPUT, ' +
                  ' @nErrNo         INT            OUTPUT, ' +
                  ' @cErrMsg        NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cBarcode,
                  @cUPC OUTPUT, @nQTY OUTPUT, @cPackDtlRefNo OUTPUT, @cPackDtlRefNo2 OUTPUT, @cPackDtlUPC OUTPUT, @cPackDtlDropID_Decode OUTPUT, @cSerialNo OUTPUT, 
                  @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_3_Fail

               IF ISNULL( @nQTY, 0) > 0
                  SET @nDecodeQTY = @nQTY
            END

            IF @cPackDtlDropID_Decode <> ''
               SET @cPackDtlDropID = @cPackDtlDropID_Decode
         END

         -- Get SKU count
         DECLARE @nSKUCnt INT
         SET @nSKUCnt = 0
         EXEC RDT.rdt_GetSKUCNT
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cUPC
            ,@nSKUCnt     = @nSKUCnt   OUTPUT
            ,@bSuccess    = @bSuccess  OUTPUT
            ,@nErr        = @nErrNo    OUTPUT
            ,@cErrMsg     = @cErrMsg   OUTPUT

         -- Check SKU valid
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 226460
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            GOTO Step_3_Fail
         END


         -- Check barcode return multi SKU
         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 226461
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
            GOTO Step_3_Fail
         END

         IF @nSKUCnt = 1
            EXEC rdt.rdt_GetSKU
                @cStorerKey  = @cStorerKey
               ,@cSKU        = @cUPC      OUTPUT
               ,@bSuccess    = @bSuccess  OUTPUT
               ,@nErr        = @nErrNo    OUTPUT
               ,@cErrMsg     = @cErrMsg   OUTPUT

         SET @cSKU = @cUPC

         -- Check scanned SKU in the master (original) Carton
         EXEC rdt.rdt_Pack_LVSUSA_Validate @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'SKU'
            ,@cPickSlipNo
            ,@cFromDropID
            ,@cPackDtlDropID
            ,@cMasterLabelNo
            ,@cSKU
            ,0 --@nQTY
            ,0 --@nCartonNo
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Step_3_Fail

         -- Get SKU info
         SELECT
            @cSKUDescr = Descr,
            @cSKUDataCapture = DataCapture,
            @cPrePackIndicator = ISNULL( PrePackIndicator, ''),
            @cPackQtyIndicator = LEFT( ISNULL( PackQtyIndicator, '0'), 3),
            @cMUOM_Desc = Pack.PackUOM3,
            @cPUOM_Desc =
               CASE @cPUOM
                  WHEN '2' THEN Pack.PackUOM1 -- Case
                  WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                  WHEN '6' THEN Pack.PackUOM3 -- Master unit
                  WHEN '1' THEN Pack.PackUOM4 -- Pallet
                  WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                  WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
               END,
               @nPUOM_Div = CAST( IsNULL(
               CASE @cPUOM
                  WHEN '2' THEN Pack.CaseCNT
                  WHEN '3' THEN Pack.InnerPack
                  WHEN '6' THEN Pack.QTY
                  WHEN '1' THEN Pack.Pallet
                  WHEN '4' THEN Pack.OtherUnit1
                  WHEN '5' THEN Pack.OtherUnit2
               END, 1) AS INT)
         FROM dbo.SKU SKU WITH (NOLOCK)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU

         -- Get PackDetail info
         SET @nPackedQTY = 0
         SET @nSKURank = 0

         -- Get PackDetail info
         ;WITH RankedSKUs AS (
            SELECT 
               LabelNo,
               SKU,
               SUM(Qty) AS Total_Qty,
               ROW_NUMBER() OVER (PARTITION BY LabelNo ORDER BY SKU) AS SKU_Rank
            FROM 
               PackDetail PD
            WHERE PD.LabelNo = @cNewLabelNo
            GROUP BY 
               LabelNo, SKU
         )
         SELECT 
            @nPackedQty = Total_Qty,
            @nSKURank = SKU_Rank
         FROM 
            RankedSKUs
         WHERE SKU = @cSKU
         ORDER BY 
            SKU;



         -- Disable QTY field (cc03)
         IF @cDisableQTYFieldSP <> ''
         BEGIN
            IF @cDisableQTYFieldSP = '1'
            BEGIN
               SET @cDisableQTYField = @cDisableQTYFieldSP
            END
            ELSE
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
                  ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
                  ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
                  ' @tVarDisableQTYField, @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                  '@nMobile            INT,           ' +
                  '@nFunc              INT,           ' +
                  '@cLangCode          NVARCHAR( 3),  ' +
                  '@nStep              INT,           ' +
                  '@nInputKey          INT,           ' +
                  '@cFacility          NVARCHAR( 5),  ' +
                  '@cStorerKey         NVARCHAR( 15), ' +
                  '@cPickSlipNo        NVARCHAR( 10), ' +
                  '@cFromDropID        NVARCHAR( 20), ' +
                  '@nCartonNo          INT,           ' +
                  '@cLabelNo           NVARCHAR( 20), ' +
                  '@cSKU               NVARCHAR( 20), ' +
                  '@nQTY               INT,           ' +
                  '@cUCCNo             NVARCHAR( 20), ' +
                  '@cCartonType        NVARCHAR( 10), ' +
                  '@cCube              NVARCHAR( 10), ' +
                  '@cWeight            NVARCHAR( 10), ' +
                  '@cRefNo             NVARCHAR( 20), ' +
                  '@cSerialNo          NVARCHAR( 30), ' +
                  '@nSerialQTY         INT,           ' +
                  '@cOption            NVARCHAR( 1),  ' +
                  '@cPackDtlRefNo      NVARCHAR( 20), ' +
                  '@cPackDtlRefNo2     NVARCHAR( 20), ' +
                  '@cPackDtlUPC        NVARCHAR( 30), ' +
                  '@cPackDtlDropID     NVARCHAR( 20), ' +
                  '@cPackData1         NVARCHAR( 30), ' +
                  '@cPackData2         NVARCHAR( 30), ' +
                  '@cPackData3         NVARCHAR( 30), ' +
                  '@tVarDisableQTYField VariableTable READONLY, ' +
                  '@cDisableQTYField   NVARCHAR( 1)   OUTPUT, ' +
                  '@nErrNo             INT            OUTPUT, ' +
                  '@cErrMsg            NVARCHAR( 20)  OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
                     @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
                     @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
                     @tVarDisableQTYField, @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Quit
               END
            END
         END

         -- (james01)
         -- Extended info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               INSERT INTO @tVar (Variable, Value) VALUES
                  ('@cPickSlipNo',     @cPickSlipNo),
                  ('@cFromDropID',     @cFromDropID),
                  ('@nCartonNo',       CAST( @nCartonNo AS NVARCHAR( 10))),
                  ('@cLabelNo',        @cLabelNo),
                  ('@cSKU',            @cSKU),
                  ('@nQTY',            CAST( @nQTY AS NVARCHAR( 10))),
                  ('@cUCCNo',          @cUCCNo),
                  ('@cCartonType',     @cCartonType),
                  ('@cCube',           @cCube),
                  ('@cWeight',         @cWeight),
                  ('@cRefNo',          @cRefNo),
                  ('@cSerialNo',       @cSerialNo),
                  ('@nSerialQTY',      CAST( @nSerialQTY AS NVARCHAR( 10))),
                  ('@cOption',         @cOption),
                  ('@cPackDtlRefNo',   @cPackDtlRefNo),
                  ('@cPackDtlRefNo2',  @cPackDtlRefNo2),
                  ('@cPackDtlUPC',     @cPackDtlUPC),
                  ('@cPackDtlDropID',  @cPackDtlDropID),
                  ('@cPackData1',      @cPackData1),
                  ('@cPackData2',      @cPackData2),
                  ('@cPackData3',      @cPackData3)

               SET @cExtendedInfo = ''
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
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
                  ' @tVar           VariableTable READONLY, ' +
                  ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +
                  ' @nErrNo         INT           OUTPUT,   ' +
                  ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
                  @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit

               IF @nStep = 3
                  SET @cOutField15 = @cExtendedInfo
            END
         END

         SET @cOutField02 = CAST( @nSKURank AS NVARCHAR(5)) + '/' + CAST( @nCartonSKU AS NVARCHAR(5))
         SET @cOutField03 = CASE WHEN @cDisableQTYField = '1' THEN '' ELSE @cSKU END
         SET @cOutField04 = @cSKU
         SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
         SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
         SET @cOutField07 = CAST( @nPackedQTY AS NVARCHAR( 8))    -- ZG02
         --SET @cOutField10 = CASE WHEN @cPrePackIndicator = '2' THEN @cPackQtyIndicator ELSE '' END --fcr946
         SET @cOutField11 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
         SET @cOutField12 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
         SET @cOutField13 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
         SET @cOutField14 = '' -- PQTY

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @cFieldAttr14 = 'O' -- @nPQTY
         END
         ELSE
         BEGIN
            SET @cFieldAttr14 = '' -- @nPQTY
         END

         EXEC rdt.rdtSetFocusField @nMobile, 8
      END

      --(cc01)  
      IF @cDefaultQTY >0 AND @nEnter = 0  
      BEGIN
         SET @nEnter = 1  
         EXEC rdt.rdtSetFocusField @nMobile, 8
         GOTO Quit
      END

      --Above is the SKU handling logic

      -- Start to handling input qty

      -- Validate MQTY
      IF @cMQTY <> '' AND RDT.rdtIsValidQTY( @cMQTY, 1) = 0 --Check zero
      BEGIN
         SET @nErrNo = 226462
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- QTY
         GOTO Step_3_QTY_Fail
      END

      -- Validate PQTY
      IF @cPQTY <> '' AND RDT.rdtIsValidQTY( @cPQTY, 1) = 0 --Check zero
      BEGIN
         SET @nErrNo = 226463
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 14 -- QTY
         GOTO Step_3_QTY_Fail
      END

      -- Get QTY
      IF @nDecodeQTY > 0
      BEGIN
         SET @cQTY = CAST( @nDecodeQTY AS NVARCHAR(8))  -- ZG02
         SET @nQTY = @nDecodeQTY
      END
      ELSE
         IF @cSKU <> '' AND @cDisableQTYField = '1'
         BEGIN
            IF @cPrePackIndicator = '2'
            BEGIN
               SET @cQTY = @cPackQtyIndicator
               SET @nQTY = CAST( @cPackQtyIndicator AS INT)
            END
            ELSE
            BEGIN
               SET @cQTY = '1'
               SET @nQTY = 1
            END
         END
         ELSE
         BEGIN
            -- Calc total QTY in master UOM
            SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
            SET @nQTY = @nQTY + CAST( @cMQTY AS INT)

            IF @cPrePackIndicator = '2'
            BEGIN
               SET @nQTY = @nQTY * CAST( @cPackQtyIndicator AS INT)
               SET @cQTY = CAST( @nQTY AS NVARCHAR(8))  -- ZG02
            END
         END

      -- Retain QTY
      SET @cOutField08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE @cMQTY END --(cc03)
      SET @cOutField14 = CASE WHEN @cPUOM_Desc <> '' THEN @cPQTY ELSE '' END

      -- Check over pack
      EXEC rdt.rdt_Pack_LVSUSA_Validate @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'QTY'
         ,''-- @cPickSlipNo
         ,'' --@cFromDropID
         ,'' --@cPackDtlDropID
         ,@cNewLabelNo -- NewLabel
         ,@cSKU
         ,@nQTY
         ,@nCartonNo
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- QTY
         GOTO Step_3_QTY_Fail
      END

      -- Check blank QTY
      IF @cQTY = '' AND @nQTY = 0
      BEGIN
         SET @nErrNo = 100204
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need QTY
         IF @cDisableQTYField = '1'
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
         ELSE
            EXEC rdt.rdtSetFocusField @nMobile, 8 -- QTY
         GOTO Step_3_QTY_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,    ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_3_QTY_Fail
         END
      END

      -- Custom data capture setup
      SET @cPackData1 = ''
      SET @cPackData2 = ''
      SET @cPackData3 = ''

      -- Confirm
      EXEC RDT.rdt_Pack_LVSUSA_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cType          = 'NEW'
         ,@cMasterLabelNo = @cMasterLabelNo
         ,@cSKU           = @cSKU
         ,@nQTY           = @nQTY
         ,@cUCCNo         = '' -- @cUCCNo
         ,@cSerialNo      = '' -- @cSerialNo
         ,@nSerialQTY     = 0  -- @nSerialQTY
         ,@cPackDtlRefNo  = @cPackDtlRefNo
         ,@cPackDtlRefNo2 = @cPackDtlRefNo2
         ,@cPackDtlUPC    = @cPackDtlUPC
         ,@cPackDtlDropID = @cPackDtlDropID
         ,@nCartonNo      = @nCartonNo    OUTPUT
         ,@cLabelNo       = @cNewLabelNo  OUTPUT --NewLabelNo
         ,@nErrNo         = @nErrNo       OUTPUT
         ,@cErrMsg        = @cErrMsg      OUTPUT
         ,@nBulkSNO       = 0
         ,@nBulkSNOQTY    = 0
         ,@cPackData1     = @cPackData1
         ,@cPackData2     = @cPackData2
         ,@cPackData3     = @cPackData3
      IF @nErrNo <> 0
         GOTO Quit

      SET @cLabelNo = @cNewLabelNo

      -- Calc carton info
      SELECT
         @nCartonSKU = COUNT(DISTINCT SKU), --DISTINCT PD.SKU
         @nCartonQTY = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.LabelNo = @cNewLabelNo

      ;WITH RankedSKUs AS (
         SELECT 
            LabelNo,
            SKU,
            SUM(Qty) AS Total_Qty,
            ROW_NUMBER() OVER (PARTITION BY LabelNo ORDER BY SKU) AS SKU_Rank
         FROM 
            PackDetail PD
         WHERE PD.LabelNo = @cNewLabelNo
         GROUP BY 
            LabelNo, SKU
      )
      SELECT 
         @nPackedQty = Total_Qty,
         @nSKURank = SKU_Rank
      FROM 
         RankedSKUs
      WHERE SKU = @cSKU
      ORDER BY 
         SKU;

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cPickSlipNo',     @cPickSlipNo),
               ('@cFromDropID',     @cFromDropID),
               ('@nCartonNo',       CAST( @nCartonNo AS NVARCHAR( 10))),
               ('@cLabelNo',        @cLabelNo),
               ('@cSKU',            @cSKU),
               ('@nQTY',            CAST( @nQTY AS NVARCHAR( 10))),
               ('@cUCCNo',          @cUCCNo),
               ('@cCartonType',     @cCartonType),
               ('@cCube',           @cCube),
               ('@cWeight',         @cWeight),
               ('@cRefNo',          @cRefNo),
               ('@cSerialNo',       @cSerialNo),
               ('@nSerialQTY',      CAST( @nSerialQTY AS NVARCHAR( 10))),
               ('@cOption',         @cOption),
               ('@cPackDtlRefNo',   @cPackDtlRefNo),
               ('@cPackDtlRefNo2',  @cPackDtlRefNo2),
               ('@cPackDtlUPC',     @cPackDtlUPC),
               ('@cPackDtlDropID',  @cPackDtlDropID),
               ('@cPackData1',      @cPackData1),
               ('@cPackData2',      @cPackData2),
               ('@cPackData3',      @cPackData3)

            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tVar, ' +
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
               ' @tVar           VariableTable READONLY, ' +
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT,   ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cFacility, @cStorerKey, @tVar,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            IF @nStep = 3
               SET @cOutField15 = @cExtendedInfo
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = CASE WHEN ISNULL(RTRIM( @cNewLabelNo),'') = '' THEN 'NEW' ELSE RTRIM( @cNewLabelNo) END -- fcr-946
      SET @cOutField02 = CAST( @nSKURank AS NVARCHAR(5)) + '/' + CAST( @nCartonSKU AS NVARCHAR(5))
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = @cSKU
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDescr, 1, 20)
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDescr, 21, 20)
      SET @cOutField07 = CAST( @nPackedQTY AS NVARCHAR( 8))    -- FCR-946
      SET @cOutField08 = CASE WHEN @cDisableQTYField = '1' THEN @cQTY ELSE @cDefaultQTY END --(cc01)
      SET @cOutField09 = CAST( @nCartonQTY AS NVARCHAR( 5))
      SET @cOutField10 = CASE WHEN @cPrePackIndicator = '2' THEN @cPackQtyIndicator ELSE '' END
      SET @cOutField11 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
      SET @cOutField12 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
      SET @cOutField13 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
      SET @cOutField14 = '' -- PQTY
      --SET @cOutField15 = '' -- ExtendedInfo
      SET @nEnter = 0      --(cc01)  

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @cFieldAttr14 = 'O' -- @nPQTY
      END
      ELSE
      BEGIN
         SET @cFieldAttr14 = '' -- @nPQTY
      END

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
   END -- Inputkey = 1

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 -- V6.4 By JCH507
            BEGIN
               GOTO  Quit
            END
         END
      END

      -- Press Esc without scan any SKU in New option, back to Statistic screen
      IF @cNewLabelNo = '' AND @nCartonQTY = 0 
      BEGIN
         EXEC rdt.rdt_Pack_LVSUSA_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CURRENT'
         ,@cPickSlipNo
         ,@cFromDropID
         ,@cPackDtlDropID
         ,@nCartonNo          OUTPUT
         ,@cMasterLabelNo     OUTPUT
         ,@cCustomNo          OUTPUT
         ,@cCustomID          OUTPUT
         ,@nCartonSKU         OUTPUT
         ,@nCartonQTY         OUTPUT
         ,@nTotalCarton       OUTPUT
         ,@nTotalPick         OUTPUT
         ,@nTotalPack         OUTPUT
         ,@nTotalShort        OUTPUT
         ,@nErrNo             OUTPUT
         ,@cErrMsg            OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- back to screen 2
         SET @cOutField01 = @cMasterLabelNo
         SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(8))  
         SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(8))  
         SET @cOutField04 = CAST( @nTotalShort AS NVARCHAR(8)) 
         SET @cOutField05 = CAST( @nCartonSKU AS NVARCHAR(5))
         SET @cOutField06 = CAST( @nCartonQTY AS NVARCHAR(5))
         SET @cOutField09 = @cDefaultOption

         -- Enable field
         SET @cFieldAttr08 = '' -- QTY23

         SET @cOutField15 = ''

         --Clear NewLabelNo when back to screen 2 --fcr946
         SET @cNewLabelNo = ''

         --Reset 
         SET @nEnter = 0 --(JHU151) 

         -- Go to statistic screen
         SET @nScn = 6491
         SET @nStep = 2
      END --Press Esc without scan any SKU in New option, back to Statistic screen
      ELSE -- New Carton created
      BEGIN
         -- Update SKU weight to Master LabelNo Pack Info Weight column first
         BEGIN TRY
            ;WITH CartonInfo AS 
            (
               SELECT PD.PickSlipNo AS PickSlipNo, PD.CartonNO AS CartonNo, SUM(PD.qty)* MAX(SKU.STDGROSSWGT) AS WGT,  MAX(CAT.CartonWeight) AS CartonWeight
               FROM PackDetail PD WITH (NOLOCK)
               INNER JOIN SKU WITH (NOLOCK)
                  ON PD.StorerKey = SKU.StorerKey
                  AND PD.SKU = SKU.Sku
               INNER JOIN Storer WITH (NOLOCK)
                  ON PD.StorerKey = STORER.StorerKey
               INNER JOIN PackInfo PI WITH (NOLOCK)
                  ON PD.PickSlipNo = PI.PickSlipNo
                  AND PD.CartonNo = PI.CartonNo
               INNER JOIN CARTONIZATION CAT WITH (NOLOCK)
                  ON Storer.CartonGroup = CAT.CartonizationGroup AND PI.CartonType = CAT.CartonType
               WHERE PD.LabelNo = @cMasterLabelNo
               GROUP BY PD.LabelNo, PD.CartonNo, PD.PickSlipNo 
            )
            UPDATE PackInfo WITH (ROWLOCK)
            SET 
               PackInfo.Weight = CartonInfo.WGT,
               PackInfo.CartonStatus = 'PACKED'
            FROM PackInfo
            JOIN CartonInfo
               ON PackInfo.PickSlipNo = CartonInfo.PickSlipNo
               AND PackInfo.CartonNo = CartonInfo.CartonNo
         END TRY
         BEGIN CATCH
            SET @nErrNo = 226464
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- update master LabelNo pack info
            GOTO Quit
         END CATCH

         --Update Add carton weight to the 1st record weight value in packinfo under this carton
         BEGIN TRY
            SET @fCartonWeight = 0
            SELECT TOP 1 @fCartonWeight = MAX(CAT.CartonWeight)
            FROM PackDetail PD WITH (NOLOCK)
            INNER JOIN Storer WITH (NOLOCK)
               ON PD.StorerKey = STORER.StorerKey
            INNER JOIN PackInfo PI WITH (NOLOCK)
               ON PD.PickSlipNo = PI.PickSlipNo
               AND PD.CartonNo = PI.CartonNo
            INNER JOIN CARTONIZATION CAT WITH (NOLOCK)
               ON Storer.CartonGroup = CAT.CartonizationGroup AND PI.CartonType = CAT.CartonType
            WHERE PD.LabelNo = @cMasterLabelNo
            GROUP BY PD.LabelNo, PD.CartonNo, PD.PickSlipNo

            UPDATE PackInfo WITH (ROWLOCK)
            SET Weight = PackInfo.Weight + ISNULL(@fCartonWeight,0)
            FROM (
               SELECT TOP (1) PI.*
               FROM PackInfo PI WITH (NOLOCK)
               JOIN PackDetail PD WITH (NOLOCK)
                  ON PI.PickSlipNo = PD.PickSlipNo
                  AND PI.CartonNo = PD.CartonNo
               WHERE PD.LabelNo = @cMasterLabelNo
               ORDER BY PI.PickSlipNo
            ) AS TOP1
            WHERE PackInfo.PickSlipNo = TOP1.PickSlipNo
            AND PackInfo.CartonNo = TOP1.CartonNo
         END TRY
         BEGIN CATCH
            SET @nErrNo = 226470
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Fail add carton weight
            GOTO Quit
         END CATCH
         --Update Add carton weight to the 1st record weight value in packinfo under this carton

         SET @cOutField01 = @cNewLabelNo
         SET @cOutField02 = ''
         
         SET @nScn = 6494 -- Carton Type Screen
         SET @nStep = 5
      END -- New carton created

      /*-- Packed
      IF @nCartonQTY > 0
      BEGIN

         -- Print label
         IF @cShipLabel <> '' OR @cCartonManifest <> ''
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = @cDefaultPrintLabelOption --Option

            -- Enable field
            SET @cFieldAttr08 = '' -- QTY
            
            --Reset 
            SET @nEnter = 0 --(JHU151) 

            -- Go to next screen
            SET @nScn = @nScn + 2
            SET @nStep = @nStep + 2

            -- Flow thru
            IF EXISTS( SELECT 1 FROM STRING_SPLIT( @cFlowThruScreen, ',') WHERE TRIM( value) = '5') -- Print label screen
            BEGIN
               SET @cInField01 = @cDefaultPrintLabelOption --Option
               SET @nInputKey = 1 -- ENTER
               GOTO Step_5
            END
            ELSE
               GOTO Quit
         END
      END*/

      /*
      IF @nCartonNo = 0 OR @nCartonQTY = 0
         SET @cType = 'NEXT'
      ELSE
         SET @cType = 'CURRENT'*/

      -- Get task
      
   END --Inputkey = 0
   
   GOTO Quit
   
   Step_3_Fail:
   BEGIN
      IF rdt.RDTGetConfig( @nFunc, 'ShowErrMsgInNewScn', @cStorerkey) = '1'
      BEGIN
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
      END

      SET @cOutField03 = '' -- SKU
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
      SET @cOutField08=@cDefaultQTY --(moo01)
      SET @cInField08=''
   END
   GOTO Quit

   Step_3_QTY_Fail:
   BEGIN
      IF rdt.RDTGetConfig( @nFunc, 'ShowErrMsgInNewScn', @cStorerkey) = '1'
      BEGIN
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
      END

      SET @cOutField08 = CASE WHEN @cFieldAttr08 = 'O' THEN @cOutField08 ELSE '' END -- PQTY
      SET @cOutField14 = CASE WHEN @cFieldAttr14 = 'O' THEN @cOutField14 ELSE '' END -- MQTY
   END
   GOTO Quit

END
GOTO Quit

/********************************************************************************
Scn = 6493. From Carton Screen
   CURRENT CARTON ID (field01)
   FROM CARTON ID    (field02, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN 
      SET @cLabelNo = @cInField02

      -- Check blank
      IF @cLabelNo = ''
      BEGIN
         SET @nErrNo = 226458
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need From Carton
         GOTO Quit
      END

      --Scanned value could be LabelNo or TrackingNo, get exact LabelNo
      IF NOT EXISTS (SELECT 1 FROM PackDetail WITH (NOLOCK)
                           WHERE StorerKey = @cStorerKey
                              AND LabelNo = @cLabelNo
                     )
      BEGIN
         -- Check if user scan the tracking no
         SELECT  TOP 1 @cFromCartTrkLabelNo = LabelNo 
         FROM CartonTrack WITH (NOLOCK)
         WHERE TrackingNo = @cLabelNo
            AND KeyName = @cStorerKey       

         IF NOT EXISTS (SELECT 1 FROM PackDetail WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                           AND LabelNo = @cFromCartTrkLabelNo)             
         BEGIN

            SET @nErrNo = 226459
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FromCartNotExist
            SET @cOutField02 = '' --Clear input value
            GOTO Quit

         END -- end not in CartonTrack
         ELSE
            SET @cLabelNo = @cFromCartTrkLabelNo -- retrieve label 
      END

      SET @cFromLabelNo = @cLabelNo

      -- Check FromLabelNo
      EXEC rdt.rdt_Pack_LVSUSA_Validate @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'LabelNo'
         ,'' -- @cPickSlipNo
         ,'' --@cFromDropID
         ,'' --@cPackDtlDropID
         ,@cFromLabelNo --@cFromLabelNo
         ,'' --@cSKU
         ,0  --@nQTY
         ,0  --@nCartonNo
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 2  -- FromLabelNo
         SET @cOutField02 = '' --Clear input value
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -----------------------------------------------
      --Merge Confirm Logic
      -----------------------------------------------
      EXEC RDT.rdt_Pack_LVSUSA_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cType          = 'MERGE'
         ,@cMasterLabelNo = @cMasterLabelNo
         ,@cSKU           = ''
         ,@nQTY           = 0
         ,@cUCCNo         = '' -- @cUCCNo
         ,@cSerialNo      = '' -- @cSerialNo
         ,@nSerialQTY     = 0  -- @nSerialQTY
         ,@cPackDtlRefNo  = ''
         ,@cPackDtlRefNo2 = ''
         ,@cPackDtlUPC    = ''
         ,@cPackDtlDropID = ''
         ,@nCartonNo      = @nCartonNo     OUTPUT
         ,@cLabelNo       = @cFromLabelNo  OUTPUT --FromLabelNo
         ,@nErrNo         = @nErrNo        OUTPUT
         ,@cErrMsg        = @cErrMsg       OUTPUT
         ,@nBulkSNO       = 0
         ,@nBulkSNOQTY    = 0
         ,@cPackData1     = @cPackData1
         ,@cPackData2     = @cPackData2
         ,@cPackData3     = @cPackData3
         IF @nErrNo <> 0
            GOTO Quit

         --Update Master Carton Packinfo
         BEGIN TRY
            ;WITH CartonInfo AS 
            (
               SELECT PD.PickSlipNo AS PickSlipNo, PD.CartonNO AS CartonNo, SUM(PD.qty)* MAX(SKU.STDGROSSWGT) AS WGT
               FROM PackDetail PD WITH (NOLOCK)
               INNER JOIN SKU WITH (NOLOCK)
                  ON PD.StorerKey = SKU.StorerKey
                  AND PD.SKU = SKU.Sku
               INNER JOIN PackInfo PI WITH (NOLOCK)
                  ON PD.PickSlipNo = PI.PickSlipNo
                  AND PD.CartonNo = PI.CartonNo
               WHERE PD.LabelNo = @cMasterLabelNo
               GROUP BY PD.LabelNo, PD.CartonNo, PD.PickSlipNo 
            )
            UPDATE PackInfo WITH (ROWLOCK)
            SET 
               PackInfo.Weight = CartonInfo.WGT,
               PackInfo.CartonStatus = 'PACKED'
            FROM PackInfo
            JOIN CartonInfo
               ON PackInfo.PickSlipNo = CartonInfo.PickSlipNo
               AND PackInfo.CartonNo = CartonInfo.CartonNo
         END TRY
         BEGIN CATCH
            SET @nErrNo = 226471
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- update master LabelNo pack info
            GOTO Quit
         END CATCH

         --Update Add carton weight to the 1st record weight value in packinfo under this carton
         BEGIN TRY
            SET @fCartonWeight = 0

            SELECT TOP 1 @fCartonWeight = MAX(CAT.CartonWeight)
            FROM PackDetail PD WITH (NOLOCK)
            INNER JOIN Storer WITH (NOLOCK)
               ON PD.StorerKey = STORER.StorerKey
            INNER JOIN PackInfo PI WITH (NOLOCK)
               ON PD.PickSlipNo = PI.PickSlipNo
               AND PD.CartonNo = PI.CartonNo
            INNER JOIN CARTONIZATION CAT WITH (NOLOCK)
               ON Storer.CartonGroup = CAT.CartonizationGroup AND PI.CartonType = CAT.CartonType
            WHERE PD.LabelNo = @cMasterLabelNo
            GROUP BY PD.LabelNo, PD.CartonNo, PD.PickSlipNo

            UPDATE PackInfo WITH (ROWLOCK)
            SET Weight = PackInfo.Weight + ISNULL(@fCartonWeight, 0)
            FROM (
               SELECT TOP (1) PI.*
               FROM PackInfo PI WITH (NOLOCK)
               JOIN PackDetail PD WITH (NOLOCK)
                  ON PI.PickSlipNo = PD.PickSlipNo
                  AND PI.CartonNo = PD.CartonNo
               WHERE PD.LabelNo = @cMasterLabelNo
               ORDER BY PI.PickSlipNo
            ) AS TOP1
            WHERE PackInfo.PickSlipNo = TOP1.PickSlipNo
            AND PackInfo.CartonNo = TOP1.CartonNo
         END TRY
         BEGIN CATCH
            SET @nErrNo = 226472
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Add carton weight fail
            GOTO Quit
         END CATCH
         --Update Add carton weight to the 1st record weight value in packinfo under this carton

         --Back to Step 2
         SET @cCustomNo    = ''
         SET @cCustomID    = ''
         SET @nCartonSKU   = 0
         SET @nCartonQTY   = 0
         SET @nTotalCarton = 0
         SET @nTotalPick   = 0
         SET @nTotalPack   = 0
         SET @nTotalShort  = 0

         -- Get task
         EXEC rdt.rdt_Pack_LVSUSA_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CURRENT'
            ,@cPickSlipNo
            ,@cFromDropID
            ,@cPackDtlDropID
            ,@nCartonNo       OUTPUT
            ,@cMasterLabelNo  OUTPUT
            ,@cCustomNo       OUTPUT
            ,@cCustomID       OUTPUT
            ,@nCartonSKU      OUTPUT
            ,@nCartonQTY      OUTPUT
            ,@nTotalCarton    OUTPUT
            ,@nTotalPick      OUTPUT
            ,@nTotalPack      OUTPUT
            ,@nTotalShort     OUTPUT
            ,@nErrNo          OUTPUT
            ,@cErrMsg         OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Prepare next screen var
         SET @cOutField01 = @cMasterLabelNo
         SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(8))  
         SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(8))  
         SET @cOutField04 = CAST( @nTotalShort AS NVARCHAR(8)) 
         SET @cOutField05 = CAST( @nCartonSKU AS NVARCHAR(5))
         SET @cOutField06 = CAST( @nCartonQTY AS NVARCHAR(5))
         SET @cOutField09 = @cDefaultOption

         /*
         SET @cOutField05 = ''--RTRIM( @cCustomNo) + '/' + CAST( @nTotalCarton AS NVARCHAR(5))
         SET @cOutField06 = ''--@cCustomID
         SET @cOutField07 = CAST( @nCartonSKU AS NVARCHAR(5))
         SET @cOutField08 = CAST( @nCartonQTY AS NVARCHAR(5))
         SET @cOutField09 = @cDefaultOption
         */

         SET @nScn = 6491
         SET @nStep = 2
      END -- Inputkey = 1

      IF @nInputKey = 0
      BEGIN
         SET @cOutField01 = @cMasterLabelNo
         SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(8))  
         SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(8))  
         SET @cOutField04 = CAST( @nTotalShort AS NVARCHAR(8)) 
         SET @cOutField05 = CAST( @nCartonSKU AS NVARCHAR(5))
         SET @cOutField06 = CAST( @nCartonQTY AS NVARCHAR(5))
         SET @cOutField09 = @cDefaultOption

         -- Clear FromLabelNo
         SET @cFromLabelNo = '' -- fcr946

         SET @nSCN = 6491 -- Stat Screen
         SET @nStep = 2
      END

END -- Step4
GOTO Quit

/********************************************************************************
Scn = 6494. NEW Carton Type
   NEW CARTON ID (field01)
   NEW CARTON Type (field02, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1
   BEGIN
      SET @cCartonType = @cInField02

      --Input Validation
      IF @cCartonType = ''
      BEGIN
         SET @nErrNo = 226465
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --carton type required
         GOTO Quit
      END

      SELECT 
         @fCartonWeight = ISNULL(CartonWeight, 0),
         @fCartonHeight = ISNULL(CartonHeight, 0),
         @fCartonWidth  = ISNULL(CartonWidth, 0),
         @fCartonLength = ISNULL(CartonLength, 0)
      FROM CARTONIZATION CAT WITH (NOLOCK)
      JOIN Storer WITH (NOLOCK)
         ON Storer.StorerKey = @cStorerKey AND Storer.CartonGroup = CAT.CartonizationGroup
      WHERE CAT.CartonType = @cCartonType

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 226466
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --invalid carton type
         GOTO Quit
      END

      -- Update new label packinfo
      BEGIN TRY
         ;WITH CartonInfo AS 
         (
            SELECT PD.PickSlipNo AS PickSlipNo, PD.CartonNO AS CartonNo, SUM(PD.qty)* MAX(SKU.STDGROSSWGT) AS WGT
            FROM PackDetail PD WITH (NOLOCK)
            INNER JOIN SKU WITH (NOLOCK)
               ON PD.StorerKey = SKU.StorerKey
               AND PD.SKU = SKU.Sku
            INNER JOIN PackInfo PI WITH (NOLOCK)
               ON PD.PickSlipNo = PI.PickSlipNo
               AND PD.CartonNo = PI.CartonNo
            WHERE PD.LabelNo = @cNewLabelNo
            GROUP BY PD.LabelNo, PD.CartonNo, PD.PickSlipNo 
         )
         UPDATE PackInfo WITH (ROWLOCK) SET
            PackInfo.Weight = CartonInfo.WGT,
            PackInfo.Height = @fCartonHeight,
            PackInfo.Width = @fCartonWidth,
            PackInfo.Length = @fCartonLength,
            PackInfo.Cube = @fCartonHeight * @fCartonLength * @fCartonWidth, -- Calculate cube
            PackInfo.CartonType = @cCartonType,
            PackInfo.CartonStatus = 'PACKED'
         FROM PackInfo
         JOIN CartonInfo
            ON PackInfo.PickSlipNo = CartonInfo.PickSlipNo
            AND PackInfo.CartonNo = CartonInfo.CartonNo
      END TRY
      BEGIN CATCH
         SET @nErrNo = 226473
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- update master LabelNo pack info
         GOTO Quit
      END CATCH

      --Update Add carton weight to the 1st record weight value in packinfo under this carton
      BEGIN TRY
         UPDATE PackInfo WITH (ROWLOCK)
         SET Weight = PackInfo.Weight + ISNULL(@fCartonWeight, 0)
         FROM (
            SELECT TOP (1) PI.*
            FROM PackInfo PI WITH (NOLOCK)
            JOIN PackDetail PD WITH (NOLOCK)
               ON PI.PickSlipNo = PD.PickSlipNo
               AND PI.CartonNo = PD.CartonNo
            WHERE PD.LabelNo = @cNewLabelNo
            ORDER BY PI.PickSlipNo
         ) AS TOP1
         WHERE PackInfo.PickSlipNo = TOP1.PickSlipNo
         AND PackInfo.CartonNo = TOP1.CartonNo
      END TRY
      BEGIN CATCH
         SET @nErrNo = 226474
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Add carton weight fail
         GOTO Quit
      END CATCH
      --Update Add carton weight to the 1st record weight value in packinfo under this carton

      SET @cOutField01 = 'NEW CARTON ID: ' + @cNewLabelNo --Carton ID
      SET @cOutField02 = '' --Option

      SET @nFromScn = 6494
      SET @nFromStep = 5

      SET @nScn = 6495
      SET @nStep = 6

   END -- Enter

   IF @nInputKey = 0
   BEGIN
      SET @nErrNo = 226469
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Must input carton type
      GOTO Quit 
   END --ESC
   
END -- step5
GOTO Quit


/********************************************************************************
Scn = 6495. Message. Print label?
   CARTON No (field01)
   Option (field02, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField02

      -- Validate blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 226467
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionRequired
         GOTO Quit
      END

      -- Validate option
      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 226468
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- Option
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      IF @cOption = '1'  -- Yes
      BEGIN
         --Set @cLabelNo value based on the different from step
         IF @nFromScn = 6494 AND @nFromStep = 5 -- New Carton
            SET @cLabelNo = @cNewLabelNo
         ELSE IF @nFromScn = 6491 AND @nFromStep = 2
            SET @cLabelNo = @cMasterLabelNo
         ELSE
            SET @cLabelNo = ''

         IF @cLabelNo = ''
         BEGIN
            SET @nErrNo = 226475
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelNo empty
            GOTO Quit
         END

         -- Ship label
         IF @cShipLabel <> ''
         BEGIN
            IF @cShipLabel = 'CstLabelSP'
            BEGIN
               DECLARE @cCstLabelSP NVARCHAR(30)
               SET @cCstLabelSP = rdt.RDTGetConfig( @nFunc, 'CstLabelSP', @cStorerKey)
               IF @cCstLabelSP = '0'
                  SET @cCstLabelSP = ''
               IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCstLabelSP AND type = 'P')  --Customize Print Label
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cCstLabelSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
                     ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
                     ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
                     ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                     '@nMobile         INT,           ' +
                     '@nFunc           INT,           ' +
                     '@cLangCode       NVARCHAR( 3),  ' +
                     '@nStep           INT,           ' +
                     '@nInputKey       INT,           ' +
                     '@cFacility       NVARCHAR( 5),  ' +
                     '@cStorerKey      NVARCHAR( 15), ' +
                     '@cPickSlipNo     NVARCHAR( 10), ' +
                     '@cFromDropID     NVARCHAR( 20), ' +
                     '@nCartonNo       INT,           ' +
                     '@cLabelNo        NVARCHAR( 20), ' +
                     '@cSKU            NVARCHAR( 20), ' +
                     '@nQTY            INT,           ' +
                     '@cUCCNo          NVARCHAR( 20), ' +
                     '@cCartonType     NVARCHAR( 10), ' +
                     '@cCube           NVARCHAR( 10), ' +
                     '@cWeight         NVARCHAR( 10), ' +
                     '@cRefNo          NVARCHAR( 20), ' +
                     '@cSerialNo       NVARCHAR( 30), ' +
                     '@nSerialQTY      INT,           ' +
                     '@cOption         NVARCHAR( 1),  ' +
                     '@cPackDtlRefNo   NVARCHAR( 20), ' +
                     '@cPackDtlRefNo2  NVARCHAR( 20), ' +
                     '@cPackDtlUPC     NVARCHAR( 30), ' +
                     '@cPackDtlDropID  NVARCHAR( 20), ' +
                     '@cPackData1      NVARCHAR( 30), ' +
                     '@cPackData2      NVARCHAR( 30), ' +
                     '@cPackData3      NVARCHAR( 30), ' +
                     '@nErrNo          INT            OUTPUT, ' +
                     '@cErrMsg         NVARCHAR( 20)  OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
                     @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
                     @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
                     @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Quit
               END
            END
            ELSE BEGIN  --Standard Print
               -- Common params
               DECLARE @tShipLabel AS VariableTable
               INSERT INTO @tShipLabel (Variable, Value) VALUES
                  ( '@cStorerKey',     @cStorerKey),
                  ( '@cPickSlipNo',    @cPickSlipNo),
                  ( '@cFromDropID',    @cFromDropID),
                  ( '@cPackDtlDropID', @cPackDtlDropID),
                  ( '@cLabelNo',       @cLabelNo),
                  ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
                  @cShipLabel, -- Report type
                  @tShipLabel, -- Report params
                  'rdtfnc_pack_LVSUSA',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit
            END
         END

         -- Carton manifest
         IF @cCartonManifest <> ''
         BEGIN
            -- Common params
            DECLARE @tCartonManifest AS VariableTable
            INSERT INTO @tCartonManifest (Variable, Value) VALUES
               ( '@cStorerKey',     @cStorerKey),
               ( '@cPickSlipNo',    @cPickSlipNo),
               ( '@cFromDropID',    @cFromDropID),
               ( '@cPackDtlDropID', @cPackDtlDropID),
               ( '@cLabelNo',       @cLabelNo),
               ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               @cCartonManifest, -- Report type
               @tCartonManifest, -- Report params
               'rdtfnc_pack_LVSUSA',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
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
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
               ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
               ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cFromDropID     NVARCHAR( 20), ' +
               '@nCartonNo       INT,           ' +
               '@cLabelNo        NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cCartonType     NVARCHAR( 10), ' +
               '@cCube           NVARCHAR( 10), ' +
               '@cWeight         NVARCHAR( 10), ' +
               '@cRefNo          NVARCHAR( 20), ' +
               '@cSerialNo       NVARCHAR( 30), ' +
               '@nSerialQTY      INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cPackDtlRefNo   NVARCHAR( 20), ' +
               '@cPackDtlRefNo2  NVARCHAR( 20), ' +
               '@cPackDtlUPC     NVARCHAR( 30), ' +
               '@cPackDtlDropID  NVARCHAR( 20), ' +
               '@cPackData1      NVARCHAR( 30), ' +
               '@cPackData2      NVARCHAR( 30), ' +
               '@cPackData3      NVARCHAR( 30), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
               @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
               @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      IF @nFromScn = 6491 AND @nFromStep = 2
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cMasterLabelNo = ''
         SET @cNewLabelNo = ''
         SET @cFromLabelNo = ''

         SET @nScn = 6490
         SET @nStep = 1
      END --back to step 1
      ELSE
      BEGIN
         --Back to screen 2
         --SET @nCartonNo    = 0
         --SET @cLabelNo     = ''
         SET @cCustomNo    = ''
         SET @cCustomID    = ''
         SET @nCartonSKU   = 0
         SET @nCartonQTY   = 0
         SET @nTotalCarton = 0
         SET @nTotalPick   = 0
         SET @nTotalPack   = 0
         SET @nTotalShort  = 0

         -- Get task
         EXEC rdt.rdt_Pack_LVSUSA_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CURRENT'
            ,@cPickSlipNo
            ,@cFromDropID
            ,@cPackDtlDropID
            ,@nCartonNo       OUTPUT
            ,@cMasterLabelNo  OUTPUT
            ,@cCustomNo       OUTPUT
            ,@cCustomID       OUTPUT
            ,@nCartonSKU      OUTPUT
            ,@nCartonQTY      OUTPUT
            ,@nTotalCarton    OUTPUT
            ,@nTotalPick      OUTPUT
            ,@nTotalPack      OUTPUT
            ,@nTotalShort     OUTPUT
            ,@nErrNo          OUTPUT
            ,@cErrMsg         OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Prepare next screen var
         SET @cOutField01 = @cMasterLabelNo
         SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(8))  
         SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(8))  
         SET @cOutField04 = CAST( @nTotalShort AS NVARCHAR(8)) 
         SET @cOutField05 = CAST( @nCartonSKU AS NVARCHAR(5))
         SET @cOutField06 = CAST( @nCartonQTY AS NVARCHAR(5))
         SET @cOutField09 = @cDefaultOption

         /*
         SET @cOutField05 = ''--RTRIM( @cCustomNo) + '/' + CAST( @nTotalCarton AS NVARCHAR(5))
         SET @cOutField06 = ''--@cCustomID
         SET @cOutField07 = CAST( @nCartonSKU AS NVARCHAR(5))
         SET @cOutField08 = CAST( @nCartonQTY AS NVARCHAR(5))
         SET @cOutField09 = @cDefaultOption
         */

         -- Go to statistic screen
         SET @nScn = 6491
         SET @nStep = 2
      END -- back to step 2

      SET @nFromScn = 0
      SET @nFromStep = 0
   END --Enter

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @nFromScn = 6494 AND @nFromStep = 5
      BEGIN
         --go to New carton type screen
         SET @cOutField01 = @cNewLabelNo
         SET @cOutField02 = ''
      END -- back to new carton type screen
      ELSE IF @nFromScn = 6491 AND @nFromStep = 2
      BEGIN
         --Back to screen 2
         --SET @nCartonNo    = 0
         --SET @cLabelNo     = ''
         SET @cCustomNo    = ''
         SET @cCustomID    = ''
         SET @nCartonSKU   = 0
         SET @nCartonQTY   = 0
         SET @nTotalCarton = 0
         SET @nTotalPick   = 0
         SET @nTotalPack   = 0
         SET @nTotalShort  = 0

         -- Get task
         EXEC rdt.rdt_Pack_LVSUSA_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CURRENT'
            ,@cPickSlipNo
            ,@cFromDropID
            ,@cPackDtlDropID
            ,@nCartonNo       OUTPUT
            ,@cMasterLabelNo  OUTPUT
            ,@cCustomNo       OUTPUT
            ,@cCustomID       OUTPUT
            ,@nCartonSKU      OUTPUT
            ,@nCartonQTY      OUTPUT
            ,@nTotalCarton    OUTPUT
            ,@nTotalPick      OUTPUT
            ,@nTotalPack      OUTPUT
            ,@nTotalShort     OUTPUT
            ,@nErrNo          OUTPUT
            ,@cErrMsg         OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Prepare next screen var
         SET @cOutField01 = @cMasterLabelNo
         SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(8))  
         SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(8))  
         SET @cOutField04 = CAST( @nTotalShort AS NVARCHAR(8)) 
         SET @cOutField05 = CAST( @nCartonSKU AS NVARCHAR(5))
         SET @cOutField06 = CAST( @nCartonQTY AS NVARCHAR(5))
         SET @cOutField09 = @cDefaultOption

         /*
         SET @cOutField05 = ''--RTRIM( @cCustomNo) + '/' + CAST( @nTotalCarton AS NVARCHAR(5))
         SET @cOutField06 = ''--@cCustomID
         SET @cOutField07 = CAST( @nCartonSKU AS NVARCHAR(5))
         SET @cOutField08 = CAST( @nCartonQTY AS NVARCHAR(5))
         SET @cOutField09 = @cDefaultOption
         */  

      END -- back to statistic screen

      -- Back to the previous screen
      SET @nScn = @nFromScn
      SET @nStep = @nFromStep

      SET @nFromScn = 0
      SET @nFromStep = 0
      
   END --ESC

END --step6
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

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,
      -- UserName       = @cUserName,
      Printer_Paper  = @cPaperPrinter,
      Printer        = @cLabelPrinter,

      V_PickSlipNo   = @cPickSlipNo,
      V_SKU          = @cSKU,
      V_QTY          = @nQTY,
      V_CaseID       = @cCustomID,
      V_SKUDescr     = @cSKUDescr,
      V_FromScn      = @nFromScn,
      V_FromStep     = @nFromStep,
      V_UOM          = @cPUOM,

      V_String1      = @cPackDtlRefNo,
      V_String2      = @cPackDtlRefNo2,
      V_String3      = @cMasterLabelNo, --fcr-946
      V_String4      = @cCartonType,
      V_String5      = @cCube,
      V_String6      = @cWeight,
      V_String7      = @cRefNo,
      V_String8      = @cLabelLine,
      V_String9      = @cPackDtlDropID,
      V_String10     = @cUCCCounter,
      V_String11     = @cMUOM_Desc,
      V_String12     = @cPUOM_Desc,
      V_String13     = @cDisableQTYFieldSP,
      V_String14     = @cFlowThruScreen, 

      V_CartonNo     = @nCartonNo,
      V_Integer1     = @nCartonSKU,
      V_Integer2     = @nCartonQTY,
      V_Integer3     = @nTotalCarton,
      V_Integer4     = @nTotalPick,
      V_Integer5     = @nTotalPack,
      V_Integer6     = @nTotalShort,
      V_Integer7     = @nPackedQTY,
      V_Integer8     = @nPUOM_Div,
      V_Integer9     = @nPQTY,
      V_Integer10    = @nMQTY,
      V_Integer11    = @nEnter,     --(cc01)
      V_Integer12    = @nSKURank, --fcr-946  

      V_String15     = @cShowPickSlipNo,
      V_String16     = @cDefaultPrintLabelOption,
      V_String17     = @cDefaultPrintPackListOption,
      V_String18     = @cDefaultWeight,
      V_String19     = @cUCCNo,
      V_String20     = @cFromLabelNo,
      V_String21     = @cExtendedValidateSP,
      V_String22     = @cExtendedUpdateSP,
      V_String23     = @cExtendedInfoSP,
      V_String24     = @cExtendedInfo,
      V_String25     = @cDecodeSP,
      V_String26     = @cDisableQTYField,
      V_String27     = @cCapturePackInfoSP,
      --V_String28     = @cPackInfo,
      V_String29     = @cAllowWeightZero,
      V_String30     = @cAllowCubeZero,
      --V_String31     = @cAutoScanIn,
      V_String32     = @cDefaultOption,
      V_String33     = @cDisableOption,
      --V_String34     = @cSerialNoCapture,
      V_String35     = @cPackList,
      V_String36     = @cShipLabel,
      V_String37     = @cCartonManifest,
      --V_String38     = @cCustomCartonNo,
      --V_String39     = @cCustomNo,
      V_String40     = @cDataCaptureSP,
      V_String41     = @cPackDtlUPC,
      --V_String42     = @cPrePackIndicator,
      --V_String43     = @cPackQtyIndicator,
      V_String44     = @cPackData1,
      V_String45     = @cPackData2,
      V_String46     = @cPackData3,
      V_String47     = @cFromLabelNo, -- fcr-946
      V_String48     = @cDefaultQTY, --(cc01)
      V_String49     = @cDefaultcartontype,
      V_String50     = @cNewLabelNo, --fcr-946

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