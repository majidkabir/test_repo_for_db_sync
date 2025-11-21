SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_Pack_SerialCapture                                */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#208973 - RDT Pack With Serial Capture                        */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2011-03-23 1.0  James    Created                                          */
/* 2011-06-08 1.1  James    Make Lot02 as NVARCHAR(9) by default (james01)   */
/* 2011-06-16 1.2  James    1. Add pallet outbound function                  */
/*                          2. Enhancements (james02)                        */
/* 2011-08-09 1.3  ChewKP   SOS#223053 Change Order Validation (ChewKP01)    */
/* 2011-08-16 1.4  James    SOS#223499 Bug fix on # of case calc (james03)   */
/* 2016-09-30 1.5  Ung      Performance tuning                               */
/* 2018-10-09 1.6  Gan      Performance tuning                               */
/*****************************************************************************/

CREATE PROC [RDT].[rdtfnc_Pack_SerialCapture](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- Misc variable
DECLARE
   @b_success           INT

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nMenu               INT,
   @nInputKey           NVARCHAR( 3),
   @cPrinter            NVARCHAR( 10),
   @cUserName           NVARCHAR( 18),
   @cPrinter_Paper      NVARCHAR( 10),

   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),

   @cOrderKey           NVARCHAR( 10),
   @cOrderLineNumber    NVARCHAR( 5),
   @cLoadKey            NVARCHAR( 10),
   @cPickSlipNo         NVARCHAR( 10),
   @cOption             NVARCHAR( 1),
   @cBatchNo            NVARCHAR( 20),
   @cSKU                NVARCHAR( 20),
   @cNewSKU             NVARCHAR( 20),
   @cDescr              NVARCHAR( 60),
   @c_ErrMsg            NVARCHAR( 20),
   @cCaseID             NVARCHAR( 30),
   @cPLTID              NVARCHAR( 30),
   @cBarcode            NVARCHAR( 30),
   @cBarcode1           NVARCHAR( 20),     -- used to store barcode into refno1
   @cBarcode2           NVARCHAR( 20),     -- used to store barcode into refno2
   @cBottleID           NVARCHAR( 30),
   @cLabelLine          NVARCHAR( 5),
   @cLabelNo            NVARCHAR( 20), 
   @cExternOrderKey     NVARCHAR( 20), 
   @cUPC                NVARCHAR( 30), 
   @cUPC_New            NVARCHAR( 30), 
   @cActQty             NVARCHAR( 5), 
   @cLottable02         NVARCHAR( 18), 
   @cDefaultQty         NVARCHAR( 5), 
   @cPackKey            NVARCHAR( 10), 

   @n_Err               INT,
   @nSKUCnt             INT, 
   @nQty                INT, 
   @nTTL_Case           INT, 
   @nCaseCnt            INT, 
   @nTTL_PIDQty         INT,
   @nTTL_PADQty         INT, 
   @nCartonNo           INT, 
   @nSKU_Qty            INT, 
   @nTTL_Qty            INT, 
   @nTTL_PLT            INT, 
   @nNextSeqNo          INT, 
   @nCount_SKU          INT, 
   @nPackDQty           INT, 
   @nActQty             INT, 
   @nLoop               INT, 
   @nUOM1Count          INT,  -- (james03)

   @cReportType         NVARCHAR( 10),
   @cPrintJobName       NVARCHAR( 50),
   @cDataWindow         NVARCHAR( 50),
   @cTargetDB           NVARCHAR( 10),

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
   @cLangCode        = Lang_code,
   @nMenu            = Menu,

   @cFacility        = Facility,
   @cStorerKey       = StorerKey,
   @cPrinter         = Printer,
   @cUserName        = UserName,
   @cPrinter_Paper   = Printer_Paper,

   @cLottable02      = V_Lottable02, 
   @cPickSlipNo      = V_PickSlipNo,
   @cOrderKey        = V_OrderKey,
   @cLoadKey         = V_LoadKey, 
   @cPickSlipNo      = V_PickSlipNo, 
   @cSKU             = V_SKU, 
   @cBarcode         = V_SKUDescr, 
   
   @nCartonNo        = V_Cartonno,
   
   @nCaseCnt         = V_Integer1,

   --@nCartonNo        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String1, 5), 0) = 1 THEN LEFT( V_String1, 5) ELSE 0 END,  
  -- @nCaseCnt         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String2, 5), 0) = 1 THEN LEFT( V_String2, 5) ELSE 0 END,  
   @cPackKey         = V_String3, 

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

FROM   RDT.RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile


-- Redirect to respective screen
IF @nFunc IN (620, 621) -- 620 = Case Packing; 621 = Piece Packing
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 620/621
   IF @nStep = 1 GOTO Step_1   -- Scn = 2760  Pickslip
   IF @nStep = 2 GOTO Step_2   -- Scn = 2761  Case ID, SKU, TTL Case
   IF @nStep = 3 GOTO Step_3   -- Scn = 2762  Case Not Exists
   IF @nStep = 4 GOTO Step_4   -- Scn = 2763  SKU, TTL Qty
   IF @nStep = 5 GOTO Step_5   -- Scn = 2766  SKU, TTL Qty
   IF @nStep = 6 GOTO Step_6   -- Scn = 2767  Print Carton Label
--   IF @nStep = 7 GOTO Step_7   -- Scn = 2768  LOTTABLE02 req

END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 620, 621)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2760
   SET @nStep = 1

   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- initialise all variable
   SET @cPickSlipNo = ''

   -- Init screen
   SET @cOutField01 = ''
END
GOTO Quit

/********************************************************************************
Step 1. screen = 2760
   PickSlipNo (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPickSlipNo = @cInField01

      -- Validate blank
      IF ISNULL(RTRIM(@cPickSlipNo), '') = ''
      BEGIN
         SET @nErrNo = 72691
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PKSLIP req
         GOTO Step_1_Fail
      END

      -- Check if pickslip exists in pickheader
      IF NOT EXISTS (SELECT 1 FROM dbo.PickHeader WITH (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo)
      BEGIN
         SET @nErrNo = 72692
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv PKSLIP
         GOTO Step_1_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)  
         WHERE PickSlipNo = @cPickSlipNo)  
      BEGIN  
         INSERT INTO dbo.PickingInfo  
         (PickSlipNo, ScanInDate, PickerID, ScanOutDate, AddWho)  
         VALUES  
         (@cPickSlipNo, GETDATE(), @cUserName, NULL, @cUserName)  
      END  

      SET @cOrderKey = ''

      -- Check if orders status = 3
      SELECT @cOrderKey = PH.OrderKey 
      FROM dbo.PickHeader PH WITH (NOLOCK) 
      JOIN Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
      WHERE PH.PickHeaderKey = @cPickSlipNo 
         AND O.StorerKey = @cStorerKey
         AND O.Status IN ( '3','5') -- (ChewKP01)

      IF ISNULL(@cOrderKey, '') = ''
      BEGIN
         SET @nErrNo = 72693
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad ORD Status
         GOTO Step_1_Fail
      END

      SET @cLoadKey = ''

      SELECT @cLoadKey = LoadKey FROM dbo.Orders WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey

      SELECT @nTTL_Case = COUNT( DISTINCT UPC) FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND SUBSTRING(UPC, 1, 1) = 'C'

      SELECT @nTTL_PLT = COUNT( DISTINCT UPC) FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND SUBSTRING(UPC, 1, 1) = 'P'

      IF @nFunc = 620   -- Case Packing
      BEGIN
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         --prepare next screen variable
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = @nTTL_Case
         SET @cOutField06 = @nTTL_PLT

         -- initialise all variable
         SET @cCaseID = ''
      END
      ELSE  -- Piece Packing
      BEGIN
         SET @nScn = @nScn + 6
         SET @nStep = @nStep + 4

         SET @nCartonNo = 0
         SET @cLottable02 = ''

         SET @cDefaultQty = ''
         SET @cDefaultQty = rdt.RDTGetConfig( 620, 'DefaultQty', @cStorerKey)

         --prepare next screen variable
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = '0'
         SET @cOutField06 = CASE WHEN ISNULL(@cDefaultQty, '') = '' THEN '' ELSE @cDefaultQty END
         SET @cOutField07 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
      END
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

      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cPickSlipNo = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 2761
   Case ID (Field01, input)
   SKU     (Field02)
   TTL Qty (Field03)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cBarcode = @cInField01

      IF ISNULL(@cBarcode, '') = ''
      BEGIN
         SET @nErrNo = 72694
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Barcode req
         GOTO Step_2_Fail
      END

      -- Determine barcode scanned is Case/PLT
      IF SUBSTRING(@cBarcode, 1, 1) NOT IN ('C', 'P')
      BEGIN
         SET @nErrNo = 73192
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV Barcode
         GOTO Step_2_Fail
      END

      -- Check if Barcode scanned before (unique Case ID across storer??)
      IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND UPC = @cBarcode)
      BEGIN
         SET @nErrNo = 72697
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BARCODE EXISTS 
         GOTO Step_2_Fail
      END

      -- If Case/PLT ID not exists in table, proceed with Confirm Add New screen
      IF NOT EXISTS (SELECT 1 
         FROM dbo.PackConfig WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND @cBarcode = CASE WHEN SUBSTRING(@cBarcode, 1, 1) = 'C' THEN UOM1Barcode 
                            ELSE UOM4Barcode END) 
      BEGIN
         SET @cSKU = ''

         -- Note: Cannot store DESCR into V_SKUDESCR because it used to store barcode scanned
         -- Barcode consists of 30 chars, only V_SKUDESCR able to store it
         SELECT TOP 1 @cSKU = SKU 
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND LEFT(SKU, 4) = SUBSTRING(@cBarcode, 2, 4)

         IF ISNULL(@cSKU, '') = ''
         BEGIN
            SET @nErrNo = 73193
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NOT EXISTS 
            GOTO Step_2_Fail
         END

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         SET @cOutField01 = ''
         SET @cOption = ''

         GOTO Quit
      END

      IF NOT EXISTS (SELECT 1  
      FROM dbo.PackConfig WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND Status >= '5' 
         AND Status < '9' 
         AND @cBarcode = CASE WHEN SUBSTRING(@cBarcode, 1, 1) = 'C' THEN UOM1Barcode 
                         ELSE UOM4Barcode END)
      BEGIN
         SET @nErrNo = 73202
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PLT/Case shipped 
         GOTO Step_2_Fail
      END

      SET @cBatchNo = ''

      SELECT TOP 1 @cBatchNo = BatchNo 
      FROM dbo.PackConfig WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND @cBarcode = CASE WHEN SUBSTRING(@cBarcode, 1, 1) = 'C' THEN UOM1Barcode 
                         ELSE UOM4Barcode END

      SET @cSKU = ''

      SELECT TOP 1 @cSKU = SKU 
      FROM dbo.PackConfig WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND Status >= '5' 
         AND Status < '9' 
         AND @cBarcode = CASE WHEN SUBSTRING(@cBarcode, 1, 1) = 'C' THEN UOM1Barcode 
                         ELSE UOM4Barcode END

      IF ISNULL(@cSKU, '') = ''
      BEGIN
         SET @nErrNo = 72695
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NOT EXISTS 
         GOTO Step_2_Fail
      END

      SELECT @nCaseCnt = 0, @nTTL_Qty = 0, @nUOM1Count = 0

      SELECT @nCaseCnt = ISNULL( CaseCnt, 0) 
      FROM dbo.SKU SKU WITH (NOLOCK) 
      JOIN dbo.Pack Pack WITH (NOLOCK) ON SKU.PackKey = Pack.PackKey
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

      IF @nCaseCnt = 0
      BEGIN
         SET @nErrNo = 73194
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BAD Case Count 
         GOTO Step_2_Fail
      END

      IF SUBSTRING(@cBarcode, 1, 1) = 'C'
      BEGIN
         SELECT @nTTL_Qty = 1 * @nCaseCnt 
         FROM dbo.PackConfig WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND Status = '5' 
            AND Status < '9' 
            AND UOM1Barcode = @cBarcode
      END
      ELSE
      BEGIN
         SELECT @nUOM1Count = COUNT(DISTINCT UOM1Barcode) 
         FROM dbo.PackConfig WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND Status = '5' 
            AND Status < '9' 
            AND UOM4Barcode = @cBarcode

         SET @nTTL_Qty = @nUOM1Count * @nCaseCnt 
      END

      -- Check if SKU exists in orders
      IF NOT EXISTS (SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND OrderKey = @cOrderKey
            AND SKU = @cSKU)
      BEGIN
         SET @nErrNo = 72696
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU 
         GOTO Step_2_Fail
      END

      -- Match Lottable02
      IF ISNULL(@cBatchNo, '') <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey
               AND SKU = @cSKU
               AND Lottable02 = @cBatchNo)
         BEGIN
            SET @nErrNo = 73191
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Batch 
            GOTO Step_2_Fail
         END
      END

      SELECT @nTTL_PIDQty = ISNULL( SUM(Qty), 0)
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey
         AND SKU = @cSKU

      SELECT @nTTL_PADQty = ISNULL( SUM(Qty), 0)
      FROM dbo.PackHeader PH WITH (NOLOCK)
      JOIN dbo.PackDetail PD WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
      WHERE PH.StorerKey = @cStorerKey
         AND PH.OrderKey = @cOrderKey
         AND PD.SKU = @cSKU

      -- Check if total scanned qty > total allocated qty
      IF @nTTL_PADQty + @nTTL_Qty > @nTTL_PIDQty
      BEGIN
         SET @nErrNo = 72698
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OVER SCANNED 
         GOTO Step_2_Fail
      END

      BEGIN TRAN
      -- Check if packheader exists
      IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
      BEGIN
         INSERT INTO dbo.PackHeader
         (PickSlipNo, StorerKey, OrderKey, LoadKey)
         VALUES
         (@cPickSlipNo, @cStorerKey, @cOrderKey, @cLoadKey)

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 72699
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PHDR FAIL 
            GOTO Step_2_Fail
         END 
      END

      -- Insert into PackDetail
      SET @nCartonNo = 0

      SET @cLabelNo = ''
      EXECUTE dbo.nsp_GenLabelNo
         '',
         @cStorerKey,
         @c_labelno     = @cLabelNo  OUTPUT,
         @n_cartonno    = @nCartonNo OUTPUT,
         @c_button      = '',
         @b_success     = @b_success OUTPUT,
         @n_err         = @n_err     OUTPUT,
         @c_errmsg      = @c_errmsg  OUTPUT

      IF @b_success <> 1
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 72700
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenLabelFail'
         GOTO Step_2_Fail
      END

      INSERT INTO dbo.PackDetail
         (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, UPC, DropID)
      VALUES
         (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSKU, @nTTL_Qty,
         'CA', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cBarcode, '')

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 72701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
         GOTO Step_2_Fail
      END 
      ELSE
      BEGIN
         -- Refno only can store 20 chars, so have to split
         SET @cBarcode1 = SUBSTRING(@cBarcode, 1, 20)
         SET @cBarcode2 = SUBSTRING(@cBarcode, 21, 10)

         EXEC RDT.rdt_STD_EventLog
           @cActionType   = '8', -- Packing
           @cUserID       = @cUserName,
           @nMobileNo     = @nMobile,
           @nFunctionID   = @nFunc,
           @cFacility     = @cFacility,
           @cStorerKey    = @cStorerkey,
           @cLocation     = '',
           @cID           = '',
           @cSKU          = @cSKU,
           @cUOM          = '',
           @nQTY          = @nTTL_Qty,
           @cLot          = '',          
           @cPickSlipNo   = @cPickSlipNo,
           @cOrderKey     = @cOrderKey,
           @cRefNo1       = @cBarcode1,
           @cRefNo2       = @cBarcode2,
           @nStep         = @nStep
           --@cRefNo1       = @cPickSlipNo,
           --@cRefNo2       = @cOrderKey, 
           --@cRefNo3       = @cBarcode1,
           --@cRefNo4       = @cBarcode2,
      END

      UPDATE PackConfig WITH (ROWLOCK) SET Status = '9' 
      WHERE StorerKey = @cStorerKey
         AND Status < '9'
         AND @cBarcode = CASE WHEN SUBSTRING(@cBarcode, 1, 1) = 'C' THEN UOM1Barcode 
                         ELSE UOM4Barcode END

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 72702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD STATUS FAIL'
         GOTO Step_2_Fail
      END

      COMMIT TRAN

      SET @nTTL_Case = 0
      SET @nTTL_PLT = 0

      SELECT @cDescr = Descr FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      SELECT @nTTL_Case = COUNT( DISTINCT UPC) FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND SUBSTRING(UPC, 1, 1) = 'C'

      SELECT @nTTL_PLT = COUNT( DISTINCT UPC) FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND SUBSTRING(UPC, 1, 1) = 'P'

      SET @cOutField01 = ''
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING(@cDescr, 1, 20)
      SET @cOutField04 = SUBSTRING(@cDescr, 21, 20)
      SET @cOutField05 = @nTTL_Case
      SET @cOutField06 = @nTTL_PLT

      SET @cCaseID = ''
      SET @cPLTID = ''
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      -- initialise all variable
      SET @cPickSlipNo = ''

      -- Init screen
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cCaseID = ''
   END
END
GOTO Quit

/********************************************************************************
Step 3. screen = 2622
   CASE/PLT NOT EXISTS (Field01, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cOption = @cInField01

      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 72703
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req
         GOTO Step_3_Fail
      END

      IF ISNULL(@cOption, '') <> '1' AND ISNULL(@cOption, '') <> '2'
      BEGIN
         SET @nErrNo = 72704
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_3_Fail
      END

      IF @cOption = '1'
      BEGIN
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         SELECT @cDescr = '', @cPackKey = '', @nCaseCnt = 0
         -- Note: Cannot store DESCR into V_SKUDESCR because it used to store barcode scanned
         -- Barcode consists of 30 chars, only V_SKUDESCR able to store it
         SELECT TOP 1 
            @cDescr = S.DESCR, 
            @cPackKey = P.PackKey, 
            @nCaseCnt = P.CaseCnt  
         FROM dbo.SKU S WITH (NOLOCK) 
         JOIN dbo.Pack P WITH (NOLOCK) ON S.PackKEY = P.PackKey 
         WHERE S.StorerKey = @cStorerKey
            AND S.SKU = @cSKU

         IF @nCaseCnt = 0
         BEGIN
            SET @nErrNo = 73195
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BAD Case Count 
            GOTO Step_3_Fail
         END

         --initiase next screen variable
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''

         --prepare next screen variable
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING(@cDescr, 1, 20)
         SET @cOutField03 = SUBSTRING(@cDescr, 21, 20)
         SET @cOutField04 = CASE WHEN SUBSTRING(@cBarcode, 1, 1) = 'P' THEN '' ELSE @nCaseCnt END
         SET @cOutField05 = @cPackKey
         SET @cOutField06 = @nCaseCnt

         IF SUBSTRING(@cBarcode, 1, 1) = 'P'
            SET @cOutField04 = ''

         GOTO QUIT
      END

      IF @cOption = '2'
      BEGIN
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1

         SET @nTTL_Case = 0
         SET @nTTL_PLT = 0
         SELECT @nTTL_Case = COUNT( DISTINCT UPC) FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND PickSlipNo = @cPickSlipNo
            AND SUBSTRING(UPC, 1, 1) = 'C'

         SELECT @nTTL_PLT = COUNT( DISTINCT UPC) FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND PickSlipNo = @cPickSlipNo
            AND SUBSTRING(UPC, 1, 1) = 'P'

         --prepare next screen variable
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = @nTTL_Case
         SET @cOutField06 = @nTTL_PLT

         -- initialise all variable
         SET @cBarcode = ''
         SET @cCaseID = ''
         SET @cPLTID = ''

         GOTO Quit
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      SET @nTTL_Case = 0
      SET @nTTL_PLT = 0
      SELECT @nTTL_Case = COUNT( DISTINCT UPC) FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND SUBSTRING(UPC, 1, 1) = 'C'

      SELECT @nTTL_PLT = COUNT( DISTINCT UPC) FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND SUBSTRING(UPC, 1, 1) = 'P'

      --prepare next screen variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = @nTTL_Case         
      SET @cOutField06 = @nTTL_PLT

      -- initialise all variable
      SET @cBarcode = ''
      SET @cCaseID = ''
      SET @cPLTID = ''

      GOTO Quit
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
  SET @cOutField01 = ''
      SET @cOption = ''
   END
END
GOTO Quit

/********************************************************************************
Step 4. screen = 2723
   SKU      (Field01, input)
   TTL Qty  (Field02)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cActQty = ''
      SET @cActQty = ISNULL(@cInField04, '') 

      IF @cActQty = '0'
      BEGIN
         SET @nErrNo = 72734
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty
         GOTO Step_4_Fail
      END

      IF @cActQty  = ''   SET @cActQty  = '0' --'Blank taken as zero'
      IF RDT.rdtIsValidQTY( @cActQty, 1) = 0
      BEGIN
         SET @nErrNo = 72735
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         GOTO Step_4_Fail
      END

      SET @nActQty = CAST(@cActQty AS INT)

      -- Check if the qty keyed in is a multipy of case count
      IF @nActQty % @nCaseCnt <> 0
      BEGIN
         SET @nErrNo = 73196
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         GOTO Step_4_Fail
      END

      SELECT @nTTL_PIDQty = ISNULL( SUM(Qty), 0)
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey
         AND SKU = @cSKU

      SELECT @nTTL_PADQty = ISNULL( SUM(Qty), 0)
      FROM dbo.PackHeader PH WITH (NOLOCK)
      JOIN dbo.PackDetail PD WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
      WHERE PH.StorerKey = @cStorerKey
         AND PH.OrderKey = @cOrderKey
         AND PD.SKU = @cSKU

      -- Check if total scanned qty > total allocated qty
      IF @nTTL_PADQty + @nActQty > @nTTL_PIDQty
      BEGIN
         SET @nErrNo = 72709
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OVER SCANNED 
         GOTO Step_4_Fail
      END

      BEGIN TRAN

      -- Check if packheader exists
      IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
      BEGIN
         INSERT INTO dbo.PackHeader
         (PickSlipNo, StorerKey, OrderKey, LoadKey)
         VALUES
         (@cPickSlipNo, @cStorerKey, @cOrderKey, @cLoadKey)

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 72710
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PHDR FAIL 
            GOTO Step_4_Fail
         END 
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND PickSlipNo = @cPickSlipNo
            AND SKU = @cSKU
            AND UPC = @cBarcode)
      BEGIN
         -- Insert into PackDetail
         SET @nCartonNo = 0

         SET @cLabelNo = ''
         EXECUTE dbo.nsp_GenLabelNo
            '',
            @cStorerKey,
            @c_labelno     = @cLabelNo  OUTPUT,
            @n_cartonno    = @nCartonNo OUTPUT,
            @c_button      = '',
            @b_success     = @b_success OUTPUT,
            @n_err         = @n_err     OUTPUT,
            @c_errmsg      = @c_errmsg  OUTPUT

         IF @b_success <> 1
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 72711
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenLabelFail'
            GOTO Step_4_Fail
         END

         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, UPC, DropID)
         VALUES
            (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSKU, @nActQty,
            'CA', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cBarcode, '')

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 72712
 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
            GOTO Step_4_Fail
         END 
         ELSE
         BEGIN
            -- Refno only can store 20 chars, so have to split
            SET @cBarcode1 = SUBSTRING(@cBarcode, 1, 20)
            SET @cBarcode2 = SUBSTRING(@cBarcode, 21, 10)

            EXEC RDT.rdt_STD_EventLog
              @cActionType   = '8', -- Packing
              @cUserID       = @cUserName,
              @nMobileNo     = @nMobile,
              @nFunctionID   = @nFunc,
              @cFacility     = @cFacility,
              @cStorerKey    = @cStorerkey,
              @cLocation     = '',
              @cID           = '',
              @cSKU          = @cSKU,
              @cUOM          = '',
              @nQTY          = @nActQty,
              @cLot          = '',
              @cPickSlipNo   = @cPickSlipNo,
              @cOrderKey     = @cOrderKey,
              @cRefNo1       = @cBarcode1,
              @cRefNo2       = @cBarcode2,
              @nStep         = @nStep         
              --@cRefNo1       = @cPickSlipNo,
              --@cRefNo2       = @cOrderKey, 
              --@cRefNo3       = @cBarcode1, 
              --@cRefNo4       = @cBarcode2,
         END
      END
      ELSE
      BEGIN
         UPDATE PackDetail WITH (ROWLOCK) SET 
            Qty = ISNULL(Qty, 0) + @nActQty 
         WHERE StorerKey = @cStorerKey
            AND PickSlipNo = @cPickSlipNo
            AND SKU = @cSKU
            AND UPC = @cBarcode

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 72713
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
            GOTO Step_4_Fail
         END 
         ELSE
         BEGIN
            -- Refno only can store 20 chars, so have to split
            SET @cBarcode1 = SUBSTRING(@cBarcode, 1, 20)
            SET @cBarcode2 = SUBSTRING(@cBarcode, 21, 10)

            EXEC RDT.rdt_STD_EventLog
              @cActionType   = '8', -- Packing
              @cUserID       = @cUserName,
              @nMobileNo     = @nMobile,
              @nFunctionID   = @nFunc,
              @cFacility     = @cFacility,
              @cStorerKey    = @cStorerkey,
              @cLocation     = '',
              @cID           = '',
              @cSKU          = @cSKU,
              @cUOM          = '',
              @nQTY          = @nActQty,
              @cLot          = '',
              @cPickSlipNo   = @cPickSlipNo,
              @cOrderKey     = @cOrderKey,
              @cRefNo1       = @cBarcode1,
              @cRefNo2       = @cBarcode2,
              @nStep         = @nStep
              --@cRefNo1       = @cPickSlipNo,
              --@cRefNo2       = @cOrderKey, 
              --@cRefNo3       = @cBarcode1, 
              --@cRefNo4       = @cBarcode2,
         END
      END

      COMMIT TRAN

      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2

      SET @nTTL_Case = 0
      SET @nTTL_PLT = 0
      SELECT @nTTL_Case = COUNT( DISTINCT UPC) FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND SUBSTRING(UPC, 1, 1) = 'C'

      SELECT @nTTL_PLT = COUNT( DISTINCT UPC) FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND SUBSTRING(UPC, 1, 1) = 'P'

      --prepare next screen variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = @nTTL_Case
      SET @cOutField06 = @nTTL_PLT

      -- initialise all variable
      SET @cBarcode = ''
      SET @cCaseID = ''
      SET @cPLTID = ''
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2

      SET @nTTL_Case = 0
      SET @nTTL_PLT = 0
      SELECT @nTTL_Case = COUNT( DISTINCT UPC) FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND SUBSTRING(UPC, 1, 1) = 'C'

      SELECT @nTTL_PLT = COUNT( DISTINCT UPC) FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND SUBSTRING(UPC, 1, 1) = 'P'

      --prepare next screen variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = @nTTL_Case
      SET @cOutField06 = @nTTL_PLT

      -- initialise all variable
      SET @cBarcode = ''
      SET @cCaseID = ''
      SET @cPLTID = ''

      GOTO Quit
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cOutField04 = @nCaseCnt

      SET @cActQty = ''
   END
END
GOTO Quit

/********************************************************************************
Step 5. screen = 2724
   SKU      (Field01, input)
   TTL Qty  (Field02)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Validate blank
      IF ISNULL(@cInField01, '') = ''
      BEGIN
         SET @nErrNo = 72714
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BTL ID/SKU req
         SET @cOutField01 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_5_Fail
      END

      SET @cBottleID = ''
      SET @cNewSKU = ''

      -- Screen mapping
      SET @cBottleID = @cInField01

      SELECT @cNewSKU = SKU FROM dbo.PackConfig WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND UOM3Barcode = @cBottleID

      -- If no SKU retrieved then assume this is SKU code
      IF ISNULL(@cNewSKU, '') = ''
      BEGIN
         SET @cNewSKU = @cBottleID
      END

      -- Look up SKU
      EXEC [RDT].[rdt_GETSKUCNT]
         @cStorerKey  = @cStorerKey,
         @cSKU        = @cNewSKU,
         @nSKUCnt     = @nSKUCnt       OUTPUT,
         @bSuccess    = @b_Success     OUTPUT,
         @nErr        = @n_Err         OUTPUT,
         @cErrMsg     = @c_ErrMsg      OUTPUT

      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 72715
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         SET @cOutField01 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_5_Fail
      END

      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 72716
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameBarcodeSKU
         SET @cOutField01 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_5_Fail
      END

      EXEC [RDT].[rdt_GETSKU]
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cNewSKU       OUTPUT
      ,@bSuccess    = @b_Success     OUTPUT
      ,@nErr        = @n_Err         OUTPUT
      ,@cErrMsg     = @c_ErrMsg      OUTPUT

      IF NOT EXISTS (SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND OrderKey = @cOrderKey
            AND SKU = @cNewSKU)
      BEGIN
         SET @nErrNo = 72717
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         SET @cOutField01 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_5_Fail
      END

      SET @cSKU = @cNewSKU

      SELECT @cDescr = '', @cPackKey = '', @nCaseCnt = 0

      SELECT TOP 1 
         @cDescr = S.DESCR, 
         @cPackKey = P.PackKey, 
         @nCaseCnt = P.CaseCnt  
      FROM dbo.SKU S WITH (NOLOCK) 
      JOIN dbo.Pack P WITH (NOLOCK) ON S.PackKEY = P.PackKey 
      WHERE S.StorerKey = @cStorerKey
         AND S.SKU = @cSKU

      IF @nCaseCnt = 0
      BEGIN
         SET @nErrNo = 73197
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BAD Case Count 
         SET @cOutField01 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_5_Fail
      END

      SET @cActQty = ''
      SET @cActQty = ISNULL(@cInField06, '') 

      IF @cActQty = '0'
      BEGIN
         SET @cActQty = ''
         SET @nErrNo = 72736
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty
         SET @cOutField06 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Step_4_Fail
      END

      IF @cActQty  = ''   SET @cActQty  = '0' --'Blank taken as zero'
      IF RDT.rdtIsValidQTY( @cActQty, 1) = 0
      BEGIN
         SET @cActQty = ''
         SET @nErrNo = 72737
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         SET @cOutField06 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Quit
      END

      SET @nActQty = CAST(@cActQty AS INT)

      SELECT @nTTL_PIDQty = ISNULL( SUM(Qty), 0)
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey
         AND SKU = @cSKU

      SELECT @nTTL_PADQty = ISNULL( SUM(Qty), 0)
      FROM dbo.PackHeader PH WITH (NOLOCK)
      JOIN dbo.PackDetail PD WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
      WHERE PH.StorerKey = @cStorerKey
         AND PH.OrderKey = @cOrderKey
         AND PD.SKU = @cSKU

      -- Check if total scanned qty > total allocated qty
      IF @nTTL_PADQty + @nActQty > @nTTL_PIDQty
      BEGIN
         SET @nErrNo = 72718
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OVER SCANNED 
         SET @cOutField07 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 7
         GOTO Step_5_Fail
      END

      IF ISNULL(@cInField07, '') <> '' 
      BEGIN
         SET @cLottable02 = ''
         SET @cLottable02 = @cInField07

         IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
            WHERE LA.StorerKey = @cStorerKey
               AND LA.Lottable02 = @cLottable02)
         BEGIN
            SET @nErrNo = 72739
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOT02 X EXISTS
            SET @cOutField07 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 7
            GOTO Step_5_Fail
         END

         -- Check if the qty keyed in is a multipy of case count
         IF @nActQty % @nCaseCnt <> 0
         BEGIN
            SET @nErrNo = 73198
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
            SET @cOutField01 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_5_Fail
         END

      END

      BEGIN TRAN

      -- Check if packheader exists
      IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
      BEGIN
         INSERT INTO dbo.PackHeader
         (PickSlipNo, StorerKey, OrderKey, LoadKey)
         VALUES
         (@cPickSlipNo, @cStorerKey, @cOrderKey, @cLoadKey)

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 72719
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PHDR FAIL 
            GOTO Step_5_Fail
         END 
      END

      -- Loose case packing
      IF @cLottable02 <> ''
      BEGIN
         SET @nLoop = @nActQty / @nCaseCnt
         WHILE @nLoop > 0
         BEGIN
            -- Insert into PackDetail
            SET @cLabelNo = ''
            EXECUTE dbo.nsp_GenLabelNo
               '',
               @cStorerKey,
               @c_labelno     = @cLabelNo  OUTPUT,
               @n_cartonno    = @nCartonNo OUTPUT,
               @c_button      = '',
               @b_success     = @b_success OUTPUT,
               @n_err         = @n_err     OUTPUT,
               @c_errmsg      = @c_errmsg  OUTPUT

            IF @b_success <> 1
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 73199
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenLabelFail'
               GOTO Step_5_Fail
            END

            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, UPC, DropID)
            VALUES
               (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSKU, @nCaseCnt,
               'EA', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '', ISNULL(@cLottable02, ''))

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 73200
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
               GOTO Step_5_Fail
            END 
            ELSE
            BEGIN
               SELECT @nCartonNo = CartonNo FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND PickSlipNo = @cPickSlipNo
                  AND SKU = @cSKU
                  AND LabelNo = @cLabelNo

               SET @cUPC = ''
               SET @cUPC_New = ''

               SELECT TOP 1           
                  @cUPC_New = UPC           
               FROM PackDetail WITH (NOLOCK)          
               WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU
                  AND UPC LIKE 'T' + 
                      CASE WHEN LEN(RTRIM(@cSKU)) >= 6 THEN LEFT(RTRIM(@cSKU), 6) 
                                WHEN LEN(RTRIM(@cSKU)) = 5 THEN RTRIM(@cSKU) + '0'  
                                WHEN LEN(RTRIM(@cSKU)) = 4 THEN RTRIM(@cSKU) + '00' 
                      END + 
                      RIGHT( '000000000' + CAST( IsNULL( RTRIM(@cLottable02), 0) AS NVARCHAR( 9)), 9) + 
                      '5' + '[0-9][0-9][0-9][0-9]'   
               ORDER BY UPC DESC

               IF ISNULL(RTRIM(@cUPC_New),'') = ''           
               BEGIN
                  SET @cUPC = 'T' + 
                              CASE WHEN LEN(RTRIM(@cSKU)) >= 6 THEN LEFT(RTRIM(@cSKU), 6) 
                                   WHEN LEN(RTRIM(@cSKU)) = 5 THEN RTRIM(@cSKU) + '0'  
                                   WHEN LEN(RTRIM(@cSKU)) = 4 THEN RTRIM(@cSKU) + '00' 
                              END + 
                              RIGHT( '000000000' + CAST( IsNULL( RTRIM(@cLottable02), 0) AS NVARCHAR( 9)), 9) + 
                              '50001'          
               END
               ELSE          
               BEGIN          
                  SET @nNextSeqNo = CAST( RIGHT(RTRIM(@cUPC_New),4) AS INT ) + 1      
                  SET @cUPC = 'T' + 
                        CASE WHEN LEN(RTRIM(@cSKU)) >= 6 THEN LEFT(RTRIM(@cSKU), 6) 
                             WHEN LEN(RTRIM(@cSKU)) = 5 THEN RTRIM(@cSKU) + '0'  
                             WHEN LEN(RTRIM(@cSKU)) = 4 THEN RTRIM(@cSKU) + '00'  
                        END + 
                        RIGHT( '000000000' + CAST( IsNULL( RTRIM(@cLottable02), 0) AS NVARCHAR( 9)), 9) + 
                        '5' + RIGHT('0000' + CONVERT(VARCHAR( 4), @nNextSeqNo), 4)
               END

               UPDATE dbo.PackDetail SET 
                  UPC = @cUPC 
               WHERE PickSlipNo = @cPickSlipNo
                  AND StorerKey = @cStorerKey
                  AND CartonNo = @nCartonNo

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 72740
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
                  GOTO Step_5_Fail
               END
               ELSE
               BEGIN
                  EXEC RDT.rdt_STD_EventLog
                    @cActionType   = '8', -- Packing
                    @cUserID       = @cUserName,
                    @nMobileNo     = @nMobile,
                    @nFunctionID   = @nFunc,
                    @cFacility     = @cFacility,
                    @cStorerKey    = @cStorerkey,
                    @cLocation     = '',
                    @cID           = @cBottleID,
                    @cSKU          = @cSKU,
                    @cUOM          = '',
                    @nQTY          = @nCaseCnt,
                    @cLot          = '',
                    @cPickSlipNo   = @cPickSlipNo,
                    @cOrderKey     = @cOrderKey,
                    @nStep         = @nStep
                    --@cRefNo1       = @cPickSlipNo,
                    --@cRefNo2       = @cOrderKey,
               END
            END

            IF EXISTS (SELECT 1 FROM dbo.PackConfig WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND UOM3Barcode = @cBottleID
                  AND SKU = @cSKU
                  AND Status < '9')
            BEGIN
               UPDATE PackConfig SET Status = '9'
               WHERE StorerKey = @cStorerKey
                  AND UOM3Barcode = @cBottleID
                  AND SKU = @cSKU
                  AND Status < '9'

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 73201
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD STATUS FAIL'
                  GOTO Step_5_Fail
               END 
            END

            /*
            if Count (Distinct Packdetail.SKU) =1 and PackDetail.Qty = Pack.casecnt, 
            then print the full case carton label; 
            If the Count (Distinct Packdetail.SKU) >1 or Count (Distinct Packdetail.SKU) =1, 
            but PackDetail.Qty <> Pack.casecnt, then print the piece carton label.
            */

            SET @cReportType = 'CTNMARKLBL'
            SET @cPrintJobName = 'PRINT_CARTON_CASE_LABEL'

            SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                   @cTargetDB = ISNULL(RTRIM(TargetDB), '')
            FROM RDT.RDTReport WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   ReportType = @cReportType

            IF ISNULL(@cDataWindow, '') = ''
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 72728
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
               GOTO Step_5_Fail
            END

            IF ISNULL(@cTargetDB, '') = ''
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 72729
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
               GOTO Step_5_Fail
            END

            SET @nErrNo = 0
            EXEC RDT.rdt_BuiltPrintJob
               @nMobile,
               @cStorerKey,
               @cReportType,
               @cPrintJobName,
               @cDataWindow,
               @cPrinter,
               @cTargetDB,
               @cLangCode,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT,
               @cStorerKey,
               @cPickSlipNo,
               @nCartonNo 

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 72730
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsertPRTFail'
               GOTO Step_5_Fail
            END

            SET @nLoop = @nLoop - 1
         END

         SET @nCartonNo = 0
      END
      ELSE
      BEGIN
         -- Loose piece packing
         IF @nCartonNo = 0
         BEGIN
            -- Insert into PackDetail
            SET @cLabelNo = ''
            EXECUTE dbo.nsp_GenLabelNo
               '',
               @cStorerKey,
               @c_labelno     = @cLabelNo  OUTPUT,
               @n_cartonno    = @nCartonNo OUTPUT,
               @c_button      = '',
               @b_success     = @b_success OUTPUT,
               @n_err         = @n_err     OUTPUT,
               @c_errmsg      = @c_errmsg  OUTPUT

            IF @b_success <> 1
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 72720
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenLabelFail'
               GOTO Step_5_Fail
            END

            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, UPC, DropID)
            VALUES
               (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSKU, @nActQty,
               'EA', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '', '')

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 72721
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
               GOTO Step_5_Fail
            END 
            ELSE
            BEGIN
               EXEC RDT.rdt_STD_EventLog
                 @cActionType   = '8', -- Packing
                 @cUserID       = @cUserName,
                 @nMobileNo     = @nMobile,
                 @nFunctionID   = @nFunc,
                 @cFacility     = @cFacility,
                 @cStorerKey    = @cStorerkey,
                 @cLocation     = '',
                 @cID           = @cBottleID,
                 @cSKU          = @cSKU,
                 @cUOM          = '',
                 @nQTY          = @nActQty,
                 @cLot          = '',
                 @cPickSlipNo   = @cPickSlipNo,
                 @cOrderKey     = @cOrderKey,
                 @nStep         = @nStep
                 --@cRefNo1       = @cPickSlipNo,
                 --@cRefNo2       = @cOrderKey,
            END

            SELECT @nCartonNo = CartonNo FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND PickSlipNo = @cPickSlipNo
               AND SKU = @cSKU
               AND LabelNo = @cLabelNo
               
            IF EXISTS (SELECT 1 FROM dbo.PackConfig WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND UOM3Barcode = @cBottleID
                  AND SKU = @cSKU
                  AND Status < '9')
            BEGIN
               UPDATE PackConfig SET Status = '9'
               WHERE StorerKey = @cStorerKey
                  AND UOM3Barcode = @cBottleID
                  AND SKU = @cSKU
                  AND Status < '9'

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 72722
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD STATUS FAIL'
                  GOTO Step_5_Fail
               END 
            END
         END
         ELSE
         BEGIN
            IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND PickSlipNo = @cPickSlipNo
                  AND SKU = @cSKU
                  AND CartonNo = @nCartonNo)
            BEGIN
               UPDATE PackDetail WITH (ROWLOCK)
                  SET Qty = ISNULL(Qty, 0) + @nActQty
               WHERE StorerKey = @cStorerKey
                  AND PickSlipNo = @cPickSlipNo
                  AND SKU = @cSKU
                  AND CartonNo = @nCartonNo
            END
            ELSE
            BEGIN
               SELECT @cLabelNo = '', @cLabelLine = ''

               SELECT TOP 1 @cLabelNo = LabelNo  
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo 

               SELECT 
                  @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5) 
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo 

               INSERT INTO dbo.PackDetail
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, UPC, DropID)
               VALUES
                  (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nActQty,
                  'EA', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '', '')
            END

       IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 72723
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
               GOTO Step_5_Fail
            END 
            ELSE
            BEGIN
               EXEC RDT.rdt_STD_EventLog
                 @cActionType   = '8', -- Packing
                 @cUserID       = @cUserName,
                 @nMobileNo     = @nMobile,
                 @nFunctionID   = @nFunc,
                 @cFacility     = @cFacility,
                 @cStorerKey    = @cStorerkey,
                 @cLocation     = '',
                 @cID           = @cBottleID,
                 @cSKU          = @cSKU,
                 @cUOM          = '',
                 @nQTY          = @nActQty,
                 @cLot          = '',
                 @cPickSlipNo   = @cPickSlipNo,
                 @cOrderKey     = @cOrderKey,
                 @nStep         = @nStep
                 --@cRefNo1       = @cPickSlipNo,
                 --@cRefNo2       = @cOrderKey,

            END
         END
      END

      COMMIT TRAN

      SELECT @cDescr = Descr FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      SELECT @nTTL_Qty = ISNULL(SUM( Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND SKU = @cSKU

      SET @cOutField01 = ''
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING(@cDescr, 1, 20)
      SET @cOutField04 = SUBSTRING(@cDescr, 21, 20)
      SET @cOutField05 = @nTTL_Qty
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF ISNULL(@cOutField02, '') = ''
      BEGIN
         SET @nScn = 2760
         SET @nStep = 1

         --prepare next screen variable
         SET @cOutField01 = ''

         SET @cPickSlipNo = ''

         GOTO Quit
      END

      IF @nCartonNo > 0
      BEGIN
         /* For Piece Packing, PackDetail.RefNo generated by below
         K (Hard Code) + RO No (Orders.ExternOrderKey) + 00001(sequence number) 
         e.g. K12344556F400002
         For 50001(sequence number), each CartonNo increase 1 - case level
         if it is a full case then reset seqno for every new pickslip
         */
         SELECT @cExternOrderKey = ExternOrderKey FROM dbo.Orders WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND OrderKey = @cOrderKey

         SET @cBatchNo = ''

         IF ISNULL(@cBottleID, '') <> ''
         BEGIN
            SELECT @cBatchNo = BatchNo FROM dbo.PackConfig WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND UOM3Barcode = @cBottleID
         END

         IF ISNULL(@cBatchNo, '') = ''
         BEGIN
            SET @cBatchNo = ''
         END

         SET @cUPC = ''
         SET @cUPC_New = ''
         SET @nNextSeqNo = 0

         SELECT TOP 1           
            @cUPC_New = UPC           
         FROM PackDetail WITH (NOLOCK)          
         WHERE PickSlipNo = @cPickSlipNo
            AND UPC LIKE 'K%5' + '[0-9][0-9][0-9][0-9]'   
         ORDER BY CartonNo DESC
                
         IF ISNULL(RTRIM(@cUPC_New),'') = ''           
         BEGIN
            SET @cUPC = 'K' + RTRIM(@cExternOrderKey) + '50001'          
         END
         ELSE          
         BEGIN          
            SET @nNextSeqNo = CAST( RIGHT(RTRIM(@cUPC_New),4) AS INT ) + 1           
            SET @cUPC = 'K' + RTRIM(@cExternOrderKey) + '5' + RIGHT('0000' + CONVERT(VARCHAR( 4), @nNextSeqNo), 4)           
         END             
      
         BEGIN TRAN

         UPDATE dbo.PackDetail SET 
            UPC = @cUPC 
         WHERE PickSlipNo = @cPickSlipNo
            AND StorerKey = @cStorerKey
            AND CartonNo = @nCartonNo

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 72740
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
            GOTO Step_5_Fail
         END

         COMMIT TRAN

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         --prepare next screen variable
         SET @cOutField01 = ''

         SET @cOption = ''
      END
      ELSE
      BEGIN
         SET @nScn = 2760
         SET @nStep = 1

         --prepare next screen variable
         SET @cOutField01 = ''

         SET @cPickSlipNo = ''

         GOTO Quit
      END
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cBottleID = ''
      SET @cActQty = ''
   END
END
GOTO Quit

/********************************************************************************
Step 6. screen = 2767
   Option (Field01, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 72725
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req
         GOTO Step_6_Fail
      END

      IF ISNULL(@cOption, '') NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 72726
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_6_Fail
      END

      IF @cOption = 1
      BEGIN
         IF @nCartonNo > 0
         BEGIN
            BEGIN TRAN

            IF ISNULL(@cPrinter, '') = ''
            BEGIN
               SET @nErrNo = 72727
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLoginPrinter
               GOTO Step_6_Fail
            END

            SET @cReportType = 'UCCLABEL'
            SET @cPrintJobName = 'PRINT_CARTON_PIECE_LABEL'

            SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                   @cTargetDB = ISNULL(RTRIM(TargetDB), '')
            FROM RDT.RDTReport WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   ReportType = @cReportType

            IF ISNULL(@cDataWindow, '') = ''
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 72731
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
               GOTO Step_6_Fail
            END

            IF ISNULL(@cTargetDB, '') = ''
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 72732
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
               GOTO Step_6_Fail
            END

            SET @nErrNo = 0
            EXEC RDT.rdt_BuiltPrintJob
               @nMobile,
               @cStorerKey,
               @cReportType,
               @cPrintJobName,
               @cDataWindow,
               @cPrinter,
               @cTargetDB,
               @cLangCode,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT,
               @cStorerKey,
               @cPickSlipNo,
               @nCartonNo 

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 72733
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsertPRTFail'
               GOTO Step_6_Fail
            END

            COMMIT TRAN
         END

         GOTO Go_Back_SKU_Screen
      END

      IF @cOption = 2
      BEGIN
         GOTO Go_Back_PickSlip_Screen
      END
   END

   Step_6_Fail:
   BEGIN
      SET @cOutField01 = ''

      SET @cOption = ''
   END
   GOTO Quit

   Go_Back_SKU_Screen:
   BEGIN
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      SET @nCartonNo = 0
      SET @cLottable02 = ''

      SET @cDefaultQty = ''
      SET @cDefaultQty = rdt.RDTGetConfig( 620, 'DefaultQty', @cStorerKey)

      --prepare next screen variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = '0'
      SET @cOutField06 = CASE WHEN ISNULL(@cDefaultQty, '') = '' THEN '' ELSE @cDefaultQty END
      SET @cOutField07 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   GOTO Quit

   Go_Back_PickSlip_Screen:
   BEGIN
      SET @nScn = @nScn - 7
      SET @nStep = @nStep - 5

      --prepare next screen variable
      SET @cOutField01 = ''

      SET @cPickSlipNo = ''
   END
END
GOTO Quit
/*
/********************************************************************************
Step 7. screen = 2768
   Option (Field01, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLottable02 = @cInField01

      IF ISNULL(@cLottable02, '') = ''
      BEGIN
         SET @nErrNo = 72738
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOT02 REQ
         SET @cOutField01 = ''
         GOTO Quit
      END
      
      IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT 
         JOIN PackHeader PH WITH (NOLOCK) ON PD.OrderKey = PH.OrderKey 
         WHERE PD.StorerKey = @cStorerKey
            AND PH.StorerKey = @cStorerKey
            AND LA.Lottable02 = @cLottable02
            AND PH.PickSlipNo = @cPickSlipNo
            AND PD.SKU = @cSKU)
      BEGIN
         SET @cLottable02 = ''
         SET @nErrNo = 72739
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOT02 X EXISTS
         SET @cOutField01 = ''
         GOTO Quit
      END

      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2

      GOTO Generate_UPC
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2

      SET @cDefaultQty = ''
      SET @cDefaultQty = rdt.RDTGetConfig( 620, 'DefaultQty', @cStorerKey)

      SELECT @cDescr = Descr FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      SELECT @nTTL_Qty = ISNULL(SUM( Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND SKU = @cSKU

      --prepare next screen variable
      SET @cOutField01 = ''
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING(@cDescr, 1, 20)
      SET @cOutField04 = SUBSTRING(@cDescr, 21, 20)
      SET @cOutField05 = @nTTL_Qty
      SET @cOutField06 = CASE WHEN ISNULL(@cDefaultQty, '') = '' THEN '' ELSE @cDefaultQty END
      SET @cOutField07 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   GOTO Quit
END
GOTO Quit
*/
/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      EditDate      = GETDATE(), 
      ErrMsg        = @cErrMsg,
      Func          = @nFunc,
      Step          = @nStep,
      Scn           = @nScn,

      StorerKey     = @cStorerKey,
      Facility      = @cFacility,
      Printer       = @cPrinter,
      -- UserName      = @cUserName,

      V_Lottable02   = @cLottable02, 
      V_PickSlipNo   = @cPickSlipNo,  
      V_OrderKey     = @cOrderKey,  
      V_LoadKey      = @cLoadKey,  
      V_SKU          = @cSKU,  
      V_SKUDESCR     = @cBarcode, 
      
      V_Cartonno     = @nCartonNo,
   
      V_Integer1     = @nCaseCnt,
 
      --V_String1      = @nCartonNo, 
      --V_String2      = @nCaseCnt,  
      V_String3      = @cPackKey, 

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