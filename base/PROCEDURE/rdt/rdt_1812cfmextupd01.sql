SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1812CfmExtUpd01                                 */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: 1. Split PickDetail base on UCC QTY                         */
/*          2. Stamp PickDetail.CaseID as UCCNo                         */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2018-01-05   Ung       1.0   WMS-3333 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1812CfmExtUpd01]
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

   DECLARE @nTranCount     INT
   DECLARE @bSuccess       INT
   DECLARE @cPickDetailKey NVARCHAR(10)
   DECLARE @cStorerKey     NVARCHAR(15)
   DECLARE @nUCCQTY        INT
   DECLARE @nBal_QTY       INT
   DECLARE @nPD_QTY        INT
   DECLARE @cUCCNo         NVARCHAR(20)
   DECLARE @cFromLOC       NVARCHAR(10)
   DECLARE @cDropID        NVARCHAR(20)
   DECLARE @cLOCType       NVARCHAR(10)
   DECLARE @curPD          CURSOR

   SET @nTranCount = @@TRANCOUNT

   -- Get task info
   SELECT
      @cStorerKey = StorerKey, 
      @cFromLOC = FromLOC, 
      @cDropID = DropID
   FROM TaskDetail WITH (NOLOCK)  
   WHERE TaskDetailKey = @cTaskdetailKey
   
   SELECT @cLOCType = LocationType FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC

   BEGIN TRAN
   SAVE TRAN rdt_1812CfmExtUpd01

   -- Split PickDetail (1 UCC 1 PickDetail) for BULK LOC task
   IF @cLOCType = 'OTHER'
   BEGIN
      -- Loop UCC for this TaskDetail
      DECLARE @curUCC CURSOR
      SET @curUCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT UCCNo, QTY
         FROM rdt.rdtFCPLog WITH (NOLOCK) 
         WHERE TaskDetailKey = @cTaskDetailKey
      OPEN @curUCC
      FETCH NEXT FROM @curUCC INTO @cUCCNo, @nUCCQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @nBal_QTY = @nUCCQTY
         
         -- Loop PickDetail to override DropID
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.PickDetailKey, QTY
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.TaskDetailKey = @cTaskDetailKey
               AND PD.QTY > 0
               AND PD.Status = '3'
               AND PD.DropID = @cDropID -- DropID stamped in standard confirm, to be override
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nPD_QTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Exact match
            IF @nPD_QTY = @nBal_QTY
            BEGIN
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  DropID = @cUCCNo, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE(), 
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 118401
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
      
               SET @nBal_QTY = 0 -- Reduce balance
                  BREAK
            END

            -- PickDetail have less
            ELSE IF @nPD_QTY < @nBal_QTY
            BEGIN
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  DropID = @cUCCNo, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE(), 
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 118402
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
      
               SET @nBal_QTY = @nBal_QTY - @nPD_QTY -- Reduce balance
            END

            -- PickDetail have more, need to split
            ELSE IF @nPD_QTY > @nBal_QTY
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
                  SET @nErrNo = 118403
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
                  Status, 
                  @nPD_QTY - @nBal_QTY, -- QTY
                  NULL, --TrafficCop
                  '1'   --OptimizeCop
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 118404
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail
                  GOTO RollBackTran
               END
      
               -- Change original PickDetail with exact QTY (with TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  QTY = @nBal_QTY,
                  DropID = @cUCCNo, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE(), 
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 118405
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END
      
               SET @nBal_QTY = 0 -- Reduce balance
                  BREAK
            END
            
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nPD_QTY
         END
            
         -- Check fully offset
         IF @nBal_QTY <> 0 
         BEGIN
            SET @nErrNo = 118406
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset error
            GOTO RollBackTran
         END

         FETCH NEXT FROM @curUCC INTO @cUCCNo, @nUCCQTY
      END
   END
   
   ELSE IF @cLOCType = 'PTL'
   BEGIN
      -- Get light of the task
      DECLARE @cStation  NVARCHAR( 20)
      DECLARE @cPosition NVARCHAR( 10)                  
      SELECT TOP 1 
          @cStation = DeviceID, 
          @cPosition = DevicePosition
      FROM DeviceProfile WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND LOC = @cFromLOC 
         AND LogicalName = 'FCP'

      -- Turn off light of task
      IF @@ROWCOUNT > 0
      BEGIN
         EXEC PTL.isp_PTL_TerminateModuleSingle
            @cStorerKey
           ,@nFunc
           ,@cStation
           ,@cPosition
           ,@bSuccess   OUTPUT
           ,@nErrNo     OUTPUT
           ,@cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END
   END
   
   -- Remove log, for close pallet move by SKU QTY (log is need until this point to split PickDetail by UCC)
   DELETE rdt.rdtFCPLog WHERE TaskDetailKey = @cTaskDetailKey  
   IF @@ERROR <> 0  
   BEGIN  
      SET @nErrNo = 118408  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelRPFLogFail  
      GOTO Quit
   END   
   
   COMMIT TRAN rdt_1812CfmExtUpd01 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1812CfmExtUpd01 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO