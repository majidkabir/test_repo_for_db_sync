SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_523ExtPA36                                            */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date        Rev  Author    Purposes                                        */
/* 2021-03-02  1.0  Chermaine WMS-16392. Created (dup rdt_523ExtPA27)         */
/******************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA36] (
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
   
   DECLARE @nTranCount     INT
   DECLARE @cSuggToLOC     NVARCHAR( 10) = ''

   
   SET @nTranCount = @@TRANCOUNT
   
      -- Find a friend 
   SELECT TOP 1 
      @cSuggToLOC = LOC.LOC
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)
   WHERE LOC.Facility = @cFacility
   AND   LOC.LOC <> @cLOC
   AND   LOC.LocLevel = '1'
   AND   LLI.StorerKey = @cStorerKey
   AND   LLI.SKU = @cSKU
   GROUP BY LOC.LOC
   HAVING SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) > 0
   ORDER BY SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen) ASC, LOC.Loc
    
   -- Find NearBy location
   IF @cSuggToLOC = ''
   BEGIN      
      SELECT TOP 1   
         @cSuggToLOC = LOC.LOC  
      FROM LOC LOC WITH (NOLOCK)       
      LEFT OUTER JOIN LotxLocxID LLI WITH (NOLOCK, INDEX=IDX_LOTxLOCxID_LOC) ON (LLI.Loc = Loc.Loc AND LLI.StorerKey = @cStorerKey )  
      WHERE LOC.Facility = @cFacility 
      AND LOC.LOC <> @cLOC 
      AND LOC.LocLevel = '1'  
      AND Loc.putawayzone = 'SNPKZONE'
      GROUP BY LOC.LOC  
      HAVING SUM( ISNULL( LLI.QTY, 0) - ISNULL( LLI.QTYPicked, 0)) = 0 
         AND SUM( ISNULL( LLI.PendingMoveIn, 0)) = 0
      ORDER BY LOC.Loc ASC 
           
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = -1  
         GOTO Quit
      END
   END

   

   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_523ExtPA36 -- For rollback or commit only our own transaction

   IF @cSuggToLOC <> ''
   BEGIN
      SET @nErrNo = 0
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cLOC
         ,@cID
         ,@cSuggToLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cSKU          = @cSKU
         ,@nPutawayQTY   = @nQTY
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      SET @cSuggestedLOC = @cSuggToLOC

      COMMIT TRAN rdt_523ExtPA36 -- Only commit change made here
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA36 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO