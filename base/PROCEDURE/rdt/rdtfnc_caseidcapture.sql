SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_CaseIDCapture                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2006-11-09   1.0  Ung        SOS305459 Created                       */
/* 2016-09-30   1.1  Ung        Performance tuning                      */
/* 2017-03-27   1.2  Ung        WMS-1373 Add pallet ID                  */
/* 2018-05-02   1.3  Ung        WMS-4846 Add DecodeSP                   */
/*                              CodeLKUP MHCSSCAN add StorerKey         */
/* 2018-10-16   1.4  TungGH     Performance                             */
/* 2018-10-10   1.5  Ung        WMS-6576 Add inner barcode              */
/* 2023-02-16   1.6  WyeChun    JSM-129049 Extend oField09 (20)         */  
/*                              and CaseID (18) length to 40 to store   */  
/*                              the proper barcode (WC01)               */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_CaseIDCapture] (
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
   @nScan          INT,
   @nTotal         INT, 
   @bSuccess       INT, 
   @nSKUCnt        INT,
   @cBrand         NVARCHAR(10), 
   @cSQL           NVARCHAR(MAX), 
   @cSQLParam      NVARCHAR(MAX)

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

   @cPickSlipNo    NVARCHAR( 10),
   @cOrderKey      NVARCHAR( 10),
   @cSKU           NVARCHAR( 20),
   @cSKUDescr      NVARCHAR( 60),
   @cBatchNo       NVARCHAR( 18),
   @cCaseID        NVARCHAR( 40), --WC01 
   @cBarcode       NVARCHAR( MAX),
   
   @cDecodeLabelNo      NVARCHAR( 20),
   @cDecodeSP           NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),

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

   @cPickSlipNo      = V_PickSlipNo,
   @cOrderKey        = V_OrderKey, 
   @cSKU             = V_SKU,
   @cSKUDescr        = V_SKUDescr,
   @cBatchNo         = V_Lottable02,
   @cCaseID          = V_Lottable03,
   @cBarcode         = V_MAX, 

   @cDecodeLabelNo      = V_String1,
   @cDecodeSP           = V_String2,
   @cExtendedValidateSP = V_String3,

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

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 877
BEGIN  
   -- Redirect to respective screen  
   IF @nStep = 0  GOTO Step_0  -- Menu. Func = 619
   IF @nStep = 1  GOTO Step_1  -- Scn = 3780. PickSlipNo  
   IF @nStep = 2  GOTO Step_2  -- Scn = 3781. Barcode
   IF @nStep = 3  GOTO Step_3  -- Scn = 3782. SKU
   IF @nStep = 4  GOTO Step_4  -- Scn = 3783. Batch no, Case ID
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 619. Menu
********************************************************************************/
Step_0:
BEGIN
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep

   -- Storer config
   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''
   SET @cDecodeSP = rdt.rdtGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
      
   -- Prepare next screen var
   SET @cOutField01 = '' -- PickSlipNo

   -- Enable all fields
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

   -- Set the entry point
   SET @nScn = 3780
   SET @nStep = 1
END
GOTO Quit


/************************************************************************************
Scn = 3780. PickSlipNo
   PSNO    (field01)
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPickSlipNo = @cInField01

      -- Validate blank PickSlipNo
      IF @cPickSlipNo = ''
      BEGIN
         SET @nErrNo = 85751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PSNO required
         GOTO Step_1_Fail
      END

      DECLARE @cChkStorerKey  NVARCHAR( 15)
      DECLARE @cChkStatus     NVARCHAR( 10)
      DECLARE @dScanInDate    DATETIME
      DECLARE @dScanOutDate   DATETIME

      -- Get PickHeader info
      SELECT @cOrderKey = OrderKey
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo

      -- Validate pickslipno
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 85752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid PSNO
         GOTO Step_1_Fail
      END

      -- Validate PickSlip type
      IF @cOrderKey IS NULL OR @cOrderKey = ''
      BEGIN
         SET @nErrNo = 85753
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Bad PSNO type
         GOTO Step_1_Fail
      END

      -- Get Order info
      SELECT 
         @cChkStorerKey = StorerKey, 
         @cChkStatus = Status
      FROM dbo.Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      -- Validate storerkey
      IF @cChkStorerKey <> @cStorerKey
      BEGIN
         SET @nErrNo = 85754
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Diff storer
         GOTO Step_1_Fail
      END

      -- Validate status
      IF @cChkStatus = '9'
      BEGIN
         SET @nErrNo = 85755
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Order Shipped
         GOTO Step_1_Fail
      END

      -- Get picking info
      SELECT TOP 1
         @dScanInDate = ScanInDate,
         @dScanOutDate = ScanOutDate
      FROM dbo.PickingInfo WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo

      -- Auto scan-in
      IF @dScanInDate IS NULL
      BEGIN
         INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID)
         VALUES (@cPickSlipNo, GETDATE(), SUSER_SNAME())
         IF @@ERROR <> 0      
         BEGIN
            SET @nErrNo = 85756
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PS scanin fail
            GOTO Step_1_Fail
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cOrderKey, @cBarcode, @cSKU, @cBatchNo, @cCaseID, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,            ' +
               '@nFunc        INT,            ' +
               '@cLangCode    NVARCHAR( 3),   ' +
               '@nStep        INT,            ' +
               '@nInputKey    INT,            ' +
               '@cFacility    NVARCHAR( 5),   ' + 
               '@cStorerKey   NVARCHAR( 15),  ' +
               '@cPickSlipNo  NVARCHAR( 10),  ' +
               '@cOrderKey    NVARCHAR( 10),  ' +
               '@cBarcode     NVARCHAR( MAX), ' +
               '@cSKU         NVARCHAR( 18),  ' +
               '@cBatchNo     NVARCHAR( 18),  ' +
               '@cCaseID      NVARCHAR( 40),  ' +  --WC01 
               '@nErrNo       INT            OUTPUT, ' +
               '@cErrMsg      NVARCHAR( 20)  OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cOrderKey, @cBarcode, @cSKU, @cBatchNo, @cCaseID, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_1_Fail 
         END
      END

      -- Calc statistic
      EXEC rdt.rdt_CaseIDCapture_GetStat @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerkey
         ,@cOrderKey
         ,@nScan     OUTPUT
         ,@nTotal    OUTPUT

      SET @cBarcode = ''

      -- Prepare next screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = '' -- Barcode
      SET @cOutField03 = CAST( @nScan AS NVARCHAR( 5)) + '/' + CAST( @nTotal AS NVARCHAR( 5))

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-Out
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

   Step_1_Fail:
   BEGIN
      SET @cOutField01 = '' -- PSNO
   END
END
GOTO Quit


/***********************************************************************************
Scn = 3781. Barcode screen
   PSNO    (field01)
   BARCODE (field02, input)
***********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cPalletID NVARCHAR(18)

      -- Screen mapping
      -- SET @cBarcode = @cInField02 -- Barcode

      SET @cSKU = ''
      SET @cBatchNo = ''
      SET @cCaseID = ''
      SET @cPalletID = ''

      -- Validate blank
      IF @cBarcode = ''
      BEGIN
         -- Prepare SKU screen var
         SET @cOutField01 = '' -- SKU
         
         -- Go to SKU next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         GOTO Quit
      END

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'BARCODE', @cBarcode) = 0
      BEGIN
         SET @nErrNo = 85760
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_2_Fail
      END

      -- Label decoding
      IF @cDecodeLabelNo <> ''
      BEGIN
         DECLARE
            @c_oFieled01 NVARCHAR(60), @c_oFieled02 NVARCHAR(20),
            @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
            @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
            @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
            @c_oFieled09 NVARCHAR(40), @c_oFieled10 NVARCHAR(20)  --WC01

         -- Retain value
         SET @c_oFieled01 = @cBarcode
         SET @c_oFieled08 = @cBatchNo
         SET @c_oFieled09 = @cCaseID
         SET @c_oFieled10 = ''

         EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @cBarCode
            ,@c_Storerkey  = @cStorerKey
            ,@c_ReceiptKey = ''
            ,@c_POKey      = ''
            ,@c_LangCode   = @cLangCode
            ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
            ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
            ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
            ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
            ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
            ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#
            ,@c_oFieled07  = @c_oFieled07 OUTPUT   -- Lottable01
            ,@c_oFieled08  = @c_oFieled08 OUTPUT   -- Lottable02
            ,@c_oFieled09  = @c_oFieled09 OUTPUT   -- Lottable03
            ,@c_oFieled10  = @c_oFieled10 OUTPUT   -- Lottable04
            ,@b_Success    = @bSuccess    OUTPUT
            ,@n_ErrNo      = @nErrNo      OUTPUT
            ,@c_ErrMsg     = @cErrMsg     OUTPUT

         IF @cErrMsg <> ''
            GOTO Step_2_Fail

         SET @cSKU = @c_oFieled01
         SET @cBatchNo = @c_oFieled08
         SET @cCaseID = @c_oFieled09
         SET @cPalletID = @c_oFieled10
      END
      
      -- Customize decode
      ELSE IF @cDecodeSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cOrderKey, @cBarcode, ' +
               ' @cSKU OUTPUT, @cBatchNo OUTPUT, @cCaseID OUTPUT, @cPalletID OUTPUT, @nScan OUTPUT, @nTotal OUTPUT, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,            ' +
               ' @nFunc          INT,            ' +
               ' @cLangCode      NVARCHAR( 3),   ' +
               ' @nStep          INT,            ' +
               ' @nInputKey      INT,            ' +
               ' @cFacility      NVARCHAR( 5),   ' +
               ' @cStorerKey     NVARCHAR( 15),  ' +
               ' @cPickSlipNo    NVARCHAR( 10),  ' +
               ' @cOrderKey      NVARCHAR( 10),  ' +
               ' @cBarcode       NVARCHAR( MAX), ' +
               ' @cSKU           NVARCHAR( 20)  OUTPUT, ' +
               ' @cBatchNo       NVARCHAR( 18)  OUTPUT, ' +
               ' @cCaseID        NVARCHAR( 40)  OUTPUT, ' +    --WC01  
               ' @cPalletID      NVARCHAR( 18)  OUTPUT, ' +
               ' @nScan          INT            OUTPUT, ' +
               ' @nTotal         INT            OUTPUT, ' +
               ' @nErrNo         INT            OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cOrderKey, @cBarcode, 
               @cSKU OUTPUT, @cBatchNo OUTPUT, @cCaseID OUTPUT, @cPalletID OUTPUT, @nScan OUTPUT, @nTotal OUTPUT, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT 

            IF @nErrNo = -1 -- Remain in current screen
            BEGIN
               SET @cBarcode = ''
               
               -- Prepare next screen var
               SET @cOutField01 = @cPickSlipNo
               SET @cOutField02 = '' -- Barcode
               SET @cOutField03 = CAST( @nScan AS NVARCHAR( 5)) + '/' + CAST( @nTotal AS NVARCHAR( 5))
               
               GOTO Quit
            END

            IF @nErrNo <> 0
            BEGIN
               SET @cBarcode = ''
               GOTO Step_3_Fail
            END
         END
      END

      -- Decoded BatchNo and CaseID, but no SKU
      IF @cSKU = '' AND @cBatchNo <> '' AND @cCaseID <> ''
      BEGIN
         -- Prepare SKU screen var
         SET @cOutField01 = '' -- SKU
         
         -- Go to SKU next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         GOTO Quit
      END

      -- Capture pallet
      IF @cPalletID <> ''
      BEGIN
         -- Confirm pallet
         EXECUTE rdt.rdt_CaseIDCapture_ConfirmPallet @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey
            ,@cOrderKey
            ,@cPalletID
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT
         IF @nErrNo <> 0
            GOTO Step_2_Fail
      END
      
      -- Capture case
      ELSE 
      BEGIN
         -- Get SKU count
         EXEC RDT.rdt_GETSKUCNT
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cSKU
            ,@nSKUCnt     = @nSKUCnt       OUTPUT
            ,@bSuccess    = @bSuccess      OUTPUT
            ,@nErr        = @nErrNo        OUTPUT
            ,@cErrMsg     = @cErrMsg       OUTPUT
   
         -- Check SKU/UPC
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 85761
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            GOTO Step_2_Fail
         END
   
         -- Check multi SKU barcode
         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 85762
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
            GOTO Step_2_Fail
         END
   
         -- Get SKU code
         EXEC RDT.rdt_GETSKU
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cSKU          OUTPUT
            ,@bSuccess    = @bSuccess      OUTPUT
            ,@nErr        = @nErrNo        OUTPUT
            ,@cErrMsg     = @cErrMsg       OUTPUT
         
         -- Capture CaseID
         EXECUTE rdt.rdt_CaseIDCapture_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey
            ,@cOrderKey
            ,@cSKU
            ,@cBatchNo
            ,@cCaseID
            ,'' -- PalletID
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT
         IF @nErrNo <> 0
            GOTO Step_2_Fail
      END
   
      -- Calc statistic
      EXEC rdt.rdt_CaseIDCapture_GetStat @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerkey
         ,@cOrderKey
         ,@nScan     OUTPUT
         ,@nTotal    OUTPUT

      SET @cBarcode = ''

      -- Prepare next screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = '' -- Barcode
      SET @cOutField03 = CAST( @nScan AS NVARCHAR( 5)) + '/' + CAST( @nTotal AS NVARCHAR( 5))
      
      -- Go to next screen
      -- SET @nScn = @nScn + 1
      -- SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- PickSlip no CaseID to capture and no short pick
      IF NOT EXISTS( SELECT TOP 1 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Status = '4' AND QTY > 0) AND
         NOT EXISTS( SELECT TOP 1 1 
            FROM PickDetail PD WITH (NOLOCK) 
               JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
            WHERE PD.OrderKey = @cOrderKey 
               AND PD.UOM IN ('1', '2') 
               AND PD.DropID = '' -- not yet capture
               AND NOT EXISTS (SELECT 1 FROM CodeLkup WITH (NOLOCK) WHERE ListName = 'MHCSSCAN' AND Code = SKU.Class AND StorerKey = @cStorerKey)) -- Brand don't need capture case ID

      BEGIN
         -- Auto scan-out
         IF EXISTS( SELECT 1 FROM PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND ScanOutDate IS NULL) 
         BEGIN
            UPDATE PickingInfo SET 
               ScanOutDate = GETDATE(), 
               PickerID = SUSER_SNAME()
            WHERE PickSlipNo = @cPickSlipNo
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 85763
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PS ScanOutFail
               GOTO Step_1_Fail
            END
         END
      END
      
      -- Prepare prev screen var
      SET @cOutField01 = '' -- PSNO

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOutField02 = '' -- Barcode
   END
END
GOTO Quit


/********************************************************************************
Scn = 3782. SKU screen
   SKU/UPC   (field01, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField01

      -- Validate blank PickSlipNo
      IF @cSKU = ''
      BEGIN
         SET @nErrNo = 85764
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- SKU needed
         GOTO Step_3_Fail
      END

      -- Get SKU count
      EXEC RDT.rdt_GETSKUCNT
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Check SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 85765
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO Step_3_Fail
      END

      -- Check multi SKU barcode
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 85766
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
         GOTO Step_3_Fail
      END

      -- Get SKU code
      EXEC RDT.rdt_GETSKU
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU          OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Check SKU on PickSlip
      IF NOT EXISTS( SELECT TOP 1 1 
         FROM PickDetail WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey 
            AND SKU = @cSKU 
            AND UOM IN ('1', '2')
            AND Status <> '4' --Short
            AND QTY > 0)
      BEGIN
         SET @nErrNo = 85767
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotIn PSNO
         GOTO Step_3_Fail
      END
      
      -- Get SKU info
      SELECT 
         @cBrand = Class, 
         @cSKUDescr = Descr 
      FROM SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU
         
      -- Check brand need to capture
      IF EXISTS( SELECT 1 FROM CodeLkup WITH (NOLOCK) WHERE ListName = 'MHCSSCAN' AND Code = @cBrand AND StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 85768
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BrandNoCapture
         GOTO Step_3_Fail
      END

      -- Batch and case ID already capture in barcode screen
      IF @cBatchNo <> '' AND @cCaseID <> ''
      BEGIN
         -- Capture CaseID
         EXECUTE rdt.rdt_CaseIDCapture_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey
            ,@cOrderKey
            ,@cSKU
            ,@cBatchNo
            ,@cCaseID
            ,'' -- PalletID
            ,@nErrNo       OUTPUT
            ,@cErrMsg      OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
   
         -- Calc statistic
         EXEC rdt.rdt_CaseIDCapture_GetStat @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerkey
            ,@cOrderKey
            ,@nScan     OUTPUT
            ,@nTotal    OUTPUT
   
         -- Prepare Barcode screen var
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = '' -- Barcode
         SET @cOutField03 = CAST( @nScan AS NVARCHAR( 5)) + '/' + CAST( @nTotal AS NVARCHAR( 5))
   
         -- Go to Barcode screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
         
         GOTO Quit
      END
      
      -- Prepare QTY screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
      SET @cOutField04 = '' -- @cBatchNo
      SET @cOutField05 = '' -- @cCaseID

      -- Goto CaseID screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Calc statistic
      EXEC rdt.rdt_CaseIDCapture_GetStat @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerkey
         ,@cOrderKey
         ,@nScan     OUTPUT
         ,@nTotal    OUTPUT

      -- Prepare next screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = '' -- Barcode
      SET @cOutField03 = CAST( @nScan AS NVARCHAR( 5)) + '/' + CAST( @nTotal AS NVARCHAR( 5))

      -- Goto Barcode screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOutField01 = '' -- SKU
   END
END
GOTO Quit


/********************************************************************************
Scn = 3783. BatchNo, CaseID screen
   SKU       (field01)
   DESCR1    (field02)
   DESCR2    (field03)
   BATCHNO   (field04, input)
   CASEID    (field15, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cBatchNo = @cInField04
      SET @cCaseID  = @cInField05

      -- Retain key-in value
      SET @cOutField04 = @cInField04
      SET @cOutField05 = @cInField05

      -- Check blank
      IF @cCaseID = ''
      BEGIN
         SET @nErrNo = 85769
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CaseID
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- CaseID
         GOTO Quit
      END

      -- Check blank
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CASEID', @cCaseID) = 0
      BEGIN
         SET @nErrNo = 85770
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- CaseID
         GOTO Quit
      END
      
      -- Capture CaseID
      EXECUTE rdt.rdt_CaseIDCapture_Confirm @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey
         ,@cOrderKey
         ,@cSKU
         ,@cBatchNo
         ,@cCaseID
         ,'' -- PalletID
         ,@nErrNo       OUTPUT
         ,@cErrMsg      OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Calc statistic
      EXEC rdt.rdt_CaseIDCapture_GetStat @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerkey
         ,@cOrderKey
         ,@nScan     OUTPUT
         ,@nTotal    OUTPUT

      -- Prepare Barcode screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = '' -- Barcode
      SET @cOutField03 = CAST( @nScan AS NVARCHAR( 5)) + '/' + CAST( @nTotal AS NVARCHAR( 5))

      -- Go to Barcode screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Go to SKU screen
      SET @cOutField01 = '' -- SKU

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
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

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,
      -- UserName       = @cUserName,

      V_PickSlipNo   = @cPickSlipNo,
      V_OrderKey     = @cOrderKey, 
      V_SKU          = @cSKU,
      V_SKUDescr     = @cSKUDescr,
      V_Lottable02   = @cBatchNo,
      V_Lottable03   = @cCaseID, 
      V_MAX          = @cBarcode, 

      V_String1      = @cDecodeLabelNo,
      V_String2      = @cDecodeSP,
      V_String3      = @cExtendedValidateSP,

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