SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1816ExtMvCfmSP01                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Move by id (based on taskdetailkey). Pass in sku tp rdt_move*/
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2021-06-15   James     1.0   WMS-16966 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1816ExtMvCfmSP01]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@cFinalLOC       NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @cFromLOC NVARCHAR(10)
   DECLARE @cFromID  NVARCHAR(18)
   DECLARE @cPickMethod NVARCHAR(10)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @nQty        INT
   DECLARE @cOrgTaskKey NVARCHAR( 10)
   
   -- Get task info
   SELECT 
      @cFromLOC = FromLOC, 
      @cFromID = FromID,
      @cPickMethod = PickMethod,
      @cSKU = Sku,
      @nQty = Qty,
      @cOrgTaskKey = SourceKey
   FROM TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey
   
   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1816ExtMvCfmSP01 -- For rollback or commit only our own transaction
   
   -- Move by ID
   IF @cPickMethod <> 'NMV'
   BEGIN
      
      EXECUTE rdt.rdt_Move
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode, 
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT,
         @cSourceType = 'rdt_1816ExtMvCfmSP01', 
         @cStorerKey  = @cStorerKey,
         @cFacility   = @cFacility, 
         @cFromLOC    = @cFromLOC, 
         @cToLOC      = @cFinalLoc, 
         @cFromID     = @cFromID, 
         @cToID       = NULL,  -- NULL means not changing ID
         @cSKU        = @cSKU,
         @nQTY        = @nQTY,
         @nFunc       = @nFunc 
      IF @nErrNo <> 0
         GOTO RollbackTran

      -- Unlock suggested location
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
         ,''      --@cFromLOC
         ,''      --@cFromID
         ,''      --@cSuggestedLOC
         ,''      --@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,''      -- @cSKU
         , 0      -- @nPutawayQty
         , ''     -- @cUCCNo
         , ''     -- @cFromLOT
         , ''     -- @cToID
         , @cOrgTaskKey -- @cTaskDetailKey

      IF @nErrNo <> 0
         GOTO RollbackTran
   END

   -- Update task
   UPDATE dbo.TaskDetail SET
      Status = '9',
      ToLOC = @cFinalLoc,
      UserKey = SUSER_SNAME(),
      EditWho = SUSER_SNAME(),
      EditDate = GETDATE(), 
      Trafficcop = NULL
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 169201
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail
      GOTO RollbackTran
   END

   COMMIT TRAN rdt_1816ExtMvCfmSP01 -- Only commit change made here
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1816ExtMvCfmSP01 -- Only rollback change made here
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
END

GO