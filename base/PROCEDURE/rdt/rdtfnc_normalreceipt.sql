SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_NormalReceipt                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: normal receipt                                              */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2005-05-19 1.0  UngDH    Created                                     */
/* 2006-02-25 1.1  UngDH    SOS46172 Handle some of the SKU field pump  */
/*                          into EXceed as NULL                         */
/* 2006-02-25 1.2  UngDH    SOS46227 SKU desc contain special chars that*/
/*                          can't be parse by XML if without translation*/
/* 2006-04-14 1.3  UngDH    Added NOLOCK, ROWLOCK                       */
/* 2006-06-20 1.4  UngDH    SOS45953 Lottable05 RCP_DATE customization  */
/* 2007-01-18 1.5  UngDH    SOS57609 Support Julian Date lottables      */
/* 2007-05-21 1.6  MaryVong SOS76264 Add storer configkey               */
/*                          "ReceivingPOKeyDefaultValue". And, if       */
/*                          POKey="NOPO", disable auto-retrieval POKey  */
/* 2007-07-10 1.7  Vicky    SOS80652 Add configkey "RDTAddSKUtoASN" to  */
/*                          allow adding SKU thats not exists in ASNDet */
/*                          also add new Option Screen to confirm add   */
/* 2007-08-03 1.8  FKLIM    Add ConfigKey 'PrePackByBOM'                */
/* 2007-09-17 1.9  Vicky    Bug fixing for PrepackByBOM                 */
/* 2007-09-20 1.10  Vicky    Fixing the SKU display when ESC from Qty scn*/
/* 2007-11-22 1.11 Vicky    SOS#92327 - To parse in lowest UOM value for*/
/*                          componentSKU instead of Parentsku           */
/* 2007-11-28 1.12 Vicky    SOS#81879 - Add generic Lottable_Wrapper    */
/* 2008-01-11 1.13 Ricky    Add a SELECT statement to retrieve SKU CODE */
/*                          for Add new SKU screen                      */
/* 2008-10-15 1.14 James    SOS87607 - On ASN/PO screen, only need to   */
/*                          clear the field with error                  */
/* 2008-11-03 1.15 Vicky    Remove XML part of code that is used to     */
/*                          make field invisible and replace with new   */
/*                          code (Vicky02)                              */
/* 2009-04-07 1.16 James    Bug fix (james01)                           */
/* 2009-04-07 1.17 Vicky    SOS#131462 - Add in Pallet Label Printing   */
/*                          Option Screen and Auto generate Pallet ID   */
/*                          (Vicky03)                                   */
/* 2009-04-21 1.18 Vicky    SOS#105912 - Go back to PLTID screen after  */
/*                          SKU received, to cater for Pallet Receiving */
/*                          (Vicky04)                                   */
/* 2009-05-26 1.19 Vicky    SOS#137512 - Check scanned Pallet ID against*/
/*                          ReceiptDetail (Vicky05)                     */
/* 2009-06-01 1.20 James    Change sourcekey of wrapper to receiptkey + */
/*                          receiptlinenumber (james02)                 */
/* 2009-07-17 1.21 Larry    SOS#142591 - Use UPC packkey to validate    */
/*                          Pack UOM instead of SKU (Lau001)            */
/* 2009-07-20 1.22 GTGoh    SOS#142253 - Include Verify PackKey Screen  */
/* 2009-08-19 1.23 Vicky    Add in EventLog (Vicky06)                   */
/* 2010-03-15 1.24 Vanessa  SOS#164544 Allow QTY in decimal and         */
/*                          DefaultLOC -- (Vanessa01)                   */
/* 2010-07-02 1.25 Vicky    SOS#178988 - Display Lottable03 although    */
/*                          Lottable03Label not setup (Vicky07)         */
/* 2010-08-12 1.26 Larry    SOS#178988 - Check Lottable03 =0 instead    */
/*                          of blank value    (Larry01)                 */
/* 2010-08-13 1.27 James    If config 'NotAllowMultiCompSKUPLT' turn on */
/*                          then go back pallet id screen for every sku */
/*                          scan (james03)                              */
/* 2010-08-30 1.28 James    If SKU not in PO (if POKey keyed in) then   */
/*                          not allowed to key in (james04)             */
/* 2010-10-13 1.29 Shong    Initialise V_xx at Step 0 (Shong01)         */
/* 2010-10-28 1.30 James    Fix Lottable05 error (james05)              */
/* 2010-11-01 1.31 ChewKP   SOS#189788 Allow MultiPO in 1 ASN (ChewKP01)*/
/* 2011-01-21 1.32 James    Allow retrieve SKU by UPC/ALTSKU (james06)  */
/* 2011-01-27 1.33 James    Fix display issue on Lot04 & Lot05 (james07)*/
/* 2011-02-09 1.34 James    SOS160310 - Add PalletID checking (james08) */
/*                                    - Add in new Qty screen           */
/* 2011-02-25 1.35 ChewKP   Bug Fixes (ChewKP02)                        */
/* 2011-03-23 1.36 Audrey   SOS209491 - Configkey "RDTAddSKUtoASN" = 0  */
/*                          check on receiptdetail.sku not exist then   */
/*                          prompt error message                (ang01) */
/* 2011-03-11 1.37 ChewKP   SOS#205437 Display PackInfo (ChewKP03)      */
/* 2011-03-17 1.38 ChewKP   SOS#205621 Skip Lottable04 Validation       */
/*                          (ChewKP04)                                  */
/* 2011-03-25 1.39 Ung      SOS# 209097 - Implement storer config       */
/*                          ASNReceiptLocBasedOnFacility                */
/* 2011-04-06 1.40 James    No need to show lottables if no pre/post    */
/*                          setup (james08)                             */
/* 2010-12-16 1.41 Chew     SOS# 198689 - Default UOM by SKUConfig =    */
/*                          RDTDefaultUOM  (ChewKP05)                   */
/* 2011-04-26 1.42 Leong    SOS# 213546 - Bug Fix                       */
/* 2012-07-23 1.43 James    Bug fix on AutoGenID (james03)              */
/* 2012-10-30 1.44 audrey   SOS259895 - RESET @cInField10 = ''   (ang02)*/
/* 2012-11-23 1.45 ChewKP   Performance Tuning (ChewKP06)               */
/* 2012-12-05 1.46 James    SOS263772 Add TOID to SKU screen (james09)  */
/* 2013-04-22 1.47 James    SOS275767 - Bug fix on AutoGenID (james10)  */
/* 2013-06-14 1.48 ChewKP   SOS#281026  - Fixes on NOPO, Remove ID      */
/*                          Outfield when ESC (ChewKP07)                */
/* 2013-08-23 1.49 ChewKP   SOS#287338 - Codelkup Priority by Storerkey */
/*                          (ChewKP08)                                  */
/* 2013-11-18 1.50 ChewKP   SOS#294699 - Bug Fix (ChewKP09)             */
/* 2014-03-07 1.51 James    Bug fix (james11)                           */
/* 2014-03-25 1.52 James    SOS306408 Default cursor @ QTY field        */
/*                                    & Lottable field (james12)        */
/* 2014-03-25 1.53 James    SOS305458 Default SKU if 1 pallet 1 SKU     */
/*                          (james13)                                   */
/* 2014-04-21 1.54 James    SOS308816 Add decode @ SKU screen (james14) */
/* 2014-04-24 1.55 James    SOS308961-Get correct codelkup for lottable */
/* 2014-04-08 1.56 James    SOS306942-Clear Plt ID after print label    */
/*                          Add generic built print job (james15)       */
/* 2014-06-04 1.57 James    Add customized confirm receipt sp (james16) */
/*                          Extend Lottable01-03                        */
/* 2014-07-01 1.58 James    SOS315152 -                                 */
/*                          1. When add new sku, clear the lottables    */
/*                          before proceed next screen (james17)        */
/*                          2. Fix wrongly display SKU as Option        */
/*                          3. When finish receive 1 SKU, if go back ID */
/*                          screen and AutoGenID turn on then need      */
/*                          default next ID                             */
/* 2014-08-07 1.59 Ung      SOS317798 Add VerifySKU                     */
/* 2014-09-08 1.60 Ung      SOS320350 Add VerifySKUInfo                 */
/* 2014-10-09 1.61 SPChin	 SOS315152 - Bug Fixed                       */
/* 2014-11-26 1.62 Ung      SOS326375 Add ExtendedUpdateSP, chg params  */
/*                          Add GetReceiveInfoSP                        */
/* 2015-06-03 1.63 Leong    SOS# 339480 - Initialize variables.         */
/* 2015-05-18 1.64 ChewKP   SOS#341736 - Add ASNStatus CANC validation  */
/*                          (ChewKP10)                                  */
/* 2015-09-02 1.65 Ung      SOS351302 Add printing NoOfCopy param       */
/* 2016-09-30 1.66 Ung      Performance tuning                          */
/* 2017-01-24 1.67 Ung      Fix recompile due to date format different  */
/* 2017-10-11 1.68 SPChin   IN00488160-Add Filter by Function ID & Fixed*/
/* 2018-02-27 1.69 JHTAN    INC0142355-ByPass PODetail check if scan 2nd*/
/*                          time (JHTAN01)                              */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtfnc_NormalReceipt] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 NVARCHAR max
) AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cChkFacility NVARCHAR( 5),
   @b_Success    INT,
   @n_err        INT,
   @c_errmsg     NVARCHAR( 250),
   @nI           INT,
   @fQTY         FLOAT,
   @cXML         NVARCHAR( 4000), -- To allow double byte data for e.g. SKU desc
   @nPKQTY       INT, -- SOS#142253
   @nPKUOM       NVARCHAR(10), -- SOS#142253
   @cNoOfCopy    NVARCHAR(5)

-- Session variable
DECLARE
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 20),
   @cSku_scan    NVARCHAR( 20), -- Added by Ricky on Jan 11th to store the pass in sku
   @cSKU         NVARCHAR( 20),
   @cUOM         NVARCHAR( 10),
   @cID          NVARCHAR( 18),
   @cSKUDesc     NVARCHAR( 60),
   @cQTY         NVARCHAR( 10),
   @nQTY         INT,
   @cPackQTY     NVARCHAR( 10), -- SOS#142253
   @cPackUOM     NVARCHAR( 10), -- SOS#142253
   @cBaseUOM     NVARCHAR( 10), -- SOS#142253
   @cReasonCode  NVARCHAR( 10),
   @cIVAS        NVARCHAR( 20),
   @cLotLabel01  NVARCHAR( 20),
   @cLotLabel02  NVARCHAR( 20),
   @cLotLabel03  NVARCHAR( 20),
   @cLotLabel04  NVARCHAR( 20),
   @cLotLabel05  NVARCHAR( 20),
   @cLottable01  NVARCHAR( 60),     -- (james16)
   @cLottable02  NVARCHAR( 60),     -- (james16)
   @cLottable03  NVARCHAR( 60),     -- (james16)
   @cLottable04  NVARCHAR( 16),
   @cLottable05  NVARCHAR( 16),
   @cPackKey     NVARCHAR( 10),
   @cHasLottable NVARCHAR( 1),
   @cLottable05_Code NVARCHAR( 30),
   @cPOKeyDefaultValue NVARCHAR( 10), -- SOS76264
   @cAddSKUtoASN       NVARCHAR( 10), -- SOS80652
   @cOption            NVARCHAR( 1),  -- SOS80652
   @cExternPOKey       NVARCHAR( 20), -- SOS80652
   @cExternReceiptKey  NVARCHAR( 20), -- SOS80652
   @cExternLineNo      NVARCHAR( 20), -- SOS80652
   @cReceiptLineNo     NVARCHAR(  5), -- SOS80652
   @cPrefUOM           NVARCHAR(  1), -- SOS80652
   @cNewSKUFlag        NVARCHAR(  1), -- SOS80652
   @cAllowOverRcpt     NVARCHAR(  1), -- SOS80652
   @cPrePackByBOM      NVARCHAR( 10),
   @nCountSku          INT,
   @nTempCount         INT,
   @cComponentSku      NVARCHAR( 20),
   @cSkuCode           NVARCHAR( 20),
   @nComponentQty      INT,
   @nTotalQty          INT,
   @nDummy             INT,
   @nUOMQty            INT,
   @cUPCPackKey        NVARCHAR(10),
   @cUPCUOM            NVARCHAR(10),
   @cUPCSKU            NVARCHAR(30),
   @nASNExists         INT,
   @nPOExists          INT,
   @cSourcekey         NVARCHAR(15), -- SOS133226 (james02)
   @cRDTDefaultUOM     NVARCHAR(10),  -- (ChewKP05)
   @cASNStatus         NVARCHAR(10)   -- (ChewKP10)

DECLARE
   @cPackUOM1          NVARCHAR(10),
   @fCaseCnt           FLOAT,
   @cPackUOM2          NVARCHAR(10),
   @fInnerPack         FLOAT,
   @cPackUOM3          NVARCHAR(10),
   @fQtyUOM3           FLOAT,
   @cPackUOM4          NVARCHAR(10),
   @fPallet            FLOAT,
   @cPackUOM8          NVARCHAR(10),
   @fOtherUnit1        FLOAT

DECLARE
   @cWeight                 NVARCHAR( 10),
   @cCube                   NVARCHAR( 10),
   @cLength                 NVARCHAR( 10),
   @cWidth                  NVARCHAR( 10),
   @cHeight                 NVARCHAR( 10),
   @cInnerPack              NVARCHAR( 10),
   @cCaseCount              NVARCHAR( 10),
   @cPalletCount            NVARCHAR( 10),
   @cVerifySKUInfo          NVARCHAR( 20)

-- SOS#81879 (Start)
DECLARE  @cLottable01_Code NVARCHAR( 20),
     @cLottable02_Code     NVARCHAR( 20),
     @cLottable03_Code     NVARCHAR( 20),
     @cLottable04_Code     NVARCHAR( 20),
     @cLottableLabel       NVARCHAR( 20),
     @cTempLottable01      NVARCHAR( 18),
     @cTempLottable02      NVARCHAR( 18),
     @cTempLottable03      NVARCHAR( 18),
     @cTempLottable04      NVARCHAR( 16),
     @cTempLottable05      NVARCHAR( 16),
     @cListName            NVARCHAR( 20),
     @cShort               NVARCHAR( 10),
     @dLottable04          DATETIME,
     @dLottable05          DATETIME,
     @dTempLottable04      DATETIME,
     @dTempLottable05      DATETIME,
     @cStoredProd          NVARCHAR( 250),
     @nCountLot            INT
-- SOS#81879 (End)

-- SOS#131462 - Vicky03 (Start)
DECLARE @cPrevOp              NVARCHAR(5),
        @cScnOption           NVARCHAR(1),
        @cAutoGenID           NVARCHAR(1),
        @cPromptOpScn         NVARCHAR(1),
        @cReceivingPrintLabel NVARCHAR(1),
        @cPrintMultiLabel     NVARCHAR(1),
        @cPrintNoOfCopy       NVARCHAR(5),
        @cDataWindow          NVARCHAR(50),
        @cTargetDB            NVARCHAR(10),
        @cPrinter             NVARCHAR(10),
        @cUserName            NVARCHAR(18),
        @cReportType          NVARCHAR(10),
-- SOS#131462 - Vicky03 (End)
        @cPalletRecv          NVARCHAR(1), -- (Vicky04)
        @cCheckPLTID          NVARCHAR(1), -- (Vicky05)
        @cPromptVerifyPKScn   NVARCHAR(1), -- SOS#142253
        @cDefaultToLoc        NVARCHAR(20),  -- (Vanessa01)
        @nPOCount             INT,           -- (ChewKP01)
        @cMultiPOKey          NVARCHAR(10),  -- (ChewKP01)
        @nPOCountQty          INT,           -- (ChewKP01)
        @c_MultiPOKey         NVARCHAR(10),  -- (ChewKP01)
        @nQtyExpected         INT,           -- (ChewKP01)
        @nReceivedQty         INT,           -- (ChewKP01)
        @cMultiPOASN          NVARCHAR(1),   -- (ChewKP01)
        @nRecordCount         INT,           -- (ChewKP01)
        @cCheckPalletID_SP    NVARCHAR(20),  -- (james08)
        @cSQLStatement        NVARCHAR(2000),-- (james08)
        @cSQLParms            NVARCHAR(2000),-- (james08)
        @nValid               INT,           -- (james08)
        @cPUOM_Desc           NVARCHAR( 5),  -- (james08)
        @cMUOM_Desc           NVARCHAR( 5),  -- (james08)
        @nPUOM_Div            INT,           -- (james08)
        @cPQTY                NVARCHAR( 5),  -- (james08)
        @cMQTY                NVARCHAR( 5),  -- (james08)
        @nActQTY              INT,           -- (james08)
        @nPQTY                INT,           -- (james08)
        @nMQTY                INT            -- (james08)

DECLARE @cDisplayLot03        NVARCHAR(1) -- (Vicky07)

DECLARE @cRCVShowPackInfo     NVARCHAR(1),   -- (ChewKP03)
        @fMasterQty           FLOAT,         -- (ChewKP03)
        @fInnerPackQty        FLOAT,         -- (ChewKP03)
        @fCaseCntQty          FLOAT,         -- (ChewKP03)
        @cUOM1                NVARCHAR(10),  -- (ChewKP03)
        @cUOM2                NVARCHAR(10),  -- (ChewKP03)
        @cUOM3                NVARCHAR(10),  -- (ChewKP03)
        @cSKUPackkey          NVARCHAR(10),  -- (ChewKP03)
        @cConvertLottable04Format NVARCHAR(10), -- (ChewKP04)
        @dLottable04Format    DATETIME,         -- (ChewKP04)
        @cDecodeLabelNo       NVARCHAR( 20),    -- (james14)
        @cSSCC                NVARCHAR( 20)     -- (james14)
-- (james14)
DECLARE @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
        @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
        @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
        @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
        @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)
DECLARE
   @cSQL            NVARCHAR(MAX),
   @cSQLParam       NVARCHAR(MAX),
   @cO_ID           NVARCHAR( 18),
   @cO_SKU          NVARCHAR( 20),
   @nO_QTY          INT,
   @cO_UOM          NVARCHAR( 10),
   @cO_Lottable01   NVARCHAR( 18),
   @cO_Lottable02   NVARCHAR( 18),
   @cO_Lottable03   NVARCHAR( 18),
   @cO_Lottable04   NVARCHAR( 16),
   @cO_Lottable05   NVARCHAR( 16),
   @cExtendedInfo   NVARCHAR( 20),
   @cExtendedInfo2  NVARCHAR( 20),
   @cExtendedInfoSP NVARCHAR( 20),
   @cSP             NVARCHAR( 20),
   @cToID           NVARCHAR( 30),
   @nO_Scn          INT,
   @nO_Step         INT,
   @cExtendedUpdateSP       NVARCHAR(20),
   @cExtendedValidateSP     NVARCHAR(20),
   -- (james16)
   @nNOPOFlag      INT,
   @cReceiptLineNumberOutput  NVARCHAR( 5),
   @cRcptConfirm_SP           NVARCHAR( 20),
   @cDebug         NVARCHAR( 1),
   @cUCC           NVARCHAR( 20),
   @cUCCSKU        NVARCHAR( 20),
   @nUCCQTY        INT,
   @cCreateUCC     NVARCHAR( 1),
   @cSubreasonCode NVARCHAR( 10)

SET @cNewSKUFlag = 'N'
-- RDT.RDTMobRec variable
DECLARE
   @nFunc        INT,
   @nScn         INT,
   @nStep        INT,
   @cLangCode    NVARCHAR( 3),
   @nInputKey    INT,
   @nMenu        INT,

   @cStorer      NVARCHAR( 15),
   @cFacility    NVARCHAR( 5),

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

   @cStorer    = StorerKey,
   @cFacility  = Facility,
   @cPrinter   = Printer, -- (Vicky03)
   @cUserName  = UserName,-- (Vicky03)

   @cUOM       = V_UOM,
   @nQTY       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY, 5), 0) = 1 THEN LEFT( V_QTY, 5) ELSE 0 END,

   @cReceiptKey = V_Receiptkey, -- (Vicky02)
   @cPOKey      = V_POKey,      -- (Vicky02)
   @cLOC        = V_Loc,        -- (Vicky02)
   @cSKU        = V_SKU,        -- (Vicky02)
   @cID         = V_ID,         -- (Vicky02)
   @cSKUDesc    = V_SKUDescr,    -- (Vicky02)

   @cLottable01       = V_Lottable01, -- SOS#81879
   @cLottable02       = V_Lottable02, -- SOS#81879
   @cLottable03       = V_Lottable03, -- SOS#81879
   @cLottable04       = rdt.rdtFormatDate( V_Lottable04), -- SOS#81879
   @cLottable05       = rdt.rdtFormatDate( V_Lottable05), -- SOS#81879

   @cPOKeyDefaultValue = V_String1, -- SOS76264
   @cAddSKUtoASN       = V_String2, -- SOS80652
   @cExternPOKey       = V_String3, -- SOS80652
   @cExternLineNo      = V_String4, -- SOS80652
   @cExternReceiptKey  = V_String5, -- SOS80652
   @cReceiptLineNo     = V_String6, -- SOS80652
   @cPrefUOM           = V_String7, -- SOS80652
   @cNewSKUFlag        = V_String8, -- SOS80652
   @cAllowOverRcpt     = V_String9, -- SOS80652

   @cPrePackByBOM      = V_String10, -- FKLIM
   @cUPCPackKey        = V_String11, -- FKLIM
   @cUPCUOM            = V_String12, -- FKLIM
   @cUPCSKU            = V_String13, -- Vicky 20-Sept-2007

   @cLottable01_Code   = V_String14, -- SOS#81879
   @cLottable02_Code   = V_String15, -- SOS#81879
   @cLottable03_Code   = V_String16, -- SOS#81879
   @cLottable04_Code   = V_String17, -- SOS#81879
   @cLottable05_Code   = V_String18, -- SOS#81879

   @cReasonCode        = V_String20, -- (Vicky02)
   @cIVAS              = V_String21, -- (Vicky02)
   @cLotLabel01        = V_String22, -- (Vicky02)
   @cLotLabel02        = V_String23, -- (Vicky02)
   @cLotLabel03        = V_String24, -- (Vicky02)
   @cLotLabel04        = V_String25, -- (Vicky02)
   @cLotLabel05        = V_String26, -- (Vicky02)
   @cPackKey           = V_String27, -- (Vicky02)
   @cHasLottable       = V_String28, -- (Vicky02)

   @cPrevOp            = V_String29, -- (Vicky03)
   @cScnOption         = V_String30, -- (Vicky03)
   @cAutoGenID         = V_String31, -- (Vicky03)
   @cPromptOpScn       = V_String32, -- (Vicky03)
   @cReceivingPrintLabel = V_String33, -- (Vicky03)
   @cPrintMultiLabel   = V_String34, -- (Vicky03)
   @cPrintNoOfCopy     = V_String35, -- (Vicky03)
   @cPalletRecv        = V_String36, -- (Vicky04)
   @cPromptVerifyPKScn = V_String37, -- SOS#142253
   @cDefaultToLoc      = V_String38, -- (Vanessa01)
   @cQTY               = V_String39, -- (Vanessa01)
   @nPOCount           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String40, 5), 0) = 1 THEN LEFT( V_String40, 5) ELSE 0 END,  -- (ChewKP01)
   @cSSCC              = V_CaseID,    -- (james14)

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
   @cInField13 = I_Field13,  @cOutField13 = O_Field13,
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

FROM RDT.RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc IN (550, 551)  -- 550 for QTY, UOM; 551 for QTY, UOM (with Ctn & Ea)
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Func = 550. Menu
   IF @nStep = 1 GOTO Step_1   -- Scn = 951. ASN #
   IF @nStep = 2 GOTO Step_2   -- Scn = 952. LOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 953. PAL ID
   IF @nStep = 4 GOTO Step_4   -- Scn = 954. SKU
   IF @nStep = 5 GOTO Step_5   -- Scn = 955. QTY, UOM
   IF @nStep = 6 GOTO Step_6   -- Scn = 956. Lottable
   IF @nStep = 7 GOTO Step_7   -- Scn = 957. Msg
   IF @nStep = 8 GOTO Step_8   -- Scn = 958. Option -- SOS80652
   IF @nStep = 9 GOTO Step_9   -- Scn = 962. Option -- Vicky03
   IF @nStep = 10 GOTO Step_10 -- Scn = 963. Msg -- Vicky04
   IF @nStep = 11 GOTO Step_11 -- Scn = 964. Verify Packkey -- SOS#142253
   IF @nStep = 12 GOTO Step_12 -- Scn = 965. QTY, UOM (with Ctn & Ea)-- SOS#160310
   IF @nStep = 13 GOTO Step_13 -- Scn = 966. Verify SKU
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 550. Menu
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN
   -- SOS76264
   SET @cPOKeyDefaultValue = ''
   SET @cPOKeyDefaultValue = rdt.RDTGetConfig( 0, 'ReceivingPOKeyDefaultValue', @cStorer)

   IF (@cPOKeyDefaultValue = '0' OR @cPOKeyDefaultValue IS NULL)
      SET @cPOKeyDefaultValue = ''

   SET @cOutField02 = @cPOKeyDefaultValue

   SELECT @cPrefUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile


   SELECT @cAllowOverRcpt = sValue
   FROM dbo.StorerConfig WITH (NOLOCK)
   WHERE ConfigKey = 'Allow_OverReceipt'
   AND   Storerkey = @cStorer

   -- (Vicky03) - Start
   SET @cPrevOp = ''
   SET @cAutoGenID = ''
   SET @cAutoGenID = rdt.RDTGetConfig( @nFunc, 'AutoGenID', @cStorer) -- Parse in Function

   SET @cPromptOpScn = ''
   SET @cPromptOpScn = rdt.RDTGetConfig( @nFunc, 'PromptOptionScn', @cStorer) -- Parse in Function

   SET @cReceivingPrintLabel = ''
   SET @cReceivingPrintLabel = rdt.RDTGetConfig( @nFunc, 'ReceivingPrintLabel', @cStorer) -- Parse in Function

   SET @cPrintMultiLabel = ''
   SET @cPrintMultiLabel = rdt.RDTGetConfig( @nFunc, 'PrintMultiLabel', @cStorer) -- Parse in Function

   SET @cPrintNoOfCopy = '0'
   SET @cPrintNoOfCopy = rdt.RDTGetConfig( @nFunc, 'PrintNoOfCopy', @cStorer) -- Parse in Function
   -- (Vicky03) - End

   -- (Vicky04)
   SET @cPalletRecv = ''
   SET @cPalletRecv = rdt.RDTGetConfig( @nFunc, 'PalletRecv', @cStorer) -- Parse in Function

   -- SOS#142253 Start
   -- Prompt Option Screen if RDT StorerConfigkey = PromptVerifyPKScn turned on
   SET @cPromptVerifyPKScn = ''
   SET @cPromptVerifyPKScn = rdt.RDTGetConfig( @nFunc, 'PromptVerifyPKScn', @cStorer) -- Parse in Function

   -- (Vanessa01)
   SET @cDefaultToLoc = ''
   SET @cDefaultToLoc = rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorer) -- Parse in Function

   -- SOS#209097 start
   IF @cDefaultToLoc = '0' OR @cDefaultToLoc = '' -- Storer config ReceiveDefaultToLoc not turn on
   BEGIN
      DECLARE @c_authority NVARCHAR(1)
      SELECT @b_success = 0
      EXECUTE nspGetRight
         @cFacility,
         @cStorer,
         NULL, -- @cSKU
         'ASNReceiptLocBasedOnFacility',
         @b_success   OUTPUT,
         @c_authority OUTPUT,
         @n_err       OUTPUT,
         @c_errmsg    OUTPUT

      IF @b_success = '1' AND @c_authority = '1'
         SELECT @cDefaultToLoc = UserDefine04
         FROM Facility WITH (NOLOCK)
         WHERE Facility = @cFacility
   END
   -- SOS#209097 end

   -- (Vicky02) - Start
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
   -- (Vicky02) - End

    -- (Vicky06) EventLog - Sign In Function
    EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorer

   -- (Shong01) Initialise all variable when start...
   SET @cLotLabel01=''
   SET @cLotLabel02=''
   SET @cLotLabel03=''
   SET @cLotLabel04=''
   SET @cLotLabel05=''
   SET @cReceiptKey=''
   SET @cPOKey     =''
   SET @cLOC       =''
   SET @cSKU       =''
   SET @cUOM       =''
   SET @cID        =''

   -- Set the entry point
   SET @nScn = 951
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 951. ASN #, PO# screen
   ASN # (field01)
   PO # (field02)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cReceiptKey = @cInField01
      SET @cPOKey = @cInField02

      -- Validate at least one field must key-in
      IF (@cReceiptKey = '' OR @cReceiptKey IS NULL) AND
         (@cPOKey = '' OR @cPOKey IS NULL OR @cPOKey = 'NOPO') -- SOS76264
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 60401, @cLangCode, 'DSP') --'ASN / PO is required'
         GOTO Step_1_Fail
      END

      DECLARE @cChkReceiptKey NVARCHAR( 10)
      DECLARE @cReceiptStatus NVARCHAR( 10)
      DECLARE @cChkStorerKey NVARCHAR( 15)
      DECLARE @nRowCount INT

      -- Both ASN & PO keyed-in
      IF NOT (@cReceiptKey = '' OR @cReceiptKey IS NULL) AND
         NOT (@cPOKey = '' OR @cPOKey IS NULL) AND
         NOT (@cPOKey = 'NOPO') -- (ChewKP07)
      BEGIN
         -- Get the ASN
         SELECT
            @cChkFacility = R.Facility,
            @cChkStorerKey = R.StorerKey,
            @cChkReceiptKey = R.ReceiptKey,
            @cReceiptStatus = R.Status,
            @cASNStatus = R.ASNStatus -- (ChewKP10)
         FROM dbo.Receipt R WITH (NOLOCK)
            INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
         WHERE R.ReceiptKey = @cReceiptKey
            -- SOS76264
            -- AND RD.POKey = @cPOKey
            AND RD.POKey = CASE WHEN @cPOKey = 'NOPO' THEN RD.POKey ELSE @cPOKey END
            AND R.StorerKey = @cStorer
         SET @nRowCount = @@ROWCOUNT

         IF @nRowCount = 0
         BEGIN
            SET @nASNExists = 0
            SET @nPOExists = 0

            -- No row returned, either ASN or PO not exists
            IF EXISTS (SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK)
               WHERE StorerKey = @cStorer
                  AND ReceiptKey = @cReceiptKey)
            BEGIN
               SET @nASNExists = 1
            END

            IF EXISTS (SELECT 1 FROM dbo.RECEIPT R WITH (NOLOCK)
               JOIN dbo.RECEIPTDETAIL RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
               WHERE R.StorerKey = @cStorer
--                AND R.ReceiptKey = @cReceiptKey
                  AND RD.POKey = CASE WHEN @cPOKey = 'NOPO' THEN RD.POKey ELSE @cPOKey END)
            BEGIN
               SET @nPOExists = 1
            END

            -- Both ASN & PO also not exists
            IF (@nASNExists = 0 AND @nPOExists = 0)
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( 60446, @cLangCode, 'DSP') --'ASN&PONotExists'
               SET @cOutField01 = '' -- ReceiptKey
               SET @cOutField02 = '' -- POKey
               SET @cReceiptKey = ''
               SET @cPOKey = ''
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Quit
            END
            ELSE
            -- Only ASN not exists
            IF @nASNExists = 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( 60447, @cLangCode, 'DSP') --'ASN Not Exists'
               SET @cOutField01 = '' -- ReceiptKey
               SET @cOutField02 = @cPOKey -- POKey
               SET @cReceiptKey = ''
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Quit
            END
            ELSE
            -- Only PO not exists
            IF @nPOExists = 0
            BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 60448, @cLangCode, 'DSP') --'PO Not Exists'
               SET @cOutField01 = @cReceiptKey
               SET @cOutField02 = '' -- POKey
               SET @cPOKey = ''
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Quit
            END
         END
--             SET @cErrMsg = rdt.rdtgetmessage( 60402, @cLangCode, 'DSP') --'ASN / PO not exists'
--             EXEC rdt.rdtSetFocusField @nMobile, 1
--             GOTO Step_1_Fail
      END
      ELSE
         -- Only ASN # keyed-in (POKey = blank)
         IF (@cReceiptKey <> '' AND @cReceiptKey IS NOT NULL)
         BEGIN
            -- Validate whether ASN have multiple PO
            DECLARE @cChkPOKey NVARCHAR( 10)
            SELECT DISTINCT
               @cChkPOKey = RD.POKey,
               @cChkFacility = R.Facility,
               @cChkStorerKey = R.StorerKey,
               @cReceiptStatus = R.Status,
               @cASNStatus = R.ASNStatus -- (ChewKP10)
            FROM dbo.Receipt R WITH (NOLOCK)
               INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
            WHERE RD.ReceiptKey = @cReceiptKey
               AND RD.StorerKey = @cStorer
            -- If return multiple row, the last row is taken & assign into var.
            -- We want blank POKey to be assigned if multiple row returned, hence using the DESC
            ORDER BY RD.POKey DESC
            SET @nRowCount = @@ROWCOUNT

            SET @nPOCount = @nRowCount

            IF @nRowCount < 1
            BEGIN
               DECLARE @nRowCount1 INT

               SELECT DISTINCT
                   @cChkFacility = R.Facility,
                   @cChkStorerKey = R.StorerKey,
                   @cReceiptStatus = R.Status,
                   @cASNStatus = R.ASNStatus -- (ChewKP10)
               FROM dbo.Receipt R WITH (NOLOCK)
               WHERE R.ReceiptKey = @cReceiptKey
               AND R.StorerKey = @cStorer
               SET @nRowCount1 = @@ROWCOUNT

               IF @nRowCount1 < 1
               BEGIN
                SET @cErrMsg = rdt.rdtgetmessage( 60403, @cLangCode, 'DSP') --'ASN does not exists'
                  SET @cOutField01 = '' -- ReceiptKey
                  SET @cReceiptKey = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 1
                GOTO Quit
               END
            END

            -- Only 1 POKey should exists in the ReceiptDetail, otherwise error
            -- Only exception is when blank POKey exists in the ReceiptDetail
            -- Changes for Multiple PO in 1 ASN (ChewKP01)
            -- Control by RDT Storer Config

            SET @cMultiPOASN = ''
            SET @cMultiPOASN = rdt.RDTGetConfig( @nFunc, 'AllowMultiPO', @cStorer)

            IF @cMultiPOASN = '1'
            BEGIN
               IF @nRowCount > 1 --AND @cChkPOKey <> ''   (ChewKP01)
               BEGIN
                     SET @cPOKey = ''
   --(ChewKP01)
   --               SET @cErrMsg = rdt.rdtgetmessage( 60404, @cLangCode, 'DSP') --'Multi PO in ASN'
   --               SET @cOutField01 = '' -- ReceiptKey
   --               SET @cReceiptKey = ''
   --               EXEC rdt.rdtSetFocusField @nMobile, 1
   --               GOTO Quit
               END
               ELSE -- (ChewKP01)
               BEGIN
                  -- (james11)
                  SET @cPOKey = CASE WHEN ISNULL( @cPOKey, '') = 'NOPO' THEN @cPOKey ELSE @cChkPOKey END
               END
            END
            ELSE
            BEGIN
               IF @nRowCount > 1 AND @cChkPOKey <> ''
               BEGIN
                     SET @cPOKey = ''

                     SET @cErrMsg = rdt.rdtgetmessage( 60404, @cLangCode, 'DSP') --'Multi PO in ASN'
                     SET @cOutField01 = '' -- ReceiptKey
                     SET @cReceiptKey = ''
                     EXEC rdt.rdtSetFocusField @nMobile, 1
                     GOTO Quit
               END

               -- (james11)
               SET @cPOKey = CASE WHEN ISNULL( @cPOKey, '') = 'NOPO' THEN @cPOKey ELSE @cChkPOKey END

            END
         END
         ELSE
            -- Only PO # keyed-in, and not equal to 'NOPO'
            IF @cPOKey <> '' AND @cPOKey IS NOT NULL AND
               @cPOKey <> 'NOPO' -- SOS76264
            BEGIN
               -- Validate whether PO have multiple ASN
               SELECT DISTINCT
                  @cChkFacility = R.Facility,
                  @cChkStorerKey = R.StorerKey,
                  @cReceiptKey = R.ReceiptKey,
                  @cReceiptStatus = R.Status,
                  @cASNStatus = R.ASNStatus -- (ChewKP10)
               FROM dbo.Receipt R WITH (NOLOCK)
                  INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
               WHERE RD.POKey = @cPOKey
                  AND RD.StorerKey = @cStorer
               SET @nRowCount = @@ROWCOUNT

               IF @nRowCount < 1
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( 60405, @cLangCode, 'DSP') --'PO does not exists'
                  SET @cOutField02 = '' -- POKey
                  SET @cPOKey = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 2
                  GOTO Quit
               END

               IF @nRowCount > 1
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( 60406, @cLangCode, 'DSP') --'Multi ASN in PO'
                  SET @cOutField02 = '' -- POKey
                  SET @cPOKey = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 2
                  GOTO Quit
               END
            END

      -- Validate ASN in different facility


      IF @cFacility <> @cChkFacility
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 60407, @cLangCode, 'DSP') --'ASN facility diff'
         SET @cOutField01 = '' -- ReceiptKey
         SET @cReceiptKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Validate ASN belong to the storer
      IF @cChkStorerKey IS NULL OR @cChkStorerKey = ''
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 60408, @cLangCode, 'DSP') --'ASN storer different'
         SET @cOutField01 = '' -- ReceiptKey
         SET @cReceiptKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Validate ASN status - (CANC) -- (ChewKP10)
      IF @cASNStatus = 'CANC'
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 67370, @cLangCode, 'DSP') --'ASN is cancelled'
         SET @cOutField01 = '' -- ReceiptKey
         SET @cReceiptKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Validate ASN status
      IF @cReceiptStatus = '9'
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 60409, @cLangCode, 'DSP') --'ASN is closed'
         SET @cOutField01 = '' -- ReceiptKey
         SET @cReceiptKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      --Start (Vanessa01)
      IF ISNULL(RTRIM(@cDefaultToLoc),'0') <> '0'
      BEGIN
         SET @cOutField01 = ISNULL(RTRIM(@cDefaultToLoc),'0') -- LOC
      END
      ELSE
      BEGIN
         -- Init next screen var
         SET @cOutField01 = '' -- LOC
      END
      --End (Vanessa01)

      SET @cOutField02 = @cReceiptKey  -- (james09)
      SET @cOutField03 = @cPOKey       -- (james09)

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
     -- (Vicky06) EventLog - Sign Out Function
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorer

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cOutField01 = ''

      -- (Vicky02) - Start
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
      -- (Vicky02) - End

      -- Commented (Vicky02)
      -- Delete session data
      --DELETE RDTSessionData WITH (ROWLOCK) WHERE Mobile = @nMobile
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- ReceiptKey
      SET @cOutField02 = '' -- POKey
      SET @cReceiptKey = ''
      SET @cPOKey = ''
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 952. Location screen
   LOC
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField01 -- LOC

      -- Validate compulsary field
      IF @cLOC = '' OR @cLOC IS NULL
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 60410, @cLangCode, 'DSP') --'LOC is required'
         GOTO Step_2_Fail
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
         SET @cErrMsg = rdt.rdtgetmessage( 60411, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_2_Fail
      END

      -- Validate location not in facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 60412, @cLangCode, 'DSP') --'LOC not in facility'
         GOTO Step_2_Fail
      END

      -- (Vicky03) - Start
      -- Auto generate ID if RDT StorerConfigkey = AutoGenID turned on
      SET @cAutoGenID = ''
      SET @cAutoGenID = rdt.RDTGetConfig( @nFunc, 'AutoGenID', @cStorer) -- (james03)
      IF @cAutoGenID = '1' and (@cPrevOp = '' OR @cPrevOp = '1')
      BEGIN
          EXECUTE dbo.nspg_GetKey
                  'ID',
                  10 ,
                  @cID               OUTPUT,
                  @b_success         OUTPUT,
                  @n_err             OUTPUT,
                  @c_errmsg          OUTPUT
         IF @b_success <> 1
         BEGIN
            SET @nErrNo = 60449
            SET @cErrMsg = rdt.rdtgetmessage( 60449, @cLangCode, 'DSP') -- 'GetIDKey Fail'
            GOTO Step_2_Fail
         END
         ELSE
         BEGIN
             -- Init next screen var
            SET @cOutField01 = @cID -- ID
            SET @cOutField02 = @cLOC      -- (james09)
         END
      END
      ELSE IF @cPrevOp = '2' -- Default Prev ID
      BEGIN
         -- Init next screen var
         SET @cOutField01 = @cID -- ID
         SET @cOutField02 = @cLOC      -- (james09)
      END
      ELSE-- (Vicky03) - End
      BEGIN
         -- Init next screen var
         SET @cOutField01 = '' -- ID
         SET @cOutField02 = @cLOC      -- (james09)
      END

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- LOC
      SET @cOutField02 = @cReceiptKey  -- (james09)
      SET @cOutField03 = @cPOKey       -- (james09)
      SET @cLOC = ''
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 953. Pallet ID screen
   ID
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cID = @cInField01 -- ID
      SET @cToID = @cInField01 -- ID

      -- Validate duplicate pallet ID
      DECLARE @nDisAllowDuplicateIdsOnRFRcpt INT
      SELECT @nDisAllowDuplicateIdsOnRFRcpt = NSQLValue
      FROM dbo.NSQLConfig WITH (NOLOCK)
      WHERE ConfigKey = 'DisAllowDuplicateIdsOnRFRcpt'

      IF (@nDisAllowDuplicateIdsOnRFRcpt = '1') AND
         (@cID <> '' AND @cID IS NOT NULL)
      BEGIN
         IF EXISTS( SELECT [ID]
            FROM dbo.LOTxLOCxID LOTxLOCxID WITH (NOLOCK)
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC)
            WHERE [ID] = @cID
               AND QTY > 0
               AND LOC.Facility = @cFacility)
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 60413, @cLangCode, 'DSP') --'Duplicate PAL ID'
            GOTO Step_3_Fail
         END
      END

      -- (Vicky05) - Start
      SET @cCheckPLTID = ''
      SET @cCheckPLTID = rdt.RDTGetConfig( @nFunc, 'CheckPLTID', @cStorer) -- Parse in Function

      IF @cCheckPLTID = '1'
      BEGIN
         IF EXISTS (SELECT 1 FROM  dbo.ReceiptDetail RD WITH (NOLOCK)
                    WHERE RD.ReceiptKey = @cReceiptKey
                    AND RD.StorerKey = @cStorer
                    AND RD.ToID = RTRIM(@cID)
                    AND RD.BeforeReceivedQty > 0)
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 60461, @cLangCode, 'DSP') --'PLT ID Exists'
            GOTO Step_3_Fail
         END
      END
      -- (Vicky05) - End

      --(james08)
      -- Stored Proc to validate Pallet ID
      SET @cCheckPalletID_SP = rdt.RDTGetConfig( @nFunc, 'CheckPalletID_SP', @cStorer)

      IF ISNULL(@cCheckPalletID_SP, '') NOT IN ('', '0')
      BEGIN
         SET @cSQLStatement = N'EXEC rdt.' + RTRIM(@cCheckPalletID_SP) +
             ' @cPalletID, @nValid OUTPUT, @nErrNo OUTPUT,  @cErrMsg OUTPUT'

         SET @cSQLParms = N'@cPalletID    NVARCHAR( 18),        ' +
                           '@nValid       INT      OUTPUT,  ' +
                           '@nErrNo       INT      OUTPUT,  ' +
                           '@cErrMsg      NVARCHAR(20) OUTPUT '

         EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,
                     @cID,
                     @nValid  OUTPUT,
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT

         IF @nErrNo <> 0
         BEGIN
            GOTO Step_3_Fail
         END

         IF @nValid = 0
         BEGIN
            SET @nErrNo = 67382
            SET @cErrMsg = rdt.rdtgetmessage( 67382, @cLangCode, 'DSP') --Invalid PltID
            GOTO Step_3_Fail
         END
      END--(james08)

      -- (james13)
      SET @cSKU = ''
      SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorer)
      IF @cExtendedInfoSP NOT IN ('0', '')
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''

            SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @cStorer, @cReceiptKey, @cPOKey, @cLOC, @cID, @cSKU, @nQTY, @cUOM, @cLottable01, @cLottable02, @cLottable03, @cLottable04, @cLottable05,
                 @cO_ID OUTPUT, @cO_SKU OUTPUT, @nO_QTY OUTPUT, @cO_UOM OUTPUT, @cO_Lottable01 OUTPUT, @cO_Lottable02 OUTPUT, @cO_Lottable03 OUTPUT, @cO_Lottable04 OUTPUT, @cO_Lottable05 OUTPUT,
                 @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT, @nValid OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@cStorer         NVARCHAR( 15), ' +
               '@cReceiptKey     NVARCHAR( 10), ' +
               '@cPOKey          NVARCHAR( 10), ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cID             NVARCHAR( 30), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cUOM            NVARCHAR( 10), ' +
               '@cLottable01     NVARCHAR( 18), ' +
               '@cLottable02     NVARCHAR( 18), ' +
               '@cLottable03     NVARCHAR( 18), ' +
               '@cLottable04     NVARCHAR( 16), ' +
               '@cLottable05     NVARCHAR( 16), ' +
               '@cO_ID           NVARCHAR( 18) OUTPUT, ' +
               '@cO_SKU          NVARCHAR( 20) OUTPUT, ' +
               '@nO_QTY          INT           OUTPUT, ' +
               '@cO_UOM          NVARCHAR( 10) OUTPUT, ' +
               '@cO_Lottable01   NVARCHAR( 18) OUTPUT, ' +
               '@cO_Lottable02   NVARCHAR( 18) OUTPUT, ' +
               '@cO_Lottable03   NVARCHAR( 18) OUTPUT, ' +
               '@cO_Lottable04   NVARCHAR( 16) OUTPUT, ' +
               '@cO_Lottable05   NVARCHAR( 16) OUTPUT, ' +
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
               '@cExtendedInfo2  NVARCHAR( 20) OUTPUT, ' +
               '@nValid          INT           OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @cStorer, @cReceiptKey, @cPOKey, @cLOC, @cToID, @cSKU, @nQTY, @cUOM, @cLottable01, @cLottable02, @cLottable03, @cLottable04, @cLottable05,
               @cO_ID OUTPUT, @cO_SKU OUTPUT, @nO_QTY OUTPUT, @cO_UOM OUTPUT,
               @cO_Lottable01 OUTPUT, @cO_Lottable02 OUTPUT, @cO_Lottable03 OUTPUT, @cO_Lottable04 OUTPUT, @cO_Lottable05 OUTPUT,
               @cExtendedInfo OUTPUT, @cExtendedInfo2 OUTPUT, @nValid OUTPUT

            IF @nValid = 0
            BEGIN
               SET @nErrNo = 67387
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PltID
               GOTO Step_3_Fail
            END

            -- Prepare extended fields
            IF ISNULL( @cO_ID, '') <> '' SET @cID = CASE WHEN ISNULL( @cO_ID, '') = '' THEN @cToID ELSE @cO_ID END
            IF ISNULL( @cO_SKU, '') <> '' SET @cSKU = @cO_SKU
            IF ISNULL( @nO_QTY, '') <> '' SET @nQTY = @cO_SKU
            IF ISNULL( @cO_UOM, '') <> '' SET @cUOM = @cO_UOM
            IF ISNULL( @cO_Lottable01, '') <> '' SET @cLottable01 = @cO_Lottable01
            IF ISNULL( @cO_Lottable02, '') <> '' SET @cLottable02 = @cO_Lottable02
            IF ISNULL( @cO_Lottable03, '') <> '' SET @cLottable03 = @cO_Lottable03
            IF ISNULL( @cO_Lottable04, '') <> '' OR RDT.RDTFormatDate(@cO_Lottable04) = '01/01/1900' OR RDT.RDTFormatDate(@cO_Lottable04) = '1900/01/01'
               SET @cLottable04 = @cO_Lottable04
            IF ISNULL( @cO_Lottable05, '') <> '' OR RDT.RDTFormatDate(@cO_Lottable05) = '01/01/1900' OR RDT.RDTFormatDate(@cO_Lottable05) = '1900/01/01'
               SET @cLottable05 = @cO_Lottable05
         END
      END

      -- Init next screen var
      SET @cOutField01 = @cSKU -- SKU
      SET @cOutField02 = '' -- SKUDesc1
      SET @cOutField03 = '' -- SKUDesc2
      SET @cOutField04 = @cID    -- (james09)

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cReceiptKey  -- (james09)
      SET @cOutField03 = @cPOKey       -- (james09)

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- ID
      SET @cOutField02 = @cLOC      -- (james09)
      SET @cID = ''
   END
END
GOTO Quit


/********************************************************************************
Step 4. Scn = 954. SKU screen
   SKU
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @nRetainSKUDesc INT
      SET @nRetainSKUDesc = 0

      -- Screen mapping
      SET @cSKU = @cInField01 -- SKU

      -- SOS#80652
      SET @cAddSKUtoASN = ''
      SET @cAddSKUtoASN = rdt.RDTGetConfig( 0, 'RDTAddSKUtoASN', @cStorer)

      -- Validate compulsary field
      IF @cSKU = '' OR @cSKU IS NULL
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 60414, @cLangCode, 'DSP') --'SKU is required'
         GOTO Step_4_Fail
      END

      -- Decode label (james14)
      SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorer)
      IF @cDecodeLabelNo = '0'
         SET @cDecodeLabelNo = ''

      IF @cDecodeLabelNo <> ''
      BEGIN
         SELECT @c_oFieled01 = '', @c_oFieled02 = '',
                @c_oFieled03 = '', @c_oFieled04 = '',
                @c_oFieled05 = '', @c_oFieled06 = '',
                @c_oFieled07 = '', @c_oFieled08 = '',
                @c_oFieled09 = '', @c_oFieled10 = ''

         SET @cErrMsg = ''
         SET @nErrNo = 0
         SET @cSSCC = ''
         EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @cInField01
            ,@c_Storerkey  = @cStorer
            ,@c_ReceiptKey = @cReceiptKey
            ,@c_POKey      = @cPOKey
            ,@c_LangCode   = @cLangCode
            ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
            ,@c_oFieled02  = @c_oFieled02 OUTPUT
            ,@c_oFieled03  = @c_oFieled03 OUTPUT
            ,@c_oFieled04  = @c_oFieled04 OUTPUT
            ,@c_oFieled05  = @c_oFieled05 OUTPUT
            ,@c_oFieled06  = @c_oFieled06 OUTPUT
            ,@c_oFieled07  = @c_oFieled07 OUTPUT
            ,@c_oFieled08  = @c_oFieled08 OUTPUT
            ,@c_oFieled09  = @c_oFieled09 OUTPUT
            ,@c_oFieled10  = @c_oFieled10 OUTPUT
            ,@b_Success    = @b_Success   OUTPUT
            ,@n_ErrNo      = @nErrNo      OUTPUT
            ,@c_ErrMsg     = @cErrMsg     OUTPUT

         IF @nErrNo <> 0
            GOTO Step_4_Fail

         SET @cSKU = @c_oFieled01
         SET @cInField01 = @c_oFieled01
         SET @cSSCC = @c_oFieled02
      END

    -- (ChewKP05)
    SET @cRDTDefaultUOM = ''
    SELECT @cRDTDefaultUOM = Data FROM dbo.SKUConfig WITH (NOLOCK)
    WHERE ConfigType = 'RDTDefaultUOM'
    AND SKU = @cSKU
    AND Storerkey = @cStorer

    DECLARE @nCount INT

      --get configKey 'PrePackByBOM'
      SET @cPrePackByBOM = ''
      SELECT @cPrePackByBOM = ISNULL(RTRIM(sValue),'')
      FROM dbo.StorerConfig WITH (NOLOCK)
      WHERE ConfigKey = 'PrePackByBOM'
         AND Storerkey = @cStorer
         IF @cPrePackByBOM = '1' --configkey 'PrePackByBOM' has been setup
         BEGIN

         -- Added By Vicky 20-Sept-2007
         SET @cUPCSKU = @cSKU

         --get sku from UPC if it matches
         SET @cUPCPackKey = ''
         SET @cUPCUOM = ''
         SELECT @cSku         = ISNULL(RTRIM(SKU),''),
                @cUPCPackKey  = ISNULL(RTRIM(PackKey),''), -- use in Receiving process below
                @cUPCUOM      = ISNULL(RTRIM(UOM),'')      -- use in Receiving process below
         FROM dbo.UPC WITH (NOLOCK)
         WHERE UPC = @cSKU
           AND StorerKey = @cStorer

         IF @cSKU <> ''
         BEGIN
            SET @nCountSku = 0

            --get total num of componentsku
            SELECT @nCountSku = COUNT(ComponentSku)
            FROM dbo.BillOfMaterial WITH (NOLOCK)
            WHERE SKU = @cSKU
               AND StorerKey = @cStorer

            --if there is none of componentSku, straight go for normal validation for sku
            IF @nCountSKu = 0
               GOTO Step_4_Valid_Sku

            --if there is one or more componentsku, check validation for each componentsku
            SET @nTempCount = 1
            WHILE @nTempCount <= @nCountSku
            BEGIN
               SET @cComponentSku = ''
               --retrieve one componentSku at a time by sequence
               SELECT @cComponentSku = ComponentSku
               FROM dbo.BillOfMaterial WITH (NOLOCK)
               WHERE SKU = @cSKU
                  AND Storerkey = @cStorer
                  AND Sequence = CONVERT(NVARCHAR, @nTempCount)

               IF ISNULL(@cUPCPackKey, '') = '' AND ISNULL(@cUPCUOM, '') = ''
               BEGIN
                   SELECT @cUPCPackKey = RTRIM(Packkey)
                   FROM dbo.SKU WITH (NOLOCK)
                   WHERE Storerkey = @cStorer
                   AND SKU = @cSKU

                   SELECT @cUPCUOM = RTRIM(PACKUOM3)
                   FROM dbo.PACK WITH (NOLOCK)
                   WHERE Packkey = @cUPCPackKey
               END

               IF RTRIM(@cAddSKUtoASN) <> '1'--(ANG01 START)
               BEGIN
                  IF NOT EXISTS(SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                                 WHERE RECEIPTKEY = @cReceiptKey
                                 AND   STORERKEY = @cStorer
                                 AND   SKU = @cComponentSku)
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( 60442, @cLangCode, 'DSP') --'SKU not in ASN'
                     SET @nRetainSKUDesc = 1 -- user want SKU description for this error
                     GOTO Step_4_Fail
                  END
               END
               ELSE
               BEGIN
                  SELECT @cSKU = @cInField01
                  SET @nScn  = @nScn + 4
                  SET @nStep = @nStep + 4
                  GOTO QUIT
               END --(ANG01 END)

               SET @nCount = 0
               --validate each componentSku
               SELECT
                  @nCount = COUNT( DISTINCT SKU.SKU)
                  --@cSkuCode = MIN( SKU.SKU) -- using MIN() just to bypass SQL aggregate checking
               FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                  INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (RD.StorerKey = SKU.StorerKey AND RD.SKU = SKU.SKU)
                  LEFT OUTER JOIN dbo.UPC UPC WITH(NOLOCK) ON (SKU.StorerKey = UPC.StorerKey AND SKU.SKU = UPC.SKU)
               WHERE RD.ReceiptKey = @cReceiptKey
                  AND (@cComponentSku IN (SKU.SKU, SKU.AltSKU, SKU.RetailSKU, SKU.ManufacturerSKU) OR UPC.UPC = @cComponentSku)

               IF @nCount = 0
               BEGIN
                  -- Get SKU description --@cSKUDesc = IsNULL( DescR, '')
                  SELECT @cSKUDesc = IsNULL( DescR, '')
                  FROM dbo.SKU SKU WITH (NOLOCK)
                     LEFT OUTER JOIN dbo.UPC UPC WITH (NOLOCK) ON (SKU.StorerKey = UPC.StorerKey AND SKU.SKU = UPC.SKU)
                  WHERE SKU.StorerKey = @cStorer
                     AND (@cComponentSku IN (SKU.SKU, SKU.AltSKU, SKU.RetailSKU, SKU.ManufacturerSKU) OR UPC.UPC = @cComponentSku)

                  IF @@ROWCOUNT = 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( 60441, @cLangCode, 'DSP') --'Invalid SKU'
                     GOTO Step_4_Fail
                  END
                  ELSE
                  BEGIN
                     --SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
                     --SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2

                     -- SOS#80652 (Start)
                     IF RTRIM(@cAddSKUtoASN) <> '1'
                     BEGIN
                        SET @cErrMsg = rdt.rdtgetmessage( 60442, @cLangCode, 'DSP') --'SKU not in ASN'
                        SET @nRetainSKUDesc = 1 -- user want SKU description for this error
                        GOTO Step_4_Fail
                     END
--                     ELSE
--                     BEGIN
--                        SELECT @cSKU = @cInField01
--                  SET @nScn  = @nScn + 4
--                  SET @nStep = @nStep + 4
--                        GOTO QUIT
--                     END
                     -- SOS#80652 (End)
                  END
               END

               IF @nCount > 1
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( 60436, @cLangCode, 'DSP') --'SKU had same barcode'
                  GOTO Step_4_Fail
               END

               -- Check ComponentSKU must exists in ASN+PO (james04)
               IF ISNULL(@cPOKey, '') <> '' AND @cPOKey <> 'NOPO'
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM dbo.PODETAIL WITH (NOLOCK)
                     WHERE StorerKey = @cStorer
                        AND POKey = @cPOKey
                        AND SKU = @cComponentSku)
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( 67380, @cLangCode, 'DSP') --'SKU not in PO'
                     GOTO Step_4_Fail
                  END
               END

               SET @nTempCount = @nTempCount + 1
            END --end of while loop

            GOTO Step_4_Next_Screen_Details

         END --end of @sku<>''

      END --end of @cPrePackByBOM = '1'

-- NOTE: if more than 1 SKU having same AltSKU.. SKU code returned is random (possible SKU not in ASN)
--       -- Get actual SKU if user key-in AltSKU / RetailSKU / ManufacturingSKU / UPC.UPC
--       SET @b_success = 0
--       EXEC dbo.nspg_GETSKU @cStorer, @cSKU OUTPUT, @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
--       IF @b_success = 0
--       BEGIN
--          SET @cErrMsg = rdt.rdtgetmessage( 60415, @cLangCode, 'DSP') --'Invalid SKU'
--          GOTO Step_4_Fail
--       END

      -- Validate if diff SKU in the ASN had the same barcode (AltSKU, RetailSKU, ManufacturingSKU or UPC.UPC)
      -- It happen bcoz the SKU get repackaged, so SKU code get changed. SKU code is controlled by storer
      -- Barcode remain the same bcoz supplier charge $$ for issue new barcode to storer

      Step_4_Valid_Sku:

      SET @nCount = 0
      SELECT
         @nCount = COUNT( DISTINCT SKU.SKU),
         @cSKU = MIN( SKU.SKU) -- using MIN() just to bypass SQL aggregate checking
      FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (RD.StorerKey = SKU.StorerKey AND RD.SKU = SKU.SKU)
         LEFT OUTER JOIN dbo.UPC UPC WITH (NOLOCK) ON (SKU.StorerKey = UPC.StorerKey AND SKU.SKU = UPC.SKU)
      WHERE RD.ReceiptKey = @cReceiptKey
         AND (@cInField01 IN (SKU.SKU, SKU.AltSKU, SKU.RetailSKU, SKU.ManufacturerSKU) OR UPC.UPC = @cInField01)

      IF @nCount = 0
      BEGIN
         -- Get SKU description
         SELECT @cSKUDesc = IsNULL( DescR, '')
         FROM dbo.SKU SKU WITH (NOLOCK)
            LEFT OUTER JOIN dbo.UPC UPC WITH (NOLOCK) ON (SKU.StorerKey = UPC.StorerKey AND SKU.SKU = UPC.SKU)
         WHERE SKU.StorerKey = @cStorer
            AND (@cInField01 IN (SKU.SKU, SKU.AltSKU, SKU.RetailSKU, SKU.ManufacturerSKU) OR UPC.UPC = @cInField01)

         IF @@ROWCOUNT = 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 60415, @cLangCode, 'DSP') --'Invalid SKU'
            GOTO Step_4_Fail
         END
         ELSE
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 60416, @cLangCode, 'DSP') --'SKU not in ASN'
            SET @nRetainSKUDesc = 1 -- user want SKU description for this error
            SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
            SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2

            -- SOS#80652 (Start)
            IF RTRIM(@cAddSKUtoASN) <> '1'
            BEGIN
              GOTO Step_4_Fail
            END
            ELSE
            BEGIN
               SELECT @cSKU = @cInField01

               SET @cOutField01 = ''   -- (james17)

               SET @nScn  = @nScn + 4
               SET @nStep = @nStep + 4
               GOTO QUIT
            END
            -- SOS#80652 (End)
         END
      END

      IF @nCount > 1
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 60436, @cLangCode, 'DSP') --'SKU had same barcode'
         GOTO Step_4_Fail
      END

      -- Check ComponentSKU must exists in ASN+PO (james04)
      IF ISNULL(@cPOKey, '') <> '' AND @cPOKey <> 'NOPO' AND RTRIM(@cAddSKUtoASN) <> '1'  --(JHTAN01)
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PODETAIL WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND POKey = @cPOKey
               AND SKU = @cSKU)  -- james06
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 67381, @cLangCode, 'DSP') --'SKU not in PO'
            GOTO Step_4_Fail
         END
      END

      Step_4_Next_Screen_Details:
      IF @cPrePackByBOM = '1' --configkey 'PrePackByBOM' has been setup
      BEGIN
         SET @nCountSku = 0

         --get total num of componentsku
         SELECT @nCountSku = COUNT(ComponentSku)
         FROM dbo.BillOfMaterial WITH (NOLOCK)
         WHERE SKU = @cSKU
            AND StorerKey = @cStorer

         --if there is none of componentSku, straight go for normal retrieval for sku
         IF @nCountSKu = 0
         BEGIN
            -- Get SKU description, IVAS, lot label
            SET @cPackKey = '' -- SOS# 213546
            SELECT
               @cSKUDesc = IsNULL( DescR, ''),
               @cIVAS = IsNULL( IVAS, ''),
               @cLotLabel01 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable01Label AND C.ListName = 'LOTTABLE01' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),  -- SOS308961
               @cLotLabel02 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),  -- SOS308961
               @cLotLabel03 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),  -- SOS308961
               @cLotLabel04 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),  -- SOS308961
               @cLotLabel05 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable05Label AND C.ListName = 'LOTTABLE05' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),  -- SOS308961
               @cLottable05_Code = IsNULL( S.Lottable05Label, ''),
               @cLottable01_Code = IsNULL(S.Lottable01Label, ''),  -- SOS#81879
               @cLottable02_Code = IsNULL(S.Lottable02Label, ''),  -- SOS#81879
               @cLottable03_Code = IsNULL(S.Lottable03Label, ''),  -- SOS#81879
               @cLottable04_Code = IsNULL(S.Lottable04Label, '')   -- SOS#81879
             , @cPackKey = S.Packkey -- SOS# 213546
            FROM dbo.SKU S WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND SKU = @cSKU
         END
         ELSE
         BEGIN --got componentsku
            SELECT
               @cSKUDesc = IsNULL( DescR, ''),
               @cIVAS = IsNULL( IVAS, '')
            FROM dbo.SKU S WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND SKU = @cSKU

            -- (Vicky07) - Start
            SET @cDisplayLot03 = ''
            SET @cDisplayLot03 = rdt.RDTGetConfig( 0, 'DisplayLot03', @cStorer)

            IF @cDisplayLot03 = '1'
            BEGIN
              SET @cLottable03 = RTRIM(@cSKU)
            END
         -- (Vicky07) - End

            SET ROWCOUNT 1
            SET @cPackkey = ''
            SELECT
               @cLotLabel01 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = SKU.Lottable01Label AND C.ListName = 'LOTTABLE01' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),  -- SOS308961
               @cLotLabel02 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = SKU.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),  -- SOS308961
               @cLotLabel03 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = SKU.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),  -- SOS308961
               @cLotLabel04 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = SKU.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),  -- SOS308961
               @cLotLabel05 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = SKU.Lottable05Label AND C.ListName = 'LOTTABLE05' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),  -- SOS308961
               @cLottable05_Code = IsNULL( SKU.Lottable05Label, ''),
               @cPackKey = SKU.Packkey,
               @cLottable01_Code = IsNULL(SKU.Lottable01Label, ''),  -- SOS#81879
               @cLottable02_Code = IsNULL(SKU.Lottable02Label, ''),  -- SOS#81879
               @cLottable03_Code = IsNULL(SKU.Lottable03Label, ''),  -- SOS#81879
               @cLottable04_Code = IsNULL(SKU.Lottable04Label, '')   -- SOS#81879
            FROM dbo.BillOfMaterial BOM WITH (NOLOCK) JOIN dbo.SKU SKU with (nolock)
            ON BOM.StorerKey = SKU.Storerkey AND BOM.ComponentSku = SKU.SKU
          WHERE BOM.SKU = @cSKU
               AND BOM.StorerKey = @cStorer
            SET ROWCOUNT 0
         END
      END
      ELSE
      BEGIN
         -- Get SKU description, IVAS, lot label
         SELECT
            @cSKUDesc = IsNULL( DescR, ''),
            @cIVAS = IsNULL( IVAS, ''),
            @cLotLabel01 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable01Label AND C.ListName = 'LOTTABLE01' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),  -- SOS308961
            @cLotLabel02 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),  -- SOS308961
            @cLotLabel03 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),  -- SOS308961
            @cLotLabel04 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),  -- SOS308961
            @cLotLabel05 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable05Label AND C.ListName = 'LOTTABLE05' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''),  -- SOS308961
            @cLottable05_Code = IsNULL( S.Lottable05Label, ''),
            @cLottable01_Code = IsNULL(S.Lottable01Label, ''),  -- SOS#81879
            @cLottable02_Code = IsNULL(S.Lottable02Label, ''),  -- SOS#81879
            @cLottable03_Code = IsNULL(S.Lottable03Label, ''),  -- SOS#81879
            @cLottable04_Code = IsNULL(S.Lottable04Label, '')   -- SOS#81879
          , @cPackKey = S.Packkey -- SOS# 213546
         FROM dbo.SKU S WITH (NOLOCK)
         WHERE StorerKey = @cStorer
            AND SKU = @cSKU
      END


      -- Turn on lottable flag (use later)
      SET @cHasLottable = '0'
      IF (@cLotLabel01 <> '' AND @cLotLabel01 IS NOT NULL) OR
         (@cLotLabel02 <> '' AND @cLotLabel02 IS NOT NULL) OR
         (@cLotLabel03 <> '' AND @cLotLabel03 IS NOT NULL) OR
         (@cLotLabel04 <> '' AND @cLotLabel04 IS NOT NULL) OR
         (@cLotLabel05 <> '' AND @cLotLabel05 IS NOT NULL)
      BEGIN
         SET @cHasLottable = '1'
      END

      -- Get Lottable, UOM
      IF @cPrePackByBOM = '1' --configkey 'PrePackByBOM' has been setup
      BEGIN
         SET @nCountSku = 0

         --get total num of componentsku
         SELECT @nCountSku = COUNT(ComponentSku)
         FROM dbo.BillOfMaterial WITH (NOLOCK)
         WHERE SKU = @cSKU
            AND StorerKey = @cStorer

         --if there is none of componentSku, straight go for normal retrieval for sku
         IF @nCountSKu = 0
            GOTO Validate_Unmatch_ASN_LN
         ELSE
         BEGIN
             --if there is one or more componentsku, check validation for each componentsku
--             SET @nTempCount = 1
--             WHILE @nTempCount <= @nCountSku
--             BEGIN
               SET @cComponentSku = ''

               --retrieve one componentSku at a time by sequence
--                SELECT @cComponentSku = ComponentSku
--                FROM dbo.BillOfMaterial WITH (NOLOCK)
--                WHERE SKU = @cSKU
--                   AND Storerkey = @cStorer
--                   AND Sequence = CONVERT(NVARCHAR, @nTempCount)

--                SET @nDummy = 0
--                SELECT TOP 1
--                   @nDummy = CASE WHEN @cID = [ToID] THEN 0 ELSE 1 END, -- Try to match PO + ID. If not found, follow line# sequence
--                   @cUOM = UOM,
--                   @cLottable01 = Lottable01,
--                   @cLottable02 = Lottable02,
--                   @cLottable03 = Lottable03,
--                   @cLottable04 = rdt.rdtFormatDate( Lottable04),
--                   @cLottable05 = rdt.rdtFormatDate( Lottable05)
--                FROM dbo.ReceiptDetail WITH (NOLOCK)
--                WHERE ReceiptKey = @cReceiptKey
--                   -- SOS7626444
--                   -- AND POKey = @cPOKey
--                   AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END
--                   AND SKU = @cComponentSku
--                   -- AND QTYExpected > BeforeReceivedQTY -- RFRC01 will create new ASN detail line, for over receive
--                ORDER BY 1, ReceiptLineNumber
--                SET @nRowCount = @@ROWCOUNT

--                IF @nRowCount = 0 AND ISNULL(@cUPCUOM, '') = ''
--                BEGIN
--                   IF @cAddSKUtoASN <> '1' --when it is not equal '1', not allow to add new sku, prompt error msg
--                   BEGIN
--                      SET @cErrMsg = rdt.rdtgetmessage( 60444, @cLangCode, 'DSP') --'60444 Unmatch ASN LN'
--                      GOTO Step_4_Fail
--                   END
--                   ELSE
--                   BEGIN

                    IF ISNULL(@cUPCUOM, '') = ''
                    BEGIN
                        -- (ChewKP05)
                        SELECT @cComponentSku = ComponentSKU From dbo.BillOfMaterial WITH (NOLOCK)
                        WHERE SKU = @cSKU
                        AND Storerkey = @cStorer

                        SET @cRDTDefaultUOM = ''
                        SELECT @cRDTDefaultUOM = Data FROM dbo.SKUConfig WITH (NOLOCK)
                        WHERE ConfigType = 'RDTDefaultUOM'
                        AND SKU = @cComponentSku
                        AND Storerkey = @cStorer

                        IF ISNULL(@cRDTDefaultUOM,'')  = '' -- (ChewKP05)
                        BEGIN
                           SELECT @cUOM = CASE @cPrefUOM
                           WHEN '2' THEN PACK.PackUOM1 -- Case
                           WHEN '3' THEN PACK.PackUOM2 -- Inner pack
                           WHEN '6' THEN PACK.PackUOM3 -- Master unit
                           WHEN '1' THEN PACK.PackUOM4 -- Pallet
                           WHEN '4' THEN PACK.PackUOM8 -- Other unit 1
                           WHEN '5' THEN PACK.PackUOM9 -- Other unit 2
                           END
                           FROM dbo.PACK PACK WITH (NOLOCK)
                           WHERE PACK.Packkey = @cPackkey
                        END
                        ELSE
                        BEGIN
                           SET @cUOM = @cRDTDefaultUOM -- (ChewKP05)
                        END
                    END
                    ELSE
                    BEGIN
                     -- Added By Vicky 17-Sept-2007
                     -- UOM should be the Scanned UPC UOM
                         SELECT @cUOM = @cUPCUOM
--             WHEN 'CS' THEN PACK.PackUOM1 -- Case
--             WHEN 'IP' THEN PACK.PackUOM2 -- Inner pack
--             WHEN 'PK' THEN PACK.PackUOM3 -- Master unit
--             WHEN 'PL' THEN PACK.PackUOM4 -- Pallet
--             WHEN 'SH' THEN PACK.PackUOM8 -- Other unit 1
-- --             END
--                        FROM dbo.PACK PACK WITH (NOLOCK)
--                        WHERE PACK.Packkey = @cUPCPackkey
                    END
--  END

--                      -- Added By Vicky 17-Sept-2007
--                      -- UOM should be the Scanned UPC UOM
--                          SELECT @cUOM = CASE @cUPCUOM
--             WHEN 'CS' THEN PACK.PackUOM1 -- Case
--             WHEN 'IP' THEN PACK.PackUOM2 -- Inner pack
--             WHEN 'PK' THEN PACK.PackUOM3 -- Master unit
--             WHEN 'PL' THEN PACK.PackUOM4 -- Pallet
--             WHEN 'SH' THEN PACK.PackUOM8 -- Other unit 1
--             END
--                        FROM dbo.PACK PACK WITH (NOLOCK)
--                        WHERE PACK.Packkey = @cPackkey
--                END
--                SET  @nTempCount =  @nTempCount + 1
--            END
            GOTO Next_Screen_Var
         END
      END

      Validate_Unmatch_ASN_LN:
      SET @nDummy = 0

      -- (Vicky07) - Start
      SET @cDisplayLot03 = ''
      SET @cDisplayLot03 = rdt.RDTGetConfig( 0, 'DisplayLot03', @cStorer)

      DECLARE @cGetReceiveInfoSP NVARCHAR(20)
      SET @cGetReceiveInfoSP = rdt.RDTGetConfig( @nFunc, 'GetReceiveInfoSP', @cStorer)
      IF @cGetReceiveInfoSP = '0'
         SET @cGetReceiveInfoSP = ''

      IF @cGetReceiveInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetReceiveInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetReceiveInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, ' +
               ' @cID         OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT, @cUOM        OUTPUT, ' +
               ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @cLottable04 OUTPUT, @cLottable05 OUTPUT, ' +
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
               ' @cUOM         NVARCHAR( 10)  OUTPUT, ' +
               ' @cLottable01  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable02  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable03  NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable04  NVARCHAR( 16)  OUTPUT, ' +
               ' @cLottable05  NVARCHAR( 16)  OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cReceiptKey, @cPOKey, @cLOC,
               @cID         OUTPUT, @cSKU        OUTPUT, @nQTY        OUTPUT, @cUOM        OUTPUT,
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @cLottable04 OUTPUT, @cLottable05 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_4_Fail
         END
      END
      ELSE
      BEGIN
         IF @nPOCount = 1 -- (ChewKP01)
         BEGIN
            IF @cDisplayLot03 = '1'
            BEGIN
               SELECT TOP 1
                  @nDummy = CASE WHEN @cID = [ToID] THEN 0 ELSE 1 END, -- Try to match PO + ID. If not found, follow line# sequence
                  @cUOM = UOM,
                  @cLottable01 = Lottable01,
                  @cLottable02 = Lottable02,
                  @cLottable03 = Lottable03,
                  @cLottable04 = rdt.rdtFormatDate( Lottable04),
                  @cLottable05 = rdt.rdtFormatDate( Lottable05)
               FROM DBO.ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
                  -- SOS76264
                  -- AND POKey = @cPOKey
                  AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END
                  AND SKU = @cSKU
                  AND ISNULL(RTRIM(Lottable03), '') = '0'  -- Larry01
               ORDER BY 1, ReceiptLineNumber
            END
            -- (Vicky07) - End
            ELSE
            BEGIN
               SELECT TOP 1
                  @nDummy = CASE WHEN @cID = [ToID] THEN 0 ELSE 1 END, -- Try to match PO + ID. If not found, follow line# sequence
                  @cUOM = UOM,
                  @cLottable01 = Lottable01,
                  @cLottable02 = Lottable02,
                  @cLottable03 = Lottable03,
                  @cLottable04 = rdt.rdtFormatDate( Lottable04),
                  @cLottable05 = rdt.rdtFormatDate( Lottable05)
               FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
                  -- SOS76264
                  -- AND POKey = @cPOKey
                  AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END
                  AND SKU = @cSKU
                  -- AND QTYExpected > BeforeReceivedQTY -- RFRC01 will create new ASN detail line, for over receive
              ORDER BY 1, ReceiptLineNumber
            END
         END
         ELSE IF @nPOCount > 1
         BEGIN
            IF @cDisplayLot03 = '1'
            BEGIN
                  SELECT TOP 1
                     @nDummy = CASE WHEN @cID = [ToID] THEN 0 ELSE 1 END, -- Try to match PO + ID. If not found, follow line# sequence
                     @cUOM = UOM,
                     @cLottable01 = Lottable01,
                     @cLottable02 = Lottable02,
                     @cLottable03 = Lottable03,
                     @cLottable04 = rdt.rdtFormatDate( Lottable04),
                     @cLottable05 = rdt.rdtFormatDate( Lottable05)
                  FROM DBO.ReceiptDetail WITH (NOLOCK)
                  WHERE ReceiptKey = @cReceiptKey
                     -- SOS76264
                     -- AND POKey = @cPOKey
                     --AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END
                     AND SKU = @cSKU
                     AND ISNULL(RTRIM(Lottable03), '') = '0'  -- Larry01
                  ORDER BY 1, ReceiptLineNumber
            END
            -- (Vicky07) - End
            ELSE
            BEGIN
               SELECT TOP 1
                  @nDummy = CASE WHEN @cID = [ToID] THEN 0 ELSE 1 END, -- Try to match PO + ID. If not found, follow line# sequence
                  @cUOM = UOM,
                  @cLottable01 = Lottable01,
                  @cLottable02 = Lottable02,
                  @cLottable03 = Lottable03,
                  @cLottable04 = rdt.rdtFormatDate( Lottable04),
                  @cLottable05 = rdt.rdtFormatDate( Lottable05)
               FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
                  -- SOS76264
                  -- AND POKey = @cPOKey
                  --AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END
                  AND SKU = @cSKU
                  -- AND QTYExpected > BeforeReceivedQTY -- RFRC01 will create new ASN detail line, for over receive
               ORDER BY 1, ReceiptLineNumber
            END
         END
         ELSE
         BEGIN
            IF @cDisplayLot03 = '1'
            BEGIN
               SELECT TOP 1
                  @nDummy = CASE WHEN @cID = [ToID] THEN 0 ELSE 1 END, -- Try to match PO + ID. If not found, follow line# sequence
                  @cUOM = UOM,
                  @cLottable01 = Lottable01,
                  @cLottable02 = Lottable02,
                  @cLottable03 = Lottable03,
                  @cLottable04 = rdt.rdtFormatDate( Lottable04),
                  @cLottable05 = rdt.rdtFormatDate( Lottable05)
               FROM DBO.ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
                  -- SOS76264
                  -- AND POKey = @cPOKey
                  AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END
                  AND SKU = @cSKU
                  AND ISNULL(RTRIM(Lottable03), '') = '0'  -- Larry01
               ORDER BY 1, ReceiptLineNumber
            END
            -- (Vicky07) - End
            ELSE
            BEGIN
               SELECT TOP 1
                  @nDummy = CASE WHEN @cID = [ToID] THEN 0 ELSE 1 END, -- Try to match PO + ID. If not found, follow line# sequence
                  @cUOM = UOM,
                  @cLottable01 = Lottable01,
                  @cLottable02 = Lottable02,
                  @cLottable03 = Lottable03,
                  @cLottable04 = rdt.rdtFormatDate( Lottable04),
                  @cLottable05 = rdt.rdtFormatDate( Lottable05)
               FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
                  -- SOS76264
                  -- AND POKey = @cPOKey
                  AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END
                  AND SKU = @cSKU
                  -- AND QTYExpected > BeforeReceivedQTY -- RFRC01 will create new ASN detail line, for over receive
               ORDER BY 1, ReceiptLineNumber
            END
         END

         SET @nRowCount = @@ROWCOUNT

         IF @nRowCount = 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 60417, @cLangCode, 'DSP') --'60417 Unmatch ASN LN'
            GOTO Step_4_Fail
         END
      END

      -- Verify SKU
      IF rdt.RDTGetConfig( @nFunc, 'VerifySKU', @cStorer) = '1'
      BEGIN
         SET @nErrNo = 0 -- SOS# 339480
         EXEC rdt.rdt_VerifySKU @nMobile, @nFunc, @cLangCode, @cStorer, @cSKU,
            'CHECK',
            @cWeight        OUTPUT,
            @cCube          OUTPUT,
            @cLength        OUTPUT,
            @cWidth         OUTPUT,
            @cHeight        OUTPUT,
            @cInnerPack     OUTPUT,
            @cCaseCount     OUTPUT,
            @cPalletCount   OUTPUT,
            @nErrNo         OUTPUT,
            @cErrMsg        OUTPUT,
            @cVerifySKUInfo OUTPUT

         IF ISNULL(@nErrNo, 0) <> 0 -- SOS# 339480
         BEGIN
            -- Enable field
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Info'   AND Short = '1') SET @cFieldAttr12 = '' ELSE SET @cFieldAttr12 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Weight' AND Short = '1') SET @cFieldAttr04 = '' ELSE SET @cFieldAttr04 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Cube'   AND Short = '1') SET @cFieldAttr05 = '' ELSE SET @cFieldAttr05 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Length' AND Short = '1') SET @cFieldAttr06 = '' ELSE SET @cFieldAttr06 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Width'  AND Short = '1') SET @cFieldAttr07 = '' ELSE SET @cFieldAttr07 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Height' AND Short = '1') SET @cFieldAttr08 = '' ELSE SET @cFieldAttr08 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Inner'  AND Short = '1') SET @cFieldAttr09 = '' ELSE SET @cFieldAttr09 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Case'   AND Short = '1') SET @cFieldAttr10 = '' ELSE SET @cFieldAttr10 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Pallet' AND Short = '1') SET @cFieldAttr11 = '' ELSE SET @cFieldAttr11 = 'O'

            -- Prepare next screen var
            SET @cOutField01 = @cSKU
            SET @cOutField02 = SUBSTRING( @cSKUDesc,  1, 20)
            SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20)
            SET @cOutField04 = @cWeight
            SET @cOutField05 = @cCube
            SET @cOutField06 = @cLength
            SET @cOutField07 = @cWidth
            SET @cOutField08 = @cHeight
            SET @cOutField09 = @cInnerPack
            SET @cOutField10 = @cCaseCount
            SET @cOutField11 = @cPalletCount
            SET @cOutField12 = @cVerifySKUInfo

            -- Go to verify SKU screen
            SET @nScn = 3950
            SET @nStep = @nStep + 9

            GOTO Quit
         END
      END

      -- (ChewKP05)
      IF ISNULL(@cRDTDefaultUOM,'') <> ''
      BEGIN
         SET @cUOM = @cRDTDefaultUOM
      END

      -- Init next screen var
      Next_Screen_Var:

   -- SOS#142253 Start
   IF @cPrefUOM < '6' AND ISNULL(@cRDTDefaultUOM,'') = '' -- (ChewKP05)
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM  dbo.ReceiptDetail RD WITH (NOLOCK)
     WHERE RD.ReceiptKey = @cReceiptKey
     AND RD.StorerKey = @cStorer
     AND RD.SKU = @cSKU
     Group By RD.StorerKey,RD.ReceiptKey,RD.SKU
     Having Sum(RD.BeforeReceivedQty) > 0)

   BEGIN
    IF @cPromptVerifyPKScn = '1'
    BEGIN

    SELECT @cBaseUOM = PACK.PackUOM3,
    @cPackKey = S.PackKey,
    @cPackUOM = CASE @cPrefUOM
      WHEN '2' THEN PACK.PackUOM1 -- Case
      WHEN '3' THEN PACK.PackUOM2 -- Inner pack
      WHEN '6' THEN PACK.PackUOM3 -- Master unit
      WHEN '1' THEN PACK.PackUOM4 -- Pallet
      WHEN '4' THEN PACK.PackUOM8 -- Other unit 1
      WHEN '5' THEN PACK.PackUOM9 -- Other unit 2
        END
     FROM dbo.PACK PACK WITH (NOLOCK)
     INNER JOIN dbo.SKU S WITH (NOLOCK) ON Pack.PackKey = S.PackKey
     WHERE S.StorerKey = @cStorer
     AND S.SKU = @cSKU

           SET @cOutField01 = @cSKU
     SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
     SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
     SET @cOutField04 = SUBSTRING( @cIVAS, 1, 20)     -- IVAS
     SET @cOutField05 = @cPackUOM -- PackUOM
     SET @cOutField06 = @cBaseUOM -- BaseUOM
     SET @cOutField07 = '' -- QTY

     SET @nScn = @nScn + 10 -- Scn= 964
     SET @nStep = @nStep + 7 -- Step = 11
              GOTO QUIT
     END
    END
   END
   ELSE -- ISNULL(@cRDTDefaultUOM,'') <> '' -- (ChewKP05)
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM  dbo.ReceiptDetail RD WITH (NOLOCK)
                    WHERE RD.ReceiptKey = @cReceiptKey
                    AND RD.StorerKey = @cStorer
                    AND RD.SKU = @cSKU
                    Group By RD.StorerKey,RD.ReceiptKey,RD.SKU
                    Having Sum(RD.BeforeReceivedQty) > 0)

      BEGIN
         IF @cPromptVerifyPKScn = '1'
         BEGIN

             SELECT @cBaseUOM = PACK.PackUOM3,
             @cPackKey = S.PackKey,
             @cPackUOM = CASE @cPrefUOM
               WHEN '2' THEN PACK.PackUOM1 -- Case
               WHEN '3' THEN PACK.PackUOM2 -- Inner pack
               WHEN '6' THEN PACK.PackUOM3 -- Master unit
               WHEN '1' THEN PACK.PackUOM4 -- Pallet
               WHEN '4' THEN PACK.PackUOM8 -- Other unit 1
               WHEN '5' THEN PACK.PackUOM9 -- Other unit 2
                 END
              FROM dbo.PACK PACK WITH (NOLOCK)
              INNER JOIN dbo.SKU S WITH (NOLOCK) ON Pack.PackKey = S.PackKey
              WHERE S.StorerKey = @cStorer
              AND S.SKU = @cSKU

              -- (ChewKP05)
              IF ISNULL(@cRDTDefaultUOM, '') <> ''
              BEGIN
                    SET @cPackUOM = @cRDTDefaultUOM

              END

              SET @cOutField01 = @cSKU
              SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
              SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
              SET @cOutField04 = SUBSTRING( @cIVAS, 1, 20)     -- IVAS
              SET @cOutField05 = @cPackUOM -- PackUOM
              SET @cOutField06 = @cBaseUOM -- BaseUOM
              SET @cOutField07 = '' -- QTY

              SET @nScn = @nScn + 10 -- Scn= 964
              SET @nStep = @nStep + 7 -- Step = 11
              GOTO QUIT
         END
      END
   END  -- (ChewKP05)
   -- SOS#142253 End

      SET @cRCVShowPackInfo = ''
      SET @cRCVShowPackInfo = rdt.RDTGetConfig( @nFunc, 'RCVShowPackInfo', @cStorer)    -- (ChewKP03)

      IF ISNULL(@cRCVShowPackInfo,'') = '1'
      BEGIN
            SET @fMasterQty       = 0
            SET @cUOM3            = ''
            SET @fInnerPackQty    = 0
            SET @cUOM2            = ''
            SET @fCaseCntQty      = 0
            SET @cUOM1            = ''

            SELECT @cSKUPackkey = Packkey
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE Storerkey = @cStorer
            AND ReceiptKey = @cReceiptKey
            AND SKU = @cSKU


            SELECT @fMasterQty      = ISNULL(Qty,0),
                   @cUOM3           = PackUOM3,
                   @fInnerPackQty   = ISNULL(InnerPack,0),
                   @cUOM2           = PackUOM2,
                   @fCaseCntQty     = ISNULL(CaseCnt,0),
                   @cUOM1           = PackUOM1
            FROM dbo.PACK WITH (NOLOCK)
            WHERE PACKKEY = @cSKUPackkey

            SET @cOutField09 = 'UOMTYP:' + ISNULL(RTRIM(@cUOM3),'') + ':' + ISNULL(RTRIM(@cUOM2),'') + ':' + ISNULL(RTRIM(@cUOM1),'')
            SET @cOutField08 = '       ' + CAST(@fMasterQty AS NVARCHAR(3)) + ' ' + CAST(@fInnerPackQty AS NVARCHAR(3)) + ' ' +  CAST(@fCaseCntQty AS NVARCHAR(3))

      END
      ELSE
      BEGIN
         SET @cOutField09 = ''
         SET @cOutField08 = ''
      END

   IF @nFunc = 550   -- (james08)
   BEGIN
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField04 = SUBSTRING( @cIVAS, 1, 20)     -- IVAS
      SET @cOutField05 = @cUOM -- UOM
      SET @cOutField06 = '' -- QTY
      SET @cOutField07 = '' -- Reason

      EXEC rdt.rdtSetFocusField @nMobile, 6  -- (james12)

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END
   ELSE
   BEGIN
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField04 = SUBSTRING( @cIVAS, 1, 20)     -- IVAS

   -- Get Pack info
      SELECT
         @cMUOM_Desc = Pack.PackUOM3,
         @cPUOM_Desc =
            CASE @cPrefUOM
               WHEN '2' THEN Pack.PackUOM1 -- Case
               WHEN '3' THEN Pack.PackUOM2 -- Inner pack
               WHEN '6' THEN Pack.PackUOM3 -- Master unit
               WHEN '1' THEN Pack.PackUOM4 -- Pallet
               WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
               WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
            END,
            @nPUOM_Div = CAST( IsNULL(
            CASE @cPrefUOM
               WHEN '2' THEN Pack.CaseCNT
               WHEN '3' THEN Pack.InnerPack
               WHEN '6' THEN Pack.QTY
               WHEN '1' THEN Pack.Pallet
               WHEN '4' THEN Pack.OtherUnit1
               WHEN '5' THEN Pack.OtherUnit2
            END, 1) AS INT)
      FROM dbo.SKU SKU WITH (NOLOCK)
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorer
         AND SKU.SKU = @cSKU

      -- Convert to prefer UOM QTY
      IF @cPrefUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
      END

      IF @cPUOM_Desc = ''
      BEGIN
         SET @cOutField05 = ''      -- @cPUOM_Desc
         SET @cOutField07 = ''      -- @nPQTY
         SET @cOutField10 = '1:1'   -- @nPUOM_Div
         SET @cFieldAttr07 = 'O'
      END
      ELSE
      BEGIN
         SET @cOutField05 = @cPUOM_Desc
         SET @cOutField07 = ''
         SET @cOutField10 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      END
      SET @cOutField06 = @cMUOM_Desc   -- @cMUOM_Desc
      SET @cOutField08 = ''            -- @nPQTY
      SET @cOutField09 = ''            -- Reason

      -- Go to next screen
      SET @nScn  = 965     -- hardcoded bcoz the screen no is not in seq
      SET @nStep = 12
   END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
-- (Vicky03) - Start
      -- Prompt Option Screen if RDT StorerConfigkey = PromptOptionScn turned on
      IF @cPromptOpScn = '1'
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = ''

         SET @cLottable01_Code = ''
         SET @cLottable02_Code = ''
         SET @cLottable03_Code = ''
         SET @cLottable04_Code = ''

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

      SET @nScn = @nScn + 8 -- Scn= 962
         SET @nStep = @nStep + 5 -- Step = 9
      END
      ELSE -- (Vicky03) - End
      BEGIN
         SET @cOutField01 = '' -- @cID  -- (ChewKP07)
         SET @cOutField02 = @cLOC   -- (james09)

         SET @cLottable01_Code = '' --SOS#81879
         SET @cLottable02_Code = '' --SOS#81879
         SET @cLottable03_Code = '' --SOS#81879
         SET @cLottable04_Code = '' --SOS#81879

         -- (Vicky02) - Start
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
         -- (Vicky02) - End

         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
     END
   END

   GOTO Quit

   Step_4_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- SKU
      SET @cOutField04 = @cID    -- (james09)
      SET @cSKU = ''

      IF @nRetainSKUDesc = 0
      BEGIN
         SET @cOutField02 = '' -- SKU desc 1
         SET @cOutField03 = '' -- SKU desc 2
      END

      SET @cLottable01_Code = '' --SOS#81879
      SET @cLottable02_Code = '' --SOS#81879
      SET @cLottable03_Code = '' --SOS#81879
      SET @cLottable04_Code = '' --SOS#81879

   END
END
GOTO Quit


/********************************************************************************
Step 5. Scn = 955. SKU, QTY screen
   SKU       (field01, display)
   SKU desc  (field02, field03, display)
   IVAS      (field04, display)
   UOM       (field05)
   QTY       (field06)
   Reason    (field07)
********************************************************************************/
Step_5:
 BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cUOM = @cInField05
      SET @cQTY = @cInField06
      SET @cReasonCode = @cInField07

      -- Validate UOM field
      IF @cUOM = '' OR @cUOM IS NULL
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 60418, @cLangCode, 'DSP') --'UOM is required'
         SET @cUOM = ''
         EXEC rdt.rdtSetFocusField @nMobile, 5
         GOTO Step_5_Fail
      END

      IF @cPrePackByBOM = '1' --configkey 'PrePackByBOM' has been setup
      BEGIN
         SET @nCountSku = 0

         --get total num of componentsku
         SELECT @nCountSku = COUNT(ComponentSku)
         FROM dbo.BillOfMaterial WITH (NOLOCK)
         WHERE SKU = @cSKU
            AND StorerKey = @cStorer

         --if there is none of componentSku, straight go for normal validation for uom
         IF @nCountSKu = 0
            GOTO Validate_UOM
         ELSE--if there is one or more componentsku
         BEGIN
            -- Validate UOM exists
            SELECT DISTINCT @cPackKey = P.PackKey
            FROM dbo.Pack P WITH (NOLOCK)
--               INNER JOIN dbo.SKU S WITH (NOLOCK) ON P.PackKey = S.PackKey  -- SOS#142591 Lau001
               INNER JOIN dbo.UPC S WITH (NOLOCK) ON P.PackKey = S.PackKey  -- SOS#142591 Lau001
               INNER JOIN dbo.BillOfMaterial BOM WITH (NOLOCK)
                  ON BOM.SKU = S.Sku AND BOM.StorerKey = S.StorerKey
            WHERE BOM.StorerKey = @cStorer
               AND BOM.SKU = @cSKU
               AND @cUOM IN (
                  P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4,
                  P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9)
            IF @@ROWCOUNT = 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( 60445, @cLangCode, 'DSP') --'Invalid UOM'
               SET @cUOM = ''
               EXEC rdt.rdtSetFocusField @nMobile, 5
               GOTO Step_5_Fail
            END

            GOTO Validate_Qty
         END
      END

      Validate_UOM:
      -- Validate UOM exists
      SELECT @cPackKey = P.PackKey
      FROM dbo.Pack P WITH (NOLOCK)
         INNER JOIN dbo.SKU S WITH (NOLOCK) ON P.PackKey = S.PackKey
      WHERE S.StorerKey = @cStorer
         AND S.SKU = @cSKU
         AND @cUOM IN (
            P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4,
            P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9)
      IF @@ROWCOUNT = 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 60419, @cLangCode, 'DSP') --'Invalid UOM'
         SET @cUOM = ''
         EXEC rdt.rdtSetFocusField @nMobile, 5
         GOTO Step_5_Fail
      END

      Validate_Qty:
      -- Validate QTY field
      IF @cQTY = '' OR @cQTY IS NULL
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 60420, @cLangCode, 'DSP') --'QTY is required'
         SET @cQTY = ''
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Step_5_Fail
      END

      -- Validate QTY is numeric
      IF IsNumeric( @cQTY) = 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 60421, @cLangCode, 'DSP') --'Invalid QTY'
         SET @cQTY = ''
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Step_5_Fail
      END

      -- Validate QTY is integer
      DECLARE @i INT
      /* (Vanessa01)
      SET @i = 1
      WHILE @i <= LEN( RTRIM( @cQTY))
      BEGIN
         IF NOT (SUBSTRING( @cQTY, @i, 1) >= '0' AND SUBSTRING( @cQTY, @i, 1) <= '9')
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 60435, @cLangCode, 'DSP') --'Invalid QTY'
            SET @cQTY = ''
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO Step_5_Fail
            BREAK
         END
         SET @i = @i + 1
      END
      (Vanessa01) */

      -- Validate QTY < 0
      -- SELECT @nQTY = CAST( @cQTY AS FLOAT) -- (Vanessa01)
      IF CAST( @cQTY AS FLOAT) < 0  -- (Vanessa01)
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 60422, @cLangCode, 'DSP') --'QTY must > 0'
         SET @cQTY = ''
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Step_5_Fail
      END

      -- Validate reason code exists
      IF @cReasonCode <> '' AND @cReasonCode IS NOT NULL
         IF NOT EXISTS( SELECT Code
            FROM dbo.CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'ASNREASON'
               AND Code = @cReasonCode)
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 60429, @cLangCode, 'DSP') --'Invalid ReasonCode'
            SET @cReasonCode = ''
            EXEC rdt.rdtSetFocusField @nMobile, 7
            GOTO Step_5_Fail
         END

      -- Convert QTY to EA
      SET @b_success = 0
      EXECUTE dbo.nspUOMCONV
         @n_fromqty    = @cQTY,
         @c_fromuom    = @cUOM,
         @c_touom      = '',
         @c_packkey    = @cPackkey,
         @n_toqty      = @nQTY         OUTPUT,
         @b_Success    = @b_Success    OUTPUT,
         @n_err        = @nErrNo       OUTPUT,
         @c_errmsg     = @cErrMsg      OUTPUT
      IF @b_success = 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 60423, @cLangCode, 'DSP') --'nspUOMCONV error'
      GOTO Step_5_Fail
      END

      -- Start (Vanessa01)
      -- Validate QTY < 1
      IF FLOOR(@nQTY) < 1
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 60462, @cLangCode, 'DSP') --'UOMConvQTY < 1'
         SET @cQTY = ''
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Step_5_Fail
      END
      -- End (Vanessa01)

      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorer)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, @cID, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cPOKey       NVARCHAR( 10), ' +
               '@cLOC         NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@nQTY         INT,           ' +
               '@cLottable01  NVARCHAR(18),  ' +
               '@cLottable02  NVARCHAR(18),  ' +
               '@cLottable03  NVARCHAR(18),  ' +
               '@dLottable04  DATETIME,      ' +
               '@nErrNo       INT            OUTPUT,  ' +
               '@cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cReceiptKey, @cPOKey, @cLOC, @cID, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               GOTO Step_5_Fail
            END
         END
      END

--       -- SOS80652
--       IF @cNewSKUFlag = 'Y' AND @cAllowOverRcpt = '0'
--       BEGIN
--         UPDATE dbo.Receiptdetail
--           SET QTYExpected =  @nQTY,
--               UOM = @cUOM,
--               Trafficcop = NULL
--         WHERE ReceiptKey = @cReceiptKey
--         AND   Receiptlinenumber = @cReceiptLineNo
--         AND   Finalizeflag = 'N'
--       END

      -- Init next screen var

/********************************************************************************************************************/
/* SOS#81879 - Start                                                                                                */
/* Generic Lottables Computation (PRE): To compute Lottables before going to Lottable Screen                        */
/* Setup spname in CODELKUP.Long where ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05'  */
/* 1. Setup RDT.Storerconfigkey = <Lottable01/02/03/04/05> , sValue = <Lottable01/02/03/04/05Label>                 */
/* 2. Setup Codelkup.Listname = ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05' and     */
/*    Codelkup.Short = 'PRE' and Codelkup.Long = <SP Name>                                */
/********************************************************************************************************************/

      IF (IsNULL(@cLottable01_Code, '') <> '') OR (IsNULL(@cLottable02_Code, '') <> '') OR (IsNULL(@cLottable03_Code, '') <> '') OR
         (IsNULL(@cLottable04_Code, '') <> '') OR (IsNULL(@cLottable05_Code, '') <> '')
      BEGIN
    --(james01)
--    SET @cLottable01 = ''
--    SET @cLottable02 = ''
--    SET @cLottable03 = ''
--    SET @dLottable04 = 0
--    SET @dLottable05 = 0


         --initiate @nCounter = 1
         SET @nCountLot = 1

         --retrieve value for pre lottable01 - 05
         WHILE @nCountLot <=5 --break the loop when @nCount >5
         BEGIN
            IF @nCountLot = 1
            BEGIN
               SET @cListName = 'Lottable01'
               SET @cLottableLabel = @cLottable01_Code
            END
            ELSE
            IF @nCountLot = 2
            BEGIN
               SET @cListName = 'Lottable02'
               SET @cLottableLabel = @cLottable02_Code
            END
            ELSE
            IF @nCountLot = 3
            BEGIN
               SET @cListName = 'Lottable03'
               SET @cLottableLabel = @cLottable03_Code
            END
            ELSE
            IF @nCountLot = 4
            BEGIN
               SET @cListName = 'Lottable04'
               SET @cLottableLabel = @cLottable04_Code
            END
            ELSE
            IF @nCountLot = 5
            BEGIN
               SET @cListName = 'Lottable05'
               SET @cLottableLabel = @cLottable05_Code
            END

            /* comment (james12)
             --get short, store procedure and lottablelable value for each lottable
             SET @cShort = ''
             SET @cStoredProd = ''
             SELECT TOP 1 @cShort = ISNULL(RTRIM(C.Short),''),
                    @cStoredProd = IsNULL(RTRIM(C.Long), '')
             FROM dbo.CodeLkUp C WITH (NOLOCK)
             JOIN RDT.StorerConfig S WITH (NOLOCK) ON (C.ListName = S.ConfigKey AND C.Code = S.SValue)
             WHERE C.ListName = @cListName
             AND   C.Code = @cLottableLabel
             ORDER BY
             CASE WHEN C.StorerKey = @cStorer THEN 1 ELSE 2 END -- (ChewKP08)
            */

            SELECT TOP 1 @cShort = C.Short,
                   @cStoredProd = IsNULL( C.Long, '')
            FROM dbo.CodeLkUp C WITH (NOLOCK)
            WHERE C.Listname = @cListName
            AND   C.Code = @cLottableLabel
            AND (C.StorerKey = @cStorer OR C.Storerkey = '') --SOS308961
            ORDER BY C.StorerKey DESC

             IF @cShort = 'PRE' AND @cStoredProd <> ''
             BEGIN
                 -- (james01) start
               IF @cListName = 'Lottable01'
                  SET @cLottable01 = ''
               ELSE IF @cListName = 'Lottable02'
                  SET @cLottable02 = ''
               ELSE IF @cListName = 'Lottable03'
                  SET @cLottable03 = ''
               ELSE IF @cListName = 'Lottable04'
                  SET @dLottable04 = ''
               ELSE IF @cListName = 'Lottable05'
                  SET @dLottable05 = ''
               -- (james01) end

               --SOS133226 (james02)
               SELECT TOP 1 @cReceiptLineNo = ReceiptLinenumber FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorer
                  AND ReceiptKey = @cReceiptKey
                  AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END
                  AND SKU = @cSKU
                  AND FinalizeFlag = 'N'
               ORDER BY ReceiptLinenumber

               SET @cSourcekey = ISNULL(RTRIM(@cReceiptKey), '') + ISNULL(RTRIM(@cReceiptLineNo), '')

               EXEC dbo.ispLottableRule_Wrapper
                @c_SPName            = @cStoredProd,
                  @c_ListName          = @cListName,
                  @c_Storerkey         = @cStorer,
                  @c_Sku               = @cSKU,
                  @c_LottableLabel     = @cLottableLabel,
                  @c_Lottable01Value   = '',
                  @c_Lottable02Value   = '',
                  @c_Lottable03Value   = '',
                  @dt_Lottable04Value  = '',
                  @dt_Lottable05Value  = '',
                  @c_Lottable01        = @cLottable01 OUTPUT,
                  @c_Lottable02        = @cLottable02 OUTPUT,
                  @c_Lottable03        = @cLottable03 OUTPUT,
                  @dt_Lottable04       = @dLottable04 OUTPUT,
                  @dt_Lottable05       = @dLottable05 OUTPUT,
                  @b_Success           = @b_Success   OUTPUT,
                  @n_Err               = @nErrNo      OUTPUT,
                  @c_Errmsg            = @cErrMsg     OUTPUT,
--                @c_Sourcekey         = @cReceiptKey,  --SOS133226  (james02)
                  @c_Sourcekey         = @cSourcekey,
                  @c_Sourcetype        = 'RDTRECEIPT'

      --IF @b_success <> 1
               IF ISNULL(@cErrMsg, '') <> ''
               BEGIN
                  SET @cErrMsg = @cErrMsg
                  GOTO Step_5_Fail
                  BREAK
               END

               SET @cLottable01 = IsNULL( @cLottable01, '')
               SET @cLottable02 = IsNULL( @cLottable02, '')
               SET @cLottable03 = IsNULL( @cLottable03, '')
               SET @dLottable04 = IsNULL( @dLottable04, 0)
               SET @dLottable05 = IsNULL( @dLottable05, 0)

                IF @dLottable04 > 0
                BEGIN
                   SET @cLottable04 = RDT.RDTFormatDate(@dLottable04)
                END
                ELSE
                BEGIN
                   SET @cLottable04 = '' -- (ChewKP09)
                END

                IF @dLottable05 > 0
                BEGIN
                   SET @cLottable05 = RDT.RDTFormatDate(@dLottable05)
                END

--
--      SET @cOutField02 = @cLottable01
--      SET @cOutField04 = @cLottable02
--      SET @cOutField06 = @cLottable03
--      SET @cOutField08 = CASE WHEN @dLottable04 <> 0 THEN rdt.rdtFormatDate( @dLottable04) END
--      SET @cOutField10 = CASE WHEN @dLottable05 <> 0 THEN rdt.rdtFormatDate( @dLottable05) END
      END

            -- increase counter by 1
            SET @nCountLot = @nCountLot + 1
       END -- nCount
    END -- Lottable <> ''
/********************************************************************************************************************/
/* SOS#81879 - End                                                                                                  */
/* Generic Lottables Computation (PRE): To compute Lottables before going to Lottable Screen                        */
/********************************************************************************************************************/


      IF @cHasLottable = '1'
      BEGIN

         -- (Vicky07) - Start
         SET @cDisplayLot03 = ''
         SET @cDisplayLot03 = rdt.RDTGetConfig( 0, 'DisplayLot03', @cStorer)
         -- (Vicky07) - End

         -- Init lot label
         SELECT
            @cOutField01 = 'Lottable01:',
            @cOutField03 = 'Lottable02:',
            @cOutField05 = 'Lottable03:',
            @cOutField07 = 'Lottable04:',
            @cOutField09 = 'Lottable05:'

         -- Disable lot label and lottable field
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
         BEGIN
            SET @cFieldAttr02 = 'O' -- (Vicky02)
            SET @cOutField02 = ''
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field02', 'NULL', 'output', 'NULL', 'NULL', '')
         END
         ELSE
         BEGIN
            -- Populate lot label and lottable
         SELECT
               @cOutField01 = @cLotLabel01,
               @cOutField02 = ISNULL(@cLottable01, '') -- SOS#81879
         END

         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
         BEGIN
            SET @cFieldAttr04 = 'O' -- (Vicky02)
            SET @cOutField04 = ''
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field04', 'NULL', 'output', 'NULL', 'NULL', '')
         END
         ELSE
         BEGIN
            SELECT
               @cOutField03 = @cLotLabel02,
               @cOutField04 = ISNULL(@cLottable02, '')  -- SOS#81879
         END

         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
         BEGIN
            -- (Vicky07) - Start
            IF @cDisplayLot03 = '1'
            BEGIN
              SET @cOutField06 = ISNULL(@cLottable03, '')
            END
            ELSE
            BEGIN
               SET @cFieldAttr06 = 'O' -- (Vicky02)
               SET @cOutField06 = ''
            END
            -- (Vicky07) - End
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field06', 'NULL', 'output', 'NULL', 'NULL', '')
         END
         ELSE
         BEGIN
         SELECT
               @cOutField05 = @cLotLabel03,
               @cOutField06 = ISNULL(@cLottable03, '')  -- SOS#81879
         END

         IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
         BEGIN
            SET @cFieldAttr08 = 'O' -- (Vicky02)
            SET @cOutField08 = ''
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
         END
         ELSE
         BEGIN
            SELECT
               @cOutField07 = @cLotLabel04,
               @cOutField08 = @cLottable04 -- SOS#81879

            -- Check if lottable04 is blank/is 01/01/1900 then no need to default anything and let user to scan (james07)
            IF ISNULL(@cLottable04, '') = '' OR rdt.rdtConvertToDate( @cLottable04) IS NULL
               SET @cOutField08 = ''
         END

         IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL
         BEGIN
            SET @cFieldAttr10 = 'O' -- (Vicky02)
            SET @cOutField10 = ''
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')
         END
         ELSE
         BEGIN
            -- Lottable05 is usually RCP_DATE
--            IF @cLottable05_Code = 'RCP_DATE' AND (@cLottable05 = '' OR RDT.RDTFormatDate(@cLottable05) = '01/01/1900') -- Edit by james on 20/03/2009
--            IF @cLottable05_Code = 'RCP_DATE' AND (ISNULL(@cLottable05, '') = '' OR RDT.RDTFormatDate(@cLottable05) = '01/01/1900')
--            BEGIN
--               SET @cLottable05 = RDT.RDTFormatDate( GETDATE())
--            END

               SELECT @cOutField09 = @cLotLabel05,
                      @cOutField10 = @cLottable05 -- (Vicky02)

            -- Check if lottable05 is blank/is 01/01/1900 then default system date. User no need to scan (james07)
            IF @cLottable05_Code = 'RCP_DATE' OR ISNULL(@cLottable05, '') = '' OR rdt.rdtConvertToDate( @cLottable05) IS NULL
               SET @cOutField10 = RDT.RDTFormatDate( GETDATE())
         END

         -- (james12)
         EXEC rdt.rdt_LottableField_Setfocus
            @nMobile       = @nMobile,
            @c_LotLabel01  = @cLotLabel01,
            @c_LotLabel02  = @cLotLabel02,
            @c_LotLabel03  = @cLotLabel03,
            @c_LotLabel04  = @cLotLabel04,
            @c_LotLabel05  = @cLotLabel05,
            @c_Lottable01  = @cLottable01,
            @c_Lottable02  = @cLottable02,
            @c_Lottable03  = @cLottable03,
            @c_Lottable04  = @cLottable04,
            @c_Lottable05  = @cLottable05

      END

      -- Go to next screen
      IF @cHasLottable = '0'
      BEGIN
         -- (Vicky07) - Start
         SET @cDisplayLot03 = ''
         SET @cDisplayLot03 = rdt.RDTGetConfig( 0, 'DisplayLot03', @cStorer)

         IF @cDisplayLot03 = '1'
         BEGIN
             SET @cOutField05 = 'Lottable03:'
             SET @cOutField06 = ISNULL(@cLottable03, '')  -- SOS#81879

             SET @nScn = @nScn + 1
             SET @nStep = @nStep + 1

             EXEC rdt.rdtSetFocusField @nMobile, 6 -- Lottable03
         END
         ELSE
         BEGIN
         -- (Vicky07) - End
            GOTO Receiving
         END
      END
      ELSE
      BEGIN
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         -- EXEC rdt.rdtSetFocusField @nMobile, 2 -- Lottable01  comment (james12)
      END
   END -- Input = 1

   IF @nInputKey = 0 -- Esc or No
   BEGIN

      -- Prepare prev screen var
      SET @cOutField01 = CASE WHEN (@cPrePackByBOM = '1' AND @cUPCSKU <> @cSKU) THEN @cUPCSKU
                              ELSE @cSKU END
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField04 = @cID

    SET @cLottable01 = ''
    SET @cLottable02 = ''
    SET @cLottable03 = ''
    SET @dLottable04 = 0
    SET @dLottable05 = 0
    SET @cLottable04 = ''

      -- (Vicky02) - Start
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
      -- (Vicky02) - End

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      -- Retain the key-in value
      SET @cOutField05 = @cInField05
      SET @cOutField06 = @cInField06
      SET @cOutField07 = @cInField07
   END

END
GOTO Quit


/********************************************************************************
Step 6. scn = 956. Lottable
   LottableLabel01   (field01, display)
   Lottable01        (field02)
   LottableLabel02   (field03, display)
   Lottable02        (field04)
   LottableLabel03   (field05, display)
   Lottable03        (field06)
   LottableLabel04   (field07, display)
   Lottable04        (field08)
   LottableLabel05   (field09, display)
   Lottable05        (field10)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cInField10 = ''--ang02
      -- Screen mapping
      SET @cInField10 = CASE WHEN ISNULL(@cInField10, '') = '' AND ISNULL(@cOutField10, '') <> '' THEN @cOutField10 ELSE @cInField10 END

      SELECT
         @cLottable01 = CASE WHEN @cLotlabel01 <> '' AND @cLotlabel01 IS NOT NULL THEN @cInField02 ELSE '' END,
         @cLottable02 = CASE WHEN @cLotlabel02 <> '' AND @cLotlabel02 IS NOT NULL THEN @cInField04 ELSE '' END,
         @cLottable03 = CASE WHEN @cLotlabel03 <> '' AND @cLotlabel03 IS NOT NULL THEN @cInField06 ELSE '' END,
         @cLottable04 = CASE WHEN @cLotlabel04 <> '' AND @cLotlabel04 IS NOT NULL THEN @cInField08 ELSE '' END,
         @cLottable05 = CASE WHEN @cLotlabel05 <> '' AND @cLotlabel05 IS NOT NULL THEN @cInField10 ELSE '' END

      -- (Vicky02) - Start
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

      -- (Vicky02) - End

/********************************************************************************************************************/
/* SOS#81879 - Start                                                                                                */
/* Generic Lottables Computation (POST): To compute Lottables after input of Lottable value                         */
/* Setup spname in CODELKUP.Long where ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05'  */
/* 1. Setup RDT.Storerconfigkey = <Lottable01/02/03/04/05> , sValue = <Lottable01/02/03/04/05Label>                 */
/* 2. Setup Codelkup.Listname = ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05' and     */
/*    Codelkup.Short = 'POST' and Codelkup.Long = <SP Name>                                                         */
/********************************************************************************************************************/


      --initiate @nCounter = 1
      SET @nCountLot = 1

      WHILE @nCountLot < = 5
      BEGIN
         IF @nCountLot = 1
         BEGIN
            SET @cListName = 'Lottable01'
            SET @cLottableLabel = @cLottable01_Code
         END
         ELSE
         IF @nCountLot = 2
         BEGIN
            SET @cListName = 'Lottable02'
            SET @cLottableLabel = @cLottable02_Code
         END
         ELSE
         IF @nCountLot = 3
         BEGIN
            SET @cListName = 'Lottable03'
            SET @cLottableLabel = @cLottable03_Code
         END
         ELSE
         IF @nCountLot = 4
         BEGIN
            SET @cListName = 'Lottable04'
            SET @cLottableLabel = @cLottable04_Code
         END
         ELSE
         IF @nCountLot = 5
         BEGIN
            SET @cListName = 'Lottable05'
            SET @cLottableLabel = @cLottable05_Code
         END

         DECLARE @cTempSKU NVARCHAR(15)

         SET @cShort = ''
         SET @cStoredProd = ''
         SET @cTempSKU = ''

         SELECT TOP 1 @cShort = C.Short,
                @cStoredProd = IsNULL( C.Long, '')
         FROM dbo.CodeLkUp C WITH (NOLOCK)
         WHERE C.Listname = @cListName
         AND   C.Code = @cLottableLabel
         AND  (C.StorerKey = @cStorer OR C.Storerkey = '') --SOS308961
         ORDER By C.StorerKey DESC


         IF @cShort = 'POST' AND @cStoredProd <> ''
         BEGIN

         -- (ChewKP04)
         SET @cConvertLottable04Format = ''
         SET @cConvertLottable04Format = rdt.RDTGetConfig( @nFunc, 'ConvertLottable04Format', @cStorer)

         IF ISNULL(RTRIM(@cConvertLottable04Format),'')  <> ''
         BEGIN
               SET @dLottable04Format = RDT.rdtConvertDateFormat(@cLottable04,@cConvertLottable04Format)

               IF ISNULL (@dLottable04Format,'' ) <> ''
               BEGIN
                       SET @dLottable04 = @dLottable04Format
               END
         END
         ELSE IF @cConvertLottable04Format = '0' OR ISNULL(RTRIM(@cConvertLottable04Format),'') = ''
         BEGIN
            IF rdt.rdtIsValidDate(@cLottable04) = 1 --valid date
               SET @dLottable04 = rdt.rdtConvertToDate( @cLottable04)
         END

         --IF rdt.rdtIsValidDate(@cLottable04) = 1 --valid date
         --   SET @dLottable04 = rdt.rdtConvertToDate( @cLottable04)

         IF rdt.rdtIsValidDate(@cLottable05) = 1 --valid date
            SET @dLottable05 = rdt.rdtConvertToDate( @cLottable05)

         IF  @cPrePackByBOM = '1'
         BEGIN
          SELECT @cTempSKU = ''
         END
           ELSE
           BEGIN
             SELECT @cTempSKU = @cSku
           END

           --SOS133226 (james02)
           SET @cSourcekey = ISNULL(RTRIM(@cReceiptKey), '') + ISNULL(RTRIM(@cReceiptLineNo), '')

       EXEC dbo.ispLottableRule_Wrapper
       @c_SPName            = @cStoredProd,
       @c_ListName          = @cListName,
       @c_Storerkey         = @cStorer,
       @c_Sku               = @cSku,
       @c_LottableLabel     = @cLottableLabel,
       @c_Lottable01Value   = @cLottable01,
       @c_Lottable02Value   = @cLottable02,
       @c_Lottable03Value   = @cLottable03,
       @dt_Lottable04Value  = @dLottable04,
       @dt_Lottable05Value  = @dLottable05,
       @c_Lottable01        = @cTempLottable01 OUTPUT,
       @c_Lottable02        = @cTempLottable02 OUTPUT,
       @c_Lottable03        = @cTempLottable03 OUTPUT,
       @dt_Lottable04       = @dTempLottable04 OUTPUT,
       @dt_Lottable05       = @dTempLottable05 OUTPUT,
       @b_Success           = @b_Success   OUTPUT,
       @n_Err               = @nErrNo      OUTPUT,
       @c_Errmsg            = @cErrMsg     OUTPUT,
--         @c_Sourcekey         = @cReceiptKey, -- (james02)
       @c_Sourcekey         = @cSourcekey,
       @c_Sourcetype        = 'RDTRECEIPT'

                 --IF @b_success <> 1
                 IF ISNULL(@cErrMsg, '') <> ''
                 BEGIN
                    SET @cErrMsg = @cErrMsg

                    IF @cListName = 'Lottable01'
                       EXEC rdt.rdtSetFocusField @nMobile, 2
                    ELSE IF @cListName = 'Lottable02'
                       EXEC rdt.rdtSetFocusField @nMobile, 4
                    ELSE IF @cListName = 'Lottable03'
                       EXEC rdt.rdtSetFocusField @nMobile, 6
                    ELSE IF @cListName = 'Lottable04'
                       EXEC rdt.rdtSetFocusField @nMobile, 8


                    GOTO Step_6_Fail
                 END


       SET @cTempLottable01 = IsNULL( @cTempLottable01, '')
       SET @cTempLottable02 = IsNULL( @cTempLottable02, '')
       SET @cTempLottable03 = IsNULL( @cTempLottable03, '')
       SET @dTempLottable04 = IsNULL( @dTempLottable04, 0)
       SET @dTempLottable05 = IsNULL( @dTempLottable05, 0)


       SET @cOutField02 = CASE WHEN @cTempLottable01 <> '' THEN @cTempLottable01 ELSE @cLottable01 END
       SET @cOutField04 = CASE WHEN @cTempLottable02 <> '' THEN @cTempLottable02 ELSE @cLottable02 END
       SET @cOutField06 = CASE WHEN @cTempLottable03 <> '' THEN @cTempLottable03 ELSE @cLottable03 END
       SET @cOutField08 = CASE WHEN @dTempLottable04 <> 0  THEN rdt.rdtFormatDate( @dTempLottable04) ELSE @cLottable04 END

       SET @cLottable01 = IsNULL(@cOutField02, '')
       SET @cLottable02 = IsNULL(@cOutField04, '')
       SET @cLottable03 = IsNULL(@cOutField06, '')
       SET @cLottable04 = IsNULL(@cOutField08, '')

        END -- Short

        --increase counter by 1
        SET @nCountLot = @nCountLot + 1

      END -- end of while

      -- Validate lottable01
      IF @cLotlabel01 <> '' AND @cLotlabel01 IS NOT NULL
      BEGIN
         --SET @cLottable01 = @cOutField02--@cInField02
         IF @cLottable01 = '' OR @cLottable01 IS NULL
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 60430, @cLangCode, 'DSP') --'Lottable01 required'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_6_Fail
         END
      END

      -- Validate lottable02
      IF @cLotlabel02 <> '' AND @cLotlabel02 IS NOT NULL
      BEGIN
         IF @cLottable02 = '' OR @cLottable02 IS NULL
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 60431, @cLangCode, 'DSP') --'Lottable02 required'
            EXEC rdt.rdtSetFocusField @nMobile, 4
            GOTO Step_6_Fail
         END
      END

      -- Validate lottable03
      IF @cLotlabel03 <> '' AND @cLotlabel03 IS NOT NULL
      BEGIN
         IF @cLottable03 = '' OR @cLottable03 IS NULL
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 60432, @cLangCode, 'DSP') --'Lottable03 required'
            EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Step_6_Fail
         END
      END

      -- Validate lottable04
      IF @cLotlabel04 <> '' AND @cLotlabel04 IS NOT NULL
      BEGIN
         -- Validate empty
       IF @cLottable04 = '' OR @cLottable04 IS NULL
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 60433, @cLangCode, 'DSP') --'Lottable04 required'
            EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO Step_6_Fail
         END
         -- Validate date
         IF RDT.rdtIsValidDate( @cLottable04) = 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 60434, @cLangCode, 'DSP') --'Invalid date'
            EXEC rdt.rdtSetFocusField @nMobile, 8
            GOTO Step_6_Fail
         END
      END

      -- Validate lottable05
      IF @cLotlabel05 <> '' AND @cLotlabel05 IS NOT NULL
      BEGIN
         -- Validate empty
         IF @cLottable05 = '' OR @cLottable05 IS NULL
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 60437, @cLangCode, 'DSP') --'Lottable05 required'
            EXEC rdt.rdtSetFocusField @nMobile, 10
            GOTO Step_6_Fail
         END
         -- Validate date
         IF RDT.rdtIsValidDate( @cLottable05) = 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 60434, @cLangCode, 'DSP') --'Invalid date'
            EXEC rdt.rdtSetFocusField @nMobile, 10
            GOTO Step_6_Fail
         END
      END

      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorer)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, @cID, @cSKU, @nQTY, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cStorerKey   NVARCHAR( 15), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cPOKey       NVARCHAR( 10), ' +
               '@cLOC         NVARCHAR( 10), ' +
               '@cID          NVARCHAR( 18), ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@nQTY         INT,           ' +
               '@cLottable01  NVARCHAR(18),  ' +
               '@cLottable02  NVARCHAR(18),  ' +
               '@cLottable03  NVARCHAR(18),  ' +
               '@dLottable04  DATETIME,      ' +
               '@nErrNo       INT            OUTPUT,  ' +
               '@cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cReceiptKey, @cPOKey, @cLOC, @cID, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               GOTO Step_6_Fail
            END
         END
      END

      GOTO Receiving
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Go back to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      SET @cRCVShowPackInfo = ''
      SET @cRCVShowPackInfo = rdt.RDTGetConfig( @nFunc, 'RCVShowPackInfo', @cStorer)    -- (ChewKP03)


      IF ISNULL(@cRCVShowPackInfo,'') = '1'
      BEGIN
            SET @fMasterQty       = 0
            SET @cUOM3            = ''
            SET @fInnerPackQty    = 0
            SET @cUOM2            = ''
            SET @fCaseCntQty      = 0
            SET @cUOM1            = ''

            SELECT @fMasterQty      = ISNULL(Qty,0),
                   @cUOM3           = PackUOM3,
                   @fInnerPackQty   = ISNULL(InnerPack,0),
                   @cUOM2           = PackUOM2,
                   @fCaseCntQty     = ISNULL(CaseCnt,0),
                   @cUOM1           = PackUOM1
            FROM dbo.PACK WITH (NOLOCK)
            WHERE PACKKEY = @cPackkey

            SET @cOutField09 = 'UOMTYP:' + ISNULL(RTRIM(@cUOM3),'') + ':' + ISNULL(RTRIM(@cUOM2),'') + ':' + ISNULL(RTRIM(@cUOM1),'')
            SET @cOutField08 = '       ' + CAST(@fMasterQty AS NVARCHAR(3)) + ' ' + CAST(@fInnerPackQty AS NVARCHAR(3)) + ' ' +  CAST(@fCaseCntQty AS NVARCHAR(3))
      END
      ELSE
      BEGIN
         SET @cOutField08 = ''
         SET @cOutField09 = ''
      END

      -- Load prev screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField04 = SUBSTRING( @cIVAS, 1, 20)     -- IVAS
      SET @cOutField05 = @cUOM
      SET @cOutField06 = @cQTY
      SET @cOutField07 = @cReasonCode

      EXEC rdt.rdtSetFocusField @nMobile, 6  -- (james12)

      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @dLottable04 = 0
      SET @dLottable05 = 0
      SET @cLottable04 = ''

      -- (Vicky02) - Start
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
      -- (Vicky02) - End

      -- Load prev screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField04 = SUBSTRING( @cIVAS, 1, 20)     -- IVAS

      IF @nFunc = 550
      BEGIN
         SET @cOutField05 = @cUOM
         SET @cOutField06 = @cQTY
         SET @cOutField07 = @cReasonCode

         EXEC rdt.rdtSetFocusField @nMobile, 6  -- (james12)

         -- Go back to prev screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
      ELSE
      BEGIN
         -- Get Pack info
         SELECT
            @cMUOM_Desc = Pack.PackUOM3,
            @cPUOM_Desc =
               CASE @cPrefUOM
                  WHEN '2' THEN Pack.PackUOM1 -- Case
                  WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                  WHEN '6' THEN Pack.PackUOM3 -- Master unit
                  WHEN '1' THEN Pack.PackUOM4 -- Pallet
                  WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                  WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
               END,
               @nPUOM_Div = CAST( IsNULL(
               CASE @cPrefUOM
                  WHEN '2' THEN Pack.CaseCNT
                  WHEN '3' THEN Pack.InnerPack
                  WHEN '6' THEN Pack.QTY
                  WHEN '1' THEN Pack.Pallet
                  WHEN '4' THEN Pack.OtherUnit1
                  WHEN '5' THEN Pack.OtherUnit2
               END, 1) AS INT)
         FROM dbo.SKU SKU WITH (NOLOCK)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE SKU.StorerKey = @cStorer
            AND SKU.SKU = @cSKU

         -- Convert to prefer UOM QTY
         IF @cPrefUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
         END

         IF @cPUOM_Desc = ''
         BEGIN
            SET @cOutField05 = ''      -- @cPUOM_Desc
            SET @cOutField07 = ''      -- @nPQTY
            SET @cOutField10 = '1:1'   -- @nPUOM_Div
            SET @cFieldAttr07 = 'O'
         END
         ELSE
         BEGIN
            SET @cOutField05 = @cPUOM_Desc
            SET @cOutField07 = ''
            SET @cOutField10 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
         END
         SET @cOutField06 = @cMUOM_Desc   -- @cMUOM_Desc
         SET @cOutField08 = ''            -- @nPQTY
         SET @cOutField09 = ''            -- Reason

         -- Go back to prev screen
         SET @nScn = 965
         SET @nStep = 12
      END
   END
   GOTO Quit

   Step_6_Fail:
   BEGIN
      -- (Vicky02) - Start
      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''
      -- (Vicky02) - End

      -- Init next screen var
      IF @cHasLottable = '1'
      BEGIN
         -- Disable lottable
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
         BEGIN
            SET @cFieldAttr02 = 'O' -- (Vicky02)
            SET @cOutField02 = ''
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field02', 'NULL', 'output', 'NULL', 'NULL', '')
         END

         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
         BEGIN
            SET @cFieldAttr04 = 'O' -- (Vicky02)
            SET @cOutField04 = ''
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field04', 'NULL', 'output', 'NULL', 'NULL', '')
         END

         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
         BEGIN
            -- (Vicky07) - Start
            SET @cDisplayLot03 = ''
            SET @cDisplayLot03 = rdt.RDTGetConfig( 0, 'DisplayLot03', @cStorer)

            IF @cDisplayLot03 = '1'
            BEGIN
                SET @cOutField05 = 'Lottable03:'
                SET @cOutField06 = ISNULL(@cLottable03, '')
            END
            ELSE
            BEGIN
               SET @cFieldAttr06 = 'O' -- (Vicky02)
               SET @cOutField06 = ''
            END
            -- (Vicky07) - End
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field06', 'NULL', 'output', 'NULL', 'NULL', '')
         END

         IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
         BEGIN
            SET @cFieldAttr08 = 'O' -- (Vicky02)
            SET @cOutField08 = ''
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
         END

         IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL
         BEGIN
            SET @cFieldAttr10 = 'O' -- (Vicky02)
            SET @cOutField10 = ''
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')
         END
      END
   END
END
GOTO Quit


/********************************************************************************
Step 7. scn = 957. Message screen
   Msg
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 0 OR @nInputKey = 1 -- Esc or No / Yes or Send
   BEGIN
      -- Use svalue to determine which screen to go (james13)
      -- if svalue = stored proc then use sp to decide else use existing 1 = ID screen / 0 = SKU screen
      SET @cSP = ''
      SET @cSP = rdt.RDTGetConfig( @nFunc, 'NotAllowMultiCompSKUPLT', @cStorer)

      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC ' + RTRIM( @cSP) +
            ' @nMobile, @cStorer, @cReceiptKey, @cID, @nScn, @nStep, @nO_Scn OUTPUT, @nO_Step OUTPUT, @nValid OUTPUT '
         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@cStorer         NVARCHAR( 15), ' +
            '@cReceiptKey     NVARCHAR( 10), ' +
            '@cID             NVARCHAR( 18), ' +
            '@nScn            INT,           ' +
            '@nStep           INT,           ' +
            '@nO_Scn          INT OUTPUT,    ' +
            '@nO_Step         INT OUTPUT,    ' +
            '@nValid          INT OUTPUT     '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @cStorer, @cReceiptKey, @cID, @nScn, @nStep, @nO_Scn OUTPUT, @nO_Step OUTPUT, @nValid OUTPUT

         IF @nValid = 0
            GOTO STEP_7_CONTINUE -- not valid then follow usual way
         ELSE
         BEGIN
            IF @nO_Scn = 953
            BEGIN
            	SET @cAutoGenID = ''
               SET @cAutoGenID = rdt.RDTGetConfig( @nFunc, 'AutoGenID', @cStorer) -- (james03)
               IF @cAutoGenID = '1'
               BEGIN
                   EXECUTE dbo.nspg_GetKey
                           'ID',
                           10 ,
                           @cID               OUTPUT,
                           @b_success         OUTPUT,
                           @n_err             OUTPUT,
                           @c_errmsg          OUTPUT
                  IF @b_success <> 1
                  BEGIN
                     SET @nErrNo = 67388
                     SET @cErrMsg = rdt.rdtgetmessage( 60449, @cLangCode, 'DSP') -- 'GetIDKey Fail'
                     GOTO Quit
                  END
               END

               -- Go back to ID screen
               SET @nScn  = 953
               SET @nStep = 3

               SET @cOutField01 = CASE WHEN @cAutoGenID = '1' THEN @cID ELSE '' END -- ID  (james17)
               SET @cOutField02 = @cLOC      -- (james09)
            END
            ELSE IF @nO_Scn = 954
            BEGIN
               -- Go back to SKU screen
               SET @nScn  = 954
               SET @nStep = 4

               -- Init next screen var
               SET @cOutField01 = '' -- SKU
               SET @cOutField02 = '' -- SKUDesc1
               SET @cOutField03 = '' -- SKUDesc2
               SET @cOutField04 = @cID    -- (james09)
            END

            GOTO Quit
         END
      END

      STEP_7_CONTINUE:
      -- if configkey is turned on the go back to ID screen (james03)
      --IF rdt.RDTGetConfig( @nFunc, 'NotAllowMultiCompSKUPLT', @cStorer) = 1  comment (james13)
      IF @cSP = '1'
      BEGIN
      	SET @cAutoGenID = ''
         SET @cAutoGenID = rdt.RDTGetConfig( @nFunc, 'AutoGenID', @cStorer) -- (james03)
         IF @cAutoGenID = '1'
         BEGIN
             EXECUTE dbo.nspg_GetKey
                     'ID',
                     10 ,
                     @cID               OUTPUT,
                     @b_success         OUTPUT,
                     @n_err             OUTPUT,
                     @c_errmsg          OUTPUT
            IF @b_success <> 1
            BEGIN
               SET @nErrNo = 67389
               SET @cErrMsg = rdt.rdtgetmessage( 60449, @cLangCode, 'DSP') -- 'GetIDKey Fail'
               GOTO Quit
            END
         END

         -- Go back to ID screen
         SET @nScn  = 953
         SET @nStep = 3

         SET @cOutField01 = CASE WHEN @cAutoGenID = '1' THEN @cID ELSE '' END -- ID  (james17)
         SET @cOutField02 = @cLOC      -- (james09)
      END
      ELSE
      BEGIN
         -- Go back to SKU screen
         SET @nScn  = 954
         SET @nStep = 4

         -- Init next screen var
         SET @cOutField01 = '' -- SKU
         SET @cOutField02 = '' -- SKUDesc1
         SET @cOutField03 = '' -- SKUDesc2
         SET @cOutField04 = @cID    -- (james09)
      END

      -- (Vicky02) - Start
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
      -- (Vicky02) - End
   END
END
GOTO Quit

/********************************************************************************
 -- SOS80652
Step 8. Scn = 958. Option
   SKU NOT IN ASN
   OK TO ADD ?
   1=YES
   2=NO
   OPTION: (field01, input)
********************************************************************************/
Step_8:
BEGIN
	IF @nInputKey = 1 -- ENTER
   BEGIN
   	-- Screen mapping
      SET @cOption = ''
      SET @cOption = @cInField01

      IF @cOption = ''
      BEGIN
      	SET @nErrNo = 60438
         SET @cErrMsg = rdt.rdtgetmessage( 60438, @cLangCode, 'DSP') --'Option required'
         GOTO Step_8_Fail
      END

      IF @cOption <> '1' AND @cOption <> '2' AND @cOption <> ''
      BEGIN
      	SET @nErrNo = 60439
         SET @cErrMsg = rdt.rdtgetmessage( 60439, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_8_Fail
      END

      IF @cOption = '1'
      BEGIN

            DECLARE @nCount1 INT
-- -- (ChewKP06)
--            SELECT
--               @nCount1 = COUNT( DISTINCT SKU.SKU)
--            FROM dbo.SKU SKU WITH (NOLOCK)
--            LEFT OUTER JOIN dbo.UPC UPC WITH (NOLOCK) ON (SKU.StorerKey = UPC.StorerKey AND SKU.SKU = UPC.SKU)
--            WHERE SKU.Storerkey = @cStorer
--            AND (@cSKU IN (SKU.SKU, SKU.AltSKU, SKU.RetailSKU, SKU.ManufacturerSKU) OR UPC.UPC = @cSKU)
--
--            IF @nCount > 1
--            BEGIN
--               SET @nErrNo = 60440
--               SET @cErrMsg = rdt.rdtgetmessage( 60440, @cLangCode, 'DSP') --'SKU had same barcode'
--               GOTO Step_8_Fail
--            END

            --Performance tuning -- (ChewKP06)
            EXEC [RDT].[rdt_GETSKUCNT]
             @cStorerKey  = @cStorer
            ,@cSKU        = @cSKU
            ,@nSKUCnt     = @nCount1       OUTPUT
            ,@bSuccess    = @b_Success     OUTPUT
            ,@nErr        = @nErrNo        OUTPUT
            ,@cErrMsg     = @cErrMsg       OUTPUT

            -- Validate SKU/UPC
            IF @nCount1 > 1
            BEGIN
               SET @nErrNo = 60440
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'SKU had same barcode'
               GOTO Step_1_Fail
            END

         -- Added by Ricky on Jan 11th to pass the correct sku to packkey retreival

-- -- (ChewKP06)
--         SELECT   @cSku_scan  = SKU.SKU
--             FROM dbo.SKU SKU WITH (NOLOCK)
--             LEFT OUTER JOIN dbo.UPC UPC WITH (NOLOCK) ON (SKU.StorerKey = UPC.StorerKey AND SKU.SKU = UPC.SKU)
--             WHERE SKU.Storerkey = @cStorer
--             AND (@cSKU IN (SKU.SKU, SKU.AltSKU, SKU.RetailSKU, SKU.ManufacturerSKU) OR UPC.UPC = @cSKU)

         -- (ChewKP06)
         SET @cSku_scan = @cSKU

         EXEC dbo.nspg_GETSKU
                        @cStorer
         ,              @cSku_scan  OUTPUT
         ,              @b_Success  OUTPUT
         ,              @nErrNo     OUTPUT
         ,              @cErrMsg    OUTPUT

        -- Get SKU description, IVAS, lot label
        SELECT
        	  @cSKU = S.SKU,	--SOS315152
           @cSKUDesc = IsNULL( DescR, ''),
           @cIVAS = IsNULL( IVAS, ''),
           @cLotLabel01 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable01Label AND C.ListName = 'LOTTABLE01' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER BY C.StorerKey DESC), ''),  -- SOS308961
           @cLotLabel02 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER BY C.StorerKey DESC), ''),  -- SOS308961
           @cLotLabel03 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER BY C.StorerKey DESC), ''),  -- SOS308961
           @cLotLabel04 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER BY C.StorerKey DESC), ''),  -- SOS308961
           @cLotLabel05 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable05Label AND C.ListName = 'LOTTABLE05' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER BY C.StorerKey DESC), ''),  -- SOS308961
           @cLottable05_Code = IsNULL( S.Lottable05Label, ''),
               @cPackkey    = S.Packkey,
           @cLottable01_Code = IsNULL( S.Lottable01Label, ''), -- SOS#81879
           @cLottable02_Code = IsNULL( S.Lottable02Label, ''), -- SOS#81879
           @cLottable03_Code = IsNULL( S.Lottable03Label, ''), -- SOS#81879
           @cLottable04_Code = IsNULL( S.Lottable04Label, '')  -- SOS#81879
        FROM dbo.SKU S WITH (NOLOCK)
        WHERE StorerKey = @cStorer
           AND SKU = @cSku_scan

		  -- (james17)
        SET @cRDTDefaultUOM = ''
        SELECT @cRDTDefaultUOM = Data FROM dbo.SKUConfig WITH (NOLOCK)
        WHERE ConfigType = 'RDTDefaultUOM'
        AND SKU = @cSku_scan
        AND Storerkey = @cStorer

        IF ISNULL(@cRDTDefaultUOM,'') <> ''
           SET @cUOM = @cRDTDefaultUOM
        ELSE
           -- Get from user login prefer uom
           SELECT @cUOM =
           CASE @cPrefUOM
           WHEN '2' THEN PACK.PackUOM1 -- Case
           WHEN '3' THEN PACK.PackUOM2 -- Inner pack
           WHEN '6' THEN PACK.PackUOM3 -- Master unit
           WHEN '1' THEN PACK.PackUOM4 -- Pallet
           WHEN '4' THEN PACK.PackUOM8 -- Other unit 1
           WHEN '5' THEN PACK.PackUOM9 -- Other unit 2
           END
           FROM dbo.SKU SKU WITH (NOLOCK)
           JOIN dbo.PACK PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey
           WHERE SKU.SKU = @cSku_scan
           AND   SKU.Storerkey = @cStorer

        -- Re-initiase lottables value
        SET @cLottable01 = ''
        SET @cLottable02 = ''
        SET @cLottable03 = ''
        SET @cLottable04 = ''
        SET @cLottable05 = ''

        -- Turn on lottable flag (use later)
        SET @cHasLottable = '0'
        IF (@cLotLabel01 <> '' AND @cLotLabel01 IS NOT NULL) OR
           (@cLotLabel02 <> '' AND @cLotLabel02 IS NOT NULL) OR
           (@cLotLabel03 <> '' AND @cLotLabel03 IS NOT NULL) OR
           (@cLotLabel04 <> '' AND @cLotLabel04 IS NOT NULL) OR
           (@cLotLabel05 <> '' AND @cLotLabel05 IS NOT NULL)
           SET @cHasLottable = '1'

            -- (Vicky02) - Start
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
            -- (Vicky02) - End

			  --SOS315152 Start
           --SELECT @cUOM = CASE @cPrefUOM
           --               WHEN '2' THEN PACK.PackUOM1 -- Case
           --               WHEN '3' THEN PACK.PackUOM2 -- Inner pack
           --               WHEN '6' THEN PACK.PackUOM3 -- Master unit
           --               WHEN '1' THEN PACK.PackUOM4 -- Pallet
           --               WHEN '4' THEN PACK.PackUOM8 -- Other unit 1
           --               WHEN '5' THEN PACK.PackUOM9 -- Other unit 2
           --               END
           --FROM dbo.PACK PACK WITH (NOLOCK)
           --WHERE PACK.Packkey = @cPackkey
           --SOS315152 End

--         IF @cAllowOverRcpt <> '1'
--             BEGIN
--              SELECT @cExternPOKey = MAX(RD.ExternPOKey),
--                 @cExternLineno = MAX(RD.ExternLineNo),
--                 @cExternReceiptKey = R.ExternReceiptKey,
--                 @cReceiptLineNo = MAX(RD.ReceiptLineNumber)
--               FROM dbo.Receipt R (NOLOCK)
--               INNER JOIN dbo.ReceiptDetail RD (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
--    WHERE RD.ReceiptKey = @cReceiptKey
--            AND RD.StorerKey = @cStorer
--               GROUP BY R.ExternReceiptKey
--
--              SET @cReceiptLineNo = RIGHT(REPLICATE('0',5) + ISNULL(RTRIM(CAST((CAST(@cReceiptLineNo AS INT) + 1) as NVARCHAR(5))), ''), 5)
--
--
--              SET  @cNewSKUFlag = 'N'
--              -- Insert Dummy Receiptdetail line with New SKU
--          INSERT INTO dbo.ReceiptDetail
--            (ReceiptKey, ReceiptLineNumber, StorerKey, SKU, QTYExpected, BeforeReceivedQTY,
--             ToID, ToLOC, Status, UOM, Packkey, DateReceived, ConditionCode, EffectiveDate, FinalizeFlag, SplitPalletFlag,
--             ExternReceiptKey)
--          SELECT
--             @cReceiptKey, @cReceiptLineNo, @cStorer, @cSKU, 0, 0,
--             @cID, @cLOC, '0', IsNULL(@cUOM, ''), @cPackkey, GETDATE(), 'OK', GETDATE(), 'N', 'N',
--             ISNULL(@cExternReceiptKey,'')
--
--             SET @cNewSKUFlag = 'Y'
--            END

        -- Init next screen var
        SET @cOutField01 = @cSKU
        SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
        SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
        SET @cOutField04 = SUBSTRING( @cIVAS, 1, 20)     -- IVAS
        SET @cOutField05 = @cUOM -- UOM
        SET @cOutField06 = '' -- QTY
        SET @cOutField07 = '' -- Reason
        SET @cOutField08 = ''         -- (james17)
        SET @cOutField09 = ''         -- (james17)

        EXEC rdt.rdtSetFocusField @nMobile, 6  -- (james12)

        -- Go to next screen
        SET @nScn  = @nScn - 3
        SET @nStep = @nStep - 3

        GOTO Quit
      END


      IF @cOption = '2' -- DEL
      BEGIN
         SET @cOutField01 = '' -- SKU
         SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
         SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
         SET @cOutField04 = @cID    -- (james09)

         -- (Vicky02) - Start
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
         -- (Vicky02) - End

         -- Go back to SKU screen
         SET @nScn = @nScn - 4
         SET @nStep = @nStep - 4

         GOTO Quit
      END
   END -- Inputkey = 1


   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOption = ''
      SET @cInField01 = ''

      SET @cOutField01 = '' -- SKU
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField04 = @cID    -- (james09)

      -- (Vicky02) - Start
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
      -- (Vicky02) - End

    SET @nScn = @nScn - 4
    SET @nStep = @nStep - 4
    GOTO Quit
 END

   Step_8_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOption = ''
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit



/********************************************************************************
 -- SOS131462
Step 9. Scn = 962. Option
   NEXT TASK?
   1 = Print Label/Next PLT ID
   2 = Next LOC
   3 = Exit ALL Task
   OPTION: (field01, input)
********************************************************************************/
Step_9:
BEGIN
   -- Screen mapping
   SET @cScnOption = ''
   SET @cScnOption = @cInField01

   IF @nInputKey = 1 OR @nInputKey = 0 -- ENTER/ESC
   BEGIN
      IF @cScnOption = ''
      BEGIN
         SET @nErrNo = 60450
         SET @cErrMsg = rdt.rdtgetmessage( 60450, @cLangCode, 'DSP') --'Option required'
         GOTO Step_9_Fail
      END

      IF @cScnOption <> '1' AND @cScnOption <> '2' AND @cScnOption <> '3' AND @cScnOption <> ''
      BEGIN
         SET @nErrNo = 60451
         SET @cErrMsg = rdt.rdtgetmessage( 60451, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_9_Fail
      END

      IF @cPrintNoOfCopy = '0'
         SET @cNoOfCopy = '1'
      ELSE
         SET @cNoOfCopy = @cPrintNoOfCopy

      IF @cScnOption = '1' -- Print Label/Next PLT ID
      BEGIN
         SET @cReportType = 'PALLETLBL'

         IF @cPrintMultiLabel = '1'
         BEGIN
            IF EXISTS (SELECT 1 FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                        WHERE RD.ReceiptKey = @cReceiptKey
                        AND RD.POKey = CASE WHEN @cPOKey = 'NOPO' THEN RD.POKey ELSE @cPOKey END
                        AND RD.StorerKey = @cStorer
                        AND RD.ToID = RTRIM(@cID)
                        HAVING COUNT(RD.ReceiptLineNumber) > 1)
               SELECT @cReportType = 'ASSTPLTLBL'
         END

         -- Validate printer setup
         IF ISNULL(@cPrinter, '') = ''
         BEGIN
            SET @nErrNo = 60452
            SET @cErrMsg = rdt.rdtgetmessage( 60452, @cLangCode, 'DSP') --NoLoginPrinter
            GOTO Step_9_Fail
         END

         SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                  @cTargetDB = ISNULL(RTRIM(TargetDB), '')
         FROM RDT.RDTReport WITH (NOLOCK)
         WHERE StorerKey = @cStorer
            AND ReportType = CASE WHEN @cPrintMultiLabel = '1' THEN RTRIM(@cReportType)
                                  ELSE 'PALLETLBL' END
            AND 1 = CASE WHEN Function_ID = @nFunc OR Function_ID = 0 THEN 1  --IN00488160
                         ELSE 0 END                                           --IN00488160

         IF ISNULL(@cDataWindow, '') = ''
         BEGIN
            SET @nErrNo = 60453
            SET @cErrMsg = rdt.rdtgetmessage( 60453, @cLangCode, 'DSP') --DWNOTSetup
            GOTO Step_9_Fail
         END

         IF ISNULL(@cTargetDB, '') = ''
         BEGIN
            SET @nErrNo = 60454
            SET @cErrMsg = rdt.rdtgetmessage( 60454, @cLangCode, 'DSP') --TgetDB Not Set
            GOTO Step_9_Fail
         END

         -- Insert print job  (james15)
         EXEC RDT.rdt_BuiltPrintJob
            @nMobile,
            @cStorer,
            @cReportType,      -- ReportType
            'PRINT_PALLETLBL', -- PrintJobName
            @cDataWindow,
            @cPrinter,
            @cTargetDB,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT,
            @cReceiptKey,
            @cID,
            --@cNoOfCopy = @cPrintNoOfCopy   --IN00488160
            @cNoOfCopy                       --IN00488160
         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 60455
            SET @cErrMsg = rdt.rdtgetmessage( 60455, @cLangCode, 'DSP') --'InsertPRTFail'
            GOTO Step_9_Fail
         END

         SET @cAutoGenID = ''
         SET @cAutoGenID = rdt.RDTGetConfig( @nFunc, 'AutoGenID', @cStorer) -- (james03)
         IF @cAutoGenID = '1'
         BEGIN
            EXECUTE dbo.nspg_GetKey
               'ID',
               10 ,
               @cID               OUTPUT,
               @b_success         OUTPUT,
               @n_err             OUTPUT,
               @c_errmsg          OUTPUT
            IF @b_success <> 1
            BEGIN
               SET @nErrNo = 60456
               SET @cErrMsg = rdt.rdtgetmessage( 60456, @cLangCode, 'DSP') -- 'GetIDKey Fail'
               GOTO Step_9_Fail
            END
         END

         -- Prepare next screen
         -- When autogenid turned off then clear the ID to display   (james15)
         SET @cOutField01 = CASE WHEN ISNULL( @cAutoGenID, '') = 1 THEN @cID  ELSE '' END
         SET @cOutField02 = @cLOC

         SET @cPrevOp = '1'

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

         -- Go back to PLT ID screen
         SET @nScn = @nScn - 9
         SET @nStep = @nStep - 6

         GOTO Quit
      END

      IF @cScnOption = '2' -- Next LOC
      BEGIN
          -- Prepare next screen
        SET @cOutField01 = ''

          SET @cPrevOp = '2'

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

          -- Go back to ToLOC screen
          SET @nScn = @nScn - 10
          SET @nStep = @nStep - 7

          GOTO Quit
      END

      IF @cScnOption = '3' -- Print last Label/Exit ALL Task
      BEGIN
           IF @cReceivingPrintLabel = '1'
           BEGIN
              SELECT @cReportType = 'PALLETLBL'

              IF @cPrintMultiLabel = '1'
              BEGIN
                 IF EXISTS (SELECT 1 FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                            WHERE RD.ReceiptKey = @cReceiptKey
                            AND RD.POKey = CASE WHEN @cPOKey = 'NOPO' THEN RD.POKey ELSE @cPOKey END
                            AND RD.StorerKey = @cStorer
                            AND RD.ToID = RTRIM(@cID)
                            HAVING COUNT(RD.ReceiptLineNumber) > 1)
                    SELECT @cReportType = 'ASSTPLTLBL'
              END

             -- Validate printer setup
            IF ISNULL(@cPrinter, '') = ''
            BEGIN
               SET @nErrNo = 60457
               SET @cErrMsg = rdt.rdtgetmessage( 60457, @cLangCode, 'DSP') --NoLoginPrinter
               GOTO Step_9_Fail
            END

            SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                     @cTargetDB = ISNULL(RTRIM(TargetDB), '')
            FROM RDT.RDTReport WITH (NOLOCK)
            WHERE StorerKey = @cStorer
                 AND ReportType = CASE WHEN @cPrintMultiLabel = '1' THEN RTRIM(@cReportType)
                     ELSE 'PALLETLBL' END
                 AND 1 = CASE WHEN Function_ID = @nFunc OR Function_ID = 0 THEN 1   --IN00488160
                              ELSE 0 END                                            --IN00488160

              IF ISNULL(@cDataWindow, '') = ''
              BEGIN
                 SET @nErrNo = 60458
                 SET @cErrMsg = rdt.rdtgetmessage( 60458, @cLangCode, 'DSP') --DWNOTSetup
                 GOTO Step_9_Fail
              END

              IF ISNULL(@cTargetDB, '') = ''
              BEGIN
                 SET @nErrNo = 60459
                 SET @cErrMsg = rdt.rdtgetmessage( 60459, @cLangCode, 'DSP') --TgetDB Not Set
                 GOTO Step_9_Fail
              END

             -- Insert print job  (james15)
             EXEC RDT.rdt_BuiltPrintJob
                @nMobile,
                @cStorer,
                @cReportType,      -- ReportType
                'PRINT_PALLETLBL', -- PrintJobName
                @cDataWindow,
                @cPrinter,
                @cTargetDB,
                @cLangCode,
                @nErrNo  OUTPUT,
                @cErrMsg OUTPUT,
                @cReceiptKey,
                @cID,
                --@cNoOfCopy = @cPrintNoOfCopy  --IN00488160
                @cNoOfCopy                      --IN00488160
             IF @nErrNo <> 0
             BEGIN
                 SET @nErrNo = 60460
                 SET @cErrMsg = rdt.rdtgetmessage( 60460, @cLangCode, 'DSP') --'InsertPRTFail'
                 GOTO Step_9_Fail
             END

              -- Call printing spooler
              -- INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Printer, NoOfCopy, Mobile, TargetDB)
              -- VALUES('PRINT_PLTLABEL', CASE WHEN @cPrintMultiLabel = '1' THEN RTRIM(@cReportType) ELSE 'PALLETLBL' END, '0', @cDataWindow, 2, @cReceiptKey, RTRIM(@cID), @cPrinter, RTRIM(@cPrintNoOfCopy), @nMobile, @cTargetDB)
          END

          -- Prepare next screen
        SET @cOutField01 = ''
        SET @cOutField02 = ''


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

          EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN#

          -- Go back to ASN screen
          SET @nScn = @nScn - 11
          SET @nStep = @nStep - 8

          GOTO Quit
      END
   END -- Inputkey = 1

   Step_9_Fail:
   BEGIN
       -- Reset this screen var
       SET @cScnOption = ''
       SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Step 10. scn = 963. Message screen
   Msg
********************************************************************************/
Step_10:
BEGIN
   IF @nInputKey = 0 OR @nInputKey = 1 -- Esc or No / Yes or Send
   BEGIN
      SET @cOutField01 = ''

      -- (james10)
      SET @cAutoGenID = ''
      SET @cAutoGenID = rdt.RDTGetConfig( @nFunc, 'AutoGenID', @cStorer)
      IF @cAutoGenID = '1'
      BEGIN
          EXECUTE dbo.nspg_GetKey
                  'ID',
                  10 ,
                  @cID               OUTPUT,
                  @b_success         OUTPUT,
                  @n_err             OUTPUT,
                  @c_errmsg          OUTPUT
         IF @b_success <> 1
         BEGIN
            SET @nErrNo = 67386
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'GetIDKey Fail'
            GOTO Quit
         END
         ELSE
         BEGIN
             -- Init next screen var
            SET @cOutField01 = @cID
         END
      END

      -- Go back to PLT ID screen
      SET @nScn  = 953
      SET @nStep = 3

      -- Init next screen var
      SET @cOutField02 = @cLOC      -- (james09)
      SET @cOutField03 = ''

      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @dLottable04 = 0
      SET @dLottable05 = 0
      SET @cLottable04 = ''

      -- (Vicky02) - Start
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
      -- (Vicky02) - End
   END
END
GOTO Quit


/********************************************************************************
SOS#142253
Step 11. Scn = 964. Verify Packkey screen
   SKU       (field01, display)
   SKU desc  (field02, field03, display)
   IVAS      (field04, display)
   PackUOM   (field05, display)
   UOM   (field06, display)
   PackQTY   (field07)
********************************************************************************/
Step_11:
 BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cPackQTY = @cInField07

      Validate_PackQty:
 -- Validate PackQTY field
   IF @cPackQTY = '' OR @cPackQTY IS NULL
   BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 67376, @cLangCode, 'DSP') --'PK QTY needed'
         SET @cPackQTY = ''
         EXEC rdt.rdtSetFocusField @nMobile, 7
         GOTO Step_11_Fail
      END

      -- Validate PackQTY is numeric
      IF IsNumeric(@cPackQTY) = 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 67377, @cLangCode, 'DSP') --'Invalid PK QTY'
         SET @cPackQTY = ''
         EXEC rdt.rdtSetFocusField @nMobile, 7
         GOTO Step_11_Fail
      END

      -- Validate PackQTY is integer0
      SET @i = 1
      WHILE @i <= LEN( RTRIM( @cPackQTY))
      BEGIN
         IF NOT (SUBSTRING( @cPackQTY, @i, 1) >= '0' AND SUBSTRING( @cPackQTY, @i, 1) <= '9')
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 67377, @cLangCode, 'DSP') --'Invalid PK QTY'
            SET @cPackQTY = ''
            EXEC rdt.rdtSetFocusField @nMobile, 7
            GOTO Step_11_Fail
            BREAK
         END
         SET @i = @i + 1
      END

      -- Validate PackQTY > 0
      IF @cPackQTY < 1
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 67378, @cLangCode, 'DSP') --'PK QTY must > 0'
         SET @cPackQTY = ''
         EXEC rdt.rdtSetFocusField @nMobile, 7
         GOTO Step_11_Fail
      END


     SELECT @nPKQTY = CASE @cPrefUOM
           WHEN '2' THEN PACK.CASECNT -- Case
           WHEN '3' THEN PACK.INNERPACK -- Inner pack
           WHEN '6' THEN PACK.QTY -- Master unit
           WHEN '1' THEN PACK.PALLET -- Pallet
           WHEN '4' THEN PACK.OtherUnit1 -- Other unit 1
           WHEN '5' THEN PACK.OtherUnit2 -- Other unit 2
           END
      FROM dbo.PACK PACK
      WHERE PACK.Packkey = @cPackkey

      IF @nPKQTY <> Cast( @cPackQTY As INT)
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 67379, @cLangCode, 'DSP') --'PK QTY not match'
         SET @cPackQTY = ''
         EXEC rdt.rdtSetFocusField @nMobile, 7
         GOTO Step_11_Fail
      END

      SET @cOutField06 = ''
      SET @cOutField07 = ''

      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField04 = SUBSTRING( @cIVAS, 1, 20)     -- IVAS
      SET @cOutField05 = @cUOM -- UOM
      SET @cOutField06 = '' -- QTY
      SET @cOutField07 = '' -- Reason

      EXEC rdt.rdtSetFocusField @nMobile, 6  -- (james12)

      SET @nScn  = @nScn - 9
      SET @nStep = @nStep - 6
  END

   IF @nInputKey = 0
   BEGIN
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField04 = @cID    -- (james09)

      SET @cLottable01_Code = ''
      SET @cLottable02_Code = ''
      SET @cLottable03_Code = ''
      SET @cLottable04_Code = ''

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

   -- Go to previous screen
   SET @nScn  = 954
   SET @nStep = 4
   END

   GOTO Quit

   Step_11_Fail:
   BEGIN
      -- Retain the key-in value
      SET @cOutField07 = @cInField07
   END
END
GOTO Quit


/********************************************************************************
Step 12. Scn = 966. SKU, QTY screen
   SKU       (field01, display)
   SKU desc  (field02, field03, display)
   IVAS      (field04, display)
   UOM       (Field10, 05, 06)
   QTY       (Field07, 08)
   Reason    (field09)
********************************************************************************/
Step_12:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
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

      -- Screen mapping
      SET @cPUOM_Desc = @cOutField05
      SET @cMUOM_Desc = @cOutField06
      SET @cReasonCode = @cInField09

      IF ISNULL(@cPUOM_Desc, '') <> ''
      BEGIN
         SET @cPQTY = IsNULL( @cInField07, '')
      END

      SET @cMQTY = IsNULL( @cInField08, '')

      IF ISNULL(@cPQTY, '') = '' SET @cPQTY = '0' -- Blank taken as zero
      IF ISNULL(@cMQTY, '') = '' SET @cMQTY = '0' -- Blank taken as zero

      -- Validate PQTY
      IF RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 67383, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 07 -- PQTY
         GOTO Step_12_Fail
      END

      -- Validate MQTY
      IF RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 67384, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 08 -- MQTY
         GOTO Step_12_Fail
      END

      -- Calc total QTY in master UOM
      SET @nPQTY = CAST( @cPQTY AS INT)
      SET @nMQTY = CAST( @cMQTY AS INT)
      SET @nActQTY = 0

      SET @nQTY = ISNULL(rdt.rdtConvUOMQTY( @cStorer, @cSKU, @nPQTY, @cPrefUOM, 6), 0) -- Convert to QTY in master UOM
      SET @nQTY = @nQTY + @nMQTY
      SET @cQTY = @nQTY
      SET @cUOM = @cMUOM_Desc

      -- Validate reason code exists
      IF @cReasonCode <> '' AND @cReasonCode IS NOT NULL
      BEGIN
         IF NOT EXISTS( SELECT Code
            FROM dbo.CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'ASNREASON'
               AND Code = @cReasonCode)
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 67385, @cLangCode, 'DSP') --'Invalid ReasonCode'
            SET @cReasonCode = ''
            EXEC rdt.rdtSetFocusField @nMobile, 09
            GOTO Step_12_Fail
         END
      END

/* (james08)
      SELECT TOP 1
         @nDummy = CASE WHEN @cID = [ToID] THEN 0 ELSE 1 END, -- Try to match PO + ID. If not found, follow line# sequence
         @cUOM = UOM,
         @cLottable01 = Lottable01,
         @cLottable02 = Lottable02,
         @cLottable03 = Lottable03,
         @cLottable04 = rdt.rdtFormatDate( Lottable04),
         @cLottable05 = rdt.rdtFormatDate( Lottable05)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END
         AND SKU = @cSKU
      ORDER BY 1, ReceiptLineNumber
*/
      /********************************************************************************************************************/
      /* SOS#81879 - Start                                                                                                */
      /* Generic Lottables Computation (PRE): To compute Lottables before going to Lottable Screen                        */
      /* Setup spname in CODELKUP.Long where ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05'  */
      /* 1. Setup RDT.Storerconfigkey = <Lottable01/02/03/04/05> , sValue = <Lottable01/02/03/04/05Label>                 */
      /* 2. Setup Codelkup.Listname = ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05' and     */
      /*    Codelkup.Short = 'PRE' and Codelkup.Long = <SP Name>                                */
      /********************************************************************************************************************/

      IF (IsNULL(@cLottable01_Code, '') <> '') OR (IsNULL(@cLottable02_Code, '') <> '') OR (IsNULL(@cLottable03_Code, '') <> '') OR
         (IsNULL(@cLottable04_Code, '') <> '') OR (IsNULL(@cLottable05_Code, '') <> '')
      BEGIN
          --(james08)
--          SET @cLottable01 = ''
--          SET @cLottable02 = ''
--          SET @cLottable03 = ''
--          SET @dLottable04 = 0
--          SET @dLottable05 = 0

         --initiate @nCounter = 1
         SET @nCountLot = 1

         --retrieve value for pre lottable01 - 05
         WHILE @nCountLot <=5 --break the loop when @nCount >5
         BEGIN
             IF @nCountLot = 1
             BEGIN
                SET @cListName = 'Lottable01'
                SET @cLottableLabel = @cLottable01_Code
             END
             ELSE
             IF @nCountLot = 2
             BEGIN
                SET @cListName = 'Lottable02'
                SET @cLottableLabel = @cLottable02_Code
             END
             ELSE
             IF @nCountLot = 3
             BEGIN
                SET @cListName = 'Lottable03'
                SET @cLottableLabel = @cLottable03_Code
             END
             ELSE
             IF @nCountLot = 4
             BEGIN
                SET @cListName = 'Lottable04'
                  SET @cLottableLabel = @cLottable04_Code
             END
             ELSE
             IF @nCountLot = 5
             BEGIN
                SET @cListName = 'Lottable05'
                SET @cLottableLabel = @cLottable05_Code
             END

             /*   comment (james12)
             --get short, store procedure and lottablelable value for each lottable
             SET @cShort = ''
             SET @cStoredProd = ''
             SELECT TOP 1 @cShort = ISNULL(RTRIM(C.Short),''),
                    @cStoredProd = IsNULL(RTRIM(C.Long), '')
             FROM dbo.CodeLkUp C WITH (NOLOCK)
             JOIN RDT.StorerConfig S WITH (NOLOCK) ON (C.ListName = S.ConfigKey AND C.Code = S.SValue)
             WHERE C.ListName = @cListName
             AND   C.Code = @cLottableLabel
             ORDER BY
             CASE WHEN C.StorerKey = @cStorer THEN 1 ELSE 2 END -- (ChewKP08)
             */

            SELECT TOP 1 @cShort = C.Short,
                   @cStoredProd = IsNULL( C.Long, '')
            FROM dbo.CodeLkUp C WITH (NOLOCK)
            WHERE C.Listname = @cListName
            AND   C.Code = @cLottableLabel
            AND  (C.StorerKey = @cStorer OR C.Storerkey = '') --SOS308961
            ORDER By C.StorerKey DESC

             IF @cShort = 'PRE' AND @cStoredProd <> ''
             BEGIN

               -- (james01) start
               IF @cListName = 'Lottable01'
                  SET @cLottable01 = ''
               ELSE IF @cListName = 'Lottable02'
                  SET @cLottable02 = ''
               ELSE IF @cListName = 'Lottable03'
                  SET @cLottable03 = ''
               ELSE IF @cListName = 'Lottable04'
                  SET @dLottable04 = ''
               ELSE IF @cListName = 'Lottable05'
                  SET @dLottable05 = ''
               -- (james01) end

               --SOS133226 (james02)
               SELECT TOP 1 @cReceiptLineNo = ReceiptLinenumber FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorer
                  AND ReceiptKey = @cReceiptKey
                  AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END
                  AND SKU = @cSKU
                  AND FinalizeFlag = 'N'
               ORDER BY ReceiptLinenumber

               SET @cSourcekey = ISNULL(RTRIM(@cReceiptKey), '') + ISNULL(RTRIM(@cReceiptLineNo), '')

               EXEC dbo.ispLottableRule_Wrapper
                  @c_SPName            = @cStoredProd,
                  @c_ListName          = @cListName,
                  @c_Storerkey         = @cStorer,
                  @c_Sku               = @cSKU,
                  @c_LottableLabel     = @cLottableLabel,
                  @c_Lottable01Value   = '',
                  @c_Lottable02Value   = '',
                  @c_Lottable03Value   = '',
                  @dt_Lottable04Value  = '',
                  @dt_Lottable05Value  = '',
                  @c_Lottable01        = @cLottable01 OUTPUT,
                  @c_Lottable02        = @cLottable02 OUTPUT,
                  @c_Lottable03 = @cLottable03 OUTPUT,
                  @dt_Lottable04       = @dLottable04 OUTPUT,
                  @dt_Lottable05       = @dLottable05 OUTPUT,
                  @b_Success           = @b_Success   OUTPUT,
                  @n_Err               = @nErrNo      OUTPUT,
                  @c_Errmsg            = @cErrMsg     OUTPUT,
                  @c_Sourcekey         = @cSourcekey,
                  @c_Sourcetype        = 'RDTRECEIPT'

                IF ISNULL(@cErrMsg, '') <> ''
                BEGIN
                   SET @cErrMsg = @cErrMsg
                   GOTO Step_12_Fail
                   BREAK
                END

                SET @cLottable01 = IsNULL( @cLottable01, '')
                SET @cLottable02 = IsNULL( @cLottable02, '')
                SET @cLottable03 = IsNULL( @cLottable03, '')
                SET @dLottable04 = IsNULL( @dLottable04, 0)
                SET @dLottable05 = IsNULL( @dLottable05, 0)

                IF @dLottable04 > 0
                BEGIN
                   SET @cLottable04 = RDT.RDTFormatDate(@dLottable04)
                END

                IF @dLottable05 > 0
                BEGIN
                   SET @cLottable05 = RDT.RDTFormatDate(@dLottable05)
                END
            END

            -- increase counter by 1
            SET @nCountLot = @nCountLot + 1
       END -- nCount
    END -- Lottable <> ''
   /********************************************************************************************************************/
   /* SOS#81879 - End                                                                                                  */
   /* Generic Lottables Computation (PRE): To compute Lottables before going to Lottable Screen                        */
   /********************************************************************************************************************/


   IF @cHasLottable = '1'
   BEGIN
      -- Init lot label
      SELECT
         @cOutField01 = 'Lottable01:',
         @cOutField03 = 'Lottable02:',
         @cOutField05 = 'Lottable03:',
         @cOutField07 = 'Lottable04:',
         @cOutField09 = 'Lottable05:'

      -- Disable lot label and lottable field
      IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
      BEGIN
         SET @cFieldAttr02 = 'O' -- (Vicky02)
         SET @cOutField02 = ''
      END
      ELSE
      BEGIN
         -- Populate lot label and lottable
         SELECT
            @cOutField01 = @cLotLabel01,
            @cOutField02 = ISNULL(@cLottable01, '') -- SOS#81879
      END

      IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
      BEGIN
         SET @cFieldAttr04 = 'O' -- (Vicky02)
         SET @cOutField04 = ''
      END
      ELSE
      BEGIN
         SELECT
            @cOutField03 = @cLotLabel02,
            @cOutField04 = ISNULL(@cLottable02, '')  -- SOS#81879
      END

      IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
      BEGIN
         SET @cFieldAttr06 = 'O' -- (Vicky02)
         SET @cOutField06 = ''
      END
      ELSE
      BEGIN
         SELECT
               @cOutField05 = @cLotLabel03,
               @cOutField06 = ISNULL(@cLottable03, '')  -- SOS#81879
      END

      IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
      BEGIN
         SET @cFieldAttr08 = 'O' -- (Vicky02)
         SET @cOutField08 = ''
         --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
      END
      ELSE
      BEGIN
         SELECT
            @cOutField07 = @cLotLabel04,
            @cOutField08 = @cLottable04 -- SOS#81879

         -- Check if lottable04 is blank/is 01/01/1900 then no need to default anything and let user to scan (james07)
         IF ISNULL(@cLottable04, '') = '' OR rdt.rdtConvertToDate( @cLottable04) IS NULL
            SET @cOutField08 = ''
      END

      IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL
      BEGIN
         SET @cFieldAttr10 = 'O' -- (Vicky02)
         SET @cOutField10 = ''
         --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')
      END
      ELSE
      BEGIN
         -- Lottable05 is usually RCP_DATE
--            IF @cLottable05_Code = 'RCP_DATE' AND (@cLottable05 = '' OR RDT.RDTFormatDate(@cLottable05) = '01/01/1900') -- Edit by james on 20/03/2009
--            IF @cLottable05_Code = 'RCP_DATE' AND (ISNULL(@cLottable05, '') = '' OR RDT.RDTFormatDate(@cLottable05) = '01/01/1900')
--            BEGIN
--               SET @cLottable05 = RDT.RDTFormatDate( GETDATE())
--            END

            SELECT @cOutField09 = @cLotLabel05,
                   @cOutField10 = @cLottable05

         -- Check if lottable05 is blank/is 01/01/1900 then default system date. User no need to scan (james07)
         IF @cLottable05_Code = 'RCP_DATE' OR rdt.rdtConvertToDate( @cLottable05) IS NULL
            SET @cOutField10 = RDT.RDTFormatDate( GETDATE())
         END
   END

   -- Go to next screen
   IF @cHasLottable = '0'
      GOTO Receiving
   ELSE
   BEGIN
      SET @nScn = 956
      SET @nStep = 6

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Lottable01
   END
   END -- Input = 1

   IF @nInputKey = 0 -- Esc or No
   BEGIN

      -- Prepare prev screen var
      SET @cOutField01 = CASE WHEN (@cPrePackByBOM = '1' AND @cUPCSKU <> @cSKU) THEN @cUPCSKU
                              ELSE @cSKU END
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField04 = @cID    -- (james09)

      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @dLottable04 = 0
      SET @dLottable05 = 0
      SET @cLottable04 = ''

      -- (Vicky02) - Start
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
      -- (Vicky02) - End

      SET @nScn = 954      -- hardcoded bcoz the screen no is not in seq
      SET @nStep = 4

   END
   GOTO Quit

   Step_12_Fail:
   BEGIN
      SET @cOutField05 = @cPUOM_Desc
      SET @cOutField06 = @cMUOM_Desc   -- @cMUOM_Desc
      SET @cOutField07 = ''            -- @nPQTY
      SET @cOutField08 = ''            -- @nMQTY
      SET @cOutField09 = ''            -- Reason

      EXEC rdt.rdtSetFocusField @nMobile, 07
   END

END
GOTO Quit


/********************************************************************************
Step 13. Screen = 967. Verify SKU
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
Step_13:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cWeight        = @cInField04
      SET @cCube          = @cInField05
      SET @cLength        = @cInField06
      SET @cWidth         = @cInField07
      SET @cHeight        = @cInField08
      SET @cInnerPack     = @cInField09
      SET @cCaseCount     = @cInField10
      SET @cPalletCount   = @cInField11
      SET @cVerifySKUInfo = @cInField12

      -- Retain key-in value
      SET @cOutField04 = @cInField04
      SET @cOutField05 = @cInField05
      SET @cOutField06 = @cInField06
      SET @cOutField07 = @cInField07
      SET @cOutField08 = @cInField08
      SET @cOutField09 = @cInField09
      SET @cOutField10 = @cInField10
      SET @cOutField11 = @cInField11
      SET @cOutField12 = @cInField12

      -- Update SKU setting
      EXEC rdt.rdt_VerifySKU @nMobile, @nFunc, @cLangCode, @cStorer, @cSKU,
         'UPDATE',
         @cWeight        OUTPUT,
         @cCube          OUTPUT,
         @cLength        OUTPUT,
         @cWidth         OUTPUT,
         @cHeight        OUTPUT,
         @cInnerPack     OUTPUT,
         @cCaseCount     OUTPUT,
         @cPalletCount   OUTPUT,
         @nErrNo         OUTPUT,
         @cErrMsg        OUTPUT,
         @cVerifySKUInfo OUTPUT

      IF @nErrNo <> 0
         GOTO Quit

      -- Go to UOM QTY screen
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField04 = SUBSTRING( @cIVAS, 1, 20)     -- IVAS
      IF @nFunc = 550
      BEGIN
         SET @cOutField05 = @cUOM
         SET @cOutField06 = @cQTY
         SET @cOutField07 = @cReasonCode
         SET @cOutField08 = ''-- SOS# 339480
         SET @cOutField09 = ''-- SOS# 339480

         EXEC rdt.rdtSetFocusField @nMobile, 6  -- (james12)

         -- Go back to prev screen
         SET @nScn = 955
         SET @nStep = @nStep - 8
      END
      ELSE
      BEGIN
         -- Get Pack info
         SELECT
            @cMUOM_Desc = Pack.PackUOM3,
            @cPUOM_Desc =
               CASE @cPrefUOM
                  WHEN '2' THEN Pack.PackUOM1 -- Case
                  WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                  WHEN '6' THEN Pack.PackUOM3 -- Master unit
                  WHEN '1' THEN Pack.PackUOM4 -- Pallet
                  WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                  WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
               END,
               @nPUOM_Div = CAST( IsNULL(
               CASE @cPrefUOM
                  WHEN '2' THEN Pack.CaseCNT
                  WHEN '3' THEN Pack.InnerPack
                  WHEN '6' THEN Pack.QTY
                  WHEN '1' THEN Pack.Pallet
                  WHEN '4' THEN Pack.OtherUnit1
                  WHEN '5' THEN Pack.OtherUnit2
               END, 1) AS INT)
         FROM dbo.SKU SKU WITH (NOLOCK)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE SKU.StorerKey = @cStorer
            AND SKU.SKU = @cSKU

         -- Convert to prefer UOM QTY
         IF @cPrefUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
         END

         IF @cPUOM_Desc = ''
         BEGIN
            SET @cOutField05 = ''      -- @cPUOM_Desc
            SET @cOutField07 = ''      -- @nPQTY
            SET @cOutField10 = '1:1'   -- @nPUOM_Div
            SET @cFieldAttr07 = 'O'
         END
         ELSE
         BEGIN
            SET @cOutField05 = @cPUOM_Desc
            SET @cOutField07 = ''
            SET @cOutField10 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
         END
         SET @cOutField06 = @cMUOM_Desc   -- @cMUOM_Desc
         SET @cOutField08 = ''            -- @nPQTY
         SET @cOutField09 = ''            -- Reason

         -- Go back to prev screen
         SET @nScn = 965
         SET @nStep = 12
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = CASE WHEN (@cPrePackByBOM = '1' AND @cUPCSKU <> @cSKU) THEN @cUPCSKU
                              ELSE @cSKU END
      SET @cOutField02 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField04 = @cID

      -- Go back to SKU screen
      SET @nScn = 954
      SET @nStep = @nStep - 9
   END

   -- Enable field
   SELECT @cFieldAttr12 = ''
   SELECT @cFieldAttr04 = ''
   SELECT @cFieldAttr05 = ''
   SELECT @cFieldAttr06 = ''
   SELECT @cFieldAttr07 = ''
   SELECT @cFieldAttr08 = ''
   SELECT @cFieldAttr09 = ''
   SELECT @cFieldAttr10 = ''
   SELECT @cFieldAttr11 = ''
END
GOTO Quit


/********************************************************************************
Receiving process
********************************************************************************/
Receiving:
BEGIN
   IF @nInputKey = 1 OR @nInputKey = 0 -- Yes or Send / Esc or No
   BEGIN
      -- Receiving
      DECLARE @c_outstring    NVARCHAR( 255)
      DECLARE @c_POKey        NVARCHAR( 10)

      -- (Vicky02) - Start
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
      -- (Vicky02) - End

   -- Support 'NOPO'

      -- (ChewKP01)
      -- check POKey Count
      IF @nPOCount > 1
      BEGIN
         SET @cPOKey = ''
      END
      ELSE
      BEGIN
         IF @cPOKey = '' OR @cPOKey IS NULL
         BEGIN
            SET @c_POKey = 'NOPO'
         END
         ELSE
         BEGIN
            SET @c_POKey = @cPOKey
         END
      END

      IF @cPrePackByBOM = '1' --configkey 'PrePackByBOM' has been setup
      BEGIN
         SET @nCountSku = 0

         --get num of componentsku
         SELECT @nCountSku = COUNT(ComponentSku)
         FROM dbo.BillOfMaterial WITH (NOLOCK)
         WHERE SKU = @cSKU
            AND StorerKey = @cStorer

         --if there is none of componentSku, straight go for normal receiving
         IF @nCountSKu = 0
            GOTO Receiving_Normal

         --initiate all the variable to '' or 0
         SELECT @cPackUOM1='', @fCaseCnt=0,
            @cPackUOM2='', @fInnerPack=0,
                @cPackUOM3='', @fQtyUOM3=0,
                @cPackUOM4='', @fPallet=0,
                @cPackUOM8='', @fOtherUnit1=0,
                @nUOMQty = 0

         IF ISNULL(RTRIM(@cUPCPackKey),'') <> '' AND ISNULL(RTRIM(@cUPCUOM),'') <> ''
         BEGIN
            --get all related packuom for packkey
            SELECT @cPackUOM1 = PackUOM1, @fCaseCnt = CaseCnt,
                   @cPackUOM2 = PackUOM2, @fInnerPack = InnerPack,
                   @cPackUOM3 = PackUOM3, @fQtyUOM3 = Qty,
                   @cPackUOM4 = PACKUOM4, @fPallet = Pallet,
                   @cPackUOM8 = PackUOM8, @fOtherUnit1 = OtherUnit1
            FROM dbo.Pack WITH (NOLOCK)
            WHERE PackKey = @cUPCPackKey

            --get UOM Qty
            IF @cUPCUOM = @cPackUOM1
               SET @nUOMQty = CONVERT(INT, @fCaseCnt)
            ELSE IF @cUPCUOM = @cPackUOM2
               SET @nUOMQty = CONVERT(INT, @fInnerPack)
            ELSE IF @cUPCUOM = @cPackUOM3
               SET @nUOMQty = CONVERT(INT, @fQtyUOM3)
            ELSE IF @cUPCUOM = @cPackUOM4
               SET @nUOMQty = CONVERT(INT, @fPallet)
            ELSE IF @cUPCUOM = @cPackUOM8
               SET @nUOMQty = CONVERT(INT, @fOtherUnit1)
            ELSE
               SET @nUOMQty = 1
         END
         ELSE
         BEGIN
            SET @nUOMQty = 1
         END

         --if there is one or more componentsku, do receiving process for each componentsku
         SET @nTempCount = 1
         BEGIN TRAN
         WHILE @nTempCount <= @nCountSku
         BEGIN
            SET @cComponentSku = ''
            SET @nComponentQty = 0
            SET @nTotalQty = 0
            --retrieve one componentSku and qty at a time by sequence
            SELECT
               @cComponentSku = ComponentSku,
               @nComponentQty = Qty
            FROM dbo.BillOfMaterial WITH (NOLOCK)
            WHERE SKU = @cSKU
               AND Storerkey = @cStorer
               AND Sequence = CONVERT(NVARCHAR, @nTempCount)

            SET @nRowCount = 0
            SET ROWCOUNT 1
            SELECT @cPackKey = PackKey,
                   @cUOM     = UOM
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
               AND StorerKey = @cStorer
               AND SKU = @cComponentSku

            SET @nRowCount = @@ROWCOUNT
            IF @nRowCount = 0
            BEGIN
--                SELECT @cPackKey = PackKey
--                FROM dbo.SKU WITH (NOLOCK)
--                WHERE SKU = @cSKU--@cComponentSku
--                   AND Storerkey = @cStorer
             -- Modified By Vicky for SOS#92327 - To parse in lowest UOM value for componentSKU instead of Parentsku (Start)
               SELECT @cPackKey = PACK.PackKey,
                      @cUOM     = PACK.PACKUOM3 -- Vicky
               FROM dbo.SKU SKU WITH (NOLOCK)
               JOIN dbo.PACK PACK WITH (NOLOCK) ON (PACK.Packkey = SKU.Packkey) -- Vicky
               WHERE SKU.SKU = @cComponentSku --@cSKU--@cComponentSku -- Vicky
               AND SKU.Storerkey = @cStorer
             -- Modified By Vicky for SOS#92327 - To parse in lowest UOM value for componentSKU instead of Parentsku (End)
            END
            SET ROWCOUNT 0

            SET @nTotalQty = @nComponentQty * CONVERT(FLOAT, @cQty) * @nUOMQty  -- (Vanessa01)


--             SET @cErrMsg = cast(@cSku as NVARCHAR)
--             GOTO Step_R

        -- (james03)
            -- by default the V_Lottable04 & V_Lottable05 in rdt.rdtmobrec
            -- is with value '1900-01-01 00:00:00.000'. If not lottable_label setup then
            -- set them with blank value
            IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
            BEGIN
               SET @cLottable04 = ''
            END

            IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL
            BEGIN
               SET @cLottable05 = ''
            END

            -- (ChewKP01) EXEC RFRC By POKey

            IF @nPOCount > 1
            BEGIN

               SET @nPOCountQty = @nPOCount

               -- (james16)
               SET @cRcptConfirm_SP = ''
               SET @cRcptConfirm_SP = rdt.RDTGetConfig( @nFunc, 'ReceiptConfirm_SP', @cStorer)

               DECLARE curPO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

               SELECT POkey, QtyExpected FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               AND Storerkey = @cStorer
               AND SKU = @cComponentSku

               OPEN curPO
               FETCH NEXT FROM curPO INTO @c_MultiPOKey, @nQtyExpected
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                     SET @nReceivedQty = 0

                     SET @nRecordCount = 0

                     SELECT @nRecordCount = Count(QtyExpected)
                     FROM dbo.ReceiptDetail WITH (NOLOCK)
                     WHERE ReceiptKey = @cReceiptKey
                     AND Storerkey = @cStorer
                     AND SKU = @cComponentSku

                     IF @nRecordCount = 1
                     BEGIN
                        SET @nReceivedQty = @nTotalQty
                     END
                     ELSE
                     BEGIN
                        IF @nQtyExpected = @nTotalQty
                        BEGIN
                           SET @nReceivedQty = @nQtyExpected
                        END
                        ELSE IF @nTotalQty >  @nQtyExpected
                        BEGIN
                           SET @nReceivedQty = @nQtyExpected
                        END
                        ELSE IF @nTotalQty <  @nQtyExpected
                        BEGIN
                           SET @nReceivedQty = @nTotalQty
                        END

                        -- End of Loop Assign all Remaining Qty
                        IF @nPOCountQty = 1
                        BEGIN
                           SET @nReceivedQty = @cQty
                        END
                     END



         --            SET @cLottable05 = CONVERT(NVARCHAR(12), GETDATE(), 112)


                     SET @nNOPOFlag = CASE WHEN @cPOkey = 'NOPO' THEN '1' ELSE '0' END

                     IF @cRcptConfirm_SP NOT IN ('', '0') AND
                        EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRcptConfirm_SP AND type = 'P')
                     BEGIN
                        SET @cSQL = 'EXEC rdt.' + RTRIM( @cRcptConfirm_SP) +
                           ' @nFunc, @nMobile, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, ' +
                           ' @cToLOC, @cToID, @cSKUCode, @cSKUUOM, @nSKUQTY, @cUCC, @cUCCSKU, @nUCCQTY, @cCreateUCC, @cLottable01, ' +
                           ' @cLottable02, @cLottable03, @dLottable04, @dLottable05, @nNOPOFlag, @cConditionCode, @cSubreasonCode, ' +
                           ' @cReceiptLineNumberOutput OUTPUT, @cDebug '

                        SET @cSQLParam =
                           '@nFunc          INT,            ' +
                           '@nMobile        INT,            ' +
                           '@cLangCode      NVARCHAR( 3),   ' +
                           '@nErrNo         INT   OUTPUT,   ' +
                           '@cErrMsg        NVARCHAR( 20) OUTPUT,  ' +
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
                           '@nNOPOFlag      INT,            ' +
                           '@cConditionCode NVARCHAR( 10),  ' +
                           '@cSubreasonCode NVARCHAR( 10),  ' +
                           '@cReceiptLineNumberOutput NVARCHAR( 5) OUTPUT, ' +
                           '@cDebug         NVARCHAR( 1) '

                        EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                           @nFunc, @nMobile, @cLangCode, @n_err OUTPUT, @c_errmsg OUTPUT, @cStorer, @cFacility, @cReceiptKey, @c_MultiPOKey,
                           @cLOC, @cID, @cComponentSku, @cUOM, @nReceivedQty, @cUCC, @cUCCSKU, @nUCCQTY, @cCreateUCC, @cLottable01,
                           @cLottable02, @cSku, @cLottable04, @cLottable05, @nNOPOFlag, @cReasonCode, @cSubreasonCode,  -- @cSku for ParentSKU
                           @cReceiptLineNumberOutput OUTPUT, @cDebug
                     END
                     ELSE
                     BEGIN
                        EXEC dbo.nspRFRC01
                              @c_sendDelimiter = null
                           ,  @c_ptcid        = 'RDT'
                           ,  @c_userid       = 'RDT'
                           ,  @c_taskId       = 'RDT'
                           ,  @c_databasename = NULL
                           ,  @c_appflag      = null
                           ,  @c_recordType   = null
                           ,  @c_server       = null
                           ,  @c_receiptkey   = null
                           ,  @c_storerkey    = @cStorer
                           ,  @c_prokey       = @cReceiptKey
                           ,  @c_sku          = @cComponentSku
                           ,  @c_lottable01   = @cLottable01
                           ,  @c_lottable02   = @cLottable02
                           ,  @c_lottable03   = @cSku -- ParentSKU
                           ,  @c_lottable04   = @cLottable04
                           ,  @c_lottable05   = @cLottable05
                           ,  @c_lot          = ''
                           ,  @c_pokey        = @c_MultiPOKey -- @c_POKey -- can be 'NOPO' (ChewKP01)
                           ,  @n_qty          = @nReceivedQty --@nTotalQty  (ChewKP01)
                           ,  @c_uom          = @cUOM
                           ,  @c_packkey      = @cPackKey
                           ,  @c_loc          = @cLOC
                           ,  @c_id           = @cID
                           ,  @c_holdflag     = @cReasonCode
                           ,  @c_other1       = ''
                           ,  @c_other2       = ''
                           ,  @c_other3       = ''
                           ,  @c_outstring    = @c_outstring  OUTPUT
                           ,  @b_Success      = @b_Success OUTPUT
                           ,  @n_err          = @n_err OUTPUT
                           ,  @c_errmsg       = @c_errmsg OUTPUT
                     END

                     IF @n_err <> 0
                     BEGIN
                        ROLLBACK TRAN
                        -- remain on the last screen
                        SET @cErrMsg = rdt.rdtgetmessage( @n_err, @cLangCode, 'DSP')

                        IF @cHasLottable = '1'
                        BEGIN
                           -- Disable lottable
                           IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
                           BEGIN
                              SET @cFieldAttr02 = 'O' -- (Vicky02)
                              SET @cOutField02 = ''
                              --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field02', 'NULL', 'output', 'NULL', 'NULL', '')
                           END

                           IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
                           BEGIN
                              SET @cFieldAttr04 = 'O' -- (Vicky02)
                              SET @cOutField04 = ''
                              --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field04', 'NULL', 'output', 'NULL', 'NULL', '')
                           END

                           IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
                           BEGIN
                              -- (Vicky07) - Start
                              SET @cDisplayLot03 = ''
                              SET @cDisplayLot03 = rdt.RDTGetConfig( 0, 'DisplayLot03', @cStorer)

                              IF @cDisplayLot03 = '1'
                              BEGIN
                                  SET @cOutField05 = 'Lottable03:'
                                  SET @cOutField06 = ISNULL(@cLottable03, '')
                              END
                              ELSE
                              BEGIN
                                 SET @cFieldAttr06 = 'O' -- (Vicky02)
                                 SET @cOutField06 = ''
                              END
                              --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field06', 'NULL', 'output', 'NULL', 'NULL', '')
                           END

                           IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
                           BEGIN
                              SET @cFieldAttr08 = 'O' -- (Vicky02)
                              SET @cOutField08 = ''
                              --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
                           END

                           IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL
                           BEGIN
                              SET @cFieldAttr10 = 'O' -- (Vicky02)
                              SET @cOutField10 = ''
                              --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')
                           END
               END

                        GOTO Quit
         END

                      SELECT @cQty = CAST(@cQty as DECIMAL(10,0))
   -- (Vicky06) EventLog - QTY
                      EXEC RDT.rdt_STD_EventLog
                          @cActionType   = '2', -- Receiving
                          @cUserID       = @cUserName,
                          @nMobileNo     = @nMobile,
                          @nFunctionID   = @nFunc,
                          @cFacility     = @cFacility,
                          @cStorerKey    = @cStorer,
                          @cLocation     = @cLOC,
                          @cID           = @cID,
                          @cSKU          = @cSku, -- ParentSKU
                          @cComponentSKU = @cComponentSku, -- Component SKU
                          @cUOM          = @cUOM,
                          @nQTY          = @nTotalQty,
                          @cRefNo1       = @cReceiptKey,
                          @cRefNo2       = @c_POKey

                     SET @nTempCount = @nTempCount + 1
                     SET @nPOCountQty = @nPOCountQty - 1
                     SET @nTotalQty = @nTotalQty - @nReceivedQty

                     IF @nTotalQty <= 0
                     BEGIN
                        SET @nTotalQty = 0
                        BREAK
                     END

                     FETCH NEXT FROM curPO INTO @c_MultiPOKey, @nQtyExpected
               END -- While Loop PO
               CLOSE curPO
               DEALLOCATE curPO
            END -- End @nPOCount > 1
            ELSE IF @nPOCount = 1 OR @nPOCount = 0 -- (ChewKP02)
            BEGIN
               SET @nNOPOFlag = CASE WHEN @cPOkey = 'NOPO' THEN '1' ELSE '0' END

               SET @cRcptConfirm_SP = ''
               SET @cRcptConfirm_SP = rdt.RDTGetConfig( @nFunc, 'ReceiptConfirm_SP', @cStorer)
               IF @cRcptConfirm_SP NOT IN ('', '0') AND
                  EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRcptConfirm_SP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cRcptConfirm_SP) +
                     ' @nFunc, @nMobile, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, ' +
                     ' @cToLOC, @cToID, @cSKUCode, @cSKUUOM, @nSKUQTY, @cUCC, @cUCCSKU, @nUCCQTY, @cCreateUCC, @cLottable01, ' +
                     ' @cLottable02, @cLottable03, @dLottable04, @dLottable05, @nNOPOFlag, @cConditionCode, @cSubreasonCode, ' +
                     ' @cReceiptLineNumberOutput OUTPUT, @cDebug '

                  SET @cSQLParam =
                     '@nFunc          INT,            ' +
                     '@nMobile        INT,            ' +
                     '@cLangCode      NVARCHAR( 3),   ' +
                     '@nErrNo         INT   OUTPUT,   ' +
                     '@cErrMsg        NVARCHAR( 20) OUTPUT,  ' +
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
                     '@nNOPOFlag      INT,            ' +
                     '@cConditionCode NVARCHAR( 10),  ' +
                     '@cSubreasonCode NVARCHAR( 10),  ' +
                     '@cReceiptLineNumberOutput NVARCHAR( 5) OUTPUT, ' +
                     '@cDebug         NVARCHAR( 1) '

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nFunc, @nMobile, @cLangCode, @n_err OUTPUT, @c_errmsg OUTPUT, @cStorer, @cFacility, @cReceiptKey, @c_POKey,
                     @cLOC, @cID, @cComponentSku, @cUOM, @nTotalQty, @cUCC, @cUCCSKU, @nUCCQTY, @cCreateUCC, @cLottable01,
                     @cLottable02, @cSku, @cLottable04, @cLottable05, @nNOPOFlag, @cReasonCode, @cSubreasonCode,  -- @cSku for ParentSKU
                     @cReceiptLineNumberOutput OUTPUT, @cDebug
               END
               ELSE
               BEGIN
                  EXEC dbo.nspRFRC01
                        @c_sendDelimiter = null
                     ,  @c_ptcid        = 'RDT'
                     ,  @c_userid       = 'RDT'
                     ,  @c_taskId       = 'RDT'
                     ,  @c_databasename = NULL
                     ,  @c_appflag      = null
                     ,  @c_recordType   = null
                     ,  @c_server       = null
                     ,  @c_receiptkey   = null
                     ,  @c_storerkey    = @cStorer
                     ,  @c_prokey       = @cReceiptKey
                     ,  @c_sku          = @cComponentSku
                     ,  @c_lottable01   = @cLottable01
                     ,  @c_lottable02   = @cLottable02
                     ,  @c_lottable03   = @cSku -- ParentSKU
                     ,  @c_lottable04   = @cLottable04
                     ,  @c_lottable05   = @cLottable05
                     ,  @c_lot          = ''
                     ,  @c_pokey        = @c_POKey -- can be 'NOPO'
                     ,  @n_qty          = @nTotalQty --@nTotalQty  (ChewKP01)
                     ,  @c_uom          = @cUOM
                     ,  @c_packkey      = @cPackKey
                     ,  @c_loc          = @cLOC
                     ,  @c_id           = @cID
                     ,  @c_holdflag     = @cReasonCode
                     ,  @c_other1       = ''
                     ,  @c_other2       = ''
                     ,  @c_other3       = ''
                     ,  @c_outstring    = @c_outstring  OUTPUT
                     ,  @b_Success      = @b_Success OUTPUT
                     ,  @n_err          = @n_err OUTPUT
                     ,  @c_errmsg       = @c_errmsg OUTPUT
               END

               IF @n_err <> 0
               BEGIN
                  ROLLBACK TRAN
                  -- remain on the last screen
                  SET @cErrMsg = rdt.rdtgetmessage( @n_err, @cLangCode, 'DSP')

                  IF @cHasLottable = '1'
                  BEGIN
                     -- Disable lottable
                     IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
                     BEGIN
                        SET @cFieldAttr02 = 'O' -- (Vicky02)
                        SET @cOutField02 = ''
                        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field02', 'NULL', 'output', 'NULL', 'NULL', '')
                     END

                     IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
                     BEGIN
                        SET @cFieldAttr04 = 'O' -- (Vicky02)
                        SET @cOutField04 = ''
                        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field04', 'NULL', 'output', 'NULL', 'NULL', '')
                     END

                     IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
                     BEGIN
                        -- (Vicky07) - Start
                        SET @cDisplayLot03 = ''
                        SET @cDisplayLot03 = rdt.RDTGetConfig( 0, 'DisplayLot03', @cStorer)

                        IF @cDisplayLot03 = '1'
                        BEGIN
                            SET @cOutField05 = 'Lottable03:'
                            SET @cOutField06 = ISNULL(@cLottable03, '')
                        END
                        ELSE
                        BEGIN
                           SET @cFieldAttr06 = 'O' -- (Vicky02)
                           SET @cOutField06 = ''
                        END
                        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field06', 'NULL', 'output', 'NULL', 'NULL', '')
                     END

                     IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
                     BEGIN
                        SET @cFieldAttr08 = 'O' -- (Vicky02)
                        SET @cOutField08 = ''
                        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
                     END

                     IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL
                     BEGIN
                        SET @cFieldAttr10 = 'O' -- (Vicky02)
                        SET @cOutField10 = ''
                        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')
                     END
                  END

                  GOTO Quit
               END

                SELECT @cQty = CAST(@cQty as DECIMAL(10,0))
                -- (Vicky06) EventLog - QTY
                EXEC RDT.rdt_STD_EventLog
                    @cActionType   = '2', -- Receiving
                    @cUserID       = @cUserName,
                    @nMobileNo     = @nMobile,
                    @nFunctionID   = @nFunc,
                    @cFacility     = @cFacility,
                    @cStorerKey    = @cStorer,
                    @cLocation     = @cLOC,
                    @cID           = @cID,
                    @cSKU          = @cSku, -- ParentSKU
                    @cComponentSKU = @cComponentSku, -- Component SKU
                    @cUOM          = @cUOM,
                    @nQTY          = @nTotalQty,
                    @cRefNo1       = @cReceiptKey,
                    @cRefNo2       = @c_POKey

               SET @nTempCount = @nTempCount + 1

            END -- @nPOCount = 1

         END --end of while loop

         IF @n_err = 0
         BEGIN
            COMMIT TRAN

            IF @cPalletRecv = '1' -- (Vicky04)
            BEGIN
               SET @nScn = 963
               SET @nStep = 10
            END
            ELSE
            BEGIN
               SET @nScn = 957
               SET @nStep = 7
            END
            GOTO Quit
         END

      END --end of @cPrePackByBOM = '1'

      Receiving_Normal:
      IF ISNULL(@cPackKey, '') = ''
      BEGIN
         SELECT @cPackKey = PackKey FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorer AND SKU = @cSKU -- SOS# 213546
      END

      IF ISNULL(@cUOM, '') = ''
      BEGIN
         SELECT @cUOM = CASE @cPrefUOM
            WHEN '2' THEN PACK.PackUOM1 -- Case
           WHEN '3' THEN PACK.PackUOM2 -- Inner pack
            WHEN '6' THEN PACK.PackUOM3 -- Master unit
            WHEN '1' THEN PACK.PackUOM4 -- Pallet
            WHEN '4' THEN PACK.PackUOM8 -- Other unit 1
            WHEN '5' THEN PACK.PackUOM9 -- Other unit 2
            END
         FROM dbo.PACK PACK WITH (NOLOCK)
         WHERE PACK.Packkey = @cPackkey
      END
      -- (james03)
      -- by default the V_Lottable04 & V_Lottable05 in rdt.rdtmobrec
      -- is with value '1900-01-01 00:00:00.000'. If not lottable_label setup then
      -- set them with blank value
      IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
      BEGIN
         SET @cLottable04 = ''
      END

      IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL
      BEGIN
         SET @cLottable05 = ''
      END

      BEGIN TRAN
      -- (ChewKP01) EXEC RFRC By POKey

            IF @nPOCount > 1
            BEGIN

               SET @nPOCountQty = @nPOCount

               -- (james16)
               SET @cRcptConfirm_SP = ''
               SET @cRcptConfirm_SP = rdt.RDTGetConfig( @nFunc, 'ReceiptConfirm_SP', @cStorer)

               DECLARE curPO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

               SELECT POkey, QtyExpected FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               AND Storerkey = @cStorer
               AND SKU = @cSku
               ORDER BY Pokey -- (james14)

               OPEN curPO
               FETCH NEXT FROM curPO INTO @c_MultiPOKey, @nQtyExpected
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  IF @c_MultiPOKey = ''
                     SET @c_MultiPOKey = 'NOPO' -- (james14)
                     SET @nReceivedQty = 0

                     SELECT @nRecordCount = Count(QtyExpected)
                     FROM dbo.ReceiptDetail WITH (NOLOCK)
                     WHERE ReceiptKey = @cReceiptKey
                     AND Storerkey = @cStorer
                     AND SKU = @cSku


                     IF @nRecordCount = 1
                     BEGIN
                        SET @nReceivedQty = @nQty
                     END
                     ELSE
                     BEGIN

                        IF @nQtyExpected = @nQty
                        BEGIN
                           SET @nReceivedQty = @nQtyExpected
                        END
                        ELSE IF @nQty >  @nQtyExpected
                        BEGIN
                           SET @nReceivedQty = CASE WHEN @nQtyExpected = 0 THEN CAST(@cQty AS INT) ELSE @nQtyExpected END
                        END
                        ELSE IF @nQty <  @nQtyExpected
                        BEGIN
                           SET @nReceivedQty = @nQty
                        END

                        IF @nPOCountQty = 1
                        BEGIN
                              SET @nReceivedQty = @nQty
                        END
                     END

                     -- End of Loop Assign all Remaining Qty

                     SET @nNOPOFlag = CASE WHEN @cPOkey = 'NOPO' THEN '1' ELSE '0' END

                     IF @cRcptConfirm_SP NOT IN ('', '0') AND
                        EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRcptConfirm_SP AND type = 'P')
                     BEGIN
                        SET @cSQL = 'EXEC rdt.' + RTRIM( @cRcptConfirm_SP) +
                           ' @nFunc, @nMobile, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, ' +
                           ' @cToLOC, @cToID, @cSKUCode, @cSKUUOM, @nSKUQTY, @cUCC, @cUCCSKU, @nUCCQTY, @cCreateUCC, @cLottable01, ' +
                           ' @cLottable02, @cLottable03, @dLottable04, @dLottable05, @nNOPOFlag, @cConditionCode, @cSubreasonCode, ' +
                           ' @cReceiptLineNumberOutput OUTPUT, @cDebug '

                        SET @cSQLParam =
                           '@nFunc          INT,            ' +
                           '@nMobile        INT,            ' +
                           '@cLangCode      NVARCHAR( 3),   ' +
                           '@nErrNo         INT   OUTPUT,   ' +
                           '@cErrMsg        NVARCHAR( 20) OUTPUT,  ' +
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
                           '@nNOPOFlag      INT,            ' +
                           '@cConditionCode NVARCHAR( 10),  ' +
                           '@cSubreasonCode NVARCHAR( 10),  ' +
                           '@cReceiptLineNumberOutput NVARCHAR( 5) OUTPUT, ' +
                           '@cDebug         NVARCHAR( 1) '

                        EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                           @nFunc, @nMobile, @cLangCode, @n_err OUTPUT, @c_errmsg OUTPUT, @cStorer, @cFacility, @cReceiptKey, @c_MultiPOKey,
                           @cLOC, @cID, @cSKU, @cUOM, @nReceivedQty, @cUCC, @cUCCSKU, @nUCCQTY, @cCreateUCC, @cLottable01,
                           @cLottable02, @cLottable03, @cLottable04, @cLottable05, @nNOPOFlag, @cReasonCode, @cSubreasonCode,  -- @cSku for ParentSKU
                           @cReceiptLineNumberOutput OUTPUT, @cDebug
                     END
                     ELSE
                     BEGIN
                        EXEC DBO.nspRFRC01
                           @c_sendDelimiter = null
                        ,  @c_ptcid        = 'RDT'
                        ,  @c_userid       = 'RDT'
                        ,  @c_taskId       = 'RDT'
                        ,  @c_databasename = NULL
                        ,  @c_appflag      = null
                        ,  @c_recordType   = null
                        ,  @c_server       = null
                        ,  @c_receiptkey   = null
                        ,  @c_storerkey    = @cStorer
                        ,  @c_prokey       = @cReceiptKey
                        ,  @c_sku          = @cSKU
                        ,  @c_lottable01   = @cLottable01
                        ,  @c_lottable02   = @cLottable02
                        ,  @c_lottable03   = @cLottable03
                        ,  @c_lottable04   = @cLottable04
                        ,  @c_lottable05   = @cLottable05
                        ,  @c_lot          = ''
                        ,  @c_pokey        = @c_MultiPOKey --@c_POKey -- can be 'NOPO' (ChewKP01)
                        ,  @n_qty          = @nReceivedQty
                        ,  @c_uom          = @cUOM
                        ,  @c_packkey      = @cPackKey
                        ,  @c_loc          = @cLOC
                        ,  @c_id           = @cID
                        ,  @c_holdflag     = @cReasonCode
                        ,  @c_other1       = ''
                        ,  @c_other2       = ''
                        ,  @c_other3       = ''
                        ,  @c_outstring    = @c_outstring  OUTPUT
                        ,  @b_Success      = @b_Success OUTPUT
                        ,  @n_err          = @n_err OUTPUT
                        ,  @c_errmsg       = @c_errmsg OUTPUT
                     END

                     IF @n_err = 0
                     BEGIN
                         SELECT @cQty = CAST(@cQty as DECIMAL(10,0))
                         -- (Vicky06) EventLog - QTY
                         EXEC RDT.rdt_STD_EventLog
                            @cActionType   = '2', -- Receiving
                            @cUserID       = @cUserName,
                            @nMobileNo     = @nMobile,
                            @nFunctionID   = @nFunc,
                            @cFacility     = @cFacility,
                            @cStorerKey    = @cStorer,
                            @cLocation     = @cLOC,
                            @cID           = @cID,
                            @cSKU          = @cSku, -- ParentSKU
                            @cUOM          = @cUOM,
                            @nQTY          = @cQty,
                            @cRefNo1       = @cReceiptKey,
                            @cRefNo2       = @c_POKey

                        --COMMIT TRAN

                     END
                     ELSE
                     BEGIN
                        ROLLBACK TRAN
                        -- remain on the last screen
                        SET @cErrMsg = rdt.rdtgetmessage( @n_err, @cLangCode, 'DSP')

                        IF @cHasLottable = '1'
                        BEGIN
                           -- Disable lottable
                           IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
                           BEGIN
                              SET @cFieldAttr02 = 'O' -- (Vicky02)
                              SET @cOutField02 = ''
                              --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field02', 'NULL', 'output', 'NULL', 'NULL', '')
                           END

                           IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
                           BEGIN
                              SET @cFieldAttr04 = 'O' -- (Vicky02)
                              SET @cOutField04 = ''
                              --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field04', 'NULL', 'output', 'NULL', 'NULL', '')
                           END

                           IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
                           BEGIN
                              SET @cFieldAttr06 = 'O' -- (Vicky02)
                              SET @cOutField06 = ''
                              --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field06', 'NULL', 'output', 'NULL', 'NULL', '')
                           END

                           IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
                           BEGIN
                              SET @cFieldAttr08 = 'O' -- (Vicky02)
                              SET @cOutField08 = ''
                              --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
                           END

                           IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL
                           BEGIN
                              SET @cFieldAttr10 = 'O' -- (Vicky02)
                              SET @cOutField10 = ''
                              --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')
                           END
                        END

                        GOTO Quit
                     END

                     SET @nPOCountQty = @nPOCountQty - 1
                     SET @cQty = @cQty - @nReceivedQty



                     IF @cQty <= 0
                     BEGIN
                        SET @cQty = ABS(@cQty)
                        BREAK
                     END

                     FETCH NEXT FROM curPO INTO @c_MultiPOKey, @nQtyExpected
               END -- While Loop PO
               CLOSE curPO
               DEALLOCATE curPO
            END -- End @nPOCount > 1
            ELSE IF @nPOCount = 1 OR @nPOCount = 0 -- (ChewKP02)
            BEGIN
               SET @nNOPOFlag = CASE WHEN @cPOkey = 'NOPO' THEN '1' ELSE '0' END

               SET @cRcptConfirm_SP = ''
               SET @cRcptConfirm_SP = rdt.RDTGetConfig( @nFunc, 'ReceiptConfirm_SP', @cStorer)
               IF @cRcptConfirm_SP NOT IN ('', '0') AND
                  EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRcptConfirm_SP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cRcptConfirm_SP) +
                     ' @nFunc, @nMobile, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cStorerKey, @cFacility, @cReceiptKey, @cPOKey, ' +
                     ' @cToLOC, @cToID, @cSKUCode, @cSKUUOM, @nSKUQTY, @cUCC, @cUCCSKU, @nUCCQTY, @cCreateUCC, @cLottable01, ' +
                     ' @cLottable02, @cLottable03, @dLottable04, @dLottable05, @nNOPOFlag, @cConditionCode, @cSubreasonCode, ' +
                     ' @cReceiptLineNumberOutput OUTPUT, @cDebug '

                  SET @cSQLParam =
                     '@nFunc          INT,            ' +
                     '@nMobile        INT,            ' +
                     '@cLangCode      NVARCHAR( 3),   ' +
                     '@nErrNo         INT   OUTPUT,   ' +
                     '@cErrMsg        NVARCHAR( 20) OUTPUT,  ' +
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
                     '@nNOPOFlag      INT,            ' +
                     '@cConditionCode NVARCHAR( 10),  ' +
                     '@cSubreasonCode NVARCHAR( 10),  ' +
                     '@cReceiptLineNumberOutput NVARCHAR( 5) OUTPUT, ' +
                     '@cDebug         NVARCHAR( 1) '

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nFunc, @nMobile, @cLangCode, @n_err OUTPUT, @c_errmsg OUTPUT, @cStorer, @cFacility, @cReceiptKey, @c_POKey,
                     @cLOC, @cID, @cSKU, @cUOM, @nQty, @cUCC, @cUCCSKU, @nUCCQTY, @cCreateUCC, @cLottable01,
                     @cLottable02, @cLottable03, @cLottable04, @cLottable05, @nNOPOFlag, @cReasonCode, @cSubreasonCode,  -- @cSku for ParentSKU
                     @cReceiptLineNumberOutput OUTPUT, @cDebug
               END
               ELSE
               BEGIN
                  EXEC DBO.nspRFRC01
                     @c_sendDelimiter = null
                  ,  @c_ptcid        = 'RDT'
                  ,  @c_userid       = 'RDT'
                  ,  @c_taskId       = 'RDT'
                  ,  @c_databasename = NULL
                  ,  @c_appflag      = null
                  ,  @c_recordType   = null
                  ,  @c_server       = null
                  ,  @c_receiptkey   = null
                  ,  @c_storerkey    = @cStorer
                  ,  @c_prokey       = @cReceiptKey
                  ,  @c_sku          = @cSKU
                  ,  @c_lottable01   = @cLottable01
                  ,  @c_lottable02   = @cLottable02
                  ,  @c_lottable03   = @cLottable03
                  ,  @c_lottable04   = @cLottable04
                  ,  @c_lottable05   = @cLottable05
                  ,  @c_lot          = ''
                  ,  @c_pokey        = @c_POKey -- can be 'NOPO'
                  ,  @n_qty          = @cQty
                  ,  @c_uom          = @cUOM
                  ,  @c_packkey      = @cPackKey
                  ,  @c_loc          = @cLOC
                  ,  @c_id           = @cID
                  ,  @c_holdflag     = @cReasonCode
                  ,  @c_other1       = ''
                  ,  @c_other2       = ''
                  ,  @c_other3       = ''
                  ,  @c_outstring    = @c_outstring  OUTPUT
                  ,  @b_Success      = @b_Success OUTPUT
                  ,  @n_err          = @n_err OUTPUT
                  ,  @c_errmsg       = @c_errmsg OUTPUT
               END

               IF @n_err = 0
               BEGIN
                   SELECT @cQty = CAST(@cQty as DECIMAL(10,0))
                   -- (Vicky06) EventLog - QTY
                   EXEC RDT.rdt_STD_EventLog
                      @cActionType   = '2', -- Receiving
                      @cUserID       = @cUserName,
                      @nMobileNo     = @nMobile,
                      @nFunctionID   = @nFunc,
                      @cFacility     = @cFacility,
                      @cStorerKey    = @cStorer,
                      @cLocation     = @cLOC,
                      @cID           = @cID,
                      @cSKU          = @cSku, -- ParentSKU
                      @cUOM          = @cUOM,
                      @nQTY          = @cQty,
                      @cRefNo1       = @cReceiptKey,
                      @cRefNo2       = @c_POKey

--                     COMMIT TRAN

--                     IF @cPalletRecv = '1' -- (Vicky04)
--                     BEGIN
--                       SET @nScn = 963
--                       SET @nStep = 10
--                     END
--                     ELSE
--                     BEGIN
--                        SET @nScn = 957
--                        SET @nStep = 7
--                     END
               END
               ELSE
               BEGIN
                  ROLLBACK TRAN
                  -- remain on the last screen
                  SET @cErrMsg = rdt.rdtgetmessage( @n_err, @cLangCode, 'DSP')

                  IF @cHasLottable = '1'
                  BEGIN
                     -- Disable lottable
                     IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
                     BEGIN
                        SET @cFieldAttr02 = 'O' -- (Vicky02)
                        SET @cOutField02 = ''
                        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field02', 'NULL', 'output', 'NULL', 'NULL', '')
                     END

                     IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
                     BEGIN
                        SET @cFieldAttr04 = 'O' -- (Vicky02)
                        SET @cOutField04 = ''
                        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field04', 'NULL', 'output', 'NULL', 'NULL', '')
                     END

                     IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
                     BEGIN
                        SET @cFieldAttr06 = 'O' -- (Vicky02)
                        SET @cOutField06 = ''
                        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field06', 'NULL', 'output', 'NULL', 'NULL', '')
                     END

                     IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
                     BEGIN
                        SET @cFieldAttr08 = 'O' -- (Vicky02)
                        SET @cOutField08 = ''
                        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
                     END

                     IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL
                     BEGIN
                        SET @cFieldAttr10 = 'O' -- (Vicky02)
                        SET @cOutField10 = ''
                        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')
                     END
                  END

                  GOTO QUIT
               END
            END

            COMMIT TRAN

            IF @cPalletRecv = '1' -- (Vicky04)
            BEGIN
              SET @nScn = 963
              SET @nStep = 10
            END
            ELSE
            BEGIN
               SET @nScn = 957
               SET @nStep = 7
            END
    Step_R:

   END --end of @cInputKey
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

      StorerKey     = @cStorer,   -- (Vicky03)
      Facility      = @cFacility, -- (Vicky03)
      Printer       = @cPrinter,  -- (Vicky03)
      -- UserName      = @cUserName, -- (Vicky03)

      V_ReceiptKey = @cReceiptKey,
      V_POKey      = @cPOKey,
      V_Loc        = @cLOC,
      V_SKU        = @cSKU,
      V_UOM        = @cUOM,
      V_ID         = @cID,
      V_QTY        = @nQTY,
      V_SKUDescr   = @cSKUDesc,     -- (Vicky02)

      V_Lottable01 = @cLottable01, -- SOS#81879
      V_Lottable02 = @cLottable02, -- SOS#81879
      V_Lottable03 = @cLottable03, -- SOS#81879
      V_Lottable04 = rdt.rdtConvertToDate( @cLottable04), -- SOS#81879
      V_Lottable05 = rdt.rdtConvertToDate( @cLottable05), -- SOS#81879

      V_String1    = @cPOKeyDefaultValue, -- SOS76264
      V_String2    = @cAddSKUtoASN,       --SOS80652
      V_String3    = @cExternPOKey,       --SOS80652
      V_String4    = @cExternLineNo,      --SOS80652
      V_String5    = @cExternReceiptKey,  -- SOS80652
      V_String6    = @cReceiptLineNo,     -- SOS80652
      V_String7    = @cPrefUOM,           -- SOS80652
      V_String8    = @cNewSKUFlag,        -- SOS80652
      V_String9    = @cAllowOverRcpt,     -- SOS80652
      V_String10   = @cPrePackByBOM,
      V_String11   = @cUPCPackKey,
      V_String12   = @cUPCUOM,
      V_String13   = @cUPCSKU, -- Vicky 20-Sept-2007

      V_String14   = @cLottable01_Code, -- SOS#81879
      V_String15   = @cLottable02_Code, -- SOS#81879
      V_String16   = @cLottable03_Code, -- SOS#81879
      V_String17   = @cLottable04_Code, -- SOS#81879
      V_String18   = @cLottable05_Code, -- SOS#81879

      V_String20   = @cReasonCode,  -- (Vicky02)
      V_String21   = @cIVAS,        -- (Vicky02)
      V_String22   = @cLotLabel01,  -- (Vicky02)
      V_String23   = @cLotLabel02,  -- (Vicky02)
      V_String24   = @cLotLabel03,  -- (Vicky02)
      V_String25   = @cLotLabel04,  -- (Vicky02)
      V_String26   = @cLotLabel05,  -- (Vicky02)
      V_String27   = @cPackKey,     -- (Vicky02)
      V_String28   = @cHasLottable, -- (Vicky02)

      V_String29   = @cPrevOp,      -- (Vicky03)
      V_String30   = @cScnOption,   -- (Vicky03)
      V_String31   = @cAutoGenID,   -- (Vicky03)
      V_String32   = @cPromptOpScn, -- (Vicky03)
      V_String33   = @cReceivingPrintLabel, -- (Vicky03)
      V_String34   = @cPrintMultiLabel,   -- (Vicky03)
      V_String35   = @cPrintNoOfCopy,     -- (Vicky03)
      V_String36   = @cPalletRecv,        -- (Vicky04)
      V_String37   = @cPromptVerifyPKScn, -- SOS#142253
      V_String38   = @cDefaultToLoc,      -- (Vanessa01)
      V_String39   = @cQty,               -- (Vanessa01)
      V_String40   = @nPOCount,           -- (ChewKP01)
      V_CaseID     = @cSSCC,           -- (james14)

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

      -- (Vicky02) - Start
      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,
      FieldAttr15  = @cFieldAttr15
      -- (Vicky02) - End

   WHERE Mobile = @nMobile
END



GO