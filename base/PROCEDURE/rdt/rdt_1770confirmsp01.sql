SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1770ConfirmSP01                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Split PickDetail base on UCC                                */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 11=03-2019  1.0  Ung       WMS-8244 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_1770ConfirmSP01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cTaskDetailKey NVARCHAR( 10),
   @cDropID        NVARCHAR( 20),
   @nQTY           INT,
   @cFinalLOC      NVARCHAR( 10),
   @cReasonKey     NVARCHAR( 10),
   @cListKey       NVARCHAR( 10),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT,
   @cDebug         NVARCHAR( 1) = NULL
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess       INT
   DECLARE @cTaskType      NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cMoveRefKey    NVARCHAR( 10)
   DECLARE @cStatus        NVARCHAR( 10)
   DECLARE @nTaskQTY       INT
   DECLARE @nQTY_Bal       INT
   DECLARE @nQTY_PD        INT
   DECLARE @nQTY_Move      INT
   DECLARE @cMoveQTYAlloc  NVARCHAR( 1)
   DECLARE @cMoveQTYPick   NVARCHAR( 1)
   DECLARE @nQTYAlloc      INT
   DECLARE @nQTYPick       INT
   DECLARE @cFromLOC       NVARCHAR( 10)
   DECLARE @cFromID        NVARCHAR( 18)
   DECLARE @cSKU           NVARCHAR( 15)
   DECLARE @cLOT           NVARCHAR( 10)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @cNewPickDetailKey  NVARCHAR( 10)

   -- Init var
   SET @nQTY_Move = 0
   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- Get task info
   SELECT
      @cTaskType = TaskType,
      @nTaskQTY = QTY, 
      @cStatus = Status,
      @cFromLOC = FromLOC, 
      @cFromID = FromID, 
      @cLOT = LOT
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey

   -- Check task already SKIP/CANCEL
   IF @cStatus IN ('0', 'X')
      RETURN

   -- Get UCC info
   DECLARE @nTotalUCCQTY INT
   SELECT @nTotalUCCQTY = ISNULL( SUM( QTY), 0) 
   FROM UCC WITH (NOLOCK) 
   WHERE LOC = @cFromLOC
      AND ID = @cFromID 
      AND Status = '1'

   -- Check UCC match pallet
   IF @nTotalUCCQTY > 0
   BEGIN
      IF @nTotalUCCQTY <> @nQTY
      BEGIN
         SET @nErrNo = 136051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PLT&UCCQTYDiff
         GOTO Quit
      END
   END
   
   -- Get storer config
   SET @cMoveQTYAlloc = rdt.rdtGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)
   SET @cMoveQTYPick = rdt.rdtGetConfig( @nFunc, 'MoveQTYPick', @cStorerKey)
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
   IF @cPickConfirmStatus NOT IN ( '3', '5')
      SET @cPickConfirmStatus = '5'

   -- Check move alloc, but picked
   IF @cMoveQTYAlloc = '1' AND @cPickConfirmStatus = '5'
   BEGIN
      SET @nErrNo = 136052
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- IncorrectSetup
      GOTO Quit
   END

   -- Check move picked, but not pick confirm
   IF @cMoveQTYPick = '1' AND @cPickConfirmStatus < '5'
   BEGIN
      SET @nErrNo = 136053
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- IncorrectSetup
      GOTO Quit
   END

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1770ConfirmSP01 -- For rollback or commit only our own transaction

   IF @cTaskType = 'FPK' -- need to update PickDetail
   BEGIN
      -- For calculation
      SET @nQTY_Bal = @nQTY

      -- Get PickDetail candidate (update status)
      DECLARE @curPD CURSOR
      SET @curPD = CURSOR FOR
         SELECT PickDetailKey, QTY, LOC, ID, SKU
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD, @cFromLOC, @cFromID, @cSKU
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Exact match
         IF @nQTY_PD = @nQTY_Bal
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               Status = @cPickConfirmStatus,
               DropID = '',
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 136054
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDtlFail
               GOTO RollBackTran
            END

            SET @nQTY_Move = @nQTY_Move + @nQTY_PD
            SET @nQTY_Bal = 0 -- Reduce balance
         END

         -- PickDetail have less
   		ELSE IF @nQTY_PD < @nQTY_Bal
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               Status = @cPickConfirmStatus,
               DropID = '',
               -- TrafficCop = NULL,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 136055
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDtlFail
               GOTO RollBackTran
            END

            SET @nQTY_Move = @nQTY_Move + @nQTY_PD
            SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance
         END

         -- PickDetail have more
   		ELSE IF @nQTY_PD > @nQTY_Bal
         BEGIN
            -- Short pick
            IF @nQTY_Bal = 0 -- Don't need to split
            BEGIN
               -- Confirm PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  Status = '4',
                  TaskDetailKey = '',
                  TrafficCop = NULL,
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 136056
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDtlFail
                  GOTO RollBackTran
               END
            END
            ELSE
            BEGIN -- Have balance, need to split

               -- Get new PickDetailkey
               EXECUTE dbo.nspg_GetKey
                  'PICKDETAILKEY',
                  10 ,
                  @cNewPickDetailKey OUTPUT,
                  @bSuccess         OUTPUT,
                  @nErrNo            OUTPUT,
                  @cErrMsg           OUTPUT
               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 136057
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetDetKey Fail
                  GOTO RollBackTran
               END

               -- Create new a PickDetail to hold the balance
               INSERT INTO dbo.PICKDETAIL (
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
                  UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,EffectiveDate, ArchiveCop, 
                  ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, Channel_ID, 
                  PickDetailKey,
                  QTY,
                  Status,
                  TrafficCop,
                  OptimizeCop)
               SELECT
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
                  UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
                  CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, 
                  ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, Channel_ID, 
                  @cNewPickDetailKey,
                  @nQTY_PD - @nQTY_Bal, -- QTY
                  -- CASE WHEN @cShort = 'Y' THEN '4' ELSE '0' END, -- Status
                  '4', -- Short
                  NULL, --TrafficCop,
                  '1'  --OptimizeCop
               FROM dbo.PickDetail WITH (NOLOCK)
      			WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
      				SET @nErrNo = 136058
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Ins PDtl Fail
                  GOTO RollBackTran
               END

               -- Split RefKeyLookup
               IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
               BEGIN
                  -- Insert RefKeyLookup
                  INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
                  SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
                  FROM RefKeyLookup WITH (NOLOCK)
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 136059
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsRefKeyFail
                     GOTO RollBackTran
                  END
               END

               -- Change orginal PickDetail with exact QTY (with TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  QTY = @nQTY_Bal,
                  DropID = '',
                  Trafficcop = NULL,
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 136060
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDtlFail
                  GOTO RollBackTran
               END

               -- Confirm orginal PickDetail with exact QTY
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  Status = @cPickConfirmStatus,
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 136061
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDtlFail
                  GOTO RollBackTran
               END

               -- Short pick
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  Status = '4',
                  TaskDetailKey = '',
                  TrafficCop = NULL,
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME()
               WHERE PickDetailKey = @cNewPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 136062
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDtlFail
                  GOTO RollBackTran
               END

               SET @nQTY_Move = @nQTY_Move + @nQTY_Bal
               SET @nQTY_Bal = 0 -- Reduce balance
            END
         END

         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD, @cFromLOC, @cFromID, @cSKU
      END

      -- Check offset
      IF @nQTY_Bal <> 0
      BEGIN
         SET @nErrNo = 136063
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Offset error
         GOTO RollBackTran
      END

      -- Get UCC candidate (update PickDetail.DropID = UCCNo)
      DECLARE @cUCCNo  NVARCHAR( 20) 
      DECLARE @cUCCLOT NVARCHAR( 10) 
      DECLARE @nUCCQTY INT
      DECLARE @curUCC  CURSOR
      IF @cLOT = ''
         SET @curUCC = CURSOR FOR
            SELECT UCCNo, LOT, QTY
            FROM UCC WITH (NOLOCK) 
            WHERE LOC = @cFromLOC
               AND ID = @cFromID 
               AND Status = '1' ORDER BY QTY,UCCNo  
      ELSE
         SET @curUCC = CURSOR FOR
            SELECT UCCNo, LOT, QTY
            FROM UCC WITH (NOLOCK) 
            WHERE LOT = @cLOT
               AND LOC = @cFromLOC
               AND ID = @cFromID 
               AND Status = '1' ORDER BY QTY,UCCNo  
      OPEN @curUCC
      FETCH NEXT FROM @curUCC INTO @cUCCNo, @cUCCLOT, @nUCCQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         WHILE @nUCCQTY > 0
         BEGIN
            -- Find PickDetail
            SET @cPickDetailKey = ''
            SELECT 
               @cPickDetailKey = PickDetailKey, 
               @nQTY_PD = QTY
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE TaskDetailKey = @cTaskDetailKey
               AND LOT = @cUCCLOT
               AND LOC = @cFromLOC
               AND ID = @cFromID
               AND Status = @cPickConfirmStatus
               AND DropID = ''
               AND QTY > 0 ORDER BY QTY DESC  

            -- Check PickDetail valid
            IF @cPickDetailKey = ''
            BEGIN
               SET @nErrNo = 136064
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PickDtlNoFound
               GOTO RollBackTran
            END

            -- Exact match or less
            IF @nQTY_PD <= @nUCCQTY
            BEGIN
               -- Confirm PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  DropID = @cUCCNo, 
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME(),
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 136065
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDtlFail
                  GOTO RollBackTran
               END
               
               SET @nUCCQTY = @nUCCQTY - @nQTY_PD
            END

            -- PickDetail have more
      		ELSE
            BEGIN
               -- Get new PickDetailkey
               EXECUTE dbo.nspg_GetKey
                  'PICKDETAILKEY',
                  10 ,
                  @cNewPickDetailKey OUTPUT,
                  @bSuccess         OUTPUT,
                  @nErrNo            OUTPUT,
                  @cErrMsg           OUTPUT
               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 136066
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetDetKey Fail
                  GOTO RollBackTran
               END

               -- Create new a PickDetail to hold the balance
               INSERT INTO dbo.PICKDETAIL (
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
                  UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,EffectiveDate, ArchiveCop, 
                  ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, Channel_ID,
                  PickDetailKey,
                  QTY,
                  Status,
                  TrafficCop,
                  OptimizeCop)
               SELECT
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
                  UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
                  CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, 
                  ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, Channel_ID, 
                  @cNewPickDetailKey,
                  @nQTY_PD - @nUCCQTY, -- QTY
                  Status,
                  NULL, --TrafficCop,
                  '1'  --OptimizeCop
               FROM dbo.PickDetail WITH (NOLOCK)
      			WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
      				SET @nErrNo = 136067
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Ins PDtl Fail
                  GOTO RollBackTran
               END

               -- Split RefKeyLookup
               IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
               BEGIN
                  -- Insert RefKeyLookup
                  INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
                  SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
                  FROM RefKeyLookup WITH (NOLOCK)
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 136068
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsRefKeyFail
                     GOTO RollBackTran
                  END
               END

               -- Change orginal PickDetail with exact QTY (with TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  QTY = @nUCCQTY,
                  DropID = @cUCCNo, 
                  Trafficcop = NULL,
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME()
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 136069
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDtlFail
                  GOTO RollBackTran
               END

               SET @nUCCQTY = 0
            END
         END
         
         FETCH NEXT FROM @curUCC INTO @cUCCNo, @cUCCLOT, @nUCCQTY
      END

      -- Move PickDetail
      IF (@cMoveQTYAlloc = '1' OR @cMoveQTYPick = '1') AND @nQTY_Move > 0
      BEGIN
         -- Calc alloc or pick
         IF @cPickConfirmStatus = '5'
         BEGIN
            SET @nQTYAlloc = 0
            SET @nQTYPick = @nQTY_Move
         END
         ELSE
         BEGIN
            SET @nQTYAlloc = @nQTY_Move
            SET @nQTYPick = 0
         END

         IF @cLOT = ''
            SET @cLOT = NULL

         IF @nTaskQTY = @nQTY
            -- Move by ID
            EXECUTE rdt.rdt_Move
               @nMobile        = @nMobile,
               @cLangCode      = @cLangCode,
               @nErrNo         = @nErrNo  OUTPUT,
               @cErrMsg        = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
               @cSourceType    = 'rdt_1770ConfirmSP01',
               @cStorerKey     = @cStorerKey,
               @cFacility      = @cFacility,
               @cFromLOC       = @cFromLOC,
               @cToLOC         = @cFinalLOC,
               @cFromID        = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
               @cToID          = @cFromID,     -- NULL means not changing ID. Blank consider a valid ID
               @nQTYAlloc      = @nQTYAlloc,
               @nQTYPick       = @nQTYPick,
               @cTaskDetailKey = @cTaskDetailKey,
               @nFunc          = @nFunc
         ELSE
            -- Move by SKU
            EXECUTE rdt.rdt_Move
               @nMobile        = @nMobile,
               @cLangCode      = @cLangCode,
               @nErrNo         = @nErrNo  OUTPUT,
               @cErrMsg        = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
               @cSourceType    = 'rdt_1770ConfirmSP01',
               @cStorerKey     = @cStorerKey,
               @cFacility      = @cFacility,
               @cFromLOC       = @cFromLOC,
               @cToLOC         = @cFinalLOC,
               @cFromID        = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
               @cToID          = @cFromID,     -- NULL means not changing ID. Blank consider a valid ID
               @cSKU           = @cSKU,
               @nQTY           = @nQTY,
               @cFromLOT       = @cLOT,
               @nQTYAlloc      = @nQTYAlloc,
               @nQTYPick       = @nQTYPick,
               @cTaskDetailKey = @cTaskDetailKey,
               @nFunc          = @nFunc
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      -- Update Task
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
         Status = '9', -- Closed
         DropID = @cDropID,
         QTY = @nQTY,
         ToLOC = @cFinalLOC,
         ReasonKey = @cReasonKey,
         EndTime = GETDATE(),
         EditDate = GETDATE(),
         EditWho  = @cUserName,
         Trafficcop = NULL
      WHERE TaskDetailKey = @cTaskDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 136070
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
         GOTO RollBackTran
      END
   END

   -- TaskType = FPK1 (don't need to update PickDetail)
   ELSE
   BEGIN
      IF (@cMoveQTYAlloc = '1' OR @cMoveQTYPick = '1')
      BEGIN
         -- Move PickDetail
         EXECUTE rdt.rdt_Move
            @nMobile        = @nMobile,
            @cLangCode      = @cLangCode,
            @nErrNo         = @nErrNo  OUTPUT,
            @cErrMsg        = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
            @cSourceType    = 'rdt_1770ConfirmSP01',
            @cStorerKey     = @cStorerKey,
            @cFacility      = @cFacility,
            @cFromLOC       = @cFromLOC,
            @cToLOC         = @cFinalLOC,
            @cFromID        = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
            @cToID          = @cFromID,     -- NULL means not changing ID. Blank consider a valid ID
            @nFunc          = @nFunc
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      -- Update Task
      UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
         Status = '9', -- Closed
         ToLOC = @cFinalLOC,
         ReasonKey = @cReasonKey,
         EndTime = GETDATE(),
         EditDate = GETDATE(),
         EditWho  = @cUserName,
         Trafficcop = NULL
      WHERE TaskDetailKey = @cTaskDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 136071
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
         GOTO RollBackTran
      END
   END

   -- Create next task
   EXEC rdt.rdt_TM_PalletPick_CreateNextTask @nMobile, @nFunc, @cLangCode,
      @cUserName,
      @cListKey,
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO RollBackTran

   COMMIT TRAN rdt_1770ConfirmSP01 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1770ConfirmSP01 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO