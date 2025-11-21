SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_540SAPCfm02                                     */  
/* Copyright: IDS                                                       */  
/* Purpose: IDX Sort And Pack Confirm                                   */  
/*                                                                      */  
/* Called from: rdtfnc_SortAndPack                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Ver  Author   Purposes                                   */  
/* 2018-Mar-27 1.0  James    WMS4203.Created                            */ 
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_540SAPCfm02]  
   @nMobile       INT,  
   @nFunc         INT,  
   @cLangCode     NVARCHAR( 3),  
   @cPackByType   NVARCHAR( 10),   
   @cLoadKey      NVARCHAR( 10),  
   @cOrderKey     NVARCHAR( 10),   
   @cConsigneeKey NVARCHAR( 15),  
   @cStorerKey    NVARCHAR( 15),  
   @cSKU          NVARCHAR( 20),  
   @nQTY          INT,   
   @cLabelNo      NVARCHAR( 20),  
   @cCartonType   NVARCHAR( 10),     
   @bSuccess      INT            OUTPUT,
   @nErrNo        INT            OUTPUT,  
   @cErrMsg       NVARCHAR( 20)  OUTPUT,   
   @cUCCNo        NVARCHAR(20) = ''

AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_success      INT  
   DECLARE @cPickDetailKey NVARCHAR( 10)  
   DECLARE @cPickSlipNo    NVARCHAR( 10)  
   DECLARE @nPickQTY       INT  
   DECLARE @nQTY_PD        INT  
   DECLARE @cActQty        NVARCHAR( 5)
   DECLARE @cDropID        NVARCHAR( 20)
   DECLARE @cAutoPackConfirm NVARCHAR( 1)
   DECLARE @cPSNO          NVARCHAR( 10)  
  
   SET @nErrNo = 0  
   SET @cErrMsg = ''  
   SET @cAutoPackConfirm = '0'
   SET @cDropID =''
   SET @cActQty = '0'

   IF rdt.RDTGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey) = '1'
      SET @cAutoPackConfirm = '1'

   IF rdt.RDTGetConfig( @nFunc, 'UseLabelNoAsDropID', @cStorerKey) = '1'
      SET @cDropID = @cLabelNo

   IF rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey) = '1'
   BEGIN
      -- From the main program, it passes @cDefaultQty as @nQty
      -- This could be a bug because user set config DefaultQty = 1 (config turn on)
      -- So get the actual qty again from screen
      SELECT @cActQty = I_Field06,
             @cLoadKey = V_CaseID
      FROM rdt.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile

      IF rdt.rdtIsValidQty( @cActQty, 1) = 1
         SET @nQTY = CAST( @cActQty AS INT)
   END
      
   SET @nPickQTY = @nQTY  
  
   DECLARE @tPD TABLE   
   (  
      PickDetailKey NVARCHAR(10) NOT NULL,  
      OrderKey      NVARCHAR(10) NOT NULL,  
      ConsigneeKey  NVARCHAR(15) NOT NULL,  
      QTY           INT      NOT NULL  
   )  
  
/*--------------------------------------------------------------------------------------------------  
  
                                           PickDetail line  
  
--------------------------------------------------------------------------------------------------*/  
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_540SAPCfm02  
  
   DECLARE @curPD CURSOR  
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT O.OrderKey, O.ConsigneeKey, PD.PickDetailKey, PD.QTY  
      FROM dbo.PickDetail PD WITH (NOLOCK)  
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)  
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)  
      WHERE LPD.LoadKey = @cLoadKey  
         AND PD.StorerKey = @cStorerKey  
         AND PD.SKU = @cSKU  
         AND PD.QTY > 0  
         AND PD.Status = '0'  
         AND PD.UOM = '6'
      ORDER BY PD.PickDetailKey  
  
   OPEN @curPD  
   FETCH NEXT FROM @curPD INTO @cOrderKey, @cConsigneeKey, @cPickDetailKey, @nQTY_PD  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      -- Exact match  
      IF @nQTY_PD = @nPickQty  
      BEGIN  
         -- Confirm PickDetail  
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
            Status = '5', 
            CaseID = 'SORTED'
         WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 107451  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail  
            GOTO RollBackTran  
         END  
  
         INSERT INTO @tPD (PickDetailKey, OrderKey, ConsigneeKey, QTY) VALUES (@cPickDetailKey, @cOrderKey, @cConsigneeKey, @nQTY_PD)  
         SET @nPickQty = 0 -- Reduce balance  
         BREAK  
      END  
  
      -- PickDetail have less  
      ELSE IF @nQTY_PD < @nPickQty  
      BEGIN  
         -- Confirm PickDetail  
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
            Status = '5', 
            CaseID = 'SORTED'
         WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 107452  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail  
            GOTO RollBackTran  
         END  
  
         INSERT INTO @tPD (PickDetailKey, OrderKey, ConsigneeKey, QTY) VALUES (@cPickDetailKey, @cOrderKey, @cConsigneeKey, @nQTY_PD)  
         SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance  
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
            @b_success         OUTPUT,  
            @nErrNo            OUTPUT,  
            @cErrMsg           OUTPUT  
         IF @b_success <> 1  
         BEGIN  
            SET @nErrNo = 107453  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail  
            GOTO RollBackTran  
         END  
  
         -- Create a new PickDetail to hold the balance  
         INSERT INTO dbo.PICKDETAIL (  
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,  
            Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,  
            DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,  
            QTY,  
            TrafficCop,  
            OptimizeCop)  
         SELECT  
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,  
            '0', DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,  
            DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,  
            @nQTY_PD - @nPickQty, -- QTY  
            NULL, --TrafficCop,  
            '1'  --OptimizeCop  
         FROM dbo.PickDetail WITH (NOLOCK)  
         WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 107454  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail  
            GOTO RollBackTran  
         END  
  
         -- Split RefKeyLookup
         IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
         BEGIN
            -- Insert into
            INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
            SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
            FROM dbo.RefKeyLookup WITH (NOLOCK) 
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 107455
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
               GOTO RollBackTran
            END
         END

         -- Change orginal PickDetail with exact QTY (with TrafficCop)  
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
            QTY = @nPickQty,  
            Trafficcop = NULL  
         WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 107456  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail  
            GOTO RollBackTran  
         END  
  
         -- Pick confirm original line  
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
            Status = '5', 
            CaseID = 'SORTED'
         WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 107457  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail  
            GOTO RollBackTran  
         END  
  
         INSERT INTO @tPD (PickDetailKey, OrderKey, ConsigneeKey, QTY) VALUES (@cPickDetailKey, @cOrderKey, @cConsigneeKey, @nPickQty)  
         SET @nPickQty = 0 -- Reduce balance  
         BREAK  
      END  
      FETCH NEXT FROM @curPD INTO @cOrderKey, @cConsigneeKey, @cPickDetailKey, @nQTY_PD  
   END  

   IF @nPickQty <> 0  
   BEGIN  
      SET @nErrNo = 107458  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset Fail  
      GOTO RollBackTran  
   END  

   GOTO Quit  
  
RollBackTran:  
      ROLLBACK TRAN rdt_540SAPCfm02  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN  
END  

GO