SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1764ExtUpd17                                          */
/* Purpose: TM Replen From, Extended Update for                               */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2023-02-06   Ung       1.0   WMS-20659 Created                             */
/* 2023-04-05   Ung       1.1   WMS-22053 Fully short set task status = H     */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1764ExtUpd17]
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

   DECLARE @nTranCount  INT
   
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cStorerKey     NVARCHAR( 15)
   DECLARE @cCaseID        NVARCHAR( 20)
   DECLARE @cPickMethod    NVARCHAR( 10)
   DECLARE @cStatus        NVARCHAR( 10)
   DECLARE @cTaskType      NVARCHAR( 10)
   DECLARE @cTaskKey       NVARCHAR( 10)
   DECLARE @cRefTaskKey    NVARCHAR( 10)
   DECLARE @cListKey       NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cTransitLOC    NVARCHAR( 10)
   DECLARE @cFinalLOC      NVARCHAR( 10)
   DECLARE @cLocationRoom  NVARCHAR( 30)
   DECLARE @nQTY           INT
   DECLARE @nUCCQTY        INT

   DECLARE @curTask     CURSOR
   DECLARE @curPD       CURSOR

   DECLARE @tTask TABLE  
   (  
      TaskDetailKey NVARCHAR(10)  
   )
   
   SET @nTranCount = @@TRANCOUNT
  
   BEGIN TRAN
   SAVE TRAN rdt_1764ExtUpd17
   
   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      IF @nStep = 6 -- ToLOC
      BEGIN
         -- Get session info
         SELECT 
            @cStorerKey = StorerKey, 
            @cFacility  = Facility 
         FROM rdt.rdtmobrec WITH (NOLOCK) 
         WHERE Mobile = @nMobile 

         -- Get task info  
         SELECT  
            @cTaskType   = TaskType, 
            @cStatus     = Status,   
            @cRefTaskKey = RefTaskKey,
            @cListKey = ListKey -- Cancel/SKIP might not have ListKey (e.g. last carton SKIP)
         FROM dbo.TaskDetail WITH (NOLOCK)  
         WHERE TaskdetailKey = @cTaskdetailKey  
        
         IF @cTaskType = 'RPF'
         BEGIN
            -- Get list key (quick fix)
            IF @cListKey = ''
               SELECT @cListKey = V_String7 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

            -- Get initial task
            IF @cListKey <> ''  -- For protection, in case ListKey is blank
               INSERT INTO @tTask (TaskDetailKey)
               SELECT TaskDetailKey
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE ListKey = @cListKey
                  AND TransitCount = 0

            -- Loop tasks
            SET @curTask = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT T.TaskDetailKey, TD.Status, TD.PickMethod, TD.CaseID, TD.QTY, TD.TransitLOC, TD.FinalLOC, LOC.LocationRoom
               FROM dbo.TaskDetail TD WITH (NOLOCK)
                  JOIN dbo.LOC WITH (NOLOCK) ON (TD.ToLOC = LOC.LOC)
                  JOIN @tTask T ON (TD.TaskDetailKey = T.TaskDetailKey)
            OPEN @curTask
            FETCH NEXT FROM @curTask INTO @cTaskKey, @cStatus, @cPickMethod, @cCaseID, @nQTY, @cTransitLOC, @cFinalLOC, @cLocationRoom
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Completed task
               IF @cStatus IN ('9', '3')
               BEGIN
                  -- Going to pack station
                  IF @cLocationRoom = 'PACKSTATION'
                  BEGIN
                     -- Loop PickDetail
                     SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT PD.PickDetailKey
                        FROM PickDetail PD WITH (NOLOCK)
                        WHERE PD.TaskDetailKey = @cTaskKey
                     OPEN @curPD
                     FETCH NEXT FROM @curPD INTO @cPickDetailKey
                     WHILE @@FETCH_STATUS = 0
                     BEGIN
                        -- Update PickDetail
                        UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                           Status = '5', 
                           DropID = CASE WHEN @cPickMethod = 'PP' THEN @cCaseID ELSE DropID END, 
                           EditDate = GETDATE(),
                           EditWho = 'rdt.' + SUSER_SNAME()
                        WHERE PickDetailKey = @cPickDetailKey
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 196051
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                           GOTO RollBackTran
                        END
                        FETCH NEXT FROM @curPD INTO @cPickDetailKey
                     END
                  END
               
                  -- Fully short
                  IF @nQTY = 0
                  BEGIN
                     -- Get UCC info
                     SELECT @nUCCQTY = QTY FROM dbo.UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UCCNo = @cCaseID
                     
                     -- Reset task to Status = H
                     UPDATE dbo.TaskDetail SET
                        DropID = '', 
                        QTY = @nUCCQTY, 
                        Status = 'H',
                        ListKey = '', 
                        UserKey = '', 
                        ReasonKey = '', 
                        ToLOC = CASE WHEN @cTransitLOC <> '' THEN @cFinalLOC ELSE ToLOC END, 
                        TransitLOC = '', 
                        FinalLOC = '', 
                        FinalID = '', 
                        EditWho = SUSER_SNAME(), 
                        EditDate = GETDATE(), 
                        TrafficCop = NULL
                     WHERE TaskDetailKey = @cTaskKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 196052
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail
                        GOTO RollBackTran
                     END
                  END
               END
               FETCH NEXT FROM @curTask INTO @cTaskKey, @cStatus, @cPickMethod, @cCaseID, @nQTY, @cTransitLOC, @cFinalLOC, @cLocationRoom
            END
         END
         
         IF @cRefTaskKey <> '' --@cTaskType = 'RPF' AND @cPickMethod = 'FP'
         BEGIN
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
                  EndTime = GETDATE(),
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME(),
                  Trafficcop = NULL
               WHERE TaskDetailKey = @cTaskKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 196053
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail
                  GOTO RollBackTran
               END
               FETCH NEXT FROM @curTask INTO @cTaskKey
            END
         END
      END
   END  

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764ExtUpd17 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO