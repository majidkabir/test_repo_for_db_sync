SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1812CreateTask02                                */
/* Copyright      : Maersk WMS                                          */
/*                                                                      */
/* Purpose: Generate next task, if current task is transit              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 03-06-2024 1.0  NLT013     UWP-17667 Created                         */
/************************************************************************/

CREATE PROC [rdt].[rdt_1812CreateTask02] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @cUserName      NVARCHAR( 15), 
   @cListKey       NVARCHAR( 10),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT
   DECLARE @nSuccess          INT
   DECLARE @nFacility         NVARCHAR( 5)
   DECLARE @cSQL              NVARCHAR( MAX)
   DECLARE @cSQLParam         NVARCHAR( MAX)
   DECLARE @cTaskDetailKey    NVARCHAR( 10)
   DECLARE @cNewTaskDetailKey NVARCHAR( 10)
   DECLARE @cStatus           NVARCHAR( 10)
   DECLARE @cWaveKey          NVARCHAR( 10)
   DECLARE @cLoadKey          NVARCHAR( 10)
   DECLARE @cStorerKey        NVARCHAR( 15)
   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @cLOT              NVARCHAR( 10)
   DECLARE @nQTY              INT
   DECLARE @cFromLOC          NVARCHAR( 10)
   DECLARE @cToLOC            NVARCHAR( 10)
   DECLARE @cToID             NVARCHAR( 18)
   DECLARE @cFinalLOC         NVARCHAR( 10)
   DECLARE @cFinalID          NVARCHAR( 18)
   DECLARE @cTransitLOC       NVARCHAR( 10)
   DECLARE @nTransitCount     INT
   DECLARE @cPriority         NVARCHAR( 10)
   DECLARE @cSourcePriority   NVARCHAR( 10)
   DECLARE @cSourceType       NVARCHAR( 30)
   DECLARE @cSkipPnDLocation  NVARCHAR( 30)
   DECLARE @c_LOCCategory     NVARCHAR(10)
   DECLARE @cSetTransitLoc    NVARCHAR(1) = 'N'
   DECLARE @tTask TABLE
   (
      TaskDetailKey NVARCHAR(10), 
      StorerKey     NVARCHAR(15),
      SKU           NVARCHAR(20),
      QTY           INT, 
      FromLoc       NVARCHAR(10),
      ToLOC         NVARCHAR(10),
      ToID          NVARCHAR(18),
      FinalLOC      NVARCHAR(10),
      FinalID       NVARCHAR(18),
      TransitLOC    NVARCHAR(10)
   )

   -- Init var
   SET @nErrNo = 0
   SET @cErrMsg = ''

   SELECT @nFacility = Facility
   FROM rdt.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile

   -- Get ToLOC from latest transit task
   SELECT TOP 1 
      @cWaveKey        = WaveKey, 
      @cLoadKey        = LoadKey, 
      @cStorerKey      = StorerKey, 
      @cStatus         = Status, 
      @cToLOC          = ToLOC, 
      @cToID           = ToID, 
      @nQTY            = QTY, 
      @nTransitCount   = TransitCount, 
      @cPriority       = Priority, 
      @cSourcePriority = SourcePriority, 
      @cSourceType     = 'rdt_1812CreateTask02'
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE ListKey = @cListKey
   ORDER BY TransitCount DESC

   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/

   -- Task not completed/SKIP/CANCEL
   IF @cStatus <> '9'
      RETURN

   -- Get initial task info
   INSERT INTO @tTask (TaskDetailKey, StorerKey, SKU, QTY, FromLoc, ToLOC, ToID, FinalLOC, FinalID)
   SELECT TaskDetailKey, StorerKey, SKU, QTY, FromLoc, @cToLOC, @cToID, FinalLOC, FinalID --NOTE: ToLOC, ToID are from lastest task
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

   SET @cSkipPnDLocation = rdt.RDTGetConfig( @nFunc, 'SkipPnDLocation', @cStorerKey)

   IF @cSkipPnDLocation IS NULL OR TRIM(@cSkipPnDLocation) = ''
      SET @cSkipPnDLocation = '0'
   
   -- Get TransitLOC for tasks
   DECLARE @curTask CURSOR
   SET @curTask = CURSOR FOR 
      SELECT TaskDetailKey, StorerKey, SKU, QTY, FromLoc, ToLOC, ToID, FinalLOC, FinalID 
      FROM @tTask t
         JOIN dbo.LOC WITH (NOLOCK) ON (t.FinalLOC = LOC.LOC)
      ORDER BY CASE WHEN LOC.LocationCategory = 'INDUCTION' THEN 2 ELSE 1 END -- Induction LOC come last, so @cFinalLOC variable in next task goes to induction LOC 
   OPEN @curTask
   FETCH NEXT FROM @curTask INTO @cTaskDetailKey, @cStorerKey, @cSKU, @nQTY, @cFromLOC, @cToLOC, @cToID, @cFinalLOC, @cFinalID
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Get from LOC info
      SELECT 
         @c_LOCCategory = LocationCategory
      FROM dbo.LOC WITH (NOLOCK) 
      WHERE LOC = @cFromLOC
         AND Facility = @nFacility

      IF @c_LOCCategory <> 'VNA' AND @cSkipPnDLocation <> '0' AND @cSkipPnDLocation <> 'PnD' AND EXISTS(SELECT 1 FROM CODELKUP WITH(NOLOCK) WHERE LISTNAME = 'LOCCATEGRY' AND Code = @cSkipPnDLocation)
      BEGIN
         UPDATE @tTask SET 
         TransitLOC = FinalLOC 
         WHERE TaskDetailKey = @cTaskDetailKey

         SET @cSetTransitLoc = 'Y'
      END
      ELSE
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
      END
      
      FETCH NEXT FROM @curTask INTO @cTaskDetailKey, @cStorerKey, @cSKU, @nQTY, @cFromLOC, @cToLOC, @cToID, @cFinalLOC, @cFinalID
   END
         
   -- Get new TaskDetailKeys
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
      SET @nErrNo = 215851
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
   
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1812CreateTask02 -- For rollback or commit only our own transaction

   SET @nTransitCount = @nTransitCount + 1

   -- Generate task
   IF EXISTS( SELECT 1 FROM @tTask WHERE TransitLOC = FinalLOC)
   BEGIN
      -- generate replen to task if:
      -- 1) Pallet have multi final LOC and
      -- 2) Pallet not contain INDUCTION TransitLOC
      IF (SELECT COUNT( DISTINCT FinalLOC) FROM dbo.TaskDetail WITH (NOLOCK) WHERE ListKey = @cListKey AND TransitCount = 0) > 1 
         AND NOT EXISTS( SELECT 1 
            FROM @tTask Task 
               JOIN dbo.LOC WITH (NOLOCK) ON (Task.TransitLOC = LOC.LOC)
            WHERE LOC.LocationCategory = 'INDUCTION')
      BEGIN
         -- Loop original task
         DECLARE @curRPLog CURSOR
         SET @curRPLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT StorerKey, SKU, LOT, QTY, FinalLOC, FinalID
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE ListKey = @cListKey
               AND TransitCount = 0 -- Original task
         OPEN @curRPLog
         FETCH NEXT FROM @curRPLog INTO @cStorerKey, @cSKU, @cLOT, @nQTY, @cFinalLOC, @cFinalID
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
                  SET @nErrNo = 215852
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
                  GOTO Fail
               END
            END

            -- Insert final task
            INSERT INTO TaskDetail (
               TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, QTY, AreaKey, 
               PickMethod, StorerKey, SKU, LOT, ListKey, TransitCount, SourceType, WaveKey, LoadKey, Priority, SourcePriority, TrafficCop)
            VALUES (
               @cNewTaskDetailKey, 'FCPT', '0', '', @cToLOC, @cToID, @cFinalLOC, @cFinalID, @nQTY, @cToLOCAreaKey, 
               'PP', @cStorerKey, @cSKU, @cLOT, @cListKey, @nTransitCount, @cSourceType, @cWaveKey, @cLoadKey, @cPriority, @cSourcePriority, NULL)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 215853
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
               GOTO RollBackTran
            END
            
            SET @cNewTaskDetailKey = ''
            FETCH NEXT FROM @curRPLog INTO @cStorerKey, @cSKU, @cLOT, @nQTY, @cFinalLOC, @cFinalID
         END
      END
      ELSE
      BEGIN
         -- Insert final task
         IF @cSetTransitLoc = 'Y'
            INSERT INTO TaskDetail (
               TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, QTY, AreaKey, TransitLOC, 
               PickMethod, StorerKey, SKU, LOT, ListKey, TransitCount, SourceType, WaveKey, LoadKey, Priority, SourcePriority, TrafficCop)
            VALUES (
               @cNewTaskDetailKey, 'FPK1', '0', '', @cToLOC, @cToID, @cFinalLOC, @cFinalID, 0, @cToLOCAreaKey, @cFinalLOC,
               'FP', @cStorerKey, '', '', @cListKey, @nTransitCount, @cSourceType, @cWaveKey, @cLoadKey, @cPriority, @cSourcePriority, NULL)
         ELSE
            INSERT INTO TaskDetail (
               TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, QTY, AreaKey, 
               PickMethod, StorerKey, SKU, LOT, ListKey, TransitCount, SourceType, WaveKey, LoadKey, Priority, SourcePriority, TrafficCop)
            VALUES (
               @cNewTaskDetailKey, 'FPK1', '0', '', @cToLOC, @cToID, @cFinalLOC, @cFinalID, 0, @cToLOCAreaKey, 
               'FP', @cStorerKey, '', '', @cListKey, @nTransitCount, @cSourceType, @cWaveKey, @cLoadKey, @cPriority, @cSourcePriority, NULL)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 215854
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
            GOTO RollBackTran
         END
      END
   END
   ELSE
   BEGIN 
      -- Insert transit task
      INSERT INTO TaskDetail (
         TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, QTY, AreaKey, 
         PickMethod, Storerkey, SKU, LOT, ListKey, TransitCount, SourceType, WaveKey, LoadKey, Priority, SourcePriority, TrafficCop)
      VALUES (
         @cNewTaskDetailKey, 'FPK1', '0', '', @cToLOC, @cToID, @cTransitLOC, @cToID, 0, @cToLOCAreaKey, 
         'FP', @cStorerkey, '', '', @cListKey, @nTransitCount, @cSourceType, @cWaveKey, @cLoadKey, @cPriority, @cSourcePriority, NULL)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 215855
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
         GOTO RollBackTran
      END
   END

   COMMIT TRAN rdt_1812CreateTask02 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1812CreateTask02 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO