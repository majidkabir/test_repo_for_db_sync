SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1764CreateTask11                                      */
/* Copyright      : IDS                                                       */
/*                                                                            */
/* Purpose: Generate next task, if current replenish is transit               */
/*                                                                            */
/* Called from:                                                               */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 13-02-2023 1.0  Ung        WMS-20659 not generate RPT if go to pack station*/
/* 05-04-2023 1.1  Ung        WMS-22053 Fully short not generate next task    */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1764CreateTask11] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @cUserName      NVARCHAR( 15),
   @cListKey       NVARCHAR( 10),
   @nErrNo         INT          OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL              NVARCHAR( MAX)
   DECLARE @cSQLParam         NVARCHAR( MAX)
   DECLARE @nTranCount        INT
   DECLARE @nRowCount         INT
   DECLARE @nSuccess          INT
   
   DECLARE @cTaskDetailKey    NVARCHAR( 10)
   DECLARE @cPickDetailKey    NVARCHAR( 10)
   DECLARE @cNewTaskDetailKey NVARCHAR( 10)
   DECLARE @cStatus           NVARCHAR( 10)
   DECLARE @cWaveKey          NVARCHAR( 10)
   DECLARE @cStorerKey        NVARCHAR( 15)
   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @cLOT              NVARCHAR( 10)
   DECLARE @nQTY              INT
   DECLARE @cToLOC            NVARCHAR( 10)
   DECLARE @cToID             NVARCHAR( 18)
   DECLARE @cCaseID           NVARCHAR( 20)
   DECLARE @cFinalLOC         NVARCHAR( 10)
   DECLARE @cFinalID          NVARCHAR( 18)
   DECLARE @cTransitLOC       NVARCHAR( 10)
   DECLARE @nTransitCount     INT
   DECLARE @nUOMQty           INT
   DECLARE @cPriority         NVARCHAR( 10)
   DECLARE @cSourcePriority   NVARCHAR( 10)
   DECLARE @cSourceType       NVARCHAR( 30)
   DECLARE @cOrgTaskKey       NVARCHAR( 30)
   
   DECLARE @cReplenByRPT      NVARCHAR( 1)

   -- Init var
   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- Get ToLOC from latest transit task
   SELECT TOP 1
      @cWaveKey        = WaveKey,
      @cStorerKey      = StorerKey,
      @cStatus         = Status,
      @cToLOC          = ToLOC,
      @cToID           = ToID,
      @nQTY            = QTY,
      @nTransitCount   = TransitCount,
      @cPriority       = Priority,
      @cSourcePriority = SourcePriority,
      @cSourceType     = 'rdt_1764CreateTask11'
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE ListKey = @cListKey
   ORDER BY
      TransitCount DESC, -- Get initial task
      CASE WHEN Status = '9' THEN 1 ELSE 2 END -- RefTask that fetch to perform together, still Status=3

   -- Task not completed/SKIP/CANCEL
   IF @cStatus <> '9'
      RETURN

   -- Task going to pack station
   DECLARE @cLocationRoom NVARCHAR( 30)
   IF @cFinalLOC <> ''
      SELECT @cLocationRoom = ISNULL( LocationRoom, '') FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cFinalLOC
   ELSE
      SELECT @cLocationRoom = ISNULL( LocationRoom, '') FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cToLOC
   IF @cLocationRoom = 'PACKSTATION'
      RETURN

   /***********************************************************************************************
                                             Stardard Create Task
   ***********************************************************************************************/
   DECLARE @tTask TABLE
   (
      TaskDetailKey NVARCHAR(10),
      StorerKey     NVARCHAR(15),
      SKU           NVARCHAR(20),
      QTY           INT,
      ToLOC         NVARCHAR(10),
      ToID          NVARCHAR(18),
      FinalLOC      NVARCHAR(10),
      FinalID       NVARCHAR(18),
      TransitLOC    NVARCHAR(10)
   )

   -- Get initial task info
   INSERT INTO @tTask (TaskDetailKey, StorerKey, SKU, QTY, ToLOC, ToID, FinalLOC, FinalID)
   SELECT TaskDetailKey, StorerKey, SKU, QTY, @cToLOC, @cToID, FinalLOC, FinalID --NOTE: ToLOC, ToID are from lastest task
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE ListKey = @cListKey
      AND TransitCount = 0

   -- Not generate next task if:
   -- 1) Already reach final location or
   -- 2) There is no transit task involved or
   -- 3) Reach conveyor location
   IF EXISTS( SELECT 1 FROM @tTask WHERE ToLOC = FinalLOC)
      RETURN

   IF EXISTS( SELECT 1 FROM @tTask WHERE FinalLOC = '')
      RETURN

   IF EXISTS( SELECT 1 FROM @tTask Task JOIN dbo.LOC WITH (NOLOCK) ON (Task.ToLOC = LOC.LOC) WHERE LOC.LocationCategory = 'INDUCTION')
      RETURN

   -- Storer configure
   SET @cReplenByRPT = rdt.RDTGetConfig( @nFunc, 'ReplenByRPT', @cStorerKey)

   -- Get TransitLOC for tasks
   DECLARE @curTask CURSOR
   SET @curTask = CURSOR FOR
      SELECT TaskDetailKey, StorerKey, SKU, QTY, ToLOC, ToID, FinalLOC, FinalID
      FROM @tTask t
         JOIN dbo.LOC WITH (NOLOCK) ON (t.FinalLOC = LOC.LOC)
      ORDER BY CASE WHEN LOC.LocationCategory = 'INDUCTION' THEN 2 ELSE 1 END -- Induction LOC come last, so @cFinalLOC variable in next task goes to induction LOC
   OPEN @curTask
   FETCH NEXT FROM @curTask INTO @cTaskDetailKey, @cStorerKey, @cSKU, @nQTY, @cToLOC, @cToID, @cFinalLOC, @cFinalID
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Get next transit LOC
      EXECUTE rdt.rdt_GetTransitLOC
         @cUserName,
         @cStorerKey,
         @cSKU,
         @nQTY,
         @cToLOC,      -- FromLOC
         @cToID,       -- FromID
         @cFinalLOC,   -- ToLOC
         0,            -- Lock PND transit LOC. 1=Yes, 0=No
         @cTransitLOC OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT  -- screen limitation, 20 char max
      IF @nErrNo <> 0
         GOTO Fail

      UPDATE @tTask SET
         TransitLOC = @cTransitLOC
      WHERE TaskDetailKey = @cTaskDetailKey

      FETCH NEXT FROM @curTask INTO @cTaskDetailKey, @cStorerKey, @cSKU, @nQTY, @cToLOC, @cToID, @cFinalLOC, @cFinalID
   END

   -- Get new TaskDetailKey
   SET @nSuccess = 1
   EXECUTE dbo.nspg_getkey
      'TASKDETAILKEY'
      , 10
      , @cNewTaskDetailKey OUTPUT
      , @nSuccess          OUTPUT
      , @nErrNo            OUTPUT
      , @cErrMsg           OUTPUT
   IF @nSuccess <> 1
   BEGIN
      SET @nErrNo = 196401
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
      GOTO Fail
   END

   -- Get LOC info
   DECLARE @cToLOCPAZone NVARCHAR(10)
   DECLARE @cToLOCAreaKey NVARCHAR(10)
   SET @cToLOCPAZone = ''
   SET @cToLOCAreaKey = ''
   SELECT @cToLOCPAZone = PutawayZone FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC
   SELECT @cToLOCAreaKey = AreaKey FROM AreaDetail WITH (NOLOCK) WHERE PutawayZone = @cToLOCPAZone

   SET @nTransitCount = @nTransitCount + 1

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1764CreateTask11 -- For rollback or commit only our own transaction

   -- Task reach final step
   IF EXISTS( SELECT 1 FROM @tTask WHERE TransitLOC = FinalLOC)
   BEGIN
      /*
      Generate TM Replen To task (RPT) if:
         1) Pallet have multi final LOC and
         2) Pallet not contain INDUCTION TransitLOC
         OR
         3) Force RPT config ReplenByRPT turn on
      */
      IF (
            (SELECT COUNT( DISTINCT FinalLOC) FROM dbo.TaskDetail WITH (NOLOCK) WHERE ListKey = @cListKey AND TransitCount = 0) > 1
            AND NOT EXISTS( SELECT 1
               FROM @tTask Task
                  JOIN dbo.LOC WITH (NOLOCK) ON (Task.TransitLOC = LOC.LOC)
               WHERE LOC.LocationCategory = 'INDUCTION')
         )
         OR @cReplenByRPT = '1'
      BEGIN
         -- Loop original task
         DECLARE @curRPLog CURSOR
         SET @curRPLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT TaskDetailKey, StorerKey, SKU, LOT, QTY, FinalLOC, FinalID, CaseID, TaskDetailKey, UOMQty
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE ListKey = @cListKey
               AND TransitCount = 0 -- Original task
               AND QTY > 0
         OPEN @curRPLog
         FETCH NEXT FROM @curRPLog INTO @cTaskDetailKey, @cStorerKey, @cSKU, @cLOT, @nQTY, @cFinalLOC, @cFinalID, @cCaseID, @cOrgTaskKey, @nUOMQty
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Get new TaskDetailKeys
            IF @cNewTaskDetailKey = ''
            BEGIN
               SET @nSuccess = 1
               EXECUTE dbo.nspg_getkey
                  'TASKDETAILKEY'
                  , 10
                  , @cNewTaskDetailKey OUTPUT
                  , @nSuccess          OUTPUT
                  , @nErrNo            OUTPUT
                  , @cErrMsg           OUTPUT
               IF @nSuccess <> 1
               BEGIN
                  SET @nErrNo = 196402
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
                  GOTO Fail
               END
            END

            -- Insert final task
            INSERT INTO TaskDetail (
               TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, QTY, CaseID, AreaKey, UOMQty,
               PickMethod, StorerKey, SKU, LOT, ListKey, TransitCount, SourceType, SourceKey, WaveKey, Priority, SourcePriority, TrafficCop)
            VALUES (
               @cNewTaskDetailKey, 'RPT', '0', '', @cToLOC, @cToID, @cFinalLOC, @cFinalID, @nQTY, @cCaseID, @cToLOCAreaKey, @nUOMQty,
               'PP', @cStorerKey, @cSKU, @cLOT, @cListKey, @nTransitCount, @cSourceType, @cOrgTaskKey, @cWaveKey, @cPriority, @cSourcePriority, NULL)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 196403
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
               GOTO RollBackTran
            END

            SET @cNewTaskDetailKey = ''
            FETCH NEXT FROM @curRPLog INTO @cTaskDetailKey, @cStorerKey, @cSKU, @cLOT, @nQTY, @cFinalLOC, @cFinalID, @cCaseID, @cOrgTaskKey, @nUOMQty
         END
      END
      ELSE
      BEGIN
         -- Final RP1 task
         INSERT INTO TaskDetail (
            TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, QTY, AreaKey,
            PickMethod, StorerKey, SKU, LOT, ListKey, TransitCount, SourceType, WaveKey, Priority, SourcePriority, TrafficCop)
         VALUES (
            @cNewTaskDetailKey, 'RP1', '0', '', @cToLOC, @cToID, @cFinalLOC, @cToID, 0, @cToLOCAreaKey,
            'FP', @cStorerKey, '', '', @cListKey, @nTransitCount, @cSourceType, @cWaveKey, @cPriority, @cSourcePriority, NULL)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 196404
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
            GOTO RollBackTran
         END
      END
   END
   ELSE
   BEGIN
      -- Transit RP1 task
      INSERT INTO TaskDetail (
         TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, QTY, AreaKey,
         PickMethod, Storerkey, SKU, LOT, ListKey, TransitCount, SourceType, WaveKey, Priority, SourcePriority, TrafficCop)
      VALUES (
         @cNewTaskDetailKey, 'RP1', '0', '', @cToLOC, @cToID, @cTransitLOC, @cToID, 0, @cToLOCAreaKey,
         'FP', @cStorerkey, '', '', @cListKey, @nTransitCount, @cSourceType, @cWaveKey, @cPriority, @cSourcePriority, NULL)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 196405
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
         GOTO RollBackTran
      END
   END

   COMMIT TRAN rdt_1764CreateTask11 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764CreateTask11 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO