SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_TM_Replen_CreateNextTask                        */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Generate next task, if current replenish is transit         */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 27-Oct-2011 1.0  Ung       Created                                   */
/* 19-Mar-2014 1.1  Ung       Fix task not create if have RefTask       */
/* 26-Jun-2014 1.2  Ung       SOS314511 RPT CaseID, SourceKey           */
/* 22-Aug-2017 1.3  ChewKP    WMS-1580, RDT StorerConfig "ReplenByRPT"  */
/*                            Generate RPT instead of RP1 for final Loc */
/*                            (ChewKP01)                                */
/* 23-Feb-2018 1.4  Ung       WMS-3179 Add TaskDetail.AreaKey           */
/* 30-Mar-2018 1.5  ChewKP    WMS-4471 - Add UOMQty for RPT (CheWKP02)  */
/* 03-Aug-2018 1.6  ChewKP    WMS-5178 - Add CreateNextTaskSP (ChewKP03)*/
/* 15-May-2024 1.7  NLT013    UWP-19518 Ability to config the new task's*/
/*                            prioprity if the source location is PND   */
/************************************************************************/

CREATE PROC [rdt].[rdt_TM_Replen_CreateNextTask] (
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

   DECLARE @nTranCount  INT
   DECLARE @nSuccess    INT
   DECLARE @cTaskDetailKey    NVARCHAR( 10)
   DECLARE @cNewTaskDetailKey NVARCHAR( 10)
   DECLARE @cStatus     NVARCHAR( 10)
   DECLARE @cWaveKey    NVARCHAR( 10)
   DECLARE @cStorerKey  NVARCHAR( 15)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @cLOT        NVARCHAR( 10)
   DECLARE @nQTY        INT
   DECLARE @cToLOC      NVARCHAR( 10)
   DECLARE @cToID       NVARCHAR( 18)
   DECLARE @cCaseID     NVARCHAR( 20)
   DECLARE @cFinalLOC   NVARCHAR( 10)
   DECLARE @cFinalID    NVARCHAR( 18)
   DECLARE @cTransitLOC NVARCHAR( 10)
   DECLARE @nTransitCount   INT
   DECLARE @cPriority       NVARCHAR( 10)
   DECLARE @cSourcePriority NVARCHAR( 10)
   DECLARE @cSourceType     NVARCHAR( 30)
   DECLARE @cOrgTaskKey     NVARCHAR( 30)
          ,@cReplenByRPT    NVARCHAR(1) 
          ,@nUOMQty         INT
          ,@cCreateNextTaskSP NVARCHAR(30)
          ,@cSQL              NVARCHAR(1000)
          ,@cSQLParam         NVARCHAR(1000)
   
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
      @cSourceType     = 'rdt_TM_Replen_CreateNextTask'
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE ListKey = @cListKey
   ORDER BY 
      TransitCount DESC, -- Get initial task
      CASE WHEN Status = '9' THEN 1 ELSE 2 END -- RefTask that fetch to perform together, still Status=3

   -- Task not completed/SKIP/CANCEL
   IF @cStatus <> '9'
      RETURN

   /***********************************************************************************************
                                             Customize Create Task 
   ***********************************************************************************************/   
   -- (ChewKP03) 
   SET @cCreateNextTaskSP = rdt.RDTGetConfig( @nFunc, 'CreateNextTaskSP', @cStorerKey)            
   IF @cCreateNextTaskSP = '0'            
      SET @cCreateNextTaskSP = ''   
      
   IF @cCreateNextTaskSP <> ''    
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCreateNextTaskSP AND type = 'P')            
      BEGIN            
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cCreateNextTaskSP) +            
            ' @nMobile, @nFunc, @cLangCode, @cUserName, @cListKey, @nErrNo  OUTPUT, @cErrMsg OUTPUT '            
         SET @cSQLParam =      
            '@nMobile        INT,                 ' +
            '@nFunc          INT,                 ' +
            '@cLangCode      NVARCHAR( 3),        ' +
            '@cUserName      NVARCHAR( 15),       ' +
            '@cListKey       NVARCHAR( 10),       ' +
            '@nErrNo         INT          OUTPUT, ' +
            '@cErrMsg        NVARCHAR( 20) OUTPUT '    

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,            
            @nMobile, @nFunc, @cLangCode, @cUserName, @cListKey, @nErrNo  OUTPUT, @cErrMsg OUTPUT      
            
         GOTO Quit             
      END  
   END
   
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
      SET @nErrNo = 74301
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
   SAVE TRAN rdt_TM_Replen_CreateNextTask -- For rollback or commit only our own transaction

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
            SELECT StorerKey, SKU, LOT, QTY, FinalLOC, FinalID, CaseID, TaskDetailKey, UOMQty
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE ListKey = @cListKey
               AND TransitCount = 0 -- Original task
         OPEN @curRPLog
         FETCH NEXT FROM @curRPLog INTO @cStorerKey, @cSKU, @cLOT, @nQTY, @cFinalLOC, @cFinalID, @cCaseID, @cOrgTaskKey, @nUOMQty
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
                  SET @nErrNo = 74302
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
               SET @nErrNo = 74303
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
               GOTO RollBackTran
            END
            
            SET @cNewTaskDetailKey = ''
            FETCH NEXT FROM @curRPLog INTO @cStorerKey, @cSKU, @cLOT, @nQTY, @cFinalLOC, @cFinalID, @cCaseID, @cOrgTaskKey, @nUOMQty
         END
      END
      ELSE
      BEGIN
         SET @cReplenByRPT = rdt.RDTGetConfig( @nFunc, 'ReplenByRPT', @cStorerKey)
         
         IF @cReplenByRPT = '1' 
         BEGIN
            -- Loop original task
            DECLARE @curRPTLog CURSOR
            SET @curRPTLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT StorerKey, SKU, LOT, QTY, FinalLOC, FinalID, CaseID, TaskDetailKey, UOMQty
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE ListKey = @cListKey
                  AND TransitCount = 0 -- Original task
            OPEN @curRPTLog
            FETCH NEXT FROM @curRPTLog INTO @cStorerKey, @cSKU, @cLOT, @nQTY, @cFinalLOC, @cFinalID, @cCaseID, @cOrgTaskKey, @nUOMQty
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
                     SET @nErrNo = 74306
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
                  SET @nErrNo = 74307
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
                  GOTO RollBackTran
               END
               
               SET @cNewTaskDetailKey = ''
               FETCH NEXT FROM @curRPTLog INTO @cStorerKey, @cSKU, @cLOT, @nQTY, @cFinalLOC, @cFinalID, @cCaseID, @cOrgTaskKey, @nUOMQty
            END
         END
         ELSE
         BEGIN
            -- Insert final task
            INSERT INTO TaskDetail (
               TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, QTY, AreaKey, 
               PickMethod, StorerKey, SKU, LOT, ListKey, TransitCount, SourceType, WaveKey, Priority, SourcePriority, TrafficCop)
            VALUES (
               @cNewTaskDetailKey, 'RP1', '0', '', @cToLOC, @cToID, @cFinalLOC, @cToID, 0, @cToLOCAreaKey, 
               'FP', @cStorerKey, '', '', @cListKey, @nTransitCount, @cSourceType, @cWaveKey, @cPriority, @cSourcePriority, NULL)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 74304
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
               GOTO RollBackTran
            END
         END
      END
   END
   ELSE
   BEGIN 
      -- Insert transit task
      INSERT INTO TaskDetail (
         TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, QTY, AreaKey, 
         PickMethod, Storerkey, SKU, LOT, ListKey, TransitCount, SourceType, WaveKey, Priority, SourcePriority, TrafficCop)
      VALUES (
         @cNewTaskDetailKey, 'RP1', '0', '', @cToLOC, @cToID, @cTransitLOC, @cToID, 0, @cToLOCAreaKey, 
         'FP', @cStorerkey, '', '', @cListKey, @nTransitCount, @cSourceType, @cWaveKey, @cPriority, @cSourcePriority, NULL)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 74305
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
         GOTO RollBackTran
      END
   END

   COMMIT TRAN rdt_TM_Replen_CreateNextTask -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_TM_Replen_CreateNextTask -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO