SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store procedure: rdt_1867Confirm01                                         */  
/* Copyright      : Maersk                                                    */  
/*                                                                            */  
/* Purpose: Confirm Pick                                                      */
/*                         For HuSQ                                           */
/* Called from: rdt_TM_Assist_ClusterPick_ConfirmPickV2                       */
/*                                                                            */
/* Date         Rev   Author    Purposes                                      */
/* 2024-10-10   1.0   JHU151    FCR-777 Created                               */
/* 2024-12-27   1.1.0 Dennis    FCR-1872 Remove Lot                           */ 
/* 2025-02-08   1.1.1 NLT013    FCR-1872 Fix some bugs                        */ 
/* 2025-02-08   1.1.2 NLT013    FCR-1872 Update PickDetailKey for PickSerialNo*/ 
/******************************************************************************/  
  
CREATE   PROC rdt.rdt_1867Confirm01 (  
    @nMobile         INT,  
    @nFunc           INT,  
    @cLangCode       NVARCHAR( 3),  
    @nStep           INT,  
    @nInputKey       INT,  
    @cFacility       NVARCHAR( 5),  
    @cStorerKey      NVARCHAR( 15),  
    @cType           NVARCHAR( 10), -- CONFIRM/SHORT/CLOSE  
    @cCartID         NVARCHAR( 10),
    @cGroupKey       NVARCHAR( 10),
    @cTaskDetailKey  NVARCHAR( 10),  
    @nQTY            INT,
    @cSerialNo       NVARCHAR( 30),
    @nSerialQTY      INT,
    @nBulkSNO        INT,
    @nBulkSNOQTY     INT,
    @nErrNo          INT           OUTPUT,  
    @cErrMsg         NVARCHAR(250) OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cSQL        NVARCHAR( MAX)  
   DECLARE @cSQLParam   NVARCHAR( MAX)  
   DECLARE @nTranCount  INT  
   


   DECLARE @cOrderKey            NVARCHAR( 10)  
   DECLARE @cLoadKey             NVARCHAR( 10)  
   DECLARE @cZone                NVARCHAR( 18)  
   DECLARE @cPickDetailKey       NVARCHAR( 18)  
   DECLARE @cPickConfirmStatus   NVARCHAR( 1)  
   DECLARE @nQTY_Bal             INT  
   DECLARE @nQTY_PD              INT 
   DECLARE @nTotalPkdSN          INT 
   DECLARE @bSuccess             INT  
   DECLARE @curCfmTask           CURSOR  
   DECLARE @curPD                CURSOR
   DECLARE @cCaseID              NVARCHAR( 20)
   DECLARE @cSKU                 NVARCHAR( 20)
   DECLARE @cPickSlipNo          NVARCHAR( 10)
   DECLARE @cLOC                 NVARCHAR( 10)
   DECLARE @cTaskKey             NVARCHAR( 10)
   DECLARE @cDropID              NVARCHAR( 20)
   DECLARE @cUserName            NVARCHAR( 18)
   DECLARE @cFromLoc             NVARCHAR( 10)
   DECLARE @cNewPickDetailKey    NVARCHAR( 10)
   DECLARE @cNewTaskDetailKey    NVARCHAR( 10)
   DECLARE @cUserDefine10        NVARCHAR( 10)
   DECLARE @cMethod              NVARCHAR( 1)
   DECLARE @nPickedQty           INT
   DECLARE @nPickDetailQty       INT
   DECLARE @nRowCount            INT

   SELECT 
      @cUserName = UserName 
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   SELECT 
      @cSKU = SKU, 
      @cCaseID = CaseID,
      @cFromLoc = FromLoc
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey
         
   INSERT INTO TRACEINFO (TraceName, TimeIn, Col1, Col2, Col3, Col4, Col5) VALUES ('1867', GETDATE(), @cUserName, @cSKU, @cCaseID, @cLOC, @cTaskDetailKey)
   SET @cOrderKey = ''  
   SET @cLoadKey = ''  
   SET @cZone = ''  
     
   -- Get storer config  
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
   IF @cPickConfirmStatus = '0'  
      SET @cPickConfirmStatus = '5'  
  
   -- For calculation  
   SET @nQTY_Bal = @nQTY  

   -- Handling transaction  
   SET @nTranCount = @@TRANCOUNT

   IF @cSerialNo <> ''
   BEGIN
      BEGIN TRAN  -- Begin our own transaction  
      SAVE TRAN ConfirmPick -- For rollback or commit only our own transaction 
 
      SELECT TOP 1 
         @cTaskDetailKey = TD.TaskDetailKey, 
         @cSKU = TD.Sku, 
         @cCaseID = TD.Caseid, 
         @cLOC = TD.FromLoc, 
         @cDropID = TD.DropID, 
         @cOrderKey = PD.OrderKey,
         @cPickDetailKey = PD.PickDetailkey,
         @nQTY_PD = PD.Qty
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( TD.TaskDetailKey = PD.TaskDetailKey)
      WHERE TD.Storerkey = @cStorerKey
      AND   TD.TaskType = 'ASTCPK'
      AND   TD.[Status] = '3'
      AND   TD.Groupkey = @cGroupKey
      AND   TD.UserKey = @cUserName
      AND   TD.DeviceID = @cCartID
      AND   TD.Sku = @cSKU
      AND   TD.Caseid = @cCaseID
      AND   TD.FromLoc = @cFromLoc
      AND   PD.[Status] < @cPickConfirmStatus
      AND   PD.QTY > 0 
      AND   PD.Status <> '4'
      AND   TD.TaskDetailKey = @cTaskDetailKey
      ORDER BY 1

      -- Check pick task
      IF @cPickDetailKey = ''
      BEGIN
         SET @nErrNo = 227251
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No pick task
         GOTO RollBackTran
      END

      -- Split PickDetail
      IF @nQTY_PD > @nSerialQTY
      BEGIN
         -- Get new PickDetailkey
         EXECUTE dbo.nspg_GetKey
            'PICKDETAILKEY',
            10 ,
            @cNewPickDetailKey OUTPUT,
            @bSuccess          OUTPUT,
            @nErrNo            OUTPUT,
            @cErrMsg           OUTPUT
         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = 227251
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
            GOTO RollBackTran
         END

         -- Create new a PickDetail to hold the balance
         INSERT INTO dbo.PickDetail (
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
            UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
            ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
            EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
            PickDetailKey,
            Status,
            QTY,
            TrafficCop,
            OptimizeCop,
            Channel_ID )      --(cc01)
         SELECT
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
            UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
            CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
            EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
            @cNewPickDetailKey,
            Status,
            @nQTY_PD - @nSerialQTY, -- QTY
            NULL, -- TrafficCop
            '1',   -- OptimizeCop
            Channel_ID --(cc01)
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 227253
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
            GOTO RollBackTran
         END

         -- Split RefKeyLookup
         IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
         BEGIN
            -- Insert into
            INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
            SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
            FROM RefKeyLookup WITH (NOLOCK)
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 227254
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
               GOTO RollBackTran
            END
         END

         -- Change orginal PickDetail with exact QTY (with TrafficCop)
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            QTY = @nSerialQTY,
            EditDate = GETDATE(),
            EditWho  = SUSER_SNAME(),
            Trafficcop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 204808
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
      END


      -- Confirm PickDetail
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET
         Status = @cPickConfirmStatus,
         DropID = @cDropID,
         EditDate = GETDATE(),
         EditWho  = SUSER_SNAME()
      WHERE PickDetailKey = @cPickDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 227255
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
         GOTO RollBackTran
      END
      
      -- Insert PickSerialNo
      INSERT INTO PickSerialNo (PickDetailKey, StorerKey, SKU, SerialNo, QTY)
      VALUES (@cPickDetailKey, @cStorerKey, @cSKU, @cSerialNo, @nSerialQTY)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 227256
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RDSNo Fail
         GOTO RollBackTran
      END
      
      IF EXISTS(SELECT 1 FROM dbo.SerialNo WITH(NOLOCK)
                           WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND SerialNo = @cSerialNo)
      BEGIN
         -- Posting to serial no
         UPDATE dbo.SerialNo SET
            Status = '5', 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME(), 
            TrafficCop = NULL
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND SerialNo = @cSerialNo
         IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
         BEGIN
            SET @nErrNo = 227257
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD SNO Fail
            GOTO RollBackTran
         END
      END

      IF NOT EXISTS(SELECT 1 FROM PickDetail WITH(NOLOCK)
                     WHERE TaskdetailKey = @cTaskDetailKey
                     AND status < '5')
      BEGIN
         UPDATE dbo.TaskDetail SET 
               [Status] = '5',
               EditDate = GETDATE(),
               EditWho = @cUserName
         WHERE TaskDetailKey = @cTaskDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 227270
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail
            GOTO RollBackTran
         END
      END
   END
   ELSE-- non serial no
   BEGIN
      
      BEGIN TRAN  -- Begin our own transaction  
      SAVE TRAN ConfirmPick -- For rollback or commit only our own transaction  
      
      SET @curCfmTask = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT TD.TaskDetailKey, TD.Sku, TD.Caseid, TD.FromLoc, TD.DropID, PD.OrderKey
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( TD.TaskDetailKey = PD.TaskDetailKey)
      WHERE TD.Storerkey = @cStorerKey
      AND   TD.TaskType = 'ASTCPK'
      AND   TD.[Status] = '3'
      AND   TD.Groupkey = @cGroupKey
      AND   TD.UserKey = @cUserName
      AND   TD.DeviceID = @cCartID
      AND   TD.Sku = @cSKU
      AND   TD.Caseid = @cCaseID
      AND   TD.FromLoc = @cFromLoc
      AND   PD.[Status] < @cPickConfirmStatus
      AND   PD.QTY > 0 
      AND   PD.Status <> '4'
      AND   TD.TaskDetailKey = @cTaskDetailKey
      ORDER BY 1
      OPEN @curCfmTask
      FETCH NEXT FROM @curCfmTask INTO @cTaskDetailKey, @cSKU, @cCaseID, @cLOC, @cDropID, @cOrderKey
      WHILE @@FETCH_STATUS = 0  
      BEGIN
         IF ISNULL( @cOrderKey, '') = ''
         BEGIN  
            SET @nErrNo = 227258  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Pick Not Found  
            GOTO RollBackTran  
         END 

         SELECT @cLoadKey = LoadKey,
                @cUserDefine10 = UserDefine10
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         SELECT @cPickSlipNo = PickheaderKey
         FROM dbo.PICKHEADER WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey 

         IF EXISTS (
                  SELECT  1  
                  FROM CodeLKUP WITH(NOLOCK) 
                  WHERE LISTNAME = 'HUSQPKTYPE' 
                  AND Code2 = '' 
                  AND StorerKey = @cStorerKey
                  AND short = @cUserDefine10)
         Begin
            SET @cMethod = '3'
         END

         IF ISNULL( @cLoadKey, '') = ''
         BEGIN  
            SET @nErrNo = 227259  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No LoadKey  
            GOTO RollBackTran  
         END 

         IF ISNULL( @cPickSlipNo, '') = ''
            SELECT @cPickSlipNo = PickheaderKey FROM dbo.PICKHEADER WITH (NOLOCK) WHERE LoadKey = @cLoadKey

         IF ISNULL( @cPickSlipNo, '') = ''
            SELECT @cPickSlipNo = PickheaderKey FROM dbo.PICKHEADER WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey

         IF ISNULL( @cPickSlipNo, '') = ''
         BEGIN  
            SET @nErrNo = 227260  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Pickslip  
            GOTO RollBackTran  
         END 

         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
         SELECT PD.PickDetailKey, PD.QTY 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) 
         WHERE PD.LOC = @cLOC 
         AND   PD.SKU = @cSKU 
         AND   PD.CaseID = @cCaseID
         AND   PD.QTY > 0 
         AND   PD.Status <> '4' 
         AND   PD.Status < @cPickConfirmStatus 
         AND   PD.TaskDetailKey = @cTaskDetailKey
         
         OPEN @curPD

         -- Loop PickDetail  
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD  
         WHILE @@FETCH_STATUS = 0  
         BEGIN

            -- Exact match  
            IF @nQTY_PD = @nQTY_Bal  
            BEGIN  
               -- Confirm PickDetail  
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
                  Status = @cPickConfirmStatus, 
                  DropID = @cDropID,
                  EditDate = GETDATE(),  
                  EditWho  = SUSER_SNAME()  
               WHERE PickDetailKey = @cPickDetailKey  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 227261  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                  GOTO RollBackTran  
               END  
   
               SET @nQTY_Bal = 0 -- Reduce balance  
            END  
   
            -- PickDetail have less  
            ELSE IF @nQTY_PD < @nQTY_Bal  
            BEGIN  
               -- Confirm PickDetail  
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
                  Status = @cPickConfirmStatus,
                  DropID = @cDropID,
                  EditDate = GETDATE(),  
                  EditWho  = SUSER_SNAME()  
               WHERE PickDetailKey = @cPickDetailKey  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 227262  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                  GOTO RollBackTran  
               END  
   
               SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance  
            END  
   
            -- PickDetail have more  
            ELSE IF @nQTY_PD > @nQTY_Bal  
            BEGIN  
               -- Don't need to split  
               IF @nQTY_Bal = 0  
               BEGIN  
                  -- Short pick  
                  IF @cType = 'SHORT' -- Don't need to split  
                  BEGIN  
                     -- Confirm PickDetail  
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
                        Status = '4',  
                        EditDate = GETDATE(),  
                        EditWho  = SUSER_SNAME(),  
                        TrafficCop = NULL  
                     WHERE PickDetailKey = @cPickDetailKey  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 171955  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                        GOTO RollBackTran  
                     END  

                     SELECT @nPickedQty = SUM(Qty) 
                     FROM dbo.PickDetail WITH(NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND TaskDetailKey = @cTaskDetailKey
                        AND Status = @cPickConfirmStatus

                     SET @nPickedQty = ISNULL(@nPickedQty, 0)
                     
                     UPDATE dbo.TaskDetail SET
                        SystemQty = Qty, 
                        Qty = @nPickedQty,  
                        EditDate = GETDATE(),  
                        EditWho  = SUSER_SNAME()
                     WHERE TaskDetailKey = @cTaskDetailKey
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 227263  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                        GOTO RollBackTran  
                     End

                     -- mutiple pickdetail in same taskdetailkey
                     IF EXISTS(SELECT 1 FROM PickDetail PD WITH(NOLOCK)
                                 WHERE storerkey = @cStorerkey
                                 AND TaskDetailKey = @cTaskDetailKey
                                 AND status <> '4')
                     BEGIN                        
                        EXECUTE dbo.nspg_getkey
                        'TaskDetailKey'
                        , 10
                        , @cNewTaskDetailKey OUTPUT
                        , @bSuccess OUTPUT
                        , @nErrNo     --OUTPUT Commented by NLT013, it overrides the old error no, if the error was not 0, but no error happens while executing this SP, error no will be updated as 0
                        , @cErrMsg OUTPUT

                        IF NOT @bSuccess = 1
                        BEGIN
                           SET @nErrNo = 227271
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKeyFailed(rdt_1867Confirm01)
                           GOTO RollBackTran 
                        END

                        SELECT @nPickDetailQty = Qty
                        FROM dbo.PickDetail WITH (NOLOCK)
                        WHERE PickDetailKey = @cPickDetailKey

                        INSERT INTO dbo.TaskDetail
                        (TaskDetailKey,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,QTY,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc
                        ,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide
                        ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey
                        ,Message01,Message02,Message03,RefTaskKey,LoadKey,AreaKey,DropID, SystemQty,Groupkey,TrafficCop)
                        SELECT  TOP 1
                        @cNewTaskDetailKey,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,@nPickDetailQty,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc
                        ,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide
                        ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey
                        ,Message01,Message02,Message03,RefTaskKey,LoadKey,AreaKey,DropID, @nPickDetailQty,GroupKey,'9'
                        FROM dbo.TaskDetail WITH (NOLOCK)
                        WHERE Taskdetailkey = @cTaskDetailKey
                        AND Storerkey = @cStorerkey
                        
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 227272
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTaskFailed
                           GOTO RollBackTran 
                        END

                        UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
                           EditDate = GETDATE(),  
                           EditWho  = SUSER_SNAME(),  
                           taskdetailkey = @cNewTaskDetailKey
                        WHERE PickDetailKey = @cPickDetailKey

                        IF @@ERROR <> 0  
                        BEGIN  
                           SET @nErrNo = 171955  
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                           GOTO RollBackTran  
                        END
                        
                        UPDATE dbo.TaskDetail SET                           
                           RefTaskKey = @cNewTaskDetailKey,
                           EditDate = GETDATE(),  
                           EditWho  = SUSER_SNAME()
                        WHERE TaskDetailKey = @cTaskDetailKey
                        IF @@ERROR <> 0  
                        BEGIN  
                           SET @nErrNo = 227263  
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                           GOTO RollBackTran  
                        End
                     END



                  END  
               END  
               ELSE  
               BEGIN -- Have balance, need to split                                         
                  
                  EXECUTE dbo.nspg_GetKey  
                     'PICKDETAILKEY',  
                     10 ,  
                     @cNewPickDetailKey OUTPUT,  
                     @bSuccess          OUTPUT,  
                     @nErrNo            OUTPUT,  
                     @cErrMsg           OUTPUT  
                  IF @bSuccess <> 1  
                  BEGIN  
                     SET @nErrNo = 227264  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
                     GOTO RollBackTran  
                  END  

                  -- Create new a PickDetail to hold the balance  
                  INSERT INTO dbo.PickDetail (  
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,  
                     UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,  
                     ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,  
                     EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,  
                     PickDetailKey,  
                     Status,  
                     QTY,  
                     TrafficCop,  
                     OptimizeCop,
                     Channel_ID)  
                  SELECT  
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,  
                     UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,  
                     CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,  
                     EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,  
                     @cNewPickDetailKey,  
                     Status,  
                     @nQTY_PD - @nQTY_Bal, -- QTY  
                     NULL, -- TrafficCop  
                     '1',  -- OptimizeCop  
                     Channel_ID
                  FROM dbo.PickDetail WITH (NOLOCK)  
                  WHERE PickDetailKey = @cPickDetailKey  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 227265  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail  
                     GOTO RollBackTran  
                  END  
   
                  -- Split RefKeyLookup  
                  IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)  
                  BEGIN  
                     -- Insert into  
                     INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)  
                     SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey  
                     FROM RefKeyLookup WITH (NOLOCK)  
                     WHERE PickDetailKey = @cPickDetailKey  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 227266  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail  
                        GOTO RollBackTran  
                     END  
                  END  
   
                  -- Change orginal PickDetail with exact QTY (with TrafficCop)  
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
                     QTY = @nQTY_Bal,  
                     EditDate = GETDATE(),  
                     EditWho  = SUSER_SNAME(),  
                     Trafficcop = NULL  
                  WHERE PickDetailKey = @cPickDetailKey  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 171959  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                     GOTO RollBackTran  
                  END  
   
                  -- Confirm orginal PickDetail with exact QTY  
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
                     Status = @cPickConfirmStatus,  
                     DropID = @cDropID,
                     EditDate = GETDATE(),  
                     EditWho  = SUSER_SNAME()  
                  WHERE PickDetailKey = @cPickDetailKey  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 227267  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                     GOTO RollBackTran  
                  END  

                  --Commented by NLT013-01
                  IF @cType = 'SHORT' AND @nQTY_Bal  > 0
                  BEGIN
                     EXECUTE dbo.nspg_getkey
                        'TaskDetailKey'
                        , 10
                        , @cNewTaskDetailKey OUTPUT
                        , @bSuccess OUTPUT
                        , @nErrNo     --OUTPUT Commented by NLT013, it overrides the old error no, if the error was not 0, but no error happens while executing this SP, error no will be updated as 0
                        , @cErrMsg OUTPUT

                     IF NOT @bSuccess = 1
                     BEGIN
                        SET @nErrNo = 227271
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKeyFailed(rdt_1867Confirm01)
                        GOTO RollBackTran 
                     END

                     SELECT @nPickedQty = SUM(Qty) 
                     FROM dbo.PickDetail WITH(NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND TaskDetailKey = @cTaskDetailKey
                     AND Status = @cPickConfirmStatus

                     SET @nPickedQty = ISNULL(@nPickedQty, 0)

                     INSERT INTO dbo.TaskDetail
                     (TaskDetailKey,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,QTY,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc
                     ,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide
                     ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey
                     ,Message01,Message02,Message03,RefTaskKey,LoadKey,AreaKey,DropID, SystemQty,Groupkey,DeviceID)
                     SELECT  TOP 1
                     @cNewTaskDetailKey,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,@nQTY_PD - @nQTY_Bal,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc
                     ,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide
                     ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey
                     ,Message01,Message02,Message03,RefTaskKey,LoadKey,AreaKey,DropID, @nQTY_PD - @nQTY_Bal,GroupKey,DeviceID
                     FROM dbo.TaskDetail WITH (NOLOCK)
                     WHERE Taskdetailkey = @cTaskDetailKey
                     AND Storerkey = @cStorerkey
                     
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 227272
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsTaskFailed
                        GOTO RollBackTran 
                     END
                  END
                  --Commented by NLT013-01
                  
                  -- Short pick
                  IF @cType = 'SHORT'
                  BEGIN                                       
                     -- Confirm PickDetail
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                        Status = '4',
                        EditDate = GETDATE(), 
                        EditWho  = SUSER_SNAME(),
                        TrafficCop = NULL,
                        TaskDetailKey = @cNewTaskDetailKey
                     WHERE PickDetailKey = @cNewPickDetailKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 227268
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                        GOTO RollBackTran
                     END

                     SELECT @nPickedQty = SUM(Qty) 
                     FROM dbo.PickDetail WITH(NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND TaskDetailKey = @cTaskDetailKey
                        AND Status = @cPickConfirmStatus

                     SET @nPickedQty = ISNULL(@nPickedQty, 0)

                     UPDATE dbo.TaskDetail SET
                        SystemQty = @nQTY_Bal, 
                        Qty = @nPickedQty,  
                        EditDate = GETDATE(),  
                        EditWho  = SUSER_SNAME(),
                        RefTaskKey = @cNewTaskDetailKey
                     WHERE TaskDetailKey = @cTaskDetailKey
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 227269  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                        GOTO RollBackTran  
                     END  
                  END

                  --Commented by NLT013-02
                  -- ELSE
                  -- BEGIN
                  --    UPDATE dbo.TaskDetail SET
                  --       SystemQty = Qty, 
                  --       Qty = @nPickedQty,  
                  --       EditDate = GETDATE(),  
                  --       EditWho  = SUSER_SNAME()
                  --    WHERE TaskDetailKey = @cTaskDetailKey
                  --    IF @@ERROR <> 0  
                  --    BEGIN  
                  --       SET @nErrNo = 227263  
                  --       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                  --       GOTO RollBackTran  
                  --    End
                     
                  --    -- Confirm PickDetail
                  --    UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                  --       EditDate = GETDATE(), 
                  --       EditWho  = SUSER_SNAME(),
                  --       TrafficCop = NULL,
                  --       TaskDetailKey = @cNewTaskDetailKey
                  --    WHERE PickDetailKey = @cNewPickDetailKey
                  --    IF @@ERROR <> 0
                  --    BEGIN
                  --       SET @nErrNo = 227268
                  --       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                  --       GOTO RollBackTran
                  --    END
                  -- END
                  --Commented by NLT013-02

                  SET @nQTY_Bal = 0 -- Reduce balance  
               END  
            END  

            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD  
         END  
         CLOSE @curPD
         DEALLOCATE @curPD
         
         EXEC RDT.rdt_STD_EventLog  
            @cActionType   = '3', -- Picking  
            @cUserID       = @cUserName,  
            @nMobileNo     = @nMobile,  
            @nFunctionID   = @nFunc,  
            @cFacility     = @cFacility,  
            @cStorerKey    = @cStorerKey,  
            @cLocation     = @cLOC,  
            @cSKU          = @cSKU,  
            @nQTY          = @nQTY,  
            @cTaskDetailKey= @cTaskDetailKey,
            @cRefNo1       = @cType,  
            @cPickSlipNo   = @cPickSlipNo

         FETCH NEXT FROM @curCfmTask INTO @cTaskDetailKey, @cSKU, @cCaseID, @cLOC, @cDropID, @cOrderKey
      END

      UPDATE dbo.TaskDetail SET 
         [Status] = '5',
         EditDate = GETDATE(),
         EditWho = @cUserName
      WHERE TaskDetailKey = @cTaskDetailKey
      AND NOT EXISTS(SELECT 1 FROM Pickdetail PD WITH(NOLOCK)
                        WHERE Taskdetail.taskdetailkey = PD.taskdetailkey
                         AND PD.status = '0')
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 227270
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail
         GOTO RollBackTran
      END  


   END-- non serial no

   --Update PickDetailKey for PickSerialNo
   SELECT @nRowCount = COUNT(1)
   FROM dbo.PickSerialNo PSN WITH(NOLOCK)
   INNER JOIN dbo.PickDetail PD WITH(NOLOCK)
      ON PSN.PickDetailKey = PD.PickDetailKey
   INNER JOIN dbo.TaskDetail TD WITH(NOLOCK)
      ON PD.StorerKey = TD.StorerKey
      AND PD.TaskDetailKey = TD.TaskDetailKey
   WHERE TD.StorerKey = @cStorerKey
      AND TD.TaskDetailKey = @cTaskDetailKey

   IF @nRowCount > 0 AND @nQTY > 0
   BEGIN
      DECLARE
         @nLoopIndex          INT,
         @nUpdateIDStart      INT,
         @nUpdateIDRange      INT

      DECLARE @tPickDetails TABLE
      (
         id                   INT IDENTITY(1,1),
         PickDetailKey        NVARCHAR(18),
         Qty                  INT
      )

      DECLARE @tPickSerialNo TABLE
      (
         id                   INT IDENTITY(1,1),
         PickSerialNoKey      BIGINT
      )

      INSERT INTO @tPickDetails( PickDetailKey, Qty)
      SELECT PickDetailKey, Qty FROM dbo.PICKDETAIL WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND TaskDetailKey = @cTaskDetailKey

      INSERT INTO @tPickSerialNo( PickSerialNoKey)
      SELECT PickSerialNoKey 
      FROM dbo.PickSerialNo PSN WITH(NOLOCK)
      INNER JOIN @tPickDetails PD ON PSN.PickDetailKey = PD.PickDetailKey

      SET @nLoopIndex = -1
      SET @nUpdateIDStart = 1

      WHILE 1 = 1
      BEGIN
         SELECT TOP 1
            @cPickDetailKey = PickDetailKey,
            @nQty = Qty,
            @nLoopIndex = id
         FROM @tPickDetails
         WHERE id > @nLoopIndex

         IF @@ROWCOUNT = 0
            BREAK

         SET @nUpdateIDRange = @nQty

         UPDATE dbo.PickSerialNo WITH(ROWLOCK)
         SET PickDetailKey = @cPickDetailKey
         WHERE EXISTS(SELECT 1 FROM @tPickSerialNo PSN WHERE PSN.PickSerialNoKey = PickSerialNo.PickSerialNoKey AND PSN.id BETWEEN @nUpdateIDStart AND @nUpdateIDStart + @nUpdateIDRange - 1)

         SET @nUpdateIDStart = @nUpdateIDStart + @nUpdateIDRange
      END
   END

   GOTO Quit
  
RollBackTran:  
   ROLLBACK TRAN ConfirmPick -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  

Fail:
END  

GO