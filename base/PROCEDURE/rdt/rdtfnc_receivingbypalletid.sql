SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_ReceivingByPalletID                                */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Receive by pallet (assume all the pallets are with same SKU,      */
/*          lottables, QTY. Iterate scanning different TO ID to receive.      */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Rev  Author      Purposes                                     */
/* 2021-04-02   1.0  James       WMS-16636. Created                           */
/******************************************************************************/
CREATE PROC [RDT].[rdtfnc_ReceivingByPalletID](
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
   @b_success           INT,
   @n_err               INT,
   @c_errmsg            NVARCHAR( 250),
   @cChkFacility        NVARCHAR( 5),
   @cChkLOC             NVARCHAR( 10),
   @nVariance           INT, 
   @nMorePage           INT,
   @nTranCount          INT,
   @cBarcode            NVARCHAR( 60),
   @cAuthority          NVARCHAR( 1), 
   @cSQL                NVARCHAR( MAX),
   @cSQLParam           NVARCHAR( MAX),
   @cSerialNo           NVARCHAR( 30),
   @nSerialQTY          INT,
   @nBulkSNO            INT,
   @nBulkSNOQTY         INT,
   @nMoreSNO            INT,
   @tCaptureVar         VARIABLETABLE,
   @tExtValidVar        VARIABLETABLE,
   @tExtUpdateVar       VARIABLETABLE,
   @tConfirmVar         VARIABLETABLE, 
   @tSKULabel           VARIABLETABLE
   
-- RDT.RDTMobRec variables
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,

   @cFacility           NVARCHAR( 5),
   @cPaperPrinter       NVARCHAR( 10), 
   @cLabelPrinter       NVARCHAR( 10), 
   @cStorerGroup        NVARCHAR( 20),
   
   @cStorerKey          NVARCHAR( 15),
   @cUOM                NVARCHAR( 10),
   @cReceiptKey         NVARCHAR( 10),
   @cLOC                NVARCHAR( 10),
   @cID                 NVARCHAR( 18),
   @cSKU                NVARCHAR( 60),
   @cSKUDesc            NVARCHAR( 60),
   @nQTY                INT,
   @cLottable01         NVARCHAR( 18),
   @cLottable02         NVARCHAR( 18),
   @cLottable03         NVARCHAR( 18),
   @dLottable04         DATETIME,
   @dLottable05         DATETIME,
   @cLottable06         NVARCHAR( 30),
   @cLottable07         NVARCHAR( 30),
   @cLottable08         NVARCHAR( 30),
   @cLottable09         NVARCHAR( 30),
   @cLottable10         NVARCHAR( 30),
   @cLottable11         NVARCHAR( 30),
   @cLottable12         NVARCHAR( 30),
   @dLottable13         DATETIME,
   @dLottable14         DATETIME,
   @dLottable15         DATETIME,

   @nTotalQTYExp        INT,
   @nTotalQTYRcv        INT,
   @nBalQTY             INT, 
   @nFromScn            INT,

   @dArriveDate         DATETIME,

   @cRefNo              NVARCHAR( 20),
   @cLottableCode       NVARCHAR( 30),
   @cSuggID             NVARCHAR( 18),
   @cSuggLOC            NVARCHAR( 10),
   @cReceiptLineNumber  NVARCHAR( 5),
   @cOption             NVARCHAR( 1),

   @cDispStyleColorSize    NVARCHAR( 1),
   @cSerialNoCapture       NVARCHAR( 1),
   @cDisableToIDField      NVARCHAR( 1),
   @cDefaultToLOC          NVARCHAR( 20),
   @cDecodeSKUSP           NVARCHAR( 20),
   @cVerifySKU             NVARCHAR( 1),
   @cExtendedPutawaySP     NVARCHAR( 20),
   @cOverrideSuggestID     NVARCHAR( 1),
   @cOverrideSuggestLOC    NVARCHAR( 1),
   @cDefaultIDAsSuggID     NVARCHAR( 1),
   @cDefaultLOCAsSuggLOC   NVARCHAR( 1),
   @cExtendedInfoSP        NVARCHAR( 20),
   @cExtendedInfo          NVARCHAR( 20),
   @cExtendedValidateSP    NVARCHAR( 20),
   @cExtendedUpdateSP      NVARCHAR( 20),
   @cMultiSKUBarcode       NVARCHAR( 1),
   @cCheckSKUInASN         NVARCHAR( 1),
   @cCaptureReceiptInfoSP  NVARCHAR( 20),
   @cRefNoSKULookup        NVARCHAR( 1), 
   @cFinalizeASN           NVARCHAR( 1),
   @cPreToIDLOC            NVARCHAR( 1),
   @cAllowOverReceive      NVARCHAR( 1),
   @cAutoReceiveNext       NVARCHAR( 1),
   @cSKULabel              NVARCHAR( 10),

   @cData1                 NVARCHAR( 60),
   @cData2                 NVARCHAR( 60),
   @cData3                 NVARCHAR( 60),
   @cData4                 NVARCHAR( 60),
   @cData5                 NVARCHAR( 60),
   @cASNStatus             NVARCHAR( 10),
   @cPOKey                 NVARCHAR( 10),
   @cDisableQTYField       NVARCHAR( 1),
   @cDefaultQTY            NVARCHAR( 1),
   @cCheckIDInUse          NVARCHAR( 20),
   @cSuggestLocSP          NVARCHAR( 20),
   @cUCCUOM                NVARCHAR( 6),  
   @nBeforeReceivedQTY     INT,
   @nASNQTY                INT,
   @nIDQTY                 INT,
   @nQTYExpected           INT,

   
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
   @nFunc         = Func,
   @nScn          = Scn,
   @nStep         = Step,
   @nInputKey     = InputKey,
   @nMenu         = Menu,
   @cLangCode     = Lang_code,

   @cFacility     = Facility,
   @cPaperPrinter = Printer_Paper, 
   @cLabelPrinter = Printer, 
   
   @cStorerGroup  = StorerGroup,
   @cStorerKey    = V_StorerKey,
   @cUOM          = V_UOM,
   @cReceiptKey   = V_ReceiptKey,
   @cPOKey        = V_POKey,
   @cLOC          = V_LOC,
   @cID           = V_ID,
   @cSKU          = V_SKU,
   @cSKUDesc      = V_SKUDescr,
   @nQTY          = V_QTY,
   @cLottable01   = V_Lottable01,
   @cLottable02   = V_Lottable02,
   @cLottable03   = V_Lottable03,
   @dLottable04   = V_Lottable04,
   @dLottable05   = V_Lottable05,
   @cLottable06   = V_Lottable06,
   @cLottable07   = V_Lottable07,
   @cLottable08   = V_Lottable08,
   @cLottable09   = V_Lottable09,
   @cLottable10   = V_Lottable10,
   @cLottable11   = V_Lottable11,
   @cLottable12   = V_Lottable12,
   @dLottable13   = V_Lottable13,
   @dLottable14   = V_Lottable14,
   @dLottable15   = V_Lottable15,

   @nTotalQTYExp  = V_Integer1,
   @nTotalQTYRcv  = V_Integer2,
   @nBalQTY       = V_Integer3,
   @nFromScn      = V_Integer4,
   @nIDQTY              = V_Integer5,      
   @nBeforeReceivedQTY  = V_Integer6,      
   @nQTYExpected        = V_Integer7,      

   @dArriveDate   = V_DateTime1,

   @cRefNo                 = V_String1,
   @cLottableCode          = V_String2,
   @cSuggID                = V_String3,
   @cSuggLOC               = V_String4,
   @cReceiptLineNumber     = V_String5,
   @cOption                = V_String7,
   @cDisableQTYField       = V_String8,
   @cDefaultQTY            = V_String9,
   @cCheckIDInUse          = V_String10,
   @cSuggestLocSP          = V_string11,
   @cUCCUOM                = V_string12,
   
   @cDispStyleColorSize    = V_String17,
   @cSerialNoCapture       = V_String18,
   @cDisableToIDField      = V_String19,
   @cCaptureReceiptInfoSP  = V_String20,
   @cDefaultToLOC          = V_String21,
   @cDecodeSKUSP           = V_String22,
   @cVerifySKU             = V_String23,
   @cExtendedPutawaySP     = V_String24,
   @cOverrideSuggestID     = V_String25,
   @cOverrideSuggestLOC    = V_String26,
   @cDefaultIDAsSuggID     = V_String27,
   @cDefaultLOCAsSuggLOC   = V_String28,
   @cExtendedInfoSP        = V_String29,
   @cExtendedInfo          = V_String30,
   @cExtendedValidateSP    = V_String31,
   @cExtendedUpdateSP      = V_String32,
   @cMultiSKUBarcode       = V_String33,
   @cCheckSKUInASN         = V_String34,
   @cRefNoSKULookup        = V_String35,
   @cFinalizeASN           = V_String36,
   @cPreToIDLOC            = V_String37,
   @cAllowOverReceive      = V_String38,
   @cAutoReceiveNext       = V_String39,
   @cSKULabel              = V_String40,

   @cData1                 = V_String41,
   @cData2                 = V_String42,
   @cData3                 = V_String43,
   @cData4                 = V_String44,
   @cData5                 = V_String45,

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

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_ASNRefNo      INT,  @nScn_ASNRefNo    INT,
   @nStep_LOC           INT,  @nScn_LOC         INT,
   @nStep_SKUQty        INT,  @nScn_SKUQty      INT,
   @nStep_Lottables     INT,  @nScn_Lottables   INT,
   @nStep_ID            INT,  @nScn_ID          INT,
   @nStep_VerifySKU     INT,  @nScn_VerifySKU   INT,
   @nStep_MultiSKU      INT,  @nScn_MultiSKU    INT
   
SELECT
   @nStep_ASNRefNo      = 1,  @nScn_ASNRefNo    = 5890,
   @nStep_LOC           = 2,  @nScn_LOC         = 5891,
   @nStep_SKUQty        = 3,  @nScn_SKUQty      = 5892,
   @nStep_Lottables     = 4,  @nScn_Lottables   = 3990,
   @nStep_ID            = 5,  @nScn_ID          = 5893,
   @nStep_VerifySKU     = 6,  @nScn_VerifySKU   = 3951,
   @nStep_MultiSKU      = 7,  @nScn_MultiSKU    = 3570

IF @nFunc = 647
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start       -- Menu. 607
   IF @nStep = 1  GOTO Step_ASNRefNo    -- Scn = 5890. ASN, RefNo
   IF @nStep = 2  GOTO Step_LOC         -- Scn = 5891. LOC
   IF @nStep = 3  GOTO Step_SKUQty      -- Scn = 5892. SKU, QTY
   IF @nStep = 4  GOTO Step_Lottables   -- Scn = 3990. Lottable
   IF @nStep = 5  GOTO Step_ID          -- Scn = 5893. ID
   IF @nStep = 6  GOTO Step_VerifySKU   -- Scn = 3951. Verify SKU
   IF @nStep = 7  GOTO Step_MultiSKU    -- Scn = 3570. Multi SKU
END
RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 647
********************************************************************************/
Step_Start:
BEGIN
   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey

   SET @cReceiptKey = ''
   SET @cRefNo = ''
   SET @cOption = ''
   SET @nQTY = 1
   SET @dArriveDate = NULL

   -- Prepare next screen var
   SET @cOutField01 = '' -- ASN
   SET @cOutField02 = '' -- PO
   SET @cOutField03 = '' -- RefNo
   
   EXEC rdt.rdtSetFocusField @nMobile, 1

   -- Set the entry point
   SET @nScn = @nScn_ASNRefNo
   SET @nStep = @nStep_ASNRefNo

END
GOTO Quit

/************************************************************************************
Step 1. Scn = 5640. RefNo, ASN screen
   REF NO   (field01, input)
   ASN      (field02, input)
************************************************************************************/
Step_ASNRefNo:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cChkReceiptKey NVARCHAR( 10)
      DECLARE @cReceiptStatus NVARCHAR( 10)
      DECLARE @cChkStorerKey NVARCHAR( 15)
      DECLARE @nRowCount INT

      -- Screen mapping
      SET @cReceiptKey = @cInField01
      SET @cPOKey = @cInField02
      SET @cRefNo = @cInField03

      -- Check ref no
      IF @cRefNo <> '' AND @cReceiptKey = ''
      BEGIN
         -- Get storer config
         DECLARE @cColumnName NVARCHAR(20)
         SET @cColumnName = rdt.RDTGetConfig( @nFunc, 'RefNoLookupColumn', @cStorerKey)

         -- Get lookup field data type
         DECLARE @cDataType NVARCHAR(128)
         SET @cDataType = ''
         SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Receipt' AND COLUMN_NAME = @cColumnName

         IF @cDataType <> ''
         BEGIN
            IF @cDataType = 'nvarchar' SET @n_Err = 1                                ELSE
            IF @cDataType = 'datetime' SET @n_Err = rdt.rdtIsValidDate( @cRefNo)     ELSE
            IF @cDataType = 'int'      SET @n_Err = rdt.rdtIsInteger(   @cRefNo)     ELSE
            IF @cDataType = 'float'    SET @n_Err = rdt.rdtIsValidQTY(  @cRefNo, 20)

            -- Check data type
            IF @n_Err = 0
            BEGIN
               SET @nErrNo = 165501
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RefNo
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- RefNo
               GOTO Quit
            END

            SET @cSQL =
               ' SELECT @cReceiptKey = ReceiptKey ' +
               ' FROM dbo.Receipt WITH (NOLOCK) ' +
               ' WHERE Facility = @cFacility ' +
                  ' AND Status <> ''9'' ' +
                  CASE WHEN @cDataType IN ('int', 'float')
                       THEN ' AND ISNULL( ' + @cColumnName + ', 0) = @cRefNo '
                       ELSE ' AND ISNULL( ' + @cColumnName + ', '''') = @cRefNo '
                  END +
                  CASE WHEN @cStorerGroup = ''
                       THEN ' AND StorerKey = @cStorerKey '
                       ELSE ' AND EXISTS( SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cStorerKey) '
                  END +
               ' SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT '
            SET @cSQLParam =
               ' @nMobile      INT, ' +
               ' @cFacility    NVARCHAR(5),  ' +
               ' @cStorerGroup NVARCHAR(20), ' +
               ' @cStorerKey   NVARCHAR(15), ' +
               ' @cColumnName  NVARCHAR(20), ' +
               ' @cRefNo       NVARCHAR(30), ' +
               ' @cReceiptKey  NVARCHAR(10) OUTPUT, ' +
               ' @nRowCount    INT          OUTPUT, ' +
               ' @nErrNo       INT          OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile,
               @cFacility,
               @cStorerGroup,
               @cStorerKey,
               @cColumnName,
               @cRefNo,
               @cReceiptKey OUTPUT,
               @nRowCount   OUTPUT,
               @nErrNo      OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            -- Check RefNo in ASN
            IF @nRowCount = 0
            BEGIN
               SET @nErrNo = 165502
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN
               GOTO Quit
            END

            -- Check RefNo in ASN
            IF @nRowCount > 1
            BEGIN
               SET @nErrNo = 165503
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo MultiASN
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- ContainerKey
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            -- Lookup field is SP
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cColumnName AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cColumnName) +
                  ' @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerGroup, @cStorerKey, @cRefNo, @cReceiptKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile       INT,           ' +
                  '@nFunc         INT,           ' +
                  '@cLangCode     NVARCHAR( 3),  ' +
                  '@cFacility     NVARCHAR( 5),  ' +
                  '@cStorerGroup  NVARCHAR( 20), ' +
                  '@cStorerKey    NVARCHAR( 15), ' +
                  '@cRefNo        NVARCHAR( 30), ' +
                  '@cReceiptKey   NVARCHAR(10)  OUTPUT, ' +
                  '@nErrNo        INT           OUTPUT, ' +
                  '@cErrMsg       NVARCHAR( 20) OUTPUT  '
   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerGroup, @cStorerKey, @cRefNo, @cReceiptKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
               IF @nErrNo <> 0
                  GOTO Quit
            END            
         END

         SET @cOutField01 = @cReceiptKey
         SET @cOutField03 = @cRefNo
      END

      -- Validate at least one field must key-in
      IF (@cReceiptKey = '' OR @cReceiptKey IS NULL) AND
         (@cPOKey = '' OR @cPOKey IS NULL OR @cPOKey = 'NOPO') -- SOS76264
      BEGIN
         SET @nErrNo = 165504
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ASN or PO
         GOTO Quit
      END

      -- Both ASN & PO keyed-in
      IF NOT (@cReceiptKey = '' OR @cReceiptKey IS NULL) AND
         NOT (@cPOKey = '' OR @cPOKey IS NULL) AND
         NOT (@cPOKey = 'NOPO')
      BEGIN
         -- Get the ASN
         SELECT
            @cChkFacility = R.Facility,
            @cChkStorerKey = R.StorerKey,
            @cChkReceiptKey = R.ReceiptKey,
            @cReceiptStatus = R.Status
         FROM dbo.Receipt R WITH (NOLOCK)
            INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
         WHERE R.ReceiptKey = @cReceiptKey
            AND RD.POKey = @cPOKey
         SET @nRowCount = @@ROWCOUNT

         -- No row returned, either ASN or PO not exists
         IF @nRowCount = 0
         BEGIN
            DECLARE @nASNExist INT
            DECLARE @nPOExist  INT
            DECLARE @nPOInASN  INT

            SET @nASNExist = 0
            SET @nPOExist = 0
            SET @nPOInASN = 0

            -- Check ASN exists
            IF EXISTS (SELECT 1 FROM dbo.Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey)
               SET @nASNExist = 1

            -- Check PO exists
            IF EXISTS (SELECT 1 FROM dbo.PO WITH (NOLOCK) WHERE POKey = @cPOKey)
               SET @nPOExist = 1

            -- Check PO in ASN
            IF EXISTS( SELECT 1 FROM dbo.ReceiptDetail RD WITH (NOLOCK) WHERE RD.ReceiptKey = @cReceiptKey AND RD.POKey = @cPOKey)
               SET @nPOInASN = 1

            -- Both ASN & PO also not exists
            IF @nASNExist = 0 AND @nPOExist = 0
            BEGIN
               SET @nErrNo = 165505
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN&PONotExist
               SET @cOutField01 = '' -- ReceiptKey
               SET @cOutField02 = '' -- POKey
               SET @cReceiptKey = ''
               SET @cPOKey = ''
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Quit
            END

            -- Only ASN not exists
            ELSE IF @nASNExist = 0
            BEGIN
               SET @nErrNo = 165506
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN Not Exist
               SET @cOutField01 = '' -- ReceiptKey
               SET @cOutField02 = @cPOKey -- POKey
               SET @cReceiptKey = ''
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Quit
            END

            -- Only PO not exists
            ELSE IF @nPOExist = 0
            BEGIN
               SET @nErrNo = 165507
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PO Not Exist
               SET @cOutField01 = @cReceiptKey
               SET @cOutField02 = '' -- POKey
               SET @cPOKey = ''
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Quit
            END

            -- PO not in ASN
            ELSE IF @nPOInASN = 0
            BEGIN
               SET @nErrNo = 165508
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PO Not In ASN
               SET @cOutField01 = @cReceiptKey
               SET @cOutField02 = '' -- POKey
               SET @cPOKey = ''
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Quit
            END
         END
      END
      ELSE
         -- Only ASN key-in (POKey = blank or NOPO)
         IF (@cReceiptKey <> '' AND @cReceiptKey IS NOT NULL)
         BEGIN
            -- Validate whether ASN have multiple PO
            DECLARE @cChkPOKey NVARCHAR( 10)
            SELECT DISTINCT
               @cChkPOKey = RD.POKey,
               @cChkFacility = R.Facility,
               @cChkStorerKey = R.StorerKey,
               @cReceiptStatus = R.Status
            FROM dbo.Receipt R WITH (NOLOCK)
               INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
            WHERE RD.ReceiptKey = @cReceiptKey
            -- If return multiple row, the last row is taken & assign into var.
            -- We want blank POKey to be assigned if multiple row returned, hence using the DESC
            ORDER BY RD.POKey DESC
            SET @nRowCount = @@ROWCOUNT

            -- No row returned, either ASN or ASN detail not exist
            IF @nRowCount = 0
            BEGIN
               SELECT
                   @cChkFacility = R.Facility,
                   @cChkStorerKey = R.StorerKey,
                   @cReceiptStatus = R.Status
               FROM dbo.Receipt R WITH (NOLOCK)
               WHERE R.ReceiptKey = @cReceiptKey
               SET @nRowCount = @@ROWCOUNT

               -- Check ASN exist
               IF @nRowCount = 0
               BEGIN
                  SET @nErrNo = 165509
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN not exist
                  SET @cOutField01 = '' -- ReceiptKey
                  SET @cReceiptKey = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 1
                  GOTO Quit
               END
            END

            -- Auto retrieve PO, if only 1 PO in ASN
            ELSE IF @nRowCount = 1
            BEGIN
               IF @cPOKey <> 'NOPO'
                  SET @cPOKey = @cChkPOKey
            END

            -- Check multi PO in ASN
            ELSE IF @nRowCount > 1
            BEGIN
               IF @cPOKey <> 'NOPO'
               BEGIN
                  SET @cPOKey = ''
                  SET @nErrNo = 165510
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiPO In ASN
                  SET @cOutField01 = @cReceiptKey
                  SET @cOutField02 = ''
                  SET @cPOKey = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 2
                  GOTO Quit
               END
            END
         END
         ELSE
            -- Only PO key-in (POKey not blank or NOPO)
            IF @cPOKey <> '' AND @cPOKey IS NOT NULL AND
               @cPOKey <> 'NOPO'
            BEGIN
               -- Validate whether PO have multiple ASN
               SELECT DISTINCT
                  @cChkFacility = R.Facility,
                  @cChkStorerKey = R.StorerKey,
                  @cReceiptKey = R.ReceiptKey,
                  @cReceiptStatus = R.Status
               FROM dbo.Receipt R WITH (NOLOCK)
                  INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
               WHERE RD.POKey = @cPOKey
               SET @nRowCount = @@ROWCOUNT

               IF @nRowCount = 0
               BEGIN
                  SET @nErrNo = 165511
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PO not exist
                  SET @cOutField02 = '' -- POKey
                  SET @cPOKey = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 2
                  GOTO Quit
               END

               IF @nRowCount > 1
               BEGIN
                  SET @nErrNo = 165512
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiASN in PO
                  SET @cOutField01 = '' -- ReceiptKey
                  SET @cOutField02 = @cPOKey
                  SET @cReceiptKey = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 1
                  GOTO Quit
               END
            END

      -- Validate ASN in different facility
      IF @cFacility <> @cChkFacility
      BEGIN
         SET @nErrNo = 165513
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         SET @cOutField01 = '' -- ReceiptKey
         SET @cReceiptKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Check storer group
      IF @cStorerGroup <> ''
      BEGIN
         -- Check storer not in storer group
         IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cChkStorerKey)
         BEGIN
            SET @nErrNo = 165514
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
            SET @cOutField01 = '' -- ReceiptKey
            SET @cReceiptKey = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END

         -- Set session storer
         SET @cStorerKey = @cChkStorerKey
      END

      -- Validate ASN belong to the storer
      IF @cStorerKey <> @cChkStorerKey
      BEGIN
         SET @nErrNo = 165515
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
         SET @cOutField01 = '' -- ReceiptKey
         SET @cReceiptKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Validate ASN status
      IF @cReceiptStatus = '9'
      BEGIN
         SET @nErrNo = 165516
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN is closed
         SET @cOutField01 = '' -- ReceiptKey
         SET @cReceiptKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Check ASN cancelled
      IF @cReceiptStatus = 'CANC'
      BEGIN
         SET @nErrNo = 165517
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN cancelled
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = '' -- ReceiptKey
         SET @cReceiptKey = ''
         GOTO Quit
      END

      -- Get storer config
      SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)
      SET @cVerifySKU = rdt.RDTGetConfig( @nFunc, 'VerifySKU', @cStorerKey)
      SET @cCheckSKUInASN = rdt.RDTGetConfig( @nFunc, 'CheckSKUInASN', @cStorerKey) 
      SET @cDisableQTYField = rdt.RDTGetConfig( @nFunc, 'DisableQTYField', @cStorerKey)
      SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)
      IF @cDefaultQTY = '0'
         SET @cDefaultQTY = ''
      SET @cDefaultToLOC = rdt.RDTGetConfig( @nFunc, 'DefaultToLOC', @cStorerKey)
      IF @cDefaultToLOC = '0'
         SET @cDefaultToLOC = ''
      SET @cDecodeSKUSP = rdt.RDTGetConfig( @nFunc, 'DecodeSKUSP', @cStorerKey)
      IF @cDecodeSKUSP = '0'
         SET @cDecodeSKUSP = ''
      SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
      IF @cExtendedInfoSP = '0'
         SET @cExtendedInfoSP = ''
      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''
      -- (james02)
      SET @cCheckIDInUse = rdt.RDTGetConfig( @nFunc, 'CheckIDInUse', @cStorerKey)
      IF @cCheckIDInUse = '0'
         SET @cCheckIDInUse = ''

      IF @cSuggestLocSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSuggestLocSP AND type = 'P')  
         BEGIN  
             SET @cSQL = 'EXEC rdt.' + RTRIM( @cSuggestLocSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +   
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cSKU, @nQTY, ' +  
               ' @cDefaultToLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
            SET @cSQLParam =  
               '@nMobile       INT,           ' +  
               '@nFunc         INT,           ' +  
               '@cLangCode     NVARCHAR( 3),  ' +  
               '@nStep         INT,           ' +  
               '@nInputKey     INT,           ' +  
               '@cFacility     NVARCHAR( 5),  ' +  
               '@cStorerKey    NVARCHAR( 15), ' +  
               '@cReceiptKey   NVARCHAR( 10), ' +  
               '@cPOKey        NVARCHAR( 10), ' +  
               '@cRefNo        NVARCHAR( 30), ' +  
               '@cID           NVARCHAR( 18), ' +  
               '@cSKU          NVARCHAR( 20), ' +  
               '@nQTY          INT,           ' +  
               '@cDefaultToLOC NVARCHAR( 10) OUTPUT, ' +  
               '@nErrNo        INT           OUTPUT, ' +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,   
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cSKU, @nQTY,  
               @cDefaultToLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
      END  
  
      -- DefaultToLOC, by facility
      IF @cDefaultToLOC = ''
      BEGIN
         DECLARE @c_authority NVARCHAR(1)
         SELECT @b_success = 0
         EXECUTE nspGetRight
            @cFacility,
            @cStorerKey,
            NULL, -- @cSKU
            'ASNReceiptLocBasedOnFacility',
            @b_success   OUTPUT,
            @c_authority OUTPUT,
            @n_err       OUTPUT,
            @c_errmsg    OUTPUT

         IF @b_success = '1' AND @c_authority = '1'
            SELECT @cDefaultToLOC = UserDefine04
            FROM Facility WITH (NOLOCK)
            WHERE Facility = @cFacility
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cPOKey        NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 30), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
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
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nAfterStep    INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cPOKey        NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 30), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
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
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_ASNREFNo, @nStep_LOC, @nInputKey, @cFacility, @cStorerKey, 
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cDefaultToLOC -- LOC

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- LOC

      -- Go to next screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
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
END
GOTO Quit

/********************************************************************************
Step 2. Scn = 4274. ID, LOC screen
   ASN     (field01)
   PO      (field02)
   LOC     (field03, input)
********************************************************************************/
Step_LOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField03

      -- Validate compulsary field
      IF @cLOC = ''
      BEGIN
         SET @nErrNo = 165518
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOC
         GOTO Quit
      END

      -- Get the location
      SET @cChkLOC = ''
      SET @cChkFacility = ''
      SELECT
         @cChkLOC = LOC,
         @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cLOC

      -- Validate location
      IF @cChkLOC = ''
      BEGIN
         SET @nErrNo = 165519
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC
         SET @cOutField04 = ''
         GOTO Quit
      END

      -- Validate location not in facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 165520
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC
         SET @cOutField04 = ''
         GOTO Quit
      END
      SET @cOutField03 = @cLOC

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cPOKey        NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 30), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
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
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      SELECT @nASNQty = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      -- Enable / disable QTY
      SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END

      -- Prepare next screen variable
      SET @cOutField01 = @cLOC
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- Descr1
      SET @cOutField05 = '' -- Descr2
      SET @cOutField06 = @nASNQty -- Stat
      SET @cOutField07 = @cDefaultQTY -- QTY
      SET @cOutField08 = '' -- UOM

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to next screen
      SET @nScn = @nScn_SKUQTY
      SET @nStep = @nStep_SKUQTY
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nAfterStep    INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cPOKey        NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 30), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
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
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nAfterStep    INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cPOKey        NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 30), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
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
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_LOC, @nScn_LOC, @nInputKey, @cFacility, @cStorerKey, 
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END

      -- Set focus on last key in field (james01)
      IF ISNULL( @cReceiptKey, '') <> ''
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN

      IF ISNULL( @cRefNo, '') <> ''
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- RefNo

      -- Prepare next screen variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      -- Go to ASN screen        
      SET @nScn = @nScn_ASNRefNo        
      SET @nStep = @nStep_ASNRefNo        

   END
END
GOTO Quit

/***********************************************************************************
Step 4. Scn = 4271. SKU, QTY screen
   ID       (field01)
   LOC      (field02)
   SKU      (field03, input)
   SKU      (field04)
   Desc1    (field05)
   Desc2    (field06)
   RCV/EXP  (field07)
   QTY      (field08, input)
   UOM      (field09)
   IDQTY    (field10)
   ExtInfo  (field11)
   CondCode (field12, input)
***********************************************************************************/
Step_SKUQTY:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cQTY     NVARCHAR( 5)

      -- Screen mapping
      SET @cSKU = @cInField02 -- SKU
      SET @cBarcode = @cInField02
      SET @cQTY = CASE WHEN @cFieldAttr07 = 'O' THEN @cOutField07 ELSE @cInField07 END -- QTY
      SET @cUCCUOM = ''    -- ZG01

      -- Validate blank
      IF @cSKU = ''
      BEGIN
         SET @nErrNo = 165521
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU needed
         GOTO Step_SKUQTY_Fail_SKU
      END

      -- Decode
      IF @cDecodeSKUSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSKUSP AND type = 'P')
         BEGIN
            DECLARE @nUCCQTY  INT
            SET @nUCCQTY = 0

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSKUSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, @cBarcode, ' +
               ' @cSKU        OUTPUT, @nUCCQTY     OUTPUT, @cUCCUOM OUTPUT, ' +  
               ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' +
               ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' +
               ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cReceiptKey  NVARCHAR( 10), ' +
               ' @cPOKey       NVARCHAR( 10), ' +
               ' @cLOC         NVARCHAR( 10), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
               ' @nUCCQTY      INT            OUTPUT, ' +
               ' @cUCCUOM      NVARCHAR( 6)   OUTPUT, ' +  
               ' @cLottable01  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable02  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable03  NVARCHAR( 18)  OUTPUT, ' +
               ' @dLottable04  DATETIME       OUTPUT, ' +
               ' @dLottable05  DATETIME       OUTPUT, ' +
               ' @cLottable06  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable07  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable08  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable09  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable10  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable11  NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable12  NVARCHAR( 30)  OUTPUT, ' +
               ' @dLottable13  DATETIME       OUTPUT, ' +
               ' @dLottable14  DATETIME       OUTPUT, ' +
               ' @dLottable15  DATETIME       OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, @cBarcode,
               @cSKU        OUTPUT, @nUCCQTY     OUTPUT, @cUCCUOM OUTPUT,  
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_SKUQTY_Fail_SKU

            IF @nUCCQTY > 0
               SET @cQTY = CAST( @nUCCQTY AS NVARCHAR(5))
         END
      END
      
      -- Get SKU/UPC
      DECLARE @nSKUCnt INT
      SET @nSKUCnt = 0

      EXEC RDT.rdt_GETSKUCNT
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 165522
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO Step_SKUQTY_Fail_SKU
      END

      IF @nSKUCnt = 1
         EXEC [RDT].[rdt_GETSKU]
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cSKU          OUTPUT
            ,@bSuccess    = @b_Success     OUTPUT
            ,@nErr        = @nErrNo        OUTPUT
            ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         IF @cMultiSKUBarcode IN ('1', '2')
         BEGIN
            EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
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
               @cMultiSKUBarcode,
               @cStorerKey,
               @cSKU     OUTPUT,
               @nErrNo   OUTPUT,
               @cErrMsg  OUTPUT,
               'ASN',    -- DocType
               @cReceiptKey

            IF @nErrNo = 0 -- Populate multi SKU screen
            BEGIN
               -- Go to Multi SKU screen
               SET @nScn = @nScn_MultiSKU
               SET @nStep = @nStep_MultiSKU
               GOTO Quit
            END
            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
               SET @nErrNo = 0
         END
         ELSE
         BEGIN
            SET @nErrNo = 165523
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
            GOTO Step_SKUQTY_Fail_SKU
         END
      END

      -- Check SKU in ASN
      IF @cCheckSKUInASN = '1'
      BEGIN
         IF NOT EXISTS( SELECT 1
            FROM dbo.Receiptdetail WITH (NOLOCK)
            WHERE Receiptkey = @cReceiptKey
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU)
         BEGIN
            SET @nErrNo = 165524
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not in ASN
            GOTO Step_SKUQTY_Fail_SKU
         END
      END

      -- Get SKU info
      SELECT
         @cSKUDesc = ISNULL( DescR, ''),
         @cLottableCode = LottableCode,
         @cUOM = CASE WHEN @cUCCUOM<>'' THEN @cUCCUOM ELSE Pack.PackUOM3 END --(yeekung02)  
      FROM dbo.SKU SKU WITH (NOLOCK)
         JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

      -- Retain value
      SET @cOutField03 = @cSKU
      SET @cOutField04 = @cSKU
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField09 = @cUOM

      -- Verify SKU
      IF @cVerifySKU = '1'
      BEGIN
         EXEC rdt.rdt_VerifySKU_V7 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDesc, 'CHECK',
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT

         IF @nErrNo <> 0
         BEGIN
            -- Go to verify SKU screen
            SET @nScn = 3951
            SET @nStep = @nStep_VerifySKU

            GOTO Quit
         END
      END

      -- Check QTY blank
      IF @cQTY = ''
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- QTY
         GOTO Step_SKUQTY_Quit
      END

      -- Check QTY valid
      IF rdt.rdtIsValidQty( @cQTY, 1) = 0
      BEGIN
         SET @nErrNo = 165525
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         GOTO Step_SKUQTY_Fail_QTY
      END

      -- Retain QTY field
      SET @cOutField08 = @cQTY
      SET @nQTY = CAST( @cQTY AS INT)

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cPOKey        NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 30), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
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
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'CAPTURE', 'POPULATE', 5, 1,
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         @cReceiptKey,
         @nFunc
      IF @nErrNo <> 0
         GOTO Quit

      IF @nMorePage = 1 -- Yes
      BEGIN
         -- Go to dynamic lottable screen
         SET @nScn = @nScn_Lottables
         SET @nStep = @nStep_Lottables

         GOTO Step_SKUQTY_Quit
      END

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nAfterStep    INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cPOKey        NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 30), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
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
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_SKUQTY, @nStep_ID, @nInputKey, @cFacility, @cStorerKey, 
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END
      
      SELECT @nASNQTY = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      
      -- Prepare next screen variable
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cLOC
      SET @cOutField04 = '' -- ID
      SET @cOutField05 = '' -- ID Qty
      SET @cOutField06 = @nASNQTY -- ASN Qty

      -- Go to next screen
      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cLOC

      -- Go to prev screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
   END
   GOTO Quit

   Step_SKUQTY_Fail_SKU:
   BEGIN
      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nErrNo, @cErrMsg
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
      SET @cOutField03 = ''
      SET @cSKU = ''
      GOTO Quit
   END

   Step_SKUQTY_Fail_QTY:
   BEGIN
      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nErrNo, @cErrMsg
      EXEC rdt.rdtSetFocusField @nMobile, 8 -- QTY
      SET @cOutField08 = ''
      GOTO Quit
   END
   
   Step_SKUQTY_Quit:
END
GOTO Quit

/********************************************************************************
Step 4. Scn = 3990. Dynamic lottables
   Label01    (field01)
   Lottable01 (field02, input)
   Label02    (field03)
   Lottable02 (field04, input)
   Label03    (field05)
   Lottable03 (field06, input)
   Label04    (field07)
   Lottable04 (field08, input)
   Label05    (field09)
   Lottable05 (field10, input)
********************************************************************************/
Step_Lottables:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'CAPTURE', 'CHECK', 5, 1,
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         @cReceiptKey,
         @nFunc

      IF @nErrNo <> 0
         GOTO Quit

      IF @nMorePage = 1 -- Yes
         GOTO Quit

      -- Enable field
      SET @cFieldAttr02 = '' -- Dynamic lottable 1..5
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nAfterStep    INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cPOKey        NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 30), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
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
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_Lottables, @nStep_ID, @nInputKey, @cFacility, @cStorerKey, 
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END
      
      -- Prepare next screen variable
      SELECT @nASNQTY = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      
      -- Prepare next screen variable
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cLOC
      SET @cOutField04 = '' -- ID
      SET @cOutField05 = '' -- ID Qty
      SET @cOutField06 = @nASNQTY -- ASN Qty

      -- Go to ID screen
      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'CAPTURE', 'POPULATE', 5, 1,
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         @cReceiptKey,
         @nFunc

      IF @nMorePage = 1 -- Yes
         GOTO Quit

      -- Enable field
      SET @cFieldAttr02 = '' -- Dynamic lottable 1..5
      SET @cFieldAttr04 = '' --
      SET @cFieldAttr06 = '' --
      SET @cFieldAttr08 = '' --
      SET @cFieldAttr10 = '' --

      -- Prepare next screen var
      SELECT @nASNQty = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      -- Enable / disable QTY
      SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END

      -- Prepare next screen variable
      SET @cOutField01 = @cLOC
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- Descr1
      SET @cOutField05 = '' -- Descr2
      SET @cOutField06 = @nASNQty -- Stat
      SET @cOutField07 = @cDefaultQTY -- QTY
      SET @cOutField08 = '' -- UOM

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to next screen
      SET @nScn = @nScn_SKUQty
      SET @nStep = @nStep_SKUQty
   END
END
GOTO Quit

/********************************************************************************
Step 5. Scn = 5893. ID, LOC screen
   ASN         (field01)
   PO          (field02)
   To LOC      (field03)
   To ID       (field04, input)
   To ID Qty   (field05)
********************************************************************************/
Step_ID:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cID = @cInField04 -- ID

      -- Check ID format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cID) = 0
      BEGIN
         SET @nErrNo = 165526
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Quit
      END

      IF @cID <> ''
      BEGIN
         EXECUTE nspGetRight
            @cFacility,
            @cStorerKey,
            NULL, -- @cSKU
            'DisAllowDuplicateIdsOnRFRcpt',
            @b_Success   OUTPUT,
            @cAuthority  OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT

         -- Check ID in used
         IF @cAuthority = '1' AND @cID <> ''
         BEGIN
            IF EXISTS( SELECT [ID]
               FROM dbo.LOTxLOCxID LOTxLOCxID WITH (NOLOCK)
                  INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC)
               WHERE [ID] = @cID
                  AND QTY > 0
                  AND LOC.Facility = @cFacility)
            BEGIN
               SET @nErrNo = 165527
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Duplicate ID
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID
               SET @cOutField02 = ''
               GOTO Quit
            END
         END
         
         SET @cOutField04 = @cID
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cPOKey        NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 30), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
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
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END
      
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN Step_ID -- For rollback or commit only our own transaction

      -- Receive
      EXEC rdt.rdt_ReceivingByPalletID_Confirm
         @nFunc               = @nFunc,
         @nMobile             = @nMobile,
         @cLangCode           = @cLangCode,
         @cStorerKey          = @cStorerKey,
         @cFacility           = @cFacility,
         @cReceiptKey         = @cReceiptKey,
         @cPOKey              = @cPOKey,
         @cRefNo              = @cRefNo,
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
         @cConditionCode      = 'OK',
         @cSubreasonCode      = '',
         @tConfirmVar         = @tConfirmVar,
         @cReceiptLineNumber  = @cReceiptLineNumber OUTPUT,
         @nErrNo              = @nErrNo    OUTPUT,
         @cErrMsg             = @cErrMsg   OUTPUT

      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN Step_ID
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Quit
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nAfterStep    INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cPOKey        NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 30), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
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
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END
      
      COMMIT TRAN Step_ID
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nAfterStep    INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cPOKey        NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 30), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
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
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_ID, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END

      SELECT @nASNQTY = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      
      SELECT @nIDQTY = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   ToId = @cID
      
      -- Prepare next screen variable (remain in current screen)
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey 
      SET @cOutField03 = @cLOC
      SET @cOutField04 = '' -- ID
      SET @cOutField05 = @nIDQTY
      SET @cOutField06 = @nASNQTY
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'CAPTURE', 'POPULATE', 5, 1,
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         @cReceiptKey,
         @nFunc

      IF @nErrNo <> 0
         GOTO Quit

      IF @nMorePage = 1 -- Yes
      BEGIN
         -- Go to dynamic lottable screen
         SET @nScn = @nScn_Lottables
         SET @nStep = @nStep_Lottables

         -- To bypass ExtendedInfo override OutField15 required by dynamic lottable
         GOTO Quit
      END
      ELSE
      BEGIN
         -- Enable field
         SET @cFieldAttr02 = '' -- Dynamic lottable 1..5
         SET @cFieldAttr04 = '' --
         SET @cFieldAttr06 = '' --
         SET @cFieldAttr08 = '' --
         SET @cFieldAttr10 = '' --

         -- Prepare next screen var
         SELECT @nASNQty = ISNULL( SUM( BeforeReceivedQty), 0)
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey

         -- Enable / disable QTY
         SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END

         -- Prepare next screen variable
         SET @cOutField01 = @cLOC
         SET @cOutField02 = '' -- SKU
         SET @cOutField03 = '' -- SKU
         SET @cOutField04 = '' -- Descr1
         SET @cOutField05 = '' -- Descr2
         SET @cOutField06 = @nASNQty -- Stat
         SET @cOutField07 = @cDefaultQTY -- QTY
         SET @cOutField08 = '' -- UOM

         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

         -- Go to next screen
         SET @nScn = @nScn_SKUQty
         SET @nStep = @nStep_SKUQty
      END
   END
END
GOTO Quit

/********************************************************************************
Step 6. Screen = 3950. Verify SKU
   SKU            (Field01)
   SKUDesc1       (Field02)
   SKUDesc2       (Field03)
   Field label 1  (Field04)
   Field value 1  (Field05, input)
   Field label 2  (Field06)
   Field value 2  (Field07, input)
   Field label 3  (Field08)
   Field value 3  (Field09, input)
   Field label 4  (Field10)
   Field value 4  (Field11, input)
   Field label 5  (Field12)
   Field value 5  (Field13, input)
********************************************************************************/
Step_VerifySKU:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Update SKU setting
      EXEC rdt.rdt_VerifySKU_V7 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDesc, 'UPDATE',
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT

      IF @nErrNo <> 0
         GOTO Quit

      -- Enable field
      SET @cFieldAttr05 = '' -- Dynamic verify SKU 1..5
      SET @cFieldAttr07 = '' --
      SET @cFieldAttr09 = '' --
      SET @cFieldAttr11 = '' --
      SET @cFieldAttr13 = '' --

      -- Enable / disable QTY
      SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END

      -- Prepare next screen variable
      SET @cOutField01 = @cLOC
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- Descr1
      SET @cOutField05 = '' -- Descr2
      SET @cOutField06 = '' -- Stat
      SET @cOutField07 = @cDefaultQTY -- QTY
      SET @cOutField08 = '' -- UOM

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to next screen
      SET @nScn = @nScn_SKUQty
      SET @nStep = @nStep_SKUQty
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Enable field
      SET @cFieldAttr05 = '' -- Dynamic verify SKU 1..5
      SET @cFieldAttr07 = '' --
      SET @cFieldAttr09 = '' --
      SET @cFieldAttr11 = '' --
      SET @cFieldAttr13 = '' --

      -- Enable / disable QTY
      SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END

      -- Prepare next screen variable
      SET @cOutField01 = @cLOC
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- Descr1
      SET @cOutField05 = '' -- Descr2
      SET @cOutField06 = '' -- Stat
      SET @cOutField07 = @cDefaultQTY -- QTY
      SET @cOutField08 = '' -- UOM

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to next screen
      SET @nScn = @nScn_SKUQty
      SET @nStep = @nStep_SKUQty
   END

   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 7. Screen = 3570. Multi SKU
   SKU         (Field01)
   SKUDesc1    (Field02)
   SKUDesc2    (Field03)
   SKU         (Field04)
   SKUDesc1    (Field05)
   SKUDesc2    (Field06)
   SKU         (Field07)
   SKUDesc1    (Field08)
   SKUDesc2    (Field09)
   Option      (Field10, input)
********************************************************************************/
Step_MultiSKU:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
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
         @cMultiSKUBarcode,
         @cStorerKey,
         @cSKU     OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
      END

      -- Get SKU info
      SELECT @cSKUDesc = 
               CASE WHEN @cDispStyleColorSize = '0'
                    THEN ISNULL( DescR, '')
                    ELSE CAST( Style AS NCHAR(20)) +   
                         CAST( Color AS NCHAR(10)) +   
                         CAST( Size  AS NCHAR(10))
               END
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU
   END

   -- Enable field
   SET @cFieldAttr05 = '' -- Dynamic verify SKU 1..5
   SET @cFieldAttr07 = '' --
   SET @cFieldAttr09 = '' --
   SET @cFieldAttr11 = '' --
   SET @cFieldAttr13 = '' --

   -- Enable / disable QTY
   SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END

   -- Prepare next screen variable
   SET @cOutField01 = @cLOC
   SET @cOutField02 = '' -- SKU
   SET @cOutField03 = '' -- SKU
   SET @cOutField04 = '' -- Descr1
   SET @cOutField05 = '' -- Descr2
   SET @cOutField06 = '' -- Stat
   SET @cOutField07 = @cDefaultQTY -- QTY
   SET @cOutField08 = '' -- UOM

   EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

   -- Go to next screen
   SET @nScn = @nScn_SKUQty
   SET @nStep = @nStep_SKUQty
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

      Facility     = @cFacility,
      
      StorerGroup  = @cStorerGroup,
      V_StorerKey  = @cStorerKey,
      V_UOM        = @cUOM,
      V_ReceiptKey = @cReceiptKey,
      V_POKey      = @cPOKey,
      V_LOC        = @cLOC,
      V_ID         = @cID,
      V_SKU        = @cSKU,
      V_SKUDescr   = @cSKUDesc,
      V_QTY        = @nQTY,
      V_Lottable01 = @cLottable01,
      V_Lottable02 = @cLottable02,
      V_Lottable03 = @cLottable03,
      V_Lottable04 = @dLottable04,
      V_Lottable05 = @dLottable05,
      V_Lottable06 = @cLottable06,
      V_Lottable07 = @cLottable07,
      V_Lottable08 = @cLottable08,
      V_Lottable09 = @cLottable09,
      V_Lottable10 = @cLottable10,
      V_Lottable11 = @cLottable11,
      V_Lottable12 = @cLottable12,
      V_Lottable13 = @dLottable13,
      V_Lottable14 = @dLottable14,
      V_Lottable15 = @dLottable15,

      V_Integer1   = @nTotalQTYExp,
      V_Integer2   = @nTotalQTYRcv,
      V_Integer3   = @nBalQTY, 
      V_Integer4   = @nFromScn,
      V_Integer5   = @nIDQTY,      
      V_Integer6   = @nBeforeReceivedQTY,      
      V_Integer7   = @nQTYExpected,      

      V_DateTime1  = @dArriveDate,

      V_String1    = @cRefNo,
      V_String2    = @cLottableCode,
      V_String3    = @cSuggID,
      V_String4    = @cSuggLOC,
      V_String5    = @cReceiptLineNumber,
      V_String7    = @cOption,
      V_String8    = @cDisableQTYField,
      V_String9    = @cDefaultQTY,
      V_String10   = @cCheckIDInUse,
      V_string11   = @cSuggestLocSP,
      V_string12   = @cUCCUOM,
      
      V_String17   = @cDispStyleColorSize,
      V_String18   = @cSerialNoCapture,
      V_String19   = @cDisableToIDField,
      V_String20   = @cCaptureReceiptInfoSP,
      V_String21   = @cDefaultToLOC,
      V_String22   = @cDecodeSKUSP,
      V_String23   = @cVerifySKU,
      V_String24   = @cExtendedPutawaySP,
      V_String25   = @cOverrideSuggestID,
      V_String26   = @cOverrideSuggestLOC,
      V_String27   = @cDefaultIDAsSuggID,
      V_String28   = @cDefaultLOCAsSuggLOC,
      V_String29   = @cExtendedInfoSP,
      V_String30   = @cExtendedInfo,
      V_String31   = @cExtendedValidateSP,
      V_String32   = @cExtendedUpdateSP,
      V_String33   = @cMultiSKUBarcode,
      V_String34   = @cCheckSKUInASN,
      V_String35   = @cRefNoSKULookup,
      V_String36   = @cFinalizeASN,
      V_String37   = @cPreToIDLOC,
      V_String38   = @cAllowOverReceive, 
      V_String39   = @cAutoReceiveNext,
      V_String40   = @cSKULabel,

      V_String41   = @cData1,
      V_String42   = @cData2,
      V_String43   = @cData3,
      V_String44   = @cData4,
      V_String45   = @cData5,

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