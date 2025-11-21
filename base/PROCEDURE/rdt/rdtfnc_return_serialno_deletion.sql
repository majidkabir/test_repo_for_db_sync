SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_Return_SerialNo_Deletion                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: To cater Normal Trade Return and Exchange Return            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2008-08-25   1.0  Vicky      Created                                 */
/* 2008-11-03   1.1  Vicky      Remove XML part of code that is used to */
/*                              make field invisible and replace with   */
/*                              new code (Vicky02)                      */
/* 2009-07-06   1.2  Vicky      Add in EventLog (Vicky06)               */
/* 2011-03-03   1.3  James      SOS201989 - Add filter by               */
/*                              ExternReceiptKey (james01)              */
/* 2016-09-30   1.4  Ung        Performance tuning                      */ 
/* 2016-10-28   1.5  James      Change isDate to rdtIsValidDate(james02)*/
/************************************************************************/
CREATE  PROC [RDT].[rdtfnc_Return_SerialNo_Deletion](
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
   @b_success      INT,
   @n_err          INT,
   @c_errmsg       NVARCHAR( 250),
   @i              INT, 
   @nTask          INT,  
   @cParentScn     NVARCHAR( 3), 
   @cOption        NVARCHAR( 1), 
   @cXML           NVARCHAR( 4000) -- To allow double byte data for e.g. SKU desc

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
   @cDropID             NVARCHAR( 18), 
   @cSKU                NVARCHAR( 20),
   @cSKUDescr           NVARCHAR( 60),
   @cUOM                NVARCHAR( 10),   -- Display NVARCHAR(3)
   @cQTY                NVARCHAR( 5), 
   @cUCC                NVARCHAR( 20),
   @cLottable01         NVARCHAR( 18),
   @cLottable02         NVARCHAR( 18),
   @cLottable03         NVARCHAR( 18),
   @dLottable04         DATETIME,
   @dLottable05         DATETIME,

   @nPQTY               INT,  -- Preffered UOM QTY
   @nMQTY               INT,  -- Master unit QTY
   
   @cUOMDesc            NVARCHAR( 3), 
   @cPrefUOM            NVARCHAR( 1), -- Pref UOM
   @nPrefUOM_Div        INT,      -- Pref UOM divider
   @cPrefUOM_Desc       NVARCHAR( 5), -- Pref UOM desc
   @cMstUOM_Desc        NVARCHAR( 5), -- Master UOM desc
   @nPrefQTY            INT,      -- QTY in pref UOM
   @nMstQTY             INT,      -- Remaining QTY in master unit
   @nActMQTY            INT,      -- Actual keyed in master QTY
   @nActPQTY            INT,      -- Actual keyed in prefered QTY
   @nActQTY             INT,      -- Actual return QTY
   @nTotalQTY           INT,      -- Total Scanned Qty
   @cActPQTY            NVARCHAR( 5),
   @cActMQTY            NVARCHAR( 5),
   @cTotalQTY           NVARCHAR( 5),
  
   @nCaseCnt            INT,
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
   @cStoredProdSN       NVARCHAR( 250),
   @cTempLotLabel       NVARCHAR(20),
--   @cConditionCode      NVARCHAR(10), 

   @cExpReason          NVARCHAR( 1),
   @cReturnReason       NVARCHAR( 1), 
   @cOverRcpt           NVARCHAR( 1), 
--   @cSerialNoFlag       NVARCHAR( 1), 
   @cSNFlag             NVARCHAR( 1),
   @cPickFaceFlag       NVARCHAR( 1),
   @cDefaultLOC         NVARCHAR( 10),
   
   @cLottable01Label    NVARCHAR( 20),
   @cLottable02Label    NVARCHAR( 20), 
   @cLottable03Label    NVARCHAR( 20),
   @cLottable04Label    NVARCHAR( 20),
   @cLottable05Label    NVARCHAR( 20),

   @cTempLottable01     NVARCHAR( 18), --input field lottable01 from lottable screen
   @cTempLottable02     NVARCHAR( 18), --input field lottable02 from lottable screen
   @cTempLottable03     NVARCHAR( 18), --input field lottable03 from lottable screen
   @cTempLottable04     NVARCHAR( 16), --input field lottable04 from lottable screen
   @cTempLottable05     NVARCHAR( 16), --input field lottable05 from lottable screen

   @cTempLotLabel01     NVARCHAR( 20), 
   @cTempLotLabel02     NVARCHAR( 20),
   @cTempLotLabel03     NVARCHAR( 20),
   @cTempLotLabel04     NVARCHAR( 20),
   @cTempLotLabel05     NVARCHAR( 20), 
   @dTempLottable04     DATETIME,
   @dTempLottable05     DATETIME,

   @cPickSlipNo         NVARCHAR( 10),
   @cCBADefaultLot4     NVARCHAR( 10),
   @nSNExists           INT,
   @cTotalPQty          NVARCHAR( 5),
   @cTotalMQty          NVARCHAR( 5),

   @cTotalASNQTY        NVARCHAR( 5),
   @cTotalASNPQty       NVARCHAR( 5),
   @cTotalASNMQty       NVARCHAR( 5),
   @nTotalASNQTY        INT,      -- Total Scanned Qty
   @cExternReceiptKey   NVARCHAR( 20),
  
--   @cTempConditionCode  NVARCHAR( 10),
      
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

   -- (Vicky02) - Start
   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),
   @cFieldAttr15 NVARCHAR( 1)
   -- (Vicky02) - End

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
   @cPickSlipNo      = V_PickSlipNo,
   
   @cLOC             = V_LOC,
   --@cTempLottable04  = V_ID, 
   @cSKU             = V_SKU,
   @cSKUDescr        = V_SKUDescr,
   @cUOM             = V_UOM,
   @cQTY             = V_QTY,
   @cLottable01      = V_Lottable01,
   @cLottable02      = V_Lottable02,
   @cLottable03      = V_Lottable03,
   @dLottable04      = V_Lottable04,
   @dLottable05      = V_Lottable05,
   @cExternReceiptKey = V_UCC,

   @nPQTY            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String1, 5), 0) = 1 THEN LEFT( V_String1, 5) ELSE 0 END,
   @cTotalMQty       = V_String2,
   @nMQTY            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 5), 0) = 1 THEN LEFT( V_String3, 5) ELSE 0 END,
   @nQTY             = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 5), 0) = 1 THEN LEFT( V_String4, 5) ELSE 0 END,
   @nCaseCnt         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 5), 0) = 1 THEN LEFT( V_String5, 5) ELSE 0 END,

   @cUOMDesc         = V_String6, 
   @cActPQTY         = V_String7,
   @cParentScn       = V_String8,
   @cActMQTY         = V_String9,
   
   @cPrefUOM         = V_String10, -- Pref UOM
   @cPrefUOM_Desc    = V_String11, -- Pref UOM desc
   @cMstUOM_Desc     = V_String12, -- Master UOM desc
   @nPrefUOM_Div     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String13, 5), 0) = 1 THEN LEFT( V_String13, 5) ELSE 0 END, -- Pref UOM divider
   @nPrefQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String14, 5), 0) = 1 THEN LEFT( V_String14, 5) ELSE 0 END, -- QTY in pref UOM
   @nMstQTY          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15, 5), 0) = 1 THEN LEFT( V_String15, 5) ELSE 0 END, -- Remaining QTY in master unit
   @nActMQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String16, 5), 0) = 1 THEN LEFT( V_String16, 5) ELSE 0 END,
   @nActPQTY         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String17, 5), 0) = 1 THEN LEFT( V_String17, 5) ELSE 0 END,
   @nActQty          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String18, 5), 0) = 1 THEN LEFT( V_String18, 5) ELSE 0 END, 
   @nTotalQty        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String19, 5), 0) = 1 THEN LEFT( V_String19, 5) ELSE 0 END, 

   @cTempLottable04  = V_String20,
   @cReturnReason    = V_String21,
   @cOverRcpt        = V_String22,
   @cExpReason       = V_String23,
   @cCBADefaultLot4  = V_String24,
--   @cTempLottable01  = V_String20,
--   @cTempLottable02  = V_String21,
--   @cTempLottable03  = V_String22,
--   @cTempLottable04  = V_String23,
--   @cTempLottable05  = V_String24,

   @nPrevScn         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String25, 5), 0) = 1 THEN LEFT( V_String25, 5) ELSE 0 END, -- Previous Screen
   @nPrevStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String26, 5), 0) = 1 THEN LEFT( V_String26, 5) ELSE 0 END, -- Previous Step

   @cIVAS            = V_String27,
   @cSerialNo        = V_String28,
   @cSubReason       = V_String29,

   @cLottable01Label = V_String30,
   @cLottable02Label = V_String31,
   @cLottable03Label = V_String32,
   @cLottable04Label = V_String33,
   @cLottable05Label = V_String34,
 
   @cDefaultLOC      = V_String35,
   @cPickFaceFlag    = V_String36,
   @cSUSR1           = V_String37,

   @nBeforeReceivedQty = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String38, 5), 0) = 1 THEN LEFT( V_String38, 5) ELSE 0 END,   
   @nSNExists          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String39, 5), 0) = 1 THEN LEFT( V_String39, 5) ELSE 0 END,   
   @cTotalPQty         = V_String40,   

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

   -- (Vicky02) - Start
   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15
   -- (Vicky02) - End

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE 
   @nStep_ASNPO      INT,  @nScn_ASNPO      INT,  
   @nStep_SKU        INT,  @nScn_SKU        INT,  
   @nStep_QTY        INT,  @nScn_QTY        INT,  
   @nStep_Lottables  INT,  @nScn_Lottables  INT,  
   @nStep_SubReason  INT,  @nScn_SubReason  INT,  
   @nStep_LOC        INT,  @nScn_LOC        INT,  
   @nStep_MsgSuccess INT,  @nScn_MsgSuccess INT,  
   @nStep_AbortTask  INT,  @nScn_AbortTask  INT

SELECT
   @nStep_ASNPO      = 1,  @nScn_ASNPO      = 1790,  
   @nStep_SKU        = 2,  @nScn_SKU        = 1791,  
   @nStep_QTY        = 3,  @nScn_QTY        = 1792,  
   @nStep_Lottables  = 4,  @nScn_Lottables  = 1793,  
   @nStep_SubReason  = 5,  @nScn_SubReason  = 1794,  
   @nStep_LOC        = 6,  @nScn_LOC        = 1795,  
   @nStep_MsgSuccess = 7,  @nScn_MsgSuccess = 1796  

-- Commented (Vicky02) - Start
-- -- Session screen
-- DECLARE @tSessionScrn TABLE
-- (
--    Typ       NVARCHAR( 10), 
--    X         NVARCHAR( 4),    -- size 4 is needed bcoz of 'NULL'
--    Y         NVARCHAR( 4),    -- size 4 is needed bcoz of 'NULL'
--    Length    NVARCHAR( 4),    -- size 4 is needed bcoz of 'NULL'
--    [ID]      NVARCHAR( 10), 
--    [Default] NVARCHAR( 60), 
--    Value     NVARCHAR( 60), 
--    [NewID]   NVARCHAR( 10)
-- )
-- Commented (Vicky02) - End

IF @nFunc = 1600
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start       -- Menu. Func = 1600
   IF @nStep = 1  GOTO Step_ASNPO       -- Scn = 1790. ASN,PO
   IF @nStep = 2  GOTO Step_SKU         -- Scn = 1791. SKU
   IF @nStep = 3  GOTO Step_QTY         -- Scn = 1792. QTY, ConditionCode
   IF @nStep = 4  GOTO Step_Lottables   -- Scn = 1793. Lottable1-5
   IF @nStep = 5  GOTO Step_SubReason   -- Scn = 1794. Subreason
   IF @nStep = 6  GOTO Step_LOC         -- Scn = 1795. LOC   
   IF @nStep = 7  GOTO Step_MsgSuccess  -- Scn = 1796. Message. 'Receive Successful'
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 1600
********************************************************************************/
Step_Start:
BEGIN
-- Commented (Vicky02) - Start
--    -- Create the session data
--    IF EXISTS (SELECT 1 FROM RDTSessionData (NOLOCK) WHERE Mobile = @nMobile)
--       UPDATE RDTSessionData WITH (ROWLOCK) SET XML = '' WHERE Mobile = @nMobile
--    ELSE
--       INSERT INTO RDTSessionData (Mobile) VALUES (@nMobile)
-- Commented (Vicky02) - End

   --get POKey as 'NOPO' if storerconfig has been setup for 'ReceivingPOKeyDefaultValue'
   SET @cPOKeyDefaultValue = ''
   SET @cPOKeyDefaultValue = rdt.RDTGetConfig( 0, 'ReceivingPOKeyDefaultValue', @cStorerKey)  

   IF (@cPOKeyDefaultValue = '0' OR @cPOKeyDefaultValue IS NULL OR @cPOKeyDefaultValue = '')
      SET @cOutField02 = ''
   ELSE
      SET @cOutField02 = @cPOKeyDefaultValue

   -- CBA only: get lottable default value if rdt storerconfig has been setup for 'CBADefaultLot4'
   SET @cCBADefaultLot4 = ''
   SELECT @cCBADefaultLot4 = ISNULL(RTRIM(sValue), '')
   FROM RDT.Storerconfig (NOLOCK)
   WHERE Storerkey = @cStorerKey
   AND Configkey = 'CBADefaultLot4'
   
 
   -- Init var
   SET @nPQTY = 0
   SET @nActPQTY = 0
   SET @nSNExists = 1

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
     @cStorerKey  = @cStorerkey
   
   -- Prepare ASN screen var
   SET @cOutField01 = '' -- ASN #
   SET @cOutField03 = '' -- Pickslip No

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
Scn = 1790. ASN, PO, PICKSLIP NO screen
   ASN         (field01)
   PO          (field02)
   PICKSLIP NO (field03)
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
      SET @cPickslipNo = @cInField03
      SET @cExternReceiptKey = @cInField04

      -- Validate blank ASN & PO
      IF (@cReceiptKey = '' OR @cReceiptKey IS NULL) AND (@cPOKey = '' OR @cPOKey IS NULL) 
      AND (@cPickslipNo = '' OR @cPickslipNo IS NULL) AND (@cExternReceiptKey = '' OR @cExternReceiptKey IS NULL)
      BEGIN
         SET @nErrNo = 65751
         SET @cErrMsg = rdt.rdtgetmessage( 65751, @cLangCode,'DSP') -- ASN/PO/PKSLIP req
         GOTO ASNPO_Fail
      END

      IF @cReceiptKey = '' AND UPPER(@cPOKey) ='NOPO' AND @cPickslipNo = '' AND @cExternReceiptKey = ''
      BEGIN
         SET @nErrNo = 65751
         SET @cErrMsg = rdt.rdtgetmessage( 65751, @cLangCode, 'DSP') -- ASN/PO/PKSLIP req
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO ASNPO_Fail  
      END

      -- Validate both ASN and PO
      IF @cReceiptKey <> '' AND @cPOKey <> '' AND  UPPER(@cPOKey) <> 'NOPO' AND @cPickslipNo = '' AND @cExternReceiptKey = ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.RECEIPT R WITH (NOLOCK)
                        JOIN dbo.RECEIPTDETAIL RD WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
                        WHERE R.ReceiptKey = @cReceiptkey
                        AND   RD.POKey = @cPOKey)
         BEGIN
        SET @nErrNo = 65752
            SET @cErrMsg = rdt.rdtgetmessage( 65752, @cLangCode, 'DSP') --Invalid ASN/PO
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
            GOTO Quit
         END
      END  

      -- Validate PickSlipNo
      IF @cReceiptKey <> '' AND @cPOKey <> '' AND  UPPER(@cPOKey) <> 'NOPO' AND @cPickslipNo <> '' AND @cExternReceiptKey = ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.RECEIPT R WITH (NOLOCK)
                        JOIN dbo.RECEIPTDETAIL RD WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
                        WHERE R.ReceiptKey = @cReceiptkey
                        AND   RD.POKey = @cPOKey
                        AND   R.CarrierReference = @cPickslipNo)
         BEGIN
            SET @nErrNo = 65753
            SET @cErrMsg = rdt.rdtgetmessage( 65753, @cLangCode, 'DSP') --Invalid ASN/PO/PSNO
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
            GOTO Quit
         END
      END  

      -- Validate ReceiptKey + POKey + ExternReceiptKey
      IF @cReceiptKey <> '' AND @cPOKey <> '' AND  UPPER(@cPOKey) <> 'NOPO' AND @cPickslipNo = '' AND @cExternReceiptKey <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.RECEIPT R WITH (NOLOCK)
                        JOIN dbo.RECEIPTDETAIL RD WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
                        WHERE R.ReceiptKey = @cReceiptkey
                        AND   RD.POKey = @cPOKey
                        AND   R.ExternReceiptKey = @cExternReceiptKey)
         BEGIN
            SET @nErrNo = 65799
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv ASN+PO+EXTR
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
            GOTO Quit
         END
      END  

      IF @cReceiptKey <> '' AND (@cPOKey = '' OR UPPER(@cPOKey) = 'NOPO') AND @cPickslipNo <> '' AND @cExternReceiptKey = ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.RECEIPT R WITH (NOLOCK)
                        JOIN dbo.RECEIPTDETAIL RD WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
                        WHERE R.ReceiptKey = @cReceiptkey
                        AND   R.CarrierReference = @cPickslipNo)
         BEGIN
            SET @nErrNo = 65754
            SET @cErrMsg = rdt.rdtgetmessage( 65754, @cLangCode, 'DSP') --Invalid ASN/PSNO
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
            GOTO Quit
         END
      END  

      IF @cReceiptKey <> '' AND (@cPOKey = '' OR UPPER(@cPOKey) = 'NOPO') AND @cPickslipNo = '' AND @cExternReceiptKey <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.RECEIPT R WITH (NOLOCK)
                        JOIN dbo.RECEIPTDETAIL RD WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
                        WHERE R.ReceiptKey = @cReceiptkey
                        AND   R.ExternReceiptKey = @cExternReceiptKey)
         BEGIN
            SET @nErrNo = 65800
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv ASN+EXTR
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
            GOTO Quit
         END
      END  

      IF @cReceiptKey = '' AND @cPOKey <> '' AND UPPER(@cPOKey) <> 'NOPO' AND @cPickslipNo <> '' AND @cExternReceiptKey = ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.RECEIPT R WITH (NOLOCK)
                        JOIN dbo.RECEIPTDETAIL RD WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
                        WHERE RD.POKey = @cPOKey
                        AND   R.CarrierReference = @cPickslipNo)
         BEGIN
            SET @nErrNo = 65755
            SET @cErrMsg = rdt.rdtgetmessage( 65755, @cLangCode, 'DSP') --Invalid PO/PSNO
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- POKey
            GOTO Quit
         END
      END 

      IF @cReceiptKey = '' AND @cPOKey <> '' AND UPPER(@cPOKey) <> 'NOPO' AND @cPickslipNo = '' AND @cExternReceiptKey <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.RECEIPT R WITH (NOLOCK)
                        JOIN dbo.RECEIPTDETAIL RD WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
                        WHERE RD.POKey = @cPOKey
                        AND   R.ExternReceiptKey = @cExternReceiptKey)
         BEGIN
            SET @nErrNo = 72416
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv PO+EXTR
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- POKey
            GOTO Quit
         END
      END 

      --When only PO keyed-in (ASN & PKSLIP left as blank)
      IF @cPOKey <> '' AND UPPER(@cPOKey) <> 'NOPO' AND (@cReceiptkey  = '' OR @cReceiptkey IS NULL) AND 
        (@cPickslipNo  = '' OR @cPickslipNo IS NULL) AND (@cExternReceiptKey  = '' OR @cExternReceiptKey IS NULL)
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK) 
                        WHERE RD.POkey = @cPOKey )
         BEGIN
            SET @nErrNo = 65756
            SET @cErrMsg = rdt.rdtgetmessage( 65756, @cLangCode, 'DSP') --PO not exists
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
            SET @nErrNo = 65757
            SET @cErrMsg = rdt.rdtgetmessage( 65757, @cLangCode, 'DSP') --ASN needed
            SET @cOutField01 = '' --ReceiptKey
            SET @cOutField02 = @cPOKey
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
            GOTO Quit
         END
      END 

      --When only PKSLIP keyed-in (ASN & PO left as blank)
      IF @cPickslipNo <> '' AND (@cPOKey = '' OR UPPER(@cPOKey) = 'NOPO') AND 
        (@cReceiptkey  = '' OR @cReceiptkey IS NULL)
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.RECEIPT R WITH (NOLOCK) 
                        WHERE R.CarrierReference = @cPickslipNo )
         BEGIN
            SET @nErrNo = 65758
            SET @cErrMsg = rdt.rdtgetmessage( 65758, @cLangCode, 'DSP') --PKSLIP not exists
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- PickslipNo
            GOTO Quit  
         END

         SET @nCountReceipt = 0

         --Get ReceiptKey count
         SELECT @nCountReceipt = COUNT(DISTINCT Receiptkey) 
         FROM dbo.RECEIPT WITH (NOLOCK)
         WHERE CarrierReference = @cPickslipNo
         GROUP BY CarrierReference

         IF @nCountReceipt = 1
         BEGIN
            --Get single ReceiptKey
            SELECT @cReceiptKey = ReceiptKey
            FROM dbo.RECEIPT WITH (NOLOCK)
            WHERE CarrierReference = @cPickslipNo
            GROUP BY ReceiptKey
         END
         ELSE IF @nCountReceipt > 1
         BEGIN
            SET @nErrNo = 65759
            SET @cErrMsg = rdt.rdtgetmessage( 65759, @cLangCode, 'DSP') --ASN needed
            SET @cOutField01 = '' --ReceiptKey
            SET @cOutField03 = @cPickslipNo
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
            GOTO Quit
         END
      END 

      --When only ExternReceiptKey keyed-in (ASN & PO left as blank)
      IF @cExternReceiptKey <> '' AND (@cPOKey = '' OR UPPER(@cPOKey) = 'NOPO') AND 
        (@cReceiptkey  = '' OR @cReceiptkey IS NULL)
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.RECEIPT R WITH (NOLOCK) 
                        WHERE R.ExternReceiptKey = @cExternReceiptKey )
         BEGIN
            SET @nErrNo = 72417
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --EXTR not exists
            SET @cOutField03 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- PickslipNo
            GOTO Quit  
         END

         SET @nCountReceipt = 0

         --Get ReceiptKey count
         SELECT @nCountReceipt = COUNT(DISTINCT Receiptkey) 
         FROM dbo.RECEIPT WITH (NOLOCK)
         WHERE ExternReceiptKey = @cExternReceiptKey
         GROUP BY ExternReceiptKey

         IF @nCountReceipt = 1
         BEGIN
            --Get single ReceiptKey
            SELECT @cReceiptKey = ReceiptKey
            FROM dbo.RECEIPT WITH (NOLOCK)
            WHERE ExternReceiptKey = @cExternReceiptKey
            GROUP BY ReceiptKey
         END
         ELSE IF @nCountReceipt > 1
         BEGIN
            SET @nErrNo = 72418
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN needed
            SET @cOutField01 = '' --ReceiptKey
            SET @cOutField03 = @cPickslipNo
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
            GOTO Quit
         END
      END 

     IF NOT EXISTS (SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK) 
                    WHERE ReceiptKey = @cReceiptkey)
     BEGIN
         SET @nErrNo = 65760
         SET @cErrMsg = rdt.rdtgetmessage( 65760, @cLangCode, 'DSP') --ASN not exists
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
         SET @nErrNo = 65761
         SET @cErrMsg = rdt.rdtgetmessage( 65761, @cLangCode, 'DSP') --Diff facility
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
         SET @nErrNo = 65762
         SET @cErrMsg = rdt.rdtgetmessage( 65762, @cLangCode,'DSP') -- Diff storer
         GOTO ASNPO_Fail
      END

      --check for ASN closed by receipt.status
      IF EXISTS (SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK)
                 WHERE Receiptkey = @cReceiptkey
                 AND   Status = '9')
      BEGIN
         SET @nErrNo = 65763
         SET @cErrMsg = rdt.rdtgetmessage( 65763, @cLangCode, 'DSP') --ASN closed
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO ASNPO_Fail    
      END

      --check for ASN closed by receipt.ASNStatus
      IF EXISTS (SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK)
                 WHERE Receiptkey = @cReceiptkey
                 AND ASNStatus = '9' )
      BEGIN
         SET @nErrNo = 65764
         SET @cErrMsg = rdt.rdtgetmessage( 65764, @cLangCode, 'DSP') --ASN closed
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO ASNPO_Fail    
      END

      --check for ASN cancelled
      IF EXISTS ( SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK)
                  WHERE Receiptkey = @cReceiptkey
                  AND ASNStatus = 'CANC')
      BEGIN
         SET @nErrNo = 65765
         SET @cErrMsg = rdt.rdtgetmessage( 65765, @cLangCode, 'DSP') --ASN cancelled
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO ASNPO_Fail    
      END

      --check for TradeReturnASN
      IF EXISTS (SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK)
                 WHERE Receiptkey = @cReceiptkey
                 AND   DocType <> 'R')
      BEGIN
         SET @nErrNo = 65766
         SET @cErrMsg = rdt.rdtgetmessage( 65766, @cLangCode, 'DSP') -- Not Return ASN
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO ASNPO_Fail
      END

      --When only ASN keyed-in (PO & PKSLIP left as blank):
      IF @cReceiptKey <> ''  AND (@cPOKey = '' OR UPPER(@cPOKey) = 'NOPO') AND 
        (@cPickslipNo  = '' OR @cPickslipNo IS NULL)
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
                  SET @nErrNo = 65767
                  SET @cErrMsg = rdt.rdtgetmessage( 65767, @cLangCode, 'DSP') --PO needed
                  SET @cOutField01 = @cReceiptKey
                  SET @cOutField02 = '' --POKey
                  EXEC rdt.rdtSetFocusField @nMobile, 2 -- POKey
                  GOTO Quit    
               END
            END           
         END
      END

      -- Prepare SKU screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = ''
      SET @cOutField05 = '' 
      SET @cOutField06 = @cPickslipNo  
      SET @cOutField07 = @cExternReceiptKey  

      -- Go to SKU screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
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
       @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
      SET @cOutField02 = '' -- PO
      SET @cOutField03 = '' -- PickslipNo

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
   GOTO Quit

   ASNPO_Fail:
   BEGIN
      SET @cReceiptKey = ''
      SET @cOutField01 = '' -- ASN
      SET @cOutField02 = @cPOKey -- PO
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = '' 
      SET @cOutField06 = '' -- Pickslipno
      SET @cPickslipNo = ''
   END
END
GOTO Quit


/***********************************************************************************
Scn = 1791. SKU screen
   ASN         (field01)
   PO          (field02)
   Ext Receipt (field07)
   PICKSLIP NO (field05)
   SKU         (field03, input)
   SKUDesc     (field04, field05)
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
         SET @nErrNo = 65768
         SET @cErrMsg = rdt.rdtgetmessage( 65768, @cLangCode, 'DSP') --SKU needed
         GOTO SKU_Fail
      END

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
         SET @nErrNo = 65769
         SET @cErrMsg = rdt.rdtgetmessage( 65769, @cLangCode, 'DSP') --Invalid SKU
         GOTO SKU_Fail
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 65770
         SET @cErrMsg = rdt.rdtgetmessage( 65770 , @cLangCode, 'DSP') --MultiSKUBarcod
         GOTO SKU_Fail
      END

      SET @cLottable01Label = ''
		SET @cLottable02Label = ''
		SET @cLottable03Label = ''
		SET @cLottable04Label = ''
		SET @cLottable05Label = ''

      --get IVAS
      SET @cIVAS = ''
--       SELECT @cIVAS = ISNULL(LEFT(RTRIM(CodeLkUp.Description),20),'')
--       FROM dbo.CodeLkUp CodeLkUp WITH (NOLOCK) 
--       JOIN dbo.SKU Sku WITH (NOLOCK) ON SKU.IVAS = CodeLkUp.Code
--          AND SKU.SKU = @cSku

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
            SET @nErrNo = 65771
            SET @cErrMsg = rdt.rdtgetmessage( 65771, @cLangCode, 'DSP') --SKU not in ASN
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
     DECLARE @cReturnDefaultQTY NVARCHAR( 10)
     DECLARE @cDefaultPQTY NVARCHAR( 5)
     DECLARE @cDefaultMQTY NVARCHAR( 5)
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

     -- Get Total Received Qty for SKU
     SET @nTotalQty = 0
     SELECT @nTotalQTY = SUM(BeforeReceivedQty)
     FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
     WHERE ReceiptKey = @cReceiptkey
     AND   POKey = CASE WHEN UPPER(@cPOKey) = 'NOPO' THEN '' ELSE @cPOKey END
     AND   SKU = @cSKU
     GROUP BY SKU

     SET @cTotalQTY = CAST(@nTotalQTY as CHAR)

     SET @cTotalPQty = ''
     SET @cTotalMQty = ''

     IF @cPrefUOM_Desc = ''
        SET @cTotalMQty = @cTotalQTY
     ELSE
     BEGIN
        -- Calc QTY in preferred UOM
        SET @cTotalPQty = CAST( @cTotalMQty AS INT) / @nPrefUOM_Div
           
        -- Calc the remaining in master unit
        SET @cTotalMQty = CAST( @cTotalMQty AS INT) % @nPrefUOM_Div
     END

     -- Get Total Received Qty for ASN
     SET @nTotalASNQty = 0
     SELECT @nTotalASNQTY = SUM(BeforeReceivedQty)
     FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
     WHERE ReceiptKey = @cReceiptkey
     AND   POKey = CASE WHEN UPPER(@cPOKey) = 'NOPO' THEN '' ELSE @cPOKey END

     SET @cTotalASNQTY = CAST(@nTotalASNQTY as CHAR)

     SET @cTotalASNPQty = ''
     SET @cTotalASNMQty = ''

     IF @cPrefUOM_Desc = ''
        SET @cTotalASNMQty = @cTotalASNQTY
     ELSE
     BEGIN
        -- Calc QTY in preferred UOM
        SET @cTotalASNPQty = CAST( @cTotalASNMQty AS INT) / @nPrefUOM_Div
           
        -- Calc the remaining in master unit
        SET @cTotalASNMQty = CAST( @cTotalASNMQty AS INT) % @nPrefUOM_Div
     END

     -- Prep QTY screen var
     SET @cOutField01 = @cSKU
	  SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)
	  SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
--	  SET @cOutField04 = @cIVAS
     IF @cPrefUOM_Desc = ''
     BEGIN
        SET @cOutField05 = '' -- @nPrefUOM_Div
        SET @cOutField06 = '' -- @cPrefUOM_Desc
        SET @cOutField08 = '' -- @cPrefQTY
        -- Disable pref QTY field
        SET @cFieldAttr08 = 'O' -- (Vicky02)
        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
     END
     ELSE
     BEGIN
        SET @cOutField05 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
        SET @cOutField06 = @cPrefUOM_Desc
        SET @cOutField08 = @cDefaultPQTY
     END
     SET @cOutField07 = @cMstUOM_Desc
     SET @cOutField09 = @cDefaultMQTY
     IF @cPrefUOM_Desc = ''
     BEGIN
        SET @cOutField10 = '' -- @nPrefUOM_Div
        SET @cOutField11 = '' -- @cPrefUOM_Desc
        SET @cOutField13 = '' -- @cPrefQTY
        SET @cOutField15 = '' -- @cPrefQTY
        -- Disable pref QTY field
        SET @cFieldAttr13 = 'O' -- (Vicky02)
        SET @cFieldAttr15 = 'O' -- (Vicky02)
        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field13', 'NULL', 'output', 'NULL', 'NULL', '')
        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field15', 'NULL', 'output', 'NULL', 'NULL', '')
     END
     ELSE
     BEGIN
        SET @cOutField10 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
        SET @cOutField11 = @cPrefUOM_Desc
        SET @cOutField13 = @cTotalPQty
        SET @cOutField13 = @cTotalASNPQty
     END
     SET @cOutField12 = @cMstUOM_Desc
     SET @cOutField14 = @cTotalMQty
     SET @cOutField04 = @cTotalASNMQty


	  -- Go to SKU screen
	  SET @nScn = @nScn_QTY
	  SET @nStep = @nStep_QTY
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cReceiptKey = ''
      SET @cOutField01 = '' -- ReceiptKey
      SET @cOutField02 = (CASE WHEN @cPOKey = 'NOPO' THEN @cPOKey ELSE '' END)
      SET @cOutField03 = '' -- Pickslipno
      SET @cOutField04 = '' -- Externreceiptkey

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
Scn = 1792. QTY screen
   SKU            (field01) 
   DESCR          (field02, field03)
   UOM Factor     (field05)
   PUOM MUOM      (field06, field07)
   QTY RTN        (field08, field09)
   UOM Factor     (field10)
   PUOM MUOM      (field11, field12)
   TOTAL QTY      (field13, field14)
   TOTAL ASN QTY  (field13, field14)
********************************************************************************/
Step_QTY:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cActPQTY = IsNULL( @cInField08, '')
      SET @cActMQTY = IsNULL( @cInField09, '')

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

      -- Validate ActPQTY
      IF @cPrefUOM_Desc <> ''
      BEGIN
	      IF @cActPQTY = '' SET @cActPQTY = '0' -- Blank taken as zero
	      IF RDT.rdtIsValidQTY( @cActPQTY, 0) = 0
	      BEGIN
	         SET @nErrNo = 65772
	         SET @cErrMsg = rdt.rdtgetmessage( 65772, @cLangCode, 'DSP') --Invalid QTY
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
	         SET @nErrNo = 65773
	         SET @cErrMsg = rdt.rdtgetmessage( 65773, @cLangCode, 'DSP') --Invalid QTY
	         EXEC rdt.rdtSetFocusField @nMobile, 09 -- MQTY
	         GOTO QTY_Fail
	      END
      END
      ELSE 
      BEGIN
         IF @cActMQTY  = '' SET @cActMQTY  = '0' -- Blank taken as zero
	      IF RDT.rdtIsValidQTY( @cActMQTY, 0) = 0
	      BEGIN
	         SET @nErrNo = 65774
	         SET @cErrMsg = rdt.rdtgetmessage( 65774, @cLangCode, 'DSP') --Invalid QTY
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
         SET @nErrNo = 65775
         SET @cErrMsg = rdt.rdtgetmessage( 65775, @cLangCode, 'DSP') --QTY needed
         GOTO QTY_Fail
      END
      
      -- If any one of the Lottablelabels being set, will got to Screen_Lottables
--      SET @cLotFlag = 'Y'
       
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
			SET @cLottable01 = ''
			SET @cLottable02 = ''
			SET @cLottable03 = ''
			SET @dLottable04 = 0
			SET @dLottable05 = 0

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
             SELECT @cShort = ISNULL(RTRIM(C.Short),''), 
                    @cStoredProd = IsNULL(RTRIM(C.Long), '')
             FROM dbo.CodeLkUp C WITH (NOLOCK) 
             JOIN RDT.StorerConfig S WITH (NOLOCK) ON (C.ListName = S.ConfigKey AND C.Code = S.SValue)
             WHERE C.ListName = @cListName
             AND   C.Code = @cLottableLabel
         
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
					    @c_Lottable01        = @cLottable01 OUTPUT,
					    @c_Lottable02        = @cLottable02 OUTPUT,
					    @c_Lottable03        = @cLottable03 OUTPUT,
					    @dt_Lottable04       = @dLottable04 OUTPUT,
					    @dt_Lottable05       = @dLottable05 OUTPUT,
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
			   END

            -- increase counter by 1
            SET @nCount = @nCount + 1
         END -- nCount

        -- Populate labels and lottables
        IF @cLottable01Label = '' OR @cLottable01Label IS NULL
        BEGIN
           SELECT @cOutField01 = 'Lottable01:'
           SELECT @cInField02 = ''
           SET @cFieldAttr02 = 'O' -- (Vicky02)
           --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field02', 'NULL', 'output', 'NULL', 'NULL', '')
        END
        ELSE
        BEGIN                  
           SELECT @cOutField01 = @cLottable01Label
           SET @cOutField02 = ISNULL(LTRIM(RTRIM(@cLottable01)), '')
        END

        IF @cLottable02Label = '' OR @cLottable02Label IS NULL
        BEGIN
           SELECT @cOutField03 = 'Lottable02:'
           SELECT @cInField04 = ''
           SET @cFieldAttr04 = 'O' -- (Vicky02)
           --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field04', 'NULL', 'output', 'NULL', 'NULL', '')
        END
        ELSE
        BEGIN            
           SELECT @cOutField03 = @cLottable02Label
           SET @cOutField04 = ISNULL(LTRIM(RTRIM(@cLottable02)), '')
        END

        IF @cLottable03Label = '' OR @cLottable03Label IS NULL
        BEGIN
           SELECT @cOutField05 = 'Lottable03:'
           SELECT @cInField06 = ''
           SET @cFieldAttr06 = 'O' -- (Vicky02)
           --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field06', 'NULL', 'output', 'NULL', 'NULL', '')
        END
        ELSE
        BEGIN                  
           SELECT @cOutField05 = @cLottable03Label
           SET @cOutField06 = ISNULL(LTRIM(RTRIM(@cLottable03)), '')
        END

        IF @cLottable04Label = '' OR @cLottable04Label IS NULL
        BEGIN
           SELECT @cOutField07 = 'Lottable04:'
           SELECT @cInField08 = ''
           SET @cFieldAttr08 = 'O' -- (Vicky02)
           --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
        END
        ELSE
        BEGIN
           SELECT  @cOutField07 = @cLottable04Label
           IF rdt.rdtIsValidDate( @dLottable04) = 1
           BEGIN
            SET @cOutField08 = RDT.RDTFormatDate( @dLottable04)
           END
        END
-- 
-- IF @cLottable05Label = '' OR @cLottable05Label IS NULL
--           INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')
--         ELSE
--         BEGIN
--            -- Lottable05 is usually RCP_DATE
--            SELECT
--               @cOutField09 = @cLottable05Label, 
--               @cOutField10 = RDT.RDTFormatDate( @dLottable05)
--        END
        EXEC rdt.rdtSetFocusField @nMobile, 1   --set focus to 1st field
        
--         SET @cLotFlag = 'Y' 
      END -- lottablelabel <> ''
      ELSE
      BEGIN
        -- Prepare Lottable Screen
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
		SET @cLottable01 = ''
		SET @cLottable02 = ''
		SET @cLottable03 = ''
		SET @dLottable04 = 0
		SET @dLottable05 = 0
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

        IF @cLottable01Label = '' OR @cLottable01Label IS NULL
        BEGIN
           SELECT @cOutField01 = 'Lottable01:'
           SELECT @cInField02 = ''
           SET @cFieldAttr02 = 'O' -- (Vicky02)
           --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field02', 'NULL', 'output', 'NULL', 'NULL', '')
        END
  
        IF @cLottable02Label = '' OR @cLottable02Label IS NULL
        BEGIN
           SELECT @cOutField03 = 'Lottable02:'
           SELECT @cInField04 = ''
           SET @cFieldAttr04 = 'O' -- (Vicky02)
           --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field04', 'NULL', 'output', 'NULL', 'NULL', '')
        END
  
        IF @cLottable03Label = '' OR @cLottable03Label IS NULL
        BEGIN
           SELECT @cOutField05 = 'Lottable03:'
           SELECT @cInField06 = ''
           SET @cFieldAttr06 = 'O' -- (Vicky02)
           --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field06', 'NULL', 'output', 'NULL', 'NULL', '')
        END

        IF @cLottable04Label = '' OR @cLottable04Label IS NULL
        BEGIN
           SELECT @cOutField07 = 'Lottable04:'
           SELECT @cInField08 = ''
           SET @cFieldAttr08 = 'O' -- (Vicky02)
           --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
        END
      END

      SET @nScn  = @nScn_Lottables
      SET @nStep = @nStep_Lottables

      SET @nPrevScn = @nScn_QTY
      SET @nPrevStep = @nStep_QTY

--      IF (IsNULL(@cLottable01Label, '') = '') AND (IsNULL(@cLottable02Label, '') = '') AND (IsNULL(@cLottable03Label, '') = '') AND 
--         (IsNULL(@cLottable04Label, '') = '') AND (IsNULL(@cLottable05Label, '') <> '')
--      BEGIN
--         SET @cLotFlag = 'N' 
--      END

--      SET @cReturnReason = 'N'
--      SET @cOverRcpt = 'N'
--      SET @cSNFlag = 'N'
--
--      SET @cSubReason = ''
--      SELECT @cSubReason =  ISNULL(RTRIM(SubReasonCode),'')
--      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
--      WHERE ReceiptKey = @cReceiptkey
--         AND   POKey = CASE WHEN UPPER(@cPOKey) = 'NOPO' THEN '' ELSE @cPOKey END
--         AND   SKU = @cSKU
--         AND   Lottable01 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE '' END
--         AND   Lottable02 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE '' END
--         AND   Lottable03 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE '' END
--         AND   Lottable04 = CASE WHEN @dLottable04 <> '' THEN @dLottable04 ELSE '' END
--         AND   Lottable05 = CASE WHEN @dLottable05 <> '' THEN @dLottable05 ELSE '' END

      -- Exceed Storerconfig ReturnReason or Allow_OverReceipt or ExpiredReason criterias are matched
      -- wll go to Screen_SerialNo
--      IF EXISTS (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK) 
--                 WHERE Configkey = 'ReturnReason'
--                 AND   Storerkey = @cStorerkey
--                 AND   sValue = '1')
--      BEGIN
--            IF @cSubReason = ''
--            SET @cReturnReason = 'Y'  
--      END
--
--      IF EXISTS (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK) 
--                 WHERE Configkey = 'Allow_OverReceipt'
--                 AND   Storerkey = @cStorerkey
--                 AND   sValue = '1')
--      BEGIN
--         IF EXISTS (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK) 
--                    WHERE Configkey = 'ByPassTolerance'
--                    AND   Storerkey = @cStorerkey
--                    AND   sValue <> '1')
--         BEGIN
--             --IF @nActQTY > @nQTY 
--             IF (@nActQTY + @nBeforeReceivedQty) > @nQTY AND @cSubReason = ''
--             BEGIN
--                SET @cOverRcpt = 'Y' 
--             END
--         END
--      END

--      IF (@cLotFlag <> 'Y') AND (@cReturnReason = 'Y' OR @cOverRcpt = 'Y')
--      BEGIN
--         --prepare SerialNo screen variable
--			SET @cOutField01 = '' --lottable01
--			SET @cOutField02 = '' --lottable02
--			SET @cOutField03 = '' --lottable03
--			SET @cOutField04 = '' --lottable04
--			SET @cOutField05 = '' --lottable05
--			SET @cOutField06 = '' 
--			SET @cOutField07 = '' 
--			SET @cOutField08 = '' 
--			SET @cOutField09 = '' 
--			SET @cOutField10 = '' 
--         SET @cSNFlag = 'Y'
--         SET @nScn  = @nScn_SubReason
--         SET @nStep = @nStep_SubReason
--
--         SET @nPrevScn = @nScn_QTY
--	      SET @nPrevStep = @nStep_QTY
--      END

--      IF (@cLotFlag <> 'Y') AND (@cReturnReason <> 'Y') AND (@cOverRcpt <> 'Y')
--      BEGIN
--        -- Prep LOC screen var
--			SET @cOutField01 = @cSKU
--			SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)
--			SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
--         SET @cOutField04 = '' -- Lottable02
--         SET @cOutField05 = '' -- Lottable03
--         SET @cOutField06 = '' -- Lottable04
--         IF @cPrefUOM_Desc = ''
--         BEGIN
--				SET @cOutField07 = '' -- @nPrefUOM_Div
--				SET @cOutField08 = '' -- @cPrefUOM_Desc
--				SET @cOutField10 = '' -- @nActPQTY
--				-- Disable pref QTY field
--				INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')
--         END
--         ELSE
--         BEGIN
--				SET @cOutField07 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
--				SET @cOutField08 = @cPrefUOM_Desc
--				SET @cOutField10 = CAST( @nActPQTY AS NVARCHAR( 5))
--	      END
--         SET @cOutField09 = @cMstUOM_Desc
--         SET @cOutField11 = CAST( @nActMQTY as NVARCHAR( 5))
--         SET @cOutField12 = '' -- SN
--
--         SET @cSNFlag = 'Y'
--         SET @nScn  = @nScn_LOC
--         SET @nStep = @nStep_LOC
--
--         SET @nPrevScn = @nScn_QTY
--	     SET @nPrevStep = @nStep_QTY
--      END

   END 

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare SKU screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- SKUDecr
      SET @cOutField05 = '' -- SKUDecr
      SET @cOutField06 = @cPickSlipNo
      SET @cOutField07 = @cExternReceiptKey  
      
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
      SET @cFieldAttr13 = ''
      -- (Vicky02) - End

      IF @cPrefUOM_Desc = ''
      BEGIN
         -- Pref QTY is always enable (as screen defination). When reach error, it will quit directly and forgot
         -- to disable the Pref QTY field. So centralize disable it here for all fail condition
         -- Disable pref QTY field
         SET @cFieldAttr08 = 'O' -- (Vicky02)
         --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
      END
      ELSE
      BEGIN
         SET @cOutField08 = @cActPQTY  -- ActMQTY
      END

      SET @cOutField09 = @cActMQTY-- ActMQTY

     IF @cPrefUOM_Desc = ''
     BEGIN
        SET @cOutField10 = '' -- @nPrefUOM_Div
        SET @cOutField11 = '' -- @cPrefUOM_Desc
        SET @cOutField13 = '' -- @cPrefQTY
        -- Disable pref QTY field
        SET @cFieldAttr13 = 'O' -- (Vicky02) 
        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field13', 'NULL', 'output', 'NULL', 'NULL', '')
     END
     ELSE
     BEGIN
        SET @cOutField10 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
        SET @cOutField11 = @cPrefUOM_Desc
        SET @cOutField13 = @cTotalPQty
     END
     SET @cOutField12 = @cMstUOM_Desc
     SET @cOutField14 = @cTotalMQty
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
    SET @cFieldAttr13 = ''
    -- (Vicky02) - End

    IF @cPrefUOM_Desc = ''
    BEGIN
        SET @cFieldAttr08 = 'O' -- (Vicky02) 
       --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
       SET @cOutField09 = @cActMQTY
    END
    ELSE
    BEGIN
        SET @cOutField08 = @cActPQTY
        SET @cOutField09 = @cActMQTY
    END

     IF @cPrefUOM_Desc = ''
     BEGIN
        SET @cOutField10 = '' -- @nPrefUOM_Div
        SET @cOutField11 = '' -- @cPrefUOM_Desc
        SET @cOutField13 = '' -- @cPrefQTY
        -- Disable pref QTY field
        SET @cFieldAttr13 = 'O' -- (Vicky02) 
        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field13', 'NULL', 'output', 'NULL', 'NULL', '')
     END
     ELSE
     BEGIN
        SET @cOutField10 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
        SET @cOutField11 = @cPrefUOM_Desc
        SET @cOutField13 = @cTotalPQty
     END
     SET @cOutField12 = @cMstUOM_Desc
     SET @cOutField14 = @cTotalMQty

    
     GOTO Quit
   END
END
GOTO Quit


/********************************************************************************
Scn = 1793. Lottables screen
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
     
      SET @cSerialNo = @cInField09 -- SN

      --retain original value for lottable01-05
      SET @cLottable01 = @cTempLottable01
      SET @cLottable02 = @cTempLottable02
      SET @cLottable03 = @cTempLottable03
      SET @cOutField02 = @cLottable01
      SET @cOutField04 = @cLottable02
      SET @cOutField06 = @cLottable03

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

      -- For Ciba TW 
      -- To default day as '01' for Lottable04 value and the default date format is YYYYMMDD
      IF @cTempLottable04 <> '' AND @cCBADefaultLot4 <> '' 
      BEGIN
        DECLARE @cDateFormat NVARCHAR( 3)
        DECLARE @cDD         NVARCHAR( 2)
        DECLARE @cMM         NVARCHAR( 2)
        DECLARE @cYYYY       NVARCHAR( 4)
        DECLARE @cDelimeter1 NVARCHAR( 1)
        DECLARE @cDelimeter2 NVARCHAR( 1)

--        IF IsIsDate(@cTempLottable04) = 0
--        BEGIN
         SET @cTempLottable04 = SUBSTRING(RTRIM(@cTempLottable04), 1,4) + '/' +  SUBSTRING(RTRIM(@cTempLottable04), 5,2) + '/' + RTRIM(@cCBADefaultLot4)
--        END
           
        SET @cYYYY       = SUBSTRING( @cTempLottable04, 1, 4)
        SET @cDelimeter1 = SUBSTRING( @cTempLottable04, 5, 1)
        SET @cMM         = SUBSTRING( @cTempLottable04, 6, 2)
        SET @cDelimeter2 = SUBSTRING( @cTempLottable04, 8, 1)
        SET @cDD         = SUBSTRING( @cTempLottable04, 9, 2)

        DECLARE @nDD INT
        -- Check Day
        IF RDT.rdtIsInteger( @cDD) = 0
        BEGIN
          SET @nErrNo = 65793
          SET @cErrMsg = rdt.rdtgetmessage( 65793, @cLangCode, 'DSP') --Invalid Day
          EXEC rdt.rdtSetFocusField @nMobile, 8 -- Lottable04
          GOTO Lottables_Fail
        END

        SET @nDD = CAST( @cDD AS INT)

        IF @nDD < 1 OR @nDD > 31
        BEGIN
          SET @nErrNo = 65794
          SET @cErrMsg = rdt.rdtgetmessage( 65794, @cLangCode, 'DSP') --Invalid Day
          EXEC rdt.rdtSetFocusField @nMobile, 8 -- Lottable04
          GOTO Lottables_Fail
        END

        DECLARE @nMM INT
        -- Check Month
        IF RDT.rdtIsInteger( @cMM) = 0
        BEGIN
          SET @nErrNo = 65795
          SET @cErrMsg = rdt.rdtgetmessage( 65795, @cLangCode, 'DSP') --Invalid Month
          EXEC rdt.rdtSetFocusField @nMobile, 8 -- Lottable04
          GOTO Lottables_Fail
        END

        SET @nMM = CAST( @cMM AS INT)

        IF @nMM < 1 OR @nMM > 12
        BEGIN
          SET @nErrNo = 65796
          SET @cErrMsg = rdt.rdtgetmessage( 65796, @cLangCode, 'DSP') --Invalid Month
          EXEC rdt.rdtSetFocusField @nMobile, 8 -- Lottable04
          GOTO Lottables_Fail
        END
         
        DECLARE @nYYYY INT  
        -- Check Year
        IF RDT.rdtIsInteger( @cYYYY) = 0
        BEGIN
          SET @nErrNo = 65797
          SET @cErrMsg = rdt.rdtgetmessage( 65797, @cLangCode, 'DSP') --Invalid Year
          EXEC rdt.rdtSetFocusField @nMobile, 8 -- Lottable04
          GOTO Lottables_Fail
        END

        SET @nYYYY = CAST( @cYYYY AS INT)

        IF @nYYYY < 1900 OR @nYYYY > 2078
        BEGIN
          SET @nErrNo = 65798
          SET @cErrMsg = rdt.rdtgetmessage( 65798, @cLangCode, 'DSP') --Invalid Year
          EXEC rdt.rdtSetFocusField @nMobile, 8 -- Lottable04
          GOTO Lottables_Fail
        END
      END

      IF @cTempLottable04 <> '' AND rdt.rdtIsValidDate( @cTempLottable04) = 0
      BEGIN
         SET @nErrNo = 65776
         SET @cErrMsg = rdt.rdtgetmessage( 65776, @cLangCode, 'DSP') --Invalid Date
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- Lottable04
         SET @dLottable04 = NULL
         GOTO Lottables_Fail
      END

       --retain original value for lottable01-05
      IF @cCBADefaultLot4 = ''
      BEGIN
        SET @dLottable04 = CAST(@cTempLottable04 as DATETIME)
      END
      ELSE
      BEGIN
        SET @dLottable04 = CONVERT(datetime, @cTempLottable04, 111)
      END

      IF @cCBADefaultLot4 = ''
      BEGIN
        SET @cOutField08 = CASE WHEN @dLottable04 <> 0  THEN rdt.rdtFormatDate( @dLottable04) ELSE @cTempLottable04 END
      END
      ELSE
      BEGIN
        SET @cOutField08 = @cTempLottable04
      END

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
		  SELECT @cShort = C.Short, 
				   @cStoredProd = IsNULL( C.Long, ''), 
				   @cLottableLabel = C.Code
		  FROM dbo.CodeLkUp C WITH (NOLOCK) 
		  WHERE C.Listname = @cListName
		  AND   C.Code = @cTempLotLabel

		  IF @cShort = 'POST' AND @cStoredProd <> ''
		  BEGIN
           
           IF rdt.rdtIsValidDate( @cTempLottable04) = 1 --valid date
           BEGIN
              IF @cCBADefaultLot4 = ''
              BEGIN
   	   		  SET @dTempLottable04 = CAST( @cTempLottable04 AS DATETIME)
              END
              ELSE
              BEGIN
                 SET @dTempLottable04 = CONVERT(datetime, @cTempLottable04, 111)
              END
           END
			  
           IF rdt.rdtIsValidDate(@cTempLottable05) = 1 --valid date
			     SET @dTempLottable05 = CAST( @cTempLottable05 AS DATETIME)

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
					  @c_Lottable01        = @cLottable01 OUTPUT,
					  @c_Lottable02        = @cLottable02 OUTPUT,
					  @c_Lottable03        = @cLottable03 OUTPUT,
					  @dt_Lottable04       = @dLottable04 OUTPUT,
					  @dt_Lottable05       = @dLottable05 OUTPUT,
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
                    IF rdt.rdtIsValidDate( @cTempLottable04) = 1 --valid date
                    BEGIN
                      IF @cCBADefaultLot4 = ''
                      BEGIN
                         SET @dLottable04 = CAST(@cTempLottable04 as DATETIME)
                      END
                      ELSE
                      BEGIN
                         SET @dLottable04 = CONVERT(datetime, @cTempLottable04, 111)
                      END
                    END
                     
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
					  SET @cOutField08 = CASE WHEN @dLottable04 <> 0 AND @cCBADefaultLot4 = '' THEN rdt.rdtFormatDate( @dLottable04) 
                                         WHEN @dLottable04 <> 0 AND @cCBADefaultLot4 <> '' THEN @dLottable04
                                         ELSE @cTempLottable04 END

                 SET @cLottable01 = IsNULL(@cOutField02, '')
                 SET @cLottable02 = IsNULL(@cOutField04, '')
					  SET @cLottable03 = IsNULL(@cOutField06, '')
					  SET @dLottable04 = IsNULL(CAST(@cOutField08 AS DATETIME), 0)

--					 SET @cErrMsg = IsNULL(CAST(@dLottable04 AS DATETIME), 0) 
--					 GOTO Lottables_Fail
        END 

			--increase counter by 1
			SET @nCount = @nCount + 1

     END -- end of while

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
      IF (@cTempLotLabel01 <> '' AND @cTempLottable01 = '' AND @cLottable01 = '')
      BEGIN
           SET @nErrNo = 65777
           SET @cErrMsg = rdt.rdtgetmessage(65777, @cLangCode, 'DSP') --Lottable01 Req
           EXEC rdt.rdtSetFocusField @nMobile, 2
           GOTO Lottables_Fail   
      END

		--if lottable02 has been setup but no value, prompt error msg
		IF (@cTempLotLabel02 <> '' AND @cTempLottable02 = '' AND @cLottable02 = '')
		BEGIN
			 SET @nErrNo = 65778
			 SET @cErrMsg = rdt.rdtgetmessage(65778, @cLangCode, 'DSP') --Lottable02 Req
          EXEC rdt.rdtSetFocusField @nMobile, 4
			 GOTO Lottables_Fail 
		END

      --if lottable03 has been setup but no value, prompt error msg
      IF (@cTempLotLabel03 <> '' AND @cTempLottable03 = '' AND @cLottable03 = '')
      BEGIN
           SET @nErrNo = 65779
           SET @cErrMsg = rdt.rdtgetmessage(65779, @cLangCode, 'DSP') --Lottable03 Req
           EXEC rdt.rdtSetFocusField @nMobile, 6
           GOTO Lottables_Fail 
      END

      --if lottable04 has been setup but no value, prompt error msg
      IF (@cTempLotLabel04 <> '' AND @cTempLottable04 = '' AND @dLottable04 = 0) 
      BEGIN
           SET @nErrNo = 65780
           SET @cErrMsg = rdt.rdtgetmessage(65780, @cLangCode, 'DSP') --Lottable04 Req
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

      IF (@cSerialNo = '' OR @cSerialNo IS NULL)
      BEGIN
          SET @nErrNo = 65781
          SET @cErrMsg = rdt.rdtgetmessage(65781, @cLangCode, 'DSP') -- Serial# Required
          SET @nSNExists = 0
          EXEC rdt.rdtSetFocusField @nMobile, 9
          GOTO Lottables_Fail 
      END
      
      IF @cSerialNo <> ''
      BEGIN
			IF NOT EXISTS (SELECT 1 FROM dbo.SERIALNO WITH (NOLOCK) 
					         WHERE Storerkey = @cStorerkey
                        AND SKU = @cSKU
                        AND SerialNo = @cSerialNo)
			BEGIN
          SET @nErrNo = 65782
          SET @cErrMsg = rdt.rdtgetmessage(65782, @cLangCode, 'DSP') -- SN# Not Exists
          SET @nSNExists = 0
   		END
         ELSE
         BEGIN
          SET @nSNExists = 1
         END
      END -- SN <> ''

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
			   SET @nErrNo = 65783
			   SET @cErrMsg = rdt.rdtgetmessage(65783, @cLangCode, 'DSP') -- No Pick Face
			END 
      END


      IF @cDefaultLOC = 'SKURETLOC'
      BEGIN 		
         SET @cDefaultLOC = ''
         SELECT @cDefaultLOC = IsNULL(ReturnLoc, '')
         FROM dbo.SKU WITH (NOLOCK)
         WHERE SKU = @cSKU
         AND   Storerkey = @cStorerkey
         
         IF @cDefaultLOC = ''
		   BEGIN
			   SET @nErrNo = 65784
			   SET @cErrMsg = rdt.rdtgetmessage(65784, @cLangCode, 'DSP') -- No Return Loc
			END 
      END


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
            (IsNUMERIC(@cSUSR1) = 1)
         BEGIN
            IF (CAST(@cSUSR1 AS FLOAT) > 0) AND ((CAST(@cOutField08 as datetime) + CAST(@cSUSR1 AS FLOAT) <= GetDate())) AND @cSubReason = ''
            BEGIN
               SET @cExpReason = 'Y'
            END
         END 
      END

      IF (@cReturnReason = 'Y') OR (@cOverRcpt  = 'Y') OR (@cExpReason = 'Y')
      BEGIN
      --prepare SubReason screen variable
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
         SET @cSNFlag = 'Y'
         SET @nScn  = @nScn_SubReason
         SET @nStep = @nStep_SubReason

         SET @nPrevScn  = @nScn_Lottables
         SET @nPrevStep = @nStep_Lottables
      END    

      IF (@cReturnReason <> 'Y') AND (@cOverRcpt <> 'Y') AND (@cExpReason <> 'Y')
      BEGIN
        -- Prep LOC screen var
		 SET @cOutField01 = @cSKU
		 SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)
		 SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField04 = @cLottable02 -- Lottable02
         SET @cOutField05 = @cLottable03 -- Lottable03
         SET @cOutField06 = CASE WHEN @cCBADefaultLot4 = '' THEN rdt.rdtFormatDate(@dLottable04) ELSE  @cTempLottable04 END-- Lottable04
         IF @cPrefUOM_Desc = ''
         BEGIN
				SET @cOutField07 = '' -- @nPrefUOM_Div
				SET @cOutField08 = '' -- @cPrefUOM_Desc
				SET @cOutField10 = '' -- @nActPQTY
				-- Disable pref QTY field
            SET @cFieldAttr10 = 'O' -- (Vicky02)
				--INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')
         END
         ELSE
         BEGIN
				SET @cOutField07 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
				SET @cOutField08 = @cPrefUOM_Desc
				SET @cOutField10 = CAST( @nActPQTY AS NVARCHAR( 5))
	      END
         SET @cOutField09 = @cMstUOM_Desc
         SET @cOutField11 = CAST( @nActMQTY as NVARCHAR( 5))
		   SET @cOutField12 = @cSerialNo -- SN
         SET @cOutField13 = @cDefaultLOC -- If default loc

         SET @cSNFlag = 'Y'
         SET @nScn  = @nScn_LOC
         SET @nStep = @nStep_LOC


         SET @nPrevScn  = @nScn_Lottables
         SET @nPrevStep = @nStep_Lottables
      END

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
        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
     END
     ELSE
     BEGIN
        SET @cOutField05 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
        SET @cOutField06 = @cPrefUOM_Desc
        --SET @cOutField07 = CAST( @nPQTY AS NVARCHAR( 5))
        SET @cOutField08 = '' -- @nActPQTY
        
     END
     SET @cOutField07 = @cMstUOM_Desc
     --SET @cOutField09 = ''--CAST( @nMQTY as NVARCHAR( 5))
     SET @cOutField09 = CAST(@nActMQTY as NVARCHAR( 5))--@cDefaultMQTY
--     SET @cOutField11 = '' -- @nActMQTY


     IF @cPrefUOM_Desc = ''
     BEGIN
        SET @cOutField10 = '' -- @nPrefUOM_Div
        SET @cOutField11 = '' -- @cPrefUOM_Desc
        SET @cOutField13 = '' -- @cPrefQTY
        -- Disable pref QTY field
        SET @cFieldAttr13 = 'O' -- (Vicky02)
        --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field13', 'NULL', 'output', 'NULL', 'NULL', '')
     END
     ELSE
     BEGIN
        SET @cOutField10 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
        SET @cOutField11 = @cPrefUOM_Desc
        SET @cOutField13 = @cTotalPQty
     END
     SET @cOutField12 = @cMstUOM_Desc
     SET @cOutField14 = @cTotalMQty

     SET @cInField02 = ''
	  SET @cInField04 = ''
	  SET @cInField06 = ''
	  SET @cInField08 = ''
	  SET @cInField10 = ''
	  SET @cInField11 = ''
	  SET @cInField12 = ''
	  SET @cInField13 = ''

      -- Go to prev screen
      SET @nScn = @nScn_QTY
      SET @nStep = @nStep_QTY
   END
   GOTO Quit

  
   Lottables_Fail:
   BEGIN
--        SELECT 
--            @cOutField01 = 'Lottable01:', 
--            @cOutField03 = 'Lottable02:',
--            @cOutField05 = 'Lottable03:', 
--            @cOutField07 = 'Lottable04:', 
--            @cOutField09 = 'Lottable05:'

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


         -- Populate labels and lottables
         IF @cLottable01Label = '' OR @cLottable01Label IS NULL
         BEGIN
            SELECT @cOutField01 = 'Lottable01:'
            SET @cFieldAttr02 = 'O' -- (Vicky02)
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field02', 'NULL', 'output', 'NULL', 'NULL', '')
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
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field04', 'NULL', 'output', 'NULL', 'NULL', '')
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
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field06', 'NULL', 'output', 'NULL', 'NULL', '')
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
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
         END
         ELSE
         BEGIN
            SELECT  @cOutField07 = @cLottable04Label
         
            IF @dLottable04 <> NULL AND rdt.rdtIsValidDate( @dLottable04) = 1
            BEGIN
               SET @cOutField08 = CASE WHEN @cCBADefaultLot4 = '' THEN RDT.RDTFormatDate(@dLottable04) 
                                  ELSE SUBSTRING(RTRIM(@cTempLottable04), 1,4) +  SUBSTRING(RTRIM(@cTempLottable04), 6,2) END
            END
            ELSE
               SET @cOutField08 = @cTempLottable04
            
         END

         -- Serial No field
         SET @cOutField09 = @cSerialNo

--          IF @cLottable05Label = '' OR @cLottable05Label IS NULL
--             INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')
--          ELSE
--          BEGIN
--             -- Lottable05 is usually RCP_DATE
-- 
--             SELECT
--                @cOutField09 = @cLottable05Label, 
--                @cOutField10 = RDT.RDTFormatDate( @dLottable05)
--          END
        -- EXEC rdt.rdtSetFocusField @nMobile, 1   --set focus to 1st field
      GOTO Quit
   END

END
GOTO Quit


/***********************************************************************************
Scn = 1794. Subreason screen
    Subreason (field01, input)
************************************************************************************/
Step_SubReason:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSubReason = @cInField01

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
      
      -- Verify SubReasonCode
      IF @cSubReason = '' AND @cReturnReason = 'Y' 
      BEGIN
           SET @nErrNo = 65785
           SET @cErrMsg = rdt.rdtgetmessage(65785, @cLangCode, 'DSP') --Return Reason
           GOTO SubReason_Fail 
      END

      IF @cSubReason = '' AND @cOverRcpt = 'Y' 
      BEGIN
           SET @nErrNo = 65786
           SET @cErrMsg = rdt.rdtgetmessage(65786, @cLangCode, 'DSP') --OverRcv Reason
           GOTO SubReason_Fail 
      END

      IF @cSubReason = '' AND @cExpReason = 'Y' 
      BEGIN
       SET @nErrNo = 65787
           SET @cErrMsg = rdt.rdtgetmessage(65787, @cLangCode, 'DSP') --Expired Reason
           GOTO SubReason_Fail 
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                 WHERE Listname = 'ASNSUBRSN'
                 AND   Code = @cSubReason)
      BEGIN
           SET @nErrNo = 65788
           SET @cErrMsg = rdt.rdtgetmessage(65788, @cLangCode, 'DSP') --Bad Subreason
           GOTO SubReason_Fail 
      END
	   
   	 -- Prep LOC screen var
		SET @cOutField01 = @cSKU
		SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)
		SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
--      IF @cLotFlag = 'Y'
--      BEGIN
		  SET @cOutField04 = @cLottable02 -- Lottable02
		  SET @cOutField05 = @cLottable03 -- Lottable03
		  SET @cOutField06 = CASE WHEN @cCBADefaultLot4 = '' THEN rdt.rdtFormatDate(@dLottable04) ELSE @cTempLottable04 END--rdt.rdtFormatDate(@dLottable04) -- Lottable04
--      END
--      ELSE
--      BEGIN
--        SET @cOutField04 = ''
--        SET @cOutField05 = ''
--        SET @cOutField06 = ''
--      END
		IF @cPrefUOM_Desc = ''
		BEGIN
				 SET @cOutField07 = '' -- @nPrefUOM_Div
				 SET @cOutField08 = '' -- @cPrefUOM_Desc
				 SET @cOutField10 = '' -- @nActPQTY
				 -- Disable pref QTY field
             SET @cFieldAttr10 = 'O' -- (Vicky02)
				 --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')
		END
		ELSE
		BEGIN
				 SET @cOutField07 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
				 SET @cOutField08 = @cPrefUOM_Desc
				 SET @cOutField10 = CAST( @nActPQTY AS NVARCHAR( 5))
		END
		SET @cOutField09 = @cMstUOM_Desc
		SET @cOutField11 = CAST( @nActMQTY as NVARCHAR( 5))
		SET @cOutField12 = @cSerialNo -- SN
		SET @cOutField13 = @cDefaultLOC -- If there's default

		SET @nScn  = @nScn_LOC
		SET @nStep = @nStep_LOC

		SET @nPrevScn  = @nScn_SubReason
		SET @nPrevStep = @nStep_SubReason
      
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
     IF @nPrevScn  = @nScn_Lottables
     BEGIN    
-- SET @cOutField01 = @cLottable01
--		 SET @cOutField02 = @cLottable02
--		 SET @cOutField03 = @cLottable03
--		 SET @cOutField04 = rdt.rdtFormatDate(@dLottable04) 
--		 SET @cOutField05 = rdt.rdtFormatDate(@dLottable05) 
--       EXEC rdt.rdtSetFocusField @nMobile, 1 -- Lottable01
            -- Populate labels and lottables
         IF @cLottable01Label = '' OR @cLottable01Label IS NULL
         BEGIN
            SET @cOutField01 = 'Lottable01:'
            SET @cInField02 = ''
            SET @cFieldAttr02 = 'O' -- (Vicky02)    
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field02', 'NULL', 'output', 'NULL', 'NULL', '')
         END
         ELSE
         BEGIN                  
            SELECT @cOutField01 = @cLottable01Label
            SET @cOutField02 = ISNULL(LTRIM(RTRIM(@cLottable01)), '')
         END

         IF @cLottable02Label = '' OR @cLottable02Label IS NULL
         BEGIN
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field04', 'NULL', 'output', 'NULL', 'NULL', '')
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
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field06', 'NULL', 'output', 'NULL', 'NULL', '')
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
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
            SET @cOutField07 = 'Lottable04:'
            SET @cInField08 = ''
            SET @cFieldAttr08 = 'O' -- (Vicky02)    
         END
         ELSE
         BEGIN
            SELECT  @cOutField07 = @cLottable04Label
            IF rdt.rdtIsValidDate( @dLottable04) = 1
            BEGIN
               SET @cOutField08 = CASE WHEN @cCBADefaultLot4 = '' THEN RDT.RDTFormatDate( @dLottable04) 
                                   ELSE SUBSTRING(RTRIM(@cTempLottable04), 1,4) +  SUBSTRING(RTRIM(@cTempLottable04), 6,2) END
            END
         END

         -- SN Field
         SET @cOutField09 = @cSerialNo

--          IF @cLottable05Label = '' OR @cLottable05Label IS NULL
--          BEGIN
--             INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')
--             SET @cOutField09 = ''
--          END
--          ELSE
--          BEGIN
--             -- Lottable05 is usually RCP_DATE
--             IF @cLottable05Label = 'RCP_DATE'
--  SET @dLottable05 = GETDATE()
-- 
--             SELECT
--                @cOutField09 = @cLottable05Label, 
--                @cOutField10 = RDT.RDTFormatDate( @dLottable05)
--          END
         EXEC rdt.rdtSetFocusField @nMobile, 1   --set focus to 1st field

       SET @nScn = @nScn_Lottables
       SET @nStep = @nStep_Lottables
     END
--     ELSE IF @nPrevScn  = @nScn_QTY
--     BEGIN
--		 -- Prep QTY screen var
--		 SET @cOutField01 = @cSKU
--		 SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)
--		 SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
--		 SET @cOutField04 = @cIVAS
--		 IF @cPrefUOM_Desc = ''
--		 BEGIN
--			 SET @cOutField05 = '' -- @nPrefUOM_Div
--			 SET @cOutField06 = '' -- @cPrefUOM_Desc
--			 --SET @cOutField07 = '' -- @nPQTY
--			 SET @cOutField08 = '' -- @nActPQTY
--			 -- Disable pref QTY field
--			 INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
--		 END
--		 ELSE
--		 BEGIN
--			 SET @cOutField05 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
--			 SET @cOutField06 = @cPrefUOM_Desc
--			 --SET @cOutField07 = CAST( @nPQTY AS NVARCHAR( 5))
--			 SET @cOutField08 = '' -- @nActPQTY
--		 END
--		 SET @cOutField07 = @cMstUOM_Desc
--		 SET @cOutField09 = ''--CAST( @nMQTY as NVARCHAR( 5))
--					  --     SET @cOutField11 = '' -- @nActMQTY
--
--     IF @cPrefUOM_Desc = ''
--     BEGIN
--        SET @cOutField10 = '' -- @nPrefUOM_Div
--        SET @cOutField11 = '' -- @cPrefUOM_Desc
--        SET @cOutField13 = '' -- @cPrefQTY
--        -- Disable pref QTY field
--        INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field13', 'NULL', 'output', 'NULL', 'NULL', '')
--     END
--     ELSE
--     BEGIN
--        SET @cOutField10 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
--        SET @cOutField11 = @cPrefUOM_Desc
--        SET @cOutField13 = @cTotalPQty
--     END
--     SET @cOutField12 = @cMstUOM_Desc
--     SET @cOutField14 = @cTotalMQty
--
--
--		 SET @cInField02 = ''
--		 SET @cInField04 = ''
--		 SET @cInField06 = ''
--		 SET @cInField08 = ''
--		 SET @cInField10 = ''
--		 SET @cInField11 = ''
--		 SET @cInField12 = ''
--		 SET @cInField13 = ''
--
--		  -- Go to prev screen
--		 SET @nScn = @nScn_QTY
--		 SET @nStep = @nStep_QTY
--   END
  END
  GOTO Quit

  SubReason_Fail:
  BEGIN
      SET @cOutField01 = @cSubReason  -- Subreason
  END
END
GOTO Quit



/********************************************************************************
Scn = 1795. LOC screen
   SKU       (field01)
   SKUDescr  (field02)
   SKUDescr  (field03)
   LOTTABLE2 (field04)
   LOTTABLE3 (field05)
   LOTTABLE4 (field06)
   UOM Factor(field07)
   PUOM MUOM (field08, field09)
   QTY RTN   (field10, field11)
   SN        (field12)
   LOC       (field13, input)
********************************************************************************/
Step_LOC:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField13 -- LOC

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
	     
      IF @cLOC = ''
      BEGIN
            SET @nErrNo = 65789
            SET @cErrMsg = rdt.rdtgetmessage(65789, @cLangCode, 'DSP') -- LOC needed
            GOTO LOC_Fail 
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                     WHERE LOC = @cLOC)
      BEGIN
            SET @nErrNo = 65790
            SET @cErrMsg = rdt.rdtgetmessage(65790, @cLangCode, 'DSP') -- Invalid LOC
            GOTO LOC_Fail 
      END
       
      IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                     WHERE LOC = @cLOC
                     AND   Facility = @cFacility)
      BEGIN
            SET @nErrNo = 65791
            SET @cErrMsg = rdt.rdtgetmessage(65791, @cLangCode, 'DSP') -- Diff facility
            GOTO LOC_Fail 
      END

      --process rdt.rdt_receive
      DECLARE @cTempConditionCode NVARCHAR(10)
      SET @cTempConditionCode = 'OK' 


      --set @cPokey value to blank when it is 'NOPO'
      SET @cPOKeyValue = CASE WHEN UPPER(@cPOkey) = 'NOPO' THEN '' ELSE @cPOkey END


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
			@nNOPOFlag     = 0,
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
             @cRefNo1       = @cReceiptKey,
             @cRefNo2       = @cPOKeyValue
      END

      -- Delete Serial No
      IF @nSNExists = 1
      BEGIN
         BEGIN TRAN

         DELETE FROM dbo.SERIALNO 
         WHERE SERIALNO = @cSerialNo 
         AND STORERKEY = @cStorerKey
         AND SKU = @cSKU

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @cErrMsg = rdt.rdtgetmessage( 65792, @cLangCode, 'DSP') --Delete SN# Err
            GOTO LOC_Fail
         END
         ELSE
         BEGIN

            COMMIT TRAN
         END
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

		SET @nScn  = @nScn_MsgSuccess
		SET @nStep = @nStep_MsgSuccess

--      IF @cLotFlag = 'Y' AND ( (@cReturnReason <> 'Y') AND (@cOverRcpt <> 'Y') AND (@cExpReason <> 'Y'))
--      BEGIN
--         SET @nPrevScn  = @nScn_Lottables
--   	   SET @nPrevStep = @nStep_Lottables
--      END
--      ELSE IF @cLotFlag <> 'Y' AND ( (@cReturnReason = 'Y') OR (@cOverRcpt = 'Y') OR (@cExpReason = 'Y'))
--      BEGIN
--   	   SET @nPrevScn  = @nScn_Subreason
--   	   SET @nPrevStep = @nStep_Subreason
--      END
--      ELSE IF @cLotFlag <> 'Y' AND ( (@cReturnReason <> 'Y') OR (@cOverRcpt <> 'Y') OR (@cExpReason <> 'Y'))
--      BEGIN
--   	   SET @nPrevScn  = @nScn_QTY
--   	   SET @nPrevStep = @nStep_QTY
--      END

      IF (@cReturnReason <> 'Y') AND (@cOverRcpt <> 'Y') AND (@cExpReason <> 'Y')
      BEGIN
         SET @nPrevScn  = @nScn_Lottables
   	   SET @nPrevStep = @nStep_Lottables
      END
      ELSE IF (@cReturnReason = 'Y') OR (@cOverRcpt = 'Y') OR (@cExpReason = 'Y')
      BEGIN
   	   SET @nPrevScn  = @nScn_Subreason
   	   SET @nPrevStep = @nStep_Subreason
      END
      

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
     IF @nPrevScn  = @nScn_Lottables
     BEGIN   
        -- Populate labels and lottables
         IF @cLottable01Label = '' OR @cLottable01Label IS NULL
         BEGIN
            SET @cOutField01 = 'Lottable01:'
            SET @cInField02 = ''
            SET @cFieldAttr02 = 'O' -- (Vicky02)
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field02', 'NULL', 'output', 'NULL', 'NULL', '')
         END
         ELSE
         BEGIN                  
            SELECT @cOutField01 = @cLottable01Label
            SET @cOutField02 = ISNULL(LTRIM(RTRIM(@cLottable01)), '')
         END

         IF @cLottable02Label = '' OR @cLottable02Label IS NULL
         BEGIN
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field04', 'NULL', 'output', 'NULL', 'NULL', '')
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
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field06', 'NULL', 'output', 'NULL', 'NULL', '')
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
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
            SET @cOutField07 = 'Lottable04:'
            SET @cInField08 = ''
            SET @cFieldAttr08 = 'O' -- (Vicky02)
         END
         ELSE
         BEGIN
            SELECT  @cOutField07 = @cLottable04Label
            IF rdt.rdtIsValidDate( @dLottable04) = 1
            BEGIN
               SET @cOutField08 = CASE WHEN @cCBADefaultLot4 = '' THEN RDT.RDTFormatDate( @dLottable04) 
                                    ELSE SUBSTRING(RTRIM(@cTempLottable04), 1,4) +  SUBSTRING(RTRIM(@cTempLottable04), 6,2) END
            END
         END

         -- SN Field
         SET @cOutField09 = ''

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
--     ELSE IF @nPrevScn  = @nScn_QTY
--     BEGIN
--		 -- Prep QTY screen var
--		 SET @cOutField01 = @cSKU
--		 SET @cOutField02 = SUBSTRING( @cSKUDescr,  1, 20)
--		 SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
--		 SET @cOutField04 = @cIVAS
--		 IF @cPrefUOM_Desc = ''
--		 BEGIN
--			 SET @cOutField05 = '' -- @nPrefUOM_Div
--			 SET @cOutField06 = '' -- @cPrefUOM_Desc
--			 --SET @cOutField07 = '' -- @nPQTY
--			 SET @cOutField08 = '' -- @nActPQTY
--			 -- Disable pref QTY field
--			 INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')
--		 END
--		 ELSE
--		 BEGIN
--			 SET @cOutField05 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
--			 SET @cOutField06 = @cPrefUOM_Desc
--			 --SET @cOutField07 = CAST( @nPQTY AS NVARCHAR( 5))
--			 SET @cOutField08 = '' -- @nActPQTY
--	 	 	 	         
--		 END
--		 SET @cOutField07 = @cMstUOM_Desc
--		 SET @cOutField09 = ''--CAST( @nMQTY as NVARCHAR( 5))
--
--       IF @cPrefUOM_Desc = ''
--       BEGIN
--           SET @cOutField10 = '' -- @nPrefUOM_Div
--           SET @cOutField11 = '' -- @cPrefUOM_Desc
--           SET @cOutField13 = '' -- @cPrefQTY
--           -- Disable pref QTY field
--           INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field13', 'NULL', 'output', 'NULL', 'NULL', '')
--       END
--       ELSE
--       BEGIN
--           SET @cOutField10 = '1:' + CAST( @nPrefUOM_Div AS NVARCHAR( 6))
--           SET @cOutField11 = @cPrefUOM_Desc
--           SET @cOutField13 = @cTotalPQty
--       END
--       SET @cOutField12 = @cMstUOM_Desc
--       SET @cOutField14 = @cTotalMQty
--
--		  -- Go to prev screen
--		 SET @nScn = @nScn_QTY
--		 SET @nStep = @nStep_QTY
--
--		SET @nPrevScn  = @nScn_SKU
--		SET @nPrevStep = @nStep_SKU
--    END
    ELSE IF @nPrevScn  = @nScn_SubReason
    BEGIN
       SET @cOutField01 = @cSubReason
       EXEC rdt.rdtSetFocusField @nMobile, 1 -- SubReason
  
       SET @nScn = @nScn_SubReason
       SET @nStep = @nStep_SubReason

--       IF @cLotFlag = 'Y'
--       BEGIN
	    SET @nPrevScn  = @nScn_Lottables
	    SET @nPrevStep = @nStep_Lottables
--       END
--       ELSE
--       BEGIN
--         SET @nPrevScn  = @nScn_QTY
--		   SET @nPrevStep = @nStep_QTY
--       END
    END  
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
Scn = 1797. Message. 'SKU successfully received'
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
      SET @cOutField06 = @cPickSlipNo

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
   
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      -- Prepare SKU screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- SKUDecr
      SET @cOutField05 = '' -- SKUDecr
      SET @cOutField06 = @cPickSlipNo
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      SET @cInField03 = ''

      -- Back to SKU screen
      SET @nScn = @nScn_SKU
      SET @nStep = @nStep_SKU
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = @cPickSlipNo
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
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
      V_PickSlipNo   = @cPickSlipNo,
 
      V_LOC          = @cLOC,
      --V_ID           = @cTempLottable04, 
      V_SKU          = @cSKU,
      V_SKUDescr     = @cSKUDescr,
      V_UOM          = @cUOM,
      V_QTY          = @cQTY,
      V_Lottable01   = @cLottable01,
      V_Lottable02   = @cLottable02,
      V_Lottable03   = @cLottable03,
      V_Lottable04   = @dLottable04,
      V_Lottable05   = @dLottable05,
      V_UCC          = @cExternReceiptKey,

      V_String1      = @nPQTY,
      V_String2      = @cTotalMQty,
      V_String3      = @nMQTY,
      V_String4      = @nQTY,
      V_String5      = @nCaseCnt, 
      
      V_String6      = @cUOMDesc,
      V_String7      = @cActPQTY,
      V_String8      = @cParentScn,
      V_String9      = @cActMQTY,
      
      V_String10     = @cPrefUOM,      -- Pref UOM
      V_String11     = @cPrefUOM_Desc, -- Pref UOM desc
      V_String12     = @cMstUOM_Desc,  -- Master UOM desc
      V_String13     = @nPrefUOM_Div,  -- Pref UOM divider
      V_String14     = @nPrefQTY,      -- QTY in pref UOM
      V_String15     = @nMstQTY,       -- Remaining QTY in master unit
      V_String16     = @nActMQTY,      -- Actual Qty in master unit
      V_String17     = @nActPQTY,      -- Actual Qty in pref UOM
      V_String18     = @nActQty,       -- Total Actual Qty (@nActMQTY + @nActPQTY)
      V_String19     = @nTotalQty,

      V_String20     = @cTempLottable04,
      V_String21     = @cReturnReason,
      V_String22     = @cOverRcpt,
      V_String23     = @cExpReason,
      V_String24     = @cCBADefaultLot4,

--		V_String20     = @cTempLottable01,
--		V_String21     = @cTempLottable02,
--		V_String22     = @cTempLottable03,
--		V_String23     = @cTempLottable04,
--		V_String24     = @cTempLottable05,

      V_String25     = @nPrevScn,
      V_String26     = @nPrevStep,
      V_String27     = @cIVAS,
      V_String28     = @cSerialNo,
      V_String29     = @cSubReason,

      V_String30     = @cLottable01Label,
      V_String31     = @cLottable02Label,
		V_String32     = @cLottable03Label,
		V_String33     = @cLottable04Label,
		V_String34     = @cLottable05Label,

      V_String35     = @cDefaultLOC,
      V_String36     = @cPickFaceFlag,
      V_String37     = @cSUSR1,
      V_String38     = @nBeforeReceivedQty,
      V_String39     = @nSNExists,
      V_String40     = @cTotalPQty,
      
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

-- Commented (Vicky02) - Start
--    -- Save session screen
--    IF EXISTS( SELECT 1 FROM @tSessionScrn)
--    BEGIN
--       DECLARE @curScreen CURSOR
--       DECLARE
--          @cTyp     NVARCHAR( 10), 
--          @cX       NVARCHAR( 4),   -- size 4 is needed bcoz of 'NULL'
--          @cY       NVARCHAR( 4),   -- size 4 is needed bcoz of 'NULL'
--          @cLength  NVARCHAR( 4),   -- size 4 is needed bcoz of 'NULL'
--          @cFieldID NVARCHAR( 10), 
--          @cDefault NVARCHAR( 60), 
--          @cValue   NVARCHAR( 60), 
--          @cNewID   NVARCHAR( 10)
-- 
--       SET @cXML = ''
--       SET @curScreen = CURSOR FOR 
--          SELECT Typ, X, Y, Length, [ID], [Default], Value, [NewID] FROM @tSessionScrn
--       OPEN @curScreen
--       FETCH NEXT FROM @curScreen INTO @cTyp, @cX, @cY, @cLength, @cFieldID, @cDefault, @cValue, @cNewID
--       WHILE @@FETCH_STATUS = 0
--       BEGIN
--          SELECT @cXML = @cXML + 
--             '<Screen ' + 
--                CASE WHEN @cTyp     IS NULL THEN '' ELSE 'Typ="'     + @cTyp     + '" ' END + 
--                CASE WHEN @cX       IS NULL THEN '' ELSE 'X="'       + @cX       + '" ' END + 
--                CASE WHEN @cY       IS NULL THEN '' ELSE 'Y="'       + @cY       + '" ' END + 
--                CASE WHEN @cLength  IS NULL THEN '' ELSE 'Length="'  + @cLength  + '" ' END + 
--                CASE WHEN @cFieldID IS NULL THEN '' ELSE 'ID="'      + @cFieldID + '" ' END + 
--          CASE WHEN @cDefault IS NULL THEN '' ELSE 'Default="' + @cDefault + '" ' END + 
--                CASE WHEN @cValue   IS NULL THEN '' ELSE 'Value="'   + @cValue   + '" ' END + 
--             CASE WHEN @cNewID   IS NULL THEN '' ELSE 'NewID="'   + @cNewID   + '" ' END + 
--             '/>'
--          FETCH NEXT FROM @curScreen INTO @cTyp, @cX, @cY, @cLength, @cFieldID, @cDefault, @cValue, @cNewID
--       END
--       CLOSE @curScreen
--       DEALLOCATE @curScreen
--  END
-- 
--    -- Note: UTF-8 is multi byte (1 to 6 bytes) encoding. Use UTF-16 for double byte
--    SET @cXML = 
--       '<?xml version="1.0" encoding="UTF-16"?>' + 
--       '<Root>' + 
--          @cXML + 
--       '</Root>'
--    UPDATE RDT.RDTSessionData WITH (ROWLOCK) SET XML = @cXML WHERE Mobile = @nMobile
-- Commented (Vicky02) - End
END



GO