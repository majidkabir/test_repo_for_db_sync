SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_PreReceiveSort2                              */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pre receive sorting                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 18-Jul-2017  1.0  James    WMS2289 - Created                         */
/* 01-Mar-2018  1.1  James    Add retain value feature (james01)        */
/* 26-Feb-2019  1.2  James    WMS8010-Add Qty screen (james02)          */
/* 06-Aug-2020  1.3  Chermaine  WMS14541-Add EventLog (cc01)            */
/* 16-Jul-2018  1.4  Ung      WMS-5728 Add confirm position             */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_PreReceiveSort2] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(125) OUTPUT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,

   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cUserName           NVARCHAR( 18),
   @cSKU                NVARCHAR( 20),
   @cSQL                NVARCHAR( MAX), 
   @cSQLParam           NVARCHAR( MAX), 

   @cReceiptGroup       NVARCHAR( 20),
   @cReceiptKey         NVARCHAR( 10),
   @cLane               NVARCHAR( 10),
   @cUCC                NVARCHAR( 1), 
   @cUCCNo              NVARCHAR( 20), 
   @cChkFacility        NVARCHAR( 5), 
   @cChkStorerKey       NVARCHAR( 15),
   @cChkReceiptKey      NVARCHAR( 10),
   @cReceiptStatus      NVARCHAR( 10),
   @cUCCStatus          NVARCHAR( 10),
   @cRecordCount        NVARCHAR( 20),
   @cShowPltPositionSP  NVARCHAR( 20),
   @cToID               NVARCHAR( 18),
   @cPreRcvSearchCriteria  NVARCHAR( 20),
   @cExtendedValidateSP    NVARCHAR( 20),
   @cExtendedInfoSP        NVARCHAR( 20), 
   @cExtendedInfo1         NVARCHAR( 20), 
   @cExtendedUpdateSP      NVARCHAR( 20), 
   @cDecodeSP              NVARCHAR( 20),
   @cBarcode            NVARCHAR( 60),
   @cUPC                NVARCHAR( 30),
   @cOption             NVARCHAR( 1),
   @cRetainParm1Value   NVARCHAR( 1),
   @cRetainParm2Value   NVARCHAR( 1),
   @cRetainParm3Value   NVARCHAR( 1),
   @cRetainParm4Value   NVARCHAR( 1),
   @cRetainParm5Value   NVARCHAR( 1),
   @cConfirmPosition    NVARCHAR( 20),
   @nTTL_ASN            INT,
   @nQTY                INT,
   @cCaptureQty         NVARCHAR( 1),
   @cQTY                NVARCHAR( 5),

   @cParam1    NVARCHAR( 20),   @cParamLabel1 NVARCHAR( 20),
   @cParam2    NVARCHAR( 20),   @cParamLabel2 NVARCHAR( 20),
   @cParam3    NVARCHAR( 20),   @cParamLabel3 NVARCHAR( 20),
   @cParam4    NVARCHAR( 20),   @cParamLabel4 NVARCHAR( 20),
   @cParam5    NVARCHAR( 20),   @cParamLabel5 NVARCHAR( 20),

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

   DECLARE 
   @cPosition01  NVARCHAR( 20), @cPosition02  NVARCHAR( 20),
   @cPosition03  NVARCHAR( 20), @cPosition04  NVARCHAR( 20),
   @cPosition05  NVARCHAR( 20), @cPosition06  NVARCHAR( 20),
   @cPosition07  NVARCHAR( 20), @cPosition08  NVARCHAR( 20),
   @cPosition09  NVARCHAR( 20), @cPosition10  NVARCHAR( 20)

   DECLARE 
   @cLottable01 NVARCHAR (18), @cLottable02 NVARCHAR (18),
   @cLottable03 NVARCHAR (18), @dLottable04 DATETIME,
   @dLottable05 DATETIME,      @cLottable06 NVARCHAR (18),
   @cLottable07 NVARCHAR (18), @cLottable08 NVARCHAR (18),
   @cLottable09 NVARCHAR (18), @cLottable10 NVARCHAR (18),
   @cLottable11 NVARCHAR (18), @cLottable12 NVARCHAR (18),
   @dLottable13 DATETIME,      @dLottable14 DATETIME,
   @dLottable15 DATETIME

   DECLARE @tExtendedUpdate AS VariableTable

-- Getting Mobile information
SELECT
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @nMenu       = Menu,
   @cLangCode   = Lang_code,

   @cStorerKey  = StorerKey,
   @cFacility   = Facility,
   @cUserName   = UserName,

   @cReceiptKey = V_ReceiptKey,
   @cLane       = V_LOC,
   @cUCCNo      = V_UCC,

   @cParam1       = V_String1,
   @cParam2       = V_String2,
   @cParam3       = V_String3,
   @cParam4       = V_String4,
   @cParam5       = V_String5,
   @cParamLabel1  = V_String6,
   @cParamLabel2  = V_String7,
   @cParamLabel3  = V_String8,
   @cParamLabel4  = V_String9,
   @cParamLabel5  = V_String10,
   @cCaptureQty   = V_String11,
   @cExtendedValidateSP    = V_String12,
   @cExtendedInfoSP        = V_String13,
   @cShowPltPositionSP     = V_String14,
   @cPreRcvSearchCriteria  = V_String15,
   @cExtendedUpdateSP      = V_String16,
   @cDecodeSP              = V_String17,
   @cRetainParm1Value      = V_String18,
   @cRetainParm2Value      = V_String19,
   @cRetainParm3Value      = V_String20,
   @cRetainParm4Value      = V_String21,
   @cRetainParm5Value      = V_String22,
   @cConfirmPosition       = V_String23,

   @nTTL_ASN      = V_Integer1,

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

FROM rdt.RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 1829 -- Pre Receive Sort 
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Inquiry SKU
   IF @nStep = 1 GOTO Step_1   -- Scn = 4980. RECEIPTGROUP
   IF @nStep = 2 GOTO Step_2   -- Scn = 4981. UCC, TTL ASN
   IF @nStep = 3 GOTO Step_3   -- Scn = 4982. UCC, Position
   IF @nStep = 4 GOTO Step_4   -- Scn = 4983. END SORTING? Option
   IF @nStep = 5 GOTO Step_5   -- Scn = 4984. Qty
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1825. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Init variable
   SET @cParam1 = ''
   SET @cParam2 = ''
   SET @cParam3 = ''
   SET @cParam4 = ''
   SET @cParam5 = ''

   SET @cPreRcvSearchCriteria = rdt.RDTGetConfig( @nFunc, 'PreRcvSearchCriteria', @cStorerkey)
   IF @cPreRcvSearchCriteria IN ('0', '')
      SET @cPreRcvSearchCriteria = ''

   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''

   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   SET @cShowPltPositionSP = rdt.RDTGetConfig( @nFunc, 'ShowPltPositionSP', @cStorerKey)
   IF @cShowPltPositionSP = '0'
      SET @cShowPltPositionSP = ''

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   SET @cConfirmPosition = rdt.RDTGetConfig( @nFunc, 'ConfirmPosition', @cStorerKey)
   SET @cRetainParm1Value = rdt.RDTGetConfig( @nFunc, 'RetainParm1Value', @cStorerKey)

   SET @cRetainParm2Value = rdt.RDTGetConfig( @nFunc, 'RetainParm2Value', @cStorerKey)

   SET @cRetainParm3Value = rdt.RDTGetConfig( @nFunc, 'RetainParm3Value', @cStorerKey)

   SET @cRetainParm4Value = rdt.RDTGetConfig( @nFunc, 'RetainParm4Value', @cStorerKey)

   SET @cRetainParm5Value = rdt.RDTGetConfig( @nFunc, 'RetainParm5Value', @cStorerKey)

   SET @cCaptureQty = rdt.RDTGetConfig( @nFunc, 'CaptureQty', @cStorerKey)

   DECLARE @cAuthority NVARCHAR(1), @bSuccess INT
   SELECT @bSuccess = 0
   EXECUTE nspGetRight
      @c_Facility    = @cFacility,
      @c_StorerKey   = @cStorerKey,
      @c_SKU         = NULL,
      @c_ConfigKey   = 'UCC',
      @b_success     = @bSuccess    OUTPUT,
      @c_authority   = @cAuthority  OUTPUT,
      @n_err         = @nErrNo      OUTPUT,
      @c_errmsg      = @cErrMsg     OUTPUT

   IF @bSuccess = '1' AND @cAuthority = '1'
      SET @cUCC = '1'
   ELSE 
      SET @cUCC = ''

   SELECT
      @cParamLabel1 = UDF01,
      @cParamLabel2 = UDF02,
      @cParamLabel3 = UDF03,
      @cParamLabel4 = UDF04,
      @cParamLabel5 = UDF05
   FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'PRESORTFLD'
      AND Code = @cPreRcvSearchCriteria
      AND StorerKey = @cStorerKey

   -- Check pallet criteria setup
   IF @cParamLabel1 = '' AND
      @cParamLabel2 = '' AND
      @cParamLabel3 = '' AND
      @cParamLabel4 = '' AND
      @cParamLabel5 = ''
   BEGIN
      SET @nErrNo = 112401
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Param NotSetup
      GOTO Quit
   END

   -- Enable / disable field
   SET @cFieldAttr02 = CASE WHEN @cParamLabel1 = '' THEN 'O' ELSE '' END
   SET @cFieldAttr04 = CASE WHEN @cParamLabel2 = '' THEN 'O' ELSE '' END
   SET @cFieldAttr06 = CASE WHEN @cParamLabel3 = '' THEN 'O' ELSE '' END
   SET @cFieldAttr08 = CASE WHEN @cParamLabel4 = '' THEN 'O' ELSE '' END
   SET @cFieldAttr10 = CASE WHEN @cParamLabel5 = '' THEN 'O' ELSE '' END

   -- Clear optional in field
   SET @cInField02 = ''
   SET @cInField04 = ''
   SET @cInField06 = ''
   SET @cInField08 = ''
   SET @cInField10 = ''
   SET @cInField11 = ''

   SET @cOption = ''

   -- Prepare next screen var
   SET @cOutField01 = @cParamLabel1
   SET @cOutField02 = ''
   SET @cOutField03 = @cParamLabel2
   SET @cOutField04 = ''
   SET @cOutField05 = @cParamLabel3
   SET @cOutField06 = ''
   SET @cOutField07 = @cParamLabel4
   SET @cOutField08 = ''
   SET @cOutField09 = @cParamLabel5
   SET @cOutField10 = ''
   SET @cOutField11 = ''

   SET @nScn = 4980
   SET @nStep = 1

   EXEC rdt.rdtSetFocusField @nMobile, 2

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 4980
   Param1      (field01, input)   
   Param2      (field02, input)   
   Param3      (field03, input)   
   Param4      (field04, input)   
   Param5      (field05, input)   
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cParam1 = @cInField02
      SET @cParam2 = @cInField04
      SET @cParam3 = @cInField06
      SET @cParam4 = @cInField08
      SET @cParam5 = @cInField10
      SET @cOption = @cInField11

      -- Retain value
      SET @cOutField02 = @cInField02
      SET @cOutField04 = @cInField04
      SET @cOutField06 = @cInField06
      SET @cOutField08 = @cInField08
      SET @cOutField10 = @cInField10

      IF ISNULL( @cOption, '') <> ''
      BEGIN
         IF @cOption <> '1'
         BEGIN
            SET @nErrNo = 112406
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
            GOTO Step_1_Fail
         END

         SET @cOutField01 = ''

         SET @cFieldAttr02 = ''
         SET @cFieldAttr04 = ''
         SET @cFieldAttr06 = ''
         SET @cFieldAttr08 = ''
         SET @cFieldAttr10 = ''

         SET @nScn = @nScn + 3
         SET @nStep = @nStep + 3

         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cParam1       NVARCHAR( 20),  ' +
               '@cParam2       NVARCHAR( 20),  ' +
               '@cParam3       NVARCHAR( 20),  ' +
               '@cParam4       NVARCHAR( 20),  ' +
               '@cParam5       NVARCHAR( 20),  ' +
               '@cUCCNo        NVARCHAR( 20),  ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      SELECT
         @cParamLabel1 = UDF01,
         @cParamLabel2 = UDF02,
         @cParamLabel3 = UDF03,
         @cParamLabel4 = UDF04,
         @cParamLabel5 = UDF05
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'PRESORTFLD'
         AND Code = @cPreRcvSearchCriteria
         AND StorerKey = @cStorerKey

      -- Extended validate
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo1 = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo, ' +
               ' @cExtendedInfo1 OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cParam1         NVARCHAR( 20),  ' +
               '@cParam2         NVARCHAR( 20),  ' +
               '@cParam3         NVARCHAR( 20),  ' +
               '@cParam4         NVARCHAR( 20),  ' +
               '@cParam5         NVARCHAR( 20),  ' +
               '@cUCCNo          NVARCHAR( 20), ' +
               '@cExtendedInfo1  NVARCHAR( 20)  OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo,
               @cExtendedInfo1 OUTPUT
         END
      END

      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

      SET @cOutField01 = ''               -- UCC
      SET @cOutField02 = @cParamLabel1
      SET @cOutField03 = @cParam1
      SET @cOutField04 = @cParamLabel2
      SET @cOutField05 = @cParam2
      SET @cOutField06 = @cParamLabel3
      SET @cOutField07 = @cParam3
      SET @cOutField08 = @cParamLabel4
      SET @cOutField09 = @cParam4
      SET @cOutField10 = @cParamLabel5
      SET @cOutField11 = @cParam5
      SET @cOutField12 = @cExtendedInfo1

      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cParam1       NVARCHAR( 20),  ' +
               '@cParam2       NVARCHAR( 20),  ' +
               '@cParam3       NVARCHAR( 20),  ' +
               '@cParam4       NVARCHAR( 20),  ' +
               '@cParam5       NVARCHAR( 20),  ' +
               '@cUCCNo        NVARCHAR( 20),  ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-Out
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey

      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

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
      SET @cReceiptGroup = ''
      SET @cOption = ''

      SET @cOutField01 = ''
      SET @cOutField11 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 2
   END
   GOTO Quit
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 4981. 
   RECEIPTGROUP   (field01)
   UCC            (field02, input)
   TTL ASN        (field03)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cUCCNo = @cInField01
      SET @cBarcode = @cInField01

      IF ISNULL( @cUCCNo, '') = ''
      BEGIN
         SET @nErrNo = 112402
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC required
         GOTO Step_2_Fail
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
               @cToID       OUTPUT, @cUCCNo      OUTPUT, @nQTY        OUTPUT, 
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT
         END
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile,    @nFunc,     @cLangCode,    @nStep,        @nInputKey,    @cStorerKey, ' + 
               ' @cParam1,    @cParam2,   @cParam3,      @cParam4,      @cParam5,      @cBarcode, ' +
               ' @cUCCNo      OUTPUT,     @nErrNo        OUTPUT,        @cErrMsg        OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cParam1      NVARCHAR( 20), ' +
               ' @cParam2      NVARCHAR( 20), ' +
               ' @cParam3      NVARCHAR( 20), ' +
               ' @cParam4      NVARCHAR( 20), ' +
               ' @cParam5      NVARCHAR( 20), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cUCCNo       NVARCHAR( 20)  OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, 
               @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cBarcode,
               @cUCCNo  OUTPUT, @nErrNo   OUTPUT, @cErrMsg  OUTPUT

            IF @nErrNo <> 0
               GOTO Step_2_Fail
         END
      END

      -- If storer turn on UCC config then only check UCC table
      -- Some might just scan SKU/UPC only
      IF @cUCC = '1'
      BEGIN
         SELECT @cUCCStatus = [Status],
                @cSKU   = SKU
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCCNo
         AND   [Status] = '0'

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 112403
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Not Exists
            GOTO Step_2_Fail
         END

         IF @cUCCStatus <> '0'
         BEGIN
            SET @nErrNo = 112404
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Received
            GOTO Step_2_Fail
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cParam1       NVARCHAR( 20),  ' +
               '@cParam2       NVARCHAR( 20),  ' +
               '@cParam3       NVARCHAR( 20),  ' +
               '@cParam4       NVARCHAR( 20),  ' +
               '@cParam5       NVARCHAR( 20),  ' +
               '@cUCCNo        NVARCHAR( 20),  ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      SET @nErrNo = 0
      SELECT @cPosition01 = '', @cPosition02 = '', @cPosition03 = '', @cPosition04 = '', @cPosition05 = ''
      SELECT @cPosition06 = '', @cPosition07 = '', @cPosition08 = '', @cPosition09 = '', @cPosition10 = ''

      IF @cShowPltPositionSP <> '' AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cShowPltPositionSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cShowPltPositionSP) +     
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo, 
              @cPosition01 OUTPUT, @cPosition02 OUTPUT, @cPosition03 OUTPUT, @cPosition04 OUTPUT, @cPosition05 OUTPUT, 
              @cPosition06 OUTPUT, @cPosition07 OUTPUT, @cPosition08 OUTPUT, @cPosition09 OUTPUT, @cPosition10 OUTPUT, 
              @nErrNo OUTPUT, @cErrMsg OUTPUT ' 

         SET @cSQLParam =    
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' +
            '@cStorerkey      NVARCHAR( 15), ' +
            '@cFacility       NVARCHAR( 5),  ' +
            '@cParam1         NVARCHAR( 20),  ' +
            '@cParam2         NVARCHAR( 20),  ' +
            '@cParam3         NVARCHAR( 20),  ' +
            '@cParam4         NVARCHAR( 20),  ' +
            '@cParam5         NVARCHAR( 20),  ' +
            '@cUCCNo          NVARCHAR( 20), ' + 
            '@cPosition01     NVARCHAR( 20)  OUTPUT, ' + 
            '@cPosition02     NVARCHAR( 20)  OUTPUT, ' + 
            '@cPosition03     NVARCHAR( 20)  OUTPUT, ' + 
            '@cPosition04     NVARCHAR( 20)  OUTPUT, ' + 
            '@cPosition05     NVARCHAR( 20)  OUTPUT, ' + 
            '@cPosition06     NVARCHAR( 20)  OUTPUT, ' + 
            '@cPosition07     NVARCHAR( 20)  OUTPUT, ' + 
            '@cPosition08     NVARCHAR( 20)  OUTPUT, ' + 
            '@cPosition09     NVARCHAR( 20)  OUTPUT, ' + 
            '@cPosition10     NVARCHAR( 20)  OUTPUT, ' + 
            '@nErrNo          INT            OUTPUT, ' + 
            '@cErrMsg         NVARCHAR( 20)  OUTPUT  ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo, 
            @cPosition01 OUTPUT, @cPosition02 OUTPUT, @cPosition03 OUTPUT, @cPosition04 OUTPUT, @cPosition05 OUTPUT, 
            @cPosition06 OUTPUT, @cPosition07 OUTPUT, @cPosition08 OUTPUT, @cPosition09 OUTPUT, @cPosition10 OUTPUT, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT
      END
      ELSE
      BEGIN
         SET @nErrNo = 112405
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SProc notsetup
         GOTO Step_2_Fail
      END
            
      IF @nErrNo <> 0
         GOTO Step_2_Fail

      -- EventLog    --(cc01)
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '4',
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @cUCC        = @cUCCNo
            
      -- Prep next screen var
      SET @cOutField01 = @cUCCNo
      SET @cOutField02 = @cPosition01
      SET @cOutField03 = @cPosition02
      SET @cOutField04 = @cPosition03
      SET @cOutField05 = @cPosition04
      SET @cOutField06 = @cPosition05
      SET @cOutField07 = @cPosition06
      SET @cOutField08 = @cPosition07
      SET @cOutField09 = @cPosition08
      SET @cOutField10 = @cPosition09
      SET @cOutField11 = @cPosition10

      IF @cConfirmPosition <> '0'
      BEGIN
         SET @cOutField11 = ''
         SET @cFieldAttr11 = ''
      END
      ELSE
         SET @cFieldAttr11 = 'O'

      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END
   
   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Enable / disable field
      SET @cFieldAttr02 = CASE WHEN @cParamLabel1 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr04 = CASE WHEN @cParamLabel2 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr06 = CASE WHEN @cParamLabel3 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr08 = CASE WHEN @cParamLabel4 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr10 = CASE WHEN @cParamLabel5 = '' THEN 'O' ELSE '' END

      -- Clear optional in field
      SET @cInField02 = ''
      SET @cInField04 = ''
      SET @cInField06 = ''
      SET @cInField08 = ''
      SET @cInField10 = ''

      -- Prepare next screen var
      SET @cOutField01 = @cParamLabel1
      SET @cOutField02 = CASE WHEN @cRetainParm1Value = '1' THEN @cParam1 ELSE '' END
      SET @cOutField03 = @cParamLabel2
      SET @cOutField04 = CASE WHEN @cRetainParm1Value = '1' THEN @cParam2 ELSE '' END
      SET @cOutField05 = @cParamLabel3
      SET @cOutField06 = CASE WHEN @cRetainParm1Value = '1' THEN @cParam3 ELSE '' END
      SET @cOutField07 = @cParamLabel4
      SET @cOutField08 = CASE WHEN @cRetainParm1Value = '1' THEN @cParam4 ELSE '' END
      SET @cOutField09 = @cParamLabel5
      SET @cOutField10 = CASE WHEN @cRetainParm1Value = '1' THEN @cParam5 ELSE '' END

      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cUCCNo = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 3. Scn = 4982. Result
   UCC         (field01)
   POSITION    (field02)
   Suggest POS (field10)
   Confirm POS (field11, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --  ENTER
   BEGIN
      IF @cConfirmPosition <> '0'
      BEGIN
         -- Check suggested and actual position
         IF @cConfirmPosition = '1' AND   -- Confirm position and must match
            @cOutField10 <> '' AND        -- There is suggested position
            @cInField11 <> @cOutField10   -- Suggested position and confirm position not match
         BEGIN
            SET @nErrNo = 112408
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff value
            GOTO Quit
         END
         SET @cOutField11 = @cInField11 
      END
   END
   
   -- Extended update
   IF @cExtendedUpdateSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile       INT,           ' +
            '@nFunc         INT,           ' +
            '@cLangCode     NVARCHAR( 3),  ' +
            '@nStep         INT,           ' +
            '@nInputKey     INT,           ' +
            '@cStorerKey    NVARCHAR( 15), ' +
            '@cParam1       NVARCHAR( 20),  ' +
            '@cParam2       NVARCHAR( 20),  ' +
            '@cParam3       NVARCHAR( 20),  ' +
            '@cParam4       NVARCHAR( 20),  ' +
            '@cParam5       NVARCHAR( 20),  ' +
            '@cUCCNo        NVARCHAR( 20),  ' +
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo,
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END
   END
   
   SELECT
      @cParamLabel1 = UDF01,
      @cParamLabel2 = UDF02,
      @cParamLabel3 = UDF03,
      @cParamLabel4 = UDF04,
      @cParamLabel5 = UDF05
   FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'PRESORTFLD'
      AND Code = @cPreRcvSearchCriteria
      AND StorerKey = @cStorerKey

   -- Extended validate
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo1 = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo, ' +
            ' @cExtendedInfo1 OUTPUT '
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' +
            '@cStorerKey      NVARCHAR( 15), ' +
            '@cParam1         NVARCHAR( 20),  ' +
            '@cParam2         NVARCHAR( 20),  ' +
            '@cParam3         NVARCHAR( 20),  ' +
            '@cParam4         NVARCHAR( 20),  ' +
            '@cParam5         NVARCHAR( 20),  ' +
            '@cUCCNo          NVARCHAR( 20), ' +
            '@cExtendedInfo1  NVARCHAR( 20)  OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo,
            @cExtendedInfo1 OUTPUT
      END
   END

   IF @cCaptureQty <> '1'
   BEGIN
      SET @cOutField01 = ''               -- UCC
      SET @cOutField02 = @cParamLabel1
      SET @cOutField03 = @cParam1
      SET @cOutField04 = @cParamLabel2
      SET @cOutField05 = @cParam2
      SET @cOutField06 = @cParamLabel3
      SET @cOutField07 = @cParam3
      SET @cOutField08 = @cParamLabel4
      SET @cOutField09 = @cParam4
      SET @cOutField10 = @cParamLabel5
      SET @cOutField11 = @cParam5
      SET @cOutField12 = @cExtendedInfo1

      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   ELSE
   BEGIN
      SET @cOutField01 = ''               -- SKU
      SET @cOutField02 = ''               -- UOM
      SET @cOutField15 = @cExtendedInfo1

      SET @nScn  = @nScn + 2
      SET @nStep = @nStep + 2
   END
END
GOTO Quit

/********************************************************************************
Step 4. Scn = 4983
   Option      (field01, input)   
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      IF ISNULL( @cOption, '') NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 112409
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         GOTO Step_4_Fail
      END

      IF @cOption = '1'
      BEGIN
         -- Extended validate
         IF @cExtendedValidateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo, ' +
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile       INT,           ' +
                  '@nFunc         INT,           ' +
                  '@cLangCode     NVARCHAR( 3),  ' +
                  '@nStep         INT,           ' +
                  '@nInputKey     INT,           ' +
                  '@cStorerKey    NVARCHAR( 15), ' +
                  '@cParam1       NVARCHAR( 20),  ' +
                  '@cParam2       NVARCHAR( 20),  ' +
                  '@cParam3       NVARCHAR( 20),  ' +
                  '@cParam4       NVARCHAR( 20),  ' +
                  '@cParam5       NVARCHAR( 20),  ' +
                  '@cUCCNo        NVARCHAR( 20),  ' +
                  '@nErrNo        INT           OUTPUT, ' +
                  '@cErrMsg       NVARCHAR( 20) OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo,
                  @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END

         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo, ' +
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  '@nMobile       INT,           ' +
                  '@nFunc         INT,           ' +
                  '@cLangCode     NVARCHAR( 3),  ' +
                  '@nStep         INT,           ' +
                  '@nInputKey     INT,           ' +
                  '@cStorerKey    NVARCHAR( 15), ' +
                  '@cParam1       NVARCHAR( 20),  ' +
                  '@cParam2       NVARCHAR( 20),  ' +
                  '@cParam3       NVARCHAR( 20),  ' +
                  '@cParam4       NVARCHAR( 20),  ' +
                  '@cParam5       NVARCHAR( 20),  ' +
                  '@cUCCNo        NVARCHAR( 20),  ' +
                  '@nErrNo        INT           OUTPUT, ' +
                  '@cErrMsg       NVARCHAR( 20) OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo,
                  @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END

         -- Enable / disable field
         SET @cFieldAttr02 = CASE WHEN @cParamLabel1 = '' THEN 'O' ELSE '' END
         SET @cFieldAttr04 = CASE WHEN @cParamLabel2 = '' THEN 'O' ELSE '' END
         SET @cFieldAttr06 = CASE WHEN @cParamLabel3 = '' THEN 'O' ELSE '' END
         SET @cFieldAttr08 = CASE WHEN @cParamLabel4 = '' THEN 'O' ELSE '' END
         SET @cFieldAttr10 = CASE WHEN @cParamLabel5 = '' THEN 'O' ELSE '' END

         -- Clear optional in field
         SET @cInField02 = ''
         SET @cInField04 = ''
         SET @cInField06 = ''
         SET @cInField08 = ''
         SET @cInField10 = ''
         SET @cInField11 = ''

         SET @cOption = ''

         -- Prepare next screen var
         SET @cOutField01 = @cParamLabel1
         SET @cOutField02 = ''
         SET @cOutField03 = @cParamLabel2
         SET @cOutField04 = ''
         SET @cOutField05 = @cParamLabel3
         SET @cOutField06 = ''
         SET @cOutField07 = @cParamLabel4
         SET @cOutField08 = ''
         SET @cOutField09 = @cParamLabel5
         SET @cOutField10 = ''
         SET @cOutField11 = ''

         SET @nScn = 4980
         SET @nStep = 1

         EXEC rdt.rdtSetFocusField @nMobile, 2
      END

      IF @cOption = '2'
      BEGIN
         -- Enable / disable field
         SET @cFieldAttr02 = CASE WHEN @cParamLabel1 = '' THEN 'O' ELSE '' END
         SET @cFieldAttr04 = CASE WHEN @cParamLabel2 = '' THEN 'O' ELSE '' END
         SET @cFieldAttr06 = CASE WHEN @cParamLabel3 = '' THEN 'O' ELSE '' END
         SET @cFieldAttr08 = CASE WHEN @cParamLabel4 = '' THEN 'O' ELSE '' END
         SET @cFieldAttr10 = CASE WHEN @cParamLabel5 = '' THEN 'O' ELSE '' END

         -- Clear optional in field
         SET @cInField02 = ''
         SET @cInField04 = ''
         SET @cInField06 = ''
         SET @cInField08 = ''
         SET @cInField10 = ''
         SET @cInField11 = ''

         SET @cOption = ''

         -- Prepare next screen var
         SET @cOutField01 = @cParamLabel1
         SET @cOutField02 = ''
         SET @cOutField03 = @cParamLabel2
         SET @cOutField04 = ''
         SET @cOutField05 = @cParamLabel3
         SET @cOutField06 = ''
         SET @cOutField07 = @cParamLabel4
         SET @cOutField08 = ''
         SET @cOutField09 = @cParamLabel5
         SET @cOutField10 = ''
         SET @cOutField11 = ''

         SET @nScn = 4980
         SET @nStep = 1

         EXEC rdt.rdtSetFocusField @nMobile, 2
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Enable / disable field
      SET @cFieldAttr02 = CASE WHEN @cParamLabel1 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr04 = CASE WHEN @cParamLabel2 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr06 = CASE WHEN @cParamLabel3 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr08 = CASE WHEN @cParamLabel4 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr10 = CASE WHEN @cParamLabel5 = '' THEN 'O' ELSE '' END

      -- Clear optional in field
      SET @cInField02 = ''
      SET @cInField04 = ''
      SET @cInField06 = ''
      SET @cInField08 = ''
      SET @cInField10 = ''
      SET @cInField11 = ''

      SET @cOption = ''

      -- Prepare next screen var
      SET @cOutField01 = @cParamLabel1
      SET @cOutField02 = ''
      SET @cOutField03 = @cParamLabel2
      SET @cOutField04 = ''
      SET @cOutField05 = @cParamLabel3
      SET @cOutField06 = ''
      SET @cOutField07 = @cParamLabel4
      SET @cOutField08 = ''
      SET @cOutField09 = @cParamLabel5
      SET @cOutField10 = ''
      SET @cOutField11 = ''

      SET @nScn = 4980
      SET @nStep = 1

      EXEC rdt.rdtSetFocusField @nMobile, 2
   END

   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = ''
   END
END

GOTO Quit

/********************************************************************************
Step 5. Scn = 4984
   Qty      (field01, input)   
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cQTY = @cInField01

      -- Validate QTY
      IF @cQTY <> '' AND RDT.rdtIsValidQTY( @cQTY, 0) = 0
      BEGIN
         SET @nErrNo = 112407
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         GOTO Quit
      END
      SET @nQTY = CAST( @cQTY AS INT)

      INSERT INTO @tExtendedUpdate (Variable, Value) VALUES ( '@nQty',     @nQTY)
      --insert into TraceInfo (tracename, timein, col1, col2) values ('1829a', getdate(), @nQty, @cQty)
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @tExtendedUpdate '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cParam1       NVARCHAR( 20),  ' +
               '@cParam2       NVARCHAR( 20),  ' +
               '@cParam3       NVARCHAR( 20),  ' +
               '@cParam4       NVARCHAR( 20),  ' +
               '@cParam5       NVARCHAR( 20),  ' +
               '@cUCCNo        NVARCHAR( 20),  ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT, ' + 
               '@tExtendedUpdate VariableTable ReadOnly '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cUCCNo,
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @tExtendedUpdate

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      SET @cOutField01 = ''               -- UCC
      SET @cOutField02 = @cParamLabel1
      SET @cOutField03 = @cParam1
      SET @cOutField04 = @cParamLabel2
      SET @cOutField05 = @cParam2
      SET @cOutField06 = @cParamLabel3
      SET @cOutField07 = @cParam3
      SET @cOutField08 = @cParamLabel4
      SET @cOutField09 = @cParam4
      SET @cOutField10 = @cParamLabel5
      SET @cOutField11 = @cParam5
      SET @cOutField12 = @cExtendedInfo1

      SET @nScn  = @nScn - 3
      SET @nStep = @nStep - 3
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

      SET @cOutField01 = ''               -- UCC
      SET @cOutField02 = @cParamLabel1
      SET @cOutField03 = @cParam1
      SET @cOutField04 = @cParamLabel2
      SET @cOutField05 = @cParam2
      SET @cOutField06 = @cParamLabel3
      SET @cOutField07 = @cParam3
      SET @cOutField08 = @cParamLabel4
      SET @cOutField09 = @cParam4
      SET @cOutField10 = @cParamLabel5
      SET @cOutField11 = @cParam5
      SET @cOutField12 = @cExtendedInfo1

      SET @nScn  = @nScn - 3
      SET @nStep = @nStep - 3
   END
   
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = ''
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
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      UserName  = @cUserName,

      V_ReceiptKey = @cReceiptKey,
      V_LOC        = @cLane,
      V_UCC        = @cUCCNo,

      V_String1 = @cParam1,
      V_String2 = @cParam2,
      V_String3 = @cParam3,
      V_String4 = @cParam4,
      V_String5 = @cParam5,
      V_String6 = @cParamLabel1,
      V_String7 = @cParamLabel2,
      V_String8 = @cParamLabel3,
      V_String9 = @cParamLabel4,
      V_String10 = @cParamLabel5,
      V_String11 = @cCaptureQty,
      V_String12 = @cExtendedValidateSP,
      V_String13 = @cExtendedInfoSP,
      V_String14 = @cShowPltPositionSP,
      V_String15 = @cPreRcvSearchCriteria,
      V_String16 = @cExtendedUpdateSP,
      V_String17 = @cDecodeSP,
      V_String18 = @cRetainParm1Value,
      V_String19 = @cRetainParm2Value,
      V_String20 = @cRetainParm3Value,
      V_String21 = @cRetainParm4Value,
      V_String22 = @cRetainParm5Value,
      V_String23 = @cConfirmPosition,

      V_Integer1 = @nTTL_ASN,

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