SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: Adjust UCC Received Qty before Finalized of ASN             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2007-02-13 1.0  Vicky      Created                                   */
/* 2014-06-23 1.1  Audrey     SOS314303 - Bug fixed(change len from 40  */
/*                                        to 20)                 (ang01)*/
/* 2016-09-30 1.2  Ung        Performance tuning                        */
/* 2018-11-21 1.3  TungGH     Performance                               */  
/* 2019-05-27 1.4  James      WMS-9128 Add ASNStatus 1 (james01)        */
/* 2022-09-22 1.5  James      WMS-20734 Allow closed ASNStatus (james02)*/
/*                            Revamp logic on ucc reveived reversal     */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_UCCReceiveReversal] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @i           INT,
   @cOption     NVARCHAR(1),
   @cScanUCC    NVARCHAR(5)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR(3),
   @nInputKey  INT,
   @nMenu      INT,
   @nRecCnt    INT,
   @nUCCCnt    INT,

   @cStorerKey NVARCHAR(15),
   @cFacility  NVARCHAR(5),

   @cReceiptKey        NVARCHAR(10),
   @cExternReceiptKey  NVARCHAR(20),
   @cLOC               NVARCHAR(10),
   @cID                NVARCHAR(18),
   @cUCC               NVARCHAR(20),
   @cQTY               NVARCHAR(5),
   @cNewQty            NVARCHAR(5),
   @cConfigValue       NVARCHAR(1),
   @cASNStatus         NVARCHAR(10),
   @cTotalUCC          NVARCHAR(5),

   @cPrevUCC           NVARCHAR(20),
   @cCurrentUCC        NVARCHAR(20),
   @cSKU               NVARCHAR(20),
   @cSKUDescr          NVARCHAR(60),
   @cSKUDescr01        NVARCHAR(60),
   @cSKUDescr02        NVARCHAR(60),
   @cUOM               NVARCHAR(10),
   @cPPK               NVARCHAR(3),
   @cLottable1         NVARCHAR(18),
   @cLottable2         NVARCHAR(18),
   @cLottable3         NVARCHAR(18),
   @cTotalAll          NVARCHAR(9),
   @cUCCCnt            NVARCHAR(4),
   @cTotalCount        NVARCHAR(4),
   @cReceiptLineNo     NVARCHAR(5),
   @cResult            NVARCHAR(1),
   @dLottable4         DATETIME,
   @dLottable5         DATETIME,
   @nQty               INT,
   @nTotalCount        INT,
   @nNewQty            INT,
   @nError             INT,
   @cNotAllowOverAdjustUCCQty  NVARCHAR( 1),
   @cAllowFinalizedASN NVARCHAR( 1),
   
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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60)

-- Load RDT.RDTMobRec
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,

   @cReceiptKey       = V_ReceiptKey,
   @cLOC              = V_Loc,
   @cID               = V_ID,
   @cUCC              = V_String1,
   @cQTY              = V_String2,
   @cTotalUCC         = V_String3,
   @cSKU              = V_SKU,
   @cUOM              = V_UOM,
   @cLottable1        = V_LottableLabel01,
   @cLottable2        = V_LottableLabel02,
   @cLottable3        = V_LottableLabel03,
   @dLottable4        = V_LottableLabel04,
   @dLottable5        = V_LottableLabel05,
   @cCurrentUCC       = V_String4,
   @cPPK              = V_String5,
   @cSKUDescr01       = V_String6,
   @cSKUDescr02       = V_String7,
   @cTotalALL         = V_String8,
   @cUCCCnt           = V_String9,
   @cTotalCount       = V_String10,
   @cNewQty           = V_String11,
   @cReceiptLineNo    = V_String12,
   @cNotAllowOverAdjustUCCQty = V_String13,
   @cAllowFinalizedASN        = V_String14,
   
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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 888  -- UCC Receive Reversal
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = UCC Receive Reversal
   IF @nStep = 1 GOTO Step_1   -- Scn = 1050. ReceiveKey
   IF @nStep = 2 GOTO Step_2   -- Scn = 1051. LOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 1052. ID
   IF @nStep = 4 GOTO Step_4   -- Scn = 1053. UCC
   IF @nStep = 5 GOTO Step_5   -- Scn = 1054. Display, counter, option
   IF @nStep = 6 GOTO Step_6   -- Scn = 1055. Display, counter, New Qty
   IF @nStep = 7 GOTO Step_7   -- Scn = 1056. Message, option
   IF @nStep = 8 GOTO Step_8   -- Scn = 1057. Message
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 888. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 1050
   SET @nStep = 1

   -- (james02)    
   SET @cNotAllowOverAdjustUCCQty = rdt.rdtGetConfig( @nFunc, 'NotAllowOverAdjustUCCQty', @cStorerKey)   

   SET @cAllowFinalizedASN = rdt.rdtGetConfig( @nFunc, 'AllowFinalizedASN', @cStorerKey)

   -- Initiate var
   SET @cReceiptKey = ''
   SET @cLOC = ''
   SET @cID = ''
   SET @cUCC = ''
   SET @cQTY = ''
   SET @cTotalUCC = ''

   -- Init screen
   SET @cOutField01 = '' -- ReceiptKey
   SET @cOutField02 = '' -- LOC
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 1050. ReceiptKey screen
   ReceiptKey       (field01)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN

      SET @cReceiptKey = @cInField01
      --TEMP COMMENT FOR TESTING
      --SELECT @cConfigValue = RTRIM(sVALUE)
      --FROM dbo.StorerConfig (NOLOCK)
      --WHERE Storerkey = @cStorerKey
      --AND   Configkey = 'UCC'


      --IF @cConfigValue <> '1'
      --BEGIN
      --   SET @nErrNo = 62901
      --   SET @cErrMsg = rdt.rdtgetmessage( 62901, @cLangCode,'DSP') --UCC Config OFF
      --   GOTO Step_1_Fail
      --END

      -- Validate blank
      IF @cReceiptKey = '' OR @cReceiptKey IS NULL
      BEGIN
         SET @nErrNo = 62902
         SET @cErrMsg = rdt.rdtgetmessage( 62902, @cLangCode,'DSP') --ASN needed
         GOTO Step_1_Fail
      END

      -- Get ASN info
      DECLARE @cStatus NVARCHAR(10)
      SELECT @cStatus = Status,
             @cASNStatus = ASNStatus
      FROM dbo.Receipt (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   Storerkey = @cStorerKey

      -- Validate ReceiptKey
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 62903
         SET @cErrMsg = rdt.rdtgetmessage( 62903, @cLangCode,'DSP') -- Invalid ASN
         GOTO Step_1_Fail
      END

      -- Validate ASN status
      IF @cStatus <> '0' -- Open ASN
      BEGIN
      	IF @cASNStatus > '1'
      	BEGIN
      		IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
      		            WHERE LISTNAME = 'INVASNSTS'
      		            AND   Code = @cASNStatus
      		            AND   Storerkey = @cStorerKey)
      		BEGIN
               SET @nErrNo = 62904
               SET @cErrMsg = rdt.rdtgetmessage( 62904, @cLangCode,'DSP') -- ASN closed
               GOTO Step_1_Fail
      		END
      	END
      END

--      SET @cReceiptKey = @cInField01 -- Receiptkey
      -- Prepare next screen var
      SET @cLOC = ''
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = ''

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cReceiptKey = ''
      SET @cOutField01 = '' -- ReceiptKey
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 1051. LOC screen
   ReceiptKey     (field01)
   LOC            (field03)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField02 -- LOC

      IF @cLOC <> '' AND @cLOC IS NOT NULL
      BEGIN
     -- Check Whether Location exists in Receiptdetail
     DECLARE @cChkLoc NVARCHAR(10)
     SELECT  @cChkLOC = ToLOC
     FROM dbo.RECEIPTDETAIL (NOLOCK)
     WHERE ToLOC = @cLOC
         AND   ReceiptKey = @cReceiptKey
         AND   Storerkey = @cStorerKey

     -- Validate location
     IF @@ROWCOUNT = 0
     BEGIN
        SET @nErrNo = 62905
        SET @cErrMsg = rdt.rdtgetmessage( 62905, @cLangCode, 'DSP') --'LOC not in ASN'
        GOTO Step_2_Fail
     END

     -- Get the location Facility
     DECLARE @cChkFacility NVARCHAR(5)
     SELECT  @cChkFacility = Facility
     FROM dbo.LOC (NOLOCK)
     WHERE LOC = @cLOC

     -- Validate location not in facility
     IF @cChkFacility <> @cFacility
     BEGIN
        SET @nErrNo = 62906
        SET @cErrMsg = rdt.rdtgetmessage( 62906, @cLangCode, 'DSP') --'Facility diff'
        GOTO Step_2_Fail
     END

     -- Get UCC Count
     DECLARE @cCntUCC INT
     SELECT  @cCntUCC = COUNT(UCCNo)
     FROM dbo.UCC (NOLOCK)
     WHERE LOC = @cLOC
         AND   ReceiptKey = @cReceiptKey
         AND   Storerkey = @cStorerKey
         AND   Status = '1'

     IF @cCntUCC < 1
     BEGIN
        SET @nErrNo = 62907
        SET @cErrMsg = rdt.rdtgetmessage( 62907, @cLangCode, 'DSP') --'No Record'
        GOTO Step_2_Fail
     END
      END -- IF @cLOC <> '' AND @cLOC IS NOT NULL

      -- Prepare next screen var
      SET @cID = ''
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cLOC
      SET @cOutField03 = ''

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN

      -- Prepare prev screen var
      SET @cReceiptKey = ''
      SET @cOutField01 = ''  -- ReceiptKey
--      SET @cOutField02 = ''  -- LOC

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      -- Reset this screen var
      SET @cLOC = ''
      SET @cOutField02 = '' -- LOC
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 1052. ID screen
   ReceiptKey     (field01)
   LOC            (field02)
   ID             (field03)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cID = @cInField03

      -- Validate not blank
      IF @cID <> '' AND @cID IS NOT NULL
      BEGIN
         -- Check Whether Location exists in Receiptdetail
       DECLARE @cChkID NVARCHAR(18)

         IF @cLOC <> '' AND @cLOC IS NOT NULL
         BEGIN
      SELECT  @cChkID = ToID
      FROM dbo.RECEIPTDETAIL (NOLOCK)
      WHERE ToLOC = @cLOC
          AND   ReceiptKey = @cReceiptKey
          AND   Storerkey = @cStorerKey
          AND   ToID = @cID
         END
     ELSE
         BEGIN
      SELECT  @cChkID = ToID
      FROM dbo.RECEIPTDETAIL (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
        AND   Storerkey = @cStorerKey
        AND   ToID = @cID
         END

     -- Validate location
     IF @@ROWCOUNT = 0
     BEGIN
        SET @nErrNo = 62908
        SET @cErrMsg = rdt.rdtgetmessage( 62908, @cLangCode, 'DSP') --'ID not in ASN'
        GOTO Step_3_Fail
     END

         -- Get UCC Count
         DECLARE @cCntUCC_ID INT
         IF @cLOC <> '' AND @cLOC IS NOT NULL
         BEGIN
      SELECT  @cCntUCC_ID = COUNT(UCCNo)
      FROM dbo.UCC (NOLOCK)
      WHERE LOC = @cLOC
          AND   [ID] = @cID
          AND   ReceiptKey = @cReceiptKey
          AND   Storerkey = @cStorerKey
          AND   Status = '1'
         END
         ELSE
         BEGIN
      SELECT  @cCntUCC_ID = COUNT(UCCNo)
      FROM dbo.UCC (NOLOCK)
      WHERE [ID] = @cID
          AND   ReceiptKey = @cReceiptKey
          AND   Storerkey = @cStorerKey
          AND   Status = '1'
         END

     IF @cCntUCC_ID < 1
     BEGIN
        SET @nErrNo = 62909
        SET @cErrMsg = rdt.rdtgetmessage( 62909, @cLangCode, 'DSP') --'No Record'
        GOTO Step_3_Fail
     END
      END -- IF @cID <> '' AND @cID IS NOT NULL

      -- Prepare next screen var
      SET @cUCC = ''
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cLOC
      SET @cOutField03 = @cID
      SET @cOutField04 = '' --UCC

      -- Remain in current screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cID = ''
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = '' -- LOC
      SET @cOutField03 = '' -- ID

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cID = ''
      SET @cOutField01 = @cReceiptkey
      SET @cOutField02 = ''
      SET @cOutField03 = '' -- ID
   END
END
GOTO Quit


/********************************************************************************
Step 4. Scn = 1053. UCC screen
   Receiptkey (field01)
   LOC        (field02)
   ID         (field03)
   UCC        (field04)
   Counter    (field05)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUCC = @cInField04

      -- Get UCC Count
      DECLARE @cCntUCC_UCC INT
      IF @cUCC <> '' AND @cUCC IS NOT NULL
      BEGIN
         IF (@cLOC <> '' AND @cLOC IS NOT NULL) AND (@cID <> '' AND @cID IS NOT NULL)
         BEGIN
            SELECT  @cCntUCC_UCC = COUNT(UCCNo)
            FROM dbo.UCC (NOLOCK)
            WHERE LOC = @cLOC
            AND   [ID] = @cID
            AND   UCCNo = @cUCC
            AND   ReceiptKey = @cReceiptKey
            AND   Storerkey = @cStorerKey
            AND   Status = '1'
         END
         ELSE IF (@cLOC = '' OR @cLOC IS NULL) AND (@cID = '' OR @cID IS NULL)
         BEGIN
            SELECT  @cCntUCC_UCC = COUNT(UCCNo)
            FROM dbo.UCC (NOLOCK)
            WHERE UCCNo = @cUCC
            AND   ReceiptKey = @cReceiptKey
            AND   Storerkey = @cStorerKey
            AND   Status = '1'
         END
         ELSE IF (@cLOC <> '' AND @cLOC IS NOT NULL) AND (@cID = '' OR @cID IS NULL)
         BEGIN
            SELECT  @cCntUCC_UCC = COUNT(UCCNo)
            FROM dbo.UCC (NOLOCK)
            WHERE UCCNo = @cUCC
            AND   LOC = @cLOC
            AND   ReceiptKey = @cReceiptKey
            AND   Storerkey = @cStorerKey
            AND   Status = '1'
         END
         ELSE IF (@cLOC = '' OR @cLOC IS NULL) AND (@cID <> '' AND @cID IS NOT NULL)
         BEGIN
            SELECT  @cCntUCC_UCC = COUNT(UCCNo)
            FROM dbo.UCC (NOLOCK)
            WHERE UCCNo = @cUCC
            AND   ID = @cID
            AND   ReceiptKey = @cReceiptKey
            AND   Storerkey = @cStorerKey
            AND   Status = '1'
         END

        IF @cCntUCC_UCC < 1
        BEGIN
           SET @nErrNo = 62910
           SET @cErrMsg = rdt.rdtgetmessage( 62910, @cLangCode, 'DSP') --'UCC not in ASN'
           GOTO Step_4_Fail
        END
      END -- IF @cUCC <> '' AND @cUCC IS NOT NULL

      DECLARE @nPrevTotalCount INT
      SELECT @cPrevUCC = ''
      SELECT @nPrevTotalCount = 0
      SELECT @nRecCnt = 0
      SELECT @nUCCCnt = 0

      EXECUTE rdt.rdt_ReceiveReserval_UCCRetrieve
         @cReceiptKey, @cLOC, @cID, @cUCC, @cStorerkey, @cPrevUCC, @nRecCnt, @nPrevTotalCount,
         @cCurrentUCC    OUTPUT,
         @nTotalCount    OUTPUT,
         @cSKU           OUTPUT,
         @cSKUDescr      OUTPUT,
         @cUOM           OUTPUT,
         @nQty           OUTPUT,
         @cPPK           OUTPUT,
         @cLottable1     OUTPUT,
         @cLottable2     OUTPUT,
         @cLottable3     OUTPUT,
         @dLottable4     OUTPUT,
         @dLottable5     OUTPUT

      IF @nTotalCount = 0
      BEGIN
         -- Blank out var
         SET @cCurrentUCC = ''
         SET @nTotalCount = 0
         SET @cSKU = ''
         SET @cSKUDescr = ''
         SET @cUOM = ''
         SET @nQty = 0
         SET @cPPK = ''
         SET @cLottable1 = ''
         SET @cLottable2 = ''
         SET @cLottable3 = ''
         SET @dLottable4 = ''
         SET @dLottable5 = ''

         -- Clear all outfields
         SET @cOutField01 = ''   -- TotalCount
         SET @cOutField02 = ''   -- Option
         SET @cOutField03 = ''   -- UCC
         SET @cOutField04 = ''   -- PPK
         SET @cOutField05 = ''   -- SKU
         SET @cOutField06 = ''   -- SKU DESCR1
         SET @cOutField07 = ''   -- SKU DESCR2
         SET @cOutField08 = ''   -- QTY + UOM
         SET @cOutField09 = ''   -- Lottable01
         SET @cOutField10 = ''   -- Lottable02
         SET @cOutField11 = ''   -- Lottable03
         SET @cOutField12 = ''   -- Lottable04
         SET @cOutField13 = ''   -- Lottable05
      END
      ELSE
      BEGIN
         -- Prepare OPTION Screen
         SET @nUCCCnt = @nUCCCnt + 1
         SET @cUCCCnt = RTRIM(CONVERT(CHAR(4), @nUCCCnt))
         SET @cTotalCount =  CONVERT(CHAR(4), @nTotalCount)

         SET @cTotalALL = RTRIM(@cUCCCnt) + '/' + RTRIM(@cTotalCount)
         SET @cQty = CAST( @nQTY AS NVARCHAR( 5))
         SET @cSKUDescr01 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cSKUDescr02 = SUBSTRING( @cSKUDescr, 21, 20) --ang01

         SET @cOutField01 = @cTotalALL--RTRIM(CONVERT(CHAR(4), @nUCCCnt)) + '/' + CONVERT(CHAR(4), @nTotalCount)
         SET @cOutField02 = ''   -- Option
         SET @cOutField03 = @cCurrentUCC
         SET @cOutField04 = @cPPK
         SET @cOutField05 = @cSKU
         SET @cOutField06 = @cSKUDescr01
         SET @cOutField07 = @cSKUDescr02
         SET @cOutField08 = @cQty
         SET @cOutField09 = @cUOM
         SET @cOutField10 = @cLottable1
         SET @cOutField11 = @cLottable2
         SET @cOutField12 = @cLottable3
         SET @cOutField13 = rdt.rdtFormatDate( @dLottable4)
         SET @cOutField14 = rdt.rdtFormatDate( @dLottable5)
      END

      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END -- @nInputKey = 1

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      -- Clear all outfields
      SET @cOutField01 = ''   -- TotalCount
      SET @cOutField02 = ''   -- Option
      SET @cOutField03 = ''   -- UCC
      SET @cOutField04 = ''   -- PPK
      SET @cOutField05 = ''   -- SKU
      SET @cOutField06 = ''   -- SKU DESCR1
      SET @cOutField07 = ''   -- SKU DESCR2
      SET @cOutField08 = ''   -- QTY + UOM
      SET @cOutField09 = ''   -- Lottable01
      SET @cOutField10 = ''   -- Lottable02
      SET @cOutField11 = ''   -- Lottable03
      SET @cOutField12 = ''   -- Lottable04
      SET @cOutField13 = ''   -- Lottable05

      SET @cUCC = ''
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cLOC -- LOC
      SET @cOutField03 = '' -- ID
      SET @cOutField04 = '' -- UCC

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      -- Reset this screen var
      SET @cUCC = ''
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cLOC -- LOC
      SET @cOutField03 = '' -- ID
      SET @cOutField04 = '' -- ID
   END
END
GOTO Quit

/********************************************************************************
Step 5. Scn = 1054. Display, counter, option
   Total   (field01)
   Opt     (field02)
   UCC     (field03)
   PPK     (field04)
   SKU     (field05)
   SKUDes1 (field06)
   SKUDes2 (field07)
   Qty     (field08)
   UOM     (field09)
   Lot1    (field10)
   LOT2    (field11)
   LOT3    (field12)
   LOT4    (field13)
   LOT5    (field14)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = ''
      SET @cOption = @cInField02
      IF @cOption = ''
      BEGIN
         DECLARE @nPrevUCCCnt INT
         SELECT @nPrevUCCCnt = CAST(@cUCCCnt AS INT)
         SELECT @nPrevTotalCount = CAST(@cTotalCount AS INT)
         SELECT @cPrevUCC = @cCurrentUCC
         SELECT @nRecCnt = 0

         EXECUTE rdt.rdt_ReceiveReserval_UCCRetrieve
            @cReceiptKey, @cLOC, @cID, @cUCC, @cStorerkey, @cPrevUCC, @nRecCnt, @nPrevTotalCount,
            @cCurrentUCC    OUTPUT,
            @nTotalCount    OUTPUT,
            @cSKU           OUTPUT,
            @cSKUDescr      OUTPUT,
            @cUOM           OUTPUT,
            @nQty           OUTPUT,
            @cPPK           OUTPUT,
            @cLottable1     OUTPUT,
            @cLottable2     OUTPUT,
            @cLottable3     OUTPUT,
            @dLottable4     OUTPUT,
            @dLottable5     OUTPUT


         -- Prepare OPTION Screen
         --IF @cCurrentUCC = @cPrevUCC AND @nTotalCount > @nPrevUCCCnt
         IF @nTotalCount > @nPrevUCCCnt
         BEGIN
            SET @nUCCCnt = CAST(@cUCCCnt AS INT) + 1
            SET @cUCCCnt = RTRIM(CONVERT(CHAR(4), @nUCCCnt))
            SET @cTotalCount =  CONVERT(CHAR(4), @nTotalCount)

            SET @cTotalALL = RTRIM(@cUCCCnt) + '/' + RTRIM(@cTotalCount)
            SET @cQty = CAST( @nQTY AS NVARCHAR( 5))
            SET @cSKUDescr01 = SUBSTRING( @cSKUDescr, 1, 20)
            SET @cSKUDescr02 = SUBSTRING( @cSKUDescr, 21, 20)--ang01

            SET @cOutField01 = @cTotalALL--RTRIM(CONVERT(CHAR(4), @nUCCCnt)) + '/' + CONVERT(CHAR(4), @nTotalCount)
            SET @cOutField02 = ''   -- Option
            SET @cOutField03 = @cCurrentUCC
            SET @cOutField04 = @cPPK
            SET @cOutField05 = @cSKU
            SET @cOutField06 = @cSKUDescr01
            SET @cOutField07 = @cSKUDescr02
            SET @cOutField08 = @cQty
            SET @cOutField09 = @cUOM
            SET @cOutField10 = @cLottable1
            SET @cOutField11 = @cLottable2
            SET @cOutField12 = @cLottable3
            SET @cOutField13 = rdt.rdtFormatDate( @dLottable4)
            SET @cOutField14 = rdt.rdtFormatDate( @dLottable5)


            -- Go to ASN screen
            SET @nScn = @nScn
            SET @nStep = @nStep
         END

          GOTO Quit
      END
      ELSE IF @cOption <> '1' AND @cOption <> '2' AND @cOption <> ''
      BEGIN
         SET @nErrNo = 62911
         SET @cErrMsg = rdt.rdtgetmessage( 62911, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_5_Fail
      END

      IF @cOption = '1' -- Edit
      BEGIN
         -- Allow reverse receive on single sku ucc only
         -- (This module doesn't have screen to key in particular sku to reverse)
         IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) 
                     WHERE Storerkey = @cStorerKey
                     AND   UCCNo = @cUCC 
                     GROUP BY UCCNo
                     HAVING COUNT( DISTINCT SKU) > 1)
         BEGIN
            SET @nErrNo = 62922
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UCC MIX SKU
            GOTO Step_5_Fail
         END
         
         -- If UCC's case count is fixed (i.e. NOT dynamic), check the case count
         IF rdt.rdtGetConfig( 0, 'UCCWithDynamicCaseCnt', @cStorerKey) <> '1' -- 1=Dynamic CaseCNT
         BEGIN
            SET @nErrNo = 62912
            SET @cErrMsg = rdt.rdtgetmessage( 62912, @cLangCode, 'DSP') --'UCC QTY Fixed'
            GOTO Step_5_Fail
         END
         ELSE
         BEGIN
            SET @cOutField01 = @cTotalALL--RTRIM(CONVERT(CHAR(4), @nUCCCnt)) + '/' + CONVERT(CHAR(4), @nTotalCount)
            SET @cOutField02 = @cCurrentUCC
            SET @cOutField03 = @cPPK
            SET @cOutField04 = @cSKU
            SET @cOutField05 = @cSKUDescr01
            SET @cOutField06 = @cSKUDescr02
            SET @cOutField07 = @cQty
            SET @cOutField08 = @cUOM
            SET @cOutField09 = '' -- New Qty
            SET @cOutField10 = @cLottable1
            SET @cOutField11 = @cLottable2
            SET @cOutField12 = @cLottable3
            SET @cOutField13 = rdt.rdtFormatDate( @dLottable4)
            SET @cOutField14 = rdt.rdtFormatDate( @dLottable5)

            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1

            GOTO Quit
         END
      END

      IF @cOption = '2' -- DEL
      BEGIN
         SET @cInField01 = 'Un-receive this UCC?'
         SET @cOutField01 = @cInField01

         -- Go to Unreceive screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2

         GOTO Quit
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOption = ''
      SET @cInField01 = ''

      -- Clear all outfields
      SET @cOutField01 = ''   -- TotalCount
      SET @cOutField02 = ''   -- Option
      SET @cOutField03 = ''   -- UCC
      SET @cOutField04 = ''   -- PPK
      SET @cOutField05 = ''   -- SKU
      SET @cOutField06 = ''   -- SKU DESCR1
      SET @cOutField07 = ''   -- SKU DESCR2
      SET @cOutField08 = ''   -- QTY + UOM
      SET @cOutField09 = ''   -- Lottable01
      SET @cOutField10 = ''   -- Lottable02
      SET @cOutField11 = ''   -- Lottable03
      SET @cOutField12 = ''   -- Lottable04
      SET @cOutField13 = ''   -- Lottable05

      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cLOC -- LOC
      SET @cOutField03 = @cID -- ID
      SET @cOutField04 = '' -- UCC

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
      GOTO Quit
   END

   GOTO Quit

   Step_5_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOption = ''
      SET @cOutField02 = '' -- Option
   END
END
GOTO Quit

/********************************************************************************
Step 6. Scn = 1055. Edit Screen - New Qty
   Total   (field01)
   Opt     (field02)
   UCC     (field03)
   PPK     (field04)
   SKU     (field05)
   SKUDes1 (field06)
   SKUDes2 (field07)
   Qty     (field08)
   UOM     (field09)
   NewQty  (field10)
   Lot1    (field11)
   LOT2    (field12)
   LOT3    (field13)
   LOT4    (field14)
   LOT5    (field15)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cNewQty = @cInField09

      -- Validate if QTY is numeric
      IF RDT.rdtIsValidQTY( @cNewQty, 1) = 0
      BEGIN
         SET @nErrNo = 62913
         SET @cErrMsg = rdt.rdtgetmessage( 62913, @cLangCode, 'DSP') --'Invalid QTY'
         GOTO Step_6_Fail
      END

      IF CAST(@cNewQty AS INT) > CAST(@cQTY AS INT)
      BEGIN
      	-- If turn on then cannot adjust > received ucc qty
      	IF @cNotAllowOverAdjustUCCQty = '1'
         BEGIN
            SET @nErrNo = 62923
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Over UCC Qty'
            GOTO Step_6_Fail
         END
      
         EXECUTE rdt.rdt_ReceiveReserval_UCCQtyValidation
             @cReceiptKey, @cLOC, @cID, @cCurrentUCC, @cStorerkey, @cNewQty,
             @cReceiptLineNo OUTPUT,
             @cResult        OUTPUT

         IF @cResult = '0'
         BEGIN
            SET @nErrNo = 62914
            SET @cErrMsg = rdt.rdtgetmessage( 62914, @cLangCode, 'DSP') --'Line Over Rcpt'
            GOTO Step_6_Fail
         END
      END
      ELSE
      BEGIN
         EXECUTE rdt.rdt_ReceiveReserval_UCCQtyValidation
            @cReceiptKey, @cLOC, @cID, @cCurrentUCC, @cStorerkey, @cNewQty,
            @cReceiptLineNo OUTPUT,
            @cResult        OUTPUT

      END

      IF @cAllowFinalizedASN = '0'
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.RECEIPTDETAIL RD (NOLOCK) WHERE RD.ReceiptKey = @cReceiptKey
                      AND RD.Storerkey = @cStorerkey
                      AND RD.ReceiptLineNumber = @cReceiptLineNo
                      AND RD.FinalizeFlag = 'Y')
         BEGIN
            SET @nErrNo = 62915
            SET @cErrMsg = rdt.rdtgetmessage( 62915, @cLangCode, 'DSP') --'Line finalized'
            GOTO Step_6_Fail
         END

         IF EXISTS (SELECT 1 FROM dbo.UCC UCC (NOLOCK) WHERE UCC.ReceiptKey = @cReceiptKey
                      AND UCC.Storerkey = @cStorerkey
                      AND UCC.UCCNo = @cCurrentUCC
                      AND UCC.Status = '1'
                      AND (UCC.LOT <> '' AND UCC.LOT IS NOT NULL))
         BEGIN
            SET @nErrNo = 62916
            SET @cErrMsg = rdt.rdtgetmessage( 62916, @cLangCode, 'DSP') --'UCC finalized'
            GOTO Step_6_Fail
         END
      END

      SET @nError = 0
      EXECUTE rdt.rdt_ReceiveReserval_UCCQtyAdjustment
         @nMobile       = @nMobile,
         @nFunc         = @nFunc,
         @cLangCode     = @cLangCode,
         @nStep         = @nStep,
         @nInputKey     = @nInputKey,
         @cFacility     = @cFacility,
         @cStorerkey    = @cStorerkey,
         @cReceiptKey   = @cReceiptKey, 
         @cLOC          = @cLOC, 
         @cID           = @cID, 
         @cUCC          = @cCurrentUCC, 
         @cQTY          = @cQTY, 
         @cNewQty       = @cNewQty, 
         @cReceiptLineNo= @cReceiptLineNo,
         @cType         = 'EDT',
         @nErrNo        = @nErrNo      OUTPUT,
         @cErrMsg       = @cErrMsg     OUTPUT

      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 62917
         SET @cErrMsg = rdt.rdtgetmessage( 62917, @cLangCode, 'DSP') --'Fail to adjust'
         GOTO Step_6_Fail
      END

      SET @cInField01 = 'UCC Adjusted '
      SET @cInField02 = 'successfully'
      SET @cInField03 = 'Press ENTER or ESC'
      SET @cInField04 = 'to continue'

      SET @cOutField01 = @cInField01
      SET @cOutField02 = @cInField02
      SET @cOutField03 = @cInField03
      SET @cOutField04 = @cInField04

      SET @nScn  = @nScn + 2
      SET @nStep = @nStep + 2
   END -- @nInputKey = 1

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      -- Go to prev screen
      SET @cInField01 = ''
      SET @cInField02 = ''
      SET @cInField09 = ''

      SET @cOption = ''
      SET @cOutField01 = @cTotalALL--RTRIM(CONVERT(CHAR(4), @nUCCCnt)) + '/' + CONVERT(CHAR(4), @nTotalCount)
      SET @cOutField02 = ''   -- Option
      SET @cOutField03 = @cCurrentUCC
      SET @cOutField04 = @cPPK
      SET @cOutField05 = @cSKU
      SET @cOutField06 = @cSKUDescr01
      SET @cOutField07 = @cSKUDescr02
      SET @cOutField08 = @cQty
      SET @cOutField09 = @cUOM
      SET @cOutField10 = @cLottable1
      SET @cOutField11 = @cLottable2
      SET @cOutField12 = @cLottable3
      SET @cOutField13 = rdt.rdtFormatDate( @dLottable4)
      SET @cOutField14 = rdt.rdtFormatDate( @dLottable5)

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_6_Fail:
   BEGIN
      -- Reset this screen var
      SET @cUCC = ''
      SET @cOutField09 = '' -- QTY
      SET @cInField09 = '' -- Input
   END
END
GOTO Quit

/********************************************************************************
Step 7. Scn = 1056. Un-receive screen
   Msg        (field01)
   Option     (field02)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1
   BEGIN
      SET @cOption = ''
      SET @cOption = @cInField02

      IF @cOption <> '1' AND @cOption <> '2' --AND @cOption <> ''
      BEGIN
         SET @nErrNo = 62918
         SET @cErrMsg = rdt.rdtgetmessage( 62918, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_7_Fail
      END

      IF @cOption = '1' -- Yes
      BEGIN
         SELECT @cReceiptLineNo = UCC.ReceiptLineNumber
         FROM dbo.UCC UCC (NOLOCK)
         WHERE UCC.Storerkey = @cStorerkey
            AND UCC.ReceiptKey = @cReceiptKey
            AND UCC.UCCNo = @cCurrentUCC
            AND UCC.Status = '1'

         IF @cAllowFinalizedASN = '0'
         BEGIN
            IF EXISTS (SELECT 1 FROM dbo.RECEIPTDETAIL RD (NOLOCK) WHERE RD.ReceiptKey = @cReceiptKey
                        AND RD.Storerkey = @cStorerkey
                        AND RD.ReceiptLineNumber = @cReceiptLineNo
                        AND RD.FinalizeFlag = 'Y')
            BEGIN
               SET @nErrNo = 62919
               SET @cErrMsg = rdt.rdtgetmessage( 62919, @cLangCode, 'DSP') --'Line finalized'
               GOTO Step_7_Fail
            END

            IF EXISTS (SELECT 1 FROM dbo.UCC UCC (NOLOCK) WHERE UCC.ReceiptKey = @cReceiptKey
                        AND UCC.Storerkey = @cStorerkey
                        AND UCC.UCCNo = @cCurrentUCC
                        AND UCC.Status = '1'
                     AND (UCC.LOT <> '' AND UCC.LOT IS NOT NULL))
            BEGIN
               SET @nErrNo = 62920
               SET @cErrMsg = rdt.rdtgetmessage( 62920, @cLangCode, 'DSP') --'UCC finalized'
               GOTO Step_7_Fail
            END
         END
      
         SET @nErrNo = 0
         EXECUTE rdt.rdt_ReceiveReserval_UCCQtyAdjustment
            @nMobile       = @nMobile,
            @nFunc         = @nFunc,
            @cLangCode     = @cLangCode,
            @nStep         = @nStep,
            @nInputKey     = @nInputKey,
            @cFacility     = @cFacility,
            @cStorerkey    = @cStorerkey,
            @cReceiptKey   = @cReceiptKey, 
            @cLOC          = @cLOC, 
            @cID           = @cID, 
            @cUCC          = @cCurrentUCC, 
            @cQTY          = @cQTY, 
            @cNewQty       = @cNewQty, 
            @cReceiptLineNo= @cReceiptLineNo,
            @cType         = 'DEL',
            @nErrNo        = @nErrNo      OUTPUT,
            @cErrMsg       = @cErrMsg     OUTPUT

         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 62921
            SET @cErrMsg = rdt.rdtgetmessage( 62921, @cLangCode, 'DSP') --'Fail to adjust'
            GOTO Step_7_Fail
         END

         SET @cInField01 = 'UCC Adjusted '
         SET @cInField02 = 'successfully'
         SET @cInField03 = 'Press ENTER or ESC'
         SET @cInField04 = 'to continue'

         SET @cOutField01 = @cInField01
         SET @cOutField02 = @cInField02
         SET @cOutField03 = @cInField03
         SET @cOutField04 = @cInField04

         -- Go to ASN screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit
      END

      IF @cOption = '2' -- No
      BEGIN
         SET @cInField02 = ''
         SET @cOutField01 = @cTotalALL
         
         -- Go to ASN screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
         GOTO Quit
       END
   END -- IF InputKey = 1

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      -- Clear all outfields
      SET @cOutField01 = ''   -- TotalCount
      SET @cOutField02 = ''   -- Option
      SET @cOutField03 = ''   -- UCC
      SET @cOutField04 = ''   -- PPK
      SET @cOutField05 = ''   -- SKU
      SET @cOutField06 = ''   -- SKU DESCR1
      SET @cOutField07 = ''   -- SKU DESCR2
      SET @cOutField08 = ''   -- QTY + UOM
      SET @cOutField09 = ''   -- Lottable01
      SET @cOutField10 = ''   -- Lottable02
      SET @cOutField11 = ''   -- Lottable03
      SET @cOutField12 = ''   -- Lottable04
      SET @cOutField13 = ''   -- Lottable05
      SET @cInField01 = ''
      SET @cInField02 = ''

      SET @cOption = ''
      SET @cOutField01 = @cTotalALL--RTRIM(CONVERT(CHAR(4), @nUCCCnt)) + '/' + CONVERT(CHAR(4), @nTotalCount)
      SET @cOutField02 = ''   -- Option
      SET @cOutField03 = @cCurrentUCC
      SET @cOutField04 = @cPPK
      SET @cOutField05 = @cSKU
      SET @cOutField06 = @cSKUDescr01
      SET @cOutField07 = @cSKUDescr02
      SET @cOutField08 = @cQty
      SET @cOutField09 = @cUOM
      SET @cOutField10 = @cLottable1
      SET @cOutField11 = @cLottable2
      SET @cOutField12 = @cLottable3
      SET @cOutField13 = rdt.rdtFormatDate( @dLottable4)
      SET @cOutField14 = rdt.rdtFormatDate( @dLottable5)

      -- Go to prev screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END
   GOTO Quit

   Step_7_Fail:
   BEGIN
      -- Reset this screen var
      SET @cUCC = ''
--       SET @cOutField02 = ''
--       SET @cInField02 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 8. Scn = 1057. Msg screen
   Msg        (field01)
   Option     (field02)
********************************************************************************/
Step_8:
BEGIN

      -- Screen mapping
      SET @cOutField01 = @cInField01
      SET @cOutField02 = @cInField02
      SET @cOutField03 = @cInField03
      SET @cOutField04 = @cInField04

    IF @nInputKey = 1 -- ENTER
      BEGIN
       SET @cOutField01 = @cReceiptKey
       SET @cOutField02 = @cLoc
       SET @cOutField03 = @cID
       SET @cOutField04 = ''

       SET @nScn  = @nScn - 4
       SET @nStep = @nStep - 4
    END -- @nInputKey = 1

    IF @nInputKey = 0 -- ESC
    BEGIN
       -- Prepare prev screen var
       SET @cUCC = ''
         SET @cInField01 = ''
         SET @cInField02 = ''
         SET @cInField03 = ''
         SET @cInField04 = ''

       SET @cOption = ''
       SET @cOutField01 = @cTotalALL--RTRIM(CONVERT(CHAR(4), @nUCCCnt)) + '/' + CONVERT(CHAR(4), @nTotalCount)
       SET @cOutField02 = ''   -- Option
       SET @cOutField03 = @cCurrentUCC
       SET @cOutField04 = @cPPK
       SET @cOutField05 = @cSKU
       SET @cOutField06 = @cSKUDescr01
       SET @cOutField07 = @cSKUDescr02
       SET @cOutField08 = @cQty
       SET @cOutField09 = @cUOM
       SET @cOutField10 = @cLottable1
       SET @cOutField11 = @cLottable2
       SET @cOutField12 = @cLottable3
       SET @cOutField13 = rdt.rdtFormatDate( @dLottable4)
       SET @cOutField14 = rdt.rdtFormatDate( @dLottable5)


       -- Go to prev screen
       SET @nScn = @nScn - 3
       SET @nStep = @nStep - 3
    END
     GOTO Quit

   Step_8_Fail:
   BEGIN
      -- Reset this screen var
      SET @cUCC = ''
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cInField01 = ''
      SET @cInField02 = ''
      SET @cInField03 = ''
      SET @cInField04 = ''
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

      V_ReceiptKey = @cReceiptKey,
      V_Loc     = @cLOC,
      V_ID      = @cID,
      V_String1 = @cUCC,
      V_String2 = @cQty,
      V_String3 = @cTotalUCC,
      V_SKU     = @cSKU,
      V_UOM     = @cUOM,
      V_LottableLabel01 = @cLottable1 ,
      V_LottableLabel02 = @cLottable2,
      V_LottableLabel03 = @cLottable3,
      V_LottableLabel04 = @dLottable4,
      V_LottableLabel05 = @dLottable5,
      V_String4 = @cCurrentUCC,
      V_String5 = @cPPK,
      V_String6 = @cSKUDescr01,
      V_String7 = @cSKUDescr02,
      V_String8 = @cTotalALL,
      V_String9 = @cUCCCnt,
      V_String10 = @cTotalCount,
      V_String11 = @cNewQty,
      V_String12 = @cReceiptLineNo,
      V_String13 = @cNotAllowOverAdjustUCCQty,
      V_String14 = @cAllowFinalizedASN,
      
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
      I_Field15 = @cInField15,  O_Field15 = @cOutField15

   WHERE Mobile = @nMobile
END



GO