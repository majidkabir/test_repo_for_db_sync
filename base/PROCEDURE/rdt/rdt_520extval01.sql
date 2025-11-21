SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_520ExtVal01                                     */
/* Purpose: Check SuggestedLOC and final LOC                            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2014-04-07   Ung       1.0   SOS307608 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_520ExtVal01]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cID             NVARCHAR( 18),
   @cFromLOC        NVARCHAR( 10),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,
   @cSuggestedLOC   NVARCHAR( 10),
   @cFinalLOC       NVARCHAR( 10),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Putaway by SKU
   IF @nFunc = 520
   BEGIN
      IF @nStep = 3 -- SuggestedLOC, FinalLOC
      BEGIN
         -- LOC not match
         IF @cSuggestedLOC <> @cFinalLOC
         BEGIN
            DECLARE @nLLIQTY INT
            DECLARE @nIDCount INT
            SELECT 
               @nIDCount = COUNT( DISTINCT ID), 
               @nLLIQTY = ISNULL( SUM( QTY-QTYAllocated), 0)
            FROM LOTxLOCxID WITH (NOLOCK) 
            WHERE LOC = @cFinalLOC
               AND QTY-QTYAllocated > 0
            
            DECLARE @nMaxPallet INT
            SELECT @nMaxPallet = MaxPallet FROM LOC WITH (NOLOCK) WHERE LOC = @cFinalLOC
         
            -- Check for single or double deep only
            IF @nMaxPallet IN (1,2) 
            BEGIN
               -- Check reach max pallet. Note: blank ID counted as 1 ID
               IF (@nIDCount >= @nMaxPallet) 
               BEGIN
                  SET @nErrNo = 86401
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Empty LOC only
                  GOTO Quit
               END
               
               -- Final LOC have stock
               IF @nIDCount > 0
               BEGIN
                  -- Get putaway stock Lottable04
                  DECLARE @dLottable04 DATETIME
                  SELECT @dLottable04 = ISNULL( LA.Lottable04, 0)
                  FROM LOTxLOCxID LLI WITH (NOLOCK) 
                     JOIN LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
                  WHERE LLI.ID = @cID
                     AND LLI.SKU = @cSKU
                     AND QTY > 0
                  
                  -- Check putaway stock and existing stock, same SKU and L04
                  IF EXISTS( SELECT TOP 1 1
                     FROM LOTxLOCxID LLI WITH (NOLOCK) 
                        JOIN LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
                     WHERE LLI.LOC = @cFinalLOC
                        AND LLI.QTY-LLI.QTYAllocated > 0
                        AND (LLI.SKU <> @cSKU OR ISNULL( LA.Lottable04, 0) <> @dLottable04))
                  BEGIN
                     SET @nErrNo = 86402
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff SKU or L4
                     GOTO Quit
                  END
               END
            END
         END
      END
   END
   
Quit:

END

GO