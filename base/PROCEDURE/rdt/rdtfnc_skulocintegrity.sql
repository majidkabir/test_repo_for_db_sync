SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_SKULOCIntegrity                              */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Inquiry                                                     */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2010-06-04 1.0  SHONG      Created                                   */
/* 2011-04-21 1.1  SHONG      Adding Qty Counted			               */
/* 2016-08-12 1.2  SHONG      SOS# 375153 Minus Qty Picked              */
/* 2016-09-30 1.3  Ung        Performance tuning                        */
/* 2018-11-14 1.4  TungGH     Performance                               */   
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_SKULOCIntegrity] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- Misc variable
DECLARE
   @cPUOM_Desc  NVARCHAR( 5), -- Preferred UOM desc
   @cMUOM_Desc  NVARCHAR( 5), -- Master unit desc

   @nQty INT, -- QTY avail in preferred UOM
   @nMQTY_Avail INT, -- QTY avail in master UOM
   @nPQTY_Alloc INT, -- QTY alloc in preferred UOM
   @nMQTY_Alloc INT, -- QTY alloc in master UOM
   @nPUOM_Div   INT, -- UOM divider

   @cColor  NVARCHAR( 10),
   @cStyle  NVARCHAR( 20),
   @cBOMSKU NVARCHAR( 18) ,
   @cSize   NVARCHAR(  5),
   @nSKUCount INT, 
   @nQtyCount INT,
   @cQtyCnt   NVARCHAR(20) 

-- RDT.RDTMobRec variable
DECLARE
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,
   @bSuccess   INT, 

   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5),
   @cUserName  NVARCHAR( 18),

   @cLOT       NVARCHAR( 10),
   @cLOC       NVARCHAR( 10),
   @cID        NVARCHAR( 18),
   @cSKU       NVARCHAR( 20),
   @cSKUDescr  NVARCHAR( 60),
   @cPUOM      NVARCHAR( 1), -- Prefer UOM
   @nCaseCnt   INT, 
   @nCartons   INT,
   @nUnits     INT,

   @nTotalRec    INT, 
   @nCurrentRec  INT, 

   @cInquiry_LOC NVARCHAR( 10), 
   @cInquiry_ID  NVARCHAR( 18), 
   @cEntryValue  NVARCHAR( 20), 

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
   @cFieldAttr15 NVARCHAR( 1)

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

   @cLOT       = V_LOT,
   @cLOC       = V_LOC,
   @cID        = V_ID,
   @cSKU       = V_SKU,
   @cPUOM      = V_UOM,
   
   @nQty       = V_QTY,

   @cBOMSKU = V_String1, 
   @cStyle  = V_String2, 
   @cColor  = V_String3, 
   @cSize   = V_String4,
   
   @nCartons     = V_Integer1,
   @nUnits       = V_Integer2,
   @nTotalRec    = V_Integer3,
   @nCurrentRec  = V_Integer4,

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

   @cFieldAttr01 = FieldAttr01,    @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 = FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 = FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 = FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 = FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 = FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 = FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 = FieldAttr15

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 886 -- Inquiry
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Inquiry
   IF @nStep = 1 GOTO Step_1   -- Scn = 1490. LOC
   IF @nStep = 2 GOTO Step_2   -- Scn = 1491. Result screen
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 555. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 1490
   SET @nStep = 1

   -- Initiate var
   SET @cInquiry_LOC = ''
   SET @cInquiry_ID = ''
   SET @cSKU = ''
   SET @cSKUDescr = ''

   SET @nTotalRec = 0
   SET @nCurrentRec = 0

   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep

   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M (NOLOCK)
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

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


   -- Init screen
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''
END
GOTO Quit

/********************************************************************************
Step 1. Scn = 1490. LOC, ID, SKU screen
   LOC (field01)
   ID  (field02)
   SKU (field03)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cInquiry_LOC = @cInField01

      -- Get no field keyed-in
      DECLARE @i INT
      SET @i = 0
      IF @cInquiry_LOC <> '' AND @cInquiry_LOC IS NOT NULL SET @i = @i + 1

      IF LEN(@cInquiry_LOC) = 0 
      BEGIN
         SET @nErrNo = 70316
         SET @cErrMsg = rdt.rdtgetmessage( 70316, @cLangCode, 'DSP') --'Value needed'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- By LOC
      IF @cInquiry_LOC <> '' AND @cInquiry_LOC IS NOT NULL
      BEGIN
         DECLARE @cChkFacility NVARCHAR( 5)
         SELECT @cChkFacility = Facility
         FROM dbo.LOC (NOLOCK) 
         WHERE LOC = @cInquiry_LOC

     -- Validate LOC
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 70317
            SET @cErrMsg = rdt.rdtgetmessage( 70317, @cLangCode, 'DSP') --'Invalid LOC'
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 70318
            SET @cErrMsg = rdt.rdtgetmessage( 70318, @cLangCode, 'DSP') --'Diff facility'
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END
      END

      -- Get total record
      SET @nTotalRec = 0
      IF @cInquiry_LOC <> ''
      BEGIN
         SELECT @nTotalRec = COUNT(DISTINCT LLI.SKU) 
         FROM dbo.LOTxLOCxID LLI (NOLOCK)
            INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (LLI.LOT = LA.LOT)
            INNER JOIN dbo.LOC LOC (NOLOCK) ON (LOC.LOC = LLI.LOC)
            INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
            INNER JOIN dbo.Pack Pack (nolock) ON (SKU.PackKey = Pack.PackKey)
         WHERE LOC.Facility = @cFacility
            AND (LLI.QTY - LLI.QTYPicked) > 0
            AND LLI.LOC = @cInquiry_LOC
         GROUP BY LLI.LOC, LLI.SKU, SKU.Descr,
            SKU.Size, SKU.Style, SKU.Color, LA.Lottable03, SKU.StorerKey
      END
   
      IF @nTotalRec = 0
      BEGIN
         SELECT @nTotalRec = 1
         SET @cLOC = @cInquiry_LOC
         SET @cID  = ''
         SET @cSKU = ''
         SET @cSKUDescr = 'Empty Location'
         SET @cSize = ''
         SET @cStyle = ''
         SET @cColor = ''
         SET @cBOMSKU = ''
         SET @cStorerKey = ''
         SET @nQty=0
         SET @nCaseCnt = 0 
         SET @nCartons = 0
         SET @nUnits   = 0         

      END
      ELSE IF @cInquiry_LOC <> ''
      BEGIN
         SET @cLOC = ''
         SET @cID  = ''
         SET @cSKU = ''
         SET @cSKUDescr = ''
         SET @cSize = ''
         SET @cStyle = ''
         SET @cColor = ''
         SET @cBOMSKU = ''
         SET @cStorerKey = ''
         SET @nQty=0
         SET @nCaseCnt = 0 
         SET @nCartons = 0
         SET @nUnits   = 0

         SELECT TOP 1
            @cLOC = LLI.LOC,
            @cID  = '',
            @cSKU = LLI.SKU,
            @cSKUDescr = SKU.Descr,
            @cSize     = SKU.Size,
            @cStyle    = SKU.Style,
            @cColor    = SKU.Color,
            @cBOMSKU   = LA.Lottable03,
            @cStorerKey = SKU.StorerKey,
            @nQty = SUM(LLI.Qty - LLI.QtyPicked)  -- SOS375153
         FROM dbo.LOTxLOCxID LLI (NOLOCK)
            INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (LLI.LOT = LA.LOT)
            INNER JOIN dbo.LOC LOC (NOLOCK) ON (LOC.LOC = LLI.LOC)
            INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
            INNER JOIN dbo.Pack Pack (nolock) ON (SKU.PackKey = Pack.PackKey)
         WHERE LOC.Facility = @cFacility
            AND (LLI.QTY - LLI.QTYPicked) > 0
            AND LLI.LOC = @cInquiry_LOC
         GROUP BY LLI.LOC, LLI.SKU, SKU.Descr,
            SKU.Size, SKU.Style, SKU.Color, LA.Lottable03, SKU.StorerKey
         ORDER BY LLI.SKU  -- Needed for looping
         
         SET @nCaseCnt=0
         SELECT TOP 1 @nCaseCnt = ISNULL(PACK.CaseCnt,0)
         FROM dbo.UPC UPC WITH (NOLOCK) 
         JOIN dbo.PACK PACK WITH (NOLOCK) ON PACK.PackKey = UPC.PackKey 
         WHERE UPC.StorerKey = @cStorerKey 
         AND   UPC.SKU = @cBOMSKU         
         AND  UPC.UOM = 'CS'
         
         IF ISNULL(RTRIM(@cBOMSKU),'') = '' 
         BEGIN
            SET @cBOMSKU = @cSKU 
         END
         
         IF @nCaseCnt = 0 
         BEGIN
            SET @nCartons = 0
            SET @nUnits = @nQty
         END
         ELSE
         BEGIN
            SET @nCartons = FLOOR(@nQty / @nCaseCnt)
            SET @nUnits   = @nQty - (@nCartons * @nCaseCnt)
         END
      END
      
      -- Prep next screen var
      SET @nCurrentRec = 1
      SET @cOutField01 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
      SET @cOutField02 = @cLOC
      SET @cOutField03 = @cBOMSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField05 = @cStyle 
      SET @cOutField06 = @cColor
      SET @cOutField07 = @cSize
      
      SET @cOutField08 = @cID
      SET @cOutField09 = CONVERT(VARCHAR(10), 
                              CASE WHEN rdt.rdtIsValidQTY( @nCartons, 0) = 1 THEN @nCartons ELSE 0 END)
      SET @cOutField10 = CONVERT(VARCHAR(10), 
                              CASE WHEN rdt.rdtIsValidQTY( @nUnits, 0) = 1 THEN @nUnits ELSE 0 END)

      SET @cInField01 = ''

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
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
      -- Reset this screen var
      SET @cInquiry_LOC = '' 
      
      SELECT 
      @cOutField01   = '',
      @cOutField02   = '',
      @cOutField03   = '',
      @cOutField04   = '',
      @cOutField05   = '',
      @cOutField06   = '',
      @cOutField07   = '',
      @cOutField08   = '',
      @cOutField09   = '',
      @cOutField10   = '',
      @cOutField11   = '',
      @cOutField12   = '',
      @cOutField13   = '',
      @cOutField14   = '',
      @cOutField15   = ''
   END
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 1491. Result screen
   Counter    (field01)
   LOC        (field02)
   BOM/SKU    (field03
   Desc       (field04)
   Style      (field05)
   Color      (field06)
   Size       (field07)
   ID         (field08)
   Carton/Unit(field09, 10)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1      -- Yes or Send
   BEGIN
      SET @nQtyCount = 0 
      
      SET @cEntryValue = @cInField11 

      SET @cQtyCnt = ISNULL(@cInField12,0)

      IF @cQtyCnt  = ''  
         SET @cQtyCnt  = '0' --'Blank taken as zero'
         
      IF rdt.rdtIsValidQTY( @cQtyCnt, 0) = 0 
      BEGIN      
         SET @nErrNo = 70271       
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty      
         GOTO Quit          
      END      
      
      SET @nQtyCount = CAST(@cQtyCnt AS INT)
      
      IF @cEntryValue = 'OKNB'
      BEGIN
         INSERT INTO dbo.SKUxLOCIntegrity (Facility, LOC, StorerKey, SKU, ParentSKU, ID, Qty, EntryValue, Code, QtyCount)
         VALUES(@cFacility, @cLOC, @cStorerKey, @cSKU, @cBOMSKU, @cID, @nQty, @cEntryValue, 'OK -NO BOM', @nQtyCount)
         
         GOTO NEXT_STEP
      END
      --12345678901234567890
      IF @cEntryValue = 'WSNB'
      BEGIN
         INSERT INTO dbo.SKUxLOCIntegrity (Facility, LOC, StorerKey, SKU, ParentSKU, ID, Qty, EntryValue, Code, QtyCount)
         VALUES(@cFacility, @cLOC, @cStorerKey, @cSKU, @cBOMSKU, @cID, @nQty, @cEntryValue, 'WRONG SKU - NO BOM', @nQtyCount)
         
         GOTO NEXT_STEP         
      END
      
      IF @cEntryValue = 'EMPTY'
      BEGIN
         INSERT INTO dbo.SKUxLOCIntegrity (Facility, LOC, StorerKey, SKU, ParentSKU, ID, Qty, EntryValue, Code, QtyCount)
         VALUES(@cFacility, @cLOC, @cStorerKey, @cSKU, @cBOMSKU, @cID, @nQty, @cEntryValue, 'EMPTY LOC', @nQtyCount)
         
         GOTO NEXT_STEP         
      END      

      IF ISNULL(@cEntryValue, '') = ''
      BEGIN
         SET @nErrNo = 70319
         SET @cErrMsg = rdt.rdtgetmessage( 70319, @cLangCode, 'DSP') -- 'BOM REQ'
         GOTO QUIT
      END

      -- Check if BOM exists in UPC table
      IF NOT EXISTS (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = @cEntryValue)
      BEGIN
         SELECT @nSKUCount = COUNT(*) 
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE SKU = @cEntryValue
         
         IF @nSKUCount = 0 
         BEGIN
            SET @nErrNo = 70320
            SET @cErrMsg = rdt.rdtgetmessage( 70320, @cLangCode, 'DSP') -- 'Invalid BOM/SKU'
            GOTO QUIT            
         END         
         
         IF @cEntryValue = @cSKU 
         BEGIN
            INSERT INTO dbo.SKUxLOCIntegrity (Facility, LOC, StorerKey, SKU, ParentSKU, ID, Qty, EntryValue, Code, QtyCount)
            VALUES(@cFacility, @cLOC, @cStorerKey, @cSKU, @cBOMSKU, @cID, @nQty, @cEntryValue, 'CORRECT SKU - NO BOM', @nQtyCount)
            
            GOTO NEXT_STEP             
         END
         ELSE
         BEGIN
            INSERT INTO dbo.SKUxLOCIntegrity (Facility, LOC, StorerKey, SKU, ParentSKU, ID, Qty, EntryValue, Code, QtyCount)
            VALUES(@cFacility, @cLOC, @cStorerKey, @cSKU, @cBOMSKU, @cID, @nQty, @cEntryValue, 'WRONG SKU - NO BOM', @nQtyCount)
            
            GOTO NEXT_STEP             
         END   
         
      END
      ELSE
      BEGIN
         IF EXISTS(SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = @cEntryValue AND SKU = @cBOMSKU)
         BEGIN
            INSERT INTO dbo.SKUxLOCIntegrity (Facility, LOC, StorerKey, SKU, ParentSKU, ID, Qty, EntryValue, Code, QtyCount)
            VALUES(@cFacility, @cLOC, @cStorerKey, @cSKU, @cBOMSKU, @cID, @nQty, @cEntryValue, 'OK', @nQtyCount)
            
            GOTO NEXT_STEP             
         END
         ELSE
         BEGIN
            INSERT INTO dbo.SKUxLOCIntegrity (Facility, LOC, StorerKey, SKU, ParentSKU, ID, Qty, EntryValue, Code, QtyCount)
            VALUES(@cFacility, @cLOC, @cStorerKey, @cSKU, @cBOMSKU, @cID, @nQty, @cEntryValue, 'WRONG BOM', @nQtyCount)
            
            GOTO NEXT_STEP             
         END            
      END     

      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '7', -- CC
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerKey,
         @cLocation     = @cLOC,
         @cID           = @cID,
         @cSKU          = @cSku,
         @cUOM          = 'CS',
         @nQTY          = @nQTY,
         @cRefNo1       = @cBOMSKU,
         @cRefNo2       = @cEntryValue,
         @nStep         = @nStep
      
      NEXT_STEP:
      IF @nCurrentRec = @nTotalRec
      BEGIN
         SET @nCurrentRec = 0
         SELECT 
         @cOutField01   = '',
         @cOutField02   = '',
         @cOutField03   = '',
         @cOutField04   = '',
         @cOutField05   = '',
         @cOutField06   = '',
         @cOutField07   = '',
         @cOutField08   = '',
         @cOutField09   = '',
         @cOutField10   = '',
         @cOutField11   = '',
         @cOutField12   = '',
         @cOutField13   = '',
         @cOutField14   = '',
         @cOutField15   = ''
         SET @cInField11 = ''

         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
         GOTO QUIT               
      END

      IF @cInquiry_LOC <> ''
      BEGIN
         SET @cID  = ''
         SET @cSKUDescr = ''
         SET @cSize = ''
         SET @cStyle = ''
         SET @cColor = ''
         SET @cBOMSKU = ''
         SET @cStorerKey = ''
         SET @nQty=0
         SET @nCaseCnt = 0 
         SET @nCartons = 0
         SET @nUnits   = 0

         SELECT TOP 1
            @cLOC = LLI.LOC,
            @cID  = '',
            @cSKU = LLI.SKU,
            @cSKUDescr = SKU.Descr,
            @cSize     = SKU.Size,
            @cStyle    = SKU.Style,
            @cColor    = SKU.Color,
            @cBOMSKU   = LA.Lottable03,
            @cStorerKey = SKU.StorerKey,
            @nQty = SUM(LLI.Qty)  
         FROM dbo.LOTxLOCxID LLI (NOLOCK)
            INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (LLI.LOT = LA.LOT)
            INNER JOIN dbo.LOC LOC (NOLOCK) ON (LOC.LOC = LLI.LOC)
            INNER JOIN dbo.SKU SKU (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
            INNER JOIN dbo.Pack Pack (nolock) ON (SKU.PackKey = Pack.PackKey)
         WHERE LOC.Facility = @cFacility
            AND (LLI.QTY - LLI.QTYPicked) > 0
            AND LLI.LOC = @cInquiry_LOC 
            AND LLI.SKU > @cSKU 
         GROUP BY LLI.LOC, LLI.SKU, SKU.Descr,
            SKU.Size, SKU.Style, SKU.Color, LA.Lottable03, SKU.StorerKey
         ORDER BY LLI.SKU  -- Needed for looping
         
         SET @nCaseCnt=0
         SELECT TOP 1 @nCaseCnt = ISNULL(PACK.CaseCnt,0)
         FROM dbo.UPC UPC WITH (NOLOCK) 
         JOIN dbo.PACK PACK WITH (NOLOCK) ON PACK.PackKey = UPC.PackKey 
         WHERE UPC.StorerKey = @cStorerKey 
         AND   UPC.SKU = @cBOMSKU         
         AND  UPC.UOM = 'CS'
         
         IF ISNULL(RTRIM(@cBOMSKU),'') = '' 
         BEGIN
            SET @cBOMSKU = @cSKU 
         END
         
         IF @nCaseCnt = 0 
         BEGIN
            SET @nCartons = 0
            SET @nUnits = @nQty
         END
         ELSE
         BEGIN
            SET @nCartons = FLOOR(@nQty / @nCaseCnt)
            SET @nUnits   = @nQty - (@nCartons * @nCaseCnt)
         END

         -- Prep next screen var
         SET @nCurrentRec = @nCurrentRec + 1
         SET @cOutField01 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
         SET @cOutField02 = @cLOC
         SET @cOutField03 = @cBOMSKU
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField05 = @cStyle 
         SET @cOutField06 = @cColor
         SET @cOutField07 = @cSize
         
         SET @cOutField08 = @cID
         SET @cOutField09 = CONVERT(VARCHAR(10), 
                                 CASE WHEN rdt.rdtIsValidQTY( @nCartons, 0) = 1 THEN @nCartons ELSE 0 END)
         SET @cOutField10 = CONVERT(VARCHAR(10), 
                                 CASE WHEN rdt.rdtIsValidQTY( @nUnits, 0) = 1 THEN @nUnits ELSE 0 END)

         SET @cInField11 = ''
      END 
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cInquiry_LOC = ''
      SELECT 
      @cOutField01   = '',
      @cOutField02   = '',
      @cOutField03   = '',
      @cOutField04   = '',
      @cOutField05   = '',
      @cOutField06   = '',
      @cOutField07   = '',
      @cOutField08   = '',
      @cOutField09   = '',
      @cOutField10   = '',
      @cOutField11   = '',
      @cOutField12   = '',
      @cOutField13   = '',
      @cOutField14   = '',
      @cOutField15   = ''
      SET @cInField11 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
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

      V_LOT     = @cLOT,
      V_LOC     = @cLOC,
      V_ID      = @cID,
      V_SKU     = @cSKU,
      V_UOM     = @cPUOM,
      
      V_QTY     = @nQty, 

      V_Lottable01 = @cColor, 
      V_Lottable02 = @cStyle, 
      V_Lottable03 = @cBOMSKU, 

      V_String1  = @cBOMSKU, 
      V_String2  = @cStyle, 
      V_String3  = @cColor, 
      V_String4  = @cSize,
      
      V_Integer1 = @nCartons,
      V_Integer2 = @nUnits, 
      V_Integer3 = @nTotalRec,
      V_Integer4 = @nCurrentRec,

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