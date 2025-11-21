SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdtfnc_PieceReturn                                        */  
/* Copyright      : LFLogistics                                               */  
/*                                                                            */  
/* Purpose: Work the same as Exceed Trade Return                              */  
/*                                                                            */  
/* Modifications log:                                                         */  
/*                                                                            */  
/* Date         Rev  Author     Purposes                                      */  
/* 2015-10-09   1.0  Ung        Migrated from 552                             */  
/* 2016-01-04   1.1  Ung        SOS359609 RefNo support SP                    */  
/* 2016-08-22   1.2  James      Add setfocus logic @ scn 1 (james01)          */  
/*                              Add default value for lottable method         */  
/* 2016-08-08   1.3  ChewKP     SOS#374476 Add ExtendedInfo (ChewKP01)        */  
/* 2016-12-20   1.4  Ung        WMS-835 Add ExtendedValidateSP to screen 1    */  
/* 2016-09-30   1.5  Ung        Performance tuning                            */  
/* 2017-08-14   1.6  Ung        WMS-2622 Add condition code                   */  
/* 2018-03-26   1.7  James      WMS-2605 Add ExtendedInfoSP @ step 1 & 2      */  
/*                              Extend Refno field to 30 chars (james02)      */  
/*                              Change config DisAllowDuplicateIdsOnRFRcpt    */  
/*                              to RDT config CheckIDInUse                    */  
/* 2018-05-16   1.8  Ung        WMS-4675 Add ExtendedUpdateSP to screen 4 ESC */  
/* 2018-10-02   1.9  TungGH     Performance                                   */  
/* 2019-03-05   2.0  James      WMS-8215 Add ExtendedValidateSP @             */  
/*                              Step_SkuQty (james03)                         */  
/* 2019-07-08   2.1  James      WMS-9487 Fix ExtendedInfoSP output field      */  
/*                              display (james04)                             */  
/* 2019-07-29   2.2  Ung        WMS-2622 Fix error no                         */  
/* 2019-05-28   2.3  YeeKung    WMS-9091 Finalize ASN screen (yeekung01)      */  
/* 2019-09-24   2.4  James      WMS-10122 Clear field when cfm error (james05)*/  
/* 2020-05-08   2.5  YeeKung    WMS-14415 Add UCCUOM   (yeekung02)            */  
/* 2020-08-29   2.6  YeeKung    WMS-14669 Add @cSuggestLocSP (yeekung03)      */  
/* 2020-10-08   2.7  LZG        INC1318151 - Reset @cUCCUOM variable (ZG01)   */  
/* 2019-10-08   2.8  Ung        WMS-10643 Add rdt format for ID               */  
/*                              Add ExtendedValidateSP to post lottable screen*/  
/*                              Performance tuning                            */  
/* 2021-07-22   2.9  Chermaine  WMS-16119 Add ExtUpdate in scn2 (cc01)        */  
/* 2022-09-08   3.0  Ung        WMS-20348 Expand RefNo to 60 chars            */
/* 2022-03-09   3.1  James      WMS-18962 Add @cBarcode to V_String (james06) */
/* 2023-01-16   3.2  Ung        WMS-21532 Add auto finalize                   */
/* 2023-08-17   3.3  Ung        WMS-23172 Add rdt_Decode                      */
/******************************************************************************/  
CREATE   PROC [RDT].[rdtfnc_PieceReturn](  
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
   @nMorePage           INT,  
   @cSQL                NVARCHAR( MAX),  
   @cSQLParam           NVARCHAR( MAX),  
   @nTranCount          INT  
  
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
  
   @cReceiptKey         NVARCHAR( 10),  
   @cPOKey              NVARCHAR( 10),  
   @cLOC                NVARCHAR( 10),  
   @cID                 NVARCHAR( 18),  
   @cSKU                NVARCHAR( 30),  
   @cSKUDesc            NVARCHAR( 60),  
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
  
   @cPreLottable01      NVARCHAR( 18),  
   @cPreLottable02      NVARCHAR( 18),  
   @cPreLottable03      NVARCHAR( 18),  
   @dPreLottable04      DATETIME,  
   @dPreLottable05      DATETIME,  
   @cPreLottable06      NVARCHAR( 30),  
   @cPreLottable07      NVARCHAR( 30),  
   @cPreLottable08      NVARCHAR( 30),  
   @cPreLottable09      NVARCHAR( 30),  
   @cPreLottable10      NVARCHAR( 30),  
   @cPreLottable11      NVARCHAR( 30),  
   @cPreLottable12      NVARCHAR( 30),  
   @dPreLottable13      DATETIME,  
   @dPreLottable14      DATETIME,  
   @dPreLottable15      DATETIME,  
  
   @cRefNo              NVARCHAR( 60),  
   @cMethod             NVARCHAR( 1),  
   @cLottableCode       NVARCHAR( 30),  
   @cUOM                NVARCHAR( 6),  
   @nQTY                INT,  
   @nIDQTY              INT,  
   @nBeforeReceivedQTY  INT,  
   @nQTYExpected        INT,  
   @cRDLineNo           NVARCHAR( 5),  
   @cReasonCode         NVARCHAR( 10),  
   @cReceiptLineNumber  NVARCHAR( 5),  
   @cUCCUOM             NVARCHAR( 6),--(yeekung02)  
   @cSuggestLocSP       NVARCHAR(20),--(yeekung03)  
  
   @cDefaultToLOC       NVARCHAR( 20),  
   @cDecodeSKUSP        NVARCHAR( 20),  
   @cMultiSKUBarcode    NVARCHAR(1),  
   @cVerifySKU          NVARCHAR( 1),  
   @cDisableQTYField    NVARCHAR(1),  
   @cDefaultQTY         NVARCHAR(1),  
   @cExtendedInfoSP     NVARCHAR( 20),  
   @cExtendedInfo       NVARCHAR( 20),  
   @cExtendedValidateSP NVARCHAR( 20),  
   @cExtendedUpdateSP   NVARCHAR( 20),  
   @cCheckSKUInASN      NVARCHAR( 1),  
   @cOption             NVARCHAR( 1),  
   @cFinalizeASN        NVARCHAR( 10),  
  
   @cDefaultLottableMethod NVARCHAR( 1),  -- (james01)  
   @cCheckIDInUse          NVARCHAR( 20),    -- (james02)  
   @cAllow_OverReceipt     NVARCHAR( 1),    --(yeekung01) 
   @cBarcode               NVARCHAR( 60),
   
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
  
   @cPreLottable01      = V_String1,  
   @cPreLottable02      = V_String2,  
   @cPreLottable03      = V_String3,  
   @cPreLottable06      = V_String6,  
   @cPreLottable07      = V_String7,  
   @cPreLottable08      = V_String8,  
   @cPreLottable09      = V_String9,  
   @cPreLottable10      = V_String10,  
   @cPreLottable11      = V_String11,  
   @cPreLottable12      = V_String12,  
   @cCheckIDInUse       = V_String16,  
   @cMethod             = V_String17,  
   @cLottableCode       = V_String18,  
   @cUOM                = V_String19,  
   @cReasonCode         = V_String20,  
  
   @cDefaultToLOC       = V_String21,  
   @cDecodeSKUSP        = V_String22,  
   @cMultiSKUBarcode    = V_String23,  
   @cVerifySKU          = V_String24,  
   @cDisableQTYField    = V_String25,  
   @cDefaultQTY         = V_String26,  
   @cExtendedInfoSP     = V_String27,  
   @cExtendedInfo       = V_String28,  
   @cExtendedValidateSP = V_String29,  
   @cExtendedUpdateSP   = V_String30,  
   @cCheckSKUInASN      = V_String31,  
   @cReceiptLineNumber  = V_String32,  
   @cFinalizeASN        = V_String33,  
   @cUCCUOM             = V_String34, --(yeekung02)  
   -- @cDefaultCursor      = V_String35, --(yeekung02)  
   @cSuggestLocSP       = V_string36, --(yeekung03)  
   @cRDLineNo           = V_String38,  
   @cRefNo              = V_String41,  -- refno is 30 chars  
   @cOption             = V_String42,  
   @cAllow_OverReceipt  = V_String43, --(yeekung01)    
   @cBarcode            = V_String44,
   
   @nIDQTY              = V_Integer1,  
   @nBeforeReceivedQTY  = V_Integer2,  
   @nQTYExpected        = V_Integer3,  
  
   @dPreLottable04      = V_DateTime1,  
   @dPreLottable05      = V_DateTime2,  
   @dPreLottable13      = V_DateTime3,  
   @dPreLottable14      = V_DateTime3,  
   @dPreLottable15      = V_DateTime5,  
  
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
   @nStep_ASNPO        INT,  @nScn_ASNPO        INT,  
   @nStep_IDLOC        INT,  @nScn_IDLOC        INT,  
   @nStep_PreLottable  INT,  @nScn_PreLottable  INT,  
   @nStep_SKUQTY       INT,  @nScn_SKUQTY       INT,  
   @nStep_PostLottable INT,  @nScn_PostLottable INT,  
   @nStep_VerifySKU    INT,  @nScn_VerifySKU    INT,  
   @nStep_MultiSKU     INT,  @nScn_MultiSKU     INT,  
   @nStep_FinalizeASN  INT,  @nScn_FinalizeASN  INT  
  
SELECT  
   @nStep_ASNPO         = 1,  @nScn_ASNPO        = 4340,  
   @nStep_IDLOC         = 2,  @nScn_IDLOC        = 4341,  
   @nStep_PreLottable   = 3,  @nScn_PreLottable  = 3990,  
   @nStep_SKUQTY        = 4,  @nScn_SKUQTY       = 4342,  
   @nStep_PostLottable  = 5,  @nScn_PostLottable = 3990,  
   @nStep_VerifySKU     = 6,  @nScn_VerifySKU    = 3951,  
   @nStep_MultiSKU      = 7,  @nScn_MultiSKU     = 3570,  
   @nStep_FinalizeASN   = 8,  @nScn_FinalizeASN  = 4343  
  
IF @nFunc = 608  
BEGIN  
   -- Redirect to respective screen  
   IF @nStep = 0  GOTO Step_Start        -- Menu. 608  
   IF @nStep = 1  GOTO Step_ASNPO        -- Scn = 4340. ASN, PO  
   IF @nStep = 2  GOTO Step_IDLOC        -- Scn = 4341. ID, LOC  
   IF @nStep = 3  GOTO Step_PreLottable  -- Scn = 3990. Pre lottable  
   IF @nStep = 4  GOTO Step_SKUQTY       -- Scn = 4342. SKU, QTY  
   IF @nStep = 5  GOTO Step_PostLottable -- Scn = 3990. Post lottable  
   IF @nStep = 6  GOTO Step_VerifySKU    -- Scn = 3951. Verify SKU  
   IF @nStep = 7  GOTO Step_MultiSKU     -- Scn = 3570. Multi SKU  
   IF @nStep = 8  GOTO Step_FinalizeASN  -- SCN = 4343. Finalize ASN  
END  
RETURN -- Do nothing if incorrect step  
  
  
/********************************************************************************  
Step_Start. Func = 608  
********************************************************************************/  
Step_Start:  
BEGIN  
   -- Get storer config  
   DECLARE @cDefaultCursor NVARCHAR( 1)
   DECLARE @cPOKeyDefaultValue NVARCHAR( 10)  

   SET @cDefaultCursor = rdt.RDTGetConfig( @nFunc, 'DefaultCursor', @cStorerKey)   --(yeekung01)  
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
  
   IF ISNULL(@cDefaultCursor,'')<>0  
      EXEC rdt.rdtSetFocusField @nMobile, @cDefaultCursor  
   ELSE  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
  
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
Step 1. Scn = 4340. ASN, PO, Container No screen  
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
               SET @nErrNo = 57601  
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
               ' @cRefNo       NVARCHAR(60), ' +  
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
               SET @nErrNo = 57602  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN  
               GOTO Quit  
            END  
  
            -- Check RefNo in ASN  
            IF @nRowCount > 1  
            BEGIN  
               SET @nErrNo = 57603  
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
                  '@cRefNo        NVARCHAR( 60), ' +  
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
         SET @nErrNo = 57604  
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
               SET @nErrNo = 57605  
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
               SET @nErrNo = 57606  
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
              SET @nErrNo = 57607  
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
               SET @nErrNo = 57608  
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
                  SET @nErrNo = 57609  
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
                  SET @nErrNo = 57610  
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
                  SET @nErrNo = 57611  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PO not exist  
                  SET @cOutField02 = '' -- POKey  
                  SET @cPOKey = ''  
                  EXEC rdt.rdtSetFocusField @nMobile, 2  
                  GOTO Quit  
               END  
  
               IF @nRowCount > 1  
               BEGIN  
                  SET @nErrNo = 57612  
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
         SET @nErrNo = 57613  
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
            SET @nErrNo = 57614  
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
         SET @nErrNo = 57615  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer  
         SET @cOutField01 = '' -- ReceiptKey  
         SET @cReceiptKey = ''  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Quit  
      END  
  
      -- Validate ASN status  
      IF @cReceiptStatus = '9'  
      BEGIN  
         SET @nErrNo = 57616  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN is closed  
         SET @cOutField01 = '' -- ReceiptKey  
         SET @cReceiptKey = ''  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Quit  
      END  
  
      -- Check ASN cancelled  
      IF @cReceiptStatus = 'CANC'  
      BEGIN  
         SET @nErrNo = 57617  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN cancelled  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         SET @cOutField01 = '' -- ReceiptKey  
         SET @cReceiptKey = ''  
         GOTO Quit  
      END  

      -- Get storer config  
      SET @cCheckSKUInASN = rdt.RDTGetConfig( @nFunc, 'CheckSKUInASN', @cStorerKey)  
      SET @cDisableQTYField = rdt.RDTGetConfig( @nFunc, 'DisableQTYField', @cStorerKey)  
      SET @cFinalizeASN = rdt.RDTGetConfig( @nFunc, 'FinalizeASN', @cStorerKey)  
      SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)  
      SET @cVerifySKU = rdt.RDTGetConfig( @nFunc, 'VerifySKU', @cStorerKey)  
  
      SET @cCheckIDInUse = rdt.RDTGetConfig( @nFunc, 'CheckIDInUse', @cStorerKey)  
      IF @cCheckIDInUse = '0'  
         SET @cCheckIDInUse = ''  
      SET @cDefaultLottableMethod = rdt.RDTGetConfig( @nFunc, 'DefaultLottableMethod', @cStorerKey)  
      IF @cDefaultLottableMethod = '0'  
         SET @cDefaultLottableMethod = ''  
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
      SET @cSuggestLocSP =  rdt.RDTGetConfig( @nFunc, 'SuggestLocSP', @cStorerKey)
      IF @cSuggestLocSP = '0'  
         SET @cSuggestLocSP = ''  
  
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
               '@cRefNo        NVARCHAR( 60), ' +  
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
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY, ' +  
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
               ' @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
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
               '@cRefNo        NVARCHAR( 60), ' +  
               '@cID           NVARCHAR( 18), ' +  
               '@cLOC          NVARCHAR( 10), ' +  
               '@cMethod       NVARCHAR( 1),  ' +  
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
               '@cRDLineNo     NVARCHAR( 10), ' +  
               '@nErrNo        INT           OUTPUT, ' +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY,  
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
               @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
      END  
  
      -- (james02)  
      -- Extended info  
      IF @cExtendedInfoSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
         BEGIN  
            SET @cExtendedInfo = ''  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY, ' +  
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
               ' @cRDLineNo, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
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
               '@cRefNo        NVARCHAR( 60), ' +  
               '@cID           NVARCHAR( 18), ' +  
               '@cLOC          NVARCHAR( 10), ' +  
               '@cMethod       NVARCHAR( 1),  ' +  
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
               '@cRDLineNo     NVARCHAR( 10),   ' +  
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +  
               '@nErrNo        INT           OUTPUT, ' +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT'  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep_ASNPO, @nScn_IDLOC, @nInputKey, @cFacility, @cStorerKey,  
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY,  
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
               @cRDLineNo, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            SET @cOutField06 = @cExtendedInfo  
         END  
      END  
  
      -- Prepare next screen var  
      SET @cOutField01 = @cReceiptKey  
      SET @cOutField02 = @cPOKey  
      SET @cOutField03 = '' -- ID  
      SET @cOutField04 = @cDefaultToLOC -- LOC  
      SET @cOutField05 = CASE WHEN @cDefaultLottableMethod <> '' THEN @cDefaultLottableMethod ELSE '' END-- Method (james01)  
  
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- ID  
  
      -- Go to next screen  
      SET @nScn = @nScn_IDLOC  
      SET @nStep = @nStep_IDLOC  
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
Step 2. Scn = 4341. ID, LOC screen  
   ASN     (field01)  
   PO      (field02)  
   ID      (field03, input)  
   LOC     (field04, input)  
   Method  (field05, input)  
********************************************************************************/  
Step_IDLOC:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cID = @cInField03  
      SET @cLOC = @cInField04  
      SET @cMethod = @cInField05  
  
      -- Check barcode format  
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cID) = 0  
      BEGIN  
         SET @nErrNo = 57630  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format  
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- ID  
         SET @cOutField03 = ''  
         GOTO Quit  
      END  
  
      IF @cID <> ''  
      BEGIN
         /*  
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
               SET @nErrNo = 57618  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Duplicate ID  
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- ID  
               SET @cOutField03 = ''  
               GOTO Quit  
            END  
         END
         */  
  
         IF @cCheckIDInUse = '1'  
         BEGIN  
            IF EXISTS( SELECT [ID]  
               FROM dbo.LOTxLOCxID LOTxLOCxID WITH (NOLOCK)  
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC)  
               WHERE [ID] = @cID  
               AND   QTY > 0  
               AND   StorerKey = @cStorerKey  
               AND   LOC.Facility = @cFacility)  
            BEGIN  
               SET @nErrNo = 57618  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Duplicate ID  
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- ID  
               SET @cOutField03 = ''  
               GOTO Quit  
            END  
         END  
      END  
      SET @cOutField03 = @cID  
  
      -- Validate compulsary field  
      IF @cLOC = ''  
      BEGIN  
         SET @nErrNo = 57619  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOC  
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC  
         SET @cOutField04 = ''  
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
         SET @nErrNo = 57620  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC  
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC  
         SET @cOutField04 = ''  
         GOTO Quit  
      END  
  
      -- Validate location not in facility  
      IF @cChkFacility <> @cFacility  
      BEGIN  
         SET @nErrNo = 57621  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility  
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- LOC  
         SET @cOutField04 = ''  
         GOTO Quit  
      END  
      SET @cOutField04 = @cLOC  
  
      -- Check method  
      IF @cMethod NOT IN ('1', '2')  
      BEGIN  
         SET @nErrNo = 57622  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid method  
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- Method  
         SET @cOutField05 = ''  
         GOTO Quit  
      END  
  
      -- Extended validate  
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY, ' +  
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
               ' @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
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
               '@cRefNo        NVARCHAR( 60), ' +  
               '@cID           NVARCHAR( 18), ' +  
               '@cLOC          NVARCHAR( 10), ' +  
               '@cMethod       NVARCHAR( 1),  ' +  
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
               '@cRDLineNo     NVARCHAR( 10), ' +  
               '@nErrNo        INT           OUTPUT, ' +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY,  
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
               @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
      END  
  
      -- Reset data  
      SELECT @cSKU = '', @nQTY = 0,  
         @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL, @dLottable05 = NULL,  
         @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',   @cLottable10 = '',  
         @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL, @dLottable15 = NULL,  
  
         @cPreLottable01 = '', @cPreLottable02 = '', @cPreLottable03 = '',   @dPreLottable04 = NULL, @dPreLottable05 = NULL,  
         @cPreLottable06 = '', @cPreLottable07 = '', @cPreLottable08 = '',   @cPreLottable09 = '',   @cPreLottable10 = '',  
         @cPreLottable11 = '', @cPreLottable12 = '', @dPreLottable13 = NULL, @dPreLottable14 = NULL, @dPreLottable15 = NULL  
  
      -- Extended update  --(cc01)  
      IF @cExtendedUpdateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY, ' +  
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
               ' @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
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
               '@cPOKey   NVARCHAR( 10), ' +  
               '@cRefNo        NVARCHAR( 60), ' +  
               '@cID           NVARCHAR( 18), ' +  
               '@cLOC          NVARCHAR( 10), ' +  
               '@cMethod       NVARCHAR( 1),  ' +  
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
               '@cRDLineNo     NVARCHAR( 10),   ' +  
               '@nErrNo        INT           OUTPUT, ' +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY,  
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
               @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
      END  
  
      IF @cMethod = '1' -- Lottable, SKU  
      BEGIN  
         -- Dynamic lottable (PRE at storer level)  
         SET @cSKU = ''  
         SET @cLottableCode = ''  
         EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'PRECAPTURE', 'POPULATE', 5, 1,  
            @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cPreLottable01 OUTPUT,  
            @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cPreLottable02 OUTPUT,  
            @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cPreLottable03 OUTPUT,  
            @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dPreLottable04 OUTPUT,  
            @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dPreLottable05 OUTPUT,  
            @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cPreLottable06 OUTPUT,  
            @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cPreLottable07 OUTPUT,  
            @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cPreLottable08 OUTPUT,  
            @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cPreLottable09 OUTPUT,  
            @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cPreLottable10 OUTPUT,  
            @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cPreLottable11 OUTPUT,  
            @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cPreLottable12 OUTPUT,  
            @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dPreLottable13 OUTPUT,  
            @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dPreLottable14 OUTPUT,  
            @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dPreLottable15 OUTPUT,  
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
            SET @nScn = @nScn_PreLottable  
            SET @nStep = @nStep_PreLottable  
  
            GOTO Quit  
         END  
      END  
  
      -- Get IDQTY  
      SELECT @nIDQTY = ISNULL( SUM( BeforeReceivedQTY), 0)  
      FROM dbo.ReceiptDetail WITH (NOLOCK)  
      WHERE ReceiptKey = @cReceiptKey  
         AND ToLOC = @cLOC  
         AND ToID = @cID  
  
      -- Enable / disable QTY  
      SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END  
  
      -- Prepare next screen variable  
      SET @cOutField01 = @cID  
      SET @cOutField02 = @cLOC  
      SET @cOutField03 = '' -- SKU  
      SET @cOutField04 = '' -- SKU  
      SET @cOutField05 = '' -- Descr1  
      SET @cOutField06 = '' -- Descr2  
      SET @cOutField07 = '' -- Stat  
      SET @cOutField08 = @cDefaultQTY -- QTY  
      SET @cOutField09 = '' -- UOM  
      SET @cOutField10 = CAST( @nIDQTY AS NVARCHAR( 10))  
      SET @cOutField12 = '' -- @cReasonCode  
  
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
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY, ' +  
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
               ' @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
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
               '@cRefNo        NVARCHAR( 60), ' +  
               '@cID           NVARCHAR( 18), ' +  
               '@cLOC          NVARCHAR( 10), ' +  
               '@cMethod       NVARCHAR( 1),  ' +  
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
               '@cRDLineNo     NVARCHAR( 10),   ' +  
               '@nErrNo        INT           OUTPUT, ' +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY,  
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
               @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
      END  
  
      -- (james02)  
      -- Extended info  
      IF @cExtendedInfoSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
         BEGIN  
            SET @cExtendedInfo = ''  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY, ' +  
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
               ' @cRDLineNo, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
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
               '@cRefNo        NVARCHAR( 60), ' +  
               '@cID           NVARCHAR( 18), ' +  
               '@cLOC          NVARCHAR( 10), ' +  
               '@cMethod       NVARCHAR( 1),  ' +  
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
               '@cRDLineNo     NVARCHAR( 10),   ' +  
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +  
               '@nErrNo        INT           OUTPUT, ' +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT'  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep_IDLOC, @nScn_IDLOC, @nInputKey, @cFacility, @cStorerKey,  
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY,  
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
               @cRDLineNo, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            SET @cOutField04 = @cExtendedInfo  
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
  
      -- Finalize ASN
      IF @cFinalizeASN = '1'
      BEGIN
         -- Check start receiving
         IF EXISTS( SELECT 1 
            FROM dbo.ReceiptDetail WITH (NOLOCK)  
            WHERE ReceiptKey= @cReceiptKey  
               AND BeforeReceivedQTY > 0)  
         BEGIN  
            SET @cOutField01 = '' -- Option
            
            -- Go to ASN Finalize screen  
            SET @nScn = @nScn_FinalizeASN  
            SET @nStep = @nStep_FinalizeASN
            
            GOTO Quit
         END  
      END  

      -- Go to ASN screen  
      SET @nScn = @nScn_ASNPO  
      SET @nStep = @nStep_ASNPO  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 3. Scn = 3990. Pre lottables  
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
Step_PreLottable:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Dynamic lottable  
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'PRECAPTURE', 'CHECK', 5, 1,  
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cPreLottable01 OUTPUT,  
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cPreLottable02 OUTPUT,  
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cPreLottable03 OUTPUT,  
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dPreLottable04 OUTPUT,  
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dPreLottable05 OUTPUT,  
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cPreLottable06 OUTPUT,  
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cPreLottable07 OUTPUT,  
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cPreLottable08 OUTPUT,  
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cPreLottable09 OUTPUT,  
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cPreLottable10 OUTPUT,  
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cPreLottable11 OUTPUT,  
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cPreLottable12 OUTPUT,  
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dPreLottable13 OUTPUT,  
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dPreLottable14 OUTPUT,  
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dPreLottable15 OUTPUT,  
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
  
      -- Copy to actual lottable  
      SET @cLottable01 = @cPreLottable01  
      SET @cLottable02 = @cPreLottable02  
      SET @cLottable03 = @cPreLottable03  
      SET @dLottable04 = @dPreLottable04  
      SET @dLottable05 = @dPreLottable05  
      SET @cLottable06 = @cPreLottable06  
      SET @cLottable07 = @cPreLottable07  
      SET @cLottable08 = @cPreLottable08  
      SET @cLottable09 = @cPreLottable09  
      SET @cLottable10 = @cPreLottable10  
      SET @cLottable11 = @cPreLottable11  
      SET @cLottable12 = @cPreLottable12  
      SET @dLottable13 = @dPreLottable13  
      SET @dLottable14 = @dPreLottable14  
      SET @dLottable15 = @dPreLottable15  
  
      -- Get IDQTY  
      SELECT @nIDQTY = ISNULL( SUM( BeforeReceivedQTY), 0)  
      FROM dbo.ReceiptDetail WITH (NOLOCK)  
      WHERE ReceiptKey = @cReceiptKey  
         AND ToLOC = @cLOC  
         AND ToID = @cID  
  
      -- Enable / disable QTY  
      SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END  
  
      -- Prepare next screen variable  
      SET @cOutField01 = @cID  
      SET @cOutField02 = @cLOC  
      SET @cOutField03 = '' -- SKU  
      SET @cOutField04 = '' -- SKU  
      SET @cOutField05 = '' -- Descr1  
      SET @cOutField06 = '' -- Descr2  
      SET @cOutField07 = '' -- Stat  
      SET @cOutField08 = @cDefaultQTY -- QTY  
      SET @cOutField09 = '' -- UOM  
      SET @cOutField10 = CAST( @nIDQTY AS NVARCHAR( 10))  
      SET @cOutField12 = '' -- @cReasonCode  
  
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU  
  
      -- Go to next screen  
      SET @nScn = @nScn_SKUQTY  
      SET @nStep = @nStep_SKUQTY  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Dynamic lottable  
      SET @cSKU = ''  
      SET @cLottableCode = ''  
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'PRECAPTURE', 'POPULATE', 5, 1,  
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cPreLottable01 OUTPUT,  
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cPreLottable02 OUTPUT,  
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cPreLottable03 OUTPUT,  
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dPreLottable04 OUTPUT,  
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dPreLottable05 OUTPUT,  
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cPreLottable06 OUTPUT,  
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cPreLottable07 OUTPUT,  
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cPreLottable08 OUTPUT,  
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cPreLottable09 OUTPUT,  
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cPreLottable10 OUTPUT,  
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cPreLottable11 OUTPUT,  
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cPreLottable12 OUTPUT,  
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dPreLottable13 OUTPUT,  
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dPreLottable14 OUTPUT,  
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dPreLottable15 OUTPUT,  
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
  
      -- Prepare next screen variable  
      SET @cOutField01 = @cReceiptKey  
      SET @cOutField02 = @cPOKey  
      SET @cOutField03 = @cID  
      SET @cOutField04 = @cLOC  
      SET @cOutField05 = @cMethod  
      SET @cOutField06 = ''  
  
      -- Go to QTY screen  
      SET @nScn = @nScn_IDLOC  
      SET @nStep = @nStep_IDLOC  
   END  
  
   Step_PreLottable_Quit:  
   BEGIN  
      -- Extended info  
      IF @cExtendedInfoSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
         BEGIN  
            SET @cExtendedInfo = ''  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY, ' +  
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
               ' @cRDLineNo, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
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
               '@cRefNo        NVARCHAR( 60), ' +  
               '@cID           NVARCHAR( 18), ' +  
               '@cLOC          NVARCHAR( 10), ' +  
               '@cMethod       NVARCHAR( 1),  ' +  
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
               '@cRDLineNo     NVARCHAR( 10),   ' +  
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +  
               '@nErrNo        INT           OUTPUT, ' +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT'  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep_PreLottable, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY,  
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
               @cRDLineNo, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            SET @cOutField11 = @cExtendedInfo   -- (james04)  
         END  
      END  
   END  
END  
GOTO Quit  
  
  
/***********************************************************************************  
Step 4. Scn = 4342. SKU, QTY screen  
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
      SET @cSKU = @cInField03 -- SKU  
      SET @cBarcode = @cInField03  
      SET @cQTY = CASE WHEN @cFieldAttr08 = 'O' THEN @cOutField08 ELSE @cInField08 END -- QTY  
      SET @cReasonCode = @cInField12  
      SET @cUCCUOM = ''    -- ZG01  
  
      -- Validate blank  
      IF @cSKU = ''  
      BEGIN  
         SET @nErrNo = 57623  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU needed  
         GOTO Step_SKUQTY_Fail_SKU  
      END  
  
      -- Decode  
      IF @cDecodeSKUSP <> ''  
      BEGIN  
         IF @cDecodeSKUSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
                  @cID         OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT,
                  @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
                  @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
                  @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT
                  -- @nErrNo   OUTPUT, @cErrMsg     OUTPUT
         END
         
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
         SET @nErrNo = 57624  
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
            SET @nErrNo = 57625  
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
            SET @nErrNo = 57627  
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
  
      -- Check POST lottable  
      IF @cMethod = '1' -- Lottable, SKU  
      BEGIN  
         -- Copy to actual lottable  
         SELECT  
            @cLottable01 = @cPreLottable01,  
            @cLottable02 = @cPreLottable02,  
            @cLottable03 = @cPreLottable03,  
            @dLottable04 = @dPreLottable04,  
            @dLottable05 = @dPreLottable05,  
            @cLottable06 = @cPreLottable06,  
            @cLottable07 = @cPreLottable07,  
            @cLottable08 = @cPreLottable08,  
            @cLottable09 = @cPreLottable09,  
            @cLottable10 = @cPreLottable10,  
            @cLottable11 = @cPreLottable11,  
            @cLottable12 = @cPreLottable12,  
            @dLottable13 = @dPreLottable13,  
            @dLottable14 = @dPreLottable14,  
            @dLottable15 = @dPreLottable15  
  
         -- Dynamic lottable  
         EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'PRECAPTURE', 'CHECK', 5, 1,  
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
         SET @nErrNo = 57626  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY  
         GOTO Step_SKUQTY_Fail_QTY  
      END  
  
      -- Check reason code  
      IF @cReasonCode <> ''  
      BEGIN  
         IF NOT EXISTS( SELECT Code  
            FROM dbo.CodeLKUP WITH (NOLOCK)  
            WHERE ListName = 'ASNREASON'  
               AND Code = @cReasonCode)  
         BEGIN  
            SET @nErrNo = 57628  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad ReasonCode  
            EXEC rdt.rdtSetFocusField @nMobile, 12 -- ReasonCode  
            SET @cReasonCode = ''  
            GOTO Quit  
         END  
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
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY, ' +  
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
               ' @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
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
               '@cRefNo        NVARCHAR( 60), ' +  
               '@cID           NVARCHAR( 18), ' +  
               '@cLOC          NVARCHAR( 10), ' +  
               '@cMethod       NVARCHAR( 1),  ' +  
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
               '@cRDLineNo     NVARCHAR( 10), ' +  
               '@nErrNo        INT           OUTPUT, ' +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY,  
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
               @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
      END  
  
      IF @cMethod = '2' -- SKU, Lottable  
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
            SET @nScn = @nScn_PostLottable  
            SET @nStep = @nStep_PostLottable  
  
            GOTO Step_SKUQTY_Quit  
         END  
      END  
  
      -- Handling transaction  
      SET @nTranCount = @@TRANCOUNT  
      BEGIN TRAN  -- Begin our own transaction  
      SAVE TRAN rdtfnc_PieceReturn -- For rollback or commit only our own transaction  
  
      -- Receive  
      EXEC rdt.rdt_PieceReturn_Confirm @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility,  
         @cReceiptKey, @cPOKey, @cLOC, @cID, @cSKU, @cUOM, @nQTY,  
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
         @cReasonCode, '', @cRDLineNo OUTPUT, @nIDQTY OUTPUT, @nQTYExpected OUTPUT, @nBeforeReceivedQTY OUTPUT,  
         @nErrNo OUTPUT, @cErrMsg OUTPUT  
      IF @nErrNo <> 0  
      BEGIN  
         ROLLBACK TRAN rdtfnc_PieceReturn  
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
            COMMIT TRAN  
  
         -- Prepare next screen var  
         SET @cOutField03 = '' -- SKU  
         SET @cOutField07 = CAST( @nBeforeReceivedQTY AS NVARCHAR( 5)) + '/' + CAST( @nQTYExpected AS NVARCHAR( 5))  
         SET @cOutField08 = @cDefaultQTY -- QTY  
         SET @cOutField10 = CAST( @nIDQTY AS NVARCHAR( 10))  
  
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU  
  
         GOTO Quit  
      END  
  
      -- Extended update  
      IF @cExtendedUpdateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY, ' +  
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
               ' @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
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
               '@cRefNo        NVARCHAR( 60), ' +  
               '@cID           NVARCHAR( 18), ' +  
               '@cLOC          NVARCHAR( 10), ' +  
               '@cMethod       NVARCHAR( 1),  ' +  
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
               '@cRDLineNo     NVARCHAR( 10),   ' +  
               '@nErrNo        INT           OUTPUT, ' +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY,  
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
               @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
            BEGIN  
               ROLLBACK TRAN rdtfnc_PieceReturn  
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
                  COMMIT TRAN  
  
               -- Prepare next screen var  
               SET @cOutField03 = '' -- SKU  
               SET @cOutField07 = CAST( @nBeforeReceivedQTY AS NVARCHAR( 5)) + '/' + CAST( @nQTYExpected AS NVARCHAR( 5))  
               SET @cOutField08 = @cDefaultQTY -- QTY  
               SET @cOutField10 = CAST( @nIDQTY AS NVARCHAR( 10))  
  
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU  
               GOTO Quit  
            END  
         END  
      END  
  
      COMMIT TRAN rdtfnc_PieceReturn  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  
      
      -- Finalize ASN
      IF @cFinalizeASN = '2' -- No prompt, auto finalize
      BEGIN
         -- Fully received
         IF NOT EXISTS( SELECT TOP 1 1
            FROM ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
            GROUP BY SKU
            HAVING ISNULL( SUM( QTYExpected), 0) <>
                   ISNULL( SUM( BeforeReceivedQty), 0))
         BEGIN
            -- Finalize ASN
            EXEC rdt.rdt_PieceReturn_Finalize
               @nFunc         = @nFunc,
               @nMobile       = @nMobile,
               @cLangCode     = @cLangCode,
               @nStep         = @nStep,
               @nInputKey     = @nInputKey,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerKey,
               @cReceiptKey   = @cReceiptKey,
               @cRefNo        = @cRefNo,
               @nErrNo        = @nErrNo  OUTPUT,
               @cErrMsg       = @cErrMsg OUTPUT

            -- Go to finalilze screen, to retry
            -- (cannot remain at current screen, due to it is not inside the transaction. ENTER again will double receive)
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')

               SET @cOutField01 = '' -- @cOption

               -- Go to next screen
               SET @nScn = @nScn_FinalizeASN
               SET @nStep = @nStep_FinalizeASN

               GOTO Quit
            END

            -- Prepare next screen var
            SET @cOutField01 = '' -- @cReceiptKey
            SET @cOutField02 = '' -- @cPOKey
            SET @cOutField03 = '' -- @cRefNo
            

            IF @cRefNo <> ''  
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- RefNo  
            ELSE
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN

            -- Go to next screen
            SET @nScn = @nScn_ASNPO
            SET @nStep = @nStep_ASNPO

            GOTO Step_SKUQTY_Quit
         END
      END
   
      -- Reset data  
      SELECT @cSKU = '', @nQTY = 0,  
         @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL, @dLottable05 = NULL,  
         @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',   @cLottable10 = '',  
         @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL, @dLottable15 = NULL  
  
      -- Prepare next screen var  
      SET @cOutField03 = '' -- SKU  
      SET @cOutField07 = CAST( @nBeforeReceivedQTY AS NVARCHAR( 5)) + '/' + CAST( @nQTYExpected AS NVARCHAR( 5))  
      SET @cOutField08 = @cDefaultQTY -- QTY  
      SET @cOutField10 = CAST( @nIDQTY AS NVARCHAR( 10))  
  
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU  
  
      -- Remain in current screen  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Extended validate (james03)  
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY, ' +  
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
               ' @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
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
               '@cRefNo        NVARCHAR( 60), ' +  
               '@cID           NVARCHAR( 18), ' +  
               '@cLOC          NVARCHAR( 10), ' +  
               '@cMethod       NVARCHAR( 1),  ' +  
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
               '@cRDLineNo     NVARCHAR( 10), ' +  
               '@nErrNo        INT           OUTPUT, ' +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY,  
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
               @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
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
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY, ' +  
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
               ' @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
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
               '@cRefNo        NVARCHAR( 60), ' +  
               '@cID           NVARCHAR( 18), ' +  
               '@cLOC          NVARCHAR( 10), ' +  
               '@cMethod       NVARCHAR( 1),  ' +  
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
               '@cRDLineNo     NVARCHAR( 10),   ' +  
               '@nErrNo        INT           OUTPUT, ' +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY,  
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
               @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
      END  
  
      IF @cMethod = '2' -- SKU, Lottable  
      BEGIN  
         -- Prepare prev screen var  
         SET @cOutField01 = @cReceiptKey  
         SET @cOutField02 = @cPOKey  
         SET @cOutField03 = @cID  
         SET @cOutField04 = @cLOC  
         SET @cOutField05 = @cMethod  
         SET @cOutField06 = ''  
  
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- ID  
  
         -- Go to prev screen  
         SET @nScn = @nScn_IDLOC  
         SET @nStep = @nStep_IDLOC  
      END  
  
      IF @cMethod = '1' -- Lottable, SKU  
      BEGIN  
         -- Dynamic lottable  
         SET @cSKU = ''  
         SET @cLottableCode = ''  
         EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'PRECAPTURE', 'POPULATE', 5, 1,  
            @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cPreLottable01 OUTPUT,  
            @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cPreLottable02 OUTPUT,  
            @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cPreLottable03 OUTPUT,  
            @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dPreLottable04 OUTPUT,  
            @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dPreLottable05 OUTPUT,  
            @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cPreLottable06 OUTPUT,  
            @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cPreLottable07 OUTPUT,  
            @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cPreLottable08 OUTPUT,  
            @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cPreLottable09 OUTPUT,  
            @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cPreLottable10 OUTPUT,  
            @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cPreLottable11 OUTPUT,  
            @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cPreLottable12 OUTPUT,  
            @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dPreLottable13 OUTPUT,  
            @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dPreLottable14 OUTPUT,  
            @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dPreLottable15 OUTPUT,  
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
            SET @nScn = @nScn_PreLottable  
            SET @nStep = @nStep_PreLottable  
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
            SET @cOutField01 = @cReceiptKey  
            SET @cOutField02 = @cPOKey  
            SET @cOutField03 = @cID  
            SET @cOutField04 = @cLOC  
            SET @cOutField05 = @cMethod  
            SET @cOutField06 = ''  
  
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- ID  
  
            -- Go to prev screen  
            SET @nScn = @nScn_IDLOC  
            SET @nStep = @nStep_IDLOC  
         END  
      END  
   END  
  
   Step_SKUQTY_Quit:  
   BEGIN  
      -- Extended info  
      IF @cExtendedInfoSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
         BEGIN  
            SET @cExtendedInfo = ''  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY, ' +  
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
               ' @cRDLineNo, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
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
               '@cRefNo        NVARCHAR( 60), ' +  
               '@cID           NVARCHAR( 18), ' +  
               '@cLOC          NVARCHAR( 10), ' +  
               '@cMethod       NVARCHAR( 1),  ' +  
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
               '@cRDLineNo     NVARCHAR( 10),   ' +  
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +  
               '@nErrNo        INT           OUTPUT, ' +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT'  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep_SKUQTY, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY,  
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
               @cRDLineNo, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nStep = @nStep_ASNPO  
               SET @cOutField04 = @cExtendedInfo  
            ELSE  
               SET @cOutField11 = @cExtendedInfo -- (ChewKP01)  
         END  
      END  
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
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 5. Scn = 3990. Post lottables  
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
Step_PostLottable:  
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
  
      -- Extended validate  
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY, ' +  
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
               ' @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
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
               '@cRefNo        NVARCHAR( 60), ' +  
               '@cID           NVARCHAR( 18), ' +  
               '@cLOC          NVARCHAR( 10), ' +  
               '@cMethod       NVARCHAR( 1),  ' +  
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
               '@cRDLineNo     NVARCHAR( 10), ' +  
               '@nErrNo        INT           OUTPUT, ' +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY,  
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
               @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
      END  
  
      -- Handling transaction  
      SET @nTranCount = @@TRANCOUNT  
      BEGIN TRAN  -- Begin our own transaction  
      SAVE TRAN rdtfnc_PieceReturn -- For rollback or commit only our own transaction  
  
      -- Receive  
      EXEC rdt.rdt_PieceReturn_Confirm @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility,  
         @cReceiptKey, @cPOKey, @cLOC, @cID, @cSKU, @cUOM, @nQTY,  
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
         @cReasonCode, '', @cRDLineNo OUTPUT, @nIDQTY OUTPUT, @nQTYExpected OUTPUT, @nBeforeReceivedQTY OUTPUT,  
         @nErrNo OUTPUT, @cErrMsg OUTPUT  
      IF @nErrNo <> 0  
      BEGIN  
         ROLLBACK TRAN rdtfnc_PieceReturn  
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
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY, ' +  
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
               ' @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
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
               '@cRefNo        NVARCHAR( 60), ' +  
               '@cID           NVARCHAR( 18), ' +  
               '@cLOC          NVARCHAR( 10), ' +  
               '@cMethod       NVARCHAR( 1),  ' +  
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
               '@cRDLineNo     NVARCHAR( 10),   ' +  
               '@nErrNo        INT           OUTPUT, ' +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY,  
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
               @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
            BEGIN  
               ROLLBACK TRAN rdtfnc_PieceReturn  
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
                  COMMIT TRAN  
               GOTO Quit  
            END  
         END  
      END  
  
      COMMIT TRAN rdtfnc_PieceReturn  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  
  
      -- Reset data  
      SELECT @cSKU = '', @nQTY = 0,  
         @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL, @dLottable05 = NULL,  
         @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',   @cLottable10 = '',  
         @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL, @dLottable15 = NULL  
  
      -- Enable field  
      SET @cFieldAttr02 = '' -- Dynamic lottable 1..5  
      SET @cFieldAttr04 = ''  
      SET @cFieldAttr06 = ''  
      SET @cFieldAttr08 = ''  
      SET @cFieldAttr10 = ''  
  
      -- Enable / disable QTY  
      SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END  
  
      -- Prepare next screen var  
      SET @cOutField01 = @cID  
      SET @cOutField02 = @cLOC  
      SET @cOutField03 = '' -- SKU  
      SET @cOutField04 = @cSKU  
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDesc, 21, 20)  
      SET @cOutField07 = CAST( @nBeforeReceivedQTY AS NVARCHAR( 5)) + '/' + CAST( @nQTYExpected AS NVARCHAR( 5))  
      SET @cOutField08 = @cDefaultQTY -- QTY  
      SET @cOutField09 = @cUOM  
      SET @cOutField10 = CAST( @nIDQTY AS NVARCHAR( 10))  
      SET @cOutField12 = '' -- @cReasonCode  
  
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU  
  
      -- Go to SKU QTY screen  
      SET @nScn = @nScn_SKUQTY  
      SET @nStep = @nStep_SKUQTY  
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
  
      -- Enable / disable QTY  
      SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END  
  
      -- Prepare next screen var  
      SET @cOutField01 = @cID  
      SET @cOutField02 = @cLOC  
      SET @cOutField03 = '' -- SKU  
      SET @cOutField04 = @cSKU  
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  
      SET @cOutField06 = rdt.rdtFormatString( @cSKUDesc, 21, 20)  
      SET @cOutField07 = CAST( @nBeforeReceivedQTY AS NVARCHAR( 5)) + '/' + CAST( @nQTYExpected AS NVARCHAR( 5))  
      SET @cOutField08 = @cDefaultQTY -- QTY  
      SET @cOutField09 = @cUOM  
      SET @cOutField10 = CAST( @nIDQTY AS NVARCHAR( 10))  
      SET @cOutField12 = '' -- @cReasonCode  
  
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU  
  
      -- Go to SKU QTY screen  
      SET @nScn = @nScn_SKUQTY  
      SET @nStep = @nStep_SKUQTY  
   END  
  
   Step_PostLottable_Quit:  
   BEGIN  
      -- Extended info  
      IF @cExtendedInfoSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
         BEGIN  
            SET @cExtendedInfo = ''  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY, ' +  
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
               ' @cRDLineNo, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
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
               '@cRefNo        NVARCHAR( 60), ' +  
               '@cID           NVARCHAR( 18), ' +  
               '@cLOC          NVARCHAR( 10), ' +  
               '@cMethod       NVARCHAR( 1),  ' +  
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
               '@cRDLineNo     NVARCHAR( 10),   ' +  
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +  
               '@nErrNo        INT           OUTPUT, ' +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT'  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep_PostLottable, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY,  
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
               @cRDLineNo, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            --SET @cOutField15 = @cExtendedInfo  
            SET @cOutField11 = @cExtendedInfo -- (ChewKP01)/(james04)  
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
   END  
  
   -- Enable field  
   SET @cFieldAttr05 = '' -- Dynamic verify SKU 1..5  
   SET @cFieldAttr07 = '' --  
   SET @cFieldAttr09 = '' --  
   SET @cFieldAttr11 = '' --  
   SET @cFieldAttr13 = '' --  
  
   -- Enable / disable QTY  
   SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END  
  
   -- Prepare next screen var  
   SET @cOutField01 = @cID  
   SET @cOutField02 = @cLOC  
   SET @cOutField03 = '' -- SKU  
   SET @cOutField04 = @cSKU  
   SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  
   SET @cOutField06 = rdt.rdtFormatString( @cSKUDesc, 21, 20)  
   SET @cOutField07 = CAST( @nBeforeReceivedQTY AS NVARCHAR( 5)) + '/' + CAST( @nQTYExpected AS NVARCHAR( 5))  
   SET @cOutField08 = @cDefaultQTY -- QTY  
   SET @cOutField09 = @cUOM  
   SET @cOutField10 = CAST( @nIDQTY AS NVARCHAR( 10))  
   SET @cOutField12 = '' -- @cReasonCode  
  
   EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU  
  
   -- Go to SKU QTY screen  
   SET @nScn = @nScn_SKUQTY  
   SET @nStep = @nStep_SKUQTY  
  
   Step_VerifySKU_Quit:  
   BEGIN  
      -- Extended info  
      IF @cExtendedInfoSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
         BEGIN  
            SET @cExtendedInfo = ''  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +  
               ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY, ' +  
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
               ' @cRDLineNo, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
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
               '@cRefNo        NVARCHAR( 60), ' +  
               '@cID           NVARCHAR( 18), ' +  
               '@cLOC          NVARCHAR( 10), ' +  
               '@cMethod       NVARCHAR( 1),  ' +  
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
               '@cRDLineNo     NVARCHAR( 10),   ' +  
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +  
               '@nErrNo        INT           OUTPUT, ' +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT'  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep_VerifySKU, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY,  
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
               @cRDLineNo, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            --SET @cOutField15 = @cExtendedInfo  
            SET @cOutField11 = @cExtendedInfo -- (ChewKP01)/(james04)  
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
  
   -- Enable / disable QTY  
   SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END  
  
   -- Prepare next screen var  
   SET @cOutField01 = @cID  
   SET @cOutField02 = @cLOC  
   SET @cOutField03 = '' -- SKU  
   SET @cOutField04 = @cSKU  
   SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  
   SET @cOutField06 = rdt.rdtFormatString( @cSKUDesc, 21, 20)  
   SET @cOutField07 = CAST( @nBeforeReceivedQTY AS NVARCHAR( 5)) + '/' + CAST( @nQTYExpected AS NVARCHAR( 5))  
   SET @cOutField08 = @cDefaultQTY -- QTY  
   SET @cOutField09 = @cUOM  
   SET @cOutField10 = CAST( @nIDQTY AS NVARCHAR( 10))  
   SET @cOutField12 = '' -- @cReasonCode  
  
   EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU  
  
   -- Go to SKU QTY screen  
   SET @nScn = @nScn_SKUQTY  
   SET @nStep = @nStep_SKUQTY  
END  
GOTO Quit  


/********************************************************************************  
Step 8. Screen = 4343. Finalize ASN  
   FINALIZE ASN?  
   1 = YES  
   9 = NO  
   OPTION:  (Field10, input)  
********************************************************************************/  
Step_FinalizeASN:  --yeekung01  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      SET @cOption = @cInField10  
  
      IF @cOption NOT IN ('1','9')  
      BEGIN  
         SET @nErrNo = 57629  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option  
         GOTO Quit  
      END  
  
      IF @cOption = '1' -- YES
      BEGIN
         -- Finalize ASN
         EXEC rdt.rdt_PieceReturn_Finalize
            @nFunc         = @nFunc,
            @nMobile       = @nMobile,
            @cLangCode     = @cLangCode,
            @nStep         = @nStep,
            @nInputKey     = @nInputKey,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerKey,
            @cReceiptKey   = @cReceiptKey,
            @cRefNo        = @cRefNo,
            @nErrNo        = @nErrNo  OUTPUT,
            @cErrMsg       = @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
         
         -- Extended update  
         IF @cExtendedUpdateSP <> ''  
         BEGIN  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
            BEGIN  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +  
                  ' @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY, ' +  
                  ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +  
                  ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +  
                  ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +  
                  ' @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
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
                  '@cRefNo        NVARCHAR( 60), ' +  
                  '@cID           NVARCHAR( 18), ' +  
                  '@cLOC          NVARCHAR( 10), ' +  
                  '@cMethod       NVARCHAR( 1),  ' +  
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
                  '@cRDLineNo     NVARCHAR( 10),   ' +  
                  '@nErrNo        INT           OUTPUT, ' +  
                  '@cErrMsg       NVARCHAR( 20) OUTPUT  '  
     
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                  @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey,  
                  @cReceiptKey, @cPOKey, @cRefNo, @cID, @cLOC, @cMethod, @cSKU, @nQTY,  
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
                  @cRDLineNo, @nErrNo OUTPUT, @cErrMsg OUTPUT  
     
               IF @nErrNo <> 0  
                  GOTO Quit  
            END  
         END  
  
         -- Go to ASNPO Screen  
         SET @nScn = @nScn_ASNPO  
         SET @nStep = @nStep_ASNPO  
      END  

      ELSE IF @cOption ='9' -- NO  
      BEGIN  
         -- Go to ASNPO Screen  
         SET @nScn = @nScn_ASNPO  
         SET @nStep = @nStep_ASNPO  
      END  
   END
   
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Prepare previous screen variable  
      SET @cOutField01 = @cReceiptKey  
      SET @cOutField02 = @cPOKey  
      SET @cInField10 =''  
      SET @cOption = ''  
  
      -- Go to previous Screen  
      SET @nScn = @nScn_IDLOC  
      SET @nStep = @nStep_IDLOC  
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
      -- UserName     = @cUserName,  
  
      V_StorerKey  = @cStorerKey,  
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
  
      V_String1    = @cPreLottable01,  
      V_String2    = @cPreLottable02,  
      V_String3    = @cPreLottable03,  
      V_String6    = @cPreLottable06,  
      V_String7    = @cPreLottable07,  
      V_String8    = @cPreLottable08,  
      V_String9    = @cPreLottable09,  
      V_String10   = @cPreLottable10,  
      V_String11   = @cPreLottable11,  
      V_String12   = @cPreLottable12,  
      V_String16   = @cCheckIDInUse,  
      V_String17   = @cMethod,  
      V_String18   = @cLottableCode,  
      V_String19   = @cUOM,  
      V_String20   = @cReasonCode,  
  
      V_String21   = @cDefaultToLOC,  
      V_String22   = @cDecodeSKUSP,  
      V_String23   = @cMultiSKUBarcode,  
      V_String24   = @cVerifySKU,  
      V_String25   = @cDisableQTYField,  
      V_String26   = @cDefaultQTY,  
      V_String27   = @cExtendedInfoSP,  
      V_String28   = @cExtendedInfo,  
      V_String29   = @cExtendedValidateSP,  
      V_String30   = @cExtendedUpdateSP,  
      V_String31   = @cCheckSKUInASN,  
      V_String32   = @cReceiptLineNumber,  
      V_String33   = @cFinalizeASN,  
      V_String34   = @cUCCUOM,  
      -- V_String35   = @cDefaultCursor,  
      V_String36   = @cSuggestLocSP,  
      V_String38   = @cRDLineNo,  
      V_String41   = @cRefNo,  
      V_String42   = @cOption,  
      V_String44   = @cBarcode,
   
      V_Integer1   = @nIDQTY,  
      V_Integer2   = @nBeforeReceivedQTY,  
      V_Integer3   = @nQTYExpected,  
  
      V_DateTime1  = @dPreLottable04,  
      V_DateTime2  = @dPreLottable05,  
      V_DateTime3  = @dPreLottable13,  
      V_DateTime4  = @dPreLottable14,  
      V_DateTime5  = @dPreLottable15,  
  
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