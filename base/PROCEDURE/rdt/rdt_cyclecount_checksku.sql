SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CycleCount_CheckSKU                             */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Cycle Count for SOS#190291                                  */
/*                                                                      */
/* Called from:[rdtfnc_CycleCount_SkuSingle]                            */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 27-10-2010  1.2  ChewKP   Get ComponentSKU                           */
/* 04-11-2010  1.3  AQSKC    Bad Sku not returning error message (Kc01) */
/* 20-04-2017  1.4  James    Remove ANSI_WARNINGS (james01)             */
/************************************************************************/

CREATE PROC [RDT].[rdt_CycleCount_CheckSKU] (
   @cStorer       NVARCHAR(15),
   @cNewSKU       NVARCHAR(20),
   @cLoc          NVARCHAR(10),
   @cID           NVARCHAR(18),
   @cCCRefNo      NVARCHAR( 10),
   @cCCSheetNo    NVARCHAR( 10),
   @nCCCountNo    INT,
   @cUserName     NVARCHAR( 18),
   @nMobile       INT,
   @cLangCode     NVARCHAR( 3),
   @cAttr07  NVARCHAR( 1)       OUTPUT, 
   @cAttr09  NVARCHAR( 1)       OUTPUT, 
   @cAttr11  NVARCHAR( 1)       OUTPUT, 
   @cAttr13  NVARCHAR( 1)       OUTPUT,
   @cOField02   NVARCHAR(60)    OUTPUT,
   @cOField03   NVARCHAR(60)    OUTPUT,
   @cOField04   NVARCHAR(60)    OUTPUT,
   @cOField05   NVARCHAR(60)    OUTPUT,
   @cOField06   NVARCHAR(60)    OUTPUT,
   @cOField07   NVARCHAR(60)    OUTPUT,
   @cOField08   NVARCHAR(60)    OUTPUT,
   @cOField09   NVARCHAR(60)    OUTPUT,
   @cOField10   NVARCHAR(60)    OUTPUT,
   @cOField11   NVARCHAR(60)    OUTPUT,
   @cOField12   NVARCHAR(60)    OUTPUT,
   @cOField13   NVARCHAR(60)    OUTPUT,
   @nSetFocusField INT           OUTPUT,
   @cUseLottable  NVARCHAR( 1)       OUTPUT,
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET ANSI_DEFAULTS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE
    @b_Success       INT
   ,@cNewSKUDescr    NVARCHAR(60)
   ,@cNewSKUDescr1   NVARCHAR(20)
   ,@cNewSKUDescr2   NVARCHAR(20)
   ,@nQty            INT

DECLARE
   @cLotLabel01         NVARCHAR( 20),  
   @cLotLabel02         NVARCHAR( 20),
   @cLotLabel03         NVARCHAR( 20),
   @cLotLabel04         NVARCHAR( 20),
   @cLotLabel05         NVARCHAR( 20),
   @cLottable01_Code    NVARCHAR( 20),
   @cLottable02_Code    NVARCHAR( 20),
   @cLottable03_Code    NVARCHAR( 20),
   @cLottable04_Code    NVARCHAR( 20),
   @cLottable05_Code    NVARCHAR( 20), 
   @cLottableLabel      NVARCHAR( 20),
   @cTempLottable01     NVARCHAR( 18),
   @cTempLottable02     NVARCHAR( 18),
   @cTempLottable03     NVARCHAR( 18),
   @cLottable04         NVARCHAR( 16),
   @cLottable05         NVARCHAR( 16),
   @dTemplottable04     DATETIME,
   @dTempLottable05     DATETIME

   SET @cNewSKUDescr = ''
   SET @cNewSKUDescr1 = ''
   SET @cNewSKUDescr2 = ''

   -- Get ComponentSKU Values (Start) -- (ChewKP01)
   SET @nErrNo = 0
   
   EXEC [RDT].[rdt_GETSKU]  
      @cStorerKey  = @cStorer, 
      @cSKU        = @cNewSKU       OUTPUT,  
      @bSuccess    = @b_success     OUTPUT, 
      @nErr        = @nErrNo        OUTPUT, 
      @cErrMsg     = @cErrMsg       OUTPUT
   
   IF @nErrNo <> 0
   BEGIN
         SET @cErrMsg = @cErrMsg    -- (Kc01) rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
         GOTO FAIL
   END     
   SET @cOField03 = @cNewSKU

   -- Get ComponentSKU Values (End) -- (ChewKP01)

--   -- Check if SKU, ALTSKU, ManufacturerSKU, UPC belong to the storer
--   SET @b_success = 0
--   EXEC dbo.nspg_GETSKU @cStorer, @cNewSKU OUTPUT, @b_success OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
--   IF @b_success = 0
--   BEGIN
--      SET @nErrNo = 71398
--      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid SKU'
--      SET @nSetFocusField = 3
--      GOTO FAIL
--   END

   IF NOT EXISTS (SELECT 1
                  FROM dbo.SKU SKU (NOLOCK)
                  INNER JOIN dbo.PACK PAC (NOLOCK) ON (SKU.PackKey = PAC.PackKey)
                  WHERE SKU.StorerKey = @cStorer
                  AND   SKU.SKU = @cNewSKU )
   BEGIN
      SET @nErrNo = 71399
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'SKU Not Found'
      SET @nSetFocusField = 3
      GOTO FAIL
   END

   SELECT TOP 1 @cNewSKUDescr = SKU.DESCR
   FROM dbo.SKU SKU (NOLOCK)
   WHERE SKU.StorerKey = @cStorer
   AND   SKU.SKU = @cNewSKU

   SET @cNewSKUDescr1 = SUBSTRING( @cNewSKUDescr,  1, 20)
   SET @cNewSKUDescr2 = SUBSTRING( @cNewSKUDescr, 21, 40)

   -- Check if SKU+LOC+ID used by other users
   IF EXISTS ( SELECT 1 
               FROM RDT.RDTCCLock WITH (NOLOCK)
               WHERE CCKey = @cCCRefNo
               AND   SheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN SheetNo ELSE @cCCSheetNo END
               AND   StorerKey = @cStorer
               AND   AddWho <> @cUserName
               AND   SKU = @cNewSKU
               AND   Loc = @cLOC
               AND   Id  = @cID
               AND   (Status < '9') ) -- Status:'0'=not yet process; '1'=partial update qty
   BEGIN      
      SET @nErrNo = 71400
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'SKU In Use'
      SET @nSetFocusField = 3
      GOTO FAIL
   END

   -- Initialize Lottables
   SET @cTempLottable01 = ''
   SET @cTempLottable02 = ''
   SET @cTempLottable03 = ''
   SET @dTempLottable04 = NULL
   SET @dTempLottable05 = NULL

   SET @cAttr07 = ''
   SET @cAttr09 = ''
   SET @cAttr11 = ''
   SET @cAttr13 = ''

   SET @cErrMsg = ''

   -- Get Lottables Details
   EXECUTE rdt.rdt_CycleCount_GetLottables
      @cCCRefNo, @cStorer, @cNewSKU, 'PRE', -- Codelkup.Short
      '', --@cIn_Lottable01
      '', --@cIn_Lottable02
      '', --@cIn_Lottable03
      '', --@dIn_Lottable04
      '', --@dIn_Lottable05
      @cLotLabel01      OUTPUT,
      @cLotLabel02      OUTPUT,
      @cLotLabel03      OUTPUT,
      @cLotLabel04      OUTPUT,
      @cLotLabel05      OUTPUT,
      @cLottable01_Code OUTPUT,
      @cLottable02_Code OUTPUT,
      @cLottable03_Code OUTPUT,
      @cLottable04_Code OUTPUT,
      @cLottable05_Code OUTPUT,
      @cTempLottable01  OUTPUT,  --@cLottable01      OUTPUT,
      @cTempLottable02  OUTPUT,  --@cLottable02      OUTPUT,
      @cTempLottable03  OUTPUT,  --@cLottable03      OUTPUT,
      @dTempLottable04  OUTPUT,  --@dLottable04      OUTPUT,
      @dTempLottable05  OUTPUT,  --@dLottable05      OUTPUT,
      @cUseLottable     OUTPUT,
      @nSetFocusField   OUTPUT,
      @nErrNo           OUTPUT,
      @cErrMsg          OUTPUT

   IF ISNULL(@cErrMsg, '') <> ''
      GOTO FAIL

   -- Initiate next screen var
   IF @cUseLottable = '1'
   BEGIN                 
      -- Clear all outfields for lottables
      SET @cOField06 = ''
      SET @cOField07 = ''
      SET @cOField08 = ''
      SET @cOField09 = ''
      SET @cOField10 = ''
      SET @cOField11 = ''
      SET @cOField12 = ''
      SET @cOField13 = ''

      -- Initiate labels
      SELECT
         @cOField06 = 'Lottable01:',
         @cOField08 = 'Lottable02:',
         @cOField10 = 'Lottable03:',
         @cOField12 = 'Lottable04:'

      --Note: Not to auto populate lottables value; user can decide which lottables to scan in 
      -- Populate labels and lottables
      IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL
      BEGIN
         SET @cAttr07 = 'O'
      END
      ELSE
      BEGIN
         SELECT @cOField06 = @cLotLabel01
         IF ISNULL(@cTempLottable01, '') <> ''
            SELECT @cOField07 = @cTempLottable01
      END

      IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL
      BEGIN
         SET @cAttr09 = 'O'
      END
      ELSE
      BEGIN
         SELECT @cOField08 = @cLotLabel02
         IF ISNULL(@cTempLottable02, '') <> ''
            SELECT @cOField09 = @cTempLottable02
      END

      IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL
      BEGIN
          SET @cAttr11 = 'O'
      END
      ELSE
      BEGIN
         SELECT @cOField10 = @cLotLabel03
         IF ISNULL(@cTempLottable03, '') <> ''
            SELECT @cOField11 = @cTempLottable03
      END

      IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL
      BEGIN
         SET @cAttr13 = 'O'
      END
      ELSE
      BEGIN
         SELECT @cOField12 = @cLotLabel04
         IF ISNULL(@dTempLottable04, '') <> ''
            SELECT @cOField13 = rdt.rdtFormatDate(@dTempLottable04)
      END

      SET @cOField04 = @cNewSKUDescr1
      SET @cOField05 = @cNewSKUDescr2
      SET @nSetFocusField = 7
      GOTO QUIT   
   END -- End of @cUseLottable = '1'
   ELSE
   BEGIN
      SET @cOField04 = @cNewSKUDescr1
      SET @cOField05 = @cNewSKUDescr2
      SET @cOField07 = ''
      SET @cOField09 = ''
      SET @cOField11 = ''
      SET @cOField13 = ''
      SET @cAttr07 = 'O'
      SET @cAttr09 = 'O'
      SET @cAttr11 = 'O'
      SET @cAttr13 = 'O'
   END

   FAIL:  
   QUIT:
      --RETURN


GO