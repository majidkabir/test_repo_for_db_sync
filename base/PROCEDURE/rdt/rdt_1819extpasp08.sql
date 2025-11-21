SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtPASP08                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 08-Mar-2017  1.0  James    WMS1075. Created                          */
/* 11-Sep-2017  1.1  James    WMS1892-Add grade for strategy (james01)  */
/************************************************************************/

CREATE PROC [RDT].[rdt_1819ExtPASP08] (
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
           @cLottable01    NVARCHAR( 18)

   DECLARE @nTranCount  INT

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1819ExtPASP08 -- For rollback or commit only our own transaction

   -- Check if it is QS type of pallet. 
   IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               JOIN dbo.SKU SKU WITH (NOLOCK) ON ( LLI.SKU = SKU.SKU)
               WHERE LLI.LOC = @cFromLoc
               AND   LLI.ID = @cID
               AND   LLI.Qty > 0
               AND   SKU.StorerKey = @cStorerKey
               AND   SKU.BUSR10 = '1')
   BEGIN
     -- Check if pallet has mix sku
      IF NOT EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND   LOC = @cFromLoc 
                        AND   ID = @cID
                        GROUP BY ID 
                        HAVING COUNT( DISTINCT SKU) > 1)
         SET @cPAType = 'QSPALLET'   -- QS type sku found on the pallet, use qs putaway strategy
      ELSE
         SET @cPAType = 'QSCASE'     -- QS type sku found on the pallet, use qs case strategy
   END
   ELSE  -- not QS type pallet
   BEGIN
      SELECT TOP 1 @cLottable01 = LA.Lottable01 
      FROM dbo.LotAttribute LA WITH (NOLOCK)
      JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( LA.LOT = LLI.LOT)
      WHERE LLI.StorerKey = @cStorerKey
      AND   LLI.LOC = @cFromLoc 
      AND   LLI.ID = @cID
      GROUP BY LA.Lottable01
      HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) > 0
      ORDER BY 1

      -- Check if pallet has mix sku
      IF NOT EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND   LOC = @cFromLoc 
                        AND   ID = @cID
                        GROUP BY ID 
                        HAVING COUNT( DISTINCT SKU) > 1)
         SET @cPAType = 'PALLET' -- no mix sku, use pallet putaway strategy
      ELSE
         SET @cPAType = 'CASE'   -- mix sku in the pallet, use case putaway strategy

      -- (james01)
      -- To differentiate putaway strategy for grade A or B SKU
      IF ISNULL( @cLottable01, '') <> ''
         SET @cPAType = @cPAType + '_' + RTRIM( @cLottable01)
   END

   SELECT @cPAStrategyKey = ISNULL( Short, '')
   FROM CodeLkup WITH (NOLOCK)
   WHERE ListName = 'RDTExtPA'
      AND Code = @cPAType
      AND StorerKey = @cStorerKey

   -- Check blank putaway strategy
   IF @cPAStrategyKey = ''
   BEGIN
      SET @nErrNo = 107101
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- StrategyNotSet
      GOTO RollBackTran
   END
   
   -- Check putaway strategy valid
   IF NOT EXISTS( SELECT 1 FROM PutawayStrategy WITH (NOLOCK) WHERE PutawayStrategyKey = @cPAStrategyKey)
   BEGIN
      SET @nErrNo = 107102
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
      SET @nErrNo = 107103
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
            SET @nErrNo = 107104
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
   ROLLBACK TRAN rdt_1819ExtPASP08 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END


GO