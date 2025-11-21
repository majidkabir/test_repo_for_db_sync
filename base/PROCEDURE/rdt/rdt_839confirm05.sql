SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store procedure: rdt_839Confirm05                                          */  
/* Copyright      : Maersk                                                    */  
/*                                                                            */  
/* Date       Rev  Author     Purposes                                        */  
/* 2019-08-15 1.0  James      WMS-10172 Created                               */ 
/* 2020-09-02 1.1  James      WMS-14949 Stamp channel id (james01)            */
/* 2021-09-27 1.2  James      WMS-18027 Add update orders status (james02)    */
/* 2022-04-20 1.3  YeeKung    WMS-19311 Add Data capture (yeekung01)          */
/* 2023-07-25 1.4  Ung        WMS-23002 Add serial no                         */
/******************************************************************************/  
  
CREATE   PROC [RDT].[rdt_839Confirm05] (  
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
   DECLARE @cTempID        NVARCHAR( 20)
  -- DECLARE @cID            NVARCHAR( 18)
   DECLARE @nChannel_ID    BIGINT
   DECLARE @cUpdOrdStatus  NVARCHAR( 1)
   DECLARE @cTempOrderKey  NVARCHAR( 10)
   DECLARE @cTempOrderLineNumber NVARCHAR( 5)
   
   DECLARE @tPickDetailKey TABLE ( PickDetailKey  NVARCHAR( 10))
   
   SET @cTempID = ''
   SELECT @cTempID = ISNULL( O_Field12, '')
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   -- ID     : 99999999
   SET @cID = RTRIM( LTRIM( SUBSTRING( @cTempID, CHARINDEX( ':', @cTempID) + 1, 18)))
   SET @cOrderKey = ''  
   SET @cLoadKey = ''  
   SET @cZone = ''  
  
   -- Get storer config  
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
   IF @cPickConfirmStatus = '0'  
      SET @cPickConfirmStatus = '5'  
  
   SET @cUpdOrdStatus = rdt.RDTGetConfig( @nFunc, 'UpdOrdStatus', @cStorerKey)
   
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
           CASE WHEN @cID = '' THEN '' ELSE ' AND PD.ID = @cID ' END +  
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
           CASE WHEN @cID = '' THEN '' ELSE ' AND PD.ID = @cID ' END +  
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
           CASE WHEN @cID = '' THEN '' ELSE ' AND PD.ID = @cID ' END +  
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
           CASE WHEN @cID = '' THEN '' ELSE ' AND PD.ID = @cID ' END +  
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
      ' @cID         NVARCHAR( 18), ' +   
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
  
   EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @curPD OUTPUT, @cPickSlipNo, @cOrderKey, @cLoadKey, @cLOC, @cDropID, @cSKU, @cID, @cPickConfirmStatus,   
      @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
      @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
      @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15  
  
   -- Handling transaction  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_PickPiece_Confirm -- For rollback or commit only our own transaction  
  
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
            SET @nErrNo = 143201  
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
            SET @nErrNo = 143202  
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
                  SET @nErrNo = 143203  
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
               SET @nErrNo = 143204  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
               GOTO RollBackTran  
            END  
  
            -- Create new a PickDetail to hold the balance  
            INSERT INTO dbo.PickDetail (  
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,  
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,  
               ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,  
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,  
               PickDetailKey, Status, QTY, TrafficCop, OptimizeCop, Channel_ID)  
            SELECT  
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,  
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,  
               CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,  
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,  
               @cNewPickDetailKey, Status, @nQTY_PD - @nQTY_Bal, NULL, '1', Channel_ID  -- (james01)
            FROM dbo.PickDetail WITH (NOLOCK)  
            WHERE PickDetailKey = @cPickDetailKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 143205  
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
                  SET @nErrNo = 143206  
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
               SET @nErrNo = 143207  
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
               SET @nErrNo = 143208  
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
                  SET @nErrNo = 143209
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                  GOTO RollBackTran
               END
            END
  
            SET @nQTY_Bal = 0 -- Reduce balance  
         END  
      END  
  
      INSERT INTO @tPickDetailKey (PickDetailKey) VALUES (@cPickDetailKey)
      
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD  
   END  
   
   IF @cUpdOrdStatus = '1'
   BEGIN
      DECLARE @curUpdOrdStatus  CURSOR
      DECLARE @curUpdOrdDtlStatus   CURSOR
      
      SET @curUpdOrdStatus = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT DISTINCT OrderKey
      FROM @tPickDetailKey t
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( t.PickDetailKey = PD.PickDetailKey)
      OPEN @curUpdOrdStatus
      FETCH NEXT FROM @curUpdOrdStatus INTO @cTempOrderKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                         WHERE OrderKey = @cTempOrderKey
                         AND   Qty > 0
                         AND   [Status] <> '4'
                         AND   [Status] < @cPickConfirmStatus )
         BEGIN
            SET @curUpdOrdDtlStatus = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT OrderLineNumber
            FROM dbo.ORDERDETAIL WITH (NOLOCK)
            WHERE OrderKey = @cTempOrderKey
            OPEN @curUpdOrdDtlStatus
            FETCH NEXT FROM @curUpdOrdDtlStatus INTO @cTempOrderLineNumber
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE dbo.ORDERDETAIL SET 
                  STATUS = @cPickConfirmStatus,
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE()
               WHERE OrderKey = @cTempOrderKey
               AND   OrderLineNumber = @cTempOrderLineNumber
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 143210
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD OrdDtl Fail
                  GOTO RollBackTran
               END
               
               FETCH NEXT FROM @curUpdOrdDtlStatus INTO @cTempOrderLineNumber
            END

            UPDATE dbo.ORDERS SET 
               STATUS = @cPickConfirmStatus,
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE OrderKey = @cTempOrderKey
               
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 143211
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD OrdHdr Fail
               GOTO RollBackTran
            END
            
         END
         FETCH NEXT FROM @curUpdOrdStatus INTO @cTempOrderKey
      END
   END
   
   COMMIT TRAN rdt_PickPiece_Confirm  
  
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
      @cDropID       = @cDropID,
      @cID           = @cID
  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_PickPiece_Confirm -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
--INSERT INTO TraceInfo (TraceName, TimeIn, Col1, Col2, Col3, Col4, Col5) VALUES ('839', GETDATE(), @cID, @cOrderKey, @cLoc, @cSKU, @cPickConfirmStatus)
END  

GO