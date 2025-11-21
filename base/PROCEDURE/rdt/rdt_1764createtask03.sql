SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764CreateTask03                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 12-Sep-2018 1.0  Ung       WMS-6243 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_1764CreateTask03] (
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

   DECLARE @nTranCount        INT
   DECLARE @nSuccess          INT
   DECLARE @cTaskDetailKey    NVARCHAR( 10)
   DECLARE @cNewTaskDetailKey NVARCHAR( 10)
   DECLARE @cStatus           NVARCHAR( 10)
   DECLARE @cToLOC            NVARCHAR( 10)
   DECLARE @cToLOCPAZone      NVARCHAR( 10)
   DECLARE @cToLOCAreaKey     NVARCHAR( 10)
   DECLARE @cSourceType       NVARCHAR( 30)
   DECLARE @cOrgTaskKey       NVARCHAR( 30)
          
   -- Init var
   SET @nErrNo = 0
   SET @cErrMsg = ''
   SET @nTranCount = @@TRANCOUNT
   SET @cSourceType = 'rdt_1764CreateTask03'

   -- Get ToLOC from latest transit task
   SELECT TOP 1 
      @cStatus = Status 
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE ListKey = @cListKey
   ORDER BY 
      TransitCount DESC, -- Get initial task
      CASE WHEN Status = '9' THEN 1 ELSE 2 END -- RefTask that fetch to perform together, still Status=3

   -- Task not completed/SKIP/CANCEL
   IF @cStatus <> '9'
      RETURN

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1764CreateTask03 -- For rollback or commit only our own transaction

   -- Loop original task
   DECLARE @curRPTLog CURSOR
   SET @curRPTLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT TaskDetailKey, ToLOC
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE ListKey = @cListKey
         AND TransitCount = 0 -- Original task
         AND FinalLOC <> ''
   OPEN @curRPTLog
   FETCH NEXT FROM @curRPTLog INTO @cOrgTaskKey, @cToLOC
   WHILE @@FETCH_STATUS = 0
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
         SET @nErrNo = 129051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
         GOTO Fail
      END

      -- Get LOC info
      SET @cToLOCPAZone = ''
      SET @cToLOCAreaKey = ''
      SELECT @cToLOCPAZone = PutawayZone FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC
      SELECT @cToLOCAreaKey = AreaKey FROM AreaDetail WITH (NOLOCK) WHERE PutawayZone = @cToLOCPAZone 

      -- Insert final task
      INSERT INTO TaskDetail (
         TaskDetailKey, TaskType, Status, UserKey, PickMethod, TransitCount, AreaKey, SourceType, FromLOC, FromID, ToLOC, ToID, 
         StorerKey, SKU, LOT, CaseID, UOMQty, QTY, ListKey, SourceKey, WaveKey, LoadKey, Priority, SourcePriority, TrafficCop)
      SELECT
         @cNewTaskDetailKey, 'RPT', '0', '', 'PP', 1, @cToLOCAreaKey, @cSourceType, ToLOC, ToID, FinalLOC, FinalID, 
         StorerKey, SKU, LOT, CaseID, UOMQty, QTY, ListKey, TaskDetailKey, WaveKey, LoadKey, Priority, SourcePriority, NULL
      FROM TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cOrgTaskKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 129052
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
         GOTO RollBackTran
      END
      
      FETCH NEXT FROM @curRPTLog INTO @cOrgTaskKey, @cToLOC
   END

   COMMIT TRAN rdt_1764CreateTask03 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764CreateTask03 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO