SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************************/
/* Store procedure: rdtVFRPFExtUpd                                                  */
/* Purpose: Send command to Junheinrich direct equipment to location                */
/*                                                                                  */
/* Modifications log:                                                               */
/*                                                                                  */
/* Date         Author    Ver.  Purposes                                            */
/* 2013-02-21   Ung       1.0   SOS256104 Created                                   */
/* 2014-01-22   Ung       1.1   SOS259759 Enable SKIP RPF PP task, release PND loc  */
/* 2015-01-27   Ung       1.2   SOS331666 Update RP1 TaskDetail.UOM                 */
/************************************************************************************/

CREATE PROCEDURE [RDT].[rdtVFRPFExtUpd]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@cTaskdetailKey  NVARCHAR( 10) 
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@nAfterStep      INT = 0
   ,@cDropID         NVARCHAR( 20) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success   INT
   DECLARE @n_err       INT
   DECLARE @c_errmsg    NVARCHAR( 250)
   DECLARE @nTranCount  INT

   DECLARE @cStorerKey  NVARCHAR( 15)
   DECLARE @cUCC        NVARCHAR( 20)
   DECLARE @cFromLOT    NVARCHAR( 10)
   DECLARE @cFromLOC    NVARCHAR( 10)
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cToLOC      NVARCHAR( 10)
   DECLARE @cPickMethod NVARCHAR( 10)
   DECLARE @cStatus     NVARCHAR( 10)
   DECLARE @cReasonKey  NVARCHAR( 10)
   DECLARE @cUserKey    NVARCHAR( 10)
   DECLARE @cTaskType   NVARCHAR( 10)
   DECLARE @cTaskKey    NVARCHAR( 10)
   DECLARE @cRefTaskKey NVARCHAR( 10)
   DECLARE @cTaskUOM    NVARCHAR( 10)
   DECLARE @cListKey    NVARCHAR( 10)
   -- DECLARE @cDropID     NVARCHAR( 20)
   DECLARE @cTransitLOC NVARCHAR( 10)
   DECLARE @cFinalLOC   NVARCHAR( 10)
   DECLARE @cFinalID    NVARCHAR( 18)
   DECLARE @nTaskQTY    INT
   DECLARE @nUCCQTY     INT
   DECLARE @curTask     CURSOR

   SET @nTranCount = @@TRANCOUNT

   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      IF @nStep = 0 -- Initial
         EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT
      
      IF @nStep = 1 -- DropID
      BEGIN
         IF LEFT( @cDropID, 1) <> 'P'
         BEGIN
            SET @nErrNo = 81256
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid format
            GOTO Quit
         END

         EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT
      END

      IF @nStep = 2 -- FromLOC
         EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT

      IF @nStep = 3 -- FromID
      BEGIN
         -- Get task info
         SELECT 
            @cPickMethod = PickMethod, 
            @cStorerKey = StorerKey, 
            -- @cFromLOT = LOT, 
            @cFromLOC = FromLOC, 
            @cFromID = FromID, 
            @cTaskType = TaskType, 
            @cUserKey = UserKey
         FROM dbo.TaskDetail WITH (NOLOCK) 
         WHERE TaskdetailKey = @cTaskdetailKey
         
         -- Stamp PickDetail.DropID for entire pallet
         IF @cTaskType = 'RPF' AND @cPickMethod = 'FP'
         BEGIN
            BEGIN TRAN
            SAVE TRAN rdtVFRPFExtUpd
            
            -- Loop tasks
            SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT TaskDetailKey, UOM, QTY
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE TaskType = 'RPF'
                  AND PickMethod = 'FP'
                  AND FromLOC = @cFromLOC
                  AND FromID = @cFromID
                  AND UserKey = @cUserKey
                  AND Status = '3'
            OPEN @curTask
            FETCH NEXT FROM @curTask INTO @cTaskKey, @cTaskUOM, @nTaskQTY
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Loop UCC
               DECLARE @curUCC CURSOR
               SET @curUCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT UCCNo, QTY
                  FROM dbo.UCC WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     -- AND LOT = @cUCCLOT
                     AND LOC = @cFromLOC
                     AND ID = @cFromID
                     AND Status = '1'
                     AND NOT EXISTS( SELECT 1 
                        FROM dbo.PickDetail WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey 
                        -- AND LOT = @cUCCLOT
                           AND LOC = @cFromLOC
                           AND ID = @cFromID
                           AND DropID = UCC.UCCNo  -- Exclude taken UCC, due to FromID can scan multiple times
                           AND Status < '9')       -- Exclude cancel order, shipped UCC and put back
   
               DECLARE
                  @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
                  @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
                  @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
                  @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
                  @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)
   
               SET @c_oFieled09 = '' --@cDropID
               SET @c_oFieled10 = @cTaskKey
               
               OPEN @curUCC
               FETCH NEXT FROM @curUCC INTO @cUCC, @nUCCQTY
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  EXEC dbo.ispVFRPFDecode
                      @cUCC
                     ,@cStorerKey        
                     ,'' -- @c_ReceiptKey   
                     ,'' -- @c_POKey        
                  	,@cLangCode	        
                  	,@c_oFieled01   OUTPUT
                  	,@c_oFieled02   OUTPUT
                     ,@c_oFieled03   OUTPUT
                     ,@c_oFieled04   OUTPUT
                     ,@c_oFieled05   OUTPUT
                     ,@c_oFieled06   OUTPUT
                     ,@c_oFieled07   OUTPUT
                     ,@c_oFieled08   OUTPUT
                     ,@c_oFieled09   OUTPUT
                     ,@c_oFieled10   OUTPUT
                     ,@b_Success     OUTPUT
                     ,@nErrNo        OUTPUT 
                     ,@cErrMsg       OUTPUT
                  IF @nErrNo <> 0
                     GOTO RollBackTran
                  
                  SET @nTaskQTY = @nTaskQTY - @nUCCQTY
                  IF @nTaskQTY <= 0
                     BREAK
                  
                  FETCH NEXT FROM @curUCC INTO @cUCC, @nUCCQTY
               END
               
               -- Full case and conso case task should fully offset
               IF @cTaskUOM IN ('2', '6') AND @nTaskQTY <> 0
               BEGIN
                  -- Check outstanding PickDetail
                  IF EXISTS( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskKey AND DropID = '')
                  BEGIN
                     SET @nErrNo = 81251
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotFullyOffset
                     GOTO RollBackTran
                  END
               END
               
               -- Update Task
               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
                  Status = '5', -- Picked
                  EndTime = GETDATE(),
                  EditDate = GETDATE(),
                  EditWho  = @cUserKey, 
                  Trafficcop = NULL
               WHERE TaskDetailKey = @cTaskKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 81252
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
                  GOTO RollBackTran
               END
               
               FETCH NEXT FROM @curTask INTO @cTaskKey, @cTaskUOM, @nTaskQTY
            END

            COMMIT TRAN rdtVFRPFExtUpd -- Only commit change made here
         END

         EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT
      END

      IF @nStep = 5 -- Option. 1=next task 2=close pallet
         IF @nAfterStep = 2 -- FromLOC
            EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, 1, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT -- Execute as @nStep = 1
      
      IF @nStep = 6 -- ToLOC
      BEGIN
         -- Get task info
         SELECT 
            @cPickMethod = PickMethod, 
            @cStorerKey = StorerKey, 
            -- @cFromLOT = LOT, 
            @cFromLOC = FromLOC, 
            @cFromID = FromID, 
            @cTaskType = TaskType, 
            @cUserKey = UserKey, 
            @cRefTaskKey = RefTaskKey, 
            @cReasonKey = ReasonKey, 
            @cDropID = DropID, 
            @cListKey = ListKey
         FROM dbo.TaskDetail WITH (NOLOCK) 
         WHERE TaskdetailKey = @cTaskdetailKey
         
         IF @cRefTaskKey <> '' --@cTaskType = 'RPF' AND @cPickMethod = 'FP'
         BEGIN
            BEGIN TRAN
            SAVE TRAN rdtVFRPFExtUpd
            
            -- Loop other tasks
            SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT TaskDetailKey
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE RefTaskKey = @cRefTaskKey
                  AND TaskDetailKey <> @cTaskdetailKey
            OPEN @curTask
            FETCH NEXT FROM @curTask INTO @cTaskKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Update Task
               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
                  Status = '9', -- Closed
                  DropID = @cDropID, 
                  ToID = CASE WHEN PickMethod = 'PP' THEN @cDropID ELSE ToID END, 
                  ReasonKey = @cReasonKey, 
                  EndTime = GETDATE(),
                  EditDate = GETDATE(),
                  EditWho  = @cUserKey, 
                  Trafficcop = NULL
               WHERE TaskDetailKey = @cTaskKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 81253
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
                  GOTO RollBackTran
               END
               FETCH NEXT FROM @curTask INTO @cTaskKey
            END
            
            COMMIT TRAN rdtVFRPFExtUpd -- Only commit change made here        
         END

         -- Get RP1 task
         DECLARE @cRP1TaskKey NVARCHAR(10)
         SET @cRP1TaskKey = ''
         SELECT TOP 1 
            @cRP1TaskKey = TaskdetailKey 
         FROM TaskDetail WITH (NOLOCK) 
         WHERE ListKey = @cListKey 
            AND TaskType = 'RP1'
            AND Status = '0'
         ORDER BY TransitCount DESC
         
         -- Update RP1 task UOM
         IF @cRP1TaskKey <> ''
         BEGIN
            -- Get UOM in ListKey
            DECLARE @cUOM NVARCHAR(10)
            IF EXISTS( SELECT 1 FROM TaskDetail WITH (NOLOCK) WHERE ListKey = @cListKey AND TaskType = 'RPF' AND UOM <> '2')
               SET @cUOM = '6'
            ELSE
               SET @cUOM = '2'

            UPDATE TaskDetail SET
               UOM = @cUOM, 
               EditDate = GETDATE(),
               EditWho  = @cUserKey, 
               Trafficcop = NULL
            WHERE TaskDetailKey = @cRP1TaskKey
         END
         
         EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT
      END
      
      IF @nStep = 9 -- Reason
      BEGIN
         -- Get task info
         SELECT 
            @cUserKey    = UserKey, 
            @cStatus     = Status, 
            @cReasonKey  = ReasonKey, 
            @cPickMethod = PickMethod, 
            @cFromID     = FromID, 
            @cToLOC      = ToLOC, 
            @cTransitLOC = TransitLOC,
            @cFinalLOC   = FinalLOC, 
            @cFinalID    = FinalID, 
            @cRefTaskKey = RefTaskKey
         FROM dbo.TaskDetail WITH (NOLOCK) 
         WHERE TaskdetailKey = @cTaskdetailKey
         
         -- Get TaskStatus
         DECLARE @cTaskStatus NVARCHAR(10)
         SELECT @cTaskStatus = TaskStatus
         FROM dbo.TaskManagerReason WITH (NOLOCK)
         WHERE TaskManagerReasonKey = @cReasonKey
         
         IF @cTaskStatus = ''
            GOTO Quit
         
         DECLARE @tTask TABLE 
         (
            TaskDetailKey NVARCHAR(10), 
            TransitLOC NVARCHAR(10),
            FinalLOC NVARCHAR(10),
            FinalID NVARCHAR(18)
         )
         
         -- Get own task
         INSERT INTO @tTask (TaskDetailKey, TransitLOC, FinalLOC, FinalID)
         SELECT @cTaskDetailKey, @cTransitLOC, @cFinalLOC, @cFinalID
         
         -- Get other tasks that perform at once
         IF @cRefTaskKey <> ''
            INSERT INTO @tTask (TaskDetailKey, TransitLOC, FinalLOC, FinalID)
            SELECT TaskDetailKey, TransitLOC, FinalLOC, FinalID
            FROM dbo.TaskDetail WITH (NOLOCK) 
            WHERE RefTaskKey = @cRefTaskKey
               AND TaskdetailKey <> @cTaskdetailKey

         BEGIN TRAN
         SAVE TRAN rdtVFRPFExtUpd
         
         -- Loop own task and other task
         SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT TaskDetailKey, TransitLOC, FinalLOC, FinalID
            FROM @tTask
         OPEN @curTask
         FETCH NEXT FROM @curTask INTO @cTaskKey, @cTransitLOC, @cFinalLOC, @cFinalID
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Update other tasks
            IF @cTransitLOC = ''
               UPDATE dbo.TaskDetail SET
                   Status = @cStatus
                  ,UserKey = @cUserKey
                  ,ReasonKey = @cReasonKey
                  ,RefTaskKey = ''
                  ,EditDate = GETDATE()
                  ,EditWho  = SUSER_SNAME()
                  ,TrafficCop = NULL
               WHERE TaskDetailKey = @cTaskKey
            ELSE
               UPDATE dbo.TaskDetail SET
                   Status = @cStatus
                  ,UserKey = @cUserKey
                  ,ReasonKey = @cReasonKey
                  ,RefTaskKey = ''
                  ,TransitLOC = ''
                  ,FinalLOC = ''
                  ,FinalID = ''
                  ,ToLOC = @cFinalLOC
                  ,ToID = @cFinalID
                  ,ListKey = ''
                  ,EditDate = GETDATE()
                  ,EditWho  = SUSER_SNAME()
                  ,TrafficCop = NULL
               WHERE TaskDetailKey = @cTaskKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 81254
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDTaskDtlFail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curTask INTO @cTaskKey, @cTransitLOC, @cFinalLOC, @cFinalID
         END

         -- Loop PickDetail
         DECLARE @cPickDetailKey NVARCHAR(10)
         DECLARE @curPD CURSOR
         SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PickDetailKey
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE TaskdetailKey IN (SELECT TaskdetailKey FROM @tTask)
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Reset DropID
            UPDATE dbo.PickDetail SET
               DropID = '', 
               TrafficCop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 81255
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END

         IF @cPickMethod = 'FP'
         BEGIN
            -- Unlock SuggestedLOC
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
               ,'' --@cSuggFromLOC
               ,@cFromID 
               ,'' --@cSuggToLOC
               ,@cStorerKey
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO RollBackTran
         END

         IF @cPickMethod = 'PP'
         BEGIN
            -- Unlock  suggested location
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
               ,''      --@cFromLOC
               ,@cFromID--@cFromID
               ,@cToLOC --@cSuggestedLOC
               ,''      --@cStorerKey
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO RollBackTran
         END

         COMMIT TRAN rdtVFRPFExtUpd -- Only commit change made here        
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdtVFRPFExtUpd -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO