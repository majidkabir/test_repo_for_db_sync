SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store procedure: rdt_TM_ClusterPick_ConfirmPick                            */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Date       Rev  Author     Purposes                                        */  
/* 2020-06-18 1.0  James      WMS-12055 Created                               */  
/* 2021-09-07 1.1  James      WMS-17429 Add AssignPackLabelToOrdCfg (james01) */
/******************************************************************************/  
  
CREATE PROC [RDT].[rdt_TM_ClusterPick_ConfirmPick] (  
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
   DECLARE @cUserName NVARCHAR( 18)
   
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
   DECLARE @cTaskKey       NVARCHAR( 10)
   DECLARE @cGroupKey      NVARCHAR( 10)
   DECLARE @cCartID        NVARCHAR( 20)
   DECLARE @nPackQTY       INT = 0 
   DECLARE @nPickQTY       INT = 0 
   DECLARE @cPackConfirm   NVARCHAR(1) = '' 

   SET @cOrderKey = ''  
   SET @cLoadKey = ''  
   SET @cZone = ''  
   SET @cUserName = SUSER_SNAME()
     
   -- Get storer config  
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
   IF @cPickConfirmStatus = '0'  
      SET @cPickConfirmStatus = '5'  
  
   -- For calculation  
   SET @nQTY_Bal = @nQTY  
   
   SELECT @cSKU = SKU,
          @cCaseID = Caseid,
          @cLOC = FromLoc,
          @cGroupKey = Groupkey,
          @cCartID = DeviceID
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
   
   IF ISNULL( @cOrderKey, '') = ''
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

   -- Handling transaction  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_TM_ClusterPick_ConfirmPick -- For rollback or commit only our own transaction  

   -- Cross dock PickSlip  
   IF @cZone IN ('XD', 'LB', 'LP')  
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.PickDetailKey, PD.QTY 
      FROM dbo.RefKeyLookup RKL WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) 
      WHERE RKL.PickSlipNo = @cPickSlipNo 
      AND   PD.LOC = @cLOC 
      AND   PD.SKU = @cSKU 
      AND   PD.CaseID = @cCaseID
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
      AND   PD.CaseID = @cCaseID
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
      AND   PD.CaseID = @cCaseID
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
      AND   PD.CaseID = @cCaseID
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

   DECLARE @curUpdTask CURSOR
   SET @curUpdTask = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT TaskDetailKey
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE Storerkey = @cStorerKey
   AND   TaskType = 'CPK'
   AND   [Status] = '3'
   AND   FromLoc = @cLOC
   AND   Sku = @cSKU
   AND   Caseid = @cCaseID
   AND   Groupkey = @cGroupKey
   AND   DeviceID = @cCartID 

   OPEN @curUpdTask
   FETCH NEXT FROM @curUpdTask INTO @cTaskKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE dbo.TaskDetail SET 
         [Status] = '5',
         EditDate = GETDATE(),
         EditWho = @cUserName
      WHERE TaskDetailKey = @cTaskKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 149012
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail
         GOTO RollBackTran
      END      

      FETCH NEXT FROM @curUpdTask INTO @cTaskKey
   END

   -- Get Pack QTY  
   SELECT @nPackQTY = ISNULL( SUM( PD.QTY), 0)  
   FROM dbo.PackDetail PD WITH (NOLOCK)   
   WHERE PD.PickSlipNo = @cPickSlipNo  

   -- Get Pick QTY  
   -- Cross dock PickSlip  
   IF @cZone IN ('XD', 'LB', 'LP')  
   BEGIN  
      -- Check outstanding PickDetail  
      IF EXISTS( SELECT TOP 1 1  
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)  
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)  
         WHERE RKL.PickSlipNo = @cPickSlipNo  
            AND PD.Status < '5'  
            AND PD.QTY > 0  
            AND (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick  
         SET @cPackConfirm = 'N'  
      ELSE  
         SET @cPackConfirm = 'Y'  
        
      -- Check fully packed  
      IF @cPackConfirm = 'Y'  
      BEGIN  
         SELECT @nPickQTY = SUM( QTY)   
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)  
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)  
         WHERE RKL.PickSlipNo = @cPickSlipNo  
           
         IF @nPickQTY <> @nPackQTY  
            SET @cPackConfirm = 'N'  
      END  
   END  
  
   -- Discrete PickSlip  
   ELSE IF @cOrderKey <> ''  
   BEGIN  
      -- Check outstanding PickDetail  
      IF EXISTS( SELECT TOP 1 1  
         FROM dbo.PickDetail PD WITH (NOLOCK)  
         WHERE PD.OrderKey = @cOrderKey  
            AND PD.Status < '5'  
            AND PD.QTY > 0  
            AND (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick  
         SET @cPackConfirm = 'N'  
      ELSE  
         SET @cPackConfirm = 'Y'  
        
      -- Check fully packed  
      IF @cPackConfirm = 'Y'  
      BEGIN  
         SELECT @nPickQTY = SUM( PD.QTY)   
         FROM dbo.PickDetail PD WITH (NOLOCK)   
         WHERE PD.OrderKey = @cOrderKey  
           
         IF @nPickQTY <> @nPackQTY  
            SET @cPackConfirm = 'N'  
      END  
   END  
     
   -- Conso PickSlip  
   ELSE IF @cLoadKey <> ''  
   BEGIN  
      -- Check outstanding PickDetail  
      IF EXISTS( SELECT TOP 1 1   
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)   
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)  
         WHERE LPD.LoadKey = @cLoadKey  
            AND PD.Status < '5'  
            AND PD.QTY > 0  
            AND (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick  
         SET @cPackConfirm = 'N'  
      ELSE  
         SET @cPackConfirm = 'Y'  
        
      -- Check fully packed  
      IF @cPackConfirm = 'Y'  
      BEGIN  
         SELECT @nPickQTY = SUM( PD.QTY)   
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)   
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)  
         WHERE LPD.LoadKey = @cLoadKey  
           
         IF @nPickQTY <> @nPackQTY  
            SET @cPackConfirm = 'N'  
      END  
   END  
  
   -- Custom PickSlip  
   ELSE  
   BEGIN  
      -- Check outstanding PickDetail  
      IF EXISTS( SELECT TOP 1 1   
         FROM PickDetail PD WITH (NOLOCK)   
         WHERE PD.PickSlipNo = @cPickSlipNo  
            AND PD.Status < '5'  
            AND PD.QTY > 0  
            AND (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick  
         SET @cPackConfirm = 'N'  
      ELSE  
         SET @cPackConfirm = 'Y'  
  
      -- Check fully packed  
      IF @cPackConfirm = 'Y'  
      BEGIN  
         SELECT @nPickQTY = SUM( PD.QTY)   
         FROM PickDetail PD WITH (NOLOCK)   
         WHERE PD.PickSlipNo = @cPickSlipNo  
           
         IF @nPickQTY <> @nPackQTY  
            SET @cPackConfirm = 'N'  
      END  
   END  

   -- Pack confirm  
   IF @cPackConfirm = 'Y'  
   BEGIN  
      -- Pack confirm  
      UPDATE dbo.PackHeader SET   
         Status = '9'   
      WHERE PickSlipNo = @cPickSlipNo  
         AND Status <> '9'  
         
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 149013  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PackCfm Fail  
         GOTO RollBackTran  
      END  
  
      -- Get storer config  
      DECLARE @cAssignPackLabelToOrdCfg NVARCHAR(1)  
      EXECUTE nspGetRight  
         @cFacility,  
         @cStorerKey,  
         '', --@c_sku  
         'AssignPackLabelToOrdCfg',  
         @bSuccess                 OUTPUT,  
         @cAssignPackLabelToOrdCfg OUTPUT,  
         @nErrNo                   OUTPUT,  
         @cErrMsg                  OUTPUT  
      IF @nErrNo <> 0  
         GOTO RollBackTran  
  
      -- Assign  
      IF @cAssignPackLabelToOrdCfg = '1'  
      BEGIN  
         -- Update PickDetail, base on PackDetail.DropID  
         EXEC isp_AssignPackLabelToOrderByLoad  
             @cPickSlipNo  
            ,@bSuccess OUTPUT  
            ,@nErrNo   OUTPUT  
            ,@cErrMsg  OUTPUT  
         IF @nErrNo <> 0  
            GOTO RollBackTran  
      END  
   END  

   COMMIT TRAN rdt_TM_ClusterPick_ConfirmPick  
  
 
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
  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_TM_ClusterPick_ConfirmPick -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  

Fail:
END  

GO