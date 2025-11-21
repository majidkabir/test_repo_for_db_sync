SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_TM_PutawayFrom_GetSuggestLOC                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 14-01-2013  1.0  Ung      SOS256104. Created                         */
/* 21-10-2014  1.1  Ung      SOS322241 Custom putaway strategy          */
/************************************************************************/

CREATE PROC [RDT].[rdt_TM_PutawayFrom_GetSuggestLOC] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18), 
   @cStorerKey       NVARCHAR( 15), 
   @cFromLOC         NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cSuggToLOC       NVARCHAR( 10)    OUTPUT,
   @cPickAndDropLOC  NVARCHAR( 10)    OUTPUT,
   @nErrNo           INT          OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount       INT
   DECLARE @cFitCasesInAisle NVARCHAR(1)
   DECLARE @cSQL             NVARCHAR( MAX)
   DECLARE @cSQLParam        NVARCHAR( MAX)
   
   -- Execute putaway strategy
   IF @cSuggToLOC = ''
   BEGIN
      -- Get extended putaway
      DECLARE @cExtendedPutawaySP NVARCHAR(20)
      SET @cExtendedPutawaySP = rdt.rdtGetConfig( @nFunc, 'ExtendedPutawaySP', @cStorerKey)
      IF @cExtendedPutawaySP = '0'
         SET @cExtendedPutawaySP = ''  

      -- Extended putaway
      IF @cExtendedPutawaySP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPutawaySP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPutawaySP) +
               ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFromLOC, @cID, @cSuggToLOC OUTPUT, @cPickAndDropLOC OUTPUT, @cFitCasesInAisle OUTPUT, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile          INT,                  ' +
               '@nFunc            INT,                  ' +
               '@cLangCode        NVARCHAR( 3),         ' +
               '@cStorerKey       NVARCHAR( 15),        ' +
               '@cFromLOC         NVARCHAR( 10),        ' +
               '@cID              NVARCHAR( 18),        ' +
               '@cSuggToLOC       NVARCHAR( 10) OUTPUT, ' + 
               '@cPickAndDropLOC  NVARCHAR( 10) OUTPUT, ' + 
               '@cFitCasesInAisle NVARCHAR( 1)  OUTPUT, ' + 
               '@nErrNo           INT           OUTPUT, ' +
               '@cErrMsg          NVARCHAR( 20) OUTPUT  '
   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFromLOC, @cID, @cSuggToLOC OUTPUT, @cPickAndDropLOC OUTPUT, @cFitCasesInAisle OUTPUT, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT
   
            IF @nErrNo <> 0
               GOTO Quit
         END
      END
      ELSE
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
            , @c_final_toloc     = @cSuggToLOC        OUTPUT
            , @c_PickAndDropLoc  = @cPickAndDropLOC   OUTPUT
            , @c_FitCasesInAisle = @cFitCasesInAisle  OUTPUT

      -- Check suggest loc
      IF @cSuggToLOC = ''
      BEGIN
         SET @nErrNo = 80201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoSuitableLOC
         GOTO Quit
      END

      -- Lock suggested location
      IF @cSuggToLOC <> '' 
      BEGIN
         -- Handling transaction
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_TM_PutawayFrom_GetSuggestLOC -- For rollback or commit only our own transaction
                  
         IF @cFitCasesInAisle <> 'Y'
         BEGIN
            EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
               ,@cFromLOC
               ,@cID
               ,@cSuggToLOC
               ,@cStorerKey
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
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
            IF @nErrNo <> 0
               GOTO RollBackTran
         END

         COMMIT TRAN rdt_TM_PutawayFrom_GetSuggestLOC -- Only commit change made here
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_TM_PutawayFrom_GetSuggestLOC -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO