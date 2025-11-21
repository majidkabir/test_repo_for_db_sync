SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_1819ExtPASP44                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 22-03-2023  1.0  yeekung  WMS-21969. Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1819ExtPASP44] (
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
   DECLARE @cSKU              NVARCHAR(20)
   DECLARE @cPAStrategyKey    NVARCHAR(20)

   SET @cSuggLOC = ''
   SET @cPickAndDropLOC = ''

   SELECT TOP 1 @cSKU =SKU
   FROM LOTXLOCXID (NOLOCK)
   WHERE ID = @cID
      AND LOC = @cFromLOC
   ORDER BY qty desc

   SELECT @cPAStrategyKey = strategykey 
   FROM SKU (NOLOCK)
   WHERE SKU = @cSKU
      AND Storerkey = @cStorerkey

   -- Suggest LOC
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

   -- Check suggest loc
   IF @cSuggLOC = ''
   BEGIN
      SET @nErrNo = -1
      GOTO Quit
   END

   -- Lock suggested location
   IF @cSuggLOC <> ''
   BEGIN
      -- Get LOC aisle
      DECLARE @cLOCAisle  NVARCHAR(10)
      SELECT @cLOCAisle = LOCAisle FROM LOC WITH (NOLOCK) WHERE LOC = @cSuggLOC

      -- Get PND
      SET @cPickAndDropLOC = ''
      SELECT TOP 1 @cPickAndDropLOC = Code
      FROM dbo.CodeLKUP C WITH (NOLOCK)
      WHERE C.ListName = 'PND'
         AND C.StorerKey = @cStorerKey
         AND C.Code2 = @cLOCAisle

      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_1819ExtPASP44 -- For rollback or commit only our own transaction

      SET @nPABookingKey = 0
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

      COMMIT TRAN rdt_1819ExtPASP44 -- Only commit change made here
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1819ExtPASP44 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO