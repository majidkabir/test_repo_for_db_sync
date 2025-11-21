SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_DataCapture                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Ad-hoc data capturing in warehouse                          */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2006-11-07 1.0  Ung        Created                                   */
/* 2007-06-07 1.1  Vicky      Fix invalid Function used                 */
/* 2016-09-30 1.2  Ung        Performance tuning                        */
/************************************************************************/

CREATE PROC RDT.rdtfnc_DataCapture (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF  

-- Misc variable
-- DECLARE

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

	@cZone         VARCHAR (10),
	@cLoc          VARCHAR (10),
	@cSKU          VARCHAR (20),
	@cUOM          VARCHAR (10),
	@cID           VARCHAR (18),
	@cConsigneeKey VARCHAR (15),
	@cCaseID       VARCHAR (15),
	@cSKUDescr     VARCHAR (60),
	@nQTY          INT,
	@cUCC          VARCHAR (20),
   @cLot          VARCHAR (10),
	@cLottable01   VARCHAR (18),
	@cLottable02   VARCHAR (18),
	@cLottable03   VARCHAR (18),
	@dLottable04   DATETIME,
	@dLottable05   DATETIME,
	@cString1      VARCHAR (20),
	@cString2      VARCHAR (20),
	@cString3      VARCHAR (20),
	@cString4      VARCHAR (20),
	@cString5      VARCHAR (20),
	@cString6      VARCHAR (20),
	@cString7      VARCHAR (20),
	@cString8      VARCHAR (20),
	@cString9      VARCHAR (20),
	@cString10     VARCHAR (20), 
   @cOutField01   VARCHAR (60) 

DECLARE @cQTY     NVARCHAR( 5)

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

   @cZone         = V_Zone,
   @cLoc          = V_Loc,
   @cSKU          = V_SKU,
   @cUOM          = V_UOM,
   @cID           = V_ID,
   @cConsigneeKey = V_ConsigneeKey,
   @cCaseID       = V_CaseID,
   @cSKUDescr     = V_SKUDescr,
   @nQTY          = V_QTY,
   @cUCC          = V_UCC,
   @cLottable01   = V_Lottable01,
   @cLottable02   = V_Lottable02,
   @cLottable03   = V_Lottable03,
   @dLottable04   = V_Lottable04,
   @dLottable05   = V_Lottable05,
   @cString1      = V_String1,
   @cString2      = V_String2,
   @cString3      = V_String3,
   @cString4      = V_String4,
   @cString5      = V_String5,
   @cString6      = V_String6,
   @cString7      = V_String7,
   @cString8      = V_String8,
   @cString9      = V_String9,
   @cString10     = V_String10, 
   @cOutField01   = O_Field01

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 880 -- Data capture
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Data capture
   IF @nStep = 1 GOTO Step_1   -- Scn = Screen range from 1020 until 1021
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 880. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 1020
   SET @nStep = 1

   -- Initiate var
   SET @cZone         = ''
   SET @cLoc          = ''
   SET @cSKU          = ''
   SET @cUOM          = ''
   SET @cID           = ''
   SET @cConsigneeKey = ''
   SET @cCaseID       = ''
   SET @cSKUDescr     = ''
   SET @nQTY          = 0
   SET @cUCC          = ''
   SET @cLottable01   = ''
   SET @cLottable02   = ''
   SET @cLottable03   = ''
   SET @dLottable04   = NULL
   SET @dLottable05   = NULL
   SET @cString1      = ''
   SET @cString2      = ''
   SET @cString3      = ''
   SET @cString4      = ''
   SET @cString5      = ''
   SET @cString6      = ''
   SET @cString7      = ''
   SET @cString8      = ''
   SET @cString9      = ''
   SET @cString10     = ''

END
GOTO Quit


/********************************************************************************
Step 1. Scn = 1100-1200. User configurable screen
   Label (V_?????, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Validate location
      IF @cLOC <> '' AND @cLOC IS NOT NULL
         IF NOT EXISTS( SELECT 1 FROM dbo.LOC (NOLOCK) WHERE LOC = @cLOC AND Facility = @cFacility)
         BEGIN
            SET @nErrNo = 62851
            SET @cErrMsg = rdt.rdtgetmessage( 62851, @cLangCode, 'DSP') --'Invalid LOC'
            GOTO Step_1_Fail
         END
      
      -- Validate SKU
     /* SELECT TOP 1
         @cSKU = SKU.SKU
      FROM dbo.SKU SKU (NOLOCK) 
      WHERE SKU.StorerKey = @cStorerKey 
         AND @cSKU IN (SKU.SKU, SKU.AltSKU, SKU.RetailSKU, SKU.ManufacturerSKU)

      IF @@ROWCOUNT = 0
      BEGIN
         -- Search UPC
         SELECT TOP 1
            @cSKU = UPC.SKU
         FROM dbo.UPC UPC (NOLOCK) 
         WHERE UPC.StorerKey = @cStorerKey
            AND UPC.UPC = @cSKU

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 62852
            SET @cErrMsg = rdt.rdtgetmessage( 62852, @cLangCode, 'DSP') --'Invalid SKU'
            GOTO Step_1_Fail
         END
      END */

      -- Validate QTY
      SET @cQTY = CAST(@nQTY as CHAR)
      IF @cQTY <> '' AND @cQTY IS NOT NULL
         IF rdt.rdtIsValidQTY( @cQTY, 0) = 0
         BEGIN
            SET @nErrNo = 60676
            SET @cErrMsg = rdt.rdtgetmessage( 60676, @cLangCode, 'DSP') --'Invalid QTY'
            GOTO Step_1_Fail
         END
         ELSE
            SET @nQTY = CAST( @cQTY AS INT)
            
      -- Validate lottable04
/*      IF @cLottable04 <> '' AND @cLottable04 IS NOT NULL
         IF IsValidDate( @cLottable04, 0) = 0
         BEGIN
            SET @nErrNo = 60676
            SET @cErrMsg = rdt.rdtgetmessage( 60676, @cLangCode, 'DSP') --'Invalid L04'
            GOTO Step_1_Fail
         END
         ELSE
            SET @dLottable04 = CAST( @cLottable04 AS DATETIME)
            
      -- Validate lottable05
      IF @cLottable05 <> '' AND @cLottable05 IS NOT NULL
         IF IsValidDate( @cLottable05, 0) = 0
         BEGIN
            SET @nErrNo = 60676
            SET @cErrMsg = rdt.rdtgetmessage( 60676, @cLangCode, 'DSP') --'Invalid L05'
            GOTO Step_1_Fail
         END
         ELSE
            SET @dLottable05 = CAST( @cLottable05 AS DATETIME)
*/

      -- Check if next screen exists
      IF EXISTS( SELECT 1 FROM rdt.rdtScn WHERE Scn = (@nScn + 1) AND Lang_Code = @cLangCode)
         -- Go to next screen
         SET @nScn = @nScn + 1 
      ELSE
      BEGIN
         -- Last screen, save
         INSERT INTO rdt.rdtDataCapture (StorerKey, Facility, V_Zone, V_Loc, V_SKU, V_UOM, V_ID, V_ConsigneeKey, V_CaseID, V_SKUDescr, V_QTY, V_UCC, V_Lottable01, V_Lottable02, V_Lottable03, V_Lottable04, V_Lottable05, V_String1, V_String2, V_String3, V_String4, V_String5, V_String6, V_String7, V_String8, V_String9, V_String10)
         VALUES (@cStorerKey, @cFacility, @cZone, @cLoc, @cSKU, @cUOM, @cID, @cConsigneeKey, @cCaseID, @cSKUDescr, @nQTY, @cUCC, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, @cString1, @cString2, @cString3, @cString4, @cString5, @cString6, @cString7, @cString8, @cString9, @cString10)
         
         -- Initiate var
         SET @cZone         = ''
         SET @cLoc          = ''
         SET @cSKU          = ''
         SET @cUOM          = ''
         SET @cID           = ''
         SET @cConsigneeKey = ''
         SET @cCaseID       = ''
         SET @cSKUDescr     = ''
         SET @nQTY          = 0
         SET @cUCC          = ''
         SET @cLottable01   = ''
         SET @cLottable02   = ''
         SET @cLottable03   = ''
         SET @dLottable04   = NULL
         SET @dLottable05   = NULL
         SET @cString1      = ''
         SET @cString2      = ''
         SET @cString3      = ''
         SET @cString4      = ''
         SET @cString5      = ''
         SET @cString6      = ''
         SET @cString7      = ''
         SET @cString8      = ''
         SET @cString9      = ''
         SET @cString10     = ''

         -- Back to 1st screen 
         SET @nScn = 1020
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Check if prev screen exists
      IF EXISTS( SELECT 1 FROM rdt.rdtScn WHERE Scn = (@nScn - 1) AND Lang_Code = @cLangCode)
         -- Go to prev screen
         SET @nScn = @nScn - 1
      ELSE
      BEGIN
         -- Back to menu
         SET @nFunc = @nMenu
         SET @nScn  = @nMenu
         SET @nStep = 0
         SET @cOutField01 = ''
      END
   END
   GOTO Quit

   Step_1_Fail:
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

      V_Zone         = @cZone, 
      V_Loc          = @cLoc, 
      V_SKU          = @cSKU, 
      V_UOM          = @cUOM, 
      V_ID           = @cID, 
      V_ConsigneeKey = @cConsigneeKey, 
      V_CaseID       = @cCaseID, 
      V_SKUDescr     = @cSKUDescr, 
      V_QTY          = @nQTY, 
      V_UCC          = @cUCC,  
      V_Lottable01   = @cLottable01, 
      V_Lottable02   = @cLottable02, 
      V_Lottable03   = @cLottable03, 
      V_Lottable04   = @dLottable04, 
      V_Lottable05   = @dLottable05, 
      V_String1      = @cString1, 
      V_String2      = @cString2, 
      V_String3      = @cString3, 
      V_String4      = @cString4, 
      V_String5      = @cString5, 
      V_String6      = @cString6, 
      V_String7      = @cString7, 
      V_String8      = @cString8, 
      V_String9      = @cString9, 
      V_String10     = @cString10, 
      O_Field01      = @cOutField01

   WHERE Mobile = @nMobile
END

GO