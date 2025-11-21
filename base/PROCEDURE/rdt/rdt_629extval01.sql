SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_629ExtVal01                                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Validate Qty to move must be equal to Qty available         */
/*          in same loc, id + lottables (regardless sku)                */
/*                                                                      */
/* Called from: rdtfnc_Move_SKU_Lottable_V7                             */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author      Purposes                               */
/* 03-Jul-2018  1.0  James       WMS2430. Created                       */
/************************************************************************/
CREATE PROC [RDT].[rdt_629ExtVal01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @cFromLOC       NVARCHAR( 10),
   @cFromID        NVARCHAR( 18),
   @cSKU           NVARCHAR( 20),
   @nQTY           INT,          
   @cToID          NVARCHAR( 18),
   @cToLOC         NVARCHAR( 10),
   @cLottableCode  NVARCHAR( 30),
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,     
   @dLottable05    DATETIME,     
   @cLottable06    NVARCHAR( 30),
   @cLottable07    NVARCHAR( 30),
   @cLottable08    NVARCHAR( 30),
   @cLottable09    NVARCHAR( 30),
   @cLottable10    NVARCHAR( 30),
   @cLottable11    NVARCHAR( 30),
   @cLottable12    NVARCHAR( 30),
   @dLottable13    DATETIME,     
   @dLottable14    DATETIME,     
   @dLottable15    DATETIME,     
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT   
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

 
   DECLARE 
      @nQTY_Bal      INT,
      @nQTY_LLI      INT,
      @nQTY_Avail    INT,
      @cSKU2Move     NVARCHAR( 20),
      @cMUOM_Desc    NVARCHAR( 5),
      @cUserName     NVARCHAR( 18),
      @cLOT          NVARCHAR( 10),
      @cWhere        NVARCHAR( MAX),
      @curLLI        CURSOR,
      @cGroupBy      NVARCHAR( MAX),
      @cOrderBy      NVARCHAR( MAX),
      @cSQL          NVARCHAR( MAX),
      @cSQLParam     NVARCHAR( MAX)

   -- Get lottable filter
   EXEC rdt.rdt_Lottable_GetCurrentSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLottableCode, 5, 'LA', 
      @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
      @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
      @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
      @cWhere   OUTPUT,
      @nErrNo   OUTPUT,
      @cErrMsg  OUTPUT

   -- Get SKU QTY
   SET @nQTY_Avail = 0
   SET @cSQL = ''
   SET @cSQL = 
   ' SELECT @nQTY_Avail = SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) ' +
   ' FROM dbo.LOTxLOCxID LLI(NOLOCK) ' +
   ' INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (LLI.LOT = LA.LOT) ' +
   ' WHERE LLI.StorerKey = @cStorerKey ' +
   ' AND   LLI.LOC = @cFromLOC ' +
   ' AND   (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0 ' +
   ' AND   LLI.ID = CASE WHEN ISNULL( @cFromID, '''') = '''' THEN LLI.ID ELSE @cFromID END ' +
   CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END 

   SET @cSQLParam = 
      ' @cStorerKey  NVARCHAR( 15), ' + 
      ' @cFromLOC    NVARCHAR( 10), ' + 
      ' @cFromID     NVARCHAR( 18), ' + 
      ' @cSKU        NVARCHAR( 20), ' + 
      ' @cLottable01 NVARCHAR( 18), ' + 
      ' @cLottable02 NVARCHAR( 18), ' + 
      ' @cLottable03 NVARCHAR( 18), ' + 
      ' @dLottable04 DATETIME,      ' + 
      ' @dLottable05 DATETIME,      ' + 
      ' @cLottable06 NVARCHAR( 30), ' + 
      ' @cLottable07 NVARCHAR( 30), ' + 
      ' @cLottable08 NVARCHAR( 30), ' + 
      ' @cLottable09 NVARCHAR( 30), ' + 
      ' @cLottable10 NVARCHAR( 30), ' + 
      ' @cLottable11 NVARCHAR( 30), ' + 
      ' @cLottable12 NVARCHAR( 30), ' + 
      ' @dLottable13 DATETIME,      ' + 
      ' @dLottable14 DATETIME,      ' + 
      ' @dLottable15 DATETIME,      ' + 
      ' @nQTY_Avail  INT           OUTPUT '

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cStorerKey, @cFromLOC, @cFromID, @cSKU, 
      @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
      @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
      @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
      @nQTY_Avail OUTPUT

      IF @nQTY_Avail <> @nQTY
      BEGIN
         SET @nErrNo = 125851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'QtyAvl<>Qty2Mv'
         GOTO Quit
      END

   Quit:
END

GO