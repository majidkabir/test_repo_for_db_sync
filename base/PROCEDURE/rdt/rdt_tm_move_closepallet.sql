SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_TM_Move_ClosePallet                             */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Confirm Move                                                */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 18-Oct-2013 1.0  Ung       Created                                   */
/* 02-Jan-2014 1.1  Ung       Fix wrongly delete rfPutaway records      */
/* 24-Feb-2014 1.2  Ung       Fix next task not generated               */
/* 17-May-2015 1.3  Ung       SOS340175 Fix generate RP1 to MV1         */
/************************************************************************/

CREATE PROC [RDT].[rdt_TM_Move_ClosePallet] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR(3),
   @cUserName      NVARCHAR(18),
   @cListKey       NVARCHAR(10),
   @nErrNo         INT         OUTPUT,
   @cErrMsg        NVARCHAR(20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cTaskDetailKey NVARCHAR( 10)
   DECLARE @cPickMethod    NVARCHAR( 10)
   DECLARE @cStorerKey     NVARCHAR( 15)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cFromLOC       NVARCHAR( 10)
   DECLARE @cFromID        NVARCHAR( 18)
   DECLARE @cToLOC         NVARCHAR( 10)
   DECLARE @cToID          NVARCHAR( 18)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cLOT           NVARCHAR( 10)
   DECLARE @cUCCNo         NVARCHAR( 20)
   DECLARE @nQTY           INT
   DECLARE @nSystemQTY     INT
   
   -- Init var
   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_TM_Move_ClosePallet -- For rollback or commit only our own transaction

   -- Loop tasks
   DECLARE @curRPTask CURSOR
   SET @curRPTask = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT TaskDetailKey, PickMethod, StorerKey, FromLOC, FromID, ToLOC, ToID, SKU, LOT, QTY, SystemQTY
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE ListKey = @cListKey
         AND UserKey = @cUserName
         AND Status = '5' -- 3=Fetch, 5=Picked, 9=Complete
      ORDER BY TaskDetailKey
   OPEN @curRPTask
   FETCH NEXT FROM @curRPTask INTO @cTaskDetailKey, @cPickMethod, @cStorerKey, @cFromLOC, @cFromID, @cToLOC, @cToID, @cSKU, @cLOT, @nQTY, @nSystemQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SELECT @cFacility = Facility FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC

      -- Full pallet replenish
      IF @cPickMethod = 'FP'
      BEGIN
         -- Reduce QTYReplen
         UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) SET
            QTYReplen = 0
         WHERE LOC = @cFromLOC
            AND ID = @cFromID
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 87651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
            GOTO RollBackTran
         END

         -- Move inventory
         EXECUTE rdt.rdt_Move
            @nMobile     = @nMobile,
            @cLangCode   = @cLangCode,
            @nErrNo      = @nErrNo  OUTPUT,
            @cErrMsg     = @cErrMsg OUTPUT,
            @cSourceType = 'rdt_TM_Move_ClosePallet',
            @cStorerKey  = @cStorerKey,
            @cFacility   = @cFacility,
            @cFromLOC    = @cFromLOC,
            @cToLOC      = @cToLOC,
            @cFromID     = @cFromID,
            @cToID       = @cFromID, 
            @nFunc       = @nFunc
         IF @nErrNo <> 0
            GOTO RollBackTran

         EXEC RDT.rdt_STD_EventLog
            @cActionType    = '5', -- Replenish
            @cUserID        = @cUserName,
            @nMobileNo      = @nMobile,
            @nFunctionID    = @nFunc,
            @cFacility      = @cFacility,
            @cStorerKey     = @cStorerKey,
            @cLocation      = @cFromLOC,
            @cToLocation    = @cToLOC,
            @cID            = @cFromID,
            @cToID          = @cToID,
            @cTaskDetailKey = @cTaskDetailKey
      END

      -- Partial pallet replenish
      IF @cPickMethod = 'PP'
      BEGIN
         -- Reduce QTYReplen
         UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) SET
            QTYReplen = CASE WHEN (QTYReplen - @nSystemQTY) >= 0 THEN (QTYReplen - @nSystemQTY) ELSE 0 END
         WHERE LOT = @cLOT
            AND LOC = @cFromLOC
            AND ID = @cFromID
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 87652
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
            GOTO RollBackTran
         END

         -- Move inventory
         IF EXISTS( SELECT 1 FROM rdt.rdtRPFLog WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey)
         BEGIN
            DECLARE @curUCC CURSOR
            SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT UCCNo FROM rdt.rdtRPFLog WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey
            OPEN @curUCC
            FETCH NEXT FROM @curUCC INTO @cUCCNo
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Move by UCC
               EXECUTE rdt.rdt_Move
                  @nMobile     = @nMobile,
                  @cLangCode   = @cLangCode,
                  @nErrNo      = @nErrNo  OUTPUT,
                  @cErrMsg     = @cErrMsg OUTPUT,
                  @cSourceType = 'rdt_TM_Move_ClosePallet',
                  @cStorerKey  = @cStorerKey,
                  @cFacility   = @cFacility,
                  @cFromLOC    = @cFromLOC,
                  @cToLOC      = @cToLOC,
                  @cFromID     = @cFromID,
                  @cToID       = @cToID,
                  @cUCC        = @cUCCNo, 
                  @nFunc       = @nFunc, 
                  @cTaskDetailKey = @cTaskDetailKey
               IF @nErrNo <> 0
                  GOTO RollBackTran

               EXEC RDT.rdt_STD_EventLog
                  @cActionType    = '5', -- Replenish
                  @cUserID        = @cUserName,
                  @nMobileNo      = @nMobile,
                  @nFunctionID    = @nFunc,
                  @cFacility      = @cFacility,
                  @cStorerKey     = @cStorerKey,
                  @cLocation      = @cFromLOC,
                  @cToLocation    = @cToLOC,
                  @cID            = @cFromID,
                  @cToID          = @cToID,
                  @cRefNo1        = @cUCCNo,
                  @cTaskDetailKey = @cTaskDetailKey

               -- Clear rdtRPFLog
               DELETE rdt.rdtRPFLog WHERE TaskDetailKey = @cTaskDetailKey AND UCCNo = @cUCCNo
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 87653
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelRPFLogFail
                  GOTO RollBackTran
               END

               FETCH NEXT FROM @curUCC INTO @cUCCNo
            END
         END
         ELSE
         BEGIN
            -- Move by SKU
            IF @nQTY > 0
            BEGIN
               EXECUTE rdt.rdt_Move
                  @nMobile     = @nMobile,
                  @cLangCode   = @cLangCode,
                  @nErrNo      = @nErrNo  OUTPUT,
                  @cErrMsg     = @cErrMsg OUTPUT,
                  @cSourceType = 'rdt_TM_Move_ClosePallet',
                  @cStorerKey  = @cStorerKey,
                  @cFacility   = @cFacility,
                  @cFromLOC    = @cFromLOC,
                  @cToLOC      = @cToLOC,
                  @cFromID     = @cFromID,
                  @cToID       = @cToID,
                  @cSKU        = @cSKU,
                  @nQTY        = @nQTY,
                  @cFromLOT    = @cLOT, 
                  @nFunc       = @nFunc, 
                  @cTaskDetailKey = @cTaskDetailKey
               IF @nErrNo <> 0
                  GOTO RollBackTran
            END

            EXEC RDT.rdt_STD_EventLog
               @cActionType    = '5', -- Replenish
               @cUserID        = @cUserName,
               @nMobileNo      = @nMobile,
               @nFunctionID    = @nFunc,
               @cFacility      = @cFacility,
               @cStorerKey     = @cStorerKey,
               @cLocation      = @cFromLOC,
               @cToLocation    = @cToLOC,
               @cID            = @cFromID,
               @cToID          = @cToID,
               @cSKU           = @cSKU,
               @nQTY           = @nQTY,
               @cLOT           = @cLOT, 
               @cTaskDetailKey = @cTaskDetailKey
         END
      END

      -- Unlock  suggested location
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
         ,''      --@cFromLOC
         ,@cFromID--@cFromID
         ,@cToLOC --@cSuggestedLOC
         ,''      --@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Update Task
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
         Status = '9', -- Closed
         -- UserPosition = @cUserPosition,
         EndTime = GETDATE(),
         EditDate = GETDATE(),
         EditWho  = @cUserName, 
         Trafficcop = NULL
      WHERE TaskDetailKey = @cTaskDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 87654
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curRPTask INTO @cTaskDetailKey, @cPickMethod, @cStorerKey, @cFromLOC, @cFromID, @cToLOC, @cToID, @cSKU, @cLOT, @nQTY, @nSystemQTY
   END

   -- Create next task
   EXEC rdt.rdt_TM_Move_CreateNextTask @nMobile, @nFunc, @cLangCode,
      @cUserName,
      @cListKey,
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO Quit

   COMMIT TRAN rdt_TM_Move_ClosePallet -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_TM_Move_ClosePallet -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO