SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store procedure: rdtfnc_PalletReceive                                         */
/* Copyright      : LFLogistics                                                  */
/*                                                                               */
/* Purpose: Mirgrated from normal receiving                                      */
/*                                                                               */
/* Date       Rev  Author   Purposes                                             */
/* 2015-08-31 1.2  Ung      SOS351444 Created                                    */
/* 2016-09-30 1.3  Ung      Performance tuning                                   */
/* 2018-06-07 1.4  James    WMS5536 - Add rdt_decode sp (james01)                */
/* 2018-10-05 1.5  TungGH   Performance                                          */
/* 2020-07-29 1.6  YeeKung  WMS-14414 Add flowthrough (yeekung01)                */
/* 2022-02-21 1.7  YeeKung  WMS-18676 fix extendevalidate (yeekung02)            */
/* 2024-09-19 1.8  JHU151   FCR-752                                              */
/*********************************************************************************/

CREATE   PROCEDURE [RDT].[rdtfnc_PalletReceive] (
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
   @cChkFacility   NVARCHAR( 5),
   @cChkReceiptKey NVARCHAR( 10),
   @cChkStorerKey  NVARCHAR( 15),
   @cOption        NVARCHAR( 1),
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
   @cFacility    NVARCHAR( 5),
   @cUserName    NVARCHAR( 18),
   @cPrinter     NVARCHAR( 10),

   @cStorerKey   NVARCHAR( 15),
   @cPUOM        NVARCHAR(  1),
   @cReceiptKey  NVARCHAR( 10),
   @cID          NVARCHAR( 18),
   @cSKU         NVARCHAR( 20),
   @cDescr       NVARCHAR( 60),
   @cFlowThruScreen     NVARCHAR( 1), --(yeekung01)

   @cPUOM_Desc          NCHAR( 5),
   @cMUOM_Desc          NCHAR( 5),
   @nPUOM_Div           INT,
   @nPQTY               INT,
   @nMQTY               INT,
   @nQTY                INT,
   @nCurrentLine        INT,
   @nTotalLine          INT,
   @nCurrentScanned     INT, --(yeekung01)
   @cRDLineNo           NVARCHAR( 5),

   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedScreenSP   NVARCHAR( 20), --(JHU151)
   @cExtendedInfo       NVARCHAR( 20),
   @cDefaultOption      NVARCHAR( 1),
   @tExtScnData			VariableTable, --(JHU151)
   @nAction             INT, --(JHU151)

   @cRefNo              NVARCHAR( 20),
   @cActReceiptKey      NVARCHAR( 10),
   @cDecodeSP           NVARCHAR( 20),
   @cBarcode            NVARCHAR( 60),
   @cDefaultcursor      NVARCHAR( 1),  --(yeekung01)

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
   @cFieldAttr15 NVARCHAR( 1),

   @cLottable01  NVARCHAR( 18), @cLottable02  NVARCHAR( 18), @cLottable03  NVARCHAR( 18),
   @dLottable04  DATETIME, @dLottable05  DATETIME,
   @cLottable06  NVARCHAR( 30), @cLottable07  NVARCHAR( 30), @cLottable08  NVARCHAR( 30),
   @cLottable09  NVARCHAR( 30), @cLottable10  NVARCHAR( 30), @cLottable11  NVARCHAR( 30),
   @cLottable12  NVARCHAR( 30),
   @dLottable13  DATETIME, @dLottable14  DATETIME, @dLottable15  DATETIME,

   @cUDF01  NVARCHAR( 250), @cUDF02 NVARCHAR( 250), @cUDF03 NVARCHAR( 250),
   @cUDF04  NVARCHAR( 250), @cUDF05 NVARCHAR( 250), @cUDF06 NVARCHAR( 250),
   @cUDF07  NVARCHAR( 250), @cUDF08 NVARCHAR( 250), @cUDF09 NVARCHAR( 250),
   @cUDF10  NVARCHAR( 250), @cUDF11 NVARCHAR( 250), @cUDF12 NVARCHAR( 250),
   @cUDF13  NVARCHAR( 250), @cUDF14 NVARCHAR( 250), @cUDF15 NVARCHAR( 250),
   @cUDF16  NVARCHAR( 250), @cUDF17 NVARCHAR( 250), @cUDF18 NVARCHAR( 250),
   @cUDF19  NVARCHAR( 250), @cUDF20 NVARCHAR( 250), @cUDF21 NVARCHAR( 250),
   @cUDF22  NVARCHAR( 250), @cUDF23 NVARCHAR( 250), @cUDF24 NVARCHAR( 250),
   @cUDF25  NVARCHAR( 250), @cUDF26 NVARCHAR( 250), @cUDF27 NVARCHAR( 250),
   @cUDF28  NVARCHAR( 250), @cUDF29 NVARCHAR( 250), @cUDF30 NVARCHAR( 250)
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

   @cStorerKey   = V_StorerKey,
   @cPUOM        = V_UOM,
   @cReceiptKey  = V_Receiptkey,
   @cID          = V_ID,
   @cSKU         = V_SKU,
   @cDescr       = V_SKUDescr,

   @cMUOM_Desc          = V_String1,
   @cPUOM_Desc          = V_String2,
   @cRDLineNo           = V_String9,

   @nPUOM_Div           = V_PUOM_Div,
   @nPQTY               = V_PQTY,
   @nMQTY               = V_MQTY,

   @nQTY                = V_Integer1,
   @nCurrentLine        = V_Integer2,
   @nTotalLine          = V_Integer3,
   @nCurrentScanned     = V_Integer4,

   @cExtendedValidateSP = V_String11,
   @cExtendedUpdateSP   = V_String12,
   @cExtendedInfoSP     = V_String13,
   @cExtendedInfo       = V_String14,
   @cDefaultOption      = V_String15,

   @cRefNo              = V_String21,
   @cActReceiptKey      = V_String22,
   @cDecodeSP           = V_String23,
   @cFlowThruScreen     = V_String24,
   @cDefaultcursor      = V_String25,
   @cExtendedScreenSP   = V_String26,

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
IF @nFunc = 605
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Func = 605. Menu
   IF @nStep = 1 GOTO Step_1   -- Scn = 4250. ASN, RefNo
   IF @nStep = 2 GOTO Step_2   -- Scn = 4251. ID
   IF @nStep = 3 GOTO Step_3   -- Scn = 4252. ID detail
   IF @nStep = 99 GOTO Step_99 -- Ext Screen
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 605. Menu
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN

   SET @cFlowThruScreen = rdt.RDTGetConfig( @nFunc, 'FlowThruScreen', @cStorerKey) --(yeekung01)

   --JHU151
   SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScreenSP = '0'
      SET @cExtendedScreenSP = ''

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep

   SET @cDefaultCursor = rdt.RDTGetConfig( @nFunc, 'DefaultCursor', @cStorerKey)   --(yeekung01)

   IF ISNULL(@cDefaultCursor,'')<>0
      EXEC rdt.rdtSetFocusField @nMobile, @cDefaultCursor
   ELSE
      EXEC rdt.rdtSetFocusField @nMobile, 1

   -- Prepare next screen var
   SET @cOutField01 = '' -- ASN

   -- Set the entry point
   SET @nScn = 4250
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 4250. ASN, RefNo
   ASN    (field01, input)
   RefNo  (field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cReceiptStatus NVARCHAR( 10)
      DECLARE @nRowCount INT

      -- Screen mapping
      SET @cReceiptKey = @cInField01
      SET @cRefNo = @cInField02

      -- Validate at least one field must key-in
      IF @cReceiptKey = '' AND @cRefNo = ''
      BEGIN
         SET @nErrNo = 52951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ASN/RefNo
         GOTO Step_1_Fail
      END

      -- Check both field key-in
      IF @cReceiptKey <> '' AND @cRefNo <> ''
      BEGIN
         SET @nErrNo = 52952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Either ASN/Ref
         GOTO Step_1_Fail
      END

      -- Clear log
      IF EXISTS( SELECT 1 FROM rdt.rdtPalletReceiveLog WITH (NOLOCK) WHERE Mobile = @nMobile)
      BEGIN
         DECLARE @nRowRef INT
         DECLARE @curCR CURSOR
         SET @curCR = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RowRef FROM rdt.rdtPalletReceiveLog WITH (NOLOCK) WHERE Mobile = @nMobile
         OPEN @curCR
         FETCH NEXT FROM @curCR INTO @nRowRef
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE rdt.rdtPalletReceiveLog WHERE RowRef = @nRowRef
            FETCH NEXT FROM @curCR INTO @nRowRef
         END
      END

      -- ASN
      IF @cReceiptKey <> ''
      BEGIN
         -- Get ASN info
         SELECT DISTINCT
            @cChkFacility = R.Facility,
            @cChkStorerKey = R.StorerKey,
            @cReceiptStatus = R.Status
         FROM dbo.Receipt R WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         SET @nRowCount = @@ROWCOUNT

         -- No row returned, either ASN or ASN detail not exist
         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 52953
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN not exist
            EXEC rdt.rdtSetFocusField @nMobile, 1
            SET @cOutField01 = '' -- ReceiptKey
            SET @cReceiptKey = ''
            GOTO Quit
         END

         -- Validate ASN in different facility
         IF @cFacility <> @cChkFacility
         BEGIN
            SET @nErrNo = 52954
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
            EXEC rdt.rdtSetFocusField @nMobile, 1
            SET @cOutField01 = '' -- ReceiptKey
            SET @cReceiptKey = ''
            GOTO Quit
         END

         -- Check storer group
         IF @cStorerGroup <> ''
         BEGIN
            -- Check storer not in storer group
            IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cChkStorerKey)
            BEGIN
               SET @nErrNo = 52955
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
               EXEC rdt.rdtSetFocusField @nMobile, 1
               SET @cOutField01 = '' -- ReceiptKey
               SET @cReceiptKey = ''
               GOTO Quit
            END

            -- Set session storer
            SET @cStorerKey = @cChkStorerKey
         END

         -- Validate ASN belong to the storer
         IF @cStorerKey <> @cChkStorerKey
         BEGIN
            SET @nErrNo = 52956
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            EXEC rdt.rdtSetFocusField @nMobile, 1
            SET @cOutField01 = '' -- ReceiptKey
            SET @cReceiptKey = ''
            GOTO Quit
         END

         -- Validate ASN status
         IF @cReceiptStatus = '9'
         BEGIN
            SET @nErrNo = 52957
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN is closed
            EXEC rdt.rdtSetFocusField @nMobile, 1
            SET @cOutField01 = '' -- ReceiptKey
            SET @cReceiptKey = ''
            GOTO Quit
         END

         -- Insert log
         INSERT INTO rdt.rdtPalletReceiveLog (Mobile, ReceiptKey)
         VALUES (@nMobile, @cReceiptKey)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 52958
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
            EXEC rdt.rdtSetFocusField @nMobile, 1
            SET @cOutField01 = '' -- ReceiptKey
            SET @cReceiptKey = ''
            GOTO Quit
         END
      END

      -- RefNo
      IF @cRefNo <> ''
      BEGIN
         -- Get storer config
         DECLARE @cColumnName NVARCHAR( 20)
         SET @cColumnName = rdt.RDTGetConfig( @nFunc, 'RefNoLookupColumn', @cStorerKey)

         -- Get lookup field data type
         DECLARE @cDataType NVARCHAR(128)
         SET @cDataType = ''
         SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Receipt' AND COLUMN_NAME = @cColumnName

         -- Check lookup field
         IF @cDataType = ''
         BEGIN
            SET @nErrNo = 52959
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad RefNoSetup
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- RefNo
            GOTO Quit
         END

         -- Check data is correct type
         DECLARE @n_Err INT
         IF @cDataType = 'nvarchar' SET @n_Err = 1                                ELSE
         IF @cDataType = 'datetime' SET @n_Err = rdt.rdtIsValidDate( @cRefNo)     ELSE
         IF @cDataType = 'int'      SET @n_Err = rdt.rdtIsInteger(   @cRefNo)     ELSE
         IF @cDataType = 'float'    SET @n_Err = rdt.rdtIsValidQTY(  @cRefNo, 20)
         IF @n_Err = 0
         BEGIN
            SET @nErrNo = 52960
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RefNo
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- RefNo
            GOTO Quit
         END

         -- Insert log
         SET @cSQL =
            ' INSERT INTO rdt.rdtPalletReceiveLog (Mobile, ReceiptKey) ' +
            ' SELECT @nMobile, ReceiptKey ' +
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
            ' ORDER BY ReceiptKey ' +
            ' SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT '
         SET @cSQLParam =
            ' @nMobile      INT, ' +
            ' @cFacility    NVARCHAR(5),  ' +
            ' @cStorerGroup NVARCHAR(20), ' +
            ' @cStorerKey   NVARCHAR(15), ' +
            ' @cColumnName  NVARCHAR(20), ' +
            ' @cRefNo       NVARCHAR(20), ' +
            ' @nRowCount    INT OUTPUT,   ' +
            ' @nErrNo       INT OUTPUT    '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
@nMobile,
            @cFacility,
            @cStorerGroup,
            @cStorerKey,
            @cColumnName,
            @cRefNo,
            @nRowCount OUTPUT,
            @nErrNo    OUTPUT

         IF @nErrNo <> 0
            GOTO Quit

         -- Check RefNo in ASN
         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 52961
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- RefNo
            GOTO Quit
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = '' -- ID
      SET @nCurrentScanned=0

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
         @cStorerKey  = @cStorerKey,
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
      -- Reset this screen var
      SET @cOutField01 = '' -- ReceiptKey
      SET @cReceiptKey = ''
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 4251. Pallet ID screen
   ASN    (field01)
   RefNo  (field02)
   TO ID  (field03, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cID = @cInField03 -- ID
      SET @cBarcode = @cInField03 -- ID

      -- Check blank
      IF @cID = ''
      BEGIN
         SET @nErrNo = 52962
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ID
         GOTO Step_2_Fail
      END

      SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerkey)
      IF @cDecodeSP = '0'
         SET @cDecodeSP = ''

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cID     = @cID         OUTPUT,
               @nErrNo  = @nErrNo      OUTPUT,
               @cErrMsg = @cErrMsg     OUTPUT,
               @cType   = 'ID'
         END
         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +
               ' @cReceiptKey OUTPUT, @cRefNo      OUTPUT, @cID      OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cReceiptKey  NVARCHAR( 10)  OUTPUT, ' +
               ' @cRefNo       NVARCHAR( 20)  OUTPUT, ' +
               ' @cID          NVARCHAR( 18)  OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode,
               @cReceiptKey      OUTPUT, @cRefNo      OUTPUT, @cID      OUTPUT,
               @nErrNo           OUTPUT, @cErrMsg     OUTPUT
         END

         IF @nErrNo <> 0
            GOTO Step_2_Fail
      END

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cID) = 0
      BEGIN
         SET @nErrNo = 52963
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_2_Fail
      END

      -- Get ID info
      SELECT @nTotalLine = COUNT(1)
      FROM rdt.rdtPalletReceiveLog PRL WITH (NOLOCK)
         JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (PRL.ReceiptKey = RD.ReceiptKey)
      WHERE PRL.Mobile = @nMobile
         AND RD.ToID = @cID

      -- Check ID in ASN
      IF @nTotalLine = 0
      BEGIN
         SET @nErrNo = 52964
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID not in ASN
         GOTO Step_2_Fail
      END

      -- Check ID received in ASN
      IF EXISTS (SELECT 1
         FROM rdt.rdtPalletReceiveLog PRL WITH (NOLOCK)
            JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (PRL.ReceiptKey = RD.ReceiptKey)
         WHERE PRL.Mobile = @nMobile
            AND RD.ToID = @cID
            AND RD.BeforeReceivedQty > 0)
      BEGIN
         SET @nErrNo = 52965
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID received
         GOTO Step_2_Fail
      END

      -- Check ID received
      IF EXISTS( SELECT 1
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
            INNER JOIN dbo.LOC WITH (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC)
         WHERE [ID] = @cID
            AND QTY > 0
            AND LOC.Facility = @cFacility)
      BEGIN
         SET @nErrNo = 52966
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID in used
         GOTO Step_2_Fail
      END

      -- ReceiptKey
      IF @cReceiptKey <> ''
         SET @cActReceiptKey = @cReceiptKey

      -- RefNo
      IF @cRefNo <> ''
      BEGIN
         -- Check ID in multi ASN
         IF EXISTS( SELECT 1
            FROM rdt.rdtPalletReceiveLog PRL WITH (NOLOCK)
               JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (PRL.ReceiptKey = RD.ReceiptKey)
            WHERE PRL.Mobile = @nMobile
               AND RD.ToID = @cID
            HAVING COUNT( DISTINCT PRL.ReceiptKey) > 1)
         BEGIN
            SET @nErrNo = 52967
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID in MultiASN
            GOTO Step_2_Fail
         END

         -- Set session storer, receipt
         SELECT TOP 1
            @cStorerKey = RD.StorerKey,
            @cActReceiptKey = RD.ReceiptKey
         FROM rdt.rdtPalletReceiveLog PRL WITH (NOLOCK)
            JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (PRL.ReceiptKey = RD.ReceiptKey)
         WHERE PRL.Mobile = @nMobile
            AND RD.ToID = @cID
      END

      -- Get storer config
      SET @cDefaultOption = rdt.RDTGetConfig( @nFunc, 'DefaultOption', @cStorerKey)
      IF @cDefaultOption = '0'
         SET @cDefaultOption = ''
      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''
      SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
      IF @cExtendedInfoSP = '0'
         SET @cExtendedInfoSP = ''
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cRefNo, @cID, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
               '@cID          NVARCHAR( 18), ' +
               '@nErrNo             INT            OUTPUT, ' +
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cRefNo, @cID,
               @nErrNo OUTPUT, @cErrMsg OUTPUT
         END
      END

      IF @cFlowThruScreen = '1'
      BEGIN
         SET @cInField14='1'
         -- Go to detail screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         GOTO STEP_3
      END


      -- Get first line
      SET @cSKU = ''
      SET @nQTY = 0
      SET @cRDLineNo = ''
      EXEC rdt.rdt_PalletReceive_GetDetail @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cFacility, @cStorerKey,
         @cActReceiptKey,
         @cID,
         @cSKU        OUTPUT,
         @nQTY        OUTPUT,
         @cRDLineNo   OUTPUT,
         @cOutField01 OUTPUT,
         @cOutField02 OUTPUT,
         @cOutField03 OUTPUT,
         @cOutField04 OUTPUT,
         @cOutField05 OUTPUT,
         @cOutField06 OUTPUT,
         @cOutField07 OUTPUT,
         @cOutField08 OUTPUT,
         @cOutField09 OUTPUT,
         @cOutField10 OUTPUT,
         @cOutField11 OUTPUT,
         @cOutField12 OUTPUT,
         @cOutField13 OUTPUT,
         @cOutField14 OUTPUT,
         @cOutField15 OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      SET @nCurrentLine = 1

      -- Get Pack info
      SELECT
         @cDescr = SKU.Descr,
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
         SET @nPQTY = @nQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
         SET @nMQTY = @nQTY % @nPUOM_Div  -- Calc the remaining in master unit
      END

      -- Prepare next screen var
      SET @cOutField01 = @cID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cDescr, 1, 20)
      SET @cOutField04 = SUBSTRING( @cDescr, 21, 20)
      SET @cOutField05 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END +  -- 12345678901234567890
                         rdt.rdtRightAlign( @cPUOM_Desc, 5) + SPACE( 3) +                                        -- 1:99999XXXXX   XXXXX
                         rdt.rdtRightAlign( @cMUOM_Desc, 5)                                                      -- QTY: 9999999 9999999
      SET @cOutField06 = rdt.rdtRightAlign( CAST( @nPQTY AS NCHAR( 7)), 7) -- PQTY
      SET @cOutField07 = rdt.rdtRightAlign( CAST( @nMQTY AS NCHAR( 7)), 7) -- MQTY
      -- SET @cOutField08 = dynamic lottable
      -- SET @cOutField09 = dynamic lottable
      -- SET @cOutField10 = dynamic lottable
      -- SET @cOutField11 = dynamic lottable
      -- SET @cOutField12 = dynamic lottable
      SET @cOutField13 = CAST( @nCurrentLine AS NVARCHAR( 2)) + '/' + CAST( @nTotalLine AS NVARCHAR( 2))
      SET @cOutField14 = @cDefaultOption

      -- Go to detail screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''

      IF @cReceiptKey <> ''
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- RefNo

      -- Go to ASN screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   
   --JHU151   
   IF @cExtendedScreenSP IN ( 'rdt_605ExtScn01', 'rdt_605ExtScn03','rdt_605ExtScn04')
   BEGIN
      SET @nAction = 0 -- jump new screen
      GOTO Step_99
   END

   GOTO Quit

   Step_2_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField03 = '' -- ID
      SET @cID = ''
   END
END
GOTO Quit


/********************************************************************************
Step 3. Screen = 4252. ID detail screen
   TO ID            (Field01)
   SKU              (Field02)
   SKU Desc1        (Field03)
   SKU Desc2        (Field04)
   DIV PUOM MUOM    (Field05)
   PQTY MQTY        (Field06, Field07)
   Dynamic lottable (Field08)
   Dynamic lottable (Field09)
   Dynamic lottable (Field10)
   Dynamic lottable (Field11)
   Dynamic lottable (Field12)
   Curr/Total line  (field13)
   OPTION           (Field14)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField14

      -- Check option valid
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 52968
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Quit
      END

      -- Blank to get next line
      IF @cOption = '2'
      BEGIN
         -- Get next line
         EXEC rdt.rdt_PalletReceive_GetDetail @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cFacility, @cStorerKey,
            @cActReceiptKey,
            @cID,
            @cSKU        OUTPUT,
            @nQTY        OUTPUT,
            @cRDLineNo   OUTPUT,
            @cOutField01 OUTPUT,
            @cOutField02 OUTPUT,
            @cOutField03 OUTPUT,
            @cOutField04 OUTPUT,
            @cOutField05 OUTPUT,
            @cOutField06 OUTPUT,
            @cOutField07 OUTPUT,
            @cOutField08 OUTPUT,
            @cOutField09 OUTPUT,
            @cOutField10 OUTPUT,
            @cOutField11 OUTPUT,
            @cOutField12 OUTPUT,
            @cOutField13 OUTPUT,
            @cOutField14 OUTPUT,
            @cOutField15 OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT
         IF @nErrNo <> 0
         BEGIN
            -- No more record
            IF @nErrNo = -1
            BEGIN
               SET @nErrNo = 52969
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more record
            END
            GOTO Quit
         END

         SET @nCurrentLine = @nCurrentLine + 1

         -- Get Pack info
         SELECT
            @cDescr = SKU.Descr,
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
            SET @nPQTY = @nQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
            SET @nMQTY = @nQTY % @nPUOM_Div  -- Calc the remaining in master unit
         END

         -- Prepare next screen var
         SET @cOutField01 = @cID
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cDescr, 1, 20)
         SET @cOutField04 = SUBSTRING( @cDescr, 21, 20)
         SET @cOutField05 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END +  -- 12345678901234567890
                            rdt.rdtRightAlign( @cPUOM_Desc, 5) + SPACE( 3) +                                        -- 1:99999XXXXX   XXXXX
                            rdt.rdtRightAlign( @cMUOM_Desc, 5)                     -- QTY: 9999999 9999999
         SET @cOutField06 = rdt.rdtRightAlign( CAST( @nPQTY AS NCHAR( 7)), 7) -- PQTY
         SET @cOutField07 = rdt.rdtRightAlign( CAST( @nMQTY AS NCHAR( 7)), 7) -- MQTY
         -- SET @cOutField08 = dynamic lottable
         -- SET @cOutField09 = dynamic lottable
         -- SET @cOutField10 = dynamic lottable
         -- SET @cOutField11 = dynamic lottable
         -- SET @cOutField12 = dynamic lottable
         SET @cOutField13 = CAST( @nCurrentLine AS NVARCHAR( 2)) + '/' + CAST( @nTotalLine AS NVARCHAR( 2))
         SET @cOutField14 = @cOption

         -- Remain in current screen
         -- SET @nScn = @nScn - 1
         -- SET @nStep = @nStep - 1

         GOTO Quit
      END

      -- Handling transaction
      DECLARE @nTranCount INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_PalletReceive -- For rollback or commit only our own transaction

      -- Receive
      EXEC rdt.rdt_PalletReceive_Confirm @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility,
         @cActReceiptKey,
         @cID,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdtfnc_PalletReceive
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
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cRefNo, @cID, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
               '@cID          NVARCHAR( 18), ' +
               '@nErrNo       INT            OUTPUT, ' +
               '@cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cRefNo, @cID,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_PalletReceive
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Quit
            END
         END
      END

      COMMIT TRAN rdtfnc_PalletReceive
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      SET @nCurrentScanned=@nCurrentScanned+1

            -- Extended validate
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cRefNo, @cID,@nCurrentScanned, ' +
                '@cExtendedInfo OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc       INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cFacility    NVARCHAR( 5),  ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cRefNo       NVARCHAR( 20), ' +
               '@cID          NVARCHAR( 18), ' +
               '@nCurrentScanned INT,           ' +
               '@cExtendedInfo NVARCHAR(20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cRefNo, @cID,@nCurrentScanned,
               @cExtendedInfo OUTPUT
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
         @cID           = @cID,
         @cRefNo1       = @cRefNo,
         @nStep         = @nStep

      -- Prep next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = '' -- ID
      SET @cOutField04 = @cExtendedInfo

      -- Go to ID screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = '' -- ID

      -- Go to ID screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


--JHU151
Step_99:
BEGIN
   IF @cExtendedScreenSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
      BEGIN
         DECLARE @nPreScn     INT
         SET @nPreScn = @nScn

         EXECUTE [RDT].[rdt_ExtScnEntry] 
               @cExtendedScreenSP, 
               @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @tExtScnData ,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,  
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,  
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,  
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,  
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,  
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT, 
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT, 
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT, 
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT, 
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT, 
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
               @nAction, 
               @nScn     OUTPUT,  @nStep OUTPUT,
               @nErrNo   OUTPUT, 
               @cErrMsg  OUTPUT,
               @cUDF01   OUTPUT, @cUDF02 OUTPUT, @cUDF03 OUTPUT,
               @cUDF04   OUTPUT, @cUDF05 OUTPUT, @cUDF06 OUTPUT,
               @cUDF07   OUTPUT, @cUDF08 OUTPUT, @cUDF09 OUTPUT,
               @cUDF10   OUTPUT, @cUDF11 OUTPUT, @cUDF12 OUTPUT,
               @cUDF13   OUTPUT, @cUDF14 OUTPUT, @cUDF15 OUTPUT,
               @cUDF16   OUTPUT, @cUDF17 OUTPUT, @cUDF18 OUTPUT,
               @cUDF19   OUTPUT, @cUDF20 OUTPUT, @cUDF21 OUTPUT,
               @cUDF22   OUTPUT, @cUDF23 OUTPUT, @cUDF24 OUTPUT,
               @cUDF25   OUTPUT, @cUDF26 OUTPUT, @cUDF27 OUTPUT,
               @cUDF28   OUTPUT, @cUDF29 OUTPUT, @cUDF30 OUTPUT

         IF @cExtendedScreenSP IN ( 'rdt_605ExtScn01', 'rdt_605ExtScn03','rdt_605ExtScn04')
         BEGIN
            IF @nPreScn = 6441 AND @nInputKey = 1
            BEGIN
               SET @nPQTY = @cUDF01
               SET @nMQTY = @cUDF02
               SET @nQTY = @cUDF03
               SET @nCurrentLine = @cUDF04
               SET @nTotalLine = @cUDF05
               SET @nCurrentScanned = @cUDF06
               SET @cRDLineNo = @cUDF07
               SET @cReceiptKey = @cUDF08
               SET @cActReceiptKey = @cUDF09
               SET @cRefNo = @cUDF10
               SET @cExtendedInfo = @cUDF11
               SET @cID = @cUDF12
               SET @cSKU = @cUDF13
               SET @cDescr = @cUDF14
               SET @cPUOM = @cUDF15
               SET @cMUOM_Desc = @cUDF16
               SET @cPUOM_Desc = @cUDF17
            END
         END

         IF @nErrNo <> 0
            GOTO Step_99_Fail
      END
   END

   GOTO Quit

Step_99_Fail:
   BEGIN
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
      Printer      = @cPrinter,
      -- UserName     = @cUserName,

      V_StorerKey  = @cStorerKey,
      V_UOM        = @cPUOM,
      V_ReceiptKey = @cReceiptKey,
      V_ID         = @cID,
      V_SKU        = @cSKU,

      V_String1    = @cMUOM_Desc,
      V_String2    = @cPUOM_Desc,
      V_String9    = @cRDLineNo,

      V_PUOM_Div   = @nPUOM_Div,
      V_PQTY       = @nPQTY,
      V_MQTY       = @nMQTY,

      V_Integer1   = @nQTY,
      V_Integer2   = @nCurrentLine,
      V_Integer3   = @nTotalLine,
      V_Integer4   = @nCurrentScanned,

      V_String11   = @cExtendedValidateSP,
      V_String12   = @cExtendedUpdateSP,
      V_String13   = @cExtendedInfoSP,
      V_String14   = @cExtendedInfo,
      V_String15   = @cDefaultOption,

      V_String21   = @cRefNo,
      V_String22   = @cActReceiptKey,
      V_String23   = @cDecodeSP,
      V_String24   = @cFlowThruScreen,
      V_String25   = @cDefaultcursor, --(yeekung01)
      V_String26   = @cExtendedScreenSP,

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