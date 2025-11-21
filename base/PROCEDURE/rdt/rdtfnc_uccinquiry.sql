SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_UCCInquiry                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: UCC Inquiry                                                 */
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
/* Date        Rev  Author     Purposes                                 */
/* 17-May-2006 1.0  MaryVong   Created                                  */
/* 11-Apr-2007 1.1  MaryVong   1) Bug Fix - Display Facility            */
/*                             2) Always clear UCC field                */
/*                             3) If UCC is blank and SKU not blank, go */
/*                                to next page (allow to rotate)        */
/* 03-Sep-2008 1.2  Vicky      Modify to cater for SQL2005 (Vicky01)    */ 
/* 15-Apr-2009 1.3  Vicky      SOS#133275 - Add new UCC screen layout   */ 
/*                             (Vicky02)                                */
/* 25-Feb-2014 1.4  Ung        SOS303820 Fix new UCC screen status = 0  */
/* 08-Oct-2014 1.5  ChewKP     SOS#322322, Allow Inquiry UCC.Status = 0 */
/*                             Add ExtendedInfo SP (ChewKP01)           */
/* 30-Sep-2016 1.6  Ung        Performance tuning                       */
/* 08-Oct-2018 1.7  TungGH     Performance                              */   
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_UCCInquiry] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 1024) OUTPUT
)
AS
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @nRowCnt        INT

-- RDT.RDTMobRec variables
DECLARE
   @nFunc          INT,
   @nScn           INT,
   @nStep          INT,
   @cLangCode      NVARCHAR( 3),
   @nInputKey      INT,
   @nMenu          INT,

   @cStorer        NVARCHAR( 15),
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cUCC           NVARCHAR( 20),
   @cSKU           NVARCHAR( 20),
   @cSKUDescr      NVARCHAR( 60),
   @cUOM           NVARCHAR( 10),   -- Display NVARCHAR(3)
   @nQTY           NVARCHAR( 5), 
   @cLOT           NVARCHAR( 10),
   @cLOC           NVARCHAR( 10),
   @cID            NVARCHAR( 18),
   @cLottable1     NVARCHAR( 18),
   @cLottable2     NVARCHAR( 18),
   @cLottable3     NVARCHAR( 18),
   @dLottable4     DATETIME,
   @dLottable5     DATETIME,

   @cPackUOM       NVARCHAR( 10),
   @cPPK           NVARCHAR( 5),
   @cUCCFacility   NVARCHAR( 5),

   @cNewScnLayout  NVARCHAR( 1),  -- (Vicky02)
   @cUCCStatus     NVARCHAR( 1),  -- (Vicky02)
   @cExtendedInfoSP  NVARCHAR(20), -- (ChewKP02)
   @cSQL           NVARCHAR(1000),   
   @cSQLParam      NVARCHAR(1000),   
   @coFieled01     NVARCHAR(20),
   
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
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorer          = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cUCC             = V_UCC,
   @cSKU             = V_SKU,
   @cSKUDescr        = V_SKUDescr,
   @cUOM             = V_UOM,
   @nQTY             = V_QTY,
   @cLOT             = V_LOT,
   @cLOC             = V_LOC,
   @cID              = V_ID,
   @cLottable1       = V_Lottable01,
   @cLottable2       = V_Lottable02,
   @cLottable3       = V_Lottable03,
   @dLottable4       = V_Lottable04,
   @dLottable5       = V_Lottable05,

   @cPackUOM         = V_String1,
   @cPPK             = V_String2,
   @cUCCFacility     = V_String3,
   @cNewScnLayout    = V_String4, -- (Vicky02)
   @cUCCStatus       = V_String5, -- (Vicky02)
   @cExtendedInfoSP  = V_String6, -- (ChewKP01)
   
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

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 557 -- UCC inquiry
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0   -- Menu. Func = 557
   IF @nStep = 1  GOTO Step_1   -- Scn = 825. UCC, SKU, DESCR, QTY, UOM, PPK, LOTTABLE1..5
   IF @nStep = 2  GOTO Step_2   -- Scn = 826. STORER, FACILITY, LOC, ID
   -- (Vicky02) - Start
   IF @nStep = 3  GOTO Step_3   -- Scn = 827. UCC, SKU, DESCR, QTY, UOM, PPK, STATUS, LOC, LOT
   IF @nStep = 4  GOTO Step_4   -- Scn = 828. STORER, FACILITY, ID, LOTTABLE1..5
   -- (Vicky02) - End
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Func = 557
********************************************************************************/
Step_0:
BEGIN
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

      -- (Vicky02)
      SET @cNewScnLayout = ''
      SET @cNewScnLayout = rdt.RDTGetConfig( @nFunc, 'NewScnLayout', @cStorer) -- Parse in Function
      
      -- (ChewKP01)
      SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorer)
      IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
      
      
      SET @cSKU = '' -- Initalize SKU      

      IF @cNewScnLayout = '1' -- (Vicky02)
      BEGIN
          SET @nScn = 827
          SET @nStep = 3
      END
      ELSE
      BEGIN
          SET @nScn = 825
          SET @nStep = 1
      END

END
GOTO Quit


/************************************************************************************
Step 1. Scn = 825. UCC screen
   UCC       (field01)
   SKU       (field02)
   SKUDESC1  (field03)
   SKUDESC2  (field04)
   QTY       (field05)
   UOM       (field06)
   PPK       (field07)
   LOTTABLE1 (field08)
   LOTTABLE2 (field09)
   LOTTABLE3 (field10)
   LOTTABLE4 (field11)
   LOTTABLE5 (field12)
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUCC = @cInField01      
      
      -- If UCC and SKU are blank
      IF (@cUCC = '' OR @cUCC IS NULL) AND (@cSKU = '' OR @cSKU IS NULL)
      BEGIN
         SET @nErrNo = 66651
         SET @cErrMsg = rdt.rdtgetmessage( 66651, @cLangCode, 'DSP') --'UCC needed'
         GOTO Step_1_Fail
      END      

      -- If UCC not blank, retrieve data
      -- Else check if UCC is blank but SKU not blank, go to next page
      IF @cUCC <> '' AND @cUCC IS NOT NULL
      BEGIN
         -- (ChewKP01)
         SELECT
             @cUCCStatus = Status
         FROM dbo.UCC (NOLOCK)
         WHERE UCCNo = @cUCC
            AND StorerKey = @cStorer

         SELECT @nRowCnt = @@ROWCOUNT

         IF @nRowCnt = 0
         BEGIN
            SET @nErrNo = 66658
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCC not exist'
            GOTO Step_3_Fail
         END
         
         IF @cUCCStatus = '1' 
         BEGIN 
         
            SET @nErrNo = 0
            EXEC RDT.rdtIsValidUCC @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
               @cUCC, 
               @cStorer,
               '1'           -- Received status
   
            IF @nErrNo > 0
               GOTO Step_1_Fail
   
            SELECT
               @cSKU = SKU,
               @cLOT = LOT,
               @cLOC = LOC,
               @cID  = ID,
               @nQTY = Qty
            FROM dbo.UCC (NOLOCK)
            WHERE UCCNo = @cUCC
               AND StorerKey = @cStorer
               AND Status = '1'
   
            SELECT @nRowCnt = @@ROWCOUNT
   
            IF @nRowCnt = 1
            BEGIN
               -- Validate SKU
               IF @cSKU = '' OR @cSKU IS NULL
               BEGIN
                  SET @nErrNo = 66652
                  SET @cErrMsg = rdt.rdtgetmessage( 66652, @cLangCode, 'DSP') --'No SKU'
                  GOTO Step_1_Fail
               END
   
               -- Validate LOT
               IF @cLOT = '' OR @cLOT IS NULL
               BEGIN
                  SET @nErrNo = 66653
                  SET @cErrMsg = rdt.rdtgetmessage( 66653, @cLangCode, 'DSP') --'LOT bad'
                  GOTO Step_1_Fail
               END
               
               -- Get Lottables
               SELECT
                  @cLottable1 = Lottable01, 
                  @cLottable2 = Lottable02, 
                  @cLottable3 = Lottable03, 
                  @dLottable4 = Lottable04,
                  @dLottable5 = Lottable05
               FROM dbo.LotAttribute (NOLOCK)
               WHERE Lot = @cLOT
      
               -- Validate LOT
               IF @cLOC = '' OR @cLOC IS NULL
               BEGIN
                  SET @nErrNo = 66654
                  SET @cErrMsg = rdt.rdtgetmessage( 66654, @cLangCode, 'DSP') --'LOC bad'
                  GOTO Step_1_Fail
               END
   
               -- Validate Facility
               IF @cLOC <> '' AND @cLOC IS NOT NULL
               BEGIN
                  SELECT @cUCCFacility = Facility
                  FROM dbo.LOC (NOLOCK)
                  WHERE LOC = @cLOC
   
                  IF @cUCCFacility = '' OR @cUCCFacility IS NULL
                  BEGIN
                     SET @nErrNo = 66655
                     SET @cErrMsg = rdt.rdtgetmessage( 66655, @cLangCode, 'DSP') --'No facility'
                     GOTO Step_1_Fail
                  END
   
                  IF @cUCCFacility <> @cFacility
                  BEGIN
                     SET @nErrNo = 66656
                     SET @cErrMsg = rdt.rdtgetmessage( 66656, @cLangCode, 'DSP') --'Facility diff'
                     -- Display result and error message on screen
                     -- GOTO Step_1_Fail
                  END
               END             
         
--               -- Get SKUDescr, UOM, PPK
--               SELECT @cSKUDescr = SKU.Descr,
--                  @cPackUOM = ISNULL(RTRIM(LTRIM(PACK.PackUOM3)), ''), -- (Vicky01)
--                  @cPPK = CASE WHEN SKU.PrePackIndicator = '2' 
--                             THEN CAST( SKU.PackQtyIndicator AS NVARCHAR( 5)) 
--                             ELSE '' 
--                          END
--               FROM dbo.SKU SKU (NOLOCK)
--                  INNER JOIN dbo.PACK PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
--               WHERE SKU.StorerKey = @cStorer
--                  AND SKU.SKU = @cSKU
            END
         END
         ELSE 
         BEGIN
            SELECT
               @cSKU = SKU,
               @nQTY = Qty
            FROM dbo.UCC (NOLOCK)
            WHERE UCCNo = @cUCC
               AND StorerKey = @cStorer
            
               
         END
         
         -- Get SKUDescr, UOM, PPK
         SELECT @cSKUDescr = SKU.Descr,
            @cPackUOM = ISNULL(RTRIM(LTRIM(PACK.PackUOM3)), ''), -- (Vicky01)
            @cPPK = CASE WHEN SKU.PrePackIndicator = '2' 
                       THEN CAST( SKU.PackQtyIndicator AS NVARCHAR( 5)) 
                       ELSE '' 
                    END
         FROM dbo.SKU SKU (NOLOCK)
            INNER JOIN dbo.PACK PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
         WHERE SKU.StorerKey = @cStorer
            AND SKU.SKU = @cSKU
            
         -- (ChewKP01)


         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cOutField13 = ''
               
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cUCC, @coFieled01 OUTPUT'
               SET @cSQLParam =
                  '@nMobile    INT,           ' +
                  '@nFunc      INT,           ' +
                  '@cLangCode  NVARCHAR( 3),  ' +
                  '@nStep      INT,           ' + 
                  '@cStorer    NVARCHAR( 15), ' + 
                  '@cUCC       NVARCHAR( 20), ' + 
                  '@coFieled01 NVARCHAR( 20) OUTPUT'
   
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cUCC, @coFieled01 OUTPUT
   
              
               -- Prepare extended fields
               IF @coFieled01 <> '' SET @cOutField13 = @coFieled01
            END
         END
         ELSE   
         BEGIN
            SET @cOutField13 = ''      
         END
   
         -- Prepare next screen var
         SET @cOutField01 = ''--@cUCC
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU descr 1
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU descr 2
         SET @cOutField05 = CAST (@nQTY AS NVARCHAR( 5))
         SET @cOutField06 = @cPackUOM --@cUOM
         SET @cOutField07 = @cPPK
         SET @cOutField08 = @cLottable1
         SET @cOutField09 = @cLottable2
         SET @cOutField10 = @cLottable3
         SET @cOutField11 = rdt.rdtFormatDate( @dLottable4)
         SET @cOutField12 = rdt.rdtFormatDate( @dLottable5) 
         
      END
      -- Go to next page
      -- UCC is blank, SKU not blank, go to next page
      ELSE IF @cSKU <> '' AND @cSKU IS NOT NULL
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cStorer
         SET @cOutField02 = @cUCCFacility
         SET @cOutField03 = @cLOC
         SET @cOutField04 = @cID

         -- Got to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cSKU = ''
      
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0 
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cSKU = ''

      -- Reset this screen var
      SET @cOutField01 = ''  -- UCC
      SET @cOutField02 = ''  -- SKU
      SET @cOutField03 = ''  -- SKU descr 1
      SET @cOutField04 = ''  -- SKU descr 2
      SET @cOutField05 = ''  -- QTY
      SET @cOutField06 = ''  -- PackUOM
      SET @cOutField07 = ''  -- PPK
      SET @cOutField08 = ''  -- Lottable1
      SET @cOutField09 = ''  -- Lottable2
      SET @cOutField10 = ''  -- Lottable3
      SET @cOutField11 = ''  -- Lottable4
      SET @cOutField12 = ''  -- Lottable5
   END
END
GOTO Quit

/************************************************************************************
 Step 2. Scn = 823. Additional Details
    STORER     (field01)
    FACILITY   (field02)
    LOC        (field03)
    ID         (field04)
************************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 OR @nInputKey = 0 -- ENTER / ESC
   BEGIN
      -- Set back values
      SET @cOutField01 = '' -- @cUCC
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU descr 1
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU descr 2
      SET @cOutField05 = CAST (@nQTY AS NVARCHAR( 5))
      SET @cOutField06 = @cPackUOM --@cUOM
      SET @cOutField07 = @cPPK
      SET @cOutField08 = @cLottable1
      SET @cOutField09 = @cLottable2
      SET @cOutField10 = @cLottable3
      SET @cOutField11 = rdt.rdtFormatDate( @dLottable4)
      SET @cOutField12 = rdt.rdtFormatDate( @dLottable5)  

      -- Back to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit

/************************************************************************************
(Vicky02)
Step 3. Scn = 827. UCC screen
   UCC       (field01)
   SKU       (field02)
   SKUDESC1  (field03)
   SKUDESC2  (field04)
   QTY       (field05)
   UOM       (field06)
   PPK       (field07)
   STATUS    (field08)
   LOC       (field09)
   LOT       (field10)
************************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUCC = @cInField01      
      
      -- If UCC and SKU are blank
      IF (@cUCC = '' OR @cUCC IS NULL) AND (@cSKU = '' OR @cSKU IS NULL)
      BEGIN
         SET @nErrNo = 66651
         SET @cErrMsg = rdt.rdtgetmessage( 66651, @cLangCode, 'DSP') --'UCC needed'
         GOTO Step_3_Fail
      END      

      -- If UCC not blank, retrieve data
      -- Else check if UCC is blank but SKU not blank, go to next page
      IF @cUCC <> '' AND @cUCC IS NOT NULL
      BEGIN
         SELECT
            @cSKU = SKU,
            @cLOT = LOT,
            @cLOC = LOC,
            @cID  = ID,
            @nQTY = Qty,
            @cUCCStatus = Status
         FROM dbo.UCC (NOLOCK)
         WHERE UCCNo = @cUCC
            AND StorerKey = @cStorer

         SELECT @nRowCnt = @@ROWCOUNT

         IF @nRowCnt = 0
         BEGIN
            SET @nErrNo = 66652
            SET @cErrMsg = rdt.rdtgetmessage( 66652, @cLangCode, 'DSP') --'UCC not exist'
            GOTO Step_3_Fail
         END

         IF @nRowCnt = 1
         BEGIN
            -- Validate SKU
            IF @cSKU = '' OR @cSKU IS NULL
            BEGIN
               SET @nErrNo = 66652
               SET @cErrMsg = rdt.rdtgetmessage( 66652, @cLangCode, 'DSP') --'No SKU'
               GOTO Step_3_Fail
            END

            -- Validate LOT
            IF @cLOT = '' AND @cUCCStatus <> '0'
            BEGIN
               SET @nErrNo = 66653
               SET @cErrMsg = rdt.rdtgetmessage( 66653, @cLangCode, 'DSP') --'LOT bad'
               GOTO Step_3_Fail
            END
            
            -- Get Lottables
            SELECT
               @cLottable1 = Lottable01, 
               @cLottable2 = Lottable02, 
               @cLottable3 = Lottable03, 
               @dLottable4 = Lottable04,
               @dLottable5 = Lottable05
            FROM dbo.LotAttribute (NOLOCK)
            WHERE Lot = @cLOT
   
            -- Validate LOC
            IF @cLOC = '' AND @cUCCStatus <> '0'
            BEGIN
               SET @nErrNo = 66654
               SET @cErrMsg = rdt.rdtgetmessage( 66654, @cLangCode, 'DSP') --'LOC bad'
               GOTO Step_3_Fail
            END

            -- Validate Facility
            IF @cLOC <> '' AND @cLOC IS NOT NULL
            BEGIN
               SELECT @cUCCFacility = Facility
               FROM dbo.LOC (NOLOCK)
               WHERE LOC = @cLOC

               IF @cUCCFacility = '' OR @cUCCFacility IS NULL
               BEGIN
                  SET @nErrNo = 66655
                  SET @cErrMsg = rdt.rdtgetmessage( 66655, @cLangCode, 'DSP') --'No facility'
                  GOTO Step_3_Fail
               END

               IF @cUCCFacility <> @cFacility
               BEGIN
                  SET @nErrNo = 66656
                  SET @cErrMsg = rdt.rdtgetmessage( 66656, @cLangCode, 'DSP') --'Facility diff'
                  -- Display result and error message on screen
                  -- GOTO Step_1_Fail
               END
            END             
      
            -- Get SKUDescr, UOM, PPK
            SELECT @cSKUDescr = SKU.Descr,
               @cPackUOM = ISNULL(RTRIM(LTRIM(PACK.PackUOM3)), ''), -- (Vicky01)
               @cPPK = CASE WHEN SKU.PrePackIndicator = '2' 
                          THEN CAST( SKU.PackQtyIndicator AS NVARCHAR( 5)) 
                          ELSE '' 
                       END
            FROM dbo.SKU SKU (NOLOCK)
               INNER JOIN dbo.PACK PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
            WHERE SKU.StorerKey = @cStorer
               AND SKU.SKU = @cSKU
       
         END
   
         -- Prepare next screen var
         SET @cOutField01 = ''--@cUCC
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU descr 1
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU descr 2
         SET @cOutField05 = CAST (@nQTY AS NVARCHAR( 5))
         SET @cOutField06 = @cPackUOM --@cUOM
         SET @cOutField07 = @cPPK
         SET @cOutField08 = @cUCCStatus
         SET @cOutField09 = @cLOC
         SET @cOutField10 = @cLot
--         SET @cOutField08 = @cLottable1
--         SET @cOutField09 = @cLottable2
--         SET @cOutField10 = @cLottable3
--         SET @cOutField11 = rdt.rdtFormatDate( @dLottable4)
--         SET @cOutField12 = rdt.rdtFormatDate( @dLottable5)         
      END
      -- Go to next page
      -- UCC is blank, SKU not blank, go to next page
      ELSE IF @cSKU <> '' AND @cSKU IS NOT NULL
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cStorer
         SET @cOutField02 = @cUCCFacility
         SET @cOutField03 = @cID
         SET @cOutField08 = @cLottable1
         SET @cOutField09 = @cLottable2
         SET @cOutField10 = @cLottable3
         SET @cOutField11 = rdt.rdtFormatDate( @dLottable4)
         SET @cOutField12 = rdt.rdtFormatDate( @dLottable5)  

         -- Got to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cSKU = ''
      
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0 
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cSKU = ''

      -- Reset this screen var
      SET @cOutField01 = ''  -- UCC
      SET @cOutField02 = ''  -- SKU
      SET @cOutField03 = ''  -- SKU descr 1
      SET @cOutField04 = ''  -- SKU descr 2
      SET @cOutField05 = ''  -- QTY
      SET @cOutField06 = ''  -- PackUOM
      SET @cOutField07 = ''  -- PPK
      SET @cOutField08 = ''  -- Lottable1
      SET @cOutField09 = ''  -- Lottable2
      SET @cOutField10 = ''  -- Lottable3
      SET @cOutField11 = ''  -- Lottable4
      SET @cOutField12 = ''  -- Lottable5
   END
END
GOTO Quit

/************************************************************************************
(Vicky02) 
Step 4. Scn = 828. Additional Details
    STORER     (field01)
    FACILITY   (field02)
    ID         (field03)
    LOTTABLE1  (field08)
    LOTTABLE2  (field09)
    LOTTABLE3  (field10)
    LOTTABLE4  (field11)
    LOTTABLE5  (field12)
************************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 OR @nInputKey = 0 -- ENTER / ESC
   BEGIN
      -- Set back values
      SET @cOutField01 = '' -- @cUCC
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU descr 1
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU descr 2
      SET @cOutField05 = CAST (@nQTY AS NVARCHAR( 5))
      SET @cOutField06 = @cPackUOM --@cUOM
      SET @cOutField07 = @cPPK
      SET @cOutField08 = @cUCCStatus
      SET @cOutField09 = @cLOC
      SET @cOutField10 = @cLot

      -- Back to previous screen
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
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey      = @cStorer,
      Facility       = @cFacility,
      -- UserName       = @cUserName,
      
      V_UCC          = @cUCC,
      V_SKU          = @cSKU,
      V_SKUDescr     = @cSKUDescr,
      V_UOM          = @cUOM,
      V_QTY          = @nQTY,
      V_LOT          = @cLOT,
      V_LOC          = @cLOC,
      V_ID           = @cID,
      V_Lottable01   = @cLottable1,
      V_Lottable02   = @cLottable2,
      V_Lottable03   = @cLottable3,
      V_Lottable04   = @dLottable4,
      V_Lottable05   = @dLottable5,

      V_String1      = @cPackUOM,
      V_String2      = @cPPK,
      V_String3      = @cUCCFacility,      
      V_String4      = @cNewScnLayout, -- (Vicky02)
      V_String5      = @cUCCStatus,    -- (Vicky02)
      V_String6      = @cExtendedInfoSP, -- (ChewKP01)

      I_Field01 = '',  O_Field01 = @cOutField01,
      I_Field02 = '',  O_Field02 = @cOutField02,
      I_Field03 = '',  O_Field03 = @cOutField03,
      I_Field04 = '',  O_Field04 = @cOutField04,
      I_Field05 = '',  O_Field05 = @cOutField05,
      I_Field06 = '',  O_Field06 = @cOutField06,
      I_Field07 = '',  O_Field07 = @cOutField07,
      I_Field08 = '',  O_Field08 = @cOutField08,
      I_Field09 = '',  O_Field09 = @cOutField09,
      I_Field10 = '',  O_Field10 = @cOutField10,
      I_Field11 = '',  O_Field11 = @cOutField11,
      I_Field12 = '',  O_Field12 = @cOutField12,
      I_Field13 = '',  O_Field13 = @cOutField13,
      I_Field14 = '',  O_Field14 = @cOutField14,
      I_Field15 = '',  O_Field15 = @cOutField15

   WHERE Mobile = @nMobile

END

GO