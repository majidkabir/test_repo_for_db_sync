SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_SKULOCInquiry                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: SKU LOC Inquiry                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 02-Feb-2017  1.0  James    WMS746 - Created                          */
/* 13-Nov-2018  1.1  TungGH   Performance                               */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_SKULOCInquiry] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(125) OUTPUT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @bSuccess       INT,   
   @cChkFacility   NVARCHAR( 5), 
   @cNextSKU       NVARCHAR( 20),
   @cNextLOC       NVARCHAR( 10),
   @cSKUDescr      NVARCHAR( 60), 
   @cQtyOnHand     NVARCHAR( 20), 
   @cQtyAvail      NVARCHAR( 20)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,

   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),

   @cInquiry_SKU NVARCHAR( 20),
   @cInquiry_Loc NVARCHAR( 10),
   @cCurrentSKU  NVARCHAR( 20), 
   @cCurrentLOC  NVARCHAR( 10),
   @cSummary     NVARCHAR( 20), 
   @nNoOfRec     INT,
   @cDisplay01   NVARCHAR( 20), 
   @cDisplay02   NVARCHAR( 20), 
   @cDisplay03   NVARCHAR( 20), 
   @cDisplay04   NVARCHAR( 20), 
   @cDisplay05   NVARCHAR( 20), 
   @cDisplay06   NVARCHAR( 20), 
   @cDisplay07   NVARCHAR( 20), 
   @cDisplay08   NVARCHAR( 20), 
   @nQty01       INT,
   @nQty02       INT,
   @nQty03       INT,
   @nQty04       INT,
   @nQty05       INT,
   
   @cDecodeSP           NVARCHAR( 20), 
   @cBarcode            NVARCHAR( 60), 
   @cUPC                NVARCHAR( 30), 
   @cLOC                NVARCHAR( 10), 
   @cID                 NVARCHAR( 18),
   @cSKU                NVARCHAR( 20),
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
   @cUserDefine01       NVARCHAR( 60),  
   @cUserDefine02       NVARCHAR( 60),  
   @cUserDefine03       NVARCHAR( 60),  
   @cUserDefine04       NVARCHAR( 60),  
   @cUserDefine05       NVARCHAR( 60),  
   @cSQL                NVARCHAR( MAX), 
   @cSQLParam           NVARCHAR( MAX), 
   @nQTY                INT,
   @cLocType            NVARCHAR( 10),
   @cExtendedGetNextRecSP  NVARCHAR( 20),

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
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @nMenu       = Menu,
   @cLangCode   = Lang_code,

   @cStorerKey  = StorerKey,
   @cFacility   = Facility,

   @cInquiry_SKU = V_SKU,
   @cInquiry_LOC = V_Loc,
   
   @cDecodeSP   = V_String1,
   @cCurrentLoc = V_String2,
   @cCurrentSKU = V_String3,
   @cSummary    = V_String4,
   @cNextLOC    = V_String5, 
   @cNextSKU    = V_String6, 
   
   @cExtendedGetNextRecSP = V_String7, 

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

IF @nFunc = 728 -- Inquiry (SKU/LOC) 
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Inquiry SKU
   IF @nStep = 1 GOTO Step_1   -- Scn = 4780. SKU, LOC
   IF @nStep = 2 GOTO Step_2   -- Scn = 4781. Result (LOC)
   IF @nStep = 3 GOTO Step_3   -- Scn = 4782. Result (SKU)
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 728. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Prep next screen var
   SET @cInquiry_SKU = ''
   SET @cInquiry_LOC = ''
   SET @cOutField01 = '' -- LOC
   SET @cOutField02 = '' -- SKU

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP IN ('0', '')
      SET @cDecodeSP = ''

   SET @cExtendedGetNextRecSP = rdt.RDTGetConfig( @nFunc, 'ExtendedGetNextRecSP', @cStorerkey)
   IF @cExtendedGetNextRecSP IN ('0', '')
      SET @cExtendedGetNextRecSP = ''
      
   SET @nScn = 4780
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 4780. LOC, SKU
   LOC (field01, input)   
   SKU (field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Initialize value
      SET @cInquiry_LOC = ''
      SET @cInquiry_SKU = ''

      -- Screen mapping
      SET @cInquiry_LOC = @cInField01
      SET @cInquiry_SKU = @cInField02

      -- Get no field keyed-in
      DECLARE @i INT
      SET @i = 0
      IF ISNULL( @cInquiry_SKU, '') <> '' SET @i = @i + 1
      IF ISNULL( @cInquiry_LOC, '') <> '' SET @i = @i + 1

      IF @i = 0
      BEGIN
         SET @nErrNo = 105901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU/LOC
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      IF @i > 1
      BEGIN
         SET @nErrNo = 105902
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Either SKU/LOC
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      IF @cDecodeSP <> ''
      BEGIN
         IF ISNULL( @cInquiry_SKU, '') = ''
            SET @cBarcode = @cInField01
         ELSE
            SET @cBarcode = @cInField02

         -- Standard decode
         IF @cDecodeSP = '1'
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
               @cID           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT, 
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT
         
         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, ' +
               ' @cSKU           OUTPUT, @cLOC           OUTPUT, ' +
               ' @cLottable01    OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT, ' +
               ' @cLottable06    OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT, ' +
               ' @cLottable11    OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT, ' +
               ' @cUserDefine01  OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT, ' + 
               ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cBarcode       NVARCHAR( 60), ' +
               ' @cSKU           NVARCHAR( 20)  OUTPUT, ' +
               ' @cLOC           NVARCHAR( 10)  OUTPUT, ' +
               ' @cLottable01    NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable02    NVARCHAR( 18)  OUTPUT, ' +
               ' @cLottable03    NVARCHAR( 18)  OUTPUT, ' +
               ' @dLottable04    DATETIME       OUTPUT, ' +
               ' @dLottable05    DATETIME       OUTPUT, ' +
               ' @cLottable06    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable07    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable08    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable09    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable10    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable11    NVARCHAR( 30)  OUTPUT, ' +
               ' @cLottable12    NVARCHAR( 30)  OUTPUT, ' +
               ' @dLottable13    DATETIME       OUTPUT, ' +
               ' @dLottable14    DATETIME       OUTPUT, ' +
               ' @dLottable15    DATETIME       OUTPUT, ' +
               ' @cUserDefine01  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine02  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine03  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine04  NVARCHAR( 60)  OUTPUT, ' +
               ' @cUserDefine05  NVARCHAR( 60)  OUTPUT, ' +
               ' @nErrNo         INT            OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, 
               @cSKU          OUTPUT, @cLOC           OUTPUT, 
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
               @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT,               
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT

            SET @cInquiry_SKU = @cSKU
            SET @cInquiry_LOC = @cLOC
         END
      END   -- End for DecodeSP

      -- By LOC
      IF ISNULL( @cInquiry_LOC, '') <> '' 
      BEGIN
         SELECT @cChkFacility = Facility
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cInquiry_LOC

         -- Validate LOC
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 105903
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         -- Validate facility
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 105904
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END
      END
      
      -- By SKU
      IF ISNULL( @cInquiry_SKU, '') <> '' 
      BEGIN
         EXEC RDT.rdt_GETSKU
             @cStorerKey = @cStorerKey
            ,@cSKU       = @cInquiry_SKU OUTPUT
            ,@bSuccess   = @bSuccess     OUTPUT
            ,@nErr       = @nErrNo       OUTPUT
            ,@cErrMsg    = @cErrMsg      OUTPUT

         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = 105905
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_1_Fail
         END
      END

      -- Get next screen data
      SET @cCurrentLOC = ''
      SET @cCurrentSKU = ''
      SET @cNextLOC = ''
      SET @cNextSKU = ''
      SET @cSummary = ''
      SET @nErrNo = 0

      IF @cExtendedGetNextRecSP <> '' AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedGetNextRecSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedGetNextRecSP) +     
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility, @cInquiry_SKU, @cInquiry_LOC, ' + 
            ' @cNextSKU OUTPUT, @cNextLOC OUTPUT, @cSKUDescr OUTPUT, @cSummary OUTPUT, @nNoOfRec OUTPUT, @cLocType OUTPUT, ' + 
            ' @cDisplay01 OUTPUT, @cDisplay02 OUTPUT, @cDisplay03 OUTPUT, @cDisplay04 OUTPUT, ' +
            ' @cDisplay05 OUTPUT, @cDisplay06 OUTPUT, @cDisplay07 OUTPUT, @cDisplay08 OUTPUT,' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    

         SET @cSQLParam =    
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' +
            '@cStorerkey      NVARCHAR( 15), ' +
            '@cFacility       NVARCHAR( 5),  ' +
            '@cInquiry_SKU    NVARCHAR( 20), ' +
            '@cInquiry_LOC    NVARCHAR( 10), ' +
            '@cNextSKU        NVARCHAR( 20)  OUTPUT, ' + 
            '@cNextLOC        NVARCHAR( 10)  OUTPUT, ' +
            '@cSKUDescr       NVARCHAR( 60)  OUTPUT, ' +
            '@cSummary        NVARCHAR( 20)  OUTPUT, ' +
            '@nNoOfRec        INT            OUTPUT, ' +
            '@cLocType        NVARCHAR( 10)  OUTPUT, ' +
            '@cDisplay01      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay02      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay03      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay04      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay05      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay06      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay07      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay08      NVARCHAR( 20)  OUTPUT, ' +  
            '@nErrNo          INT            OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20)  OUTPUT  ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility, @cInquiry_SKU, @cInquiry_LOC,  
               @cNextSKU OUTPUT, @cNextLOC OUTPUT, @cSKUDescr OUTPUT, @cSummary OUTPUT, @nNoOfRec OUTPUT, @cLocType OUTPUT, 
               @cDisplay01 OUTPUT, @cDisplay02 OUTPUT, @cDisplay03 OUTPUT, @cDisplay04 OUTPUT, 
               @cDisplay05 OUTPUT, @cDisplay06 OUTPUT, @cDisplay07 OUTPUT, @cDisplay08 OUTPUT, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT 
      END
      ELSE
      BEGIN
         EXEC rdt.rdt_SKULOCInquiry_GetNext 
            @nMobile       = @nMobile, 
            @nFunc         = @nFunc, 
            @cLangCode     = @cLangCode, 
            @nStep         = @nStep, 
            @nInputKey     = @nInputKey, 
            @cStorerKey    = @cStorerKey, 
            @cFacility     = @cFacility, 
            @cInquiry_SKU  = @cInquiry_SKU, 
            @cInquiry_LOC  = @cInquiry_LOC, 
            @cNextSKU      = @cNextSKU       OUTPUT, 
            @cNextLOC      = @cNextLOC       OUTPUT, 
            @cSKUDescr     = @cSKUDescr      OUTPUT, 
            @cSummary      = @cSummary       OUTPUT,
            @nNoOfRec      = @nNoOfRec       OUTPUT, 
            @cLocType      = @cLocType       OUTPUT, 
            @cDisplay01    = @cDisplay01     OUTPUT, 
            @cDisplay02    = @cDisplay02     OUTPUT, 
            @cDisplay03    = @cDisplay03     OUTPUT, 
            @cDisplay04    = @cDisplay04     OUTPUT, 
            @cDisplay05    = @cDisplay05     OUTPUT, 
            @cDisplay06    = @cDisplay06     OUTPUT,
            @cDisplay07    = @cDisplay07     OUTPUT,
            @cDisplay08    = @cDisplay08     OUTPUT,
            @nErrNo        = @nErrNo         OUTPUT, 
            @cErrMsg       = @cErrMsg        OUTPUT
      END

      IF ( @cInquiry_LOC <> '' AND ISNULL( @cNextSKU, '') = '') OR 
         ( @cInquiry_SKU <> '' AND ISNULL( @cNextLOC, '') = '')
      BEGIN
         SET @nErrNo = 105906
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NO MORE RECORD
         GOTO Step_1_Fail
      END

      SET @cCurrentLOC = @cNextLOC
      SET @cCurrentSKU = @cNextSKU

      IF ISNULL( @cInquiry_LOC, '') <> ''
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cSummary
         SET @cOutField02 = @cCurrentLOC
         SET @cOutField03 = @nNoOfRec
         SET @cOutField04 = @cDisplay01
         SET @cOutField05 = @cDisplay02
         SET @cOutField06 = @cDisplay03
         SET @cOutField07 = @cDisplay04
         SET @cOutField08 = @cDisplay05
         SET @cOutField09 = @cDisplay06
         SET @cOutField10 = @cDisplay07
         SET @cOutField11 = @cDisplay08                           

         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cSummary
         SET @cOutField02 = @cCurrentSKU
         SET @cOutField03 = SUBSTRING( @cSKUDescr,  1, 20)
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField05 = @cLocType
         SET @cOutField06 = @nNoOfRec
         SET @cOutField07 = @cDisplay01
         SET @cOutField08 = @cDisplay02
         SET @cOutField09 = @cDisplay03
         SET @cOutField10 = @cDisplay04
         SET @cOutField11 = @cDisplay05

         SET @nScn  = @nScn + 2
         SET @nStep = @nStep + 2
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cInquiry_SKU = ''
      SET @cInquiry_LOC = ''

      SET @cOutField01 = @cInquiry_LOC
      SET @cOutField02 = @cInquiry_SKU
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 4781. Result
   Loc         (field01)
   Summary     (field02)
   No Of SKU   (field03)
   SKU1        (field04)
   SKU2        (field05)
   SKU3        (field06)
   SKU4        (field07)
   SKU5        (field08)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @nErrNo = 0

      IF @cExtendedGetNextRecSP <> '' AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedGetNextRecSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedGetNextRecSP) +     
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility, @cInquiry_SKU, @cInquiry_LOC, ' + 
            ' @cNextSKU OUTPUT, @cNextLOC OUTPUT, @cSKUDescr OUTPUT, @cSummary OUTPUT, @nNoOfRec OUTPUT, @cLocType OUTPUT, ' + 
            ' @cDisplay01 OUTPUT, @cDisplay02 OUTPUT, @cDisplay03 OUTPUT, @cDisplay04 OUTPUT, ' +
            ' @cDisplay05 OUTPUT, @cDisplay06 OUTPUT, @cDisplay07 OUTPUT, @cDisplay08 OUTPUT,' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    

         SET @cSQLParam =    
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' +
            '@cStorerkey      NVARCHAR( 15), ' +
            '@cFacility       NVARCHAR( 5),  ' +
            '@cInquiry_SKU    NVARCHAR( 20), ' +
            '@cInquiry_LOC    NVARCHAR( 10), ' +
            '@cNextSKU        NVARCHAR( 20)  OUTPUT, ' + 
            '@cNextLOC        NVARCHAR( 10)  OUTPUT, ' +
            '@cSKUDescr       NVARCHAR( 60)  OUTPUT, ' +
            '@cSummary        NVARCHAR( 20)  OUTPUT, ' +
            '@nNoOfRec        INT            OUTPUT, ' +
            '@cLocType        NVARCHAR( 10)  OUTPUT, ' +
            '@cDisplay01      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay02      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay03      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay04      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay05      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay06      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay07      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay08      NVARCHAR( 20)  OUTPUT, ' +  
            '@nErrNo          INT            OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20)  OUTPUT  ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility, @cInquiry_SKU, @cInquiry_LOC,  
               @cNextSKU OUTPUT, @cNextLOC OUTPUT, @cSKUDescr OUTPUT, @cSummary OUTPUT, @nNoOfRec OUTPUT, @cLocType OUTPUT, 
               @cDisplay01 OUTPUT, @cDisplay02 OUTPUT, @cDisplay03 OUTPUT, @cDisplay04 OUTPUT, 
               @cDisplay05 OUTPUT, @cDisplay06 OUTPUT, @cDisplay07 OUTPUT, @cDisplay08 OUTPUT, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT 
      END
      ELSE
      BEGIN
         -- Get next screen data
         EXEC rdt.rdt_SKULOCInquiry_GetNext 
            @nMobile       = @nMobile, 
            @nFunc         = @nFunc, 
            @cLangCode     = @cLangCode, 
            @nStep         = @nStep, 
            @nInputKey     = @nInputKey, 
            @cStorerKey    = @cStorerKey, 
            @cFacility     = @cFacility, 
            @cInquiry_SKU  = @cInquiry_SKU, 
            @cInquiry_LOC  = @cInquiry_LOC, 
            @cNextSKU      = @cNextSKU       OUTPUT, 
            @cNextLOC      = @cNextLOC       OUTPUT, 
            @cSKUDescr     = @cSKUDescr      OUTPUT, 
            @cSummary      = @cSummary       OUTPUT,
            @nNoOfRec      = @nNoOfRec       OUTPUT, 
            @cLocType      = @cLocType       OUTPUT, 
            @cDisplay01    = @cDisplay01     OUTPUT, 
            @cDisplay02    = @cDisplay02     OUTPUT, 
            @cDisplay03    = @cDisplay03     OUTPUT, 
            @cDisplay04    = @cDisplay04     OUTPUT, 
            @cDisplay05    = @cDisplay05     OUTPUT, 
            @cDisplay06    = @cDisplay06     OUTPUT,
            @cDisplay07    = @cDisplay07     OUTPUT,
            @cDisplay08    = @cDisplay08     OUTPUT,
            @nErrNo        = @nErrNo         OUTPUT, 
            @cErrMsg       = @cErrMsg        OUTPUT
      END

      IF ISNULL( @cInquiry_LOC, '') <> '' AND @cCurrentSKU = @cNextSKU
      BEGIN
         SET @nErrNo = 105907
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NO MORE RECORD
         GOTO Step_2_Fail
      END

      SET @cCurrentLOC = @cNextLOC
      SET @cCurrentSKU = @cNextSKU


      -- Prep next screen var
      SET @cOutField01 = @cSummary
      SET @cOutField02 = @cCurrentLOC
      SET @cOutField03 = @nNoOfRec
      SET @cOutField04 = @cDisplay01
      SET @cOutField05 = @cDisplay02
      SET @cOutField06 = @cDisplay03
      SET @cOutField07 = @cDisplay04
      SET @cOutField08 = @cDisplay05
      SET @cOutField09 = @cDisplay06
      SET @cOutField10 = @cDisplay07
      SET @cOutField11 = @cDisplay08                           
      
   END
   
   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep prev screen var
      IF @cInquiry_LOC <> '' EXEC rdt.rdtSetFocusField @nMobile, 1
      IF @cInquiry_SKU <> '' EXEC rdt.rdtSetFocusField @nMobile, 2

      SET @cInquiry_SKU = ''
      SET @cInquiry_LOC = ''
      SET @cOutField01 = @cInquiry_LOC
      SET @cOutField02 = @cInquiry_SKU
      
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
END
GOTO Quit

/********************************************************************************
Step 3. Scn = 4782. Result
   Sku         (field01)
   Descr1      (field02)
   Descr2      (field03)
   Summary     (field04)
   Pick Loc    (field05)
   No Of Loc   (field06)
   SKU1        (field07)
   SKU2        (field08)
   SKU3        (field09)
   SKU4        (field10)
   SKU5        (field08)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @nErrNo = 0

      IF @cExtendedGetNextRecSP <> '' AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedGetNextRecSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedGetNextRecSP) +     
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility, @cInquiry_SKU, @cInquiry_LOC, ' + 
            ' @cNextSKU OUTPUT, @cNextLOC OUTPUT, @cSKUDescr OUTPUT, @cSummary OUTPUT, @nNoOfRec OUTPUT, @cLocType OUTPUT, ' + 
            ' @cDisplay01 OUTPUT, @cDisplay02 OUTPUT, @cDisplay03 OUTPUT, @cDisplay04 OUTPUT, ' +
            ' @cDisplay05 OUTPUT, @cDisplay06 OUTPUT, @cDisplay07 OUTPUT, @cDisplay08 OUTPUT,' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    

         SET @cSQLParam =    
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' +
            '@cStorerkey      NVARCHAR( 15), ' +
            '@cFacility       NVARCHAR( 5),  ' +
            '@cInquiry_SKU    NVARCHAR( 20), ' +
            '@cInquiry_LOC    NVARCHAR( 10), ' +
            '@cNextSKU        NVARCHAR( 20)  OUTPUT, ' + 
            '@cNextLOC        NVARCHAR( 10)  OUTPUT, ' +
            '@cSKUDescr       NVARCHAR( 60)  OUTPUT, ' +
            '@cSummary        NVARCHAR( 20)  OUTPUT, ' +
            '@nNoOfRec        INT            OUTPUT, ' +
            '@cLocType        NVARCHAR( 10)  OUTPUT, ' +
            '@cDisplay01      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay02      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay03      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay04      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay05      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay06      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay07      NVARCHAR( 20)  OUTPUT, ' +
            '@cDisplay08      NVARCHAR( 20)  OUTPUT, ' +  
            '@nErrNo          INT            OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20)  OUTPUT  ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility, @cInquiry_SKU, @cInquiry_LOC,  
               @cNextSKU OUTPUT, @cNextLOC OUTPUT, @cSKUDescr OUTPUT, @cSummary OUTPUT, @nNoOfRec OUTPUT, @cLocType OUTPUT, 
               @cDisplay01 OUTPUT, @cDisplay02 OUTPUT, @cDisplay03 OUTPUT, @cDisplay04 OUTPUT, 
               @cDisplay05 OUTPUT, @cDisplay06 OUTPUT, @cDisplay07 OUTPUT, @cDisplay08 OUTPUT, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT 
      END
      ELSE
      BEGIN
         -- Get next screen data
         EXEC rdt.rdt_SKULOCInquiry_GetNext 
            @nMobile       = @nMobile, 
            @nFunc         = @nFunc, 
            @cLangCode     = @cLangCode, 
            @nStep         = @nStep, 
            @nInputKey     = @nInputKey, 
            @cStorerKey    = @cStorerKey, 
            @cFacility     = @cFacility, 
            @cInquiry_SKU  = @cInquiry_SKU, 
            @cInquiry_LOC  = @cInquiry_LOC, 
            @cNextSKU      = @cNextSKU       OUTPUT, 
            @cNextLOC      = @cNextLOC       OUTPUT, 
            @cSKUDescr     = @cSKUDescr      OUTPUT, 
            @cSummary      = @cSummary       OUTPUT,
            @nNoOfRec      = @nNoOfRec       OUTPUT, 
            @cLocType      = @cLocType       OUTPUT, 
            @cDisplay01    = @cDisplay01     OUTPUT, 
            @cDisplay02    = @cDisplay02     OUTPUT, 
            @cDisplay03    = @cDisplay03     OUTPUT, 
            @cDisplay04    = @cDisplay04     OUTPUT, 
            @cDisplay05    = @cDisplay05     OUTPUT, 
            @cDisplay06    = @cDisplay06     OUTPUT,
            @cDisplay07    = @cDisplay07     OUTPUT,
            @cDisplay08    = @cDisplay08     OUTPUT,
            @nErrNo        = @nErrNo         OUTPUT, 
            @cErrMsg       = @cErrMsg        OUTPUT
      END

      IF ISNULL( @cInquiry_SKU, '') <> '' AND @cCurrentLOC = @cNextLOC
      BEGIN
         SET @nErrNo = 105908
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NO MORE RECORD
         GOTO Step_3_Fail
      END

      SET @cCurrentLOC = @cNextLOC
      SET @cCurrentSKU = @cNextSKU

      -- Prep next screen var
      SET @cOutField01 = @cSummary
      SET @cOutField02 = @cCurrentSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr,  1, 20)
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField05 = @cLocType
      SET @cOutField06 = @nNoOfRec
      SET @cOutField07 = @cDisplay01
      SET @cOutField08 = @cDisplay02
      SET @cOutField09 = @cDisplay03
      SET @cOutField10 = @cDisplay04
      SET @cOutField11 = @cDisplay05      
   END
   
   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep prev screen var
      IF @cInquiry_LOC <> '' EXEC rdt.rdtSetFocusField @nMobile, 1
      IF @cInquiry_SKU <> '' EXEC rdt.rdtSetFocusField @nMobile, 2

      SET @cInquiry_SKU = ''
      SET @cInquiry_LOC = ''
      SET @cOutField01 = @cInquiry_LOC
      SET @cOutField02 = @cInquiry_SKU
      
      SET @nScn  = @nScn - 2
      SET @nStep = @nStep - 2
   END
   GOTO Quit

   Step_3_Fail:
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

      V_SKU  = @cInquiry_SKU,
      V_LOC  = @cInquiry_LOC,

      V_String1 = @cDecodeSP,
      V_String2 = @cCurrentLOC,
      V_String3 = @cCurrentSKU,
      V_String4 = @cSummary,
      V_String5 = @cNextLOC, 
      V_String6 = @cNextSKU, 
      V_String7 = @cExtendedGetNextRecSP, 

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