SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_UCCReceive2                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Receive ASN by using Carton ID                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 21-Jun-2017  1.0  James    WMS2212 - Created                         */
/* 16-Nov-2018  1.1  Gan      Performance tuning                        */
/* 09-Aug-2021  1.2  James    WMS-17614 Add ExtendedInfoSP (james01)    */
/* 11-Apr-2023  1.3  James    WMS-22200 Add config not allow SKU in     */
/*                            carton to be overreceived (james02)       */
/* 17-Apr-2023  1.4  James    Bug fix on lottable receiving (james03)   */  
/* 20-Apr-2023  1.5  James    Bug fix on ctn count checking (james04)   */  
/* 11-Aug-2023  1.6  yeekung  WMS-23230 Add Eventlog (yeekung01)        */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_UCCReceive2] (
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

   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @cUserName           NVARCHAR( 18),
   @cSKU                NVARCHAR( 20),
   @cSQL                NVARCHAR( MAX),
   @cSQLParam           NVARCHAR( MAX),
   @cCartonID           NVARCHAR( 20),
   @cPOKey              NVARCHAR( 10),
   @cReceiptKey         NVARCHAR( 10),
   @cToID               NVARCHAR( 18),
   @cToLOC              NVARCHAR( 10),
   @cChkFacility        NVARCHAR( 5),
   @cChkStorerKey       NVARCHAR( 15),
   @cChkReceiptKey      NVARCHAR( 10),
   @cChkPOKey           NVARCHAR( 10),
   @cReceiptStatus      NVARCHAR( 10),
   @cUOM                NVARCHAR( 10),
   @cSKUDesc            NVARCHAR( 60),
   @cQTY                NVARCHAR( 10),
   @cPackQTY            NVARCHAR( 10),
   @cPackUOM            NVARCHAR( 10),
   @cAllowCtnIDBlank    NVARCHAR( 1),
   @cASNStatus          NVARCHAR( 10),
   @cDecodeSKUSP        NVARCHAR( 20),
   @cSKUCode            NVARCHAR( 20),
   @cMultiSKUBarcode    NVARCHAR( 1),
   @cVerifySKU          NVARCHAR( 1),
   @cBarcode            NVARCHAR( 60),
   @cUPC                NVARCHAR( 30),
   @cAuthority          NVARCHAR( 30),
   @cChkLOC             NVARCHAR( 10),
   @cSKU2Receive        NVARCHAR( 20),
   @cSKU2Delete         NVARCHAR( 20),
   @nQtyExpected        INT,
   @nLogQtyReceived     INT,
   @nSum_QtyReceived    INT,
   @nSum_QtyExpected    INT,
   @nSum_LogQtyReceived INT,
   @nQTY                INT,
   @nRowCount           INT,
   @nNOPOFlag           INT,
   @bSuccess            INT,
   @nSKUCnt             INT,
   @nQty2Receive        INT,
   @nToID_Qty           INT,
   @nTranCount          INT,
   @nRowRef             INT,
   @cPOKeyDefaultValue     NVARCHAR( 10),
   @cReceiveDefaultToLoc   NVARCHAR( 10),
   @cPromptIfRcvQtyMisMatch   NVARCHAR( 1),
   @cReceiptKey2Delete  NVARCHAR( 10),
   @cDisableQTYField    NVARCHAR(1),
   @cDefaultQTY         NVARCHAR(1),

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

   @cExtendedInfo       NVARCHAR( 20),
   @cExtendedInfoSP     NVARCHAR( 20),
   @tExtInfoVar         VARIABLETABLE,
   @cCartonIDOnRcptDetail  NVARCHAR( 1),
   @cNotAllowCtnQtyOverRcv NVARCHAR( 1),
   
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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1),

   @cErrMsg01  NVARCHAR( 20),   @cErrMsg02   NVARCHAR( 20),
   @cErrMsg03  NVARCHAR( 20),   @cErrMsg04   NVARCHAR( 20),
   @cErrMsg05  NVARCHAR( 20)


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

   @nQTY        = V_Integer1,

   @cReceiptKey = V_ReceiptKey,
   @cPOKey      = V_POKey,
   @cToID       = V_ID,
   @cToLoc      = V_LOC,
   @cCartonID   = V_UCC,
   @cUOM        = V_UOM,
  -- @nQTY        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY, 5), 0) = 1 THEN LEFT( V_QTY, 5) ELSE 0 END,
   @cSKU        = V_SKU,
   @cSKUDesc    = V_SKUDescr,

   @cAllowCtnIDBlank       = V_String1,
   @cDecodeSKUSP           = V_String2,
   @cReceiveDefaultToLoc   = V_String3,
   @cMultiSKUBarcode       = V_String4,
   @cVerifySKU             = V_String5,
   @cPOKeyDefaultValue     = V_String6,
   @cQty                   = V_String7,
   @cPromptIfRcvQtyMisMatch= V_String8,
   @cDisableQTYField       = V_String9,
   @cDefaultQTY            = V_String10,
   @cExtendedInfoSP        = V_String11,
   @cCartonIDOnRcptDetail  = V_String12,
   @cNotAllowCtnQtyOverRcv = V_String13,
   
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


FROM rdt.RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 1582 -- Carton ID Receive
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = 1582
   IF @nStep = 1 GOTO Step_1   -- Scn = 4950. Carton ID, ASN, PO
   IF @nStep = 2 GOTO Step_2   -- Scn = 4951. Qty
   IF @nStep = 3 GOTO Step_3   -- Scn = 4952. To ID, To Loc
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1582. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Initialize value
   SET @cCartonID = ''
   SET @cReceiptKey = ''
   SET @cPOKey = ''

   -- Get storer config
   SET @cPOKeyDefaultValue = rdt.RDTGetConfig( @nFunc, 'ReceivingPOKeyDefaultValue', @cStorerKey)
   IF @cPOKeyDefaultValue = '0'
      SET @cPOKeyDefaultValue = ''

   -- Check if allow Carton ID blank
   SET @cAllowCtnIDBlank = rdt.RDTGetConfig( @nFunc, 'AllowCtnIDBlank', @cStorerKey)

   -- Get receive DefaultToLoc
   SET @cReceiveDefaultToLoc = rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorerKey)
   IF @cReceiveDefaultToLoc IN ('', '0')
      SET @cReceiveDefaultToLoc = ''

   SET @cDecodeSKUSP = rdt.RDTGetConfig( @nFunc, 'DecodeSKUSP', @cStorerKey)
   IF @cDecodeSKUSP = '0'
      SET @cDecodeSKUSP = ''

   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)
   SET @cVerifySKU = rdt.RDTGetConfig( @nFunc, 'VerifySKU', @cStorerKey)
   SET @cPromptIfRcvQtyMisMatch = rdt.RDTGetConfig( @nFunc, 'PromptIfRcvQtyMisMatch', @cStorerKey)
   SET @cDisableQTYField = rdt.RDTGetConfig( @nFunc, 'DisableQTYField', @cStorerKey)
   SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)

   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   SET @cCartonIDOnRcptDetail = rdt.rdtGetConfig( @nFunc, 'CartonIDOnRcptDetail', @cStorerKey)

   -- (james02)
   SET @cNotAllowCtnQtyOverRcv = rdt.rdtGetConfig( @nFunc, 'NotAllowCtnQtyOverRcv', @cStorerKey)
   
   -- Prep next screen var
   SET @cOutField01 = '' -- CARTON ID
   SET @cOutField02 = '' -- ASN
   SET @cOutField03 = CASE WHEN @cPOKeyDefaultValue = '' THEN '' ELSE @cPOKeyDefaultValue END-- PO

   SET @nScn = 4950
   SET @nStep = 1

   -- Clear not finish data
   DECLARE CUR_RCV CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT RowRef
   FROM rdt.rdtUCCReceive2Log WITH (NOLOCK)
   WHERE AddWho = @cUserName
   AND   [Status] = '0'
   OPEN CUR_RCV
   FETCH NEXT FROM CUR_RCV INTO @nRowRef
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      DELETE FROM rdt.rdtUCCReceive2Log
      WHERE RowRef = @nRowRef

      FETCH NEXT FROM CUR_RCV INTO @nRowRef
   END
   CLOSE CUR_RCV
   DEALLOCATE CUR_RCV

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 4950
   CARTON ID   (field01, input)
   ASN         (field02, input)
   LANE        (field03, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cCartonID = @cInField01
      SET @cReceiptKey = @cInField02
      SET @cPOKey = @cInField03

      IF ISNULL( @cCartonID, '') = ''
      BEGIN
         IF @cAllowCtnIDBlank <> '1'
         BEGIN
            SET @nErrNo = 111501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Ctn ID
            GOTO Step_1_Fail
         END

         -- Validate at least one field must key-in to look for carton id
         IF ISNULL( @cReceiptKey, '') = ''
         BEGIN
            SET @nErrNo = 111502
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ASN
            GOTO Step_1_Fail
         END

         SET @nRowCount = 0
         SELECT @cCartonID = R.UserDefine01,
                @cChkPOKey = RD.POKey,
                @cChkFacility = R.Facility,
                @cChkStorerKey = R.StorerKey,
                @cReceiptStatus = R.Status,
                @cASNStatus = R.ASNStatus
         FROM dbo.Receipt R WITH (NOLOCK)
         JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
         WHERE R.ReceiptKey = @cReceiptKey
         AND   (( @cPOKey = '') OR ( R.POKey = @cPOKey))
         AND   RD.StorerKey = @cStorerKey

         SET @nRowCount = @@ROWCOUNT
         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 111503
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN not exists
            GOTO Step_1_Fail
         END

         IF @cCartonIDOnRcptDetail = '1'
            SELECT @cCartonID = UserDefine01
            FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey

         -- Check if carton exists in ASN
         IF ISNULL( @cCartonID, '') = ''
         BEGIN
            SET @nErrNo = 111504
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN No Ctn ID
            GOTO Step_1_Fail
         END
      END

      SET @nRowCount = 0
      SELECT @cChkReceiptKey = R.ReceiptKey,
             @cChkPOKey = RD.POKey,
             @cChkFacility = R.Facility,
             @cChkStorerKey = R.StorerKey,
             @cReceiptStatus = R.Status,
             @cASNStatus = R.ASNStatus
      FROM dbo.Receipt R WITH (NOLOCK)
      JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
      WHERE (( @cCartonIDOnRcptDetail = '1' AND RD.UserDefine01 = @cCartonID) OR ( R.UserDefine01 = @cCartonID))
      AND   (( @cReceiptKey = '') OR ( R.ReceiptKey = @cReceiptKey))
      AND   (( @cPOKey = '') OR ( R.POKey = @cPOKey))
      AND   RD.StorerKey = @cStorerKey

      SET @nRowCount = @@ROWCOUNT
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 111505
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN not exists
         GOTO Step_1_Fail
      END

      IF @cFacility <> @cChkFacility
      BEGIN
         SET @nErrNo = 111506
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'
         GOTO Step_1_Fail
      END

      -- Validate ASN belong to the storer
      IF ISNULL( @cChkStorerKey, '') = ''
      BEGIN
         SET @nErrNo = 111507
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff storer'
         GOTO Step_1_Fail
      END

      -- Validate ASN status - (CANC)
      IF @cASNStatus = 'CANC'
      BEGIN
         SET @nErrNo = 111508
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ASN canc'
         GOTO Step_1_Fail
      END

      -- Validate ASN status
      IF @cReceiptStatus = '9'
      BEGIN
         SET @nErrNo = 111509
         SET @cErrMsg = rdt.rdtgetmessage( 60409, @cLangCode, 'DSP') --'ASN is closed'
         GOTO Step_1_Fail
      END

      -- Check if carton exists in multi ASN
      IF EXISTS ( SELECT 1
                  FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                  JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
                  WHERE (( @cCartonIDOnRcptDetail = '1' AND RD.UserDefine01 = @cCartonID) OR ( R.UserDefine01 = @cCartonID))
                  AND   R.StorerKey = @cStorerKey
                  GROUP BY R.ReceiptKey
                  HAVING COUNT( DISTINCT R.ReceiptKey) > 1) -- (james04)  
      BEGIN
         SET @nErrNo = 111510
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ctn Multi ASN
         GOTO Step_1_Fail
      END

      IF ISNULL( @cReceiptKey, '') = ''
         SET @cReceiptKey = @cChkReceiptKey

      IF ISNULL( @cPOKey, '') = '' OR @cPOKey <> 'NOPO'
         SET @cPOKey = @cChkPOKey

      SET @nSum_QtyReceived = 0
      SET @nSum_QtyExpected = 0
      SELECT @nSum_QtyReceived = ISNULL( SUM( BeforeReceivedQty), 0),
             @nSum_QtyExpected = ISNULL( SUM( QTYExpected), 0)
      FROM dbo.ReceiptDetail RD WITH (NOLOCK)
      JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
      WHERE R.ReceiptKey = @cReceiptKey
      AND   (( @cPOKey = '') OR ( R.POKey = @cPOKey))
      AND   R.StorerKey = @cStorerKey
      AND   (( @cCartonIDOnRcptDetail = '1' AND RD.UserDefine01 = @cCartonID) OR ( R.UserDefine01 = @cCartonID))

      -- Enable / disable QTY
      SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END

      SET @cOutField01 = @cCartonID
      SET @cOutField02 = @cReceiptKey
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = @nSum_QtyExpected
      SET @cOutField07 = @nSum_QtyReceived
      SET @cOutField08 = @cDefaultQTY -- QTY

      EXEC rdt.rdtSetFocusField @nMobile, 3

      SET @cSKU = ''
      SET @cQty = ''

      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Clear not finish data
      DECLARE CUR_RCV CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT RowRef
      FROM rdt.rdtUCCReceive2Log WITH (NOLOCK)
      WHERE AddWho = @cUserName
      AND   [Status] = '0'
      OPEN CUR_RCV
      FETCH NEXT FROM CUR_RCV INTO @nRowRef
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE FROM rdt.rdtUCCReceive2Log
         WHERE RowRef = @nRowRef

         FETCH NEXT FROM CUR_RCV INTO @nRowRef
      END
      CLOSE CUR_RCV
      DEALLOCATE CUR_RCV

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
      SET @cFieldAttr08 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cCartonID = ''
      SET @cReceiptKey = ''
      SET @cPOKey = ''
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   GOTO Quit
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 4951.
   CARTON ID   (field01)
   SKU         (field02, input)
   QTY         (field11, field12, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cUPC = @cInField03
      --SET @cQTY = @cInField08
      SET @cQTY = CASE WHEN @cFieldAttr08 = 'O' THEN @cOutField08 ELSE @cInField08 END -- QTY

      IF ISNULL( @cInField03, '') = ''
      BEGIN
         -- SKU is blank, check if anything received so far
         IF EXISTS ( SELECT 1
                     FROM rdt.rdtUCCReceive2Log WITH (NOLOCK)
                     WHERE ReceiptKey = @cReceiptKey
                     AND   (( @cPOKey = '') OR ( POKey = @cPOKey))
                     AND   StorerKey = @cStorerKey
                     AND   UCCNo = @cCartonID
                     AND   [Status] < '9'
                     AND   AddWho = @cUserName
                     AND   ISNULL( QTYReceived, 0) > 0)
         BEGIN
            SET @nSum_QtyReceived = 0
            SET @nSum_QtyExpected = 0
            SET @cSKU = ''
            DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT RD.SKU, ISNULL( SUM( BeforeReceivedQty), 0), ISNULL( SUM( QTYExpected), 0)
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
            WHERE R.ReceiptKey = @cReceiptKey
            AND   (( @cPOKey = '') OR ( R.POKey = @cPOKey))
            AND   R.StorerKey = @cStorerKey
            AND   (( @cCartonIDOnRcptDetail = '1' AND RD.UserDefine01 = @cCartonID) OR ( R.UserDefine01 = @cCartonID))
            GROUP BY RD.SKU
            OPEN CUR_LOOP
            FETCH NEXT FROM CUR_LOOP INTO @cSKU, @nSum_QtyReceived, @nSum_QtyExpected
            WHILE @@FETCH_STATUS <> -1
            BEGIN

               SET @nLogQtyReceived = 0
               IF EXISTS ( SELECT 1 FROM rdt.rdtUCCReceive2Log WITH (NOLOCK)
                           WHERE ReceiptKey = @cReceiptKey
                           AND   (( @cPOKey = '') OR ( POKey = @cPOKey))
                           AND   StorerKey = @cStorerKey
                           AND   UCCNo = @cCartonID
                           AND   [Status] < '9'
                           AND   AddWho = @cUserName
                           AND   SKU = @cSKU)
               BEGIN
                  SELECT @nLogQtyReceived = ISNULL( SUM( QtyReceived), 0)
                  FROM rdt.rdtUCCReceive2Log WITH (NOLOCK)
                  WHERE ReceiptKey = @cReceiptKey
                  AND   (( @cPOKey = '') OR ( POKey = @cPOKey))
                  AND   StorerKey = @cStorerKey
                  AND   UCCNo = @cCartonID
                  AND   [Status] < '9'
                  AND   AddWho = @cUserName
                  AND   SKU = @cSKU

                  IF @nLogQtyReceived = 0
                  BEGIN
                     SET @nErrNo = 111525
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Nothing 2 Rcv
                     GOTO Step_2_Fail
                  END
               END

               IF @cPromptIfRcvQtyMisMatch = '1' AND ( @nSum_QtyExpected <> ( @nSum_QtyReceived + @nLogQtyReceived))
               BEGIN
                  SET @nErrNo = 0
                  SET @cErrMsg01 = SUBSTRING( rdt.rdtgetmessage( 111526, @cLangCode, 'DSP'), 7, 14)
                  SET @cErrMsg02 = SUBSTRING( rdt.rdtgetmessage( 111527, @cLangCode, 'DSP'), 7, 14)

                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
                  @cErrMsg01, @cErrMsg02, @cErrMsg03, @cErrMsg04, @cErrMsg05

                  SET @nErrNo = 0
                  BREAK
               END

               FETCH NEXT FROM CUR_LOOP INTO @cSKU, @nSum_QtyReceived, @nSum_QtyExpected
            END
            CLOSE CUR_LOOP
            DEALLOCATE CUR_LOOP

            SET @nSum_LogQtyReceived = 0
            SELECT @nSum_LogQtyReceived = ISNULL( SUM( QtyReceived), 0)
            FROM rdt.rdtUCCReceive2Log WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
            AND   (( @cPOKey = '') OR ( POKey = @cPOKey))
            AND   StorerKey = @cStorerKey
            AND   UCCNo = @cCartonID
            AND   [Status] < '9'
            AND   AddWho = @cUserName
            AND   SKU = @cSKU

            -- Prep next screen var
            SET @cOutField01 = @cCartonID
            SET @cOutField02 = @cReceiptKey
            SET @cOutField03 = @nSum_LogQtyReceived
            SET @cOutField04 = @cUOM
            SET @cOutField05 = ''
            SET @cOutField06 = ''
            SET @cOutField07 = CASE WHEN @cReceiveDefaultToLoc <> '' THEN @cReceiveDefaultToLoc ELSE '' END

            EXEC rdt.rdtSetFocusField @nMobile, 5

            SET @nScn  = @nScn + 1
            SET @nStep = @nStep + 1

            GOTO Quit
         END
      END

      IF ISNULL( @cUPC, '') = ''
      BEGIN
         SET @nErrNo = 111511
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU required
         GOTO Step_SKU_Fail
      END

      -- Decode
      IF @cDecodeSKUSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSKUSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cToID       OUTPUT, @cUPC        OUTPUT, @nQTY        OUTPUT,
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT
         END
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSKUSP AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSKUSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCartonID, @cReceiptKey, @cPOKey, @cBarcode, ' +
               ' @cSKU        OUTPUT, @nQTY        OUTPUT, @cID        OUTPUT, @cLOC     OUTPUT, ' +
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cCartonID    NVARCHAR( 20), ' +
               ' @cReceiptKey  NVARCHAR( 10), ' +
               ' @cPOKey       NVARCHAR( 10), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +
               ' @nQTY         INT            OUTPUT, ' +
               ' @cID          NVARCHAR( 18)  OUTPUT, ' +
               ' @cLOC         NVARCHAR( 10)  OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCartonID, @cReceiptKey, @cPOKey, @cUPC,
               @cSKU        OUTPUT, @nQTY        OUTPUT, @cToID       OUTPUT, @cToLOC      OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_SKU_Fail

            IF @nQTY > 0
               SET @cQTY = CAST( @nQTY AS NVARCHAR( 5))
         END
      END

      -- Get SKU/UPC
      SET @nSKUCnt = 0
      EXEC RDT.rdt_GETSKUCNT
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 111512
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO Step_SKU_Fail
      END

      IF @nSKUCnt = 1
      BEGIN
         EXEC [RDT].[rdt_GETSKU]
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cUPC          OUTPUT
            ,@bSuccess    = @bSuccess      OUTPUT
            ,@nErr        = @nErrNo        OUTPUT
            ,@cErrMsg     = @cErrMsg       OUTPUT

         SET @cSKU = @cUPC
      END

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
               @cUPC     OUTPUT,
               @nErrNo   OUTPUT,
               @cErrMsg  OUTPUT,
               'ASN',    -- DocType
               @cReceiptKey

            IF @nErrNo = 0 -- Populate multi SKU screen
            BEGIN
               -- Go to Multi SKU screen
               SET @nScn = 3570
               SET @nStep = 4
               GOTO Quit
            END
            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
               SET @nErrNo = 0
         END
         ELSE
         BEGIN
            SET @nErrNo = 111513
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
            GOTO Step_SKU_Fail
         END
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                      JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
                      WHERE R.ReceiptKey = @cReceiptKey
                      AND   (( @cPOKey = '') OR ( R.POKey = @cPOKey))
                      AND   R.StorerKey = @cStorerKey
                      AND   (( @cCartonIDOnRcptDetail = '1' AND RD.UserDefine01 = @cCartonID) OR ( R.UserDefine01 = @cCartonID))
                      AND   RD.SKU = @cSKU)
      BEGIN
         SET @nErrNo = 111514
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not In Ctn
         GOTO Step_SKU_Fail
      END

      -- Get sku descr & uom
      SELECT @cSKUDesc = SKU.DESCR,
             @cUOM = Pack.PackUOM3
      FROM dbo.SKU SKU WITH (NOLOCK)
      JOIN dbo.Pack Pack WITH (NOLOCK) ON SKU.PackKey = Pack.PackKey
      WHERE SKU.StorerKey = @cStorerKey
      AND   SKU.SKU = @cSKU

      SET @cOutField01 = @cCartonID
      SET @cOutField02 = @cReceiptKey
      SET @cOutField03 = @cSKU
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 1, 20)
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
      SET @cOutField09 = @cSKU

      -- Validate blank QTY
      IF ISNULL( @cQty, '') = ''
      BEGIN
         --SET @nErrNo = 111515
         --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Qty Required
         --GOTO Step_Qty_Fail
         EXEC rdt.rdtSetFocusField @nMobile, 8
         GOTO Quit
      END

      -- Validate QTY
      IF rdt.rdtIsValidQty( @cQty, 1) = 0
      BEGIN
         SET @nErrNo = 111516
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty
         GOTO Step_Qty_Fail
      END

      IF @cNotAllowCtnQtyOverRcv = '1'
      BEGIN
      	DECLARE @nSKUExpQty     INT = 0
      	DECLARE @nSKURcvQty     INT = 0

         SELECT @nSKUExpQty = ISNULL( SUM( QTYExpected), 0)
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
         WHERE R.ReceiptKey = @cReceiptKey
         AND   (( @cPOKey = '') OR ( R.POKey = @cPOKey))
         AND   R.StorerKey = @cStorerKey
         AND   (( @cCartonIDOnRcptDetail = '1' AND RD.UserDefine01 = @cCartonID) OR ( R.UserDefine01 = @cCartonID))
         AND   RD.SKU = @cSKU

         SELECT @nSKURcvQty = ISNULL( SUM( QtyReceived), 0)
         FROM rdt.rdtUCCReceive2Log WITH (NOLOCK)
         WHERE ReceiptKey = ReceiptKey
         AND   (( @cPOKey = '') OR ( POKey = @cPOKey))
         AND   SKU = @cSKU
         AND   UCCNo = @cCartonID
         AND   StorerKey = @cStorerKey
         AND   [Status] = '0'
         AND   AddWho = @cUserName

      	IF ( @nSKURcvQty + CAST( @cQty AS NVARCHAR( 5))) > @nSKUExpQty
         BEGIN
            SET @nErrNo = 111529
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Over Rcv
            GOTO Step_SKU_Fail
         END
      END

      SET @nSum_QtyReceived = 0
      SET @nSum_QtyExpected = 0
      SELECT @nSum_QtyReceived = ISNULL( SUM( BeforeReceivedQty), 0),
             @nSum_QtyExpected = ISNULL( SUM( QTYExpected), 0)
      FROM dbo.ReceiptDetail RD WITH (NOLOCK)
      JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
      WHERE R.ReceiptKey = @cReceiptKey
      AND   (( @cPOKey = '') OR ( R.POKey = @cPOKey))
      AND   R.StorerKey = @cStorerKey
      AND   (( @cCartonIDOnRcptDetail = '1' AND RD.UserDefine01 = @cCartonID) OR ( R.UserDefine01 = @cCartonID))
      --AND   RD.SKU = @cSKU

      SET @nQty = CAST( @cQty AS NVARCHAR( 5))

      IF EXISTS ( SELECT 1 FROM rdt.rdtUCCReceive2Log WITH (NOLOCK)
                  WHERE ReceiptKey = ReceiptKey
                  AND   (( @cPOKey = '') OR ( POKey = @cPOKey))
                  AND   SKU = @cSKU
                  AND   StorerKey = @cStorerKey
                  AND   [Status] = '0'
                  AND   AddWho = @cUserName)
      BEGIN
         UPDATE rdt.rdtUCCReceive2Log WITH (ROWLOCK) SET
            QtyReceived = QtyReceived + @nQTY,
            EditWho = sUSER_sNAME(),
            EditDate = GETDATE()
         WHERE ReceiptKey = ReceiptKey
         AND   (( @cPOKey = '') OR ( POKey = @cPOKey))
         AND   SKU = @cSKU
         AND   StorerKey = @cStorerKey
         AND   [Status] = '0'
         AND   AddWho = @cUserName

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 111523
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RcvLog Err
            GOTO Step_2_Fail
         END
      END
      ELSE
      BEGIN
         SELECT @nQtyExpected = ISNULL( SUM( QTYExpected), 0)
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
         WHERE R.ReceiptKey = @cReceiptKey
         AND   (( @cPOKey = '') OR ( R.POKey = @cPOKey))
         AND   R.StorerKey = @cStorerKey
         AND   (( @cCartonIDOnRcptDetail = '1' AND RD.UserDefine01 = @cCartonID) OR ( R.UserDefine01 = @cCartonID))
         AND   RD.SKU = @cSKU

         INSERT INTO rdt.rdtUCCReceive2Log ( ReceiptKey, ReceiptLineNumber, POKey, StorerKey, SKU, UOM,
            QtyExpected, QtyReceived, ToID, ToLOC, UCCNo, Status, AddWho, AddDate, EditWho, EditDate)
         VALUES
         ( @cReceiptKey, '', @cPOKey, @cStorerKey, @cSKU, @cUOM,
            @nQtyExpected, @nQTY, '', '', @cCartonID, '0', @cUserName, GETDATE(), @cUserName, GETDATE())

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 111524
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins RcvLog Err
            GOTO Step_2_Fail
         END
      END

      SET @nSum_LogQtyReceived = 0
      SELECT @nSum_LogQtyReceived = ISNULL( SUM( QtyReceived), 0)
      FROM rdt.rdtUCCReceive2Log WITH (NOLOCK)
      WHERE ReceiptKey = ReceiptKey
      AND   (( @cPOKey = '') OR ( POKey = @cPOKey))
      AND   StorerKey = @cStorerKey
      AND   [Status] = '0'
      AND   AddWho = @cUserName

      SET @cOutField01 = @cCartonID
      SET @cOutField02 = @cReceiptKey
      SET @cOutField03 = ''
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 1, 20)
      SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
      SET @cOutField06 = @nSum_QtyExpected
      SET @cOutField07 = ( @nSum_QtyReceived + @nSum_LogQtyReceived)
      SET @cOutField08 = @cDefaultQTY -- QTY
      SET @cOutField09 = @cSKU

      EXEC rdt.rdtSetFocusField @nMobile, 3

   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep prev screen var
      SET @cCartonID = ''
      SET @cReceiptKey = ''
      SET @cPOKey = ''

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cFieldAttr08 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1

      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END

   Step_2_Quit:
   BEGIN
      -- Extended Info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cPOKey, @cCartonID, @cSKU, @nQTY, @cToLOC, @cTOID, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @tExtInfoVar, @cExtendedInfo OUTPUT'
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
               '@cCartonID     NVARCHAR( 20), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@nQTY          INT,           ' +
               '@cToLOC        NVARCHAR( 10), ' +
               '@cTOID         NVARCHAR( 18), ' +
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
               '@tExtInfoVar   VariableTable READONLY, ' +
               '@cExtendedInfo NVARCHAR( 20) OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cPOKey, @cCartonID, @cSKU, @nQTY, @cToLOC, @cTOID,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @tExtInfoVar, @cExtendedInfo OUTPUT

            IF @cExtendedInfo <> ''
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cUPC = ''
      SET @cQTY = ''
      SET @cOutField03 = ''
      SET @cOutField08 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 3
   END
   GOTO Quit

   Step_SKU_Fail:
   BEGIN
      SET @cUPC = ''
      SET @cOutField03 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 3
   END
   GOTO Quit

   Step_Qty_Fail:
   BEGIN
      SET @cQTY = ''
      SET @cOutField08 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 8
   END
END
GOTO Quit

/********************************************************************************
Step 3. Scn = 4952. Result
   CARTON ID   (field01)
   TO ID       (field02, input)
   To LOC      (field03, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cToID = @cInField05
      SET @cToLOC = @cInField07

      SET @cBarcode = @cInField05

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cBarcode) = 0
      BEGIN
         SET @nErrNo = 111517
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_ToID_Fail
      END

      EXECUTE nspGetRight
         @c_Facility    = @cFacility,
         @c_StorerKey   = @cStorerKey,
         @c_SKU         = NULL,        -- @cSKU
         @c_ConfigKey   = 'DisAllowDuplicateIdsOnRFRcpt',
         @b_Success     = @bSuccess    OUTPUT,
         @c_Authority   = @cAuthority  OUTPUT,
         @n_err         = @nErrNo      OUTPUT,
         @c_errmsg      = @cErrMsg     OUTPUT

      -- Check ID in used
      IF @cAuthority = '1' AND @cToID <> ''
      BEGIN
         IF EXISTS( SELECT [ID]
            FROM dbo.LOTxLOCxID LOTxLOCxID WITH (NOLOCK)
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC)
            WHERE [ID] = @cToID
               AND QTY > 0
               AND LOC.Facility = @cFacility)
         BEGIN
            SET @nErrNo = 111518
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Duplicate ID
            GOTO Step_ToID_Fail
         END
      END

     -- Validate compulsary field
      IF ISNULL( @cToLOC, '') = ''
      BEGIN
         SET @nErrNo = 111519
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOC
         GOTO Step_ToLOC_Fail
      END

      -- Get the location
      SET @cChkLOC = ''
      SET @cChkFacility = ''
      SELECT
         @cChkLOC = LOC,
         @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cToLOC

      -- Validate location
      IF @cChkLOC = ''
      BEGIN
         SET @nErrNo = 111520
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         GOTO Step_ToLOC_Fail
      END

      -- Validate location not in facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 111521
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         GOTO Step_ToLOC_Fail
      END

      --IF @nQTY = 0
      --BEGIN
      --   SET @nErrNo = 111522
      --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Nothing To Rcv
      --   GOTO Quit
      --END

      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_UCCReceive2 -- For rollback or commit only our own transaction

      SET @nNOPOFlag = CASE WHEN @cPOkey = 'NOPO' THEN 1 ELSE 0 END

      DECLARE CUR_RCV CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT SKU, ISNULL( SUM( QtyReceived), 0)
      FROM rdt.rdtUCCReceive2Log WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   (( @cPOKey = '') OR ( POKey = @cPOKey))
      AND   StorerKey = @cStorerKey
      AND   UCCNo = @cCartonID
      AND   [Status] = '0'
      AND   AddWho = @cUserName
      GROUP BY SKU
      OPEN CUR_RCV
      FETCH NEXT FROM CUR_RCV INTO @cSKU2Receive, @nQty2Receive
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT TOP 1
                @cLottable01 = RD.Lottable01,
                @cLottable02 = RD.Lottable02,
                @cLottable03 = RD.Lottable03,
                @dLottable04 = RD.Lottable04,
                @cLottable06 = RD.Lottable06,
                @cLottable07 = RD.Lottable07,
                @cLottable08 = RD.Lottable08,
                @cLottable09 = RD.Lottable09,
                @cLottable10 = RD.Lottable10,
                @cLottable11 = RD.Lottable11,
                @cLottable12 = RD.Lottable12,
                @dLottable13 = RD.Lottable13,
                @dLottable14 = RD.Lottable14,
                @dLottable15 = RD.Lottable15
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
         WHERE R.StorerKey = @cStorerKey
         AND   R.ReceiptKey = @cReceiptKey
         AND   (( @cCartonIDOnRcptDetail = '1' AND RD.UserDefine01 = @cCartonID) OR ( R.UserDefine01 = @cCartonID))
         AND   RD.SKU = @cSKU2Receive
         --AND   RD.BeforeReceivedQty > 0 (james03)  

         EXEC rdt.rdt_UCCReceive2_Confirm
            @nFunc         = @nFunc,
            @nMobile       = @nMobile,
            @cLangCode     = @cLangCode,
            @nErrNo        = @nErrNo OUTPUT,
            @cErrMsg       = @cErrMsg OUTPUT,
            @cStorerKey    = @cStorerKey,
            @cFacility     = @cFacility,
            @cReceiptKey   = @cReceiptKey,
            @cPOKey        = @cPoKey,
            @cToLOC        = @cToLOC,
            @cToID         = @cTOID,
            @cSKUCode      = @cSKU2Receive,
            @cSKUUOM       = @cUOM,
            @nSKUQTY       = @nQty2Receive,
            @cUCC          = '',
            @cUCCSKU       = '',
            @nUCCQTY       = '',
            @cCreateUCC    = '0',
            @cLottable01   = @cLottable01,
            @cLottable02   = @cLottable02,
            @cLottable03   = @cLottable03,
            @dLottable04   = @dLottable04,
            @dLottable05   = NULL,
            @cLottable06   = @cLottable06,
            @cLottable07   = @cLottable07,
            @cLottable08   = @cLottable08,
            @cLottable09   = @cLottable09,
            @cLottable10   = @cLottable10,
            @cLottable11   = @cLottable11,
            @cLottable12   = @cLottable12,
            @dLottable13   = @dLottable13,
            @dLottable14   = @dLottable14,
            @dLottable15   = @dLottable15,
            @nNOPOFlag     = @nNOPOFlag,
            @cConditionCode = 'OK',
            @cSubreasonCode = ''

         IF @nErrno <> 0
         BEGIN
            CLOSE CUR_RCV
            DEALLOCATE CUR_RCV
            GOTO RollBackTran
         END
         ELSE
         BEGIN
            UPDATE rdt.rdtUCCReceive2Log WITH (ROWLOCK) SET
               [Status] = '9',
               EditWho = @cUserName,
               EditDate = GETDATE()
            WHERE ReceiptKey = @cReceiptKey
            AND   (( @cPOKey = '') OR ( POKey = @cPOKey))
            AND   StorerKey = @cStorerKey
            AND   UCCNo = @cCartonID
            AND   [Status] = '0'
            AND   AddWho = @cUserName

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 111528
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RcvLog Err
               CLOSE CUR_RCV
               DEALLOCATE CUR_RCV
               GOTO RollBackTran
            END
         END

         EXEC RDT.rdt_STD_EventLog --(yeekung01)
            @cActionType   = '2', -- Receiving
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cReceiptKey   = @cReceiptKey,
            @cPOKey        = @cPOKey,
            @cStorerKey    = @cStorerkey,
            @cLocation     = @cToLOC,
            @cID           = @cTOID,
            @cSKU          = @cSKU2Receive,
            @cUOM          = @cUOM,
            @nQTY          = @nQty2Receive,
            @cUCC          = @cCartonID,
            @cLottable01   = @cLottable01,
            @cLottable02   = @cLottable02,
            @cLottable03   = @cLottable03,
            @dLottable04   = @dLottable04,
            @cLottable06   = @cLottable06,
            @cLottable07   = @cLottable07,
            @cLottable08   = @cLottable08,
            @cLottable09   = @cLottable09,
            @cLottable10   = @cLottable10,
            @cLottable11   = @cLottable11,
            @cLottable12   = @cLottable12,
            @dLottable13   = @dLottable13,
            @dLottable14   = @dLottable14,
            @dLottable15   = @dLottable15

         FETCH NEXT FROM CUR_RCV INTO @cSKU2Receive, @nQty2Receive
      END
      CLOSE CUR_RCV
      DEALLOCATE CUR_RCV

      GOTO CommitTran

      RollBackTran:
         ROLLBACK TRAN rdt_UCCReceive2 -- Only rollback change made here

      CommitTran:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Go back screen 1 after scanned toid/toloc
      SET @cCartonID = ''
      SET @cReceiptKey = ''
      SET @cPOKey = ''

      -- Prep next screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1

      SET @nScn  = @nScn - 2
      SET @nStep = @nStep - 2
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @nSum_QtyReceived = 0
      SET @nSum_QtyExpected = 0
      SELECT @nSum_QtyReceived = ISNULL( SUM( BeforeReceivedQty), 0),
             @nSum_QtyExpected = ISNULL( SUM( QTYExpected), 0)
      FROM dbo.ReceiptDetail RD WITH (NOLOCK)
      JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
      WHERE R.ReceiptKey = @cReceiptKey
      AND   (( @cPOKey = '') OR ( R.POKey = @cPOKey))
      AND   R.StorerKey = @cStorerKey
      AND   (( @cCartonIDOnRcptDetail = '1' AND RD.UserDefine01 = @cCartonID) OR ( R.UserDefine01 = @cCartonID))

      SET @nSum_LogQtyReceived = 0
      SELECT @nSum_LogQtyReceived = ISNULL( SUM( QtyReceived), 0)
      FROM rdt.rdtUCCReceive2Log WITH (NOLOCK)
      WHERE ReceiptKey = ReceiptKey
      AND   (( @cPOKey = '') OR ( POKey = @cPOKey))
      AND   StorerKey = @cStorerKey
      AND   [Status] = '0'
      AND   AddWho = @cUserName

      SET @cOutField01 = @cCartonID
      SET @cOutField02 = @cReceiptKey
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = @nSum_QtyExpected
      SET @cOutField07 = ( @nSum_QtyReceived + @nSum_LogQtyReceived)
      SET @cOutField08 = @cDefaultQTY -- QTY

      EXEC rdt.rdtSetFocusField @nMobile, 3

      SET @cSKU = ''
      SET @cQty = ''

      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_ToID_Fail:
   BEGIN
      SET @cToID = ''
      SET @cOutField05 = ''
      SET @cOutField07 = @cToLOC
      EXEC rdt.rdtSetFocusField @nMobile, 5
   END
   GOTO Quit

   Step_ToLOC_Fail:
   BEGIN
      SET @cToLOC = ''
      SET @cOutField05 = @cToID
      SET @cOutField07 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 7
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 4. Screen = 3570. Multi SKU
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
Step_4:
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

   SET @nSum_QtyReceived = 0
   SET @nSum_QtyExpected = 0
   SELECT @nSum_QtyReceived = ISNULL( SUM( BeforeReceivedQty), 0),
          @nSum_QtyExpected = ISNULL( SUM( QTYExpected), 0)
   FROM dbo.ReceiptDetail RD WITH (NOLOCK)
   JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
   WHERE R.ReceiptKey = @cReceiptKey
   AND   (( @cPOKey = '') OR ( R.POKey = @cPOKey))
   AND   R.StorerKey = @cStorerKey
   AND   (( @cCartonIDOnRcptDetail = '1' AND RD.UserDefine01 = @cCartonID) OR ( R.UserDefine01 = @cCartonID))

   SET @nSum_LogQtyReceived = 0
   SELECT @nSum_LogQtyReceived = ISNULL( SUM( QtyReceived), 0)
   FROM rdt.rdtUCCReceive2Log WITH (NOLOCK)
   WHERE ReceiptKey = ReceiptKey
   AND   (( @cPOKey = '') OR ( POKey = @cPOKey))
   AND   StorerKey = @cStorerKey
   AND   [Status] = '0'
   AND   AddWho = @cUserName

   -- Prepare next screen var
   SET @cOutField01 = @cCartonID
   SET @cOutField02 = @cReceiptKey
   SET @cOutField03 = @cSKU
   SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 1, 20)
   SET @cOutField05 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
   SET @cOutField06 = @nSum_QtyExpected
   SET @cOutField07 = ( @nSum_QtyReceived + @nSum_LogQtyReceived)
   SET @cOutField08 = @cQty
   SET @cOutField09 = @cSKU

   EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

   -- Go to SKU QTY screen
   SET @nScn = @nScn - 2
   SET @nStep = @nStep - 2
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
      V_POKey      = @cPOKey,
      V_ID         = @cToID,
      V_LOC        = @cToLoc,
      V_UCC        = @cCartonID,
      V_UOM        = @cUOM,
      --V_QTY        = @nQTY,
      V_SKUDescr   = @cSKUDesc,
      V_SKU        = @cSKU,

      V_Integer1   = @nQTY,

      V_String1 = @cAllowCtnIDBlank,
      V_String2 = @cDecodeSKUSP,
      V_String3 = @cReceiveDefaultToLoc,
      V_String4 = @cMultiSKUBarcode,
      V_String5 = @cVerifySKU,
      V_String6 = @cPOKeyDefaultValue,
      V_String7 = @cQty,
      V_String8 = @cPromptIfRcvQtyMisMatch,
      V_String9 = @cDisableQTYField,
      V_String10 = @cDefaultQTY,
      V_String11 = @cExtendedInfoSP,
      V_String12 = @cCartonIDOnRcptDetail,
      V_String13 = @cNotAllowCtnQtyOverRcv,

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