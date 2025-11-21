SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/    
/* Store procedure: rdt_839Confirm09                                          */    
/* Copyright      : Maersk                                                    */    
/*                                                                            */    
/* Date       Rev  Author     Purposes                                        */    
/* 2021-10-28 1.0  James      WMS-18174. Created                              */ 
/* 2022-04-20 1.1  YeeKung    WMS-19311 Add Data capture (yeekung01)          */
/* 2023-07-25 1.2  Ung        WMS-23002 Add serial no                         */
/******************************************************************************/    
    
CREATE   PROC [RDT].[rdt_839Confirm09] (    
   @nMobile       INT,               
   @nFunc         INT,               
   @cLangCode     NVARCHAR( 3),      
   @nStep         INT,               
   @nInputKey     INT,               
   @cFacility     NVARCHAR( 5) ,     
   @cStorerKey    NVARCHAR( 15),     
   @cType         NVARCHAR( 10),     
   @cPickSlipNo   NVARCHAR( 10),     
   @cPickZone     NVARCHAR( 1),      
   @cDropID       NVARCHAR( 20),     
   @cLOC          NVARCHAR( 10),     
   @cSKU          NVARCHAR( 20),     
   @nQTY          INT,               
   @cLottableCode NVARCHAR( 30),     
   @cLottable01   NVARCHAR( 18),       
   @cLottable02   NVARCHAR( 18),       
   @cLottable03   NVARCHAR( 18),       
   @dLottable04   DATETIME,    
   @dLottable05   DATETIME,    
   @cLottable06   NVARCHAR( 30),      
   @cLottable07   NVARCHAR( 30),      
   @cLottable08   NVARCHAR( 30),      
   @cLottable09   NVARCHAR( 30),      
   @cLottable10   NVARCHAR( 30),      
   @cLottable11   NVARCHAR( 30),     
   @cLottable12   NVARCHAR( 30),     
   @dLottable13   DATETIME,    
   @dLottable14   DATETIME,    
   @dLottable15   DATETIME,
   @cPackData1    NVARCHAR( 30),
   @cPackData2    NVARCHAR( 30),
   @cPackData3    NVARCHAR( 30),
   @cID           NVARCHAR( 18),
   @cSerialNo     NVARCHAR( 30),
   @nSerialQTY    INT,
   @nBulkSNO      INT,
   @nBulkSNOQTY   INT,    
   @nErrNo        INT           OUTPUT,     
   @cErrMsg       NVARCHAR(250) OUTPUT      
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @nTranCount           INT    
   DECLARE @cOrderKey            NVARCHAR( 10)    
   DECLARE @cLoadKey             NVARCHAR( 10)    
   DECLARE @cZone                NVARCHAR( 18)    
   DECLARE @cPickDetailKey       NVARCHAR( 18)    
   DECLARE @cPickConfirmStatus   NVARCHAR( 1)    
   DECLARE @cRoute               NVARCHAR( 20)    
   DECLARE @cOrderRefNo          NVARCHAR( 18)  
   DECLARE @cConsigneekey        NVARCHAR( 15)  
   DECLARE @cLabelNo             NVARCHAR( 20)  
   DECLARE @cLabelLine           NVARCHAR( 5)  
   DECLARE @cShippLabel          NVARCHAR( 10)  
   DECLARE @cLabelPrinter        NVARCHAR( 10)  
   DECLARE @nQTY_Bal             INT    
   DECLARE @nQTY_PD              INT    
   DECLARE @bSuccess             INT    
   DECLARE @nPackQty             INT  
   DECLARE @nTotalPickedQty      INT  
   DECLARE @nTotalPackedQty      INT  
   DECLARE @nCartonNo            INT  
   DECLARE @nPackCfm             INT = 0  
   DECLARE @curPD                CURSOR    
   DECLARE @curPrint             CURSOR  
   DECLARE @cWhere               NVARCHAR( MAX)    
   DECLARE @cSQL                 NVARCHAR( MAX)  
   DECLARE @cSQLParam            NVARCHAR( MAX)  
   DECLARE @tShippLabel          VariableTable  
   DECLARE @cOrdType             NVARCHAR( 10)  
   DECLARE @cPackOrdType         NVARCHAR( 20)  
           
   SET @cOrderKey = ''    
   SET @cLoadKey = ''    
   SET @cZone = ''    
  
   SELECT @cLabelPrinter = Printer  
   FROM rdt.RDTMOBREC WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
       
   -- Get storer config    
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)    
   IF @cPickConfirmStatus = '0'    
      SET @cPickConfirmStatus = '5'    
  
   SET @cPackOrdType = rdt.RDTGetConfig( @nFunc, 'PackOrdType', @cStorerKey)    
  
   -- For calculation    
   SET @nQTY_Bal = @nQTY    
    
   -- Get PickHeader info    
   SELECT TOP 1    
      @cOrderKey = OrderKey,    
      @cLoadKey = ExternOrderKey,    
      @cZone = Zone    
   FROM dbo.PickHeader WITH (NOLOCK)    
   WHERE PickHeaderKey = @cPickSlipNo    
    
   -- Get lottable filter    
   EXEC rdt.rdt_Lottable_GetCurrentSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLottableCode, 4, 'LA',     
      @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,    
      @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,    
      @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,    
      @cWhere   OUTPUT,    
      @nErrNo   OUTPUT,    
      @cErrMsg  OUTPUT    
    
   -- Cross dock PickSlip    
   IF @cZone IN ('XD', 'LB', 'LP')    
      SET @cSQL =     
         ' SELECT PD.PickDetailKey, PD.QTY ' +    
         ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +    
         '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' +    
         '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +     
         ' WHERE RKL.PickSlipNo = @cPickSlipNo ' +    
         '   AND PD.LOC = @cLOC ' +    
         '   AND PD.SKU = @cSKU ' +    
         '   AND PD.QTY > 0 ' +    
         '   AND PD.Status <> ''4'' ' +    
         '   AND PD.Status < @cPickConfirmStatus ' +    
           CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END    
    
   -- Discrete PickSlip    
   ELSE IF @cOrderKey <> ''    
      SET @cSQL =     
         ' SELECT PD.PickDetailKey, PD.QTY ' +    
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +    
         '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +    
         '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +     
         ' WHERE PD.OrderKey = @cOrderKey ' +    
         '    AND PD.LOC = @cLOC ' +    
         '    AND PD.SKU = @cSKU ' +    
         '    AND PD.QTY > 0 ' +    
         '    AND PD.Status <> ''4'' ' +    
         '    AND PD.Status < @cPickConfirmStatus ' +    
           CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END    
    
   -- Conso PickSlip    
   ELSE IF @cLoadKey <> ''    
      SET @cSQL =     
         ' SELECT PD.PickDetailKey, PD.QTY ' +    
         ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +    
         '    JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +    
         '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +    
         '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +     
         ' WHERE LPD.LoadKey = @cLoadKey ' +    
         '    AND PD.LOC = @cLOC ' +    
         '    AND PD.SKU = @cSKU ' +    
         '    AND PD.QTY > 0 ' +    
         '    AND PD.Status <> ''4'' ' +    
         '    AND PD.Status < @cPickConfirmStatus ' +    
           CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END    
    
   -- Custom PickSlip    
   ELSE    
      SET @cSQL =     
         ' SELECT PD.PickDetailKey, PD.QTY ' +    
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +    
         '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +    
         '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +     
         ' WHERE PD.PickSlipNo = @cPickSlipNo ' +    
         '    AND PD.LOC = @cLOC ' +    
         '    AND PD.SKU = @cSKU ' +    
         '    AND PD.QTY > 0 ' +    
         '    AND PD.Status <> ''4'' ' +    
         '    AND PD.Status < @cPickConfirmStatus ' +    
           CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END    
    
   -- Open cursor    
   SET @cSQL =     
      ' SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' +     
         @cSQL +     
      ' OPEN @curPD '     
       
   SET @cSQLParam =     
      ' @curPD       CURSOR OUTPUT, ' +     
      ' @cPickSlipNo NVARCHAR( 10), ' +     
      ' @cOrderKey   NVARCHAR( 10), ' +     
      ' @cLoadKey    NVARCHAR( 10), ' +     
      ' @cLOC        NVARCHAR( 10), ' +     
      ' @cDropID     NVARCHAR( 20), ' +      
      ' @cSKU        NVARCHAR( 20), ' +     
      ' @cPickConfirmStatus NVARCHAR( 1), ' +     
      ' @cLottable01 NVARCHAR( 18), ' +     
      ' @cLottable02 NVARCHAR( 18), ' +     
      ' @cLottable03 NVARCHAR( 18), ' +     
     ' @dLottable04 DATETIME,      ' +     
      ' @dLottable05 DATETIME,      ' +     
      ' @cLottable06 NVARCHAR( 30), ' +     
      ' @cLottable07 NVARCHAR( 30), ' +     
      ' @cLottable08 NVARCHAR( 30), ' +     
      ' @cLottable09 NVARCHAR( 30), ' +     
      ' @cLottable10 NVARCHAR( 30), ' +     
      ' @cLottable11 NVARCHAR( 30), ' +     
      ' @cLottable12 NVARCHAR( 30), ' +     
      ' @dLottable13 DATETIME,      ' +     
      ' @dLottable14 DATETIME,      ' +     
      ' @dLottable15 DATETIME       '    
    
   EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @curPD OUTPUT, @cPickSlipNo, @cOrderKey, @cLoadKey, @cLOC, @cDropID, @cSKU, @cPickConfirmStatus,     
      @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,    
      @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,    
      @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15    
    
   -- Handling transaction    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN  -- Begin our own transaction    
   SAVE TRAN rdt_839Confirm09 -- For rollback or commit only our own transaction    
    
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
            SET @nErrNo = 178151    
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
            SET @nErrNo = 178152    
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
                  SET @nErrNo = 178152    
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
               SET @nErrNo = 178154    
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
               SET @nErrNo = 178155    
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
                  SET @nErrNo = 178156    
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
               SET @nErrNo = 178157    
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
               SET @nErrNo = 178158    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
               GOTO RollBackTran    
            END    
              
            -- Short pick  
            IF @cType = 'SHORT'  
            BEGIN  
               -- Confirm PickDetail  
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
        Status = '4',  
                  DropID = '',   
                  EditDate = GETDATE(),   
                  EditWho  = SUSER_SNAME(),  
                  TrafficCop = NULL  
               WHERE PickDetailKey = @cNewPickDetailKey  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 178159  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                  GOTO RollBackTran  
               END  
            END  
    
            SET @nQTY_Bal = 0 -- Reduce balance    
         END    
      END    
    
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD    
   END    
  
   IF @cOrderKey = ''  
      SELECT TOP 1 @cOrderKey = OrderKey  
      FROM dbo.LoadPlanDetail WITH (NOLOCK)  
      WHERE LoadKey = @cLoadKey  
      ORDER BY 1  
        
   SELECT @cOrdType = DocType  
   FROM dbo.ORDERS WITH (NOLOCK)  
   WHERE OrderKey = @cOrderKey  
   SET @nPackQty = @nQty   
  
   IF CHARINDEX( @cOrdType, @cPackOrdType) > 0  
   BEGIN  
      -- Prevent overpacked  
      SET @nTotalPickedQty = 0   
      SELECT @nTotalPickedQty = ISNULL(SUM(QTY), 0)   
      FROM dbo.PickDetail WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND   OrderKey = @cOrderKey  
      AND   SKU = @cSKU  
      AND   [STATUS] = @cPickConfirmStatus   
  
      SET @nTotalPackedQty = 0   
      SELECT @nTotalPackedQty = ISNULL(SUM(QTY), 0)   
      FROM dbo.PackDetail WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND   PickSlipNo = @cPickSlipNo  
      AND   SKU = @cSKU  
              
      IF (@nTotalPackedQty + @nPackQty) > @nTotalPickedQty   
      BEGIN  
         SET @nErrNo = 178160  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU Overpacked'  
         GOTO RollBackTran  
      END  
              
      -- Same DropID + PickSlipNo will group SKU into a carton. 1 carton could be multi sku  
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)   
                     WHERE StorerKey = @cStorerKey  
                     AND   PickSlipNo = @cPickSlipNo  
                     AND   DropID = @cDropID)  
      BEGIN  
         IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)  
         BEGIN  
            SELECT @cRoute = [Route],   
                   @cOrderRefNo = SUBSTRING(ExternOrderKey, 1, 18),   
                   @cConsigneekey = ConsigneeKey   
            FROM dbo.Orders WITH (NOLOCK)   
            WHERE OrderKey = @cOrderKey  
            AND   StorerKey = @cStorerKey  
     
            INSERT INTO dbo.PackHeader  
            (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)  
            VALUES  
            (@cRoute, @cOrderKey, @cOrderRefNo, @cLoadKey, @cConsigneekey, @cStorerKey, @cPickSlipNo)  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 178161  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPHdrFail'  
               GOTO RollBackTran  
            END   
         END  
  
         SET @nCartonNo = 0  
         SET @cLabelNo = ''  
  
         EXECUTE dbo.nsp_GenLabelNo  
            '',  
            @cStorerKey,  
            @c_labelno     = @cLabelNo    OUTPUT,  
            @n_cartonno    = @nCartonNo   OUTPUT,  
            @c_button      = '',  
            @b_success     = @bSuccess    OUTPUT,  
            @n_err         = @nErrNo      OUTPUT,  
            @c_errmsg      = @cErrMsg     OUTPUT  
  
         IF @bSuccess <> 1  
         BEGIN  
            SET @nErrNo = 178162  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenLabelFail'  
            GOTO RollBackTran  
         END  
  
         INSERT INTO dbo.PackDetail  
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)  
         VALUES  
            (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, @nPackQty,  
            @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID)  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 178163  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'  
            GOTO RollBackTran  
         END   
      END -- DropID not exists  
      ELSE  
      BEGIN  
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
         AND   PickSlipNo = @cPickSlipNo  
         AND   DropID = @cDropID  
         AND   SKU = @cSKU)  
         BEGIN  
            SET @nCartonNo = 0  
            SET @cLabelNo = ''  
  
            SELECT @nCartonNo = CartonNo, @cLabelNo = LabelNo   
            FROM dbo.PackDetail WITH (NOLOCK)  
            WHERE Pickslipno = @cPickSlipNo  
            AND   StorerKey = @cStorerKey  
            AND   DropID = @cDropID  
  
            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)  
            FROM dbo.PackDetail WITH (NOLOCK)  
            WHERE Pickslipno = @cPickSlipNo  
            AND   CartonNo = @nCartonNo  
            AND   DropID = @cDropID  
  
            INSERT INTO dbo.PackDetail  
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)  
            VALUES  
               (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nPackQty,  
               @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID)  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 178164  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'  
               GOTO RollBackTran  
            END   
         END   -- DropID exists but SKU not exists (insert new line with same cartonno)  
         ELSE  
         BEGIN  
            UPDATE dbo.PackDetail WITH (ROWLOCK) SET  
               QTY = QTY + @nPackQty,  
               EditWho = SUSER_SNAME(),  
               EditDate = GETDATE()  
            WHERE StorerKey = @cStorerKey  
            AND   PickSlipNo = @cPickSlipNo  
            AND   DropID = @cDropID  
            AND   SKU = @cSKU  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 178165  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'  
               GOTO RollBackTran  
            END  
  
            SELECT TOP 1 @cLabelNo = LabelNo   
            FROM dbo.PackDetail WITH (NOLOCK)  
            WHERE Pickslipno = @cPickSlipNo  
            AND   StorerKey = @cStorerKey  
            AND   DropID = @cDropID  
            AND   SKU = @cSKU  
            ORDER BY 1  
         END   -- DropID exists and SKU exists (update qty only)  
      END  
  
      IF NOT EXISTS ( SELECT 1   
                      FROM dbo.PickDetail WITH (NOLOCK)  
                      WHERE StorerKey = @cStorerKey  
                      AND   OrderKey = @cOrderKey  
                      AND   ([STATUS] = '0' OR [STATUS] = '4'))   
      BEGIN  
         -- Check pick = pack then pack confirm  
         SET @nTotalPickedQty = 0   
         SELECT @nTotalPickedQty = ISNULL(SUM(QTY), 0)   
         FROM dbo.PickDetail WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND   OrderKey = @cOrderKey  
         AND   [Status] = @cPickConfirmStatus  
  
         SET @nTotalPackedQty = 0   
         SELECT @nTotalPackedQty = ISNULL(SUM(QTY), 0)   
         FROM dbo.PackDetail WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND   PickSlipNo = @cPickSlipNo  
  
         IF @nTotalPickedQty = @nTotalPackedQty  
         BEGIN  
            UPDATE dbo.PACKHEADER SET   
               [STATUS] = '9'   
            WHERE PickSlipNo = @cPickSlipNo  
  
            IF @@ERROR <> 0  
            BEGIN          
               SET @nErrNo = 178166          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail      
               GOTO RollBackTran    
            END   
           
            SET @nPackCfm = 1  
         END  
      END  
        
      IF @nPackCfm = 1  
      BEGIN  
         -- Update packdetail.labelno = pickdetail.caseid  
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
   END  
     
   COMMIT TRAN rdt_839Confirm09    
    
   DECLARE @cUserName NVARCHAR( 18)    
   SET @cUserName = SUSER_SNAME()    
    
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
      @cRefNo1       = @cType,    
      @cPickSlipNo   = @cPickSlipNo,    
      @cPickZone     = @cPickZone,     
      @cDropID       = @cDropID    
     
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN rdt_839Confirm09 -- Only rollback change made here    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
END    

GO