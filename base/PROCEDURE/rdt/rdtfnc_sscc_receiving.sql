SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_SSCC_Receiving                               */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: SSCC Receiving (SSCC = ReceiptDetail.UserDefine01)          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2021-12-09 1.0  James    WMS-18515. Created                          */
/* 17-03-2022 1.1  Leong    JSM-57674 - Add RDTGetConfig                */
/* 2022-04-05 1.2  YeeKung  WMS-19352 Add ExtendedInfo (yeekung01)      */
/* 2022-08-11 1.3  Ung      WMS-20503 Add SM carton                     */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdtfnc_SSCC_Receiving] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @b_success           INT

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),

   @cStorerkey          NVARCHAR(15),
   @cUserName           NVARCHAR(18),
   @cFacility           NVARCHAR(5),
   @cPrinter            NVARCHAR(10),

   @cReceiptKey         NVARCHAR(10),
   @cLOC                NVARCHAR(10),
   @cID                 NVARCHAR(18),
   @cSKU                NVARCHAR(20),
   @cSKUDesc            NVARCHAR(60),
   @cUOM                NVARCHAR(10),
   @cQty                NVARCHAR(5),
   @cOption             NVARCHAR(1),

   @cLottableLabel      NVARCHAR(20),
   @cLottable01         NVARCHAR(18),
   @cLottable02         NVARCHAR(18),
   @cLottable03         NVARCHAR(18),
   @dLottable04         DATETIME,
   @dLottable05         DATETIME,

   @cLottable06         NVARCHAR(30),      --(CS01)
   @cLottable07         NVARCHAR(30),      --(CS01)
   @cLottable08         NVARCHAR(30),      --(CS01)
   @cLottable09         NVARCHAR(30),      --(CS01)
   @cLottable10         NVARCHAR(30),      --(CS01)
   @cLottable11         NVARCHAR(30),      --(CS01)
   @cLottable12         NVARCHAR(30),      --(CS01)
   @dLottable13         DATETIME,          --(CS01)
   @dLottable14         DATETIME,          --(CS01)
   @dLottable15         DATETIME,          --(CS01)

   @cTempLotLabel       NVARCHAR(20),
   @cTempLottable01     NVARCHAR(18), --input field lottable01 from lottable screen
   @cTempLottable02     NVARCHAR(18), --input field lottable02 from lottable screen
   @cTempLottable03     NVARCHAR(18), --input field lottable03 from lottable screen
   @cTempLottable04     NVARCHAR(16), --input field lottable04 from lottable screen
   @cTempLottable05     NVARCHAR(16), --input field lottable05 from lottable screen

   @cLottable01Label    NVARCHAR(20),
   @cLottable02Label    NVARCHAR(20),
   @cLottable03Label    NVARCHAR(20),
   @cLottable04Label    NVARCHAR(20),
   @cLottable05Label    NVARCHAR(20),

   @cLottable06Label    NVARCHAR(20),          --(CS01)
   @cLottable07Label    NVARCHAR(20),          --(CS01)
   @cLottable08Label    NVARCHAR(20),          --(CS01)
   @cLottable09Label    NVARCHAR(20),          --(CS01)
   @cLottable10Label    NVARCHAR(20),          --(CS01)
   @cLottable11Label    NVARCHAR(20),          --(CS01)
   @cLottable12Label    NVARCHAR(20),          --(CS01)
   @cLottable13Label    NVARCHAR(20),           --(CS01)
   @cLottable14Label    NVARCHAR(20),           --(CS01)
   @cLottable15Label    NVARCHAR(20),           --(CS01)

   @cTempLotLabel01     NVARCHAR(20),
   @cTempLotLabel02     NVARCHAR(20),
   @cTempLotLabel03     NVARCHAR(20),
   @cTempLotLabel04     NVARCHAR(20),
   @cTempLotLabel05     NVARCHAR(20),

   @dTempLottable04     DATETIME,
   @dTempLottable05     DATETIME,

   @dTempLottable13     DATETIME,            --(CS01)
   @dTempLottable14     DATETIME,            --(CS01)
   @dTempLottable15     DATETIME,            --(CS01)

   @cExtendedInfoSP     NVARCHAR(20),
   @cExtendedInfo       NVARCHAR(20),
   @cExtendedValidateSP NVARCHAR(20),
   @cExtendedUpdateSP   NVARCHAR(20),
   @cSQL                NVARCHAR(MAX),
   @cSQLParam           NVARCHAR(MAX),
   @cSSCC               NVARCHAR(30),
   @cChk_Facility       NVARCHAR(5),
   @cChk_StorerKey      NVARCHAR(15),
   @cChk_Status         NVARCHAR(10),
   @cChk_ASNStatus      NVARCHAR(10),
   @cChk_FinalizeFlag   NVARCHAR(10),
   @cConditionCode      NVARCHAR(10),
   @cSubreasonCode      NVARCHAR(10),
   @cReceiptLineNumber  NVARCHAR(5),
   @nChk_RCVQty         INT,
   @nTTL_SSCC           INT,
   @nTTL_SCANNED        INT,
   @nTtl_RCVQty         INT,
   @nQTY                INT,
   @nTranCount          INT,
   @dArriveDate         DATETIME,

   @tExtValidVar        VARIABLETABLE,
   @tExtUpdateVar       VARIABLETABLE,
   @tConfirmVar         VARIABLETABLE,

   @cInField01 NVARCHAR(60),   @cOutField01 NVARCHAR(60),
   @cInField02 NVARCHAR(60),   @cOutField02 NVARCHAR(60),
   @cInField03 NVARCHAR(60),   @cOutField03 NVARCHAR(60),
   @cInField04 NVARCHAR(60),   @cOutField04 NVARCHAR(60),
   @cInField05 NVARCHAR(60),   @cOutField05 NVARCHAR(60),
   @cInField06 NVARCHAR(60),   @cOutField06 NVARCHAR(60),
   @cInField07 NVARCHAR(60),   @cOutField07 NVARCHAR(60),
   @cInField08 NVARCHAR(60),   @cOutField08 NVARCHAR(60),
   @cInField09 NVARCHAR(60),   @cOutField09 NVARCHAR(60),
   @cInField10 NVARCHAR(60),   @cOutField10 NVARCHAR(60),
   @cInField11 NVARCHAR(60),   @cOutField11 NVARCHAR(60),
   @cInField12 NVARCHAR(60),   @cOutField12 NVARCHAR(60),
   @cInField13 NVARCHAR(60),   @cOutField13 NVARCHAR(60),
   @cInField14 NVARCHAR(60),   @cOutField14 NVARCHAR(60),
   @cInField15 NVARCHAR(60),   @cOutField15 NVARCHAR(60),

   @cFieldAttr01 NVARCHAR(1), @cFieldAttr02 NVARCHAR(1),
   @cFieldAttr03 NVARCHAR(1), @cFieldAttr04 NVARCHAR(1),
   @cFieldAttr05 NVARCHAR(1), @cFieldAttr06 NVARCHAR(1),
   @cFieldAttr07 NVARCHAR(1), @cFieldAttr08 NVARCHAR(1),
   @cFieldAttr09 NVARCHAR(1), @cFieldAttr10 NVARCHAR(1),
   @cFieldAttr11 NVARCHAR(1), @cFieldAttr12 NVARCHAR(1),
   @cFieldAttr13 NVARCHAR(1), @cFieldAttr14 NVARCHAR(1),
   @cFieldAttr15 NVARCHAR(1),

   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)

-- Getting Mobile information
SELECT
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @cLangCode   = Lang_code,
   @nMenu       = Menu,

   @cStorerKey  = StorerKey,
   @cFacility   = Facility,
   @cUserName   = UserName,
   @cPrinter    = Printer,

   @cReceiptKey   = V_ReceiptKey,
   @cLOC          = V_LOC,
   @cID           = V_ID,
   @cSKU          = V_SKU,
   @cUOM          = V_UOM,
   @nQTY          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY,  5), 0) = 1 THEN LEFT( V_QTY,  5) ELSE 0 END,

   @cOption                = V_String1,
   @cExtendedInfoSP        = V_String2,
   @cExtendedInfo          = V_String3,
   @cExtendedValidateSP    = V_String4,
   @cExtendedUpdateSP      = V_String5,

   @cSSCC                  = V_String41,

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

FROM   RDT.RDTMOBREC WITH (NOLOCK)
WHERE  Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_Scan          INT,  @nScn_Scan           INT,
   @nStep_Finalize      INT,  @nScn_Finalize       INT

SELECT
   @nStep_Scan          = 1,  @nScn_Scan           = 5990,
   @nStep_Finalize      = 2,  @nScn_Finalize       = 5991

-- Redirect to respective screen
IF @nFunc = 1583
BEGIN
   IF @nStep = 0 GOTO Step_Start    -- Menu
   IF @nStep = 1 GOTO Step_Scan     -- Scn = 5990. SSCC, ASN, SKU, TTL, SCAN
   IF @nStep = 2 GOTO Step_Finalize -- Scn = 5991. FINALIZE
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step_Start. Func = 1583
********************************************************************************/
Step_Start:
BEGIN
   -- Set the entry point
   SET @nScn  = @nScn_Scan
   SET @nStep = @nStep_Scan

   -- initialise all variable
   SET @cSSCC = ''
   SET @cReceiptKey = ''
   SET @cSKU = ''
   SET @cSKUDesc = ''
   SET @nTTL_SCANNED = ''
   SET @nTTL_SSCC = ''

   -- JSM-57674
   SET @cExtendedValidateSP = rdt.RDTGetConfig(@nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''

   SET @cExtendedUpdateSP = rdt.RDTGetConfig(@nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''

   SET @cExtendedInfoSP = rdt.RDTGetConfig(@nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   -- Prep next screen var
   SET @cOutField01 = '' -- SSCC
   SET @cOutField02 = '' -- ReceiptKey
   SET @cOutField03 = '' -- SKU
   SET @cOutField04 = '' -- Descr1
   SET @cOutField05 = '' -- Descr2
   SET @cOutField06 = '' -- Ttl/Scan
   SET @cOutField07 = '' -- SSCC (input)

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

/********************************************************************************
Step 1. Scn = 5990. SSCC, ASN, SKU, SCAN SSCC screen
   SSCC # (field01)
   ASN    (field02)
   SKU    (field03)
   DESCR1 (field04)
   DESCR2 (field05)
   TTL/SCAN (field06)
   SSCC # (field07, input)
********************************************************************************/
Step_Scan:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      --screen mapping
      SET @cSSCC = @cInField07

      --validate blank LOC
      IF ISNULL(@cSSCC, '') = ''
      BEGIN
         SET @nErrNo = 179801
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --SSCC req
         GOTO Step_Scan_Fail
      END

      SELECT
         @cReceiptKey = R.ReceiptKey,
         @cChk_Facility = R.Facility,
         @cChk_StorerKey = R.StorerKey,
         @cChk_Status = R.[Status],
         @cChk_ASNStatus = R.ASNStatus
      FROM dbo.RECEIPT R WITH (NOLOCK)
      JOIN dbo.RECEIPTDETAIL RD WITH (NOLOCK) ON ( R.ReceiptKey = RD.ReceiptKey)
      WHERE R.StorerKey = @cStorerkey
      AND   R.Notes IN ('S', 'SM')
      AND   RD.UserDefine01 = @cSSCC

      --check if receiptkey exists
      IF ISNULL(@cReceiptKey, '') = ''
      BEGIN
         SET @nErrNo = 179802
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN not exists
         GOTO Step_Scan_Fail
      END

      --check diff facility
      IF @cFacility <> @cChk_Facility
      BEGIN
         SET @nErrNo = 179803
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         GOTO Step_Scan_Fail
      END

      --check diff storer
      IF @cChk_StorerKey <> @cStorerkey
      BEGIN
         SET @nErrNo = 179804
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
         GOTO Step_Scan_Fail
      END

      --check for ASN closed by receipt.status
      IF @cChk_Status = '9'
      BEGIN
         SET @nErrNo = 179805
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN closed
         GOTO Step_Scan_Fail
      END

      --check for ASN closed by receipt.ASNStatus
      IF @cChk_ASNStatus = '9'
      BEGIN
         SET @nErrNo = 179806
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN closed
         GOTO Step_Scan_Fail
      END

      --check for ASN cancelled
      IF @cChk_ASNStatus = 'CANC'
      BEGIN
         SET @nErrNo = 179807
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN cancelled
         GOTO Step_Scan_Fail
      END

      SELECT TOP 1
         @cSKU = SKU,
         @cChk_FinalizeFlag = FinalizeFlag,
         @nChk_RCVQty = SUM( QtyExpected - BeforeReceivedQty)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   UserDefine01 = @cSSCC
      GROUP BY Sku, FinalizeFlag
      ORDER BY 2 DESC

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 179808
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SSCC
         GOTO Step_Scan_Fail
      END

      IF @cChk_FinalizeFlag = 'Y'
      BEGIN
         SET @nErrNo = 179809
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SSCC Received
         GOTO Step_Scan_Fail
      END

      IF NOT @nChk_RCVQty > 0
      BEGIN
         SET @nErrNo = 179810
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SSCC Received
         GOTO Step_Scan_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cSSCC, @cLOC, @cID, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cOption, @dArriveDate, @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cSSCC         NVARCHAR( 20), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
               '@cLottable01   NVARCHAR( 18), ' +
               '@cLottable02   NVARCHAR( 18), ' +
               '@cLottable03   NVARCHAR( 18), ' +
               '@dLottable04   DATETIME,      ' +
               '@dLottable05   DATETIME,      ' +
               '@cLottable06   NVARCHAR( 30), ' +
               '@cLottable07   NVARCHAR( 30), ' +
               '@cLottable08   NVARCHAR( 30), ' +
               '@cLottable09   NVARCHAR( 30), ' +
               '@cLottable10   NVARCHAR( 30), ' +
               '@cLottable11   NVARCHAR( 30), ' +
               '@cLottable12   NVARCHAR( 30), ' +
               '@dLottable13   DATETIME,      ' +
               '@dLottable14   DATETIME,      ' +
               '@dLottable15   DATETIME,      ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtValidVar  VariableTable READONLY, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cSSCC, @cLOC, @cID, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cOption, @dArriveDate, @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_Scan_Fail
         END
      END

      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN Step_SSCC -- For rollback or commit only our own transaction

      -- Receive
      EXEC rdt.rdt_SSCC_Receiving_Confirm
         @nFunc               = @nFunc,
         @nMobile             = @nMobile,
         @cLangCode           = @cLangCode,
         @cStorerKey          = @cStorerKey,
         @cFacility           = @cFacility,
         @dArriveDate         = @dArriveDate,
         @cReceiptKey         = @cReceiptKey,
         @cToLoc              = @cLOC,
         @cToID               = @cID,
         @cSKUCode            = @cSKU,
         @cSKUUOM             = @cUOM,
         @nSKUQTY             = @nQTY,
         @cLottable01         = @cLottable01,
         @cLottable02         = @cLottable02,
         @cLottable03         = @cLottable03,
         @dLottable04         = @dLottable04,
         @dLottable05         = @dLottable05,
         @cLottable06         = @cLottable06,
         @cLottable07         = @cLottable07,
         @cLottable08         = @cLottable08,
         @cLottable09         = @cLottable09,
         @cLottable10         = @cLottable10,
         @cLottable11         = @cLottable11,
         @cLottable12         = @cLottable12,
         @dLottable13         = @dLottable13,
         @dLottable14         = @dLottable14,
         @dLottable15         = @dLottable15,
         @cSSCC               = @cSSCC,
         @cConditionCode      = @cConditionCode,
         @cSubreasonCode      = @cSubreasonCode,
         @tConfirmVar         = @tConfirmVar,
         @cReceiptLineNumber  = @cReceiptLineNumber OUTPUT,
         @nErrNo              = @nErrNo    OUTPUT,
         @cErrMsg             = @cErrMsg   OUTPUT

      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN Step_SSCC
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Step_Scan_Fail
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cSSCC, @cLOC, @cID, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cOption, @dArriveDate, @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cSSCC         NVARCHAR( 20), ' +
               '@cLOC          NVARCHAR( 20), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
               '@cLottable01   NVARCHAR( 18), ' +
               '@cLottable02   NVARCHAR( 18), ' +
               '@cLottable03   NVARCHAR( 18), ' +
               '@dLottable04   DATETIME,      ' +
               '@dLottable05   DATETIME,      ' +
               '@cLottable06   NVARCHAR( 30), ' +
               '@cLottable07   NVARCHAR( 30), ' +
               '@cLottable08   NVARCHAR( 30), ' +
               '@cLottable09   NVARCHAR( 30), ' +
               '@cLottable10   NVARCHAR( 30), ' +
               '@cLottable11   NVARCHAR( 30), ' +
               '@cLottable12   NVARCHAR( 30), ' +
               '@dLottable13   DATETIME,      ' +
               '@dLottable14   DATETIME,      ' +
               '@dLottable15   DATETIME,      ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtUpdateVar VariableTable READONLY, ' +
               '@nErrNo        INT           OUTPUT,   ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cSSCC, @cLOC, @cID, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cOption, @dArriveDate, @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN Step_SSCC
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Quit
            END
         END
      END

      COMMIT TRAN Step_SSCC
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo =''

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cSSCC, @cLOC, @cID, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cOption, @dArriveDate, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cSSCC         NVARCHAR( 20), ' +
               '@cLOC          NVARCHAR( 20), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
               '@cLottable01   NVARCHAR( 18), ' +
               '@cLottable02   NVARCHAR( 18), ' +
               '@cLottable03   NVARCHAR( 18), ' +
               '@dLottable04   DATETIME,      ' +
               '@dLottable05   DATETIME,      ' +
               '@cLottable06   NVARCHAR( 30), ' +
               '@cLottable07   NVARCHAR( 30), ' +
               '@cLottable08   NVARCHAR( 30), ' +
               '@cLottable09   NVARCHAR( 30), ' +
               '@cLottable10   NVARCHAR( 30), ' +
               '@cLottable11   NVARCHAR( 30), ' +
               '@cLottable12   NVARCHAR( 30), ' +
               '@dLottable13   DATETIME,      ' +
               '@dLottable14   DATETIME,      ' +
               '@dLottable15   DATETIME,      ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +
               '@nErrNo        INT           OUTPUT,   ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cSSCC, @cLOC, @cID, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cOption, @dArriveDate, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               GOTO Quit
            END
         END
      END


      SELECT @nTtl_RCVQty = SUM( QtyExpected - BeforeReceivedQty)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      IF @nTtl_RCVQty = 0
      BEGIN
         SET @cOption = ''

         --prepare next screen variable
         SET @cOutField01 = @cReceiptkey
         SET @cOutField02 = ''
         SET @cOutField03 =@cExtendedInfo

         -- Go to next screen
         SET @nScn = @nScn_Finalize
         SET @nStep = @nStep_Finalize
      END
      ELSE
      BEGIN
         SELECT TOP 1 @cSKU = SKU
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   UserDefine01 = @cSSCC
         ORDER BY 1

         SELECT @cSKUDesc = DESCR
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerkey
         AND   Sku = @cSKU

         SELECT @nTTL_SSCC = COUNT( DISTINCT UserDefine01)
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey

         SELECT @nTTL_SCANNED = COUNT( DISTINCT UserDefine01)
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND ( BeforeReceivedQty = QtyExpected)

         --prepare next screen variable
         SET @cOutField01 = @cSSCC
         SET @cOutField02 = @cReceiptkey
         SET @cOutField03 = @cSKU
         SET @cOutField04 = SUBSTRING( @cSKUDesc, 1, 20)
         SET @cOutField05 = SUBSTRING( @cSKUDesc, 21, 20)
         SET @cOutField06 = CAST( @nTTL_SCANNED AS NVARCHAR( 3)) + '/' + CAST( @nTTL_SSCC AS NVARCHAR( 3))
         SET @cOutField07 = ''
         SET @cOutField08=@cExtendedInfo

         SET @cSSCC = ''
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-Out
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_Scan_Fail:
   BEGIN
      SET @cSSCC = ''
      SET @cOutField07 = '' -- SSCC
   END
END
GOTO Quit

/********************************************************************************
Step 2. Scn = 5991. Finalize screen
   ASN      (field01)
   Option   (field02, input)
********************************************************************************/
Step_Finalize:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      --screen mapping
      SET @cOption = @cInField02

      -- Check blank
      IF ISNULL( @cOption, '') = ''
      BEGIN
         SET @nErrNo = 179811
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option needed
         GOTO Step_Finalize_Fail
      END

      -- Check option valid
      IF @cOption NOT IN ( '1', '9')
      BEGIN
         SET @nErrNo = 179812
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_Finalize_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cSSCC, @cLOC, @cID, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cOption, @dArriveDate, @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cSSCC         NVARCHAR( 20), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
               '@cLottable01   NVARCHAR( 18), ' +
               '@cLottable02   NVARCHAR( 18), ' +
               '@cLottable03   NVARCHAR( 18), ' +
               '@dLottable04   DATETIME,      ' +
               '@dLottable05   DATETIME,      ' +
               '@cLottable06   NVARCHAR( 30), ' +
               '@cLottable07   NVARCHAR( 30), ' +
               '@cLottable08   NVARCHAR( 30), ' +
               '@cLottable09   NVARCHAR( 30), ' +
               '@cLottable10   NVARCHAR( 30), ' +
               '@cLottable11   NVARCHAR( 30), ' +
               '@cLottable12   NVARCHAR( 30), ' +
               '@dLottable13   DATETIME,      ' +
               '@dLottable14   DATETIME,      ' +
               '@dLottable15   DATETIME,      ' +
               '@cOption       NVARCHAR( 1),  ' +
               '@dArriveDate   DATETIME,      ' +
               '@tExtValidVar  VariableTable READONLY, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cSSCC, @cLOC, @cID, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cOption, @dArriveDate, @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_Finalize_Fail
         END
      END

      IF @cOption = '1' -- Yes
      BEGIN
         -- Handling transaction
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         -- Cross DB trans will hit "Cannot promote the transaction to a distributed transaction because there is an active save point in this transaction."
         -- SAVE TRAN Step_FinalizeASN -- For rollback or commit only our own transaction

         -- Finalize ASN
         EXEC rdt.rdt_SSCC_Receiving_Finalize
            @nFunc         = @nFunc,
            @nMobile       = @nMobile,
            @cLangCode     = @cLangCode,
            @nStep         = @nStep,
            @nInputKey     = @nInputKey,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerKey,
            @cReceiptKey   = @cReceiptKey,
            @nErrNo        = @nErrNo  OUTPUT,
            @cErrMsg       = @cErrMsg OUTPUT
         
         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN -- Step_FinalizeASN
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN

            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Quit
         END

         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
                  ' @cReceiptKey, @cSSCC, @cLOC, @cID, @cSKU, @nQTY, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @cOption, @dArriveDate, @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile       INT,           ' +
                  '@nFunc         INT,           ' +
                  '@cLangCode     NVARCHAR( 3),  ' +
                  '@nStep         INT,           ' +
                  '@nInputKey     INT,           ' +
                  '@cFacility     NVARCHAR( 5),  ' +
                  '@cStorerKey    NVARCHAR( 15), ' +
                  '@cReceiptKey   NVARCHAR( 10), ' +
                  '@cSSCC         NVARCHAR( 20), ' +
                  '@cLOC          NVARCHAR( 10), ' +
                  '@cID           NVARCHAR( 18), ' +
                  '@cSKU          NVARCHAR( 20), ' +
                  '@nQTY          INT,           ' +
                  '@cLottable01   NVARCHAR( 18), ' +
                  '@cLottable02   NVARCHAR( 18), ' +
                  '@cLottable03   NVARCHAR( 18), ' +
                  '@dLottable04   DATETIME,      ' +
                  '@dLottable05   DATETIME,      ' +
                  '@cLottable06   NVARCHAR( 30), ' +
                  '@cLottable07   NVARCHAR( 30), ' +
                  '@cLottable08   NVARCHAR( 30), ' +
                  '@cLottable09   NVARCHAR( 30), ' +
                  '@cLottable10   NVARCHAR( 30), ' +
                  '@cLottable11   NVARCHAR( 30), ' +
                  '@cLottable12   NVARCHAR( 30), ' +
                  '@dLottable13   DATETIME,      ' +
                  '@dLottable14   DATETIME,      ' +
                  '@dLottable15   DATETIME,      ' +
                  '@cOption       NVARCHAR( 1),  ' +
                  '@dArriveDate   DATETIME,      ' +
                  '@tExtUpdateVar VariableTable READONLY, ' +
                  '@nErrNo        INT           OUTPUT,   ' +
                  '@cErrMsg       NVARCHAR( 20) OUTPUT    '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                  @cReceiptKey, @cSSCC, @cLOC, @cID, @cSKU, @nQTY,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @cOption, @dArriveDate, @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  ROLLBACK TRAN -- Step_FinalizeASN
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
                  GOTO Quit
               END
            END
         END

         COMMIT TRAN -- Step_FinalizeASN
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
      END

      -- Set the entry point
      SET @nScn  = @nScn_Scan
      SET @nStep = @nStep_Scan

      -- initialise all variable
      SET @cSSCC = ''
      SET @cReceiptKey = ''
      SET @cSKU = ''
      SET @cSKUDesc = ''
      SET @nTTL_SCANNED = ''
      SET @nTTL_SSCC = ''

      -- Prep next screen var
      SET @cOutField01 = '' -- SSCC
      SET @cOutField02 = '' -- ReceiptKey
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- Descr1
      SET @cOutField05 = '' -- Descr2
      SET @cOutField06 = '' -- Ttl/Scan
      SET @cOutField07 = '' -- SSCC (input)

      GOTO Quit
   END

   IF @nInputKey = 0 -- Esc
   BEGIN
      -- Set the entry point
      SET @nScn  = @nScn_Scan
      SET @nStep = @nStep_Scan

      -- initialise all variable
      SET @cSSCC = ''

      -- Prep next screen var
      SET @cOutField01 = '' -- SSCC

      GOTO Quit
   END
   GOTO Quit

   Step_Finalize_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField02 = '' -- Option
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

       StorerKey    = @cStorerKey,
       Facility     = @cFacility,
       -- UserName     = @cUserName,
       Printer      = @cPrinter,

       V_Receiptkey = @cReceiptkey,
       V_LOC = @cLOC,
       V_ID  = @cID,
       V_SKU = @cSKU,
       V_UOM = @cUOM,
       V_QTY = @nQTY,

       V_String1  = @cOption,
       V_String2  = @cExtendedInfoSP,
       V_String3  = @cExtendedInfo,
       V_String4  = @cExtendedValidateSP,
       V_String5  = @cExtendedUpdateSP,

       V_String41 = @cSSCC,

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