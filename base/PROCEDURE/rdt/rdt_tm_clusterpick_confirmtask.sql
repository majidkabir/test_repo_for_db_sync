SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/    
/* Store procedure: rdt_TM_ClusterPick_ConfirmTask                            */    
/* Copyright      : LF Logistics                                              */    
/*                                                                            */    
/* Date       Rev  Author     Purposes                                        */    
/* 2020-06-18 1.0  James      WMS-12055 Created                               */    
/******************************************************************************/    
    
CREATE PROC [RDT].[rdt_TM_ClusterPick_ConfirmTask] (    
    @nMobile         INT,    
    @nFunc           INT,    
    @cLangCode       NVARCHAR( 3),    
    @nStep           INT,    
    @nInputKey       INT,    
    @cFacility       NVARCHAR( 5),    
    @cStorerKey      NVARCHAR( 15),    
    @cType           NVARCHAR( 10), -- CONFIRM/SHORT/CLOSE    
    @cTaskDetailKey  NVARCHAR( 10),    
    @nQTY            INT,    
    @tConfirm        VARIABLETABLE READONLY,  
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
   DECLARE @cConfirmSP  NVARCHAR( 20)    
    
   -- Get storer config    
   SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)    
   IF @cConfirmSP = '0'    
      SET @cConfirmSP = ''    
    
   /***********************************************************************************************    
                                              Custom confirm    
   ***********************************************************************************************/    
   -- Check confirm SP blank    
   IF @cConfirmSP <> ''    
   BEGIN    
      -- Confirm SP    
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +    
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType, ' +    
         ' @cTaskDetailKey, @nQTY, ' +     
         ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
      SET @cSQLParam =    
         ' @nMobile        INT,           ' +    
         ' @nFunc          INT,           ' +    
         ' @cLangCode      NVARCHAR( 3),  ' +    
         ' @nStep          INT,           ' +    
         ' @nInputKey      INT,           ' +    
         ' @cFacility      NVARCHAR( 5) , ' +    
         ' @cStorerKey     NVARCHAR( 15), ' +    
         ' @cType          NVARCHAR( 10), ' +    
         ' @cTaskDetailKey NVARCHAR( 10), ' +    
         ' @nQTY           INT,           ' +    
         ' @nErrNo         INT           OUTPUT, ' +    
         ' @cErrMsg        NVARCHAR(250) OUTPUT  '    
    
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType,    
         @cTaskDetailKey, @nQTY,  
         @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
      GOTO Quit    
   END    
    
   /***********************************************************************************************    
                                              Standard confirm    
   ***********************************************************************************************/    
   DECLARE @cOrderKey      NVARCHAR( 10)    
   DECLARE @cLoadKey       NVARCHAR( 10)    
   DECLARE @cZone          NVARCHAR( 18)    
   DECLARE @cPickDetailKey NVARCHAR( 18)    
   DECLARE @cPickConfirmStatus NVARCHAR( 1)    
   DECLARE @nQTY_Bal       INT    
   DECLARE @nQTY_PD        INT    
   DECLARE @bSuccess       INT    
   DECLARE @curPD          CURSOR    
   DECLARE @cCaseID        NVARCHAR( 20)  
   DECLARE @cSKU           NVARCHAR( 20)  
   DECLARE @cPickSlipNo    NVARCHAR( 10)  
   DECLARE @cLOC           NVARCHAR( 10)  
     
   SET @cOrderKey = ''    
   SET @cLoadKey = ''    
   SET @cZone = ''    
    
   -- Get storer config    
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)    
   IF @cPickConfirmStatus = '0'    
      SET @cPickConfirmStatus = '5'    
    
   -- For calculation    
   SET @nQTY_Bal = @nQTY    
     
   SELECT @cSKU = SKU,  
          @cCaseID = Caseid,  
          @cLOC = FromLoc  
   FROM dbo.TaskDetail WITH (NOLOCK)  
   WHERE TaskDetailKey = @cTaskDetailKey  
     
   SELECT TOP 1 @cOrderKey = OrderKey  
   FROM dbo.PICKDETAIL WITH (NOLOCK)  
   WHERE Storerkey = @cStorerKey  
   AND   CaseID = @cCaseID  
   AND   Sku = @cSKU  
   AND   Loc = @cLOC  
   AND   [Status] < @cPickConfirmStatus  
   ORDER BY 1  
     
   IF @@ROWCOUNT = 0  
   BEGIN    
      SET @nErrNo = 149001    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Pick Not Found    
      GOTO Fail    
   END   
           
   SELECT @cLoadKey = LoadKey  
   FROM dbo.ORDERS WITH (NOLOCK)  
   WHERE OrderKey = @cOrderKey  
  
   SELECT @cPickSlipNo = PickheaderKey  
   FROM dbo.PICKHEADER WITH (NOLOCK)   
   WHERE OrderKey = @cOrderKey   
     
   IF ISNULL( @cPickSlipNo, '') = ''  
      SELECT @cPickSlipNo = PickheaderKey FROM dbo.PICKHEADER WITH (NOLOCK) WHERE LoadKey = @cLoadKey  
  
   IF ISNULL( @cPickSlipNo, '') = ''  
      SELECT @cPickSlipNo = PickheaderKey FROM dbo.PICKHEADER WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey  
  
   IF ISNULL( @cPickSlipNo, '') = ''  
   BEGIN    
      SET @nErrNo = 149002    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Pickslip    
      GOTO Fail    
   END   
  
   -- Get PickHeader info    
   SELECT @cZone = Zone    
   FROM dbo.PickHeader WITH (NOLOCK)    
   WHERE PickHeaderKey = @cPickSlipNo    
   --DELETE FROM TraceInfo WHERE TraceName = '123'  
   --INSERT INTO TRACEINFO (TRACENAME, TIMEIN, Col1, Col2, Col3) VALUES ('123', GETDATE(), @cOrderKey, @cPickSlipNo, @cZone)  
   --INSERT INTO TRACEINFO (TRACENAME, TIMEIN, Col1, Col2, Col3, Col4, Col5) VALUES ('123', GETDATE(), @cStorerKey, @cCaseID, @cSKU, @cPickConfirmStatus, @cTaskDetailKey)  
   -- Handling transaction    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN  -- Begin our own transaction    
   SAVE TRAN rdt_TM_ClusterPick_ConfirmTask -- For rollback or commit only our own transaction    
  
   -- Cross dock PickSlip    
   IF @cZone IN ('XD', 'LB', 'LP')    
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT PD.PickDetailKey, PD.QTY   
      FROM dbo.RefKeyLookup RKL WITH (NOLOCK)   
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)   
      WHERE RKL.PickSlipNo = @cPickSlipNo   
      AND   PD.LOC = @cLOC   
      AND   PD.SKU = @cSKU   
      AND   PD.QTY > 0   
      AND   PD.Status <> '4'  
      AND   PD.Status < @cPickConfirmStatus   
    
   -- Discrete PickSlip    
   ELSE IF @cOrderKey <> ''    
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
      SELECT PD.PickDetailKey, PD.QTY   
      FROM dbo.PickDetail PD WITH (NOLOCK)   
      JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)   
      WHERE PD.OrderKey = @cOrderKey   
      AND   PD.LOC = @cLOC   
      AND   PD.SKU = @cSKU   
      AND   PD.QTY > 0   
      AND   PD.Status <> '4'   
      AND   PD.Status < @cPickConfirmStatus   
    
   -- Conso PickSlip    
   ELSE IF @cLoadKey <> ''    
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
      SELECT PD.PickDetailKey, PD.QTY   
      FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)   
      JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)   
      JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)   
      WHERE LPD.LoadKey = @cLoadKey   
      AND   PD.LOC = @cLOC   
      AND   PD.SKU = @cSKU   
      AND   PD.QTY > 0   
      AND   PD.Status <> '4'   
      AND   PD.Status < @cPickConfirmStatus   
   
   -- Custom PickSlip    
   ELSE    
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
      SELECT PD.PickDetailKey, PD.QTY   
      FROM dbo.PickDetail PD WITH (NOLOCK)   
      JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)   
      WHERE PD.PickSlipNo = @cPickSlipNo   
      AND   PD.LOC = @cLOC   
      AND   PD.SKU = @cSKU   
      AND   PD.QTY > 0   
      AND   PD.Status <> '4'   
      AND   PD.Status < @cPickConfirmStatus   
   
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
            EditDate = GETDATE(),    
            EditWho  = SUSER_SNAME()    
         WHERE PickDetailKey = @cPickDetailKey    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 149003    
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
            EditDate = GETDATE(),    
            EditWho  = SUSER_SNAME()    
         WHERE PickDetailKey = @cPickDetailKey    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 149004    
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
                  SET @nErrNo = 149005    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
                  GOTO RollBackTran    
               END    
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
               SET @nErrNo = 149006    
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
               OptimizeCop)    
            SELECT    
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,    
        UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,    
               CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,    
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,    
               @cNewPickDetailKey,    
               Status,    
               @nQTY_PD - @nQTY_Bal, -- QTY    
               NULL, -- TrafficCop    
               '1'   -- OptimizeCop    
            FROM dbo.PickDetail WITH (NOLOCK)    
            WHERE PickDetailKey = @cPickDetailKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 149007    
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
                  SET @nErrNo = 149008    
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
               SET @nErrNo = 149009    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
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
               SET @nErrNo = 149010    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
               GOTO RollBackTran    
            END    
              
            -- Short pick  
            IF @cType = 'SHORT'  
            BEGIN  
               -- Confirm PickDetail  
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
                  Status = '4',  
                  EditDate = GETDATE(),   
                  EditWho  = SUSER_SNAME(),  
                  TrafficCop = NULL  
               WHERE PickDetailKey = @cNewPickDetailKey  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 149011  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                  GOTO RollBackTran  
               END  
            END  
    
            SET @nQTY_Bal = 0 -- Reduce balance    
         END    
      END    
    
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD    
   END    
    
   COMMIT TRAN rdt_TM_ClusterPick_ConfirmTask    
    
   DECLARE @cUserName NVARCHAR( 18)    
   SET @cUserName = SUSER_SNAME()    
    
   EXEC RDT.rdt_STD_EventLog    
      @cActionType   = '3', -- Picking    
      @cUserID       = @cUserName,    
      @nMobileNo     = @nMobile,    
      @nFunctionID   = @nFunc,    
      @cFacility     = @cFacility,    
      @cStorerKey    = @cStorerKey,    
      @cLocation   = @cLOC,    
      @cSKU          = @cSKU,    
      @nQTY          = @nQTY,    
      @cTaskDetailKey= @cTaskDetailKey,  
      @cRefNo1       = @cType,    
      @cPickSlipNo   = @cPickSlipNo  
    
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN rdt_TM_ClusterPick_ConfirmTask -- Only rollback change made here    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
  
Fail:  
END    

GO