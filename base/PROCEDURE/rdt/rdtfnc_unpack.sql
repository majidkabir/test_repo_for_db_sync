SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdtfnc_Unpack                                          */
/* Copyright      : LFLogistics                                            */
/*                                                                         */
/* Date         Rev  Author     Purposes                                   */
/* 2017-05-30   1.0  Ung        WMS-1919 Created                           */
/* 2018-10-08   1.1  Gan        Performance tuning                         */
/* 2020-04-27   1.2  James      WMS-13005 Add ExtendedUpdateSP (james01)   */
/* 2020-04-27   1.2  James      WMS-13276 Add ExtendedValidateSP (james02) */
/***************************************************************************/

CREATE PROC [RDT].[rdtfnc_Unpack] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 VARCHAR max
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @bSuccess       INT,
   @cOption        NVARCHAR( 1),
   @cSQL           NVARCHAR( MAX),
   @cSQLParam      NVARCHAR( MAX)
   
-- RDT.RDTMobRec variables
DECLARE
   @nFunc          INT,
   @nScn           INT,
   @nStep          INT,
   @cLangCode      NVARCHAR( 3),
   @nInputKey      INT,
   @nMenu          INT,

   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cUserName      NVARCHAR( 18),

   @cLoadKey       NVARCHAR( 10),
   @cOrderKey      NVARCHAR( 10),
   @cPickSlipNo    NVARCHAR( 10),
   @cPickZone      NVARCHAR( 10),
   @cFromSKU       NVARCHAR( 20),
   @nQTY           INT,
   @cSKUDescr      NVARCHAR( 60),
   @cCartonID      NVARCHAR( 20),

   @cFromDropID    NVARCHAR( 20),
   @cFromCartonNo  NVARCHAR( 5),
   @cLabelNo       NVARCHAR( 20),
   @cType          NVARCHAR( 10), 

   @nCartonNo      INT, 
   @nCartonSKU     INT, 
   @nCartonQTY     INT, 
   @nTotalCarton   INT, 
   @nTotalPick     INT, 
   @nTotalPack     INT, 
   @nTotalShort    INT, 
   @nPackedQTY     INT, 
   
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cDecodeSP           NVARCHAR( 20),
   @cUnpackConfirm      NVARCHAR( 1),
   @tExtUpdate          VARIABLETABLE,
   @tExtValidate        VARIABLETABLE,

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

   @cFacility        = Facility,
   @cStorerKey       = StorerKey,
   @cUserName        = UserName,
   
   @cLoadKey         = V_LoadKey,
   @cOrderKey        = V_OrderKey,
   @cPickZone        = V_Zone, 
   @cPickSlipNo      = V_PickSlipNo,
   @cFromSKU         = V_SKU,
   @nQTY             = V_QTY,
   @cSKUDescr        = V_SKUDescr,
   @cCartonID        = V_CaseID, 
   
   @nCartonNo        = V_Cartonno,
   
   @nCartonSKU       = V_Integer1,
   @nCartonQTY       = V_Integer2,
   @nTotalCarton     = V_Integer3,
   @nTotalPick       = V_Integer4,
   @nTotalPack       = V_Integer5,
   @nTotalShort      = V_Integer6,
   @nPackedQTY       = V_Integer7,

   @cFromDropID      = V_String1,
   @cFromCartonNo    = V_String2,
   @cLabelNo         = V_String3,
   @cType            = V_String9,
  
   --@nCartonNo        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String11, 5), 0) = 1 THEN LEFT( V_String11, 5) ELSE 0 END, 
   --@nCartonSKU       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String12, 5), 0) = 1 THEN LEFT( V_String12, 5) ELSE 0 END, 
  -- @nCartonQTY       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String13, 5), 0) = 1 THEN LEFT( V_String13, 5) ELSE 0 END, 
  -- @nTotalCarton     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String14, 5), 0) = 1 THEN LEFT( V_String14, 5) ELSE 0 END, 
  -- @nTotalPick       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15, 5), 0) = 1 THEN LEFT( V_String15, 5) ELSE 0 END, 
  -- @nTotalPack       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String16, 5), 0) = 1 THEN LEFT( V_String16, 5) ELSE 0 END, 
  -- @nTotalShort      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String17, 5), 0) = 1 THEN LEFT( V_String17, 5) ELSE 0 END, 
  -- @nPackedQTY       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String18, 5), 0) = 1 THEN LEFT( V_String18, 5) ELSE 0 END, 

   @cExtendedValidateSP = V_String21,
   @cExtendedUpdateSP   = V_String22,
   @cExtendedInfoSP     = V_String23,
   @cExtendedInfo       = V_String24,
   @cDecodeSP           = V_String25,
   @cUnpackConfirm      = V_String26,

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

IF @nFunc = 837 -- Pack
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0  -- Menu. Func = 837
   IF @nStep = 1  GOTO Step_1  -- Scn = 4920. PickSlipNo, FromDropID, SKU
   IF @nStep = 2  GOTO Step_2  -- Scn = 4921. Statistic
   IF @nStep = 3  GOTO Step_3  -- Scn = 4922. Confrim repack?
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step_0. Func = 837
********************************************************************************/
Step_0:
BEGIN
   -- Get storer configure
   SET @cUnpackConfirm = rdt.RDTGetConfig( @nFunc, 'UnpackConfirm', @cStorerKey)

   SET @cDecodeSP = rdt.rdtGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
      
   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep

   SET @cPickSlipNo   = ''
   SET @cFromDropID   = ''
   SET @cFromCartonNo = ''
   SET @cFromSKU      = ''

   -- Prepare next screen var
   SET @cOutField01 = '' -- PickSlipNo
   SET @cOutField02 = '' -- FromDropID
   SET @cOutField03 = '' -- FromSKU
   SET @cOutField04 = '' -- FromCartonNo
   
   EXEC rdt.rdtSetFocusField @nMobile, 1  -- PickSlipNo
   
   -- Go to PickSlipNo screen
   SET @nScn = 4920
   SET @nStep = 1
END
GOTO Quit


/************************************************************************************
Scn = 4920. PickSlipNo screen
   PSNO        (field01, input)
   CARTONNO    (field02, input)
   SKU         (field03, input)
   FROMDROPID  (field04, input)
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cRemainInScreen NVARCHAR(1)
      DECLARE @cBarcode NVARCHAR(60)
      DECLARE @cUPC NVARCHAR(30)
      
      -- Retain key-in value
      SET @cOutField01 = @cInField01
      SET @cOutField02 = @cInField02
      SET @cOutField03 = @cInField03
      SET @cOutField04 = @cInField04

      -- Validate if anything changed
      IF @cPickSlipNo   <> @cInField01 OR
         @cFromDropID   <> @cInField02 OR
         @cFromCartonNo <> @cInField03 OR
         @cFromSKU      <> @cInField04 
      BEGIN
         -- There are changes, remain in current screen
         SET @cRemainInScreen = 'Y'
      END
          
      -- Screen mapping
      SET @cPickSlipNo = @cInField01
      SET @cFromDropID = @cInField02
      SET @cFromCartonNo = @cInField03
      SET @cFromSKU = @cInField04
      
      SET @cBarcode = @cInField04
      SET @cUPC = LEFT( @cInField04, 30)

      -- Check blank
      IF @cPickSlipNo = '' AND @cFromDropID = '' 
      BEGIN
         SET @nErrNo = 110501
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PS/DropID
         GOTO Quit
      END
      
      -- Lookup PickSlipNo
      IF @cFromDropID <> '' AND @cPickSlipNo = ''
      BEGIN
         -- Get discrete pick slip
         SELECT TOP 1 
            @cPickSlipNo = PickSlipNo
         FROM PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND DropID = @cFromDropID
         ORDER BY AddDate DESC
         
         IF @cPickSlipNo = ''
         BEGIN
            SET @nErrNo = 110516
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDNotFound
            EXEC rdt.rdtSetFocusField @nMobile, 2  -- FromDropID
            SET @cOutField02 = ''
            GOTO Quit
         END

         SET @cInField01 = @cPickSlipNo
      END

      -- Check blank
      IF @cPickSlipNo = ''
      BEGIN
         SET @nErrNo = 110502
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PSNO required
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- PickSlipNo
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Get PackHeader info
      DECLARE @cChkStorerKey NVARCHAR(15)
      DECLARE @cChkStatus NVARCHAR(1)
      SELECT 
         @cChkStorerKey = StorerKey, 
         @cChkStatus = Status
      FROM PackHeader WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo 
      
      -- Check PickSlipNo valid
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 110503
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- PickSlipNo
         SET @cOutField01 = ''
         GOTO Quit
      END
      
      -- Check PickSlip different storer
      IF @cChkStorerKey <> @cStorerKey
      BEGIN
         SET @nErrNo = 110504
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- PickSlipNo
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check pack confirmed
      IF @cChkStatus = '9'
      BEGIN
         -- Auto scan-in
         IF @cUnpackConfirm <> '1'
         BEGIN
            SET @nErrNo = 110505
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pack Confirmed
            EXEC rdt.rdtSetFocusField @nMobile, 1  -- PickSlipNo
            SET @cOutField01 = ''
            GOTO Quit
         END
      END
      SET @cOutField01 = @cPickSlipNo
      
      -- Check drop ID
      IF @cFromDropID <> ''
      BEGIN
         -- Check FromDropID format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'FROMDROPID', @cFromDropID) = 0
         BEGIN
            SET @nErrNo = 110506
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 2  -- ToDropID
            SET @cOutField02 = ''
            GOTO Quit
         END
         
         -- Check DropID in pickslip
         IF NOT EXISTS( SELECT TOP 1 1 FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND DropID = @cFromDropID)
         BEGIN
            SET @nErrNo = 110507
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDNotInPS
            EXEC rdt.rdtSetFocusField @nMobile, 2  -- ToDropID
            SET @cOutField02 = ''
            GOTO Quit
         END
      END
      SET @cOutField02 = @cFromDropID
      
      -- Check carton no
      IF @cFromCartonNo <> ''
      BEGIN
         IF RDT.rdtIsValidQTY( @cFromCartonNo, 1) = 0 --Check zero
         BEGIN
            SET @nErrNo = 110508
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CartonNo
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- FromCartonNo
            SET @cOutField03 = ''
            GOTO Quit
         END
         
         -- Check carton no in PickSlip
         IF NOT EXISTS( SELECT TOP 1 1 FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @cFromCartonNo)
         BEGIN
            SET @nErrNo = 110509
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CTN not in PS
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- FromCartonNo
            SET @cOutField03 = ''
            GOTO Quit
         END
      END
      SET @cOutField03 = @cFromCartonNo
      
      -- Check SKU
      IF @cBarcode <> ''
      BEGIN
         -- Decode
         IF @cDecodeSP <> ''
         BEGIN
            -- Standard decode
            IF @cDecodeSP = '1'
            BEGIN
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
                  @cUPC    = @cUPC       OUTPUT, 
                  @nErrNo  = @nErrNo     OUTPUT, 
                  @cErrMsg = @cErrMsg    OUTPUT
               IF @nErrNo <> 0
               BEGIN
                  EXEC rdt.rdtSetFocusField @nMobile, 4 -- FromSKU
                  SET @cOutField04 = ''
                  GOTO Quit
               END
            END
            
            -- Customize decode
            ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cBarcode, ' +
                  ' @cSKU OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  ' @nMobile      INT,           ' +
                  ' @nFunc        INT,           ' +
                  ' @cLangCode    NVARCHAR( 3),  ' +
                  ' @nStep        INT,           ' +
                  ' @nInputKey    INT,           ' +
                  ' @cFacility    NVARCHAR( 5),  ' +
                  ' @cStorerKey   NVARCHAR( 15), ' +
                  ' @cPickSlipNo  NVARCHAR( 10), ' +
                  ' @cFromDropID  NVARCHAR( 20), ' +
                  ' @cBarcode     NVARCHAR( 60), ' +
                  ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
                  ' @nErrNo       INT            OUTPUT, ' +
                  ' @cErrMsg      NVARCHAR( 20)  OUTPUT'
   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cBarcode, 
                  @cUPC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
               IF @nErrNo <> 0
               BEGIN
                  EXEC rdt.rdtSetFocusField @nMobile, 4 -- FromSKU
                  SET @cOutField04 = ''
                  GOTO Quit
               END
            END
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
            SET @nErrNo = 110510
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- FromSKU
            SET @cOutField04 = ''
            GOTO Quit
         END
   
         -- Check barcode return multi SKU
         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 110511
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- FromSKU
            SET @cOutField04 = ''
            GOTO Quit
         END

         IF @nSKUCnt = 1
            EXEC rdt.rdt_GetSKU
                @cStorerKey  = @cStorerKey
               ,@cSKU        = @cUPC      OUTPUT
               ,@bSuccess    = @bSuccess  OUTPUT
               ,@nErr        = @nErrNo    OUTPUT
               ,@cErrMsg     = @cErrMsg   OUTPUT
         
         SET @cFromSKU = @cUPC

         -- Check SKU in PickSlipNo
         IF NOT EXISTS( SELECT TOP 1 1 FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND StorerKey = @cStorerKey AND SKU = @cFromSKU)
         BEGIN
            SET @nErrNo = 110512
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not in PS
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- FromSKU
            SET @cOutField04 = ''
            GOTO Quit
         END
      END
      SET @cOutField04 = @cFromSKU
      
      -- Remain in current screen
      IF @cRemainInScreen = 'Y'
      BEGIN
         -- Position cursor on next empty field
         IF @cInField01 = '' EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE 
         IF @cInField02 = '' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE 
         IF @cInField03 = '' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE 
         IF @cInField04 = '' EXEC rdt.rdtSetFocusField @nMobile, 4 
         GOTO Quit
      END
      
      SET @nCartonNo    = 0
      SET @cLabelNo     = ''
      SET @cCartonID    = ''
      SET @nCartonSKU   = 0
      SET @nCartonQTY   = 0
      SET @nTotalCarton = 0
      SET @nTotalPick   = 0
      SET @nTotalPack   = 0
      SET @nTotalShort  = 0

      -- Get task
      EXEC rdt.rdt_Unpack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CURRENT'
         ,@cPickSlipNo
         ,@cFromDropID
         ,@cFromSKU
         ,@cFromCartonNo
         ,@nCartonNo    OUTPUT
         ,@cLabelNo     OUTPUT
         ,@cCartonID    OUTPUT
         ,@nCartonSKU   OUTPUT
         ,@nCartonQTY   OUTPUT
         ,@nTotalCarton OUTPUT
         ,@nTotalPick   OUTPUT
         ,@nTotalPack   OUTPUT
         ,@nTotalShort  OUTPUT
         ,@nErrNo       OUTPUT
         ,@cErrMsg      OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
      
      -- Check QTY to unpack
      IF @nCartonQTY = 0
      BEGIN
         SET @nErrNo = 110517
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY not found
         GOTO Quit
      END

      -- Prepare next screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(5))
      SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(5))
      SET @cOutField04 = CAST( @nTotalShort AS NVARCHAR(5))
      SET @cOutField05 = CAST( @nCartonNo AS NVARCHAR(5)) + '/' + CAST( @nTotalCarton AS NVARCHAR(5))
      SET @cOutField06 = @cCartonID
      SET @cOutField07 = CAST( @nCartonSKU AS NVARCHAR(5))
      SET @cOutField08 = CAST( @nCartonQTY AS NVARCHAR(5))
      SET @cOutField09 = '' -- Option
      
      -- Go to statistic screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
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
Scn = 4921. Statistic screen
   OPTION    (field09, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cType = @cInField09

      -- Loop blank
      IF @cType = ''
      BEGIN
         -- Get task
         EXEC rdt.rdt_Unpack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXT'
            ,@cPickSlipNo
            ,@cFromDropID
            ,@cFromSKU
            ,@cFromCartonNo
            ,@nCartonNo    OUTPUT
            ,@cLabelNo     OUTPUT
            ,@cCartonID    OUTPUT
            ,@nCartonSKU   OUTPUT
            ,@nCartonQTY   OUTPUT
            ,@nTotalCarton OUTPUT
            ,@nTotalPick   OUTPUT
            ,@nTotalPack   OUTPUT
            ,@nTotalShort  OUTPUT
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
   
         -- Prepare next screen var
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(5))
         SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(5))
         SET @cOutField04 = CAST( @nTotalShort AS NVARCHAR(5))
         SET @cOutField05 = CAST( @nCartonNo AS NVARCHAR(5)) + '/' + CAST( @nTotalCarton AS NVARCHAR(5))
         SET @cOutField06 = @cCartonID
         SET @cOutField07 = CAST( @nCartonSKU AS NVARCHAR(5))
         SET @cOutField08 = CAST( @nCartonQTY AS NVARCHAR(5))
         SET @cOutField09 = '' -- Option
         
         GOTO Quit
      END

      -- Validate option
      IF @cType <> '1' AND @cType <> '2'
      BEGIN
         SET @nErrNo = 110513
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         SET @cOutField08 = '' -- Option
         GOTO Quit
      END

      -- Get statistics
      DECLARE @nTotalCTN INT
      DECLARE @nTotalSKU INT
      DECLARE @nTotalQTY INT
      SELECT 
         @nTotalCTN = COUNT( DISTINCT PD.LabelNo), 
         @nTotalSKU = COUNT( DISTINCT PD.SKU), 
         @nTotalQTY = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND (@cFromCartonNo = '' OR CartonNo = @cFromCartonNo)
         AND (@cFromDropID = '' OR DropID = @cFromDropID)
         AND (@cFromSKU = '' OR SKU = @cFromSKU)
         AND (@cType = '2' OR CartonNo = @nCartonNo)

      -- Check QTY to unpack (could be unpacked by others)
      IF @nTotalQTY = 0
      BEGIN
         SET @nErrNo = 110518
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY not found
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- Option
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Prepare next screen var
      SET @cOutField01 = CAST( @nTotalCTN AS NVARCHAR( 5))
      SET @cOutField02 = CAST( @nTotalSKU AS NVARCHAR( 5))
      SET @cOutField03 = CAST( @nTotalQTY AS NVARCHAR( 5))
      SET @cOutField04 = '' -- Option

      -- Go to repack screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = '' -- PickSlipNo
      SET @cOutField02 = '' -- FromDropID
      SET @cOutField03 = '' -- FromSKU
      SET @cOutField04 = '' -- FromCartonNo
      
      IF @cFromDropID <> ''
         EXEC rdt.rdtSetFocusField @nMobile, 2  -- FromDropID
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- PickSlipNo

      SET @cPickSlipNo   = ''
      SET @cFromDropID   = ''
      SET @cFromCartonNo = ''
      SET @cFromSKU      = ''
      
      -- Go to PickSlipNo screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Scn = 4922. Confirm repack?
   Option (field04, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField04

      -- Validate blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 110514
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionRequired
         GOTO Quit
      END

      -- Validate option
      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 110515
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- Option
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- (james02)
      -- Extended updatedate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cPickSlipNo, @cFromDropID, @cFromSKU, @nCartonNo, @cLabelNo, @cType, @cOption, ' + 
               ' @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT '

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
               ' @cFromSKU       NVARCHAR( 20), ' +
               ' @nCartonNo      INT, ' +
               ' @cLabelNo       NVARCHAR( 20), ' +
               ' @cType          NVARCHAR( 10), ' +
               ' @cOption        NVARCHAR( 1),  ' +
               ' @tExtValidate   VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cPickSlipNo, @cFromDropID, @cFromSKU, @nCartonNo, @cLabelNo, @cType, @cOption, 
               @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Quit
         END
      END
      
      DECLARE @nTranCount  INT
      SET @nTranCount = @@TRANCOUNT

      BEGIN TRAN
      SAVE TRAN rdt_Unpack_Confirm -- For rollback or commit only our own transaction
      
      IF @cOption = '1'  -- Yes
      BEGIN
         -- Unpack current
         IF @cType = '1' 
            EXEC rdt.rdt_Unpack_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
               ,@cPickSlipNo
               ,@cFromDropID
               ,@cFromSKU
               ,@nCartonNo
               ,@cLabelNo
               ,@nErrNo
               ,@cErrMsg

         -- Unpack all
         IF @cType = '2' 
            EXEC rdt.rdt_Unpack_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
               ,@cPickSlipNo
               ,@cFromDropID
               ,@cFromSKU
               ,@cFromCartonNo -- Could have value
               ,'' -- @cLabelNo
               ,@nErrNo
               ,@cErrMsg
         IF @nErrNo <> 0
            GOTO RollBackTran
      END
      
      -- (james01)
      -- Extended updatedate
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            IF @cType = '2'
            BEGIN
               SET @nCartonNo = CAST( @cFromCartonNo AS INT)
               SET @cLabelNo = ''
            END
            
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cPickSlipNo, @cFromDropID, @cFromSKU, @nCartonNo, @cLabelNo, ' + 
               ' @tExtUpdate, @nErrNo OUTPUT, @cErrMsg OUTPUT '

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
               ' @cFromSKU       NVARCHAR( 20), ' +
               ' @nCartonNo      INT, ' +
               ' @cLabelNo       NVARCHAR( 20), ' +
               ' @tExtUpdate     VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cPickSlipNo, @cFromDropID, @cFromSKU, @nCartonNo, @cLabelNo,  
               @tExtUpdate, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO RollBackTran
         END
      END
      
      COMMIT TRAN rdt_Unpack_Confirm
      GOTO Quit_rdt_Unpack_Confirm

      RollBackTran:
         ROLLBACK TRAN rdt_Unpack_Confirm -- Only rollback change made here
      Quit_rdt_Unpack_Confirm:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
   END
   
   -- Get statistics
   EXEC rdt.rdt_Unpack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXT'
      ,@cPickSlipNo
      ,@cFromDropID
      ,@cFromSKU
      ,@cFromCartonNo
      ,@nCartonNo    OUTPUT
      ,@cLabelNo     OUTPUT
      ,@cCartonID    OUTPUT
      ,@nCartonSKU   OUTPUT
      ,@nCartonQTY   OUTPUT
      ,@nTotalCarton OUTPUT
      ,@nTotalPick   OUTPUT
      ,@nTotalPack   OUTPUT
      ,@nTotalShort  OUTPUT
      ,@nErrNo       OUTPUT
      ,@cErrMsg      OUTPUT
   IF @nErrNo <> 0
      GOTO Quit

   -- Prepare current screen var
   SET @cOutField01 = @cPickSlipNo
   SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(5))
   SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(5))
   SET @cOutField04 = CAST( @nTotalShort AS NVARCHAR(5))
   SET @cOutField05 = CAST( @nCartonNo AS NVARCHAR(5)) + '/' + CAST( @nTotalCarton AS NVARCHAR(5))
   SET @cOutField06 = @cCartonID
   SET @cOutField07 = CAST( @nCartonSKU AS NVARCHAR(5))
   SET @cOutField08 = CAST( @nCartonQTY AS NVARCHAR(5))
   SET @cOutField09 = '' -- Type

   -- Go to statistic screen
   SET @nScn = @nScn - 1
   SET @nStep = @nStep - 1
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

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,
   
      V_LoadKey      = @cLoadKey,
      V_OrderKey     = @cOrderKey,
      V_PickSlipNo   = @cPickSlipNo,
      V_Zone         = @cPickZone, 
      V_SKU          = @cFromSKU,
      V_QTY          = @nQTY,
      V_CaseID       = @cCartonID, 
      V_SKUDescr     = @cSKUDescr,
      
      V_Cartonno     = @nCartonNo,
   
      V_Integer1     = @nCartonSKU,
      V_Integer2     = @nCartonQTY,
      V_Integer3     = @nTotalCarton,
      V_Integer4     = @nTotalPick,
      V_Integer5     = @nTotalPack,
      V_Integer6     = @nTotalShort,
      V_Integer7     = @nPackedQTY,

      V_String1      = @cFromDropID,
      V_String2      = @cFromCartonNo,
      V_String3      = @cLabelNo,
      V_String9      = @cType,

      --V_String11     = @nCartonNo, 
      --V_String12     = @nCartonSKU, 
      --V_String13     = @nCartonQTY, 
      --V_String14     = @nTotalCarton, 
      --V_String15     = @nTotalPick, 
      --V_String16     = @nTotalPack, 
      --V_String17     = @nTotalShort, 
      --V_String18     = @nPackedQTY, 
      
      V_String21     = @cExtendedValidateSP,
      V_String22     = @cExtendedUpdateSP, 
      V_String23     = @cExtendedInfoSP, 
      V_String24     = @cExtendedInfo, 
      V_String25     = @cDecodeSP, 
      V_String26     = @cUnpackConfirm,

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