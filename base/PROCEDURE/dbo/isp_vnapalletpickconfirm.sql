SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_VNAPalletPickConfirm                            */
/* Copyright      : Maersk WMS                                          */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2024-03-08  1.0  NLT013    UWP-16452 Created                         */
/* 2024-05-16  1.1  NLT013    UWP-19518 Ability to config task priority */
/************************************************************************/

CREATE PROC [dbo].[isp_VNAPalletPickConfirm] (
   @cTaskDetailKey                  NVARCHAR( 10),
   @nErrNo                          INT            OUTPUT,
   @cErrMsg                         NVARCHAR( 255) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @nMobile                      INT,
      @cLangCode                    NVARCHAR(3),
      @nFunc                        INT,
      @nInternalErrNo               INT,

      @cSQL                         NVARCHAR(MAX),
      @cSQLParam                    NVARCHAR(MAX),
      @cConfirmSP                   NVARCHAR( 20),
      @cPickedStatus                NVARCHAR( 1),
      @cPickConfirmStatus           NVARCHAR( 1),
      @bSuccess                     INT,
      @cFacility                    NVARCHAR( 5),
      @cStorerKey                   NVARCHAR( 15),

      @nQty                         INT,
      @nQTY_Bal                     INT,
      @nQTY_PD                      INT,
      @nQTY_Move                    INT,
      @nQTYAlloc                    INT,
      @nQTYPick                     INT,
      @cUOM                         NVARCHAR( 5),
      @nUOMQty                      INT,

      @cPickDetailKey               NVARCHAR( 10),
      @cTaskType                    NVARCHAR( 10),
      @cStatus                      NVARCHAR( 10),
      @cTaskCode                    NVARCHAR( 10),
      @cLOT                         NVARCHAR( 10),
      @cPickMethod                  NVARCHAR( 10),
      @cSourceType                  NVARCHAR( 30),
      @cFromLoc                     NVARCHAR( 10),
      @cFromID                      NVARCHAR( 18),
      @cSku                         NVARCHAR( 20),
      @cListKey                     NVARCHAR( 10),

      @cTaskUserKey                 NVARCHAR( 18),
      @cTaskFromLoc                 NVARCHAR( 10),
      @cTaskToLoc                   NVARCHAR( 10),
      @cTaskFinalLoc                NVARCHAR( 10),
      @cID                          NVARCHAR( 18),
      @cTaskStatus                  NVARCHAR( 10),
      @cLoadKey                     NVARCHAR( 10),

      @cVNAOUT                      NVARCHAR( 10) = 'VNAOUT',
      @cFPK                         NVARCHAR( 10) = 'FPK',
      @cFPK1                        NVARCHAR( 10) = 'FPK1',
      @cUserName                    NVARCHAR( 18),
      @cNewTaskDetailKey            NVARCHAR( 10),
      @cPnDTransitTaskPriority      NVARCHAR( 10),
      @cLocCategory                 NVARCHAR( 10)


   -- Init var
   SET @nFunc              = 1201
   SET @nMobile            = -1
   SET @cLangCode          = 'ENG'
   SET @nQTY_Move          = 0
   SET @nErrNo             = 0
   SET @cErrMsg            = ''
   SET @nInternalErrNo     = 0
   SET @cSourceType        = 'isp_VNAPalletPickConfirm'
   SET @cPickedStatus      = '5'
   SET @cPickConfirmStatus = '9'
   SET @cUserName          = SYSTEM_USER

   -- Get task info
   SELECT
      @cTaskType        = td.TaskType,
      @cTaskCode        = ISNULL(td.Message03, ''),
      @cFacility        = ISNULL(loc.Facility, ''),
      @cStorerKey       = td.StorerKey,
      @cTaskFromLoc     = td.FromLoc,
      @cTaskToLoc       = ToLoc,
      @cID              = ToID,
      @nQTY             = td.Qty,
      @cTaskUserKey     = td.UserKey,
      @cTaskStatus      = td.Status,
      @cListKey         = td.ListKey,
      @cStatus          = td.Status,
      @cTaskFinalLoc    = td.FinalLOC,
      @cLoadKey         = td.LoadKey,
      @cLot             = td.Lot,
      @cUOM             = td.UOM,
      @nUOMQty          = td.UOMQty
   FROM dbo.TaskDetail td WITH(NOLOCK)
   INNER JOIN dbo.Loc loc WITH(NOLOCK)
      ON td.FromLoc = loc.Loc
   INNER JOIN dbo.Loc loc1 WITH(NOLOCK)
      ON td.ToLoc = loc1.Loc
      AND loc.Facility = loc1.Facility
   WHERE TaskDetailKey = @cTaskDetailKey

   -- Check task already SKIP/CANCEL
   IF @cStatus <> '3'
   BEGIN
      SET @nErrNo = 212530
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Task Status
      RETURN
   END

   IF @cTaskType <> @cVNAOUT OR  @cTaskCode <> @cFPK
   BEGIN
      SET @nErrNo = 212515
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Not VNAOUTFPK Task
      RETURN
   END

   IF @cLoadKey IS NULL OR TRIM(@cLoadKey) = ''
   BEGIN
      SET @nErrNo = 212532
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LoadKey is missing in Task Detail
      RETURN
   END

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN isp_VNAPalletPickConfirm -- For rollback or commit only our own transaction

   -- For calculation
   SET @nQTY_Bal = @nQTY

   -- Get PickDetail candidate
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
            Status = @cPickedStatus,
            DropID = CASE WHEN @cID = '' THEN DropID ELSE @cID END,
            EditDate = GETDATE(),
            EditWho  = SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 212519
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
            Status = @cPickedStatus,
            DropID = CASE WHEN @cID = '' THEN DropID ELSE @cID END,
            EditDate = GETDATE(),
            EditWho  = SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 212520
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Update Task Detail Fail
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
               SET @nErrNo = 212521
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDtlFail
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN -- Have balance, need to split

            -- Get new PickDetailkey
            DECLARE @cNewPickDetailKey NVARCHAR( 10)
            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY',
               10 ,
               @cNewPickDetailKey OUTPUT,
               @bSuccess          OUTPUT,
               @nErrNo            OUTPUT,
               @cErrMsg           OUTPUT
            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 212522
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'GetDetKey Fail'
               GOTO RollBackTran
            END

            -- Create new a PickDetail to hold the balance
            INSERT INTO dbo.PICKDETAIL (
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
               ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo,
               PickDetailKey,
               QTY,
               Status,
               TrafficCop,
               OptimizeCop)
            SELECT
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
               CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo,
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
               SET @nErrNo = 212523
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
                  SET @nErrNo = 212524
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsRefKeyFail
                  GOTO RollBackTran
               END
            END

            -- Change orginal PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               QTY = @nQTY_Bal,
               DropID = CASE WHEN @cID = '' THEN DropID ELSE @cID END,
               Trafficcop = NULL,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 212525
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDtlFail
               GOTO RollBackTran
            END

            -- Confirm orginal PickDetail with exact QTY
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               Status = @cPickedStatus,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 212526
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
               SET @nErrNo = 212527
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
      SET @nErrNo = 212528
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Offset error
      GOTO RollBackTran
   END 

   SET @nQTYAlloc    = 0
   SET @nQTYPick     = @nQTY_Move

   -- Execute move process
   -- Move by ID
   EXECUTE rdt.rdt_Move
      @nMobile        = @nMobile,
      @cLangCode      = @cLangCode,
      @nErrNo         = @nErrNo  OUTPUT,
      @cErrMsg        = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
      @cSourceType    = cSourceType,
      @cStorerKey     = @cStorerKey,
      @cFacility      = @cFacility,
      @cFromLOC       = @cTaskFromLoc,
      @cToLOC         = @cTaskToLoc,
      @cFromID        = @cID,     -- NULL means not filter by ID. Blank is a valid ID
      @cToID          = @cID,     -- NULL means not changing ID. Blank consider a valid ID
      @nQTYAlloc      = @nQTYAlloc,
      @nQTYPick       = @nQTYPick,
      @cTaskDetailKey = @cTaskDetailKey,
      @nFunc          = @nFunc

   IF @nErrNo <> 0
   BEGIN
      SET @nInternalErrNo = 212540
      SET @cErrMsg = CONCAT_WS(',', rdt.rdtgetmessage( @nInternalErrNo, @cLangCode, 'DSP'),  @nErrNo, @cErrMsg )--Move Inentory Fail, details:
      GOTO RollBackTran
   END

   -- Update Task
   UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
      Status            = @cPickConfirmStatus, -- Closed
      EndTime           = GETDATE(),
      EditDate          = GETDATE(),
      EditWho           = @cUserName,
      Trafficcop        = NULL,
      StatusMsg         = '',
      PendingMoveIn     = 0
   WHERE TaskDetailKey = @cTaskDetailKey

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 212529
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Update Task Detail Fail
      GOTO RollBackTran
   END

   -- Create next task
   EXEC rdt.rdt_TM_PalletPick_CreateNextTask @nMobile, @nFunc, @cLangCode,
      @cUserName,
      @cListKey,
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
      
   IF @nErrNo <> 0
   BEGIN
      SET @nInternalErrNo = 212542
      SET @cErrMsg = CONCAT_WS(',', rdt.rdtgetmessage( @nInternalErrNo, @cLangCode, 'DSP'),  @nErrNo, @cErrMsg )--Create 2nd task Fail, details:
      GOTO RollBackTran
   END

   SELECT @cNewTaskDetailKey = TaskDetailKey,
         @cFromLoc = FromLoc
   FROM dbo.TaskDetail td WITH(NOLOCK)
   WHERE StorerKey         = @cStorerKey
      AND TaskType         = @cFPK1
      AND FromID           = @cID
      AND Status           = '0'
      AND FromLoc          = @cTaskToLoc
      AND ToLoc            = @cTaskFinalLoc
      AND LoadKey          = @cLoadKey

   IF @cNewTaskDetailKey IS NULL OR TRIM(@cNewTaskDetailKey) = ''
   BEGIN
      SET @nErrNo = 212517
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No new task
      GOTO RollBackTran
   END

      --Get ToLoc category from latest transit task
   SELECT @cLocCategory = LocationCategory
   FROM dbo.Loc WITH(NOLOCK)
   WHERE Facility = @cFacility
      AND Loc = @cFromLoc
   
   --Get PnDTransitTaskPriority
   SET @cPnDTransitTaskPriority = rdt.RDTGetConfig( @nFunc, 'PnDTransitTaskPriority', @cStorerKey)
   IF @cPnDTransitTaskPriority IS NULL OR TRY_CAST(@cPnDTransitTaskPriority AS INT) IS NULL 
      SET @cPnDTransitTaskPriority = '0'

   UPDATE dbo.TaskDetail WITH (ROWLOCK) SET 
      RefTaskKey        = @cTaskDetailKey,
      UserKey           = '',
      UOM               = @cUOM,
      UOMQty            = @nUOMQty,
      Qty               = @nQty,
      Priority          = CASE WHEN @cLocCategory IN ('PND_IN', 'PND_OUT', 'PND') AND @cPnDTransitTaskPriority BETWEEN 1 AND 9 THEN @cPnDTransitTaskPriority ELSE Priority END
   WHERE TaskDetailKey = @cNewTaskDetailKey

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 212518
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Update new task fail
      GOTO RollBackTran
   END

   DELETE FROM dbo.RFPUTAWAY
   WHERE StorerKey = @cStorerKey
      AND TaskDetailKey = @cTaskDetailKey

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 212547
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Remove Putaway Record Fail
      GOTO RollBackTran
   END

   COMMIT TRAN isp_VNAPalletPickConfirm -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN isp_VNAPalletPickConfirm -- Only rollback change made here

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO