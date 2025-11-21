SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store procedure: rdtfnc_SSCC_Receiving1                                       */
/* Copyright      : LFLogistics                                                  */
/*                                                                               */
/* Purpose: SSCC receiving                                                       */
/*                                                                               */
/* Date       Rev  Author   Purposes                                             */
/* 2023-03-01 1.0  Ung      WMS-21709 Created                                    */
/*********************************************************************************/

CREATE   PROCEDURE [RDT].[rdtfnc_SSCC_Receiving1] (
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @bSuccess       INT,
   @n_Err          INT,
   @c_ErrMsg       NVARCHAR( 250),
   @cBarcode       NVARCHAR( 60), 

   @cChkFacility   NVARCHAR( 5),
   @nMorePage      INT,
   @cSQL           NVARCHAR( MAX),
   @cSQLParam      NVARCHAR( MAX)

-- Session variable
DECLARE
   @nFunc        INT,
   @nScn         INT,
   @nStep        INT,
   @cLangCode    NVARCHAR( 3),
   @nInputKey    INT,
   @nMenu        INT,

   @cStorerGroup NVARCHAR( 20),
   @cStorerKey   NVARCHAR( 15),
   @cFacility    NVARCHAR( 5),

   @cPUOM        NVARCHAR(  1),
   @cReceiptKey  NVARCHAR( 10),
   @cLOC         NVARCHAR( 20),
   @cID          NVARCHAR( 18),
   @cSKU         NVARCHAR( 20),
   @cSKUDesc     NVARCHAR( 60),
   @cLottable01  NVARCHAR( 18),
   @cLottable02  NVARCHAR( 18),
   @cLottable03  NVARCHAR( 18),
   @dLottable04  DATETIME,
   @dLottable05  DATETIME,
   @cLottable06  NVARCHAR( 30),
   @cLottable07  NVARCHAR( 30),
   @cLottable08  NVARCHAR( 30),
   @cLottable09  NVARCHAR( 30),
   @cLottable10  NVARCHAR( 30),
   @cLottable11  NVARCHAR( 30),
   @cLottable12  NVARCHAR( 30),
   @dLottable13  DATETIME,
   @dLottable14  DATETIME,
   @dLottable15  DATETIME,
   @nPUOM_Div    INT,
   @nPQTY        INT,
   @nMQTY        INT,
   @nQTY         INT,

   @cRefNo              NVARCHAR( 20),
   @cIVAS               NVARCHAR( 20),
   @cLottableCode       NVARCHAR( 30),
   @cReasonCode         NVARCHAR( 10),
   @cPUOM_Desc          NCHAR( 5),
   @cMUOM_Desc          NCHAR( 5),
   @cReceiptLineNumber  NVARCHAR( 5),

   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cDefaultToLOC       NVARCHAR( 20),
   @cDecodeSSCCSP       NVARCHAR( 20),
   @cDecodeSKUSP        NVARCHAR( 20),
   
   @cPalletSSCC         NVARCHAR( 30),
   @cCaseSSCC           NVARCHAR( 30),

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
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerGroup = StorerGroup,
   @cFacility  = Facility,

   @cStorerKey  = V_StorerKey,
   @cPUOM       = V_UOM,
   @cReceiptKey = V_Receiptkey,
   @cLOC        = V_LOC,
   @cID         = V_ID,
   @cSKU        = V_SKU,
   @cSKUDesc    = V_SKUDescr,
   @cLottable01 = V_Lottable01,
   @cLottable02 = V_Lottable02,
   @cLottable03 = V_Lottable03,
   @dLottable04 = V_Lottable04,
   @dLottable05 = V_Lottable05,
   @cLottable06 = V_Lottable06,
   @cLottable07 = V_Lottable07,
   @cLottable08 = V_Lottable08,
   @cLottable09 = V_Lottable09,
   @cLottable10 = V_Lottable10,
   @cLottable11 = V_Lottable11,
   @cLottable12 = V_Lottable12,
   @dLottable13 = V_Lottable13,
   @dLottable14 = V_Lottable14,
   @dLottable15 = V_Lottable15,
   @nPUOM_Div   = V_PUOM_Div, 
   @nPQTY       = V_PQTY,
   @nMQTY       = V_MQTY,   
   @nQTY        = V_QTY, 

   @cRefNo              = V_String1,
   @cIVAS               = V_String2,
   @cLottableCode       = V_String3,
   @cReasonCode         = V_String4,
   @cMUOM_Desc          = V_String5,
   @cPUOM_Desc          = V_String6,
   @cReceiptLineNumber  = V_String7,

   @cExtendedValidateSP = V_String20,
   @cExtendedUpdateSP   = V_String21,
   @cExtendedInfoSP     = V_String22,
   @cExtendedInfo       = V_String23,
   @cDefaultToLOC       = V_String24,
   @cDecodeSSCCSP       = V_String25,
   @cDecodeSKUSP        = V_String26,
   
   @cPalletSSCC         = V_String41,
   @cCaseSSCC           = V_String42,

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
   @nStep_Start      INT,  
   @nStep_ASN        INT,  @nScn_ASN         INT,
   @nStep_LOC        INT,  @nScn_LOC         INT,
   @nStep_ID         INT,  @nScn_ID          INT,
   @nStep_SSCC       INT,  @nScn_SSCC        INT,
   @nStep_SKU        INT,  @nScn_SKU         INT,
   @nStep_Lottable   INT,  @nScn_Lottable    INT,
   @nStep_QTY        INT,  @nScn_QTY         INT

SELECT
   @nStep_Start      = 0,  
   @nStep_ASN        = 1,  @nScn_ASN         = 6220,
   @nStep_LOC        = 2,  @nScn_LOC         = 6221,
   @nStep_ID         = 3,  @nScn_ID          = 6222,
   @nStep_SSCC       = 4,  @nScn_SSCC        = 6223,
   @nStep_SKU        = 5,  @nScn_SKU         = 6224,
   @nStep_Lottable   = 6,  @nScn_Lottable    = 3990,
   @nStep_QTY        = 7,  @nScn_QTY         = 6225

-- Redirect to respective screen
IF @nFunc = 1584
BEGIN
   IF @nStep = 0 GOTO Step_Start       -- Func = 1584. Menu
   IF @nStep = 1 GOTO Step_ASN         -- Scn = 6220. ASN, REF NO
   IF @nStep = 2 GOTO Step_LOC         -- Scn = 6221. LOC
   IF @nStep = 3 GOTO Step_ID          -- Scn = 6222. ID
   IF @nStep = 4 GOTO Step_SSCC        -- Scn = 6223. Pallet, Case SSCC
   IF @nStep = 5 GOTO Step_SKU         -- Scn = 6224. SKU
   IF @nStep = 6 GOTO Step_Lottable    -- Scn = 3990. Lottable
   IF @nStep = 7 GOTO Step_QTY         -- Scn = 6225. QTY
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 1584. Menu
********************************************************************************/
Step_Start:
BEGIN
   -- Get default UOM
   SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = SUSER_SNAME()

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey

   -- Prepare next screen var
   SET @cOutField01 = '' -- ASN
   SET @cOutField03 = '' -- REFNO

   -- Set the entry point
   SET @nScn = @nScn_ASN
   SET @nStep = @nStep_ASN
END
GOTO Quit


/********************************************************************************
Step 1. Scn = ASN screen
   ASN      (field01, input)
   REF NO   (field03, input)
********************************************************************************/
Step_ASN:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cChkReceiptKey NVARCHAR( 10)
      DECLARE @cReceiptStatus NVARCHAR( 10)
      DECLARE @cChkStorerKey NVARCHAR( 15)
      DECLARE @nRowCount INT

      -- Screen mapping
      SET @cReceiptKey = @cInField01
      SET @cRefNo = @cInField03

      -- Check ref no
      IF @cRefNo <> '' AND @cReceiptKey = ''
      BEGIN
         -- Get storer config
         DECLARE @cFieldName NVARCHAR(20)
         SET @cFieldName = rdt.RDTGetConfig( @nFunc, 'RefNoLookupColumn', @cStorerKey)

         -- Get lookup field data type
         DECLARE @cDataType NVARCHAR(128)
         SET @cDataType = ''
         SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Receipt' AND COLUMN_NAME = @cFieldName

         IF @cDataType <> ''
         BEGIN
            IF @cDataType = 'nvarchar' SET @n_Err = 1                                ELSE
            IF @cDataType = 'datetime' SET @n_Err = rdt.rdtIsValidDate( @cRefNo)     ELSE
            IF @cDataType = 'int'      SET @n_Err = rdt.rdtIsInteger(   @cRefNo)     ELSE
            IF @cDataType = 'float'    SET @n_Err = rdt.rdtIsValidQTY(  @cRefNo, 20)

            -- Check data type
            IF @n_Err = 0
            BEGIN
               SET @nErrNo = 197301
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RefNo
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- RefNo
               GOTO Quit
            END

            DECLARE @tReceipt TABLE
            (
               RowRef     INT IDENTITY( 1, 1),
               ReceiptKey NVARCHAR( 10) NOT NULL
            )

            SET @cSQL =
               ' SELECT ReceiptKey ' +
               ' FROM dbo.Receipt WITH (NOLOCK) ' +
               ' WHERE Facility = ' + QUOTENAME( @cFacility, '''') +
                  ' AND ISNULL( ' + @cFieldName + CASE WHEN @cDataType IN ('int', 'float') THEN ',0)' ELSE ','''')' END + ' = ' + QUOTENAME( @cRefNo, '''') +
               ' ORDER BY ReceiptKey '

            -- Get ASN by RefNo
            INSERT INTO @tReceipt (ReceiptKey)
            EXEC (@cSQL)
            SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
            IF @nErrNo <> 0
               GOTO Quit

            -- Check RefNo in ASN
            IF @nRowCount = 0
            BEGIN
               SET @nErrNo = 197302
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- REF NO
               GOTO Quit
            END
            SET @cOutField03 = @cRefNo

            -- Only 1 ASN. Auto retrieve the ASN
            IF @nRowCount = 1
            BEGIN
               SELECT @cReceiptKey = ReceiptKey FROM @tReceipt
               SET @cOutField01 = @cReceiptKey
            END

            -- Multi ASN found, prompt user to select
            IF @nRowCount > 1
            BEGIN
               SET @nErrNo = 197303
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi ASN
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- REF NO
               GOTO Quit
            END
         END
      END

      -- Validate at least one field must key-in
      IF @cReceiptKey = ''
      BEGIN
         SET @nErrNo = 197304
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ASN or PO
         GOTO Quit
      END

      -- Get ASN info
      SELECT
          @cChkFacility = Facility,
          @cChkStorerKey = StorerKey,
          @cReceiptStatus = Status
      FROM dbo.Receipt WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      SET @nRowCount = @@ROWCOUNT

      -- Check ASN exist
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 197305
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN not exist
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN
         SET @cOutField01 = '' -- ASN
         GOTO Quit
      END

      -- Validate ASN in different facility
      IF @cFacility <> @cChkFacility
      BEGIN
         SET @nErrNo = 197306
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN
         SET @cOutField01 = '' -- ASN
         GOTO Quit
      END

      -- Check storer group
      IF @cStorerGroup <> ''
      BEGIN
         -- Check storer not in storer group
         IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cChkStorerKey)
         BEGIN
            SET @nErrNo = 197307
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN
            SET @cOutField01 = '' -- ASN
            GOTO Quit
         END

         -- Set session storer
         SET @cStorerKey = @cChkStorerKey
      END

      -- Validate ASN belong to the storer
      IF @cStorerKey <> @cChkStorerKey
      BEGIN
         SET @nErrNo = 197308
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN
         SET @cOutField01 = '' -- ASN
         GOTO Quit
      END

      -- Validate ASN status
      IF @cReceiptStatus = '9'
      BEGIN
         SET @nErrNo = 197309
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN is closed
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN
         SET @cOutField01 = '' -- ASN
         GOTO Quit
      END

      -- Get storer config
      SET @cDefaultToLOC = rdt.RDTGetConfig( @nFunc, 'DefaultToLoc', @cStorerKey)
      IF @cDefaultToLOC = '0'
         SET @cDefaultToLOC = ''
      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''
      SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
      IF @cExtendedInfoSP = '0'
         SET @cExtendedInfoSP = ''
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''
      SET @cDecodeSSCCSP = rdt.RDTGetConfig( @nFunc, 'DecodeSSCCSP', @cStorerKey)
      IF @cDecodeSSCCSP = '0'
         SET @cDecodeSSCCSP = ''
      SET @cDecodeSKUSP = rdt.RDTGetConfig( @nFunc, 'DecodeSKUSP', @cStorerKey)
      IF @cDecodeSKUSP = '0'
         SET @cDecodeSKUSP = ''

      -- DefaultToLOC, by facility
      IF @cDefaultToLOC = ''
      BEGIN
         DECLARE @cAuthority NVARCHAR(1)
         SET @bSuccess = 0
         EXECUTE nspGetRight
            @cFacility,
            @cStorerKey,
            NULL, -- @cSKU
            'ASNReceiptLocBasedOnFacility',
            @bSuccess    OUTPUT,
            @cAuthority  OUTPUT,
            @n_err       OUTPUT,
            @c_errmsg    OUTPUT

         IF @bSuccess = 1 AND @cAuthority = '1'
            SELECT @cDefaultToLOC = UserDefine04
            FROM Facility WITH (NOLOCK)
            WHERE Facility = @cFacility
      END

      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField03 = @cDefaultToLOC

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
Step 2. Scn = LOC screen
   ASN   (field01)
   TOLOC (field03, input)
********************************************************************************/
Step_LOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField03 -- LOC

      -- Check blank
      IF @cLOC = ''
      BEGIN
         SET @nErrNo = 197310
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOC
         GOTO Quit
      END

      -- Get the location
      DECLARE @cChkLOC NVARCHAR( 10) = ''
      SET @cChkFacility = ''
      SELECT
         @cChkLOC = LOC,
         @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cLOC

      -- Validate location
      IF @cChkLOC = ''
      BEGIN
         SET @nErrNo = 197311
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         SET @cOutField03 = '' -- LOC
         GOTO Quit
      END

      -- Validate location not in facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 197312
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         SET @cOutField03 = '' -- LOC
         GOTO Quit
      END

      -- Prepare next screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = '' -- ID

      -- Go to next screen
      SET @nScn  = @nScn_ID
      SET @nStep = @nStep_ID
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = '' -- ASN
      SET @cOutField03 = '' -- REF NO

      IF @cRefNo <> '' 
        EXEC rdt.rdtSetFocusField @nMobile, 3 -- REF NO
      ELSE
        EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN

      SET @nScn = @nScn_ASN
      SET @nStep = @nStep_ASN
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = ID screen
   TO LOC (field01)
   TO ID  (field02, input)
********************************************************************************/
Step_ID:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cID = LEFT( @cInField02, 18) -- ID

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cID) = 0
      BEGIN
         SET @nErrNo = 197313
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         SET @cOutField02 = '' -- ID
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cReceiptKey, @cRefNo, @cLOC, @cID, @cPalletSSCC, @cCaseSSCC, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nQTY, @cReasonCode, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cRefNo       NVARCHAR( 20), ' + 
               '@cLOC         NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
               '@cPalletSSCC  NVARCHAR( 30), ' +
               '@cCaseSSCC    NVARCHAR( 30), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cLottable01  NVARCHAR( 18), ' +
               '@cLottable02  NVARCHAR( 18), ' +
               '@cLottable03  NVARCHAR( 18), ' +
               '@dLottable04  DATETIME,      ' +
               '@dLottable05  DATETIME,      ' +
               '@cLottable06  NVARCHAR( 30), ' +
               '@cLottable07  NVARCHAR( 30), ' +
               '@cLottable08  NVARCHAR( 30), ' +
               '@cLottable09  NVARCHAR( 30), ' +
               '@cLottable10  NVARCHAR( 30), ' +
               '@cLottable11  NVARCHAR( 30), ' +
               '@cLottable12  NVARCHAR( 30), ' +
               '@dLottable13  DATETIME,      ' +
               '@dLottable14  DATETIME,      ' +
               '@dLottable15  DATETIME,      ' +
               '@nQTY         INT,           ' +
               '@cReasonCode  NVARCHAR( 10), ' +
               '@nErrNo             INT            OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cReceiptKey, @cRefNo, @cLOC, @cID, @cPalletSSCC, @cCaseSSCC, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nQTY, @cReasonCode, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Prev next screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = '' -- Pallet SSCC
      SET @cOutField03 = '' -- Case SSCC

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Pallet SSCC

      -- Go to next screen
      SET @nScn  = @nScn_SSCC
      SET @nStep = @nStep_SSCC
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField03 = '' -- LOC

      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
   END
END
GOTO Quit


/********************************************************************************
Step 4. Scn = SSCC screen
   TO ID       (field01)
   PALLET SSCC (field02, intput)
   CASE SSCC   (field03, intput)
********************************************************************************/
Step_SSCC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPalletSSCC = @cInField02 -- Pallet SSCC
      SET @cCaseSSCC = @cInField03   -- Case SSCC
      
      -- Check blank
      IF @cPalletSSCC = '' AND @cCaseSSCC = ''
      BEGIN
         SET @nErrNo = 197314
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SSCC
         GOTO Quit
      END
      
      -- Check either
      IF @cPalletSSCC <> '' AND @cCaseSSCC <> ''
      BEGIN
         SET @nErrNo = 197315
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet or Case
         GOTO Quit
      END
      
      -- Check format
      IF @cPalletSSCC <> ''
      BEGIN
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'PalletSSCC', @cPalletSSCC) = 0
         BEGIN
            SET @nErrNo = 197316
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Pallet SSCC
            SET @cOutField02 = '' -- Pallet SSCC
            GOTO Quit
         END
      END
      
      -- Check format
      IF @cCaseSSCC <> ''
      BEGIN
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CaseSSCC', @cCaseSSCC) = 0
         BEGIN
            SET @nErrNo = 197317
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- Case SSCC
            SET @cOutField03 = '' -- Case SSCC
            GOTO Quit
         END
      END
      
      -- Init var
      SELECT @cSKU = '', @nQTY = 0,
         @cLottable01 = '', @cLottable02 = '', @cLottable03 = '', @dLottable04 = 0,  @dLottable05 = 0,
         @cLottable06 = '', @cLottable07 = '', @cLottable08 = '', @cLottable09 = '', @cLottable10 = '',
         @cLottable11 = '', @cLottable12 = '', @dLottable13 = 0,  @dLottable14 = 0,  @dLottable15 = 0
      
      -- Decode
      IF @cDecodeSSCCSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSSCCSP = '1'
         BEGIN
            IF @cPalletSSCC <> ''
            BEGIN
               SET @cBarcode = @cPalletSSCC
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
                  @cUserDefine01 = @cPalletSSCC OUTPUT,
                  @cType         = 'PalletSSCC'
            END

            IF @cCaseSSCC <> ''
            BEGIN
               SET @cBarcode = @cCaseSSCC
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
                  @cUserDefine01 = @cCaseSSCC OUTPUT, 
                  @cType         = 'CaseSSCC'
            END
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSSCCSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSSCCSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cLOC, @cBarcode, ' +
               ' @cID         OUTPUT, @cPalletSSCC OUTPUT, @cCaseSSCC   OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT, ' +
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
               ' @cLOC         NVARCHAR( 10), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cID          NVARCHAR( 18)  OUTPUT, ' +
               ' @cPalletSSCC  NVARCHAR( 30)  OUTPUT, ' +
               ' @cCaseSSCC    NVARCHAR( 30)  OUTPUT, ' +
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
               ' @nQTY         INT            OUTPUT, ' +
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
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cLOC, @cBarcode, 
               @cID         OUTPUT, @cPalletSSCC OUTPUT, @cCaseSSCC   OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT,
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cOutField02 = '' -- Pallet SSCC
               SET @cOutField03 = '' -- Case SSCC
               GOTO Quit
            END
         END
      END
      
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cReceiptKey, @cRefNo, @cLOC, @cID, @cPalletSSCC, @cCaseSSCC, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nQTY, @cReasonCode, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cRefNo       NVARCHAR( 20), ' + 
               '@cLOC         NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
               '@cPalletSSCC  NVARCHAR( 30), ' +
               '@cCaseSSCC    NVARCHAR( 30), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cLottable01  NVARCHAR( 18), ' +
               '@cLottable02  NVARCHAR( 18), ' +
               '@cLottable03  NVARCHAR( 18), ' +
               '@dLottable04  DATETIME,      ' +
               '@dLottable05  DATETIME,      ' +
               '@cLottable06  NVARCHAR( 30), ' +
               '@cLottable07  NVARCHAR( 30), ' +
               '@cLottable08  NVARCHAR( 30), ' +
               '@cLottable09  NVARCHAR( 30), ' +
               '@cLottable10  NVARCHAR( 30), ' +
               '@cLottable11  NVARCHAR( 30), ' +
               '@cLottable12  NVARCHAR( 30), ' +
               '@dLottable13  DATETIME,      ' +
               '@dLottable14  DATETIME,      ' +
               '@dLottable15  DATETIME,      ' +
               '@nQTY         INT,           ' +
               '@cReasonCode  NVARCHAR( 10), ' +
               '@nErrNo             INT            OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cReceiptKey, @cRefNo, @cLOC, @cID, @cPalletSSCC, @cCaseSSCC, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nQTY, @cReasonCode, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END
      
      -- Init next screen var
      SET @cOutField01 = CASE WHEN @cPalletSSCC <> '' THEN @cPalletSSCC ELSE @cCaseSSCC END
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = '' -- SKUDesc1
      SET @cOutField04 = '' -- SKUDesc2

      -- Go to next screen
      SET @nScn  = @nScn_SKU
      SET @nStep = @nStep_SKU

      -- Flow thru SKU screen
      IF @cSKU <> ''
      BEGIN
         SET @cInField02 = @cSKU
         
         -- Go to SKU screen
         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU
         
         GOTO Step_SKU
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = '' -- @cID

      -- Go to ID screen
      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID
   END
END
GOTO Quit


/********************************************************************************
Step 4. Scn = SKU screen
   SSCC     (field01)
   SKU      (field02, intput)
   SKU desc (field03)
   SKU desc (field04)
********************************************************************************/
Step_SKU:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cUPC NVARCHAR(30)

      -- Screen mapping
      SET @cUPC = SUBSTRING( @cInField02, 1, 30) -- SKU
      SET @cBarcode = @cInField02

      -- Validate compulsary field
      IF @cBarcode = ''
      BEGIN
         SET @nErrNo = 197318
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU is require
         GOTO Quit
      END

      -- Decode
      IF @cDecodeSKUSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSKUSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cID         OUTPUT, @cUPC        OUTPUT, @nQTY        OUTPUT,
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @cType   = 'UPC'
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSKUSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSKUSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cLOC, @cBarcode, ' +
               ' @cID         OUTPUT, @cPalletSSCC OUTPUT, @cCaseSSCC   OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT, ' +
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
               ' @cLOC         NVARCHAR( 10), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cID          NVARCHAR( 18)  OUTPUT, ' +
               ' @cPalletSSCC  NVARCHAR( 30)  OUTPUT, ' +
               ' @cCaseSSCC    NVARCHAR( 30)  OUTPUT, ' +
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
               ' @nQTY         INT            OUTPUT, ' +
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
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cLOC, @cBarcode, 
               @cID         OUTPUT, @cPalletSSCC OUTPUT, @cCaseSSCC   OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT, 
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_SKU_Fail

            IF @cSKU <> ''
               SET @cUPC = @cSKU
         END
      END

      -- Check SKU
      DECLARE @nSKUCnt INT = 0
      EXEC RDT.rdt_GetSKUCNT
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC
         ,@nSKUCnt     = @nSKUCnt   OUTPUT
         ,@bSuccess    = @bSuccess  OUTPUT
         ,@nErr        = @nErrNo    OUTPUT
         ,@cErrMsg     = @cErrMsg   OUTPUT
         ,@cSKUStatus  = 'ACTIVE'
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 197319
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO Step_SKU_Fail
      END

      -- Get SKU
      IF @nSKUCnt = 1
      BEGIN
         EXEC [RDT].[rdt_GETSKU]
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cUPC      OUTPUT
            ,@bSuccess    = @bSuccess  OUTPUT
            ,@nErr        = @nErrNo    OUTPUT
            ,@cErrMsg     = @cErrMsg   OUTPUT
            ,@cSKUStatus  = 'ACTIVE'

         SET @cSKU = @cUPC
      END

      -- Check barcode return multi SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 197320
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
         GOTO Step_SKU_Fail
      END

      -- Get SKU info
      SELECT
         @cSKUDesc = IsNULL( DescR, ''),
         @cIVAS = IsNULL( IVAS, ''),
         @cLottableCode = LottableCode,
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
         JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

      -- Retain value
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20) -- SKU desc 2

      -- Check SKU in ASN
      IF NOT EXISTS( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND StorerKey = @cStorerKey AND SKU = @cSKU)
      BEGIN
         SET @nErrNo = 197321
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not in ASN
         GOTO Step_SKU_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cReceiptKey, @cRefNo, @cLOC, @cID, @cPalletSSCC, @cCaseSSCC, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nQTY, @cReasonCode, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cRefNo       NVARCHAR( 20), ' + 
               '@cLOC         NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
               '@cPalletSSCC  NVARCHAR( 30), ' +
               '@cCaseSSCC    NVARCHAR( 30), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cLottable01  NVARCHAR( 18), ' +
               '@cLottable02  NVARCHAR( 18), ' +
               '@cLottable03  NVARCHAR( 18), ' +
               '@dLottable04  DATETIME,      ' +
               '@dLottable05  DATETIME,      ' +
               '@cLottable06  NVARCHAR( 30), ' +
               '@cLottable07  NVARCHAR( 30), ' +
               '@cLottable08  NVARCHAR( 30), ' +
               '@cLottable09  NVARCHAR( 30), ' +
               '@cLottable10  NVARCHAR( 30), ' +
               '@cLottable11  NVARCHAR( 30), ' +
               '@cLottable12  NVARCHAR( 30), ' +
               '@dLottable13  DATETIME,      ' +
               '@dLottable14  DATETIME,      ' +
               '@dLottable15  DATETIME,      ' +
               '@nQTY         INT,           ' +
               '@cReasonCode  NVARCHAR( 10), ' +
               '@nErrNo             INT            OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cReceiptKey, @cRefNo, @cLOC, @cID, @cPalletSSCC, @cCaseSSCC, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nQTY, @cReasonCode, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_SKU_Fail
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
         SET @nScn = @nScn_Lottable
         SET @nStep = @nStep_Lottable
      END
      ELSE
      BEGIN
         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @nMQTY = @nQTY
            SET @cFieldAttr08 = 'O' -- @nPQTY
         END
         ELSE
         BEGIN
            SET @nPQTY = @nQTY / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY = @nQTY % @nPUOM_Div -- Calc the remaining in master unit
            SET @cFieldAttr08 = '' -- @nPQTY
         END

         -- Prepare next screen variable
         SET @cOutField01 = @cSKU
         SET @cOutField02 = rdt.rdtFormatString( @cSKUDesc, 1, 20)
         SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
         SET @cOutField04 = SUBSTRING( @cIVAS, 1, 20)
         SET @cOutField05 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
         SET @cOutField06 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
         SET @cOutField07 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
         SET @cOutField08 = CASE WHEN @nPQTY = 0 OR @cFieldAttr08 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END -- PQTY
         SET @cOutField09 = CASE WHEN @nMQTY = 0 THEN '' ELSE CAST( @nMQTY AS NVARCHAR( 5)) END -- MQTY
         SET @cOutField10 = '' -- Reason
         SET @cOutField15 = '' -- ExtendedInfo

         IF @cFieldAttr08 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY

         -- Go to QTY screen
         SET @nScn = @nScn_QTY
         SET @nStep = @nStep_QTY
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = '' -- Pallet SSCC
      SET @cOutField03 = '' -- Case SSCC

      IF @cPalletSSCC <> ''
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Pallet SSCC
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- Case SSCC

      -- Go to SSCC screen
      SET @nScn = @nScn_SSCC
      SET @nStep = @nStep_SSCC
   END
   GOTO Quit

   Step_SKU_Fail:
   BEGIN
      SET @cOutField02 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 5. Scn = lottables
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
Step_Lottable:
BEGIN
   IF @nInputKey = 1 -- ENTER
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

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @nMQTY = @nQTY
         SET @cFieldAttr08 = 'O' -- @nPQTY
      END
      ELSE
      BEGIN
         SET @nPQTY = @nQTY / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY = @nQTY % @nPUOM_Div -- Calc the remaining in master unit
         SET @cFieldAttr08 = '' -- @nPQTY
      END

      -- Prepare next screen variable
      SET @cOutField01 = @cSKU
      SET @cOutField02 = rdt.rdtFormatString( @cSKUDesc, 1, 20)
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
      SET @cOutField04 = SUBSTRING( @cIVAS, 1, 20)
      SET @cOutField05 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
      SET @cOutField06 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
      SET @cOutField07 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
      SET @cOutField08 = CASE WHEN @nPQTY = 0 OR @cFieldAttr08 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END -- PQTY
      SET @cOutField09 = CASE WHEN @nMQTY = 0 THEN '' ELSE CAST( @nMQTY AS NVARCHAR( 5)) END -- MQTY
      SET @cOutField10 = '' -- Reason
      SET @cOutField15 = '' -- ExtendedInfo

      IF @cFieldAttr08 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY

      -- Go to QTY screen
      SET @nScn  = @nScn_QTY
      SET @nStep = @nStep_QTY
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

      -- Load prev screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20) -- SKU desc 2

      -- Go back to prev screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END
END
GOTO Quit


/********************************************************************************
Step 6. Scn = QTY screen
   SKU       (field01)
   SKU desc  (field02)
   SKU desc  (field03)
   IVAS      (field04)
   UOM ratio (field05)
   PUOM      (field06)
   MUOM   (field07)
   PQTY      (field08, input)
   MQTY      (field09, input)
   Reason    (field10, input)
********************************************************************************/
Step_QTY:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cPQTY       NVARCHAR( 7)
      DECLARE @cMQTY       NVARCHAR( 7)

      -- Screen mapping
      SET @cPQTY = CASE WHEN @cFieldAttr08 = 'O' THEN @cOutField08 ELSE @cInField08 END
      SET @cMQTY = CASE WHEN @cFieldAttr09 = 'O' THEN @cOutField09 ELSE @cInField09 END
      SET @cReasonCode = @cInField10

      -- Retain value
      SET @cOutField08 = CASE WHEN @cFieldAttr08 = 'O' THEN @cOutField08 ELSE @cInField08 END -- PQTY
      SET @cOutField09 = CASE WHEN @cFieldAttr09 = 'O' THEN @cOutField09 ELSE @cInField09 END -- MQTY

      -- Validate PQTY
      IF @cPQTY <> '' AND RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 197322
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY
         GOTO Quit
      END
      SET @nPQTY = CAST( @cPQTY AS INT)

      -- Validate MQTY
      IF @cMQTY <> '' AND RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 197323
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 9 -- MQTY
         GOTO Quit
      END
      SET @nMQTY = CAST( @cMQTY AS INT)

      -- Calc total QTY in master UOM
      SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nQTY = @nQTY + @nMQTY

      -- Validate reason code exists
      IF @cReasonCode <> '' AND @cReasonCode IS NOT NULL
         IF NOT EXISTS( SELECT Code
            FROM dbo.CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'ASNREASON'
               AND Code = @cReasonCode)
         BEGIN
            SET @nErrNo = 197324
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad ReasonCode
            SET @cReasonCode = ''
            EXEC rdt.rdtSetFocusField @nMobile, 10
            GOTO Quit
         END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cReceiptKey, @cRefNo, @cLOC, @cID, @cPalletSSCC, @cCaseSSCC, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nQTY, @cReasonCode, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cRefNo       NVARCHAR( 20), ' + 
               '@cLOC         NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
               '@cPalletSSCC  NVARCHAR( 30), ' +
               '@cCaseSSCC    NVARCHAR( 30), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@cLottable01  NVARCHAR( 18), ' +
               '@cLottable02  NVARCHAR( 18), ' +
               '@cLottable03  NVARCHAR( 18), ' +
               '@dLottable04  DATETIME,      ' +
               '@dLottable05  DATETIME,      ' +
               '@cLottable06  NVARCHAR( 30), ' +
               '@cLottable07  NVARCHAR( 30), ' +
               '@cLottable08  NVARCHAR( 30), ' +
               '@cLottable09  NVARCHAR( 30), ' +
               '@cLottable10  NVARCHAR( 30), ' +
               '@cLottable11  NVARCHAR( 30), ' +
               '@cLottable12  NVARCHAR( 30), ' +
               '@dLottable13  DATETIME,      ' +
               '@dLottable14  DATETIME,      ' +
               '@dLottable15  DATETIME,      ' +
               '@nQTY         INT,           ' +
               '@cReasonCode  NVARCHAR( 10), ' +
               '@nErrNo             INT            OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cReceiptKey, @cRefNo, @cLOC, @cID, @cPalletSSCC, @cCaseSSCC, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nQTY, @cReasonCode, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Reason code
      IF @cReasonCode = ''
         SET @cReasonCode = 'OK'

      -- Receive
      EXEC rdt.rdt_SSCC_Receiving1_Confirm
         @nFunc          = @nFunc,
         @nMobile        = @nMobile,
         @cLangCode      = @cLangCode,
         @nStep          = @nStep, 
         @nInputKey      = @nInputKey, 
         @cStorerKey     = @cStorerKey,
         @cFacility      = @cFacility,
         @cReceiptKey    = @cReceiptKey,
         @cRefNo         = @cRefNo,
         @cLOC           = @cLOC,
         @cID            = @cID,
         @cPalletSSCC    = @cPalletSSCC, 
         @cCaseSSCC      = @cCaseSSCC, 
         @cSKU           = @cSKU,
         @cLottable01    = @cLottable01,
         @cLottable02    = @cLottable02,
         @cLottable03    = @cLottable03,
         @dLottable04    = @dLottable04,
         @dLottable05    = NULL,
         @cLottable06    = @cLottable06,
         @cLottable07    = @cLottable07,
         @cLottable08    = @cLottable08,
         @cLottable09    = @cLottable09,
         @cLottable10    = @cLottable10,
         @cLottable11    = @cLottable11,
         @cLottable12    = @cLottable12,
         @dLottable13    = @dLottable13,
         @dLottable14    = @dLottable14,
         @dLottable15    = @dLottable15,
         @nQTY           = @nQTY,
         @cConditionCode = @cReasonCode,
         @cSubreasonCode = '',
         @nErrNo         = @nErrNo  OUTPUT,
         @cErrMsg        = @cErrMsg OUTPUT,
         @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      IF @cPalletSSCC <> ''
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = '' -- ID
         
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID
         
         -- Go to ID screen
         SET @nScn = @nScn_ID
         SET @nStep = @nStep_ID
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cID
         SET @cOutField02 = '' -- Pallet SSCC
         SET @cOutField03 = '' -- Case SSCC

         EXEC rdt.rdtSetFocusField @nMobile, 3 -- Case SSCC
         
         -- Go to SSCC screen
         SET @nScn = @nScn_SSCC
         SET @nStep = @nStep_SSCC
      END
      
      -- Reset data
      SELECT @cPalletSSCC = '', @cCaseSSCC = '', @cSKU = '', @nQTY = 0,
         @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL, @dLottable05 = NULL,
         @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',   @cLottable10 = '',
         @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL, @dLottable15 = NULL
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
         SET @nScn = @nScn_Lottable
         SET @nStep = @nStep_Lottable
      END
      ELSE
      BEGIN
         -- Enable field
         SET @cFieldAttr02 = '' -- Dynamic lottable 1..5
         SET @cFieldAttr04 = '' --
         SET @cFieldAttr06 = '' --
         SET @cFieldAttr08 = '' --
         SET @cFieldAttr10 = '' --

         -- Prepare prev screen var
         SET @cOutField01 = @cID
         SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 1, 20)
         SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20)

         -- Go back to SKU screen
         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU
      END
      GOTO Quit
   END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      Facility     = @cFacility,

      V_StorerKey  = @cStorerKey,
      V_UOM        = @cPUOM,
      V_ReceiptKey = @cReceiptKey,
      V_LOC        = @cLOC,
      V_ID         = @cID,
      V_SKU        = @cSKU,
      V_SKUDescr   = @cSKUDesc,
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
      V_PUOM_Div   = @nPUOM_Div ,
      V_PQTY       = @nPQTY,
      V_MQTY       = @nMQTY,
      V_QTY        = @nQTY,

      V_String1    = @cRefNo,
      V_String2    = @cIVAS,
      V_String3    = @cLottableCode,
      V_String4    = @cReasonCode,
      V_String5    = @cMUOM_Desc,
      V_String6    = @cPUOM_Desc,
      V_String7    = @cReceiptLineNumber,

      V_String20   = @cExtendedValidateSP,
      V_String21   = @cExtendedUpdateSP,
      V_String22   = @cExtendedInfoSP,
      V_String23   = @cExtendedInfo,
      V_String24   = @cDefaultToLOC,
      V_String25   = @cDecodeSSCCSP,
      V_String26   = @cDecodeSKUSP,

      V_String41   = @cPalletSSCC,
      V_String42   = @cCaseSSCC,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01 = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02 = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03 = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04 = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05 = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06 = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07 = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08 = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09 = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10 = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11 = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12 = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13 = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14 = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15 = @cFieldAttr15

   WHERE Mobile = @nMobile
END

GO