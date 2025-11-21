SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/*********************************************************************************/
/* Store procedure: rdtfnc_ConReceive                                            */
/* Copyright      : LFLogistics                                                  */
/*                                                                               */
/* Purpose: Container receive across multiple ASN                                */
/*                                                                               */
/* Date       Rev  Author   Purposes                                             */
/* 2015-08-23 1.0  Ung      SOS347636 Migrated from 600                          */
/* 2016-09-30 1.1  Ung      Performance tuning                                   */
/* 2017-06-16 1.2  Ung      WMS-2231 Add AutoGenID SP                            */
/* 2017-06-22 1.3  Ung      WMS-2230 Add sub reason                              */
/* 2019-06-24 1.4  James    WMS-9426 Add clear ExtendedInfo var @screen3(james01)*/
/* 2019-07-19 1.5  SPChin   INC0782771 - Set Initial value of @cPalletRecv       */
/* 2020-05-08 1.6  James    WMS-12559 Add default to loc (james02)               */
/* 2020-07-17 1.7  Chermaine  WMS-14193 Add MultiSKUConfig (cc01)                */
/* 2021-01-15 1.8  James    INC1406611 Bug fix on retrieve default toloc(james03)*/
/* 2021-06-18 1.9  James    WMS-17264 Enable piece receive (james04)             */
/*                          Add ExtendedInfoSP to step 7                         */
/*                          Add ExtendedUpdateSP to stp 3                        */
/* 2021-06-16 1.9  Chermain WMS-17244 Change RefNolookup as exec sp,             */
/*                          SET @cDefaultToLOC = @cReceiveDefaultToLoc           */
/*                          Add config @cGotoUCCIDScn                            */
/*                          Add UCCID step_13 (cc02)                             */
/* 2022-07-19 2.0  Ung      WMS-20246 Add standard Decode                        */
/* 2023-03-28 2.1  James    JSM-138949 - Bug fix on MultiSKUBarcode (james05)    */
/* 2024-04-19 2.2  Dennis   UWP-18504 Condition Code Enhancements                */
/*********************************************************************************/

CREATE   PROCEDURE [RDT].[rdtfnc_ConReceive] (
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
   @b_Success      INT,
   @n_Err          INT,
   @c_ErrMsg       NVARCHAR( 250),

   @cChkFacility   NVARCHAR( 5),
   @cChkLOC        NVARCHAR( 10),
   @nMorePage      INT,
   @cBarcode       NVARCHAR( 60),
   @cOption        NVARCHAR( 1),
   @cSQL           NVARCHAR( MAX),
   @cSQLParam      NVARCHAR( MAX),
   @cAutoID        NVARCHAR( 18),
   @nRowRef        INT,
   @curCR          CURSOR

-- Session variable
DECLARE
   @nFunc        INT,
   @nScn         INT,
   @nStep        INT,
   @cLangCode    NVARCHAR( 3),
   @nInputKey    INT,
   @nMenu        INT,
   @cUserName    NVARCHAR( 18),
   @cPrinter     NVARCHAR( 10),
   @cStorerGroup NVARCHAR( 20),
   @cStorerKey   NVARCHAR( 15),
   @cFacility    NVARCHAR( 5),

   @cPUOM        NVARCHAR(  1),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 20),
   @cID          NVARCHAR( 18),
   @cSKU         NVARCHAR( 20),
   @cMultiSKU    NVARCHAR( 20),     --(cc01)
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

   @cRefNo              NVARCHAR( 20),
   @cIVAS               NVARCHAR( 20),
   @cLottableCode       NVARCHAR( 30),
   @cReasonCode         NVARCHAR( 10),
   @cSuggToLOC          NVARCHAR( 10),
   @cFinalLOC           NVARCHAR( 10),
   @cReceiptLineNumber  NVARCHAR( 5),
   @cPalletRecv         NVARCHAR( 1),
   @cSubreasonCode      NVARCHAR( 10),

   @cPUOM_Desc          NCHAR( 5),
   @cMUOM_Desc          NCHAR( 5),
   @nPUOM_Div           INT,
   @nPQTY               INT,
   @nMQTY               INT,
   @nQTY                INT,
   @nFromScn            INT,
   @nPABookingKey       INT,

   @cColumnName         NVARCHAR( 20),
   @cDefaultToLOC       NVARCHAR( 20),
   @cCheckPLTID         NVARCHAR( 1),
   @cAutoGenID          NVARCHAR( 20),
   @cGetReceiveInfoSP   NVARCHAR( 20),
   @cDecodeSP           NVARCHAR( 20),
   @cAddSKUtoASN        NVARCHAR( 1),
   @cVerifySKU          NVARCHAR( 1),
   @cPalletRecvSP       NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cRcptConfirmSP      NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cPutawaySP          NVARCHAR( 20),
   @cPutaway            NVARCHAR( 1),
   @tDefaultToLOC       VARIABLETABLE,
   @cMultiSKUBarcode    NVARCHAR(1), --(cc01)
   @cReceiveDefaultToLoc   NVARCHAR( 20),
   @cDefaultReceiveQty  NVARCHAR( 10),
   @cFlowThruQtyScreen  NVARCHAR( 1),
   @cDataType           NVARCHAR(128),
   @cGotoUccIDScn       NVARCHAR(1), --(cc02)

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

-- Load RDT.RDTMobRec
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerGroup = StorerGroup,
   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cPrinter   = Printer,
   @cUserName  = UserName,

   @cPUOM       = V_UOM,
   @cReceiptKey = V_Receiptkey,
   @cPOKey      = V_POKey,
   @cLOC        = V_Loc,
   @cID         = V_ID,
   @cSKU        = V_SKU,
   @cSKUDesc    = V_SKUDescr,
   @nQTY        = V_QTY,
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

   @nPUOM_Div           = V_Integer1,
   @nPQTY               = V_Integer2,
   @nMQTY               = V_Integer3,
   @nQTY                = V_Integer4,
   @nFromScn            = V_Integer5,
   @nPABookingKey       = V_Integer6,

   @cRefNo              = V_String1,
   @cIVAS               = V_String2,
   @cLottableCode       = V_String3,
   @cReasonCode         = V_String4,
   @cSuggToLOC          = V_String5,
   @cFinalLOC           = V_String6,
   @cReceiptLineNumber  = V_String7,
   @cPalletRecv         = V_String8,
   @cSubreasonCode      = V_String9,

   @cMUOM_Desc          = V_String10,
   @cPUOM_Desc          = V_String11,
   @cDefaultReceiveQty  = V_String12,
   @cFlowThruQtyScreen  = V_String13,
   
   @cColumnName         = V_String21,
   @cDefaultToLOC       = V_String22,
   @cCheckPLTID         = V_String23,
   @cAutoGenID          = V_String24,
   @cGetReceiveInfoSP   = V_String25,
   @cDecodeSP           = V_String26,
   @cAddSKUtoASN        = V_String27,
   @cVerifySKU          = V_String28,
   @cPalletRecvSP       = V_String29,
   @cExtendedValidateSP = V_String30,
   @cExtendedUpdateSP   = V_String31,
   @cRcptConfirmSP      = V_String32,
   @cExtendedInfoSP     = V_String33,
   @cExtendedInfo       = V_String34,
   @cPutawaySP          = V_String35,
   @cPutaway            = V_String36,
   @cMultiSKUBarcode    = V_String37,  --(cc01)
   @cReceiveDefaultToLoc= V_String38,  --(james03)
   @cGotoUccIDScn       = V_String39,  --(cc02)
   @cBarcode            = V_String41,  --(cc02)
   @cColumnName         = V_String42,
   
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

   @cFieldAttr01 = FieldAttr01,    @cFieldAttr02 = FieldAttr02,
   @cFieldAttr03 = FieldAttr03,    @cFieldAttr04 = FieldAttr04,
   @cFieldAttr05 = FieldAttr05,    @cFieldAttr06 = FieldAttr06,
   @cFieldAttr07 = FieldAttr07,    @cFieldAttr08 = FieldAttr08,
   @cFieldAttr09 = FieldAttr09,    @cFieldAttr10 = FieldAttr10,
   @cFieldAttr11 = FieldAttr11,    @cFieldAttr12 = FieldAttr12,
   @cFieldAttr13 = FieldAttr13,    @cFieldAttr14 = FieldAttr14,
   @cFieldAttr15 = FieldAttr15

FROM RDT.RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 598
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Func = 598. Menu
   IF @nStep = 1 GOTO Step_1   -- Scn = 4230. ASN, PO, CONT NO
   IF @nStep = 2 GOTO Step_2   -- Scn = 4231. LOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 4232. ID
   IF @nStep = 4 GOTO Step_4   -- Scn = 4233. SKU
   IF @nStep = 5 GOTO Step_5   -- Scn = 3490. Lottable
   IF @nStep = 6 GOTO Step_6   -- Scn = 4235. QTY, COND
   IF @nStep = 7 GOTO Step_7   -- Scn = 4236. Message. successful received
   IF @nStep = 8 GOTO Step_8   -- Scn = 4237. Option. Add SKU not in ASN?
   IF @nStep = 9 GOTO Step_9   -- Scn = 4238. Option. Print pallet label?
   IF @nStep = 10 GOTO Step_10 -- Scn = 3950. Verify SKU
   IF @nStep = 11 GOTO Step_11 -- Scn = 4239. Putaway
   IF @nStep = 12 GOTO Step_12 -- Scn = 3570. Multi SKU
   IF @nStep = 13 GOTO Step_13 -- Scn = 4234. UCCID   --(cc02)

END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 550. Menu
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN
   -- Get default UOM
   SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName

   -- Get storer config
   SET @cCheckPLTID = rdt.RDTGetConfig( @nFunc, 'CheckPLTID', @cStorerKey)
   SET @cAddSKUtoASN = rdt.RDTGetConfig( @nFunc, 'RDTAddSKUtoASN', @cStorerKey)
   SET @cVerifySKU = rdt.RDTGetConfig( @nFunc, 'VerifySKU', @cStorerKey)

   SET @cAutoGenID = rdt.RDTGetConfig( @nFunc, 'AutoGenID', @cStorerKey)
   IF @cAutoGenID = '0'
      SET @cAutoGenID = ''
   SET @cReceiveDefaultToLoc = rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorerKey)
   IF @cReceiveDefaultToLoc = '0'
      SET @cReceiveDefaultToLoc = ''
   SET @cRcptConfirmSP = rdt.RDTGetConfig( @nFunc, 'ReceiptConfirm_SP', @cStorerKey)
   IF @cRcptConfirmSP = '0'
      SET @cRcptConfirmSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cPalletRecvSP = rdt.RDTGetConfig( @nFunc, 'PalletRecvSP', @cStorerKey)
   IF @cPalletRecvSP = '0'
      SET @cPalletRecvSP = ''
   SET @cGetReceiveInfoSP = rdt.RDTGetConfig( @nFunc, 'GetReceiveInfoSP', @cStorerKey)
   IF @cGetReceiveInfoSP = '0'
      SET @cGetReceiveInfoSP = ''
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cPutawaySP = rdt.RDTGetConfig( @nFunc, 'PutawaySP', @cStorerKey)
   IF @cPutawaySP = '0'
      SET @cPutawaySP = ''

   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey) --(cc01)

   -- (james04)
   SET @cDefaultReceiveQty = rdt.RDTGetConfig( @nFunc, 'DefaultReceiveQty', @cStorerKey)
   SET @cFlowThruQtyScreen = rdt.RDTGetConfig( @nFunc, 'FlowThruQtyScreen', @cStorerKey)

   --(cc02)
   SET @cGotoUccIDScn = rdt.RDTGetConfig( @nFunc, 'GotoUccIDScn', @cStorerKey)
   IF @cGotoUccIDScn = '0'
      SET @cGotoUccIDScn = ''

   SET @cColumnName = rdt.RDTGetConfig( @nFunc, 'RefNoLookupColumn', @cStorerKey)
   
   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey

   -- Init var (due to var pass out by decodeSP, GetReceiveInfoSP is not reset)
   SELECT @cID = '', @cSKU = '', @nQTY = 0,
      @cLottable01 = '', @cLottable02 = '', @cLottable03 = '', @dLottable04 = 0,  @dLottable05 = 0,
      @cLottable06 = '', @cLottable07 = '', @cLottable08 = '', @cLottable09 = '', @cLottable10 = '',
      @cLottable11 = '', @cLottable12 = '', @dLottable13 = 0,  @dLottable14 = 0,  @dLottable15 = 0

   --INC0782771 - If RDT.Storerconfig = @cPalletRecvSP turn on, @cPalletRecv will set as '1'
   SET @cPalletRecv = '0'

   -- Prepare next screen var
   SET @cOutField01 = '' -- ContainerNo
   SET @cDefaultToLOC = ''

   -- Set the entry point
   SET @nScn = 4230
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 4030. Ref No screen
   REF NO  (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cChkReceiptKey NVARCHAR( 10)
      DECLARE @cReceiptStatus NVARCHAR( 10)
      DECLARE @cChkStorerKey NVARCHAR( 15)
      DECLARE @nRowCount INT

      -- Screen mapping
      SET @cRefNo = @cInField01

      -- Validate at least one field must key-in
      IF @cRefNo = ''
      BEGIN
         SET @nErrNo = 55901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need RefNo
         GOTO Quit
      END

      -- Lookup ref no  --(cc02)
      IF @cRefNo <> ''
      BEGIN
         EXEC rdt.rdt_ConReceive_RefNoLookup @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cSKU         = '' -- @cSKU
            ,@cRefNo       = @cRefNo      OUTPUT
            ,@nErrNo       = @nErrNo      OUTPUT
            ,@cErrMsg      = @cErrMsg     OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END

      -- (james02)
      IF ISNULL( @cReceiveDefaultToLoc, '') <> ''  -- (james03)
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cReceiveDefaultToLoc AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cReceiveDefaultToLoc) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, ' +
            ' @cLOC, @cID, @cSKU, @nQTY, @cReceiptKey, @cReceiptLineNumber, @tDefaultToLOC, ' +
            ' @cDefaultToLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cRefNo       NVARCHAR( 20), ' +
               '@cColumnName  NVARCHAR( 20), ' +
               '@cLOC         NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@nQTY         INT,           ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10), ' +
               '@tDefaultToLOC      VARIABLETABLE READONLY, ' +
               '@cDefaultToLOC      NVARCHAR( 10)  OUTPUT,  ' +
               '@nErrNo             INT            OUTPUT,  ' +
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName,
               @cLOC, @cID, @cSKU, @nQTY, @cReceiptKey, @cReceiptLineNumber, @tDefaultToLOC,
               @cDefaultToLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO QUIT
         END
         ELSE
            SET @cDefaultToLOC = @cReceiveDefaultToLoc
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

      -- Prepare next screen var
      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cDefaultToLOC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-Out
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey

      -- Clear log
      IF EXISTS( SELECT 1 FROM rdt.rdtConReceiveLog WITH (NOLOCK) WHERE Mobile = @nMobile)
      BEGIN
         SET @curCR = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RowRef FROM rdt.rdtConReceiveLog WITH (NOLOCK) WHERE Mobile = @nMobile
         OPEN @curCR
         FETCH NEXT FROM @curCR INTO @nRowRef
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE rdt.rdtConReceiveLog WHERE RowRef = @nRowRef
            FETCH NEXT FROM @curCR INTO @nRowRef
         END
      END

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cOutField01 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 4031. Location screen
   REF NO (field01)
   TOLOC  (field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField02 -- LOC

      -- Validate compulsary field
      IF @cLOC = '' OR @cLOC IS NULL
      BEGIN
         SET @nErrNo = 55905
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOC
         GOTO Step_2_Fail
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
         SET @nErrNo = 55906
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         GOTO Step_2_Fail
      END

      -- Validate location not in facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 55907
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         GOTO Step_2_Fail
      END

      --(cc02)
      IF @cGotoUccIDScn = '1'
      BEGIN
      	SET @cOutField01 = '' --ToID
      	SET @cOutField02 = '' --SKU/ucc
      	SET @cOutField03 = '' --SKU desc
      	SET @cOutField04 = '' --SKU desc

      -- Go to SKU screen
      SET @nScn  = @nScn + 2
      SET @nStep = @nStep + 2

      GOTO Quit
      END

      -- AutoGenID
      SET @cID = ''
      IF @cAutoGenID <> ''
      BEGIN
         EXEC rdt.rdt_ConReceive_AutoGenID @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cAutoGenID
            ,@cRefNo
            ,@cColumnName
            ,@cLOC
            ,@cID
            ,@cAutoID  OUTPUT
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT
         IF @nErrNo <> 0
            GOTO Step_2_Fail

         SET @cID = @cAutoID
      END

      -- Prepare next screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cRefNo
      SET @cDefaultToLOC = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField02 = '' -- LOC
      SET @cLOC = ''
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 4032. Pallet ID screen
   TO LOC (field01)
   TO ID  (field02, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cID = @cInField02 -- ID
      SET @cBarcode = @cInField02

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cBarcode) = 0
      BEGIN
         SET @nErrNo = 55909
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_3_Fail
      END

      -- Decode
      SET @cSKU = ''
      IF @cDecodeSP <> ''
      BEGIN
         SELECT @cSKU = '', @nQTY = 0,
            @cLottable01 = '', @cLottable02 = '', @cLottable03 = '', @dLottable04 = 0,  @dLottable05 = 0,
            @cLottable06 = '', @cLottable07 = '', @cLottable08 = '', @cLottable09 = '', @cLottable10 = '',
            @cLottable11 = '', @cLottable12 = '', @dLottable13 = 0,  @dLottable14 = 0,  @dLottable15 = 0

         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cID     = @cID     OUTPUT,
               @nErrNo  = @nErrNo  OUTPUT,
               @cErrMsg = @cErrMsg OUTPUT,
               @cType   = 'ID'

            IF @nErrNo <> 0
               GOTO Step_3_Fail
         END
         
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cBarcode, @cFieldName, ' +
               ' @cID         OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT, ' +
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
               ' @cRefNo       NVARCHAR( 20), ' +
               ' @cColumnName  NVARCHAR( 20), ' +
               ' @cLOC         NVARCHAR( 10), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cFieldName   NVARCHAR( 10), ' +
               ' @cID          NVARCHAR( 18)  OUTPUT, ' +
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
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cBarcode, 'ID',
               @cID         OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT,
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_3_Fail
         END
      END

      DECLARE @cAuthority NVARCHAR(1)
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
            SET @nErrNo = 55910
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Duplicate ID
            GOTO Step_3_Fail
         END
      END

      -- Check pallet received
      IF @cCheckPLTID = '1'
      BEGIN
         IF EXISTS (SELECT 1
            FROM rdt.rdtConReceiveLog CRL WITH (NOLOCK)
               JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (RD.ReceiptKey = CRL.ReceiptKey)
            WHERE CRL.Mobile = @nMobile
               AND RD.ToID = @cID
               AND RD.BeforeReceivedQty > 0)
         BEGIN
            SET @nErrNo = 55911
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID received
            GOTO Step_3_Fail
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cRefNo       NVARCHAR( 20), ' +
               '@cColumnName  NVARCHAR( 20), ' +
               '@cLOC         NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
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
               '@cSuggToLOC   NVARCHAR( 10), ' +
               '@cFinalLOC    NVARCHAR( 10), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10), ' +
               '@nErrNo             INT            OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_3_Fail
         END
      END

      -- Extended validate
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cRefNo       NVARCHAR( 20), ' +
               '@cColumnName  NVARCHAR( 20), ' +
               '@cLOC         NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
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
               '@cSuggToLOC   NVARCHAR( 10), ' +
               '@cFinalLOC    NVARCHAR( 10), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10), ' +
               '@nErrNo             INT            OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber,
               @nErrNo OUTPUT, @cErrMsg OUTPUT
         END
      END

      -- Init next screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = @cSKU -- SKU
      SET @cOutField03 = '' -- SKUDesc1
      SET @cOutField04 = '' -- SKUDesc2
      SET @cOutField15 = '' -- ExtendedInfo

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cLOC

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField02 = '' -- ID
      SET @cID = ''
   END
END
GOTO Quit


/********************************************************************************
Step 4. Scn = 4033. SKU screen
   TO ID    (field01)
   SKU      (field02, intput)
   SKU desc (field03)
   SKU desc (field04)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField02 -- SKU
      SET @cBarcode = @cInField02
      SET @cMultiSKU = @cSKU     --(cc01)

      -- Validate compulsary field
      IF @cSKU = '' OR @cSKU IS NULL
      BEGIN
         SET @nErrNo = 55912
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU is require
         GOTO Step_4_Fail
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cID         OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT,
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @cType   = 'UPC'

            IF @nErrNo <> 0
               GOTO Step_3_Fail
         END
         
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cBarcode, @cFieldName, ' +
               ' @cID         OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT, ' +
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
               ' @cRefNo       NVARCHAR( 20), ' +
               ' @cColumnName  NVARCHAR( 20), ' +
               ' @cLOC         NVARCHAR( 10), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cFieldName   NVARCHAR( 10), ' +
               ' @cID          NVARCHAR( 18)  OUTPUT, ' +
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
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cBarcode, 'SKU',
               @cID         OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT,
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_4_Fail
         END
      END

      -- Get SKU
      DECLARE @nSKUCnt INT
      SET @nSKUCnt = 0
      SELECT
         @nSKUCnt = COUNT( DISTINCT A.SKU),
         @cSKU = MIN( A.SKU) -- Just to bypass SQL aggregrate checking
      FROM
      (
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU
         UNION ALL
         SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU
      ) A

      -- Check SKU
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 55913
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO Step_4_Fail
      END

      -- Check barcode return multi SKU
      IF @nSKUCnt > 1
      BEGIN
      	--(cc01)
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
               @cMultiSKU  OUTPUT,
               @nErrNo     OUTPUT,
               @cErrMsg    OUTPUT,
               'CONTAINER',    -- DocType
               @cRefNo

            IF @nErrNo = 0 -- Populate multi SKU screen
            BEGIN
               SET @cDataType = ''
               SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Receipt' AND COLUMN_NAME = @cColumnName

            	SET @cSQL =
            	'SELECT DISTINCT sku ' +
               'FROM receiptDetail WITH (NOLOCK) ' +
               'WHERE storerKey = @cStorerKey ' +
               CASE WHEN @cDataType IN ('int', 'float')
                       THEN ' AND ISNULL( ' + @cColumnName + ', 0) = @cRefNo '
                       ELSE ' AND ISNULL( ' + @cColumnName + ', '''') = @cRefNo '
                END +
               'AND sku IN (@cOutField02,@cOutField06,@cOutField10)' +
               CASE WHEN @cStorerGroup = ''
                       THEN ' AND StorerKey = @cStorerKey '
                       ELSE ' AND EXISTS( SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cStorerKey) '
                  END +
               ' SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT '

            	SET @cSQLParam =
               ' @cStorerGroup NVARCHAR(20), ' +
               ' @cStorerKey   NVARCHAR(15), ' +
               ' @cColumnName  NVARCHAR(20), ' +
               ' @cRefNo       NVARCHAR(30), ' +
               ' @cOutField02  NVARCHAR(18), ' +
               ' @cOutField06  NVARCHAR(18), ' +
               ' @cOutField10  NVARCHAR(18), ' +
               ' @nRowCount    INT          OUTPUT, ' +
               ' @nErrNo       INT          OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @cStorerGroup,
               @cStorerKey,
               @cColumnName,
               @cRefNo,
               @cOutField02,
               @cOutField06,
               @cOutField10,
               @nRowCount   OUTPUT,
               @nErrNo      OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            	IF @nRowCount >1
            	BEGIN
            		-- Go to Multi SKU screen
            		SET @cFieldAttr13 = ''
            		SET @nFromScn = @nScn
                  SET @nScn = 3570
                  SET @nStep = @nStep + 8
                  GOTO Quit
            	END
               ELSE
               BEGIN
               	--SELECT @cSKU = sku FROM receiptDetail (NOLOCK) WHERE storerKey = @cStorerKey AND receiptKey = @cRefNo AND sku IN (@cOutField02,@cOutField06,@cOutField10)
               	SET @nErrNo = 0  --Skip multi sku screen

               	--SET the SKU as receiptDetail' SKU
               	SET @cSQL =
            	   'SELECT TOP 1 @cSKU = sku ' +
                  'FROM receiptDetail WITH (NOLOCK) ' +
                  'WHERE storerKey = @cStorerKey ' +
                  CASE WHEN @cDataType IN ('int', 'float')
                          THEN ' AND ISNULL( ' + @cColumnName + ', 0) = @cRefNo '
                          ELSE ' AND ISNULL( ' + @cColumnName + ', '''') = @cRefNo '
                   END +
                  'AND sku IN (@cOutField02,@cOutField06,@cOutField10)' +
                  CASE WHEN @cStorerGroup = ''
                          THEN ' AND StorerKey = @cStorerKey '
                          ELSE ' AND EXISTS( SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cStorerKey) '
                     END +
                  ' SELECT @nErrNo = @@ERROR'

            	   SET @cSQLParam =
                  ' @cStorerGroup NVARCHAR(20), ' +
                  ' @cStorerKey   NVARCHAR(15), ' +
                  ' @cColumnName  NVARCHAR(20), ' +
                  ' @cRefNo       NVARCHAR(30), ' +
                  ' @cOutField02  NVARCHAR(18), ' +
                  ' @cOutField06  NVARCHAR(18), ' +
                  ' @cOutField10  NVARCHAR(18), ' +
                  ' @cSKU         NVARCHAR(20)   OUTPUT,  ' +
                  ' @nErrNo       INT          OUTPUT  '
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,

                  @cStorerGroup,
                  @cStorerKey,
                  @cColumnName,
                  @cRefNo,
                  @cOutField02,
                  @cOutField06,
                  @cOutField10,
                  @cSKU       OUTPUT,
                  @nErrNo     OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit

               END

            END

            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
            BEGIN
               SET @nErrNo = 0
               SET @cSku = @cMultiSKU
            END
         END
         ELSE
         BEGIN
         	SET @nErrNo = 55914
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
            GOTO Step_4_Fail
         END
      END

      -- Get SKU info
      SET @cSKUDesc = ''
      SELECT
         @cSKUDesc = ISNULL( DescR, ''),
         @cLottableCode = LottableCode
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Retain value
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20) -- SKU desc 2
/*
      -- Check SKU in PO
      IF @cPOKey <> '' AND @cPOKey <> 'NOPO'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PODetail WITH (NOLOCK) WHERE POKey = @cPOKey AND StorerKey = @cStorerKey AND SKU = @cSKU)
         BEGIN
            SET @nErrNo = 55915
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not in PO
            GOTO Step_4_Fail
         END
      END
*/
      -- Check SKU in ASN
      DECLARE @nSKUNotInASN INT
      IF NOT EXISTS( SELECT 1
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            JOIN rdt.rdtConReceiveLog CRL WITH (NOLOCK) ON (RD.ReceiptKey = CRL.ReceiptKey)
         WHERE CRL.Mobile = @nMobile
            AND RD.StorerKey = @cStorerKey
            AND RD.SKU = @cSKU)
      BEGIN
         SET @nSKUNotInASN = 1
         IF @cAddSKUtoASN <> '1'
         BEGIN
            SET @nErrNo = 55916
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not in ASN
            GOTO Step_4_Fail
         END
      END

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
            SET @nFromScn = @nScn
            SET @nScn = 3951
            SET @nStep = @nStep + 6

            GOTO Quit
         END
      END

      -- Get receiving info
      IF @cGetReceiveInfoSP = ''
      BEGIN
         SELECT TOP 1
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
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            JOIN rdt.rdtConReceiveLog CRL WITH (NOLOCK) ON (RD.ReceiptKey = CRL.ReceiptKey)
         WHERE CRL.Mobile = @nMobile
            AND SKU = @cSKU
         ORDER BY
            CASE WHEN @cID = ToID THEN 0 ELSE 1 END,
            CASE WHEN QTYExpected > 0 AND QTYExpected > BeforeReceivedQTY THEN 0 ELSE 1 END,
            ReceiptLineNumber
      END
      ELSE
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetReceiveInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetReceiveInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cColumnName, @cLOC, ' +
               ' @cID         OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT, ' +
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
               ' @cRefNo       NVARCHAR( 20), ' +
               ' @cColumnName  NVARCHAR( 20), ' +
               ' @cLOC         NVARCHAR( 10), ' +
               ' @cID          NVARCHAR( 18)  OUTPUT, ' +
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
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cColumnName, @cLOC,
               @cID         OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT,
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_4_Fail
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cRefNo       NVARCHAR( 20), ' +
               '@cColumnName  NVARCHAR( 20), ' +
               '@cLOC         NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
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
               '@cSuggToLOC   NVARCHAR( 10), ' +
               '@cFinalLOC    NVARCHAR( 10), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10), ' +
               '@nErrNo             INT            OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_4_Fail
         END
      END

      -- Add SKU to ASN
      IF @nSKUNotInASN = 1 AND @cAddSKUtoASN = '1'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- Option

         -- Go to Add SKU to ASN screen
         SET @nFromScn = @nScn
         SET @nScn  = @nScn + 4
         SET @nStep = @nStep + 4

         GOTO Quit
      END

      --(cc02)
      IF @cGotoUccIDScn = '1'
      BEGIN
      	-- Extended info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber, ' +
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
                  '@cRefNo        NVARCHAR( 20), ' +
                  '@cColumnName   NVARCHAR( 20), ' +
                  '@cLOC          NVARCHAR( 10), ' +
                  '@cID           NVARCHAR( 18), ' +
                  '@cSKU          NVARCHAR( 20), ' +
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
                  '@nQTY          INT,           ' +
                  '@cReasonCode   NVARCHAR( 10), ' +
                  '@cSuggToLOC    NVARCHAR( 10), ' +
                  '@cFinalLOC     NVARCHAR( 10), ' +
                  '@cReceiptKey   NVARCHAR( 10), ' +
                  '@cReceiptLineNumber NVARCHAR( 10),   ' +
                  '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +
                  '@nErrNo        INT           OUTPUT, ' +
                  '@cErrMsg       NVARCHAR( 20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, 4, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber,
                  @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_3_Fail

               SET @cOutField15 = @cExtendedInfo
            END
         END

      	-- Prepare next screen var
         SET @cOutField01 = @cRefNo
         SET @cOutField02 = @cBarcode
         SET @cOutField03 = @cID

         -- Go to UCCID screen
         SET @nFromScn = @nScn
         SET @nScn  = 4234
         SET @nStep = @nStep + 9

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
         @cRefNo,
         @nFunc

      IF @nErrNo <> 0
         GOTO Quit

      IF @nMorePage = 1 -- Yes
      BEGIN
         -- Go to dynamic lottable screen
         SET @nFromScn = @nScn
         SET @nScn = 3990
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
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
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU

         IF rdt.rdtIsValidQTY( @cDefaultReceiveQty, 1) = 1
            SET @nQTY = CAST( @cDefaultReceiveQty AS INT)

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
         SET @cOutField08 = CASE WHEN @nPQTY = 0 OR @cFieldAttr08 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 7)) END -- PQTY
         SET @cOutField09 = CASE WHEN @nMQTY = 0 THEN '' ELSE CAST( @nMQTY AS NVARCHAR( 7)) END -- MQTY
         SET @cOutField10 = '' -- ConditionCode
         SET @cOutField11 = '' -- SubReasonCode
         SET @cOutField15 = '' -- ExtendedInfo

         IF @cFieldAttr08 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY

         -- Go to QTY screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2

         -- Extended info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber, ' +
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
                  '@cRefNo        NVARCHAR( 20), ' +
                  '@cColumnName   NVARCHAR( 20), ' +
                  '@cLOC          NVARCHAR( 10), ' +
                  '@cID           NVARCHAR( 18), ' +
                  '@cSKU          NVARCHAR( 20), ' +
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
                  '@nQTY          INT,           ' +
                  '@cReasonCode   NVARCHAR( 10), ' +
                  '@cSuggToLOC    NVARCHAR( 10), ' +
                  '@cFinalLOC     NVARCHAR( 10), ' +
                  '@cReceiptKey   NVARCHAR( 10), ' +
                  '@cReceiptLineNumber NVARCHAR( 10),   ' +
                  '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +
                  '@nErrNo        INT           OUTPUT, ' +
                  '@cErrMsg       NVARCHAR( 20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, 4, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber,
                  @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_3_Fail

               SET @cOutField15 = @cExtendedInfo
            END
         END

         IF @cFlowThruQtyScreen = '1'
         BEGIN
            IF @cFieldAttr08 = '' AND @nPQTY > 0 SET @cInField08 = @nPQTY
            IF @cFieldAttr09 = '' AND @nMQTY > 0 SET @cInField09 = @nMQTY
            GOTO Step_6
         END

      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Extended validate
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cRefNo       NVARCHAR( 20), ' +
               '@cColumnName  NVARCHAR( 20), ' +
               '@cLOC         NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
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
               '@cSuggToLOC   NVARCHAR( 10), ' +
               '@cFinalLOC    NVARCHAR( 10), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10), ' +
               '@nErrNo             INT            OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber,
               @nErrNo OUTPUT, @cErrMsg OUTPUT
         END
      END

      -- Check if pallet label setup
      IF EXISTS( SELECT 1 FROM RDT.RDTReport WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND ReportType IN ('PalletLBL'))
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = '' -- Option

         -- Go to print pallet label screen
         SET @nScn = @nScn + 5
         SET @nStep = @nStep + 5
      END
      ELSE
      BEGIN
      	--(cc02)
         IF @cGotoUccIDScn = '1'
         BEGIN
      	   SET @cOutField01 = @cRefNo
      	   SET @cOutField02 = @cLOC

            -- Go to loc screen
            SET @nScn  = @nScn - 2
            SET @nStep = @nStep - 2

            GOTO Quit
         END

         -- Prepare next screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = '' -- @cID

         -- Go to ID screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
     END
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField02 = '' -- SKU
      SET @cSKU = ''
   END
END
GOTO Quit


/********************************************************************************
Step 5. Scn = 3490. Dynamic lottables
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
Step_5:
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
         @cRefNo,
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
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

      IF rdt.rdtIsValidQTY( @cDefaultReceiveQty, 1) = 1
         SET @nQTY = CAST( @cDefaultReceiveQty AS INT)

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
      SET @cOutField08 = CASE WHEN @nPQTY = 0 OR @cFieldAttr08 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 7)) END -- PQTY
      SET @cOutField09 = CASE WHEN @nMQTY = 0 THEN '' ELSE CAST( @nMQTY AS NVARCHAR( 7)) END -- MQTY
      SET @cOutField10 = '' -- ConditionCode
      SET @cOutField11 = '' -- SubReasonCode
      SET @cOutField15 = '' -- ExtendedInfo

      IF @cFieldAttr08 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY

      -- Go to QTY screen
      SET @nScn  = 4235--@nFromScn + 2
      SET @nStep = @nStep + 1

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber, ' +
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
               '@cRefNo        NVARCHAR( 20), ' +
               '@cColumnName   NVARCHAR( 20), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cSKU          NVARCHAR( 20), ' +
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
               '@nQTY          INT,           ' +
               '@cReasonCode   NVARCHAR( 10), ' +
               '@cSuggToLOC    NVARCHAR( 10), ' +
               '@cFinalLOC     NVARCHAR( 10), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10),   ' +
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 5, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber,
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_3_Fail

            SET @cOutField15 = @cExtendedInfo
         END
      END

      IF @cFlowThruQtyScreen = '1'
      BEGIN
         IF @cFieldAttr08 = '' AND @nPQTY > 0 SET @cInField08 = @nPQTY
         IF @cFieldAttr09 = '' AND @nMQTY > 0 SET @cInField09 = @nMQTY
         GOTO Step_6
      END
   END

   IF @nInputKey = 0 -- Esc or No
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
         @cRefNo,
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
      SET @cOutField02 = '' -- @cSKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20) -- SKU desc 2

      -- Go back to prev screen
      SET @nScn = @nFromScn
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_5_Fail:

END
GOTO Quit


/********************************************************************************
Step 6. Scn = 4035. QTY screen
   SKU       (field01)
   SKU desc  (field02)
   SKU desc  (field03)
   IVAS      (field04)
   UOM ratio (field05)
   PUOM      (field06)
   MUOM      (field07)
   PQTY      (field08, input)
   MQTY      (field09, input)
   Reason    (field10, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cPQTY       NVARCHAR( 7)
      DECLARE @cMQTY       NVARCHAR( 7)

      -- Screen mapping
      SET @cPQTY = CASE WHEN @cFieldAttr08 = 'O' THEN @cOutField08 ELSE @cInField08 END
      SET @cMQTY = CASE WHEN @cFieldAttr09 = 'O' THEN @cOutField09 ELSE @cInField09 END
      SET @cReasonCode = @cInField10
      SET @cSubreasonCode = @cInField11

      -- Retain value
      SET @cOutField08 = CASE WHEN @cFieldAttr08 = 'O' THEN @cOutField08 ELSE @cInField08 END -- PQTY
      SET @cOutField09 = CASE WHEN @cFieldAttr09 = 'O' THEN @cOutField09 ELSE @cInField09 END -- MQTY

      -- Validate PQTY
      IF @cPQTY <> '' AND RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 55917
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY
         GOTO Step_6_Fail
      END
      SET @nPQTY = CAST( @cPQTY AS INT)

      -- Validate MQTY
      IF @cMQTY <> '' AND RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 55918
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 9 -- MQTY
         GOTO Step_6_Fail
      END
      SET @nMQTY = CAST( @cMQTY AS INT)

      -- Calc total QTY in master UOM
      SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nQTY = @nQTY + @nMQTY

      IF ISNULL(rdt.RDTGetConfig( @nFunc, 'CONDCODECHECKSTORER', @cStorerKey),'0') = '1'
      AND @cReasonCode <> '' AND @cReasonCode IS NOT NULL
      BEGIN
         IF NOT EXISTS( SELECT Code
            FROM dbo.CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'ASNREASON'
               AND Storerkey = @cStorerkey
               AND Code = @cReasonCode)
         BEGIN
            SET @nErrNo = 59429
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad ReasonCode
            SET @cReasonCode = ''
            EXEC rdt.rdtSetFocusField @nMobile, 10
            GOTO Step_6_Fail
         END
      END
      -- Validate reason code exists
      ELSE IF @cReasonCode <> '' AND @cReasonCode IS NOT NULL
      BEGIN
         IF NOT EXISTS( SELECT Code
            FROM dbo.CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'ASNREASON'
               AND Code = @cReasonCode)
         BEGIN
            SET @nErrNo = 59429
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Cond Code
            SET @cReasonCode = ''
            EXEC rdt.rdtSetFocusField @nMobile, 10
            GOTO Step_6_Fail
         END
      END

      -- Check sub reason
      IF @cSubreasonCode <> ''
      BEGIN
         IF NOT EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'ASNSUBRSN' AND Code = @cSubreasonCode AND StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 59429
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad ReasonCode
            SET @cSubreasonCode = ''
            EXEC rdt.rdtSetFocusField @nMobile, 11
            GOTO Step_6_Fail
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cRefNo       NVARCHAR( 20), ' +
               '@cColumnName  NVARCHAR( 20), ' +
               '@cLOC         NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
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
               '@cSuggToLOC   NVARCHAR( 10), ' +
               '@cFinalLOC    NVARCHAR( 10), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10), ' +
               '@nErrNo             INT            OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_6_Fail
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
      -- DECLARE @nNOPOFlag INT
      -- SET @nNOPOFlag = CASE WHEN @cPOkey = 'NOPO' THEN 1 ELSE 0 END

      -- Reason code
      IF @cReasonCode = ''
         SET @cReasonCode = 'OK'

      -- Custom receiving logic
      IF @cRcptConfirmSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cRcptConfirmSP) +
            ' @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, @cRefNo, @cColumnName, @cToLOC, @cToID, ' +
            ' @cSKUCode, @cSKUUOM, @nSKUQTY, @cUCC, @cUCCSKU, @nUCCQTY, @cCreateUCC, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @nNOPOFlag, @cConditionCode, @cSubreasonCode, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @cReceiptKeyOutput OUTPUT, @cReceiptLineNumberOutput OUTPUT '

         SET @cSQLParam =
            '@nFunc          INT,            ' +
            '@nMobile        INT,            ' +
            '@cLangCode      NVARCHAR( 3),   ' +
            '@cStorerKey     NVARCHAR( 15),  ' +
            '@cFacility      NVARCHAR( 5),   ' +
            '@cRefNo         NVARCHAR( 20),  ' +
            '@cColumnName    NVARCHAR( 20),  ' +
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
            '@nErrNo         INT              OUTPUT, ' +
            '@cErrMsg        NVARCHAR( 20)    OUTPUT, ' +
            '@cReceiptKeyOutput NVARCHAR( 20) OUTPUT, ' +
            '@cReceiptLineNumberOutput NVARCHAR( 20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, @cRefNo, @cColumnName, @cLOC, @cID,
            @cSKU, @cUOM, @nQTY, '', '', 0, '',
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, NULL,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            1, @cReasonCode, @cSubreasonCode,
            @nErrNo OUTPUT, @cErrMsg OUTPUT, @cReceiptKey OUTPUT, @cReceiptLineNumber OUTPUT
      END
      ELSE
      BEGIN
         -- Receive
         EXEC rdt.rdt_ConReceive
            @nFunc         = @nFunc,
            @nMobile       = @nMobile,
            @cLangCode     = @cLangCode,
            @nErrNo        = @nErrNo OUTPUT,
            @cErrMsg       = @cErrMsg OUTPUT,
            @cStorerKey    = @cStorerKey,
            @cFacility     = @cFacility,
            @cRefNo        = @cRefNo,
            @cColumnName   = @cColumnName,
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
            @dLottable05   = NULL,
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
            @nNOPOFlag     = 1,
            @cConditionCode = @cReasonCode,
            @cSubreasonCode = @cSubreasonCode,
            @cReceiptKeyOutput = @cReceiptKey OUTPUT,
            @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT
      END

      IF @nErrNo <> 0
         GOTO Quit

      -- Extended validate
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cRefNo       NVARCHAR( 20), ' +
               '@cColumnName  NVARCHAR( 20), ' +
               '@cLOC         NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
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
               '@cSuggToLOC   NVARCHAR( 10), ' +
               '@cFinalLOC    NVARCHAR( 10), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10), ' +
               '@nErrNo             INT            OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber,
               @nErrNo OUTPUT, @cErrMsg OUTPUT
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
         @cLocation     = @cLOC,
         @cID           = @cID,
         @cSKU          = @cSKU,
         @cUOM          = @cUOM,
         @nQTY          = @nQTY,
         @cRefNo1       = @cRefNo,
         @cRefNo2       = @cColumnName,
         @cRefNo3       = @cReasonCode,
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
         @dLottable15   = @dLottable15

      -- Enable field
      SET @cFieldAttr08 = '' -- @nPQTY

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      IF @cFlowThruQtyScreen = '1'
         GOTO Step_7
   END

   IF @nInputKey = 0 -- Esc or No
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
         @cRefNo,
         @nFunc

      IF @nErrNo <> 0
         GOTO Quit

      IF @nMorePage = 1 -- Yes
      BEGIN
         -- Go to dynamic lottable screen
         SET @nScn = 3990
         SET @nStep = @nStep - 1
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
         SET @cOutField02 = '' -- SKU
         SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 1, 20)
         SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20)

         -- Go back to SKU screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
      END
   END
   GOTO Quit

   Step_6_Fail:

END
GOTO Quit


/********************************************************************************
Step 7. scn = 4036. Message screen
   Successful received
   Press ENTER or ESC
   to continue
********************************************************************************/
Step_7:
BEGIN
   -- Check receive pallet
   IF @cPalletRecvSP = '1'
      SET @cPalletRecv = '1'
   ELSE
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPalletRecvSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cPalletRecvSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, @nQTY, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @cPalletRecv OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cStorerKey   NVARCHAR( 15), ' +
            '@cRefNo       NVARCHAR( 20), ' +
            '@cColumnName  NVARCHAR( 20), ' +
            '@cLOC         NVARCHAR( 10), ' +
            '@cID          NVARCHAR( 18), ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' +
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
            '@cPalletRecv  NVARCHAR( 1)   OUTPUT, ' +
            '@nErrNo       INT            OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20)  OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, @nQTY,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @cPalletRecv OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
      END
   END

   -- Check need to putaway
   SET @cPutaway = ''
   IF @cPutawaySP = '1' OR @cPutawaySP = '2'
      SET @cPutaway = @cPutawaySP
   ELSE
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPutawaySP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cPutawaySP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, @nQTY, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @cPutaway OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cStorerKey   NVARCHAR( 15), ' +
            '@cRefNo       NVARCHAR( 20), ' +
            '@cColumnName  NVARCHAR( 20), ' +
            '@cLOC         NVARCHAR( 10), ' +
            '@cID          NVARCHAR( 18), ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' +
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
            '@cPutaway     NVARCHAR( 1)   OUTPUT, ' +
            '@nErrNo       INT            OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20)  OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, @nQTY,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @cPutaway OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
      END
   END

   -- Putaway
   IF @cPutaway = '1' OR @cPutaway = '2'
   BEGIN
      -- Suggest LOC
      EXEC rdt.rdt_ConReceive_Putaway @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'SUGGEST',
         @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, @nQTY, @cReceiptKey, @cReceiptLineNumber, '',
         @cSuggToLOC    OUTPUT,
         @nPABookingKey OUTPUT,
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT

      -- Prepare next screen var
      SET @cOutField01 = @cSuggToLOC
      SET @cOutField02 = '' --FinalLOC

      -- Go to putaway screen
      SET @nScn = @nScn + 4
      SET @nStep = @nStep + 4

      GOTO Quit
   END

   IF @cPalletRecv = '1'
   BEGIN
      -- AutoGenID
      SET @cID = ''
      IF @cAutoGenID <> ''
      BEGIN
         EXEC rdt.rdt_ConReceive_AutoGenID @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cAutoGenID
            ,@cRefNo
            ,@cColumnName
            ,@cLOC
            ,@cID
            ,@cAutoID  OUTPUT
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         SET @cID = @cAutoID
      END

      --(cc02)
      IF @cGotoUccIDScn = '1'
      BEGIN
      	SET @cOutField01 = @cRefNo
         SET @cOutField02 = ''

         -- Go to UCCID screen
         SET @nScn = @nScn - 4234
         SET @nStep = @nStep - 6

         GOTO QUIT
      END

      -- Prep next screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID

      -- Go to ID screen
      SET @nScn = @nScn - 4
      SET @nStep = @nStep - 4
   END
   ELSE
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20) -- SKU desc 2

      -- Go to SKU screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END


END

   Step_7_Quit:
   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber, ' +
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
            '@cRefNo        NVARCHAR( 20), ' +
            '@cColumnName   NVARCHAR( 20), ' +
            '@cLOC          NVARCHAR( 10), ' +
            '@cID           NVARCHAR( 18), ' +
            '@cSKU          NVARCHAR( 20), ' +
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
            '@nQTY          INT,           ' +
            '@cReasonCode   NVARCHAR( 10), ' +
            '@cSuggToLOC    NVARCHAR( 10), ' +
            '@cFinalLOC     NVARCHAR( 10), ' +
            '@cReceiptKey   NVARCHAR( 10), ' +
            '@cReceiptLineNumber NVARCHAR( 10),   ' +
            '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, 4, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber,
            @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit

         SET @cOutField15 = @cExtendedInfo
      END
   END

   -- Reset data
   SELECT @cSKU = '', @nQTY = 0,
      @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL, @dLottable05 = NULL,
      @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',   @cLottable10 = '',
      @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL, @dLottable15 = NULL

GOTO Quit


/********************************************************************************
Step 8. Scn = 4037. Option
   ADD SKU NOT IN ASN?
   1 = YES
   2 = NO
   OPTION: (field01, input)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 55921
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option
         GOTO Step_8_Fail
      END

      -- Check valid option
      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 55922
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_8_Fail
      END

      IF @cOption = '1' -- Yes
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
            @cRefNo,
            @nFunc

         IF @nErrNo <> 0
            GOTO Quit

         IF @nMorePage = 1 -- Yes
         BEGIN
            -- Go to dynamic lottable screen
            SET @nScn = 3990
            SET @nStep = @nStep - 3
         END
         ELSE
         BEGIN
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
               INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE SKU.StorerKey = @cStorerKey
               AND SKU.SKU = @cSKU

            IF rdt.rdtIsValidQTY( @cDefaultReceiveQty, 1) = 1
               SET @nQTY = CAST( @cDefaultReceiveQty AS INT)

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
            SET @cOutField08 = CASE WHEN @nPQTY = 0 OR @cFieldAttr08 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 7)) END -- PQTY
            SET @cOutField09 = CASE WHEN @nMQTY = 0 THEN '' ELSE CAST( @nMQTY AS NVARCHAR( 7)) END -- MQTY
            SET @cOutField10 = '' -- ConditionCode
            SET @cOutField11 = '' -- SubReasonCode
            SET @cOutField15 = '' -- ExtendedInfo

            IF @cFieldAttr08 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY

            -- Go to QTY screen
            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2

            IF @cFlowThruQtyScreen = '1'
            BEGIN
               IF @cFieldAttr08 = '' AND @nPQTY > 0 SET @cInField08 = @nPQTY
               IF @cFieldAttr09 = '' AND @nMQTY > 0 SET @cInField09 = @nMQTY
               GOTO Step_6
            END
         END
      END

      IF @cOption = '2' -- No
      BEGIN
         SET @cOutField01 = @cID
         SET @cOutField02 = '' -- SKU
         SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 1, 20)
         SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20)

         -- Go back to SKU screen
         SET @nScn = @nScn - 4
         SET @nStep = @nStep - 4
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cID
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 1, 20)
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20)

      SET @nScn = @nScn - 4
      SET @nStep = @nStep - 4
   END
   GOTO Quit

   Step_8_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOption = ''
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Step 9. Scn = 4038. Message
   Print pallet label?
   1 = YES
   2 = NO
   OPTION   (field01, input)
********************************************************************************/
Step_9:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 55923
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option
         GOTO Step_9_Fail
      END

      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 55924
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_9_Fail
      END

      IF @cOption = '1' -- Yes
      BEGIN
         -- Validate printer setup
         IF @cPrinter = ''
         BEGIN
            SET @nErrNo = 55925
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLoginPrinter
            GOTO Step_9_Fail
         END

         -- Get report info
         DECLARE @cDataWindow NVARCHAR(50)
         DECLARE @cTargetDB   NVARCHAR(10)
         SELECT
            @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
            @cTargetDB = ISNULL(RTRIM(TargetDB), '')
         FROM RDT.RDTReport WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND ReportType ='PALLETLBL'

         -- Check data window
         IF ISNULL(@cDataWindow, '') = ''
         BEGIN
            SET @nErrNo = 55926
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
            GOTO Step_9_Fail
         END

         -- Check database
         IF ISNULL(@cTargetDB, '') = ''
         BEGIN
            SET @nErrNo = 55927
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
            GOTO Step_9_Fail
         END

         -- Insert print job
         EXEC RDT.rdt_BuiltPrintJob
            @nMobile,
            @cStorerKey,
            'PALLETLBL',       -- ReportType
            'PRINT_PALLETLBL', -- PrintJobName
            @cDataWindow,
            @cPrinter,
            @cTargetDB,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT,
            @cReceiptKey,
            @cID

         -- AutoGenID
         SET @cID = ''
         IF @cAutoGenID <> ''
         BEGIN
            EXEC rdt.rdt_ConReceive_AutoGenID @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
               ,@cAutoGenID
               ,@cRefNo
               ,@cColumnName
               ,@cLOC
               ,@cID
               ,@cAutoID  OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT
            IF @nErrNo <> 0
               GOTO Step_9_Fail

            SET @cID = @cAutoID
         END

         -- Prepare next screen
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cID

         -- Go to ID screen
         SET @nScn = @nScn - 6
         SET @nStep = @nStep - 6
      END

      IF @cOption = '2' -- No
      BEGIN
         -- AutoGenID
         SET @cID = ''
         IF @cAutoGenID <> ''
         BEGIN
            EXEC rdt.rdt_ConReceive_AutoGenID @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
               ,@cAutoGenID
               ,@cRefNo
               ,@cColumnName
               ,@cLOC
               ,@cID
               ,@cAutoID  OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT
            IF @nErrNo <> 0
               GOTO Step_9_Fail

            SET @cID = @cAutoID
         END

         -- Prepare next screen
         SET @cOutField01 = @cLOC
         SET @cOutField02 = @cID

         -- Go back to ID screen
         SET @nScn = @nScn - 6
         SET @nStep = @nStep - 6
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen
      SET @cOutField01 = @cID
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 1, 20)
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20)

      -- Go back to SKU screen
      SET @nScn = @nScn - 5
      SET @nStep = @nStep - 5
   END
   GOTO Quit

   Step_9_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOption = ''
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Step 10. Screen = 3950. Verify SKU
   SKU         (Field01)
   SKUDesc1    (Field02)
   SKUDesc2    (Field03)
   Weight      (Field04, input)
   Cube        (Field05, input)
   Length      (Field06, input)
   Width       (Field07, input)
   Height      (Field08, input)
   InnerPack   (Field09, input)
   CaseCount   (Field10, input)
   PalletCount (Field11, input)
********************************************************************************/
Step_10:
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
      SET @cFieldAttr06 = '' --
      SET @cFieldAttr08 = '' --
      SET @cFieldAttr10 = '' --
      SET @cFieldAttr12 = '' --
      SET @cFieldAttr13 = '' --

      -- Prepare prev screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = '' -- @cSKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20) -- SKU desc 2

      -- Go back to SKU screen
      SET @nScn = @nFromScn
      SET @nStep = @nStep - 6
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Enable field
      SET @cFieldAttr04 = '' -- Dynamic verify SKU 1..5
      SET @cFieldAttr06 = '' --
      SET @cFieldAttr08 = '' --
      SET @cFieldAttr10 = '' --
      SET @cFieldAttr12 = '' --

      -- Prepare prev screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = '' -- @cSKU
      SET @cOutField03 = '' --rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1 --(cc01)
      SET @cOutField04 = '' --rdt.rdtFormatString( @cSKUDesc, 21, 20) -- SKU desc 2 --(cc01)
      SET @cOutField15  = '' --(cc01)

      SET @cSKU = '' --(cc01)

      -- Go back to SKU screen
      SET @nScn = @nFromScn
      SET @nStep = @nStep - 6
   END

   -- Enable field
   SELECT @cFieldAttr04 = ''
   SELECT @cFieldAttr05 = ''
   SELECT @cFieldAttr06 = ''
   SELECT @cFieldAttr07 = ''
   SELECT @cFieldAttr08 = ''
   SELECT @cFieldAttr09 = ''
   SELECT @cFieldAttr10 = ''
   SELECT @cFieldAttr11 = ''
   SELECT @cFieldAttr12 = ''
END
GOTO Quit


/********************************************************************************
Step 11. Screen = 4239. Putaway
   Suggest LOC (Field01)
   Final LOC   (Field02, input)
********************************************************************************/
Step_11:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFinalLOC = @cInField02

      -- Putaway
      EXEC rdt.rdt_ConReceive_Putaway @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'EXECUTE',
         @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, @nQTY, @cReceiptKey, @cReceiptLineNumber, @cFinalLOC,
         @cSuggToLOC    OUTPUT,
         @nPABookingKey OUTPUT,
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT
      IF @nErrNo <> 0
      BEGIN
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cRefNo       NVARCHAR( 20), ' +
               '@cColumnName  NVARCHAR( 20), ' +
               '@cLOC         NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
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
               '@cSuggToLOC   NVARCHAR( 10), ' +
               '@cFinalLOC    NVARCHAR( 10), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10), ' +
               '@nErrNo             INT            OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber,
               @nErrNo OUTPUT, @cErrMsg OUTPUT
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Check compulsory putaway
      IF @cPutaway = '1'
         GOTO Quit

      -- Cancel putaway
      EXEC rdt.rdt_ConReceive_Putaway @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CANCEL',
         @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, @nQTY, @cReceiptKey, @cReceiptLineNumber, @cFinalLOC,
         @cSuggToLOC    OUTPUT,
         @nPABookingKey OUTPUT,
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
   END

   IF @cPalletRecv = '1'
   BEGIN
      -- AutoGenID
      SET @cID = ''
      IF @cAutoGenID <> ''
      BEGIN
         EXEC rdt.rdt_ConReceive_AutoGenID @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cAutoGenID
            ,@cRefNo
            ,@cColumnName
            ,@cLOC
            ,@cID
            ,@cAutoID  OUTPUT
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         SET @cID = @cAutoID
      END

      -- Prep next screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID

      -- Go to ID screen
      SET @nScn = @nScn - 8
      SET @nStep = @nStep - 8
   END
   ELSE
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20) -- SKU desc 2

      -- Go to SKU screen
      SET @nScn = @nScn - 7
      SET @nStep = @nStep - 7
   END

   -- Reset data
   SELECT @cSKU = '', @nQTY = 0,
      @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL, @dLottable05 = NULL,
      @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',   @cLottable10 = '',
      @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL, @dLottable15 = NULL

END
GOTO Quit

/********************************************************************************
Step 12. Screen = 3570. Multi SKU
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
Step_12:  --(cc01)
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
      SELECT @cSKUDesc = Descr FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU

      -- Init next screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = @cSKU -- SKU
      SET @cOutField03 = @cSKUDesc -- SKUDesc1
      SET @cOutField04 = '' -- SKUDesc2

      SET @cSKU = ''

      -- Go to next screen
      SET @nScn  = 4233
      SET @nStep = @nStep - 8
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
   	-- Init next screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = '' -- SKUDesc1
      SET @cOutField04 = '' -- SKUDesc2
      SET @cOutField15 = '' -- ExtendedInfo

      SET @cSKU = ''

      -- Go to next screen
      SET @nScn  = 4233
      SET @nStep = @nStep - 8
   END


   ---- Dynamic lottable
   --EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'CAPTURE', 'POPULATE', 5, 1,
   --   @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
   --   @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
   --   @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
   --   @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
   --   @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
   --   @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
   --   @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
   --   @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
   --   @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
   --   @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
   --   @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
   --   @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
   --   @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
   --   @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
   --   @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
   --   @nMorePage   OUTPUT,
   --   @nErrNo      OUTPUT,
   --   @cErrMsg     OUTPUT,
   --   @cRefNo,
   --   @nFunc

   --IF @nErrNo <> 0
   --   GOTO Quit

   --IF @nMorePage = 1 -- Yes
   --BEGIN
   --   -- Go to dynamic lottable screen
   --   SET @nFromScn = @nScn
   --   SET @nScn = 3990
   --   SET @nStep = @nStep - 7
   --END
   --ELSE
   --BEGIN
   --   -- Get SKU info
   --   SELECT
   --      @cSKUDesc = IsNULL( DescR, ''),
   --      @cIVAS = IsNULL( IVAS, ''),
   --      @cLottableCode = LottableCode,
   --      @cMUOM_Desc = Pack.PackUOM3,
   --      @cPUOM_Desc =
   --         CASE @cPUOM
   --            WHEN '2' THEN Pack.PackUOM1 -- Case
   --            WHEN '3' THEN Pack.PackUOM2 -- Inner pack
   --            WHEN '6' THEN Pack.PackUOM3 -- Master unit
   --            WHEN '1' THEN Pack.PackUOM4 -- Pallet
   --            WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
   --            WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
   --         END,
   --         @nPUOM_Div = CAST( IsNULL(
   --         CASE @cPUOM
   --            WHEN '2' THEN Pack.CaseCNT
   --            WHEN '3' THEN Pack.InnerPack
   --            WHEN '6' THEN Pack.QTY
   --            WHEN '1' THEN Pack.Pallet
   --            WHEN '4' THEN Pack.OtherUnit1
   --            WHEN '5' THEN Pack.OtherUnit2
   --         END, 1) AS INT)
   --   FROM dbo.SKU SKU WITH (NOLOCK)
   --      INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
   --   WHERE SKU.StorerKey = @cStorerKey
   --      AND SKU.SKU = @cSKU

   --   -- Convert to prefer UOM QTY
   --   IF @cPUOM = '6' OR -- When preferred UOM = master unit
   --      @nPUOM_Div = 0  -- UOM not setup
   --   BEGIN
   --      SET @cPUOM_Desc = ''
   --      SET @nPQTY = 0
   --      SET @nMQTY = @nQTY
   --      SET @cFieldAttr08 = 'O' -- @nPQTY
   --   END
   --   ELSE
   --   BEGIN
   --      SET @nPQTY = @nQTY / @nPUOM_Div -- Calc QTY in preferred UOM
   --      SET @nMQTY = @nQTY % @nPUOM_Div -- Calc the remaining in master unit
   --      SET @cFieldAttr08 = '' -- @nPQTY
   --   END

   --   -- Prepare next screen variable
   --   SET @cOutField01 = @cSKU
   --   SET @cOutField02 = rdt.rdtFormatString( @cSKUDesc, 1, 20)
   --   SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
   --   SET @cOutField04 = SUBSTRING( @cIVAS, 1, 20)
   --   SET @cOutField05 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
   --   SET @cOutField06 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
   --   SET @cOutField07 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
   --   SET @cOutField08 = CASE WHEN @nPQTY = 0 OR @cFieldAttr08 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 7)) END -- PQTY
   --   SET @cOutField09 = CASE WHEN @nMQTY = 0 THEN '' ELSE CAST( @nMQTY AS NVARCHAR( 7)) END -- MQTY
   --   SET @cOutField10 = '' -- ConditionCode
   --   SET @cOutField11 = '' -- SubReasonCode
   --   SET @cOutField15 = '' -- ExtendedInfo

   --   IF @cFieldAttr08 = ''
   --      EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY

   --   -- Go to QTY screen
   --   SET @nScn = 4035
   --   SET @nStep = @nStep - 6

   --   -- Extended info
   --   IF @cExtendedInfoSP <> ''
   --   BEGIN
   --      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
   --      BEGIN
   --         SET @cExtendedInfo = ''
   --         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
   --            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, ' +
   --            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
   --            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
   --            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
   --            ' @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber, ' +
   --            ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
   --         SET @cSQLParam =
   --            '@nMobile       INT,           ' +
   --            '@nFunc         INT,           ' +
   --            '@cLangCode     NVARCHAR( 3),  ' +
   --            '@nStep         INT,           ' +
   --            '@nAfterStep    INT,           ' +
   --            '@nInputKey     INT,           ' +
   --            '@cFacility     NVARCHAR( 5),  ' +
   --            '@cStorerKey    NVARCHAR( 15), ' +
   --            '@cRefNo        NVARCHAR( 20), ' +
   --            '@cColumnName   NVARCHAR( 20), ' +
   --            '@cLOC          NVARCHAR( 10), ' +
   --            '@cID           NVARCHAR( 18), ' +
   --            '@cSKU          NVARCHAR( 20), ' +
   --            '@cLottable01   NVARCHAR( 18), ' +
   --            '@cLottable02   NVARCHAR( 18), ' +
   --            '@cLottable03   NVARCHAR( 18), ' +
   --            '@dLottable04   DATETIME,      ' +
   --            '@dLottable05   DATETIME,      ' +
   --            '@cLottable06   NVARCHAR( 30), ' +
   --            '@cLottable07   NVARCHAR( 30), ' +
   --            '@cLottable08   NVARCHAR( 30), ' +
   --            '@cLottable09   NVARCHAR( 30), ' +
   --            '@cLottable10   NVARCHAR( 30), ' +
   --            '@cLottable11   NVARCHAR( 30), ' +
   --            '@cLottable12   NVARCHAR( 30), ' +
   --            '@dLottable13   DATETIME,      ' +
   --            '@dLottable14   DATETIME,      ' +
   --            '@dLottable15   DATETIME,      ' +
   --            '@nQTY          INT,           ' +
   --            '@cReasonCode   NVARCHAR( 10), ' +
   --            '@cSuggToLOC    NVARCHAR( 10), ' +
   --            '@cFinalLOC     NVARCHAR( 10), ' +
   --            '@cReceiptKey   NVARCHAR( 10), ' +
   --            '@cReceiptLineNumber NVARCHAR( 10),   ' +
   --            '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +
   --            '@nErrNo        INT           OUTPUT, ' +
   --            '@cErrMsg       NVARCHAR( 20) OUTPUT'

   --         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
   --            @nMobile, @nFunc, @cLangCode, 4, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU,
   --            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
   --            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
   --            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
   --            @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber,
   --            @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

   --         IF @nErrNo <> 0
   --            GOTO Step_3_Fail

   --         SET @cOutField15 = @cExtendedInfo
   --      END
   --   END
   --END
END

GOTO Quit

/********************************************************************************
Step 13. Scn = 4234. UCC Pallet ID screen
   Ref No (field01)
   UCC    (field02)
   TO ID  (field03, input)
********************************************************************************/
Step_13:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cID = @cInField03 -- ID

       -- Check barcode format
      IF @cID =''
      BEGIN
         SET @nErrNo = 55935
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID IS Require
         GOTO Step_13_Fail
      END

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cBarcode) = 0
      BEGIN
         SET @nErrNo = 55932
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_13_Fail
      END

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
            SET @nErrNo = 55933
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Duplicate ID
            GOTO Step_13_Fail
         END
      END

      -- Check pallet received
      IF @cCheckPLTID = '1'
      BEGIN
         IF EXISTS (SELECT 1
            FROM rdt.rdtConReceiveLog CRL WITH (NOLOCK)
               JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (RD.ReceiptKey = CRL.ReceiptKey)
            WHERE CRL.Mobile = @nMobile
               AND RD.ToID = @cID
               AND RD.BeforeReceivedQty > 0)
         BEGIN
            SET @nErrNo = 55934
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID received
            GOTO Step_13_Fail
         END
      END

       -- Get UOM
      SELECT @cUOM = PackUOM3
      FROM dbo.SKU WITH (NOLOCK)
         JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cRefNo       NVARCHAR( 20), ' +
               '@cColumnName  NVARCHAR( 20), ' +
               '@cLOC         NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
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
               '@cSuggToLOC   NVARCHAR( 10), ' +
               '@cFinalLOC    NVARCHAR( 10), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10), ' +
               '@nErrNo             INT            OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_13_Fail
         END
      END

      -- Custom receiving logic
      IF @cRcptConfirmSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cRcptConfirmSP) +
            ' @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, @cRefNo, @cColumnName, @cToLOC, @cToID, ' +
            ' @cSKUCode, @cSKUUOM, @nSKUQTY, @cUCC, @cUCCSKU, @nUCCQTY, @cCreateUCC, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @nNOPOFlag, @cConditionCode, @cSubreasonCode, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @cReceiptKeyOutput OUTPUT, @cReceiptLineNumberOutput OUTPUT '

         SET @cSQLParam =
            '@nFunc          INT,            ' +
            '@nMobile        INT,            ' +
            '@cLangCode      NVARCHAR( 3),   ' +
            '@cStorerKey     NVARCHAR( 15),  ' +
            '@cFacility      NVARCHAR( 5),   ' +
            '@cRefNo         NVARCHAR( 20),  ' +
            '@cColumnName    NVARCHAR( 20),  ' +
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
            '@nErrNo         INT              OUTPUT, ' +
            '@cErrMsg        NVARCHAR( 20)    OUTPUT, ' +
            '@cReceiptKeyOutput NVARCHAR( 20) OUTPUT, ' +
            '@cReceiptLineNumberOutput NVARCHAR( 20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, @cRefNo, @cColumnName, @cLOC, @cID,
            @cSKU, @cUOM, @nQTY, '', '', 0, '',
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, NULL,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            1, @cReasonCode, @cSubreasonCode,
            @nErrNo OUTPUT, @cErrMsg OUTPUT, @cReceiptKey OUTPUT, @cReceiptLineNumber OUTPUT
      END
      ELSE
      BEGIN
         -- Receive
         EXEC rdt.rdt_ConReceive
            @nFunc         = @nFunc,
            @nMobile       = @nMobile,
            @cLangCode     = @cLangCode,
            @nErrNo        = @nErrNo OUTPUT,
            @cErrMsg       = @cErrMsg OUTPUT,
            @cStorerKey    = @cStorerKey,
            @cFacility     = @cFacility,
            @cRefNo        = @cRefNo,
            @cColumnName   = @cColumnName,
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
            @dLottable05   = NULL,
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
            @nNOPOFlag     = 1,
            @cConditionCode = @cReasonCode,
            @cSubreasonCode = @cSubreasonCode,
            @cReceiptKeyOutput = @cReceiptKey OUTPUT,
            @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT
      END

      IF @nErrNo <> 0
         GOTO Quit

      -- Extended validate
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cRefNo       NVARCHAR( 20), ' +
               '@cColumnName  NVARCHAR( 20), ' +
               '@cLOC         NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
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
               '@cSuggToLOC   NVARCHAR( 10), ' +
               '@cFinalLOC    NVARCHAR( 10), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10), ' +
               '@nErrNo             INT            OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cRefNo, @cColumnName, @cLOC, @cID, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nQTY, @cReasonCode, @cSuggToLOC, @cFinalLOC, @cReceiptKey, @cReceiptLineNumber,
               @nErrNo OUTPUT, @cErrMsg OUTPUT
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
         @cLocation     = @cLOC,
         @cID           = @cID,
         @cSKU          = @cSKU,
         @cUOM          = @cUOM,
         @nQTY          = @nQTY,
         @cRefNo1       = @cRefNo,
         @cRefNo2       = @cColumnName,
         @cRefNo3       = @cReasonCode,
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
         @dLottable15   = @dLottable15




      -- Init next screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = @cSKU -- SKU
      SET @cOutField03 = '' -- SKUDesc1
      SET @cOutField04 = '' -- SKUDesc2
      SET @cOutField15 = '' -- ExtendedInfo

      -- Go to Msg scn
      SET @nScn = 4236
      SET @nStep = @nStep - 6
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = '' --toID
      SET @cOutField02 = '' --Sku/UCCC
      SET @cOutField03 = '' --Sku desc
      SET @cOutField04 = '' --Sku desc

      --go to SKU screen
      SET @nScn = 4233
      SET @nStep = @nStep - 9
   END
   GOTO Quit

   Step_13_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField02 = '' -- ID
      SET @cID = ''
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

      StorerKey    = @cStorerKey,
      Facility     = @cFacility,
      Printer      = @cPrinter,
      -- UserName     = @cUserName,

      V_UOM        = @cPUOM,
      V_ReceiptKey = @cReceiptKey,
      V_POKey      = @cPOKey,
      V_Loc        = @cLOC,
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

      V_Integer1   = @nPUOM_Div ,
      V_Integer2   = @nPQTY,
      V_Integer3   = @nMQTY,
      V_Integer4   = @nQTY,
      V_Integer5   = @nFromScn,
      V_Integer6   = @nPABookingKey,

      V_String1    = @cRefNo,
      V_String2    = @cIVAS,
      V_String3    = @cLottableCode,
      V_String4    = @cReasonCode,
      V_String5    = @cSuggToLOC,
      V_String6    = @cFinalLOC,
      V_String7    = @cReceiptLineNumber,
      V_String8    = @cPalletRecv,
      V_String9    = @cSubreasonCode,

      V_String10   = @cMUOM_Desc,
      V_String11   = @cPUOM_Desc,
      V_String12   = @cDefaultReceiveQty,
      V_String13   = @cFlowThruQtyScreen,

      V_String21   = @cColumnName,
      V_String22   = @cDefaultToLOC,
      V_String23   = @cCheckPLTID,
      V_String24   = @cAutoGenID,
      V_String25   = @cGetReceiveInfoSP,
      V_String26   = @cDecodeSP,
      V_String27   = @cAddSKUtoASN,
      V_String28   = @cVerifySKU,
      V_String29   = @cPalletRecvSP,
      V_String30   = @cExtendedValidateSP,
      V_String31   = @cExtendedUpdateSP,
      V_String32   = @cRcptConfirmSP,
      V_String33   = @cExtendedInfoSP,
      V_String34   = @cExtendedInfo,
      V_String35   = @cPutawaySP,
      V_String36   = @cPutaway,
      V_String37   = @cMultiSKUBarcode, --(cc01)
      V_String38   = @cReceiveDefaultToLoc,
      V_String39   = @cGotoUccIDScn,   --(cc02)
      V_String41   = @cBarcode,        --(cc02)
      V_String42   = @cColumnName,

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