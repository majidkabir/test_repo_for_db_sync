SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_523ExtPA15                                            */
/* Copyright      : LF Logistics                                              */  
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 28-05-2018  1.0  Ung      WMS-5183 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA15] (
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
   
   DECLARE @nTranCount INT
   DECLARE @cSuggToLOC NVARCHAR(10)
   
   SET @nTranCount = @@TRANCOUNT
   SET @cSuggToLOC = '' 

   SELECT @cSuggToLOC = UserDefine01
   FROM SKUConfig WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU
      AND ConfigType = 'NKPALOC'
   
   -- Find a friend (same SKU) 
   IF @cSuggToLOC = ''
      SELECT TOP 1 
         @cSuggToLOC = LOC.LOC
      FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LOC.Facility = @cFacility
         AND LLI.StorerKey = @cStorerKey
         AND LLI.SKU = @cSKU
         AND LLI.QTY-LLI.QTYPicked > 0
         AND LOC.LOC <> @cLOC
      GROUP BY LOC.LOC
      ORDER BY SUM( LLI.QTY-LLI.QTYPicked)
   
   -- Putaway to default LOC
   IF @cSuggToLOC = ''
   BEGIN
      DECLARE @cDefaultPutawayLOC NVARCHAR( 10)
      SET @cDefaultPutawayLOC = rdt.RDTGetConfig( @nFunc, 'DefaultPutawayLOC', @cStorerKey)
      IF @cDefaultPutawayLOC = '0'
         SET @cDefaultPutawayLOC = ''
         
      IF @cDefaultPutawayLOC <> ''
         SET @cSuggToLOC = @cDefaultPutawayLOC
   END
   
   -- Find empty LOC
   IF @cSuggToLOC = ''
      SELECT TOP 1 
         @cSuggToLOC = LOC.LOC
      FROM LOC WITH (NOLOCK)
         LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
      WHERE LOC.Facility = @cFacility
      GROUP BY LOC.PALogicalLOC, LOC.LOC
      HAVING SUM( ISNULL( LLI.QTY, 0)-ISNULL( LLI.QTYPicked, 0)) = 0
         AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
      ORDER BY LOC.PALogicalLOC, LOC.LOC   
   
   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   IF @cSuggToLOC <> ''
   BEGIN
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_523ExtPA15 -- For rollback or commit only our own transaction
      
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

      COMMIT TRAN rdt_523ExtPA15 -- Only commit change made here
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA15 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO