SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************************/
/* Store procedure: rdtfnc_IkeaEcomReturn                                                          */
/* Copyright      : Maersk                                                                         */
/*                                                                                                 */
/* Purpose: Ecomm Trade Return                                                                     */
/*                                                                                                 */
/* Modifications log:                                                                              */
/*                                                                                                 */
/* Date         Rev  Author      Purposes                                                          */
/* 2023-07-21   1.0  James       WMS-22912. Created                                                */
/* 2023-09-13   1.1  James       Adhoc fix rdt_Decode used invalid type (james01)                  */
/***************************************************************************************************/
CREATE   PROC [RDT].[rdtfnc_IkeaEcomReturn](
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
   @nTranCount          INT,
   @cBarcode            NVARCHAR( 60),
   @cSQL                NVARCHAR( MAX),
   @cSQLParam           NVARCHAR( MAX),
   @tExtValidVar        VARIABLETABLE,
   @tExtUpdateVar       VARIABLETABLE,
   @tConfirmVar         VARIABLETABLE,
   @tExtInfoVar         VARIABLETABLE

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

   @cStorerKey          NVARCHAR( 15),
   @cUOM                NVARCHAR( 10),
   @cReceiptKey         NVARCHAR( 10),
   @cToLOC              NVARCHAR( 10),
   @cToID               VARCHAR( 18),
   @cSKU                NVARCHAR( 60),
   @cSKUDesc            NVARCHAR( 60),
   @nQTY                INT,
   @cType               NVARCHAR( 10),
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
   @nTotalASNQTY        INT,
   @nTotalREFQTY        INT,
   @nQTYExp             INT,
   @nQTYRcv             INT,
   @nUdf05              INT,
   @nFromScn            INT,
   @nSkuDamage          INT,
   @nParcelCnt          INT,
   @bSuccess            INT,
   @nBeforeReceivedQty  INT,
   
   @cRefNo              NVARCHAR( 60),
   @cLottableCode       NVARCHAR( 30),
   @cReceiptLineNumber  NVARCHAR( 5),
   @cConditionCode      NVARCHAR( 10),
   @cSubreasonCode      NVARCHAR( 10),

   @cDecodeSKUSP           NVARCHAR( 20),
   @cExtendedInfoSP        NVARCHAR( 20),
   @cExtendedInfo          NVARCHAR( 20),
   @cExtendedValidateSP    NVARCHAR( 20),
   @cExtendedUpdateSP      NVARCHAR( 20),

   @cDecodeSP              NVARCHAR( 20),
   @cMethod                NVARCHAR( 1),
   @cErrMsg1               NVARCHAR( 20),
   @cErrMsg2               NVARCHAR( 20),
   @cErrMsg3               NVARCHAR( 20),
   @cErrMsg4               NVARCHAR( 20),
   @cErrMsg5               NVARCHAR( 20),
   @cQTY                   NVARCHAR( 5),
   @cDefaultQTY            NVARCHAR( 5),
   @cSkuDamage             NVARCHAR( 5),
   @cParcelDmg             NVARCHAR( 1),
   @cRDLineNumber          NVARCHAR( 5),
   @nRDExpQty              INT,
   @cIDBarcode             NVARCHAR( 60),
   @cID                    NVARCHAR( 18),
   @cUDF05                 NVARCHAR( 10),
   @cOption                NVARCHAR( 3),
   @cLine                  NVARCHAR( 5),
   @curVerifySKU           CURSOR,
   @nCnt                   INT,
   
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

   @cStorerKey    = V_StorerKey,
   @cUOM          = V_UOM,
   @cReceiptKey   = V_ReceiptKey,
   @cToLOC        = V_LOC,
   @cToID         = V_ID,
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
   @nParcelCnt    = V_Integer3,

   @cRefNo                 = V_String1,
   @cLottableCode          = V_String2,
   @cMethod                = V_String3,
   @cDefaultQTY            = V_String4,
   @cReceiptLineNumber     = V_String5,
   @cConditionCode         = V_String6,
   @cSubreasonCode         = V_String7,
   @cDecodeSP              = V_String8,
   @cDecodeSKUSP           = V_String9,
   @cExtendedInfoSP        = V_String10,
   @cExtendedInfo          = V_String11,
   @cExtendedValidateSP    = V_String12,
   @cExtendedUpdateSP      = V_String13,

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
   @nStep_ToIDLocType      INT,  @nScn_ToIDLocType    INT,
   @nStep_MethodRefNo      INT,  @nScn_MethodRefNo    INT,
   @nStep_SkuQty           INT,  @nScn_SkuQty         INT,
   @nStep_SkuDamage        INT,  @nScn_SkuDamage      INT,
   @nStep_RefNoParcelDmg   INT,  @nScn_RefNoParcelDmg INT,
   @nStep_VerifySKU        INT,  @nScn_VerifySKU      INT

SELECT
   @nStep_ToIDLocType      = 1,  @nScn_ToIDLocType    = 6270,
   @nStep_MethodRefNo      = 2,  @nScn_MethodRefNo    = 6271,
   @nStep_SkuQty           = 3,  @nScn_SkuQty         = 6272,
   @nStep_SkuDamage        = 4,  @nScn_SkuDamage      = 6273,
   @nStep_RefNoParcelDmg   = 5,  @nScn_RefNoParcelDmg = 6274,
   @nStep_VerifySKU        = 6,  @nScn_VerifySKU      = 6275

IF @nFunc = 657
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start            -- Menu. 607
   IF @nStep = 1  GOTO Step_ToIDLocType      -- Scn = 6270. TO ID, TO LOC, TYPE
   IF @nStep = 2  GOTO Step_MethodRefNo      -- Scn = 6271. METHOD, REF NO
   IF @nStep = 3  GOTO Step_SkuQty           -- Scn = 6272. SKU, QTY
   IF @nStep = 4  GOTO Step_SkuDamage        -- Scn = 6273. SKU DAMAGE
   IF @nStep = 5  GOTO Step_RefNoParcelDmg   -- Scn = 6274. REFNO, PARCEL DAMAGE
   IF @nStep = 6  GOTO Step_VerifySKU        -- Scn = 6275. VERIFY SKU
END
RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 657
********************************************************************************/
Step_Start:
BEGIN
   -- Get storer config
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
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
   SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)
   IF @cDefaultQTY = '0'
      SET @cDefaultQTY = ''

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey


   -- Prepare next screen var
   SET @cOutField01 = '' -- To ID
   SET @cOutField02 = '' -- To LOC
   SET @cOutField03 = '' -- TYPE

   EXEC rdt.rdtSetFocusField @nMobile, 1

   -- Set the entry point
   SET @nScn = @nScn_ToIDLocType
   SET @nStep = @nStep_ToIDLocType

END
GOTO Quit

/************************************************************************************
Step 1. Scn = 6270. TO ID, TO LOC, TYPE screen
   TO ID    (field01, input)
   TO LOC   (field02, input)
   TYPE     (field02, input)
************************************************************************************/
Step_ToIDLocType:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToID = @cInField01
      SET @cToLOC = @cInField02
      SET @cType = @cInField03
      SET @cIDBarcode = @cInField01

      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'Type', @cType) = 0  
      BEGIN  
         SET @nErrNo = 203901  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format  
         GOTO Step_Type_Fail  
      END 
      
      IF @cType = '99'
      BEGIN
         SET @nParcelCnt = 0
         
         -- Prepare next screen var
         SET @cOutField01 = '' -- REF NO
         SET @cOutField02 = '' -- PARCEL DAMAGE
         SET @cOutField03 = @nParcelCnt
         
         EXEC rdt.rdtSetFocusField @nMobile, 1
         
         SET @nScn = @nScn_RefNoParcelDmg
         SET @nStep = @nStep_RefNoParcelDmg
         
         GOTO Quit
      END
      
      -- Check blank
      IF @cToID = '' 
      BEGIN
         SET @nErrNo = 203902
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need To ID
         GOTO Step_ToID_Fail
      END
      
      IF @cToLOC = ''
      BEGIN
         SET @nErrNo = 203903
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need To LOC
         GOTO Step_ToLOC_Fail
      END
      
      -- Decode
      -- Standard decode
      IF @cDecodeSP = '1'
      BEGIN
         EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cIDBarcode,
            @cID     = @cToID   OUTPUT,
            @nErrNo  = @nErrNo  OUTPUT,
            @cErrMsg = @cErrMsg OUTPUT,
            @cType   = 'ID'

         IF @nErrNo <> 0
            GOTO Step_ToID_Fail
      END

      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ToID', @cToID) = 0  
      BEGIN  
         SET @nErrNo = 203904  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format  
         GOTO Step_ToID_Fail  
      END  

      IF NOT EXISTS( SELECT 1
                     FROM dbo.LOC WITH (NOLOCK)
                     WHERE Facility = @cFacility
                     AND   Loc = @cToLOC)  
      BEGIN  
         SET @nErrNo = 203905  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid To Loc  
         GOTO Step_ToLOC_Fail  
      END  

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
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
               '@tExtValidVar  VariableTable READONLY, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cToID, @cToLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
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
               '@tExtUpdateVar VariableTable READONLY, ' +
               '@nErrNo        INT           OUTPUT,   ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cToID, @cToLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = ''   -- METHOD
      SET @cOutField02 = ''   -- REF NO

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to next screen
      SET @nScn = @nScn_MethodRefNo
      SET @nStep = @nStep_MethodRefNo
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
   
   Step_ToID_Fail:
   BEGIN
   	SET @cOutField01 = ''
   	SET @cOutField02 = @cToLOC
   	SET @cOutField03 = @cType
   	
   	SET @cToID = ''
   	EXEC rdt.rdtSetFocusField @nMobile, 1
   	GOTO Quit
   END
   
   Step_ToLOC_Fail:
   BEGIN
   	SET @cOutField01 = @cToID
   	SET @cOutField02 = ''
   	SET @cOutField03 = @cType
   	
   	SET @cToLOC = ''
   	EXEC rdt.rdtSetFocusField @nMobile, 2
   	GOTO Quit
   END
   
   Step_Type_Fail:
   BEGIN
   	SET @cOutField01 = @cToID
   	SET @cOutField02 = @cToLOC
   	SET @cOutField03 = ''
   	
   	SET @cType = ''
   	EXEC rdt.rdtSetFocusField @nMobile, 3
   	GOTO Quit
   END
END
GOTO Quit

/***********************************************************************************
Step 2. Scn = 6271. METHOD, REF NO screen
   METHOD    (field01, input)
   REF NO    (field02, input)
***********************************************************************************/
Step_MethodRefNo:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cMethod = @cInField01
      SET @cRefNo = @cInField02

      -- Check blank
      IF @cMethod = '' 
      BEGIN
         SET @nErrNo = 203906
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Method
         GOTO Step_Method_Fail
      END
      
      IF @cRefNo = ''
      BEGIN
         SET @nErrNo = 203907
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need RefNo
         GOTO Step_RefNo_Fail
      END
      
      SET @cReceiptKey = ''
      SELECT TOP 1 @cReceiptKey = RD.ReceiptKey
      FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
      JOIN dbo.RECEIPT R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
      WHERE R.StorerKey = @cStorerKey
      AND   R.Facility = @cFacility
      AND   RD.StorerKey = @cStorerKey
      AND   RD.UserDefine02 = @cRefNo
      AND   RD.FinalizeFlag <> 'Y'
      ORDER BY 1
      
      IF @cReceiptKey = ''
      BEGIN
         SET @nErrNo = 203908
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN Not Found
         GOTO Step_RefNo_Fail
      END
      
      IF EXISTS ( SELECT 1 
                  FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                  WHERE ReceiptKey = @cReceiptKey
                  AND   SubReasonCode NOT IN ('N', 'Y'))
      BEGIN
      	SET @cErrMsg1 = rdt.rdtgetmessage( 203909, @cLangCode, 'DSP') -- Hand Over
      	SET @cErrMsg2 = rdt.rdtgetmessage( 203910, @cLangCode, 'DSP') -- Not Complete
      	
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2  

         SET @nErrNo = 203910
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not Complete
         GOTO Step_RefNo_Fail      	
      END
      
      SELECT TOP 1 @cID = ToId 
      FROM RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      ORDER BY 1 DESC
      
      IF ISNULL( @cID, '') <> '' AND @cID <> @cToID
      BEGIN
      	SET @cErrMsg1 = rdt.rdtgetmessage( 203911, @cLangCode, 'DSP') -- 1 ASN Only
      	SET @cErrMsg2 = rdt.rdtgetmessage( 203912, @cLangCode, 'DSP') -- 1 To ID
      	
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2  

         SET @nErrNo = 203912
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --1 To ID
         GOTO Step_RefNo_Fail      	
      END
      


      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cRefNo
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- Desc1
      SET @cOutField05 = '' -- Desc2
      SET @cOutField06 = ''
      SET @cOutField07 = CASE WHEN @cDefaultQTY <> '' THEN @cDefaultQTY ELSE '' END -- QTY
      SET @cOutField08 = ''
      
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to next screen
      SET @nScn = @nScn_SkuQty
      SET @nStep = @nStep_SkuQty
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- To ID
      SET @cOutField02 = '' -- To LOC
      SET @cOutField03 = '' -- TYPE

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Set the entry point
      SET @nScn = @nScn_ToIDLocType
      SET @nStep = @nStep_ToIDLocType
   END
   GOTO Quit
   
   Step_Method_Fail:
   BEGIN
   	SET @cOutField01 = ''
   	SET @cOutField02 = @cRefNo

   	SET @cMethod = ''
   	EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   GOTO Quit
   
   Step_RefNo_Fail:
   BEGIN
   	SET @cOutField01 = @cMethod
   	SET @cOutField02 = ''

   	SET @cRefNo = ''
   	EXEC rdt.rdtSetFocusField @nMobile, 2
   END
END
GOTO Quit

/***********************************************************************************
Step 3. Scn = 6272. SKU, QTY screen
   ASN      (field01)
   REF NO   (field02)
   SKU      (field03, input)
   Desc1    (field04)
   Desc2    (field05)
   RCV      (field05)
   QTY      (field06, input)
   ASN QTY  (field07)
***********************************************************************************/
Step_SkuQty:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField03 -- SKU
      SET @cBarcode = @cInField03
      SET @cQTY = @cInField07 -- QTY
      
      -- Validate blank
      IF @cSKU = '' OR @cSKU IS NULL
      BEGIN
         SET @nErrNo = 203913
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
         IF @cDecodeSKUSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cUPC          = @cSKU        OUTPUT, 
               @nQTY          = @nQTY        OUTPUT,
               @nErrNo        = @nErrNo      OUTPUT, 
               @cErrMsg       = @cErrMsg     OUTPUT,
               @cType         = 'UPC'
         END

         IF @nQTY > 0  
            SET @cQTY = CAST( @nQTY AS NVARCHAR( 5)) 
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
         SET @nErrNo = 203914
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

      -- Get SKU info
      SELECT
         @cSKUDesc = ISNULL( DescR, ''),
         @cLottableCode = LottableCode,
         @cUOM = Pack.PackUOM3
      FROM dbo.SKU SKU WITH (NOLOCK)
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

      -- Retain value
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 21, 20) -- SKU desc 2

      -- Check SKU in ASN
      IF NOT EXISTS( SELECT 1
                     FROM dbo.Receiptdetail WITH (NOLOCK)
                     WHERE Receiptkey = @cReceiptKey
                     AND   StorerKey = @cStorerKey
                     AND   SKU = @cSKU
                     AND   UserDefine02 = @cRefNo)
      BEGIN
         SET @nErrNo = 203915
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not in ASN
         GOTO Step_SKU_Fail
      END

      -- Check QTY blank  
      IF @cQTY = ''  
      BEGIN  
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- QTY  
         GOTO Step_QTY_Fail  
      END  

      -- Check QTY valid, Method = 2 allow qty = 0  
      IF @cMethod = 1 AND 
         rdt.rdtIsValidQty( @cQTY, 1) = 0  
      BEGIN  
         SET @nErrNo = 203916  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY  
         GOTO Step_QTY_Fail  
      END  
      ELSE IF @cMethod = 2 AND 
         rdt.rdtIsValidQty( @cQTY, 0) = 0  
      BEGIN  
         SET @nErrNo = 203916  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY  
         GOTO Step_QTY_Fail  
      END  
      
      -- Retain QTY field  
      SET @cOutField07 = @cQTY  
      SET @nQTY = CAST( @cQTY AS INT)  
      
      -- Check over receive
      IF EXISTS( SELECT 1
         FROM ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU
         HAVING ISNULL( SUM( BeforeReceivedQty), 0) + @nQTY >
                  ISNULL( SUM( QTYExpected), 0))
      BEGIN
         SET @nErrNo = 203917
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over received
         GOTO Step_SKU_Fail
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
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
               '@tExtValidVar  VariableTable READONLY, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cToID, @cToLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @tExtValidVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_SKU_Fail
         END
      END

      -- If same refno exists same sku, go to verify sku
      IF EXISTS ( SELECT 1
                  FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                  WHERE ReceiptKey = @cReceiptKey
                  AND   UserDefine02 = @cRefNo
                  AND   Sku = @cSKU
                  GROUP BY Sku
                  HAVING COUNT( Sku) > 1)
      BEGIN
      	-- Prepare next screen variable
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)
         SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         
         SET @nCnt = 1
         SET @curVerifySKU = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT TOP 5 ReceiptLineNumber, QtyExpected
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   UserDefine02 = @cRefNo
         AND   Sku = @cSKU
         AND   QtyExpected > BeforeReceivedQty
         AND   FinalizeFlag <> 'Y'
         ORDER BY ReceiptLineNumber
         OPEN @curVerifySKU
         FETCH NEXT FROM @curVerifySKU INTO @cRDLineNumber, @nRDExpQty
         WHILE @@FETCH_STATUS = 0
         BEGIN
         	IF @nCnt = 1
         	   SET @cOutField04 = SUBSTRING(@cRDLineNumber, PATINDEX('%[^0]%', @cRDLineNumber), LEN(@cRDLineNumber)) + SPACE( 10) + CAST( @nRDExpQty AS NVARCHAR( 3))
         	IF @nCnt = 2
         	   SET @cOutField05 = SUBSTRING(@cRDLineNumber, PATINDEX('%[^0]%', @cRDLineNumber), LEN(@cRDLineNumber)) + SPACE( 10) + CAST( @nRDExpQty AS NVARCHAR( 3))
         	IF @nCnt = 3
         	   SET @cOutField06 = SUBSTRING(@cRDLineNumber, PATINDEX('%[^0]%', @cRDLineNumber), LEN(@cRDLineNumber)) + SPACE( 10) + CAST( @nRDExpQty AS NVARCHAR( 3))
         	IF @nCnt = 4
         	   SET @cOutField07 = SUBSTRING(@cRDLineNumber, PATINDEX('%[^0]%', @cRDLineNumber), LEN(@cRDLineNumber)) + SPACE( 10) + CAST( @nRDExpQty AS NVARCHAR( 3))
         	IF @nCnt = 5
         	   SET @cOutField08 = SUBSTRING(@cRDLineNumber, PATINDEX('%[^0]%', @cRDLineNumber), LEN(@cRDLineNumber)) + SPACE( 10) + CAST( @nRDExpQty AS NVARCHAR( 3))
         	
         	SET @nCnt = @nCnt + 1

         	FETCH NEXT FROM @curVerifySKU INTO @cRDLineNumber, @nRDExpQty
         END
         
         SET @cOutField11 = ''   -- Option
         
         SET @nScn = @nScn_VerifySKU
         SET @nStep = @nStep_VerifySKU
         
         GOTO Quit
      END
      
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN Step_SKU -- For rollback or commit only our own transaction

      -- 1 Refno only 1 distinct same sku scenario, lottable11 = line#
      SELECT @cLine = Lottable11
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   UserDefine02 = @cRefNo
      AND   Sku = @cSKU
      
      SET @cLottable11 = @cLine
      
      -- Receive
      EXEC rdt.rdt_IkeaEcomReturn_Confirm
         @nFunc               = @nFunc,
         @nMobile             = @nMobile,
         @cLangCode           = @cLangCode,
         @cStorerKey          = @cStorerKey,
         @cFacility           = @cFacility,
         @cReceiptKey         = @cReceiptKey,
         @cRefNo              = @cRefNo,
         @cToLoc              = @cToLoc,
         @cToID               = @cToID,
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
         @cConditionCode      = @cConditionCode,
         @cSubreasonCode      = @cSubreasonCode,
         @nSkuDamage          = @nSkuDamage,
         @tConfirmVar         = @tConfirmVar,
         @cReceiptLineNumber  = @cReceiptLineNumber OUTPUT,
         @nErrNo              = @nErrNo    OUTPUT,
         @cErrMsg             = @cErrMsg   OUTPUT

      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN Step_SKU
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Step_SKU_Fail
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
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
               '@tExtUpdateVar VariableTable READONLY, ' +
               '@nErrNo        INT           OUTPUT,   ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cToID, @cToLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN Step_SKU
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Step_SKU_Fail
            END
         END
      END

      COMMIT TRAN Step_SKU
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      IF @cMethod = '2'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = ''	-- SKU DAMAGE
            
         -- Go to next screen
         SET @nScn = @nScn_SkuDamage
         SET @nStep = @nStep_SkuDamage	
            
         GOTO Quit
      END
      
      -- Get statistic
      SELECT
         @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
         @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   UserDefine02 = @cRefNo
      
      -- Already key in toid & toloc, receive and stay in sku screen
      IF @nTotalQTYExp = @nTotalQTYRcv --AND 1 = 0
      BEGIN
         IF @cMethod = '1'
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = ''   -- METHOD
            SET @cOutField02 = ''   -- REF NO

            EXEC rdt.rdtSetFocusField @nMobile, 1

            -- Go to next screen
            SET @nScn = @nScn_MethodRefNo
            SET @nStep = @nStep_MethodRefNo	
         END
         ELSE IF @cMethod = '2'
         BEGIN
         	-- Prepare next screen var
            SET @cOutField01 = ''	-- SKU DAMAGE
            
            -- Go to next screen
            SET @nScn = @nScn_SkuDamage
            SET @nStep = @nStep_SkuDamage	
         END
         
         GOTO Quit
      END

      -- Get statistic
      SELECT
         @nQTYExp = ISNULL( SUM( QtyExpected), 0),
         @nQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   Sku = @cSKU
      AND   UserDefine02 = @cRefNo
         
      SELECT @nTotalASNQTY = ISNULL( SUM( QtyExpected), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      SELECT @nTotalREFQTY = ISNULL( SUM( QtyExpected), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   UserDefine02 = @cRefNo
      
      -- Prepare next screen variable
      SET @cOutField01 = @cReceiptKey -- ASN
      SET @cOutField02 = @cRefNo -- ID
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = SUBSTRING( @cSKUDesc, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDesc, 21, 20)
      SET @cOutField06 = CAST( @nQTYRcv AS NVARCHAR( 5)) + '/' + CAST( @nQTYExp AS NVARCHAR( 5))
      SET @cOutField07 = CASE WHEN @cDefaultQTY <> '' THEN @cDefaultQTY ELSE '' END -- QTY
      SET @cOutField08 = @nTotalASNQTY
      SET @cOutField09 = @nTotalREFQTY
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = ''   -- METHOD
      SET @cOutField02 = ''   -- REF NO

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to next screen
      SET @nScn = @nScn_MethodRefNo
      SET @nStep = @nStep_MethodRefNo
   END
   GOTO Quit

   Step_SKU_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cOutField03 = '' -- SKU
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
      GOTO Quit
   END

   Step_QTY_Fail:
   BEGIN
      SET @cQty = ''
      SET @cOutField07 = '' -- QTY
      EXEC rdt.rdtSetFocusField @nMobile, 7 -- QTY
      GOTO Quit
   END
END
GOTO Quit

/***********************************************************************************
Step 4. Scn = 6273. SKU DAMAGE screen
   SKU DAMAGE    (field01, input)
***********************************************************************************/
Step_SkuDamage:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKUDamage = @cInField01

      -- Check blank
      IF @cSKUDamage = '' 
      BEGIN
         SET @nErrNo = 203918
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Value
         GOTO Step_SkuDamage_Fail
      END
      
      -- Check QTY valid  
      IF rdt.rdtIsValidQty( @cSKUDamage, 1) = 0  
      BEGIN  
         SET @nErrNo = 203919  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Value  
         GOTO Step_SkuDamage_Fail  
      END  
      
      SET @nSkuDamage = CAST( @cSkuDamage AS INT)
      
      SELECT 
         @nUDF05 = ISNULL( SUM( CONVERT( INT, UserDefine05)), 0), 
         @nQTYExp = ISNULL( SUM( QtyExpected), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ReceiptKey = @cReceiptKey
      AND   UserDefine02 = @cRefNo
      AND   Sku = @cSKU
      AND   Lottable11 = @cLottable11  -- Line#
      
      IF ( @nSkuDamage + @nUdf05) > @nQTYExp
      BEGIN
         SET @nErrNo = 203920
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Value
         GOTO Step_SkuDamage_Fail
      END

      IF EXISTS ( SELECT 1 
                  FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   ReceiptKey = @cReceiptKey
                  AND   UserDefine02 = @cRefNo
                  AND   SubreasonCode = 'Y')
      BEGIN
      	SELECT @nBeforeReceivedQty = ISNULL( SUM( BeforeReceivedQty), 0)
      	FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   UserDefine02 = @cRefNo
         AND   SubreasonCode = 'Y'
      	
      	IF ( @nSkuDamage + @nUdf05 + @nBeforeReceivedQty) > @nQTYExp
         BEGIN
            SET @nErrNo = 203932
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Value
            GOTO Step_SkuDamage_Fail
         END
      END
      
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN Step_SKUDamage -- For rollback or commit only our own transaction

   	SELECT  
   	   @cReceiptLineNumber = ReceiptLineNumber, 
   	   @cUDF05 = UserDefine05
   	FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   UserDefine02 = @cRefNo
      AND   Sku = @cSKU   
      AND   Lottable11 = @cLottable11  -- Line#
   	
   	SET @cUDF05 = CAST( @cUDF05 AS INT) + @nSkuDamage
   	
      IF @cReceiptLineNumber <> ''
      BEGIN
         UPDATE dbo.RECEIPTDETAIL SET 
            UserDefine05 = @cUDF05, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE()
         WHERE ReceiptKey = @cReceiptKey
         AND   ReceiptLineNumber = @cReceiptLineNumber	
      
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 203926
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD UDF01 ERR
            ROLLBACK TRAN Step_SKUDamage
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
            GOTO Step_SkuDamage_Fail
         END
      END
      ELSE
      BEGIN
         SET @nErrNo = 203927
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ASN NOT FOUND
         ROLLBACK TRAN Step_SKUDamage
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Step_SkuDamage_Fail
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
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
               '@tExtUpdateVar VariableTable READONLY, ' +
               '@nErrNo        INT           OUTPUT,   ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cToID, @cToLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN Step_SKUDamage
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Step_SkuDamage_Fail
            END
         END
      END

      COMMIT TRAN Step_SKUDamage
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Get statistic
      SELECT
         @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
         @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   UserDefine02 = @cRefNo

      IF @nTotalQTYExp = @nTotalQTYRcv
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = ''   -- METHOD
         SET @cOutField02 = ''   -- REF NO

         EXEC rdt.rdtSetFocusField @nMobile, 1

         -- Go to next screen
         SET @nScn = @nScn_MethodRefNo
         SET @nStep = @nStep_MethodRefNo
      END
      ELSE
      BEGIN
         -- Get statistic
         SELECT
            @nQTYExp = ISNULL( SUM( QtyExpected), 0),
            @nQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   Sku = @cSKU
         AND   UserDefine02 = @cRefNo
         
         SELECT @nTotalASNQTY = ISNULL( SUM( QtyExpected), 0)
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey

         SELECT @nTotalREFQTY = ISNULL( SUM( QtyExpected), 0)
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   UserDefine02 = @cRefNo
      
         -- Prepare next screen variable
         SET @cOutField01 = @cReceiptKey -- ASN
         SET @cOutField02 = @cRefNo -- ID
         SET @cOutField03 = '' -- SKU
         SET @cOutField04 = SUBSTRING( @cSKUDesc, 1, 20)
         SET @cOutField05 = SUBSTRING( @cSKUDesc, 21, 20)
         SET @cOutField06 = CAST( @nQTYRcv AS NVARCHAR( 5)) + '/' + CAST( @nQTYExp AS NVARCHAR( 5))
         SET @cOutField07 = CASE WHEN @cDefaultQTY <> '' THEN @cDefaultQTY ELSE '' END -- QTY
         SET @cOutField08 = @nTotalASNQTY
         SET @cOutField09 = @nTotalREFQTY
         
         -- Go to next screen
         SET @nScn = @nScn_SkuQty
         SET @nStep = @nStep_SkuQty
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Get statistic
      SELECT
         @nQTYExp = ISNULL( SUM( QtyExpected), 0),
         @nQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   Sku = @cSKU
      AND   UserDefine02 = @cRefNo
         
      SELECT @nTotalASNQTY = ISNULL( SUM( QtyExpected), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      SELECT @nTotalREFQTY = ISNULL( SUM( QtyExpected), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   UserDefine02 = @cRefNo
      
      -- Prepare next screen variable
      SET @cOutField01 = @cReceiptKey -- ASN
      SET @cOutField02 = @cRefNo -- ID
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = SUBSTRING( @cSKUDesc, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDesc, 21, 20)
      SET @cOutField06 = CAST( @nQTYRcv AS NVARCHAR( 5)) + '/' + CAST( @nQTYExp AS NVARCHAR( 5))
      SET @cOutField07 = CASE WHEN @cDefaultQTY <> '' THEN @cDefaultQTY ELSE '' END -- QTY
      SET @cOutField08 = @nTotalASNQTY
      SET @cOutField09 = @nTotalREFQTY
      
      -- Go to next screen
      SET @nScn = @nScn_SkuQty
      SET @nStep = @nStep_SkuQty
   END
   GOTO Quit
   
   Step_SkuDamage_Fail:
   BEGIN
   	SET @cOutField01 = ''

   	SET @cSkuDamage = ''
   END
END
GOTO Quit

/***********************************************************************************
Step 5. Scn = 6274. SKU DAMAGE screen
   REF NO           (field01, input)
   PARCEL DAMAGE    (field02, input)
***********************************************************************************/
Step_RefNoParcelDmg:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cRefNo = @cInField01
      SET @cParcelDmg = @cInField02

      -- Check blank
      IF @cRefNo = '' 
      BEGIN
         SET @nErrNo = 203921
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need RefNo
         GOTO Step_PRefNo_Fail
      END

      SET @cReceiptKey = ''
      SELECT TOP 1 @cReceiptKey = RD.ReceiptKey
      FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
      JOIN dbo.RECEIPT R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
      WHERE R.StorerKey = @cStorerKey
      AND   R.Facility = @cFacility
      AND   RD.StorerKey = @cStorerKey
      AND   RD.UserDefine02 = @cRefNo
      AND   RD.FinalizeFlag <> 'Y'
      ORDER BY 1
      
      IF @cReceiptKey = ''
      BEGIN
         SET @nErrNo = 203922
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN Not Found
         GOTO Step_PRefNo_Fail
      END
      
      IF EXISTS ( SELECT 1 
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   UserDefine02 = @cRefNo
         AND   ( UserDefine07 IS NULL OR UserDefine07 = '1900-01-01 00:00:00'))
      BEGIN
         SET @nParcelCnt = @nParcelCnt + 1
      END
      
      UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK) SET 
      	UserDefine07 = GETDATE(), 
      	SubReasonCode = CASE WHEN @cParcelDmg = 'Y' THEN 'Y' ELSE 'N' END,
      	EditDate = GETDATE(),
      	EditWho = SUSER_SNAME()
      WHERE ReceiptKey = @cReceiptKey
      AND   UserDefine02 = @cRefNo
      
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 203923
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd ASN Fail
         GOTO Step_PRefNo_Fail
      END
               
      -- Remain in current screen
   	SET @cOutField01 = ''
      SET @cOutField02 = @cParcelDmg
      SET @cOutField03 = @nParcelCnt
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
   	SET @nParcelCnt = 0

      -- Prepare next screen var
      SET @cOutField01 = '' -- To ID
      SET @cOutField02 = '' -- To LOC
      SET @cOutField03 = '' -- TYPE

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Set the entry point
      SET @nScn = @nScn_ToIDLocType
      SET @nStep = @nStep_ToIDLocType
   END
   GOTO Quit
   
   Step_PRefNo_Fail:
   BEGIN
   	SET @cOutField01 = ''
      SET @cOutField02 = @cParcelDmg
      
   	SET @cRefNo = ''
   	EXEC rdt.rdtSetFocusField @nMobile, 1
   END
END
GOTO Quit

/***********************************************************************************
Step 6. Scn = 6275. VERIFY SKU screen
   SKU            (field01)
   DESCR          (field02)
   DESCR          (field03)
   LINE, QTY, OPTION (field04, input)
***********************************************************************************/
Step_VerifySKU:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField11

      -- Check blank
      IF @cOption = '' 
      BEGIN
         SET @nErrNo = 203928
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option
         GOTO Step_VerifySKU_Fail
      END

      IF rdt.rdtIsValidQty( @cOption, 0) = 0
      BEGIN
         SET @nErrNo = 203929
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_VerifySKU_Fail
      END

      SET @cLine = RIGHT( CONCAT('00000', @cOption), 5)
      
      IF NOT EXISTS ( SELECT 1 
                      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                      WHERE ReceiptKey = @cReceiptKey
                      AND   UserDefine02 = @cRefNo
                      AND   ReceiptLineNumber = @cLine)
      BEGIN
         SET @nErrNo = 203930
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_VerifySKU_Fail
      END

      -- Check over receive
      IF EXISTS( SELECT 1
         FROM ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   ReceiptLineNumber = @cLine
         HAVING ISNULL( SUM( BeforeReceivedQty), 0) + @nQTY >
                  ISNULL( SUM( QTYExpected), 0))
      BEGIN
         SET @nErrNo = 203931
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over received
         GOTO Step_VerifySKU_Fail
      END

      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN Step_VerifySKU -- For rollback or commit only our own transaction

      -- 1 Refno multiple same sku scenario, lottable11 = line#
      SET @cLottable11 = @cLine

      -- Receive
      EXEC rdt.rdt_IkeaEcomReturn_Confirm
         @nFunc               = @nFunc,
         @nMobile             = @nMobile,
         @cLangCode           = @cLangCode,
         @cStorerKey          = @cStorerKey,
         @cFacility           = @cFacility,
         @cReceiptKey         = @cReceiptKey,
         @cRefNo              = @cRefNo,
         @cToLoc              = @cToLoc,
         @cToID               = @cToID,
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
         @cConditionCode      = @cConditionCode,
         @cSubreasonCode      = @cSubreasonCode,
         @nSkuDamage          = @nSkuDamage,
         @tConfirmVar         = @tConfirmVar,
         @cReceiptLineNumber  = @cReceiptLineNumber OUTPUT,
         @nErrNo              = @nErrNo    OUTPUT,
         @cErrMsg             = @cErrMsg   OUTPUT

      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN Step_VerifySKU
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Step_VerifySKU_Fail
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cRefNo, @cID, @cLOC, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cReceiptKey   NVARCHAR( 10), ' +
               '@cRefNo        NVARCHAR( 60), ' +
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
               '@tExtUpdateVar VariableTable READONLY, ' +
               '@nErrNo        INT           OUTPUT,   ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cRefNo, @cToID, @cToLOC, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @tExtUpdateVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN Step_VerifySKU
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Step_VerifySKU_Fail
            END
         END
      END

      COMMIT TRAN Step_VerifySKU
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      IF @cMethod = '2'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = ''	-- SKU DAMAGE
            
         -- Go to next screen
         SET @nScn = @nScn_SkuDamage
         SET @nStep = @nStep_SkuDamage	
            
         GOTO Quit
      END
      
      -- Get statistic
      SELECT
         @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
         @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   UserDefine02 = @cRefNo
      
      -- Already key in toid & toloc, receive and stay in sku screen
      IF @nTotalQTYExp = @nTotalQTYRcv --AND 1 = 0
      BEGIN
         IF @cMethod = '1'
         BEGIN
            -- Prepare next screen var
            SET @cOutField01 = ''   -- METHOD
            SET @cOutField02 = ''   -- REF NO

            EXEC rdt.rdtSetFocusField @nMobile, 1

            -- Go to next screen
            SET @nScn = @nScn_MethodRefNo
            SET @nStep = @nStep_MethodRefNo	
         END
         ELSE IF @cMethod = '2'
         BEGIN
         	-- Prepare next screen var
            SET @cOutField01 = ''	-- SKU DAMAGE
            
            -- Go to next screen
            SET @nScn = @nScn_SkuDamage
            SET @nStep = @nStep_SkuDamage	
         END
         
         GOTO Quit
      END

      -- Get statistic
      SELECT
         @nQTYExp = ISNULL( SUM( QtyExpected), 0),
         @nQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   Sku = @cSKU
      AND   UserDefine02 = @cRefNo
         
      SELECT @nTotalASNQTY = ISNULL( SUM( QtyExpected), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      SELECT @nTotalREFQTY = ISNULL( SUM( QtyExpected), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   UserDefine02 = @cRefNo
      
      -- Prepare next screen variable
      SET @cOutField01 = @cReceiptKey -- ASN
      SET @cOutField02 = @cRefNo -- ID
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = SUBSTRING( @cSKUDesc, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDesc, 21, 20)
      SET @cOutField06 = CAST( @nQTYRcv AS NVARCHAR( 5)) + '/' + CAST( @nQTYExp AS NVARCHAR( 5))
      SET @cOutField07 = CASE WHEN @cDefaultQTY <> '' THEN @cDefaultQTY ELSE '' END -- QTY
      SET @cOutField08 = @nTotalASNQTY
      SET @cOutField09 = @nTotalREFQTY
      
      -- Go to next screen
      SET @nScn = @nScn_SkuQty
      SET @nStep = @nStep_SkuQtY	
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Get statistic
      SELECT
         @nQTYExp = ISNULL( SUM( QtyExpected), 0),
         @nQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   Sku = @cSKU
      AND   UserDefine02 = @cRefNo
         
      SELECT @nTotalASNQTY = ISNULL( SUM( QtyExpected), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      SELECT @nTotalREFQTY = ISNULL( SUM( QtyExpected), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   UserDefine02 = @cRefNo
      
      -- Prepare next screen variable
      SET @cOutField01 = @cReceiptKey -- ASN
      SET @cOutField02 = @cRefNo -- ID
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = CAST( @nQTYRcv AS NVARCHAR( 5)) + '/' + CAST( @nQTYExp AS NVARCHAR( 5))
      SET @cOutField07 = CASE WHEN @cDefaultQTY <> '' THEN @cDefaultQTY ELSE '' END -- QTY
      SET @cOutField08 = @nTotalASNQTY
      SET @cOutField09 = @nTotalREFQTY
      
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to next screen
      SET @nScn = @nScn_SkuQty
      SET @nStep = @nStep_SkuQty
   END
   GOTO Quit
   
   Step_VerifySKU_Fail:
   BEGIN
   	SET @cOutField01 = ''
   	SET @cLine = ''
   END
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

      V_StorerKey  = @cStorerKey,
      V_UOM        = @cUOM,
      V_ReceiptKey = @cReceiptKey,
      V_LOC        = @cToLOC,
      V_ID         = @cToID,
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
      V_Integer3   = @nParcelCnt,

      V_String1    = @cRefNo,
      V_String2    = @cLottableCode,
      V_String3    = @cMethod,
      V_String4    = @cDefaultQTY,
      V_String5    = @cReceiptLineNumber,
      V_String6    = @cConditionCode,
      V_String7    = @cSubreasonCode,
      V_String8    = @cDecodeSP,
      V_String9    = @cDecodeSKUSP,
      V_String10    = @cExtendedInfoSP,
      V_String11   = @cExtendedInfo,
      V_String12   = @cExtendedValidateSP,
      V_String13   = @cExtendedUpdateSP,

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