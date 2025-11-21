SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispVFRPFDecodeLstCtn                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Decode last carton                                          */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 09-07-2013  1.0  Ung         SOS272437. Created                      */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispVFRPFDecodeLstCtn]
	 @cLangCode	      NVARCHAR(3)
   ,@cTaskDetailKey  NVARCHAR(10)
   ,@cUCCNo          NVARCHAR(20)
   ,@nPickQty        INT         OUTPUT
   ,@nErrNo          INT         OUTPUT
   ,@cErrMsg         NVARCHAR(20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT
   DECLARE @b_success      INT

   DECLARE @cOrderGroup    NVARCHAR(20)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @nPD_QTY        INT
   DECLARE @nBalQTY        INT

   DECLARE @cOtherTaskDetailKey NVARCHAR( 10)
   DECLARE @cNewTaskDetailKey   NVARCHAR( 10)
   DECLARE @cTaskType      NVARCHAR( 10)
   DECLARE @cListKey       NVARCHAR( 10)
   DECLARE @cWaveKey       NVARCHAR( 10)
   DECLARE @cToLOC         NVARCHAR( 10)
   DECLARE @cToID          NVARCHAR( 18)
   DECLARE @cLOT           NVARCHAR( 10)
   DECLARE @cLOC           NVARCHAR( 10)
   DECLARE @cID            NVARCHAR( 18)
   DECLARE @nTD_QTY        INT
   DECLARE @cTD_ToLOC      NVARCHAR( 10)
   DECLARE @cTD_ToID       NVARCHAR( 18)
   DECLARE @nSystemQTY     INT
   DECLARE @cUserKey       NVARCHAR( 18)
   DECLARE @cTransitLOC    NVARCHAR( 10)
   DECLARE @nTransitCount  INT
   DECLARE @cSourceType    NVARCHAR( 30)
   DECLARE @cPickMethod    NVARCHAR( 1)

   DECLARE @curPD CURSOR
   DECLARE @curTD CURSOR

   -- Last carton logic
   /*
   if loose carton balance < qty available to move (means taken by other wave)
      check if other wave(s) with same type  (retail or launch type) had allocated it
      if no, prompt error
      if yes
         find its pickdetail, split it if necessary
         find its taskdetail, split it if necessary
      update task with listkey
   */

   SET @cPickMethod = 'L' -- Loose case
   SET @cOtherTaskDetailKey = ''

   -- Get task info
   SELECT 
      @cWaveKey = WaveKey, 
      @cListKey = ListKey,
      @cTaskType = TaskType, 
      @cToLOC = ToLOC,
      @cToID = ToID,
      @cLOT = LOT, 
      @cLOC = FromLOC,
      @cID = FromID, 
      @cTransitLOC = TransitLOC, 
      @nTransitCount = TransitCount, 
      @cUserKey = UserKey, 
      @cSourceType = 'ispVFRPFDecodeLstCtn'
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey
   
   -- Get Wave grouping 
   SELECT TOP 1 
      @cOrderGroup = OrderGroup -- X=Launch, RT=Retail, WS=Wholesale
   FROM dbo.Orders O WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
   WHERE PD.TaskDetailKey = @cTaskDetailKey
   
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN ispVFRPFDecodeLstCtn -- For rollback or commit only our own transaction
   
   -- Get TaskDetail candidate
   SET @curTD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TD.TaskDetailKey, TD.QTY, TD.ToLOC, TD.ToID
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      WHERE TD.TaskType = @cTaskType
         AND TD.LOT = @cLOT
         AND TD.FromLOC = @cLOC
         AND TD.FromID = @cID
         AND TD.Status = '0'
         AND TD.UOM = '7' -- Loose carton
         AND TD.TaskDetailKey <> @cTaskDetailKey
         AND EXISTS( SELECT TOP 1 1
            FROM WaveDetail WD WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON (WD.OrderKey = O.OrderKey)
            WHERE WD.WaveKey = TD.WaveKey
               AND O.OrderGroup = CASE WHEN @cOrderGroup = 'L' THEN 'L' ELSE OrderGroup END) -- X one group, RT/WS another group. Same group go to same destination
      ORDER BY TD.QTY
      
   -- Loop TaskDetail
   OPEN @curTD
   FETCH NEXT FROM @curTD INTO @cOtherTaskDetailKey, @nTD_QTY, @cTD_ToLOC, @cTD_ToID
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Exact match
      IF @nTD_QTY = @nPickQty
      BEGIN
         -- TaskDetail
         UPDATE TaskDetail WITH (ROWLOCK) SET
             Status       = '3'
            ,UserKey      = @cUserKey
            ,ReasonKey    = ''
            ,RefTaskKey   = @cTaskDetailKey
            ,TransitLOC   = CASE WHEN @cTransitLOC = '' THEN TransitLOC   ELSE @cTransitLOC   END
            ,FinalLOC     = CASE WHEN @cTransitLOC = '' THEN FinalLOC     ELSE @cTD_ToLOC     END
            ,FinalID      = CASE WHEN @cTransitLOC = '' THEN FinalID      ELSE @cTD_ToID      END
            ,ToLOC        = CASE WHEN @cTransitLOC = '' THEN ToLOC        ELSE @cTransitLOC   END
            ,ToID         = CASE WHEN @cTransitLOC = '' THEN ToID         ELSE @cToID         END
            ,TransitCount = CASE WHEN @cTransitLOC = '' THEN TransitCount ELSE @nTransitCount END
            ,ListKey      = @cListKey
            ,StartTime    = CURRENT_TIMESTAMP
            ,EditDate     = CURRENT_TIMESTAMP
            ,EditWho      = @cUserKey
            ,TrafficCop   = NULL
         WHERE TaskDetailKey = @cOtherTaskDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 81651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDTaskDtlFail
            GOTO RollBackTran
         END
         
         -- PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            DropID = @cUCCNo, 
            PickMethod = @cPickMethod, 
            TrafficCop = NULL
         WHERE TaskDetailKey = @cOtherTaskDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 81652
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END
         
         SET @nPickQty = 0 -- Reduce balance
         BREAK
      END
            
      -- TaskDetail have less
      ELSE IF @nTD_QTY < @nPickQty
      BEGIN
         -- TaskDetail
         UPDATE TaskDetail WITH (ROWLOCK) SET
             Status       = '3'
            ,UserKey      = @cUserKey
            ,ReasonKey    = ''
            ,RefTaskKey   = @cTaskDetailKey
            ,TransitLOC   = CASE WHEN @cTransitLOC = '' THEN TransitLOC   ELSE @cTransitLOC   END
            ,FinalLOC     = CASE WHEN @cTransitLOC = '' THEN FinalLOC     ELSE @cTD_ToLOC     END
            ,FinalID      = CASE WHEN @cTransitLOC = '' THEN FinalID      ELSE @cTD_ToID      END
            ,ToLOC        = CASE WHEN @cTransitLOC = '' THEN ToLOC        ELSE @cTransitLOC   END
            ,ToID         = CASE WHEN @cTransitLOC = '' THEN ToID         ELSE @cToID         END
            ,TransitCount = CASE WHEN @cTransitLOC = '' THEN TransitCount ELSE @nTransitCount END
            ,ListKey      = @cListKey
            ,StartTime    = CURRENT_TIMESTAMP
            ,EditDate     = CURRENT_TIMESTAMP
            ,EditWho      = @cUserKey
            ,TrafficCop   = NULL
         WHERE TaskDetailKey = @cOtherTaskDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 81653
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDTaskDtlFail
            GOTO RollBackTran
         END
         
         -- PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            DropID = @cUCCNo, 
            PickMethod = @cPickMethod, 
            TrafficCop = NULL
         WHERE TaskDetailKey = @cOtherTaskDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 81654
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END

         SET @nPickQty = @nPickQty - @nTD_QTY -- Reduce balance
      END

      -- TaskDetail have more, split TaskDetail and PickDetail
      ELSE IF @nTD_QTY > @nPickQty
      BEGIN
         -- Get new TaskDetailKey
      	SET @b_success = 1
      	EXECUTE dbo.nspg_getkey
      		'TASKDETAILKEY'
      		, 10
      		, @cNewTaskDetailKey OUTPUT
      		, @b_success         OUTPUT
      		, @nErrNo            OUTPUT
      		, @cErrMsg           OUTPUT
         IF @b_success <> 1
         BEGIN
            SET @nErrNo = 81655
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
            GOTO RollBackTran
         END

         -- Create a new TaskDetail to hold the balance
         INSERT INTO TaskDetail (
            TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, QTY, SystemQTY, 
            UOM, PickMethod, StorerKey, SKU, LOT, WaveKey, Priority, SourcePriority, SourceType, TrafficCop)
         SELECT
            @cNewTaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, QTY-@nPickQty, SystemQTY-@nPickQty, 
            UOM, PickMethod, StorerKey, SKU, LOT, WaveKey, Priority, SourcePriority, @cSourceType, NULL
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cOtherTaskDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 81656
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
            GOTO RollBackTran
         END
         
         -- Update original TaskDetail to take the QTY
         UPDATE TaskDetail WITH (ROWLOCK) SET
             Status       = '3'
            ,QTY          = @nPickQty
            ,SystemQTY    = @nPickQty
            ,UserKey      = @cUserKey
            ,ReasonKey    = ''
            ,RefTaskKey   = @cTaskDetailKey
            ,TransitLOC   = CASE WHEN @cTransitLOC = '' THEN TransitLOC   ELSE @cTransitLOC   END
            ,FinalLOC     = CASE WHEN @cTransitLOC = '' THEN FinalLOC     ELSE @cTD_ToLOC     END
            ,FinalID      = CASE WHEN @cTransitLOC = '' THEN FinalID      ELSE @cTD_ToID      END
            ,ToLOC        = CASE WHEN @cTransitLOC = '' THEN ToLOC        ELSE @cTransitLOC   END
            ,ToID         = CASE WHEN @cTransitLOC = '' THEN ToID         ELSE @cToID         END
            ,TransitCount = CASE WHEN @cTransitLOC = '' THEN TransitCount ELSE @nTransitCount END
            ,ListKey      = @cListKey
            ,StartTime    = CURRENT_TIMESTAMP
            ,EditDate     = CURRENT_TIMESTAMP
            ,EditWho      = @cUserKey
            ,TrafficCop   = NULL
         WHERE TaskDetailKey = @cOtherTaskDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 81657
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDTaskDtlFail
            GOTO RollBackTran
         END
         
         SET @nBalQTY = @nTD_QTY - @nPickQTY
         SET @nPickQTY = 0
         
         -- Create new PickDetail(s) to hold the balance
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.PickDetailKey, PD.QTY
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.TaskDetailKey = @cOtherTaskDetailKey
               AND PD.QTY > 0
               AND PD.Status = '0'
               AND PD.DropID = ''
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nPD_QTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Exact match
            IF @nPD_QTY = @nBalQTY
            BEGIN
               -- PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  TaskDetailKey = @cNewTaskDetailKey, 
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 81658
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
               SET @nBalQTY = 0 -- Reduce balance
               BREAK
            END
      
            -- PickDetail have less
            ELSE IF @nPD_QTY < @nBalQTY
            BEGIN
               -- PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  TaskDetailKey = @cNewTaskDetailKey, 
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 81659
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
      
               SET @nBalQTY = @nBalQTY - @nPD_QTY -- Reduce balance
            END
      
            -- PickDetail have more, need to split
            ELSE IF @nPD_QTY > @nBalQTY
            BEGIN
               -- Get new PickDetailkey
               DECLARE @cNewPickDetailKey NVARCHAR( 10)
               EXECUTE dbo.nspg_GetKey
                  'PICKDETAILKEY',
                  10 ,
                  @cNewPickDetailKey OUTPUT,
                  @b_success         OUTPUT,
                  @nErrNo            OUTPUT,
                  @cErrMsg           OUTPUT
               IF @b_success <> 1
               BEGIN
                  SET @nErrNo = 81660
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
                  GOTO RollBackTran
               END
      
               -- Create a new PickDetail to hold the balance
               INSERT INTO dbo.PickDetail (
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
                  DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
                  PickDetailKey,
                  Status, 
                  QTY,
                  TrafficCop,
                  OptimizeCop)
               SELECT
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,
                  DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
                  @cNewPickDetailKey,
                  '0', 
                  @nPD_QTY - @nBalQTY, -- QTY
                  NULL, --TrafficCop
                  '1'   --OptimizeCop
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 81661
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail
                  GOTO RollBackTran
               END
      
               -- Change original PickDetail with exact QTY (with TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  QTY = @nBalQTY,
                  TaskDetailKey = @cNewTaskDetailKey, 
                  Trafficcop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 81662
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
      
               SET @nBalQTY = 0 -- Reduce balance
               BREAK
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nPD_QTY
         END
         
         -- Check offset error
         IF @nBalQTY <> 0
         BEGIN
            SET @nErrNo = 81663
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ErrOffsetPKDtl
            GOTO RollBackTran
         END
      
         -- Update original PickDetail(s) to take the QTY
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.PickDetailKey
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.TaskDetailKey = @cOtherTaskDetailKey
               AND PD.QTY > 0
               AND PD.Status = '0'
               AND PD.DropID = ''
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cUCCNo, 
               PickMethod = @cPickMethod, 
               TrafficCop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 81664
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END
      END
      
      FETCH NEXT FROM @curTD INTO @cOtherTaskDetailKey, @nTD_QTY, @cTD_ToLOC, @cTD_ToID
   END
            
   -- Update own RefTaskKey
   IF @cOtherTaskDetailKey <> ''
   BEGIN
      UPDATE TaskDetail WITH (ROWLOCK) SET
          RefTaskKey = @cTaskDetailKey
         ,TrafficCop = NULL
      WHERE TaskDetailKey = @cTaskDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 81665
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDTaskDtlFail
         GOTO RollBackTran
      END
   END
   
   COMMIT TRAN ispVFRPFDecodeLstCtn
   GOTO Quit
   
RollBackTran:
      ROLLBACK TRAN ispVFRPFDecodeLstCtn
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO