SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_CycleCount_GetLottables                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get Lottables details                                       */
/*                                                                      */
/* Called from: rdtfnc_CycleCount                                       */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 30-Apr-2009 1.0  MaryVong    Created                                 */
/* 04-Nov-2009 1.1  James       No need to consider Lot05 (james01)     */
/* 22-Dec-2011 1.2  Ung         SOS235351 Handle empty LOC no StorerKey */
/* 18-Dec-2013 1.3  Leong       SOS# 297863 - Select one row only.      */
/* 24-Apr-2014 1.4  James       SOS308961-Get correct codelkup for      */
/*                              lottables                               */
/* 27-Mar-2014 1.5  James       1. Not always get top lot1-4. Follow    */
/*                              what is return from wrapper (james02)   */
/*                              2. Fix codelkup retrieve if > 1 storer  */
/*                              No need join rdt.storerconfig           */
/* 20-Apr-2017 1.6  James       Remove ANSI_WARNINGS (james03)          */
/************************************************************************/

CREATE PROC [RDT].[rdt_CycleCount_GetLottables] (
   @cCCRefNo         NVARCHAR( 10),
   @cStorer          NVARCHAR( 15),
   @cSKU             NVARCHAR( 20),
   @cClkupShort      NVARCHAR( 10), -- 'PRE' or 'POST'
   @cIn_Lottable01   NVARCHAR( 18),
   @cIn_Lottable02   NVARCHAR( 18),
   @cIn_Lottable03   NVARCHAR( 18),
   @dIn_Lottable04   DATETIME,
   @dIn_Lottable05   DATETIME,
   @cLotLabel01      NVARCHAR( 20) OUTPUT,
   @cLotLabel02      NVARCHAR( 20) OUTPUT,
   @cLotLabel03      NVARCHAR( 20) OUTPUT,
   @cLotLabel04      NVARCHAR( 20) OUTPUT,
   @cLotLabel05      NVARCHAR( 20) OUTPUT,
   @cLottable01_Code NVARCHAR( 20) OUTPUT,
   @cLottable02_Code NVARCHAR( 20) OUTPUT,
   @cLottable03_Code NVARCHAR( 20) OUTPUT,
   @cLottable04_Code NVARCHAR( 20) OUTPUT,
   @cLottable05_Code NVARCHAR( 20) OUTPUT,
   @cOut_Lottable01  NVARCHAR( 18) OUTPUT,
   @cOut_Lottable02  NVARCHAR( 18) OUTPUT,
   @cOut_Lottable03  NVARCHAR( 18) OUTPUT,
   @dOut_Lottable04  DATETIME  OUTPUT,
   @dOut_Lottable05  DATETIME  OUTPUT,
   @cHasLottable     NVARCHAR( 1)  OUTPUT,
   @nSetFocusField   INT       OUTPUT,
   @nErrNo           INT       OUTPUT,
   @cErrMsg          NVARCHAR( 1024) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLottableLabel NVARCHAR( 20),
      @cListName           NVARCHAR( 20),
      @cStoredProd         NVARCHAR( 250),
      @nCountLot           INT,
      @b_Success           INT

   -- Get labels of lottables
   SELECT
      @cLotLabel01 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable01Label AND C.ListName = 'LOTTABLE01' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''), -- SOS# 297863/308961
      @cLotLabel02 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''), -- SOS# 297863/308961
      @cLotLabel03 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''), -- SOS# 297863/308961
      @cLotLabel04 = IsNULL(( SELECT TOP 1 C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> '' AND (C.StorerKey = @cStorer OR C.Storerkey = '') ORDER By C.StorerKey DESC), ''), -- SOS# 297863/308961
      -- @cLotLabel05 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable05Label AND C.ListName = 'LOTTABLE05' AND C.Code <> ''), ''),
      @cLottable01_Code = IsNULL( S.Lottable01Label, ''),
      @cLottable02_Code = IsNULL( S.Lottable02Label, ''),
      @cLottable03_Code = IsNULL( S.Lottable03Label, ''),
      @cLottable04_Code = IsNULL( S.Lottable04Label, '')
      -- @cLottable05_Code = IsNULL( S.Lottable05Label, '') (james01)
   FROM dbo.SKU S (NOLOCK)
   WHERE StorerKey = @cStorer
   AND   SKU = @cSKU

   -- Turn on Lottable Flag
   SET @cHasLottable = '0'

   IF (@cLotLabel01 <> '' AND @cLotLabel01 IS NOT NULL) OR
      (@cLotLabel02 <> '' AND @cLotLabel02 IS NOT NULL) OR
      (@cLotLabel03 <> '' AND @cLotLabel03 IS NOT NULL) OR
      (@cLotLabel04 <> '' AND @cLotLabel04 IS NOT NULL) --OR
      -- (@cLotLabel05 <> '' AND @cLotLabel05 IS NOT NULL)   (james01)
   SET @cHasLottable = '1'

   IF @cHasLottable = '0' GOTO Quit

   /***********************************************************************************************************************/
   /* SOS#81879 Start - 'PRE' or 'POST'                                                                                   */
   /* Generic Lottables Computation: To compute Lottables before go to Lottable Screen (PRE) or after input values (POST) */
   /* Setup spname in CODELKUP.Long where ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05'     */
   /* 1. Setup RDT.Storerconfigkey = <Lottable01/02/03/04/05> , sValue = <Lottable01/02/03/04/05Label>                    */
   /* 2. Setup Codelkup.Listname = ListName = 'LOTTABLE01'/'LOTTABLE02'/'LOTTABLE03'/'LOTTABLE04'/'LOTTABLE05' and        */
   /*    Codelkup.Short = ('PRE' or 'POST') and Codelkup.Long = <SP Name>                                                 */
   /***********************************************************************************************************************/

   -- Initiate @nCounter = 1
   SET @nCountLot = 1

   -- Retrieve value for lottable01 - 05
   WHILE @nCountLot <= 5 --break the loop when @nCount > 5
   BEGIN
      IF @nCountLot = 1
      BEGIN
         SET @cListName = 'Lottable01'
         SET @cLottableLabel = @cLottable01_Code
      END
      ELSE
      IF @nCountLot = 2
      BEGIN
         SET @cListName = 'Lottable02'
         SET @cLottableLabel = @cLottable02_Code
      END
      ELSE
      IF @nCountLot = 3
      BEGIN
         SET @cListName = 'Lottable03'
         SET @cLottableLabel = @cLottable03_Code
      END
      ELSE
      IF @nCountLot = 4
      BEGIN
         SET @cListName = 'Lottable04'
           SET @cLottableLabel = @cLottable04_Code
      END
      ELSE
      IF @nCountLot = 5
      BEGIN
         SET @cListName = 'Lottable05'
         SET @cLottableLabel = @cLottable05_Code
      END

      -- Get Store procedure and lottablelable value for each lottable
      SET @cStoredProd = ''
      SELECT TOP 1 @cStoredProd = IsNULL(RTRIM(C.Long), '')
      FROM dbo.CodeLkUp C WITH (NOLOCK)
      WHERE C.ListName = @cListName
      AND   C.Code = @cLottableLabel
      AND   C.Short = @cClkupShort
      AND  (C.StorerKey = @cStorer OR C.Storerkey = '') --SOS308961
      ORDER By C.StorerKey DESC

      IF @cStoredProd <> ''
      BEGIN
         EXEC dbo.ispLottableRule_Wrapper
            @c_SPName            = @cStoredProd,
            @c_ListName          = @cListName,
            @c_Storerkey         = @cStorer,
            @c_Sku               = @cSKU,
            @c_LottableLabel     = @cLottableLabel,
            @c_Lottable01Value   = @cIn_Lottable01,
            @c_Lottable02Value   = @cIn_Lottable02,
            @c_Lottable03Value   = @cIn_Lottable03,
            @dt_Lottable04Value  = @dIn_Lottable04,
            @dt_Lottable05Value  = @dIn_Lottable05,
            @c_Lottable01        = @cOut_Lottable01 OUTPUT,
            @c_Lottable02        = @cOut_Lottable02 OUTPUT,
            @c_Lottable03        = @cOut_Lottable03 OUTPUT,
            @dt_Lottable04       = @dOut_Lottable04 OUTPUT,
            @dt_Lottable05       = @dOut_Lottable05 OUTPUT,
            @b_Success           = @b_Success       OUTPUT,
            @n_Err               = @nErrNo          OUTPUT,
            @c_Errmsg            = @cErrMsg         OUTPUT,
            @c_Sourcekey         = @cCCRefNo,
            @c_Sourcetype        = 'RDTCCOUNT'

         IF ISNULL(@cErrMsg, '') <> ''
         BEGIN
            SET @cErrMsg = @cErrMsg

            IF @cListName = 'Lottable01'
            BEGIN
               SET @nSetFocusField = 2
               IF ISNULL(@cOut_Lottable01, '') = ''
                  SELECT @cOut_Lottable01 = Lottable01 FROM dbo.CCDetail WITH (NOLOCK)
                  WHERE CCKEY = @cCCRefNo
                     AND SKU = @cSKU
                     AND Status < '2'
                  ORDER BY LOT
            END
            ELSE IF @cListName = 'Lottable02'
            BEGIN
               SET @nSetFocusField = 4
               IF ISNULL(@cOut_Lottable02, '') = ''
               BEGIN
                  SELECT @cOut_Lottable02 = Lottable02 FROM dbo.CCDetail WITH (NOLOCK)
                  WHERE CCKEY = @cCCRefNo
                     AND SKU = @cSKU
                     AND Status < '2'
                  ORDER BY LOT
                  IF @@ROWCOUNT = 0
                     SET @cOut_Lottable02 = '111'
               END
            END
            ELSE IF @cListName = 'Lottable03'
               SET @nSetFocusField = 6
            ELSE IF @cListName = 'Lottable04'
               SET @nSetFocusField = 8

            GOTO QUIT
            BREAK
         END
      END
      -- Increase counter by 1
      SET @nCountLot = @nCountLot + 1
   END -- WHILE @nCountLot <= 5
   /***********************************************************************************************************************/
   /* SOS#81879 - End                                                                                                     */
   /* Generic Lottables Computation: To compute Lottables before go to Lottable Screen (PRE) or after input values (POST) */
   /***********************************************************************************************************************/
   /* comment (james02)
   IF @cLotLabel01 <> '' AND ISNULL(@cOut_Lottable01, '') = '' AND @cClkupShort = 'PRE'
   BEGIN
      SELECT TOP 1 @cOut_Lottable01 = Lottable01 FROM dbo.CCDetail WITH (NOLOCK)
      WHERE CCKEY = @cCCRefNo
         AND SKU = @cSKU
         AND Status < '2'
      ORDER BY LOT
   END
   IF @cLotLabel02 <> '' AND ISNULL(@cOut_Lottable02, '') = '' AND @cClkupShort = 'PRE'
   BEGIN
      SELECT TOP 1 @cOut_Lottable02 = Lottable02 FROM dbo.CCDetail WITH (NOLOCK)
      WHERE CCKEY = @cCCRefNo
         AND SKU = @cSKU
         AND Status < '2'
      ORDER BY LOT
   END
   IF @cLotLabel03 <> '' AND ISNULL(@cOut_Lottable03, '') = '' AND @cClkupShort = 'PRE'
   BEGIN
      SELECT TOP 1 @cOut_Lottable03 = Lottable03 FROM dbo.CCDetail WITH (NOLOCK)
      WHERE CCKEY = @cCCRefNo
         AND SKU = @cSKU
         AND Status < '2'
      ORDER BY LOT
   END
   IF @cLotLabel04 <> '' AND ISNULL(@dOut_Lottable04, '') = '' AND @cClkupShort = 'PRE'
   BEGIN
      SELECT TOP 1 @dOut_Lottable04 = Lottable04 FROM dbo.CCDetail WITH (NOLOCK)
      WHERE CCKEY = @cCCRefNo
         AND SKU = @cSKU
         AND Status < '2'
      ORDER BY LOT
   END*/
   QUIT:

END

GO