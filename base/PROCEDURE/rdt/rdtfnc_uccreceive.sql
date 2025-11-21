SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdtfnc_UCCReceive                                      */
/* Copyright      : IDS                                                    */
/*                                                                         */
/* Purpose: UCC Receive                                                    */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2007-05-29 1.0  FKLIM   Created                                         */
/* 2007-12-06 1.1  Vicky   SOS#81879 - Add generic Lottable_Wrapper        */
/* 2008-09-22 1.2  Vicky   SOS#105011 - Add in checking for not            */
/*                         mactched UCC vs PO (Vicky01)                    */
/*                         - Skip prompting Multi SKU/UCC error msg        */
/*                         if configkey "SkipCheckMultiUCC" = 1 (Vicky02)  */
/* 2009-07-06 1.3  Vicky   Add in EventLog (Vicky06)                       */
/* 2012-09-12 1.4  Ung     SOS255639.                                      */
/*                         Add UCCWithMultiSKU                             */
/*                         Add Close pallet                                */
/*                         Add UCCExtValidate                              */
/*                         Add SkipLottable01..04                          */
/*                         Add SkipEstUCCOnID                              */
/*                         Add ExtendedUpdateSP                            */
/* 2013-06-11 1.5  Ung     SOS279908                                       */
/*                         Add Param1..5                                   */
/*                         Add DispStyleColorSize                          */
/* 2013-11-21 1.6  ChewKP  TBLSG - Bug Fixed (ChewKP01)                    */
/* 2014-04-24 1.7  Ung     SOS308961 PRE POST codelkup with StorerKey      */
/* 2013-11-15 1.8  ChewKP  SOS292682 Allow DocType = 'R' (ChewKP02)        */
/* 2014-08-20 1.9  Ung     Performance tuning for multi SKU UCC            */
/* 2015-02-12 2.0  Ung     SOS333395 Add ExtendedValidateSP                */
/* 2015-01-15 2.1  CSCHONG New lottable 05 to 15 (CS01)                    */
/* 2015-05-25 2.2  CSCHONG Remove rdt_receive lottable06-15 parm (CS02)    */
/* 2015-06-21 2.3  Ung     SOS341986 Add piece scanning                    */
/* 2015-08-28 2.4  Ung     SOS345120 Add ExtendedInfoSP                    */
/* 2016-02-26 2.5  Ung     SOS358802 Add IsValidFormat for ID field        */
/* 2016-09-02 2.6  ChewKP  SOS#375818 Add rdtIsValidFormat (ChewKP03)      */
/* 2016-09-30 2.7  Ung     Performance tuning                              */
/* 2017-01-24 2.8  Ung     Fix recompile due to date format different      */
/* 2017-04-19 2.9  Ung     SOS372561 Add ReceiptConfirm_SP                 */
/* 2018-10-01 3.0  TungGH  Performance                                     */
/* 2019-05-03 3.1  James   WMS7987-Add ExtendedValidateSP @ step3 (james01)*/
/* 2019-07-05 3.2  Ung     Fix performance tuning                          */
/* 2020-01-22 3.3  Ung     LWP-57 Performance tuning                       */
/* 2021-06-02 3.4  Chermai WMS-17109 Add print label at step1 (cc01)       */
/* 2022-04-12 3.5  James   WMS-19453 Add RDTFormat for UCC scan (james02)  */
/* 2021-12-06 3.6  YeeKung WMS-18390 Add Multi UCC status (yeekung01)      */
/* 2021-10-15 3.7  yeekung  WMS-19671 Add eventlog refno2(yeekung02)       */
/* 2022-09-08 3.8  yeekung  WMS-20650 Add extendeinfo instep3(yeekung03)   */
/* 2020-05-04 3.9  YeeKung WMS-11867 Add verifySKU (yeekung01)            */
/* 2022-04-12 4.0  James   WMS-22928 Add RDTFormat for UCC Qty (james03)   */
/* 2023-12-04 4.1  Ung     WMS-24276 Add DecodeSP                          */
/* 2024-01-16 4.2  James   WMS-24545 Add ExtValidSP @ step 8 (james04)     */
/* 2024-01-18 4.3  YeeKung WMS-24503 Skip Step_10 (yeekung04)              */
/* 2024-02-21 4.4  YeeKung WMS-24854 Add ExtValidSP @ Step 5 (yeekung05)   */
/* 2024-06-18 4.5  Ung     WMS-25618 Fix ExtInfoSP @nStep at step 8        */
/* 2024-10-01 4.6  Ung     WMS-26411 Add ExtendedScreenSP                  */
/*                         Add standard DecodeSP for UCCNo                 */
/* 2024-09-11 4.7  Ung     WMS-26203 Add new UCC with UCCWithMultiSKU      */
/* 2024-06-18 4.8  CYU027  UWP-20900 bugfix for NOPO check                 */
/* 2024-09-30 4.9  YYS027  UWP-25017 bugfix for string(dmy) to date when   */
/*                         calling rdt_UCCReceive_Confirm                  */
/* 2024-10-14 5.0  CYU027  FCR-759 ID and UCC Length Issue                 */
/* 2024-11-07 5.1  YYS027   Merged from 4.6(v0) and 4.3(V2) to 4.7(V2)      */
/* 2024-12-05 5.2  ShaoAn  FCR-1103 Changes in UCC Receive to process      */
/***************************************************************************/
CREATE   PROC [RDT].[rdtfnc_UCCReceive](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS
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
   @cSQL                            NVARCHAR(MAX),
   @cSQLParam                       NVARCHAR(MAX),
   @cParam1                         NVARCHAR(20),
   @cParam2                         NVARCHAR(20),
   @cParam3                         NVARCHAR(20),
   @cParam4                         NVARCHAR(20),
   @cParam5                         NVARCHAR(20)

-- Define a variable
DECLARE
   @nFunc         INT,
   @nScn          INT,
   @nStep         INT,
   @cLangCode     NVARCHAR(3),
   @nMenu         INT,
   @nInputKey     NVARCHAR(3),

   @cStorerKey    NVARCHAR(15),
   @cFacility     NVARCHAR(5),
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
   @cUCC                 NVARCHAR(20),
   @cDesc                NVARCHAR(60),
   @nQTY                 INT,
   @cPackKey             NVARCHAR(10),
   @cPQIndicator         NVARCHAR(10),
   @cPPK                 NVARCHAR(30),
   @nCaseCntQty          INT,
   @nCnt                 INT,
  	@nFromScn             INT, --(yeekung01)
  	@nNewUCCWithMultiSKURcv INT, -- To detect received new UCC with multi SKU UCC
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
   @cFlowThruScreen      NVARCHAR( 1), --(yeekung04)
   @cExtScnSP            NVARCHAR(20),            -- change from ExtendedScreenSP to ExtScnSP (yys027 migrate-crocs-FCR-1126)
   @tExtScnData          VariableTable,           -- for support ExtScnSP
   @nAction              INT,

   @cLottable01       NVARCHAR(18),
   @cLottable02       NVARCHAR(18),
   @cLottable03       NVARCHAR(18),
   @dLottable04       DATETIME,
   @dLottable05       DATETIME,

   /*CS01 Start*/

   @cLottable06       NVARCHAR(30),
   @cLottable07       NVARCHAR(30),
   @cLottable08       NVARCHAR(30),
   @cLottable09       NVARCHAR(30),
   @cLottable10       NVARCHAR(30),
   @cLottable11       NVARCHAR(30),
   @cLottable12       NVARCHAR(30),
   @dLottable13       DATETIME,
   @dLottable14       DATETIME,
   @dLottable15       DATETIME,

   /*CS01 End*/

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
   @cUserDefine01      NVARCHAR(30), -- FCR759
   @cUserDefine02      NVARCHAR(30), -- FCR759
   @cUserDefine03      NVARCHAR(30), -- FCR759
   @cUserDefine04      NVARCHAR(30), -- FCR759
   @cUserDefine05      NVARCHAR(30), -- FCR759
   @cUserDefine06      NVARCHAR(30), -- FCR759
   @cUserDefine07      NVARCHAR(30), -- FCR759
   @cUserDefine08      NVARCHAR(30), -- FCR759
   @cUserDefine09      NVARCHAR(30), -- FCR759

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

   @cUDF01  NVARCHAR( 250), @cUDF02 NVARCHAR( 250), @cUDF03 NVARCHAR( 250),
   @cUDF04  NVARCHAR( 250), @cUDF05 NVARCHAR( 250), @cUDF06 NVARCHAR( 250),
   @cUDF07  NVARCHAR( 250), @cUDF08 NVARCHAR( 250), @cUDF09 NVARCHAR( 250),
   @cUDF10  NVARCHAR( 250), @cUDF11 NVARCHAR( 250), @cUDF12 NVARCHAR( 250),
   @cUDF13  NVARCHAR( 250), @cUDF14 NVARCHAR( 250), @cUDF15 NVARCHAR( 250),
   @cUDF16  NVARCHAR( 250), @cUDF17 NVARCHAR( 250), @cUDF18 NVARCHAR( 250),
   @cUDF19  NVARCHAR( 250), @cUDF20 NVARCHAR( 250), @cUDF21 NVARCHAR( 250),
   @cUDF22  NVARCHAR( 250), @cUDF23 NVARCHAR( 250), @cUDF24 NVARCHAR( 250),
   @cUDF25  NVARCHAR( 250), @cUDF26 NVARCHAR( 250), @cUDF27 NVARCHAR( 250),
   @cUDF28  NVARCHAR( 250), @cUDF29 NVARCHAR( 250), @cUDF30 NVARCHAR( MAX)

-- Getting Mobile information
SELECT
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @cLangCode   = Lang_code,
   @nMenu       = Menu,

   @cFacility   = Facility,
   @cStorerKey  = StorerKey,
   @cUserName   = UserName,-- (Vicky06)
   @cPaperPrinter = Printer_Paper,   --(cc01)
   @cLabelPrinter = Printer,  --(cc01)

   @cPOKeyDefaultValue = V_String1,

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
   @cUserDefine08          = V_String38, -- FCR-759
   @cUserDefine09          = V_String39, -- FCR-759
   @cFlowThruScreen        = V_String40,
   @cExtScnSP      = V_String41,

   @nQTY             = V_Integer1,
   @nCaseCntQty      = V_Integer2,
   @nCnt             = V_Integer3,
  	@nFromScn         = V_Integer4,

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

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE  Mobile = @nMobile

SET  @nAction=0
-- Redirect to respective screen
IF @nFunc = 898 -- UCC receive
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 898
   IF @nStep = 1 GOTO Step_1   -- Scn = 1300   ASN, PO
   IF @nStep = 2 GOTO Step_2   -- Scn = 1301   TO LOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 1302   TO ID
   IF @nStep = 4 GOTO Step_4   -- Scn = 1303   ESTIMATED UCC ON ID
   IF @nStep = 5 GOTO Step_5   -- Scn = 1304   Lottable01..5
   IF @nStep = 6 GOTO Step_6   -- Scn = 1305   UCC
   IF @nStep = 7 GOTO Step_7   -- Scn = 1306   CREATE NEW UCC?
   IF @nStep = 8 GOTO Step_8   -- Scn = 1307   SKU/UPC
   IF @nStep = 9 GOTO Step_9   -- Scn = 1308   QTY
   IF @nStep =10 GOTO Step_10  -- Scn = 1309   Extra data info
   IF @nStep =11 GOTO Step_11  -- Scn = 1310   Message. Not all ucc received. ESC anyway?
   IF @nStep =12 GOTO Step_12  -- Scn = 1311   Message. Close pallet?
   IF @nStep =13 GOTO Step_13  -- Scn = 3950   Verify SKU
   IF @nStep =99 GOTO Step_99  -- Scn = Customizate screen
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 898)
********************************************************************************/
Step_0:
BEGIN
   --get POKey as 'NOPO' if storerconfig has been setup for 'ReceivingPOKeyDefaultValue'
   SET @cPOKeyDefaultValue = ''
   SET @cPOKeyDefaultValue = rdt.RDTGetConfig( 0, 'ReceivingPOKeyDefaultValue', @cStorerKey)

   IF (@cPOKeyDefaultValue = '0' OR @cPOKeyDefaultValue IS NULL OR @cPOKeyDefaultValue = '')
      SET @cOutField02 = ''
   ELSE
      SET @cOutField02 = @cPOKeyDefaultValue

   SET @cMultiUCC = rdt.RDTGetConfig( @nFunc, 'multiUCC', @cStorerKey)

   SET @cSkipEstUCCOnID = rdt.RDTGetConfig( @nFunc, 'SkipEstUCCOnID', @cStorerKey)
   SET @cSkipLottable01 = rdt.RDTGetConfig( @nFunc, 'SkipLottable01', @cStorerKey)
   SET @cSkipLottable02 = rdt.RDTGetConfig( @nFunc, 'SkipLottable02', @cStorerKey)
   SET @cSkipLottable03 = rdt.RDTGetConfig( @nFunc, 'SkipLottable03', @cStorerKey)
   SET @cSkipLottable04 = rdt.RDTGetConfig( @nFunc, 'SkipLottable04', @cStorerKey)
   SET @cClosePallet = rdt.RDTGetConfig( @nFunc, 'ClosePallet', @cStorerKey)
   SET @cDisableQTYField = rdt.RDTGetConfig( @nFunc, 'DisableQTYField', @cStorerKey)
   SET @cDispStyleColorSize = rdt.RDTGetConfig( @nFunc, 'DispStyleColorSize', @cStorerKey)
   SET @cClosePalletCountUCC = rdt.RDTGetConfig( @nFunc, 'ClosePalletCountUCC', @cStorerKey)
   SET @cUCCExtValidate = rdt.RDTGetConfig( @nFunc, 'UCCExtValidate', @cStorerKey)
   IF @cUCCExtValidate = '0'
      SET @cUCCExtValidate = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtScnSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey) -- change from ExtendedScreenSP to ExtScnSP (yys027 migrate-1126)
   IF @cExtScnSP = '0'
      SET @cExtScnSP = ''

   SET @cFlowThruScreen = rdt.RDTGetConfig( @nFunc, 'FlowThruScreen', @cStorerKey)

   --(cc01)
   SET @cUCCLabel = rdt.rdtGetConfig( @nFunc, 'UCCLabel', @cStorerKey)
   IF @cUCCLabel = '0'
      SET @cUCCLabel = ''

	SET @cVerifySKU = rdt.RDTGetConfig( @nFunc, 'VerifySKU', @cStorerKey)


   SET @cDecodeSP  = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey) --(yeekung01)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   SET @cDecodeQty = rdt.RDTGetConfig( @nFunc, 'DecodeQty', @cStorerKey) --(yeekung01)

   -- Added by Vicky for SOS#105011 (Start - Vicky01)
   SET @cCheckPOUCC = ''

   SELECT @cCheckPOUCC = ISNULL(RTRIM(sValue), '0')
   FROM RDT.Storerconfig WITH (NOLOCK)
   WHERE Storerkey = @cStorerKey
   AND Configkey = 'CheckPOUCC'
   -- Added by Vicky for SOS#105011 (End - Vicky01)

   SET @cUCCWithMultiSKU = rdt.RDTGetConfig( @nFunc, 'UCCWithMultiSKU', @cStorerKey)

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey

   -- Enable all fields
   SET @cFieldAttr01 = ''
   SET @cFieldAttr02 = ''
   SET @cFieldAttr03 = ''
   SET @cFieldAttr04 = ''
   SET @cFieldAttr05 = ''
   SET @cFieldAttr06 = ''
   SET @cFieldAttr07 = ''
   SET @cFieldAttr08 = ''
   SET @cFieldAttr09 = ''
   SET @cFieldAttr10 = ''
   SET @cFieldAttr11 = ''
   SET @cFieldAttr12 = ''
   SET @cFieldAttr13 = ''
   SET @cFieldAttr14 = ''
   SET @cFieldAttr15 = ''

   -- Set the entry point
   SET @nScn  = 1300
   SET @nStep = 1

   -- Init var
   SET @nCaseCntQty =0
   SET @nCnt = 0

   -- initialise all variable
   SET @cReceiptKey = ''
   SET @cPOKey= ''

   -- Prep next screen var
   SET @cOutField01 = '' -- ReceiptKey
END
GOTO Quit


/********************************************************************************
Step 1. screen = 1300
   ASN (Field01, input)
   PO  (Field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
       --to remove 'NOPO' as default to outfield02
      IF UPPER(@cInField02) <> 'NOPO'
      BEGIN
         SET @cPOKey = ''
         SET @cOutField02=''
      END

      -- Screen mapping
      SET @cReceiptKey = @cInField01
      SET @cPOKey = @cInField02

      --When both ASN and PO is blank
      IF @cReceiptKey = '' AND  @cPOkey = ''
      BEGIN
         SET @nErrNo = 63116
         SET @cErrMsg = rdt.rdtgetmessage( 63116, @cLangCode, 'DSP') --ASN or PO req
         GOTO Step_1_Fail
      END

      IF @cReceiptKey = '' AND UPPER(@cPOKey) ='NOPO'
      BEGIN
         SET @nErrNo = 63165
         SET @cErrMsg = rdt.rdtgetmessage( 63165, @cLangCode, 'DSP') --ASN needed
         GOTO Step_1_Fail
      END

      -- when both ASN and PO key in, check if the ASN and PO exists
      IF @cReceiptKey <> '' AND @cPOKey <> '' AND  UPPER(@cPOKey) <> 'NOPO'
      BEGIN
         IF NOT EXISTS (SELECT 1
            FROM dbo.Receipt R WITH (NOLOCK)
               JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
            WHERE R.ReceiptKey = @cReceiptkey
               AND RD.POKey = @cPOKey)
         BEGIN
            SET @nErrNo = 63117
            SET @cErrMsg = rdt.rdtgetmessage( 63117, @cLangCode, 'DSP') --Invalid ASN/PO
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
            GOTO Quit
         END
      END

       --When only PO keyed-in (ASN left as blank)
      IF @cPOKey <> '' AND UPPER(@cPOKey) <> 'NOPO' AND @cReceiptkey  = ''
      BEGIN
         IF NOT EXISTS (SELECT 1
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE POkey = @cPOKey)
         BEGIN
            SET @nErrNo = 63120
            SET @cErrMsg = rdt.rdtgetmessage( 63120, @cLangCode, 'DSP') --PO not exists
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- POKey
            GOTO Step_1_Fail
         END

         DECLARE @nCountReceipt int
         SET @nCountReceipt = 0

         --get ReceiptKey count
         SELECT @nCountReceipt = COUNT(DISTINCT Receiptkey)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE POKey = @cPOKey
         GROUP BY POkey

         IF @nCountReceipt = 1
         BEGIN
            --get single ReceiptKey
            SELECT @cReceiptKey = ReceiptKey
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE POkey = @cPOKey
            GROUP BY ReceiptKey
         END
         ELSE IF @nCountReceipt > 1
         BEGIN
            SET @nErrNo = 63121
            SET @cErrMsg = rdt.rdtgetmessage( 63121, @cLangCode, 'DSP') --ASN needed
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
            GOTO Step_1_Fail
         END
      END

      --check if receiptkey exists
      IF NOT EXISTS (SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptkey)
      BEGIN
         SET @nErrNo = 63118
         SET @cErrMsg = rdt.rdtgetmessage( 63118, @cLangCode, 'DSP') --ASN not exists
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail
      END

      --check diff facility
      IF NOT EXISTS ( SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND Facility = @cFacility)
      BEGIN
         SET @nErrNo = 63122
         SET @cErrMsg = rdt.rdtgetmessage( 63122, @cLangCode, 'DSP') --Diff facility
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail
      END

      --check diff storer
      IF NOT EXISTS ( SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND Storerkey = @cStorerkey)
      BEGIN
         SET @nErrNo = 63123
         SET @cErrMsg = rdt.rdtgetmessage( 63123, @cLangCode, 'DSP') --Diff storer
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail
      END

      --check for TradeReturnASN
-- (ChewKP02)
--      IF EXISTS ( SELECT 1
--         FROM dbo.Receipt WITH (NOLOCK)
--         WHERE Receiptkey = @cReceiptkey
--            AND DocType = 'R')
--      BEGIN
--         SET @nErrNo = 63124
--         SET @cErrMsg = rdt.rdtgetmessage( 63124, @cLangCode, 'DSP') --TradeReturnASN
--         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
--         GOTO Step_1_Fail
--      END

/*
      --check for ASN closed by receipt.status
      IF EXISTS ( SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND Status = '9')
      BEGIN
         SET @nErrNo = 63125
         SET @cErrMsg = rdt.rdtgetmessage( 63125, @cLangCode, 'DSP') --ASN closed
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail
      END
*/
      --check for ASN closed by receipt.ASNStatus
      IF EXISTS ( SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND ASNStatus = '9' )
      BEGIN
         SET @nErrNo = 63126
         SET @cErrMsg = rdt.rdtgetmessage( 63126, @cLangCode, 'DSP') --ASN closed
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail
      END

      --check for ASN cancelled
      IF EXISTS ( SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND ASNStatus = 'CANC')
      BEGIN
         SET @nErrNo = 63127
         SET @cErrMsg = rdt.rdtgetmessage( 63127, @cLangCode, 'DSP') --ASN cancelled
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail
      END

      --When only ASN keyed-in (PO left as blank or NOPO): --retrieve single PO if there is
      IF @cReceiptKey <> '' AND (@cPOKey = '' OR UPPER(@cPOKey) = 'NOPO')
      BEGIN
         DECLARE @nCountPOKey int
         SET @nCountPOKey = 0

         --get pokey count
         SELECT @nCountPOKey = count(distinct POKey)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptkey
         GROUP BY Receiptkey

         IF @nCountPOKey = 1
         BEGIN
            IF UPPER(@cPOKey) <> 'NOPO'
            BEGIN
               --get single pokey
               SELECT @cPOKey = POKey
               FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptkey
               GROUP BY POkey
            END
         END
         ELSE IF @nCountPOKey > 1
         BEGIN
            --receive against blank PO
            IF EXISTS ( SELECT 1
                        FROM dbo.ReceiptDetail WITH (NOLOCK)
                        WHERE ReceiptKey = @cReceiptkey
                           AND (POKey IS NULL or POKey = ''))
            BEGIN
            IF UPPER(@cPOKey) <> 'NOPO'
               SET @cPOKey = ''
            END
            ELSE
            BEGIN
               IF UPPER(@cPOKey) <> 'NOPO'
               BEGIN
                  SET @nErrNo = 63119
                  SET @cErrMsg = rdt.rdtgetmessage( 63119, @cLangCode, 'DSP') --PO needed
                  SET @cOutField01 = @cReceiptKey
                  EXEC rdt.rdtSetFocusField @nMobile, 2 -- POKey
                  GOTO Quit
               END
            END
         END
--         ELSE IF @nCountPOKey > 2
--         BEGIN
--            --multiple PO
--            IF UPPER(@cPOKey) <> 'NOPO'
--            BEGIN
--               SET @nErrNo = 63119
--               SET @cErrMsg = rdt.rdtgetmessage( 63119, @cLangCode, 'DSP') --PO needed
--               SET @cOutField01 = @cReceiptKey
--               EXEC rdt.rdtSetFocusField @nMobile, 2 -- POKey
--               GOTO Quit
--            END
--         END
      END

      -- Get receive DefaultToLoc
      SET @cLOC = rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorerKey)
      IF @cLOC = '0'
         SET @cLOC = ''

      -- Extended validate SP
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               '  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04 ' +
               ' ,@cUCC, @cSKU, @nQTY, @cParam1 OUTPUT, @cParam2 OUTPUT, @cParam3 OUTPUT, @cParam4 OUTPUT, @cParam5 OUTPUT, @cOption ' +
               ' ,@nErrNo   OUTPUT ' +
               ' ,@cErrMsg  OUTPUT '
            SET @cSQLParam = +
               '  @nMobile     INT       ' +
               ' ,@nFunc       INT       ' +
               ' ,@cLangCode   NVARCHAR(  3) ' +
               ' ,@nStep       INT       ' +
               ' ,@nInputKey   INT       ' +
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
               ' ,@cParam1     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam2     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam3     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam4     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam5     NVARCHAR( 20) OUTPUT ' +
               ' ,@cOption     NVARCHAR( 1)  ' +
               ' ,@nErrNo      INT       OUTPUT ' +
               ' ,@cErrMsg     NVARCHAR( 20) OUTPUT '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04
               ,@cUCC, @cSKU, @nQTY, @cParam1 OUTPUT, @cParam2 OUTPUT, @cParam3 OUTPUT, @cParam4 OUTPUT, @cParam5 OUTPUT, @cOption
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END


      --prepare next screen variable
      SET @cOutField01 = @cReceiptkey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cLOC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     -- (Vicky06) EventLog - Sign Out Function
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cReceiptkey = ''
      SET @cOutField01 = '' --ReceiptKey
      SET @cOutField02 = @cPOKey
   END
END
GOTO Quit


/********************************************************************************
Step 2. (screen = 1301) LOC
   ASN:     (Field01)
   PO:      (Field02)
   TO LOC:  (Field03, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      --screen mapping
      SET @cLOC = @cInField03

      --validate blank LOC
      IF @cLOC = '' OR @cLOC IS NULL
      BEGIN
         SET @nErrNo = 63128
         SET @cErrMsg = rdt.rdtgetmessage(63128, @cLangCode, 'DSP') --TO LOC needed
         GOTO Step_2_Fail
      END

      --check for exist of loc in the table
      IF NOT EXISTS ( SELECT 1
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cLOC)
      BEGIN
         SET @nErrNo = 63161
         SET @cErrMsg = rdt.rdtgetmessage(63161, @cLangCode, 'DSP') --LOC not found
         GOTO Step_2_Fail
      END

      --check for diff facility
      IF NOT EXISTS ( SELECT 1
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cLOC
            AND FACILITY = @cFacility)
      BEGIN
         SET @nErrNo = 63129
         SET @cErrMsg = rdt.rdtgetmessage(63129, @cLangCode, 'DSP') --Diff facility
         GOTO Step_2_Fail
      END

      --prepare next screen variable
      SET @cOutField01 = @cReceiptkey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cLOC
      SET @cTOID       = ''
      SET @cOutField04 = '' --TO ID

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = '' -- ReceiptKey
      SET @cOutField02 = @cPOKey
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cLOC = ''
      SET @cOutField03 = '' -- LOC
   END
END
GOTO Quit


/********************************************************************************
Step 3. screen (scn = 1302) TO ID
   ASN:     (field01)
   PO:      (field02)
   TO LOC:  (field03)
   TO ID:   (field04, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      --screen mapping
      SET @cTOID = @cInField04

      --check if TOID is null
      IF @cTOID = '' OR @cTOID IS NULL
      BEGIN
         SET @nErrNo = 63130
         SET @cErrMsg = rdt.rdtgetmessage(63130, @cLangCode, 'DSP') --TO ID needed
         GOTO Step_3_Fail
      END

      -- Check ID format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cTOID) = 0
      BEGIN
         SET @nErrNo = 63164
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_3_Fail
      END

      --check whether allow duplicate pallet id
      SET @cDisAllowDuplicateIdsOnRFRcpt = ''
      EXECUTE dbo.nspGetRight
         NULL, -- Facility
         @cStorerKey,
         @cSKU,
         'DisAllowDuplicateIdsOnRFRcpt',
         @b_success                        OUTPUT,
         @cDisAllowDuplicateIdsOnRFRcpt    OUTPUT,
         @nErrNo                           OUTPUT,
         @cErrMsg                          OUTPUT

      IF @b_success <> 1
      BEGIN
         SET @nErrNo = 63131
         SET @cErrMsg = rdt.rdtgetmessage(63131, @cLangCode, 'DSP') --nspGetRight'
         GOTO Step_3_Fail
      END

      --allow duplicate TOID or not
      IF @cDisAllowDuplicateIdsOnRFRcpt = '1'
      BEGIN
         -- check if TOLOC is valid
         IF EXISTS ( SELECT LLI.ID
            FROM dbo.LotxLocxId LLI WITH (NOLOCK)
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.Loc = LOC.LOC)
               WHERE LLI.ID = @cTOID
               AND LOC.Facility = @cFacility
               AND LLI.QTY > 0)
         BEGIN
            SET @nErrNo = 63132
            SET @cErrMsg = rdt.rdtgetmessage(63132, @cLangCode, 'DSP') --Duplicate ID
            GOTO Step_3_Fail
        END
      END

	  DECLARE @cIDBarcode NVARCHAR(100)
	  SET @cIDBarcode = @cInField04

      -- Decode
      -- Standard decode
      IF @cDecodeSP = '1'
      BEGIN
         EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cIDBarcode,
            @cID     = @cTOID   OUTPUT,
            @nErrNo  = @nErrNo  OUTPUT,
            @cErrMsg = @cErrMsg OUTPUT,
            @cType   = 'ID'

         IF @nErrNo <> 0
            GOTO Step_3_Fail
      END
      ELSE
      BEGIN
         IF @cDecodeSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SELECT @cSKU = '', @nQTY = 0

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                           ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, ' +
                           ' @cUCC        OUTPUT, @nUCCQTY     OUTPUT,' +
                           ' @cUserDefine01 OUTPUT, @cUserDefine02 OUTPUT, @cUserDefine03 OUTPUT, @cUserDefine04 OUTPUT, @cUserDefine05 OUTPUT, ' +
                           ' @cUserDefine06 OUTPUT, @cUserDefine07 OUTPUT, @cUserDefine08 OUTPUT, @cUserDefine09 OUTPUT, ' +
                           ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' +
                           ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' +
                           ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, ' +
                           ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
               SET @cSQLParam =
                       ' @nMobile         INT,                    ' +
                       ' @nFunc           INT,                    ' +
                       ' @cLangCode       NVARCHAR( 3),           ' +
                       ' @nStep           INT,                    ' +
                       ' @nInputKey       INT,                    ' +
                       ' @cStorerKey      NVARCHAR( 15),          ' +
                       ' @cReceiptKey     NVARCHAR( 10),          ' +
                       ' @cPOKey          NVARCHAR( 10),          ' +
                       ' @cLOC            NVARCHAR( 10),          ' +
                       ' @cUCC            NVARCHAR( MAX)  OUTPUT,  ' +
                       ' @nUCCQTY         INT            OUTPUT,  ' +
                       ' @cUserDefine01   NVARCHAR(30)   OUTPUT,  ' +
                       ' @cUserDefine02   NVARCHAR(30)   OUTPUT,  ' +
                       ' @cUserDefine03   NVARCHAR(30)   OUTPUT,  ' +
                       ' @cUserDefine04   NVARCHAR(30)   OUTPUT,  ' +
                       ' @cUserDefine05   NVARCHAR(30)   OUTPUT,  ' +
                       ' @cUserDefine06   NVARCHAR(30)   OUTPUT,  ' +
                       ' @cUserDefine07   NVARCHAR(30)   OUTPUT,  ' +
                       ' @cUserDefine08   NVARCHAR(30)   OUTPUT,  ' +
                       ' @cUserDefine09   NVARCHAR(30)   OUTPUT,  ' +
                       ' @cLottable01     NVARCHAR( 18)  OUTPUT,  ' +
                       ' @cLottable02     NVARCHAR( 18)  OUTPUT,  ' +
                       ' @cLottable03     NVARCHAR( 18)  OUTPUT,  ' +
                       ' @dLottable04     DATETIME       OUTPUT,  ' +
                       ' @dLottable05     DATETIME       OUTPUT,  ' +
                       ' @cLottable06     NVARCHAR( 30)  OUTPUT,  ' +
                       ' @cLottable07     NVARCHAR( 30)  OUTPUT,  ' +
                       ' @cLottable08     NVARCHAR( 30)  OUTPUT,  ' +
                       ' @cLottable09     NVARCHAR( 30)  OUTPUT,  ' +
                       ' @cLottable10     NVARCHAR( 30)  OUTPUT,  ' +
                       ' @cLottable11     NVARCHAR( 30)  OUTPUT,  ' +
                       ' @cLottable12     NVARCHAR( 30)  OUTPUT,  ' +
                       ' @dLottable13     DATETIME       OUTPUT,  ' +
                       ' @dLottable14     DATETIME       OUTPUT,  ' +
                       ' @dLottable15     DATETIME       OUTPUT,  ' +
                       ' @nErrNo          INT            OUTPUT,  ' +
                       ' @cErrMsg         NVARCHAR( 20)  OUTPUT   '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                    @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC,
                    @cIDBarcode        OUTPUT, @nQTY     OUTPUT,
                    @cUserDefine01 OUTPUT, @cUserDefine02 OUTPUT, @cUserDefine03 OUTPUT, @cUserDefine04 OUTPUT, @cUserDefine05 OUTPUT,
                    @cUserDefine06 OUTPUT, @cUserDefine07 OUTPUT, @cUserDefine08 OUTPUT, @cUserDefine09 OUTPUT,
                    @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
                    @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
                    @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
                    @nErrNo      OUTPUT, @cErrMsg     OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_3_Fail

				SET @cTOID = @cIDBarcode

            END
         END
      END

      -- (james01)
      -- Extended validate SP
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               '  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04 ' +
               ' ,@cUCC, @cSKU, @nQTY, @cParam1 OUTPUT, @cParam2 OUTPUT, @cParam3 OUTPUT, @cParam4 OUTPUT, @cParam5 OUTPUT, @cOption ' +
               ' ,@nErrNo   OUTPUT ' +
               ' ,@cErrMsg  OUTPUT '
            SET @cSQLParam = +
               '  @nMobile     INT       ' +
               ' ,@nFunc       INT       ' +
               ' ,@cLangCode   NVARCHAR(  3) ' +
               ' ,@nStep       INT       ' +
               ' ,@nInputKey   INT       ' +
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
               ' ,@cParam1     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam2     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam3     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam4     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam5     NVARCHAR( 20) OUTPUT ' +
               ' ,@cOption     NVARCHAR( 1)  ' +
               ' ,@nErrNo      INT       OUTPUT ' +
               ' ,@cErrMsg     NVARCHAR( 20) OUTPUT '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04
               ,@cUCC, @cSKU, @nQTY, @cParam1 OUTPUT, @cParam2 OUTPUT, @cParam3 OUTPUT, @cParam4 OUTPUT, @cParam5 OUTPUT, @cOption
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT

            IF @nErrNo <> 0
               GOTO Step_3_Fail
         END
      END

      -- Extended update SP
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               '  @nMobile, @nFunc, @nStep, @cLangCode, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04 ' +
               ' ,@cUCC, @cSKU, @nQTY, @cParam1 OUTPUT, @cParam2 OUTPUT, @cParam3 OUTPUT, @cParam4 OUTPUT, @cParam5 OUTPUT, @cOption ' +
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
               ' ,@cParam1     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam2     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam3     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam4     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam5     NVARCHAR( 20) OUTPUT ' +
               ' ,@cOption     NVARCHAR( 1)  ' +
               ' ,@nErrNo      INT       OUTPUT ' +
               ' ,@cErrMsg     NVARCHAR( 20) OUTPUT '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @nMobile, @nFunc, @nStep, @cLangCode, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04
               ,@cUCC, @cSKU, @nQTY, @cParam1 OUTPUT, @cParam2 OUTPUT, @cParam3 OUTPUT, @cParam4 OUTPUT, @cParam5 OUTPUT, @cOption
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT

            IF @nErrNo <> 0
               GOTO Step_3_Fail
         END
      END

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
                @nMobile, @nFunc, @cLangCode, 6, @nStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04
               ,@cUCC, @cSKU, @nQTY, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption, @cExtendedInfo OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END

      --prepare next screen variable
      SET @cTotalCarton = ''
      SET @cOutField01 = @cReceiptkey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cLOC
      SET @cOutField04 = @cTOID
      SET @cOutField05 = '' --estimated ucc on ID

      IF @cSkipEstUCCOnID = '1'
         SELECT @cFieldAttr05 = 'O', @cInField05 = ''

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = '' -- LOC

      --go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cTOID = ''
      SET @cOutField04 = '' -- TOID
   END
END
GOTO Quit


/********************************************************************************
Step 4. (screen = 1303) ESTIMATED UCC ON ID
   ASN:     (field01)
   PO:      (field02)
   TO LOC:  (field03)
   TO ID:   (field04)
   ESTIMATED UCC ON ID: (field05, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      --screen mapping
      SET @cTotalCarton = @cInField05

      IF @cSkipEstUCCOnID <> '1'
      BEGIN
         --check if Qty is Null
         IF @cTotalCarton = '' OR @cTotalCarton IS NULL
         BEGIN
            SET @nErrNo = 63133
            SET @cErrMsg = rdt.rdtgetmessage(63133, @cLangCode, 'DSP') --Qty Needed
            GOTO Step_4_Fail
         END

         --check if qty is valid
         IF rdt.rdtIsValidQTY( @cTotalCarton, 1) = 0  --1=Valid zero
         BEGIN
            SET @nErrNo = 63134
            SET @cErrMsg = rdt.rdtgetmessage(63134, @cLangCode, 'DSP') --Invalid Qty
            GOTO Step_4_Fail
         END
      END

      --prepare next screen variable
      SET @cOutField01 = '' --lottable01
      SET @cOutField02 = '' --lottable02
      SET @cOutField03 = '' --lottable03
      SET @cOutField04 = '' --lottable04
      SET @cFieldAttr05 = ''

      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @dLottable04 = 0
      SET @dLottable05 = 0

      /*CS01 Start*/

      SET @cLottable06 = ''
      SET @cLottable07 = ''
      SET @cLottable08 = ''
      SET @cLottable09 = ''
      SET @cLottable10 = ''
      SET @cLottable11 = ''
      SET @cLottable12 = ''
      SET @dLottable13 = 0
      SET @dLottable14 = 0
      SET @dLottable15 = 0

      /*CS01 End*/

      --initiate @nCounter = 1
      SET @nCount = 1

      --retrieve value for pre lottable01 - 04
      WHILE @nCount <=4 --break the loop when @nCount >4
      BEGIN
         IF @nCount = 1 SET @cListName = 'Lottable01'
         IF @nCount = 2 SET @cListName = 'Lottable02'
         IF @nCount = 3 SET @cListName = 'Lottable03'
         IF @nCount = 4 SET @cListName = 'Lottable04'

         --get short, store procedure and lottablelable value for each lottable
         SET @cShort = ''
         SET @cStoredProd = ''
         SET @cLottableLabel = ''
         SELECT TOP 1
            @cShort = C.Short,
            @cStoredProd = IsNULL( C.Long, ''),
            @cLottableLabel = S.SValue
         FROM dbo.CodeLkUp C WITH (NOLOCK)
         JOIN RDT.StorerConfig S WITH (NOLOCK)ON C.ListName = S.ConfigKey
         WHERE C.ListName = @cListName
            AND C.Code = S.SValue
            AND S.Storerkey = @cStorerKey -- NOTE: storer level
            AND (C.StorerKey = @cStorerkey OR C.StorerKey = '')
         ORDER By C.StorerKey DESC

         IF @cShort = 'PRE' AND @cStoredProd <> ''
         BEGIN
            EXEC dbo.ispLottableRule_Wrapper
               @c_SPName            = @cStoredProd,
               @c_ListName          = @cListName,
               @c_Storerkey         = @cStorerkey,
               @c_Sku               = '',
               @c_LottableLabel     = @cLottableLabel,
               @c_Lottable01Value   = '',
               @c_Lottable02Value   = '',
               @c_Lottable03Value   = '',
               @dt_Lottable04Value  = '',
               @dt_Lottable05Value  = '',
               @c_Lottable06Value   = '',                     --(CS01)
               @c_Lottable07Value   = '',                     --(CS01)
               @c_Lottable08Value   = '',                     --(CS01)
               @c_Lottable09Value   = '',                     --(CS01)
               @c_Lottable10Value   = '',                     --(CS01)
               @c_Lottable11Value   = '',                     --(CS01)
               @c_Lottable12Value   = '',                     --(CS01)
               @dt_Lottable13Value  = '',                     --(CS01)
               @dt_Lottable14Value  = '',                     --(CS01)
               @dt_Lottable15Value  = '',                     --(CS01)
               @c_Lottable01        = @cLottable01 OUTPUT,
               @c_Lottable02        = @cLottable02 OUTPUT,
               @c_Lottable03        = @cLottable03 OUTPUT,
               @dt_Lottable04       = @dLottable04 OUTPUT,
               @dt_Lottable05       = @dLottable05 OUTPUT,
               @c_Lottable06        = @cLottable06 OUTPUT,   --(CS01)
               @c_Lottable07        = @cLottable07 OUTPUT,   --(CS01)
               @c_Lottable08        = @cLottable08 OUTPUT,   --(CS01)
               @c_Lottable09        = @cLottable09 OUTPUT,   --(CS01)
               @c_Lottable10        = @cLottable10 OUTPUT,   --(CS01)
               @c_Lottable11        = @cLottable11 OUTPUT,   --(CS01)
               @c_Lottable12        = @cLottable12 OUTPUT,   --(CS01)
               @dt_Lottable13       = @dLottable13 OUTPUT,   --(CS01)
               @dt_Lottable14       = @dLottable14 OUTPUT,   --(CS01)
               @dt_Lottable15       = @dLottable15 OUTPUT,   --(CS01)
               @b_Success           = @b_Success   OUTPUT,
               @n_Err               = @nErrNo      OUTPUT,
               @c_Errmsg            = @cErrMsg     OUTPUT,
 			      @c_Sourcekey         = @cReceiptkey,  -- SOS#81879
					@c_Sourcetype        = 'RDTUCCRCV'    -- SOS#81879

               --IF @b_success <> 1
               IF ISNULL(@cErrMsg, '') <> ''
               BEGIN
                  SET @cErrMsg = @cErrMsg
                  GOTO Step_4_Fail
                  BREAK
               END

               SET @cLottable01 = IsNULL( @cLottable01, '')
               SET @cLottable02 = IsNULL( @cLottable02, '')
               SET @cLottable03 = IsNULL( @cLottable03, '')
               SET @dLottable04 = IsNULL( @dLottable04, 0)
               SET @dLottable05 = IsNULL( @dLottable05, 0)

               SET @cOutField01 = @cLottable01
               SET @cOutField02 = @cLottable02
               SET @cOutField03 = @cLottable03
               SET @cOutField04 = CASE WHEN @dLottable04 <> 0 THEN rdt.rdtFormatDate( @dLottable04) END
         END

         -- increase counter by 1
         SET @nCount = @nCount + 1

      END

      --reset carton cnt
      SET @cCartonCnt = '0'

      -- Skip lottable
      IF @cSkipLottable01 = '1' SELECT @cFieldAttr01 = 'O', @cInField01 = '', @cLottable01 = '', @cTempLottable01 = ''
      IF @cSkipLottable02 = '1' SELECT @cFieldAttr02 = 'O', @cInField02 = '', @cLottable02 = '', @cTempLottable02 = ''
      IF @cSkipLottable03 = '1' SELECT @cFieldAttr03 = 'O', @cInField03 = '', @cLottable03 = '', @cTempLottable03 = ''
      IF @cSkipLottable04 = '1' SELECT @cFieldAttr04 = 'O', @cInField04 = '', @dLottable04 = 0 , @cTempLottable04 = ''

      --set cursor to first field
      EXEC rdt.rdtSetFocusField @nMobile, 1 --Lottable01

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      IF @cSkipLottable01 = '1' AND @cSkipLottable02 = '1' AND @cSkipLottable03 = '1' AND @cSkipLottable04 = '1'
      BEGIN
         -- Prepare next screen var
         SET @cUCC        = ''
         SET @cSKU        = ''
         SET @cDesc       = ''
         SET @cPQIndicator= ''
         SET @cPPK        = ''
         SET @nQTY        = 0
         SET @cOutField01 = '' --ucc
         SET @cOutField02 = '' --sku
         SET @cOutField03 = '' --sku desc
         SET @cOutField04 = '' --sku desc
         SET @cOutField05 = '' --ppk/du
         SET @cOutField06 = '' --lottable01
         SET @cOutField07 = '' --lottable02
         SET @cOutField08 = '' --lottable03
         SET @cOutField09 = '' --lottable04
         SET @cOutField10 = '' --qty
         SET @cOutField11 = RTRIM(CAST( @cCartonCnt AS NVARCHAR( 4))) + CASE WHEN @cSkipEstUCCOnID = '1' THEN '' ELSE '/' + CAST( @cTotalCarton AS NVARCHAR( 4)) END  -- (ChewKP02)

         -- Enable field
         SET @cFieldAttr01 = ''
         SET @cFieldAttr02 = ''
         SET @cFieldAttr03 = ''
         SET @cFieldAttr04 = ''

         -- Go to UCC screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END

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
                @nMobile, @nFunc, @cLangCode, 6, @nStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04
               ,@cUCC, @cSKU, @nQTY, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption, @cExtendedInfo OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END
   END

   IF @nInputKey = 0 -- Esc
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cLOC
      SET @cOutField04 = ''
      SET @cFieldAttr05 = ''

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   IF @cExtScnSP <> ''
   BEGIN
      GOTO Step_99
   END

   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cOutField05 = @cTotalCarton
   END
END
GOTO Quit


/********************************************************************************
Step 5. (screen = 1304) Lottable1 to 5
   LotLabel01: (field01, input)
   LotLabel02: (field02, input)
   LotLabel03: (field03, input)
   LotLabel04: (field04, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1      -- ENTER
   BEGIN
      --Screen Mapping
      SET @cTempLottable01 = @cInField01
      SET @cTempLottable02 = @cInField02
      SET @cTempLottable03 = @cInField03
      SET @cTempLottable04 = @cInField04

      --check for date validation for lottable04
      IF @cTempLottable04 <> '' AND rdt.rdtIsValidDate(@cTempLottable04) = 0
      BEGIN
         SET @nErrNo = 63149
         SET @cErrMsg = rdt.rdtgetmessage( 63149, @cLangCode, 'DSP') --Invalid Date
         SET @cOutField04 = @cTempLottable04
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Lottable04
         GOTO Step_5_Fail
      END

      --(ChewKP03)
      IF @cTempLottable01 <> ''
      BEGIN
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'LOTTABLE01', @cTempLottable01) = 0
         BEGIN
            SET @nErrNo = 63170
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            GOTO Step_5_Fail
         END
      END

      IF @cTempLottable02 <> ''
      BEGIN
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'LOTTABLE02', @cTempLottable02) = 0
         BEGIN
            SET @nErrNo = 63171
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            GOTO Step_5_Fail
         END
      END

      IF @cTempLottable03 <> ''
      BEGIN
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'LOTTABLE03', @cTempLottable03) = 0
         BEGIN
            SET @nErrNo = 63172
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            GOTO Step_5_Fail
         END
      END

      --(yeekung05)
      -- Extended validate SP
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               '  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04 ' +
               ' ,@cUCC, @cSKU, @nQTY, @cParam1 OUTPUT, @cParam2 OUTPUT, @cParam3 OUTPUT, @cParam4 OUTPUT, @cParam5 OUTPUT, @cOption ' +
               ' ,@nErrNo   OUTPUT ' +
               ' ,@cErrMsg  OUTPUT '
            SET @cSQLParam = +
               '  @nMobile     INT       ' +
               ' ,@nFunc       INT       ' +
               ' ,@cLangCode   NVARCHAR(  3) ' +
               ' ,@nStep       INT       ' +
               ' ,@nInputKey   INT       ' +
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
               ' ,@cParam1     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam2     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam3     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam4     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam5     NVARCHAR( 20) OUTPUT ' +
               ' ,@cOption     NVARCHAR( 1)  ' +
               ' ,@nErrNo      INT       OUTPUT ' +
               ' ,@cErrMsg     NVARCHAR( 20) OUTPUT '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cTempLottable01, @cTempLottable02, @cTempLottable03, @cTempLottable04
               ,@cUCC, @cSKU, @nQTY, @cParam1 OUTPUT, @cParam2 OUTPUT, @cParam3 OUTPUT, @cParam4 OUTPUT, @cParam5 OUTPUT, @cOption
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT

            IF @nErrNo <> 0
               GOTO Step_5_Fail
         END
      END


      -- Enable field
      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''

      --prepare next screen variable
      SET @cUCC        = ''
      SET @cSKU        = ''
      SET @cDesc       = ''
      SET @cPQIndicator= ''
      SET @cPPK        = ''
      SET @nQTY        = 0
      SET @cOutField01 = '' --ucc
      SET @cOutField02 = '' --sku
      SET @cOutField03 = '' --sku desc
      SET @cOutField04 = '' --sku desc
      SET @cOutField05 = '' --ppk/du
      SET @cOutField06 = '' --lottable01
      SET @cOutField07 = '' --lottable02
      SET @cOutField08 = '' --lottable03
      SET @cOutField09 = '' --lottable04
      SET @cOutField10 = '' --qty
      SET @cOutField11 = RTRIM(CAST( @cCartonCnt AS NVARCHAR( 4))) + CASE WHEN @cSkipEstUCCOnID = '1' THEN '' ELSE '/' + CAST( @cTotalCarton AS NVARCHAR( 4)) END -- (ChewKP02)

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

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
                @nMobile, @nFunc, @cLangCode, 6, @nStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04
               ,@cUCC, @cSKU, @nQTY, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption, @cExtendedInfo OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END
   END

   IF @nInputKey = 0 -- Esc
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

      --go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   IF @cExtScnSP <> ''
   BEGIN
      GOTO Step_99
   END

   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cOutField01 = @cTempLottable01
      SET @cOutField02 = @cTempLottable02
      SET @cOutField03 = @cTempLottable03
      SET @cOutField04 = @cTempLottable04
   END
END
GOTO Quit

/********************************************************************************
Step 6. (screen = 1305) UCC, SKU, PPK/DU, LOTTABLE01-04, QTY
   UCC        (field01, input)
   COUNTER    (field11) --99/99
   SKU        (field02)
   sku desc   (field03)
   sku desc2  (field04)
   PPK/DU     (field05)
   lottable01 (field06)
   lottable02 (field07)
   lottable03 (field08)
   lottable04 (field09)
   QTY:       (field10)
********************************************************************************/
Step_6:
BEGIN
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
            SET @nScn  = @nScn + 6
            SET @nStep = @nStep + 6
            EXEC rdt.rdtSetFocusField @nMobile, 1 --Option

            IF @cClosePalletCountUCC <> '1'
               SET @cFieldAttr02 = 'O' -- Count UCC
            GOTO Step_6_Quit
         END
         ELSE
         BEGIN
            SET @nErrNo = 63136
            SET @cErrMsg = rdt.rdtgetmessage( 63136, @cLangCode, 'DSP') --UCC Required
            GOTO Step_6_Fail
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
         SET @nScn  = @nScn + 2
         SET @nStep = @nStep + 2

         GOTO Step_6_Quit
      END

      --max carton no and go back
      IF CAST(@cCartonCnt AS INT) >= CAST(@cTotalCarton AS INT) AND @cSkipEstUCCOnID <> '1'
      BEGIN
         SET @nErrNo = 63135
         SET @cErrMsg = rdt.rdtgetmessage( 63135, @cLangCode, 'DSP') -->Max No of CTN
         GOTO Step_6_Fail
      END

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'UCC', @cUCC) = 0
      BEGIN
         SET @nErrNo = 63173
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_6_Fail
      END

      IF rdt.rdtIsValidDate(@cTempLottable04) = 1 --valid date
        SET @dTempLottable04 = rdt.rdtConvertToDate( @cTempLottable04)

		SET @nQTY = 0

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         DECLARE @nUCCQTY INT
         DECLARE @cUCCBarcode NVARCHAR(100)
         SET @cUCCBarcode = @cInField01

         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cUCC,
                 @cUCCNo      = @cUCCBarcode OUTPUT,
                 @nQTY        = @nUCCQTY     OUTPUT,
                 @cLottable01 = @cLottable01 OUTPUT,
                 @cLottable02 = @cLottable02 OUTPUT,
                 @cLottable03 = @cLottable03 OUTPUT,
                 @dLottable04 = @dLottable04 OUTPUT,
               -- @nErrNo   = @nErrNo  OUTPUT,
               -- @cErrMsg  = @cErrMsg OUTPUT,
                 @cType       = 'UCCNo'
         END

         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, ' +
                        ' @cUCC        OUTPUT, @nUCCQTY     OUTPUT,' +
                        ' @cUserDefine01 OUTPUT, @cUserDefine02 OUTPUT, @cUserDefine03 OUTPUT, @cUserDefine04 OUTPUT, @cUserDefine05 OUTPUT, ' +
                        ' @cUserDefine06 OUTPUT, @cUserDefine07 OUTPUT, @cUserDefine08 OUTPUT, @cUserDefine09 OUTPUT, ' +
                        ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT, ' +
                        ' @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT, ' +
                        ' @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT, ' +
                        ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
                    ' @nMobile         INT,                    ' +
                    ' @nFunc           INT,                    ' +
                    ' @cLangCode       NVARCHAR( 3),           ' +
                    ' @nStep           INT,                    ' +
                    ' @nInputKey       INT,                    ' +
                    ' @cStorerKey      NVARCHAR( 15),          ' +
                    ' @cReceiptKey     NVARCHAR( 10),          ' +
                    ' @cPOKey          NVARCHAR( 10),          ' +
                    ' @cLOC            NVARCHAR( 10),          ' +
                    ' @cUCC            NVARCHAR( MAX)  OUTPUT,  ' +
                    ' @nUCCQTY         INT            OUTPUT,  ' +
                    ' @cUserDefine01   NVARCHAR(30)   OUTPUT,  ' +
                    ' @cUserDefine02   NVARCHAR(30)   OUTPUT,  ' +
                    ' @cUserDefine03   NVARCHAR(30)   OUTPUT,  ' +
                    ' @cUserDefine04   NVARCHAR(30)   OUTPUT,  ' +
                    ' @cUserDefine05   NVARCHAR(30)   OUTPUT,  ' +
                    ' @cUserDefine06   NVARCHAR(30)   OUTPUT,  ' +
                    ' @cUserDefine07   NVARCHAR(30)   OUTPUT,  ' +
                    ' @cUserDefine08   NVARCHAR(30)   OUTPUT,  ' +
                    ' @cUserDefine09   NVARCHAR(30)   OUTPUT,  ' +
                    ' @cLottable01     NVARCHAR( 18)  OUTPUT,  ' +
                    ' @cLottable02     NVARCHAR( 18)  OUTPUT,  ' +
                    ' @cLottable03     NVARCHAR( 18)  OUTPUT,  ' +
                    ' @dLottable04     DATETIME       OUTPUT,  ' +
                    ' @dLottable05     DATETIME       OUTPUT,  ' +
                    ' @cLottable06     NVARCHAR( 30)  OUTPUT,  ' +
                    ' @cLottable07     NVARCHAR( 30)  OUTPUT,  ' +
                    ' @cLottable08     NVARCHAR( 30)  OUTPUT,  ' +
                    ' @cLottable09     NVARCHAR( 30)  OUTPUT,  ' +
                    ' @cLottable10     NVARCHAR( 30)  OUTPUT,  ' +
                    ' @cLottable11     NVARCHAR( 30)  OUTPUT,  ' +
                    ' @cLottable12     NVARCHAR( 30)  OUTPUT,  ' +
                    ' @dLottable13     DATETIME       OUTPUT,  ' +
                    ' @dLottable14     DATETIME       OUTPUT,  ' +
                    ' @dLottable15     DATETIME       OUTPUT,  ' +
                    ' @nErrNo          INT            OUTPUT,  ' +
                    ' @cErrMsg         NVARCHAR( 20)  OUTPUT   '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC,
                 @cUCCBarcode    OUTPUT,  @nUCCQTY       OUTPUT,
                 @cUserDefine01  OUTPUT,  @cUserDefine02 OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05 OUTPUT,
                 @cUserDefine06  OUTPUT,  @cUserDefine07 OUTPUT, @cUserDefine08  OUTPUT, @cUserDefine09  OUTPUT,
                 @cLottable01    OUTPUT,  @cLottable02   OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05 OUTPUT,
                 @cLottable06    OUTPUT,  @cLottable07   OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10 OUTPUT,
                 @cLottable11    OUTPUT,  @cLottable12   OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15 OUTPUT,
                 @nErrNo         OUTPUT,  @cErrMsg       OUTPUT

            IF @nErrNo <> 0
               GOTO Step_6_Fail

            SET @cUCC = @cUCCBarcode
         END
      END

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
               GOTO Step_6_Fail
         END
      END

      --get ucc count
      SET @nCnt = 0
      SELECT @nCnt = COUNT(UCCNo)
      FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCC

      --check if multi sku per UCC
      IF @cUCCWithMultiSKU <> '1'
      BEGIN
         IF @nCnt > 1
         BEGIN
            SET @nErrNo = 63137
            SET @cErrMsg = rdt.rdtgetmessage( 63137, @cLangCode, 'DSP') --Multi Sku/ UCC
            GOTO Step_6_Fail
         END
      END

       -- Added by Vicky for SOS#105011 (Start - Vicky01)
      DECLARE @cActPOKey NVARCHAR(10), @cErrMsg1 NVARCHAR(20), @cErrMsg2 NVARCHAR(20), @cErrMsg3 NVARCHAR(20)

      -- for [(UPPER(@cPOKey) <> 'NOPO' OR @cPOKey <> '')] and [(UPPER(@cPOKey) <> 'NOPO' AND @cPOKey <> '')], condition OP [AND] is meet to logic.  (YYS027 MERGE V0 TO V2 20241106)
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
            GOTO Step_6_Fail
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
         GOTO Step_6_Fail
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
				   GOTO Step_6_Fail
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
         --not allowed add new UCC
         IF @cReceiveAllowAddNewUCC = '0'
         BEGIN
            SET @nErrNo = 63139
            SET @cErrMsg = rdt.rdtgetmessage(63139, @cLangCode, 'DSP') --UCC Not Found
            GOTO Step_6_Fail
         END

         --allowed add new UCC
         IF @cReceiveAllowAddNewUCC = '1'
         BEGIN
            --go to screen SKU
            SET @nScn  = @nScn + 2
            SET @nStep = @nStep + 2

            SET @cSKU = ''
            SET @nQTY = 0
            SET @nNewUCCWithMultiSKURcv = 0

            --prepare next screen var
            SET @cOutField01 = @cUCC
            SET @cOutField02 = '' --sku
            SET @cOutField03 = RTRIM(CAST( @cCartonCnt AS NVARCHAR( 4))) + CASE WHEN @cSkipEstUCCOnID = '1' THEN '' ELSE '/' + CAST( @cTotalCarton AS NVARCHAR( 4)) END --(ChewKP02)
            SET @cOutField04 = ''

            GOTO Step_6_Quit
         END

          --allowed add new UCC
         IF @cReceiveAllowAddNewUCC = '2'
         BEGIN
            --go to prompt screen 'Create New UCC?'
            SET @nScn  = @nScn + 1
            SET @nStep = @nStep + 1

         --prepare next screen variable
            SET @cOutField01 = '' --option

            GOTO Step_6_Quit
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

	 				     GOTO Step_6_Fail  -- Error will break
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
               GOTO Step_6_Fail
            END

            --if lottable02 has been setup but no value, prompt error msg
            IF @cSkipLottable02 <> '1' AND (@cTempLotLabel02 <> '' AND @cOutField07 = '')
            BEGIN
               SET @nErrNo = 63152
               SET @cErrMsg = rdt.rdtgetmessage(63152, @cLangCode, 'DSP') --Lottable02 Req
               EXEC rdt.rdtSetFocusField @nMobile, 7
               GOTO Step_6_Fail
            END

            --if lottable03 has been setup but no value, prompt error msg
            IF @cSkipLottable03 <> '1' AND (@cTempLotLabel03 <> '' AND @cOutField08 = '')
            BEGIN
               SET @nErrNo = 63153
               SET @cErrMsg = rdt.rdtgetmessage(63153, @cLangCode, 'DSP') --Lottable03 Req
               EXEC rdt.rdtSetFocusField @nMobile, 8
               GOTO Step_6_Fail
            END

            --if lottable04 has been setup but no value, prompt error msg
            IF @cSkipLottable04 <> '1' AND (@cTempLotLabel04 <> '' AND @cOutField09 = '')
            BEGIN
               SET @nErrNo = 63154
               SET @cErrMsg = rdt.rdtgetmessage(63154, @cLangCode, 'DSP') --Lottable04 Req
               EXEC rdt.rdtSetFocusField @nMobile, 9
               GOTO Step_6_Fail
            END

            -- Update ReceiptDetail
            IF @cUCCWithMultiSKU = '1'
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
                     GOTO Step_6_Fail
                  END
/*
                  -- Update UCC
                  UPDATE dbo.UCC WITH (ROWLOCK) SET
                     ID = @cTOID,
                     LOC = @cLOC,
                     Status = '1', --1=Received
                     ReceiptKey = @cReceiptKey,
                     ReceiptLineNumber = @cReceiptLineNumber
                  WHERE UCCNo = @cTempUCC
                     AND StorerKey = @cStorerKey
                     AND SKU = @cSKU
                  IF @nErrno <> 0
                  BEGIN
                     ROLLBACK TRAN UCCWithMultiSKU
                     WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                        COMMIT TRAN

                     SET @nErrNo = 63154
                     SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
                     GOTO Step_6_Fail
                  END
*/
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
                     GOTO Step_6_Fail

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
                  SET @nScn  = @nScn + 6
                  SET @nStep = @nStep + 6
                  EXEC rdt.rdtSetFocusField @nMobile, 1 --Option

                  IF @cClosePalletCountUCC <> '1'
                     SET @cFieldAttr02 = 'O'

                  GOTO Step_6_Quit
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
            GOTO Step_6_Quit
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
         SET @nScn = @nScn + 5
         SET @nStep = @nStep + 5

         GOTO Step_6_Quit
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
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

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
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END

   Step_6_Quit:
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
                @nMobile, @nFunc, @cLangCode, 6, @nStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04
               ,@cUCC, @cSKU, @nQTY, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption, @cExtendedInfo OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END
   END
   GOTO Quit

   Step_6_Fail:
   BEGIN
      SET @cUCC = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 7. (screen = 1306) Create New UCC
   Create new ucc?
   1=YES
   2=NO
   OPTION: (field01, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1      -- ENTER
   BEGIN
      --screen mapping
      SET @cOption = @cInField01

      --check if option is blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 63159
         SET @cErrMsg = rdt.rdtgetmessage(63159, @cLangCode, 'DSP') --Option required
         GOTO Step_7_Fail
      END

      --invalid option other than '1' or '2'
      IF (@cOption <> '1' AND @cOption <> '2')
	   BEGIN
         SET @nErrNo = 63142
         SET @cErrMsg = rdt.rdtgetmessage(63142, @cLangCode, 'DSP') --Invalid option
         GOTO Step_7_Fail
      END

      IF @cOption = '1' --Go to next screen
      BEGIN
         SET @cSKU = ''
         SET @nQTY = 0
         SET @nNewUCCWithMultiSKURcv = 0

         --prepare next screen var
         SET @cOutField01 = @cUCC
         SET @cOutField02 = '' --sku
         SET @cOutField03 = RTRIM(CAST( @cCartonCnt AS NVARCHAR( 4))) + CASE WHEN @cSkipEstUCCOnID = '1' THEN '' ELSE '/' + CAST( @cTotalCarton AS NVARCHAR( 4)) END -- (ChewKP02)
         SET @cOutField04 = '' -- QTY

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Step_7_Quit
      END
   END

   --prepare previous screen variable
   SET @cOutField01 = ''--ucc
   SET @cOutField02 = @cSku
   SET @cOutField02 = @cSKU
   SET @cOutField03 = SUBSTRING( @cDesc,1,20)
   SET @cOutField04 = SUBSTRING( @cDesc,21,40)
   SET @cOutField05 = CASE WHEN IsNULL(@cPPK, '') = '' THEN '0'  ELSE @cPPK END +
                      '/' +
                      CASE WHEN IsNULL(@cPQIndicator, '') = '' THEN '0' ELSE @cPQIndicator END
   SET @cOutField06 = @cOutField06
   SET @cOutField07 = @cOutField07
   SET @cOutField08 = @cOutField08
   SET @cOutField09 = @cOutField09
   SET @cOutField10 = CAST( @nQTY AS NVARCHAR( 5))
   SET @cOutField11 = RTRIM(CAST( @cCartonCnt AS NVARCHAR( 4))) + CASE WHEN @cSkipEstUCCOnID = '1' THEN '' ELSE '/' + CAST( @cTotalCarton AS NVARCHAR( 4)) END -- (ChewKP02)

   -- Go to previous screen
   SET @nScn = @nScn - 1
   SET @nStep = @nStep - 1

   Step_7_Quit:
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
                @nMobile, @nFunc, @cLangCode, 6, @nStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04
               ,@cUCC, @cSKU, @nQTY, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption, @cExtendedInfo OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END
   END

   IF @cExtScnSP <> ''
   BEGIN
      GOTO Step_99
   END

   GOTO Quit

   Step_7_Fail:
   BEGIN
      SET @cOutField01 = ''--option
      SET @cOption = ''
   END
END
GOTO Quit


/********************************************************************************
Step 8. (screen  = 1307) UCC, SKU/UPC
   UCC:     (field01)         (field03) --99/99
   SKU/UPC: (field02, input)
   QTY:     (field04)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1      -- Yes OR Send
   BEGIN
      DECLARE @cSKUBarcode NVARCHAR( 60)
      DECLARE @cUPC NVARCHAR(30)

      --screen mapping
      -- SET @cActSku = @cInField02
      SET @cUPC = LEFT( @cInField02, 30)
      SET @cSKUBarcode = @cInField02

      --check if sku is null
      IF @cUPC = ''
      BEGIN
         IF @cDisableQTYField = '0' OR (@cDisableQTYField = '1' AND @nQTY = 0)
         BEGIN
            SET @nErrNo = 63143
            SET @cErrMsg = rdt.rdtgetmessage(63143, @cLangCode, 'DSP') --SKU required
            GOTO Step_8_Fail
         END
      END
      ELSE
      BEGIN
         -- Decode
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cSKUBarcode,
               @cUPC    = @cUPC OUTPUT,
               @nQTY    = @nQTY OUTPUT,
               -- @nErrNo  = @nErrNo  OUTPUT,
               -- @cErrMsg = @cErrMsg OUTPUT,
               @cType   = 'UPC'
         END

         -- Get SKU/UPC
         /*
         SELECT
            @nSKUCnt = COUNT( DISTINCT A.SKU),
            @cActSku = MIN( A.SKU) -- Just to bypass SQL aggregrate checking
         FROM
         (
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cActSku
            UNION ALL
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cActSku
            UNION ALL
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cActSku
            UNION ALL
            SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cActSku
            UNION ALL
            SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cActSku
         ) A
         */

         -- Check SKU
         EXEC RDT.rdt_GetSKUCNT
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cUPC
            ,@nSKUCnt     = @nSKUCnt   OUTPUT
            ,@bSuccess    = @b_Success OUTPUT
            ,@nErr        = @nErrNo    OUTPUT
            ,@cErrMsg     = @cErrMsg   OUTPUT
            ,@cSKUStatus  = 'ACTIVE'

         -- Validate SKU/UPC
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 63144
            SET @cErrMsg = rdt.rdtgetmessage( 63144, @cLangCode, 'DSP') --'Invalid SKU'
            GOTO Step_8_Fail
         END

         -- Validate barcode return multiple SKU
         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 63163
            SET @cErrMsg = rdt.rdtgetmessage( 63163 , @cLangCode, 'DSP') --'SameBarCodeSKU'
            GOTO Step_8_Fail
         END

         -- Get SKU
         EXEC [RDT].[rdt_GETSKU]
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cUPC          OUTPUT
            ,@bSuccess    = @b_Success     OUTPUT
            ,@nErr        = @nErrNo        OUTPUT
            ,@cErrMsg     = @cErrMsg       OUTPUT
            ,@cSKUStatus  = 'ACTIVE'

         -- Piece scan
         IF @cDisableQTYField = '1'
         BEGIN
            -- Check same SKU
            IF @cUPC <> @cSKU AND @nQTY > 0
            BEGIN
               SET @nErrNo = 63169
               SET @cErrMsg = rdt.rdtgetmessage( 63169 , @cLangCode, 'DSP') --'Different SKU'
               GOTO Step_8_Fail
            END
         END

         SET @cSKU = @cUPC

      	-- Verify SKU
         IF @cVerifySKU = '1'
         BEGIN
            EXEC rdt.rdt_VerifySKU_V7 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, '', 'CHECK',
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
               SET @nStep = @nStep + 5

               GOTO Quit
            END
         END
      -- Extended validate SP
         IF @cExtendedValidateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
                  '  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04 ' +
                  ' ,@cUCC, @cSKU, @nQTY, @cParam1 OUTPUT, @cParam2 OUTPUT, @cParam3 OUTPUT, @cParam4 OUTPUT, @cParam5 OUTPUT, @cOption ' +
                  ' ,@nErrNo   OUTPUT ' +
                  ' ,@cErrMsg  OUTPUT '
               SET @cSQLParam = +
                  '  @nMobile     INT       ' +
                  ' ,@nFunc       INT       ' +
                  ' ,@cLangCode   NVARCHAR(  3) ' +
                  ' ,@nStep       INT       ' +
                  ' ,@nInputKey   INT       ' +
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
                  ' ,@cParam1     NVARCHAR( 20) OUTPUT ' +
                  ' ,@cParam2     NVARCHAR( 20) OUTPUT ' +
                  ' ,@cParam3     NVARCHAR( 20) OUTPUT ' +
                  ' ,@cParam4     NVARCHAR( 20) OUTPUT ' +
                  ' ,@cParam5     NVARCHAR( 20) OUTPUT ' +
                  ' ,@cOption     NVARCHAR( 1)  ' +
                  ' ,@nErrNo      INT       OUTPUT ' +
                  ' ,@cErrMsg     NVARCHAR( 20) OUTPUT '
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                   @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cTempLottable01, @cTempLottable02, @cTempLottable03, @cTempLottable04
                  ,@cUCC, @cSKU, @nQTY, @cParam1 OUTPUT, @cParam2 OUTPUT, @cParam3 OUTPUT, @cParam4 OUTPUT, @cParam5 OUTPUT, @cOption
                  ,@nErrNo   OUTPUT
                  ,@cErrMsg  OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
         -- Piece scan
         IF @cDisableQTYField = '1'
         BEGIN
            -- Top up QTY
            SET @nQTY = @nQTY + 1

            -- Prepare current screen var
            SET @cOutField02 = '' -- SKU/UPC
            SET @cOutField04 = CAST( @nQTY AS NVARCHAR( 5))

            -- Remain in current screen
            GOTO Step_8_Quit
         END
      END

      --get some value to be use in below part
      SELECT
         @cDesc = CASE WHEN @cDispStyleColorSize = '1' THEN Style + Color + Size + Measurement ELSE Descr END,
         @cPPK = PREPACKINDICATOR,
         @cPQIndicator = PackQtyIndicator,
         @cPackkey = PackKey,
         @cTempLotLabel01 = Lottable01Label,
         @cTempLotLabel02 = Lottable02Label,
         @cTempLotLabel03 = Lottable03Label,
         @cTempLotLabel04 = Lottable04Label
      FROM dbo.Sku WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      SELECT @cUOM = PACKUOM3
      FROM dbo.Pack WITH (NOLOCK)
      WHERE Packkey = @cPackkey

       --prepare next screen
      SET @cOutField06 = '' --lottable01
      SET @cOutField07 = '' --lottable02
      SET @cOutField08 = '' --lottable03
      SET @cOutField09 = '' --lottable04

       --retain original value for lottable01-05
      SET @cLottable01 = @cTempLottable01
      SET @cLottable02 = @cTempLottable02
      SET @cLottable03 = @cTempLottable03
      SET @dLottable04 = rdt.rdtConvertToDate( @cTempLottable04)
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
                  @c_Lottable06Value   = '',             --(CS01)
                  @c_Lottable07Value   = '',             --(CS01)
                  @c_Lottable08Value   = '',             --(CS01)
                  @c_Lottable09Value   = '',             --(CS01)
                  @c_Lottable10Value   = '',             --(CS01)
                  @c_Lottable11Value   = '',             --(CS01)
                  @c_Lottable12Value   = '',             --(CS01)
                  @dt_Lottable13Value  = NULL,           --(CS01)
                  @dt_Lottable14Value  = NULL,           --(CS01)
                  @dt_Lottable15Value  = NULL,           --(CS01)
                  @c_Lottable01        = @cLottable01 OUTPUT,
                  @c_Lottable02        = @cLottable02 OUTPUT,
                  @c_Lottable03        = @cLottable03 OUTPUT,
                  @dt_Lottable04       = @dLottable04 OUTPUT,
                  @dt_Lottable05       = @dLottable05 OUTPUT,
                  @c_Lottable06        = @cLottable06 OUTPUT,  --(CS01)
                  @c_Lottable07        = @cLottable07 OUTPUT,  --(CS01)
                  @c_Lottable08        = @cLottable08 OUTPUT,  --(CS01)
                  @c_Lottable09        = @cLottable09 OUTPUT,  --(CS01)
                  @c_Lottable10        = @cLottable10 OUTPUT,  --(CS01)
                  @c_Lottable11        = @cLottable11 OUTPUT,  --(CS01)
                  @c_Lottable12        = @cLottable12 OUTPUT,  --(CS01)
                  @dt_Lottable13       = @dLottable13 OUTPUT,  --(CS01)
                  @dt_Lottable14       = @dLottable14 OUTPUT,  --(CS01)
                  @dt_Lottable15       = @dLottable15 OUTPUT,  --(CS01)
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

                 GOTO Step_8_Fail  -- Error will break
              END

            SET @cLottable01 = IsNULL( @cLottable01, '')
            SET @cLottable02 = IsNULL( @cLottable02, '')
            SET @cLottable03 = IsNULL( @cLottable03, '')
            SET @dLottable04 = IsNULL( @dLottable04, 0)
            SET @dLottable05 = IsNULL( @dLottable05, 0)

            --overwrite the outField value when there is POST value for lottable
            SET @cOutField06 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE @cTempLottable01 END
            SET @cOutField07 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE @cTempLottable02 END
            SET @cOutField08 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE @cTempLottable03 END
            SET @cOutField09 = CASE WHEN @dLottable04 <> 0  THEN rdt.rdtFormatDate( @dLottable04) ELSE @cTempLottable04 END
         END

         --increase counter by 1
         SET @nCount = @nCount + 1

      END -- end of while

      --prepare next screen variable
      SET @cOutField01 = @cUCC
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cDesc,  1, 20)
      SET @cOutField04 = SUBSTRING( @cDesc, 21, 20)
      SET @cOutField05 = CASE WHEN IsNULL(@cPPK, '') = '' THEN '0' ELSE  @cPPK END +
	                      '/' +
	                      CASE WHEN IsNULL(@cPQIndicator, '') = '' THEN '0' ELSE @cPQIndicator END
      SET @cOutField10 = CASE WHEN @nQTY > 0 THEN CAST( @nQTY AS NVARCHAR( 5)) ELSE '' END --qty
      SET @cOutField11 = RTRIM(CAST( @cCartonCnt AS NVARCHAR( 4))) + CASE WHEN @cSkipEstUCCOnID = '1' THEN '' ELSE '/' + CAST( @cTotalCarton AS NVARCHAR( 4)) END -- (ChewKP02)

      --if lottable01 has been setup but blank value, prompt erro msg
      IF @cSkipLottable01 <> '1' AND @cTempLotLabel01 <> '' AND @cOutField06 = ''
      BEGIN
         SET @nErrNo = 63155
         SET @cErrMsg = rdt.rdtgetmessage(63155, @cLangCode, 'DSP') --Lottable01 Req
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Step_8_Fail
      END

      --if lottable02 has been setup but blank value, prompt erro msg
      IF @cSkipLottable02 <> '1' AND @cTempLotLabel02 <> '' AND @cOutField07 = ''
      BEGIN
         SET @nErrNo = 63156
         SET @cErrMsg = rdt.rdtgetmessage(63156, @cLangCode, 'DSP') --Lottable02 Req
         EXEC rdt.rdtSetFocusField @nMobile, 7
         GOTO Step_8_Fail
      END

      --if lottable03 has been setup but blank value, prompt erro msg
      IF @cSkipLottable03 <> '1' AND @cTempLotLabel03 <> '' AND @cOutField08 = ''
      BEGIN
         SET @nErrNo = 63157
         SET @cErrMsg = rdt.rdtgetmessage(63157, @cLangCode, 'DSP') --Lottable03 Req
         EXEC rdt.rdtSetFocusField @nMobile, 8
         GOTO Step_8_Fail
      END

      --if lottable04 has been setup but blank value, prompt erro msg
      IF @cSkipLottable04 <> '1' AND @cTempLotLabel04 <> '' AND @cOutField09 = ''
      BEGIN
         SET @nErrNo = 63158
         SET @cErrMsg = rdt.rdtgetmessage(63158, @cLangCode, 'DSP') --Lottable04 Req
         EXEC rdt.rdtSetFocusField @nMobile, 9
         GOTO Step_8_Fail
      END

      IF @cDisableQTYField = '1'
      BEGIN
         SET @cOutField10 = CAST( @nQTY AS NVARCHAR( 5))
         SET @cFieldAttr10 = 'O' -- QTY
      END

      --go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

   END

   IF @nInputKey = 0 -- Esc
   BEGIN
      -- Received multi SKU UCC
      IF @cUCC <> '' AND @cUCC <> 'NOUCC' AND @cUCCWithMultiSKU = '1' AND @nNewUCCWithMultiSKURcv = 1
      BEGIN
         --increase carton count by one if it is not loose qty
         IF UPPER(@cUCC) <> 'NOUCC'
            SET @cCartonCnt = Convert(char,Cast( @cCartonCnt as Int) + 1 )
      END

      --prepare previous screen variable
      SET @cOutField01 = ''
      SET @cOutField02 = @cSku
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cDesc,1,20)
      SET @cOutField04 = SUBSTRING( @cDesc,21,40)
      SET @cOutField05 = CASE WHEN IsNULL(@cPPK, '') = '' THEN '0'  ELSE @cPPK END +
	                      '/' +
	                      CASE WHEN IsNULL(@cPQIndicator, '') = '' THEN '0' ELSE @cPQIndicator END
      SET @cOutField06 = @cOutField06
      SET @cOutField07 = @cOutField07
      SET @cOutField08 = @cOutField08
      SET @cOutField09 = @cOutField09
      SET @cOutField10 = CAST( @nQTY AS NVARCHAR( 5))
      SET @cOutField11 = RTRIM(CAST( @cCartonCnt AS NVARCHAR( 4))) + CASE WHEN @cSkipEstUCCOnID = '1' THEN '' ELSE '/' + CAST( @cTotalCarton AS NVARCHAR( 4)) END -- (ChewKP02)

      -- Go to previous screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END

   Step_8_Quit:
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
            --2024-06-18 4.5  Ung     WMS-25618 Fix ExtInfoSP @nStep at step 8
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @nMobile, @nFunc, @cLangCode, 8, @nStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04
               ,@cUCC, @cSKU, @nQTY, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption, @cExtendedInfo OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END
   END

   IF @cExtScnSP <> ''
   BEGIN
      GOTO Step_99
   END

   GOTO Quit

   Step_8_Fail:
   BEGIN
      SET @cOutField02 = '' --sku
      SET @cOutField03 = RTRIM(CAST( @cCartonCnt AS NVARCHAR( 4))) + CASE WHEN @cSkipEstUCCOnID = '1' THEN '' ELSE '/' + CAST( @cTotalCarton AS NVARCHAR( 4)) END -- (ChewKP02)
   END
END
GOTO Quit

/********************************************************************************
Step 9. (screen = 1308) UCC, SKU/UPC
   UCC:        (field01)
   Counter:    (field11) --99/99
   SKU/UPC:    (field02)
   SKU Desc1:  (field03)
   SKU Desc2:  (field04)
   PPK/DU:     (field05)
   LOTTABLE 1/2/3/4:
   Lottable01  (field06)
   Lottable02  (field07)
   Lottable03  (field08)
   Lottable04  (field09)
   QTY:        (field10, input)
********************************************************************************/
Step_9:
BEGIN
   IF @nInputKey = 1      -- ENTER
   BEGIN
      DECLARE @cQTY NVARCHAR( 10)

      --screen mapping
      SET @cQty = CASE WHEN @cFieldAttr10 = 'O' THEN @cOutField10 ELSE @cInField10 END

      --check if qty is null
      IF @cQty = '' OR @cQty IS NULL
      BEGIN
         SET @nErrNo = 63145
         SET @cErrMsg = rdt.rdtgetmessage(63145, @cLangCode, 'DSP') --QTY required
         GOTO Step_9_Fail
      END

      --check if qty is valid
      IF rdt.rdtIsValidQty(@cQty, 1) = 0
      BEGIN
         SET @nErrNo = 63146
         SET @cErrMsg = rdt.rdtgetmessage(63146, @cLangCode, 'DSP') --Invalid Qty
         GOTO Step_9_Fail
      END

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'QTY', @cQty) = 0
      BEGIN
         SET @nErrNo = 63174
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty
         GOTO Step_9_Fail
      END

      SET @nQTY = CAST( @cQTY AS INT)

      --if UCCWithDynamicCaseCnt is setup = 0, casecnt must equal with qty
      IF UPPER(@cUCC) <> 'NOUCC'-- no effect on noucc
      BEGIN
         SET @cUCCWithDynamicCaseCnt = ''
         SELECT @cUCCWithDynamicCaseCnt = SValue
         FROM RDT.StorerConfig WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND ConfigKey = 'UCCWithDynamicCaseCnt'
         IF ISNULL(@cUCCWithDynamicCaseCnt,'0') = '0' --0=check against Pack.CaseCnt  1=Dynamic case count
         BEGIN
            -- Get case count
            SELECT @nCaseCntQty = Pack.CaseCnt
               FROM dbo.Sku Sku WITH (NOLOCK)
               JOIN dbo.Pack Pack WITH (NOLOCK) ON Sku.Packkey = Pack.Packkey
            WHERE Sku.Storerkey = @cStorerKey
               AND Sku.sku = @cSku

            --prompt error if @cQty <> @nCaseCntQty
            IF @nQTY <> @nCaseCntQty
            BEGIN
               SET @nErrNo = 63147
               SET @cErrMsg = rdt.rdtgetmessage( 63147, @cLangCode, 'DSP') --CaseCnt Diff
               GOTO Step_9_Fail
            END
         END
      END

      SET @cParam1 = ''
      SET @cParam2 = ''
      SET @cParam3 = ''
      SET @cParam4 = ''
      SET @cParam5 = ''

      -- Extended update SP
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               '  @nMobile, @nFunc, @nStep, @cLangCode, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04 ' +
               ' ,@cUCC, @cSKU, @nQTY, @cParam1 OUTPUT, @cParam2 OUTPUT, @cParam3 OUTPUT, @cParam4 OUTPUT, @cParam5 OUTPUT, @cOption ' +
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
               ' ,@cParam1     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam2     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam3     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam4     NVARCHAR( 20) OUTPUT ' +
               ' ,@cParam5     NVARCHAR( 20) OUTPUT ' +
               ' ,@cOption     NVARCHAR( 1)  ' +
               ' ,@nErrNo      INT       OUTPUT ' +
               ' ,@cErrMsg     NVARCHAR( 20) OUTPUT '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @nMobile, @nFunc, @nStep, @cLangCode, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04
               ,@cUCC, @cSKU, @nQTY, @cParam1 OUTPUT, @cParam2 OUTPUT, @cParam3 OUTPUT, @cParam4 OUTPUT, @cParam5 OUTPUT, @cOption
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT

            IF @nErrNo <> 0
               GOTO Step_9_Fail
         END
      END

      --prepare next screen variable
      SET @cOutField01 = @cParam1 -- Extra data 1
      SET @cOutField02 = @cParam2 -- Extra data 2
      SET @cOutField03 = @cParam3 -- Extra data 3
      SET @cOutField04 = @cParam4 -- Extra data 4
      SET @cOutField05 = @cParam5 -- Extra data 5

      SET @cFieldAttr10 = '' -- QTY

      --go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      IF @cFlowThruScreen ='1'
      BEGIN
         GOTO STEP_10
      END

   END

   IF @nInputKey = 0 -- Esc
   BEGIN
      SET @cOutField01 = @cUCC
      SET @cOutField02 = '' --sku
      SET @cOutField03 = RTRIM(CAST( @cCartonCnt AS NVARCHAR( 4))) + CASE WHEN @cSkipEstUCCOnID = '1' THEN '' ELSE '/' + CAST( @cTotalCarton AS NVARCHAR( 4)) END -- (ChewKP02)
      SET @cOutField04 = CAST( @nQTY AS NVARCHAR( 5))

      SET @cFieldAttr10 = '' -- QTY

      -- Go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   IF @cExtScnSP <> ''
   BEGIN
      GOTO Step_99
   END

   GOTO Quit

   Step_9_Fail:
   BEGIN
      SET @cOutField10 = @cQTY
   END

END
GOTO Quit

/********************************************************************************
Step 10. (screen = 1309) Extra Data
   Extra Data 1: (field01)
   Extra Data 2: (field02)
   Extra Data 3: (field03)
   Extra Data 4: (field04)
   Extra Data 5: (field05)
********************************************************************************/
Step_10:
BEGIN
   IF @nInputKey = 1      -- ENTER
   BEGIN
      -- Screen mapping
      SET @cParam1 = @cInField01
      SET @cParam2 = @cInField02
      SET @cParam3 = @cInField03
      SET @cParam4 = @cInField04
      SET @cParam5 = @cInField05

      --set @cPokey value to blank when it is 'NOPO'
      SET @cPOKeyValue = CASE WHEN UPPER(@cPOkey) = 'NOPO' THEN '' ELSE @cPOkey END

      --set @cPOKeyDefaultValue to 1 when it is 'NOPO'
      SET @cPOKeyDefaultValue = CASE WHEN UPPER(@cPOkey) = 'NOPO' THEN '1' ELSE '0' END

      --set @cTempAddNewUCC to 1 when it is allowed to add new ucc
      SET @cTempAddNewUCC = CASE WHEN @cReceiveAllowAddNewUCC in ('1','2') THEN '1' ELSE '0' END

      --set @cTempUCC to blank when it is 'NOUCC'
      SET @cTempUCC = CASE WHEN UPPER(RTRIM(@cUCC)) = 'NOUCC' THEN '' ELSE @cUCC END

      -- Extended update SP

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
               GOTO Step_10_Fail
         END
      END

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

      IF @cUCC <> '' AND @cUCC <> 'NOUCC' AND @cUCCWithMultiSKU = '1'
      BEGIN
         SET @cSKU = ''
         SET @nQTY = 0
         SET @nNewUCCWithMultiSKURcv = 1

         --prepare next screen var
         SET @cOutField01 = @cUCC
         SET @cOutField02 = '' --sku
         SET @cOutField03 = RTRIM(CAST( @cCartonCnt AS NVARCHAR( 4))) + CASE WHEN @cSkipEstUCCOnID = '1' THEN '' ELSE '/' + CAST( @cTotalCarton AS NVARCHAR( 4)) END -- (ChewKP02)
         SET @cOutField04 = '' -- QTY

         -- Go to SKU screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
      END
      ELSE
      BEGIN
         --increase carton count by one if it is not loose qty
         IF UPPER(@cUCC) <> 'NOUCC'
            SET @cCartonCnt = Convert(char,Cast( @cCartonCnt as Int) + 1 )

         SET @cOutField11 = RTRIM(CAST( @cCartonCnt AS NVARCHAR( 4))) + CASE WHEN @cSkipEstUCCOnID = '1' THEN '' ELSE '/' + CAST( @cTotalCarton AS NVARCHAR( 4)) END -- (ChewKP02)

         --go to UCC screen
         SET @cOutField10 = ''
         SET @nScn = @nScn - 4
         SET @nStep = @nStep - 4
      END
   END

   IF @nInputKey = 0 -- Esc
   BEGIN
      --prepare previous screen
      SET @cOutField01 = @cUCC
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cDesc,  1, 20)
      SET @cOutField04 = SUBSTRING( @cDesc, 21, 20)
      SET @cOutField05 = CASE WHEN IsNULL(@cPPK, '') = '' THEN '0'  ELSE @cPPK END +
	                      '/' +
	                    CASE WHEN IsNULL(@cPQIndicator, '') = '' THEN '0' ELSE @cPQIndicator END
      SET @cOutField06 = @cOutField06
      SET @cOutField07 = @cOutField07
      SET @cOutField08 = @cOutField08
      SET @cOutField09 = @cOutField09
      SET @cOutField10 = CAST( @nQTY AS NVARCHAR( 5))
      SET @cOutField11 = RTRIM(CAST( @cCartonCnt AS NVARCHAR( 4))) + CASE WHEN @cSkipEstUCCOnID = '1' THEN '' ELSE '/' + CAST( @cTotalCarton AS NVARCHAR( 4)) END -- (ChewKP02)

      IF @cDisableQTYField = '1'
         SET @cFieldAttr10 = 'O'

      -- Go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

   END

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
             @nMobile, @nFunc, @cLangCode, 6, @nStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04
            ,@cUCC, @cSKU, @nQTY, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption, @cExtendedInfo OUTPUT
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT

         SET @cOutField15 = @cExtendedInfo
      END
   END
   GOTO Quit

   Step_10_Fail:
END
GOTO Quit

/********************************************************************************
Step 11. (screen = 1310) Not all ucc received. Esc anyway?
   Not all ucc received.
   ESC anyway?
   1=YES
   2=NO
   OPTION: (field01, input)
********************************************************************************/
Step_11:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      --screen mapping
      SET @cOption = @cInField01

      --check if option is blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 63160
         SET @cErrMsg = rdt.rdtgetmessage( 63160, @cLangCode, 'DSP') --Option required
         GOTO Step_11_Fail
      END

      --prompt error msg if option is not '1' or '2'
      IF (@cOption <> '1' AND @cOption <> '2')
	   BEGIN
         SET @cErrMsg = rdt.rdtgetmessage(63148, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_11_Fail
      END

      IF @cOption = '1'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cTempLottable01
         SET @cOutField02 = @cTempLottable02
         SET @cOutField03 = @cTempLottable03
         SET @cOutField04 = @cTempLottable04

         -- Go to lottable screen
         SET @nScn = @nScn - 6
         SET @nStep = @nStep - 6

         IF @cSkipLottable01 = '1' AND @cSkipLottable02 = '1' AND @cSkipLottable03 = '1' AND @cSkipLottable04 = '1'
         BEGIN
            -- Prepare prev screen var
            SET @cOutField01 = @cReceiptKey
            SET @cOutField02 = @cPOKey
            SET @cOutField03 = @cLOC
            SET @cOutField04 = @cTOID
            SET @cOutField05 = @cTotalCarton

            IF @cSkipEstUCCOnID = '1'
               SET @cFieldAttr05 = 'O'

            -- Go to estimate UCC on ID screen
            SET @nScn = @nScn - 1
            SET @nStep = @nStep - 1
         END
         GOTO Step_11_Quit
      END
   END

   --prepare previous screen
   SET @cOutField01 = '' --ucc
   SET @cOutField02 = @cSKU
   SET @cOutField03 = SUBSTRING( @cDesc,  1, 20)
   SET @cOutField04 = SUBSTRING( @cDesc, 21, 20)
   SET @cOutField05 = CASE WHEN IsNULL(@cPPK, '') = '' THEN '0'  ELSE @cPPK END +
                      '/' +
                      CASE WHEN IsNULL(@cPQIndicator, '') = '' THEN '0' ELSE @cPQIndicator END
   SET @cOutField06 = @cOutField06
   SET @cOutField07 = @cOutField07
   SET @cOutField08 = @cOutField08
   SET @cOutField09 = @cOutField09
   SET @cOutField10 = CAST( @nQTY AS NVARCHAR( 5))
   SET @cOutField11 = RTRIM(CAST( @cCartonCnt AS NVARCHAR( 4))) + CASE WHEN @cSkipEstUCCOnID = '1' THEN '' ELSE '/' + CAST( @cTotalCarton AS NVARCHAR( 4)) END -- (ChewKP02)

   --go to UCC screen
   SET @nScn = @nScn - 5
   SET @nStep = @nStep - 5

   Step_11_Quit:
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
                @nMobile, @nFunc, @cLangCode, 6, @nStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04
               ,@cUCC, @cSKU, @nQTY, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption, @cExtendedInfo OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END
   END

   IF @cExtScnSP <> ''
   BEGIN
      GOTO Step_99
   END

   GOTO Quit

   Step_11_Fail:
   BEGIN
      SET @cOutField01 = '' --option
      SET @cOption = ''
   END

END
GOTO Quit

/********************************************************************************
Step 12. (screen = 1311) Close pallet?
   Close pallet?
   1 = NO
   2 = YES
   3 = YES AND PUTAWAY
   OPTION: (field01, input)
********************************************************************************/
Step_12:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cCountUCC NVARCHAR(2)

      --screen mapping
      SET @cOption = @cInField01
      SET @cCountUCC = @cInField02

      --check if option is blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 63166
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option required
         GOTO Quit
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '2', '3')
	   BEGIN
	      SET @nErrNo = 63167
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         SET @cOutField01 = '' --option
         SET @cOption = ''
         GOTO Quit
      END

      -- Close pallet
      IF @cOption IN ('2', '3') -- 2=YES, 3=YES AND PUTAWAY
      BEGIN
         -- Check UCC count
         IF @cClosePalletCountUCC = '1'
         BEGIN
            -- Check count valid
            IF rdt.rdtIsValidQTY( @cCountUCC, 1) = 0  --1=Validate zero
            BEGIN
               SET @nErrNo = 63150
               SET @cErrMsg = rdt.rdtgetmessage(63134, @cLangCode, 'DSP') --Invalid QTY
               GOTO Quit
            END

            -- Count UCC on pallet
            DECLARE @nCountUCConID INT
            SELECT @nCountUCConID = COUNT( DISTINCT UCCNo)
            FROM UCC WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND ID = @cToID

            -- Check UCC on ID
            IF CAST( @cCountUCC AS INT) <> @nCountUCConID
            BEGIN
               SET @nErrNo = 63162
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong count
               GOTO Quit
            END
         END

         -- Update DropID
         UPDATE DropID SET Status = '9' WHERE DropID = @cToID
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 63168
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DID Fail
            GOTO Quit
         END

         -- Extended update SP
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  '  @nMobile, @nFunc, @nStep, @cLangCode, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04 ' +
                  ' ,@cUCC, @cSKU, @nQTY ,@cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption ' +
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
                  GOTO Quit
            END
         END

         -- EventLog
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
            @cRefNo1       = 'CLOSE'
      END

      IF @cExtScnSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
         BEGIN
            DELETE FROM @tExtScnData
            INSERT INTO @tExtScnData (Variable, Value) VALUES
            ('@cReceiptKey',  @cReceiptKey),
            ('@cPOKey',  @cPOKey),
            ('@cLOC',  @cLOC),
            ('@cToID',  @cToID),
            ('@cUCC',  @cUCC),
            ('@cSKU',  @cSKU),
            ('@cQTY',  CONVERT(VARCHAR(20),@nQTY)),         --cast
            ('@cParam1',  @cParam1),
            ('@cParam2',  @cParam2),
            ('@cParam3',  @cParam3),
            ('@cParam4',  @cParam4),
            ('@cParam5',  @cParam5),
            ('@cOption',  @cOption)

            EXECUTE [RDT].[rdt_ExtScnEntry]
            @cExtScnSP,
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

            /*
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedScreenSP) +
               '  @nMobile, @nFunc, @cLangCode, @nStep OUTPUT, @nScn OUTPUT, @nInputKey, @cFacility, @cStorerKey ' +
               ' ,@cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04 ' +
               ' ,@cUCC, @cSKU, @nQTY, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption ' +
               ' ,@cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT ' +
               ' ,@cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT ' +
               ' ,@cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT ' +
               ' ,@cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT ' +
               ' ,@cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT ' +
               ' ,@cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT ' +
               ' ,@cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT ' +
               ' ,@cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT ' +
               ' ,@cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT ' +
               ' ,@cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT ' +
               ' ,@cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT ' +
               ' ,@cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT ' +
               ' ,@cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT ' +
               ' ,@cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT ' +
               ' ,@cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT ' +
               ' ,@nErrNo   OUTPUT ' +
               ' ,@cErrMsg  OUTPUT '
            SET @cSQLParam = +
               '  @nMobile     INT           ' +
               ' ,@nFunc       INT           ' +
               ' ,@cLangCode   NVARCHAR( 3)  ' +
               ' ,@nStep       INT OUTPUT    ' +
               ' ,@nScn        INT OUTPUT    ' +
               ' ,@nInputKey   INT           ' +
               ' ,@cFacility   NVARCHAR( 5)  ' +
               ' ,@cStorerKey  NVARCHAR( 15) ' +
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
               ' ,@cInField01  NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT ' +
               ' ,@cInField02  NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT ' +
               ' ,@cInField03  NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT ' +
               ' ,@cInField04  NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT ' +
               ' ,@cInField05  NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT ' +
               ' ,@cInField06  NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT ' +
               ' ,@cInField07  NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT ' +
               ' ,@cInField08  NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT ' +
               ' ,@cInField09  NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT ' +
               ' ,@cInField10  NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT ' +
               ' ,@cInField11  NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT ' +
               ' ,@cInField12  NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT ' +
               ' ,@cInField13  NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT ' +
               ' ,@cInField14  NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT ' +
               ' ,@cInField15  NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT ' +
               ' ,@nErrNo      INT       OUTPUT ' +
               ' ,@cErrMsg     NVARCHAR( 20) OUTPUT '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                @nMobile, @nFunc, @cLangCode, @nStep OUTPUT, @nScn OUTPUT, @nInputKey, @cFacility, @cStorerKey
               ,@cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04
               ,@cUCC, @cSKU, @nQTY, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption
               ,@cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT
               ,@cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT
               ,@cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT
               ,@cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT
               ,@cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT
               ,@cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT
               ,@cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT
               ,@cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT
               ,@cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT
               ,@cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT
               ,@cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT
               ,@cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT
               ,@cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT
               ,@cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT
               ,@cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT
            */
            IF @nErrNo <> 0
               GOTO Quit

            IF @nStep = 99
               GOTO Quit
         END
      END

      -- Close pallet
      IF @cOption IN ('2', '3') -- 2=YES, 3=YES AND PUTAWAY
      BEGIN
         -- Prepare next screen
         SET @cToID = ''
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @cPOKey
         SET @cOutField03 = @cLOC
         SET @cOutField04 = ''
         SET @cFieldAttr02 = '' -- Count UCC

         -- Go to ID screen
         SET @nScn = @nScn - 9
         SET @nStep = @nStep - 9

         GOTO Step_12_Quit
      END
   END

   -- prepare previous screen
   SET @cOutField01 = '' --ucc
   SET @cOutField02 = @cSKU
   SET @cOutField03 = SUBSTRING( @cDesc,  1, 20)
   SET @cOutField04 = SUBSTRING( @cDesc, 21, 20)
   SET @cOutField05 = CASE WHEN IsNULL(@cPPK, '') = '' THEN '0'  ELSE @cPPK END +
                      '/' +
                      CASE WHEN IsNULL(@cPQIndicator, '') = '' THEN '0' ELSE @cPQIndicator END
   SET @cOutField06 = @cOutField06
   SET @cOutField07 = @cOutField07
   SET @cOutField08 = @cOutField08
   SET @cOutField09 = @cOutField09
   SET @cOutField10 = CAST( @nQTY AS NVARCHAR( 5))
   SET @cOutField11 = RTRIM(CAST( @cCartonCnt AS NVARCHAR( 4))) + CASE WHEN @cSkipEstUCCOnID = '1' THEN '' ELSE '/' + CAST( @cTotalCarton AS NVARCHAR( 4)) END -- (ChewKP02)
   SET @cFieldAttr02 = '' -- Count UCC

   -- go to UCC screen
   SET @nScn = @nScn - 6
   SET @nStep = @nStep - 6

   Step_12_Quit:
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
                @nMobile, @nFunc, @cLangCode, 6, @nStep, @nInputKey, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04
               ,@cUCC, @cSKU, @nQTY, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @cOption, @cExtendedInfo OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT

            SET @cOutField15 = @cExtendedInfo
         END
      END
   END

   IF @cExtScnSP <> ''
   BEGIN
      GOTO Step_99
   END

END
GOTO Quit

/********************************************************************************
Step 10. Screen = 3950. Verify SKU
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
Step_13:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Update SKU setting
      EXEC rdt.rdt_VerifySKU_V7 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, '', 'UPDATE',
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

      -- Prepare prev screen var
      SET @cOutField01 = @cUCC

      -- Go back to SKU screen
      SET @nScn = @nFromScn
      SET @nStep = @nStep - 5
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
      SET @cOutField01 = @cUCC

      -- Go back to SKU screen
      SET @nScn = @nFromScn
      SET @nStep = @nStep - 5
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
Step 99. Scn = Customize
********************************************************************************/
Step_99:
BEGIN
   IF @cExtScnSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
      BEGIN
         DECLARE @nStepBak INT
         DECLARE @nScnBak INT
         SELECT @nStepBak = @nStep, @nScnBak = @nScn, @nErrNo=0, @cErrMsg=''
         DELETE FROM @tExtScnData
         INSERT INTO @tExtScnData (Variable, Value) VALUES
         ('@cReceiptKey',  @cReceiptKey),
         ('@cPOKey',  @cPOKey),
         ('@cLOC',  @cLOC),
         ('@cToID',  @cToID),
         ('@cUCC',  @cUCC),
         ('@cSKU',  @cSKU),
         ('@cQTY',  CONVERT(VARCHAR(20),@nQTY)),         --cast
         ('@cParam1',  @cParam1),
         ('@cParam2',  @cParam2),
         ('@cParam3',  @cParam3),
         ('@cParam4',  @cParam4),
         ('@cParam5',  @cParam5),
         ('@cOption',  @cOption)

         EXECUTE [RDT].[rdt_ExtScnEntry]
         @cExtScnSP,
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

         IF @cExtScnSP = 'rdt_898ExtScn02' AND @nInputKey = 1
            BEGIN
               IF @nStepBak = 99
                  BEGIN
                     SET @cUCC = @cUDF01
                     SET @nQTY = CAST(@cUDF02 AS INT)
                     SET @nCaseCntQty = CAST(@cUDF03 AS INT)
                     SET @nCnt = CAST(@cUDF04 AS INT)
                     SET @cReceiveAllowAddNewUCC = @cUDF05
                  END
               ELSE IF @nStepBak = 10
                  BEGIN
                     SET @cCartonCnt = @cUDF01
                  END
            END

         IF @nErrNo <> 0
            BEGIN
               GOTO Step_99_Fail
            END
      END
   END
   GOTO Quit
   Step_99_Fail:
   BEGIN
      GOTO Quit
   END
END

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func = @nFunc,
      Step = @nStep,
      Scn = @nScn,

      Printer_Paper  = @cPaperPrinter,   --(cc01)
      Printer        = @cLabelPrinter,    --(cc01)

      V_Receiptkey = @cReceiptkey,
      V_POKey = @cPOKey,
      V_LOC = @cLOC,
      V_ID  = @cTOID,
      V_SKU = @cSKU,
      V_UOM = @cUOM,
      V_UCC = @cUCC,
      V_SkuDescr = @cDesc,


      V_String1 = @cPOKeyDefaultValue,
      V_String2 = @cTotalCarton,
      V_String3 = @cCartonCnt,
      V_String6 = @cPackKey,
      V_String8 = @cPQIndicator,
      V_String9 = @cPPK,
      V_String12 = @cTempLottable01,
      V_String13 = @cTempLottable02,
      V_String14 = @cTempLottable03,
      V_String15 = @cTempLottable04,
      V_String16 = @cUCCWithMultiSKU,
      V_String17 = @cReceiveAllowAddNewUCC,

      V_Integer1 = @nQTY,
      V_Integer2 = @nCaseCntQty,
      V_Integer3 = @nCnt,
      V_Integer4 = @nFromScn,
      V_Integer5 = @nNewUCCWithMultiSKURcv,

      V_String18 = @cCheckPOUCC, -- Vicky01
      V_String19 = @cExtendedUpdateSP,
      V_String20 = @cUCCExtValidate,
      V_String21 = @cClosePallet,
      V_String22 = @cSkipEstUCCOnID,

      V_String23 = @cSkipLottable01,
      V_String24 = @cSkipLottable02,
      V_String25 = @cSkipLottable03,
      V_String26 = @cSkipLottable04,
      V_String27 = @cDispStyleColorSize,
      V_String28 = @cClosePalletCountUCC,
      V_String29 = @cExtendedValidateSP,
      V_String30 = @cDisableQTYField,
      V_String31 = @cExtendedInfoSP,
      V_String32 = @cExtendedInfo,
      V_String33 = @cUCCLabel,  --(cc01)
      V_String34 = @cMultiUCC,
      V_String35 = @cDecodeSP,
      V_String36 = @cDecodeQty,
      V_String37 = @cVerifySKU,
      V_String38 = @cUserDefine08,
      V_String39 = @cUserDefine09,
      V_String40 = @cFlowThruScreen,
      V_String41 = @cExtScnSP,

      V_Lottable01 = @cLottable01,
      V_Lottable02 = @cLottable02,
      V_Lottable03 = @cLottable03,
      V_Lottable04 = @dLottable04,
      V_Lottable05 = @dLottable05,

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