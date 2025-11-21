SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/****************************************************************************/
/* Store procedure: rdtfnc_ASN_UCC_Outstanding_Qty_Inquiry                  */
/* Copyright      : IDS                                                     */
/*                                                                          */
/* Purpose: ASN Inquiry                                                     */
/*                                                                          */
/* Modifications log:                                                       */
/*                                                                          */
/* Date       Rev  Author   Purposes                                        */
/* 2008-10-06 1.0  Vanessa  Created                                         */
/* 2008-11-17 1.0  Vanessa  Avoid display first sku @cQty=@cQtyExpected,    */
/*                          Add on DEALLOCATE CUR_RECEIPTDETAIL and         */
/*                          Convert all QTY variables to CHAR --(Vanessa01) */
/* 2016-09-30 1.2  Ung      Performance tuning                              */
/* 2018-10-10 1.3  TungGH   Performance                                     */
/****************************************************************************/
CREATE PROC [RDT].[rdtfnc_ASN_UCC_Outstanding_Qty_Inquiry](
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
   @b_success           INT,
   @cUOM                NVARCHAR(10),
   @nSKUCnt             INT,
   @cPackUOM            NVARCHAR(10)
  
-- Define a variable
DECLARE  
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cReceiptKey         NVARCHAR(10),
   @cSKU                NVARCHAR(20),
   @cDesc               NVARCHAR(60),
   @cTTLQty             NVARCHAR(5),
   @cTTLQtyExpected     NVARCHAR(5),
   @cQty                NVARCHAR(5),
   @cQtyExpected        NVARCHAR(5),

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
            
-- Getting Mobile information
SELECT 
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @cLangCode        = Lang_code,
   @nMenu            = Menu,

   @cFacility        = Facility,
   @cStorerKey       = StorerKey,

   @cReceiptKey      = V_ReceiptKey,
   @cSKU             = V_SKU, 
   @cUOM             = V_UOM, 
   @cDesc            = V_SkuDescr,  
   @cTTLQty          = V_String1,
   @cTTLQtyExpected  = V_String2,     
   @cQty             = V_String3,
   @cQtyExpected     = V_String4,
   @cPackUOM         = V_String5,

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

FROM   RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1630 -- ASN Inquiry
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1630
   IF @nStep = 1 GOTO Step_1   -- Scn = 1900   ASN
   IF @nStep = 2 GOTO Step_2   -- Scn = 1901   ASN, TTL SCN Qty, TTL EXP Qty...
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1900)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 1900
   SET @nStep = 1

   -- Init var
   SET @nSKUCnt = 0

   -- initialise all variable
   SET @cReceiptKey = ''

   -- Prep next screen var   
   SET @cOutField01 = ''  -- Receiptkey
   SET @cOutField02 = ''  -- UOM
   SET @cOutField03 = ''  -- TTLQty
   SET @cOutField04 = ''  -- TTLQtyExpected
   SET @cOutField05 = ''  -- SKU
   SET @cOutField06 = ''  -- SKU Desc
   SET @cOutField07 = ''  -- PackUOM
   SET @cOutField08 = ''  -- Qty
   SET @cOutField09 = ''  -- QtyExpected
END
GOTO Quit

/********************************************************************************
Step 1. screen = 1900
   ASN (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cReceiptKey = @cInField01

      --When ASN is blank
      IF @cReceiptKey = ''
      BEGIN
         SET @nErrNo = 66001
         SET @cErrMsg = rdt.rdtgetmessage( 66001, @cLangCode, 'DSP') --ASN needed
         GOTO Step_1_Fail  
      END 

      --check diff facility
      IF NOT EXISTS ( SELECT 1 
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND Facility = @cFacility)
      BEGIN
         SET @nErrNo = 66002
         SET @cErrMsg = rdt.rdtgetmessage( 66002, @cLangCode, 'DSP') --Diff facility
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail    
      END

      --check diff storer
      IF NOT EXISTS ( SELECT 1 
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND Storerkey = @cStorerkey)
      BEGIN
         SET @nErrNo = 66003
         SET @cErrMsg = rdt.rdtgetmessage( 66003, @cLangCode, 'DSP') --Diff storer
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail    
      END

      --check for ASN cancelled
      IF EXISTS ( SELECT 1 
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND ASNStatus = 'CANC')
      BEGIN
         SET @nErrNo = 66004
         SET @cErrMsg = rdt.rdtgetmessage( 66004, @cLangCode, 'DSP') --ASN cancelled
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail    
      END

      --check if receiptkey exists
      IF NOT EXISTS (SELECT 1 
         FROM dbo.Receipt WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptkey)
      BEGIN
         SET @nErrNo = 66005
         SET @cErrMsg = rdt.rdtgetmessage( 66005, @cLangCode, 'DSP') --ASN not exists
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail  
      END
      ELSE
      BEGIN
         SELECT @cSKU = MIN(SKU), 
                @cTTLQtyExpected = RTRIM(CAST(ISNULL(SUM(QtyExpected),0) AS CHAR)) --(Vanessa01)
         FROM dbo.RECEIPTDETAIL (NOLOCK) 
         WHERE StorerKey = @cStorerkey
         AND RECEIPTKEY = @cReceiptkey

         SELECT @cTTLQty = RTRIM(CAST(ISNULL(SUM(Qty),0) AS CHAR)) --(Vanessa01)
         FROM dbo.UCC (NOLOCK) 
         WHERE StorerKey = @cStorerkey
         AND RECEIPTKEY = @cReceiptkey

         SELECT @cUOM = PACK.PackUOM3 
         FROM dbo.PACK PACK (NOLOCK) 
         JOIN dbo.SKU SKU (NOLOCK) ON (SKU.PACKKEY = PACK.PACKKEY)
         WHERE SKU.SKU = @cSKU
         AND SKU.StorerKey = @cStorerkey

         IF CAST(@cTTLQtyExpected AS INT) <> CAST(@cTTLQty AS INT) 
         BEGIN
            -- (Vanessa01) Avoid display first sku @cQty=@cQtyExpected
            DECLARE CUR_RECEIPTDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
               SELECT SKU, RTRIM(CAST(ISNULL(SUM(QtyExpected),0) AS CHAR)) --(Vanessa01)
               FROM dbo.RECEIPTDETAIL (NOLOCK) 
               WHERE StorerKey = @cStorerkey
               AND RECEIPTKEY = @cReceiptkey
               AND SKU >= @cSKU
               GROUP BY SKU
               ORDER BY SKU

            OPEN CUR_RECEIPTDETAIL
            FETCH NEXT FROM CUR_RECEIPTDETAIL INTO @cSKU, @cQtyExpected
            WHILE @@FETCH_STATUS = 0
            BEGIN
               SELECT @cQty = RTRIM(CAST(ISNULL(SUM(Qty),0) AS CHAR))  --(Vanessa01)
               FROM dbo.UCC (NOLOCK) 
               WHERE StorerKey = @cStorerkey
               AND RECEIPTKEY = @cReceiptkey
               AND SKU = @cSKU

               SELECT @cPackUOM = PACK.PackUOM3, 
                      @cDesc = SKU.Descr 
               FROM dbo.PACK PACK (NOLOCK) 
               JOIN dbo.SKU SKU (NOLOCK) ON (SKU.PACKKEY = PACK.PACKKEY)
               WHERE SKU.SKU = @cSKU
               AND SKU.StorerKey = @cStorerkey
               
               IF CAST(@cQtyExpected AS INT) <> CAST(@cQty AS INT) 
               BEGIN
                  CLOSE CUR_RECEIPTDETAIL
                  DEALLOCATE CUR_RECEIPTDETAIL                    
                  GOTO Step_1_Next
               END
               ELSE
               BEGIN
                  FETCH NEXT FROM CUR_RECEIPTDETAIL INTO @cSKU, @cQtyExpected
               END
            END
            CLOSE CUR_RECEIPTDETAIL       
            DEALLOCATE CUR_RECEIPTDETAIL   
            -- (Vanessa01)        
         END
         ELSE
         BEGIN
            SELECT @cSKU = ''
         END
      END
 
Step_1_Next:  -- (Vanessa01) 
      --prepare next screen variable
      SET @cOutField01 = @cReceiptkey
      SET @cOutField02 = @cUOM
      SET @cOutField03 = @cTTLQty
      SET @cOutField04 = @cTTLQtyExpected
      SET @cOutField05 = @cSKU
      SET @cOutField06 = @cDesc
      SET @cOutField07 = @cPackUOM
      SET @cOutField08 = @cQty
      SET @cOutField09 = @cQtyExpected
                  
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
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cReceiptkey = ''

      -- Reset this screen var
      SET @cOutField01 = ''  -- Receiptkey
      SET @cOutField02 = ''  -- UOM
      SET @cOutField03 = ''  -- TTLQty
      SET @cOutField04 = ''  -- TTLQtyExpected
      SET @cOutField05 = ''  -- SKU
      SET @cOutField06 = ''  -- SKU Desc
      SET @cOutField07 = ''  -- PackUOM
      SET @cOutField08 = ''  -- Qty
      SET @cOutField09 = ''  -- QtyExpected
   END
END
GOTO Quit


/********************************************************************************
Step 2. (screen = 1901) ASN, TTL SCN Qty, TTL EXP Qty...
   ASN:         
                (Field01)  -- ASN
                (Field02)  -- UOM
   TTL SCN QTY: (Field03)
   TTL EXP QTY: (Field04)
   SKU:         
                (Field05)  -- SKU 
                (Field06)  -- SKU Descr
                (Field07)  -- UOM
   SCN QTY:     (Field08)  
   EXP QTY:     (Field09)              

   ENTER =  Next Page
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN

      --prepare next screen variable
      SET @cOutField01 = @cReceiptkey
      SET @cOutField02 = @cUOM
      SET @cOutField03 = @cTTLQty
      SET @cOutField04 = @cTTLQtyExpected
      SET @cOutField05 = @cSKU
      SET @cOutField06 = @cDesc
      SET @cOutField07 = @cPackUOM
      SET @cOutField08 = @cQty
      SET @cOutField09 = @cQtyExpected

      DECLARE CUR_RECEIPTDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT SKU, RTRIM(CAST(ISNULL(SUM(QtyExpected),0) AS CHAR)) --(Vanessa01)
         FROM dbo.RECEIPTDETAIL (NOLOCK) 
         WHERE StorerKey = @cStorerkey
         AND RECEIPTKEY = @cReceiptkey
         AND SKU > @cSKU
         GROUP BY SKU
         ORDER BY SKU

      OPEN CUR_RECEIPTDETAIL
      FETCH NEXT FROM CUR_RECEIPTDETAIL INTO @cSKU, @cQtyExpected
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SELECT @cQty = RTRIM(CAST(ISNULL(SUM(Qty),0) AS CHAR))  --(Vanessa01)
         FROM dbo.UCC (NOLOCK) 
         WHERE StorerKey = @cStorerkey
         AND RECEIPTKEY = @cReceiptkey
         AND SKU = @cSKU

         SELECT @cPackUOM = PACK.PackUOM3, 
                @cDesc = SKU.Descr 
         FROM dbo.PACK PACK (NOLOCK) 
         JOIN dbo.SKU SKU (NOLOCK) ON (SKU.PACKKEY = PACK.PACKKEY)
         WHERE SKU.SKU = @cSKU
         AND SKU.StorerKey = @cStorerkey
         
         IF CAST(@cQtyExpected AS INT) <> CAST(@cQty AS INT) 
         BEGIN
            CLOSE CUR_RECEIPTDETAIL
            DEALLOCATE CUR_RECEIPTDETAIL                    
            GOTO Step_2_Next
         END
         ELSE
         BEGIN
            FETCH NEXT FROM CUR_RECEIPTDETAIL INTO @cSKU, @cQtyExpected
         END
      END
      CLOSE CUR_RECEIPTDETAIL       --(Vanessa01)
      DEALLOCATE CUR_RECEIPTDETAIL  --(Vanessa01) 

      -- Check if no next record found
      IF @@FETCH_STATUS = -1
      BEGIN
         SET @nErrNo = 66006
         SET @cErrMsg = rdt.rdtgetmessage( 66006, @cLangCode, 'DSP') --No next record
         GOTO Step_2_Fail  
      END

      Step_2_Next:
      BEGIN
         --prepare next screen variable
         SET @cOutField01 = @cReceiptkey
         SET @cOutField02 = @cUOM
         SET @cOutField03 = @cTTLQty
         SET @cOutField04 = @cTTLQtyExpected
         SET @cOutField05 = @cSKU
         SET @cOutField06 = @cDesc
         SET @cOutField07 = @cPackUOM
         SET @cOutField08 = @cQty
         SET @cOutField09 = @cQtyExpected
      END              
 
      -- Get next sku
      SET @nScn = @nScn 
      SET @nStep = @nStep 
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = '' -- ReceiptKey
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cDesc = ''
      SET @cPackUOM = ''
      SET @cQty = ''
      SET @cQtyExpected = ''
      SET @cOutField05 = ''  -- SKU
      SET @cOutField06 = ''  -- SKU Desc
      SET @cOutField07 = ''  -- PackUOM
      SET @cOutField08 = ''  -- Qty
      SET @cOutField09 = ''  -- QtyExpected
   END   
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
       EditDate      = GETDATE(), 
       ErrMsg        = @cErrMsg, 
       Func          = @nFunc,
       Step          = @nStep,            
       Scn           = @nScn,
       V_Receiptkey  = @cReceiptkey,
       V_SKU         = @cSKU,  
       V_UOM         = @cUOM,
       V_SkuDescr    = @cDesc,
       V_String1     = @cTTLQty,
       V_String2     = @cTTLQtyExpected,
       V_String3     = @cQty,
       V_String4     = @cQtyExpected,   
       V_String5     = @cPackUOM,   

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