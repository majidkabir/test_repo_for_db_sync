SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdtfnc_LineReceiving                                      */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2005-05-19 1.0  Ung      SOS315431 Created                                 */
/* 2016-03-18 1.1  James    Add Pallet ID validation (james01)                */
/* 2016-05-17 1.2  Ung      SOS370260 ReceiptConfirmSP param same as others   */
/* 2017-03-03 1.3  James    Add ExtendedUpdateSP (james02)                    */
/* 2018-03-29 1.4  Ung      WMS-4378 Add Verify SKU                           */
/* 2018-06-28 1.5  Ung      WMS-5564 Capture L05                              */
/* 2018-10-28 1.6  Gan      Performance tuning                                */
/* 2023-08-07 1.7  Ung      WMS-23117 Add DataCapture                         */
/* 2024-04-19 1.8  Dennis   UWP-18504 Condition Code Enhancements             */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdtfnc_LineReceiving] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cSQL         NVARCHAR( MAX),
   @cSQLParam    NVARCHAR( MAX),
   @cChkFacility NVARCHAR( 5),
   @bSuccess     INT,
   @nQTY         INT,
   @cLottable04  NVARCHAR( 10),
   @nMorePage    INT,
   @tVar         VariableTable

-- RDT.RDTMobRec variable
DECLARE
   @nFunc        INT,
   @nScn         INT,
   @nStep        INT,
   @cLangCode    NVARCHAR( 3),
   @nInputKey    INT,
   @nMenu        INT,

   @cPrinter     NVARCHAR(10),
   @cUserName    NVARCHAR(18),
   @cStorerGroup NVARCHAR( 20),
   @cStorerKey   NVARCHAR( 15),
   @cFacility    NVARCHAR( 5),

   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 20),
   @cID          NVARCHAR( 18),
   @cSKU         NVARCHAR( 20),
   @cSKUDesc     NVARCHAR( 60),
   @cPUOM        NVARCHAR( 10),
   @cBarcode     NVARCHAR( MAX),

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

   @cLineNo             NVARCHAR( 5),
   @cIVAS               NVARCHAR( 20),
   @cPUOM_Desc          NVARCHAR( 5),
   @cMUOM_Desc          NVARCHAR( 5),
   @nPUOM_Div           INT,
   @cLottableCode       NVARCHAR( 30),
   @cReasonCode         NVARCHAR( 10),

   @cPOKeyDefaultValue  NVARCHAR( 10),
   @cDefaultToLoc       NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cRcptConfirmSP      NVARCHAR( 20),
   @cPalletRecv         NVARCHAR( 1),
   @cExtendedUpdateSP   NVARCHAR( 20),   -- (james02)
   @cReceiptLineNumber  NVARCHAR( 5),   -- (james02)
   @cVerifySKU          NVARCHAR( 1),
   @cDecodeSP           NVARCHAR( 20), --(yeekung01)
   @cDataCapture        NVARCHAR( 1), 

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

-- Load RDT.RDTMobRec
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerGroup = StorerGroup,
   @cFacility    = Facility,
   @cPrinter     = Printer,
   @cUserName    = UserName,

   @cStorerKey  = V_StorerKey,
   @cPUOM       = V_UOM,
   @cReceiptKey = V_Receiptkey,
   @cPOKey      = V_POKey,
   @cLOC        = V_LOC,
   @cID         = V_ID,
   @cSKU        = V_SKU,
   @cSKUDesc    = V_SKUDescr,
   @nQTY        = V_QTY,
   @cBarcode    = V_Barcode,

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

   @cLineNo             = V_String1,
   @cIVAS               = V_String2,
   @cPUOM_Desc          = V_String4,
   @cMUOM_Desc          = V_String5,
  -- @nPUOM_Div           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6, 5), 0) = 1 THEN LEFT( V_String6, 5) ELSE 0 END,
   @cLottableCode       = V_String7,
   @cReasonCode         = V_String8,

   @cPOKeyDefaultValue  = V_String10,
   @cDefaultToLoc       = V_String11,
   @cExtendedValidateSP = V_String12,
   @cRcptConfirmSP      = V_String13,
   @cPalletRecv         = V_String14,
   @cExtendedUpdateSP   = V_String15,
   @cVerifySKU          = V_String16,
   @cDecodeSP           = V_String17,
   @cDataCapture        = V_String18,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,   @cFieldAttr01 = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,   @cFieldAttr02 = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,   @cFieldAttr03 = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,   @cFieldAttr04 = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,   @cFieldAttr05 = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,   @cFieldAttr06 = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,   @cFieldAttr07 = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,   @cFieldAttr08 = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,   @cFieldAttr09 = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,   @cFieldAttr10 = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,   @cFieldAttr11 = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,   @cFieldAttr12 = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,   @cFieldAttr13 = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,   @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,   @cFieldAttr15 = FieldAttr15

FROM RDT.RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_ASN              INT,  @nScn_ASN            INT,
   @nStep_LOC              INT,  @nScn_LOC            INT,
   @nStep_ID               INT,  @nScn_ID             INT,
   @nStep_LineNo           INT,  @nScn_LineNo         INT,
   @nStep_Lottable         INT,  @nScn_Lottable       INT,
   @nStep_QTY              INT,  @nScn_QTY            INT,
   @nStep_Message          INT,  @nScn_Message        INT,
   @nStep_VerifySKU        INT,  @nScn_VerifySKU      INT,
   @nStep_DataCapture      INT,  @nScn_DataCapture    INT
   
SELECT                                                
   @nStep_ASN              = 1,  @nScn_ASN            = 3980,
   @nStep_LOC              = 2,  @nScn_LOC            = 3981,
   @nStep_ID               = 3,  @nScn_ID             = 3982,
   @nStep_LineNo           = 4,  @nScn_LineNo         = 3983,
   @nStep_Lottable         = 5,  @nScn_Lottable       = 3990,
   @nStep_QTY              = 6,  @nScn_QTY            = 3985,
   @nStep_Message          = 7,  @nScn_Message        = 3986,
   @nStep_VerifySKU        = 8,  @nScn_VerifySKU      = 3951,
   @nStep_DataCapture      = 9,  @nScn_DataCapture    = 3987

-- Redirect to respective screen
IF @nFunc = 537
BEGIN
   IF @nStep = 0 GOTO Step_Start       -- Func = 537
   IF @nStep = 1 GOTO Step_ASN         -- Scn = 3980. ASN, PO
   IF @nStep = 2 GOTO Step_LOC         -- Scn = 3981. TO LOC
   IF @nStep = 3 GOTO Step_ID          -- Scn = 3982. TO ID
   IF @nStep = 4 GOTO Step_LineNo      -- Scn = 3983. Line no
   IF @nStep = 5 GOTO Step_Lottable    -- Scn = 3990. Dynamic lottable
   IF @nStep = 6 GOTO Step_QTY         -- Scn = 3985. QTY
   IF @nStep = 7 GOTO Step_Message     -- Scn = 3986. Message. Line received
   IF @nStep = 8 GOTO Step_VerifySKU   -- Scn = 3951. Verify SKU
   IF @nStep = 9 GOTO Step_DataCapture -- Scn = 3987. Data capture
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 537. Menu
********************************************************************************/
Step_Start:
BEGIN
   -- Get preferred UOM
   SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName

   -- Get storer config (THIS module support storer group, loading storer config is at ASN screen)
   SET @cPOKeyDefaultValue = rdt.RDTGetConfig( @nFunc, 'ReceivingPOKeyDefaultValue', @cStorerKey)
   IF @cPOKeyDefaultValue = '0'
      SET @cPOKeyDefaultValue = ''

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
   SET @cOutField01 = '' -- ASN
   SET @cOutField02 = @cPOKeyDefaultValue

   -- Set the entry point
   SET @nScn = @nScn_ASN
   SET @nStep = @nStep_ASN
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3980. ASN, PO screen
   ASN   (field01, input)
   PO    (field02, input)
********************************************************************************/
Step_ASN:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cReceiptKey = @cInField01
      SET @cPOKey = @cInField02

      -- Retain value
      SET @cOutField01 = @cInField01
      SET @cOutField02 = @cInField02

      -- Validate at least one field must key-in
      IF @cReceiptKey = '' AND @cPOKey IN ('', 'NOPO')
      BEGIN
         SET @nErrNo = 50851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ASN or PO
         GOTO Quit
      END

      DECLARE @cChkReceiptKey NVARCHAR( 10)
      DECLARE @cReceiptStatus NVARCHAR( 10)
      DECLARE @cChkStorerKey NVARCHAR( 15)
      DECLARE @nRowCount INT

      -- Both ASN & PO keyed-in
      IF @cReceiptKey <> '' AND @cPOKey NOT IN ('', 'NOPO')
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
            AND RD.POKey = CASE WHEN @cPOKey = 'NOPO' THEN RD.POKey ELSE @cPOKey END
         SET @nRowCount = @@ROWCOUNT

         IF @nRowCount = 0
         BEGIN
            -- Only ASN not exists
            IF NOT EXISTS (SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey)
            BEGIN
               SET @nErrNo = 50852
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN not exist
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN
               SET @cOutField01 = '' -- ASN
               GOTO Quit
            END

            -- Only PO not exists
            IF @cPOKey <> 'NOPO'
            BEGIN
               IF NOT EXISTS (SELECT 1
                  FROM dbo.Receipt R WITH (NOLOCK)
                     JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
                  WHERE R.ReceiptKey = @cReceiptKey
                     AND RD.POKey = @cPOKey)
               BEGIN
                  SET @nErrNo = 50853
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PO not exist
                  EXEC rdt.rdtSetFocusField @nMobile, 2 -- PO
                  SET @cOutField02 = '' -- PO
                  GOTO Quit
               END
            END
         END
      END
      ELSE
         -- Only ASN keyed-in
         IF @cReceiptKey <> ''
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
               -- We want non blank POKey to be assigned if multiple row returned
            ORDER BY RD.POKey
            SET @nRowCount = @@ROWCOUNT

            -- Check ASN valid
            IF @nRowCount < 1
            BEGIN
               SELECT
                   @cChkFacility = R.Facility,
                   @cChkStorerKey = R.StorerKey,
                   @cReceiptStatus = R.Status
               FROM dbo.Receipt R WITH (NOLOCK)
               WHERE R.ReceiptKey = @cReceiptKey

               SET @nRowCount = @@ROWCOUNT
               IF @nRowCount < 1
               BEGIN
                  SET @nErrNo = 50854
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN not exist
                  EXEC rdt.rdtSetFocusField @nMobile, 1
                  SET @cOutField01 = '' -- ASN
                  GOTO Quit
               END
            END

            -- Check multi POKey, but not specify which
            IF @nRowCount > 1 AND @cPOKey <> 'NOPO'
            BEGIN
               SET @nErrNo = 50855
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi POInASN
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- PO
               -- SET @cOutField01 = '' -- ASN
               GOTO Quit
            END

            -- Auto default POKey, if only 1 POKey
            IF @nRowCount = 1 AND @cPOKey <> 'NOPO'
               SET @cPOKey = @cChkPOKey
         END
         ELSE
            -- Only PO keyed-in
            IF @cPOKey NOT IN ('', 'NOPO')
            BEGIN
               -- Validate whether PO have multiple ASN
               SELECT DISTINCT
                  @cChkFacility = R.Facility,
                  @cChkStorerKey = R.StorerKey,
                  @cReceiptKey = R.ReceiptKey,
                  @cReceiptStatus = R.Status
               FROM dbo.Receipt R WITH (NOLOCK)
                  INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey  = RD.ReceiptKey)
               WHERE RD.POKey = @cPOKey
                  AND RD.StorerKey = @cStorerKey

               SET @nRowCount = @@ROWCOUNT
               IF @nRowCount < 1
               BEGIN
                  SET @nErrNo = 50856
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PO not exist
                  EXEC rdt.rdtSetFocusField @nMobile, 2 -- PO
                  SET @cOutField02 = '' -- PO
                  GOTO Quit
               END

               IF @nRowCount > 1
               BEGIN
                  SET @nErrNo = 50857
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi ASNInPO
                  EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN
                  -- SET @cOutField02 = '' -- PO
                  GOTO Quit
               END
            END

      -- Validate ASN in different facility
      IF @cFacility <> @cChkFacility
      BEGIN
         SET @nErrNo = 50858
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
            SET @nErrNo = 50878
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
         SET @nErrNo = 50859
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN
         SET @cOutField01 = '' -- ASN
         GOTO Quit
      END

      -- Get storer config
      SET @cDataCapture = rdt.RDTGetConfig( @nFunc, 'DataCapture', @cStorerKey)
      SET @cPalletRecv = rdt.RDTGetConfig( @nFunc, 'PalletRecv', @cStorerKey)
      SET @cVerifySKU = rdt.RDTGetConfig( @nFunc, 'VerifySKU', @cStorerKey)

      SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
      IF @cDecodeSP = '0'
         SET @cDecodeSP = ''
      SET @cDefaultToLoc = rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorerKey)
      IF @cDefaultToLoc = '0'
         SET @cDefaultToLoc = ''
      SET @cRcptConfirmSP = rdt.RDTGetConfig( @nFunc, 'ReceiptConfirmSP', @cStorerKey)
      IF @cRcptConfirmSP = '0'
         SET @cRcptConfirmSP = ''
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''
      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      -- Validate ASN status
      IF @cReceiptStatus = '9'
      BEGIN
         SET @nErrNo = 50860
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN is closed
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN
         SET @cOutField01 = '' -- ASN
         GOTO Quit
      END

      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cDefaultToLoc

      -- Go to LOC screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     -- EventLog
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

      SET @cOutField01 = ''
   END
END
GOTO Quit


/********************************************************************************
Step LOC. Scn = 3981. Location screen
   ASN      (field01)
   PO       (field02)
   TO LOC   (field03, input)
********************************************************************************/
Step_LOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField03 -- LOC

      -- Validate compulsary field
      IF @cLOC = '' OR @cLOC IS NULL
      BEGIN
         SET @nErrNo = 50861
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOC
         GOTO Step_LOC_Fail
      END

      -- Get the location
      DECLARE @cChkLOC NVARCHAR( 10)
      SELECT
         @cChkLOC = LOC,
         @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cLOC

      -- Validate location
      IF @cChkLOC IS NULL OR @cChkLOC = ''
      BEGIN
         SET @nErrNo = 50862
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         GOTO Step_LOC_Fail
      END

      -- Validate location not in facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 50863
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC not in FAC
         GOTO Step_LOC_Fail
      END

      -- Init next screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = '' -- ID

      -- Go to ID screen
      SET @nScn  = @nScn_ID
      SET @nStep = @nStep_ID
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey

      -- Go to ASN screen
      SET @nScn = @nScn_ASN
      SET @nStep = @nStep_ASN
   END
   GOTO Quit

   Step_LOC_Fail:
   BEGIN
      SET @cOutField03 = '' -- LOC
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 3982. Pallet ID screen
   TO LOC   (field01)
   TO ID    (field02, input)
********************************************************************************/
Step_ID:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cID = @cInField02 -- ID

      -- Check format valid
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cID) = 0
      BEGIN
         SET @nErrNo = 50879
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_ID_Fail
      END

      IF @cID <> ''
      BEGIN
         DECLARE @cAuthority NVARCHAR(1)
         EXECUTE nspGetRight
            @cFacility,
            @cStorerKey,
            NULL, -- @cSKU
            'DisAllowDuplicateIdsOnRFRcpt',
            @bSuccess    OUTPUT,
            @cAuthority  OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT

         -- Check ID in used
         IF @cAuthority = '1'
         BEGIN
            IF EXISTS( SELECT TOP 1 1
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
               WHERE LOC.Facility = @cFacility
                  AND ID = @cID
                  AND QTY-QTYPicked > 0)
            BEGIN
               SET @nErrNo = 50864
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToID in used
               GOTO Step_ID_Fail
            END
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, @cLOC, @cID, @cSKU, @nQTY, @cReasonCode, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cReceiptKey     NVARCHAR( 10), ' +
               '@cPOKey          NVARCHAR( 10), ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cID             NVARCHAR( 30), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cReasonCode     NVARCHAR( 10), ' +
               '@cLottable01     NVARCHAR( 18), ' +
               '@cLottable02     NVARCHAR( 18), ' +
               '@cLottable03     NVARCHAR( 18), ' +
               '@dLottable04     DATETIME,      ' +
               '@dLottable05     DATETIME,      ' +
               '@cLottable06     NVARCHAR( 30), ' +
               '@cLottable07     NVARCHAR( 30), ' +
               '@cLottable08     NVARCHAR( 30), ' +
               '@cLottable09     NVARCHAR( 30), ' +
               '@cLottable10     NVARCHAR( 30), ' +
               '@cLottable11     NVARCHAR( 30), ' +
               '@cLottable12     NVARCHAR( 30), ' +
               '@dLottable13     DATETIME,      ' +
               '@dLottable14     DATETIME,      ' +
               '@dLottable15     DATETIME,      ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, @cLOC, @cID, @cSKU, @nQTY, @cReasonCode,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_ID_Fail
         END
      END

      -- Init next screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = '' -- LineNo

      -- Go to line no screen
      SET @nScn  = @nScn_LineNo
      SET @nStep = @nStep_LineNo
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cLOC

      -- Go to LOC screen
      SET @nScn = @nScn_LOC
      SET @nStep = @nStep_LOC
   END
   GOTO Quit

   Step_ID_Fail:
   BEGIN
      SET @cOutField02 = '' -- ID
   END
END
GOTO Quit


/********************************************************************************
Step 4. Scn = 3983. LineNo screen
   TO ID    (field01)
   LINE NO  (field02, input)
********************************************************************************/
Step_LineNo:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLineNo = @cInField02 -- LineNo

      -- Check blank
      IF @cLineNo = ''
      BEGIN
         SET @nErrNo = 50865
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LineNo
         GOTO Step_LineNo_Fail
      END

      -- Check line no format
      IF RDT.rdtIsValidQTY( @cLineNo, 1) = 0
      BEGIN
         SET @nErrNo = 50866
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LineNo
         GOTO Step_LineNo_Fail
      END

      -- Pad with zero
      SET @cLineNo = RIGHT( '00000' + CAST( @cLineNo AS NVARCHAR(5)), 5)

      -- Get ReceiptDetail info
      SELECT
         @cSKU = SKU,
         @cLottable01 = Lottable01,
         @cLottable02 = Lottable02,
         @cLottable03 = Lottable03,
         @dLottable04 = Lottable04,
         @dLottable05 = Lottable05,
         @cLottable06 = Lottable06,
         @cLottable07 = Lottable07,
         @cLottable08 = Lottable08,
         @cLottable09 = Lottable09,
         @cLottable10 = Lottable10,
         @cLottable11 = Lottable11,
         @cLottable12 = Lottable12,
         @dLottable13 = Lottable13,
         @dLottable14 = Lottable14,
         @dLottable15 = Lottable15
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND ReceiptLineNumber = @cLineNo

      -- Check LineNo valid
      IF @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 50867
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Line not exist
         GOTO Step_LineNo_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, @cLOC, @cID, @cSKU, @nQTY, @cReasonCode, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cReceiptKey     NVARCHAR( 10), ' +
               '@cPOKey          NVARCHAR( 10), ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cID             NVARCHAR( 30), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cReasonCode     NVARCHAR( 10), ' +
               '@cLottable01     NVARCHAR( 18), ' +
               '@cLottable02     NVARCHAR( 18), ' +
               '@cLottable03     NVARCHAR( 18), ' +
               '@dLottable04     DATETIME,      ' +
               '@dLottable05     DATETIME,      ' +
               '@cLottable06     NVARCHAR( 30), ' +
               '@cLottable07     NVARCHAR( 30), ' +
               '@cLottable08     NVARCHAR( 30), ' +
               '@cLottable09     NVARCHAR( 30), ' +
               '@cLottable10     NVARCHAR( 30), ' +
               '@cLottable11     NVARCHAR( 30), ' +
               '@cLottable12     NVARCHAR( 30), ' +
               '@dLottable13     DATETIME,      ' +
               '@dLottable14     DATETIME,      ' +
               '@dLottable15     DATETIME,      ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, @cLOC, @cID, @cSKU, @nQTY, @cReasonCode,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_LineNo_Fail
         END
      END

      -- Get SKU info
      SELECT
         @cSKUDesc = Descr,
         @cIVAS = ISNULL( IVAS, ''),
         @cLottableCode = LottableCode
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Get Pack info
      SELECT
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
            @nPUOM_Div = CAST( ISNULL(
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
            SET @nScn = @nScn_VerifySKU
            SET @nStep = @nStep_VerifySKU

            GOTO Quit
         END
      END

      -- Data capture
      IF @cDataCapture = '1'
      BEGIN
         SET @cBarcode = ''
         
         -- Go to data capture screen
         SET @nScn = @nScn_DataCapture
         SET @nStep = @nStep_DataCapture
         
         GOTO Quit
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
            SET @cFieldAttr08 = 'O' -- @nPQTY
         END
         ELSE
         BEGIN
            SET @cFieldAttr08 = ''  -- @nPQTY
         END

         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
         SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
         SET @cOutField04 = @cIVAS
         SET @cOutField05 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = @cMUOM_Desc
         SET @cOutField08 = '' -- @nPQTY
         SET @cOutField09 = '' -- @nMQTY
         SET @cOutField10 = '' -- Reason

         -- Go to QTY screen
         SET @nScn = @nScn_QTY
         SET @nStep = @nStep_QTY
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cLOC
      SET @cOutField02 = '' -- ID

      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID
   END
   GOTO Quit

   Step_LineNo_Fail:
   BEGIN
      SET @cOutField02 = '' -- @cID
   END
END
GOTO Quit


/********************************************************************************
Step 5. scn = 3990. Dynamic lottables
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
         SET @cFieldAttr08 = 'O' -- @nPQTY
      END
      ELSE
      BEGIN
         SET @cFieldAttr08 = ''  -- @nPQTY
      END

      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField04 = @cIVAS
      SET @cOutField05 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      SET @cOutField06 = @cPUOM_Desc
      SET @cOutField07 = @cMUOM_Desc
      SET @cOutField08 = '' -- @nPQTY
      SET @cOutField09 = '' -- @nMQTY
      SET @cOutField10 = '' -- Reason

      -- Go to QTY screen
      SET @nScn = @nScn_QTY
      SET @nStep = @nStep_QTY
   END

   IF @nInputKey = 0 -- ESC
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

      IF @nMorePage = 1 -- Yes
         GOTO Quit

      -- Enable field
      SET @cFieldAttr02 = '' -- Dynamic lottable 1..5
      SET @cFieldAttr04 = '' --
      SET @cFieldAttr06 = '' --
      SET @cFieldAttr08 = '' --
      SET @cFieldAttr10 = '' --

      -- Prepare prev screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = '' -- LineNo

      -- Go line no screen
      SET @nScn = @nScn_LineNo
      SET @nStep = @nStep_LineNo
   END
END
GOTO Quit


/********************************************************************************
Step 6. Scn = 3985. QTY screen
   SKU       (field01)
   SKU desc1 (field02)
   SKU desc1 (field03)
   IVAS      (field04)
   Ratio     (field05)
   PUOM      (Field06)
   MUOM      (Field07)
   PQTY      (Field08, input)
   MQTY      (Field09, input)
   Reason    (field10, input)
********************************************************************************/
Step_QTY:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cPQTY    NVARCHAR(5)
      DECLARE @cMQTY    NVARCHAR(5)
      DECLARE @nPQTY    INT
      DECLARE @nMQTY    INT

      -- Screen mapping
      SET @cPQTY = CASE WHEN @cFieldAttr08 = 'O' THEN @cOutField08 ELSE @cInField08 END
      SET @cMQTY = CASE WHEN @cFieldAttr09 = 'O' THEN @cOutField09 ELSE @cInField09 END
      SET @cReasonCode = @cInField10

      -- Retain value
      SET @cOutField08 = CASE WHEN @cFieldAttr08 = 'O' THEN @cOutField08 ELSE @cInField08 END -- PQTY
      SET @cOutField09 = CASE WHEN @cFieldAttr09 = 'O' THEN @cOutField09 ELSE @cInField09 END -- MQTY

      -- Check PQTY
      IF @cPQTY <> '' AND RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 50874
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY
         GOTO Quit
      END
      SET @nPQTY = CAST( @cPQTY AS INT)

      -- Check MQTY
      IF @cMQTY <> '' AND RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 50875
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 9 -- MQTY
         GOTO Quit
      END
      SET @nMQTY = CAST( @cMQTY AS INT)

      -- Calc total QTY in master UOM
      SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nQTY = @nQTY + @nMQTY

      -- Check QTY
      IF @nQTY = 0
      BEGIN
         SET @nErrNo = 50876
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         GOTO Quit
      END

      IF ISNULL(rdt.RDTGetConfig( @nFunc, 'CONDCODECHECKSTORER', @cStorerKey),'0') = '1'
      AND @cReasonCode <> '' AND @cReasonCode IS NOT NULL
      BEGIN
         IF NOT EXISTS( SELECT Code
            FROM dbo.CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'ASNREASON'
               AND Storerkey = @cStorerkey
               AND Code = @cReasonCode)
         BEGIN
            SET @nErrNo = 50877
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad ReasonCode
            SET @cReasonCode = ''
            EXEC rdt.rdtSetFocusField @nMobile, 10
            GOTO Quit
         END
      END
      -- Validate reason code exists
      ELSE IF @cReasonCode <> '' AND @cReasonCode IS NOT NULL
         IF NOT EXISTS( SELECT Code
            FROM dbo.CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'ASNREASON'
               AND Code = @cReasonCode)
         BEGIN
            SET @nErrNo = 50877
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad ReasonCode
            SET @cReasonCode = ''
            EXEC rdt.rdtSetFocusField @nMobile, 10
            GOTO Quit
         END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, @cLOC, @cID, @cSKU, @nQTY, @cReasonCode, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cReceiptKey     NVARCHAR( 10), ' +
               '@cPOKey          NVARCHAR( 10), ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cID             NVARCHAR( 30), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cReasonCode     NVARCHAR( 10), ' +
               '@cLottable01     NVARCHAR( 18), ' +
               '@cLottable02     NVARCHAR( 18), ' +
               '@cLottable03     NVARCHAR( 18), ' +
               '@dLottable04     DATETIME,      ' +
               '@dLottable05     DATETIME,      ' +
               '@cLottable06     NVARCHAR( 30), ' +
               '@cLottable07     NVARCHAR( 30), ' +
               '@cLottable08     NVARCHAR( 30), ' +
               '@cLottable09     NVARCHAR( 30), ' +
               '@cLottable10     NVARCHAR( 30), ' +
               '@cLottable11     NVARCHAR( 30), ' +
               '@cLottable12     NVARCHAR( 30), ' +
               '@dLottable13     DATETIME,      ' +
               '@dLottable14     DATETIME,      ' +
               '@dLottable15     DATETIME,      ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, @cLOC, @cID, @cSKU, @nQTY, @cReasonCode,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Get UOM
      DECLARE @cUOM NVARCHAR(10)
      SELECT @cUOM = PackUOM3
      FROM dbo.SKU WITH (NOLOCK)
         JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- NOPO flag
      DECLARE @nNOPOFlag INT
      SET @nNOPOFlag = CASE WHEN @cPOkey = 'NOPO' THEN 1 ELSE 0 END

      -- Reason code
      IF @cReasonCode = ''
         SET @cReasonCode = 'OK'

      -- Custom receiving logic
      IF @cRcptConfirmSP <> '' AND
         EXISTS( SELECT 1 FROM sys.objects WHERE name = @cRcptConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cRcptConfirmSP) +
            ' @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, @cToLOC, @cToID, ' +
            ' @cSKUCode, @cSKUUOM, @nSKUQTY, @cUCC, @cUCCSKU, @nUCCQTY, @cCreateUCC, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @nNOPOFlag, @cConditionCode, @cSubreasonCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cReceiptLineNumberOutput OUTPUT '

         SET @cSQLParam =
            '@nFunc          INT,            ' +
            '@nMobile        INT,            ' +
            '@cLangCode      NVARCHAR( 3),   ' +
            '@cStorerKey     NVARCHAR( 15),  ' +
            '@cFacility      NVARCHAR( 5),   ' +
            '@cReceiptKey    NVARCHAR( 10),  ' +
            '@cPOKey         NVARCHAR( 10),  ' +
            '@cToLOC         NVARCHAR( 10),  ' +
            '@cToID          NVARCHAR( 18),  ' +
            '@cSKUCode       NVARCHAR( 20),  ' +
            '@cSKUUOM        NVARCHAR( 10),  ' +
            '@nSKUQTY        INT,            ' +
            '@cUCC           NVARCHAR( 20),  ' +
            '@cUCCSKU        NVARCHAR( 20),  ' +
            '@nUCCQTY        INT,            ' +
            '@cCreateUCC     NVARCHAR( 1),   ' +
            '@cLottable01    NVARCHAR( 18),  ' +
            '@cLottable02    NVARCHAR( 18),  ' +
            '@cLottable03    NVARCHAR( 18),  ' +
            '@dLottable04    DATETIME,       ' +
            '@dLottable05    DATETIME,       ' +
            '@cLottable06    NVARCHAR( 30),  ' +
            '@cLottable07    NVARCHAR( 30),  ' +
            '@cLottable08    NVARCHAR( 30),  ' +
            '@cLottable09    NVARCHAR( 30),  ' +
            '@cLottable10    NVARCHAR( 30),  ' +
            '@cLottable11    NVARCHAR( 30),  ' +
            '@cLottable12    NVARCHAR( 30),  ' +
            '@dLottable13    DATETIME,       ' +
            '@dLottable14    DATETIME,       ' +
            '@dLottable15    DATETIME,       ' +
            '@nNOPOFlag      INT,            ' +
            '@cConditionCode NVARCHAR( 10),  ' +
            '@cSubreasonCode NVARCHAR( 10),  ' +
            '@nErrNo         INT           OUTPUT, ' +
            '@cErrMsg        NVARCHAR( 20) OUTPUT, ' +
            '@cReceiptLineNumberOutput NVARCHAR( 5) OUTPUT '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, @cLOC, @cID,
            @cSKU, @cUOM, @nQTY, '', '', 0, '',
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nNOPOFlag, @cReasonCode, '', @nErrNo OUTPUT, @cErrMsg OUTPUT, @cReceiptLineNumber OUTPUT
      END
      ELSE
      BEGIN
         -- Receive
         EXEC rdt.rdt_Receive_V7
            @nFunc         = @nFunc,
            @nMobile       = @nMobile,
            @cLangCode     = @cLangCode,
            @nErrNo        = @nErrNo OUTPUT,
            @cErrMsg       = @cErrMsg OUTPUT,
            @cStorerKey    = @cStorerKey,
            @cFacility     = @cFacility,
            @cReceiptKey   = @cReceiptKey,
            @cPOKey        = @cPoKey,  -- (ChewKP01)
            @cToLOC        = @cLOC,
            @cToID         = @cID,
            @cSKUCode      = @cSKU,
            @cSKUUOM       = @cUOM,
            @nSKUQTY       = @nQTY,
            @cUCC          = '',
            @cUCCSKU       = '',
            @nUCCQTY       = '',
            @cCreateUCC    = '',
            @cLottable01   = @cLottable01,
            @cLottable02   = @cLottable02,
            @cLottable03   = @cLottable03,
            @dLottable04   = @dLottable04,
            @dLottable05   = @dLottable05,
            @cLottable06   = @cLottable06,
            @cLottable07   = @cLottable07,
            @cLottable08   = @cLottable08,
            @cLottable09   = @cLottable09,
            @cLottable10   = @cLottable10,
            @cLottable11   = @cLottable11,
            @cLottable12   = @cLottable12,
            @dLottable13   = @dLottable13,
            @dLottable14   = @dLottable14,
            @dLottable15   = @dLottable15,
            @nNOPOFlag     = @nNOPOFlag,
            @cConditionCode = @cReasonCode,
            @cSubreasonCode = '',
            @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT
      END

      IF @nErrNo <> 0
         GOTO Quit

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, @cLOC, @cID, @cSKU, @nQTY, @cReasonCode, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cReceiptLineNumber, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cPOKey       NVARCHAR( 10), ' +
               '@cLOC         NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@nQTY         INT,           ' +
               '@cReasonCode  NVARCHAR( 10), ' +
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
               '@cReceiptLineNumber NVARCHAR( 5),    ' +
               '@nErrNo       INT            OUTPUT, ' +
               '@cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, @cID, @cSKU, @nQTY, @cReasonCode,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cReceiptLineNumber, @nErrNo OUTPUT, @cErrMsg OUTPUT
         END
      END

      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '2', -- Receiving
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerKey,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = @cPOKey,
         @cLocation     = @cLOC,
         @cID           = @cID,
         @cSKU          = @cSKU,
         @cUOM          = @cUOM,
         @nQTY          = @nQTY,
         @cReasonKey    = @cReasonCode,
         --@cRefNo4       = @cReasonCode,
         @cLottable01   = @cLottable01,
         @cLottable02   = @cLottable02,
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
         @dLottable05   = @dLottable05,
         @cLottable06   = @cLottable06,
         @cLottable07   = @cLottable07,
         @cLottable08   = @cLottable08,
         @cLottable09   = @cLottable09,
         @cLottable10   = @cLottable10,
         @cLottable11   = @cLottable11,
         @cLottable12   = @cLottable12,
         @dLottable13   = @dLottable13,
         @dLottable14   = @dLottable14,
         @dLottable15   = @dLottable15,
         @nStep         = @nStep

      -- Go to message screen
      SET @nScn = @nScn_Message
      SET @nStep = @nStep_Message
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

         -- Prep prev screen var
         SET @cOutField01 = @cID
         SET @cOutField02 = '' -- LineNo

         -- Go to line no screen
         SET @nScn = @nScn_LineNo
         SET @nStep = @nStep_LineNo
      END
   END
END
GOTO Quit


/********************************************************************************
Step 7. Scn = 3986. Message screen
********************************************************************************/
Step_Message:
BEGIN
   IF @cPalletRecv = '1'
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = '' -- @cID

      -- Go back to ID screen
      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID
   END
   ELSE
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = '' -- @cLineNo

      -- Go back to LineNo screen
      SET @nScn = @nScn_LineNo
      SET @nStep = @nStep_LineNo
   END
END
GOTO Quit


/********************************************************************************
Step 8. Screen = 3950. Verify SKU
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
      SET @cFieldAttr04 = '' -- Dynamic verify SKU 1..5
      SET @cFieldAttr05 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr07 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr10 = ''
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''

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
            SET @cFieldAttr08 = 'O' -- @nPQTY
         END
         ELSE
         BEGIN
            SET @cFieldAttr08 = ''  -- @nPQTY
         END

         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
         SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
         SET @cOutField04 = @cIVAS
         SET @cOutField05 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = @cMUOM_Desc
         SET @cOutField08 = '' -- @nPQTY
         SET @cOutField09 = '' -- @nMQTY
         SET @cOutField10 = '' -- Reason

         -- Go to QTY screen
         SET @nScn = @nScn_QTY
         SET @nStep = @nStep_QTY
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Enable field
      SET @cFieldAttr04 = '' -- Dynamic verify SKU 1..5
      SET @cFieldAttr05 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr07 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr10 = ''
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''

      -- Prepare prev screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = '' -- Line no

      -- Go to line no screen
      SET @nScn = @nScn_LineNo
      SET @nStep = @nStep_LineNo
   END
END
GOTO Quit


/********************************************************************************
Scn = 3986. Data capture
   DATA    (field01, input)
********************************************************************************/
Step_DataCapture:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Standard decode
      IF @cDecodeSP = '1'
      BEGIN
         EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
            @cLottable01 = @cLottable01 OUTPUT,
            @cLottable02 = @cLottable02 OUTPUT,
            @cLottable03 = @cLottable03 OUTPUT,
            @dLottable04 = @dLottable04 OUTPUT,
            @dLottable05 = @dLottable05 OUTPUT,
            @cLottable06 = @cLottable06 OUTPUT,
            @cLottable07 = @cLottable07 OUTPUT,
            @cLottable08 = @cLottable08 OUTPUT,
            @cLottable09 = @cLottable09 OUTPUT,
            @cLottable10 = @cLottable10 OUTPUT,
            @cLottable11 = @cLottable11 OUTPUT,
            @cLottable12 = @cLottable12 OUTPUT,
            @dLottable13 = @dLottable13 OUTPUT,
            @dLottable14 = @dLottable14 OUTPUT,
            @dLottable15 = @dLottable15 OUTPUT,
            -- @nErrNo   = @nErrNo      OUTPUT,
            -- @cErrMsg  = @cErrMsg     OUTPUT,
            @cType       = 'DATA'
      END
      ELSE
      BEGIN
         IF @cDecodeSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, @cBarcode, ' +
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID OUTPUT, ' + 
                  ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' + 
                  ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' + 
                  ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT  '
               SET @cSQLParam =
                  ' @nMobile      INT,             ' +
                  ' @nFunc        INT,             ' +
                  ' @cLangCode    NVARCHAR( 3),    ' +
                  ' @nStep        INT,             ' +
                  ' @nInputKey    INT,             ' +
                  ' @cFacility    NVARCHAR( 5),    ' +
                  ' @cStorerKey   NVARCHAR( 15),   ' +
                  ' @cReceiptKey  NVARCHAR( 10),   ' +
                  ' @cPOKey       NVARCHAR( 10),   ' +
                  ' @cLOC         NVARCHAR( 10),   ' +
                  ' @cBarcode     NVARCHAR( MAX),  ' +
                  ' @nErrNo       INT            OUTPUT, ' +
                  ' @cErrMsg      NVARCHAR( 20)  OUTPUT, ' +
                  ' @cID          NVARCHAR( 18) = '''' OUTPUT, ' + 
                  ' @cLottable01  NVARCHAR( 18) = '''' OUTPUT, ' + 
                  ' @cLottable02  NVARCHAR( 18) = '''' OUTPUT, ' + 
                  ' @cLottable03  NVARCHAR( 18) = '''' OUTPUT, ' + 
                  ' @dLottable04  DATETIME      = NULL OUTPUT, ' + 
                  ' @dLottable05  DATETIME      = NULL OUTPUT, ' + 
                  ' @cLottable06  NVARCHAR( 30) = '''' OUTPUT, ' + 
                  ' @cLottable07  NVARCHAR( 30) = '''' OUTPUT, ' + 
                  ' @cLottable08  NVARCHAR( 30) = '''' OUTPUT, ' + 
                  ' @cLottable09  NVARCHAR( 30) = '''' OUTPUT, ' + 
                  ' @cLottable10  NVARCHAR( 30) = '''' OUTPUT, ' + 
                  ' @cLottable11  NVARCHAR( 30) = '''' OUTPUT, ' + 
                  ' @cLottable12  NVARCHAR( 30) = '''' OUTPUT, ' + 
                  ' @dLottable13  DATETIME      = NULL OUTPUT, ' + 
                  ' @dLottable14  DATETIME      = NULL OUTPUT, ' + 
                  ' @dLottable15  DATETIME      = NULL OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, @cBarcode,
                  @nErrNo      = @nErrNo      OUTPUT, 
                  @cErrMsg     = @cErrMsg     OUTPUT, 
                  @cLottable01 = @cLottable01 OUTPUT,
                  @cLottable02 = @cLottable02 OUTPUT,
                  @cLottable03 = @cLottable03 OUTPUT,
                  @dLottable04 = @dLottable04 OUTPUT,
                  @dLottable05 = @dLottable05 OUTPUT,
                  @cLottable06 = @cLottable06 OUTPUT,
                  @cLottable07 = @cLottable07 OUTPUT,
                  @cLottable08 = @cLottable08 OUTPUT,
                  @cLottable09 = @cLottable09 OUTPUT,
                  @cLottable10 = @cLottable10 OUTPUT,
                  @cLottable11 = @cLottable11 OUTPUT,
                  @cLottable12 = @cLottable12 OUTPUT,
                  @dLottable13 = @dLottable13 OUTPUT,
                  @dLottable14 = @dLottable14 OUTPUT,
                  @dLottable15 = @dLottable15 OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_DataCapture_Fail
            END
         END
      END
      
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, @cLOC, @cID, @cSKU, @nQTY, @cReasonCode, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cReceiptKey     NVARCHAR( 10), ' +
               '@cPOKey          NVARCHAR( 10), ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cID             NVARCHAR( 30), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cReasonCode     NVARCHAR( 10), ' +
               '@cLottable01     NVARCHAR( 18), ' +
               '@cLottable02     NVARCHAR( 18), ' +
               '@cLottable03     NVARCHAR( 18), ' +
               '@dLottable04     DATETIME,      ' +
               '@dLottable05     DATETIME,      ' +
               '@cLottable06     NVARCHAR( 30), ' +
               '@cLottable07     NVARCHAR( 30), ' +
               '@cLottable08     NVARCHAR( 30), ' +
               '@cLottable09     NVARCHAR( 30), ' +
               '@cLottable10     NVARCHAR( 30), ' +
               '@cLottable11     NVARCHAR( 30), ' +
               '@cLottable12     NVARCHAR( 30), ' +
               '@dLottable13     DATETIME,      ' +
               '@dLottable14     DATETIME,      ' +
               '@dLottable15     DATETIME,      ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, @cLOC, @cID, @cSKU, @nQTY, @cReasonCode,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_DataCapture_Fail
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
            SET @cFieldAttr08 = 'O' -- @nPQTY
         END
         ELSE
         BEGIN
            SET @cFieldAttr08 = ''  -- @nPQTY
         END

         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
         SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
         SET @cOutField04 = @cIVAS
         SET @cOutField05 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = @cMUOM_Desc
         SET @cOutField08 = '' -- @nPQTY
         SET @cOutField09 = '' -- @nMQTY
         SET @cOutField10 = '' -- Reason

         -- Go to QTY screen
         SET @nScn = @nScn_QTY
         SET @nStep = @nStep_QTY
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = '' -- LineNo

      -- Go line no screen
      SET @nScn = @nScn_LineNo
      SET @nStep = @nStep_LineNo
   END
   GOTO Quit
   
   Step_DataCapture_Fail:
      SET @cBarcode = ''
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      V_StorerKey  = @cStorerKey,
      V_ReceiptKey = @cReceiptKey,
      V_POKey      = @cPOKey,
      V_Loc        = @cLOC,
      V_SKU        = @cSKU,
      V_UOM        = @cPUOM,
      V_ID         = @cID,
      V_QTY        = @nQTY,
      V_SKUDescr   = @cSKUDesc,
      V_Barcode    = @cBarcode, 

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

      V_PUOM_Div   = @nPUOM_Div,

      V_String1  = @cLineNo,
      V_String2  = @cIVAS,
      V_String4  = @cPUOM_Desc,
      V_String5  = @cMUOM_Desc,
      --V_String6  = @nPUOM_Div,
      V_String7  = @cLottableCode,
      V_String8  = @cReasonCode,

      V_String10 = @cPOKeyDefaultValue ,
      V_String11 = @cDefaultToLoc,
      V_String12 = @cExtendedValidateSP,
      V_String13 = @cRcptConfirmSP,
      V_String14 = @cPalletRecv,
      V_String15 = @cExtendedUpdateSP,
      V_String16 = @cVerifySKU,
      V_String17 = @cDecodeSP,
      V_String18 = @cDataCapture,

      I_Field01 = '',  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,
      I_Field02 = '',  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,
      I_Field03 = '',  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,
      I_Field04 = '',  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,
      I_Field05 = '',  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,
      I_Field06 = '',  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,
      I_Field07 = '',  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,
      I_Field08 = '',  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08,
      I_Field09 = '',  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,
      I_Field10 = '',  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,
      I_Field11 = '',  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,
      I_Field12 = '',  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,
      I_Field13 = '',  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,
      I_Field14 = '',  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,
      I_Field15 = '',  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile
END

GO