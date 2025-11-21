SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_523ExtPA01                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 07-12-2016  1.0  Ung      WMS-751 Created                                  */
/* 02-05-2017  1.1  Ung      WMS-1660 Change hardcode zones to configurable   */
/* 06-09-2017  1.2  Ung      WMS-1660 Add facility                            */
/* 11-10-2018  1.3  Ung      WMS-6567 Change code lookup setup                */
/* 22-11-2018  1.4  Ung      WMS-6567 Remove putaway to empty LOC             */
/* 21-10-2022  1.5  Ung      WMS-20980 Change LocationFlag                    */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_523ExtPA01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18), 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5),
   @cLOC             NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cLOT             NVARCHAR( 10),
   @cUCC             NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cSuggestedLOC    NVARCHAR( 10)  OUTPUT,
   @nPABookingKey    INT            OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount  INT
   DECLARE @cLottable10 NVARCHAR( 30)
   DECLARE @cBUSR7      NVARCHAR( 30)
   DECLARE @cMaterial   NVARCHAR( 9) -- Style
   DECLARE @cSuggToLOC  NVARCHAR( 10)
   
   SET @nTranCount = @@TRANCOUNT
   SET @cSuggToLOC = ''
   
   -- Get SKU info
   SELECT @cLottable10 = Lottable10 FROM LOTAttribute WITH (NOLOCK) WHERE LOT = @cLOT
   SELECT @cBUSR7 = BUSR7 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
   SET @cMaterial = SUBSTRING( @cSKU, 1, 9)
   
   /*
      L10 is return stock grade:
         A = A grade
         B = B grade
         C = C grade
         D = D grade
         
      BUSR7
         10 = APPAREL
         20 = FOOTWEAR
         30 = EQUIPMENT
   */

   -- Apparel, equipment
   IF @cBUSR7 IN ('10', '30')
   BEGIN
      -- A grade stock
      IF @cLottable10 = 'A'
      BEGIN
         SELECT TOP 1
            @cSuggToLOC = LOC.LOC
         FROM SKUxLOC SL WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
         WHERE SL.StorerKey = @cStorerKey
            AND SUBSTRING( SL.SKU, 1, 9) = @cMaterial
            -- AND LOC.PutawayZone = 'MEZ2_BASKT'
            AND LOC.Facility = @cFacility
            AND LOC.PutawayZone IN (
               SELECT Long FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTPAZone' AND Short = @cBUSR7 + @cLottable10 AND StorerKey = @cStorerKey AND Code2 = @nFunc)
            AND (SL.QTY - SL.QTYPicked) > 0
         GROUP BY LOC.LOC, LOC.LogicalLocation, SUBSTRING( SL.SKU, 1, 9)
         ORDER BY 
            SUM( SL.QTY - SL.QTYPicked), 
            LOC.LogicalLocation,
            LOC.LOC
/*      
         IF @cSuggToLOC = ''
            SELECT TOP 1
               @cSuggToLOC = LOC.LOC
            FROM LOTxLOCxID LLI WITH (NOLOCK)
               JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LOC.PutawayZone IN (
                  SELECT Long FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTPAZone' AND Short = @cBUSR7 + @cLottable10 AND StorerKey = @cStorerKey AND Code2 = @nFunc)
            GROUP BY LOC.LOC, LOC.LogicalLocation
            HAVING ISNULL( SUM( QTY-QTYPicked), 0) = 0
               AND ISNULL( SUM( PendingMoveIn), 0) = 0
            ORDER BY 
               LOC.LogicalLocation, 
               LOC.LOC
*/
      END
      
      -- B grade stock
      ELSE IF @cLottable10 = 'B'
      BEGIN
         SELECT TOP 1
            @cSuggToLOC = LOC.LOC
         FROM SKUxLOC SL WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
         WHERE SL.StorerKey = @cStorerKey
            AND SUBSTRING( SL.SKU, 1, 9) = @cMaterial
            -- AND LOC.PutawayZone = 'NIK_BASKTB'
            AND LOC.Facility = @cFacility
            AND LOC.PutawayZone IN (
               SELECT Long FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTPAZone' AND Short = @cBUSR7 + @cLottable10 AND StorerKey = @cStorerKey AND Code2 = @nFunc)
            AND LOC.LocationFlag = 'NONE'
            AND LOC.LOC NOT IN ('81RB', 'F1RB', 'F1RBE')
            AND (SL.QTY - SL.QTYPicked) > 0
         GROUP BY LOC.LOC, LOC.LogicalLocation, SUBSTRING( SL.SKU, 1, 9)
         ORDER BY 
            SUM( SL.QTY - SL.QTYPicked), 
            LOC.LogicalLocation,
            LOC.LOC
/*
         IF @cSuggToLOC = ''
            SELECT TOP 1
               @cSuggToLOC = LOC.LOC
            FROM LOTxLOCxID LLI WITH (NOLOCK)
               JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LOC.PutawayZone IN (
                  SELECT Long FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTPAZone' AND Short = @cBUSR7 + @cLottable10 AND StorerKey = @cStorerKey AND Code2 = @nFunc)
               AND LOC.LocationFlag = 'HOLD'
            GROUP BY LOC.LOC, LOC.LogicalLocation
            HAVING ISNULL( SUM( QTY-QTYPicked), 0) = 0
               AND ISNULL( SUM( PendingMoveIn), 0) = 0
            ORDER BY 
               LOC.LogicalLocation, 
               LOC.LOC
*/
      END
   END
   
   -- Footware
   IF @cBUSR7 = '20'
   BEGIN
      -- A grade stock
      IF @cLottable10 = 'A'
      BEGIN
         -- Find in MEZ2_750 zone
         SELECT TOP 1
            @cSuggToLOC = LOC.LOC
         FROM SKUxLOC SL WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
         WHERE SL.StorerKey = @cStorerKey
            AND SUBSTRING( SL.SKU, 1, 9) = @cMaterial
            AND (SL.QTY - SL.QTYPicked) > 0
            -- AND LOC.PutawayZone = 'MEZ2_750' 
            AND LOC.Facility = @cFacility
            AND LOC.PutawayZone IN (
               SELECT Long FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTPAZone' AND Short = @cBUSR7 + @cLottable10 AND StorerKey = @cStorerKey AND Code2 = @nFunc)
         GROUP BY LOC.LOC, LOC.LogicalLocation, SUBSTRING( SL.SKU, 1, 9)
         -- HAVING SUM( SL.QTY - SL.QTYPicked) + @nQTY <= 200
         ORDER BY 
            SUM( SL.QTY - SL.QTYPicked), 
            LOC.LogicalLocation, 
            LOC.LOC
/*
         IF @cSuggToLOC = ''
            SELECT TOP 1
               @cSuggToLOC = LOC.LOC
            FROM LOTxLOCxID LLI WITH (NOLOCK)
               JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LOC.PutawayZone IN (
                  SELECT Long FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTPAZone' AND Short = @cBUSR7 + @cLottable10 AND StorerKey = @cStorerKey AND Code2 = @nFunc)
            GROUP BY LOC.LOC, LOC.LogicalLocation
            HAVING ISNULL( SUM( QTY-QTYPicked), 0) = 0
               AND ISNULL( SUM( PendingMoveIn), 0) = 0
            ORDER BY 
               LOC.LogicalLocation, 
               LOC.LOC
*/
      END
      
      -- B grade stock
      ELSE IF @cLottable10 = 'B'
      BEGIN
         SELECT TOP 1
            @cSuggToLOC = LOC.LOC
         FROM SKUxLOC SL WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
         WHERE SL.StorerKey = @cStorerKey
            AND SUBSTRING( SL.SKU, 1, 9) = @cMaterial
            AND (SL.QTY - SL.QTYPicked) > 0
            -- AND LOC.PutawayZone = 'MEZ2_750B' 
            AND LOC.Facility = @cFacility
            AND LOC.PutawayZone IN (
               SELECT Long FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTPAZone' AND Short = @cBUSR7 + @cLottable10 AND StorerKey = @cStorerKey AND Code2 = @nFunc)
            AND LOC.LocationFlag = 'NONE'
            AND LOC.LOC NOT IN ('81RB', 'F1RB', 'F1RBE')
         GROUP BY LOC.LOC, LOC.LogicalLocation, SUBSTRING( SL.SKU, 1, 9)
         ORDER BY 
            SUM( SL.QTY - SL.QTYPicked), 
            LOC.LogicalLocation, 
            LOC.LOC
/*
         IF @cSuggToLOC = ''
            SELECT TOP 1
               @cSuggToLOC = LOC.LOC
            FROM LOTxLOCxID LLI WITH (NOLOCK)
               JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LOC.PutawayZone IN (
                  SELECT Long FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTPAZone' AND Short = @cBUSR7 + @cLottable10 AND StorerKey = @cStorerKey AND Code2 = @nFunc)
               AND LOC.LocationFlag = 'HOLD'
            GROUP BY LOC.LOC, LOC.LogicalLocation
            HAVING ISNULL( SUM( QTY-QTYPicked), 0) = 0
               AND ISNULL( SUM( PendingMoveIn), 0) = 0
            ORDER BY 
               LOC.LogicalLocation, 
               LOC.LOC
*/
      END
   END
   
   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   IF @cSuggToLOC <> ''
   BEGIN
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_523ExtPA01 -- For rollback or commit only our own transaction
      
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cLOC
         ,@cID
         ,@cSuggToLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cSKU          = @cSKU
         ,@nPutawayQTY   = @nQTY
         ,@cFromLOT      = @cLOT
         ,@cUCCNo        = @cUCC
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      SET @cSuggestedLOC = @cSuggToLOC

      COMMIT TRAN rdt_523ExtPA01 -- Only commit change made here
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO