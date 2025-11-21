SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_UCCDataPatch                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: RDT Replenishment                                           */
/*          SOS79779 - UCC Data Patching                                */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2007-06-29 1.0  jwong    Created                                     */
/* 2016-09-30 1.1  Ung      Performance tuning                          */   
/* 2018-11-21 1.2  Gan      Performance tuning                          */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_UCCDataPatch] (
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
   @cChkFacility NVARCHAR( 5),
   @nSKUCnt      INT, 
   @nRowCount    INT,
   @cXML         NVARCHAR( 4000) -- To allow double byte data for e.g. SKU desc

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

   @cLot        NVARCHAR( 10),
   @cLoc        NVARCHAR( 10),
   @cUCC        NVARCHAR( 20),
   @cUCC_Facility NVARCHAR( 5), -- UCC Facility
   @cUCC_Status NVARCHAR( 1),   -- UCC Status
   @cLottable02 NVARCHAR( 18),
   @cID         NVARCHAR( 18),
   @cUCC_QTY    NVARCHAR( 5),
   @cUCC_SKU    NVARCHAR(20),
   @cSKU        NVARCHAR(20),
   @cDesc       NVARCHAR(60),
   @cPQIndicator NVARCHAR(10),
   @cPPK        NVARCHAR(30),
   @nUCC_Cnt    INT,        -- UCC Cnt
   @nUCC_QTY    INT,        -- UCC QTY
   @nQTY        INT,        -- QTY key-in
   @nLLI_QTY    INT,        -- LotxLocXID QTY

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
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @nMenu       = Menu,
   @cLangCode   = Lang_code,

   @cStorerKey  = StorerKey,
   @cFacility   = Facility,

   @cLot        = V_Lot,
   @cLoc        = V_LOC,
   @cID         = V_ID,
   @cLottable02 = V_Lottable02,
   @cSKU        = V_SKU, 
   @cDesc       = V_SkuDescr,       
   @cPQIndicator= ISNULL(RTRIM(V_String8),'0'),
   @cPPK        = ISNULL(RTRIM(V_String9),'0'),
   
   @nQTY        = V_Integer1,
   @nUCC_QTY    = V_Integer2,
   @nLLI_QTY    = V_Integer3,

  -- @nQTY        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY,  5), 0) = 1 THEN LEFT( V_QTY,  5) ELSE 0 END,
   @cUCC        = V_UCC,
  -- @nUCC_QTY    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String1,  5), 0) = 1 THEN LEFT( V_String1,  5) ELSE 0 END,
  -- @nLLI_QTY    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String2,  5), 0) = 1 THEN LEFT( V_String2,  5) ELSE 0 END,

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

-- Redirect to respective screen
IF @nFunc = 899 -- UCC Data Patch
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 899
   IF @nStep = 1 GOTO Step_1   -- Scn = 1471. Lottable02
   IF @nStep = 2 GOTO Step_2   -- Scn = 1472. Loc
   IF @nStep = 3 GOTO Step_3   -- Scn = 1473. UCC
   IF @nStep = 4 GOTO Step_4   -- Scn = 1474. CREATE NEW UCC?
   IF @nStep = 5 GOTO Step_5   -- Scn = 1475. UCC, SKU/UPC
   IF @nStep = 6 GOTO Step_6   -- Scn = 1476. QTY
   IF @nStep = 7 GOTO Step_7   -- Scn = 1477. Display all info
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 899)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 1471
   SET @nStep = 1

   -- Init var
   SET @nQTY = 0

   -- Prep next screen var
   SET @cLottable02 = ''
   SET @cOutField01 = '01000' -- Default as '01000'
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 1225
   Lottable02: (Field01, input01)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLottable02 = @cInField01

      -- Prep next screen var
      SET @cOutField01 = @cLottable02
      SET @cOutField02 = '' -- LOC

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cLottable02 = ''
      SET @cOutField01 = '01000' -- Default = '01000'
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen = 1472
   LOTTABLE02 (Field01)
   LOC:  (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLoc = @cInField02

      IF @cLoc = ''
      BEGIN
         SET @nErrNo = 63351
         SET @cErrMsg = rdt.rdtgetmessage( 63351, @cLangCode, 'DSP') --'LOC needed'
         GOTO Step_2_Fail
      END

      -- Validate if Loc exists
      SET @cUCC_Facility = ''

      SELECT @cUCC_Facility = Facility FROM dbo.LOC WITH (NOLOCK) WHERE Loc = @CLoc
      IF ISNULL(@cUCC_Facility, '') = ''
      BEGIN
         SET @nErrNo = 63351
         SET @cErrMsg = rdt.rdtgetmessage( 63352, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_2_Fail
      END

      IF @cUCC_Facility <> @cFacility
      BEGIN
         SET @nErrNo = 63352
         SET @cErrMsg = rdt.rdtgetmessage( 63353, @cLangCode, 'DSP') --'Diff facility'
         GOTO Step_2_Fail       
      END


      -- Prep next screen var
      SET @cOutField01 = @cLottable02
      SET @cOutField02 = @cLoc
      SET @cOutField03 = '' -- Qty

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
      SET @cLoc = ''
      SET @cOutField01 = '01000'
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cLoc = ''
      SET @cOutField02 = '' -- LOC
   END
END
GOTO Quit


/********************************************************************************
Step 3. Screen 1473
   LOTTABLE02   (Field01)
   LOC          (Field02)
   UCC          (Field03, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1      -- Yes OR Send
   BEGIN
      SET @cUCC = @cInField03

      IF @cUCC = '' OR @cUCC IS NULL
      BEGIN
         SET @nErrNo = 63368
         SET @cErrMsg = rdt.rdtgetmessage( 63368, @cLangCode, 'DSP') --'UCC needed'
         GOTO Step_3_Fail
      END

      SELECT @nUCC_Cnt = COUNT(1) 
      FROM dbo.UCC WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND UCCNo = @cUCC

      -- Check if UCC exists
      IF @nUCC_Cnt = 0
      BEGIN
         --go to prompt screen 'Create New UCC?'
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1    
         
         --prepare next screen variable
         SET @cOutField01 = '' --option
         GOTO QUIT
      END

      -- Check if UCC is MultiSKU/PO
      IF @nUCC_Cnt > 1
      BEGIN
         SET @nErrNo = 63354
         SET @cErrMsg = rdt.rdtgetmessage( 63354, @cLangCode, 'DSP') --'UCCMultiSKU/PO'
         GOTO Step_3_Fail
      END

      -- Check UCC status
      SELECT 
         @cUCC_Status = Status, 
         @nUCC_QTY = QTY,
         @cUCC_SKU = SKU
      FROM dbo.UCC WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
            AND UCCNo = @cUCC

      IF @cUCC_Status <> '2'
      BEGIN
         SET @nErrNo = 63355
         SET @cErrMsg = rdt.rdtgetmessage( 63355, @cLangCode, 'DSP') --'Invalid Status'
         GOTO Step_3_Fail      
      END

      IF RDT.rdtIsValidQTY( @nUCC_QTY, 0) = 0
      BEGIN
         SET @nErrNo = 63356
         SET @cErrMsg = rdt.rdtgetmessage( 63356, @cLangCode, 'DSP') --'Invalid UCCQTY'
         GOTO Step_3_Fail
      END

      SET @nLLI_QTY = 0
      SELECT 
         @cLot = LLI.Lot, 
         @cID = LLI.ID, 
         @nLLI_QTY = (LLI.Qty - LLI.QtyPicked)  - SUM(ISNULL(UCC.Qty, 0))
      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
         INNER JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.StorerKey = LA.StorerKey AND LLI.LOT = LA.Lot)   
         LEFT OUTER JOIN dbo.UCC UCC WITH (NOLOCK) ON (LLI.Lot = UCC.Lot AND LLI.loc = UCC.Loc AND LLI.ID = UCC.ID
            AND UCC.Status = 1) 
      WHERE  LLI.StorerKey = @cStorerKey 
         AND LLI.SKU = @cUCC_SKU
         AND LLI.Loc = @cLoc
         AND LA.Lottable02 = @cLottable02
      GROUP BY LLI.LOT, LLI.LOC, LLI.ID, LLI.Qty, LLI.QtyPicked
      HAVING (LLI.Qty - LLI.QtyPicked) - SUM(ISNULL(UCC.Qty, 0)) >= @nUCC_QTY
      ORDER BY LLI.Lot DESC

      IF @nLLI_QTY >= @nUCC_QTY
      BEGIN
         BEGIN TRAN

         UPDATE dbo.UCC WITH (ROWLOCK) SET 
            Lot = @cLot, 
            Loc = @cLoc, 
            ID = @cID, 
            QTY = @nUCC_QTY, 
            Status = 1,
   			EditDate = GETDATE(),
   			EditWho = sUSER_sNAME()  
         WHERE StorerKey = @cStorerKey AND UCCNo = @cUCC

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN

            SET @nErrNo = 63357
            SET @cErrMsg = rdt.rdtgetmessage( 63357, @cLangCode, 'DSP') --'Upd Failed'
            GOTO Quit
         END

         COMMIT TRAN
      END
      ELSE
      BEGIN
         SET @nErrNo = 63358
  SET @cErrMsg = rdt.rdtgetmessage( 63358, @cLangCode, 'DSP') --'NoInv2OffSet'
         GOTO Step_3_Fail
      END         

      -- Prep next screen var
      SET @cOutField01 = @cLottable02
      SET @cOutField02 = @cLoc
      SET @cOutField03 = ''
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
   -- Prepare prev screen
      SET @cOutField01 = @cLottable02
      SET @cOutField02 = '' -- LOC
      SET @cLOC = ''

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOutField01 = @cLottable02
      SET @cOutField02 = @cLoc
      SET @cOutField03 = '' -- UCC
   END
END
GOTO Quit

/********************************************************************************
Step 4. Screen 1474
   Create new ucc?
   1=YES 
   2=NO
   OPTION: (field01, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1      -- ENTER
   BEGIN
      --screen mapping
      DECLARE @cOption NVARCHAR( 1)
      SET @cOption = @cInField01

      --check if option is blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 63359
         SET @cErrMsg = rdt.rdtgetmessage(63359, @cLangCode, 'DSP') --Option needed
         GOTO Step_4_Fail      
      END      
      
      --invalid option other than '1' or '2'
      IF (@cOption <> '1' AND @cOption <> '2') 
	   BEGIN
         SET @nErrNo = 63360
         SET @cErrMsg = rdt.rdtgetmessage(63360, @cLangCode, 'DSP') --Invalid option
         GOTO Step_4_Fail      
      END      
      
      IF @cOption = '1' --Go to next screen
      BEGIN
         --prepare next screen var
         SET @cOutField01 = @cUCC
         SET @cOutField02 = '' -- SKU
   
         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1 

         GOTO Quit
      END
   END
     
   --prepare previous screen variable
   SET @cOutField01 = @cLottable02
   SET @cOutField02 = @cLOC
   SET @cOutField03 = '' -- UCC
            
   -- Go to previous screen
   SET @nScn = @nScn - 1
   SET @nStep = @nStep - 1 
   
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cOutField01 = ''--option
      SET @cOption = ''
   END
END
GOTO Quit


/********************************************************************************
Step 5. (screen  = 1475) UCC, SKU/UPC
   UCC:     (field01)
   SKU/UPC: (field02, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1      -- Yes OR Send
   BEGIN
      --screen mapping
      SET @cSku = @cInField02

      --check if sku is null
      IF @cSku = '' OR @cSKu IS NULL
      BEGIN
         SET @nErrNo = 63361
         SET @cErrMsg = rdt.rdtgetmessage(63361, @cLangCode, 'DSP') --SKU required
         GOTO Step_5_Fail         
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
         SET @nErrNo = 63362
         SET @cErrMsg = rdt.rdtgetmessage( 63362, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_5_Fail
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 63363
         SET @cErrMsg = rdt.rdtgetmessage( 63363, @cLangCode, 'DSP') --'SameBarCodeSKU'
         GOTO Step_5_Fail
      END

      --get some value to be use in below part
      SELECT   
         @cDesc = DESCR, 
         @cPPK = PREPACKINDICATOR, 
         @cPQIndicator = PackQtyIndicator
      FROM dbo.Sku WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU    

      --prepare next screen variable
      SET @cOutField01 = @cUCC
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cDesc,  1,20)
      SET @cOutField04 = SUBSTRING( @cDesc, 21,20)
      SET @cOutField05 = CASE WHEN IsNULL(@cPPK, '') = '' THEN '0' ELSE  @cPPK END +
	                      '/' +
	                      CASE WHEN IsNULL(@cPQIndicator, '') = '' THEN '0' ELSE @cPQIndicator END
      SET @cOutField10 = ''--qty

      --go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1 
      
   END
     
   IF @nInputKey = 0 -- Esc 
   BEGIN
      --prepare previous screen variable
      SET @cOutField01 = @cLottable02
      SET @cOutField02 = @cLOC
      SET @cOutField03 = '' -- UCC

      -- Go to previous screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
 
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cSku = ''
      SET @cOutField02 = '' --sku
   END
END
GOTO Quit

/********************************************************************************
Step 9. Screen 1476
   UCC:        (field01)        
   SKU/UPC:    (field02)
   SKU Desc1:  (field03)
   SKU Desc2:  (field04)
   PPK/DU:     (field05)
   QTY:        (field10, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1      -- ENTER
   BEGIN
      --screen mapping
      DECLARE @cQTY NVARCHAR( 5)
      SET @cQty = @cInField10

      --check if qty is null
      IF @cQty = '' OR @cQty IS NULL
      BEGIN
         SET @nErrNo = 63364
         SET @cErrMsg = rdt.rdtgetmessage(63364, @cLangCode, 'DSP') --QTY required
         GOTO Step_6_Fail      
      END

      --check if qty is valid
      IF rdt.rdtIsValidQty(@cQty, 1) = 0 
      BEGIN
         SET @nErrNo = 63365
         SET @cErrMsg = rdt.rdtgetmessage(63365, @cLangCode, 'DSP') --Invalid Qty
         GOTO Step_6_Fail      
      END
      SET @nQTY = CAST( @cQTY AS INT)

      --prepare next screen variable
      SET @cOutField01 = @cUCC
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cDesc,  1,20)
      SET @cOutField04 = SUBSTRING( @cDesc, 21,20)
      SET @cOutField05 = CASE WHEN IsNULL(@cPPK, '') = '' THEN '0'  ELSE @cPPK END +
	                   '/' +
	                      CASE WHEN IsNULL(@cPQIndicator, '') = '' THEN '0' ELSE @cPQIndicator END
      SET @cOutField10 = @cQty

      --go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1 
      
   END

   IF @nInputKey = 0 -- Esc
   BEGIN
      SET @cOutField01 = @cUCC
      SET @cOutField02 = '' --sku
                  
      -- Go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1  
   END
   GOTO Quit

   Step_6_Fail:
   BEGIN
      SET @cOutField10 = @cQty
   END

END
GOTO Quit


/********************************************************************************
Step 7. Screen 1477
   UCC:        (field01)        
   SKU/UPC:    (field02)
   SKU Desc1:  (field03)
   SKU Desc2:  (field04)
   PPK/DU:     (field05)
   QTY:        (field10)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1      -- ENTER
   BEGIN
      SET @nLLI_QTY = 0
      SELECT 
         @cLot = LLI.Lot, 
         @cID = LLI.ID, 
         @nLLI_QTY = (LLI.Qty - LLI.QtyAllocated)  - SUM(ISNULL(UCC.Qty, 0))
      FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
         INNER JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.StorerKey = LA.StorerKey AND LLI.LOT = LA.Lot)   
         LEFT OUTER JOIN dbo.UCC UCC WITH (NOLOCK) ON (LLI.Lot = UCC.Lot AND LLI.loc = UCC.Loc AND LLI.ID = UCC.ID
            AND UCC.Status = 1) 
      WHERE  LLI.StorerKey = @cStorerKey 
         AND LLI.SKU = @cSKU
         AND LLI.Loc = @cLoc
         AND LA.Lottable02 = @cLottable02
      GROUP BY LLI.LOT, LLI.LOC, LLI.ID, LLI.Qty, LLI.QtyAllocated
      HAVING (LLI.Qty - LLI.QtyAllocated) - SUM(ISNULL(UCC.Qty, 0)) >= @nQTY
      ORDER BY LLI.Lot DESC

      IF @nLLI_QTY >= @nQTY
      BEGIN
         BEGIN TRAN

         INSERT INTO dbo.UCC (UCCNo, ExternKey, StorerKey, SKU, QTY, LOT, LOC, ID, Status)
         VALUES (@cUCC, '', @cStorerKey, @cSKU, @nQTY, @cLOT, @cLOC, @cID, '1')

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN

            SET @nErrNo = 63366
            SET @cErrMsg = rdt.rdtgetmessage( 63366, @cLangCode, 'DSP') --'Upd Failed'
            GOTO Quit
         END

         COMMIT TRAN
      END
      ELSE
      BEGIN
         SET @nErrNo = 63367
         SET @cErrMsg = rdt.rdtgetmessage( 63367, @cLangCode, 'DSP') --'NoInv2OffSet'
         GOTO Step_7_Fail
      END         
      
      --prepare next screen var
      SET @cOutField01 = @cLottable02
      SET @cOutField02 = @cLOC
      SET @cOutField03 = '' -- UCC

      --go to UCC screen 
      SET @nScn = @nScn - 4
      SET @nStep = @nStep - 4 
   END

   IF @nInputKey = 0 -- Esc 
   BEGIN    
      --prepare previous screen
      SET @cOutField01 = @cUCC
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cDesc,  1, 20)
      SET @cOutField04 = SUBSTRING( @cDesc, 21, 20)
      SET @cOutField05 = CASE WHEN IsNULL(@cPPK, '') = '' THEN '0'  ELSE @cPPK END +
	                      '/' +
	                    CASE WHEN IsNULL(@cPQIndicator, '') = '' THEN '0' ELSE @cPQIndicator END
      SET @cOutField10 = @cQty
                 
      -- Go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1 

   END
   GOTO Quit

   Step_7_Fail:
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

      V_LOT     = @cLOT,
      V_LOC     = @cLoc,
      V_ID      = @cID, 
      V_Lottable02 = @cLottable02,
      --V_QTY     = @nQTY,
      V_SKU     = @cSKU, 
      V_SkuDescr = @cDesc,    
      V_String8 = @cPQIndicator,
      V_String9 = @cPPK,
      V_UCC     = @cUCC, 
      --V_String1 = @nUCC_QTY,
      --V_String2 = @nLLI_QTY,
      
      V_Integer1 = @nQTY,
      V_Integer2 = @nUCC_QTY,
      V_Integer3 = @nLLI_QTY,

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