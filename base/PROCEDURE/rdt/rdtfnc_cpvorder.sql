SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_CPVOrder                                     */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Serial no capture by ext orderkey + sku                     */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 11-Aug-2018 1.0  Ung        WMS-5368 Created                         */
/* 07-Mar-2019 1.1  ChewKP     Changes                                  */
/* 08-MAr-2019 1.2  ChewKP     Fixes                                    */
/* 26-Jul-2021 1.3  Chermaine  WMS-17552 Add busr10 in scn2& 5(cc01)    */
/* 03-Sep-2021 1.4  Chermaine  WMS-17762 Change Varian msg display(cc02)*/
/* 02-Oct-2023 1.5  Ung        WMS-23702 Allocate upon close order      */ 
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_CPVOrder] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc var
DECLARE
   @bSuccess         INT,
   @nRowCount        INT,
   @cChkSKU          NVARCHAR(20),
   @cOption          NVARCHAR(1),
   @cExternLotStatus NVARCHAR(10),
   @dExpiryDate      DATETIME,
   @nShelfLife       INT,
   @nInnerPack       INT,
   @dToday           DATETIME

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @cUserName   NVARCHAR( 10),
   @nInputKey   INT,
   @nMenu       INT,

   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),

   @cOrderKey         NVARCHAR( 30),
   @cSKU              NVARCHAR( 20),
   @cDesc             NVARCHAR( 60),
   @dExternLottable04 DATETIME,
   @cLottable07       NVARCHAR( 30),
   @cLottable08       NVARCHAR( 30),

   @cScan             NVARCHAR( 10),
   @cTotal            NVARCHAR( 10),

   @cBarcode          NVARCHAR( 60),
   @cNonSerializeSKU  NVARCHAR( 20),
   @nNonSerializeQty  INT,
   @cNonSerializeLot  NVARCHAR( 60),
   @cBusr10           NVARCHAR( 20),  --(cc01)


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
   @cUserName   = UserName,

   @cStorerKey  = StorerKey,
   @cFacility   = Facility,

   @cOrderKey         = V_OrderKey,
   @cSKU              = V_SKU,
   @cDesc             = V_SKUDescr,
   @dExternLottable04 = V_Lottable04,
   @cLottable07       = V_Lottable07,
   @cLottable08       = V_Lottable08,

   @cScan             = V_String1,
   @cTotal            = V_String2,
   @cBusr10           = V_String3,  --(cc01)


   @cBarcode          = V_String41,

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

FROM rdt.RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 631 -- Serial no capture by order SKU
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = 631
   IF @nStep = 1 GOTO Step_1   -- 5260 OrderKey
   IF @nStep = 2 GOTO Step_2   -- 5261 LOT
   IF @nStep = 3 GOTO Step_3   -- 5262 Close order?
   IF @nStep = 4 GOTO Step_4   -- 5263 Reset order?
   IF @nStep = 5 GOTO Step_5   -- 5264 Multi SKU selection
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 631. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 5260
   SET @nStep = 1

   -- Initiate var
   SET @cOrderKey = ''
   SET @cSKU = ''

   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 5260
   ORDER KEY  (Field01, input)
   OPTION     (Field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOrderKey = @cInField01
      SET @cOption = @cInField02

      IF @cOrderKey = ''
      BEGIN
         SET @nErrNo = 125001
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need OrderKey
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Order
         GOTO Quit
      END

      -- Get order info
      DECLARE @cChkFacility   NVARCHAR(5)
      DECLARE @cChkStorerKey  NVARCHAR(15)
      DECLARE @cStatus        NVARCHAR(10)
      DECLARE @cSOStatus      NVARCHAR(10)
      SELECT
         @cChkFacility = Facility,
         @cChkStorerKey = StorerKey,
         @cStatus = Status,
         @cSOStatus = SOStatus
      FROM Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      -- Check order valid
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 125002
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid order
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Order
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check diff storer
      IF @cChkStorerKey <> @cStorerKey
      BEGIN
         SET @nErrNo = 125003
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Order
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check diff facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 125004
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Order
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check status
      IF @cStatus = '9'
      BEGIN
         SET @nErrNo = 125005
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order picked
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Order
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check status
      IF @cSOStatus = 'CANC'
      BEGIN
         SET @nErrNo = 125006
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Order
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check status
      IF @cOption <> '' AND @cOption <> '1'
      BEGIN
         SET @nErrNo = 125022
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Option
         SET @cOutField02 = ''
         GOTO Quit
      END



      -- Reset
      IF @cOption = '1'
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = '' -- Option

         SET @nScn = @nScn + 3
         SET @nStep = @nStep + 3
      END
      ELSE
      BEGIN


         SET @cSKU = ''
         SET @cDesc = ''
         SET @cScan = '0'
         SET @cTotal = '0'

         -- Prep next screen var
         SET @cOutField01 = @cOrderKey
         SET @cOutField02 = '' -- LOT
         SET @cOutField03 = '' -- SKU
         SET @cOutField04 = '' -- Desc1
         SET @cOutField05 = '' -- Desc2
         SET @cOutField06 = '' -- Desc3
         SET @cOutField07 = @cScan + '/' + @cTotal
         SET @cOutField08 = '' --busr10

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
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
       @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option
   END
   GOTO Quit
END
GOTO Quit


/********************************************************************************
Step 2. Screen = 5261
   ORDER KEY   (Field01)
   LOT         (Field02, input)
   SKU         (Field03)
   Busr10      (Field08)    --(cc01)
   DESC1       (Field04)
   DESC2       (Field05)
   DESC3       (Field06)
   SCAN/TOTAL  (Field07)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cBarcode = @cInField02

      -- Check blank
      IF @cBarcode = ''
      BEGIN
         SET @nErrNo = 125011
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOT
         GOTO Quit
      END

      -- In future MasterLOT could > 30 chars, need to use 2 lottables field
      SET @cLottable07 = ''
      SET @cLottable08 = ''

      -- Decode to abstract master LOT
      EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
         @cLottable07 = @cLottable07 OUTPUT,
         @cLottable08 = @cLottable08 OUTPUT,
         @nErrNo  = @nErrNo  OUTPUT,
         @cErrMsg = @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Check barcode format
      IF @cLottable07 = '' AND @cLottable08 = ''
      BEGIN
         SET @nErrNo = 125012
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format
         SET @cOutField02 = ''
         GOTO Quit
      END

      DECLARE @cMasterLOT NVARCHAR(60)
      SELECT @cMasterLOT = @cLottable07 + @cLottable08

      -- Get master LOT info
      SELECT
         @cChkSKU = SKU,
         @cExternLotStatus = ExternLotStatus,
         @dExternLottable04 = ExternLottable04
      FROM ExternLotAttribute WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ExternLOT = @cMasterLOT

      SET @nRowCount = @@ROWCOUNT

      -- Check SKU in order
      IF @nRowCount = 1
      BEGIN
         IF NOT EXISTS( SELECT TOP 1 1
            FROM OrderDetail WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
               AND StorerKey = @cStorerKey
               AND SKU = @cChkSKU)
         BEGIN
            SET @nErrNo = 125026
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotInOrder
            SET @cOutField02 = ''
            GOTO Quit
         END

         SET @cSKU = @cChkSKU
      END

      -- Check master LOT valid
      ELSE IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 125013
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SNO
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Check multi SKU extern LOT
      ELSE -- IF @nRowCount > 1
      BEGIN
         SET @cChkSKU = ''
         EXEC rdt.rdt_CPVMultiSKUExtLOT @nMobile, @nFunc, @cLangCode,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,
            'POPULATE',
            @cMasterLOT,
            @cStorerKey,
            @cChkSKU    OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT

         IF @nErrNo = 0 -- Populate multi SKU screen
         BEGIN
            -- Go to Multi SKU screen
            SET @nScn = @nScn + 3
            SET @nStep = @nStep + 3
            GOTO Quit
         END
      END

      -- Check master LOT status
      IF @cExternLotStatus <> 'ACTIVE'
      BEGIN
         SET @nErrNo = 125014
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inactive LOT
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Get SKU info
      SELECT
         @cDesc = SKU.Descr,
         @nShelfLife = SKU.ShelfLife,
         @nInnerPack = Pack.InnerPack,
         @cBusr10 = SUBSTRING( SKU.BUSR10 , 1, 20)    --(cc01)
      FROM SKU WITH (NOLOCK)
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

      -- Calc expiry date
      SET @dToday = CONVERT( DATE, GETDATE())
      SET @dExpiryDate = @dExternLottable04
      IF @nShelfLife > 0
         SET @dExpiryDate = DATEADD( dd, -@nShelfLife, @dExternLottable04)

      -- Check expired stock
      IF @dExpiryDate < @dToday
      BEGIN
         SET @nErrNo = 125015
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Stock expired
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Confirm
      EXEC rdt.rdt_CPVOrder_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
         @cOrderKey,
         @cSKU,
         @nInnerPack,
         @cBarcode    = @cBarcode,
         @cLottable07 = @cLottable07,
         @cLottable08 = @cLottable08,
         @cScan       = @cScan   OUTPUT,
         @cTotal      = @cTotal  OUTPUT,
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Init next screen var
      SET @cOutField01 = @cOrderKey
      SET @cOutField02 = '' -- LOT
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cDesc,  1, 20) -- SKUDesc1
      SET @cOutField05 = SUBSTRING( @cDesc, 21, 20) -- SKUDesc2
      SET @cOutField06 = SUBSTRING( @cDesc, 41, 20)
      SET @cOutField07 = @cScan + '/' + @cTotal
      SET @cOutField08 = @cBusr10  --(cc01)
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
--      IF EXISTS( SELECT 1 FROM rdtCPVOrderLog WITH (NOLOCK) WHERE OrderKey = @cOrderKey)
--      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- OPTION

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
--      END
--      ELSE
--      BEGIN
--         -- Prepare next screen var
--         SET @cOutField01 = '' -- OrderKey
--         SET @cOutField02 = '' -- Option
--
--         SET @nScn = @nScn - 1
--         SET @nStep = @nStep - 1
--      END
   END
END
GOTO Quit


/********************************************************************************
Step 3. Screen = 5262. CLOSE ORDER?
   OPTION (Field01, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 125016
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need OPTION
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check blank
      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 125017
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid OPTION
         SET @cOutField01 = ''
         GOTO Quit
      END

      IF @cOption = '1'
      BEGIN

         -- INSERT INTO rdt.rdtCPVOrderLog for Label Item which SKU.SerialNoCapture = '2'
         IF EXISTS ( SELECT 1 FROM dbo.OrderDetail OD WITH (NOLOCK)
                     INNER JOIN dbo.SKU SKU WITH (NOLOCK)  ON SKU.SKU = OD.SKU AND SKU.StorerKey = OD.StorerKey
                     WHERE OD.StorerKey = @cStorerKey
                     AND OD.OrderKey = @cOrderKey
                     AND SKU.SerialNoCapture = '2')
         BEGIN


            DECLARE @curLog CURSOR

            SET @curLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT OD.SKU, SUM(OD.OpenQty)
            FROM dbo.OrderDetail OD WITH (NOLOCK)
            INNER JOIN dbo.SKU SKU WITH (NOLOCK)  ON SKU.SKU = OD.SKU AND SKU.StorerKey = OD.StorerKey
            WHERE OD.StorerKey = @cStorerKey
            AND OD.OrderKey = @cOrderKey
            AND SKU.SerialNoCapture = '2'
            GROUP BY OD.SKU
            ORDER BY OD.SKU

            OPEN @curLog
            FETCH NEXT FROM @curLog INTO @cNonSerializeSKU , @nNonSerializeQty
            WHILE @@FETCH_STATUS = 0
            BEGIN

               SELECT
                  @cNonSerializeLot = ISNULL(ExternLot,'')
               FROM ExternLotAttribute WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND SKU = @cNonSerializeSKU

               IF NOT EXISTS ( SELECT 1 FROM rdt.rdtCPVOrderLog WITH (NOLOCK)
                               WHERE StorerKey = @cStorerKey
                               AND OrderKey = @cOrderKey
                               AND SKU = @cNonSerializeSKU
                               AND Lottable07 = @cNonSerializeLot
                               AND Lottable07 = @cNonSerializeLot
                               AND Qty = @nNonSerializeQty)
               BEGIN
                  INSERT INTO rdt.rdtCPVOrderLog
                     (Mobile, OrderKey, StorerKey, SKU, QTY, Barcode, Lottable07, Lottable08)
                  VALUES
                     (@nMobile, @cOrderKey, @cStorerKey, @cNonSerializeSKU, @nNonSerializeQty, @cNonSerializeLot, @cNonSerializeLot, '')

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 125028
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LOG Fail
                     GOTO QUIT
                  END
               END
               FETCH NEXT FROM @curLog INTO @cNonSerializeSKU , @nNonSerializeQty
            END
         END


         DECLARE @cVarSKU     NVARCHAR(20)
         DECLARE @cVarDesc    NVARCHAR(60)
         DECLARE @cVarBusr10  NVARCHAR(20) --(cc01)
         DECLARE @nVarInner   INT
         DECLARE @nOrderQTY   INT
         DECLARE @nLogQTY     INT

         DECLARE @tVarianList TABLE    --(cc02)
         (
         	Num         INT IDENTITY(1,1) NOT NULL,
            VarSku      NVARCHAR(20),
            VarQty      INT
         )


         -- Get variance
         INSERT INTO @tVarianList (VarSku,VarQty) --(cc02)
         SELECT --Top 1
            --@cVarSKU = OD.SKU,
            --@nOrderQTY = OD.QTY ,
            --@nLogQTY = ISNULL( L.QTY, 0),
            OD.SKU + SPACE(17-LEN(OD.SKU)),
            --OD.QTY - ISNULL( L.QTY, 0)
            (CASE WHEN P.InnerPack > 0 THEN OD.QTY/ P.InnerPack ELSE OD.QTY END) -
            (CASE WHEN P.InnerPack > 0 THEN ISNULL( L.QTY, 0)/ P.InnerPack ELSE ISNULL( L.QTY, 0) END)
         FROM
         (
            SELECT StorerKey, SKU, ISNULL( SUM( OpenQTY) - SUM(QtyAllocated) , 0) QTY
            FROM OrderDetail OD WITH (NOLOCK)
            WHERE OD.OrderKey = @cOrderKey
            GROUP BY StorerKey, SKU
            HAVING ISNULL( SUM( OpenQTY) - SUM(QtyAllocated) , 0) > 0
         ) OD LEFT JOIN
         (
            SELECT StorerKey, SKU, ISNULL( SUM( QTY), 0) QTY
            FROM rdt.rdtCPVOrderLog L WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
            GROUP BY StorerKey, SKU
         ) L ON (OD.StorerKey = L.StorerKey AND OD.SKU = L.SKU)
         LEFT JOIN SKU S WITH (NOLOCK) ON (OD.SKU = S.SKU AND OD.StorerKey = S.storerKey)
         LEFT JOIN Pack P WITH (NOLOCK) ON (S.PackKey = P.PackKey)
         WHERE L.SKU IS NULL
            OR (L.QTY <> OD.QTY)

         SET @nRowCount = @@ROWCOUNT

         -- Check variance
         IF @nRowCount > 0
         BEGIN
            DECLARE @cMsg1     NVARCHAR( 20)
            DECLARE @cMsg2     NVARCHAR( 20)
            DECLARE @cMsg3     NVARCHAR( 20)
            DECLARE @cMsg4     NVARCHAR( 20)
            DECLARE @cMsg5     NVARCHAR( 20)
            DECLARE @cMsg6     NVARCHAR( 20)
            DECLARE @cMsg7     NVARCHAR( 20)
            DECLARE @cMsg8     NVARCHAR( 20)
            DECLARE @cMsg9     NVARCHAR( 20)
            DECLARE @cMsg10    NVARCHAR( 20)
            --DECLARE @cMsg11    NVARCHAR( 20)
            --DECLARE @cMsg12    NVARCHAR( 20)
            --DECLARE @cMsg13    NVARCHAR( 20)
            --DECLARE @cMsg14    NVARCHAR( 20)
            --DECLARE @cMsg15    NVARCHAR( 20)

            --SELECT
            --   @cVarDesc = Descr,
            --   @nVarInner = Pack.InnerPack,
            --   @cVarBusr10 = SUBSTRING( SKU.BUSR10 , 1, 20) --(cc01)
            --FROM SKU WITH (NOLOCK)
            --   JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            --WHERE StorerKey = @cStorerKey
            --   AND SKU = @cVarSKU

            --IF @nVarInner > 0
            --BEGIN
            --   SET @nOrderQTY = @nOrderQTY / @nVarInner
            --   SET @nLogQTY = @nLogQTY / @nVarInner
            --END

            SET @cMsg1 = rdt.rdtgetmessage( 125023, @cLangCode, 'DSP') --Variance found:
            SET @cMsg2 = 'Total SKU:' + CONVERT(NVARCHAR(3),@nRowCount)--''
            SET @cMsg3 = (SELECT VarSKU + CONVERT(NVARCHAR(3),VarQty) FROM @tVarianList WHERE Num = 1) --@cVarSKU
            SET @cMsg4 = (SELECT VarSKU + CONVERT(NVARCHAR(3),VarQty) FROM @tVarianList WHERE Num = 2) --@cVarBusr10
            SET @cMsg5 = (SELECT VarSKU + CONVERT(NVARCHAR(3),VarQty) FROM @tVarianList WHERE Num = 3) --SUBSTRING( @cVarDesc, 1, 20)
            SET @cMsg6 = (SELECT VarSKU + CONVERT(NVARCHAR(3),VarQty) FROM @tVarianList WHERE Num = 4) --SUBSTRING( @cVarDesc, 21, 20)
            SET @cMsg7 = (SELECT VarSKU + CONVERT(NVARCHAR(3),VarQty) FROM @tVarianList WHERE Num = 5) --SUBSTRING( @cVarDesc, 41, 20)
            SET @cMsg8 = (SELECT VarSKU + CONVERT(NVARCHAR(3),VarQty) FROM @tVarianList WHERE Num = 6) --''
            SET @cMsg9 = (SELECT VarSKU + CONVERT(NVARCHAR(3),VarQty) FROM @tVarianList WHERE Num = 7) --RTRIM( rdt.rdtgetmessage( 125024, @cLangCode, 'DSP')) + ' ' + --ORDER QTY:
                         --CAST( @nOrderQTY AS NVARCHAR(10))
            SET @cMsg10 = (SELECT VarSKU + CONVERT(NVARCHAR(3),VarQty) FROM @tVarianList WHERE Num = 8) --RTRIM( rdt.rdtgetmessage( 125025, @cLangCode, 'DSP')) + ' ' + --SCAN  QTY:
                         --CAST( @nLogQTY AS NVARCHAR(10))
            --SET @cMsg11 = ''
            --SET @cMsg12 = ''
            --SET @cMsg13 = ''
            --SET @cMsg14 = ''
            --SET @cMsg15 = ''

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
               @cMsg1, @cMsg2, @cMsg3, @cMsg4, @cMsg5, @cMsg6, @cMsg7, @cMsg8, @cMsg9, @cMsg10
               --, @cMsg11 , @cMsg12 , @cMsg13 , @cMsg14 , @cMsg15

            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Submit for allocation schedule
         UPDATE Orders SET
            UserDefine10 = 'PENDALLOC',
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE()
         WHERE OrderKey = @cOrderKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 125019
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Order Fail
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Change to allocate by RDT (after migrated Exceed to SCE, it takes too many clicks to allocate an order)
         EXEC dbo.isp_RCM_ORD_CPV
            @cOrderKey,
            @bSuccess   OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT,
            @c_Code = ''
         IF @bSuccess <> 1 OR @nErrNo <> 0
         BEGIN
            --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @cErrMsg
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = '' -- OrderKey

      -- Go to Order screen
      SET @nScn  = @nScn - 2
      SET @nStep = @nStep - 2
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cOrderKey
      SET @cOutField02 = '' -- LOT
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cDesc, 1, 20)
      SET @cOutField05 = SUBSTRING( @cDesc, 21, 20)
      SET @cOutField06 = SUBSTRING( @cDesc, 41, 20)
      SET @cOutField07 = @cScan + '/' + @cTotal

      -- Go back LOT screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Step 4. Screen = 5264. RESET ORDER?
   OPTION (Field01, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 125020
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need OPTION
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check blank
      IF @cOption NOT IN ('1', '3', '9')
      BEGIN
         SET @nErrNo = 125021
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid OPTION
         SET @cOutField01 = ''
         GOTO Quit
      END

      IF @cOption IN ( '1' ,'3' )
      BEGIN
         -- Reset
         EXEC rdt.rdt_CPVOrder_Reset @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
            @cOrderKey, @cOption,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END

      -- Prepare next screen var
      SET @cOutField01 = '' -- OrderKey
      SET @cOutField02 = '' -- Option

      -- Go to Order screen
      SET @nScn  = @nScn - 3
      SET @nStep = @nStep - 3
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cOrderKey
      SET @cOutField02 = '' -- Option

      -- Go back order screen
      SET @nScn  = @nScn - 3
      SET @nStep = @nStep - 3
   END
END
GOTO Quit


/********************************************************************************
Step 5. Screen = 5264. Multi SKU
   SKU         (Field01)
   burs10      (Field11)   --(cc01)
   SKUDesc1    (Field02)
   SKUDesc2    (Field03)
   SKU         (Field04)
   SKUDesc1    (Field05)
   SKUDesc2    (Field06)
   SKU         (Field07)
   burs10      (Field12)   --(cc01)
   SKUDesc1    (Field08)
   SKUDesc2    (Field09)
   Option      (Field10, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cMasterLOT = @cLottable07 + @cLottable08

      EXEC rdt.rdt_CPVMultiSKUExtLOT @nMobile, @nFunc, @cLangCode,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,
         'CHECK',
         @cMasterLOT,
         @cStorerKey OUTPUT,
         @cSKU       OUTPUT,
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
      END



      ---- Check SKU in order
      IF NOT EXISTS( SELECT TOP 1 1
         FROM OrderDetail WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU)
      BEGIN
         SET @nErrNo = 125027
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotInOrder
         GOTO Quit
      END

      -- Get master LOT info
      SELECT TOP 1
         @cExternLotStatus = ExternLotStatus,
         @dExternLottable04 = ExternLottable04
      FROM ExternLotAttribute WITH (NOLOCK)
      WHERE ExternLOT = @cMasterLOT
         AND StorerKey = @cStorerKey
         AND @cSKU = SKU

      -- Check master LOT status
      IF @cExternLotStatus <> 'ACTIVE'
      BEGIN
         SET @nErrNo = 125014
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inactive LOT
         --SET @cOutField06 = ''
         GOTO Quit
      END

      -- Get SKU info
      SELECT
         @cDesc = SKU.Descr,
         @nShelfLife = SKU.ShelfLife,
         @nInnerPack = Pack.InnerPack
      FROM SKU WITH (NOLOCK)
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

      -- Calc expiry date
      SET @dToday = CONVERT( DATE, GETDATE())
      SET @dExpiryDate = @dExternLottable04
      IF @nShelfLife > 0
         SET @dExpiryDate = DATEADD( dd, -@nShelfLife, @dExternLottable04)


      -- Check expired stock
      IF @dExpiryDate < @dToday
      BEGIN
         SET @nErrNo = 125015
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Stock expired
         --SET @cOutField06 = ''
         GOTO Quit
      END

      -- Confirm
      EXEC rdt.rdt_CPVOrder_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
         @cOrderKey,
         @cSKU,
         @nInnerPack,
         @cBarcode    = @cBarcode,
         @cLottable07 = @cLottable07,
         @cLottable08 = @cLottable08,
         @cScan       = @cScan   OUTPUT,
         @cTotal      = @cTotal  OUTPUT,
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
   END

   -- Init next screen var
   SET @cOutField01 = @cOrderKey
   SET @cOutField02 = '' -- LOT
   SET @cOutField03 = @cSKU
   SET @cOutField04 = SUBSTRING( @cDesc,  1, 20) -- SKUDesc1
   SET @cOutField05 = SUBSTRING( @cDesc, 21, 20) -- SKUDesc2
   SET @cOutField06 = SUBSTRING( @cDesc, 41, 20)
   SET @cOutField07 = @cScan + '/' + @cTotal
   SET @cOutField08  = @cBusr10  --(cc01)

   -- Go to LOT screen
   SET @nScn = @nScn - 3
   SET @nStep = @nStep - 3
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

      StorerKey = @cStorerKey,
      Facility  = @cFacility,

      V_OrderKey   = @cOrderKey,
      V_SKU        = @cSKU,
      V_SKUDescr   = @cDesc,
      V_Lottable04 = @dExternLottable04,
      V_Lottable07 = @cLottable07,
      V_Lottable08 = @cLottable08,

      V_String1 = @cScan,
      V_String2 = @cTotal,


      V_String41 = @cBarcode,

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