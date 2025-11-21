SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1764CreateTask13                                      */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Purpose: For Levis                                                         */
/*                                                                            */
/* Called from:                                                               */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev    Author     Purposes                                      */
/* 2024-12-04 1.0.0  JCH507     FCR-1157 Created                              */
/* 2025-01-03 1.0.1  JCH507     FCR-1157 Unlock/Relock finalloc (ASTMV)       */
/* 2025-01-07 1.0.2  JCH507     FCR-1157 Return if no task in the list        */
/* 2025-01-17 1.0.3  JCH507     FCR-1157 V1.2 Add LocType='DYNAMICPK'         */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1764CreateTask13] (
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

   DECLARE @bDebugFlag        BINARY = 0

   DECLARE @cSQL              NVARCHAR( MAX)
   DECLARE @cSQLParam         NVARCHAR( MAX)
   DECLARE @nTranCount        INT
   DECLARE @nRowCount         INT
   DECLARE @nSuccess          INT
   
   DECLARE @cTaskDetailKey    NVARCHAR( 10)
   DECLARE @cPickDetailKey    NVARCHAR( 10)
   DECLARE @cNewTaskDetailKey NVARCHAR( 10)
   DECLARE @cWaveKey          NVARCHAR( 10)
   DECLARE @cStorerKey        NVARCHAR( 15)
   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @cLOT              NVARCHAR( 10)
   DECLARE @nQTY              INT
   DECLARE @nSystemQTY        INT
   DECLARE @cToLOC            NVARCHAR( 10)
   DECLARE @cLogicalToLOC     NVARCHAR( 20)
   DECLARE @cToID             NVARCHAR( 18)
   DECLARE @cCaseID           NVARCHAR( 20)
   DECLARE @cFinalLOC         NVARCHAR( 10)
   DECLARE @cFinalID          NVARCHAR( 18)
   DECLARE @cTransitLOC       NVARCHAR( 10)
   DECLARE @nTransitCount     INT
   DECLARE @cUOM              NVARCHAR( 5)
   DECLARE @nUOMQty           INT
   DECLARE @cPriority         NVARCHAR( 10)
   DECLARE @cSourcePriority   NVARCHAR( 10)
   DECLARE @cSourceType       NVARCHAR( 30)
   DECLARE @cOrgTaskKey       NVARCHAR( 30)
   DECLARE @cRefTaskKey       NVARCHAR( 10)
   DECLARE @cPickMethod       NVARCHAR( 10)
   DECLARE @cTaskType         NVARCHAR( 10)

   DECLARE @cNewTaskStatus    NVARCHAR( 10)

   DECLARE @cFinalLocType     NVARCHAR( 10)
   DECLARE @cSLLocType        NVARCHAR( 10)
   DECLARE @cFinalLocCategory NVARCHAR( 10)
   DECLARE @cFinalLOCAreaKey  NVARCHAR( 10)
   DECLARE @cFinalLogicalLoc  NVARCHAR( 18)
   
   DECLARE @nCounter          INT
   DECLARE @nMax              INT
   DECLARE @cReplenByRPT      NVARCHAR( 1)
   DECLARE @cOrderKey         NVARCHAR(10)
   DECLARE @cLoadKey          NVARCHAR(10)
   DECLARE @nPABookingKey     INT = 0

   -- Init var
   SET @nErrNo = 0
   SET @cErrMsg = ''

   DECLARE @tTask TABLE
   (
      RowNumber      INT IDENTITY,
      TaskDetailKey  NVARCHAR(10),
      STATUS         NVARCHAR(10),
      Priority       NVARCHAR(10),
      SourcePriority NVARCHAR(10),
      StorerKey      NVARCHAR(15),
      SKU            NVARCHAR(20),
      LOT            NVARCHAR(10),
      UOM            NVARCHAR(5),
      UOMQty         INT,     
      QTY            INT,
      ToLOC          NVARCHAR(10),
      LogicalToLOC   NVARCHAR(20),
      ToID           NVARCHAR(18),
      CaseID         NVARCHAR(20),
      FinalLOC       NVARCHAR(10),
      FinalID        NVARCHAR(18),
      TransitCount   INT,
      PickMethod     NVARCHAR(10),
      RefTaskKey     NVARCHAR(10),
      WaveKey        NVARCHAR(10),
      SystemQTY      INT,
      OrderKey       NVARCHAR(10),
      LoadKey        NVARCHAR(10)
   )

   DECLARE @tNewTask TABLE
   (
      TaskDetailKey  NVARCHAR(10),
      TaskType       NVARCHAR(10),
      Priority       NVARCHAR(10),
      SourcePriority NVARCHAR(10),
      StorerKey      NVARCHAR(15),
      SKU            NVARCHAR(20),
      LOT            NVARCHAR(10),
      UOM            NVARCHAR(5),
      UOMQty         INT,            
      QTY            INT,
      FromLOC        NVARCHAR(10),
      FromID         NVARCHAR(18),
      ToLOC          NVARCHAR(10),
      ToID           NVARCHAR(18),
      CaseID         NVARCHAR(20),
      TransitCount   INT,
      PickMethod     NVARCHAR(10),
      RefTaskKey     NVARCHAR(10),
      WaveKey        NVARCHAR(10),
      SourceKey      NVARCHAR(30),
      SystemQTY      INT,
      OrderKey       NVARCHAR(10),
      LoadKey        NVARCHAR(10),
      LogicalFromLOC NVARCHAR(20),
      LogicalToLOC   NVARCHAR(20)
   )

   -- Get initial task info
   INSERT INTO @tTask (TaskDetailKey, Status, StorerKey, SKU, LOT, UOM, UOMQty, QTY, ToLOC, LogicalToLOC, ToID, CaseID, FinalLoc, FinalID, 
                        TransitCount, PickMethod, RefTaskKey, WaveKey, Priority, SourcePriority, SystemQTY,OrderKey,LoadKey)
      SELECT TaskDetailKey, Status, StorerKey, SKU, LOT, UOM, UOMQty, Qty, ToLOC, LogicalToLoc, ToID, Caseid, FinalLOC, FinalID, 
               TransitCount, PickMethod, RefTaskKey, WaveKey, Priority, SourcePriority, SystemQty,OrderKey,LoadKey
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE ListKey = @cListKey
         AND TransitCount = 0
         AND Qty <> 0 AND ISNULL(ReasonKey,'') = '' -- Skip the full short tasks

   SET @nMax = @@ROWCOUNT
   SET @nCounter = 1

   IF @nMax = 0
   BEGIN
      --V1.0.2 start
      Return
      /*
      SET @nErrNo = 230101
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Task to Handle
      GOTO FAIL*/
      --V1.0.2 end
   END

   IF @bDebugFlag = 1
   BEGIN
      SELECT 'Task List'
      SELECT * FROM @tTask
   END

   -- Not generate next task if:
   -- 1) Already reach final location or
   -- 2) There is no transit task involved or
   -- 3) Reach conveyor location
   IF EXISTS( SELECT 1 FROM @tTask WHERE ToLOC = FinalLOC)
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'ToLoc = FinalLoc, Return'
      RETURN
   END

   IF EXISTS( SELECT 1 FROM @tTask WHERE FinalLOC = '')
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'FinalLoc is empty, Return'
      RETURN
   END

   IF EXISTS( SELECT 1 FROM @tTask WHERE Status <> '9')
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'Not All Tasks Finished'
      RETURN
   END

   --IF EXISTS( SELECT 1 FROM @tTask Task JOIN dbo.LOC WITH (NOLOCK) ON (Task.ToLOC = LOC.LOC) WHERE LOC.LocationCategory = 'INDUCTION')
      --RETURN



   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1764CreateTask13 -- For rollback or commit only our own transaction

   WHILE @nCounter <= @nMax
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'Looping Tasks', @nCounter AS Counter, @nMax AS Max

      SELECT
         @cTaskDetailKey   = TASKDETAILKEY,
         @cWaveKey         = WaveKey,
         @cStorerKey       = StorerKey,
         @cToLOC           = ToLOC,
         @cLogicalToLOC    = ISNULL(LogicalToLOC,''),
         @cToID            = ToID,
         @cCaseID          = CaseID,
         @cFinalLoc        = FinalLoc,
         @cFinalID         = FinalID,
         @cPickMethod      = PickMethod,
         @cRefTaskKey      = RefTaskKey,
         @cSKU             = SKU,
         @cLOT             = LOT,
         @cUOM             = UOM,
         @nUOMQty          = UOMQty,
         @nQTY             = QTY,
         @nTransitCount    = TransitCount,
         @cPriority        = Priority,
         @cSourcePriority  = SourcePriority,
         @nSystemQTY       = SystemQty,
         @cSourceType      = 'rdt_1764CreateTask13',
         @cOrderKey        = OrderKey,
         @cLoadKey         = LoadKey
      FROM @tTask
      WHERE RowNumber = @nCounter

      IF @bDebugFlag = 1
         SELECT 'Current Task', @cTaskDetailKey

 
      -- Get Final loc attributes
      SELECT TOP 1
         @cFinalLocCategory = LOC.LocationCategory,
         @cFinalLocType = LOC.LocationType,
         @cFinalLogicalLoc = ISNULL(LOC.LogicalLocation,''),
         @cFinalLOCAreaKey = ISNULL(AreaKey,''),
         @cSLLocType    = SL.LocationType
      FROM dbo.LOC WITH (NOLOCK)
      JOIN dbo.PutawayZone PZ WITH (NOLOCK)
         ON LOC.FACILITY = PZ.FACILITY AND Loc.PutawayZone = PZ.PutawayZone
      LEFT JOIN dbo.SKUxLOC SL WITH (NOLOCK)  
         ON SL.StorerKey = @cStorerKey AND LOC.LOC = SL.LOC
      LEFT JOIN dbo.AreaDetail AD WITH(NOLOCK)
         ON PZ.PutawayZone = AD.PutawayZone
      WHERE LOC.LOC = @cFinalLOC

      SET @cNewTaskDetailKey = ''

      IF @bDebugFlag = 1
         SELECT 'Final Loc Attributes', @cFinalLOC AS FinalLoc, @cFinalLocCategory AS FinalLocCategory, 
            @cFinalLocType AS FinalLocType, @cSLLocType AS SLLocType

      --Generate ASTMV task
      IF @cFinalLocType = 'PND' AND @cFinalLocCategory = 'Induction'
      BEGIN

         IF @bDebugFlag = 1
         BEGIN
               SELECT 'Go throgh task list (ASTMV)'
               SELECT 'Check if there is any RFPUTAWAY task'
         END

         --v1.0.1 start
         -- Unlock the final loc if there is rfputaway record
         IF EXISTS (SELECT 1 FROM dbo.RFPUTAWAY WITH (NOLOCK)
                     WHERE TaskDetailKey = @cTaskDetailKey
                  )
         BEGIN
            IF @bDebugFlag = 1
               SELECT 'Unlock Task', @cTaskDetailKey
            
            EXEC rdt.rdt_Putaway_PendingMoveIn 
               @cUserName = ''
               ,@cType = 'UNLOCK'
               ,@cFromLoc = ''
               ,@cFromID = ''
               ,@cSuggestedLOC = ''
               ,@cStorerKey = @cStorerKey
               ,@nErrNo = @nErrNo OUTPUT
               ,@cErrMsg = @cErrmsg OUTPUT
               ,@cSKU = ''
               ,@nPutawayQTY    = 0
               ,@cFromLOT       = ''
               ,@cTaskDetailKey = @cTaskDetailKey
               ,@nFunc = @nFunc
               ,@nPABookingKey = 0
            IF @nErrNo <> 0
            BEGIN
               GOTO RollBackTran
            END
         END --unlock final loc
         --v1.0.1 end

         -- One pallet has muliple RPF tasks, only create one ASTMV task for each pallet
         IF NOT EXISTS (SELECT 1 FROM @tNewTask 
                        WHERE TaskType = 'ASTMV'
                           AND Storerkey = @cStorerKey
                           AND FromLOC = @cToLOC
                           AND ToLOC = @cFinalLOC
                           AND FromID = @cToID
                        )
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
               SET @nErrNo = 230102
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
               GOTO RollBackTran
            END

            IF @bDebugFlag = 1
               SELECT 'Insert new ASTMV task to list', @cNewTaskDetailKey

            INSERT INTO @tNewTask 
               (TaskDetailKey, TaskType, StorerKey, SKU, LOT, UOM, UOMQty, QTY, FromLOC,LogicalFromLOC, FromID, ToLOC, LogicalToLOC, 
                  ToID, CaseID,TransitCount, PickMethod, RefTaskKey, WaveKey,Priority, SourcePriority, SourceKey, 
                  SystemQTY,OrderKey,LoadKey)
            VALUES
               (@cNewTaskDetailKey, 'ASTMV', @cStorerKey, '', '', '', 0, 0, @cToLOC, @cLogicalToLOC, @cToID, @cFinalLOC, @cFinalLogicalLoc, 
                  @cToID, '', @nTransitCount+1, 'FP', @cRefTaskKey, @cWaveKey, @cPriority, @cSourcePriority, @cListKey,
                  @nSystemQTY,@cOrderKey,@cLoadKey)

            --v1.0.1 start
            IF @bDebugFlag = 1
               SELECT 'relock final loc'

            EXEC rdt.rdt_Putaway_PendingMoveIn 
               @cUserName = ''
               ,@cType = 'LOCK'
               ,@cFromLoc = @cToLOC
               ,@cFromID = @cToID
               ,@cSuggestedLOC = @cFinalLOC
               ,@cStorerKey = @cStorerKey
               ,@nErrNo = @nErrNo OUTPUT
               ,@cErrMsg = @cErrmsg OUTPUT
               ,@cTaskDetailKey = @cNewTaskDetailKey
               ,@nFunc = @nFunc
               ,@nPABookingKey = @nPABookingKey OUTPUT
               ,@cMoveQTYAlloc = '1'
            IF @nErrNo <> 0
            BEGIN
               GOTO RollBackTran
            END
            --V1.0.1 end
         END --generate ASTMV
      END --ASTMV
      ELSE IF (@cSLLocType = 'PICK' OR @cFinalLocType = 'DYNAMICPK') AND @cFinalLocCategory = 'Shelving' --v1.0.3
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
            SET @nErrNo = 230103
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
            GOTO RollBackTran
         END

         IF @bDebugFlag = 1
            SELECT 'Insert new ASTRPT task to list', @cNewTaskDetailKey

         INSERT INTO @tNewTask 
            (TaskDetailKey, TaskType, StorerKey, SKU, LOT, UOM, UOMQty, QTY, FromLOC, LogicalFromLOC, FromID, ToLOC, LogicalToLOC, ToID, CaseID, TransitCount, 
               PickMethod, RefTaskKey, WaveKey,Priority, SourcePriority, SourceKey, SystemQTY,OrderKey,LoadKey)
         VALUES
            (@cNewTaskDetailKey, 'ASTRPT', @cStorerKey, @cSKU, @cLOT, @cUOM, @nUOMQty, @nQTY, @cToLOC, @cLogicalToLOC, @cToID, @cFinalLOC, @cFinalLogicalLoc,  @cToID, @cCaseID, @nTransitCount+1, 
               'PP', @cRefTaskKey, @cWaveKey, @cPriority, @cSourcePriority, @cTaskDetailKey, @nSystemQTY,@cOrderKey,@cLoadKey)
      END --ASTRPT

      SET @nCounter = @nCounter + 1
   END --end while

   IF @bDebugFlag = 1
   BEGIN
      SELECT 'Loop finished'
      SELECT 'New Task List'
      SELECT * FROM @tNewTask
      SELECT 'Write to TaskDetail from NewTaskList'
   END

   BEGIN TRY
      INSERT INTO dbo.TaskDetail (
                  TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, QTY, CaseID, AreaKey, UOM, UOMQty,
                  PickMethod, StorerKey, SKU, LOT, ListKey, TransitCount, SourceType, SourceKey, WaveKey, Priority, SourcePriority, TrafficCop,
                  RefTaskKey, SystemQty,OrderKey,LoadKey,LogicalFromLOC,LogicalToLOC)
      SELECT
         TaskDetailKey, TaskType, '0', '', FromLOC, FromID, ToLOC, ToID, QTY, CaseID, @cFinalLOCAreaKey, UOM, UOMQty,
         PickMethod, StorerKey, SKU, LOT, '', TransitCount, 'rdt_1764CreateTask13', SourceKey, WaveKey, Priority, SourcePriority, NULL,
         RefTaskKey, SystemQTY,OrderKey,LoadKey,LogicalFromLOC,LogicalToLOC
      FROM @tNewTask
   END TRY
   BEGIN CATCH
      SET @nErrNo = 230104
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTaskFail
      GOTO RollBackTran
   END CATCH

   COMMIT TRAN rdt_1764CreateTask13 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764CreateTask13 -- Only rollback change made here
Fail:
Quit:
   IF @bDebugFlag = 1
      SELECT 'Quit', @nErrNo AS ErrNo, @cErrMsg AS ErrMsg
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO