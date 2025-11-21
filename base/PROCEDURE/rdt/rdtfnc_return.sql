SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdtfnc_Return                                             */
/* Copyright      : IDS                                                       */
/*                                                                            */
/* Purpose: Work the same as Exceed Trade Return                              */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2007-06-14   1.0  Vicky      Created                                       */
/* 2007-09-04   1.1  FKLim      Change of Spec                                */
/* 2008-01-04   1.2  Ung        SOS97261 Add RDT storer config                */
/*                              "ReturnDefaultQTY"                            */
/* 2007-12-05   1.3  Vicky      SOS#81879 - Modify Lottable_Wrapper           */
/* 2008-11-03   1.4  Vicky      Remove XML part of code that is used to       */
/*                              make field invisible and replace with         */
/*                              new code (Vicky02)                            */
/* 2009-07-06   1.5  Vicky      Add in EventLog (Vicky06)                     */
/* 2010-05-18   1.6  James      SOS173450 - Add in new screen (james01)       */
/* 2010-07-20   1.7  Tlting     Remove DB Pointing Hard Coding                */
/* 2010-07-19   1.8  ChewKP     SOS#176652 - New Screen and Flows             */
/*                              (ChewKP01)                                    */
/* 2010-08-12   1.9  James      Clear variables (james02)                     */
/* 2010-10-21   2.0  Audrey     SOS#191990 -Add initial var (ang01)           */
/* 2013-09-11   2.1  ChewKP     SOS#289137 - Include SKU in Lottable          */
/*                              Wrapper (ChewKP02)                            */
/* 2014-03-25   2.2  Ung        SOS306108 Add DecodeLabelNo                   */
/* 2014-04-24   2.3  Ung        SOS308961 PRE POST codelkup w StorerKey       */
/* 2014-07-31   2.4  James      SOS317336 - Add Zone, ExtendedInfo            */
/*                              Add config SkipLottable0X (james03)           */
/* 2014-09-19   2.5  Ung        SOS319427 Fix NOPOFlag                        */
/* 2015-01-16   2.6  CSCHONG    New lottable 05 to 15 (CS01)                  */
/* 2015-05-25   2.7  CSCHONG    Remove rdt_receive lottable06-15              */
/*                              parm (CS02)                                   */
/* 2015-03-23   2.8  James      SOS334084 - Add ExtendedInfoSP @ step 4       */
/*                              Fix IVAS display (james04)                    */
/* 2015-07-06   2.8  James      SOS336742-Add multi skubarcode (james04)      */
/* 2016-09-30   2.9  Ung        Performance tuning                            */
/* 2016-10-20   3.0  Leong      IN00177098 - Extend variables length.         */
/* 2016-10-28   3.1  James      Change isDate to rdtIsValidDate(james05)      */
/* 2017-01-24   3.2  Ung        Fix recompile due to date format different    */
/* 2017-10-06   3.3  Ung        WMS-3153 Add ExtendedInfo at SKU screen       */
/*                              WMS-3154 ADD ExtendedValidate at ID screen    */
/*                              Change ExtendedInfo to use rdt schema         */
/* 2018-10-16   3.4  TungGH     Performance                                   */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_Return](
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- Misc variables
DECLARE
   @b_success      INT,
   @n_err          INT,
   @c_errmsg       NVARCHAR( 250),
   @cXML           NVARCHAR( 4000), -- To allow double byte data for e.g. SKU desc
   @nNOPOFlag      INT

-- RDT.RDTMobRec variables
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,

   @nPrevScn            INT,
   @nPrevStep           INT,

   @cStorerKey          NVARCHAR( 15),
   @cUserName           NVARCHAR( 18),
   @cFacility           NVARCHAR( 5),

   @cReceiptKey         NVARCHAR( 10),
   @cPOKey              NVARCHAR( 10),
   @cPOKeyValue         NVARCHAR( 10),
   @cPOKeyDefaultValue  NVARCHAR( 10),
   @cLOC                NVARCHAR( 10),
   @cID                 NVARCHAR( 18),
   @cSKU                NVARCHAR( 60),
   @cSKUDescr           NVARCHAR( 60),
   @cUOM                NVARCHAR( 10),   -- Display NVARCHAR(3)
   @cQTY                NVARCHAR( 5),
   @cLottable01         NVARCHAR( 18),
   @cLottable02         NVARCHAR( 18),
   @cLottable03         NVARCHAR( 18),
   @dLottable04         DATETIME,
   @dLottable05         DATETIME,

   @cLottable06         NVARCHAR( 30),      --(CS01)
   @cLottable07         NVARCHAR( 30),      --(CS01)
   @cLottable08         NVARCHAR( 30),      --(CS01)
   @cLottable09         NVARCHAR( 30),      --(CS01)
   @cLottable10         NVARCHAR( 30),      --(CS01)
   @cLottable11         NVARCHAR( 30),      --(CS01)
   @cLottable12         NVARCHAR( 30),      --(CS01)
   @dLottable13         DATETIME,           --(CS01)
   @dLottable14         DATETIME,           --(CS01)
   @dLottable15         DATETIME,           --(CS01)

   @nPQTY               INT,  -- Preffered UOM QTY
   @nMQTY               INT,  -- Master unit QTY

   @cPrefUOM            NVARCHAR( 1), -- Pref UOM
   @nPrefUOM_Div        INT,      -- Pref UOM divider
   @cPrefUOM_Desc       NVARCHAR(10), -- Pref UOM desc   -- IN00177098
   @cMstUOM_Desc        NVARCHAR(10), -- Master UOM desc -- IN00177098
   @nMstQTY             INT,      -- Remaining QTY in master unit
   @nActMQTY            INT,      -- Actual keyed in master QTY
   @nActPQTY            INT,      -- Actual keyed in prefered QTY
   @nActQTY             INT,      -- Actual return QTY
   @cActPQTY            NVARCHAR( 5),
   @cActMQTY            NVARCHAR( 5),

   @nSKUCnt             INT,
   @nQTY                INT,      -- Receiptdetail.QTY
   @nBeforeReceivedQty  INT,      -- ReceiptDetail.BeforeReceivedQty
   @cSValue             NVARCHAR( 10),
   @cIVAS               NVARCHAR( 30),
   @cSUSR1              NVARCHAR( 18),
   @cListName           NVARCHAR( 20),
   @cShort              NVARCHAR( 10),
   @cStoredProd         NVARCHAR( 250),
   @cLottableLabel      NVARCHAR( 20),
   @cLotFlag            NVARCHAR( 1),
   @nCount              INT,

   @cSerialNo           NVARCHAR( 18),
   @cSubReason          NVARCHAR( 10),
   @cShortSN            NVARCHAR( 10),
   @cTempLotLabel       NVARCHAR(20),
   @cConditionCode      NVARCHAR(10),

   @cExpReason          NVARCHAR( 1),
   @cReturnReason       NVARCHAR( 1),
   @cOverRcpt           NVARCHAR( 1),
   @cSerialNoFlag       NVARCHAR( 1),
   @cIDFlag             NVARCHAR( 1),
   @cPickFaceFlag       NVARCHAR( 1),
   @cDefaultLOC         NVARCHAR( 10),

   @cLottable01Label    NVARCHAR( 20),
   @cLottable02Label    NVARCHAR( 20),
   @cLottable03Label    NVARCHAR( 20),
   @cLottable04Label    NVARCHAR( 20),
   @cLottable05Label    NVARCHAR( 20),

   @cLottable06Label    NVARCHAR( 20),       --(CS01)
   @cLottable07Label    NVARCHAR( 20),       --(CS01)
   @cLottable08Label    NVARCHAR( 20),       --(CS01)
   @cLottable09Label    NVARCHAR( 20),       --(CS01)
   @cLottable10Label    NVARCHAR( 20),       --(CS01)
   @cLottable11Label    NVARCHAR( 20),       --(CS01)
   @cLottable12Label    NVARCHAR( 20),       --(CS01)
   @cLottable13Label    NVARCHAR( 20),       --(CS01)
   @cLottable14Label    NVARCHAR( 20),       --(CS01)
   @cLottable15Label    NVARCHAR( 20),       --(CS01)

   @cTempLottable01     NVARCHAR( 60), --input field lottable01 from lottable screen
   @cTempLottable02     NVARCHAR( 60), --input field lottable02 from lottable screen
   @cTempLottable03     NVARCHAR( 60), --input field lottable03 from lottable screen
   @cTempLottable04     NVARCHAR( 16), --input field lottable04 from lottable screen
   @cTempLottable05     NVARCHAR( 16), --input field lottable05 from lottable screen

   @cTempLotLabel01     NVARCHAR( 20),
   @cTempLotLabel02     NVARCHAR( 20),
   @cTempLotLabel03     NVARCHAR( 20),
   @cTempLotLabel04     NVARCHAR( 20),
   @cTempLotLabel05     NVARCHAR( 20),
   @dTempLottable04     DATETIME,
   @dTempLottable05     DATETIME,

   @cTempConditionCode  NVARCHAR( 10),

   @nCTotalUQtyExpected INT, -- (ChewKP01)
   @nCTotalBeforeReceivedQty INT,    -- (ChewKP01)
   @bSkipToLoc          NVARCHAR(1), -- (CheWKP01)
   @bSkipToID           NVARCHAR(1), -- (CheWKP01)
   @bSkipQty            NVARCHAR(1), -- (CheWKP01)
   @bSkipSuccessMsg     NVARCHAR(1), -- (CheWKP01)
   @cReturnDefaultQTY   NVARCHAR( 10),
   @cDefaultPQTY        NVARCHAR( 5),
   @cDefaultMQTY        NVARCHAR( 5),
   @cDefaultUOM         NVARCHAR( 5),
   @cDecodeLabelNo      NVARCHAR( 20),
   @cZone               NVARCHAR( 10), -- (james03)
   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @cExtendedValidateSP NVARCHAR( 20),
   @cReturnZoneReq      NVARCHAR( 1),
   @cSkipLottable       NVARCHAR( 1),
   @cSkipLottable01     NVARCHAR( 1),
   @cSkipLottable02     NVARCHAR( 1),
   @cSkipLottable03     NVARCHAR( 1),
   @cSkipLottable04     NVARCHAR( 1),
   @cSQL                NVARCHAR( MAX),
   @cSQLParam           NVARCHAR( MAX),
   @cMultiSKUBarcode    NVARCHAR(1),   -- (james04)


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

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,

   @cReceiptKey      = V_ReceiptKey,
   @cPOKey           = V_POKey,

   @cLOC             = V_LOC,
   @cID              = V_ID,
   @cSKU             = V_SKU,
   @cSKUDescr        = V_SKUDescr,
   @cUOM             = V_UOM,
   @cQTY             = V_QTY,
   @cLottable01      = V_Lottable01,
   @cLottable02      = V_Lottable02,
   @cLottable03      = V_Lottable03,
   @dLottable04      = V_Lottable04,
   @dLottable05      = V_Lottable05,

   @cLottable06      = V_Lottable06,               --(CS01)
   @cLottable07      = V_Lottable07,               --(CS01)
   @cLottable08      = V_Lottable08,               --(CS01)
   @cLottable09      = V_Lottable09,               --(CS01)
   @cLottable10      = V_Lottable10,               --(CS01)
   @cLottable11      = V_Lottable11,               --(CS01)
   @cLottable12      = V_Lottable12,               --(CS01)
   @dLottable13      = V_Lottable13,               --(CS01)
   @dLottable14      = V_Lottable14,               --(CS01)
   @dLottable15      = V_Lottable15,               --(CS01)

   @nPQTY            = V_PQTY,
   @nMQTY            = V_MQTY,
   @nPrevScn         = V_FromScn, -- Previous Screen
   @nPrevStep        = V_FromStep, -- Previous Step   
      
   @nQTY               = V_Integer1,
   @nPrefUOM_Div       = V_Integer2, -- Pref UOM divider
   @nMstQTY            = V_Integer3, -- Remaining QTY in master unit
   @nActMQTY           = V_Integer4,
   @nActPQTY           = V_Integer5,
   @nActQty            = V_Integer6,
   @nBeforeReceivedQty = V_Integer7,   
      
   @cActPQTY         = V_String4,
   @cActMQTY         = V_String5,
   @cPrefUOM         = V_String6, -- Pref UOM
   @cPrefUOM_Desc    = V_String7, -- Pref UOM desc
   @cMstUOM_Desc     = V_String8, -- Master UOM desc
   @cSkipLottable01  = V_String14,
   @cSkipLottable02  = V_String15,
   @cSkipLottable03  = V_String16,
   @cSkipLottable04  = V_String17,
   @cLotFlag         = V_String20,
   @cReturnReason    = V_String21,
   @cOverRcpt        = V_String22,
   @cExpReason       = V_String23,
   @cIDFlag          = V_String24,
   @cIVAS            = V_String27,
   @cConditionCode   = V_String28,
   @cSubReason       = V_String29,
   @cLottable01Label = V_String30,
   @cLottable02Label = V_String31,
   @cLottable03Label = V_String32,
   @cLottable04Label = V_String33,
   @cLottable05Label = V_String34,
   @cDefaultLOC      = V_String35,
   @cPickFaceFlag    = V_String36,
   @cSUSR1           = V_String37,
   @cDefaultUOM      = V_String39,
   @cDecodeLabelNo   = V_String40,
   @cZone            = V_OrderKey,  -- (james03)

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

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_ASNPO      INT,  @nScn_ASNPO      INT,
   @nStep_SKU        INT,  @nScn_SKU        INT,
   @nStep_QTY        INT,  @nScn_QTY        INT,
   @nStep_Lottables  INT,  @nScn_Lottables  INT,
   @nStep_SubReason  INT,  @nScn_SubReason  INT,
   @nStep_ID         INT,  @nScn_ID         INT,
   @nStep_LOC        INT,  @nScn_LOC        INT,
   @nStep_MsgSuccess INT,  @nScn_MsgSuccess INT,
   @nStep_IDLOC      INT,  @nScn_IDLOC      INT,      -- (james01)
   @nPrev_Step       INT,  @nPrev_Scn       INT,      -- (james01)
   @nStep_Zone       INT,  @nScn_Zone       INT,      -- (james03)
   @nStep_MultiSKU   INT,  @nScn_MultiSKU   INT       -- (james04)

SELECT
   @nStep_ASNPO      = 1,  @nScn_ASNPO      = 1450,
   @nStep_SKU        = 2,  @nScn_SKU        = 1451,
   @nStep_QTY        = 3,  @nScn_QTY        = 1452,
   @nStep_Lottables  = 4,  @nScn_Lottables  = 1453,
   @nStep_SubReason  = 5,  @nScn_SubReason  = 1454,
   @nStep_ID         = 6,  @nScn_ID         = 1455,
   @nStep_LOC        = 7,  @nScn_LOC        = 1456,
   @nStep_MsgSuccess = 8,  @nScn_MsgSuccess = 1457,
   @nStep_IDLOC      = 9,  @nScn_IDLOC      = 1458,   -- (james01)
   @nPrev_Step       = 0,  @nPrev_Scn       = 0,      -- (james01)
   @nStep_Zone       = 10, @nScn_Zone       = 1459,   -- (james03)
   @nStep_MultiSKU   = 11, @nScn_MultiSKU   = 3570    -- (james04)

IF @nFunc = 552 OR @nFunc = 581
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start       -- Menu. Func = 552
   IF @nStep = 1  GOTO Step_ASNPO       -- Scn = 1450. ASN,PO
   IF @nStep = 2  GOTO Step_SKU         -- Scn = 1451. SKU
   IF @nStep = 3  GOTO Step_QTY         -- Scn = 1452. QTY, ConditionCode
   IF @nStep = 4  GOTO Step_Lottables   -- Scn = 1453. Lottable1-5
   IF @nStep = 5  GOTO Step_SubReason   -- Scn = 1454. Verify SerialNo, Subreason
   IF @nStep = 6  GOTO Step_ID          -- Scn = 1455. ID
   IF @nStep = 7  GOTO Step_LOC         -- Scn = 1456. LOC
   IF @nStep = 8  GOTO Step_MsgSuccess  -- Scn = 1457. Message. 'Receive Successful'
   IF @nStep = 9  GOTO Step_IDLOC       -- Scn = 1458. TO ID, TO LOC
   IF @nStep = 10 GOTO Step_Zone        -- Scn = 1459. Zone
   IF @nStep = 11 GOTO Step_MultiSKU    -- Scn = 3570. Multi SKU
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 860 / 861 / 862
********************************************************************************/
Step_Start:
BEGIN
   --get POKey as 'NOPO' if storerconfig has been setup for 'ReceivingPOKeyDefaultValue'
   SET @cPOKeyDefaultValue = ''
   SET @cPOKeyDefaultValue = rdt.RDTGetConfig( 0, 'ReceivingPOKeyDefaultValue', @cStorerKey)

   IF (@cPOKeyDefaultValue = '0' OR @cPOKeyDefaultValue IS NULL OR @cPOKeyDefaultValue = '')
      SET @cOutField02 = ''
   ELSE
      SET @cOutField02 = @cPOKeyDefaultValue

   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''

   -- (james03)
   SET @cReturnZoneReq = rdt.RDTGetConfig( @nFunc, 'ReturnZoneReq', @cStorerKey)

   SET @cSkipLottable01 = rdt.RDTGetConfig( @nFunc, 'SkipLottable01', @cStorerKey)
   SET @cSkipLottable02 = rdt.RDTGetConfig( @nFunc, 'SkipLottable02', @cStorerKey)
   SET @cSkipLottable03 = rdt.RDTGetConfig( @nFunc, 'SkipLottable03', @cStorerKey)
   SET @cSkipLottable04 = rdt.RDTGetConfig( @nFunc, 'SkipLottable04', @cStorerKey)

   -- Init var
   SET @nPQTY = 0
   SET @nActPQTY = 0
   /* Add initial var (ang01)*/
   SET @cReceiptKey      = ''
   SET @cPOKey           = ''
   SET @cLOC             = ''
   SET @cID              = ''
   SET @cSKU             = ''
   SET @cSKUDescr        = ''
   SET @cUOM             = ''
   SET @cQTY             = ''
   SET @cLottable01      = ''
   SET @cLottable02      = ''
   SET @cLottable03      = ''
   SET @dLottable04      = ''
   SET @dLottable05      = ''
   SET @cLottable06      = ''         --(CS01)
   SET @cLottable07      = ''         --(CS01)
   SET @cLottable08      = ''         --(CS01)
   SET @cLottable09      = ''         --(CS01)
   SET @cLottable10      = ''         --(CS01)
   SET @cLottable11      = ''         --(CS01)
   SET @cLottable12      = ''         --(CS01)
   SET @dLottable13      = ''         --(CS01)
   SET @dLottable14      = ''         --(CS01)
   SET @dLottable15      = ''         --(CS01)
   SET @nMQTY            = 0
   SET @nQTY             = 0
   SET @cActPQTY         = ''
   SET @cActMQTY         = ''
   SET @cPrefUOM         = ''
   SET @cPrefUOM_Desc    = ''
   SET @cMstUOM_Desc     = ''
   SET @nPrefUOM_Div     = 0
   SET @nMstQTY          = 0
   SET @nActMQTY         = 0
   SET @nActQty          = 0
   SET @cLotFlag         = ''
   SET @cReturnReason    = ''
   SET @cOverRcpt        = ''
   SET @cExpReason       = ''
   SET @cIDFlag          = ''
   SET @nPrevScn         = 0
   SET @nPrevStep        = 0
   SET @cIVAS            = ''
   SET @cConditionCode   = ''
   SET @cSubReason       = ''
   SET @cLottable01Label = ''
   SET @cLottable02Label = ''
   SET @cLottable03Label = ''
   SET @cLottable04Label = ''
   SET @cLottable05Label = ''
   SET @cLottable06Label = ''         --(CS01)
   SET @cLottable07Label = ''         --(CS01)
   SET @cLottable08Label = ''         --(CS01)
   SET @cLottable09Label = ''         --(CS01)
   SET @cLottable10Label = ''         --(CS01)
   SET @cLottable11Label = ''         --(CS01)
   SET @cLottable12Label = ''         --(CS01)
   SET @cLottable13Label = ''         --(CS01)
   SET @cLottable14Label = ''         --(CS01)
   SET @cLottable15Label = ''         --(CS01)
   SET @cDefaultLOC      = ''
   SET @cPickFaceFlag    = ''
   SET @cSUSR1           = ''
   SET @nBeforeReceivedQty = 0
   SET @cDefaultUOM        = ''
 /* Add in init var (ang01)*/

   -- Get prefer UOM
   SELECT @cPrefUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M (NOLOCK)
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

    -- (Vicky06) EventLog - Sign In Function
    EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep

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

   -- (james03)
   -- If zone required to scan, goto scan zone screen (screen 10)
   IF ISNULL( @cReturnZoneReq, '') = '1'
   BEGIN
      SET @cOutField01 = '' -- Zone

      -- Go to Zone screen
      SET @nScn = @nScn_Zone
      SET @nStep = @nStep_Zone
      GOTO Quit
   END

   -- Prepare PickSlipNo screen var
   SET @cOutField01 = '' -- PickSlipNo

   -- Go to PickSlipNo screen
   SET @nScn = @nScn_ASNPO
   SET @nStep = @nStep_ASNPO
   GOTO Quit

   Step_Start_Fail:
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/************************************************************************************
Scn = 1450. ASN, PO screen
   ASN    (field01)
   PO     (field02)
************************************************************************************/
Step_ASNPO:
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
      SET @cPOKey      = @cInField02

      -- Validate blank ASN & PO
      IF (@cReceiptKey = '' OR @cReceiptKey IS NULL) AND (@cPOKey = '' OR @cPOKey IS NULL)
      BEGIN
         SET @nErrNo = 63301
         SET @cErrMsg = rdt.rdtgetmessage( 63301, @cLangCode,'DSP') -- ASN or PO req
         GOTO ASNPO_Fail
      END

      IF @cReceiptKey = '' AND UPPER(@cPOKey) ='NOPO'
      BEGIN
         SET @nErrNo = 63337
         SET @cErrMsg = rdt.rdtgetmessage( 63337, @cLangCode, 'DSP') --ASN needed
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO ASNPO_Fail
      END

      -- Validate both ASN and PO
      IF @cReceiptKey <> '' AND @cPOKey <> '' AND  UPPER(@cPOKey) <> 'NOPO'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.RECEIPT R WITH (NOLOCK)
                        JOIN dbo.RECEIPTDETAIL RD WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
          WHERE R.ReceiptKey = @cReceiptkey
                        AND   RD.POKey = @cPOKey)
         BEGIN
        SET @nErrNo = 63302
            SET @cErrMsg = rdt.rdtgetmessage( 63302, @cLangCode, 'DSP') --Invalid ASN/PO
            SET @cOutField01 = ''
            SET @cOutField02 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Quit
         END
      END

      --When only PO keyed-in (ASN left as blank)
      IF @cPOKey <> '' AND UPPER(@cPOKey) <> 'NOPO' AND (@cReceiptkey  = '' OR @cReceiptkey IS NULL)
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
                        WHERE RD.POkey = @cPOKey )
         BEGIN
            SET @nErrNo = 63305
            SET @cErrMsg = rdt.rdtgetmessage( 63305, @cLangCode, 'DSP') --PO not exists
            SET @cOutField02 = @cPOKey
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- POKey
            GOTO Quit
         END

         DECLARE @nCountReceipt int
         SET @nCountReceipt = 0

         --Get ReceiptKey count
         SELECT @nCountReceipt = COUNT(DISTINCT Receiptkey)
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE POKey = @cPOKey
         GROUP BY POkey

         IF @nCountReceipt = 1
         BEGIN
            --Get single ReceiptKey
            SELECT @cReceiptKey = ReceiptKey
            FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
            WHERE POkey = @cPOKey
            GROUP BY ReceiptKey
         END
         ELSE IF @nCountReceipt > 1
         BEGIN
            SET @nErrNo = 63306
            SET @cErrMsg = rdt.rdtgetmessage( 63306, @cLangCode, 'DSP') --ASN needed
            SET @cOutField01 = '' --ReceiptKey
            SET @cOutField02 = @cPOKey
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
            GOTO Quit
         END
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK)
                     WHERE ReceiptKey = @cReceiptkey)
     BEGIN
         SET @nErrNo = 63303
         SET @cErrMsg = rdt.rdtgetmessage( 63303, @cLangCode, 'DSP') --ASN not exists
         SET @cOutField01 = '' --ReceiptKey
         SET @cOutField02 = @cPOKey
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Quit
      END

      DECLARE @cChkStorerKey  NVARCHAR( 15)

      --check diff facility
      IF NOT EXISTS (SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK)
                     WHERE Receiptkey = @cReceiptkey
                     AND   Facility = @cFacility)
      BEGIN
         SET @nErrNo = 63307
         SET @cErrMsg = rdt.rdtgetmessage( 63307, @cLangCode, 'DSP') --Diff facility
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO ASNPO_Fail
      END

      -- Get storerkey
      SELECT @cChkStorerKey = StorerKey
      FROM dbo.RECEIPT (NOLOCK)
      WHERE ReceiptKey = @cReceiptkey

      -- Validate storerkey
      IF @cChkStorerKey IS NULL OR @cChkStorerKey = '' OR @cChkStorerKey <> @cStorerKey
      BEGIN
         SET @nErrNo = 63308
         SET @cErrMsg = rdt.rdtgetmessage( 63308, @cLangCode,'DSP') -- Diff storer
         GOTO ASNPO_Fail
      END

      --check for ASN closed by receipt.status
      IF EXISTS (SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK)
                 WHERE Receiptkey = @cReceiptkey
                 AND   Status = '9')
      BEGIN
         SET @nErrNo = 63309
         SET @cErrMsg = rdt.rdtgetmessage( 63309, @cLangCode, 'DSP') --ASN closed
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO ASNPO_Fail
      END

      --check for ASN closed by receipt.ASNStatus
      IF EXISTS (SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK)
                 WHERE Receiptkey = @cReceiptkey
                 AND ASNStatus = '9' )
      BEGIN
         SET @nErrNo = 63310
         SET @cErrMsg = rdt.rdtgetmessage( 63310, @cLangCode, 'DSP') --ASN closed
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO ASNPO_Fail
      END

      --check for ASN cancelled
      IF EXISTS ( SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK)
                  WHERE Receiptkey = @cReceiptkey
                  AND ASNStatus = 'CANC')
      BEGIN
         SET @nErrNo = 63336
         SET @cErrMsg = rdt.rdtgetmessage( 63336, @cLangCode, 'DSP') --ASN cancelled
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO ASNPO_Fail
      END

      --check for TradeReturnASN
      IF EXISTS (SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK)
                 WHERE Receiptkey = @cReceiptkey
                 AND   DocType <> 'R')
      BEGIN
         SET @nErrNo = 63311
         SET @cErrMsg = rdt.rdtgetmessage( 63311, @cLangCode, 'DSP') -- Not Return ASN
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO ASNPO_Fail
      END

      --When only ASN keyed-in (PO left as blank):
      IF @cReceiptKey <> ''  AND (@cPOKey = '' OR UPPER(@cPOKey) = 'NOPO')
      BEGIN

         DECLARE @nCountPOKey int
         SET @nCountPOKey = 0

         --Get pokey count
         SELECT @nCountPOKey = COUNT(DISTINCT POKey)
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptkey
         GROUP BY Receiptkey

         IF @nCountPOKey = 1
         BEGIN
            IF UPPER(@cPOKey) <> 'NOPO'
            BEGIN
               --Get single pokey
               SELECT DISTINCT @cPOKey = POKey
               FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptkey
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
                  SET @nErrNo = 63304
                  SET @cErrMsg = rdt.rdtgetmessage( 63304, @cLangCode, 'DSP') --PO needed
                  SET @cOutField01 = @cReceiptKey
                  SET @cOutField02 = '' --POKey
                  EXEC rdt.rdtSetFocusField @nMobile, 2 -- POKey
                  GOTO Quit
               END
            END
         END

--         ELSE IF @nCountPOKey > 2
--         BEGIN
--            IF UPPER(@cPOKey) <> 'NOPO'
--            BEGIN
--               --multiple PO
--               SET @nErrNo = 63304
--       SET @cErrMsg = rdt.rdtgetmessage( 63304, @cLangCode, 'DSP') --PO needed
--               SET @cOutField01 = @cReceiptKey
--               SET @cOutField02 = '' --POKey
--       EXEC rdt.rdtSetFocusField @nMobile, 2 -- POKey
--       GOTO Quit
--            END
--         END
      END

      SET @nCTotalBeforeReceivedQty = 0
      SET @nCTotalUQtyExpected = 0

      -- Calculate QTY by preferred UOM  -- (ChewKP01)
      SELECT  @nCTotalUQtyExpected = SUM(QtyExpected), @nCTotalBeforeReceivedQty = SUM(BeforeReceivedQty)  FROM dbo.ReceiptDetail (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   POKey = CASE WHEN UPPER('@cPokey') = 'NOPO' THEN '' ELSE @cPokey END

      -- Get Default UOM -- (ChewKP01)
      SELECT @cDefaultUOM = Short FROM dbo.CodeLkup (NOLOCK)
      WHERE LISTNAME = 'DMASTERUOM' AND CODE = @cStorerKey



      IF @nFunc = 552
      BEGIN
         -- Prepare SKU screen var
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @cPOKey
         SET @cOutField03 = '' -- SKU
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = @nCTotalUQtyExpected      -- (ChewKP01)
         SET @cOutField07 = @cDefaultUOM              -- (ChewKP01)
         SET @cOutField08 = @nCTotalBeforeReceivedQty -- (ChewKP01)
         SET @cOutField09 = @cDefaultUOM              -- (ChewKP01)

         -- Go to SKU screen
         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU
      END
      ELSE
      BEGIN
          -- Prep LOC screen var
         SET @cDefaultLOC = ''

         SELECT @cDefaultLOC = RTRIM(sValue) FROM RDT.STORERCONFIG WITH (NOLOCK)
         WHERE Configkey = 'ReturnDefaultToLOC'
         AND   Storerkey = @cStorerkey

         SET @cPickFaceFlag = 'N'

         IF @cDefaultLOC = 'PICKFACE'
         BEGIN
            SET @cDefaultLOC = ''
            SELECT @cDefaultLOC = IsNULL(LOC, '')
            FROM dbo.SKUxLOC WITH (NOLOCK)
            WHERE SKU = @cSKU
            AND   Storerkey = @cStorerkey
            AND   (LocationType = 'PICK' OR LocationType = 'CASE')

            SET @cPickFaceFlag = 'Y'

            IF @cDefaultLOC = ''
            BEGIN
               SET @nErrNo = 63332
               SET @cErrMsg = rdt.rdtgetmessage(63332, @cLangCode, 'DSP') -- No Pick Face
            END
         END

         SET @cOutField01 = ''
         SET @cOutField02 = CASE WHEN ISNULL(@cDefaultLOC, '') = '' THEN '' ELSE @cDefaultLOC END


         -- Get Config
         SET @bSkipToLoc = rdt.RDTGetConfig( @nFunc, 'SkipToLoc', @cStorerKey) -- (ChewKP01)

         -- Get Config
         SET @bSkipToID = rdt.RDTGetConfig( @nFunc, 'SkipToID', @cStorerKey) -- (ChewKP01)



         -- IF SkipToLoc , SkipToID , and DefaultLoc had values Skip ToIDLOC Screen -- (ChewKP01)
         IF @bSkipToLoc = '1' AND @bSkipToID = '1' AND @cDefaultLOC <> ''
         BEGIN
             -- Prepare SKU screen var
            SET @cOutField01 = @cReceiptKey
            SET @cOutField02 = @cPOKey
            SET @cOutField03 = '' -- SKU
            SET @cOutField04 = ''
            SET @cOutField05 = ''
            SET @cOutField06 = @nCTotalUQtyExpected      -- (ChewKP01)
            SET @cOutField07 = @cDefaultUOM              -- (ChewKP01)
            SET @cOutField08 = @nCTotalBeforeReceivedQty -- (ChewKP01)
            SET @cOutField09 = @cDefaultUOM              -- (ChewKP01)

             -- Remember current scn & step no
            SET @nPrevScn = @nScn_SKU
            SET @nPrevStep = @nStep_SKU

            -- Go to SKU screen
            SET @nScn = @nScn_SKU
            SET @nStep = @nStep_SKU
         END
         ELSE
         BEGIN
             -- Remember current scn & step no
            SET @nPrevScn = @nScn_ASNPO
            SET @nPrevStep = @nStep_ASNPO



            -- Go to SKU screen
            SET @nScn = @nScn_IDLOC
            SET @nStep = @nStep_IDLOC
         END
      END
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
       @cStorerKey  = @cStorerkey,
       @nStep       = @nStep

      -- (james03)
      -- If zone required to scan, goto scan zone screen (screen 10)
      SET @cReturnZoneReq = rdt.RDTGetConfig( @nFunc, 'ReturnZoneReq', @cStorerKey)
      IF ISNULL( @cReturnZoneReq, '') = '1'
      BEGIN
         SET @cOutField01 = '' -- Zone

         -- Go to Zone screen
         SET @nScn = @nScn_Zone
         SET @nStep = @nStep_Zone
         GOTO Quit
      END

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
      SET @cOutField02 = '' -- PO

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
   END
   GOTO Quit

   ASNPO_Fail:
   BEGIN
      SET @cReceiptKey = ''
      SET @cOutField01 = '' -- ASN
      SET @cOutField02 = @cPOKey -- PO
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
   END
END
GOTO Quit


/***********************************************************************************
Scn = 1451. SKU screen
   ASN     (field01)
   PO      (field02)
   SKU     (field03, input)
   SKUDesc (field04, field05)
   ASN QTY, EA (field06 )
   RCV QTY, EA (field08 )
***********************************************************************************/
Step_SKU:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField03 -- SKU

      -- Validate blank
      IF @cSKU = '' OR @cSKU IS NULL
      BEGIN
         SET @nErrNo = 63312
         SET @cErrMsg = rdt.rdtgetmessage( 63312, @cLangCode, 'DSP') --SKU needed
         GOTO SKU_Fail
      END

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'SKU', @cSKU) = 0
      BEGIN
         SET @nErrNo = 63343
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO SKU_Fail
      END

      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @dLottable04 = 0
      SET @dLottable05 = 0

      SET @cLottable06   = ''           --(CS01)
      SET @cLottable07   = ''           --(CS01)
      SET @cLottable08   = ''           --(CS01)
      SET @cLottable09   = ''           --(CS01)
      SET @cLottable10   = ''           --(CS01)
      SET @cLottable11   = ''           --(CS01)
      SET @cLottable12   = ''           --(CS01)
      SET @dLottable13   = 0            --(CS01)
      SET @dLottable14   = 0            --(CS01)
      SET @dLottable15   = 0            --(CS01)

      -- Label decoding
      IF @cDecodeLabelNo <> ''
      BEGIN
         DECLARE
            @c_oFieled01 NVARCHAR(60), @c_oFieled02 NVARCHAR(20),
            @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
            @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
            @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
            @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)

         -- Retain value
         SET @c_oFieled01 = @cSKU
         SET @c_oFieled05 = @cQTY
         SET @c_oFieled07 = @cLottable01
         SET @c_oFieled08 = @cLottable02
         SET @c_oFieled09 = @cLottable03
         SET @c_oFieled10 = @dLottable04

         EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @cSKU
            ,@c_Storerkey  = @cStorerKey
            ,@c_ReceiptKey = ''
            ,@c_POKey      = ''
            ,@c_LangCode   = @cLangCode
            ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
            ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
            ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
            ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
            ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
            ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#
            ,@c_oFieled07  = @c_oFieled07 OUTPUT   -- Lottable01
            ,@c_oFieled08  = @c_oFieled08 OUTPUT   -- Lottable02
            ,@c_oFieled09  = @c_oFieled09 OUTPUT   -- Lottable03
            ,@c_oFieled10  = @c_oFieled10 OUTPUT   -- Lottable04
            ,@b_Success    = @b_Success   OUTPUT
            ,@n_ErrNo      = @nErrNo      OUTPUT
            ,@c_ErrMsg     = @cErrMsg     OUTPUT

         IF @cErrMsg <> ''
            GOTO SKU_Fail

         SET @cSKU = @c_oFieled01
         SET @cQTY = @c_oFieled05
         SET @cLottable01 = @c_oFieled07
         SET @cLottable02 = @c_oFieled08
         SET @cLottable03 = @c_oFieled09
         SET @dLottable04 = @c_oFieled10
      END
      /*
      -- Get SKU/UPC
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

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 63313
         SET @cErrMsg = rdt.rdtgetmessage( 63313, @cLangCode, 'DSP') --Invalid SKU
         GOTO SKU_Fail
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 63314
         SET @cErrMsg = rdt.rdtgetmessage( 63314 , @cLangCode, 'DSP') --MultiSKUBarcod
         GOTO SKU_Fail
      END
      */
      -- Get SKU/UPC
      SET @nSKUCnt = 0
      EXEC RDT.rdt_GETSKUCNT
          @cStorerKey  = @cStorerkey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT
      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 63313
         SET @cErrMsg = rdt.rdtgetmessage( 63313, @cLangCode, 'DSP') --Invalid SKU
         GOTO SKU_Fail
      END
      IF @nSKUCnt = 1
         --SET @cSKU = @cSKUCode
         EXEC [RDT].[rdt_GETSKU]
             @cStorerKey  = @cStorerkey
            ,@cSKU        = @cSKU          OUTPUT
            ,@bSuccess    = @b_Success     OUTPUT
            ,@nErr        = @nErrNo        OUTPUT
            ,@cErrMsg     = @cErrMsg       OUTPUT
      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerkey)
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
               @cErrMsg  OUTPUT--,
               --'ASN',    -- DocType
               --@cReceiptKey
            IF @nErrNo = 0 -- Populate multi SKU screen
            BEGIN
               -- Go to Multi SKU screen
               -- Remember current scn & step no
               SET @nPrevScn = @nScn_SKU
               SET @nPrevStep = @nStep_SKU
               SET @nScn = 3570
               SET @nStep = @nStep_MultiSKU
               GOTO Quit
            END
            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
               SET @nErrNo = 0
         END
         ELSE
         BEGIN
            SET @nErrNo = 63314
            SET @cErrMsg = rdt.rdtgetmessage( 63314 , @cLangCode, 'DSP') --MultiSKUBarcod
            GOTO SKU_Fail
         END
      END

      SET @cLottable01Label = ''
      SET @cLottable02Label = ''
      SET @cLottable03Label = ''
      SET @cLottable04Label = ''
      SET @cLottable05Label = ''

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

      --get IVAS
      SET @cIVAS = ''
      SELECT @cIVAS = ISNULL(LEFT(RTRIM(CodeLkUp.Description),20),'')
      FROM dbo.CodeLkUp CodeLkUp WITH (NOLOCK)
      JOIN dbo.SKU Sku WITH (NOLOCK) ON SKU.IVAS = CodeLkUp.Code
         AND SKU.SKU = @cSku
         AND SKU.StorerKey = @cStorerKey
         AND CodeLkUp.ListName = 'IVAS'   -- (james04)

    SELECT @cSKUDescr        = RTRIM(SKU.DESCR),
     --@cIVAS            = IsNULL(RTRIM(SKU.IVAS), ''),
             @cSUSR1           = IsNULL(RTRIM(SKU.SUSR1), ''),
             @cLottable01Label = IsNULL(RTRIM(SKU.Lottable01Label), ''),
     @cLottable02Label = IsNULL(RTRIM(SKU.Lottable02Label), ''),
     @cLottable03Label = IsNULL(RTRIM(SKU.Lottable03Label), ''),
     @cLottable04Label = IsNULL(RTRIM(SKU.Lottable04Label), ''),
     @cLottable05Label = IsNULL(RTRIM(SKU.Lottable05Label), ''),
     @cMstUOM_Desc = PACK.PackUOM3,
     @cPrefUOM_Desc =
      CASE @cPrefUOM
       WHEN '2' THEN PACK.PackUOM1 -- Case
       WHEN '3' THEN PACK.PackUOM2 -- Inner pack
       WHEN '6' THEN PACK.PackUOM3 -- Master unit
       WHEN '1' THEN PACK.PackUOM4 -- Pallet
       WHEN '4' THEN PACK.PackUOM8 -- Other unit 1
       WHEN '5' THEN PACK.PackUOM9 -- Other unit 2
     END,
     @nPrefUOM_Div = CAST( IsNULL(
     CASE @cPrefUOM
       WHEN '2' THEN PACK.CaseCNT
       WHEN '3' THEN PACK.InnerPack
       WHEN '6' THEN PACK.QTY
       WHEN '1' THEN PACK.Pallet
       WHEN '4' THEN PACK.OtherUnit1
       WHEN '5' THEN PACK.OtherUnit2
     END, 1) AS INT)
      FROM dbo.SKU SKU WITH (NOLOCK)
      INNER JOIN dbo.PACK PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
      AND   SKU.SKU = @cSKU



      SET @nQty = 0
      SET @nBeforeReceivedQty = 0

      SELECT @nQTY = SUM(QtyExpected),
             @nBeforeReceivedQty = SUM(BeforeReceivedQty)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptkey
      AND   POKey = CASE WHEN UPPER(@cPOKey) = 'NOPO' THEN '' ELSE @cPOKey END
      AND   SKU = @cSKU
      GROUP BY SKU

      SELECT @cSValue= SValue
      FROM rdt.STORERCONFIG WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ConfigKey = 'ReturnCheckSKUInASN'

      IF @cSValue = '1'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                        WHERE ReceiptKey = @cReceiptKey
                        AND   Storerkey = @cStorerKey
                        AND   SKU = @cSKU )
         BEGIN
            SET @nErrNo = 63315
            SET @cErrMsg = rdt.rdtgetmessage( 63315, @cLangCode, 'DSP') --SKU not in ASN
            GOTO SKUChk_Fail
         END
      END

     -- Convert to prefer UOM QTY
     IF @cPrefUOM = '6' OR -- When preferred UOM = master unit
        @nPrefUOM_Div = 0  -- UOM not setup
     BEGIN
        SET @cPrefUOM_Desc = ''
     END

     -- Get storer config ReturnDefaultQTY

     SET @cReturnDefaultQTY = rdt.RDTGetConfig( 0, 'ReturnDefaultQTY', @cStorerKey)

     -- Put default QTY
     SET @cDefaultPQTY = ''
     SET @cDefaultMQTY = ''
     IF rdt.rdtIsValidQTY( @cReturnDefaultQTY, 1) = 1 -- Check for zero QTY
     BEGIN
        -- Convert to prefer UOM QTY
        IF @cPrefUOM_Desc = ''
           SET @cDefaultMQTY = @cReturnDefaultQTY
        ELSE
        BEGIN
           -- Calc QTY in preferred UOM
           SET @cDefaultPQTY = CAST( @cReturnDefaultQTY AS INT) / @nPrefUOM_Div

           -- Calc the remaining in master unit
           SET @cDefaultMQTY = CAST( @cReturnDefaultQTY AS INT) % @nPrefUOM_Div
        END
     END

     -- Prep QTY screen var
     SET @cOutField01 = @cSKU
     SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)
     SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
     SET @cOutField04 = @cIVAS
     IF @cPrefUOM_Desc = ''
     BEGIN
        SET @cOutField05 = '' -- @nPrefUOM_Div
        SET @cOutField06 = '' -- @cPrefUOM_Desc
        SET @cOutField08 = '' -- @cPrefQTY
        -- Disable pref QTY field
        SET @cFieldAttr08 = 'O' -- (Vicky02)
        SET @cInField08 = '' -- (james02)
     END
     ELSE
     BEGIN
        SET @cOutField05 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
        SET @cOutField06 = @cPrefUOM_Desc
        SET @cOutField08 = @cDefaultPQTY
     END
     SET @cOutField07 = @cMstUOM_Desc
     SET @cOutField09 = @cDefaultMQTY
     SET @cOutField10 = '' -- ConditionCode
     SET @cOutField11 = '' -- ExtendedInfo

     -- Get Config
     SET @bSkipQty = rdt.RDTGetConfig( @nFunc, 'SkipQty', @cStorerKey) -- (ChewKP01)
     --SET @n_ReturnDefaultQTY = rdt.RDTGetConfig( @nFunc, 'ReturnDefaultQTY', @cStorerKey) -- (ChewKP01)

     IF @bSkipQty = '1' AND @cReturnDefaultQTY > 0 -- (ChewKP01)
     BEGIN
        --SET @nInputKey = 1

        -- Go to SKU screen
      --SET @nScn = @nScn_QTY
      --SET @nStep = Step_SQTY
        GOTO Step_SKIP_QTY
     END
     ELSE
     BEGIN
      -- Go to SKU screen
      SET @nScn = @nScn_QTY
      SET @nStep = @nStep_QTY
     END

      SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
      IF @cExtendedInfoSP = '0'
         SET @cExtendedInfoSP = ''

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cZone, @cReceiptKey, @cPOKey, @cSKU, @nQTY,
                 @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cConditionCode, @cSubReason,
                 @cToLOC, @cToID, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR( 3), ' +
               '@nStep           INT, ' +
               '@nInputKey       INT, ' +
               '@cZone           NVARCHAR( 10), ' +
               '@cReceiptKey     NVARCHAR( 10), ' +
               '@cPOKey          NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT, ' +
               '@cLottable01     NVARCHAR( 18), ' +
               '@cLottable02     NVARCHAR( 18), ' +
               '@cLottable03     NVARCHAR( 18), ' +
               '@dLottable04     DATETIME, ' +
               '@cConditionCode  NVARCHAR( 10), ' +
               '@cSubReason      NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@cToID           NVARCHAR( 18), ' +
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cZone, @cReceiptKey, @cPOKey, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cConditionCode, @cSubReason,
               @cLOC, @cID, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nStep = @nStep_QTY
               SET @cOutField11 = @cExtendedInfo
         END
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      IF @nFunc = 552
      BEGIN
         -- Prepare prev screen var
         SET @cReceiptKey = ''
         SET @cOutField01 = '' -- ReceiptKey
         SET @cOutField02 = '' --@cPOKey -- (ChewKP02)

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

         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey

         -- Go to prev screen
         SET @nScn = @nScn_ASNPO
         SET @nStep = @nStep_ASNPO
      END
      ELSE
      IF @nFunc = 581
      BEGIN
          -- Prep LOC screen var
         SET @cDefaultLOC = ''

         SELECT @cDefaultLOC = RTRIM(sValue) FROM RDT.STORERCONFIG WITH (NOLOCK)
         WHERE Configkey = 'ReturnDefaultToLOC'
         AND   Storerkey = @cStorerkey

         SET @cPickFaceFlag = 'N'

         IF @cDefaultLOC = 'PICKFACE'
         BEGIN
            SET @cDefaultLOC = ''
            SELECT @cDefaultLOC = IsNULL(LOC, '')
            FROM dbo.SKUxLOC WITH (NOLOCK)
            WHERE SKU = @cSKU
            AND   Storerkey = @cStorerkey
            AND   (LocationType = 'PICK' OR LocationType = 'CASE')

            SET @cPickFaceFlag = 'Y'

            IF @cDefaultLOC = ''
            BEGIN
               SET @nErrNo = 63332
               SET @cErrMsg = rdt.rdtgetmessage(63332, @cLangCode, 'DSP') -- No Pick Face
            END
         END

         SET @cOutField01 = ''
         SET @cOutField02 = CASE WHEN ISNULL(@cDefaultLOC, '') = '' THEN '' ELSE @cDefaultLOC END

         -- Remember current scn & step no
         SET @nPrevScn = @nScn_ASNPO
         SET @nPrevStep = @nStep_ASNPO


         -- Get Config
         SET @bSkipToLoc = rdt.RDTGetConfig( @nFunc, 'SkipToLoc', @cStorerKey) -- (ChewKP01)

         -- Get Config
         SET @bSkipToID = rdt.RDTGetConfig( @nFunc, 'SkipToID', @cStorerKey) -- (ChewKP01)

         -- IF SkipToLoc , SkipToID , and DefaultLoc had values Skip ToIDLOC Screen -- (ChewKP01)
         IF @bSkipToLoc = '1' AND @bSkipToID = '1' AND @cDefaultLOC <> ''
         BEGIN
            -- Prepare prev screen var
            SET @cReceiptKey = ''
            SET @cOutField01 = '' -- ReceiptKey
            SET @cOutField02 = '' --@cPOKey (ChewKP02)

            -- Go to prev screen
            SET @nScn = @nScn_ASNPO
            SET @nStep = @nStep_ASNPO

         END
         ELSE
         BEGIN
            -- Go to SKU screen
            SET @nScn = @nScn_IDLOC
            SET @nStep = @nStep_IDLOC
         END
      END
   END
   GOTO Quit

   SKU_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cOutField03 = '' -- SKU
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
      GOTO Quit
   END

   SKUChk_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr,  1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
      GOTO Quit
   END
END
GOTO Quit


/********************************************************************************
Scn = 1452. QTY screen
   SKU       (field01)
   DESCR     (field02, field03)
   IVAS      (field04)
   UOM Factor(field05)
   PUOM MUOM (field06, field07)
   QTY RTN   (field08, field09)
   Condition (field10, input)
********************************************************************************/
Step_QTY:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cActPQTY = IsNULL( @cInField08, '')
      SET @cActMQTY = IsNULL( @cInField09, '')
      SET @cConditionCode = IsNULL( @cInField10, '')

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

      -- Validate ActPQTY
      IF @cPrefUOM_Desc <> ''
      BEGIN
       IF @cActPQTY = '' SET @cActPQTY = '0' -- Blank taken as zero
       IF RDT.rdtIsValidQTY( @cActPQTY, 0) = 0
       BEGIN
          SET @nErrNo = 63316
          SET @cErrMsg = rdt.rdtgetmessage( 63316, @cLangCode, 'DSP') --Invalid QTY
          EXEC rdt.rdtSetFocusField @nMobile, 08 -- PQTY
          GOTO QTY_Fail
       END
      END

      -- Validate ActMQTY
      IF @cPrefUOM_Desc = ''
      BEGIN
       IF @cActMQTY  = '' SET @cActMQTY  = '0' -- Blank taken as zero
       IF RDT.rdtIsValidQTY( @cActMQTY, 1) = 0
       BEGIN
          SET @nErrNo = 63317
          SET @cErrMsg = rdt.rdtgetmessage( 63317, @cLangCode, 'DSP') --Invalid QTY
          EXEC rdt.rdtSetFocusField @nMobile, 09 -- MQTY
          GOTO QTY_Fail
       END
      END
      ELSE
      BEGIN
       IF @cActMQTY  = '' SET @cActMQTY  = '0' -- Blank taken as zero
       IF RDT.rdtIsValidQTY( @cActMQTY, 0) = 0
       BEGIN
          SET @nErrNo = 63317
          SET @cErrMsg = rdt.rdtgetmessage( 63317, @cLangCode, 'DSP') --Invalid QTY
          EXEC rdt.rdtSetFocusField @nMobile, 09 -- MQTY
          GOTO QTY_Fail
       END
      END

      -- Calc total QTY in master UOM
      SET @nActPQTY = CAST( @cActPQTY AS INT)
      SET @nActMQTY = CAST( @cActMQTY AS INT)

      SET @nActQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @nActPQTY, @cPrefUOM, 6) -- Convert to QTY in master UOM
      SET @nActQTY = @nActQTY + @nActMQTY

      -- Validate QTY
      IF @nActQTY = 0
      BEGIN
         SET @nErrNo = 63318
         SET @cErrMsg = rdt.rdtgetmessage( 63318, @cLangCode, 'DSP') --QTY needed
         GOTO QTY_Fail
      END

      IF @cConditionCode <> ''
      BEGIN
         IF NOT EXISTS(SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                 WHERE Listname = 'ASNREASON'
                 AND   Code =  @cConditionCode)
         BEGIN
           SET @nErrNo = 63319
           SET @cErrMsg = rdt.rdtgetmessage( 63319, @cLangCode, 'DSP') --Bad Cond Code
                     EXEC rdt.rdtSetFocusField @nMobile, 10 -- CondCode
           GOTO QTYCD_Fail
         END
     END

     -- If any one of the Lottablelabels being set, will got to Screen_Lottables
     SET @cLotFlag = 'N'

     IF (IsNULL(@cLottable01Label, '') <> '') OR (IsNULL(@cLottable02Label, '') <> '') OR (IsNULL(@cLottable03Label, '') <> '') OR
         (IsNULL(@cLottable04Label, '') <> '') OR (IsNULL(@cLottable05Label, '') <> '')
     BEGIN
         --prepare next screen variable
         SET @cOutField01 = '' --lottable01
         SET @cOutField02 = '' --lottable02
         SET @cOutField03 = '' --lottable03
         SET @cOutField04 = '' --lottable04
         SET @cOutField05 = '' --lottable05
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cInField08 = ''
/*
         SET @cLottable01 = ''
         SET @cLottable02 = ''
         SET @cLottable03 = ''
         SET @dLottable04 = 0
         SET @dLottable05 = 0
*/
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

         --initiate @nCounter = 1
         SET @nCount = 1

         --retrieve value for pre lottable01 - 05
         WHILE @nCount <=5 --break the loop when @nCount >5
         BEGIN
             IF @nCount = 1
             BEGIN
                SET @cListName = 'Lottable01'
                SET @cLottableLabel = @cLottable01Label
             END
             ELSE
             IF @nCount = 2
             BEGIN
                SET @cListName = 'Lottable02'
                SET @cLottableLabel = @cLottable02Label
             END
             ELSE
             IF @nCount = 3
             BEGIN
                SET @cListName = 'Lottable03'
                SET @cLottableLabel = @cLottable03Label
             END
             ELSE
             IF @nCount = 4
             BEGIN
                SET @cListName = 'Lottable04'
                  SET @cLottableLabel = @cLottable04Label
             END
             ELSE
             IF @nCount = 5
             BEGIN
                SET @cListName = 'Lottable05'
                SET @cLottableLabel = @cLottable05Label
             END

             --get short, store procedure and lottablelable value for each lottable
             SET @cShort = ''
             SET @cStoredProd = ''

             SELECT TOP 1
               @cShort      = CASE WHEN C.UDF04 <> '' THEN 'PRE'   ELSE ISNULL(RTRIM(C.Short),'') END,
               @cStoredProd = CASE WHEN C.UDF04 <> '' THEN C.UDF04 ELSE IsNULL(RTRIM(C.Long), '') END
             FROM dbo.CodeLkUp C WITH (NOLOCK)
             JOIN RDT.StorerConfig S WITH (NOLOCK) ON (C.ListName = S.ConfigKey AND C.Code = S.SValue)
             WHERE C.ListName = @cListName
             AND   C.Code = @cLottableLabel
             AND  (C.StorerKey = @cStorerkey OR C.StorerKey = '')
             ORDER By C.StorerKey DESC

             IF @cShort = 'PRE' AND @cStoredProd <> ''
             BEGIN
                  EXEC dbo.ispLottableRule_Wrapper
                     @c_SPName            = @cStoredProd,
                     @c_ListName          = @cListName,
                     @c_Storerkey         = @cStorerkey,
                     @c_Sku               = @cSKU,   -- (ChewKP02)
                     @c_LottableLabel     = @cLottableLabel,
                     @c_Lottable01Value   = '',
                     @c_Lottable02Value   = '',
                     @c_Lottable03Value   = '',
                     @dt_Lottable04Value  = '',
                     @dt_Lottable05Value  = '',
                     @c_Lottable06Value   = '',                       --(CS01)
                     @c_Lottable07Value   = '',                       --(CS01)
                     @c_Lottable08Value   = '',                       --(CS01)
                     @c_Lottable09Value   = '',                       --(CS01)
                     @c_Lottable10Value   = '',                       --(CS01)
                     @c_Lottable11Value   = '',                       --(CS01)
                     @c_Lottable12Value   = '',                       --(CS01)
                     @dt_Lottable13Value  = '',                       --(CS01)
                     @dt_Lottable14Value  = '',                       --(CS01)
                     @dt_Lottable15Value  = '',                       --(CS01)
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
                     @c_Sourcekey         = @cReceiptKey, -- SOS#81879
                     @c_Sourcetype        = 'RECEIPTRET'  -- SOS#81879


                  IF ISNULL(@cErrMsg, '') <> ''   -- SOS#81879
                  BEGIN
                               SET @cErrMsg = @cErrMsg   -- SOS#81879
                   GOTO QTYCD_Fail
                   BREAK
                  END

                  SET @cLottable01 = IsNULL( @cLottable01, '')
                  SET @cLottable02 = IsNULL( @cLottable02, '')
                  SET @cLottable03 = IsNULL( @cLottable03, '')
                  SET @dLottable04 = IsNULL( @dLottable04, 0)
                  SET @dLottable05 = IsNULL( @dLottable05, 0)

            --
            --      SET @cOutField02 = @cLottable01
            --      SET @cOutField04 = @cLottable02
            --      SET @cOutField06 = @cLottable03
            --      SET @cOutField08 = CASE WHEN @dLottable04 <> 0 THEN rdt.rdtFormatDate( @dLottable04) END
            --      SET @cOutField10 = CASE WHEN @dLottable05 <> 0 THEN rdt.rdtFormatDate( @dLottable05) END
             END

            -- increase counter by 1
            SET @nCount = @nCount + 1
         END -- nCount

         -- Skip lottable
         IF @cSkipLottable01 = '1' SELECT @cFieldAttr02 = 'O', @cInField01 = '', @cLottable01 = ''
         IF @cSkipLottable02 = '1' SELECT @cFieldAttr04 = 'O', @cInField02 = '', @cLottable02 = ''
         IF @cSkipLottable03 = '1' SELECT @cFieldAttr06 = 'O', @cInField03 = '', @cLottable03 = ''
         IF @cSkipLottable04 = '1' SELECT @cFieldAttr08 = 'O', @cInField04 = '', @dLottable04 = 0
         -- Initiate labels
--        SELECT
--           @cOutField01 = 'Lottable01:',
--           @cOutField03 = 'Lottable02:',
--           @cOutField05 = 'Lottable03:',
--     @cOutField07 = 'Lottable04:',
--           @cOutField09 = 'Lottable05:'

        -- Populate labels and lottables
        IF @cLottable01Label = '' OR @cLottable01Label IS NULL
        BEGIN
           SELECT @cOutField01 = 'Lottable01:'
           SELECT @cInField02 = ''
           SET @cFieldAttr02 = 'O' -- (Vicky02)
        END
        ELSE
        BEGIN
           SELECT @cOutField01 = @cLottable01Label
        END
        SET @cOutField02 = @cLottable01
        SET @cInField02 = @cOutField02

        IF @cLottable02Label = '' OR @cLottable02Label IS NULL
        BEGIN
           SELECT @cOutField03 = 'Lottable02:'
           SELECT @cInField04 = ''
           SET @cFieldAttr04 = 'O' -- (Vicky02)
        END
        ELSE
        BEGIN
           SELECT @cOutField03 = @cLottable02Label
        END
        SET @cOutField04 = @cLottable02
        SET @cInField04 = @cOutField04

        IF @cLottable03Label = '' OR @cLottable03Label IS NULL
        BEGIN
           SELECT @cOutField05 = 'Lottable03:'
           SELECT @cInField06 = ''
           SET @cFieldAttr06 = 'O' -- (Vicky02)
        END
        ELSE
        BEGIN
           SELECT @cOutField05 = @cLottable03Label
        END
        SET @cOutField06 = @cLottable03
        SET @cInField06 = @cOutField06

        IF @cLottable04Label = '' OR @cLottable04Label IS NULL
        BEGIN
           SELECT @cOutField07 = 'Lottable04:'
           SELECT @cInField08 = ''
           SET @cFieldAttr08 = 'O' -- (Vicky02)
        END
        ELSE
        BEGIN
           SELECT  @cOutField07 = @cLottable04Label
        END
        IF rdt.rdtIsValidDate( @dLottable04) = 1
        BEGIN
           SET @cOutField08 = RDT.RDTFormatDate( @dLottable04)
           SET @cInField08 = @cOutField08
        END
         EXEC rdt.rdtSetFocusField @nMobile, 1   --set focus to 1st field

         SET @cLotFlag = 'Y'
         SET @nScn  = @nScn_Lottables
         SET @nStep = @nStep_Lottables

         SET @nPrevScn = @nScn_QTY
         SET @nPrevStep = @nStep_QTY
      END -- lottablelabel <> ''



      IF (IsNULL(@cLottable01Label, '') = '') AND (IsNULL(@cLottable02Label, '') = '') AND (IsNULL(@cLottable03Label, '') = '') AND
         (IsNULL(@cLottable04Label, '') = '') AND (IsNULL(@cLottable05Label, '') <> '')
      BEGIN
         SET @cLotFlag = 'N'
      END

      SET @cReturnReason = 'N'
      SET @cOverRcpt = 'N'
      SET @cSerialNoFlag = 'N'
      SET @cIDFlag = 'N'

      SET @cSubReason = ''
      SELECT @cSubReason =  ISNULL(RTRIM(SubReasonCode),'')
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptkey
         AND   POKey = CASE WHEN UPPER(@cPOKey) = 'NOPO' THEN '' ELSE @cPOKey END
         AND   SKU = @cSKU
         AND   Lottable01 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE '' END
         AND   Lottable02 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE '' END
         AND   Lottable03 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE '' END
         AND   Lottable04 = CASE WHEN @dLottable04 <> '' THEN @dLottable04 ELSE '' END
         AND   Lottable05 = CASE WHEN @dLottable05 <> '' THEN @dLottable05 ELSE '' END

      -- Exceed Storerconfig ReturnReason or Allow_OverReceipt or ExpiredReason criterias are matched
      -- wll go to Screen_SerialNo
      IF EXISTS (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK)
                 WHERE Configkey = 'ReturnReason'
                 AND   Storerkey = @cStorerkey
                 AND   sValue = '1')
      BEGIN
          IF @cSubReason = ''
            SET @cReturnReason = 'Y'
      END

      IF EXISTS (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK)
                 WHERE Configkey = 'Allow_OverReceipt'
                 AND   Storerkey = @cStorerkey
                 AND   sValue = '1')
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK)
                    WHERE Configkey = 'ByPassTolerance'
                    AND   Storerkey = @cStorerkey
                    AND   sValue <> '1')
         BEGIN
             --IF @nActQTY > @nQTY
             IF (@nActQTY + @nBeforeReceivedQty) > @nQTY AND @cSubReason = ''
             BEGIN
                SET @cOverRcpt = 'Y'
             END
         END
      END

      -- (james01)
      -- If using ASN return by pallet and no lottable label setup and no reason code setup
      IF @nFunc = 581 AND @cLotFlag <> 'Y' AND NOT EXISTS
         (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK)
                 WHERE Configkey = 'ReturnReason'
                 AND   Storerkey = @cStorerkey
                 AND   sValue = '1')
      BEGIN
         --process rdt.rdt_receive
         SET @cTempConditionCode =''
         IF (@cConditionCode = '' OR @cConditionCode IS NULL)
            SET @cTempConditionCode = 'OK'
         ELSE
            SET @cTempConditionCode = @cConditionCode


         --set @cPokey value to blank when it is 'NOPO'
         SET @cPOKeyValue = CASE WHEN UPPER(@cPOkey) = 'NOPO' THEN '' ELSE @cPOkey END
         SET @nNOPOFlag = CASE WHEN UPPER(@cPOkey) = 'NOPO' THEN 1 ELSE 0 END

           --update transaction
           EXEC rdt.rdt_Receive
            @nFunc         = @nFunc,--'0',
            @nMobile       = @nMobile,
            @cLangCode     = @cLangCode,
            @nErrNo        = @nErrNo OUTPUT,
            @cErrMsg       = @cErrMsg OUTPUT,
            @cStorerKey    = @cStorerKey,
            @cFacility     = @cFacility,
            @cReceiptKey   = @cReceiptKey,
            @cPOKey        = @cPOKeyValue, --@cPOKey,
            @cToLOC        = @cLOC,
            @cToID         = @cID,
            @cSKUCode      = @cSKU,
            @cSKUUOM       = @cMstUOM_Desc,
            @nSKUQTY       = @nActQTY,
            @cUCC          = '',
            @cUCCSKU       = '',
            @nUCCQTY       = '',
            @cCreateUCC    = '0',
            @cLottable01   = @cLottable01,
            @cLottable02   = @cLottable02,
            @cLottable03   = @cLottable03,
            @dLottable04   = @dLottable04,
            @dLottable05   = @dLottable05,
--            @cLottable06   = '',              --(CS01)
--            @cLottable07   = '',              --(CS01)
--            @cLottable08   = '',              --(CS01)
--            @cLottable09   = '',              --(CS01)
--            @cLottable10   = '',              --(CS01)
--            @cLottable11   = '',              --(CS01)
--            @cLottable12   = '',              --(CS01)
--            @dLottable13   = NULL,            --(CS01)
--            @dLottable14   = NULL,            --(CS01)
--            @dLottable15   = NULL,            --(CS01)
            @nNOPOFlag     = @nNOPOFlag,
            @cConditionCode = @cTempConditionCode,
            @cSubReasonCode = @cSubReason

         IF @nErrno <> 0
         BEGIN
           SET @nErrNo = @nErrNo
           SET @cErrMsg = @cErrMsg
           GOTO QTY_Fail
         END
         ELSE
         BEGIN
            -- (Vicky06) EventLog - QTY
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '2', -- Receiving
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerKey,
               @cLocation     = @cLOC,
               @cID           = @cID,
               @cSKU          = @cSku,
               @cUOM          = @cMstUOM_Desc,
               @nQTY          = @nActQTY,
               @cReceiptKey   = @cReceiptKey,
               @cPOKey        = @cPOKeyValue,
               @nStep         = @nStep
        END

         -- Prep Msg screen var
        SET @cOutField01 = ''
        SET @cOutField02 = ''
        SET @cOutField03 = ''
        SET @cOutField04 = ''
        SET @cOutField05 = ''
        SET @cOutField06 = ''
        SET @cOutField07 = ''
        SET @cOutField08 = ''
        SET @cOutField09 = ''
        SET @cOutField10 = ''
        SET @cOutField11 = ''
        SET @cOutField12 = ''
        SET @cOutField13 = ''

        SET @cInField01 = ''
        SET @cInField02 = ''
        SET @cInField03 = ''
        SET @cInField04 = ''
        SET @cInField05 = ''
        SET @cInField06 = ''
        SET @cInField07 = ''
        SET @cInField08 = ''
        SET @cInField09 = ''
        SET @cInField10 = ''
        SET @cInField11 = ''
        SET @cInField12 = ''
        SET @cInField13 = ''

        --  (ChewKP01) Start --
        SET @bSkipSuccessMsg = rdt.RDTGetConfig(@nFunc, 'SkipSuccessMsg', @cStorerKey)

        IF @bSkipSuccessMsg = '1'
        BEGIN
       --  Prepare Screen Variable
        SET @nCTotalBeforeReceivedQty = 0
        SET @nCTotalUQtyExpected = 0

        -- Calculate QTY by preferred UOM  -- (ChewKP01)
        SELECT  @nCTotalUQtyExpected = SUM(QtyExpected), @nCTotalBeforeReceivedQty = SUM(BeforeReceivedQty)  FROM dbo.ReceiptDetail (NOLOCK)
        WHERE ReceiptKey = @cReceiptKey
        AND   POKey = CASE WHEN UPPER('@cPokey') = 'NOPO' THEN '' ELSE @cPokey END


        -- Prepare SKU screen var
        SET @cOutField01 = @cReceiptKey
        SET @cOutField02 = @cPOKey
        SET @cOutField03 = '' -- SKU
        SET @cOutField04 = ''
        SET @cOutField05 = ''
        SET @cOutField06 = @nCTotalUQtyExpected      -- (ChewKP01)
        SET @cOutField07 = @cDefaultUOM              -- (ChewKP01)
        SET @cOutField08 = @nCTotalBeforeReceivedQty -- (ChewKP01)
        SET @cOutField09 = @cDefaultUOM              -- (ChewKP01)

         -- Remember current scn & step no
         SET @nPrevScn = @nScn_SKU
         SET @nPrevStep = @nStep_SKU

         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU
         GOTO Quit
        END
        ELSE
        BEGIN
            SET @nScn  = @nScn_MsgSuccess
            SET @nStep = @nStep_MsgSuccess
            GOTO Quit
        END
      -- (ChewKP01) End --
      END

      -- (james01)
      -- If using ASN return by pallet and with lottable label setup
      -- (since lottable label setup, so no need check reason code setup)


      IF @nFunc = 581 AND @cLotFlag = 'Y'
      BEGIN
         SET @nScn  = @nScn_Lottables
         SET @nStep = @nStep_Lottables

         SET @nPrevScn = @nScn_QTY
       SET @nPrevStep = @nStep_QTY
      END

      IF (@cLotFlag <> 'Y') AND (@cReturnReason = 'Y' OR @cOverRcpt = 'Y')
      BEGIN
         --prepare SerialNo screen variable
         SET @cOutField01 = '' --lottable01
         SET @cOutField02 = '' --lottable02
         SET @cOutField03 = '' --lottable03
         SET @cOutField04 = '' --lottable04
         SET @cOutField05 = '' --lottable05
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cSerialNoFlag = 'Y'
         SET @nScn  = @nScn_SubReason
         SET @nStep = @nStep_SubReason

         SET @nPrevScn = @nScn_QTY
         SET @nPrevStep = @nStep_QTY
      END

      IF (@cLotFlag <> 'Y') AND (@cReturnReason <> 'Y') AND (@cOverRcpt <> 'Y')
      BEGIN
         -- Get stored proc name for extended info (james03)
         SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
         IF @cExtendedInfoSP = '0'
            SET @cExtendedInfoSP = ''

         -- Extended info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cZone, @cReceiptKey, @cPOKey, @cSKU, @nQTY,
                    @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cConditionCode, @cSubReason,
                    @cToLOC, @cToID, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

               SET @cSQLParam =
                  '@nMobile         INT, ' +
                  '@nFunc           INT, ' +
                  '@cLangCode       NVARCHAR( 3), ' +
                  '@nStep           INT, ' +
                  '@nInputKey       INT, ' +
                  '@cZone           NVARCHAR( 10), ' +
                  '@cReceiptKey     NVARCHAR( 10), ' +
                  '@cPOKey          NVARCHAR( 10), ' +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@nQTY            INT, ' +
                  '@cLottable01     NVARCHAR( 18), ' +
                  '@cLottable02     NVARCHAR( 18), ' +
                  '@cLottable03     NVARCHAR( 18), ' +
                  '@dLottable04     DATETIME, ' +
                  '@cConditionCode  NVARCHAR( 10), ' +
                  '@cSubReason      NVARCHAR( 10), ' +
                  '@cToLOC          NVARCHAR( 10), ' +
                  '@cToID           NVARCHAR( 18), ' +
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
                  '@nErrNo          INT OUTPUT, ' +
                  '@cErrMsg         NVARCHAR( 20) OUTPUT '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cZone, @cReceiptKey, @cPOKey, @cSKU, @nQTY,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cConditionCode, @cSubReason,
                  @cLOC, @cID, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            END
         END

         -- Prep ID screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField04 = '' -- Lottable02
         SET @cOutField05 = '' -- Lottable03
         SET @cOutField06 = '' -- Lottable04
         IF @cPrefUOM_Desc = ''
         BEGIN
            SET @cOutField07 = '' -- @nPrefUOM_Div
            SET @cOutField08 = '' -- @cPrefUOM_Desc
            SET @cOutField10 = '' -- @nActPQTY
    -- Disable pref QTY field
            SET @cFieldAttr10 = 'O' -- (Vicky02)
            SET @cInField10 = '' -- (james02)
         END
         ELSE
         BEGIN
           SET @cOutField07 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
           SET @cOutField08 = @cPrefUOM_Desc
           SET @cOutField10 = CAST( @nActPQTY AS NVARCHAR( 5))
         END

         SET @cOutField09 = @cMstUOM_Desc
         SET @cOutField11 = CAST( @nActMQTY as NVARCHAR( 5))
         SET @cOutField12 = '' -- ID
         SET @cOutField13 = CASE WHEN ISNULL( @cExtendedInfo, '') <> '' THEN @cExtendedInfo ELSE '' END

         SET @cIDFlag = 'Y'
         SET @nScn  = @nScn_ID
         SET @nStep = @nStep_ID

         SET @nPrevScn = @nScn_QTY
       SET @nPrevStep = @nStep_QTY
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN


      -- Prepare SKU screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- SKUDecr
      SET @cOutField05 = '' -- SKUDecr

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

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Go to prev screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END
   GOTO Quit

   QTY_Fail:
   BEGIN
      -- (Vicky02) - Start
      SET @cFieldAttr08 = ''
      -- (Vicky02) - End

      IF @cPrefUOM_Desc = ''
      BEGIN
         -- Pref QTY is always enable (as screen defination). When reach error, it will quit directly and forgot
         -- to disable the Pref QTY field. So centralize disable it here for all fail condition
         -- Disable pref QTY field
         SET @cFieldAttr08 = 'O' -- (Vicky02)
         SET @cInField08 = '' -- (james02)
      END
      ELSE
      BEGIN
         SET @cOutField08 = @cActPQTY  -- ActMQTY
      END

      SET @cOutField09 = @cActMQTY-- ActMQTY
      SET @cOutField10 = @cConditionCode
      --SET @cOutField11 = ''
      GOTO Quit
   END

   QTYCD_Fail:
   BEGIN
     -- Pref QTY is always enable (as screen defination). When reach error, it will quit directly and forgot
     -- to disable the Pref QTY field. So centralize disable it here for all fail condition
     -- Disable pref QTY field

    -- (Vicky02) - Start
    SET @cFieldAttr08 = ''
    -- (Vicky02) - End

    IF @cPrefUOM_Desc = ''
    BEGIN
       SET @cFieldAttr08 = 'O' -- (Vicky02)
       SET @cInField08 = '' -- (james02)
       SET @cOutField09 = @cActMQTY
    END
    ELSE
    BEGIN
        SET @cOutField08 = @cActPQTY
        SET @cOutField09 = @cActMQTY
    END

    SET @cConditionCode = ''
    SET @cOutField10 = '' --CondCode


     GOTO Quit
   END
END
GOTO Quit

/********************************************************************************
(ChewKP01)
Step_SKIP_QTY -- Call from Screen 3
********************************************************************************/
Step_SKIP_QTY:
BEGIN

      -- Screen mapping
      --SET @cActPQTY = IsNULL( @cInField08, '')
      --SET @cActMQTY = IsNULL( @cInField09, '')
      --SET @cConditionCode = IsNULL( @cInField10, '')

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

      SET @cActPQTY = 0
      SET @nActMQTY = @cReturnDefaultQTY
      SET @nActQTY = @nActMQTY + @cActPQTY

      -- If any one of the Lottablelabels being set, will got to Screen_Lottables
      SET @cLotFlag = 'N'

      IF (IsNULL(@cLottable01Label, '') <> '') OR (IsNULL(@cLottable02Label, '') <> '') OR (IsNULL(@cLottable03Label, '') <> '') OR
         (IsNULL(@cLottable04Label, '') <> '') OR (IsNULL(@cLottable05Label, '') <> '')
      BEGIN
         --prepare next screen variable
         SET @cOutField01 = '' --lottable01
         SET @cOutField02 = '' --lottable02
         SET @cOutField03 = '' --lottable03
         SET @cOutField04 = '' --lottable04
         SET @cOutField05 = '' --lottable05
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cInField08 = ''
/*
         SET @cLottable01 = ''
         SET @cLottable02 = ''
         SET @cLottable03 = ''
         SET @dLottable04 = 0
         SET @dLottable05 = 0
*/
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

         --initiate @nCounter = 1
         SET @nCount = 1

         --retrieve value for pre lottable01 - 05
         WHILE @nCount <=5 --break the loop when @nCount >5
         BEGIN
             IF @nCount = 1
             BEGIN
                SET @cListName = 'Lottable01'
                SET @cLottableLabel = @cLottable01Label
             END
             ELSE
             IF @nCount = 2
             BEGIN
                SET @cListName = 'Lottable02'
                SET @cLottableLabel = @cLottable02Label
             END
             ELSE
             IF @nCount = 3
             BEGIN
                SET @cListName = 'Lottable03'
                SET @cLottableLabel = @cLottable03Label
             END
             ELSE
             IF @nCount = 4
             BEGIN
                SET @cListName = 'Lottable04'
                  SET @cLottableLabel = @cLottable04Label
             END
             ELSE
             IF @nCount = 5
             BEGIN
                SET @cListName = 'Lottable05'
                SET @cLottableLabel = @cLottable05Label
             END

             --get short, store procedure and lottablelable value for each lottable
             SET @cShort = ''
             SET @cStoredProd = ''
             SELECT TOP 1
               @cShort      = CASE WHEN C.UDF04 <> '' THEN 'PRE'   ELSE ISNULL(RTRIM(C.Short),'') END,
               @cStoredProd = CASE WHEN C.UDF04 <> '' THEN C.UDF04 ELSE IsNULL(RTRIM(C.Long), '') END
             FROM dbo.CodeLkUp C WITH (NOLOCK)
             JOIN RDT.StorerConfig S WITH (NOLOCK) ON (C.ListName = S.ConfigKey AND C.Code = S.SValue)
             WHERE C.ListName = @cListName
             AND   C.Code = @cLottableLabel
             AND  (C.StorerKey = @cStorerkey OR C.StorerKey = '')
             ORDER By C.StorerKey DESC

             IF @cShort = 'PRE' AND @cStoredProd <> ''
             BEGIN
                  EXEC dbo.ispLottableRule_Wrapper
                     @c_SPName            = @cStoredProd,
                     @c_ListName          = @cListName,
                     @c_Storerkey         = @cStorerkey,
                     @c_Sku               = @cSKU,  -- (ChewKP02)
                     @c_LottableLabel     = @cLottableLabel,
                     @c_Lottable01Value   = '',
                     @c_Lottable02Value   = '',
                     @c_Lottable03Value   = '',
                     @dt_Lottable04Value  = '',
                     @dt_Lottable05Value  = '',
                     @c_Lottable06Value   = '',                       --(CS01)
                     @c_Lottable07Value   = '',                       --(CS01)
                     @c_Lottable08Value   = '',                       --(CS01)
                     @c_Lottable09Value   = '',                       --(CS01)
                     @c_Lottable10Value   = '',                       --(CS01)
                     @c_Lottable11Value   = '',                       --(CS01)
                     @c_Lottable12Value   = '',                       --(CS01)
                     @dt_Lottable13Value  = '',                       --(CS01)
                     @dt_Lottable14Value  = '',                       --(CS01)
                     @dt_Lottable15Value  = '',                       --(CS01)
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
                     @c_Sourcekey         = @cReceiptKey, -- SOS#81879
                     @c_Sourcetype        = 'RECEIPTRET'  -- SOS#81879


                IF ISNULL(@cErrMsg, '') <> ''   -- SOS#81879
                BEGIN
                   SET @cErrMsg = @cErrMsg   -- SOS#81879
                   GOTO SKIP_QTYCD_Fail
                   BREAK
                END

                SET @cLottable01 = IsNULL( @cLottable01, '')
                SET @cLottable02 = IsNULL( @cLottable02, '')
                SET @cLottable03 = IsNULL( @cLottable03, '')
                SET @dLottable04 = IsNULL( @dLottable04, 0)
                SET @dLottable05 = IsNULL( @dLottable05, 0)

         --
         --      SET @cOutField02 = @cLottable01
         --      SET @cOutField04 = @cLottable02
         --      SET @cOutField06 = @cLottable03
         --      SET @cOutField08 = CASE WHEN @dLottable04 <> 0 THEN rdt.rdtFormatDate( @dLottable04) END
         --      SET @cOutField10 = CASE WHEN @dLottable05 <> 0 THEN rdt.rdtFormatDate( @dLottable05) END
             END

             -- increase counter by 1
             SET @nCount = @nCount + 1
         END -- nCount

         -- Initiate labels
--        SELECT
--           @cOutField01 = 'Lottable01:',
--           @cOutField03 = 'Lottable02:',
--           @cOutField05 = 'Lottable03:',
--           @cOutField07 = 'Lottable04:',
-- @cOutField09 = 'Lottable05:'

        -- Populate labels and lottables
        IF @cLottable01Label = '' OR @cLottable01Label IS NULL
        BEGIN
           SELECT @cOutField01 = 'Lottable01:'
           SELECT @cInField02 = ''
           SET @cFieldAttr02 = 'O' -- (Vicky02)
        END
        ELSE
        BEGIN
           SELECT @cOutField01 = @cLottable01Label
        END
        SET @cOutField02 = @cLottable01
        SET @cInField02 = @cOutField02

        IF @cLottable02Label = '' OR @cLottable02Label IS NULL
        BEGIN
           SELECT @cOutField03 = 'Lottable02:'
           SELECT @cInField04 = ''
           SET @cFieldAttr04 = 'O' -- (Vicky02)
        END
        ELSE
        BEGIN
           SELECT @cOutField03 = @cLottable02Label
        END
        SET @cOutField04 = @cLottable02
        SET @cInField04 = @cOutField04

        IF @cLottable03Label = '' OR @cLottable03Label IS NULL
        BEGIN
           SELECT @cOutField05 = 'Lottable03:'
           SELECT @cInField06 = ''
           SET @cFieldAttr06 = 'O' -- (Vicky02)
        END
        ELSE
        BEGIN
           SELECT @cOutField05 = @cLottable03Label
        END
        SET @cOutField06 = @cLottable03
        SET @cInField06 = @cOutField06

        IF @cLottable04Label = '' OR @cLottable04Label IS NULL
        BEGIN
           SELECT @cOutField07 = 'Lottable04:'
           SELECT @cInField08 = ''
           SET @cFieldAttr08 = 'O' -- (Vicky02)
        END
        ELSE
        BEGIN
           SELECT  @cOutField07 = @cLottable04Label
        END
        IF rdt.rdtIsValidDate( @dLottable04) = 1
        BEGIN
           SET @cOutField08 = RDT.RDTFormatDate( @dLottable04)
           SET @cInField08 = @cOutField08
        END
        EXEC rdt.rdtSetFocusField @nMobile, 1   --set focus to 1st field

         SET @cLotFlag = 'Y'
         SET @nScn  = @nScn_Lottables
         SET @nStep = @nStep_Lottables

         SET @nPrevScn = @nScn_QTY
       SET @nPrevStep = @nStep_QTY
      END -- lottablelabel <> ''

      IF (IsNULL(@cLottable01Label, '') = '') AND (IsNULL(@cLottable02Label, '') = '') AND (IsNULL(@cLottable03Label, '') = '') AND
         (IsNULL(@cLottable04Label, '') = '') AND (IsNULL(@cLottable05Label, '') <> '')
      BEGIN
         SET @cLotFlag = 'N'
      END



      SET @cReturnReason = 'N'
      SET @cOverRcpt = 'N'
      SET @cSerialNoFlag = 'N'
      SET @cIDFlag = 'N'

      SET @cSubReason = ''
      SELECT @cSubReason =  ISNULL(RTRIM(SubReasonCode),'')
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptkey
         AND   POKey = CASE WHEN UPPER(@cPOKey) = 'NOPO' THEN '' ELSE @cPOKey END
         AND   SKU = @cSKU
         AND   Lottable01 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE '' END
         AND   Lottable02 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE '' END
         AND   Lottable03 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE '' END
         AND   Lottable04 = CASE WHEN @dLottable04 <> '' THEN @dLottable04 ELSE '' END
         AND   Lottable05 = CASE WHEN @dLottable05 <> '' THEN @dLottable05 ELSE '' END

      -- Exceed Storerconfig ReturnReason or Allow_OverReceipt or ExpiredReason criterias are matched
      -- wll go to Screen_SerialNo
      IF EXISTS (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK)
                 WHERE Configkey = 'ReturnReason'
                 AND   Storerkey = @cStorerkey
                 AND   sValue = '1')
      BEGIN
          IF @cSubReason = ''
            SET @cReturnReason = 'Y'
      END

      IF EXISTS (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK)
                 WHERE Configkey = 'Allow_OverReceipt'
                 AND   Storerkey = @cStorerkey
                 AND   sValue = '1')
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK)
                    WHERE Configkey = 'ByPassTolerance'
                    AND   Storerkey = @cStorerkey
                    AND   sValue <> '1')
         BEGIN
             --IF @nActQTY > @nQTY
             IF (@nActQTY + @nBeforeReceivedQty) > @nQTY AND @cSubReason = ''
             BEGIN
                SET @cOverRcpt = 'Y'
             END
         END
      END

      -- (james01)
      -- If using ASN return by pallet and no lottable label setup and no reason code setup



      IF @nFunc = 581 AND @cLotFlag <> 'Y' AND NOT EXISTS
         (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK)
                 WHERE Configkey = 'ReturnReason'
                 AND   Storerkey = @cStorerkey
                 AND   sValue = '1')
      BEGIN
         --process rdt.rdt_receive
         SET @cTempConditionCode =''
         IF (@cConditionCode = '' OR @cConditionCode IS NULL)
            SET @cTempConditionCode = 'OK'
         ELSE
            SET @cTempConditionCode = @cConditionCode


         --set @cPokey value to blank when it is 'NOPO'
         SET @cPOKeyValue = CASE WHEN UPPER(@cPOkey) = 'NOPO' THEN '' ELSE @cPOkey END

         IF ISNULL(@cLOC,'') = '' -- (ChewKP01)
         BEGIN
            SET @cLOC = @cDefaultLOC
         END

         SET @nNOPOFlag = CASE WHEN UPPER(@cPOkey) = 'NOPO' THEN 1 ELSE 0 END

        --update transaction
        EXEC rdt.rdt_Receive
         @nFunc         = @nFunc,--'0',
         @nMobile       = @nMobile,
         @cLangCode     = @cLangCode,
         @nErrNo        = @nErrNo OUTPUT,
         @cErrMsg       = @cErrMsg OUTPUT,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = @cPOKeyValue, --@cPOKey,
         @cToLOC        = @cLOC,
         @cToID         = @cID,
         @cSKUCode      = @cSKU,
         @cSKUUOM       = @cMstUOM_Desc,
         @nSKUQTY       = @nActQTY,
         @cUCC          = '',
         @cUCCSKU       = '',
         @nUCCQTY       = '',
         @cCreateUCC    = '0',
         @cLottable01   = @cLottable01,
         @cLottable02   = @cLottable02,
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
         @dLottable05   = @dLottable05,
--         @cLottable06   = '',              --(CS01)
--         @cLottable07   = '',              --(CS01)
--         @cLottable08   = '',              --(CS01)
--         @cLottable09   = '',              --(CS01)
--         @cLottable10   = '',              --(CS01)
--         @cLottable11   = '',              --(CS01)
--         @cLottable12   = '',              --(CS01)
--         @dLottable13   = NULL,            --(CS01)
--         @dLottable14   = NULL,            --(CS01)
--         @dLottable15   = NULL,            --(CS01)
         @nNOPOFlag     = @nNOPOFlag,
         @cConditionCode = @cTempConditionCode,
         @cSubReasonCode = @cSubReason

        IF @nErrno <> 0
        BEGIN
          SET @nErrNo = @nErrNo
          SET @cErrMsg = @cErrMsg
          GOTO SKIP_QTY_Fail
        END
        ELSE
        BEGIN
           -- (Vicky06) EventLog - QTY
           EXEC RDT.rdt_STD_EventLog
              @cActionType   = '2', -- Receiving
              @cUserID       = @cUserName,
              @nMobileNo     = @nMobile,
              @nFunctionID   = @nFunc,
              @cFacility     = @cFacility,
              @cStorerKey    = @cStorerKey,
              @cLocation     = @cLOC,
              @cID           = @cID,
              @cSKU          = @cSku,
              @cUOM          = @cMstUOM_Desc,
              @nQTY          = @nActQTY,
              @cReceiptKey   = @cReceiptKey,
              @cPOKey        = @cPOKeyValue,
              @nStep         = @nStep
        END



          -- Prep Msg screen var
     SET @cOutField01 = ''
     SET @cOutField02 = ''
     SET @cOutField03 = ''
     SET @cOutField04 = ''
     SET @cOutField05 = ''
     SET @cOutField06 = ''
     SET @cOutField07 = ''
     SET @cOutField08 = ''
     SET @cOutField09 = ''
     SET @cOutField10 = ''
     SET @cOutField11 = ''
     SET @cOutField12 = ''
     SET @cOutField13 = ''

     SET @cInField01 = ''
     SET @cInField02 = ''
     SET @cInField03 = ''
     SET @cInField04 = ''
     SET @cInField05 = ''
     SET @cInField06 = ''
     SET @cInField07 = ''
     SET @cInField08 = ''
     SET @cInField09 = ''
     SET @cInField10 = ''
     SET @cInField11 = ''
     SET @cInField12 = ''
     SET @cInField13 = ''



     SET @bSkipSuccessMsg = rdt.RDTGetConfig(@nFunc, 'SkipSuccessMsg', @cStorerKey)



    IF @bSkipSuccessMsg = '1'
    BEGIN
      -- Prepare Screen Variable
      SET @nCTotalBeforeReceivedQty = 0
      SET @nCTotalUQtyExpected = 0

      -- Calculate QTY by preferred UOM  -- (ChewKP01)
      SELECT  @nCTotalUQtyExpected = SUM(QtyExpected), @nCTotalBeforeReceivedQty = SUM(BeforeReceivedQty)  FROM dbo.ReceiptDetail (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   POKey = CASE WHEN UPPER('@cPokey') = 'NOPO' THEN '' ELSE @cPokey END


     -- Prepare SKU screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = @nCTotalUQtyExpected      -- (ChewKP01)
      SET @cOutField07 = @cDefaultUOM              -- (ChewKP01)
      SET @cOutField08 = @nCTotalBeforeReceivedQty -- (ChewKP01)
      SET @cOutField09 = @cDefaultUOM              -- (ChewKP01)

      -- Remember current scn & step no
      SET @nPrevScn = @nScn_SKU
      SET @nPrevStep = @nStep_SKU

      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
      GOTO Quit
    END
    ELSE
    BEGIN
      SET @nScn  = @nScn_MsgSuccess
      SET @nStep = @nStep_MsgSuccess
      GOTO Quit
    END

      END

      -- (james01)
      -- If using ASN return by pallet and with lottable label setup
      -- (since lottable label setup, so no need check reason code setup)



      IF @nFunc = 581 AND @cLotFlag = 'Y'
      BEGIN
         SET @nScn  = @nScn_Lottables
         SET @nStep = @nStep_Lottables

         SET @nPrevScn = @nScn_QTY
         SET @nPrevStep = @nStep_QTY
      END

      IF (@cLotFlag <> 'Y') AND (@cReturnReason = 'Y' OR @cOverRcpt = 'Y')
      BEGIN
         --prepare SerialNo screen variable
         SET @cOutField01 = '' --lottable01
         SET @cOutField02 = '' --lottable02
         SET @cOutField03 = '' --lottable03
         SET @cOutField04 = '' --lottable04
         SET @cOutField05 = '' --lottable05
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cSerialNoFlag = 'Y'
         SET @nScn  = @nScn_SubReason
         SET @nStep = @nStep_SubReason

         SET @nPrevScn = @nScn_QTY
       SET @nPrevStep = @nStep_QTY
      END

      IF (@cLotFlag <> 'Y') AND (@cReturnReason <> 'Y') AND (@cOverRcpt <> 'Y')
      BEGIN
        -- Prep ID screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField04 = '' -- Lottable02
         SET @cOutField05 = '' -- Lottable03
         SET @cOutField06 = '' -- Lottable04
         IF @cPrefUOM_Desc = ''
         BEGIN
            SET @cOutField07 = '' -- @nPrefUOM_Div
            SET @cOutField08 = '' -- @cPrefUOM_Desc
            SET @cOutField10 = '' -- @nActPQTY
            -- Disable pref QTY field
            SET @cFieldAttr10 = 'O' -- (Vicky02)
            SET @cInField10 = '' -- (james02)
         END
         ELSE
         BEGIN
            SET @cOutField07 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
            SET @cOutField08 = @cPrefUOM_Desc
            SET @cOutField10 = CAST( @nActPQTY AS NVARCHAR( 5))
         END
         SET @cOutField09 = @cMstUOM_Desc
         SET @cOutField11 = CAST( @nActMQTY as NVARCHAR( 5))
         SET @cOutField12 = '' -- ID
         SET @cOutField13 = ''

         SET @cIDFlag = 'Y'
         SET @nScn  = @nScn_ID
         SET @nStep = @nStep_ID

         SET @nPrevScn = @nScn_QTY
       SET @nPrevStep = @nStep_QTY
      END

   GOTO Quit

   SKIP_QTY_Fail:
   BEGIN
      -- (Vicky02) - Start
      SET @cFieldAttr08 = ''
      -- (Vicky02) - End

      IF @cPrefUOM_Desc = ''
      BEGIN
         -- Pref QTY is always enable (as screen defination). When reach error, it will quit directly and forgot
         -- to disable the Pref QTY field. So centralize disable it here for all fail condition
         -- Disable pref QTY field
         SET @cFieldAttr08 = 'O' -- (Vicky02)
         SET @cInField08 = '' -- (james02)
      END
      ELSE
      BEGIN
         SET @cOutField08 = @cActPQTY  -- ActMQTY
      END

      SET @cOutField09 = @cActMQTY-- ActMQTY
      SET @cOutField10 = @cConditionCode
      --SET @cOutField11 = ''
      GOTO Quit
   END

   SKIP_QTYCD_Fail:
   BEGIN
     -- Pref QTY is always enable (as screen defination). When reach error, it will quit directly and forgot
     -- to disable the Pref QTY field. So centralize disable it here for all fail condition
     -- Disable pref QTY field

    -- (Vicky02) - Start
    SET @cFieldAttr08 = ''
    -- (Vicky02) - End

    IF @cPrefUOM_Desc = ''
    BEGIN
       SET @cFieldAttr08 = 'O' -- (Vicky02)
       SET @cInField08 = '' -- (james02)
       SET @cOutField09 = @cActMQTY
    END
    ELSE
    BEGIN
        SET @cOutField08 = @cActPQTY
        SET @cOutField09 = @cActMQTY
    END

    SET @cConditionCode = ''
    SET @cOutField10 = '' --CondCode


     GOTO Quit
   END
END
GOTO Quit

/********************************************************************************
Scn = 1453. Lottables screen
   Lottable01 (field01)
   Lottable02 (field02)
   Lottable03 (field03)
   Lottable04 (field04)
********************************************************************************/
Step_Lottables:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      --Screen Mapping
      SET @cTempLottable01 = @cInField02
      SET @cTempLottable02 = @cInField04
      SET @cTempLottable03 = @cInField06
      SET @cTempLottable04 = @cInField08
--      SET @cTempLottable05 = @cInField10

      --retain original value for lottable01-05
      SET @cLottable01 = @cTempLottable01
      SET @cLottable02 = @cTempLottable02
      SET @cLottable03 = @cTempLottable03
      SET @cOutField02 = @cLottable01
      SET @cOutField04 = @cLottable02
      SET @cOutField06 = @cLottable03

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

      IF @cTempLottable04 <> '' AND rdt.rdtIsValidDate(@cTempLottable04) = 0
      BEGIN
         SET @nErrNo = 63320
         SET @cErrMsg = rdt.rdtgetmessage( 63320, @cLangCode, 'DSP') --Invalid Date
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- Lottable04
         SET @dLottable04 = NULL
         GOTO Lottables_Fail
      END

       --retain original value for lottable01-05
      SET @dLottable04 = rdt.rdtConvertToDate( @cTempLottable04)
      SET @cOutField08 = CASE WHEN @dLottable04 <> 0  THEN rdt.rdtFormatDate( @dLottable04) ELSE @cTempLottable04 END

      --check for date validation for lottable05
--       IF @cTempLottable05 <> '' AND rdt.rdtIsValidDate(@cTempLottable05) = 0
--       BEGIN
--          SET @nErrNo = 63321
--          SET @cErrMsg = rdt.rdtgetmessage( 63321, @cLangCode, 'DSP') --Invalid Date
--          EXEC rdt.rdtSetFocusField @nMobile, 5 -- Lottable05
--          GOTO Lottables_Fail
--   END

      SET @cTempLotLabel01 = @cLottable01Label
      SET @cTempLotLabel02 = @cLottable02Label
      SET @cTempLotLabel03 = @cLottable03Label
      SET @cTempLotLabel04 = @cLottable04Label
      SET @cTempLotLabel05 = @cLottable05Label

      --initiate @nCounter = 1
      SET @nCount = 1

      WHILE @nCount < = 5
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
         ELSE IF @nCount = 5
         BEGIN
            SET @cListName = 'Lottable05'
            SET @cTempLotLabel = @cTempLotLabel05
         END

         SET @cShort = ''
         SET @cStoredProd = ''
         SET @cLottableLabel = ''
         SELECT TOP 1
            @cShort      = CASE WHEN C.UDF05 <> '' THEN 'POST'  ELSE C.Short END,
            @cStoredProd = CASE WHEN C.UDF05 <> '' THEN C.UDF05 ELSE IsNULL(RTRIM(C.Long), '') END,
            @cLottableLabel = C.Code
         FROM dbo.CodeLkUp C WITH (NOLOCK)
         WHERE C.Listname = @cListName
         AND   C.Code = @cTempLotLabel
         AND  (C.StorerKey = @cStorerkey OR C.StorerKey = '')
         ORDER By C.StorerKey DESC

         IF @cShort = 'POST' AND @cStoredProd <> ''
         BEGIN
            IF rdt.rdtIsValidDate(@cTempLottable04) = 1 --valid date
               SET @dTempLottable04 = rdt.rdtConvertToDate( @cTempLottable04)

            IF rdt.rdtIsValidDate(@cTempLottable05) = 1 --valid date
               SET @dTempLottable05 = rdt.rdtConvertToDate( @cTempLottable05)

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
               @dt_Lottable05Value  = @dTempLottable05,
               @c_Lottable06Value   = '',                       --(CS01)
               @c_Lottable07Value   = '',                       --(CS01)
               @c_Lottable08Value   = '',                       --(CS01)
               @c_Lottable09Value   = '',                       --(CS01)
               @c_Lottable10Value   = '',                       --(CS01)
               @c_Lottable11Value   = '',                       --(CS01)
               @c_Lottable12Value   = '',                       --(CS01)
               @dt_Lottable13Value  = '',                       --(CS01)
               @dt_Lottable14Value  = '',                       --(CS01)
               @dt_Lottable15Value  = '',                       --(CS01)
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
               @c_Sourcekey         = @cReceiptKey, -- SOS#81879
               @c_Sourcetype        = 'RECEIPTRET'  -- SOS#81879

            IF ISNULL(@cErrMsg, '') <> ''  -- SOS#81879
            BEGIN
               SET @cErrMsg = @cErrMsg -- SOS#81879

               --retain original value for lottable01-05
               SET @cLottable01 = @cTempLottable01
               SET @cLottable02 = @cTempLottable02
               SET @cLottable03 = @cTempLottable03
               IF rdt.rdtIsValidDate(@cTempLottable04) = 1 --valid date
                  SET @dLottable04 = rdt.rdtConvertToDate( @cTempLottable04)

               IF @cListName = 'Lottable01'
                  EXEC rdt.rdtSetFocusField @nMobile, 2
               ELSE IF @cListName = 'Lottable02'
                  EXEC rdt.rdtSetFocusField @nMobile, 4
               ELSE IF @cListName = 'Lottable03'
                  EXEC rdt.rdtSetFocusField @nMobile, 6
               ELSE IF @cListName = 'Lottable04'
                  EXEC rdt.rdtSetFocusField @nMobile, 8

               GOTO Lottables_Fail  -- Error will break
            END

            SET @cLottable01 = IsNULL( @cLottable01, '')
            SET @cLottable02 = IsNULL( @cLottable02, '')
            SET @cLottable03 = IsNULL( @cLottable03, '')
            SET @dLottable04 = IsNULL( @dLottable04, 0)
            SET @dLottable05 = IsNULL( @dLottable05, 0)

            SET @cOutField02 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE @cTempLottable01 END
            SET @cOutField04 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE @cTempLottable02 END
            SET @cOutField06 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE @cTempLottable03 END
            SET @cOutField08 = CASE WHEN @dLottable04 <> 0  THEN rdt.rdtFormatDate( @dLottable04) ELSE @cTempLottable04 END

            SET @cLottable01 = IsNULL(@cOutField02, '')
            SET @cLottable02 = IsNULL(@cOutField04, '')
            SET @cLottable03 = IsNULL(@cOutField06, '')
            SET @dLottable04 = IsNULL(@cOutField08, 0)
         END

         --increase counter by 1
         SET @nCount = @nCount + 1
      END -- end of while

      -- Skip lottable
      IF @cSkipLottable01 = '1' SET @cLottable01 = ''
      IF @cSkipLottable02 = '1' SET @cLottable02 = ''
      IF @cSkipLottable03 = '1' SET @cLottable03 = ''
      IF @cSkipLottable04 = '1' SET @dLottable04 = 0

      IF (@cTempLotLabel01 <> '' AND @cTempLottable01 <> '' AND @cLottable01 = '')
      BEGIN
         SET @cLottable01 = @cTempLottable01
      END

      IF (@cTempLotLabel02 <> '' AND @cTempLottable02 <> '' AND @cLottable02 = '')
      BEGIN
         SET @cLottable02 = @cTempLottable02
      END

      IF (@cTempLotLabel03 <> '' AND @cTempLottable03 <> '' AND @cLottable03 = '')
      BEGIN
         SET @cLottable03 = @cTempLottable03
      END

      IF (@cTempLotLabel04 <> '' AND @cTempLottable04 <> '' AND @dLottable04 = 0)
      BEGIN
         SET @dLottable04 = @cTempLottable04
      END

      --if lottable01 has been setup but no value, prompt error msg
      IF @cSkipLottable01 <> '1' AND (@cTempLotLabel01 <> '' AND @cTempLottable01 = '' AND @cLottable01 = '')
      BEGIN
         SET @nErrNo = 63322
         SET @cErrMsg = rdt.rdtgetmessage(63322, @cLangCode, 'DSP') --Lottable01 Req
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Lottables_Fail
      END

      --if lottable02 has been setup but no value, prompt error msg
      IF @cSkipLottable02 <> '1' AND (@cTempLotLabel02 <> '' AND @cTempLottable02 = '' AND @cLottable02 = '')
      BEGIN
         SET @nErrNo = 63323
         SET @cErrMsg = rdt.rdtgetmessage(63323, @cLangCode, 'DSP') --Lottable02 Req
         EXEC rdt.rdtSetFocusField @nMobile, 4
         GOTO Lottables_Fail
      END

      --if lottable03 has been setup but no value, prompt error msg
      IF @cSkipLottable03 <> '1' AND (@cTempLotLabel03 <> '' AND @cTempLottable03 = '' AND @cLottable03 = '')
      BEGIN
         SET @nErrNo = 63324
         SET @cErrMsg = rdt.rdtgetmessage(63324, @cLangCode, 'DSP') --Lottable03 Req
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Lottables_Fail
      END

      --if lottable04 has been setup but no value, prompt error msg
      IF @cSkipLottable04 <> '1' AND (@cTempLotLabel04 <> '' AND @cTempLottable04 = '' AND @dLottable04 = 0)
      BEGIN
         SET @nErrNo = 63325
         SET @cErrMsg = rdt.rdtgetmessage(63325, @cLangCode, 'DSP') --Lottable04 Req
         EXEC rdt.rdtSetFocusField @nMobile, 8
         GOTO Lottables_Fail
      END

      --if lottable05 has been setup but no value, set lottable05 to default date
--       IF (@cTempLotLabel05 <> '' AND @cTempLottable05 = '' AND @dLottable05 = 0)
--       BEGIN
--            SET @nErrNo = 63326
--            SET @cErrMsg = rdt.rdtgetmessage(63326, @cLangCode, 'DSP') --Lottable05 req
--            EXEC rdt.rdtSetFocusField @nMobile, 10
--            GOTO Lottables_Fail
--       END

      -- Exceed Storerconfig ReturnReason or Allow_OverReceipt or ExpiredReason criterias are matched
      -- wll go to Screen_SerialNo

      SET @cExpReason = 'N'
      SET @cReturnReason = 'N'
      SET @cOverRcpt = 'N'

      SET @cSubReason = ''
      SELECT @cSubReason =  ISNULL(RTRIM(SubReasonCode),'')
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptkey
      AND   POKey = CASE WHEN UPPER(@cPOKey) = 'NOPO' THEN '' ELSE @cPOKey END
      AND   SKU = @cSKU
      AND   Lottable01 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE '' END
      AND   Lottable02 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE '' END
      AND   Lottable03 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE '' END
      AND   Lottable04 = CASE WHEN @dLottable04 <> '' THEN @dLottable04 ELSE '' END
      AND   Lottable05 = CASE WHEN @dLottable05 <> '' THEN @dLottable05 ELSE '' END

      IF EXISTS (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK)
                 WHERE Configkey = 'ReturnReason'
                 AND   Storerkey = @cStorerkey
                 AND   sValue = '1')
      BEGIN
         IF @cSubReason = ''
         BEGIN
            SET @cReturnReason = 'Y'
         END
      END

      IF EXISTS (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK)
                 WHERE Configkey = 'Allow_OverReceipt'
                 AND   Storerkey = @cStorerkey
                 AND   sValue = '1')
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK)
                    WHERE Configkey = 'ByPassTolerance'
            AND   Storerkey = @cStorerkey
                    AND   sValue <> '1')
         BEGIN
             IF ( @nActQTY + @nBeforeReceivedQty ) > @nQTY AND @cSubReason = ''
             BEGIN
                SET @cOverRcpt = 'Y'
             END
         END
      END

      IF EXISTS (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK)
                 WHERE Configkey = 'ExpiredReason'
                 AND   Storerkey = @cStorerkey
                 AND   sValue = '1')
      BEGIN
         IF (@cTempLotLabel04 = 'EXP_DATE' OR @cTempLotLabel04 = 'EXP-DATE') AND
            (IsNUMERIC(@cSUSR1) = 1) AND rdt.rdtIsValidDate( @cOutField08) = 1
         BEGIN
            IF (CAST(@cSUSR1 AS FLOAT) > 0) AND ((rdt.rdtConvertToDate( @cOutField08) + CAST(@cSUSR1 AS FLOAT) <= GetDate())) AND @cSubReason = ''
            BEGIN
               SET @cExpReason = 'Y'
            END
         END
      END

      -- (james01)
      -- If using ASN return by pallet and lottable label setup and no reason code setup
      IF @nFunc = 581 AND @cLotFlag = 'Y' AND NOT EXISTS
         (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK)
                 WHERE Configkey = 'ReturnReason'
                 AND   Storerkey = @cStorerkey
                 AND   sValue = '1')
      BEGIN
         --process rdt.rdt_receive
         SET @cTempConditionCode =''
         IF (@cConditionCode = '' OR @cConditionCode IS NULL)
            SET @cTempConditionCode = 'OK'
         ELSE
            SET @cTempConditionCode = @cConditionCode

         --set @cPokey value to blank when it is 'NOPO'
         SET @cPOKeyValue = CASE WHEN UPPER(@cPOkey) = 'NOPO' THEN '' ELSE @cPOkey END

         IF ISNULL(@cLOC,'') = '' -- (ChewKP01)
         BEGIN
            SET @cLOC = @cDefaultLOC
         END

         SET @nNOPOFlag = CASE WHEN UPPER(@cPOkey) = 'NOPO' THEN 1 ELSE 0 END

         --update transaction
         EXEC rdt.rdt_Receive
            @nFunc         = @nFunc,--'0',
            @nMobile       = @nMobile,
            @cLangCode     = @cLangCode,
            @nErrNo        = @nErrNo OUTPUT,
            @cErrMsg       = @cErrMsg OUTPUT,
            @cStorerKey    = @cStorerKey,
            @cFacility     = @cFacility,
            @cReceiptKey   = @cReceiptKey,
            @cPOKey     = @cPOKeyValue, --@cPOKey,
            @cToLOC        = @cLOC,
            @cToID         = @cID,
            @cSKUCode      = @cSKU,
            @cSKUUOM       = @cMstUOM_Desc,
            @nSKUQTY       = @nActQTY,
            @cUCC          = '',
            @cUCCSKU       = '',
            @nUCCQTY       = '',
            @cCreateUCC    = '0',
            @cLottable01   = @cLottable01,
            @cLottable02   = @cLottable02,
            @cLottable03   = @cLottable03,
            @dLottable04   = @dLottable04,
            @dLottable05   = @dLottable05,
--            @cLottable06   = '',              --(CS01)
--            @cLottable07   = '',              --(CS01)
--            @cLottable08   = '',              --(CS01)
--            @cLottable09   = '',              --(CS01)
--            @cLottable10   = '',              --(CS01)
--            @cLottable11   = '',              --(CS01)
--            @cLottable12   = '',              --(CS01)
--            @dLottable13   = NULL,            --(CS01)
--            @dLottable14   = NULL,            --(CS01)
--            @dLottable15   = NULL,            --(CS01)
            @nNOPOFlag     = @nNOPOFlag,
            @cConditionCode = @cTempConditionCode,
            @cSubReasonCode = @cSubReason

         IF @nErrno <> 0
         BEGIN
           SET @nErrNo = @nErrNo
           SET @cErrMsg = @cErrMsg
           GOTO Lottables_Fail
         END
         ELSE
         BEGIN
            -- (Vicky06) EventLog - QTY
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '2', -- Receiving
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerKey,
               @cLocation     = @cLOC,
               @cID           = @cID,
               @cSKU          = @cSku,
               @cUOM          = @cMstUOM_Desc,
               @nQTY          = @nActQTY,
               @cReceiptKey   = @cReceiptKey,
               @cPOKey        = @cPOKeyValue,
               @nStep         = @nStep
         END

         -- Prep Msg screen var
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cOutField11 = ''
         SET @cOutField12 = ''
         SET @cOutField13 = ''

         SET @cInField01 = ''
         SET @cInField02 = ''
         SET @cInField03 = ''
         SET @cInField04 = ''
         SET @cInField05 = ''
         SET @cInField06 = ''
         SET @cInField07 = ''
         SET @cInField08 = ''
         SET @cInField09 = ''
         SET @cInField10 = ''
         SET @cInField11 = ''
         SET @cInField12 = ''
         SET @cInField13 = ''

         -- (ChewKP01) Start --
         SET @bSkipSuccessMsg = rdt.RDTGetConfig(@nFunc, 'SkipSuccessMsg', @cStorerKey)

         IF @bSkipSuccessMsg = '1'
         BEGIN
            -- Prepare Screen Variable
            SET @nCTotalBeforeReceivedQty = 0
            SET @nCTotalUQtyExpected = 0

            -- Calculate QTY by preferred UOM  -- (ChewKP01)
            SELECT  @nCTotalUQtyExpected = SUM(QtyExpected), @nCTotalBeforeReceivedQty = SUM(BeforeReceivedQty)  FROM dbo.ReceiptDetail (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
            AND   POKey = CASE WHEN UPPER('@cPokey') = 'NOPO' THEN '' ELSE @cPokey END

            -- Prepare SKU screen var
            SET @cOutField01 = @cReceiptKey
            SET @cOutField02 = @cPOKey
            SET @cOutField03 = '' -- SKU
            SET @cOutField04 = ''
            SET @cOutField05 = ''
            SET @cOutField06 = @nCTotalUQtyExpected      -- (ChewKP01)
            SET @cOutField07 = @cDefaultUOM              -- (ChewKP01)
            SET @cOutField08 = @nCTotalBeforeReceivedQty -- (ChewKP01)
            SET @cOutField09 = @cDefaultUOM              -- (ChewKP01)

            -- Remember current scn & step no
            SET @nPrevScn = @nScn_SKU
            SET @nPrevStep = @nStep_SKU

            SET @nScn = @nScn_SKU
            SET @nStep = @nStep_SKU
            GOTO Quit
         END
         ELSE
         BEGIN
            SET @nScn  = @nScn_MsgSuccess
            SET @nStep = @nStep_MsgSuccess
            GOTO Quit
         END
         -- (ChewKP01) End --
      END

      IF @nFunc = 581 AND @cLotFlag = 'Y' AND EXISTS
         (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK)
                 WHERE Configkey = 'ReturnReason'
                 AND   Storerkey = @cStorerkey
                 AND   sValue = '1')
      BEGIN
         --prepare SerialNo screen variable
         SET @cOutField01 = '' --lottable01
         SET @cOutField02 = '' --lottable02
         SET @cOutField03 = '' --lottable03
         SET @cOutField04 = '' --lottable04
         SET @cOutField05 = '' --lottable05
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cSerialNoFlag = 'Y'
         SET @nScn  = @nScn_SubReason
         SET @nStep = @nStep_SubReason

         SET @nPrevScn  = @nScn_Lottables
         SET @nPrevStep = @nStep_Lottables
      END

      IF (@cReturnReason = 'Y') OR (@cOverRcpt  = 'Y') OR (@cExpReason = 'Y')
      BEGIN
         --prepare SerialNo screen variable
         SET @cOutField01 = '' --lottable01
         SET @cOutField02 = '' --lottable02
         SET @cOutField03 = '' --lottable03
         SET @cOutField04 = '' --lottable04
         SET @cOutField05 = '' --lottable05
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cSerialNoFlag = 'Y'
         SET @nScn  = @nScn_SubReason
         SET @nStep = @nStep_SubReason

         SET @nPrevScn  = @nScn_Lottables
         SET @nPrevStep = @nStep_Lottables
      END

      IF (@cReturnReason <> 'Y') AND (@cOverRcpt <> 'Y') AND (@cExpReason <> 'Y')
      BEGIN
         -- (james04)
         -- Get stored proc name for extended info (james03)
         SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
         IF @cExtendedInfoSP = '0'
            SET @cExtendedInfoSP = ''

         -- Extended info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cZone, @cReceiptKey, @cPOKey, @cSKU, @nQTY,
                    @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cConditionCode, @cSubReason,
                    @cToLOC, @cToID, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

               SET @cSQLParam =
                  '@nMobile         INT, ' +
                  '@nFunc           INT, ' +
                  '@cLangCode       NVARCHAR( 3), ' +
                  '@nStep           INT, ' +
                  '@nInputKey       INT, ' +
                  '@cZone           NVARCHAR( 10), ' +
                  '@cReceiptKey     NVARCHAR( 10), ' +
                  '@cPOKey          NVARCHAR( 10), ' +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@nQTY            INT, ' +
                  '@cLottable01     NVARCHAR( 18), ' +
                  '@cLottable02     NVARCHAR( 18), ' +
                  '@cLottable03     NVARCHAR( 18), ' +
                  '@dLottable04     DATETIME, ' +
                  '@cConditionCode  NVARCHAR( 10), ' +
                  '@cSubReason      NVARCHAR( 10), ' +
                  '@cToLOC          NVARCHAR( 10), ' +
                  '@cToID           NVARCHAR( 18), ' +
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
                  '@nErrNo          INT OUTPUT, ' +
                  '@cErrMsg         NVARCHAR( 20) OUTPUT '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cZone, @cReceiptKey, @cPOKey, @cSKU, @nQTY,
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cConditionCode, @cSubReason,
                  @cLOC, @cID, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            END
         END

        -- Prep ID screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField04 = @cLottable02 -- Lottable02
         SET @cOutField05 = @cLottable03 -- Lottable03
         SET @cOutField06 = rdt.rdtFormatDate(@dLottable04) -- Lottable04
         IF @cPrefUOM_Desc = ''
         BEGIN
            SET @cOutField07 = '' -- @nPrefUOM_Div
            SET @cOutField08 = '' -- @cPrefUOM_Desc
            SET @cOutField10 = '' -- @nActPQTY
            -- Disable pref QTY field
            SET @cFieldAttr10 = 'O' -- (Vicky02)
            SET @cInField10 = '' -- (james02)
         END
         ELSE
         BEGIN
            SET @cOutField07 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
            SET @cOutField08 = @cPrefUOM_Desc
            SET @cOutField10 = CAST( @nActPQTY AS NVARCHAR( 5))
         END
         SET @cOutField09 = @cMstUOM_Desc
         SET @cOutField11 = CAST( @nActMQTY as NVARCHAR( 5))
         SET @cOutField12 = '' -- ID
         SET @cOutField13 = @cExtendedInfo   -- (james04)

         SET @cIDFlag = 'Y'
         SET @nScn  = @nScn_ID
         SET @nStep = @nStep_ID


         SET @nPrevScn  = @nScn_Lottables
         SET @nPrevStep = @nStep_Lottables
      END
   END

   IF @nInputKey = 0 -- ESC
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

      -- Enable / disable field
      IF @cSkipLottable01 = '1' SELECT @cFieldAttr02 = 'O', @cInField01 = ''
      IF @cSkipLottable02 = '1' SELECT @cFieldAttr04 = 'O', @cInField02 = ''
      IF @cSkipLottable03 = '1' SELECT @cFieldAttr06 = 'O', @cInField03 = ''
      IF @cSkipLottable04 = '1' SELECT @cFieldAttr08 = 'O', @cInField04 = ''

     -- Prep QTY screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField04 = @cIVAS

      IF @cPrefUOM_Desc = ''
      BEGIN
         SET @cOutField05 = '' -- @nPrefUOM_Div
         SET @cOutField06 = '' -- @cPrefUOM_Desc
         --SET @cOutField07 = '' -- @nPQTY
         SET @cOutField08 = '' -- @nActPQTY
         -- Disable pref QTY field
         SET @cFieldAttr08 = 'O' -- (Vicky02)
         SET @cInField08 = '' -- (james02)
      END
      ELSE
      BEGIN
         SET @cOutField05 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
         SET @cOutField06 = @cPrefUOM_Desc
         --SET @cOutField07 = CAST( @nPQTY AS NVARCHAR( 5))
         SET @cOutField08 = '' -- @nActPQTY
      END

      SET @cOutField07 = @cMstUOM_Desc
      SET @cOutField09 = ''--CAST( @nMQTY as NVARCHAR( 5))
      --     SET @cOutField11 = '' -- @nActMQTY
      SET @cOutField10 = @cConditionCode

      SET @cInField02 = ''
      SET @cInField04 = ''
      SET @cInField06 = ''
      SET @cInField08 = ''
      SET @cInField10 = ''

      -- Get Config
      SET @bSkipQty = rdt.RDTGetConfig( @nFunc, 'SkipQty', @cStorerKey) -- (ChewKP01)
      --SET @n_ReturnDefaultQTY = rdt.RDTGetConfig( @nFunc, 'ReturnDefaultQTY', @cStorerKey) -- (ChewKP01)

      SET @cReturnDefaultQTY = rdt.RDTGetConfig( 0, 'ReturnDefaultQTY', @cStorerKey)

      IF @bSkipQty = '1' AND @cReturnDefaultQTY > 0 -- (ChewKP01)
      BEGIN
         -- Prepare Screen Variable
         SET @nCTotalBeforeReceivedQty = 0
         SET @nCTotalUQtyExpected = 0

         -- Calculate QTY by preferred UOM  -- (ChewKP01)
         SELECT  @nCTotalUQtyExpected = SUM(QtyExpected), @nCTotalBeforeReceivedQty = SUM(BeforeReceivedQty)  FROM dbo.ReceiptDetail (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   POKey = CASE WHEN UPPER('@cPokey') = 'NOPO' THEN '' ELSE @cPokey END

         -- Prepare SKU screen var
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @cPOKey
         SET @cOutField03 = '' -- SKU
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = @nCTotalUQtyExpected      -- (ChewKP01)
         SET @cOutField07 = @cDefaultUOM              -- (ChewKP01)
         SET @cOutField08 = @nCTotalBeforeReceivedQty -- (ChewKP01)
         SET @cOutField09 = @cDefaultUOM              -- (ChewKP01)

         -- Remember current scn & step no
         SET @nPrevScn = @nScn_SKU
         SET @nPrevStep = @nStep_SKU

         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU
         GOTO Quit
      END
      ELSE
      BEGIN
         -- Go to prev screen
         SET @nScn = @nScn_QTY
         SET @nStep = @nStep_QTY
      END
   END
   GOTO Quit

   Lottables_Fail:
   BEGIN
      -- (Vicky02) - Start
      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      -- (Vicky02) - End

         -- Populate labels and lottables
         IF @cLottable01Label = '' OR @cLottable01Label IS NULL
         BEGIN
            SELECT @cOutField01 = 'Lottable01:'
            SET @cFieldAttr02 = 'O' -- (Vicky02)
         END
         ELSE
         BEGIN
            SELECT @cOutField01 = @cLottable01Label
            SET @cOutField02 = ISNULL(LTRIM(RTRIM(@cLottable01)), '')
         END

         IF @cLottable02Label = '' OR @cLottable02Label IS NULL
         BEGIN
            SELECT @cOutField03 = 'Lottable02:'
            SET @cFieldAttr04 = 'O' -- (Vicky02)
         END
         ELSE
         BEGIN
            SELECT @cOutField03 = @cLottable02Label
            SET @cOutField04 = ISNULL(LTRIM(RTRIM(@cLottable02)), '')
         END

         IF @cLottable03Label = '' OR @cLottable03Label IS NULL
         BEGIN
            SELECT @cOutField05 = 'Lottable03:'
            SET @cFieldAttr06 = 'O' -- (Vicky02)
         END
         ELSE
         BEGIN
            SELECT @cOutField05 = @cLottable03Label
            SET @cOutField06 = ISNULL(LTRIM(RTRIM(@cLottable03)), '')
         END

         IF @cLottable04Label = '' OR @cLottable04Label IS NULL
         BEGIN
            SELECT @cOutField07 = 'Lottable04:'
            SET @cFieldAttr08 = 'O' -- (Vicky02)
         END
         ELSE
         BEGIN
            SELECT  @cOutField07 = @cLottable04Label

            IF @dLottable04 <> NULL AND rdt.rdtIsValidDate( @dLottable04) = 1
            BEGIN
               SET @cOutField08 = RDT.RDTFormatDate(@dLottable04)
            END
            ELSE
               SET @cOutField08 = @cTempLottable04

         END

      GOTO Quit
   END
END
GOTO Quit


/***********************************************************************************
Scn = 1454. Subreason screen
    Subreason (field01, input)
************************************************************************************/
Step_SubReason:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSubReason = @cInField01

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

      -- Verify SubReasonCode
      IF @cSubReason = '' AND @cReturnReason = 'Y'
      BEGIN
         SET @nErrNo = 63327
         SET @cErrMsg = rdt.rdtgetmessage(63327, @cLangCode, 'DSP') --Return Reason
         GOTO SubReason_Fail
      END

      IF @cSubReason = '' AND @cOverRcpt = 'Y'
      BEGIN
         SET @nErrNo = 63328
         SET @cErrMsg = rdt.rdtgetmessage(63328, @cLangCode, 'DSP') --OverRcv Reason
         GOTO SubReason_Fail
      END

      IF @cSubReason = '' AND @cExpReason = 'Y'
      BEGIN
         SET @nErrNo = 63329
         SET @cErrMsg = rdt.rdtgetmessage(63329, @cLangCode, 'DSP') --Expired Reason
         GOTO SubReason_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                     WHERE Listname = 'ASNSUBRSN'
                     AND   Code = @cSubReason)
      BEGIN
         SET @nErrNo = 63330
         SET @cErrMsg = rdt.rdtgetmessage(63330, @cLangCode, 'DSP') --Bad Subreason
         GOTO SubReason_Fail
      END

      -- Get stored proc name for extended info (james03)
      SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
      IF @cExtendedInfoSP = '0'
         SET @cExtendedInfoSP = ''

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cZone, @cReceiptKey, @cPOKey, @cSKU, @nQTY,
                 @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cConditionCode, @cSubReason,
                 @cToLOC, @cToID, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR( 3), ' +
               '@nStep           INT, ' +
               '@nInputKey       INT, ' +
               '@cZone           NVARCHAR( 10), ' +
               '@cReceiptKey     NVARCHAR( 10), ' +
               '@cPOKey          NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT, ' +
               '@cLottable01     NVARCHAR( 18), ' +
               '@cLottable02     NVARCHAR( 18), ' +
               '@cLottable03     NVARCHAR( 18), ' +
               '@dLottable04     DATETIME, ' +
               '@cConditionCode  NVARCHAR( 10), ' +
               '@cSubReason      NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@cToID           NVARCHAR( 18), ' +
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cZone, @cReceiptKey, @cPOKey, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cConditionCode, @cSubReason,
               @cLOC, @cID, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         END
      END

      IF @nFunc = 552
      BEGIN
         -- Prep ID screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)

         IF @cLotFlag = 'Y'
         BEGIN
            SET @cOutField04 = @cLottable02 -- Lottable02
            SET @cOutField05 = @cLottable03 -- Lottable03
            SET @cOutField06 = rdt.rdtFormatDate(@dLottable04) -- Lottable04
         END
         ELSE
         BEGIN
           SET @cOutField04 = ''
           SET @cOutField05 = ''
           SET @cOutField06 = ''
         END

         -- Extended
         IF @cPrefUOM_Desc = ''
         BEGIN
            SET @cOutField07 = '' -- @nPrefUOM_Div
            SET @cOutField08 = '' -- @cPrefUOM_Desc
            SET @cOutField10 = '' -- @nActPQTY
            -- Disable pref QTY field
            SET @cFieldAttr10 = 'O' -- (Vicky02)
            SET @cInField10 = '' -- (james02)
         END
         ELSE
         BEGIN
            SET @cOutField07 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
            SET @cOutField08 = @cPrefUOM_Desc
            SET @cOutField10 = CAST( @nActPQTY AS NVARCHAR( 5))
         END

         SET @cOutField09 = @cMstUOM_Desc
         SET @cOutField11 = CAST( @nActMQTY as NVARCHAR( 5))
         SET @cOutField12 = ''
         SET @cOutField13 = @cExtendedInfo

         SET @nScn  = @nScn_ID
         SET @nStep = @nStep_ID

         SET @nPrevScn  = @nScn_SubReason
         SET @nPrevStep = @nStep_SubReason
      END
      ELSE
         -- (james01)
         -- If using ASN return by pallet and no lottable label setup and no reason code setup
         IF @nFunc = 581
         BEGIN
            --process rdt.rdt_receive
            SET @cTempConditionCode =''
            IF (@cConditionCode = '' OR @cConditionCode IS NULL)
               SET @cTempConditionCode = 'OK'
            ELSE
               SET @cTempConditionCode = @cConditionCode


            --set @cPokey value to blank when it is 'NOPO'
            SET @cPOKeyValue = CASE WHEN UPPER(@cPOkey) = 'NOPO' THEN '' ELSE @cPOkey END
            SET @nNOPOFlag = CASE WHEN UPPER(@cPOkey) = 'NOPO' THEN 1 ELSE 0 END

            --update transaction
            EXEC rdt.rdt_Receive
               @nFunc         = @nFunc,--'0',
               @nMobile       = @nMobile,
               @cLangCode     = @cLangCode,
               @nErrNo        = @nErrNo OUTPUT,
               @cErrMsg       = @cErrMsg OUTPUT,
               @cStorerKey    = @cStorerKey,
               @cFacility     = @cFacility,
               @cReceiptKey   = @cReceiptKey,
               @cPOKey        = @cPOKeyValue, --@cPOKey,
               @cToLOC        = @cLOC,
               @cToID         = @cID,
               @cSKUCode      = @cSKU,
               @cSKUUOM       = @cMstUOM_Desc,
               @nSKUQTY       = @nActQTY,
               @cUCC          = '',
               @cUCCSKU       = '',
               @nUCCQTY       = '',
               @cCreateUCC    = '0',
               @cLottable01   = @cLottable01,
               @cLottable02   = @cLottable02,
               @cLottable03   = @cLottable03,
               @dLottable04   = @dLottable04,
               @dLottable05   = @dLottable05,
--               @cLottable06   = '',              --(CS01)
--               @cLottable07   = '',              --(CS01)
--               @cLottable08   = '',              --(CS01)
--               @cLottable09   = '',              --(CS01)
--               @cLottable10   = '',              --(CS01)
--               @cLottable11   = '',              --(CS01)
--               @cLottable12   = '',              --(CS01)
--               @dLottable13   = NULL,            --(CS01)
--               @dLottable14   = NULL,            --(CS01)
--               @dLottable15   = NULL,            --(CS01)
               @nNOPOFlag     = @nNOPOFlag,
               @cConditionCode = @cTempConditionCode,
               @cSubReasonCode = @cSubReason

            IF @nErrno <> 0
            BEGIN
               SET @nErrNo = @nErrNo
               SET @cErrMsg = @cErrMsg
               GOTO QTY_Fail
            END
            ELSE
            BEGIN
               -- (Vicky06) EventLog - QTY
               EXEC RDT.rdt_STD_EventLog
                  @cActionType   = '2', -- Receiving
                  @cUserID       = @cUserName,
                  @nMobileNo     = @nMobile,
                  @nFunctionID   = @nFunc,
                  @cFacility     = @cFacility,
                  @cStorerKey    = @cStorerKey,
                  @cLocation     = @cLOC,
                  @cID           = @cID,
                  @cSKU          = @cSku,
                  @cUOM          = @cMstUOM_Desc,
                  @nQTY          = @nActQTY,
                  @cReceiptKey   = @cReceiptKey,
                  @cPOKey        = @cPOKeyValue,
                  @nStep         = @nStep
            END

          -- Prep Msg screen var
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = ''
            SET @cOutField06 = ''
            SET @cOutField07 = ''
            SET @cOutField08 = ''
            SET @cOutField09 = ''
            SET @cOutField10 = ''
            SET @cOutField11 = ''
            SET @cOutField12 = ''
            SET @cOutField13 = ''

            SET @cInField01 = ''
            SET @cInField02 = ''
            SET @cInField03 = ''
            SET @cInField04 = ''
            SET @cInField05 = ''
            SET @cInField06 = ''
            SET @cInField07 = ''
            SET @cInField08 = ''
            SET @cInField09 = ''
            SET @cInField10 = ''
            SET @cInField11 = ''
            SET @cInField12 = ''
            SET @cInField13 = ''

            -- (ChewKP01) Start --
            SET @bSkipSuccessMsg = rdt.RDTGetConfig(@nFunc, 'SkipSuccessMsg', @cStorerKey)

            IF @bSkipSuccessMsg = '1'
            BEGIN
               -- Prepare Screen Variable
               SET @nCTotalBeforeReceivedQty = 0
               SET @nCTotalUQtyExpected = 0

               -- Calculate QTY by preferred UOM  -- (ChewKP01)
               SELECT  @nCTotalUQtyExpected = SUM(QtyExpected), @nCTotalBeforeReceivedQty = SUM(BeforeReceivedQty)  FROM dbo.ReceiptDetail (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               AND   POKey = CASE WHEN UPPER('@cPokey') = 'NOPO' THEN '' ELSE @cPokey END


               -- Prepare SKU screen var
               SET @cOutField01 = @cReceiptKey
               SET @cOutField02 = @cPOKey
               SET @cOutField03 = '' -- SKU
               SET @cOutField04 = ''
               SET @cOutField05 = ''
               SET @cOutField06 = @nCTotalUQtyExpected      -- (ChewKP01)
               SET @cOutField07 = @cDefaultUOM              -- (ChewKP01)
               SET @cOutField08 = @nCTotalBeforeReceivedQty -- (ChewKP01)
               SET @cOutField09 = @cDefaultUOM              -- (ChewKP01)

               -- Remember current scn & step no
               SET @nPrevScn = @nScn_SKU
               SET @nPrevStep = @nStep_SKU

               SET @nScn = @nScn_SKU
               SET @nStep = @nStep_SKU
               GOTO Quit
            END
            ELSE
            BEGIN
               SET @nScn  = @nScn_MsgSuccess
               SET @nStep = @nStep_MsgSuccess
               GOTO Quit
            END
            -- (ChewKP01) End --
         END
      END

      IF @nInputKey = 0 -- ESC
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

         -- Prepare previous screen var
         IF @nPrevScn  = @nScn_Lottables
         BEGIN
            IF @cLottable01Label = '' OR @cLottable01Label IS NULL
            BEGIN
               SET @cOutField01 = 'Lottable01:'
               SET @cInField02 = ''
               SET @cFieldAttr02 = 'O' -- (Vicky02)
            END
            ELSE
            BEGIN
               SELECT @cOutField01 = @cLottable01Label
               SET @cOutField02 = ISNULL(LTRIM(RTRIM(@cLottable01)), '')
            END

            IF @cLottable02Label = '' OR @cLottable02Label IS NULL
            BEGIN
               SET @cOutField03 = 'Lottable02:'
               SET @cInField04 = ''
               SET @cFieldAttr04 = 'O' -- (Vicky02)
            END
            ELSE
            BEGIN
               SELECT @cOutField03 = @cLottable02Label
               SET @cOutField04 = ISNULL(LTRIM(RTRIM(@cLottable02)), '')
            END

            IF @cLottable03Label = '' OR @cLottable03Label IS NULL
            BEGIN
               SET @cOutField05 = 'Lottable03:'
               SET @cInField06 = ''
               SET @cFieldAttr06 = 'O' -- (Vicky02)
            END
            ELSE
            BEGIN
               SELECT @cOutField05 = @cLottable03Label
               SET @cOutField06 = ISNULL(LTRIM(RTRIM(@cLottable03)), '')
            END

            IF @cLottable04Label = '' OR @cLottable04Label IS NULL
            BEGIN
               SET @cOutField07 = 'Lottable04:'
               SET @cInField08 = ''
               SET @cFieldAttr08 = 'O' -- (Vicky02)
            END
            ELSE
            BEGIN
               SELECT  @cOutField07 = @cLottable04Label
               IF rdt.rdtIsValidDate( @dLottable04) = 1
               BEGIN
                  SET @cOutField08 = RDT.RDTFormatDate( @dLottable04)
               END
            END

            EXEC rdt.rdtSetFocusField @nMobile, 1   --set focus to 1st field

            SET @nScn = @nScn_Lottables
            SET @nStep = @nStep_Lottables
         END
         ELSE IF @nPrevScn  = @nScn_QTY
         BEGIN
            -- Prep QTY screen var
            SET @cOutField01 = @cSKU
            SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)
            SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
            SET @cOutField04 = @cIVAS

            IF @cPrefUOM_Desc = ''
            BEGIN
               SET @cOutField05 = '' -- @nPrefUOM_Div
               SET @cOutField06 = '' -- @cPrefUOM_Desc
               --SET @cOutField07 = '' -- @nPQTY
               SET @cOutField08 = '' -- @nActPQTY
               -- Disable pref QTY field
               SET @cFieldAttr08 = 'O' -- (Vicky02)
               SET @cInField08 = '' -- (james02)
            END
            ELSE
            BEGIN
               SET @cOutField05 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
               SET @cOutField06 = @cPrefUOM_Desc
               --SET @cOutField07 = CAST( @nPQTY AS NVARCHAR( 5))
               SET @cOutField08 = '' -- @nActPQTY
            END

            SET @cOutField07 = @cMstUOM_Desc
            SET @cOutField09 = ''--CAST( @nMQTY as NVARCHAR( 5))
            --     SET @cOutField11 = '' -- @nActMQTY
            SET @cOutField10 = @cConditionCode -- ConditionCode

            SET @cInField02 = ''
            SET @cInField04 = ''
            SET @cInField06 = ''
            SET @cInField08 = ''
            SET @cInField10 = ''

            -- Get Config
            SET @bSkipQty = rdt.RDTGetConfig( @nFunc, 'SkipQty', @cStorerKey) -- (ChewKP01)
            --SET @n_ReturnDefaultQTY = rdt.RDTGetConfig( @nFunc, 'ReturnDefaultQTY', @cStorerKey) -- (ChewKP01)


            IF @bSkipQty = '1' AND @cReturnDefaultQTY > 0 -- (ChewKP01)
            BEGIN
               -- Prepare Screen Variable
               SET @nCTotalBeforeReceivedQty = 0
               SET @nCTotalUQtyExpected = 0

               -- Calculate QTY by preferred UOM  -- (ChewKP01)
               SELECT  @nCTotalUQtyExpected = SUM(QtyExpected), @nCTotalBeforeReceivedQty = SUM(BeforeReceivedQty)  FROM dbo.ReceiptDetail (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               AND   POKey = CASE WHEN UPPER('@cPokey') = 'NOPO' THEN '' ELSE @cPokey END

               -- Prepare SKU screen var
               SET @cOutField01 = @cReceiptKey
               SET @cOutField02 = @cPOKey
               SET @cOutField03 = '' -- SKU
               SET @cOutField04 = ''
               SET @cOutField05 = ''
               SET @cOutField06 = @nCTotalUQtyExpected      -- (ChewKP01)
               SET @cOutField07 = @cDefaultUOM              -- (ChewKP01)
               SET @cOutField08 = @nCTotalBeforeReceivedQty -- (ChewKP01)
               SET @cOutField09 = @cDefaultUOM              -- (ChewKP01)

               -- Remember current scn & step no
               SET @nPrevScn = @nScn_SKU
               SET @nPrevStep = @nStep_SKU

               SET @nScn = @nScn_SKU
               SET @nStep = @nStep_SKU
               GOTO Quit
            END
            ELSE
            BEGIN
               -- Go to prev screen
               SET @nScn = @nScn_QTY
               SET @nStep = @nStep_QTY
            END
         END
      END
      GOTO Quit

      SubReason_Fail:
      BEGIN
         SET @cOutField01 = @cSubReason  -- Subreason
      END
END
GOTO Quit


/********************************************************************************
Scn = 1455. ID screen
   SKU       (field01)
   SKUDescr  (field02)
   SKUDescr  (field03)
   LOTTABLE2 (field04)
   LOTTABLE3 (field05)
   LOTTABLE4 (field06)
   UOM Factor(field07)
   PUOM MUOM (field08, field09)
   QTY RTN   (field10, field11)
   ID        (field12, input)
********************************************************************************/
Step_ID:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @nIDExists INT
      SET @nIDExists = 0

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
      SET @cID = @cInField12 -- ID

      IF @cID <> ''
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK)
         WHERE Configkey = 'DisAllowDuplicateIdsOnRFRcpt'
         AND   sValue = '1'
         AND   Storerkey = @cStorerkey)
         BEGIN
            SELECT @nIDExists = 1
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LLI.ID = @cID
            --AND   LLI.Storerkey = @cStorerkey
            AND   LOC.Facility = @cFacility
            AND   LLI.QTY > 0

            IF @nIDExists > 0
            BEGIN
               SET @nErrNo = 63331
               SET @cErrMsg = rdt.rdtgetmessage(63331, @cLangCode, 'DSP') -- Duplicate ID
               GOTO ID_Fail
            END
         END
      END -- ID <> ''

      SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cZone, @cReceiptKey, @cPOKey, @cSKU, @nQTY,
                 @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cConditionCode, @cSubReason, @cToLOC, @cToID, 
                 @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR( 3), ' +
               '@nStep           INT, ' +
               '@nInputKey       INT, ' +
               '@cFacility       NVARCHAR( 5),  ' + 
               '@cStorerKey      NVARCHAR( 15), ' + 
               '@cZone           NVARCHAR( 10), ' +
               '@cReceiptKey     NVARCHAR( 10), ' +
               '@cPOKey          NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT, ' +
               '@cLottable01     NVARCHAR( 18), ' +
               '@cLottable02     NVARCHAR( 18), ' +
               '@cLottable03     NVARCHAR( 18), ' +
               '@dLottable04     DATETIME, ' +
               '@cConditionCode  NVARCHAR( 10), ' +
               '@cSubReason      NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@cToID           NVARCHAR( 18), ' +
               '@nErrNo          INT OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cZone, @cReceiptKey, @cPOKey, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cConditionCode, @cSubReason, @cLOC, @cID, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Prep LOC screen var
      SET @cDefaultLOC = ''

      SELECT @cDefaultLOC = RTRIM(sValue) FROM RDT.STORERCONFIG WITH (NOLOCK)
      WHERE Configkey = 'ReturnDefaultToLOC'
      AND   Storerkey = @cStorerkey

      SET @cPickFaceFlag = 'N'

      IF @cDefaultLOC = 'PICKFACE'
      BEGIN
         SET @cDefaultLOC = ''
         SELECT @cDefaultLOC = IsNULL(LOC, '')
         FROM dbo.SKUxLOC WITH (NOLOCK)
         WHERE SKU = @cSKU
         AND   Storerkey = @cStorerkey
         AND   (LocationType = 'PICK' OR LocationType = 'CASE')

         SET @cPickFaceFlag = 'Y'

         IF @cDefaultLOC = ''
         BEGIN
            SET @nErrNo = 63332
            SET @cErrMsg = rdt.rdtgetmessage(63332, @cLangCode, 'DSP') -- No Pick Face
         END
      END

      -- Get stored proc name for extended info (james03)
      SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
      IF @cExtendedInfoSP = '0'
         SET @cExtendedInfoSP = ''

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cZone, @cReceiptKey, @cPOKey, @cSKU, @nQTY,
                 @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cConditionCode, @cSubReason,
                 @cToLOC, @cToID, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@nFunc           INT, ' +
               '@cLangCode       NVARCHAR( 3), ' +
               '@nStep           INT, ' +
               '@nInputKey       INT, ' +
               '@cZone           NVARCHAR( 10), ' +
               '@cReceiptKey     NVARCHAR( 10), ' +
               '@cPOKey          NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT, ' +
               '@cLottable01     NVARCHAR( 18), ' +
               '@cLottable02     NVARCHAR( 18), ' +
               '@cLottable03     NVARCHAR( 18), ' +
               '@dLottable04     DATETIME, ' +
               '@cConditionCode  NVARCHAR( 10), ' +
               '@cSubReason      NVARCHAR( 10), ' +
               '@cToLOC          NVARCHAR( 10), ' +
               '@cToID           NVARCHAR( 18), ' +
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo          INT OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cZone, @cReceiptKey, @cPOKey, @cSKU, @nQTY,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cConditionCode, @cSubReason,
               @cLOC, @cID, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         END
      END

      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)

      IF @cLotFlag = 'Y'
      BEGIN
         SET @cOutField04 = @cLottable02 -- Lottable02
         SET @cOutField05 = @cLottable03 -- Lottable03
         SET @cOutField06 = rdt.rdtFormatDate(@dLottable04) -- Lottable04
      END
      ELSE
      BEGIN
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
      END

      IF @cPrefUOM_Desc = ''
      BEGIN
         SET @cOutField07 = '' -- @nPrefUOM_Div
         SET @cOutField08 = '' -- @cPrefUOM_Desc
         SET @cOutField10 = '' -- @nActPQTY
         -- Disable pref QTY field
         SET @cFieldAttr10 = 'O' -- (Vicky02)
         SET @cInField10 = '' -- (james02)
      END
      ELSE
      BEGIN
         SET @cOutField07 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
         SET @cOutField08 = @cPrefUOM_Desc
         SET @cOutField10 = CAST( @nActPQTY AS NVARCHAR( 5))
      END

      SET @cOutField09 = @cMstUOM_Desc
      SET @cOutField11 = CAST( @nActMQTY as NVARCHAR( 5))
      SET @cOutField12 = @cID-- ID
      SET @cOutField13 = CASE WHEN ISNULL( @cDefaultLOC, '') = '' THEN @cExtendedInfo ELSE @cDefaultLOC END -- If default loc -- (james03)

      SET @nScn  = @nScn_LOC
      SET @nStep = @nStep_LOC

      IF @cLotFlag = 'Y' AND ( (@cReturnReason <> 'Y') AND (@cOverRcpt <> 'Y') AND (@cExpReason <> 'Y'))
      BEGIN
         SET @nPrevScn  = @nScn_Lottables
         SET @nPrevStep = @nStep_Lottables
      END
      ELSE IF @cLotFlag <> 'Y' AND ( (@cReturnReason = 'Y') OR (@cOverRcpt = 'Y') OR (@cExpReason = 'Y'))
      BEGIN
         SET @nPrevScn  = @nScn_Subreason
         SET @nPrevStep = @nStep_Subreason
      END
      ELSE IF @cLotFlag <> 'Y' AND ( (@cReturnReason <> 'Y') OR (@cOverRcpt <> 'Y') OR (@cExpReason <> 'Y'))
      BEGIN
         SET @nPrevScn  = @nScn_QTY
         SET @nPrevStep = @nStep_QTY
      END
   END

   IF @nInputKey = 0 -- ESC
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

      -- Prepare previous screen var
      IF @nPrevScn  = @nScn_Lottables
      BEGIN
         -- Populate labels and lottables
         IF @cLottable01Label = '' OR @cLottable01Label IS NULL
         BEGIN
            SET @cOutField01 = 'Lottable01:'
            SET @cInField02 = ''
            SET @cFieldAttr02 = 'O' -- (Vicky02)
         END
         ELSE
         BEGIN
            SELECT @cOutField01 = @cLottable01Label
            SET @cOutField02 = ISNULL(LTRIM(RTRIM(@cLottable01)), '')
         END

         IF @cLottable02Label = '' OR @cLottable02Label IS NULL
         BEGIN
            SET @cOutField03 = 'Lottable02:'
            SET @cInField04 = ''
            SET @cFieldAttr04 = 'O' -- (Vicky02)
         END
         ELSE
         BEGIN
            SELECT @cOutField03 = @cLottable02Label
          SET @cOutField04 = ISNULL(LTRIM(RTRIM(@cLottable02)), '')
         END

         IF @cLottable03Label = '' OR @cLottable03Label IS NULL
         BEGIN
            SET @cOutField05 = 'Lottable03:'
            SET @cInField06 = ''
            SET @cFieldAttr06 = 'O' -- (Vicky02)
         END
         ELSE
         BEGIN
            SELECT @cOutField05 = @cLottable03Label
            SET @cOutField06 = ISNULL(LTRIM(RTRIM(@cLottable03)), '')
         END

         IF @cLottable04Label = '' OR @cLottable04Label IS NULL
         BEGIN
            SET @cOutField07 = 'Lottable04:'
            SET @cInField08 = ''
            SET @cFieldAttr08 = 'O' -- (Vicky02)
         END
         ELSE
         BEGIN
            SELECT  @cOutField07 = @cLottable04Label
            IF rdt.rdtIsValidDate( @dLottable04) = 1
            BEGIN
               SET @cOutField08 = RDT.RDTFormatDate( @dLottable04)
            END
         END

         EXEC rdt.rdtSetFocusField @nMobile, 1   --set focus to 1st field

         SET @cInField02 = ''
         SET @cInField04 = ''
         SET @cInField06 = ''
         SET @cInField08 = ''
         SET @cInField10 = ''

         SET @nScn = @nScn_Lottables
         SET @nStep = @nStep_Lottables

         SET @nPrevScn  = @nScn_QTY
         SET @nPrevStep = @nStep_QTY
      END
      ELSE IF @nPrevScn  = @nScn_QTY
      BEGIN
         -- Prep QTY screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField04 = @cIVAS

         IF @cPrefUOM_Desc = ''
         BEGIN
            SET @cOutField05 = '' -- @nPrefUOM_Div
            SET @cOutField06 = '' -- @cPrefUOM_Desc
            --SET @cOutField07 = '' -- @nPQTY
            SET @cOutField08 = '' -- @nActPQTY
            -- Disable pref QTY field
            SET @cFieldAttr08 = 'O' -- (Vicky02)
            SET @cInField08 = '' -- (james02)
         END
         ELSE
         BEGIN
            SET @cOutField05 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
            SET @cOutField06 = @cPrefUOM_Desc
            --SET @cOutField07 = CAST( @nPQTY AS NVARCHAR( 5))
            SET @cOutField08 = '' -- @nActPQTY
         END

         SET @cOutField07 = @cMstUOM_Desc
         SET @cOutField09 = ''--CAST( @nMQTY as NVARCHAR( 5))
          --     SET @cOutField11 = '' -- @nActMQTY
         SET @cOutField10 = @cConditionCode -- ConditionCode

         -- Go to prev screen
         SET @nScn = @nScn_QTY
         SET @nStep = @nStep_QTY

         SET @nPrevScn  = @nScn_SKU
         SET @nPrevStep = @nStep_SKU
      END
      ELSE IF @nPrevScn  = @nScn_SubReason
      BEGIN
         SET @cOutField01 = @cSubReason
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- SubReason

         SET @nScn = @nScn_SubReason
         SET @nStep = @nStep_SubReason

         IF @cLotFlag = 'Y'
         BEGIN
            SET @nPrevScn  = @nScn_Lottables
            SET @nPrevStep = @nStep_Lottables
         END
         ELSE
         BEGIN
            SET @nPrevScn  = @nScn_QTY
            SET @nPrevStep = @nStep_QTY
         END
      END
   END
   GOTO Quit

   ID_Fail:
   BEGIN
      SET @cOutField12 = '' -- ID
   END
END
GOTO Quit


/********************************************************************************
Scn = 1456. LOC screen
   SKU       (field01)
   SKUDescr  (field02)
   SKUDescr  (field03)
   LOTTABLE2 (field04)
   LOTTABLE3 (field05)
   LOTTABLE4 (field06)
   UOM Factor(field07)
   PUOM MUOM (field08, field09)
   QTY RTN   (field10, field11)
   ID        (field12)
   LOC       (field13, input)
********************************************************************************/
Step_LOC:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField13 -- LOC

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

      IF @cLOC = ''
      BEGIN
            SET @nErrNo = 63333
            SET @cErrMsg = rdt.rdtgetmessage(63333, @cLangCode, 'DSP') -- LOC needed
            GOTO LOC_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                     WHERE LOC = @cLOC)
      BEGIN
            SET @nErrNo = 63334
            SET @cErrMsg = rdt.rdtgetmessage(63334, @cLangCode, 'DSP') -- Invalid LOC
            GOTO LOC_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                     WHERE LOC = @cLOC
                     AND   Facility = @cFacility)
      BEGIN
           SET @nErrNo = 63335
            SET @cErrMsg = rdt.rdtgetmessage(63335, @cLangCode, 'DSP') -- Diff facility
            GOTO LOC_Fail
      END

      --process rdt.rdt_receive
      SET @cTempConditionCode =''
      IF (@cConditionCode = '' OR @cConditionCode IS NULL)
         SET @cTempConditionCode = 'OK'
      ELSE
         SET @cTempConditionCode = @cConditionCode


      --set @cPokey value to blank when it is 'NOPO'
      SET @cPOKeyValue = CASE WHEN UPPER(@cPOkey) = 'NOPO' THEN '' ELSE @cPOkey END
      SET @nNOPOFlag = CASE WHEN UPPER(@cPOkey) = 'NOPO' THEN 1 ELSE 0 END

  --update transaction
  EXEC rdt.rdt_Receive
   @nFunc         = @nFunc,--'0',
   @nMobile       = @nMobile,
   @cLangCode     = @cLangCode,
   @nErrNo        = @nErrNo OUTPUT,
   @cErrMsg       = @cErrMsg OUTPUT,
   @cStorerKey    = @cStorerKey,
   @cFacility     = @cFacility,
   @cReceiptKey   = @cReceiptKey,
   @cPOKey        = @cPOKeyValue, --@cPOKey,
   @cToLOC        = @cLOC,
   @cToID         = @cID,
   @cSKUCode      = @cSKU,
   @cSKUUOM       = @cMstUOM_Desc,
   @nSKUQTY       = @nActQTY,
   @cUCC          = '',
   @cUCCSKU       = '',
   @nUCCQTY       = '',
   @cCreateUCC    = '0',
   @cLottable01   = @cLottable01,
   @cLottable02   = @cLottable02,
   @cLottable03   = @cLottable03,
   @dLottable04   = @dLottable04,
   @dLottable05   = @dLottable05,
--   @cLottable06   = '',              --(CS01)
--   @cLottable07   = '',              --(CS01)
--   @cLottable08   = '',              --(CS01)
--   @cLottable09   = '',              --(CS01)
--   @cLottable10   = '',              --(CS01)
--   @cLottable11   = '',              --(CS01)
--   @cLottable12   = '',              --(CS01)
--   @dLottable13   = NULL,            --(CS01)
--   @dLottable14   = NULL,            --(CS01)
--   @dLottable15   = NULL,            --(CS01)
   @nNOPOFlag     = @nNOPOFlag,
   @cConditionCode = @cTempConditionCode,
   @cSubReasonCode = @cSubReason

  IF @nErrno <> 0
      BEGIN
        SET @nErrNo = @nErrNo
        SET @cErrMsg = @cErrMsg
        GOTO LOC_FAIL
      END
      ELSE
      BEGIN
          -- (Vicky06) EventLog - QTY
          EXEC RDT.rdt_STD_EventLog
             @cActionType   = '2', -- Receiving
             @cUserID       = @cUserName,
             @nMobileNo     = @nMobile,
             @nFunctionID   = @nFunc,
             @cFacility     = @cFacility,
             @cStorerKey    = @cStorerKey,
             @cLocation     = @cLOC,
             @cID           = @cID,
             @cSKU          = @cSku,
             @cUOM          = @cMstUOM_Desc,
             @nQTY          = @nActQTY,
             @cReceiptKey   = @cReceiptKey,
             @cPOKey        = @cPOKeyValue,
             @nStep         = @nStep
      END

       -- Prep Msg screen var
  SET @cOutField01 = ''
  SET @cOutField02 = ''
  SET @cOutField03 = ''
  SET @cOutField04 = ''
  SET @cOutField05 = ''
  SET @cOutField06 = ''
  SET @cOutField07 = ''
  SET @cOutField08 = ''
  SET @cOutField09 = ''
      SET @cOutField10 = ''
  SET @cOutField11 = ''
  SET @cOutField12 = ''
      SET @cOutField13 = ''

  SET @cInField01 = ''
  SET @cInField02 = ''
  SET @cInField03 = ''
  SET @cInField04 = ''
  SET @cInField05 = ''
  SET @cInField06 = ''
  SET @cInField07 = ''
  SET @cInField08 = ''
  SET @cInField09 = ''
      SET @cInField10 = ''
  SET @cInField11 = ''
  SET @cInField12 = ''
      SET @cInField13 = ''

   -- (ChewKP01) Start --
   SET @bSkipSuccessMsg = rdt.RDTGetConfig(@nFunc, 'SkipSuccessMsg', @cStorerKey)

    IF @bSkipSuccessMsg = '1'
    BEGIN
    -- Prepare Screen Variable
     SET @nCTotalBeforeReceivedQty = 0
     SET @nCTotalUQtyExpected = 0

     -- Calculate QTY by preferred UOM  -- (ChewKP01)
     SELECT  @nCTotalUQtyExpected = SUM(QtyExpected), @nCTotalBeforeReceivedQty = SUM(BeforeReceivedQty)  FROM dbo.ReceiptDetail (NOLOCK)
     WHERE ReceiptKey = @cReceiptKey
     AND   POKey = CASE WHEN UPPER('@cPokey') = 'NOPO' THEN '' ELSE @cPokey END


     -- Prepare SKU screen var
     SET @cOutField01 = @cReceiptKey
     SET @cOutField02 = @cPOKey
     SET @cOutField03 = '' -- SKU
     SET @cOutField04 = ''
     SET @cOutField05 = ''
     SET @cOutField06 = @nCTotalUQtyExpected      -- (ChewKP01)
     SET @cOutField07 = @cDefaultUOM              -- (ChewKP01)
     SET @cOutField08 = @nCTotalBeforeReceivedQty -- (ChewKP01)
     SET @cOutField09 = @cDefaultUOM              -- (ChewKP01)

    -- Remember current scn & step no
            SET @nPrevScn = @nScn_SKU
            SET @nPrevStep = @nStep_SKU

    SET @nScn = @nScn_SKU
    SET @nStep = @nStep_SKU
    GOTO Quit
   END
   ELSE
   BEGIN
    SET @nScn  = @nScn_MsgSuccess
    SET @nStep = @nStep_MsgSuccess
    GOTO Quit
   END
   -- (ChewKP01) End --
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
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

      -- Prepare previous screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)

      IF @cLotFlag = 'Y'
      BEGIN
         SET @cOutField04 = @cLottable02 -- Lottable02
         SET @cOutField05 = @cLottable03 -- Lottable03
         SET @cOutField06 = rdt.rdtFormatDate(@dLottable04) -- Lottable04
      END
      ELSE
      BEGIN
        SET @cOutField04 = ''
        SET @cOutField05 = ''
        SET @cOutField06 = ''
      END

      IF @cPrefUOM_Desc = ''
      BEGIN
         SET @cOutField07 = '' -- @nPrefUOM_Div
         SET @cOutField08 = '' -- @cPrefUOM_Desc
         SET @cOutField10 = '' -- @nActPQTY

         -- Disable pref QTY field
         SET @cFieldAttr10 = 'O' -- (Vicky02)
         SET @cInField10 = '' -- (james02)
      END
      ELSE
      BEGIN
         SET @cOutField07 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
         SET @cOutField08 = @cPrefUOM_Desc
         SET @cOutField10 = CAST( @nActPQTY AS NVARCHAR( 5))
      END

      SET @cOutField09 = @cMstUOM_Desc
      SET @cOutField11 = CAST( @nActMQTY as NVARCHAR( 5))
      SET @cOutField12 = '' -- ID
      SET @cOutField13 = @cExtendedInfo

      -- Go to prev screen
      SET @nScn = @nScn_ID
      SET @nStep = @nStep_ID
   END
   GOTO Quit

   LOC_Fail:
   BEGIN
      SET @cLOC = ''
      SET @cOutField13 = '' -- LOC
      GOTO Quit
   END
END
GOTO Quit

/********************************************************************************
Scn = 1457. Message. 'SKU successfully received'
   Option (field01)
********************************************************************************/
Step_MsgSuccess:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''

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

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU


      SET @nCTotalBeforeReceivedQty = 0
      SET @nCTotalUQtyExpected = 0

      -- Calculate QTY by preferred UOM  -- (ChewKP01)
      SELECT  @nCTotalUQtyExpected = SUM(QtyExpected), @nCTotalBeforeReceivedQty = SUM(BeforeReceivedQty)  FROM dbo.ReceiptDetail (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   POKey = CASE WHEN UPPER('@cPokey') = 'NOPO' THEN '' ELSE @cPokey END

      -- Prepare SKU screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- SKUDecr
      SET @cOutField05 = '' -- SKUDecr
      SET @cOutField06 = @nCTotalUQtyExpected      -- (ChewKP01)
      SET @cOutField07 = @cDefaultUOM              -- (ChewKP01)
      SET @cOutField08 = @nCTotalBeforeReceivedQty -- (ChewKP01)
      SET @cOutField09 = @cDefaultUOM              -- (ChewKP01)
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      SET @cInField03 = ''

      -- Back to SKU screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   IF @nInputKey = 0 -- ESC
   BEGIN

     -- Calculate QTY by preferred UOM  -- (ChewKP01)
     SELECT  @nCTotalUQtyExpected = SUM(QtyExpected), @nCTotalBeforeReceivedQty = SUM(BeforeReceivedQty)  FROM dbo.ReceiptDetail (NOLOCK)
     WHERE ReceiptKey = @cReceiptKey
     AND   POKey = CASE WHEN UPPER('@cPokey') = 'NOPO' THEN '' ELSE @cPokey END

      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = @nCTotalUQtyExpected      -- (ChewKP01)
      SET @cOutField07 = @cDefaultUOM              -- (ChewKP01)
      SET @cOutField08 = @nCTotalBeforeReceivedQty -- (ChewKP01)
      SET @cOutField09 = @cDefaultUOM              -- (ChewKP01)
      SET @cOutField10 = ''
      SET @cOutField11 = ''

      SET @cInField01 = ''
      SET @cInField02 = ''
      SET @cInField03 = ''
      SET @cInField04 = ''
      SET @cInField05 = ''
      SET @cInField06 = ''
      SET @cInField07 = ''
      SET @cInField08 = ''
      SET @cInField09 = ''
      SET @cInField10 = ''
      SET @cInField11 = ''
      SET @cInField12 = ''
      SET @cInField13 = ''

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



      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END
   GOTO Quit

   MsgSuccess_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''

      GOTO Quit
   END
END
GOTO Quit


/********************************************************************************
Scn = 1458. TO ID & TO LOC screen
   TO ID     (field01, input)
   TO LOC    (field02, input)
********************************************************************************/
Step_IDLOC:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
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

      -- Screen mapping
      SET @cID = @cInField01 -- ID
      SET @cLOC = @cInField02 -- LOC

      -- Get Config
      SET @bSkipToLoc = rdt.RDTGetConfig( @nFunc, 'SkipToLoc', @cStorerKey) -- (ChewKP01)

      -- Get Config
      SET @bSkipToID = rdt.RDTGetConfig( @nFunc, 'SkipToID', @cStorerKey) -- (ChewKP01)



      IF @bSkipToID <> '1' -- (ChewKP01)
      BEGIN
         IF ISNULL(@cID, '') = ''
         BEGIN
            SET @nErrNo = 63338
            SET @cErrMsg = rdt.rdtgetmessage(63338, @cLangCode, 'DSP') -- ID Req
            SET @cOutField01 = ''
            SET @cOutField02 = @cLOC
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END
         ELSE
         BEGIN
            IF EXISTS (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK)
                WHERE Configkey = 'DisAllowDuplicateIdsOnRFRcpt'
                AND   sValue = '1'
                AND   Storerkey = @cStorerkey)
            BEGIN
             SELECT @nIDExists = 1
             FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
             JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
             WHERE LLI.ID = @cID
              --AND   LLI.Storerkey = @cStorerkey
                 AND   LOC.Facility = @cFacility
             AND   LLI.QTY > 0

                     IF @nIDExists > 0
                     BEGIN
                        SET @nErrNo = 63339
                        SET @cErrMsg = rdt.rdtgetmessage(63339, @cLangCode, 'DSP') -- Duplicate ID
                        SET @cOutField01 = ''
                        SET @cOutField02 = @cLOC
                        EXEC rdt.rdtSetFocusField @nMobile, 1
                        GOTO Quit
                     END
            END


         END -- ID <> ''
      END   -- @bSkipToID <> '1'


      IF @bSkipToLoc <> '1' -- (ChewKP01)
      BEGIN
         IF ISNULL(@cLOC, '') = ''
         BEGIN
            SET @nErrNo = 63340
            SET @cErrMsg = rdt.rdtgetmessage(63340, @cLangCode, 'DSP') -- LOC req
            SET @cOutField01 = @cID
            SET @cOutField02 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END
         ELSE
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                           WHERE LOC = @cLOC)
            BEGIN
               SET @nErrNo = 63341
               SET @cErrMsg = rdt.rdtgetmessage(63341, @cLangCode, 'DSP') -- Invalid LOC
               SET @cOutField01 = @cID
               SET @cOutField02 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Quit
            END

            IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                           WHERE LOC = @cLOC
                           AND   Facility = @cFacility)
            BEGIN
               SET @nErrNo = 63342
               SET @cErrMsg = rdt.rdtgetmessage(63342, @cLangCode, 'DSP') -- Diff facility
               SET @cOutField01 = @cID
               SET @cOutField02 = ''
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Quit
            END
         END
      END -- @bSkipToLoc <> '1'

      SET @nCTotalBeforeReceivedQty = 0
      SET @nCTotalUQtyExpected = 0

      -- Calculate QTY by preferred UOM  -- (ChewKP01)
      SELECT  @nCTotalUQtyExpected = SUM(QtyExpected), @nCTotalBeforeReceivedQty = SUM(BeforeReceivedQty)  FROM dbo.ReceiptDetail (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   POKey = CASE WHEN UPPER('@cPokey') = 'NOPO' THEN '' ELSE @cPokey END


      -- Prepare SKU screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = @nCTotalUQtyExpected      -- (ChewKP01)
      SET @cOutField07 = @cDefaultUOM              -- (ChewKP01)
      SET @cOutField08 = @nCTotalBeforeReceivedQty -- (ChewKP01)
      SET @cOutField09 = @cDefaultUOM              -- (ChewKP01)

  -- Remember current scn & step no
      SET @nPrevScn = @nScn_SKU
      SET @nPrevStep = @nStep_SKU

      -- Go to SKU screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cReceiptKey = ''
      SET @cOutField01 = '' -- ReceiptKey
      SET @cOutField02 = @cPOKey

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

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey

      -- Go to prev screen
      SET @nScn = @nScn_ASNPO
      SET @nStep = @nStep_ASNPO
   END
END
GOTO Quit

/********************************************************************************
Scn = 1459. Zone screen
   Zone     (field01, input)
********************************************************************************/
Step_Zone:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cZone = @cInField01 -- ID

      IF ISNULL( @cZone, '') = ''
      BEGIN
         SET @nErrNo = 63344
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') -- Zone req
         GOTO Step_Zone_Fail
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                      WHERE Facility = @cFacility
                      AND   PutawayZone = @cZone)
      BEGIN
         SET @nErrNo = 63345
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') -- Invalid Zone
         GOTO Step_Zone_Fail
      END

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

      -- Prepare screen var
      SET @cOutField01 = ''

      -- Go to PickSlipNo screen
      SET @nScn = @nScn_ASNPO
      SET @nStep = @nStep_ASNPO
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
   GOTO Quit

   Step_Zone_Fail:
   BEGIN
      SET @cOutField01 = ''
      SET @cZone = ''
   END
END
GOTO Quit

/********************************************************************************
Step 8. Screen = 3570. Multi SKU
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
      SELECT @cSKUDescr = Descr FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
   END
   SET @nCTotalBeforeReceivedQty = 0
   SET @nCTotalUQtyExpected = 0
   -- Calculate QTY by preferred UOM  -- (ChewKP01)
   SELECT  @nCTotalUQtyExpected = SUM(QtyExpected), @nCTotalBeforeReceivedQty = SUM(BeforeReceivedQty)  FROM dbo.ReceiptDetail (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
   AND   POKey = CASE WHEN UPPER('@cPokey') = 'NOPO' THEN '' ELSE @cPokey END
   -- Get Default UOM -- (ChewKP01)
   SELECT @cDefaultUOM = Short FROM dbo.CodeLkup (NOLOCK)
   WHERE LISTNAME = 'DMASTERUOM' AND CODE = @cStorerKey
   -- Prepare SKU fields
   IF @nFunc = 552
   BEGIN
      -- Prepare SKU screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cSKU -- SKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr,  1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDescr,  21, 20)
      SET @cOutField06 = @nCTotalUQtyExpected      -- (ChewKP01)
      SET @cOutField07 = @cDefaultUOM              -- (ChewKP01)
      SET @cOutField08 = @nCTotalBeforeReceivedQty -- (ChewKP01)
      SET @cOutField09 = @cDefaultUOM              -- (ChewKP01)
      -- Go to SKU screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END
   ELSE
   BEGIN
      -- Prep LOC screen var
      SET @cDefaultLOC = ''
      SELECT @cDefaultLOC = RTRIM(sValue) FROM RDT.STORERCONFIG WITH (NOLOCK)
      WHERE Configkey = 'ReturnDefaultToLOC'
      AND   Storerkey = @cStorerkey
      SET @cPickFaceFlag = 'N'
      IF @cDefaultLOC = 'PICKFACE'
      BEGIN
         SET @cDefaultLOC = ''
         SELECT @cDefaultLOC = IsNULL(LOC, '')
         FROM dbo.SKUxLOC WITH (NOLOCK)
         WHERE SKU = @cSKU
         AND   Storerkey = @cStorerkey
         AND   (LocationType = 'PICK' OR LocationType = 'CASE')
         SET @cPickFaceFlag = 'Y'
         IF @cDefaultLOC = ''
         BEGIN
            SET @nErrNo = 63332
            SET @cErrMsg = rdt.rdtgetmessage(63332, @cLangCode, 'DSP') -- No Pick Face
         END
      END
      SET @cOutField01 = ''
      SET @cOutField02 = CASE WHEN ISNULL(@cDefaultLOC, '') = '' THEN '' ELSE @cDefaultLOC END
      -- Get Config
      SET @bSkipToLoc = rdt.RDTGetConfig( @nFunc, 'SkipToLoc', @cStorerKey) -- (ChewKP01)
      -- Get Config
      SET @bSkipToID = rdt.RDTGetConfig( @nFunc, 'SkipToID', @cStorerKey) -- (ChewKP01)
      -- IF SkipToLoc , SkipToID , and DefaultLoc had values Skip ToIDLOC Screen -- (ChewKP01)
      IF @bSkipToLoc = '1' AND @bSkipToID = '1' AND @cDefaultLOC <> ''
      BEGIN
            -- Prepare SKU screen var
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @cPOKey
         SET @cOutField03 = @cSKU -- SKU
         SET @cOutField04 = SUBSTRING( @cSKUDescr,  1, 20)
         SET @cOutField05 = SUBSTRING( @cSKUDescr,  21, 20)
         SET @cOutField06 = @nCTotalUQtyExpected      -- (ChewKP01)
         SET @cOutField07 = @cDefaultUOM              -- (ChewKP01)
         SET @cOutField08 = @nCTotalBeforeReceivedQty -- (ChewKP01)
         SET @cOutField09 = @cDefaultUOM              -- (ChewKP01)
            -- Remember current scn & step no
         SET @nPrevScn = @nScn_SKU
         SET @nPrevStep = @nStep_SKU
         -- Go to SKU screen
         SET @nScn = @nScn_SKU
         SET @nStep = @nStep_SKU
      END
      ELSE
      BEGIN
         -- Remember current scn & step no
         SET @nPrevScn = @nScn_ASNPO
         SET @nPrevStep = @nStep_ASNPO
         -- Go to SKU screen
         SET @nScn = @nScn_IDLOC
         SET @nStep = @nStep_IDLOC
      END
   END
   -- Go to SKU QTY screen
   SET @nPrevScn = @nScn_SKU
   SET @nPrevStep = @nStep_SKU
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

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,
      -- UserName       = @cUserName,

      V_ReceiptKey   = @cReceiptKey,
      V_POKey        = @cPOKey,
      V_LOC          = @cLOC,
      V_ID           = @cID,
      V_SKU          = @cSKU,
      V_SKUDescr     = @cSKUDescr,
      V_UOM          = @cUOM,
      V_QTY          = @cQTY,
      V_Lottable01   = @cLottable01,
      V_Lottable02   = @cLottable02,
      V_Lottable03   = @cLottable03,
      V_Lottable04   = @dLottable04,
      V_Lottable05   = @dLottable05,
      V_Lottable06   = @cLottable06,
      V_Lottable07   = @cLottable07,
      V_Lottable08   = @cLottable08,
      V_Lottable09   = @cLottable09,
      V_Lottable10   = @cLottable10,
      V_Lottable11   = @cLottable11,
      V_Lottable12   = @cLottable12,
      V_Lottable13   = @dLottable13,
      V_Lottable14   = @dLottable14,
      V_Lottable15   = @dLottable15,

      V_PQTY         = @nPQTY,
      V_MQTY         = @nMQTY,
      V_FromScn      = @nPrevScn,
      V_FromStep     = @nPrevStep,
      
      V_Integer1     = @nQTY,
      V_Integer2     = @nPrefUOM_Div,  -- Pref UOM divider
      V_Integer3     = @nMstQTY,       -- Remaining QTY in master unit
      V_Integer4     = @nActMQTY,      -- Actual Qty in master unit
      V_Integer5     = @nActPQTY,      -- Actual Qty in pref UOM
      V_Integer6     = @nActQty,       -- Total Actual Qty (@nActMQTY + @nActPQTY)
      V_Integer7     = @nBeforeReceivedQty,
      
      V_String4      = @cActPQTY,
      V_String5      = @cActMQTY,
      V_String6      = @cPrefUOM,      -- Pref UOM
      V_String7      = @cPrefUOM_Desc, -- Pref UOM desc
      V_String8      = @cMstUOM_Desc,  -- Master UOM desc

      V_String14     = @cSkipLottable01,
      V_String15     = @cSkipLottable02,
      V_String16     = @cSkipLottable03,
      V_String17     = @cSkipLottable04,

      V_String20     = @cLotFlag,
      V_String21     = @cReturnReason,
      V_String22     = @cOverRcpt,
      V_String23     = @cExpReason,
      V_String24     = @cIDFlag,
      V_String27     = @cIVAS,
      V_String28     = @cConditionCode,
      V_String29     = @cSubReason,
      V_String30     = @cLottable01Label,
      V_String31     = @cLottable02Label,
      V_String32     = @cLottable03Label,
      V_String33     = @cLottable04Label,
      V_String34     = @cLottable05Label,
      V_String35     = @cDefaultLOC,
      V_String36     = @cPickFaceFlag,
      V_String37     = @cSUSR1,
      V_String39     = @cDefaultUOM,
      V_String40     = @cDecodeLabelNo,
      V_OrderKey     = @cZone,         -- (james03)

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