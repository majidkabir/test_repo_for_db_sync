SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure:  rdt_839Confirm06                                         */  
/* Copyright      : Maersk                                                    */  
/*                                                                            */  
/* Date       Rev  Author     Purposes                                        */  
/* 17-06-2020 1.0  YeeKung    WMS13795 Created                                */
/* 20-04-2022 1.1  YeeKung    WMS-19311 Add Data capture (yeekung01)          */
/* 16-01-2023 1.2  Calvin     JSM-123639 Stamp Channel_ID (CLVN01)            */
/* 04-04-2023 1.3  YeeKung    JSM-140598 Add blocking status 4 (yeekun02)     */
/* 25-07-2023 1.4  Ung        WMS-23002 Add serial no                         */ 
/******************************************************************************/  
  
CREATE   PROC [RDT].[rdt_839Confirm06] (  
    @nMobile         INT  
   ,@nFunc           INT  
   ,@cLangCode       NVARCHAR( 3)  
   ,@nStep           INT  
   ,@nInputKey       INT  
   ,@cFacility       NVARCHAR( 5)  
   ,@cStorerKey      NVARCHAR( 15)  
   ,@cType           NVARCHAR( 10) -- CONFIRM/SHORT/CLOSE  
   ,@cPickSlipNo     NVARCHAR( 10)  
   ,@cPickZone       NVARCHAR( 10)  
   ,@cDropID         NVARCHAR( 20)  
   ,@cLOC            NVARCHAR( 10)  
   ,@cSKU            NVARCHAR( 20)  
   ,@nQTY            INT  
   ,@cLottableCode   NVARCHAR( 30)  
   ,@cLottable01     NVARCHAR( 18)    
   ,@cLottable02     NVARCHAR( 18)    
   ,@cLottable03     NVARCHAR( 18)    
   ,@dLottable04     DATETIME    
   ,@dLottable05     DATETIME    
   ,@cLottable06     NVARCHAR( 30)   
   ,@cLottable07     NVARCHAR( 30)   
   ,@cLottable08     NVARCHAR( 30)   
   ,@cLottable09     NVARCHAR( 30)   
   ,@cLottable10     NVARCHAR( 30)   
   ,@cLottable11     NVARCHAR( 30)  
   ,@cLottable12     NVARCHAR( 30)  
   ,@dLottable13     DATETIME  
   ,@dLottable14     DATETIME  
   ,@dLottable15     DATETIME
   ,@cPackData1      NVARCHAR( 30)
   ,@cPackData2      NVARCHAR( 30)
   ,@cPackData3      NVARCHAR( 30)   
   ,@cID             NVARCHAR( 18)
   ,@cSerialNo       NVARCHAR( 30)
   ,@nSerialQTY      INT
   ,@nBulkSNO        INT
   ,@nBulkSNOQTY     INT
   ,@nErrNo          INT           OUTPUT  
   ,@cErrMsg         NVARCHAR(250) OUTPUT  
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
  
   DECLARE @cOrderKey      NVARCHAR( 10)  
   DECLARE @cLoadKey       NVARCHAR( 10)  
   DECLARE @cZone          NVARCHAR( 18)  
   DECLARE @cPickDetailKey NVARCHAR( 18)  
   DECLARE @cPickConfirmStatus NVARCHAR( 1)  
   DECLARE @nQTY_Bal       INT  
   DECLARE @nQTY_PD        INT  
   DECLARE @bSuccess       INT  
   DECLARE @curPD          CURSOR  
   DECLARE @cWhere         NVARCHAR( MAX)  
   DECLARE @nRowCount      INT 
   DECLARE @cPD_OrderKey   NVARCHAR( 10) 

   SET @cOrderKey = ''    
   SET @cLoadKey = ''    
   SET @cZone = ''  
   
   DECLARE @tOrders TABLE  
   (  
      OrderKey NVARCHAR( 10) NOT NULL,   
      PRIMARY KEY CLUSTERED (OrderKey)  
   )  
    
    
   -- Get storer config    
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)    
   IF @cPickConfirmStatus = '0'    
      SET @cPickConfirmStatus = '5'    
    
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
         ' SELECT PD.PickDetailKey, PD.QTY, PD.OrderKey  ' +    
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
         ' SELECT PD.PickDetailKey, PD.QTY, PD.OrderKey  ' +    
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
         ' SELECT PD.PickDetailKey, PD.QTY, PD.OrderKey ' +    
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
         ' SELECT PD.PickDetailKey, PD.QTY, PD.OrderKey  ' +    
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
   SAVE TRAN rdt_839Confirm06 -- For rollback or commit only our own transaction 

    -- Loop PickDetail    
   FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD, @cPD_OrderKey      
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
            SET @nErrNo = 153851     
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
            GOTO RollBackTran    
         END    

         IF NOT EXISTS( SELECT 1 FROM @tOrders WHERE OrderKey = @cPD_OrderKey)  
            INSERT INTO @tOrders (OrderKey) VALUES (@cPD_OrderKey)  
    
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
            SET @nErrNo = 153852    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
            GOTO RollBackTran    
         END
         
         IF NOT EXISTS( SELECT 1 FROM @tOrders WHERE OrderKey = @cPD_OrderKey)  
            INSERT INTO @tOrders (OrderKey) VALUES (@cPD_OrderKey)      
    
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
                  SET @nErrNo = 153853    
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
               SET @nErrNo = 153854    
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
			   Channel_ID)    --(CLVN01)
            SELECT    
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,    
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,    
               CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,    
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,    
               @cNewPickDetailKey,    
               Status,    
               @nQTY_PD - @nQTY_Bal, -- QTY    
               NULL, -- TrafficCop    
               '1',   -- OptimizeCop   
			   Channel_ID  --(CLVN01)			  
            FROM dbo.PickDetail WITH (NOLOCK)    
            WHERE PickDetailKey = @cPickDetailKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 153855    
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
                  SET @nErrNo = 153856    
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
               SET @nErrNo = 153857    
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
               SET @nErrNo = 153858    
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
                  SET @nErrNo = 153859  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                  GOTO RollBackTran  
               END  
            END  
    
            SET @nQTY_Bal = 0 -- Reduce balance    
         END    
      END    
    
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD,@cPD_OrderKey    
   END    

   DECLARE @curOrder CURSOR, 
           @cStatus  INT 
   SET @curOrder = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT OrderKey FROM @tOrders  
   OPEN @curOrder  
   FETCH NEXT FROM @curOrder INTO @cPD_OrderKey  
   WHILE @@FETCH_STATUS = 0  
   BEGIN
      -- Get Order info  
      SELECT   
         @cStatus = Status   
      FROM Orders WITH (NOLOCK)   
      WHERE OrderKey = @cPD_OrderKey   
         AND DocType ='E'


      IF (ISNULL(@cStatus,'')<>'' AND @cStatus <3 )
      BEGIN
         IF NOT EXISTS (SELECT 1
               FROM Pickdetail (NOLOCK)
               WHERE Orderkey  = @cPD_OrderKey
               AND Storerkey = @cStorerKey
               AND Status IN ('0', '4')) 
         BEGIN
            UPDATE Orders  WITH (ROWLOCK)
            SET  
               Status = '3',    
               EditDate = GETDATE(),   
               EditWho = SUSER_SNAME()  
            WHERE OrderKey = @cPD_OrderKey  
            SET @nErrNo = @@ERROR   
            IF @nErrNo <> 0  
            BEGIN  
               SET @nErrNo = 128760  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Order Fail  
               GOTO RollbackTran  
            END  
         END
      END

      FETCH NEXT FROM @curOrder INTO @cPD_OrderKey  
   END 
    
   COMMIT TRAN rdt_839Confirm06    
    
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
   ROLLBACK TRAN rdt_839Confirm06 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO