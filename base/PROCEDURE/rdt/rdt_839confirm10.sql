SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store procedure: rdt_839Confirm10                                          */  
/* Copyright      : Maersk                                                    */  
/*                                                                            */  
/* Date       Rev  Author     Purposes                                        */  
/* 2021-04-26 1.0  yeekung    WMS-16839 Created                               */ 
/* 2022-04-20 1.1  YeeKung    WMS-19311 Add Data capture (yeekung01)          */
/* 2023-07-25 1.2  Ung        WMS-23002 Add serial no                         */
/******************************************************************************/  
  
CREATE   PROC [RDT].[rdt_839Confirm10] (  
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
   DECLARE @cTempPickDetailKey NVARCHAR(20)
   DECLARE @cTempLot      NVARCHAR(20)
   DECLARE @clot          NVARCHAR(20)

   SET @cTempID = ''
   SELECT @cTempID = ISNULL( V_string50, '')
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- ID     : 99999999
  -- SET @cID = RTRIM( LTRIM( SUBSTRING( @cTempID, CHARINDEX( ':', @cTempID) + 1, 18)))
   SET @cOrderKey = ''  
   SET @cLoadKey = ''  
   SET @cZone = ''  
  
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
           CASE WHEN @cID = '' THEN '' ELSE ' AND PD.ID = @cTempID ' END +  
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
      ' @cTempID     NVARCHAR( 18), ' +   
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
  
   EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @curPD OUTPUT, @cPickSlipNo, @cOrderKey, @cLoadKey, @cLOC, @cDropID, @cSKU, @cTempID, @cPickConfirmStatus,   
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
            SET @nErrNo = 166851  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
            GOTO RollBackTran  
         END  


         IF EXISTS (SELECT 1 FROM pickdetail (NOLOCK) 
            WHERE PickDetailKey = @cPickDetailKey  
            AND ID<>@cTempID) AND ISNULL(@cTempID,'')<>''
         BEGIN
            SELECT @cTempPickDetailKey=PickDetailKey,@ctempLot=lli.lot
            FROM pickdetail pd (NOLOCK) JOIN dbo.LOTxLOCxID lli (NOLOCK)
            ON (pd.loc=lli.loc AND pd.id=lli.id AND pd.sku=lli.sku)
            WHERE lli.id=@cTempID
            AND lli.loc=@cLOC
            AND lli.sku=@cSKU
            AND lli.qty>0
         

            SELECT @cID=id,@clot=lot
            FROM pickdetail pd (NOLOCK)
            WHERE PickDetailKey = @cPickDetailKey  

            IF ISNULL(@cTempPickDetailKey,'')<>''
            BEGIN
               -- Confirm PickDetail  
               UPDATE dbo.PickDetail WITH (ROWLOCK) 
               SET  
                  id=@cID,
                  lot=@clot
               WHERE PickDetailKey = @cTempPickDetailKey 

               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 166861  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
                  GOTO RollBackTran  
               END  
            END
            -- swap id  
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
               id=@cTempID,
               lot=CASE WHEN ISNULL(@cTempLot,'')<>'' THEN @cTempLot ELSE lot end
            WHERE PickDetailKey = @cPickDetailKey 

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 166862 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
               GOTO RollBackTran  
            END  
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
            SET @nErrNo = 166852  
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
                  SET @nErrNo = 166853  
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
               SET @nErrNo = 166854  
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
               SET @nErrNo = 166855  
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
                  SET @nErrNo = 166856  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail  
                  GOTO RollBackTran  
               END  
            END  
  
            -- Change orginal PickDetail with exact QTY (with TrafficCop)  
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
               QTY = @nQTY_Bal,  
               ID     =CASE WHEN ISNULL(@cTempID,'')='' THEN ID ELSE @cTempID END,
               EditDate = GETDATE(),  
               EditWho  = SUSER_SNAME(),  
               Trafficcop = NULL  
            WHERE PickDetailKey = @cPickDetailKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 166858  
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
               SET @nErrNo = 166859  
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
                  SET @nErrNo = 166860
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                  GOTO RollBackTran
               END
            END
  
            SET @nQTY_Bal = 0 -- Reduce balance  
         END  
      END  
  
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD  
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
END  

GO