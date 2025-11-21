SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_523ExtPA28                                            */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date        Rev  Author    Purposes                                        */
/* 2020-01-28  1.0  Chermaine WMS-11747 Created                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA28] (
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
   DECLARE @cLottable01    NVARCHAR( 20)
   DECLARE @cLottable02    NVARCHAR( 20)

   
   SET @nTranCount = @@TRANCOUNT
   
   SELECT  
      @cLottable01 = Lottable01,  
      @cLottable02 = Lottable02
   FROM LOTAttribute WITH (NOLOCK)
   WHERE LOT = @cLOT

   -- Find a friend with max QTY   
   SELECT TOP 1  
      @cSuggToLOC = LOC.LOC
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
   JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON ( LLI.LOT = LA.LOT)
   --JOIN dbo.UCC U WITH (NOLOCK) ON ( U.sku = LLI.SKU AND U.Storerkey = LLI.StorerKey)
   --JOIN dbo.receiptDetail RD WITH (NOLOCK) ON ( U.Receiptkey = RD.ReceiptKey AND U.Storerkey = RD.StorerKey)
   --JOIN dbo.PODETAIL PD WITH (NOLOCK) ON ( RD.POKey = PD.POKey AND RD.POLineNumber = PD.POLineNumber AND PD.Lottable01 = LA.Lottable01 AND PD.Lottable02 = LA.Lottable02)
   WHERE LOC.Facility = @cFacility
   AND LOC.LOC <> @cLOC
   AND LOC.LocLevel = '1'
   AND LLI.StorerKey = @cStorerKey
   AND   LLI.SKU = @cSKU
   AND LA.Lottable01 = @cLottable01
   AND LA.Lottable02 = @cLottable02
   GROUP BY LOC.LOC
   ORDER BY SUM( lli.Qty - lli.QtyAllocated - lli.QtyPicked - LLI.QtyReplen), LOC.Loc

   IF @@ROWCOUNT = 0
   BEGIN
      SET @cSuggestedLOC = 'NONE'
      GOTO Quit
   END

   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_523ExtPA28 -- For rollback or commit only our own transaction

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

      COMMIT TRAN rdt_523ExtPA28 -- Only commit change made here
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA28 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO