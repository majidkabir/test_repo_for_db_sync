SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_TM_CasePutaway_Confirm                          */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 05-Jun-2014 1.0  Ung       Created                                   */
/* 27-Jun-2014 1.1  Ung       Finalize Transfer                         */
/* 03-Aug-2014 1.2  Ung       SOS317842 Fix unlock FromID could be diff */ 
/* 17-Sep-2014 1.3  Chee      Bug Fix - Update TaskDetail.Toloc after   */ 
/*                            unlock pendingMoveIn (Chee01)             */
/************************************************************************/

CREATE PROC [RDT].[rdt_TM_CasePutaway_Confirm] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @cUserName      NVARCHAR( 18), 
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15), 
   @cTaskDetailKey NVARCHAR( 10),
   @cFinalLOC      NVARCHAR( 10),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cFromLOC    NVARCHAR( 10)
   DECLARE @cToLOC      NVARCHAR( 10)
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cToID       NVARCHAR( 18)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @cLOT        NVARCHAR( 10)
   DECLARE @cCaseID     NVARCHAR( 20)
   DECLARE @nQTY        INT

   -- Init var
   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- Get task info
   SELECT 
      @cFromLOC = FromLOC, 
      @cFromID = FromID, 
      @cToLOC = ToLOC, 
      @cToID = ToID, 
      @cSKU = SKU, 
      @nQTY = QTY, 
      @cLOT = LOT, 
      @cCaseID = CaseID
   FROM dbo.TaskDetail WITH (NOLOCK) 
   WHERE TaskDetailKey = @cTaskDetailKey

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_TM_CasePutaway_Confirm -- For rollback or commit only our own transaction

   -- Move by SKU
   EXECUTE rdt.rdt_Move
      @nMobile     = @nMobile,
      @cLangCode   = @cLangCode,
      @nErrNo      = @nErrNo  OUTPUT,
      @cErrMsg     = @cErrMsg OUTPUT,
      @cSourceType = 'rdtfnc_TM_CasePutaway_Confirm',
      @cStorerKey  = @cStorerKey,
      @cFacility   = @cFacility,
      @cFromLOC    = @cFromLOC,
      @cToLOC      = @cFinalLOC, -- Final LOC
      @cFromID     = @cFromID,
      @cToID       = @cToID,
      @cSKU        = @cSKU,
      @nQTY        = @nQTY,
      @cFromLOT    = @cLOT
   IF @nErrNo <> 0
      GOTO RollBackTran
   
   -- Update Task
   UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
      Status = '9',
      EndTime = GETDATE(),
      EditDate = GETDATE(),
      EditWho  = @cUserName, 
      Trafficcop = NULL
   WHERE TaskDetailKey = @cTaskDetailKey
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 89001
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
      GOTO RollBackTran
   END

   -- Unlock suggested location
   EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'    
      ,@cFromLOC   
      ,'' -- @cFromID could be changed if have transit
      ,@cToLOC
      ,@cStorerKey    
      ,@nErrNo  OUTPUT    
      ,@cErrMsg OUTPUT    
      ,@cSKU        = @cSKU    
      ,@nPutawayQTY = @nQTY    
      ,@cFromLOT    = @cLOT
      ,@cUCCNo      = @cCaseID

   IF @nErrNo <> 0
      GOTO RollBackTran

   -- Update TaskDetail.Toloc only after unlock (Chee01)
   IF @cFinalLOC <> @cToLoc
   BEGIN
         UPDATE TASKDETAIL WITH (ROWLOCK)  
         SET ToLoc = @cFinalLOC, TrafficCop = NULL  
         WHERE TaskDetailKey = @cTaskdetailkey  
   END

   COMMIT TRAN rdt_TM_CasePutaway_Confirm -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_TM_CasePutaway_Confirm -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO