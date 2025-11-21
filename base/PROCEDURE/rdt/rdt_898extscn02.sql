SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_898ExtScn02                                           */  
/*                                                                            */  
/* Purpose:   For Levis - Changes in UCC Receive to process for returns       */  
/*                                                                            */  
/* Date        Rev     Author   Purposes                                      */  
/* 2024-11-15  1.0.0   ShaoAn   FCR-1103 Changes in UCC Receive to process    */  
/*                              for returns                                   */
/* 2025-01-02  1.0.1   jch507   FCR-1103 Add extinfo entry to step=10 section */  
/******************************************************************************/  
  
CREATE   PROC  [RDT].[rdt_898ExtScn02] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nScn         INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15), 

   @tExtScnData      VariableTable READONLY,
   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,  @cLottable01 NVARCHAR( 18) OUTPUT,  
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,  @cLottable02 NVARCHAR( 18) OUTPUT,  
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,  @cLottable03 NVARCHAR( 18) OUTPUT,  
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,  @dLottable04 DATETIME      OUTPUT,  
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,  @dLottable05 DATETIME      OUTPUT,  
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,  @cLottable06 NVARCHAR( 30) OUTPUT, 
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  @cLottable07 NVARCHAR( 30) OUTPUT, 
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  @cLottable08 NVARCHAR( 30) OUTPUT, 
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  @cLottable09 NVARCHAR( 30) OUTPUT, 
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  @cLottable10 NVARCHAR( 30) OUTPUT, 
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,  @cLottable11 NVARCHAR( 30) OUTPUT,
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,  @cLottable12 NVARCHAR( 30) OUTPUT,
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,  @dLottable13 DATETIME      OUTPUT,
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,  @dLottable14 DATETIME      OUTPUT,
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,  @dLottable15 DATETIME      OUTPUT,
   @nAction          INT, 
   @nAfterScn        INT            OUTPUT, 
   @nAfterStep       INT            OUTPUT, 
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 20)  OUTPUT,
   @cUDF01  NVARCHAR( 250) OUTPUT, @cUDF02 NVARCHAR( 250) OUTPUT, @cUDF03 NVARCHAR( 250) OUTPUT,
   @cUDF04  NVARCHAR( 250) OUTPUT, @cUDF05 NVARCHAR( 250) OUTPUT, @cUDF06 NVARCHAR( 250) OUTPUT,
   @cUDF07  NVARCHAR( 250) OUTPUT, @cUDF08 NVARCHAR( 250) OUTPUT, @cUDF09 NVARCHAR( 250) OUTPUT,
   @cUDF10  NVARCHAR( 250) OUTPUT, @cUDF11 NVARCHAR( 250) OUTPUT, @cUDF12 NVARCHAR( 250) OUTPUT,
   @cUDF13  NVARCHAR( 250) OUTPUT, @cUDF14 NVARCHAR( 250) OUTPUT, @cUDF15 NVARCHAR( 250) OUTPUT,
   @cUDF16  NVARCHAR( 250) OUTPUT, @cUDF17 NVARCHAR( 250) OUTPUT, @cUDF18 NVARCHAR( 250) OUTPUT,
   @cUDF19  NVARCHAR( 250) OUTPUT, @cUDF20 NVARCHAR( 250) OUTPUT, @cUDF21 NVARCHAR( 250) OUTPUT,
   @cUDF22  NVARCHAR( 250) OUTPUT, @cUDF23 NVARCHAR( 250) OUTPUT, @cUDF24 NVARCHAR( 250) OUTPUT,
   @cUDF25  NVARCHAR( 250) OUTPUT, @cUDF26 NVARCHAR( 250) OUTPUT, @cUDF27 NVARCHAR( 250) OUTPUT,
   @cUDF28  NVARCHAR( 250) OUTPUT, @cUDF29 NVARCHAR( 250) OUTPUT, @cUDF30 NVARCHAR( 250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Misc variable
   DECLARE
	   @b_success                       INT,
	   @cDisAllowDuplicateIdsOnRFRcpt   NVARCHAR(1),
	   @cAllow_OverReceipt              NVARCHAR(1),
	   @cOption                         NVARCHAR(1),
	   @cUOM                            NVARCHAR(10),
	   @cPOKeyValue                     NVARCHAR(10),
	   @cReceiveAllowAddNewUCC          NVARCHAR(10),
	   @cUCCWithDynamicCaseCnt          NVARCHAR(10),
	   @cTempAddNewUCC                  NVARCHAR(10),
      @cUCC                            NVARCHAR(20),
	   @cTempUCC                        NVARCHAR(20),
	   @cListName                       NVARCHAR(20),
	   @cShort                          NVARCHAR(10),
	   @cStoredProd                     NVARCHAR(250),
	   @nCount                          INT,
	   @cTempLotLabel                   NVARCHAR(20),
	   @cLottableLabel                  NVARCHAR(20),
	   @dTempLottable04                 DATETIME,
	   @dTempLottable09                 DATETIME,
	   @nSKUCnt                         INT,
	   @cSQL                            NVARCHAR(1000),
	   @cSQLParam                       NVARCHAR(1000),
	   @cParam1                         NVARCHAR(20),													
	   @cParam2                         NVARCHAR(20),
	   @cParam3                         NVARCHAR(20),
	   @cParam4                         NVARCHAR(20),
	   @cParam5                         NVARCHAR(20),
      @cDocType                        NVARCHAR(1)

   DECLARE
	   @cPaperPrinter  NVARCHAR( 10),  --(cc01)
      @cLabelPrinter  NVARCHAR( 10),  --(cc01)
      @cReceiptKey          NVARCHAR(10),
      @cReceiptLineNumber   NVARCHAR( 5),
      @cPOKey               NVARCHAR(10),
      @cPOKeyDefaultValue   NVARCHAR(10),
      @cLOC                 NVARCHAR(10),
      @cTOID                NVARCHAR(18),
      @cSKU                 NVARCHAR(20),
      @cTotalCarton         NVARCHAR(4), -- (ChewKP02)
      @cCartonCnt           NVARCHAR(4), -- (ChewKP02)
      @cDesc                NVARCHAR(60),
      @nQTY                 INT,
      @cPackKey             NVARCHAR(10),
      @cPQIndicator         NVARCHAR(10),
      @cPPK                 NVARCHAR(30),
      @nCaseCntQty          INT,
      @nCnt                 INT,
      @nFromScn             INT, --(yeekung01)
      @cExtendedUpdateSP    NVARCHAR(20),
      @cUCCExtValidate      NVARCHAR(20),
      @cClosePallet         NVARCHAR(1),
      @cSkipEstUCCOnID      NVARCHAR( 1),
      @cSkipLottable01      NVARCHAR( 1),
      @cSkipLottable02      NVARCHAR( 1),
      @cSkipLottable03      NVARCHAR( 1),
      @cSkipLottable04      NVARCHAR( 1),
      @cDispStyleColorSize  NVARCHAR( 1),
      @cClosePalletCountUCC NVARCHAR( 1),
      @cExtendedValidateSP  NVARCHAR(20),
      @cDisableQTYField     NVARCHAR( 1),
      @cExtendedInfoSP      NVARCHAR( 20),
      @cExtendedInfo        NVARCHAR( 20),
      @cVerifySKU           NVARCHAR( 1),
      @cMultiUCC            NVARCHAR(  1),
      @cDecodeSP            NVARCHAR( 20), --(yeekung01)
      @cDecodeQty           NVARCHAR(1) ,--(yeekung01)
      @cExtendedScreenSP    NVARCHAR(20) ,--(wsa099)

      @cTempLottable01   NVARCHAR(18), --input field lottable01 from lottable screen
      @cTempLottable02   NVARCHAR(18), --input field lottable02 from lottable screen
      @cTempLottable03   NVARCHAR(18), --input field lottable03 from lottable screen
      @cTempLottable04   NVARCHAR(16), --input field lottable04 from lottable screen

      @cTempLotLabel01   NVARCHAR(20),
      @cTempLotLabel02   NVARCHAR(20),
      @cTempLotLabel03   NVARCHAR(20),
      @cTempLotLabel04   NVARCHAR(20),

      @cCheckPOUCC        NVARCHAR(1), -- (Vicky01)
      @cUCCWithMultiSKU   NVARCHAR(1),

      @cUserName          NVARCHAR(18), -- (Vicky06)
      @cUCCLabel          NVARCHAR(20), --(cc01)

      @cRetUCCCreate     NVARCHAR(1),    --(WSA099))
      @cRetUCCNoMixSKU   NVARCHAR(1)     --(WSA099)

   -- Screen constant  
   DECLARE  
      @nStep_1             INT,  @nStep_1_Scn              INT,  
      @nStep_2             INT,  @nStep_2_Scn              INT,  
      @nStep_3             INT,  @nStep_3_Scn              INT,  
      @nStep_4             INT,  @nStep_4_Scn              INT,  
      @nStep_5             INT,  @nStep_5_Scn              INT,  
      @nStep_6             INT,  @nStep_6_Scn              INT, 
      @nStep_7             INT,  @nStep_7_Scn              INT,   
      @nStep_8             INT,  @nStep_8_Scn              INT,   
      @nStep_9             INT,  @nStep_9_Scn              INT,   
      @nStep_10            INT,  @nStep_10_Scn             INT,   
      @nStep_11            INT,  @nStep_11_Scn             INT,   
      @nStep_12            INT,  @nStep_12_Scn             INT,   
      @nStep_13            INT,  @nStep_13_Scn             INT,   
      @nStep_99            INT,  @nStep_99_Scn             INT

   SELECT  
      @nStep_1                = 1,      @nStep_1_Scn             = 1300,  
      @nStep_2                = 2,      @nStep_2_Scn             = 1301, 
      @nStep_3                = 3,      @nStep_3_Scn             = 1302, 
      @nStep_4                = 4,      @nStep_4_Scn             = 1303, 
      @nStep_5                = 5,      @nStep_5_Scn             = 1304, 
      @nStep_6                = 6,      @nStep_6_Scn             = 1305, 
      @nStep_7                = 7,      @nStep_7_Scn             = 1306, 
      @nStep_8                = 8,      @nStep_8_Scn             = 1307, 
      @nStep_9                = 9,      @nStep_9_Scn             = 1308, 
      @nStep_10               = 10,     @nStep_10_Scn            = 1309, 
      @nStep_11               = 11,     @nStep_11_Scn            = 1310, 
      @nStep_12               = 12,     @nStep_12_Scn            = 1311, 
      @nStep_13               = 13,     @nStep_13_Scn            = 3950, 
      @nStep_99               = 99
   
   SELECT
      @cReceiptKey   = V_ReceiptKey,
      @cPOKey        = V_POKey,
      @cLOC          = V_LOC,
      @cTOID         = V_ID,
      @cSKU          = V_SKU,
      @cUCC          = V_UCC,
      @cUOM          = V_UOM,
      @cDesc         = V_SkuDescr,

      @cLottable01   = V_Lottable01,
      @cLottable02   = V_Lottable02,
      @cLottable03   = V_Lottable03,
      @dLottable04   = V_Lottable04,
      @dLottable05   = V_Lottable05,
      /*CS01 Start*/
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
      /*CS01 End*/
      @cTotalCarton     = v_String2,
      @cCartonCnt       = v_String3,
      @cPackKey         = V_String6,
      @cPQIndicator     = ISNULL(RTRIM(V_String8),'0'),
      @cPPK             = ISNULL(RTRIM(V_String9),'0'),
      @cTempLottable01  = V_String12,
      @cTempLottable02  = V_String13,
      @cTempLottable03  = V_String14,
      @cTempLottable04  = V_String15,
      @cUCCWithMultiSKU = V_String16,
      @cReceiveAllowAddNewUCC = V_String17,
      @cCheckPOUCC            = V_String18, -- Vicky01
      @cExtendedUpdateSP      = V_String19,
      @cUCCExtValidate        = V_String20,
      @cClosePallet           = V_String21,
      @cSkipEstUCCOnID        = V_String22,
      @cSkipLottable01        = V_String23,
      @cSkipLottable02        = V_String24,
      @cSkipLottable03        = V_String25,
      @cSkipLottable04        = V_String26,
      @cDispStyleColorSize    = V_String27,
      @cClosePalletCountUCC   = V_String28,
      @cExtendedValidateSP    = V_String29,
      @cDisableQTYField       = V_String30,
      @cExtendedInfoSP        = V_String31,
      @cExtendedInfo          = V_String32,
      @cUCCLabel              = V_String33, --(cc01)
      @cMultiUCC              = V_String34,
      @cDecodeSP              = V_String35, --(yeekung01)
      @cDecodeQty             = V_String36, --(yeekung01)
      @cVerifySKU             = V_String37, --(yeekung01)
      @cExtendedScreenSP      = V_String38, 

      --@nQTY             = V_Integer1,
      @nCaseCntQty      = V_Integer2,
      @nCnt             = V_Integer3,
      @nFromScn         = V_Integer4
   FROM rdt.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile

   SELECT @nQTY = CAST(Value AS INT) FROM @tExtScnData WHERE Variable="@cQTY"

   --(WSA099)
   SET @cRetUCCCreate = rdt.rdtGetConfig( @nFunc, 'RetUCCCreate', @cStorerKey)
   SET @cRetUCCNoMixSKU = rdt.rdtGetConfig( @nFunc, 'RetUCCNoMixSKU', @cStorerKey)

   SELECT @cDocType = DOCTYPE
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND Storerkey = @cStorerkey

   IF @nFunc = 898
   BEGIN
      IF @cDocType <> 'R'
          GOTO Quit

      IF @nStep = 6
      BEGIN
         IF @nScn = 1305
         BEGIN
           
            SET @nAfterScn = @nStep_6_Scn
            SET @nAfterStep = @nStep_99
            GOTO Quit
         END
      END
      ELSE IF @nStep = @nStep_99
      BEGIN
         IF @nScn = 1305
         BEGIN
            --===================================Start==================================================
            IF @nInputKey = 1      -- ENTER
            BEGIN
               --screen mapping
               SET @cUCC = @cInField01

               -- Check UCC blank
               IF @cUCC = ''
               BEGIN
                  IF @cClosePallet = '1'
                  BEGIN
                     -- Go to close pallet screen
                     SET @cOutField01 = '' --Option
                     SET @cOutField02 = '' --Count UCC
                     SET @nAfterScn  = @nStep_6_Scn + 6  -- @nScn + 6
                     SET @nAfterStep = @nStep_6 + 6      --@nStep + 6
                     EXEC rdt.rdtSetFocusField @nMobile, 1 --Option

                     IF @cClosePalletCountUCC <> '1'
                        SET @cFieldAttr02 = 'O' -- Count UCC
                     GOTO Step_99_Quit
                  END
                  ELSE
                  BEGIN
                     SET @nErrNo = 229154
                     SET @cErrMsg = rdt.rdtgetmessage( 229154, @cLangCode, 'DSP') --UCC Required
                     GOTO Step_99_Fail
                  END
               END

               -- if ucc is 'NOUCC, go to SKU screen
               IF UPPER( @cUCC) = 'NOUCC'
               BEGIN
                  --prepare next screen variable
                  SET @cOutField01 = @cUCC
                  SET @cOutField02 = '' --sku
                  SET @cOutField03 = RTRIM(CAST( @cCartonCnt AS NVARCHAR( 4))) + CASE WHEN @cSkipEstUCCOnID = '1' THEN '' ELSE '/' + CAST( @cTotalCarton AS NVARCHAR( 4)) END -- (ChewKP02)

                  -- Go to SKU screen
                  SET @nAfterScn  = @nStep_6_Scn + 2 -- @nScn + 2
                  SET @nAfterStep = @nStep_6 + 2     --@nStep + 2

                  GOTO Step_99_Quit
               END

               --max carton no and go back
               IF CAST(@cCartonCnt AS INT) >= CAST(@cTotalCarton AS INT) AND @cSkipEstUCCOnID <> '1'
               BEGIN
                  SET @nErrNo = 63135
                  SET @cErrMsg = rdt.rdtgetmessage( 63135, @cLangCode, 'DSP') -->Max No of CTN
                  GOTO Step_99_Fail
               END

               -- Check barcode format
               IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'UCC', @cUCC) = 0
               BEGIN
                  SET @nErrNo = 63173
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
                  GOTO Step_99_Fail
               END

               IF rdt.rdtIsValidDate(@cTempLottable04) = 1 --valid date
               SET @dTempLottable04 = rdt.rdtConvertToDate( @cTempLottable04)

               -- UCC extended validation
               IF @cUCCExtValidate <> ''
               BEGIN
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cUCCExtValidate AND type = 'P')
                  BEGIN
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cUCCExtValidate) +
                        '  @nMobile, @nFunc, @cLangCode, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cUCC ' +
                        ' ,@nErrNo   OUTPUT ' +
                        ' ,@cErrMsg  OUTPUT '
                     SET @cSQLParam = +
                        '  @nMobile     INT       ' +
                        ' ,@nFunc       INT       ' +
                        ' ,@cLangCode   NVARCHAR(  3) ' +
                        ' ,@cReceiptKey NVARCHAR( 10) ' +
                        ' ,@cPOKey      NVARCHAR( 10) ' +
                        ' ,@cLOC        NVARCHAR( 10) ' +
                        ' ,@cToID       NVARCHAR( 18) ' +
                        ' ,@cLottable01 NVARCHAR( 18) ' +
                        ' ,@cLottable02 NVARCHAR( 18) ' +
                        ' ,@cLottable03 NVARCHAR( 18) ' +
                        ' ,@dLottable04 DATETIME  ' +
                        ' ,@cUCC        NVARCHAR( 20) ' +
                        ' ,@nErrNo      INT       OUTPUT ' +
                        ' ,@cErrMsg     NVARCHAR( 20) OUTPUT '
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                        @nMobile, @nFunc, @cLangCode, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cTempLottable01, @cTempLottable02, @cTempLottable03, @dTempLottable04, @cUCC
                        ,@nErrNo   OUTPUT
                        ,@cErrMsg  OUTPUT

                     IF @nErrNo <> 0
                        GOTO Step_99_Fail
                  END
               END

               SET @nQTY = 0

               -- Decode
               IF @cDecodeSP <> ''
               BEGIN
                  DECLARE @nUCCQTY INT

                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
                  BEGIN

                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, ' +
                        ' @cUCC        OUTPUT, @nUCCQTY     OUTPUT,' +
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
                        ' @cUCC         NVARCHAR( 20)  OUTPUT, ' +
                        ' @nUCCQTY      INT            OUTPUT, ' +
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
                        @cUCC        OUTPUT, @nUCCQTY     OUTPUT,
                        @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
                        @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
                        @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
                        @nErrNo      OUTPUT, @cErrMsg     OUTPUT

                  END
               END
               SET @cUDF01 = @cUCC

               IF EXISTS(SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UCCNo = @cUCC AND Status <> '6')
               BEGIN
                  SET @nErrNo = 229151
                  SET @cErrMsg = rdt.rdtgetmessage( 229151, @cLangCode, 'DSP') --UCC Already Exists
                  GOTO Step_99_Fail
               END

               --get ucc count
               SET @nCnt = 0
               SELECT @nCnt = COUNT(UCCNo)
               FROM dbo.UCC WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND UCCNo = @cUCC AND Status <> '6'

               IF @cRetUCCNoMixSKU = '1'
               BEGIN
                  IF @nCnt > 1
                  BEGIN
                     SET @nErrNo = 229152
                     SET @cErrMsg = rdt.rdtgetmessage( 229152, @cLangCode, 'DSP') --Multi Sku/ UCC
                     GOTO Step_99_Fail
                  END
               END

               -- Added by Vicky for SOS#105011 (Start - Vicky01)
               DECLARE @cActPOKey NVARCHAR(10), @cErrMsg1 NVARCHAR(20), @cErrMsg2 NVARCHAR(20), @cErrMsg3 NVARCHAR(20)

               IF @cCheckPOUCC = '1' AND @nCnt > 0 AND UPPER(@cPOKey) <> 'NOPO' AND @cPOKey <> ''
               BEGIN
               SELECT @cActPOKey = ISNULL(SUBSTRING(RTRIM(Sourcekey), 1,10), '')
               FROM dbo.UCC WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND UCCNo = @cUCC

               IF @cActPOKey <> RTRIM(@cPOKey)
               BEGIN
                     SET @nErrNo = 0
                     SET @cErrMsg1 = 'UCC:'
                     SET @cErrMsg2 = 'UCC not in this PO'
                     SET @cErrMsg3 = 'Correct PO is'
                     --SET @cErrMsg = rdt.rdtgetmessage( 63166, @cLangCode, 'DSP') -- UCC:
                     EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1,
                     @cUCC, '', @cErrMsg2, '', @cErrMsg3,  @cActPOKey
                     IF @nErrNo = 1
                     BEGIN
                        SET @cErrMsg1 = ''
                        SET @cErrMsg2 = ''
                        SET @cErrMsg3 = ''
                     END
                     GOTO Step_99_Fail
               END
               END
               -- Added by Vicky for SOS#105011 (End - Vicky01)

               --check UCC status
               DECLARE @cUCCStatus NVARCHAR(1)
               SET @cUCCStatus = ''

               SELECT @cUCCStatus = STATUS
               FROM dbo.UCC WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND UCCNo = @cUCC

               IF RTRIM(@cUCCStatus) = '1' AND @cMultiUCC<>'1'
               BEGIN
                  SET @nErrNo = 63138
                  SET @cErrMsg = rdt.rdtgetmessage( 63138, @cLangCode, 'DSP') --UCC Received
                  GOTO Step_99_Fail
               END

               --single ucc
               IF @nCnt > 0
               BEGIN
               --Get sku
                  SELECT @cSKU = SKU
                  FROM dbo.UCC WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND UCCNo = @cUCC

                  --get some values for use in below part
                  SELECT
                     @cPackKey = PACKKEY,
                     @cDesc = CASE WHEN @cDispStyleColorSize = '1' THEN Style + Color + Size + Measurement ELSE Descr END,
                     @cPPK = PREPACKINDICATOR,
                     @cPQIndicator = PackQtyIndicator,
                     @cTempLotLabel01 = Lottable01Label,
                     @cTempLotLabel02 = Lottable02Label,
                     @cTempLotLabel03 = Lottable03Label,
                     @cTempLotLabel04 = Lottable04Label
                  FROM dbo.Sku WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND SKU = @cSKU

                  --get casecnt, uom
                  SET @nCaseCntQty = 0
                  SELECT
                     @nCaseCntQty = PACK.CASECNT,
                     @cUOM        = PACK.PackUOM3
                  FROM dbo.Pack Pack WITH (NOLOCK)
                  WHERE PackKey = @cPackKey

                  IF @nQTY = 0
                  BEGIN
                     SELECT @nQTY = QTY
                     FROM dbo.UCC WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND UCCNo = @cUCC
                  END

                  --Compare case count with UCC Qty
                  SET @cUCCWithDynamicCaseCnt = ''
                  SELECT @cUCCWithDynamicCaseCnt = SValue
                  FROM RDT.StorerConfig WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND ConfigKey = 'UCCWithDynamicCaseCnt'
                  IF ISNULL(@cUCCWithDynamicCaseCnt,'0') = '0' --0=check against Pack.casecnt  1=Dynamic case count
                  BEGIN
                     IF @nCaseCntQty <> @nQTY
                     BEGIN
                        SET @nErrNo = 63140
                        SET @cErrMsg = rdt.rdtgetmessage( 63140, @cLangCode, 'DSP') --Invalid UCCQTY
                        GOTO Step_99_Fail
                     END
                  END
               END -- UCC Exists

               --Get value from RDT Storer config 'ReceiveAllowAddNewUCC'
               SET @cReceiveAllowAddNewUCC = ''
               SELECT @cReceiveAllowAddNewUCC = ISNULL( SVALUE, '0')
               FROM rdt.StorerConfig WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND ConfigKey = 'ReceiveAllowAddNewUCC'

               --UCC not found
               IF @nCnt = 0
               BEGIN
                  IF @cRetUCCCreate = '1'
                  BEGIN
                     --go to screen SKU
                     SET @nAfterScn  = @nStep_6_Scn +2 -- @nScn + 2
                     SET @nAfterStep = @nStep_6 + 2    --@nStep + 2

                     SET @cSKU = ''
                     SET @nQTY = 0

                     --prepare next screen var
                     SET @cOutField01 = @cUCC
                     SET @cOutField02 = '' --sku
                     SET @cOutField03 = RTRIM(CAST( @cCartonCnt AS NVARCHAR( 4))) + CASE WHEN @cSkipEstUCCOnID = '1' THEN '' ELSE '/' + CAST( @cTotalCarton AS NVARCHAR( 4)) END --(ChewKP02)
                     SET @cOutField04 = ''

                     SET @cReceiveAllowAddNewUCC = @cRetUCCCreate
                     GOTO Step_99_Quit
                  END
                  ELSE IF @cRetUCCCreate = '2'
                  BEGIN 
                     --go to prompt screen 'Create New UCC?'
                     SET @nAfterScn  = @nStep_6_Scn + 1  --@nScn + 1
                     SET @nAfterStep = @nStep_6 + 1      --@nStep + 1

                     --prepare next screen variable
                     SET @cOutField01 = '' --option

                     SET @cReceiveAllowAddNewUCC = @cRetUCCCreate

                     GOTO Step_99_Quit
                  END
                  ELSE
                  BEGIN
                     --not allowed add new UCC
                     IF @cReceiveAllowAddNewUCC = '0'
                     BEGIN
                        SET @nErrNo = 63139
                        SET @cErrMsg = rdt.rdtgetmessage(63139, @cLangCode, 'DSP') --UCC Not Found
                        GOTO Step_99_Fail
                     END

                     --allowed add new UCC
                     IF @cReceiveAllowAddNewUCC = '1'
                     BEGIN
                        --go to screen SKU
                        SET @nAfterScn  = @nStep_6_Scn +2 -- @nScn + 2
                        SET @nAfterStep = @nStep_6 + 2    --@nStep + 2

                        SET @cSKU = ''
                        SET @nQTY = 0

                        --prepare next screen var
                        SET @cOutField01 = @cUCC
                        SET @cOutField02 = '' --sku
                        SET @cOutField03 = RTRIM(CAST( @cCartonCnt AS NVARCHAR( 4))) + CASE WHEN @cSkipEstUCCOnID = '1' THEN '' ELSE '/' + CAST( @cTotalCarton AS NVARCHAR( 4)) END --(ChewKP02)
                        SET @cOutField04 = ''

                        GOTO Step_99_Quit
                     END

                     --allowed add new UCC
                     IF @cReceiveAllowAddNewUCC = '2'
                     BEGIN
                        --go to prompt screen 'Create New UCC?'
                        SET @nAfterScn  = @nStep_6_Scn + 1  --@nScn + 1
                        SET @nAfterStep = @nStep_6 + 1   --@nStep + 1

                     --prepare next screen variable
                        SET @cOutField01 = '' --option

                        GOTO Step_99_Quit
                     END
                  END
               END

               ELSE --ucc found
               BEGIN
                  IF EXISTS ( SELECT 1
                     FROM dbo.UCC WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND UCCNo = @cUCC)
                  BEGIN
                     -- prepare next screen variable
                     SET @cOutField06 = '' --lottable01
                     SET @cOutField07 = '' --lottable02
                     SET @cOutField08 = '' --lottable03
                     SET @cOutField09 = '' --lottable04

                     --retain original value for lottable01-05
                     SET @cLottable01 = @cTempLottable01
                     SET @cLottable02 = @cTempLottable02
                     SET @cLottable03 = @cTempLottable03
                     SET @dLottable04 = rdt.rdtConvertToDate(@cTempLottable04)
                     SET @cOutField06 = @cLottable01
                     SET @cOutField07 = @cLottable02
                     SET @cOutField08 = @cLottable03
                     SET @cOutField09 = CASE WHEN @dLottable04 <> 0  THEN rdt.rdtFormatDate( @dLottable04) ELSE @cTempLottable04 END

                     --initiate @nCounter = 1
                     SET @nCount = 1

                     WHILE @nCount < = 4
                     BEGIN
                        IF @nCount = 1
                        BEGIN
                           SET @cListName = 'Lottable01'
                           SET @cTempLotLabel = @cTempLotLabel01
                        END
                        ELSE IF @nCount = 2
                        BEGIN
                           SET @cListName = 'Lottable02'
                           SET @cTempLotLabel = @cTempLotLabel02
                        END
                        ELSE IF @nCount = 3
                        BEGIN
                           SET @cListName = 'Lottable03'
                           SET @cTempLotLabel = @cTempLotLabel03
                        END
                        ELSE IF @nCount = 4
                        BEGIN
                           SET @cListName = 'Lottable04'
                           SET @cTempLotLabel = @cTempLotLabel04
                        END

                        SELECT TOP 1
                           @cShort = C.Short,
                           @cStoredProd = IsNULL( C.Long, ''),
                           @cLottableLabel = C.Code
                        FROM dbo.CodeLkUp C WITH (NOLOCK)
                        WHERE C.Listname = @cListName
                           AND C.Code = @cTempLotLabel
                           AND (C.StorerKey = @cStorerkey OR C.StorerKey = '')
                        ORDER By C.StorerKey DESC

                        IF @cShort = 'POST' AND @cStoredProd <> ''
                        BEGIN
                        IF rdt.rdtIsValidDate(@cTempLottable04) = 1 --valid date
                           SET @dTempLottable04 = rdt.rdtConvertToDate( @cTempLottable04)

                           EXEC dbo.ispLottableRule_Wrapper
                                 @c_SPName            = @cStoredProd,
                                 @c_ListName          = @cListName,
                                 @c_Storerkey         = @cStorerkey,
                                 @c_Sku               = @cSku,
                                 @c_LottableLabel     = @cLottableLabel,
                                 @c_Lottable01Value   = @cTempLottable01,
                                 @c_Lottable02Value   = @cTempLottable02,
                                 @c_Lottable03Value   = @cTempLottable03,
                                 @dt_Lottable04Value  = @dTempLottable04,
                                 @dt_Lottable05Value  = NULL,
                                 @c_Lottable06Value   = '',                      --(CS01)
                                 @c_Lottable07Value   = '',                      --(CS01)
                                 @c_Lottable08Value   = '',                      --(CS01)
                                 @c_Lottable09Value   = '',                      --(CS01)
                                 @c_Lottable10Value   = '',                      --(CS01)
                                 @c_Lottable11Value   = '',                      --(CS01)
                                 @c_Lottable12Value   = '',                      --(CS01)
                                 @dt_Lottable13Value  = NULL,                    --(CS01)
                                 @dt_Lottable14Value  = NULL,                    --(CS01)
                                 @dt_Lottable15Value  = NULL,                    --(CS01)
                                 @c_Lottable01        = @cLottable01 OUTPUT,
                                 @c_Lottable02        = @cLottable02 OUTPUT,
                                 @c_Lottable03        = @cLottable03 OUTPUT,
                                 @dt_Lottable04       = @dLottable04 OUTPUT,
                                 @dt_Lottable05       = @dLottable05 OUTPUT,
                                 @c_Lottable06        = @cLottable06 OUTPUT,        --(CS01)
                                 @c_Lottable07        = @cLottable07 OUTPUT,        --(CS01)
                                 @c_Lottable08        = @cLottable08 OUTPUT,        --(CS01)
                                 @c_Lottable09        = @cLottable09 OUTPUT,        --(CS01)
                                 @c_Lottable10        = @cLottable10 OUTPUT,        --(CS01)
                                 @c_Lottable11        = @cLottable11 OUTPUT,        --(CS01)
                                 @c_Lottable12        = @cLottable12 OUTPUT,        --(CS01)
                                 @dt_Lottable13       = @dLottable13 OUTPUT,        --(CS01)
                                 @dt_Lottable14       = @dLottable14 OUTPUT,        --(CS01)
                                 @dt_Lottable15       = @dLottable15 OUTPUT,        --(CS01)
                                 @b_Success           = @b_Success   OUTPUT,
                                 @n_Err               = @nErrNo      OUTPUT,
                                 @c_Errmsg            = @cErrMsg     OUTPUT,
                                 @c_Sourcekey         = @cReceiptkey,  -- SOS#81879
                                 @c_Sourcetype        = 'RDTUCCRCV'    -- SOS#81879

                           --IF @b_success <> 1
                           IF ISNULL(@cErrMsg, '') <> ''
                           BEGIN
                           SET @cErrMsg = @cErrMsg

                           IF @cListName = 'Lottable01'
                              EXEC rdt.rdtSetFocusField @nMobile, 6
                           ELSE IF @cListName = 'Lottable02'
                              EXEC rdt.rdtSetFocusField @nMobile, 7
                           ELSE IF @cListName = 'Lottable03'
                              EXEC rdt.rdtSetFocusField @nMobile, 8
                           ELSE IF @cListName = 'Lottable04'
                              EXEC rdt.rdtSetFocusField @nMobile, 9

                           GOTO Step_99_Fail  -- Error will break
                           END

                           SET @cLottable01 = IsNULL( @cLottable01, '')
                           SET @cLottable02 = IsNULL( @cLottable02, '')
                           SET @cLottable03 = IsNULL( @cLottable03, '')
                           SET @dLottable04 = IsNULL( @dLottable04, 0)
                           SET @dLottable05 = IsNULL( @dLottable05, 0)

                           --overwrite the outfield value if lottable POST was setup
                           SET @cOutField06 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE @cTempLottable01 END
                           SET @cOutField07 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE @cTempLottable02 END
                           SET @cOutField08 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE @cTempLottable03 END
                           SET @cOutField09 = CASE WHEN @dLottable04 <> 0  THEN rdt.rdtFormatDate( @dLottable04) ELSE @cTempLottable04 END
                        END

                        --increase counter by 1
                        SET @nCount = @nCount + 1
                     END -- end of while

                     -- Skip lottable
                     IF @cSkipLottable01 = '1' SET @cLottable01 = ''
                     IF @cSkipLottable02 = '1' SET @cLottable02 = ''
                     IF @cSkipLottable03 = '1' SET @cLottable03 = ''
                     IF @cSkipLottable04 = '1' SET @dLottable04 = 0

                     --prepare next screen variable
                     SET @cOutField01 = @cUCC
                     SET @cOutField02 = @cSKU
                     SET @cOutField03 = SUBSTRING( @cDesc,  1, 20)
                     SET @cOutField04 = SUBSTRING( @cDesc, 21, 20)
                     SET @cOutField05 = CASE WHEN IsNULL(@cPPK, '') = '' THEN '0'  ELSE @cPPK END +
                                       '/' +
                                       CASE WHEN IsNULL(@cPQIndicator, '') = '' THEN '0' ELSE @cPQIndicator END
                     SET @cOutField10 = CAST( @nQTY AS NVARCHAR( 5))

                     --set @cPokey value to blank when it is 'NOPO'
                     SET @cPOKeyValue = CASE WHEN UPPER(@cPOkey) = 'NOPO' THEN '' ELSE @cPOkey END

                     --set @cPOKeyDefaultValue to 1 when it is 'NOPO'
                     SET @cPOKeyDefaultValue = CASE WHEN UPPER(@cPOkey) = 'NOPO' THEN '1' ELSE '0' END

                     --set @cTempAddNewUCC to 1 when it is allowed to add new ucc
                     SET @cTempAddNewUCC = CASE WHEN @cReceiveAllowAddNewUCC in ('1','2') THEN '1' ELSE '0' END

                     --set @cTempUCC to blank when it is 'NOUCC'
                     SET @cTempUCC = CASE WHEN UPPER(RTRIM(@cUCC)) = 'NOUCC' THEN '' ELSE @cUCC END

                     --if lottable01 has been setup but no value, prompt error msg
                     IF @cSkipLottable01 <> '1' AND (@cTempLotLabel01 <> '' AND @cOutField06 = '')
                     BEGIN
                        SET @nErrNo = 63151
                        SET @cErrMsg = rdt.rdtgetmessage(63151, @cLangCode, 'DSP') --Lottable01 Req
                        EXEC rdt.rdtSetFocusField @nMobile, 6
                        GOTO Step_99_Fail
                     END

                     --if lottable02 has been setup but no value, prompt error msg
                     IF @cSkipLottable02 <> '1' AND (@cTempLotLabel02 <> '' AND @cOutField07 = '')
                     BEGIN
                        SET @nErrNo = 63152
                        SET @cErrMsg = rdt.rdtgetmessage(63152, @cLangCode, 'DSP') --Lottable02 Req
                        EXEC rdt.rdtSetFocusField @nMobile, 7
                        GOTO Step_99_Fail
                     END

                     --if lottable03 has been setup but no value, prompt error msg
                     IF @cSkipLottable03 <> '1' AND (@cTempLotLabel03 <> '' AND @cOutField08 = '')
                     BEGIN
                        SET @nErrNo = 63153
                        SET @cErrMsg = rdt.rdtgetmessage(63153, @cLangCode, 'DSP') --Lottable03 Req
                        EXEC rdt.rdtSetFocusField @nMobile, 8
                        GOTO Step_99_Fail
                     END

                     --if lottable04 has been setup but no value, prompt error msg
                     IF @cSkipLottable04 <> '1' AND (@cTempLotLabel04 <> '' AND @cOutField09 = '')
                     BEGIN
                        SET @nErrNo = 63154
                        SET @cErrMsg = rdt.rdtgetmessage(63154, @cLangCode, 'DSP') --Lottable04 Req
                        EXEC rdt.rdtSetFocusField @nMobile, 9
                        GOTO Step_99_Fail
                     END

                     -- Update ReceiptDetail
                     -- here should use return config 2024-11-20 ShaoAn
                     --IF @cUCCWithMultiSKU = '1'
                     IF @cRetUCCNoMixSKU = '1'
                     BEGIN
                        DECLARE @nSKUCount INT
                        DECLARE @nTotalQTY INT

                        SET @nSKUCount = 0
                        SET @nTotalQTY = 0

                        DECLARE @nTranCount INT
                        SET @nTranCount = @@TRANCOUNT
                        BEGIN TRAN  -- Begin our own transaction
                        SAVE TRAN UCCWithMultiSKU -- For rollback or commit only our own transaction

                        DECLARE @curUCC CURSOR
                        SET @curUCC = CURSOR FAST_FORWARD FOR
                           SELECT SKU, QTY FROM dbo.UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UCCNo = @cTempUCC
                           -- ORDER BY SKU -- (ChewKP01)
                           ORDER BY UCC_RowRef
                        OPEN @curUCC
                        FETCH NEXT FROM @curUCC INTO @cSKU, @nQTY
                        WHILE @@FETCH_STATUS = 0
                        BEGIN
                           SET @nSKUCount = @nSKUCount + 1
                           SET @nTotalQTY = @nTotalQTY + @nQTY

                           -- Get UOM
                           SELECT @cUOM = PackUOM3
                           FROM dbo.SKU WITH (NOLOCK)
                              JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
                           WHERE SKU.StorerKey = @cStorerKey
                              AND SKU.SKU = @cSKU

                        IF @cExtendedUpdateSP <> ''
                        BEGIN
                              IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
                              BEGIN
                                 SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                                          '  @nMobile, @nFunc, @nStep, @cLangCode, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04 ' +
                                          ' ,@cUCC, @cSKU, @nQTY, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption ' +
                                          ' ,@nErrNo   OUTPUT ' +
                                          ' ,@cErrMsg  OUTPUT '
                                 SET @cSQLParam = +
                                          '  @nMobile     INT       ' +
                                          ' ,@nFunc       INT       ' +
                                          ' ,@nStep       INT       ' +
                                          ' ,@cLangCode   NVARCHAR(  3) ' +
                                          ' ,@cReceiptKey NVARCHAR( 10) ' +
                                          ' ,@cPOKey      NVARCHAR( 10) ' +
                                          ' ,@cLOC        NVARCHAR( 10) ' +
                                          ' ,@cToID       NVARCHAR( 18) ' +
                                          ' ,@cLottable01 NVARCHAR( 18) ' +
                                          ' ,@cLottable02 NVARCHAR( 18) ' +
                                          ' ,@cLottable03 NVARCHAR( 18) ' +
                                          ' ,@dLottable04 DATETIME      ' +
                                          ' ,@cUCC        NVARCHAR( 20) ' +
                                          ' ,@cSKU        NVARCHAR( 20) ' +
                                          ' ,@nQTY        INT           ' +
                                          ' ,@cParam1     NVARCHAR( 20) ' +
                                          ' ,@cParam2     NVARCHAR( 20) ' +
                                          ' ,@cParam3     NVARCHAR( 20) ' +
                                          ' ,@cParam4     NVARCHAR( 20) ' +
                                          ' ,@cParam5     NVARCHAR( 20) ' +
                                          ' ,@cOption     NVARCHAR( 1)  ' +
                                          ' ,@nErrNo      INT       OUTPUT ' +
                                          ' ,@cErrMsg     NVARCHAR( 20) OUTPUT '
                                 EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                                          @nMobile, @nFunc, @nStep, @cLangCode, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04
                                          ,@cUCC, @cSKU, @nQTY, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption
                                          ,@nErrNo   OUTPUT
                                          ,@cErrMsg  OUTPUT

                                 IF @nErrNo <> 0
                                 BEGIN
                                    ROLLBACK TRAN UCCWithMultiSKU
                                    WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                                       COMMIT TRAN
                                    GOTO Step_99_Fail
                                 END
                              END
                           END

                           -- Update ReceiptDetail
                           SET @dTempLottable09 = rdt.rdtConvertToDate(@cOutField09)            --for UWP-25017
                           EXEC rdt.rdt_UCCReceive_Confirm
                              @nFunc         = @nFunc,
                              @nMobile       = @nMobile,
                              @cLangCode     = @cLangCode,
                              @nErrNo        = @nErrNo OUTPUT,
                              @cErrMsg       = @cErrMsg OUTPUT,
                              @cStorerKey    = @cStorerKey,
                              @cFacility     = @cFacility,
                              @cReceiptKey   = @cReceiptKey,
                              @cPOKey        = @cPoKeyValue,
                              @cToLOC        = @cLOC,
                              @cToID         = @cTOID,
                              @cSKUCode      = '',
                              @cSKUUOM       = '',
                              @nSKUQTY       = '',
                              @cUCC          = @cTempUCC,
                              @cUCCSKU       = @cSKU,
                              @nUCCQTY       = @nQTY,
                              @cCreateUCC    = '0',
                              @cLottable01   = @cOutField06,
                              @cLottable02   = @cOutField07,
                              @cLottable03   = @cOutField08,
                              @dLottable04   = @dTempLottable09,                 --@cOutField09,  --for UWP-25017
                              @dLottable05   = NULL,
                              @nNOPOFlag     = @cPOKeyDefaultValue,
                              @cConditionCode = 'OK',
                              @cSubreasonCode = ''
                           IF @nErrno <> 0
                           BEGIN
                              ROLLBACK TRAN UCCWithMultiSKU
                              WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                                 COMMIT TRAN
                              GOTO Step_99_Fail
                           END

                           SELECT @cReceiptLineNumber=receiptlinenumber
                           FROM receiptdetail (NOLOCK)
                           where receiptkey=@cReceiptKey
                              AND SKU=@cSKU
                           ORDER BY EDITDATE DESC;

                           -- EventLog
                           EXEC RDT.rdt_STD_EventLog
                              @cActionType   = '2', -- Receiving
                              @cUserID       = @cUserName,
                              @nMobileNo     = @nMobile,
                              @nFunctionID   = @nFunc,
                              @cFacility     = @cFacility,
                              @cReceiptKey   = @cReceiptKey,
                              @cPOKey        = @cPoKeyValue,
                              @cStorerKey    = @cStorerkey,
                              @cLocation     = @cLOC,
                              @cID           = @cTOID,
                              @cSKU          = @cSku,
                              @cUOM          = @cUOM,
                              @nQTY          = @nQTY,
                              @cUCC          = @cTempUCC,
                              @cRefNo2       = @cReceiptLineNumber

                           FETCH NEXT FROM @curUCC INTO @cSKU, @nQTY
                        END

                        COMMIT TRAN UCCWithMultiSKU     -- Only commit change made in here
                        WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                           COMMIT TRAN

                        -- Prepare next screen variable
                        IF @nSKUCount > 1
                        BEGIN
                           SET @cSKU = 'MULTI SKU'
                           SET @cDesc = ''
                           SET @cPPK = ''
                           SET @cPQIndicator = ''

                           IF @cDecodeQTY='1'
                              SET @nQTY = @nUCCQTY
                           ELSE
                              SET @nQTY = @nTotalQTY

                           SET @cOutField02 = @cSKU
                           SET @cOutField03 = SUBSTRING( @cDesc,  1, 20)
                           SET @cOutField04 = SUBSTRING( @cDesc, 21, 20)
                           SET @cOutField05 = CASE WHEN IsNULL(@cPPK, '') = '' THEN '0'  ELSE @cPPK END +
                                             '/' +
                                             CASE WHEN IsNULL(@cPQIndicator, '') = '' THEN '0' ELSE @cPQIndicator END
                           SET @cOutField10 = CAST( @nQTY AS NVARCHAR( 5))
                        END
                     END
                     ELSE
                     BEGIN
                        IF @cExtendedUpdateSP <> ''
                        BEGIN
                           IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
                           BEGIN
                              SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                                          '  @nMobile, @nFunc, @nStep, @cLangCode, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04 ' +
                                          ' ,@cUCC, @cSKU, @nQTY, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption ' +
                                          ' ,@nErrNo   OUTPUT ' +
                                          ' ,@cErrMsg  OUTPUT '
                              SET @cSQLParam = +
                                          '  @nMobile     INT       ' +
                                          ' ,@nFunc       INT       ' +
                                          ' ,@nStep       INT       ' +
                                          ' ,@cLangCode   NVARCHAR(  3) ' +
                                          ' ,@cReceiptKey NVARCHAR( 10) ' +
                                          ' ,@cPOKey      NVARCHAR( 10) ' +
                                          ' ,@cLOC        NVARCHAR( 10) ' +
                                          ' ,@cToID       NVARCHAR( 18) ' +
                                          ' ,@cLottable01 NVARCHAR( 18) ' +
                                          ' ,@cLottable02 NVARCHAR( 18) ' +
                                          ' ,@cLottable03 NVARCHAR( 18) ' +
                                          ' ,@dLottable04 DATETIME      ' +
                                          ' ,@cUCC        NVARCHAR( 20) ' +
                                          ' ,@cSKU        NVARCHAR( 20) ' +
                                          ' ,@nQTY        INT           ' +
                                          ' ,@cParam1     NVARCHAR( 20) ' +
                                          ' ,@cParam2     NVARCHAR( 20) ' +
                                          ' ,@cParam3     NVARCHAR( 20) ' +
                                          ' ,@cParam4     NVARCHAR( 20) ' +
                                          ' ,@cParam5     NVARCHAR( 20) ' +
                                          ' ,@cOption     NVARCHAR( 1)  ' +
                                          ' ,@nErrNo      INT       OUTPUT ' +
                                          ' ,@cErrMsg     NVARCHAR( 20) OUTPUT '
                              EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                                          @nMobile, @nFunc, @nStep, @cLangCode, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04
                                          ,@cUCC, @cSKU, @nQTY, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption
                                          ,@nErrNo   OUTPUT
                                          ,@cErrMsg  OUTPUT

                              IF @nErrNo <> 0
                              BEGIN
                                 GOTO Step_99_Fail
                              END
                           END
                        END

                        SET @dTempLottable09 = rdt.rdtConvertToDate(@cOutField09)            --for UWP-25017
                        EXEC rdt.rdt_UCCReceive_Confirm
                           @nFunc         = @nFunc,
                           @nMobile       = @nMobile,
                           @cLangCode     = @cLangCode,
                           @nErrNo        = @nErrNo OUTPUT,
                           @cErrMsg       = @cErrMsg OUTPUT,
                           @cStorerKey    = @cStorerKey,
                           @cFacility     = @cFacility,
                           @cReceiptKey   = @cReceiptKey,
                           @cPOKey        = @cPoKeyValue,
                           @cToLOC        = @cLOC,
                           @cToID         = @cTOID,
                           @cSKUCode      = '',
                           @cSKUUOM       = '',
                           @nSKUQTY       = '',
                           @cUCC          = @cTempUCC,
                           @cUCCSKU       = @cSku,
                           @nUCCQTY       = @nQTY,
                           @cCreateUCC    = '0',
                           @cLottable01   = @cOutField06,
                           @cLottable02   = @cOutField07,
                           @cLottable03   = @cOutField08,
                           @dLottable04   = @dTempLottable09,                 --@cOutField09,  --for UWP-25017
                           @dLottable05   = NULL,
                           @nNOPOFlag     = @cPOKeyDefaultValue,
                           @cConditionCode = 'OK',
                           @cSubreasonCode = ''
                           IF @nErrno <> 0
                              GOTO Step_99_Fail

                        SELECT @cReceiptLineNumber=receiptlinenumber
                        FROM receiptdetail (NOLOCK)
                        where receiptkey=@cReceiptKey
                           AND SKU=@cSKU
                        ORDER BY EDITDATE DESC;

                        -- EventLog
                        EXEC RDT.rdt_STD_EventLog
                           @cActionType   = '2', -- Receiving
                           @cUserID       = @cUserName,
                           @nMobileNo     = @nMobile,
                           @nFunctionID   = @nFunc,
                           @cFacility     = @cFacility,
                           @cReceiptKey   = @cReceiptKey,
                           @cPOKey        = @cPoKeyValue,
                           @cStorerKey    = @cStorerkey,
                           @cLocation     = @cLOC,
                           @cID           = @cTOID,
                           @cSKU          = @cSku,
                           @cUOM          = @cUOM,
                           @nQTY          = @nQTY,
                           @cUCC          = @cTempUCC,
                           @cRefNo2       = @cReceiptLineNumber
                     END

                     --increase carton cnt by 1 if it is not loose qty
                     IF UPPER(@cUCC) <> 'NOUCC'
                        SET @cCartonCnt = CONVERT(CHAR,CAST( @cCartonCnt AS INT) + 1 )

                     -- Close pallet if single SKU pallet and QTYExpected = QTY received
                     IF @cClosePallet = '2'
                     BEGIN
                        IF EXISTS( SELECT 1
                           FROM dbo.ReceiptDetail WITH (NOLOCK)
                           WHERE ReceiptKey = @cReceiptKey
                              AND ToID = @cToID
                           GROUP BY SKU
                           HAVING COUNT( DISTINCT SKU) = 1                       -- Single SKU pallet
                              AND SUM( QTYExpected) = SUM( BeforeReceivedQTY))   -- SKU fully received
                        BEGIN
                           -- Go to close pallet screen
                           SET @cOutField01 = '' --Option
                           SET @cOutField02 = '' -- Count UCC
                           SET @nAfterScn  = @nStep_6_Scn + 6 -- @nScn + 6
                           SET @nAfterStep = @nStep_6 + 6      --@nStep + 6
                           EXEC rdt.rdtSetFocusField @nMobile, 1 --Option

                           IF @cClosePalletCountUCC <> '1'
                              SET @cFieldAttr02 = 'O'

                           GOTO Step_99_Quit
                        END
                     END

                     -- Retain in current screen
                     SET @cOutField01 = '' --UCC
                     SET @cOutField11 = RTRIM(CAST( @cCartonCnt AS NVARCHAR( 4))) + CASE WHEN @cSkipEstUCCOnID = '1' THEN '' ELSE '/' + CAST( @cTotalCarton AS NVARCHAR( 4)) END -- (ChewKP01)
                  END
               END

               --(cc01)
               IF @cUCCLabel <> ''
               BEGIN
                  -- Common params
                  DECLARE @tUCCLabel AS VariableTable
                  INSERT INTO @tUCCLabel (Variable, Value) VALUES ( '@cUCCNo', @cUCC)

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, @cPaperPrinter,
                     @cUCCLabel, -- Report type
                     @tUCCLabel, -- Report params
                     'rdtfnc_UCCReceive',
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     GOTO Step_99_Quit
                  END
               END
            END

            IF @nInputKey = 0 -- Esc
            BEGIN
               --ucc count < estimated ucc
               IF CAST(@cCartonCnt AS INT) < CAST(@cTotalCarton AS INT) AND @cSkipEstUCCOnID <> '1'
               BEGIN
                  --prepare next screen
                  SET @cOutField01 = '' --option

                  -- Go to "Not all UCC received. Escape anyway?" screen
                  SET @nAfterScn = @nStep_6_Scn + 5
                  SET @nAfterStep = @nStep_6 + 5

                  GOTO Step_99_Quit
               END

               -- Prepare prev screen var
               SET @cOutField01 = @cTempLottable01
               SET @cOutField02 = @cTempLottable02
               SET @cOutField03 = @cTempLottable03
               SET @cOutField04 = @cTempLottable04

               -- Enable / disable field
               IF @cSkipLottable01 = '1' SELECT @cFieldAttr01 = 'O', @cInField01 = ''
               IF @cSkipLottable02 = '1' SELECT @cFieldAttr02 = 'O', @cInField02 = ''
               IF @cSkipLottable03 = '1' SELECT @cFieldAttr03 = 'O', @cInField03 = ''
               IF @cSkipLottable04 = '1' SELECT @cFieldAttr04 = 'O', @cInField04 = ''

               -- Go to lottable screen
               SET @nAfterScn = @nStep_6_Scn - 1
               SET @nAfterStep = @nStep_6 - 1

               IF @cSkipLottable01 = '1' AND @cSkipLottable02 = '1' AND @cSkipLottable03 = '1' AND @cSkipLottable04 = '1'
               BEGIN
                  -- Enable field
                  SET @cFieldAttr01 = ''
                  SET @cFieldAttr02 = ''
                  SET @cFieldAttr03 = ''
                  SET @cFieldAttr04 = ''

                  IF @cSkipEstUCCOnID = '1'
                     SET @cFieldAttr05 = 'O'

                  -- Prepare prev screen var
                  SET @cOutField01 = @cReceiptKey
                  SET @cOutField02 = @cPOKey
                  SET @cOutField03 = @cLOC
                  SET @cOutField04 = @cTOID
                  SET @cOutField05 = @cTotalCarton

                  -- Go to estimate UCC on ID screen
                  SET @nAfterScn = @nAfterScn - 1
                  SET @nAfterStep = @nAfterStep - 1
               END
            END

            Step_99_Quit:
            BEGIN
               -- Extended info
               IF @cExtendedInfoSP <> ''
               BEGIN
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
                  BEGIN
                     SET @cOutField15 = ''
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                        '  @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04 ' +
                        ' ,@cUCC, @cSKU, @nQTY, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption, @cExtendedInfo OUTPUT ' +
                        ' ,@nErrNo   OUTPUT ' +
                        ' ,@cErrMsg  OUTPUT '
                     SET @cSQLParam = +
                        '  @nMobile       INT           ' +
                        ' ,@nFunc         INT           ' +
                        ' ,@cLangCode     NVARCHAR(  3) ' +
                        ' ,@nStep         INT           ' +
                        ' ,@nAfterStep    INT           ' +
                        ' ,@nInputKey     INT           ' +
                        ' ,@cReceiptKey   NVARCHAR( 10) ' +
                        ' ,@cPOKey        NVARCHAR( 10) ' +
                        ' ,@cLOC          NVARCHAR( 10) ' +
                        ' ,@cToID         NVARCHAR( 18) ' +
                        ' ,@cLottable01   NVARCHAR( 18) ' +
                        ' ,@cLottable02   NVARCHAR( 18) ' +
                        ' ,@cLottable03   NVARCHAR( 18) ' +
                        ' ,@dLottable04   DATETIME      ' +
                        ' ,@cUCC          NVARCHAR( 20) ' +
                        ' ,@cSKU          NVARCHAR( 20) ' +
                        ' ,@nQTY          INT           ' +
                        ' ,@cParam1       NVARCHAR( 20) ' +
                        ' ,@cParam2       NVARCHAR( 20) ' +
                        ' ,@cParam3       NVARCHAR( 20) ' +
                        ' ,@cParam4       NVARCHAR( 20) ' +
                        ' ,@cParam5       NVARCHAR( 20) ' +
                        ' ,@cOption       NVARCHAR( 1)  ' +
                        ' ,@cExtendedInfo NVARCHAR(20)  OUTPUT ' +
                        ' ,@nErrNo        INT           OUTPUT ' +
                        ' ,@cErrMsg       NVARCHAR( 20) OUTPUT '
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                        @nMobile, @nFunc, @cLangCode, 99, @nAfterStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04
                        ,@cUCC, @cSKU, @nQTY, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption, @cExtendedInfo OUTPUT
                        ,@nErrNo   OUTPUT
                        ,@cErrMsg  OUTPUT

                     SET @cOutField15 = @cExtendedInfo
                  END
               END
               SET @cUDF02 = CAST(@nQTY AS NVARCHAR(10))
               SET @cUDF03 = CAST(@nCaseCntQty AS NVARCHAR(10))
               SET @cUDF04 = CAST(@nCnt AS NVARCHAR(10))
               SET @cUDF05 = @cReceiveAllowAddNewUCC
            END

            GOTO Quit

            Step_99_Fail:
            BEGIN
               SET @cUCC = ''
               SET @cOutField01 = ''
               SET @cUDF01 = ''
            END
            --===================================End====================================================
         END
      END
      ELSE IF @nStep = 10
      BEGIN 
         IF @nInputKey = 1
         BEGIN
            --set @cPokey value to blank when it is 'NOPO'
            SET @cPOKeyValue = CASE WHEN UPPER(@cPOkey) = 'NOPO' THEN '' ELSE @cPOkey END

            --set @cPOKeyDefaultValue to 1 when it is 'NOPO'
            SET @cPOKeyDefaultValue = CASE WHEN UPPER(@cPOkey) = 'NOPO' THEN '1' ELSE '0' END

            --set @cTempAddNewUCC to 1 when it is allowed to add new ucc
            SET @cTempAddNewUCC = CASE WHEN @cReceiveAllowAddNewUCC in ('1','2') THEN '1' ELSE '0' END

            --set @cTempUCC to blank when it is 'NOUCC'
            SET @cTempUCC = CASE WHEN UPPER(RTRIM(@cUCC)) = 'NOUCC' THEN '' ELSE @cUCC END

            IF @cUCC = 'NOUCC'
            BEGIN
               --update transaction
               SET @dTempLottable09 = rdt.rdtConvertToDate(@cOutField09)            --for UWP-25017
               EXEC rdt.rdt_UCCReceive_Confirm
               @nFunc         = @nFunc,
               @nMobile       = @nMobile,
               @cLangCode     = @cLangCode,
               @nErrNo        = @nErrNo OUTPUT,
               @cErrMsg       = @cErrMsg OUTPUT,
               @cStorerKey    = @cStorerKey,
               @cFacility     = @cFacility,
               @cReceiptKey   = @cReceiptKey,
               @cPOKey        = @cPoKeyValue,
               @cToLOC        = @cLOC,
               @cToID         = @cTOID,
               @cSKUCode      = @cSku,
               @cSKUUOM       = @cUOM,
               @nSKUQTY       = @nQTY,
               @cUCC          = '',
               @cUCCSKU       = '',
               @nUCCQTY       = '',
               @cCreateUCC    = @cTempAddNewUCC,
               @cLottable01   = @cOutField06,
               @cLottable02   = @cOutField07,
               @cLottable03   = @cOutField08,
               @dLottable04   = @dTempLottable09,                 --@cOutField09,  --for UWP-25017
               @dLottable05   = NULL,
               @nNOPOFlag     = @cPOKeyDefaultValue,
               @cConditionCode = 'OK',
               @cSubreasonCode = ''
            END
            ELSE IF @cUCC <> '' AND @cUCC <> 'NOUCC'
            BEGIN
               --update transaction
               SET @dTempLottable09 = rdt.rdtConvertToDate(@cOutField09)            --for UWP-25017
               EXEC rdt.rdt_UCCReceive_Confirm
                  @nFunc         = @nFunc,
                  @nMobile       = @nMobile,
                  @cLangCode     = @cLangCode,
                  @nErrNo        = @nErrNo OUTPUT,
                  @cErrMsg       = @cErrMsg OUTPUT,
                  @cStorerKey    = @cStorerKey,
                  @cFacility     = @cFacility,
                  @cReceiptKey   = @cReceiptKey,
                  @cPOKey        = @cPoKeyValue,
                  @cToLOC        = @cLOC,
                  @cToID         = @cTOID,
                  @cSKUCode      = '',
                  @cSKUUOM       = '',
                  @nSKUQTY       = '',
                  @cUCC          = @cUCC,
                  @cUCCSKU       = @cSKU,
                  @nUCCQTY       = @nQTY,
                  @cCreateUCC    = @cTempAddNewUCC,
                  @cLottable01   = @cOutField06,
                  @cLottable02   = @cOutField07,
                  @cLottable03   = @cOutField08,
                  @dLottable04   = @dTempLottable09,              -- @cOutField09,  --for UWP-25017
                  @dLottable05   = NULL,
                  @nNOPOFlag     = @cPOKeyDefaultValue,
                  @cConditionCode = 'OK',
                  @cSubreasonCode = ''
            END
            IF @nErrno <> '' or @cErrMsg <> ''
               GOTO Step_10_Fail

            SELECT @cReceiptLineNumber=receiptlinenumber
            FROM receiptdetail (NOLOCK)
            where receiptkey=@cReceiptKey
               AND SKU=@cSKU
            ORDER BY EDITDATE DESC;

            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '2', -- Receiving
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerkey,
               @cReceiptKey   = @cReceiptKey,
               @cPOKey        = @cPoKeyValue,
               @cLocation     = @cLOC,
               @cID           = @cTOID,
               @cSKU          = @cSku,
               @cUOM          = @cUOM,
               @nQTY          = @nQTY,
               @cUCC          = @cUCC,
               @cRefNo2       = @cReceiptLineNumber

            --prepare next screen var
            SET @cOutField01 = ''

            --increase carton count by one if it is not loose qty
            IF UPPER(@cUCC) <> 'NOUCC'
               SET @cCartonCnt = Convert(char,Cast( @cCartonCnt as Int) + 1 )

            SET @cOutField11 = RTRIM(CAST( @cCartonCnt AS NVARCHAR( 4))) + CASE WHEN @cSkipEstUCCOnID = '1' THEN '' ELSE '/' + CAST( @cTotalCarton AS NVARCHAR( 4)) END -- (ChewKP02)

            SET @cUDF01 = @cCartonCnt

            --go to UCC screen
            SET @cOutField10 = ''
            SET @nAfterScn = @nStep_6_Scn
            SET @nAfterStep = @nStep_99
         END

         --v1.0.1 Start
         Step_10_Quit:
         -- Extended info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cOutField15 = ''
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  '  @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04 ' +
                  ' ,@cUCC, @cSKU, @nQTY, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption, @cExtendedInfo OUTPUT ' +
                  ' ,@nErrNo   OUTPUT ' +
                  ' ,@cErrMsg  OUTPUT '
               SET @cSQLParam = +
                  '  @nMobile       INT           ' +
                  ' ,@nFunc         INT           ' +
                  ' ,@cLangCode     NVARCHAR(  3) ' +
                  ' ,@nStep         INT           ' +
                  ' ,@nAfterStep    INT           ' +
                  ' ,@nInputKey     INT           ' +
                  ' ,@cReceiptKey   NVARCHAR( 10) ' +
                  ' ,@cPOKey        NVARCHAR( 10) ' +
                  ' ,@cLOC          NVARCHAR( 10) ' +
                  ' ,@cToID         NVARCHAR( 18) ' +
                  ' ,@cLottable01   NVARCHAR( 18) ' +
                  ' ,@cLottable02   NVARCHAR( 18) ' +
                  ' ,@cLottable03   NVARCHAR( 18) ' +
                  ' ,@dLottable04   DATETIME      ' +
                  ' ,@cUCC          NVARCHAR( 20) ' +
                  ' ,@cSKU          NVARCHAR( 20) ' +
                  ' ,@nQTY          INT           ' +
                  ' ,@cParam1       NVARCHAR( 20) ' +
                  ' ,@cParam2       NVARCHAR( 20) ' +
                  ' ,@cParam3       NVARCHAR( 20) ' +
                  ' ,@cParam4       NVARCHAR( 20) ' +
                  ' ,@cParam5       NVARCHAR( 20) ' +
                  ' ,@cOption       NVARCHAR( 1)  ' +
                  ' ,@cExtendedInfo NVARCHAR(20)  OUTPUT ' +
                  ' ,@nErrNo        INT           OUTPUT ' +
                  ' ,@cErrMsg       NVARCHAR( 20) OUTPUT '
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, 10, @nAfterStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04
                  ,@cUCC, @cSKU, @nQTY, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption, @cExtendedInfo OUTPUT
                  ,@nErrNo   OUTPUT
                  ,@cErrMsg  OUTPUT

               SET @cOutField15 = @cExtendedInfo
            END
         END
         --v1.0.1 End

         GOTO Quit

         Step_10_Fail:
         BEGIN
            SET @nAfterScn = @nScn - 1
            SET @nAfterStep = @nStep - 1
         END
      END
   END

   Quit:
END

GO