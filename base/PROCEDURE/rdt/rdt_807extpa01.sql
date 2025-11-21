SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_807ExtPA01                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 16-12-2016  1.0  Ung      WMS-752 Created                                  */
/* 25-04-2017  1.1  Ung      WMS-1705 Change hardcode zones to configurable   */
/******************************************************************************/

CREATE PROC [RDT].[rdt_807ExtPA01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18), 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5),
   @cType            NVARCHAR( 10),
   @cCartID          NVARCHAR( 10),
   @cToteID          NVARCHAR( 20),
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
   DECLARE @cLOT        NVARCHAR( 10)
   DECLARE @cLOC        NVARCHAR( 10)
   DECLARE @cID         NVARCHAR( 18)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @nQTY        INT
   DECLARE @cSuggToLOC  NVARCHAR( 10)
   DECLARE @curPA       CURSOR

   SET @nTranCount = @@TRANCOUNT
   
   IF @cType = 'LOCK'
   BEGIN
      -- Check ID booked
      IF EXISTS( SELECT 1 
         FROM RFPutaway R WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (R.FromLOC = LOC.LOC)
         WHERE LOC.Facility = @cFacility
            AND R.FromID = @cToteID)
         GOTO Quit
      
      SET @curPA = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LLI.LOC, LLI.ID, LLI.LOT, LLI.SKU, LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked
         FROM LOTxLOCxID LLI WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
      	WHERE LOC.Facility = @cFacility
      	   AND LLI.StorerKey = @cStorerKey
      	   AND LLI.ID = @cToteID
            AND (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked) > 0
      OPEN @curPA
      FETCH NEXT FROM @curPA INTO @cLOC, @cID, @cLOT, @cSKU, @nQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
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
                  AND LOC.PutawayZone IN (
                     SELECT Short FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTPAZone' AND Code = @cBUSR7 + @cLottable10 AND StorerKey = @cStorerKey AND Code2 = @nFunc)
                  AND (SL.QTY - SL.QTYPicked) > 0
               GROUP BY LOC.LOC, LOC.LogicalLocation, SUBSTRING( SL.SKU, 1, 9)
               ORDER BY 
                  SUM( SL.QTY - SL.QTYPicked), 
                  LOC.LogicalLocation,
                  LOC.LOC
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
                  AND LOC.PutawayZone IN (
                     SELECT Short FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTPAZone' AND Code = @cBUSR7 + @cLottable10 AND StorerKey = @cStorerKey AND Code2 = @nFunc)
                  AND (SL.QTY - SL.QTYPicked) > 0
               GROUP BY LOC.LOC, LOC.LogicalLocation, SUBSTRING( SL.SKU, 1, 9)
               ORDER BY 
                  SUM( SL.QTY - SL.QTYPicked), 
                  LOC.LogicalLocation,
                  LOC.LOC
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
                  AND LOC.PutawayZone IN (
                     SELECT Short FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTPAZone' AND Code = @cBUSR7 + @cLottable10 AND StorerKey = @cStorerKey AND Code2 = @nFunc)
               GROUP BY LOC.LOC, LOC.LogicalLocation, SUBSTRING( SL.SKU, 1, 9)
               HAVING SUM( SL.QTY - SL.QTYPicked) + @nQTY <= 200
               ORDER BY 
                  SUM( SL.QTY - SL.QTYPicked) DESC, 
                  LOC.LogicalLocation, 
                  LOC.LOC
                  
               -- Find in GF2_1500 zone
               IF @cSuggToLOC = ''
                  SELECT TOP 1
                     @cSuggToLOC = LOC.LOC
                  FROM SKUxLOC SL WITH (NOLOCK)
                     JOIN LOC WITH (NOLOCK) ON (SL.LOC = LOC.LOC)
                  WHERE SL.StorerKey = @cStorerKey
                     AND SUBSTRING( SL.SKU, 1, 9) = @cMaterial
                     AND (SL.QTY - SL.QTYPicked) > 0
                     -- AND LOC.PutawayZone = 'GF2_1500' 
                     AND LOC.PutawayZone IN (
                        SELECT Short FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTPAZone' AND Code = @cBUSR7 + @cLottable10 AND StorerKey = @cStorerKey AND Code2 = @nFunc)
                  GROUP BY LOC.LOC, LOC.LogicalLocation, SUBSTRING( SL.SKU, 1, 9)
                  HAVING SUM( SL.QTY - SL.QTYPicked) + @nQTY <= 400
                  ORDER BY 
                     SUM( SL.QTY - SL.QTYPicked) DESC, 
                     LOC.LogicalLocation, 
                     LOC.LOC
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
                  AND LOC.PutawayZone IN (
                     SELECT Short FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTPAZone' AND Code = @cBUSR7 + @cLottable10 AND StorerKey = @cStorerKey AND Code2 = @nFunc)
               GROUP BY LOC.LOC, LOC.LogicalLocation, SUBSTRING( SL.SKU, 1, 9)
               ORDER BY 
                  SUM( SL.QTY - SL.QTYPicked), 
                  LOC.LogicalLocation, 
                  LOC.LOC
            END
         END
         
         /*-------------------------------------------------------------------------------
                                       Book suggested location
         -------------------------------------------------------------------------------*/
         IF @cSuggToLOC <> ''
         BEGIN
            -- Handling transaction
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_807ExtPA01 -- For rollback or commit only our own transaction
            
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
   
            IF @nErrNo <> 0
               GOTO RollBackTran
      
            COMMIT TRAN rdt_807ExtPA01 -- Only commit change made here
         END
      
         FETCH NEXT FROM @curPA INTO @cLOC, @cID, @cLOT, @cSKU, @nQTY
      END
      GOTO Quit
   END
   
   IF @cType = 'UNLOCK'
   BEGIN
      -- Check cart have ID booked
      IF NOT EXISTS( SELECT 1 FROM rdt.rdtPACartLog WITH (NOLOCK) WHERE CartID = @cCartID)
         GOTO Quit
      
      SET @curPA = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT ToteID
         FROM rdt.rdtPACartLog WITH (NOLOCK)
      	WHERE CartID = @cCartID
      OPEN @curPA
      FETCH NEXT FROM @curPA INTO @cID
      WHILE @@FETCH_STATUS = 0
      BEGIN
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_807ExtPA01 -- For rollback or commit only our own transaction
         
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'UNLOCK'
            ,'' --@cLOC
            ,@cID
            ,'' --@cSuggToLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO RollBackTran
   
         COMMIT TRAN rdt_807ExtPA01 -- Only commit change made here
      
         FETCH NEXT FROM @curPA INTO @cID
      END
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_807ExtPA01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO