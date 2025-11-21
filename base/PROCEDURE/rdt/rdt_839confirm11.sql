SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store procedure: rdt_839Confirm11                                          */  
/* Copyright      : Maersk                                                    */  
/*                                                                            */  
/* Date       Rev  Author     Purposes                                        */  
/* 2022-04-16 1.0  YeeKung    WMS-19311 Created                               */
/* 2023-07-25 1.1  Ung        WMS-23002 Add serial no                         */
/******************************************************************************/  
  
CREATE   PROC [RDT].[rdt_839Confirm11] (  
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
   DECLARE @cPackConfirm         NVARCHAR( 1)
   DECLARE @cDocType             NVARCHAR( 1)
   DECLARE @curPDtl              CURSOR 

   SET @cOrderKey = ''  
   SET @cLoadKey = ''  
   SET @cZone = ''  

   -- Get storer config  
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
   IF @cPickConfirmStatus = '0'  
      SET @cPickConfirmStatus = '5'  

   -- Get storer config  
   SET @cPackConfirm = rdt.RDTGetConfig( @nFunc, 'PackConfirm', @cStorerKey)  
  
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
   SAVE TRAN rdt_839Confirm11 -- For rollback or commit only our own transaction  
  
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
            SET @nErrNo = 186201  
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
            SET @nErrNo = 186202  
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
                  SET @nErrNo = 186202  
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
               SET @nErrNo = 186204  
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
               SET @nErrNo = 186205  
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
                  SET @nErrNo = 186206  
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
               SET @nErrNo = 186207  
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
               SET @nErrNo = 186208  
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
                  SET @nErrNo = 186209
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
                  GOTO RollBackTran
               END
            END
  
            SET @nQTY_Bal = 0 -- Reduce balance  
         END  
      END  
  
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD  
   END  

   IF ISNULL(@cOrderKey,'') =''
   BEGIN
      -- Get orderkey
      SELECT @cOrderKey = OrderKey
      FROM dbo.pickdetail WITH (NOLOCK)  
      WHERE pickslipno = @cPickSlipNo
         AND storerkey=@cstorerkey

      SELECT @cDocType =DocType
      FROM ORDERS (NOLOCK)
      WHERE Orderkey=@cOrderKey
      AND storerkey=@cstorerkey
   END

   IF @cDocType<>'E'
   BEGIN

      SET @nPackQty = @nQty 

      -- Prevent overpacked
      SET @nTotalPickedQty = 0 
      SELECT @nTotalPickedQty = ISNULL(SUM(QTY), 0) 
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   OrderKey = @cOrderKey
      AND   SKU = @cSKU
      AND   [STATUS] <= @cPickConfirmStatus 

      SET @nTotalPackedQty = 0 
      SELECT @nTotalPackedQty = ISNULL(SUM(QTY), 0) 
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   PickSlipNo = @cPickSlipNo
      AND   SKU = @cSKU
            
      IF (@nTotalPackedQty + @nPackQty) > @nTotalPickedQty 
      BEGIN
         SET @nErrNo = 186210
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU Overpacked'
         GOTO RollBackTran
      END
            
      -- Same DropID + PickSlipNo will group SKU into a carton. 1 carton could be multi sku
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND   PickSlipNo = @cPickSlipNo
                     AND   DropID = @cDropID
                     AND   lottablevalue=@cPackData1)
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
         BEGIN
   
            INSERT INTO dbo.PackHeader
            ( OrderKey,  Loadkey, StorerKey, PickSlipNo)
            VALUES
            ( @cOrderKey, @cLoadKey, @cStorerKey, @cPickSlipNo)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 186211
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
            SET @nErrNo = 186212
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenLabelFail'
            GOTO RollBackTran
         END

         SELECT TOP 1 @cPickDetailKey=pickdetailkey
         FROM pickdetail (Nolock)
         where orderkey=@cOrderKey
            AND storerkey=@cstorerkey
            AND sku=@csku
            AND status=@cPickConfirmStatus
         order by editdate desc;

         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID,lottablevalue)
         VALUES
            (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, @nPackQty,
            @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID,@cPackData1)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 186213
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

            SELECT TOP 1 @cPickDetailKey=pickdetailkey
            FROM pickdetail (Nolock)
            where orderkey=@cOrderKey
               AND storerkey=@cstorerkey
               AND sku=@csku
               AND status=@cPickConfirmStatus
            order by editdate desc;

            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE Pickslipno = @cPickSlipNo
            AND   CartonNo = @nCartonNo
            AND   DropID = @cDropID

            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID,LOTTABLEVALUE)
            VALUES
               (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nPackQty,
               @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID,@cPackData1)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 186214
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
               SET @nErrNo = 186215
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

      -- Check pick = pack then pack confirm
      SET @nTotalPickedQty = 0 
      SELECT @nTotalPickedQty = ISNULL(SUM(QTY), 0) 
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   OrderKey = @cOrderKey
      AND   QTY > 0
      AND   [STATUS] <> '4' 
      AND   [STATUS] < '9'

      SET @nTotalPackedQty = 0 
      SELECT @nTotalPackedQty = ISNULL(SUM(QTY), 0) 
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   PickSlipNo = @cPickSlipNo

      IF @nTotalPickedQty = @nTotalPackedQty
      BEGIN
         DECLARE @cLottablevalue NVARCHAR(20)
          
         SET @curPDtl = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LPD.refno,
                LPD.labelno,
                LPD.Lottablevalue
         FROM dbo.PackDetail LPD WITH (NOLOCK)     
         WHERE pickslipno= @cPickSlipNo   

         OPEN @curPDtl
         -- Loop PickDetail    
         FETCH NEXT FROM @curPDtl INTO @cPickDetailKey,@cLabelNo,@cLottablevalue  
         WHILE @@FETCH_STATUS = 0    
         BEGIN  
            UPDATE PICKDETAIL
            set dropid=@cLabelNo,
                altsku= @cLottablevalue
            WHERE pickdetailkey=@cPickDetailKey

            IF @@ERROR <> 0
            BEGIN        
               SET @nErrNo = 186216        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail    
               GOTO RollBackTran  
            END 

            FETCH NEXT FROM @curPDtl INTO @cPickDetailKey,@cLabelNo,@cLottablevalue 
         END
         CLOSE @curPDtl
         DEALLOCATE @curPDtl

         UPDATE dbo.PACKHEADER SET 
            [STATUS] = '9' 
         WHERE PickSlipNo = @cPickSlipNo

         IF @@ERROR <> 0
         BEGIN        
            SET @nErrNo = 186216        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail    
            GOTO RollBackTran  
         END 
         
         SET @nPackCfm = 1
      END
   END
   
   COMMIT TRAN rdt_839Confirm11  
  
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
   ROLLBACK TRAN rdt_839Confirm11 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO