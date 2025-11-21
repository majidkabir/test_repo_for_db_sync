SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_CPVReturn                                    */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Return, inner QTY                                           */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 14-Sep-2018 1.0  Ung        WMS-6632 Created                         */
/* 07-Mar-2019 1.1  ChewKP     Changes                                  */
/* 11-Mar-2019 1.2  ChewKP     Changes                                  */
/* 08-Apr-2019 1.3  Ung        WMS-6632 Change expiry checking          */
/* 25-Apr-2019 1.4  CheWKP     WMS-6632 Fixes (ChewKP01)                */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_CPVReturn] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc var
DECLARE
   @bSuccess         INT,
   @nRowCount        INT,
   @cOption          NVARCHAR(1),
   @cChkFacility     NVARCHAR( 5),
   @cExternLotStatus NVARCHAR(10),
   @dExpiryDate      DATETIME,
   @nShelfLife       INT,
   @cShelfLife       NVARCHAR( 10),
   @nInnerPack       INT

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @cUserName   NVARCHAR( 10),
   @nInputKey   INT,
   @nMenu       INT,

   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),

   @cReceiptKey       NVARCHAR( 10),
   @cToLOC            NVARCHAR( 10),
   @cSKU              NVARCHAR( 20),
   @cDesc             NVARCHAR( 60),
   @dExternLottable04 DATETIME,
   @cLottable07       NVARCHAR( 30),
   @cLottable08       NVARCHAR( 30),

   @cExternReceiptKey NVARCHAR( 20),
   @cMasterLOT        NVARCHAR( 60),

   @nScan             INT,
   @nSKUQTY           INT,

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

-- Load RDT.RDTMobRec
SELECT
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @nMenu       = Menu,
   @cLangCode   = Lang_code,
   @cUserName   = UserName,

   @cStorerKey  = StorerKey,
   @cFacility   = Facility,

   @cReceiptKey       = V_ReceiptKey,
   @cToLOC            = V_LOC,
   @cSKU              = V_SKU,
   @cDesc             = V_SKUDescr,
   @dExternLottable04 = V_Lottable04,
   @cLottable07       = V_Lottable07,
   @cLottable08       = V_Lottable08,

   @cExternReceiptKey = V_String1,
   @cMasterLOT        = V_String41,

   @nScan             = V_Integer1,
   @nSKUQTY           = V_Integer2,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01 = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15

FROM rdt.RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 630 -- Serial no capture by Receipt SKU
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = 630
   IF @nStep = 1 GOTO Step_1   -- 5250 ASN
   IF @nStep = 2 GOTO Step_2   -- 5251 TO LOC
   IF @nStep = 3 GOTO Step_3   -- 5252 LOT
   IF @nStep = 4 GOTO Step_4   -- 5253 Multi SKU selection
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 630. Menu
********************************************************************************/
Step_0:
BEGIN
   SET @nScan = 0

   -- Prepare next screen var
   SET @cOutField01 = '' -- @cReceiptKey
   SET @cOutField02 = '' -- @cExternReceiptKey

   -- Set the entry point
   SET @nScn = 5250
   SET @nStep = 1

   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 5250. ASN
   ASN      (Field01, input)
   EXT ASN  (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cReceiptKey = @cInField01
      SET @cExternReceiptKey = @cInField02

      -- Check blank
      IF @cReceiptKey = '' AND @cExternReceiptKey = ''
      BEGIN
         SET @nErrNo = 130201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ASN / EXT
         GOTO Quit
      END

      -- Check both key-in
      IF @cReceiptKey <> '' AND @cExternReceiptKey <> ''
      BEGIN
         SET @nErrNo = 130202
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN or EXT ASN
         GOTO Quit
      END

      DECLARE @cChkStorerKey  NVARCHAR(15)
      DECLARE @cStatus        NVARCHAR(10)
      DECLARE @cASNStatus     NVARCHAR(10)

      IF @cReceiptKey <> ''
         -- Get Receipt info
         SELECT
            @cChkFacility = Facility,
            @cChkStorerKey = StorerKey,
            @cStatus = Status,
            @cASNStatus = ASNStatus
         FROM Receipt WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
      ELSE
         SELECT
            @cChkFacility = Facility,
            @cChkStorerKey = StorerKey,
            @cStatus = Status,
            @cASNStatus = ASNStatus
         FROM Receipt WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND ExternReceiptKey = @cExternReceiptKey

      -- Check Receipt valid
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 130203
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ASN
         GOTO Step1_Fail
      END

      -- Check diff storer
      IF @cChkStorerKey <> @cStorerKey
      BEGIN
         SET @nErrNo = 130204
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
         GOTO Step1_Fail
      END

      -- Check diff facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 130205
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         GOTO Step1_Fail
      END

      -- Check status
      IF @cStatus = '9' OR @cASNStatus = '9'
      BEGIN
         SET @nErrNo = 130206
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN closed
         GOTO Step1_Fail
      END

      -- Prep next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cExternReceiptKey
      SET @cOutField03 = 'CPV-STAGE' -- TO LOC

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     -- EventLog
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign-out
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option
   END
   GOTO Quit

   Step1_Fail:
   BEGIN
      IF @cExternReceiptKey <> ''
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- ExternReceipt
         SET @cOutField02 = ''
      END
      ELSE
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Receipt
         SET @cOutField01 = ''
      END
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen = 5251. TO LOC
   ASN      (Field01)
   EXT ASN  (Field02)
   TO LOC   (Field03, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToLOC = @cInField03 -- LOC

      -- Check blank
      IF @cToLOC = ''
      BEGIN
         SET @nErrNo = 130207
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOC
         GOTO Quit
      END

      -- Get LOC info
      SET @cChkFacility = ''
      SELECT @cChkFacility = Facility
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cToLOC

      -- Check LOC valid
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 130208
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         SET @cOutField03 = ''
         GOTO Quit
      END

      -- Check facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 130209
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         SET @cOutField03 = ''
         GOTO Quit
      END

      SELECT @nScan = Count(ReceiptLineNumber)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ReceiptKey = @cReceiptKey

      -- Prepare next screen var
      SET @cOutField01 = '' -- LOT
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = '' -- Desc1
      SET @cOutField04 = '' -- Desc2
      SET @cOutField05 = '' -- Desc3
      SET @cOutField06 = '' -- SKU QTY
      SET @cOutField07 = CAST (ISNULL(@nScan,0 ) AS NVARCHAR(5)) -- Scan

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- ReceiptKey
      SET @cOutField02 = '' -- ExternReceiptKey
      SET @cOutField03 = '' -- TOLOC

      IF @cExternReceiptKey <> ''
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- ExternReceipt
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Step 3. Screen = 5252. LOT
   LOT         (Field01, input)
   SKU         (Field02)
   DESC1       (Field03)
   DESC2       (Field04)
   QTY         (Field05)
   SCAN        (Field06)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cBarcode NVARCHAR( 60)

      -- Screen mapping
      SET @cBarcode = @cInField01

      -- Check blank
      IF @cBarcode = ''
      BEGIN
         SET @nErrNo = 130210
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOT
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- In future MasterLOT could > 30 chars, need to use 2 lottables field
      SET @cLottable07 = ''
      SET @cLottable08 = ''

      -- Decode to abstract master LOT
      EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
         @cLottable07 = @cLottable07 OUTPUT,
         @cLottable08 = @cLottable08 OUTPUT,
         @nErrNo  = @nErrNo  OUTPUT,
         @cErrMsg = @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Check barcode format
      IF @cLottable07 = '' AND @cLottable08 = ''
      BEGIN
         SET @nErrNo = 130211
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format
         SET @cOutField01 = ''
         GOTO Quit
      END

      SELECT @cMasterLOT = @cLottable07 + @cLottable08

      -- Get master LOT info
      SELECT
         @cSKU = SKU,
         @cExternLotStatus = ExternLotStatus,
         @dExternLottable04 = ExternLottable04
      FROM ExternLotAttribute WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ExternLOT = @cMasterLOT

      SET @nRowCount = @@ROWCOUNT

      -- Check master LOT valid
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 130212
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOT
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check multi SKU extern LOT
      IF @nRowCount > 1
      BEGIN
         EXEC rdt.rdt_CPVMultiSKUExtLOT @nMobile, @nFunc, @cLangCode,
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
            @cMasterLOT,
            @cStorerKey OUTPUT,
            @cSKU       OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT

         IF @nErrNo = 0 -- Populate multi SKU screen
         BEGIN
            -- Go to Multi SKU screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
            GOTO Quit
         END
      END

      -- Check master LOT status      
      IF @cExternLotStatus NOT IN ( 'ACTIVE' , 'BLOCKED' )  -- (ChewKP01) 
      BEGIN
         SET @nErrNo = 130213
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inactive LOT
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Get SKU info
      SELECT
         @cDesc = SKU.Descr,
         @cShelfLife = SKU.SUSR1,
         @nInnerPack = Pack.InnerPack
      FROM SKU WITH (NOLOCK)
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

      -- Calc expiry date
      IF @cShelfLife <> '' AND @cShelfLife IS NOT NULL
      BEGIN
         DECLARE @dToday DATETIME
         SET @dToday = CONVERT( DATE, GETDATE())
         SET @nShelfLife = @cShelfLife
         SET @dExpiryDate = @dExternLottable04
         -- IF @nShelfLife > 0
            SET @dExpiryDate = DATEADD( dd, -@nShelfLife, @dExternLottable04)

         -- Check expired stock
         IF @dExpiryDate < @dToday
         BEGIN
            SET @nErrNo = 130214
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Stock expired
            SET @cOutField01 = ''
            GOTO Quit
         END
      END

      -- Confirm
      EXEC rdt.rdt_CPVReturn_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
         @cReceiptKey = @cReceiptKey,
         @cToLOC      = @cToLOC,
         @cSKU        = @cSKU,
         @dLottable04 = @dExternLottable04,
         @cLottable07 = @cLottable07,
         @cLottable08 = @cLottable08,
         @nErrNo      = @nErrNo     OUTPUT,
         @cErrMsg     = @cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Get stat
      SELECT @nSKUQTY = ISNULL( SUM( BeforeReceivedQTY), 0)
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU

      SET @nScan = @nScan + 1
      IF @nInnerPack > 0
         SET @nSKUQTY = @nSKUQTY / @nInnerPack

      -- Prepare current screen var
      SET @cOutField01 = '' -- LOT
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cDesc, 1, 20)
      SET @cOutField04 = SUBSTRING( @cDesc, 21, 20)
      SET @cOutField05 = SUBSTRING( @cDesc, 41, 20)
      SET @cOutField06 = CAST( @nSKUQTY AS NVARCHAR(10))
      SET @cOutField07 = CAST( @nScan AS NVARCHAR(10))
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cExternReceiptKey
      SET @cOutField03 = '' -- TOLOC

      -- Go back TO LOC screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
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
      EXEC rdt.rdt_CPVMultiSKUExtLOT @nMobile, @nFunc, @cLangCode,
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
         @cMasterLOT,
         @cStorerKey OUTPUT,
         @cSKU       OUTPUT,
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
      END

      -- Get master LOT info
      SELECT TOP 1
         @cExternLotStatus = ExternLotStatus,
         @dExternLottable04 = ExternLottable04
      FROM ExternLotAttribute WITH (NOLOCK)
      WHERE ExternLOT = @cMasterLOT
         AND StorerKey = @cStorerKey
         AND @cSKU = SKU

      -- Check master LOT status
      IF @cExternLotStatus NOT IN ( 'ACTIVE' , 'BLOCKED' )  -- (ChewKP01) 
      BEGIN
         SET @nErrNo = 130215
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inactive LOT
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Get SKU info
      SELECT
         @cDesc = SKU.Descr,
         @cShelfLife = SKU.SUSR1,
         @nInnerPack = Pack.InnerPack
      FROM SKU WITH (NOLOCK)
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSKU

      -- Calc expiry date
      IF @cShelfLife <> '' AND @cShelfLife IS NOT NULL
      BEGIN
         SET @dExpiryDate = CONVERT( DATE, GETDATE()) -- Today
         SET @nShelfLife = @cShelfLife
         -- IF @nShelfLife > 0
            SET @dExpiryDate = DATEADD( dd, CAST( @nShelfLife AS INT), @dExpiryDate)

         -- Check expired stock
         IF @dExpiryDate > @dExternLottable04
         BEGIN
            SET @nErrNo = 130216
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Stock expired
            SET @cOutField01 = ''
            GOTO Quit
         END
      END
      
      -- Confirm
      EXEC rdt.rdt_CPVReturn_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
         @cReceiptKey = @cReceiptKey,
         @cToLOC      = @cToLOC,
         @cSKU        = @cSKU,
         @dLottable04 = @dExpiryDate,
         @cLottable07 = @cLottable07,
         @cLottable08 = @cLottable08,
         @nErrNo      = @nErrNo     OUTPUT,
         @cErrMsg     = @cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Get stat
      SELECT @nSKUQTY = ISNULL( SUM( BeforeReceivedQTY), 0)
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU

      SET @nScan = @nScan + 1
      IF @nInnerPack > 0
         SET @nSKUQTY = @nSKUQTY / @nInnerPack
   END

   -- Init next screen var
   SET @cOutField01 = '' -- LOT
   SET @cOutField02 = @cSKU
   SET @cOutField03 = SUBSTRING( @cDesc,  1, 20) -- SKUDesc1
   SET @cOutField04 = SUBSTRING( @cDesc, 21, 20) -- SKUDesc2
   SET @cOutField05 = SUBSTRING( @cDesc, 41, 20)
   SET @cOutField06 = CAST( @nSKUQTY AS NVARCHAR(10))
   SET @cOutField07 = CAST( @nScan AS NVARCHAR(10))

   -- Go to SKU screen
   SET @nScn = @nScn - 1
   SET @nStep = @nStep - 1

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

      StorerKey = @cStorerKey,
      Facility  = @cFacility,

      V_ReceiptKey = @cReceiptKey,
      V_LOC        = @cToLOC,
      V_SKU        = @cSKU,
      V_SKUDescr   = @cDesc,
      V_Lottable04 = @dExternLottable04,
      V_Lottable07 = @cLottable07,
      V_Lottable08 = @cLottable08,

      V_String1    = @cExternReceiptKey,
      V_String41   = @cMasterLOT,

      V_Integer1   = @nScan,
      V_Integer2   = @nSKUQTY,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile
END

GO