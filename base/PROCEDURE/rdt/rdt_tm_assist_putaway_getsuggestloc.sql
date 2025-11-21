SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_TM_Assist_Putaway_GetSuggestLOC                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2019-09-12  1.0  Ung      WMS-10452 Add override LOC                 */
/* 2021-08-04  1.1  Chermain WMS-17638 Modify ExtPA param (cc01)        */
/************************************************************************/

CREATE PROC [RDT].[rdt_TM_Assist_Putaway_GetSuggestLOC] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5),
   @cTaskDetailKey   NVARCHAR( 10),
   @cFromLOC         NVARCHAR( 10),
   @cFromID          NVARCHAR( 18),
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
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cTaskDetailKey, @cFromLOC, @cFromID, ' + 
            ' @cSuggLOC OUTPUT, @cPickAndDropLOC OUTPUT, @cFitCasesInAisle OUTPUT, @nPABookingKey OUTPUT, ' + 
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile          INT,                  ' +
            '@nFunc            INT,                  ' +
            '@cLangCode        NVARCHAR( 3),         ' +
            '@nStep            INT,                  ' + 
            '@nInputKey        INT,                  ' + 
            '@cStorerKey       NVARCHAR( 15),        ' +
            '@cFacility        NVARCHAR( 5),         ' + 
            '@cTaskDetailKey   NVARCHAR( 10),        ' +
            '@cFromLOC         NVARCHAR( 10),        ' +
            '@cFromID          NVARCHAR( 18),        ' +
            '@cSuggLOC         NVARCHAR( 10) OUTPUT, ' + 
            '@cPickAndDropLOC  NVARCHAR( 10) OUTPUT, ' + 
            '@cFitCasesInAisle NVARCHAR( 1)  OUTPUT, ' + 
            '@nPABookingKey    INT           OUTPUT, ' + 
            '@nErrNo           INT           OUTPUT, ' +
            '@cErrMsg          NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cTaskDetailKey, @cFromLOC, @cFromID, 
            @cSuggLOC OUTPUT, @cPickAndDropLOC OUTPUT, @cFitCasesInAisle OUTPUT, @nPABookingKey OUTPUT, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END

      ELSE IF EXISTS( SELECT 1 FROM PutawayStrategy WITH (NOLOCK) WHERE PutawayStrategyKey = @cExtendedPutawaySP)
      BEGIN
         -- Suggest LOC
         EXEC @nErrNo = [dbo].[nspRDTPASTD]
              @c_userid          = 'RDT'
            , @c_storerkey       = @cStorerKey
            , @c_lot             = ''
            , @c_sku             = ''
            , @c_id              = @cFromID
            , @c_fromloc         = @cFromLOC
            , @n_qty             = 0
            , @c_uom             = '' -- not used
            , @c_packkey         = '' -- optional, if pass-in SKU
            , @n_putawaycapacity = 0
            , @c_final_toloc     = @cSuggLOC          OUTPUT
            , @c_PickAndDropLoc  = @cPickAndDropLOC   OUTPUT
            , @c_FitCasesInAisle = @cFitCasesInAisle  OUTPUT
            , @c_PAStrategyKey   = @cExtendedPutawaySP
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
         , @c_id              = @cFromID
         , @c_fromloc         = @cFromLOC
         , @n_qty             = 0
         , @c_uom             = '' -- not used
         , @c_packkey         = '' -- optional, if pass-in SKU
         , @n_putawaycapacity = 0
         , @c_final_toloc     = @cSuggLOC          OUTPUT
         , @c_PickAndDropLoc  = @cPickAndDropLOC   OUTPUT
         , @c_FitCasesInAisle = @cFitCasesInAisle  OUTPUT
   END
   
   -- Check suggest loc
   IF @cSuggLOC = ''
   BEGIN
      SET @nErrNo = 143901
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoSuitableLOC

      SET @nErrNo = -1
      GOTO Quit
   END

   -- Suggested location
   IF @cSuggLOC <> '' 
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_TM_Assist_Putaway -- For rollback or commit only our own transaction
      
      -- Lock suggested location
      IF @cFitCasesInAisle <> 'Y'
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'
            ,@cFromLOC
            ,@cFromID
            ,@cSuggLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
            ,@cTaskDetailKey = @cTaskDetailKey
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      -- Lock PND location
      IF @cPickAndDropLOC <> ''
      BEGIN
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'
            ,@cFromLOC
            ,@cFromID
            ,@cPickAndDropLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@nPABookingKey = @nPABookingKey OUTPUT
            ,@cTaskDetailKey = @cTaskDetailKey
         IF @nErrNo <> 0
            GOTO RollBackTran
      END
      
      -- Update TaskDetail
      IF @cPickAndDropLOC = ''    
         UPDATE TaskDetail WITH (ROWLOCK) SET    
             ToLOC      = @cSuggLOC 
            ,EditDate   = GETDATE()
            ,EditWho    = SUSER_SNAME()
            ,TrafficCop = NULL        
         WHERE TaskDetailKey = @cTaskDetailKey    
      ELSE    
         UPDATE TaskDetail WITH (ROWLOCK) SET    
             FinalLOC   = @cSuggLOC
            ,FinalID    = @cFromID
            ,ToLOC      = @cPickAndDropLOC
            ,ToID       = @cFromID
            ,TransitLOC = @cPickAndDropLOC
            ,ListKey    = @cTaskDetailKey
            ,EditDate   = GETDATE()
            ,EditWho    = SUSER_SNAME()
            ,TrafficCop = NULL        
         WHERE TaskDetailKey = @cTaskDetailKey          

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 143902
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail
         GOTO RollBackTran
      END

      COMMIT TRAN rdtfnc_TM_Assist_Putaway -- Only commit change made here
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdtfnc_TM_Assist_Putaway -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO