SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_InboundSKUPutaway_GetSuggestLOC                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 15-06-2017  1.0  James    WMS22466. Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_InboundSKUPutaway_GetSuggestLOC] (
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
   @nPABookingKey    INT            OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
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
   
   SET @cSuggLOC = ''
   SET @cPickAndDropLOC = ''
   
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
            ' @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility, @cFromLOC, @cID, ' + 
            ' @cSuggLOC OUTPUT, @cPickAndDropLOC OUTPUT, @cFitCasesInAisle OUTPUT, @nPABookingKey OUTPUT, ' + 
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile          INT,                  ' +
            '@nFunc            INT,                  ' +
            '@cLangCode        NVARCHAR( 3),         ' +
            '@cUserName        NVARCHAR( 18),        ' +
            '@cStorerKey       NVARCHAR( 15),        ' +
            '@cFacility        NVARCHAR( 5),         ' + 
            '@cFromLOC         NVARCHAR( 10),        ' +
            '@cID              NVARCHAR( 18),        ' +
            '@cSuggLOC         NVARCHAR( 10) OUTPUT, ' + 
            '@cPickAndDropLOC  NVARCHAR( 10) OUTPUT, ' + 
            '@cFitCasesInAisle NVARCHAR( 1)  OUTPUT, ' + 
            '@nPABookingKey    INT           OUTPUT, ' + 
            '@nErrNo           INT           OUTPUT, ' +
            '@cErrMsg          NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility, @cFromLOC, @cID, 
            @cSuggLOC OUTPUT, @cPickAndDropLOC OUTPUT, @cFitCasesInAisle OUTPUT, @nPABookingKey OUTPUT, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END
   END
   ELSE
   BEGIN
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

      -- Check suggest loc
      IF @cSuggLOC = ''
      BEGIN
         SET @nErrNo = -1
         GOTO Quit
      END
   
      -- Lock suggested location
      IF @cSuggLOC <> '' 
      BEGIN
         -- Handling transaction
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_InboundSKUPutaway -- For rollback or commit only our own transaction
         
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
   
         COMMIT TRAN rdt_InboundSKUPutaway -- Only commit change made here
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_InboundSKUPutaway -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO