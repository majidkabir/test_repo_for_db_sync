SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtfnc_SerialNoCapture                              */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Serial No Capture                                           */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 01-Sep-2006 1.0  jwong    Created                                    */
/* 26-Oct-2006 1.1  MaryVong Modified option #1. Serial # Capture:      */
/*                           1) Add in control not allow to re-scan     */
/*                              confirmed PickSlipNo                    */
/*                           2) Running total counted base on pickslip, */
/*                              not by individual SKU                   */
/*                           3) Running total appears on both Scan UPC  */
/*                              and Scan Serial No screens              */
/*                           4) Validate Short Pick when press ESC from */
/*                              Scan UPC screen                         */
/*                           5) User allow to rotate scanning UPC and   */
/*                              Serial No                               */
/*                           Note: No more calling Step_11              */
/* 24-Apr-2007 1.2  James    Split capture, delete & search to 3        */
/*                           different screen                           */
/* 23-Nov-2007 1.3  Vicky    SOS#91982 - Add additional column LOT# to  */
/*                           cater TW CIBA request. Will only appear if */
/*                           StorerConfigkey = SerialNoCaptureShowLot   */
/*                           is turned on. This field is just for value */
/*                           storage purpose. For Search & Delete has   */
/*                           to consider combination of Serial# + Lot#  */
/*                           (Vicky01)                                  */
/* 31-Dec-2007 1.4  James    1)Re-structure the script to make it either*/
/*                             Scan Pickslip#->UPC->Lot#->Serial# or    */
/*                             Pickslip#->UPC->Serial#                  */
/*                           2)Add in another screen just for serial#   */
/*                             scan if 'SerialNoCaptureShowLot' not     */
/*                             turned on                                */
/* 02-Sep-2008 1.5  Vicky    Modify to cater for SQL2005 (Vicky01)      */
/* 29-Sep-2008 1.6  Vicky    SOS#117130 - Extend the length of LotNo    */
/*                           field (Vicky02)                            */
/* 02-Dec-2009 1.7  Vicky    take out DBName parsing to Sub-SP (Vicky02)*/
/* 11-Jan-2010 1.8  Vicky    SOS#153915 - Add in SSCC checking (Vicky03)*/
/* 10-Mar-2010 1.9  James    SOS#153915 - If CHECKSSCC is on            */
/*                           1. Serial No = 22 digits is carton and < 22*/
/*                              is decanter (james01)                   */
/*                           2. For decanter no need to check length    */
/*                           3. For carton always take the last 18 digit*/
/* 08-Apr-2010 2.0  James    SOS#153915 - Change Serial No length to    */
/*                           20 digits (james02)                        */
/* 21-Feb-2012 2.1  Ung      SOS236331 Added: optional QTY screen and   */
/*                           storer config CaptureSNoAndQTY             */
/*                           storer config CaptureSNoNotCheckSNoUnique  */
/*                           storer config CaptureSNoNotCheckScanOut    */
/*                           Clean up source                            */
/* 18-Feb-2013 2.2  ChewKP   SOS#270055 - Support Discrete PS (ChewKP01)*/
/* 14-Jul-2014 2.3  James    SOS315487 - Extend length of serial no     */
/*                           from 20 to 30 chars (james03)              */
/* 24-Feb-2015 2.4  ChewKP   SOS#331416 Iterate Step 4 (ChewKP02)       */
/* 30-Sep-2016 2.5  Ung      Performance tuning                         */
/* 15-Sep-2017 2.6  James    WMS2988-Bug fix (james04)                  */
/* 24-Sep-2018 2.7  James    WMS7751-Remove OD.loadkey (james05)        */
/* 11-Sep-2019 2.8  James    WMS-10383-Add validformat @ step 4(james06)*/
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_SerialNoCapture] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE
   @b_success        INT,
   @n_err            INT,
   @c_errmsg         NVARCHAR( 215),
   @nQTY             INT

-- Variable for RDT.RDTMobRec
DECLARE
   @nFunc            INT,
   @nScn             INT,
   @nStep            INT,
   @cLangCode        NVARCHAR( 3),
   @nInputKey        INT,
   @nMenu            INT,

   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @cUserName        NVARCHAR( 18),

   @cPickSlipNo          NVARCHAR( 10),
   @cSKU                 NVARCHAR( 20),
   @cDescr               NVARCHAR( 30),
   @cOrderKey            NVARCHAR( 10),
   @nScannedSerialCount  INT,
   @nTotalSerialCount    INT,
   @cSerialNo            NVARCHAR( 30), --(james03)
   @nSKUScannedCount     INT,
   @nSKUTotalSerialCount NVARCHAR( 5),
   @cLotNo               NVARCHAR(20),
   @cShowLot             NVARCHAR(1),
   @cCheckSSCC           NVARCHAR(20), -- (james03)
   @cNotCheckSNoUnique   NVARCHAR(1),
   @cNotCheckScanOut     NVARCHAR(1),
   @cCaptureSNoAndQTY    NVARCHAR(1),
   @cSerialNo1           NVARCHAR( 20), --(james03)
   @cSerialNo2           NVARCHAR( 20), --(james03)
   @cCheckSSCC_SP        NVARCHAR( 20), --(james03)
   @cSQL                 NVARCHAR(MAX), --(james03)
   @cSQLParam            NVARCHAR(MAX), --(james03)
   @cExtendedValidateSP  NVARCHAR(30),  -- (ChewKP02)
   @cCaptureSNoIterate   NVARCHAR(1),   -- (ChewKP02)
   @cDecodeLabelNo       NVARCHAR(20),  -- (ChewKP02)

   @cQTY                 NVARCHAR( 5),

   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20), -- (ChewKP02)
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20), -- (ChewKP02)
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20), -- (ChewKP02)
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20), -- (ChewKP02)
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20), -- (ChewKP02)

   @cInField01 NVARCHAR( 60),  @cOutField01 NVARCHAR( 60),
   @cInField02 NVARCHAR( 60),  @cOutField02 NVARCHAR( 60),
   @cInField03 NVARCHAR( 60),  @cOutField03 NVARCHAR( 60),
   @cInField04 NVARCHAR( 60),  @cOutField04 NVARCHAR( 60),
   @cInField05 NVARCHAR( 60),  @cOutField05 NVARCHAR( 60),
   @cInField06 NVARCHAR( 60),  @cOutField06 NVARCHAR( 60),
   @cInField07 NVARCHAR( 60),  @cOutField07 NVARCHAR( 60),
   @cInField08 NVARCHAR( 60),  @cOutField08 NVARCHAR( 60),
   @cInField09 NVARCHAR( 60),  @cOutField09 NVARCHAR( 60),
   @cInField10 NVARCHAR( 60),  @cOutField10 NVARCHAR( 60),
   @cInField11 NVARCHAR( 60),  @cOutField11 NVARCHAR( 60),
   @cInField12 NVARCHAR( 60),  @cOutField12 NVARCHAR( 60),
   @cInField13 NVARCHAR( 60),  @cOutField13 NVARCHAR( 60),
   @cInField14 NVARCHAR( 60),  @cOutField14 NVARCHAR( 60),
   @cInField15 NVARCHAR( 60),  @cOutField15 NVARCHAR( 60)

-- Getting Mobile information
SELECT
   @nFunc  = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @cLangCode   = Lang_code,
   @nMenu       = Menu,
   @cFacility   = Facility,
   @cStorerKey  = StorerKey,

   @cPickSlipNo = V_PickSlipNo,
   @cSKU        = V_SKU,
   @cDescr      = V_SKUDescr,
   @cOrderKey   = V_OrderKey,
   @cQty        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_Qty, 5), 0) = 1 THEN LEFT( V_Qty, 5) ELSE 0 END,

   @nScannedSerialCount  = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String1, 5), 0) = 1 THEN LEFT( V_String1, 5) ELSE 0 END,
   @nTotalSerialCount    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String2, 5), 0) = 1 THEN LEFT( V_String2, 5) ELSE 0 END,
   @nSKUScannedCount     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 5), 0) = 1 THEN LEFT( V_String3, 5) ELSE 0 END,
   @nSKUTotalSerialCount = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 5), 0) = 1 THEN LEFT( V_String4, 5) ELSE 0 END,
   @cLotNo               = V_String5,
--   @cSerialNo            = V_String6,   -- (james03)
   @cShowLot             = V_String7,
   @cCheckSSCC           = V_String8,
   @cNotCheckSNoUnique   = V_String9,
   @cNotCheckScanOut     = V_String10,
   @cCaptureSNoAndQTY    = V_String11,
   @cSerialNo1           = V_String12,    -- (james03)
   @cSerialNo2           = V_String13,    -- (james03)
   @cCaptureSNoIterate   = V_String14,    -- (ChewKP02)
   @cExtendedValidateSP  = V_String15,    -- (ChewKP02)
   @cDecodeLabelNo       = V_String16,    -- (ChewKP02)

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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15

FROM   RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 870
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 872
   IF @nStep = 1 GOTO Step_1   -- Scn = 870   PickSlipNo
   IF @nStep = 2 GOTO Step_2   -- Scn = 871   UPC/SKU
   IF @nStep = 3 GOTO Step_3   -- Scn = 882   LOT
   IF @nStep = 4 GOTO Step_4   -- Scn = 873   SerialNo
   IF @nStep = 5 GOTO Step_5   -- Scn = 874   QTY
   IF @nStep = 6 GOTO Step_6   -- Scn = 885   Option (short pick)
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Called from menu (func = 554)
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey

   SET @nScn = 870
   SET @nStep = 1

   -- Storer config
   SET @cCheckSSCC = rdt.RDTGetConfig( @nFunc, 'CheckSSCC', @cStorerKey)
   SET @cShowLot = rdt.RDTGetConfig( 0, 'SerialNoCaptureShowLot', @cStorerKey)
   SET @cNotCheckSNoUnique = rdt.RDTGetConfig( 0, 'CaptureSNoNotCheckSNoUnique', @cStorerKey)
   SET @cNotCheckScanOut = rdt.RDTGetConfig( @nFunc, 'CaptureSNoNotCheckScanOut', @cStorerKey)
   SET @cCaptureSNoAndQTY = rdt.RDTGetConfig( @nFunc, 'CaptureSNoAndQTY', @cStorerKey)

   -- (ChewKP02)
   SET @cCaptureSNoIterate = rdt.RDTGetConfig( @nFunc, 'CaptureSNoIterate', @cStorerKey)

   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
   BEGIN
      SET @cExtendedValidateSP = ''
   END

   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''


END

GOTO Quit

/********************************************************************************
Step 1. Scn = 870
   PickSlipNo   (Field01)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPickSlipNo = @cInField01



      -- Check PickSlipNo blank
      IF (@cPickSlipNo = '' OR @cPickSlipNo IS NULL)
      BEGIN
         SET @nErrNo = 62501
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PSNo Required
         GOTO Step_1_Fail
      END

      -- Check PickSlipNo valid
      IF NOT EXISTS ( SELECT 1
         FROM dbo.PICKHEADER WITH (NOLOCK)
         WHERE PICKHEADERKEY = @cPickSlipNo)
      BEGIN
         SET @nErrNo = 62502
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNo
         GOTO Step_1_Fail
      END

      -- Check PickSlipNo scanned in
      IF EXISTS( SELECT 1
         FROM dbo.PickHeader PH WITH (NOLOCK)
            LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
         WHERE PH.PickHeaderKey = @cPickSlipNo
            AND [PI].ScanInDate IS NULL)
      BEGIN
         SET @nErrNo = 62503
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS Not Scan In
         GOTO Step_1_Fail
      END

      -- Check PickSlipNo scanned out
      IF @cNotCheckScanOut <> '1'
         IF EXISTS( SELECT 1
            FROM dbo.PickHeader PH WITH (NOLOCK)
               LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
            WHERE PH.PickHeaderKey = @cPickSlipNo
               AND [PI].ScanOutDate IS NULL)
         BEGIN
            SET @nErrNo = 62504
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS Not ScanOut
            GOTO Step_1_Fail
         END

      -- Get counter
      IF LEN( RTRIM( @cCheckSSCC)) > 1
         EXEC rdt.rdt_SerialNoCapture_GetPickSlipIterate
            @cPickSlipNo,
            NULL,
            @nScannedSerialCount OUTPUT,
            @nTotalSerialCount OUTPUT,
            ''    -- (james02)
      ELSE
         EXEC rdt.rdt_SerialNoCapture_GetPickSlipIterate
            @cPickSlipNo,
            NULL,
            @nScannedSerialCount OUTPUT,
            @nTotalSerialCount OUTPUT,
            @cCheckSSCC -- (Vicky03)

      -- Check if PickSlipNo completed
      IF @nScannedSerialCount = @nTotalSerialCount
      BEGIN
         SET @nErrNo = 62505
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS Scanned
         GOTO Step_1_Fail
      END

      -- Prepare next screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = '' -- SKU
      SET @cOutField05 = CAST( @nScannedSerialCount AS NVARCHAR(5)) + '/' + CAST( @nTotalSerialCount AS NVARCHAR(5))

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
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
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cPickSlipNo = ''
      SET @cOutField01 = '' --PickSlipNo
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 872
   PickSlipNo (field01)
   SKU        (field02, input)
   Remaining  (field05)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField02

      -- (ChewKP02)
      IF @cSKU = ''
      BEGIN

         IF @cDecodeLabelNo = ''
         BEGIN
            SET @nErrNo = 62524
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU/UPC needed
            GOTO Step_2_Fail
         END

         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
         GOTO QUIT

      END

      -- Check SKU blank
      IF @cSKU = ''
      BEGIN
         SET @nErrNo = 62506
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU/UPC needed
         GOTO Step_2_Fail
      END

      -- Get SKU/UPC
      DECLARE @nSKUCnt INT
      EXEC [RDT].[rdt_GETSKUCNT]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt   OUTPUT
         ,@bSuccess    = @b_Success OUTPUT
         ,@nErr        = @n_Err     OUTPUT
         ,@cErrMsg     = @c_ErrMsg  OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 62507
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO Step_2_Fail
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 62508
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameBarCodeSKU
         GOTO Step_2_Fail
      END

      -- Get SKU
      EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU       OUTPUT
         ,@bSuccess    = @b_Success  OUTPUT
         ,@nErr        = @n_Err      OUTPUT
         ,@cErrMsg     = @c_ErrMsg   OUTPUT

      -- Get PickSlip info
      DECLARE @cExternOrderKey NVARCHAR( 20)
      DECLARE @cZone           NVARCHAR( 18)
      DECLARE @cSKUInPickSlip  NVARCHAR( 20)
      SELECT TOP 1
         @cExternOrderKey = ExternOrderkey,
         @cOrderKey = OrderKey,
         @cZone = Zone
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo

      -- Check if SKU in picklist
      SET @cSKUInPickSlip = ''
      IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
         SELECT TOP 1 @cSKUInPickSlip = PD.SKU
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON RKL.PickDetailKey = PD.PickDetailKey
         WHERE RKL.PickSlipNo = @cPickSlipNo
            AND PD.SKU = @cSKU
      ELSE
      BEGIN
         -- (ChewKP01)
         IF @cOrderKey <> ''
         BEGIN
            SELECT TOP 1 @cSKUInPickSlip = PD.SKU
            FROM dbo.OrderDetail OD WITH (NOLOCK)
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            WHERE OD.OrderKey = @cOrderKey
               AND PD.SKU = @cSKU
         END
         ELSE
         BEGIN
            SELECT TOP 1 @cSKUInPickSlip = PD.SKU
            FROM dbo.Orders O WITH (NOLOCK)
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
            WHERE O.LoadKey = @cExternOrderKey
               AND O.OrderKey = CASE WHEN @cOrderKey = '' THEN O.OrderKey ELSE @cOrderKey END
               AND PD.SKU = @cSKU
         END
      END

      IF @cSKUInPickSlip = ''
      BEGIN
         SET @nErrNo = 62509
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotInOrder
         GOTO Step_2_Fail
      END

      -- Check if SKU.SUSR4 = SSCC
      IF @cCheckSSCC = '1'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.SKU WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND SKU = @cSKU AND SUSR4 = 'SSCC')
         BEGIN
            SET @nErrNo = 62510
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NonSSCCSKU
            GOTO Step_2_Fail
         END
      END

      -- Get counter
      IF LEN( RTRIM( @cCheckSSCC)) > 1
         EXEC rdt.rdt_SerialNoCapture_GetPickSlipIterate
            @cPickSlipNo,
            @cSKU,
            @nSKUScannedCount OUTPUT,
            @nSKUTotalSerialCount OUTPUT,
            ''
      ELSE
         EXEC rdt.rdt_SerialNoCapture_GetPickSlipIterate
            @cPickSlipNo,
            @cSKU,
            @nSKUScannedCount OUTPUT,
            @nSKUTotalSerialCount OUTPUT,
            @cCheckSSCC

      -- Check if SKU completed
      IF @nSKUTotalSerialCount - @nSKUScannedCount <= 0
      BEGIN
         SET @nErrNo = 62511
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Qty Found
         GOTO Step_2_Fail
      END

      -- Get counter
      IF LEN( RTRIM( @cCheckSSCC)) > 1
         EXEC rdt.rdt_SerialNoCapture_GetPickSlipIterate
            @cPickSlipNo,
            @cSKU,
            @nSKUScannedCount OUTPUT,
            @nSKUTotalSerialCount OUTPUT,
            ''
      ELSE
         EXEC rdt.rdt_SerialNoCapture_GetPickSlipIterate
            @cPickSlipNo,
            @cSKU,   -- (james04)
            @nScannedSerialCount OUTPUT,
            @nTotalSerialCount OUTPUT,
            @cCheckSSCC -- (Vicky03)

      -- Check if PickSlipNo completed
      IF @nScannedSerialCount = @nTotalSerialCount
      BEGIN
         SET @nErrNo = 62512
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scanned All
         GOTO Step_2_Fail
      END

      -- Prepare next screen var
      SET @cLotNo = ''
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @cSKU
      SET @cOutField03 = '' -- LOT
      SET @cOutField05 = CAST( @nScannedSerialCount AS NVARCHAR(5)) + '/' + CAST( @nTotalSerialCount AS NVARCHAR(5))
      IF @cShowLot = '1'
      BEGIN
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         SET @cSerialNo = ''
         SET @cOutField04 = '' -- SerialNo
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
      END
   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      --INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3) VALUES ('870STEP2_0', GETDATE(), @cPickSlipNo, @nScannedSerialCount, @nTotalSerialCount)
      SET @nScannedSerialCount = 0
      SET @nTotalSerialCount = 0
      -- Get counter
      IF LEN( RTRIM( @cCheckSSCC)) > 1
         EXEC rdt.rdt_SerialNoCapture_GetPickSlipIterate
            @cPickSlipNo,
            NULL,
            @nScannedSerialCount OUTPUT,
            @nTotalSerialCount OUTPUT,
            ''
      ELSE
         EXEC rdt.rdt_SerialNoCapture_GetPickSlipIterate
            @cPickSlipNo,
            NULL,
            @nScannedSerialCount OUTPUT,
            @nTotalSerialCount OUTPUT,
            @cCheckSSCC
      --INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3) VALUES ('870STEP2_1', GETDATE(), @cPickSlipNo, @nScannedSerialCount, @nTotalSerialCount)
      IF @nScannedSerialCount = @nTotalSerialCount
      BEGIN
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
         SET @cOutField01 = '' --PickSlipNo
      END

      -- Go to short pick screen
      IF @nScannedSerialCount < @nTotalSerialCount
      BEGIN
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = '' -- Option
         SET @nScn = @nScn + 4
         SET @nStep = @nStep + 4
      END
   END
   GOTO QUIT

   Step_2_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cOutField02 = '' -- SKU
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 874
   PickSlipNo (field01)
   SKU        (field02)
Lot        (field03, input)
   Remaining  (field05)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLotNo = @cInField03

      -- Check LotNo blank
      IF @cLotNo = ''
      BEGIN
         SET @nErrNo = 62513
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LotNo Required
         GOTO Step_3_Fail
      END

      -- Prep next screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @cSKU
      SET @cOutField03 = @cLotNo
      SET @cOutField04 = '' -- SerialNo
      SET @cOutField05 = CAST( @nScannedSerialCount AS NVARCHAR(5)) + '/' + CAST( @nTotalSerialCount AS NVARCHAR(5))

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = '' --SKU
      SET @cOutField05 = CAST( @nScannedSerialCount AS NVARCHAR(5)) + '/' + CAST( @nTotalSerialCount AS NVARCHAR(5))
   END
   GOTO QUIT

   Step_3_Fail:
   BEGIN
      SET @cLotNo = ''
      SET @cOutField03 = '' -- LOT
   END
END
GOTO Quit


/********************************************************************************
Step 4. Scn = 874
   PickSlipNo (field01)
   SKU        (field02)
   Lot        (field03)
   SerialNo   (field04, input)
   Remaining  (field05)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSerialNo = @cInField04
      SET @nQTY = 1

      -- Check SerialNo blank
      IF @cSerialNo = ''
      BEGIN
         SET @nErrNo = 62514
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SerialNo
         GOTO Step_4_Fail
      END

      -- (james06)
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'SERIAL', @cSerialNo) = 0
      BEGIN
         SET @nErrNo = 62525
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_4_Fail
      END

      IF @cDecodeLabelNo <> ''
      BEGIN
         SET @c_oFieled01 = @cSKU
         SET @c_oFieled05 = @cQTY

         SELECT TOP 1
            @cOrderKey = OrderKey
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickSlipNo


         EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @cSerialNo
            ,@c_Storerkey  = @cStorerkey
            ,@c_ReceiptKey = @cPickSlipNo -- PickSlipNo
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
            ,@b_Success    = @b_Success   OUTPUT
            ,@n_ErrNo      = @nErrNo      OUTPUT
            ,@c_ErrMsg     = @cErrMsg     OUTPUT

         IF ISNULL(@cErrMsg, '') <> ''
         BEGIN
            DECLARE @cErrMsg1 NVARCHAR(20)
            SET @cErrMsg1 = @cErrMsg
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            GOTO Step_4_Fail
         END

         SET @cSKU = @c_oFieled01
         SET @cQTY = @c_oFieled05



      END

      -- (james03)
 -- If rdt CheckSSCC config has value 1 then check len of serialno
      -- If len of config > 1 and is a valid sp name then use customised sp to check for serial no validity
      IF LEN( RTRIM( @cCheckSSCC)) > 1 AND
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCheckSSCC AND type = 'P')
      BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCheckSSCC) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cSerialNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,       '     +
               '@nFunc        INT,       '     +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,       '     +
               '@nInputKey    INT,       '     +
               '@cSerialNo    NVARCHAR( 30)  OUTPUT, ' +
               '@nErrNo       INT OUTPUT,  ' +
               '@cErrMsg      NVARCHAR( 20)  OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cSerialNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_4_Fail
      END
      ELSE
      BEGIN
         -- Check SSCC
         IF @cCheckSSCC = '1'
         BEGIN
            DECLARE @nSerialLength INT
            SET @nSerialLength = LEN( RTRIM( @cSerialNo))

            -- Check label length
            IF @nSerialLength > 13 AND @nSerialLength <= 19
            BEGIN
               SET @nErrNo = 62515
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Serial No
               GOTO Step_4_Fail
            END

            -- Truncate serial no
            IF @nSerialLength > 18
            BEGIN
               SET @cSerialNo = RIGHT( RTRIM( @cSerialNo), 18)
               SET @nSerialLength = LEN( RTRIM( @cSerialNo))
            END

            -- Get QTY
            IF @nSerialLength < 18
               SET @nQTY = 1

            IF @nSerialLength = 18
            BEGIN
               -- Get case count
               DECLARE @nCaseCnt INT
               SELECT @nCaseCnt = CAST( P.CaseCnt AS INT)
               FROM dbo.PACK P WITH (NOLOCK)
                  JOIN dbo.SKU S WITH (NOLOCK) ON (P.Packkey = S.Packkey)
               WHERE S.Storerkey = @cStorerkey
                  AND S.SKU = @cSKU

               -- Check case count valid
               IF @nCaseCnt < 1
               BEGIN
                  SET @nErrNo = 62516
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoCaseCnt
                  GOTO Step_4_Fail
               END

               SET @nQTY = @nCaseCnt
            END
         END
      END

      -- Truncate serial no
      IF LEN( RTRIM( @cSerialNo)) > 18 AND ( ISNULL( @cCheckSSCC, '') = '' OR @cCheckSSCC = '0')
         SET @cSerialNo = RIGHT( RTRIM( @cSerialNo), 18)

      SET @cSerialNo1 = SUBSTRING( RTRIM( @cSerialNo),  1, 20)  -- (james02)
      SET @cSerialNo2 = SUBSTRING( RTRIM( @cSerialNo), 21, 10)  -- (james02)

      -- Check SerialNo unique
      IF @cNotCheckSNoUnique <> '1'
      BEGIN
         IF @cShowLot = '1'
         BEGIN
            IF EXISTS (SELECT 1 FROM dbo.SerialNO WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SerialNo = @cSerialNo AND LotNo = @cLotNo)
            BEGIN
               SET @nErrNo = 62517
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Dup SNo+LotNo
               GOTO Step_4_Fail
            END
         END
         ELSE
         BEGIN
            IF EXISTS (SELECT 1 FROM dbo.SerialNO WITH (NOLOCK) WHERE StorerKey = @cStorerkey AND SerialNo = @cSerialNo)
            BEGIN
               SET @nErrNo = 62518
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Duplicate SNo
               GOTO Step_4_Fail
            END
         END
      END

      IF @cExtendedValidateSP <> ''
      BEGIN

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN


            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cSKU, @cOrderKey, @cSerialNo, @cLotNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT, ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cSKU           NVARCHAR( 20), ' +
               '@cOrderKey      NVARCHAR( 10), ' +
               '@cSerialNo      NVARCHAR( 20), ' +
               '@cLotNo         NVARCHAR( 20), ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT'


            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cSKU, @cOrderKey, @cSerialNo, @cLotNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO QUIT
            END

         END
      END

      -- Capture QTY
      IF @cCaptureSNoAndQTY = '1'
      BEGIN
         -- Prepare next screen var
         IF @cDecodeLabelNo <> ''
         BEGIN
            SET @cOutField01 = @cQty
         END
         ELSE
         BEGIN
            SET @cOutField01 = '' -- QTY
         END

         -- Go to SKU screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit
      END


      -- Check QTY
      IF (@nQTY + @nScannedSerialCount) > @nTotalSerialCount
      BEGIN
         SET @nErrNo = 62519
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY over scan
         GOTO Step_4_Fail
      END

      -- Insert SerialNo
      EXECUTE rdt.rdt_SerialNoCapture_Confirm
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode,
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT,
         @cOrderKey   = @cOrderKey,
         @cStorerKey  = @cStorerKey,
         @cSKU        = @cSKU,
         @cLotNo      = @cLotNo,
         @cSerialNo   = @cSerialNo,
         @nQTY        = @nQTY
      IF @nErrNo <> 0
         GOTO Step_4_Fail

      -- (ChewKP02)
      IF @cCaptureSNoIterate = '1'
      BEGIN
          IF LEN( RTRIM( @cCheckSSCC)) > 1
            EXEC rdt.rdt_SerialNoCapture_GetPickSlipIterate
               @cPickSlipNo,
               NULL,
               @nScannedSerialCount OUTPUT,
               @nTotalSerialCount OUTPUT,
               ''    -- (james02)
          ELSE
            EXEC rdt.rdt_SerialNoCapture_GetPickSlipIterate
               @cPickSlipNo,
               NULL,
               @nScannedSerialCount OUTPUT,
               @nTotalSerialCount OUTPUT,
               @cCheckSSCC -- (Vicky03)

         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = @cSKU
         SET @cOutField03 = '' -- LOT
         SET @cOutField05 = CAST( @nScannedSerialCount AS NVARCHAR(5)) + '/' + CAST( @nTotalSerialCount AS NVARCHAR(5))

      END
      ELSE
      BEGIN
         -- Prepare next screen var
         SET @nScannedSerialCount = @nScannedSerialCount + @nQTY
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = '' -- SKU
         SET @cOutField05 = CAST( @nScannedSerialCount AS NVARCHAR(5)) + '/' + CAST( @nTotalSerialCount AS NVARCHAR(5))

         -- Go to SKU screen
         SET @nScn  = @nScn - 2
         SET @nStep = @nStep - 2
      END

   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      IF LEN( RTRIM( @cCheckSSCC)) > 1
      EXEC rdt.rdt_SerialNoCapture_GetPickSlipIterate
         @cPickSlipNo,
         NULL,
         @nScannedSerialCount OUTPUT,
         @nTotalSerialCount OUTPUT,
         ''    -- (james02)
      ELSE
      EXEC rdt.rdt_SerialNoCapture_GetPickSlipIterate
         @cPickSlipNo,
         NULL,
         @nScannedSerialCount OUTPUT,
         @nTotalSerialCount OUTPUT,
         @cCheckSSCC -- (Vicky03)

      IF @cShowLot = '1'
      BEGIN
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = @cSKU
         SET @cOutField03 = '' -- LOT
         SET @cOutField05 = CAST( @nScannedSerialCount AS NVARCHAR(5)) + '/' + CAST( @nTotalSerialCount AS NVARCHAR(5))

         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = '' -- SKU
         SET @cOutField05 = CAST( @nScannedSerialCount AS NVARCHAR(5)) + '/' + CAST( @nTotalSerialCount AS NVARCHAR(5))

         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
      END
   END

   Step_4_Fail:
   BEGIN
      SET @cSerialNo = ''
      SET @cOutField04 = '' -- SerialNo
   END
END
GOTO Quit


/********************************************************************************
Step 5. Sscn = 875
   QTY (Field01, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN


      -- Screen mapping
      SET @cQTY = @cInField01


      -- Check QTY blank
      IF @cQTY = ''
      BEGIN
         SET @nErrNo = 62520
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY required
         GOTO Step_5_Fail
      END

      -- Check QTY valid
      IF RDT.rdtIsValidQTY( @cQTY, 1) = 0
      BEGIN
         SET @nErrNo = 62521
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         GOTO Step_5_Fail
      END
      SET @nQTY = @cQTY

      -- Check QTY
      IF (@nQTY + @nScannedSerialCount) > @nTotalSerialCount
      BEGIN
         SET @nErrNo = 62522
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY over scan
         GOTO Step_5_Fail
      END

      SET @cSerialNo = @cSerialNo1 + @cSerialNo2 -- (ChewKP02)

      -- Insert SerialNo
      EXECUTE rdt.rdt_SerialNoCapture_Confirm
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode,
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT,
         @cOrderKey   = @cOrderKey,
         @cStorerKey  = @cStorerKey,
         @cSKU        = @cSKU,
         @cLotNo      = @cLotNo,
         @cSerialNo   = @cSerialNo,
         @nQTY        = @nQTY
      IF @nErrNo <> 0
         GOTO Step_5_Fail


      --(ChewKP02)
      IF @cCaptureSNoIterate = '1'
      BEGIN

         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = @cSKU
         SET @cOutField03 = '' -- LOT
         SET @cOutField05 = CAST( @nScannedSerialCount AS NVARCHAR(5)) + '/' + CAST( @nTotalSerialCount AS NVARCHAR(5))

         SET @nScn  = @nScn - 1
         SET @nStep = @nStep - 1
      END
      ELSE
      BEGIN
         -- Prepare next screen var
         SET @nScannedSerialCount = @nScannedSerialCount + @nQTY
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = '' -- SKU
         SET @cOutField05 = CAST( @nScannedSerialCount AS NVARCHAR(5)) + '/' + CAST( @nTotalSerialCount AS NVARCHAR(5))

         -- Go to UPC screen
         SET @nScn  = @nScn - 3
         SET @nStep = @nStep - 3
      END
   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @cSKU -- SKU
      SET @cOutField03 = @cLotNo
      SET @cOutField04 = '' -- SerialNo
      SET @cOutField05 = CAST( @nScannedSerialCount AS NVARCHAR(5)) + '/' + CAST( @nTotalSerialCount AS NVARCHAR(5))

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_5_Fail:
END
GOTO Quit


/********************************************************************************
Step 6. Scn = 875
   PickSlipNo (field01)
   short picked.

   Pls scan again
   or unallocated.

   1 = scan again
   2 = unallocated
   Option (field02, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cOption NVARCHAR( 1)

      -- Screen mapping
      SET @cOption = @cInField02

      -- Check option valid
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 62523
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         SET @cOutField02 = ''
         SET @cOption = ''
         GOTO Quit
      END

      IF @cOption = '1' -- Back to SKU screen
      BEGIN
         SET @nScn = @nScn - 4
         SET @nStep = @nStep - 4
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = '' -- SKU
         GOTO Quit
      END

      IF @cOption = '2' -- Back to PickSlipNo screen
      BEGIN
         SET @nScn = @nScn - 5
         SET @nStep = @nStep - 5
         SET @cOutField01 = '' --@cPickSlipNo
         GOTO Quit
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
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func = @nFunc,
      Step = @nStep,
      Scn = @nScn,

      V_PickSlipNo = @cPickSlipNo,
      V_SKU        = @cSKU,
      V_SKUDescr   = @cDescr,
      V_OrderKey   = @cOrderKey,
      V_Qty        = @cQty,

      V_String1    = @nScannedSerialCount,
      V_String2    = @nTotalSerialCount,
      V_String3    = @nSKUScannedCount,
      V_String4    = @nSKUTotalSerialCount,
      V_String5    = @cLotNo,
--      V_String6    = @cSerialNo,     -- (james03)
      V_String7    = @cShowLot,
      V_String8    = @cCheckSSCC,
      V_String9    = @cNotCheckSNoUnique,
      V_String10   = @cNotCheckScanOut,
      V_String11   = @cCaptureSNoAndQTY,
      V_String12   = @cSerialNo1,      -- (james03)
      V_String13   = @cSerialNo2,      -- (james03)
      V_String14   = @cCaptureSNoIterate, -- (ChewKP02)
      V_String15   = @cExtendedValidateSP, -- (ChewKP02)
      V_String16   = @cDecodeLabelNo,  -- (ChewKP02)

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
      I_Field15 = @cInField15,  O_Field15 = @cOutField15

   WHERE Mobile = @nMobile
END

GO