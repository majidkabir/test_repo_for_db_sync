SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1804FetchTask01                                 */
/*                                                                      */
/* Purpose: Fetch next lot to show. Order by largest available qty      */
/*                                                                      */
/* Called by rdtfnc_MoveToUCC                                           */
/*                                                                      */
/* Modifications log:                                                   */
/* Date       Rev  Author     Purposes                                  */
/* 2019-01-09 1.0  James      WMS-7490 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_1804FetchTask01] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cFacility       NVARCHAR( 5),
   @cStorerkey      NVARCHAR( 15),
   @cToLoc          NVARCHAR( 10),
   @cToID           NVARCHAR( 18),
   @cFromLoc        NVARCHAR( 10),
   @cFromID         NVARCHAR( 18),
   @cSKU            NVARCHAR( 20),
   @cLot            NVARCHAR( 10)  OUTPUT,
   @cLottable01     NVARCHAR( 18)  OUTPUT,
   @cLottable02     NVARCHAR( 18)  OUTPUT,
   @cLottable03     NVARCHAR( 18)  OUTPUT,
   @dLottable04     DATETIME       OUTPUT,
   @nCountTotalLot  INT            OUTPUT,
   @nErrNo          INT            OUTPUT,
   @cErrMsg         NVARCHAR( 20)  OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount     INT

   IF @nStep = 5
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- Get batch with most availabe qty
         SELECT TOP 1
            @cLottable01 = LA.Lottable01,
            @cLottable02 = LA.Lottable02,
            @cLottable03 = LA.Lottable03,
            @dLottable04 = LA.Lottable04
         FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
         WHERE LLI.StorerKey = @cStorerKey
         AND LLI.LOC = @cFromLOC
         AND (( ISNULL( @cFromID, '') = '') OR ( LLI.ID = ISNULL(@cFromID, '')))
         AND LLI.SKU = @cSKU
         GROUP BY LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04
         HAVING SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
         ORDER BY SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) DESC,
         LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + ISNULL( CONVERT( NVARCHAR( 10), LA.Lottable04, 112), '') DESC

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 133801
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --No Rec To Move
            GOTO Quit
         END

         SELECT @nRowCount = COUNT(1)
         FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
         WHERE LLI.StorerKey = @cStorerKey
         AND LLI.LOC = @cFromLOC
         AND (( ISNULL( @cFromID, '') = '') OR ( LLI.ID = ISNULL(@cFromID, '')))
         AND LLI.SKU = @cSKU
         GROUP BY LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04
         HAVING SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
         
         SET @nCountTotalLot = @@ROWCOUNT

         SELECT TOP 1 @cLot = LA.Lot
         FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
         WHERE LLI.StorerKey = @cStorerKey
         AND LLI.LOC = @cFromLOC
         AND (( ISNULL( @cFromID, '') = '') OR ( LLI.ID = ISNULL(@cFromID, '')))
         AND LLI.SKU = @cSKU
         AND LA.Lottable01 = @cLottable01
         AND LA.Lottable02 = @cLottable02
         AND LA.Lottable03 = @cLottable03
         AND LA.Lottable04 = @dLottable04
         GROUP BY LA.Lot
         HAVING SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
         ORDER BY SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) DESC
         --SET @cLot = 'dummy'  -- Set lot = dummy as main program didn't use this value when custom fetch task turn on
      END
   END

   IF @nStep = 6
   BEGIN
      IF @nInputKey = 1
      BEGIN
         --delete from TraceInfo where TraceName = '1804_1'
         --insert into TraceInfo (TraceName, TimeIn, Col1, Col2, Col3, Col4, step1, step2, step3, step4) values 
         --('1804_1', getdate(), @cStorerKey, @cFromLOC, @cFromID, @cSKU, @cLottable01, @cLottable02, @cLottable03, @dLottable04)
         -- Get batch with most availabe qty
         SELECT TOP 1
            @cLottable01 = LA.Lottable01,
            @cLottable02 = LA.Lottable02,
            @cLottable03 = LA.Lottable03,
            @dLottable04 = LA.Lottable04
         FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
         WHERE LLI.StorerKey = @cStorerKey
         AND LLI.LOC = @cFromLOC
         AND (( ISNULL( @cFromID, '') = '') OR ( LLI.ID = ISNULL(@cFromID, '')))
         AND LLI.SKU = @cSKU
         AND ( LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + ISNULL( CONVERT( NVARCHAR( 10), LA.Lottable04, 112), '')) <
             ( @cLottable01 + @cLottable02 + @cLottable03 + ISNULL( CONVERT( NVARCHAR( 20), @dLottable04, 112), ''))
         AND ( LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + ISNULL( CONVERT( NVARCHAR( 10), LA.Lottable04, 112), '')) <>
             ( @cLottable01 + @cLottable02 + @cLottable03 + ISNULL( CONVERT( NVARCHAR( 20), @dLottable04, 112), ''))
         GROUP BY LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04
         HAVING SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
         ORDER BY SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) DESC,
         LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + ISNULL( CONVERT( NVARCHAR( 10), LA.Lottable04, 112), '') DESC


         IF @@ROWCOUNT = 0
         BEGIN
            SELECT TOP 1
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = LA.Lottable04
            FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
            WHERE LLI.StorerKey = @cStorerKey
            AND LLI.LOC = @cFromLOC
            AND (( ISNULL( @cFromID, '') = '') OR ( LLI.ID = ISNULL(@cFromID, '')))
            AND LLI.SKU = @cSKU
            GROUP BY LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04
            HAVING SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
            ORDER BY SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) DESC,
            LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + ISNULL( CONVERT( NVARCHAR( 10), LA.Lottable04, 112), '') DESC

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 133802
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --No Rec To Move
               GOTO Quit
            END
         END
      
         SELECT TOP 1 @cLot = LA.Lot
         FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
         WHERE LLI.StorerKey = @cStorerKey
         AND LLI.LOC = @cFromLOC
         AND (( ISNULL( @cFromID, '') = '') OR ( LLI.ID = ISNULL(@cFromID, '')))
         AND LLI.SKU = @cSKU
         AND LA.Lottable01 = @cLottable01
         AND LA.Lottable02 = @cLottable02
         AND LA.Lottable03 = @cLottable03
         AND LA.Lottable04 = @dLottable04
         GROUP BY LA.Lot
         HAVING SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
         ORDER BY SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) DESC
      END
   END

   Quit:

GO