SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtVFRPFCfmExtUpd                                   */
/* Purpose: Confirm extended update. Update PickDetail                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2014-02-25   Ung       1.0   SOS259759 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtVFRPFCfmExtUpd]
    @nMobile            INT 
   ,@nFunc              INT 
   ,@cLangCode          NVARCHAR( 3) 
   ,@cTaskdetailKey     NVARCHAR( 10) 
   ,@cNewTaskdetailKey  NVARCHAR( 10) 
   ,@nErrNo             INT           OUTPUT 
   ,@cErrMsg            NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPickDetailKey NVARCHAR(10)
   DECLARE @cDropID        NVARCHAR(20)
   DECLARE @bSuccess       INT
   DECLARE @nQTY_PD        INT
   DECLARE @nPickQTY       INT
   DECLARE @nNewTaskQty    INT
   DECLARE @nOrgTaskQty    INT
   DECLARE @nShortQTY      INT
   DECLARE @cType          NVARCHAR(10)
   DECLARE @cTask          NVARCHAR(3)

   SET @nOrgTaskQty = 0
   SET @nShortQTY = 0
   SET @nNewTaskQty = 0

   -- Not split task, exit
   IF @cNewTaskdetailKey = ''
      RETURN

   -- Get orginal task info
   SELECT 
      @nOrgTaskQty = QTY, 
      @nShortQTY   = CASE WHEN QTY < SystemQTY THEN SystemQTY - QTY ELSE 0 END
   FROM TaskDetail WITH (NOLOCK) 
   WHERE TaskDetailKey = @cTaskdetailKey

   -- Get new task (splitted task) info 
   SELECT @nNewTaskQty = SystemQTY FROM TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cNewTaskdetailKey

   -- Get PickDetail info
   IF EXISTS( SELECT TOP 1 1 FROM PickDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskdetailKey AND DropID <> '')
      SET @cType = 'UCC'
   ELSE
      SET @cType = 'DPP'

   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdtVFRPFCfmExtUpd

   -- Loop PickDetail for original task
   DECLARE @curPD CURSOR
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.PickDetailKey, PD.QTY, PD.DropID
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.TaskDetailKey = @cTaskDetailKey
         AND PD.QTY > 0
         AND PD.Status = '0'

   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD, @cDropID
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- UCC
      IF @cType = 'UCC' 
      BEGIN
         -- For original task
         IF @cDropID <> ''
            SET @nOrgTaskQty = @nOrgTaskQty - @nQTY_PD

         -- For new task
         IF @cDropID = '' 
         BEGIN
            -- Change PickDetail task
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               TaskDetailKey = @cNewTaskDetailKey, 
               EditWho  = SUSER_SNAME(), 
               EditDate = GETDATE(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 85401
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            
            SET @nNewTaskQty = @nNewTaskQty - @nQTY_PD
         END
      END
      
      -- DPP
      IF @cType = 'DPP'
      BEGIN 
         -- Decide which task and what QTY to offset
         IF @nOrgTaskQty > 0
         BEGIN
            SET @cTask = 'ORG'
            SET @nPickQty = @nOrgTaskQty
            SET @cTaskDetailKey = @cTaskDetailKey
         END
         ELSE IF @nShortQTY > 0
         BEGIN
            SET @cTask = 'SHT'
            SET @nPickQty = @nShortQty
            SET @cTaskDetailKey = @cTaskDetailKey
         END
         ELSE IF @nNewTaskQTY > 0
         BEGIN
            SET @cTask = 'NEW'
            SET @nPickQty = @nNewTaskQty
            SET @cTaskDetailKey = @cNewTaskDetailKey
         END
   
         -- PickDetail have less or exact match
         IF @nQTY_PD <= @nPickQty
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               TaskDetailKey = @cTaskDetailKey, 
               Status = CASE WHEN @cTask = 'SHT' THEN '4' ELSE Status END, 
               EditWho  = SUSER_SNAME(), 
               EditDate = GETDATE(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 85402
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
         END
   
         -- PickDetail have more, need to split
         ELSE IF @nQTY_PD > @nPickQty
         BEGIN
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
               SET @nErrNo = 85403
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
               @nQTY_PD - @nPickQty, -- QTY
               NULL, --TrafficCop
               '1'   --OptimizeCop
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 85404
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail
               GOTO RollBackTran
            END
   
            -- Change original PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               QTY = @nPickQty,
               TaskDetailKey = @cTaskDetailKey, 
               Status = CASE WHEN @cTask = 'SHT' THEN '4' ELSE Status END, 
               EditWho  = SUSER_SNAME(), 
               EditDate = GETDATE(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 85405
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            
            -- Set QTY taken
            SET @nQTY_PD = @nPickQty
         END
   
         -- Reduce balance
         IF @cTask = 'ORG' SET @nOrgTaskQty = @nOrgTaskQty - @nQTY_PD
         IF @cTask = 'SHT' SET @nShortQty   = @nShortQty   - @nQTY_PD
         IF @cTask = 'NEW' SET @nNewTaskQty = @nNewTaskQty - @nQTY_PD
      END
      
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD, @cDropID
   END

   -- Must fully offset
   IF @nOrgTaskQty <> 0 OR @nNewTaskQty <> 0 OR @nShortQTY <> 0
   BEGIN
      SET @nErrNo = 85406
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotFullyOffset
      GOTO RollBackTran
   END

   COMMIT TRAN rdtVFRPFCfmExtUpd -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdtVFRPFCfmExtUpd -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO