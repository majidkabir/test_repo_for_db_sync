SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP33                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2021-04-30  1.0  James    WMS-16792. Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP33] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18),
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cFromLOC         NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cSuggLOC         NVARCHAR( 10)  OUTPUT,
   @cPickAndDropLOC  NVARCHAR( 10)  OUTPUT,
   @cFitCasesInAisle NVARCHAR( 1)   OUTPUT,
   @nPABookingKey    INT            OUTPUT, 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT
   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @cLOT              NVARCHAR( 10)
   DECLARE @cLottable03       NVARCHAR( 18)

   SET @nTranCount = @@TRANCOUNT
   SET @cSuggLOC = ''

   -- Get pallet info
   SELECT TOP 1 
      @cLOT = LOT, 
      @cSKU = LLI.Sku
   FROM LOTxLOCxID LLI WITH (NOLOCK) 
   JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LOC.Facility = @cFacility
   AND   LLI.LOC = @cFromLOC 
   AND   LLI.ID = @cID 
   AND   LLI.QTY > 0
   ORDER BY 1

   SELECT @cLottable03 = Lottable03
   FROM dbo.LOTATTRIBUTE WITH (NOLOCK)
   WHERE Lot = @cLOT
   
   -- Find friend with min qty
   SELECT TOP 1 
      @cSuggLOC = LOC.LOC
   FROM LOTxLOCxID LLI WITH (NOLOCK)
   JOIN LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
   WHERE LOC.Facility = @cFacility
   AND   LOC.[Status] <> 'HOLD' 
   AND   LOC.LocationFlag = 'NONE'
   AND   LLI.StorerKey = @cStorerKey
   AND   LLI.SKU = @cSKU
   AND   LA.Lottable03 = @cLottable03
   AND (( Qty - QtyPicked > 0) OR ( PendingMoveIn > 0))
   AND   EXISTS( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK) 
                 WHERE C.LISTNAME = 'CUSTPARAM' 
                 AND   C.StorerKey = @cStorerKey
                 AND   C.Code = 'PUTLOCCAT' 
                 AND   C.code2 = LOC.LocationCategory)
   ORDER BY ( Qty - QtyPicked), PendingMoveIn 

   -- Lock suggested location
   IF @cSuggLOC <> '' 
   BEGIN
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1819ExtPASP33 -- For rollback or commit only our own transaction
      
      IF @cFitCasesInAisle <> 'Y'
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
            ,@cFromLOC
            ,@cID
            ,@cSuggLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      -- Lock PND location
      IF @cPickAndDropLOC <> ''
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
            ,@cFromLOC
            ,@cID
            ,@cPickAndDropLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      COMMIT TRAN rdt_1819ExtPASP33 -- Only commit change made here
   END
   
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1819ExtPASP33 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO