SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP30                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2020-05-19   1.0  James    WMS-12964. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP30] (
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

   DECLARE @cUCC  NVARCHAR( 20), 
           @cLOT  NVARCHAR( 10), 
           @cLOC  NVARCHAR( 10), 
           @cSKU  NVARCHAR( 20),
           @cPAType  NVARCHAR( 10),
           @cPAStrategyKey NVARCHAR( 10),
           @nCnt  INT

   DECLARE @nTranCount  INT

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1819ExtPASP30 -- For rollback or commit only our own transaction

   SET @nCnt = 0
   SELECT @nCnt = SUM( Cnt) FROM (
   SELECT COUNT(1) AS Cnt 
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.LOC = @cFromLoc 
   AND   LLI.ID = @cID
   GROUP BY LLI.ID, LA.Sku, LA.Lottable02, LA.Lottable03, LA.Lottable04
   HAVING ISNULL( SUM(LLI.Qty - LLI.QtyPicked), 0) > 0) A

   -- Check if pallet has mix sku   
   IF ISNULL( @nCnt, 0) = 1
      SET @cPAType = 'PALLET'
   ELSE
      SET @cPAType = 'CASE'

   SELECT @cPAStrategyKey = ISNULL( Short, '')
   FROM CodeLkup WITH (NOLOCK)
   WHERE ListName = 'RDTExtPA'
      AND Code = @cPAType
      AND StorerKey = @cStorerKey

   -- Check blank putaway strategy
   IF @cPAStrategyKey = ''
   BEGIN
      SET @nErrNo = 151451
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- StrategyNotSet
      GOTO RollBackTran
   END
   
   -- Check putaway strategy valid
   IF NOT EXISTS( SELECT 1 FROM PutawayStrategy WITH (NOLOCK) WHERE PutawayStrategyKey = @cPAStrategyKey)
   BEGIN
      SET @nErrNo = 151452
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- BadStrategyKey
      GOTO RollBackTran
   END

   EXEC @nErrNo = [dbo].[nspRDTPASTD]
        @c_userid          = 'RDT'
      , @c_storerkey       = @cStorerKey
      , @c_lot             = ''
      , @c_sku             = ''
      , @c_id              = @cID
      , @c_fromloc         = @cFromLOC
      , @n_qty             = 0
      , @c_uom             = '' -- not used
      , @c_packkey         = '' -- optional, if pass-in SKU
      , @n_putawaycapacity = 0
      , @c_final_toloc     = @cSuggLOC          OUTPUT
      , @c_PickAndDropLoc  = @cPickAndDropLOC   OUTPUT
      , @c_FitCasesInAisle = @cFitCasesInAisle  OUTPUT
      , @c_PAStrategyKey   = @cPAStrategyKey
      , @n_PABookingKey    = @nPABookingKey     OUTPUT

   IF ISNULL( @cSuggLOC, '') <> ''
   BEGIN
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
   END
   ELSE
   BEGIN
      SET @nErrNo = 151453
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Suggested LOC
      GOTO RollBackTran
   END

   IF @cFitCasesInAisle = 'Y'
   BEGIN
      DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT UCCNo, LOT, LOC, SKU
      FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   LOC = @cFromLOC
      AND   ID = @cID
      AND   Status = '1'
      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @cUCC, @cLOT, @cLOC, @cSKU
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE dbo.RFPutaway WITH (ROWLOCK) SET 
            CaseID = @cUCC
         WHERE StorerKey = @cStorerKey
         AND   LOT = @cLOT
         AND   FromLOC = @cFromLOC
         AND   ID = @cID
         AND   SKU = @cSKU

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 151454
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdRFPutaway Err
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            GOTO RollBackTran
         END
         FETCH NEXT FROM CUR_UPD INTO @cUCC, @cLOT, @cLOC, @cSKU
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1819ExtPASP30 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END


GO