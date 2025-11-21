SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: UCC Swap                                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2012-09-07 1.0  Ung      SOS255352. Created                          */
/* 2014-04-07 1.1  Ung      SOS308790. Add CrossDock ASN                */
/* 2014-06-02 1.2  Ung      SOS313440. Add Random check                 */
/* 2015-05-20 1.3  SPChin   SOS342022 - Bug Fixed                       */
/* 2016-09-30 1.4  Ung      Performance tuning                          */   
/* 2018-10-03 1.5  Gan      Performance tuning                          */
/************************************************************************/

CREATE  PROCEDURE [RDT].[rdtfnc_UCC_Swap] (
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
   @i             INT,
   @nRowCount     INT,
   @nQTY          INT,
   @cLOC          NVARCHAR(10),
   @cSwapped      NVARCHAR(5),
   @cTotal        NVARCHAR(5),
   @nTotalRec     INT,
   @nCurrentRec   INT

-- RDT.RDTMobRec variable
DECLARE
   @nFunc         INT,
   @nScn          INT,
   @nStep         INT,
   @cLangCode     NVARCHAR( 3),
   @nInputKey     INT,
   @nMenu         INT,

   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cUserName     NVARCHAR(18),

   @cReceiptKey   NVARCHAR( 10),
   @cSKU          NVARCHAR( 20),
   @cSKUDescr     NVARCHAR( 60),

   @cOldUCC       NVARCHAR( 20),
   @cNewUCC       NVARCHAR( 20),
   @cDocType      NVARCHAR( 10),

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
   @cUserName  = UserName,

   @cReceiptKey = V_ReceiptKey,
   @cSKU       = V_SKU,
   @cSKUDescr  = V_SKUDescr,

   @cOldUCC    = V_String1,
   @cNewUCC    = V_String2,
   @cDocType   = V_String3,

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

IF @nFunc = 527 -- UCC Swap
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = UCC Swap
   IF @nStep = 1 GOTO Step_1   -- Scn = 3170. ASN, Lane
   IF @nStep = 2 GOTO Step_2   -- Scn = 3171. Old UCC
   IF @nStep = 3 GOTO Step_3   -- Scn = 3172. New UCC
   IF @nStep = 4 GOTO Step_4   -- Scn = 3173. Message
   IF @nStep = 5 GOTO Step_5   -- Scn = 3174. SKU
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 527. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 3170
   SET @nStep = 1

   -- Prep next screen var
   SET @cReceiptKey = ''
   SET @cOldUCC = ''
   SET @cNewUCC = ''
   SET @cSKU = ''
   SET @cSKUDescr = ''

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- Init screen
   SET @cOutField01 = '' -- ASN
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3170. ASN
   ASN      (field01, input)
   NEW UCC  (field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cReceiptKey = @cInField01
      SET @cNewUCC = @cInField02

      -- Check blank
      IF @cReceiptKey = '' AND @cNewUCC = ''
      BEGIN
         SET @nErrNo = 76851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Need ASN/UCC
         GOTO Quit
      END

      -- Check both key-in
      IF @cReceiptKey <> '' AND @cNewUCC <> ''
      BEGIN
         SET @nErrNo = 76852
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Key-in either
         GOTO Quit
      END

      -- ASN
      IF @cReceiptKey <> ''
      BEGIN
         -- Get ASN info
         DECLARE @cChkFacility   NVARCHAR( 5)
         DECLARE @cChkReceiptKey NVARCHAR( 10)
         DECLARE @cASNStatus     NVARCHAR( 10)
         DECLARE @cChkStorerKey  NVARCHAR( 15)
         SELECT
             @cChkFacility = Facility,
             @cChkStorerKey = StorerKey,
             @cASNStatus = ASNStatus,
             @cDocType = DocType
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey

         -- Check ASN
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 76853
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ASN
            GOTO Step_1_Fail
         END

         -- Check facility different
         IF @cFacility <> @cChkFacility
         BEGIN
            SET @nErrNo = 76854
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
            GOTO Step_1_Fail
         END

         -- Check storer different
         IF @cStorerKey <> @cChkStorerKey
         BEGIN
            SET @nErrNo = 76855
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            GOTO Step_1_Fail
         END

         -- Check ASN status
         IF @cASNStatus = '9'
         BEGIN
            SET @nErrNo = 76856
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN finalized
            GOTO Step_1_Fail
         END

         -- Prep next screen var
         SET @cOldUCC = ''
         SET @cOutField01 = '' -- Old UCC

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END

      -- New UCC
      IF @cNewUCC <> ''
      BEGIN
         -- Check valid UCC
         IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cNewUCC AND StorerKey = @cStorerKey AND LEFT( @cNewUCC, 2) = 'VF')
         BEGIN
            SET @nErrNo = 76857
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid NewUCC
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- New UCC
            SET @cOutField02 = '' -- New UCC
            GOTO Quit
         END

         -- Get UCC info
         SELECT
            @cOldUCC = UserDefined04,
            @cLOC = UserDefined06
         FROM dbo.UCC WITH (NOLOCK)
         WHERE UCCNo = @cNewUCC
            AND StorerKey = @cStorerKey

         -- Calc statistic
         EXEC rdt.rdt_UCC_Swap_GetStat @nMobile, @nFunc, @cLangCode, @cReceiptKey, @cStorerKey, @cNewUCC,
            @cTotal   OUTPUT,
            @cSwapped OUTPUT,
            @nErrNo   OUTPUT,
            @cErrMsg  OUTPUT

         -- Prep next screen var
         SET @cOutField01 = @cOldUCC
         SET @cOutField02 = @cNewUCC
         SET @cOutField03 = @cLOC
         SET @cOutField04 = RTRIM( @cSwapped) + '/' + RTRIM( @cTotal)

         -- Go to next screen
         SET @nScn = @nScn + 3
         SET @nStep = @nStep + 3
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     -- EventLog
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey,
       @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cReceiptKey = ''
      SET @cOutField01 = '' -- ASN
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- ASN
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 3170. OldUCC
   OldUCC  (field01, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOldUCC = @cInField01

      -- Check blank
      IF @cOldUCC = '' OR @cOldUCC IS NULL
      BEGIN
         SET @nErrNo = 76858
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OLD UCC needed
         GOTO Step_2_Fail
      END

      -- Check UCC swapped
      IF EXISTS( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE Userdefined04 = @cOldUCC AND StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 76859
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Swapped
         GOTO Step_2_Fail
      END

      -- Check UCC
      IF NOT EXISTS( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cOldUCC AND StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 76860
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC not exist
         GOTO Step_2_Fail
      END

      -- Check UCC swapped
      IF EXISTS( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cOldUCC AND StorerKey = @cStorerKey AND Userdefined04 <> '' AND SourceType <> 'CANCSO')
      BEGIN
         SET @nErrNo = 76861
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Swapped
         GOTO Step_2_Fail
      END

      -- Check UCC not in ASN
      IF NOT EXISTS( SELECT 1
         FROM dbo.UCC WITH (NOLOCK)
         WHERE UCCNo = @cOldUCC
            AND StorerKey = @cStorerKey
            AND ExternKey IN (SELECT ExternReceiptKey FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey))
      BEGIN
         SET @nErrNo = 76862
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC not in ASN
         GOTO Step_2_Fail
      END

      -- Get SKU info
      SET @cSKU = ''
      SELECT TOP 1
         @cSKU = SKU.SKU,
         @cSKUDescr = SKU.Descr
      FROM dbo.UCC WITH (NOLOCK)
         JOIN dbo.SKU WITH (NOLOCK) ON (UCC.StorerKey = SKU.StorerKey AND UCC.SKU = SKU.SKU)
      WHERE UCC.UCCNo = @cOldUCC
         AND UCC.StorerKey = @cStorerKey
         AND (STDGrossWGT = 0 OR STDCube = 0)
      ORDER BY SKU.SKU

      -- Check new SKU
      IF @cSKU <> '' AND @cDocType <> 'X'
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField04 = '' -- Weight
         SET @cOutField05 = '' -- Cube
         SET @cOutField06 = '2' -- Odd size
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Weight

         -- Go to SKU screen
         SET @nScn = @nScn + 3
         SET @nStep = @nStep + 3
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cNewUCC = ''
         SET @cOutField01 = @cOldUCC
         SET @cOutField02 = '' -- NewUCC

         -- Go to new UCC screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cReceiptKey = ''
      SET @cNewUCC = ''
      SET @cOutField01 = '' -- ASN
      SET @cOutField02 = '' -- New UCC

      -- Go back to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOldUCC  = ''
      SET @cOutField01 = '' -- OldUCC
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 3072. NewUCC
   OldUCC   (field01)
   NewUCC   (field02, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cNewUCC = @cInField02

      -- Check blank
      IF @cNewUCC = '' OR @cNewUCC IS NULL
      BEGIN
         SET @nErrNo = 76863
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --New UCC needed
         GOTO Step_3_Fail
      END

      -- Check same UCC
      IF @cOldUCC = @cNewUCC
      BEGIN
         SET @nErrNo = 76864
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameOld&NewUCC
         GOTO Step_3_Fail
      END

      -- Check UCC format
      IF LEN( @cNewUCC) <> 10 OR LEFT( @cNewUCC, 2) <> 'VF'
      BEGIN
         SET @nErrNo = 76865
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid format
         GOTO Step_3_Fail
      END

      -- Check UCC exist
      IF EXISTS( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cNewUCC AND StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 76866
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NewUCCAdyExist
         GOTO Step_3_Fail
      END

      -- Calc assign LOC
      EXEC rdt.rdt_UCC_Swap @nMobile, @nFunc, @cLangCode, @cReceiptKey, @cStorerKey, @cOldUCC, @cNewUCC,
         @cLOC    OUTPUT,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Step_3_Fail

      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '4', -- Move
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @cReceiptKey = @cReceiptKey,
         @cToLocation = @cLOC,
         --@cRefNo1     = @cOldUCC,
         --@cRefNo2     = @cNewUCC,
         @cUCC        = @cOldUCC,
         @cToUCC      = @cNewUCC,
         @nStep       = @nStep

      -- Calc statistic
      EXEC rdt.rdt_UCC_Swap_GetStat @nMobile, @nFunc, @cLangCode, @cReceiptKey, @cStorerKey, @cNewUCC,
         @cTotal   OUTPUT,
         @cSwapped OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

      -- Prep next screen var
      SET @cOutField01 = @cOldUCC
      SET @cOutField02 = @cNewUCC
      SET @cOutField03 = @cLOC
      SET @cOutField04 = RTRIM( @cSwapped) + '/' + RTRIM( @cTotal)

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOldUCC = ''
      SET @cOutField01 = '' -- OldUCC

      -- Go back to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cNewUCC = ''
      SET @cOutField02 = '' --NewUCC
   END
END
GOTO Quit


/********************************************************************************
Step 4. scn = 3073. Message screen
   OldUCC   (field01)
   NewUCC   (field02)
   LOC      (field03)
********************************************************************************/
Step_4:
BEGIN
   -- Go back to 1st screen
   SET @nScn  = @nScn - 2
   SET @nStep = @nStep - 2

   -- Prep next screen var
   SET @cOldUCC = ''
   SET @cOutField01 = '' -- Old UCC
END
GOTO Quit


/********************************************************************************
Step 5. scn = 3074. Weight, cube, odd size screen
   SKU      (field01)
   Desc1    (field02)
   Desc2    (field03)
   Weight   (field04, input)
   Cube     (field05, input)
   Odd size (field06, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cWeight  NVARCHAR(10)
      DECLARE @cCube    NVARCHAR(10)
      DECLARE @cOddSize NVARCHAR(1)

      -- Screen mapping
      SET @cWeight = @cInField04
      SET @cCube   = @cInField05
      SET @cOddSize   = @cInField06

      -- Retain value
      SET @cOutField04 = @cInField04
      SET @cOutField05 = @cInField05
      SET @cOutField06 = @cInField06

      -- Check blank weight
      IF @cWeight = '' OR @cWeight IS NULL
      BEGIN
         SET @nErrNo = 76867
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Weight needed
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Weight
         GOTO Quit
      END

      -- Check weight valid
      IF rdt.rdtIsValidQty( @cWeight, 21) = 0
      BEGIN
         SET @nErrNo = 76868
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid weight
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Weight
         GOTO Quit
      END

      -- Check blank cube
      IF @cCube = '' OR @cCube IS NULL
      BEGIN
         SET @nErrNo = 76869
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cube needed
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- Cube
         GOTO Quit
      END

      -- Check weight valid
      IF rdt.rdtIsValidQty( @cCube, 21) = 0
      BEGIN
         SET @nErrNo = 76870
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid cube
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- Cube
         GOTO Quit
      END

      -- Check odd size
      IF @cOddSize NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 76871
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOddSize
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- OddSize
         GOTO Quit
      END

      -- Update SKU
      UPDATE SKU SET
         STDGrossWGT = @cWeight,
         STDCube = @cCube,
         Notes1 = CASE WHEN @cOddSize = '1' THEN 'ODDSIZE' ELSE '' END
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 76872
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD SKU Fail
         GOTO Quit
      END

      -- Get SKU info
      SET @cSKU = ''
      SELECT TOP 1
         @cSKU = SKU.SKU,
         @cSKUDescr = SKU.Descr
      FROM dbo.UCC WITH (NOLOCK)
         JOIN dbo.SKU WITH (NOLOCK) ON (UCC.StorerKey = SKU.StorerKey AND UCC.SKU = SKU.SKU)
      WHERE UCC.UCCNo = @cOldUCC
         AND UCC.StorerKey = @cStorerKey
         AND (STDGrossWGT = 0 OR STDCube = 0)
      ORDER BY SKU.SKU

      -- Check new SKU
      IF @cSKU <> ''
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField04 = '' --Weight
         SET @cOutField05 = '' --Cube
         --SET @cOutField06 = '' --OddSize	--SOS342022
         SET @cOutField06 = '2' --OddSize		--SOS342022
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Weight

         -- Remain in current screen
         -- SET @nScn = @nScn + 1
         -- SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cNewUCC = ''
         SET @cOutField01 = @cOldUCC
         SET @cOutField02 = '' --NewUCC

         -- Go to new UCC screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prep next screen var
      SET @cOldUCC = ''
      SET @cOutField01 = '' -- OldUCC

      -- Go back to 1st screen
      SET @nScn  = @nScn - 3
      SET @nStep = @nStep - 3
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
      -- UserName  = @cUserName,

      V_ReceiptKey = @cReceiptKey,
      V_SKU      = @cSKU,
      V_SKUDescr = @cSKUDescr,

      V_String1  = @cOldUCC,
      V_String2  = @cNewUCC,
      V_String3  = @cDocType,

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