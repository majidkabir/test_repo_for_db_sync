SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_CartonLabelReceive                           */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: allows user receive-in stock in the form of cartons         */
/*                                                                      */
/* FBR            : 122729                                              */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2009-02-05 1.0  James    Created                                     */
/* 2010-01-13 1.1  ChewKP   SOS#202287 Display Qty Received and Qty     */
/*                          Expected (ChewKP01)                         */
/* 2015-01-16 1.2  CSCHONG  New lottable 05 to 15 (CS01)                */
/* 2015-05-25 1.3  CSCHONG  Remove rdt_receive lottable06-15 parm (CS02)*/
/* 2016-09-30 1.4  Ung      Performance tuning                          */
/* 2016-10-28 1.5  James    Change isDate to rdtIsValidDate (james01)   */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdtfnc_CartonLabelReceive] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF  

-- Misc variable
DECLARE
   @b_success           INT

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nMenu               INT,
   @nInputKey           NVARCHAR( 3),

   @cStorerkey          NVARCHAR( 15),
   @cUserName           NVARCHAR( 18),
   @cFacility           NVARCHAR( 5),
   @cPrinter            NVARCHAR( 10),

   @cReceiptKey         NVARCHAR( 10),
   @cPOKey              NVARCHAR( 10),
   @cPOKeyDefaultValue  NVARCHAR( 10),
   @cLOC                NVARCHAR( 10),
   @cTOID               NVARCHAR( 18),
   @cSKU                NVARCHAR( 20),
   @cSKUDesc            NVARCHAR( 60),
   @cUOM                NVARCHAR( 10),
   @cQty                NVARCHAR( 5),
   @cEst_Ctn_Cnt        NVARCHAR( 5),
   @cLabelNo            NVARCHAR( 32),

   @cStyle              NVARCHAR( 20),
   @cColor              NVARCHAR( 10),
   @cSize               NVARCHAR( 5),
   @cCO                 NVARCHAR( 20),
   @cLottable_Exists    NVARCHAR( 1),
   @cOption             NVARCHAR( 1),
   @cPOKeyValue         NVARCHAR( 10),
   @cListName           NVARCHAR( 20),
   @cShort              NVARCHAR( 10),
   @cStoredProd         NVARCHAR( 250),

   @nCount              INT,
   @nQty                INT,
   @nEst_Ctn_Cnt        INT,  -- Estimated carton count
   @nCtn_Cnt            INT,  -- current carton count
   @nSum_QtyExpected    INT,
   @nSum_BeforeReceivedQty INT, 

   @cLottableLabel      NVARCHAR( 20),
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

   @cTempLotLabel       NVARCHAR( 20),
   @cTempLottable01     NVARCHAR( 18), --input field lottable01 from lottable screen
   @cTempLottable02     NVARCHAR( 18), --input field lottable02 from lottable screen
   @cTempLottable03     NVARCHAR( 18), --input field lottable03 from lottable screen
   @cTempLottable04     NVARCHAR( 16), --input field lottable04 from lottable screen
   @cTempLottable05     NVARCHAR( 16), --input field lottable05 from lottable screen

   @cLottable01Label    NVARCHAR( 20),
   @cLottable02Label    NVARCHAR( 20), 
   @cLottable03Label    NVARCHAR( 20),
   @cLottable04Label    NVARCHAR( 20),
   @cLottable05Label    NVARCHAR( 20),

   @cLottable06Label    NVARCHAR( 20),          --(CS01)
   @cLottable07Label    NVARCHAR( 20),          --(CS01)
   @cLottable08Label    NVARCHAR( 20),          --(CS01)
   @cLottable09Label    NVARCHAR( 20),          --(CS01)
   @cLottable10Label    NVARCHAR( 20),          --(CS01)
   @cLottable11Label    NVARCHAR( 20),          --(CS01)
   @cLottable12Label    NVARCHAR( 20),          --(CS01)
   @cLottable13Label    NVARCHAR( 20),           --(CS01) 
   @cLottable14Label    NVARCHAR( 20),           --(CS01)
   @cLottable15Label    NVARCHAR( 20),           --(CS01)

   @cTempLotLabel01     NVARCHAR( 20), 
   @cTempLotLabel02     NVARCHAR( 20),
   @cTempLotLabel03     NVARCHAR( 20),
   @cTempLotLabel04     NVARCHAR( 20),
   @cTempLotLabel05     NVARCHAR( 20), 

   @dTempLottable04     DATETIME,
   @dTempLottable05     DATETIME,
   
   @dTempLottable13     DATETIME,            --(CS01)
   @dTempLottable14     DATETIME,            --(CS01)
   @dTempLottable15     DATETIME,            --(CS01)

   @cDecodeLabelNo       NVARCHAR( 20),
   @cReceiveDefaultToLoc NVARCHAR( 10),
   @nRetainLottableValue INT,
   @nDisAllowDuplicateIdsOnRFRcpt INT,
   

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

   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)

-- Getting Mobile information
SELECT
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @cLangCode   = Lang_code,
   @nMenu       = Menu,

   @cStorerKey  = StorerKey,
   @cFacility   = Facility,
   @cUserName   = UserName,
   @cPrinter    = Printer,

   @cReceiptKey   = V_ReceiptKey,
   @cPOKey        = V_POKey,
   @cLOC          = V_LOC,
   @cTOID         = V_ID,
   @cSKU          = V_SKU,
   @cUOM          = V_UOM,
   @nQTY          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY,  5), 0) = 1 THEN LEFT( V_QTY,  5) ELSE 0 END,
   @cLottable01   = V_Lottable01,
   @cLottable02   = V_Lottable02,
   @cLottable03   = V_Lottable03,
   @dLottable04   = V_Lottable04,

   @cPOKeyDefaultValue = V_String1,
   @nEst_Ctn_Cnt       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String2,  5), 0) = 1 THEN LEFT( V_String2,  5) ELSE 0 END,
   @nCtn_Cnt           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3,  5), 0) = 1 THEN LEFT( V_String3,  5) ELSE 0 END,
   @cLottable01Label   = V_String4,
   @cLottable02Label   = V_String5,
   @cLottable03Label   = V_String6,
   @cLottable04Label   = V_String7,
   @cDecodeLabelNo     = V_String8,
   @cReceiveDefaultToLoc = V_String9,
   @nRetainLottableValue = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String10,  5), 0) = 1 THEN LEFT( V_String10,  5) ELSE 0 END,
   @nDisAllowDuplicateIdsOnRFRcpt = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String11,  5), 0) = 1 THEN LEFT( V_String11,  5) ELSE 0 END,
   @cStyle             = V_String12,
   @cColor             = V_String13,
   @cSize              = V_String14,
   @cCO                = V_String15,
   @nSum_QtyExpected   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String16,  5), 0) = 1 THEN LEFT( V_String16,  5) ELSE 0 END, -- (ChewKP01)
   @nSum_BeforeReceivedQty = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String17,  5), 0) = 1 THEN LEFT( V_String17,  5) ELSE 0 END, -- (ChewKP01)
   

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

FROM   RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1740 OR @nFunc = 1741
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu
   IF @nStep = 1 GOTO Step_1   -- Scn = 1920. ASN #
   IF @nStep = 2 GOTO Step_2   -- Scn = 1921. LOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 1922. PAL ID
   IF @nStep = 4 GOTO Step_4   -- Scn = 1923. SKU
   IF @nStep = 5 GOTO Step_5   -- Scn = 1924. LABEL
   IF @nStep = 6 GOTO Step_6   -- Scn = 1925. LOTTABLES
   IF @nStep = 7 GOTO Step_7   -- Scn = 1926. CONFIRM OVER RECEIVE
   IF @nStep = 8 GOTO Step_8   -- Scn = 1927. CONFIRM SHORT RECEIVE

END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 1580. Menu
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN
   -- Note: rdt.RDTGetConfig default return '0' if config not setup, have to reset the variable = '' or something else
   --get POKey as 'NOPO' if storerconfig has been setup for 'ReceivingPOKeyDefaultValue'
   SET @cPOKeyDefaultValue = rdt.RDTGetConfig( @nFunc, 'ReceivingPOKeyDefaultValue', @cStorerkey)
   IF @cPOKeyDefaultValue = '0'
      SET @cPOKeyDefaultValue = ''

   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerkey)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''

   SET @cReceiveDefaultToLoc = rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorerkey)
   IF @cReceiveDefaultToLoc = '0'
      SET @cReceiveDefaultToLoc = ''

   SET @nRetainLottableValue = 0
   SET @nRetainLottableValue = rdt.RDTGetConfig( @nFunc, 'RetainLottableValue', @cStorerkey)

   --check whether allow duplicate pallet id
   SET @nDisAllowDuplicateIdsOnRFRcpt = 0 -- Default Off
   SELECT @nDisAllowDuplicateIdsOnRFRcpt = NSQLValue
   FROM dbo.NSQLConfig (NOLOCK)
   WHERE ConfigKey = 'DisAllowDuplicateIdsOnRFRcpt'

   IF ISNULL(@cPOKeyDefaultValue, '') <> ''
      SET @cOutField02 = @cPOKeyDefaultValue
   ELSE
      SET @cOutField02 = ''

   -- Set the entry point
   SET @nScn  = 1920
   SET @nStep = 1

   -- initialise all variable
   SET @cReceiptKey = ''
   SET @cPOKey= ''

   -- Prep next screen var
   SET @cOutField01 = '' -- ReceiptKey

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


/********************************************************************************
Step 1. Scn = 1920. ASN #, PO# screen
   ASN # (field01)
   PO # (field02)
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
      IF ISNULL(@cReceiptKey, '') = '' AND  ISNULL(@cPOkey, '') = ''
      BEGIN
         SET @nErrNo = 66176
         SET @cErrMsg = rdt.rdtgetmessage( 66176, @cLangCode, 'DSP') --ASN or PO req
         GOTO Step_1_Fail
      END

      IF ISNULL(@cReceiptKey, '') = '' AND UPPER(@cPOKey) ='NOPO'
      BEGIN
         SET @nErrNo = 66177
         SET @cErrMsg = rdt.rdtgetmessage( 66177, @cLangCode, 'DSP') --ASN needed
         GOTO Step_1_Fail
      END

      -- when both ASN and PO key in, check if the ASN and PO exists
      IF ISNULL(@cReceiptKey, '') <> '' AND ISNULL(@cPOKey, '') <> '' AND  UPPER(@cPOKey) <> 'NOPO'
      BEGIN
         IF NOT EXISTS (SELECT 1
            FROM dbo.Receipt R WITH (NOLOCK)
               JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
            WHERE R.ReceiptKey = @cReceiptkey
               AND RD.POKey = @cPOKey)
         BEGIN
            SET @nErrNo = 66178
            SET @cErrMsg = rdt.rdtgetmessage( 66178, @cLangCode, 'DSP') --Invalid ASN/PO
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
            GOTO Quit
         END
      END

       --When only PO keyed-in (ASN left as blank)
      IF ISNULL(@cPOKey, '') <> '' AND UPPER(@cPOKey) <> 'NOPO' AND ISNULL(@cReceiptkey, '')  = ''
      BEGIN
         IF NOT EXISTS (SELECT 1
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE POkey = @cPOKey)
         BEGIN
            SET @nErrNo = 66179
            SET @cErrMsg = rdt.rdtgetmessage( 66179, @cLangCode, 'DSP') --PO not exists
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- POKey
            GOTO Step_1_Fail
         END

         DECLARE @nCountReceipt int
         SET @nCountReceipt = 0

         --get ReceiptKey count
         SELECT @nCountReceipt = COUNT(DISTINCT Receiptkey)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE POKey = @cPOKey

         IF @nCountReceipt = 1
         BEGIN
            --get single ReceiptKey
            SELECT @cReceiptKey = ReceiptKey
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE POkey = @cPOKey
         END
         ELSE IF @nCountReceipt > 1
         BEGIN
            SET @nErrNo = 66180
            SET @cErrMsg = rdt.rdtgetmessage( 66180, @cLangCode, 'DSP') --ASN needed
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
            GOTO Step_1_Fail
         END
      END

      --check if receiptkey exists
      IF NOT EXISTS (SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptkey)
      BEGIN
         SET @nErrNo = 66181
         SET @cErrMsg = rdt.rdtgetmessage( 66181, @cLangCode, 'DSP') --ASN not exists
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail
      END

      --check diff facility
      IF NOT EXISTS ( SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND Facility = @cFacility)
      BEGIN
         SET @nErrNo = 66182
         SET @cErrMsg = rdt.rdtgetmessage( 66182, @cLangCode, 'DSP') --Diff facility
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail
      END

      --check diff storer
      IF NOT EXISTS ( SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND Storerkey = @cStorerkey)
      BEGIN
         SET @nErrNo = 66183
         SET @cErrMsg = rdt.rdtgetmessage( 66183, @cLangCode, 'DSP') --Diff storer
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail
      END

      --check for ASN closed by receipt.status
      IF EXISTS ( SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND Status = '9')
      BEGIN
         SET @nErrNo = 66184
         SET @cErrMsg = rdt.rdtgetmessage( 66184, @cLangCode, 'DSP') --ASN closed
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail
      END

      --check for ASN closed by receipt.ASNStatus
      IF EXISTS ( SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND ASNStatus = '9' )
      BEGIN
         SET @nErrNo = 66185
         SET @cErrMsg = rdt.rdtgetmessage( 66185, @cLangCode, 'DSP') --ASN closed
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail
      END

      --check for ASN cancelled
      IF EXISTS ( SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND ASNStatus = 'CANC')
      BEGIN
         SET @nErrNo = 66186
         SET @cErrMsg = rdt.rdtgetmessage( 66186, @cLangCode, 'DSP') --ASN cancelled
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail
      END

      --When only ASN keyed-in (PO left as blank or NOPO): --retrieve single PO if there is
      IF ISNULL(@cReceiptKey, '') <> '' AND (@cPOKey = '' OR UPPER(@cPOKey) = 'NOPO')
      BEGIN
         DECLARE @nCountPOKey int
         SET @nCountPOKey = 0

         --get pokey count
         SELECT @nCountPOKey = COUNT(DISTINCT POKey)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptkey

         IF @nCountPOKey = 1
         BEGIN
            IF UPPER(@cPOKey) <> 'NOPO'
            BEGIN
               --get single pokey
               SELECT @cPOKey = POKey
               FROM dbo.ReceiptDetail WITH (NOLOCK)
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
                  SET @nErrNo = 66187
                  SET @cErrMsg = rdt.rdtgetmessage( 66187, @cLangCode, 'DSP') --PO needed
                  SET @cOutField01 = @cReceiptKey
                  EXEC rdt.rdtSetFocusField @nMobile, 2 -- POKey
                  GOTO Quit
               END
            END
         END
      END

      --prepare next screen variable
      SET @cOutField01 = @cReceiptkey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cReceiveDefaultToLoc

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option

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

   Step_1_Fail:
   BEGIN
      SET @cReceiptkey = ''
      SET @cOutField01 = '' --ReceiptKey
      SET @cOutField02 = @cPOKey
   END
END
GOTO Quit

/********************************************************************************
Step 2. Scn = 1921. Location screen
   LOC
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      --screen mapping
      SET @cLOC = @cInField03

      --validate blank LOC
      IF ISNULL(@cLOC, '') = ''
      BEGIN
         SET @nErrNo = 66188
         SET @cErrMsg = rdt.rdtgetmessage(66188, @cLangCode, 'DSP') --TO LOC needed
         GOTO Step_2_Fail
      END

      --check for exist of loc in the table
      IF NOT EXISTS ( SELECT 1
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cLOC)
      BEGIN
         SET @nErrNo = 66189
         SET @cErrMsg = rdt.rdtgetmessage(66189, @cLangCode, 'DSP') --Invalid TO LOC
         GOTO Step_2_Fail
      END

      --check for diff facility
      IF NOT EXISTS ( SELECT 1
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cLOC
            AND FACILITY = @cFacility)
      BEGIN
         SET @nErrNo = 66190
         SET @cErrMsg = rdt.rdtgetmessage(66190, @cLangCode, 'DSP') --Diff facility
         GOTO Step_2_Fail
      END

      --prepare next screen variable
      SET @cOutField01 = @cReceiptkey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cLOC
      SET @cOutField04 = '' --TO ID

      SET @cTOID       = ''

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = '' -- ReceiptKey
      SET @cOutField02 = CASE WHEN @cPOKey = 'NOPO' THEN 'NOPO' ELSE '' END
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
Step 3. Scn = 1922. Pallet ID screen
   ID
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      --screen mapping
      SET @cTOID = @cInField04

      --check if TOID is null
      IF ISNULL(@cTOID, '') = ''
      BEGIN
         SET @nErrNo = 66191
         SET @cErrMsg = rdt.rdtgetmessage(66191, @cLangCode, 'DSP') --TO ID needed
         GOTO Step_3_Fail
      END

      --allow duplicate TOID or not
      IF (@nDisAllowDuplicateIdsOnRFRcpt = '1') AND ISNULL(@cTOID, '') <> ''
      BEGIN
         -- check if TOLOC is valid
         IF EXISTS ( SELECT LLI.ID
            FROM dbo.LotxLocxId LLI WITH (NOLOCK)
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.Loc = LOC.LOC)
               WHERE LLI.ID = @cTOID
               AND LOC.Facility = @cFacility
               AND LLI.QTY > 0)
         BEGIN
            SET @nErrNo = 66193
            SET @cErrMsg = rdt.rdtgetmessage(66193, @cLangCode, 'DSP') --Duplicate ID
            GOTO Step_3_Fail
         END
      END

      --prepare next screen variable
      SET @cOutField01 = @cReceiptkey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cLOC
      SET @cOutField04 = @cTOID
      SET @cOutField05 = '' -- CTN on ID

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      -- Reset lottable value on new ID
      SET @cLottable01 = ''
      SET @cLottable02 = ''
      SET @cLottable03 = ''
      SET @dLottable04 = 0
   END


   IF @nInputKey = 0 -- Esc
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = '' -- LOC

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
Step 4. (screen = 1923) 
   ReceiptKey: (field01)
   PO:         (field02)
   TO LOC:     (field03)
   TO ID:      (field04)

   CTN ON ID   (field05, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1      -- ENTER
   BEGIN
      --Screen Mapping
      SET @cEst_Ctn_Cnt = @cInField05

      -- Check if extimated qty key in
      IF ISNULL(@cEst_Ctn_Cnt, '') = ''
      BEGIN
         SET @nErrNo = 66194
         SET @cErrMsg = rdt.rdtgetmessage( 66194, @cLangCode, 'DSP') --Qty needed
         GOTO Step_4_Fail
      END

      IF RDT.rdtIsValidQTY( @cEst_Ctn_Cnt, 0) = 0
      BEGIN
         SET @nErrNo = 66195
         SET @cErrMsg = rdt.rdtgetmessage( 66195, @cLangCode, 'DSP') --Invalid Qty
         GOTO Step_4_Fail
      END

      SET @nEst_Ctn_Cnt = @cEst_Ctn_Cnt
      
      

      --prepare next screen variable
      SET @cOutField01 = ' 0/' + CONVERT(CHAR( 2), @nEst_Ctn_Cnt)
      SET @cOutField02 = '' --Label
      SET @cOutField03 = '' --SKU
      SET @cOutField04 = '' --Style
      SET @cOutField05 = '' --Color
      SET @cOutField06 = '' --Size
      SET @cOutField07 = '' --Qty
      SET @cOutField08 = '' --CO#
      SET @cOutField09 = '' -- Qty Received, Qty Expected -- (ChewKP01)

      -- Reset current carton count value
      SET @nCtn_Cnt = 0

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

     -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END


   IF @nInputKey = 0 -- Esc
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cLOC
      SET @cOutField04 = ''--ID

      --go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:
      SET @cOutField05 = ''

END
GOTO Quit


/********************************************************************************
Step 5. Scn = 1924. Label screen
   Label
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      --Screen Mapping
      SET @cLabelNo = @cInField02

      IF ISNULL(@cLabelNo, '') = ''
      BEGIN
         SET @nErrNo = 66196
         SET @cErrMsg = rdt.rdtgetmessage( 66196, @cLangCode, 'DSP') --LabelNo needed
         GOTO Step_5_Fail
      END

      IF ISNULL(@cDecodeLabelNo, '') = ''
      BEGIN
         SET @nErrNo = 66198
         SET @cErrMsg = rdt.rdtgetmessage( 66198, @cLangCode, 'DSP') --DecodeSP Blank
         GOTO Step_5_Fail
      END

      EXEC dbo.ispLabelNo_Decoding_Wrapper 
          @c_SPName     = @cDecodeLabelNo
         ,@c_LabelNo    = @cLabelNo
         ,@c_Storerkey  = @cStorerkey
         ,@c_ReceiptKey = @cReceiptKey
         ,@c_POKey      = @cPOKey
	      ,@c_LangCode   = @cLangCode
	      ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
	      ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
         ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
         ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
         ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
         ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#
         ,@c_oFieled07  = @c_oFieled07 OUTPUT
         ,@c_oFieled08  = @c_oFieled08 OUTPUT
         ,@c_oFieled09  = @c_oFieled09 OUTPUT
         ,@c_oFieled10  = @c_oFieled10 OUTPUT
         ,@b_Success    = @b_Success   OUTPUT
         ,@n_ErrNo      = @nErrNo      OUTPUT
         ,@c_ErrMsg     = @cErrMsg     OUTPUT

      IF ISNULL(@cErrMsg, '') <> ''  
      BEGIN
         SET @cErrMsg = @cErrMsg
         GOTO Step_5_Fail
      END  

      -- Check if current carton carton count greater than the estimated carton count
      IF @nEst_Ctn_Cnt < @nCtn_Cnt + 1
      BEGIN
         SET @nErrNo = 66197
         SET @cErrMsg = rdt.rdtgetmessage( 66197, @cLangCode, 'DSP') --CTN > TotalCTN
         GOTO Step_5_Fail
      END

      SET @cSKU = @c_oFieled01
      SET @cStyle = @c_oFieled02
      SET @cColor = @c_oFieled03
      SET @cSize = @c_oFieled04
      SET @nQty = CAST(@c_oFieled05 AS INT)
      SET @cCO = @c_oFieled06

      SELECT TOP 1 @cUOM = UOM 
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ReceiptKey = @cReceiptKey
         AND SKU = @cSKU

      SELECT @nSum_BeforeReceivedQty = SUM(BeforeReceivedQty), 
             @nSum_QtyExpected = SUM(QtyExpected) 
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ReceiptKey = @cReceiptKey
         AND SKU = @cSKU

      SET @nCount = 1
      SET @cLottable_Exists = ''
      WHILE @nCount <=4 --break the loop when @nCount >4
      BEGIN
         IF @nCount = 1 SET @cListName = 'Lottable01'
         IF @nCount = 2 SET @cListName = 'Lottable02'
         IF @nCount = 3 SET @cListName = 'Lottable03'
         IF @nCount = 4 SET @cListName = 'Lottable04'

         -- Check if lottable setup
         IF EXISTS (SELECT 1 
         FROM dbo.CodeLkUp C WITH (NOLOCK) 
         JOIN RDT.StorerConfig S WITH (NOLOCK)ON C.ListName = S.ConfigKey
         WHERE C.ListName = @cListName
            AND C.Code = S.SValue
            AND S.StorerKey = @cStorerKey)
         BEGIN
            SET @cLottable_Exists = 1
            BREAK            
         END
         ELSE
            SET @nCount = @nCount + 1
      END   --  @nCount <=4

         -- Lottable setup for SKU
      IF @cLottable_Exists = '1'
         GOTO Lottable
      ELSE
      BEGIN -- Lottable not setup, check over receive
         IF (@nQTY + @nSum_BeforeReceivedQty) > @nSum_QtyExpected
         BEGIN
            SET @nScn = @nScn + 2
            SET @nStep = @nStep + 2 

            SET @cOutField01 = ''

            GOTO Quit
         END
         ELSE
         BEGIN
            -- Confirm receive
            
            
            EXEC rdt.rdt_Receive    
               @nFunc         = @nFunc,
               @nMobile       = @nMobile,
               @cLangCode     = @cLangCode,
               @nErrNo        = @nErrNo OUTPUT,
               @cErrMsg       = @cErrMsg OUTPUT,
               @cStorerKey    = @cStorerKey,
               @cFacility     = @cFacility,
               @cReceiptKey   = @cReceiptKey,
               @cPOKey        = @cPoKey,
               @cToLOC        = @cLOC,
               @cToID         = @cTOID,
               @cSKUCode      = @cSKU,
               @cSKUUOM       = @cUOM,
               @nSKUQTY       = @nQTY,
               @cUCC          = '',
               @cUCCSKU       = '',
               @nUCCQTY       = '',
               @cCreateUCC    = '',
               @cLottable01   = '',
               @cLottable02   = '',   
               @cLottable03   = '',
               @dLottable04   = NULL,
               @dLottable05   = NULL,
               @nNOPOFlag     = @cPOKeyDefaultValue,
               @cConditionCode = 'OK',
               @cSubreasonCode = ''

            IF @nErrno <> 0  
            BEGIN
               SET @cErrMsg = @cErrMsg
               GOTO Step_5_Fail     
            END
            -- Increase current carton count by 1
            SET @nCtn_Cnt = @nCtn_Cnt + 1

         END   -- lottable not setuo
      END   

      --prepare next screen variable
      SET @cOutField01 = CONVERT(CHAR( 2), @nCtn_Cnt) + '/' + CONVERT(CHAR( 2), @nEst_Ctn_Cnt)
      SET @cOutField02 = '' --Label
      SET @cOutField03 = @cSKU --SKU
      SET @cOutField04 = @cStyle --Style
      SET @cOutField05 = @cColor --Color
      SET @cOutField06 = @cSize --Size
      SET @cOutField07 = @nQty --Qty
      SET @cOutField08 = @cCO --CO#
      SET @cOutField09 = CONVERT(CHAR( 5),(@nQTY + @nSum_BeforeReceivedQty)) + '/' +  CONVERT(CHAR( 5) , @nSum_QtyExpected ) -- (ChewKP01)
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- If user receive less than estimated carton ctn and received at least 1 carton
      -- then goto confirm short receive
      IF (@nEst_Ctn_Cnt > @nCtn_Cnt) AND @nCtn_Cnt > 0
      BEGIN
         -- Prepare prev screen var
         SET @cOutField01 = ''

         SET @nScn = @nScn + 3
         SET @nStep = @nStep + 3
      END
      ELSE
      BEGIN
         -- Prepare prev screen var
         SET @cOutField01 = @cReceiptkey
         SET @cOutField02 = @cPOKey
         SET @cOutField03 = @cLOC
         SET @cOutField04 = @cTOID
         SET @cOutField05 = '' -- CTN on ID

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

         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cOutField02 = '' -- Label
      SET @cLabelNo = ''
   END
   GOTO Quit

   Lottable:
   BEGIN
      --prepare next screen variable
      SET @cOutField01 = '' --lottable01
      SET @cOutField02 = '' --lottable02
      SET @cOutField03 = '' --lottable03
      SET @cOutField04 = '' --lottable04

      -- If configkey 'RetainLottableValue' turned on retail the lottable value
      IF @nRetainLottableValue = 0
      BEGIN
         SET @cLottable01 = ''
         SET @cLottable02 = ''
         SET @cLottable03 = ''
         SET @dLottable04 = 0
      END
         --initiate @nCounter = 1
      SET @nCount = 1

      --retrieve value for pre lottable01 - 04
      WHILE @nCount <=4 --break the loop when @nCount >4
      BEGIN
         IF @nCount = 1 
            SET @cListName = 'Lottable01'
         IF @nCount = 2 
            SET @cListName = 'Lottable02'
         IF @nCount = 3 
            SET @cListName = 'Lottable03'
         IF @nCount = 4 
            SET @cListName = 'Lottable04'

          --get short, store procedure and lottablelable value for each lottable
         SET @cShort = ''
         SET @cStoredProd = ''
         SET @cLottableLabel = ''
         SELECT   
            @cShort = C.Short,   
            @cStoredProd = IsNULL( C.Long, ''),   
            @cLottableLabel = S.SValue  
         FROM dbo.CodeLkUp C WITH (NOLOCK)   
         JOIN RDT.StorerConfig S WITH (NOLOCK)ON C.ListName = S.ConfigKey  
         WHERE C.ListName = @cListName  
            AND C.Code = S.SValue  
            AND S.Storerkey = @cStorerKey  

         IF @nCount = 1 
            SET @cLottable01Label = CASE WHEN ISNULL(@cLottableLabel, '') = '' THEN '' ELSE RTRIM(@cLottableLabel) + ':' END
         IF @nCount = 2 
            SET @cLottable02Label = CASE WHEN ISNULL(@cLottableLabel, '') = '' THEN '' ELSE RTRIM(@cLottableLabel) + ':' END
         IF @nCount = 3 
            SET @cLottable03Label = CASE WHEN ISNULL(@cLottableLabel, '') = '' THEN '' ELSE RTRIM(@cLottableLabel) + ':' END
         IF @nCount = 4 
            SET @cLottable04Label = CASE WHEN ISNULL(@cLottableLabel, '') = '' THEN '' ELSE RTRIM(@cLottableLabel) + ':' END

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
               @c_Sourcekey         = @cReceiptkey,  
		         @c_Sourcetype        = 'RDTCTNRCV'    

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

               SET @cOutField01 = @cLottable01
               SET @cOutField02 = @cLottable02
               SET @cOutField03 = @cLottable03
               SET @cOutField04 = CASE WHEN @dLottable04 <> 0 THEN rdt.rdtFormatDate( @dLottable04) END
            END -- 'PRE'

            SET @nCount = @nCount + 1
         END   -- while @nCount < 4

         -- Populate labels and lottables
         IF @cLottable01Label = '' OR @cLottable01Label IS NULL
         BEGIN
            SELECT @cOutField01 = 'Lottable01:'
            SELECT @cInField01 = ''
            SELECT @cFieldAttr01 = 'O' 

            SELECT @cOutField02 = ''
            SELECT @cInField02 = ''
            SELECT @cFieldAttr02 = 'O' 
         END
         ELSE
         BEGIN                  
            SELECT @cOutField01 = @cLottable01Label
            SELECT @cInField01 = ''
            SELECT @cFieldAttr01 = 'O' 
            SELECT @cOutField02 = ISNULL(LTRIM(RTRIM(@cLottable01)), '')
         END

         IF @cLottable02Label = '' OR @cLottable02Label IS NULL
         BEGIN
            SELECT @cOutField03 = 'Lottable02:'
            SELECT @cInField03 = ''
            SELECT @cFieldAttr03 = 'O' 

            SELECT @cOutField04 = ''
            SELECT @cInField04 = ''
            SELECT @cFieldAttr04 = 'O'
         END
         ELSE
         BEGIN            
            SELECT @cOutField03 = @cLottable02Label
            SELECT @cInField03 = ''
            SELECT @cFieldAttr03 = 'O' 
            SELECT @cOutField04 = ISNULL(LTRIM(RTRIM(@cLottable02)), '')
         END

         IF @cLottable03Label = '' OR @cLottable03Label IS NULL
         BEGIN
            SELECT @cOutField05 = 'Lottable03:'
            SELECT @cInField05 = ''
            SELECT @cFieldAttr05 = 'O' 

            SELECT @cOutField06 = ''
            SELECT @cInField06 = ''
            SELECT @cFieldAttr06 = 'O' 
         END
         ELSE
         BEGIN                  
            SELECT @cOutField05 = @cLottable03Label
            SELECT @cInField05 = ''
            SELECT @cFieldAttr05 = 'O' 
            SET @cOutField06 = ISNULL(LTRIM(RTRIM(@cLottable03)), '')
         END

         IF @cLottable04Label = '' OR @cLottable04Label IS NULL
         BEGIN
            SELECT @cOutField07 = 'Lottable04:'
            SELECT @cInField07 = ''
            SELECT @cFieldAttr07 = 'O' 

            SELECT @cOutField08 = ''
            SELECT @cInField08 = ''
            SELECT @cFieldAttr08 = 'O' 
         END
         ELSE
         BEGIN
            SELECT  @cOutField07 = @cLottable04Label
            SELECT @cInField07 = ''
            SELECT @cFieldAttr07 = 'O' 
            IF rdt.rdtIsValidDate( @dLottable04) = 1
            BEGIN
               SET @cOutField08 = RDT.RDTFormatDate( @dLottable04)
            END
         END
         --set cursor to first field
         EXEC rdt.rdtSetFocusField @nMobile, 1 --Lottable01

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1 

         GOTO Quit
   END   -- Lottable
END
GOTO Quit

/********************************************************************************
Step 6. (screen = 1925) Lottable1 to 5
   LotLabel01: (field01, input)
   LotLabel02: (field02, input)
   LotLabel03: (field03, input)
   LotLabel04: (field04, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1      -- ENTER
   BEGIN
      --Screen Mapping
      SET @cTempLottable01 = @cInField02     
      SET @cTempLottable02 = @cInField04     
      SET @cTempLottable03 = @cInField06     
      SET @cTempLottable04 = @cInField08     

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
         SET @nErrNo = 66199
         SET @cErrMsg = rdt.rdtgetmessage( 66199, @cLangCode, 'DSP') --Invalid Date
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- Lottable04
         SET @dLottable04 = NULL
         GOTO Lottables_Fail
      END

       --retain original value for lottable01-04
      SET @dLottable04 = CAST(@cTempLottable04 as DATETIME)
      SET @cOutField08 = CASE WHEN @dLottable04 <> 0  THEN rdt.rdtFormatDate( @dLottable04) ELSE @cTempLottable04 END

      SET @cTempLotLabel01 = @cLottable01Label
		SET @cTempLotLabel02 = @cLottable02Label
		SET @cTempLotLabel03 = @cLottable03Label
		SET @cTempLotLabel04 = @cLottable04Label

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

         SET @cShort = '' 
         SET @cStoredProd = ''
         SET @cLottableLabel = ''
         SELECT   
            @cShort = C.Short,   
            @cStoredProd = IsNULL( C.Long, ''),   
            @cLottableLabel = S.SValue  
         FROM dbo.CodeLkUp C WITH (NOLOCK)   
         JOIN RDT.StorerConfig S WITH (NOLOCK)ON C.ListName = S.ConfigKey  
         WHERE C.ListName = @cListName  
            AND C.Code = S.SValue  
            AND S.Storerkey = @cStorerKey  

         IF @cShort = 'POST' AND @cStoredProd <> ''
         BEGIN
            IF rdt.rdtIsValidDate(@cTempLottable04) = 1 --valid date
               SET @dTempLottable04 = CAST( @cTempLottable04 AS DATETIME)

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
               @c_Sourcekey         = @cReceiptKey, 
               @c_Sourcetype        = 'RDTCTNRCV'  
   				     
            IF ISNULL(@cErrMsg, '') <> ''  
            BEGIN
               SET @cErrMsg = @cErrMsg 

               --retain original value for lottable01-05
               SET @cLottable01 = @cTempLottable01
               SET @cLottable02 = @cTempLottable02
               SET @cLottable03 = @cTempLottable03
               IF rdt.rdtIsValidDate(@cTempLottable04) = 1 --valid date
               SET @dLottable04 = CAST(@cTempLottable04 as DATETIME)

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


            SET @cOutField02 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE @cTempLottable01 END
            SET @cOutField04 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE @cTempLottable02 END
            SET @cOutField06 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE @cTempLottable03 END
            SET @cOutField08 = CASE WHEN @dLottable04 <> 0  THEN rdt.rdtFormatDate( @dLottable04) ELSE @cTempLottable04 END

            SET @cLottable01 = IsNULL(@cOutField02, '')
            SET @cLottable02 = IsNULL(@cOutField04, '')
            SET @cLottable03 = IsNULL(@cOutField06, '')
            SET @dLottable04 = IsNULL(CAST(@cOutField08 AS DATETIME), 0)
         END 

         --increase counter by 1
         SET @nCount = @nCount + 1
      END -- end of while

      IF (@cTempLotLabel01 <> '' AND @cTempLottable01 <> '' AND @cLottable01 = '')
         SET @cLottable01 = @cTempLottable01

      IF (@cTempLotLabel02 <> '' AND @cTempLottable02 <> '' AND @cLottable02 = '')
         SET @cLottable02 = @cTempLottable02

      IF (@cTempLotLabel03 <> '' AND @cTempLottable03 <> '' AND @cLottable03 = '')
         SET @cLottable03 = @cTempLottable03

      IF (@cTempLotLabel04 <> '' AND @cTempLottable04 <> '' AND @dLottable04 = 0)
         SET @dLottable04 = @cTempLottable04

      --if lottable01 has been setup but no value, prompt error msg
      IF (@cTempLotLabel01 <> '' AND @cTempLottable01 = '' AND @cLottable01 = '')
      BEGIN
         SET @nErrNo = 66200
         SET @cErrMsg = rdt.rdtgetmessage(66200, @cLangCode, 'DSP') --Lottable01 Req
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Lottables_Fail   
      END

	   --if lottable02 has been setup but no value, prompt error msg
	   IF (@cTempLotLabel02 <> '' AND @cTempLottable02 = '' AND @cLottable02 = '')
	   BEGIN
         SET @nErrNo = 66201
         SET @cErrMsg = rdt.rdtgetmessage(66201, @cLangCode, 'DSP') --Lottable02 Req
         EXEC rdt.rdtSetFocusField @nMobile, 4
         GOTO Lottables_Fail 
	   END

      --if lottable03 has been setup but no value, prompt error msg
      IF (@cTempLotLabel03 <> '' AND @cTempLottable03 = '' AND @cLottable03 = '')
      BEGIN
         SET @nErrNo = 66202
         SET @cErrMsg = rdt.rdtgetmessage(66202, @cLangCode, 'DSP') --Lottable03 Req
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Lottables_Fail 
      END

      --if lottable04 has been setup but no value, prompt error msg
      IF (@cTempLotLabel04 <> '' AND @cTempLottable04 = '' AND @dLottable04 = 0) 
      BEGIN
         SET @nErrNo = 66203
         SET @cErrMsg = rdt.rdtgetmessage(66203, @cLangCode, 'DSP') --Lottable04 Req
         EXEC rdt.rdtSetFocusField @nMobile, 8
         GOTO Lottables_Fail 
      END

      -- Check if over received
      IF (@nQTY + @nSum_BeforeReceivedQty) > @nSum_QtyExpected
      BEGIN
         --prepare next screen variable
         SET @cOutField01 = ''
         
         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1 
      END
      ELSE
      BEGIN
         -- Confirm receive
         EXEC rdt.rdt_Receive    
            @nFunc         = @nFunc,
            @nMobile       = @nMobile,
            @cLangCode     = @cLangCode,
            @nErrNo        = @nErrNo OUTPUT,
            @cErrMsg       = @cErrMsg OUTPUT,
            @cStorerKey    = @cStorerKey,
            @cFacility     = @cFacility,
            @cReceiptKey   = @cReceiptKey,
            @cPOKey        = @cPoKey,
            @cToLOC        = @cLOC,
            @cToID         = @cTOID,
            @cSKUCode      = @cSKU,
            @cSKUUOM       = @cUOM,
            @nSKUQTY       = @nQTY,
            @cUCC          = '',
            @cUCCSKU       = '',
            @nUCCQTY       = '',
            @cCreateUCC    = '',
            @cLottable01   = @cLottable01,
            @cLottable02   = @cLottable02,   
            @cLottable03   = @cLottable03,
            @dLottable04   = @dLottable04,
            @dLottable05   = NULL,
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
            @nNOPOFlag     = @cPOKeyDefaultValue,
            @cConditionCode = 'OK',
            @cSubreasonCode = ''

            IF @nErrno <> 0  
            BEGIN
               SET @cErrMsg = @cErrMsg
               GOTO Lottables_Fail     
            END
            -- Increase current carton count by 1
            SET @nCtn_Cnt = @nCtn_Cnt + 1

            --prepare next screen variable
            SET @cOutField01 = CONVERT(CHAR( 2), @nCtn_Cnt) + '/' + CONVERT(CHAR( 2), @nEst_Ctn_Cnt)
            SET @cOutField02 = '' --Label
            SET @cOutField03 = @cSKU --SKU
            SET @cOutField04 = @cStyle --Style
            SET @cOutField05 = @cColor --Color
            SET @cOutField06 = @cSize --Size
            SET @cOutField07 = @nQty --Qty
            SET @cOutField08 = @cCO --CO#
            SET @cOutField09 = CONVERT(CHAR( 5),(@nQTY + @nSum_BeforeReceivedQty)) + '/' +  CONVERT(CHAR( 5) , @nSum_QtyExpected ) -- (ChewKP01)

            -- Go to next screen
            SET @nScn = @nScn - 1
            SET @nStep = @nStep - 1

            -- Flush the srceen
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
   END

   IF @nInputKey = 0 -- Esc
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = CONVERT(CHAR( 2), @nCtn_Cnt) + '/' + CONVERT(CHAR( 2), @nEst_Ctn_Cnt)
      SET @cOutField02 = '' --Label
      SET @cOutField03 = @cSKU --SKU
      SET @cOutField04 = @cStyle --Style
      SET @cOutField05 = @cColor --Color
      SET @cOutField06 = @cSize --Size
      SET @cOutField07 = @nQty --Qty
      SET @cOutField08 = @cCo --CO#

      --go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      -- Flush the srceen
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

   Step_6_Fail:
   BEGIN
      SET @cOutField01 = @cTempLottable01
      SET @cOutField03 = @cTempLottable02
      SET @cOutField05 = @cTempLottable03
      SET @cOutField07 = @cTempLottable04
   END

   Lottables_Fail:
   BEGIN
      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''

      -- Populate labels and lottables
      IF @cLottable01Label = '' OR @cLottable01Label IS NULL
      BEGIN
         SELECT @cOutField01 = 'Lottable01:'
         SELECT @cInField01 = ''
         SELECT @cFieldAttr01 = 'O' 
         SELECT @cFieldAttr02 = 'O' 
      END
      ELSE
      BEGIN                  
         SELECT @cOutField01 = @cLottable01Label
         SET @cOutField02 = ISNULL(LTRIM(RTRIM(@cLottable01)), '')
      END

      IF @cLottable02Label = '' OR @cLottable02Label IS NULL
      BEGIN
         SELECT @cOutField03 = 'Lottable02:'
         SELECT @cInField03 = ''
         SELECT @cFieldAttr03 = 'O' 
         SELECT @cFieldAttr04 = 'O' 
      END
      ELSE
      BEGIN            
         SELECT @cOutField03 = @cLottable02Label
         SET @cOutField04 = ISNULL(LTRIM(RTRIM(@cLottable02)), '')
      END
      IF @cLottable03Label = '' OR @cLottable03Label IS NULL
      BEGIN
         SELECT @cOutField05 = 'Lottable03:'
         SELECT @cInField05 = ''
         SELECT @cFieldAttr05 = 'O' 
         SELECT @cFieldAttr06 = 'O' 
      END
      ELSE
      BEGIN                  
         SELECT @cOutField05 = @cLottable03Label
         SET @cOutField06 = ISNULL(LTRIM(RTRIM(@cLottable03)), '')
      END

      IF @cLottable04Label = '' OR @cLottable04Label IS NULL
      BEGIN
         SELECT @cOutField07 = 'Lottable04:'
         SELECT @cInField07 = ''
         SELECT @cFieldAttr07 = 'O' 
         SELECT @cFieldAttr08 = 'O' 
      END
      ELSE
      BEGIN
         SELECT  @cOutField07 = @cLottable04Label
         SELECT @cInField07 = ''
         SELECT @cFieldAttr07 = 'O' 

         IF @dLottable04 <> NULL AND rdt.rdtIsValidDate( @dLottable04) = 1
         BEGIN
            SET @cOutField08 = RDT.RDTFormatDate(@dLottable04)
         END
         ELSE
         SET @cOutField08 = ''
      END
      GOTO Quit
   END
END
GOTO Quit

/********************************************************************************
Step 7. (screen = 1926) Confirm over receive
   Option: (input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1      -- ENTER
   BEGIN
      --Screen Mapping
      SET @cOption = @cInField01

      --if input is not either '1' or '2'
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 66204
         SET @cErrMsg = rdt.rdtgetmessage( 66204, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_7_Fail
      END

      IF @cOption = '1'
      BEGIN
         -- Confirm receive
         EXEC rdt.rdt_Receive    
            @nFunc         = @nFunc,
            @nMobile       = @nMobile,
            @cLangCode     = @cLangCode,
            @nErrNo        = @nErrNo OUTPUT,
            @cErrMsg       = @cErrMsg OUTPUT,
            @cStorerKey    = @cStorerKey,
            @cFacility     = @cFacility,
            @cReceiptKey   = @cReceiptKey,
            @cPOKey        = @cPoKey,
            @cToLOC        = @cLOC,
            @cToID         = @cTOID,
            @cSKUCode      = @cSKU,
            @cSKUUOM       = @cUOM,
            @nSKUQTY       = @nQTY,
            @cUCC          = '',
            @cUCCSKU       = '',
            @nUCCQTY       = '',
            @cCreateUCC    = '',
            @cLottable01   = @cLottable01,
            @cLottable02   = @cLottable02,   
            @cLottable03   = @cLottable03,
            @dLottable04   = @dLottable04,
            @dLottable05   = NULL,
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
            @nNOPOFlag     = @cPOKeyDefaultValue,
            @cConditionCode = 'OK',
            @cSubreasonCode = ''

            -- Increase current carton count by 1
            SET @nCtn_Cnt = @nCtn_Cnt + 1

            --prepare next screen variable
            SET @cOutField01 = CONVERT(CHAR( 2), @nCtn_Cnt) + '/' + CONVERT(CHAR( 2), @nEst_Ctn_Cnt)
            SET @cOutField02 = '' --Label
            SET @cOutField03 = @cSKU --SKU
            SET @cOutField04 = @cStyle --Style
            SET @cOutField05 = @cColor --Color
            SET @cOutField06 = @cSize --Size
            SET @cOutField07 = @nQty --Qty
            SET @cOutField08 = @cCO --CO#
            SET @cOutField09 = CONVERT(CHAR( 5),(@nQTY + @nSum_BeforeReceivedQty)) + '/' +  CONVERT(CHAR( 5) , @nSum_QtyExpected ) -- (ChewKP01)

            -- Go to next screen
            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2 
      END

      IF @cOption = '2'
      BEGIN
         --prepare next screen variable
         SET @cOutField01 = CONVERT(CHAR( 2), @nCtn_Cnt) + '/' + CONVERT(CHAR( 2), @nEst_Ctn_Cnt)
         SET @cOutField02 = '' --Label
         SET @cOutField03 = @cSKU --SKU
         SET @cOutField04 = @cStyle --Style
         SET @cOutField05 = @cColor --Color
         SET @cOutField06 = @cSize --Size
         SET @cOutField07 = @nQty --Qty
         SET @cOutField08 = @cCO --CO#
         SET @cOutField09 = CONVERT(CHAR( 5),(@nSum_BeforeReceivedQty)) + '/' +  CONVERT(CHAR( 5) , @nSum_QtyExpected ) -- (ChewKP01)

         -- Go to next screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2 
      END
   END

   IF @nInputKey = 0 -- Esc
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = CONVERT(CHAR( 2), @nCtn_Cnt) + '/' + CONVERT(CHAR( 2), @nEst_Ctn_Cnt)
      SET @cOutField02 = '' --Label
      SET @cOutField03 = '' --SKU
      SET @cOutField04 = '' --Style
      SET @cOutField05 = '' --Color
      SET @cOutField06 = '' --Size
      SET @cOutField07 = '' --Qty
      SET @cOutField08 = '' --CO#
      SET @cOutField09 = CONVERT(CHAR( 5),(@nSum_BeforeReceivedQty)) + '/' +  CONVERT(CHAR( 5) , @nSum_QtyExpected ) -- (ChewKP01)

      --go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_7_Fail:
   BEGIN
      SET @cOutField01 = @cTempLottable01
      SET @cOutField02 = @cTempLottable02
      SET @cOutField03 = @cTempLottable03
      SET @cOutField04 = @cTempLottable04
   END
END
GOTO Quit

/********************************************************************************
Step 8. (screen = 1927) Confirm short receive
   Option: (input)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1      -- ENTER
   BEGIN
      --Screen Mapping
      SET @cOption = @cInField01

      --if input is not either '1' or '2'
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 66205
         SET @cErrMsg = rdt.rdtgetmessage( 66205, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_8_Fail
      END

      IF @cOption = '1'
      BEGIN
         -- Prepare prev screen var
         SET @cOutField01 = @cReceiptkey
         SET @cOutField02 = @cPOKey
         SET @cOutField03 = @cLOC
         SET @cOutField04 = @cTOID
         SET @cOutField05 = '' -- CTN on ID

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

         -- Go to next screen
         SET @nScn = @nScn - 4
         SET @nStep = @nStep - 4
      END

      IF @cOption = '2'
      BEGIN
         --prepare next screen variable
         SET @cOutField01 = CONVERT(CHAR( 2), @nCtn_Cnt) + '/' + CONVERT(CHAR( 2), @nEst_Ctn_Cnt)
         SET @cOutField02 = '' --Label
         SET @cOutField03 = @cSKU --SKU
         SET @cOutField04 = @cStyle --Style
         SET @cOutField05 = @cColor --Color
         SET @cOutField06 = @cSize --Size
         SET @cOutField07 = @nQty --Qty
         SET @cOutField08 = @cCO --CO#
         SET @cOutField09 = CONVERT(CHAR( 5),(@nQTY + @nSum_BeforeReceivedQty)) + '/' +  CONVERT(CHAR( 5) , @nSum_QtyExpected ) -- (ChewKP01)

         -- Go to next screen
         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3 
      END
   END

   IF @nInputKey = 0 -- Esc
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = CONVERT(CHAR( 2), @nCtn_Cnt) + '/' + CONVERT(CHAR( 2), @nEst_Ctn_Cnt)
      SET @cOutField02 = '' --Label
      SET @cOutField03 = '' --SKU
      SET @cOutField04 = '' --Style
      SET @cOutField05 = '' --Color
      SET @cOutField06 = '' --Size
      SET @cOutField07 = '' --Qty
      SET @cOutField08 = '' --CO#
      SET @cOutField09 = CONVERT(CHAR( 5),(@nQTY + @nSum_BeforeReceivedQty)) + '/' +  CONVERT(CHAR( 5) , @nSum_QtyExpected ) -- (ChewKP01)

      --go to previous screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END
   GOTO Quit

   Step_8_Fail:
   BEGIN
      SET @cOutField01 = @cTempLottable01
      SET @cOutField02 = @cTempLottable02
      SET @cOutField03 = @cTempLottable03
      SET @cOutField04 = @cTempLottable04
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
       Func = @nFunc,
       Step = @nStep,
       Scn = @nScn,

       StorerKey    = @cStorerKey,
       Facility     = @cFacility,
       -- UserName     = @cUserName,
       Printer      = @cPrinter,

       V_Receiptkey = @cReceiptkey,
       V_POKey = @cPOKey,
       V_LOC = @cLOC,
       V_ID  = @cTOID,
       V_SKU = @cSKU,
       V_UOM = @cUOM,
       V_QTY = @nQTY,

       V_Lottable01 = @cLottable01,
       V_Lottable02 = @cLottable02,
       V_Lottable03 = @cLottable03,
       V_Lottable04 = @dLottable04,

       V_String1  = @cPOKeyDefaultValue,
       V_String2  = @nEst_Ctn_Cnt,
       V_String3  = @nCtn_Cnt,
       V_String4  = @cLottable01Label,
       V_String5  = @cLottable02Label,
       V_String6  = @cLottable03Label,
       V_String7  = @cLottable04Label,
       V_String8  = @cDecodeLabelNo,
       V_String9  = @cReceiveDefaultToLoc,
       V_String10 = @nRetainLottableValue,
       V_String11 = @nDisAllowDuplicateIdsOnRFRcpt,
       V_String12 = @cStyle,
       V_String13 = @cColor,
       V_String14 = @cSize,
       V_String15 = @cCO,
       V_String16 = @nSum_QtyExpected,        -- (ChewKP01)
       V_String17 = @nSum_BeforeReceivedQty,  -- (ChewKP01)


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