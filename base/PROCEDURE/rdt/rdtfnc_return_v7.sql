SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Store procedure: rdtfnc_Return_V7                                          */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Work the same as Exceed Trade Return                              */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2015-09-10   1.0  Ung        Migrated from 552                             */
/* 2017-01-04   1.1  Ung        WMS-632 Fix NOPO                              */
/* 2016-09-30   1.2  Ung        Performance tuning                            */
/* 2017-07-10   1.3  Ung        WMS-2369 Code lookup ASNREASON add StorerKey  */
/*                              RefNo support SP                              */
/* 2017-09-11   1.4  Ung        WMS-2948 Clear ASN field                      */
/* 2017-10-06   1.5  Ung        WMS-3159 Clear RefNo field                    */
/* 2018-02-26   1.6  ChewKp     WMS-3836 Fixes (ChewKP01)                     */
/* 2018-10-16   1.7  Gan        Performance tuning                            */
/* 2018-02-26   1.8  James      WMS-8069 Add flow thru screen (james01)       */
/* 2019-09-25   1.9  YeeKung    WMS-10667 Suggtoloc (yeekung01)               */
/* 2021-03-03   2.0  James      WMS-16415 Add config make reason code to be   */
/*                              mandatory (james02)                           */
/* 2021-10-14   2.1  YeeKung    JSM-25174 Add error =2 in multisku (yeekung02)*/
/* 2023-07-26   2.2  James      WMS-23005 Add capture data (james03)          */
/*                              Add ToLoc Diff screen                         */
/******************************************************************************/
CREATE   PROC [RDT].[rdtfnc_Return_V7](
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
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
   @nTotalQTYExp        INT,
   @nTotalQTYRcv        INT,
   @nMorePage           INT,
   @cBarcode            NVARCHAR( 60),
   @cSQL                NVARCHAR( MAX),
   @cSQLParam           NVARCHAR( MAX)

-- RDT.RDTMobRec variables
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,

   @cStorerGroup        NVARCHAR( 20),
   @cStorerKey          NVARCHAR( 15),
   @cUserName           NVARCHAR( 18),
   @cFacility           NVARCHAR( 5),

   @cPUOM               NVARCHAR(  1),
   @cReceiptKey         NVARCHAR( 10),
   @cPOKey              NVARCHAR( 10),
   @cLOC                NVARCHAR( 10),
   @cID                 NVARCHAR( 18),
   @cSKU                NVARCHAR( 60),
   @cSKUDesc            NVARCHAR( 60),
   @cQTY                NVARCHAR( 5),
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

   @cRefNo              NVARCHAR( 20),
   @cIVASDesc           NVARCHAR( 20),
   @cLottableCode       NVARCHAR( 30),
   @cReasonCode         NVARCHAR( 10),
   @cSuggID             NVARCHAR( 18),
   @cSuggLOC            NVARCHAR( 10),
   @cReceiptLineNumber  NVARCHAR( 5),

   @cPUOM_Desc          NVARCHAR( 5),
   @cMUOM_Desc          NVARCHAR( 5),
   @nPUOM_Div           INT,
   @nPQTY               INT,
   @nMQTY               INT,
   @nQTY                INT,

   @cDefaultToLOC       NVARCHAR( 20),
   @cGetReceiveInfoSP   NVARCHAR( 20),
   @cDecodeSKUSP        NVARCHAR( 20),
   @cVerifySKU          NVARCHAR( 1),
   @cRcptConfirmSP      NVARCHAR( 20),
   @cExtendedPutawaySP  NVARCHAR( 20),
   @cOverrideSuggestID  NVARCHAR( 1),
   @cOverrideSuggestLOC NVARCHAR( 1),
   @cDefaultIDAsSuggID  NVARCHAR( 1),
   @cDefaultLOCAsSuggLOC NVARCHAR( 1),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cMultiSKUBarcode    NVARCHAR( 1),
   @cCheckSKUInASN      NVARCHAR( 1),
   @cDefaultQTY         NVARCHAR( 5),
   @cFlowThruQtyScn     NVARCHAR( 1),
   @cReasonCodeMandatory   NVARCHAR(1),
   @cCaptureReceiptInfoSP  NVARCHAR( 20),
   @tCaptureVar         VARIABLETABLE,
   @cData1                 NVARCHAR( 60),
   @cData2                 NVARCHAR( 60),
   @cData3                 NVARCHAR( 60),
   @cData4                 NVARCHAR( 60),
   @cData5                 NVARCHAR( 60),
   @cOption                NVARCHAR( 1),
   
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

   @cStorerGroup  = StorerGroup,
   @cFacility     = Facility,
   @cUserName     = UserName,

   @cStorerKey    = V_StorerKey,
   @cPUOM         = V_UOM,
   @cReceiptKey   = V_ReceiptKey,
   @cPOKey        = V_POKey,
   @cLOC          = V_LOC,
   @cID           = V_ID,
   @cSKU          = V_SKU,
   @cSKUDesc      = V_SKUDescr,
   @cQTY          = V_QTY,
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

   @nPUOM_Div     = V_PUOM_Div,
   @nPQTY         = V_PQTY,
   @nMQTY         = V_MQTY,

   @nQTY          = V_Integer1,

   @cRefNo        = V_String1,
   @cIVASDesc     = V_String2,
   @cLottableCode = V_String3,
   @cReasonCode   = V_String4,
   @cSuggID       = V_String5,
   @cSuggLOC      = V_String6,
   @cReceiptLineNumber     = V_String7,
   @cFlowThruQtyScn        = V_String8,
   @cCaptureReceiptInfoSP  = V_String9,
   @cMUOM_Desc    = V_String10,
   @cPUOM_Desc    = V_String11,
  -- @nPUOM_Div     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String12, 5), 0) = 1 THEN LEFT( V_String12, 5) ELSE 0 END,
  -- @nPQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String13, 5), 0) = 1 THEN LEFT( V_String13, 5) ELSE 0 END,
  -- @nMQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String14, 5), 0) = 1 THEN LEFT( V_String14, 5) ELSE 0 END,
  -- @nQTY          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15, 5), 0) = 1 THEN LEFT( V_String15, 5) ELSE 0 END,

   @cDefaultToLOC       = V_String21,
   @cGetReceiveInfoSP   = V_String22,
   @cDecodeSKUSP        = V_String23,
   @cVerifySKU          = V_String24,
   @cRcptConfirmSP      = V_String25,
   @cExtendedPutawaySP  = V_String26,
   @cOverrideSuggestID  = V_String27,
   @cOverrideSuggestLOC = V_String28,
   @cDefaultIDAsSuggID  = V_String29,
   @cDefaultLOCAsSuggLOC = V_String30,
   @cExtendedInfoSP     = V_String31,
   @cExtendedInfo       = V_String32,
   @cExtendedValidateSP = V_String33,
   @cExtendedUpdateSP   = V_String34,
   @cMultiSKUBarcode    = V_String35,
   @cCheckSKUInASN      = V_String36,
   @cDefaultQTY         = V_String37,
   @cReasonCodeMandatory= V_String38,

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
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08  =FieldAttr08,
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
   @nStep_ASNPO         INT,  @nScn_ASNPO       INT,
   @nStep_SKU           INT,  @nScn_SKU         INT,
   @nStep_QTY           INT,  @nScn_QTY         INT,
   @nStep_Lottables     INT,  @nScn_Lottables   INT,
   @nStep_IDLOC         INT,  @nScn_IDLOC       INT,
   @nStep_VerifySKU     INT,  @nScn_VerifySKU   INT,
   @nStep_MultiSKU      INT,  @nScn_MultiSKU    INT,
   @nStep_CaptureData   INT,  @nScn_CaptureData INT,
   @nStep_ToLocDiff     INT,  @nScn_ToLocDiff   INT

SELECT
   @nStep_ASNPO         = 1,  @nScn_ASNPO       = 4270,
   @nStep_SKU           = 2,  @nScn_SKU         = 4271,
   @nStep_QTY           = 3,  @nScn_QTY         = 4272,
   @nStep_Lottables     = 4,  @nScn_Lottables   = 3990,
   @nStep_IDLOC         = 5,  @nScn_IDLOC       = 4274,
   @nStep_VerifySKU     = 6,  @nScn_VerifySKU   = 3951,
   @nStep_MultiSKU      = 7,  @nScn_MultiSKU    = 3570,
   @nStep_CaptureData   = 8,  @nScn_CaptureData = 4275,
   @nStep_ToLocDiff     = 9,  @nScn_ToLocDiff   = 4276

IF @nFunc = 607
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start       -- Menu. 607
   IF @nStep = 1  GOTO Step_ASNPO       -- Scn = 4270. ASN, PO, RefNo
   IF @nStep = 2  GOTO Step_SKU         -- Scn = 4271. SKU
   IF @nStep = 3  GOTO Step_QTY         -- Scn = 4272. QTY
   IF @nStep = 4  GOTO Step_Lottables   -- Scn = 3990. Lottable
   IF @nStep = 5  GOTO Step_IDLOC       -- Scn = 4274. ID, LOC
   IF @nStep = 6  GOTO Step_VerifySKU   -- Scn = 3951. Verify SKU
   IF @nStep = 7  GOTO Step_MultiSKU    -- Scn = 3570. Multi SKU
   IF @nStep = 8  GOTO Step_CaptureData -- Scn = 4275. Capture data
   IF @nStep = 9  GOTO Step_ToLocDiff   -- Scn = 4276. ToLoc Diff
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step_Start. Func = 607
********************************************************************************/
Step_Start:
BEGIN
   -- Get default UOM
   SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName

   -- Get storer config
   DECLARE @cPOKeyDefaultValue NVARCHAR( 10)
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
   SET @cOutField03 = '' -- RefNo

   -- Set the entry point
   SET @nScn = @nScn_ASNPO
   SET @nStep = @nStep_ASNPO
END
GOTO Quit


/************************************************************************************
Step 1. Scn = 4270. ASN, PO, Container No screen
   ASN          (field01, input)
   PO           (field02, input)
   REF NO       (field03, input)
************************************************************************************/
Step_ASNPO:
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

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cColumnName AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cColumnName) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerGroup, @cStorerKey, ' +
               ' @cReceiptKey OUTPUT, @cPOKey OUTPUT, @cRefNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cStorerGroup NVARCHAR( 20), ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cReceiptKey  NVARCHAR( 10)  OUTPUT, ' +
               ' @cPOKey       NVARCHAR( 10)  OUTPUT, ' +
               ' @cRefNo       NVARCHAR( 20)  OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerGroup, @cStorerKey,
               @cReceiptKey OUTPUT, @cPOKey OUTPUT, @cRefNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            SET @cOutField01 = @cReceiptKey
            SET @cOutField02 = @cPOKey
            SET @cOutField03 = @cRefNo
         END
         ELSE
         BEGIN
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
                  SET @nErrNo = 56651
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
                  ' @cRefNo       NVARCHAR(20), ' +
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
                  SET @nErrNo = 56652
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN
                  GOTO Quit
               END

               -- Check RefNo in ASN
               IF @nRowCount > 1
               BEGIN
                  SET @nErrNo = 56653
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo MultiASN
                  EXEC rdt.rdtSetFocusField @nMobile, 3 -- ContainerKey
                  GOTO Quit
               END

               SET @cOutField01 = @cReceiptKey
               SET @cOutField03 = @cRefNo
            END
         END
      END

      -- Validate at least one field must key-in
      IF (@cReceiptKey = '' OR @cReceiptKey IS NULL) AND
         (@cPOKey = '' OR @cPOKey IS NULL OR @cPOKey = 'NOPO') -- SOS76264
      BEGIN
         SET @nErrNo = 56654
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
               SET @nErrNo = 56655
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
               SET @nErrNo = 56656
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
               SET @nErrNo = 56657
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
               SET @nErrNo = 56658
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
                  SET @nErrNo = 56659
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
                  SET @nErrNo = 56660
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
                  SET @nErrNo = 56661
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PO not exist
                  SET @cOutField02 = '' -- POKey
                  SET @cPOKey = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 2
                  GOTO Quit
               END

               IF @nRowCount > 1
               BEGIN
                  SET @nErrNo = 56662
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
         SET @nErrNo = 56663
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
            SET @nErrNo = 56664
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
         SET @nErrNo = 56665
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
         SET @cOutField01 = '' -- ReceiptKey
         SET @cReceiptKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Validate ASN status
      IF @cReceiptStatus = '9'
      BEGIN
         SET @nErrNo = 56666
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN is closed
         SET @cOutField01 = '' -- ReceiptKey
         SET @cReceiptKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Check ASN cancelled
      IF @cReceiptStatus = 'CANC'
      BEGIN
         SET @nErrNo = 56667
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN cancelled
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = '' -- ReceiptKey
         SET @cReceiptKey = ''
         GOTO Quit
      END

      -- Get storer config
      SET @cOverrideSuggestID = rdt.RDTGetConfig( @nFunc, 'OverrideSuggestID', @cStorerKey)
      SET @cOverrideSuggestLOC = rdt.RDTGetConfig( @nFunc, 'OverrideSuggestLOC', @cStorerKey)
      SET @cDefaultIDAsSuggID = rdt.RDTGetConfig( @nFunc, 'DefaultIDAsSuggID', @cStorerKey)
      SET @cDefaultLOCAsSuggLOC = rdt.RDTGetConfig( @nFunc, 'DefaultLOCAsSuggLOC', @cStorerKey)
      SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)
      SET @cCheckSKUInASN = rdt.RDTGetConfig( @nFunc, 'CheckSKUInASN', @cStorerKey)
      SET @cVerifySKU = rdt.RDTGetConfig( @nFunc, 'VerifySKU', @cStorerKey)

      SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)
      IF @cDefaultQTY = '0'
         SET @cDefaultQTY = ''
      SET @cDefaultToLOC = rdt.RDTGetConfig( @nFunc, 'ReturnDefaultToLOC', @cStorerKey)
      IF @cDefaultToLOC = '0'
         SET @cDefaultToLOC = ''
      SET @cRcptConfirmSP = rdt.RDTGetConfig( @nFunc, 'ReceiptConfirm_SP', @cStorerKey)
      IF @cRcptConfirmSP = '0'
         SET @cRcptConfirmSP = ''
      SET @cGetReceiveInfoSP = rdt.RDTGetConfig( @nFunc, 'GetReceiveInfoSP', @cStorerKey)
      IF @cGetReceiveInfoSP = '0'
         SET @cGetReceiveInfoSP = ''
      SET @cDecodeSKUSP = rdt.RDTGetConfig( @nFunc, 'DecodeSKUSP', @cStorerKey)
      IF @cDecodeSKUSP = '0'
         SET @cDecodeSKUSP = ''
      SET @cExtendedPutawaySP = rdt.RDTGetConfig( @nFunc, 'ExtendedPutawaySP', @cStorerKey)
      IF @cExtendedPutawaySP = '0'
         SET @cExtendedPutawaySP = ''
      SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
      IF @cExtendedInfoSP = '0'
         SET @cExtendedInfoSP = ''
      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''

      SET @cFlowThruQtyScn = rdt.RDTGetConfig( @nFunc, 'FlowThruQtyScn', @cStorerKey)

      SET @cReasonCodeMandatory = rdt.RDTGetConfig( @nFunc, 'ReasonCodeMandatory', @cStorerKey)

      SET @cCaptureReceiptInfoSP = rdt.RDTGetConfig( @nFunc, 'CaptureReceiptInfoSP', @cStorerKey)
      IF @cCaptureReceiptInfoSP = '0'
         SET @cCaptureReceiptInfoSP = ''
      
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
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
               '@cRefNo        NVARCHAR( 20), ' +
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
               '@cReasonCode   NVARCHAR( 10), ' +
               '@cSuggID       NVARCHAR( 18), ' +
               '@cSuggLOC      NVARCHAR( 10), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10),   ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_SKU_Fail
         END
      END
      
      -- Capture ASN Info
      IF @cCaptureReceiptInfoSP <> ''
      BEGIN
         EXEC rdt.rdt_Return_V7_CaptureInfo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'DISPLAY',
            @cReceiptKey, @cRefNo, @cID, @cLOC, @cData1, @cData2, @cData3, @cData4, @cData5,
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
            @tCaptureVar,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Go to next screen
         SET @nScn = @nScn_CaptureData
         SET @nStep = @nStep_CaptureData

         GOTO Quit
      END
      
      -- Get statistic
      IF @cPOKey = 'NOPO'
         SELECT
            @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
            @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
      ELSE
         SELECT
            @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
            @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND POKey = @cPOKey

      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- Desc1
      SET @cOutField05 = '' -- Desc2
      SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
      SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to next screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
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


/***********************************************************************************
Step 2. Scn = 4271. SKU screen
   ASN   (field01)
   PO    (field02)
   SKU   (field03, input)
   Desc1 (field04)
   Desc2 (field05)
   Scan/Expected QTY (field06)
***********************************************************************************/
Step_SKU:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField03 -- SKU
      SET @cBarcode = @cInField03

      -- Validate blank
      IF @cSKU = '' OR @cSKU IS NULL
      BEGIN
         SET @nErrNo = 56668
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU needed
         GOTO Step_SKU_Fail
      END

      -- Init var (due to var pass out by DecodeSKUSP, GetReceiveInfoSP is not reset)
      SELECT @nQTY = 0,
         @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL, @dLottable05 = NULL,
         @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',   @cLottable10 = '',
         @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL, @dLottable15 = NULL

      -- Decode
      IF @cDecodeSKUSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSKUSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSKUSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, @cBarcode, ' +
               ' @cSKU        OUTPUT, @nQTY        OUTPUT, ' +
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
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, @cBarcode,
               @cSKU        OUTPUT, @nQTY        OUTPUT,
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_SKU_Fail
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
         SET @nErrNo = 56669
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO Step_SKU_Fail
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
            ELSE IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
               SET @nErrNo = 0
            ELSE
            BEGIN
               SET @nErrNo = 56690
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
               GOTO Step_SKU_Fail
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 56686
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
            GOTO Step_SKU_Fail
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
            SET @nErrNo = 56687
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not in ASN
            GOTO Step_SKU_Fail
         END
      END

      -- Get SKU info
      DECLARE @cIVAS NVARCHAR( 30)
      SELECT
         @cSKUDesc = ISNULL( DescR, ''),
         @cIVAS = ISNULL( IVAS, ''),
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

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @nMQTY = @nQTY
      END
      ELSE
      BEGIN
         SET @nPQTY = @nQTY / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY = @nQTY % @nPUOM_Div -- Calc the remaining in master unit
      END

      -- Get IVAS
      SET @cIVASDesc = ''
      IF @cIVAS <> ''
      BEGIN
         SELECT TOP 1
            @cIVASDesc = LEFT( CodeLkUp.Description, 20)
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'IVAS'
            AND Code = @cIVAS
      END

      -- Retain value
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20) -- SKU desc 2

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
               '@cRefNo        NVARCHAR( 20), ' +
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
               '@cReasonCode   NVARCHAR( 10), ' +
               '@cSuggID       NVARCHAR( 18), ' +
               '@cSuggLOC      NVARCHAR( 10), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10),   ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_SKU_Fail
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
            SET @nScn = 3951
            SET @nStep = @nStep_VerifySKU

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
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END
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
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, ' +
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
               ' @cReceiptKey  NVARCHAR( 10), ' +
               ' @cPOKey       NVARCHAR( 10), ' +
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
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC,
               @cID         OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT,
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_SKU_Fail
         END
      END

      -- Enable / disable PQTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
         SET @cFieldAttr08 = 'O' -- @nPQTY
      ELSE
         SET @cFieldAttr08 = '' -- @nPQTY

      -- Prepare next screen variable
      SET @cOutField01 = @cSKU
      SET @cOutField02 = rdt.rdtFormatString( @cSKUDesc, 1, 20)
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
      SET @cOutField04 = @cIVASDesc
      SET @cOutField05 = '1:' + CAST( @nPUOM_Div AS NCHAR( 5))
      SET @cOutField06 = @cPUOM_Desc
      SET @cOutField07 = @cMUOM_Desc
      SET @cOutField08 = '' -- PQTY
      SET @cOutField09 = CASE WHEN @cDefaultQTY <> '' THEN @cDefaultQTY ELSE '' END -- MQTY

      -- Extended info -- (ChewKP01)
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
               '@cRefNo        NVARCHAR( 20), ' +
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
               '@cReasonCode   NVARCHAR( 10), ' +
               '@cSuggID       NVARCHAR( 18), ' +
               '@cSuggLOC      NVARCHAR( 10), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10),   ' +
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_SKU, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END
      ELSE
      BEGIN
         SET @cOutField15 = '' -- ExtendedInfo
      END



      IF @cFieldAttr08 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY

      -- Go to QTY screen
      SET @nScn = @nScn_QTY
      SET @nStep = @nStep_QTY
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Capture ASN Info
      IF @cCaptureReceiptInfoSP <> ''
      BEGIN
         EXEC rdt.rdt_Return_V7_CaptureInfo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'DISPLAY',
            @cReceiptKey, @cRefNo, @cID, @cLOC, @cData1, @cData2, @cData3, @cData4, @cData5,
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
            @tCaptureVar,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Go to next screen
         SET @nScn = @nScn_CaptureData
         SET @nStep = @nStep_CaptureData

         GOTO Quit
      END

      -- Prepare prev screen var
      SET @cOutField01 = '' -- @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = '' -- @cRefNo

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey

      -- Go to prev screen
      SET @nScn = @nScn_ASNPO
      SET @nStep = @nStep_ASNPO
   END

   Step_SKU_Quit:
   BEGIN
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
               '@cRefNo        NVARCHAR( 20), ' +
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
               '@cReasonCode   NVARCHAR( 10), ' +
               '@cSuggID       NVARCHAR( 18), ' +
               '@cSuggLOC      NVARCHAR( 10), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10),   ' +
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_SKU, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END
   END
   -- (james01)
   -- Next screen qty value already available
   -- and flow thru screen config setup then direct go thru it
   -- DefaultQty setup then screen already have value
   IF @cDefaultQTY <> '' AND @nInputKey = 1
   BEGIN

      IF @cFlowThruQtyScn = '1'
      BEGIN
         SET @cInField09 = @cDefaultQTY
         GOTO Step_QTY  -- Forced to go qty screen directly
      END
   END

   GOTO Quit

   Step_SKU_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cOutField03 = '' -- SKU
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
      GOTO Quit
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 4272. QTY screen
   SKU       (field01)
   SKU desc  (field02)
   SKU desc  (field03)
   IVAS      (field04)
   UOM ratio (field05)
   PUOM      (field06)
   MUOM      (field07)
   PQTY      (field08, input)
   MQTY      (field09, input)
   Scan/Exp  (field10)
********************************************************************************/
Step_QTY:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cPQTY NVARCHAR( 5)
      DECLARE @cMQTY NVARCHAR( 5)

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
         SET @nErrNo = 56671
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY
         GOTO Quit
      END
      SET @nPQTY = CAST( @cPQTY AS INT)

      -- Validate MQTY
      IF @cMQTY <> '' AND RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 56672
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 9 -- MQTY
         GOTO Quit
      END
      SET @nMQTY = CAST( @cMQTY AS INT)

      -- Calc total QTY in master UOM
      SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nQTY = @nQTY + @nMQTY

      -- Validate QTY
      IF @nQTY = 0
      BEGIN
         SET @nErrNo = 56673
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         GOTO Quit
      END

      -- (james02)
      IF @cReasonCodeMandatory = '1' AND @cReasonCode = ''
      BEGIN
         SET @nErrNo = 56689
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cond. Code req
         GOTO Quit
      END

      -- Validate reason code exists
      IF @cReasonCode <> '' AND @cReasonCode IS NOT NULL
         IF NOT EXISTS( SELECT Code
            FROM dbo.CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'ASNREASON'
               AND Code = @cReasonCode
               AND StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 56674
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad ReasonCode
            EXEC rdt.rdtSetFocusField @nMobile, 10
            SET @cReasonCode = ''
            GOTO Quit
         END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
               '@cRefNo        NVARCHAR( 20), ' +
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
               '@cReasonCode   NVARCHAR( 10), ' +
               '@cSuggID       NVARCHAR( 18), ' +
               '@cSuggLOC      NVARCHAR( 10), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10),   ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @nErrNo OUTPUT, @cErrMsg OUTPUT

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
         SET @nScn = 3990
         SET @nStep = @nStep_Lottables
      END
      ELSE
      BEGIN
         SET @cSuggID = ''
         SET @cSuggLOC = ''

         -- Check need to putaway
         IF @cExtendedPutawaySP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPutawaySP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPutawaySP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @cReasonCode, @cID, @cLOC, @cReceiptLineNumber, @cSuggID OUTPUT, @cSuggLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile      INT,           ' +
                  '@nFunc        INT,           ' +
                  '@cLangCode    NVARCHAR( 3),  ' +
                  '@nStep        INT,           ' +
                  '@nInputKey    INT,           ' +
                  '@cStorerKey   NVARCHAR( 15), ' +
                  '@cReceiptKey  NVARCHAR( 10), ' +
                  '@cPOKey       NVARCHAR( 10), ' +
                  '@cRefNo       NVARCHAR( 20), ' +
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
                  '@cReasonCode  NVARCHAR( 10), ' +
                  '@cID          NVARCHAR( 18), ' +
                  '@cLOC         NVARCHAR( 10), ' +
                  '@cReceiptLineNumber NVARCHAR( 5),    ' +
                  '@cSuggID      NVARCHAR( 18)  OUTPUT, ' +
                  '@cSuggLOC     NVARCHAR( 10)  OUTPUT, ' +
                  '@nErrNo       INT            OUTPUT, ' +
                  '@cErrMsg      NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @cReasonCode, @cID, @cLOC, @cReceiptLineNumber, @cSuggID OUTPUT, @cSuggLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
            END
         END

         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
                  '@cRefNo        NVARCHAR( 20), ' +
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
                  '@cReasonCode   NVARCHAR( 10), ' +
                  '@cSuggID       NVARCHAR( 18), ' +
                  '@cSuggLOC      NVARCHAR( 10), ' +
                  '@cID           NVARCHAR( 18), ' +
                  '@cLOC          NVARCHAR( 10), ' +
                  '@cReceiptLineNumber NVARCHAR( 10),   ' +
                  '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +
                  '@nErrNo        INT           OUTPUT, ' +
                  '@cErrMsg       NVARCHAR( 20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep_SKU, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               SET @cOutField15 = @cExtendedInfo
            END
         END
         ELSE
         BEGIN
            SET @cOutField15 = '' -- ExtendedInfo
         END

         -- Prepare next screen variable
         SET @cOutField01 = @cSuggID
         SET @cOutField02 = CASE WHEN @cDefaultIDAsSuggID = '1' THEN @cSuggID ELSE '' END -- ID
         SET @cOutField03 = @cSuggLOC
         SET @cOutField04 = CASE WHEN @cDefaultLOCAsSuggLOC = '1' THEN @cSuggLOC ELSE @cDefaultToLOC  END -- LOC

         EXEC rdt.rdtSetFocusField @nMobile, 2 -- SuggID

         -- Go to next screen
         SET @nScn = @nScn_IDLOC
         SET @nStep = @nStep_IDLOC
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Get statistic
      IF @cPOKey = 'NOPO'
         SELECT
            @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
            @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
      ELSE
         SELECT
            @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
            @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND POKey = @cPOKey

      -- Prepare prev screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 1, 20)
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
      SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
      SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

      SET @cFieldAttr08 = '' -- PQTY
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to prev screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END
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

      SET @cSuggID = ''
      SET @cSuggLOC = ''

      -- Check need to putaway
      IF @cExtendedPutawaySP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPutawaySP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPutawaySP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cReasonCode, @cID, @cLOC, @cReceiptLineNumber, @cSuggID OUTPUT, @cSuggLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cPOKey       NVARCHAR( 10), ' +
               '@cRefNo       NVARCHAR( 20), ' +
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
               '@cReasonCode  NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
               '@cLOC         NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 5),    ' +
               '@cSuggID      NVARCHAR( 18)  OUTPUT, ' +
               '@cSuggLOC     NVARCHAR( 10)  OUTPUT, ' +
               '@nErrNo       INT            OUTPUT, ' +
               '@cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cReasonCode, @cID, @cLOC, @cReceiptLineNumber, @cSuggID OUTPUT, @cSuggLOC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         END
      END

      -- Prepare next screen variable
      SET @cOutField01 = @cSuggID
      SET @cOutField02 = CASE WHEN @cDefaultIDAsSuggID = '1' THEN @cSuggID ELSE '' END -- ID
      SET @cOutField03 = @cSuggLOC
      SET @cOutField04 = CASE WHEN @cDefaultLOCAsSuggLOC = '1' THEN @cSuggLOC ELSE @cDefaultToLOC  END -- LOC

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- SuggID

      -- Go to ID LOC screen
      SET @nScn = @nScn_IDLOC
      SET @nStep = @nStep_IDLOC
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

      IF @cFlowThruQtyScn = '1'
      BEGIN
         -- Get statistic
         IF @cPOKey = 'NOPO'
            SELECT
               @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
               @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
         ELSE
            SELECT
               @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
               @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
               AND POKey = @cPOKey

         -- Prepare next screen var
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @cPOKey
         SET @cOutField03 = '' -- SKU
         SET @cOutField04 = '' -- Desc1
         SET @cOutField05 = '' -- Desc2
         SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
         SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

         -- Go to next screen
         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU
      END
      ELSE
      BEGIN
         -- Enable / disable PQTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
            SET @cFieldAttr08 = 'O' -- @nPQTY
         ELSE
            SET @cFieldAttr08 = '' -- @nPQTY

         -- Prepare next screen variable
         SET @cOutField01 = @cSKU
         SET @cOutField02 = rdt.rdtFormatString( @cSKUDesc, 1, 20)
         SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
         SET @cOutField04 = @cIVASDesc
         SET @cOutField05 = '1:' + CAST( @nPUOM_Div AS NCHAR( 5))
         SET @cOutField06 = @cPUOM_Desc
         SET @cOutField07 = @cMUOM_Desc
         SET @cOutField08 = CASE WHEN @nPQTY = 0 OR @cFieldAttr08 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END -- PQTY
         SET @cOutField09 = CAST( @nMQTY AS NVARCHAR( 5)) -- MQTY
         SET @cOutField15 = '' -- ExtendedInfo

         IF @cFieldAttr08 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY

         -- Go to QTY screen
         SET @nScn = @nScn_QTY
         SET @nStep = @nStep_QTY
      END
   END

   Step_Lottables_Quit:
   BEGIN
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
               '@cRefNo        NVARCHAR( 20), ' +
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
               '@cReasonCode   NVARCHAR( 10), ' +
               '@cSuggID       NVARCHAR( 18), ' +
               '@cSuggLOC      NVARCHAR( 10), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10),   ' +
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_Lottables, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END
   END
END
GOTO Quit


/********************************************************************************
Step 5. Scn = 4274. ID, LOC screen
   SuggID  (field01)
   ID      (field02, input)
   SuggLOC (field03)
   LOC     (field04, input)
********************************************************************************/
Step_IDLOC:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cID = @cInField02 -- ID
      SET @cLOC = @cInField04 -- LOC

      -- Check different ID
      IF @cSuggID <> @cID AND @cSuggID <> ''
      BEGIN
         -- Check allow overwrite
         IF @cOverrideSuggestID <> '1'
         BEGIN
            SET @nErrNo = 56675
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff ID
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID
            SET @cOutField02 = ''
            GOTO Quit
         END
      END

      -- Check ID format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cID) = 0
      BEGIN
         SET @nErrNo = 56688
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID
         SET @cOutField02 = ''
         GOTO Quit
      END

      IF @cID <> ''
      BEGIN
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
         IF @cAuthority = '1'
         BEGIN
            IF EXISTS( SELECT [ID]
               FROM dbo.LOTxLOCxID LOTxLOCxID WITH (NOLOCK)
                  INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC)
               WHERE [ID] = @cID
                  AND QTY > 0
                  AND LOC.Facility = @cFacility)
            BEGIN
               SET @nErrNo = 56676
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Duplicate ID
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- ID
               SET @cOutField02 = ''
               GOTO Quit
            END
         END
         SET @cOutField02 = @cID
         -- (ChewKP02) Cursor to Next Input field
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC
      END

      -- Validate compulsary field
      IF @cLOC = ''
      BEGIN
         SET @nErrNo = 56677
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOC
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC
         SET @cOutField04 = ''
         GOTO Quit
      END

      -- Check ToLoc first before proceed to ToLoc Diff screen (if config turn on)
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
         SET @nErrNo = 56679
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC
         SET @cOutField04 = ''
         GOTO Quit
      END

      -- Validate location not in facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 56680
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC
         SET @cOutField04 = ''
         GOTO Quit
      END
      SET @cOutField04 = @cLOC
      
      -- Check different ID
      IF @cSuggLOC <> @cLOC AND @cSuggLOC <> ''
      BEGIN
         -- Check allow overwrite
         IF @cOverrideSuggestLOC <> '1'
         BEGIN
      	   -- Allow override suggested loc and prompt ToLoc Diff screen
      	   IF @cOverrideSuggestLOC = '2'
      	   BEGIN
      		   SET @cOption = ''
      		   SET @cOutField01  = ''
      		   
               -- Go to next screen
               SET @nScn = @nScn_ToLocDiff
               SET @nStep = @nStep_ToLocDiff
               
               GOTO Quit 
      	   END
      	   ELSE
      	   BEGIN
               SET @nErrNo = 56678
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff LOC
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC
               SET @cOutField04 = ''
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
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
               '@cRefNo        NVARCHAR( 20), ' +
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
               '@cReasonCode   NVARCHAR( 10), ' +
               '@cSuggID       NVARCHAR( 18), ' +
               '@cSuggLOC      NVARCHAR( 10), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10),   ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @nErrNo OUTPUT, @cErrMsg OUTPUT

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

      -- Handling transaction
      DECLARE @nTranCount INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_Return_V7 -- For rollback or commit only our own transaction

      -- Custom receiving logic
      IF @cRcptConfirmSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cRcptConfirmSP) +
            ' @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, @cToLOC, @cToID, ' +
            ' @cSKUCode, @cSKUUOM, @nSKUQTY, @cUCC, @cUCCSKU, @nUCCQTY, @cCreateUCC, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @nNOPOFlag, @cConditionCode, @cSubreasonCode, @cReceiptLineNumber OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

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
            '@cReceiptLineNumber NVARCHAR( 5) OUTPUT, ' +
            '@nErrNo         INT           OUTPUT, ' +
            '@cErrMsg        NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, @cLOC, @cID,
            @cSKU, @cUOM, @nQTY, '', '', 0, '',
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, NULL,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nNOPOFlag, @cReasonCode, '', @cReceiptLineNumber OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
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
            @nNOPOFlag     = @nNOPOFlag,
            @cConditionCode = @cReasonCode,
            @cSubreasonCode = '',
            @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT
      END

      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdtfnc_Return_V7
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
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
               '@cRefNo        NVARCHAR( 20), ' +
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
               '@cReasonCode   NVARCHAR( 10), ' +
               '@cSuggID       NVARCHAR( 18), ' +
               '@cSuggLOC      NVARCHAR( 10), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10),   ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_IDLOC, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_Return_V7
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Quit
            END
         END
      END

      COMMIT TRAN rdtfnc_Return_V7
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

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
         @cRefNo1       = @cReceiptKey, -- Retain for backward compatible
         @cRefNo2       = @cPOKey,      -- Retain for backward compatible
         @cRefNo3       = @cRefNo,
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

      -- Get statistic
      IF @cPOKey = 'NOPO'
         SELECT
            @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
            @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
      ELSE
         SELECT
            @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
            @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND POKey = @cPOKey

      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- Desc1
      SET @cOutField05 = '' -- Desc2
      SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
      SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to next screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU

      -- Reset data
      SELECT @cSKU = '', @nQTY = 0,
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

         -- (james01)
         -- Flow thru screen enable, go back to prev skipped screen
         IF @cFlowThruQtyScn = '1'
         BEGIN
            SET @cOutField01 = @cReceiptKey
            SET @cOutField02 = @cPOKey
            SET @cOutField03 = '' -- SKU
            SET @cOutField04 = '' -- Desc1
            SET @cOutField05 = '' -- Desc2
            SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
            SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))
            SET @cOutField15 = '' -- ExtendedInfo (yeekung01)

            EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

            -- Go to next screen
            SET @nScn = @nScn_SKU
            SET @nStep = @nStep_SKU
         END
         ELSE
         BEGIN
            -- Enable / disable PQTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
               SET @cFieldAttr08 = 'O' -- @nPQTY
            ELSE
               SET @cFieldAttr08 = '' -- @nPQTY

            -- Prepare next screen variable
            SET @cOutField01 = @cSKU
            SET @cOutField02 = rdt.rdtFormatString( @cSKUDesc, 1, 20)
            SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
            SET @cOutField04 = @cIVASDesc
            SET @cOutField05 = '1:' + CAST( @nPUOM_Div AS NCHAR( 5))
            SET @cOutField06 = @cPUOM_Desc
            SET @cOutField07 = @cMUOM_Desc
            SET @cOutField08 = CASE WHEN @nPQTY = 0 OR @cFieldAttr08 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 5)) END -- PQTY
            SET @cOutField09 = CAST( @nMQTY AS NVARCHAR( 5)) -- MQTY
            SET @cOutField15 = '' -- ExtendedInfo

            IF @cFieldAttr08 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY

            -- Go to QTY screen
            SET @nScn = @nScn_QTY
            SET @nStep = @nStep_QTY
         END
      END
   END

   Step_IDLOC_Quit:
   BEGIN
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
               '@cRefNo        NVARCHAR( 20), ' +
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
               '@cReasonCode   NVARCHAR( 10), ' +
               '@cSuggID       NVARCHAR( 18), ' +
               '@cSuggLOC      NVARCHAR( 10), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10),   ' +
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_IDLOC, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
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

      -- Enable / disable PQTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
         SET @cFieldAttr08 = 'O' -- @nPQTY
      ELSE
         SET @cFieldAttr08 = '' -- @nPQTY

      -- Prepare next screen variable
      SET @cOutField01 = @cSKU
      SET @cOutField02 = rdt.rdtFormatString( @cSKUDesc, 1, 20)
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
      SET @cOutField04 = @cIVASDesc
      SET @cOutField05 = '1:' + CAST( @nPUOM_Div AS NCHAR( 5))
      SET @cOutField06 = @cPUOM_Desc
      SET @cOutField07 = @cMUOM_Desc
      SET @cOutField08 = '' -- PQTY
      SET @cOutField09 = '' -- MQTY
      SET @cOutField15 = '' -- ExtendedInfo

      IF @cFieldAttr08 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY

      -- Go to QTY screen
      SET @nScn = @nScn_QTY
      SET @nStep = @nStep_QTY
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Enable field
      SET @cFieldAttr05 = '' -- Dynamic verify SKU 1..5
      SET @cFieldAttr07 = '' --
      SET @cFieldAttr09 = '' --
      SET @cFieldAttr11 = '' --
      SET @cFieldAttr13 = '' --

      -- Get statistic
      IF @cPOKey = 'NOPO'
         SELECT
            @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
            @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
      ELSE
         SELECT
            @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
            @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND POKey = @cPOKey

      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- Desc1
      SET @cOutField05 = '' -- Desc2
      SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
      SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to next screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   -- (james01)
   -- Next screen qty value already available
   -- and flow thru screen config setup then direct go thru it
   -- DefaultQty setup then screen already have value
   IF @cDefaultQTY <> '' AND @nInputKey = 1
   BEGIN
      IF @cFlowThruQtyScn = '1'
      BEGIN
         SET @cInField09 = @cDefaultQTY
         GOTO Step_QTY  -- Forced to go qty screen directly
      END
   END

   GOTO Quit

   Step_VerifySKU_Quit:
   BEGIN
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
               '@cRefNo        NVARCHAR( 20), ' +
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
               '@cReasonCode   NVARCHAR( 10), ' +
               '@cSuggID       NVARCHAR( 18), ' +
               '@cSuggLOC      NVARCHAR( 10), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cReceiptLineNumber NVARCHAR( 10),   ' +
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep_VerifySKU, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END
   END
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
      SELECT @cSKUDesc = Descr FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
   END

   -- Get statistic
   IF @cPOKey = 'NOPO'
      SELECT
         @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
         @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
   ELSE
      SELECT
         @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
         @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND POKey = @cPOKey

   -- Prepare next screen var
   SET @cOutField01 = @cReceiptKey
   SET @cOutField02 = @cPOKey
   SET @cOutField03 = @cSKU
   SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1
   SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 21, 20) -- SKU desc 2
   SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
   SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

   EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

   -- Go to next screen
   SET @nScn = @nScn_SKU
   SET @nStep = @nStep_SKU

END
GOTO Quit

/***********************************************************************************
Step 6. Scn = 4275. Capture data screen
   Data1    (field01)
   Input1   (field02, input)
   .
   .
   .
   Data5    (field09)
   Input5   (field10, input)
***********************************************************************************/
Step_CaptureData:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cData1 = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END
      SET @cData2 = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END
      SET @cData3 = CASE WHEN @cFieldAttr06 = '' THEN @cInField06 ELSE @cOutField06 END
      SET @cData4 = CASE WHEN @cFieldAttr08 = '' THEN @cInField08 ELSE @cOutField08 END
      SET @cData5 = CASE WHEN @cFieldAttr10 = '' THEN @cInField10 ELSE @cOutField10 END

      -- Retain value
      SET @cOutField02 = @cInField02
      SET @cOutField04 = @cInField04
      SET @cOutField06 = @cInField06
      SET @cOutField08 = @cInField08
      SET @cOutField10 = @cInField10

      EXEC rdt.rdt_Return_V7_CaptureInfo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'UPDATE',
         @cReceiptKey, @cRefNo, @cID, @cLOC, @cData1, @cData2, @cData3, @cData4, @cData5,
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
         @tCaptureVar,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Enable field
      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

      -- Get statistic
      IF @cPOKey = 'NOPO'
         SELECT
            @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
            @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
      ELSE
         SELECT
            @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
            @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND POKey = @cPOKey

      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- Desc1
      SET @cOutField05 = '' -- Desc2
      SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
      SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to next screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Enable field
      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

      -- Prepare next screen var
      SET @cOutField01 = '' -- ASN
      SET @cOutField02 = @cPOKeyDefaultValue
      SET @cOutField03 = '' -- RefNo

      -- Set the entry point
      SET @nScn = @nScn_ASNPO
      SET @nStep = @nStep_ASNPO
   END
END
GOTO Quit

/********************************************************************************
Step 7. Scn = 4276. ToLoc Diff screen
   Option  (field01, input)
********************************************************************************/
Step_ToLOCDiff:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01 -- Option
      
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 56691
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Required
         GOTO Quit
      END
      
      -- Validate option
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 56692
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Quit
      END
      
      IF @cOption = '1'
      BEGIN
         -- Get UOM
         SELECT @cUOM = PackUOM3
         FROM dbo.SKU WITH (NOLOCK)
            JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU

         -- NOPO flag
         SET @nNOPOFlag = CASE WHEN @cPOkey = 'NOPO' THEN 1 ELSE 0 END

         -- Handling transaction
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN ToLocCfmRcpt -- For rollback or commit only our own transaction

         -- Custom receiving logic
         IF @cRcptConfirmSP <> ''
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cRcptConfirmSP) +
               ' @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, @cToLOC, @cToID, ' +
               ' @cSKUCode, @cSKUUOM, @nSKUQTY, @cUCC, @cUCCSKU, @nUCCQTY, @cCreateUCC, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nNOPOFlag, @cConditionCode, @cSubreasonCode, @cReceiptLineNumber OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

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
               '@cReceiptLineNumber NVARCHAR( 5) OUTPUT, ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, @cLOC, @cID,
               @cSKU, @cUOM, @nQTY, '', '', 0, '',
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, NULL,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nNOPOFlag, @cReasonCode, '', @cReceiptLineNumber OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
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
               @nNOPOFlag     = @nNOPOFlag,
               @cConditionCode = @cReasonCode,
               @cSubreasonCode = '',
               @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT
         END

         IF @nErrNo <> 0
         BEGIN
            ROLLBACK TRAN ToLocCfmRcpt
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
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY, ' +
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
                  ' @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
                  '@cRefNo        NVARCHAR( 20), ' +
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
                  '@cReasonCode   NVARCHAR( 10), ' +
                  '@cSuggID       NVARCHAR( 18), ' +
                  '@cSuggLOC      NVARCHAR( 10), ' +
                  '@cID           NVARCHAR( 18), ' +
                  '@cLOC          NVARCHAR( 10), ' +
                  '@cReceiptLineNumber NVARCHAR( 10),   ' +
                  '@nErrNo        INT           OUTPUT, ' +
                  '@cErrMsg       NVARCHAR( 20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep_IDLOC, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cPOKey, @cRefNo, @cSKU, @nQTY,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
                  @cReasonCode, @cSuggID, @cSuggLOC, @cID, @cLOC, @cReceiptLineNumber, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  ROLLBACK TRAN ToLocCfmRcpt
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
                  GOTO Quit
               END
            END
         END

         COMMIT TRAN ToLocCfmRcpt
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

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
            @cRefNo1       = @cReceiptKey, -- Retain for backward compatible
            @cRefNo2       = @cPOKey,      -- Retain for backward compatible
            @cRefNo3       = @cRefNo,
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

         -- Get statistic
         IF @cPOKey = 'NOPO'
            SELECT
               @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
               @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
         ELSE
            SELECT
               @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
               @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
               AND POKey = @cPOKey

         -- Prepare next screen var
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @cPOKey
         SET @cOutField03 = '' -- SKU
         SET @cOutField04 = '' -- Desc1
         SET @cOutField05 = '' -- Desc2
         SET @cOutField06 = CAST( @nTotalQTYExp AS NVARCHAR(10))
         SET @cOutField07 = CAST( @nTotalQTYRcv AS NVARCHAR(10))

         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

         -- Go to next screen
         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU

         -- Reset data
         SELECT @cSKU = '', @nQTY = 0,
            @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL, @dLottable05 = NULL,
            @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',   @cLottable10 = '',
            @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL, @dLottable15 = NULL
      END
      
      IF @cOption = '2'
      BEGIN
         -- Prepare next screen variable
         SET @cOutField01 = @cSuggID
         SET @cOutField02 = CASE WHEN @cDefaultIDAsSuggID = '1' THEN @cSuggID ELSE '' END -- ID
         SET @cOutField03 = @cSuggLOC
         SET @cOutField04 = CASE WHEN @cDefaultLOCAsSuggLOC = '1' THEN @cSuggLOC ELSE @cDefaultToLOC  END -- LOC

         EXEC rdt.rdtSetFocusField @nMobile, 2 -- SuggID

         -- Go to next screen
         SET @nScn = @nScn_IDLOC
         SET @nStep = @nStep_IDLOC
      END
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen variable
      SET @cOutField01 = @cSuggID
      SET @cOutField02 = CASE WHEN @cDefaultIDAsSuggID = '1' THEN @cSuggID ELSE '' END -- ID
      SET @cOutField03 = @cSuggLOC
      SET @cOutField04 = CASE WHEN @cDefaultLOCAsSuggLOC = '1' THEN @cSuggLOC ELSE @cDefaultToLOC  END -- LOC

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- SuggID

      -- Go to next screen
      SET @nScn = @nScn_IDLOC
      SET @nStep = @nStep_IDLOC
   END
   
   GOTO Quit
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
      -- UserName     = @cUserName,

      V_StorerKey  = @cStorerKey,
      V_UOM        = @cPUOM,
      V_ReceiptKey = @cReceiptKey,
      V_POKey      = @cPOKey,
      V_LOC        = @cLOC,
      V_ID         = @cID,
      V_SKU        = @cSKU,
      V_SKUDescr   = @cSKUDesc,
      V_QTY        = @cQTY,
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
      V_PQTY       = @nPQTY,
      V_MQTY       = @nMQTY,

      V_Integer1   = @nQTY,

      V_String1    = @cRefNo,
      V_String2    = @cIVAS,
      V_String3    = @cLottableCode,
      V_String4    = @cReasonCode,
      V_String5    = @cSuggID,
      V_String6    = @cSuggLOC,
      V_String7    = @cReceiptLineNumber,
      V_String8    = @cFlowThruQtyScn,
      V_String9    = @cCaptureReceiptInfoSP,
      V_String10   = @cMUOM_Desc,
      V_String11   = @cPUOM_Desc,
      --V_String12   = @nPUOM_Div ,
      --V_String13   = @nPQTY,
      --V_String14   = @nMQTY,
      --V_String15   = @nQTY,

      V_String21   = @cDefaultToLOC,
      V_String22   = @cGetReceiveInfoSP,
      V_String23   = @cDecodeSKUSP,
      V_String24   = @cVerifySKU,
      V_String25   = @cRcptConfirmSP,
      V_String26   = @cExtendedPutawaySP,
      V_String27   = @cOverrideSuggestID,
      V_String28   = @cOverrideSuggestLOC,
      V_String29   = @cDefaultIDAsSuggID,
      V_String30   = @cDefaultLOCAsSuggLOC,
      V_String31   = @cExtendedInfoSP,
      V_String32   = @cExtendedInfo,
      V_String33   = @cExtendedValidateSP,
      V_String34   = @cExtendedUpdateSP,
      V_String35   = @cMultiSKUBarcode,
      V_String36   = @cCheckSKUInASN,
      V_String37   = @cDefaultQTY,
      V_String38   = @cReasonCodeMandatory,

      V_String41   = @cData1,
      V_String42   = @cData2,
      V_String43   = @cData3,
      V_String44   = @cData4,
      V_String45   = @cData5,
      
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