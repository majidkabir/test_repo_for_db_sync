SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_SKUStyle_Inquiry                             */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author     Purposes                                 */
/* 23-05-2019  1.0  Ung        WMS-9078 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_SKUStyle_Inquiry] (
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
DECLARE
   @b_success           INT,
   @n_err               INT,
   @c_errmsg            NVARCHAR( 20),

   @cPUOM_Desc  NVARCHAR( 5), 
   @cMUOM_Desc  NVARCHAR( 5), 

   @nPQTY_Avail FLOAT, 
   @nMQTY_Avail FLOAT, 
   @nPQTY_Alloc FLOAT, 
   @nMQTY_Alloc FLOAT, 
   @nPUOM_Div   INT, 
   @nPQTY_Hold  FLOAT, 
   @nMQTY_Hold  FLOAT, 

   @cRDTDefaultUOM         NVARCHAR(10),
   @cPackkey               NVARCHAR(10),
   @nMorePage              INT,
   @cUPC          NVARCHAR( 30),
   @cBarcode      NVARCHAR( 60) 

-- RDT.RDTMobRec variable
DECLARE
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,
   @bSuccess   INT,

   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),

   @cLOT          NVARCHAR( 10),
   @cLOC          NVARCHAR( 10),
   @cID           NVARCHAR( 18),
   @cSKU          NVARCHAR( 20),
   @cSKUDescr     NVARCHAR( 60),
   @cPUOM         NVARCHAR( 1), 

   @nTotalRec     INT,
   @nCurrentRec   INT,

   @cStyle        NVARCHAR( 20),
   @nMQty_RPL     FLOAT,      
   @nPQty_RPL     FLOAT,      
   @nMQty_TTL     FLOAT,      
   @nPQty_TTL     FLOAT,      
   @nMQty_Pick    FLOAT,      
   @nPQty_Pick    FLOAT,      
   @cDecodeSP     NVARCHAR( 20), 

   @nQty          INT,           
   @cSQL          NVARCHAR( 2000), 
   @cSQLParam     NVARCHAR( 2000), 
   @cUserDefine01 NVARCHAR( 60),  
   @cUserDefine02 NVARCHAR( 60),  
   @cUserDefine03 NVARCHAR( 60),  
   @cUserDefine04 NVARCHAR( 60),  
   @cUserDefine05 NVARCHAR( 60),  

   @cDecodeLabelNo      NVARCHAR( 20),
   @cSKUBarcode         NVARCHAR( 30),
   @cChkStorerKey       NVARCHAR( 15),

   @nQTY_TTL            INT,
   @nQTY_Hold           INT,
   @nQTY_Alloc          INT,
   @nQTY_Pick           INT,
   @nQTY_RPL            INT,
   @nQTY_Avail          INT,
   @nSKUCnt             INT,

   @cLottableCode NVARCHAR( 30), 
   @cLottable01 NVARCHAR( 18),
   @cLottable02 NVARCHAR( 18),
   @cLottable03 NVARCHAR( 18),
   @dLottable04 DATETIME, 
   @dLottable05 DATETIME, 
   @cLottable06 NVARCHAR( 30), 
   @cLottable07 NVARCHAR( 30), 
   @cLottable08 NVARCHAR( 30), 
   @cLottable09 NVARCHAR( 30), 
   @cLottable10 NVARCHAR( 30), 
   @cLottable11 NVARCHAR( 30), 
   @cLottable12 NVARCHAR( 30), 
   @dLottable13 DATETIME, 
   @dLottable14 DATETIME, 
   @dLottable15 DATETIME, 

   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),
   @c_oFieled11 NVARCHAR(20), @c_oFieled12 NVARCHAR(20),
   @c_oFieled13 NVARCHAR(20), @c_oFieled14 NVARCHAR(20),
   @c_oFieled15 NVARCHAR(20),

   @cInField01 NVARCHAR( 60),  @cOutField01 NVARCHAR( 60),  @cFieldAttr01 NVARCHAR( 1), 
   @cInField02 NVARCHAR( 60),  @cOutField02 NVARCHAR( 60),  @cFieldAttr02 NVARCHAR( 1), 
   @cInField03 NVARCHAR( 60),  @cOutField03 NVARCHAR( 60),  @cFieldAttr03 NVARCHAR( 1), 
   @cInField04 NVARCHAR( 60),  @cOutField04 NVARCHAR( 60),  @cFieldAttr04 NVARCHAR( 1), 
   @cInField05 NVARCHAR( 60),  @cOutField05 NVARCHAR( 60),  @cFieldAttr05 NVARCHAR( 1), 
   @cInField06 NVARCHAR( 60),  @cOutField06 NVARCHAR( 60),  @cFieldAttr06 NVARCHAR( 1), 
   @cInField07 NVARCHAR( 60),  @cOutField07 NVARCHAR( 60),  @cFieldAttr07 NVARCHAR( 1), 
   @cInField08 NVARCHAR( 60),  @cOutField08 NVARCHAR( 60),  @cFieldAttr08 NVARCHAR( 1), 
   @cInField09 NVARCHAR( 60),  @cOutField09 NVARCHAR( 60),  @cFieldAttr09 NVARCHAR( 1), 
   @cInField10 NVARCHAR( 60),  @cOutField10 NVARCHAR( 60),  @cFieldAttr10 NVARCHAR( 1), 
   @cInField11 NVARCHAR( 60),  @cOutField11 NVARCHAR( 60),  @cFieldAttr11 NVARCHAR( 1), 
   @cInField12 NVARCHAR( 60),  @cOutField12 NVARCHAR( 60),  @cFieldAttr12 NVARCHAR( 1), 
   @cInField13 NVARCHAR( 60),  @cOutField13 NVARCHAR( 60),  @cFieldAttr13 NVARCHAR( 1), 
   @cInField14 NVARCHAR( 60),  @cOutField14 NVARCHAR( 60),  @cFieldAttr14 NVARCHAR( 1), 
   @cInField15 NVARCHAR( 60),  @cOutField15 NVARCHAR( 60),  @cFieldAttr15 NVARCHAR( 1)

-- Load RDT.RDTMobRec
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode = Lang_code,

   @cStorerKey    = StorerKey,
   @cFacility     = Facility,

   @cLottable01 =  V_Lottable01,
   @cLottable02 =  V_Lottable02,
   @cLottable03 =  V_Lottable03,
   @dLottable04 =  V_Lottable04,
   @dLottable05 =  V_Lottable05,
   @cLottable06 =  V_Lottable06,
   @cLottable07 =  V_Lottable07,
   @cLottable08 =  V_Lottable08,
   @cLottable09 =  V_Lottable09,
   @cLottable10 =  V_Lottable10,
   @cLottable11 =  V_Lottable11,
   @cLottable12 =  V_Lottable12,
   @dLottable13 =  V_Lottable13,
   @dLottable14 =  V_Lottable14,
   @dLottable15 =  V_Lottable15,

   @cLOT       = V_LOT,
   @cLOC       = V_LOC,
   @cID        = V_ID,
   @cSKU       = V_SKU,
   @cPUOM      = V_UOM,
   @cSKUDescr  = V_SKUDescr, 

   @nTotalRec    = V_Integer1,  
   @nCurrentRec  = V_Integer2,  
   @nPQTY_Avail  = V_Integer3,  
   @nPQTY_Alloc  = V_Integer4,  
   @nPQTY_Hold   = V_Integer5,  
   @nMQTY_Avail  = V_Integer6,  
   @nMQTY_Alloc  = V_Integer7,  
   @nMQTY_Hold   = V_Integer8,  
   @nMQTY_TTL    = V_Integer9,  
   @nMQTY_RPL    = V_Integer10,  
   @nPQTY_TTL    = V_Integer11,  
   @nPQTY_RPL    = V_Integer12,  
   @nMQTY_Pick   = V_Integer13,  
   @nPQTY_Pick   = V_Integer14,  

   @cStyle       = V_String1,
   @cPUOM_Desc   = V_String4,
   @cMUOM_Desc   = V_String5,
   @cDecodeSP    = V_String6,
   @cLottableCode          = V_String10, 

   @cInField01 = I_Field01,  @cOutField01 = O_Field01,  @cFieldAttr01  =FieldAttr01,
   @cInField02 = I_Field02,  @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,
   @cInField03 = I_Field03,  @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,
   @cInField04 = I_Field04,  @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,
   @cInField05 = I_Field05,  @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,
   @cInField06 = I_Field06,  @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,
   @cInField07 = I_Field07,  @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,
   @cInField08 = I_Field08,  @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08,  
   @cInField09 = I_Field09,  @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,
   @cInField10 = I_Field10,  @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,
   @cInField11 = I_Field11,  @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,
   @cInField12 = I_Field12,  @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,
   @cInField13 = I_Field13,  @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,
   @cInField14 = I_Field14,  @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,  @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15

FROM RDT.RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_SKU       INT,  @nScn_Style     INT,
   @nStep_Result    INT,  @nScn_Result    INT,
   @nStep_Lottables INT,  @nScn_Lottables INT

SELECT
   @nStep_SKU       = 1,  @nScn_Style     = 5140,
   @nStep_Result    = 2,  @nScn_Result    = 5141,
   @nStep_Lottables = 3,  @nScn_Lottables = 5142

IF @nFunc = 724 -- SKU style inquiry
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_Start       -- Func = 724
   IF @nStep = 1 GOTO Step_SKU         -- Scn = 5470. SKU
   IF @nStep = 2 GOTO Step_Result      -- Scn = 5471. Result
   IF @nStep = 3 GOTO Step_Lottables   -- Scn = 5472. Lottables
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 724. Menu
********************************************************************************/
Step_Start:
BEGIN
   -- Set the entry point
   SET @nScn = @nScn_Style
   SET @nStep = @nStep_SKU

   -- Initiate var
   SET @cStyle = ''
   SET @cLOC = ''
   SET @cID = ''
   SET @cSKU = ''
   SET @cSKUDescr = ''
   SET @cSKUBarcode = ''

   SET @nTotalRec = 0
   SET @nCurrentRec = 0

   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerkey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = '' 

   -- Init screen
   SET @cOutField01 = ''
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 5140. Style screen
   Style (field01)
********************************************************************************/
Step_SKU:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cBarcode = @cInField01
      SET @cUPC = LEFT( @cInField01, 30)

      SET @cStyle = ''

      -- Check blank
      IF @cUPC = ''
      BEGIN
         SET @nErrNo = 138951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NEED SKU/UPC
         GOTO Quit            
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
               @cUserDefine01 = @cUPC     OUTPUT,
               @nErrNo        = @nErrNo   OUTPUT, 
               @cErrMsg       = @cErrMsg  OUTPUT

            IF @nErrNo <> 0 
               GOTO Step_1_Fail

            SET @cStyle = @cUPC
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +
               ' @cStyle OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cBarcode       NVARCHAR( 60), ' +
               ' @cStyle         NVARCHAR( 20)  OUTPUT, ' +
               ' @nErrNo         INT            OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cBarcode, 
               @cStyle  OUTPUT, 
               @nErrNo  OUTPUT, 
               @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Step_1_Fail
         END
      END

      -- By SKU
      IF @cStyle = ''
      BEGIN
         -- Get SKU count
         EXEC [RDT].[rdt_GETSKUCNT]
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cUPC
            ,@nSKUCnt     = @nSKUCnt       OUTPUT
            ,@bSuccess    = @b_Success     OUTPUT
            ,@nErr        = @n_Err         OUTPUT
            ,@cErrMsg     = @c_ErrMsg      OUTPUT

         -- Check SKU valid
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 138952
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            GOTO Step_1_Fail            
         END

         -- Check multi SKU barcode
         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 138953
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
            GOTO Step_1_Fail            
         END

         -- Get SKU
         EXEC [RDT].[rdt_GETSKU]
            @cStorerKey   = @cStorerKey
           ,@cSKU         = @cUPC      OUTPUT
           ,@bSuccess     = @bSuccess  OUTPUT
           ,@nErr         = @nErrNo    OUTPUT
           ,@cErrMsg      = @cErrMsg   OUTPUT

         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = 138954
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            GOTO Step_1_Fail
         END
         
         SET @cSKU = @cUPC
         SELECT @cStyle = Style FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
      END

      -- Check style
      IF @cStyle = ''
      BEGIN
         SET @nErrNo = 138955
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Style is blank
         GOTO Step_1_Fail            
      END

      -- Init data
      SELECT 
         @cLOT = '', @cLOC = '', @cID = '', @cSKU = '', @nTotalRec = 0, 
         @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL,  @dLottable05 = NULL,
         @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',    @cLottable10 = '',
         @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL,  @dLottable15 = NULL

      -- Get next record
      EXEC rdt.rdt_SKUStyle_Inquiry @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey,
         @cPUOM,           
         @cStyle,
         @cLOT              OUTPUT, 
         @cLOC              OUTPUT,
         @cID               OUTPUT,
         @cSKU              OUTPUT,
         @cSKUDescr         OUTPUT,
         @nTotalRec         OUTPUT,
         @nMQTY_TTL         OUTPUT,
         @nMQTY_Hold        OUTPUT,
         @nMQTY_Alloc       OUTPUT,
         @nMQTY_Pick        OUTPUT,
         @nMQTY_RPL         OUTPUT,
         @nMQTY_Avail       OUTPUT,
         @nPQTY_TTL         OUTPUT,
         @nPQTY_Hold        OUTPUT,
         @nPQTY_Alloc       OUTPUT,
         @nPQTY_Pick        OUTPUT,
         @nPQTY_RPL         OUTPUT,
         @nPQTY_Avail       OUTPUT,
         @cPUOM_Desc        OUTPUT,
         @cMUOM_Desc        OUTPUT,
         @cLottableCode     OUTPUT,
         @cLottable01       OUTPUT, 
         @cLottable02       OUTPUT, 
         @cLottable03       OUTPUT, 
         @dLottable04       OUTPUT, 
         @dLottable05       OUTPUT, 
         @cLottable06       OUTPUT, 
         @cLottable07       OUTPUT, 
         @cLottable08       OUTPUT, 
         @cLottable09       OUTPUT, 
         @cLottable10       OUTPUT, 
         @cLottable11       OUTPUT, 
         @cLottable12       OUTPUT, 
         @dLottable13       OUTPUT, 
         @dLottable14       OUTPUT, 
         @dLottable15       OUTPUT, 
         @nErrNo            OUTPUT,
         @cErrMsg           OUTPUT  

      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
         GOTO Step_1_Fail
      END

      -- Prep next screen var
      SET @nCurrentRec = 1
      SET @cOutField01 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField05 = @cLOC
      SET @cOutField06 = @cID

      SET @cOutField07 = CASE WHEN @cPUOM_Desc <> ''
                           THEN LEFT( @cPUOM_Desc + REPLICATE(' ', 5), 5) + ' ' + @cMUOM_Desc
                           ELSE SPACE( 6) + @cMUOM_Desc END
      SET @cOutField08 = CASE WHEN @cPUOM_Desc <> ''
                           THEN LEFT( CAST( LEFT(@nPQTY_TTL, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_TTL, 5) AS NVARCHAR( 5))
                           ELSE SPACE( 6) + CAST( LEFT(@nMQTY_TTL, 5)   AS NVARCHAR( 5)) END
      SET @cOutField09 = CASE WHEN @cPUOM_Desc <> ''
                           THEN LEFT( CAST( LEFT(@nPQTY_Hold, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Hold, 5) AS NVARCHAR( 5))
                           ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Hold, 5)  AS NVARCHAR( 5)) END -- (Vicky01)
      SET @cOutField10 = CASE WHEN @cPUOM_Desc <> ''
                           THEN LEFT( CAST( LEFT(@nPQTY_Alloc, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Alloc, 5) AS NVARCHAR( 5))
                           ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Alloc, 5) AS NVARCHAR( 5)) END
      SET @cOutField11 = CASE WHEN @cPUOM_Desc <> ''
                           THEN LEFT( CAST( LEFT(@nPQTY_Pick, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Pick, 5) AS NVARCHAR( 5))
                           ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Pick, 5) AS NVARCHAR( 5)) END
      SET @cOutField12 = CASE WHEN @cPUOM_Desc <> ''
                           THEN LEFT( CAST( LEFT(@nPQTY_RPL, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_RPL, 5) AS NVARCHAR( 5))
                           ELSE SPACE( 6) + CAST( LEFT(@nMQTY_RPL, 5)   AS NVARCHAR( 5)) END -- (james02)
      SET @cOutField13 = CASE WHEN @cPUOM_Desc <> ''
                           THEN LEFT( CAST( LEFT(@nPQTY_Avail, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Avail, 5) AS NVARCHAR( 5))
                           ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Avail, 5) AS NVARCHAR( 5)) END

      -- Go to next screen
      SET @nScn = @nScn_Result
      SET @nStep = @nStep_Result
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

Step_1_Fail:
   SET @cOutField01 = '' -- Style

END
GOTO Quit


/********************************************************************************
Step 2. Scn = 5141. Result screen
   Counter    (field01)
   SKU        (field02)
   Desc1      (field03
   Desc2      (field04)
   LOC        (field05)
   ID         (field06)
   UOM        (field07, 10)
   QTY AVL    (field08, 11)
   QTY ALC    (field09, 12)
   QTY HLD    (field13, 14)
********************************************************************************/
Step_Result:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SELECT 
         @cOutField01 = '', @cOutField02 = '', @cOutField03 = '', @cOutField04 = '', @cOutField05 = '', 
         @cOutField06 = '', @cOutField07 = '', @cOutField08 = '', @cOutField09 = '', @cOutField10 = ''

      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 10, 1, 
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',      -- SourceKey
         @nFunc   -- SourceType

      -- Check any output
      IF @cOutField01 <> '' OR @cOutField02 <> '' OR @cOutField03 <> '' OR @cOutField04 <> '' OR @cOutField05 <> '' OR 
         @cOutField06 <> '' OR @cOutField07 <> '' OR @cOutField08 <> '' OR @cOutField09 <> '' OR @cOutField10 <> ''
      BEGIN
         -- Go to lottable screen
         SET @nScn = @nScn_Lottables
         SET @nStep = @nStep_Lottables

         GOTO Quit
      END
      ELSE
      BEGIN
         IF @nCurrentRec = @nTotalRec
         BEGIN
            SET @cSKU = ''
            SET @cLOC = ''
            SET @cID = ''
            SET @cLOT = ''
            SET @nCurrentRec = 0
         END

         -- Get next record
         EXEC rdt.rdt_SKUStyle_Inquiry @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey,
            @cPUOM,           
            @cStyle,
            @cLOT              OUTPUT, 
            @cLOC              OUTPUT,
            @cID               OUTPUT,
            @cSKU              OUTPUT,
            @cSKUDescr         OUTPUT,
            @nTotalRec         OUTPUT,
            @nMQTY_TTL         OUTPUT,
            @nMQTY_Hold        OUTPUT,
            @nMQTY_Alloc       OUTPUT,
            @nMQTY_Pick        OUTPUT,
            @nMQTY_RPL         OUTPUT,
            @nMQTY_Avail       OUTPUT,
            @nPQTY_TTL         OUTPUT,
            @nPQTY_Hold        OUTPUT,
            @nPQTY_Alloc       OUTPUT,
            @nPQTY_Pick        OUTPUT,
            @nPQTY_RPL         OUTPUT,
            @nPQTY_Avail       OUTPUT,
            @cPUOM_Desc        OUTPUT,
            @cMUOM_Desc        OUTPUT,
            @cLottableCode     OUTPUT,
            @cLottable01       OUTPUT, 
            @cLottable02       OUTPUT, 
            @cLottable03       OUTPUT, 
            @dLottable04       OUTPUT, 
            @dLottable05       OUTPUT, 
            @cLottable06       OUTPUT, 
            @cLottable07       OUTPUT, 
            @cLottable08       OUTPUT, 
            @cLottable09       OUTPUT, 
            @cLottable10       OUTPUT, 
            @cLottable11       OUTPUT, 
            @cLottable12       OUTPUT, 
            @dLottable13       OUTPUT, 
            @dLottable14       OUTPUT, 
            @dLottable15       OUTPUT, 
            @nErrNo            OUTPUT,
            @cErrMsg           OUTPUT  

         IF @nErrNo <> 0
         BEGIN
            IF @nTotalRec <> -1  -- -1 indicates no more record
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
               GOTO Step_1_Fail
            END
            ELSE
            BEGIN
               SET @nTotalRec = @nCurrentRec
            END
         END

         -- Prep next screen var
         SET @nCurrentRec = CASE WHEN @nTotalRec = @nCurrentRec THEN @nCurrentRec ELSE @nCurrentRec + 1 END
         SET @cOutField01 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField05 = @cLOC
         SET @cOutField06 = @cID

         SET @cOutField07 = CASE WHEN @cPUOM_Desc <> ''
                              THEN LEFT( @cPUOM_Desc + REPLICATE(' ', 5), 5) + ' ' + @cMUOM_Desc
                              ELSE SPACE( 6) + @cMUOM_Desc END
         SET @cOutField08 = CASE WHEN @cPUOM_Desc <> ''
                              THEN LEFT( CAST( LEFT(@nPQTY_TTL, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_TTL, 5) AS NVARCHAR( 5))
                              ELSE SPACE( 6) + CAST( LEFT(@nMQTY_TTL, 5)   AS NVARCHAR( 5)) END
         SET @cOutField09 = CASE WHEN @cPUOM_Desc <> ''
                              THEN LEFT( CAST( LEFT(@nPQTY_Hold, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Hold, 5) AS NVARCHAR( 5))
                              ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Hold, 5)  AS NVARCHAR( 5)) END -- (Vicky01)
         SET @cOutField10 = CASE WHEN @cPUOM_Desc <> ''
                              THEN LEFT( CAST( LEFT(@nPQTY_Alloc, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Alloc, 5) AS NVARCHAR( 5))
                              ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Alloc, 5) AS NVARCHAR( 5)) END
         SET @cOutField11 = CASE WHEN @cPUOM_Desc <> ''
                              THEN LEFT( CAST( LEFT(@nPQTY_Pick, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Pick, 5) AS NVARCHAR( 5))
                              ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Pick, 5) AS NVARCHAR( 5)) END
         SET @cOutField12 = CASE WHEN @cPUOM_Desc <> ''
                              THEN LEFT( CAST( LEFT(@nPQTY_RPL, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_RPL, 5) AS NVARCHAR( 5))
                              ELSE SPACE( 6) + CAST( LEFT(@nMQTY_RPL, 5)   AS NVARCHAR( 5)) END -- (james02)
         SET @cOutField13 = CASE WHEN @cPUOM_Desc <> ''
                              THEN LEFT( CAST( LEFT(@nPQTY_Avail, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Avail, 5) AS NVARCHAR( 5))
                              ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Avail, 5) AS NVARCHAR( 5)) END
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cStyle  = ''
      SET @cOutField01 = '' -- Style

      -- Go to prev screen
      SET @nScn = @nScn_Style
      SET @nStep = @nStep_SKU
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 5142. Result screen
   LOTTABLE01 (field01)
   LOTTABLE02 (field02)
   LOTTABLE03 (field03)
   LOTTABLE04 (field04)
   LOTTABLE05 (field05)
   LOTTABLE06 (field06)
   LOTTABLE07 (field07)
   LOTTABLE08 (field08)
   LOTTABLE09 (field09)
   LOTTABLE10 (field10)
********************************************************************************/
Step_Lottables:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      IF @nCurrentRec = @nTotalRec
      BEGIN
         SET @cSKU = ''
         SET @cLOC = ''
         SET @cID = ''
         SET @cLOT = ''
         SET @nCurrentRec = 0
      END

      -- Get next record
      EXEC rdt.rdt_SKUStyle_Inquiry @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey,
         @cPUOM,           
         @cStyle,
         @cLOT              OUTPUT, 
         @cLOC              OUTPUT,
         @cID               OUTPUT,
         @cSKU              OUTPUT,
         @cSKUDescr         OUTPUT,
         @nTotalRec         OUTPUT,
         @nMQTY_TTL         OUTPUT,
         @nMQTY_Hold        OUTPUT,
         @nMQTY_Alloc       OUTPUT,
         @nMQTY_Pick        OUTPUT,
         @nMQTY_RPL         OUTPUT,
         @nMQTY_Avail       OUTPUT,
         @nPQTY_TTL         OUTPUT,
         @nPQTY_Hold        OUTPUT,
         @nPQTY_Alloc       OUTPUT,
         @nPQTY_Pick        OUTPUT,
         @nPQTY_RPL         OUTPUT,
         @nPQTY_Avail       OUTPUT,
         @cPUOM_Desc        OUTPUT,
         @cMUOM_Desc        OUTPUT,
         @cLottableCode     OUTPUT,
         @cLottable01       OUTPUT, 
         @cLottable02       OUTPUT, 
         @cLottable03       OUTPUT, 
         @dLottable04       OUTPUT, 
         @dLottable05       OUTPUT, 
         @cLottable06       OUTPUT, 
         @cLottable07       OUTPUT, 
         @cLottable08       OUTPUT, 
         @cLottable09       OUTPUT, 
         @cLottable10       OUTPUT, 
         @cLottable11       OUTPUT, 
         @cLottable12       OUTPUT, 
         @dLottable13       OUTPUT, 
         @dLottable14       OUTPUT, 
         @dLottable15       OUTPUT, 
         @nErrNo            OUTPUT,
         @cErrMsg           OUTPUT  

      IF @nErrNo <> 0
      BEGIN
         IF @nTotalRec <> -1  -- -1 indicates no more record
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
            GOTO Quit
         END
         ELSE
         BEGIN
            SET @nTotalRec = @nCurrentRec
         END
      END

      -- Prep next screen var
      SET @nCurrentRec = CASE WHEN @nTotalRec = @nCurrentRec THEN @nCurrentRec ELSE @nCurrentRec + 1 END
      SET @cOutField01 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField05 = @cLOC
      SET @cOutField06 = @cID

      SET @cOutField07 = CASE WHEN @cPUOM_Desc <> ''
                           THEN LEFT( @cPUOM_Desc + REPLICATE(' ', 5), 5) + ' ' + @cMUOM_Desc
                           ELSE SPACE( 6) + @cMUOM_Desc END
      SET @cOutField08 = CASE WHEN @cPUOM_Desc <> ''
                           THEN LEFT( CAST( LEFT(@nPQTY_TTL, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_TTL, 5) AS NVARCHAR( 5))
                           ELSE SPACE( 6) + CAST( LEFT(@nMQTY_TTL, 5)   AS NVARCHAR( 5)) END
      SET @cOutField09 = CASE WHEN @cPUOM_Desc <> ''
                           THEN LEFT( CAST( LEFT(@nPQTY_Hold, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Hold, 5) AS NVARCHAR( 5))
                           ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Hold, 5)  AS NVARCHAR( 5)) END -- (Vicky01)
      SET @cOutField10 = CASE WHEN @cPUOM_Desc <> ''
                           THEN LEFT( CAST( LEFT(@nPQTY_Alloc, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Alloc, 5) AS NVARCHAR( 5))
                           ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Alloc, 5) AS NVARCHAR( 5)) END
      SET @cOutField11 = CASE WHEN @cPUOM_Desc <> ''
                           THEN LEFT( CAST( LEFT(@nPQTY_Pick, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Pick, 5) AS NVARCHAR( 5))
                           ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Pick, 5) AS NVARCHAR( 5)) END
      SET @cOutField12 = CASE WHEN @cPUOM_Desc <> ''
                           THEN LEFT( CAST( LEFT(@nPQTY_RPL, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_RPL, 5) AS NVARCHAR( 5))
                           ELSE SPACE( 6) + CAST( LEFT(@nMQTY_RPL, 5)   AS NVARCHAR( 5)) END -- (james02)
      SET @cOutField13 = CASE WHEN @cPUOM_Desc <> ''
                           THEN LEFT( CAST( LEFT(@nPQTY_Avail, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Avail, 5) AS NVARCHAR( 5))
                           ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Avail, 5) AS NVARCHAR( 5)) END

      -- Go back previous screen
      SET @nScn = @nScn_Result
      SET @nStep = @nStep_Result
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField05 = @cLOC
      SET @cOutField06 = @cID

      SET @cOutField07 = CASE WHEN @cPUOM_Desc <> ''
                         THEN LEFT( @cPUOM_Desc + REPLICATE(' ', 5), 5) + ' ' + @cMUOM_Desc
                         ELSE SPACE( 6) + @cMUOM_Desc END
      SET @cOutField08 = CASE WHEN @cPUOM_Desc <> ''
                         THEN LEFT( CAST( @nPQTY_TTL AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_TTL AS NVARCHAR( 5))
                         ELSE SPACE( 6) + CAST( @nMQTY_TTL   AS NVARCHAR( 5)) END
      SET @cOutField09 = CASE WHEN @cPUOM_Desc <> ''
                         THEN LEFT( CAST( @nPQTY_Hold AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Hold AS NVARCHAR( 5))
                         ELSE SPACE( 6) + CAST( @nMQTY_Hold  AS NVARCHAR( 5)) END -- (Vicky01)
      SET @cOutField10 = CASE WHEN @cPUOM_Desc <> ''
                         THEN LEFT( CAST( @nPQTY_Alloc AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Alloc AS NVARCHAR( 5))
                         ELSE SPACE( 6) + CAST( @nMQTY_Alloc AS NVARCHAR( 5)) END
      SET @cOutField11 = CASE WHEN @cPUOM_Desc <> ''
                         THEN LEFT( CAST( @nPQTY_Pick AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Pick AS NVARCHAR( 5))
                         ELSE SPACE( 6) + CAST( @nMQTY_Pick AS NVARCHAR( 5)) END
      SET @cOutField12 = CASE WHEN @cPUOM_Desc <> ''
                         THEN LEFT( CAST( @nPQTY_RPL AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_RPL AS NVARCHAR( 5))
                         ELSE SPACE( 6) + CAST( @nMQTY_RPL   AS NVARCHAR( 5)) END -- (james02)
      SET @cOutField13 = CASE WHEN @cPUOM_Desc <> ''
                         THEN LEFT( CAST( @nPQTY_Avail AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Avail AS NVARCHAR( 5))
                         ELSE SPACE( 6) + CAST( @nMQTY_Avail AS NVARCHAR( 5)) END

      -- Go to prev screen
      SET @nScn = @nScn_Result
      SET @nStep = @nStep_Result
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDT.RDTMOBREC with (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      Facility  = @cFacility,

      V_StorerKey  = @cStorerKey, 
      V_LOT        = @cLOT,
      V_LOC        = @cLOC,
      V_ID         = @cID,
      V_SKU        = @cSKU,
      V_UOM        = @cPUOM,
      V_SKUDescr   = @cSKUDescr, 

      V_Lottable01 = @cLottable01,
      V_Lottable02 = @cLottable02,
      V_Lottable03 = @cLottable03,
      V_Lottable04 = @dLottable04,
      V_Lottable05 = @dLottable05,
      V_Lottable06 = @cLottable06,
      V_Lottable07 = @cLottable07,
      V_Lottable08 = @cLottable08,
      V_Lottable09 = @cLottable09,
      V_Lottable10 = @cLottable10,
      V_Lottable11 = @cLottable11,
      V_Lottable12 = @cLottable12,
      V_Lottable13 = @dLottable13,
      V_Lottable14 = @dLottable14,
      V_Lottable15 = @dLottable15,

      V_Integer1  = @nTotalRec,  
      V_Integer2  = @nCurrentRec,  
      V_Integer3  = @nPQTY_Avail,  
      V_Integer4  = @nPQTY_Alloc,  
      V_Integer5  = @nPQTY_Hold,  
      V_Integer6  = @nMQTY_Avail,  
      V_Integer7  = @nMQTY_Alloc,  
      V_Integer8  = @nMQTY_Hold,  
      V_Integer9  = @nMQTY_TTL,  
      V_Integer10 = @nMQTY_RPL,  
      V_Integer11 = @nPQTY_TTL,  
      V_Integer12 = @nPQTY_RPL,  
      V_Integer13 = @nMQTY_Pick,  
      V_Integer14 = @nPQTY_Pick,  
            
      V_String1  = @cStyle,

      V_String4  = @cPUOM_Desc,
      V_String5  = @cMUOM_Desc,
      V_String6  = @cDecodeSP,
      V_String10 = @cLottableCode, 

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,  FieldAttr01 = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,  FieldAttr02 = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,  FieldAttr03 = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,  FieldAttr04 = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,  FieldAttr05 = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,  FieldAttr06 = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,  FieldAttr07 = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,  FieldAttr08 = @cFieldAttr08, 
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,  FieldAttr09 = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,  FieldAttr10 = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,  FieldAttr11 = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,  FieldAttr12 = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,  FieldAttr13 = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,  FieldAttr14 = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,  FieldAttr15 = @cFieldAttr15       
      
   WHERE Mobile = @nMobile
END  
 

GO