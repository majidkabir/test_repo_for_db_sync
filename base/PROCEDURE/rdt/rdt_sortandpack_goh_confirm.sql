SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_SortAndPack_GOH_Confirm                         */  
/* Copyright: IDS                                                       */  
/* Purpose: Sor tAnd Pack GOH Confirm                                   */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Ver  Author   Purposes                                    */  
/* 2012-12-07 1.0  James    SOS262234 Created                           */  
/* 2013-10-18 1.1  James    SOS287522-Exclude qty from manually created */
/*                          orderline (james01)                         */
/* 2021-04-21 1.2  Chermain WMS-16846 Add Channel_ID (cc01)             */
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_SortAndPack_GOH_Confirm]  
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
   @nErrNo        INT  OUTPUT,  
   @cErrMsg       NVARCHAR( 20) OUTPUT  
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
   DECLARE @cSOStatus      NVARCHAR( 10)
  
   SET @nErrNo = 0  
   SET @cErrMsg = ''  
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
   SAVE TRAN rdt_SortAndPack_GOH_Confirm  
  
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
         AND O.ConsigneeKey = @cConsigneeKey  
         AND O.OrderKey = @cOrderKey 
         AND ISNULL(OD.UserDefine04, '') <> 'M' -- (james01)
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
            Status = '5'  
         WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 77401  
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
            Status = '5'  
         WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 77402  
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
            SET @nErrNo = 77403  
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
            OptimizeCop,
            Channel_ID )--(cc01)    
         SELECT  
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,  
            '0', DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,  
            DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,  
            @nQTY_PD - @nPickQty, -- QTY  
            NULL, --TrafficCop,  
            '1',  --OptimizeCop  
            Channel_ID --(cc01) 
         FROM dbo.PickDetail WITH (NOLOCK)  
         WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 77404  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail  
            GOTO RollBackTran  
         END  
  
         -- Change orginal PickDetail with exact QTY (with TrafficCop)  
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
            QTY = @nPickQty,  
            Trafficcop = NULL  
         WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 77405  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail  
            GOTO RollBackTran  
         END  
  
         -- Pick confirm original line  
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
            Status = '5'  
         WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 77406  
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
      SET @nErrNo = 77407  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset Fail  
      GOTO RollBackTran  
   END  
  
  
/*--------------------------------------------------------------------------------------------------  
  
                                      PackHeader, PackDetail line  
  
--------------------------------------------------------------------------------------------------*/  
   DECLARE @curT CURSOR  
   SET @curT = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT OrderKey, ConsigneeKey, PickDetailKey, QTY  
      FROM @tPD  
   OPEN @curT  
   FETCH NEXT FROM @curT INTO @cOrderKey, @cConsigneeKey, @cPickDetailKey, @nQTY_PD  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      -- Get PickSlipNo (PickHeader)  
      SET @cPickSlipNo = ''  
      SELECT @cPickSlipNo = PickHeaderKey  
      FROM dbo.PickHeader WITH (NOLOCK)  
      WHERE ExternOrderKey = @cLoadKey  
         AND OrderKey = @cOrderKey  
  
      -- PackHeader  
      IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)  
      BEGIN  
         -- Get PickSlipNo (PackHeader)  
         DECLARE @cPSNO NVARCHAR( 10)  
         SET @cPSNO = ''  
         SELECT @cPSNO = PickSlipNo  
         FROM dbo.PackHeader WITH (NOLOCK)  
         WHERE LoadKey = @cLoadKey  
            AND OrderKey = @cOrderKey  
  
         IF @cPSNO <> ''  
            SET @cPickSlipNo = @cPSNO  
         ELSE  
         BEGIN  
            -- New PickSlipNo  
            IF @cPickSlipNo = ''  
            BEGIN  
               EXECUTE nspg_GetKey  
                  'PICKSLIP',  
                  9,  
                  @cPickSlipNo OUTPUT,  
                  @b_success   OUTPUT,  
                  @nErrNo      OUTPUT,  
                  @cErrMsg     OUTPUT  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 77408  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail  
                  GOTO RollBackTran  
               END  
               SET @cPickSlipNo = 'P' + RTRIM( @cPickSlipNo)  
            END  
  
            -- Insert PackHeader  
            INSERT INTO dbo.PackHeader  
               (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey, OrderRefNo, TtlCnts, [STATUS])  
            VALUES  
               (@cPickSlipNo, @cStorerkey, @cOrderkey, @cLoadKey, '99', @cConsigneeKey, '', 0, '0')  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 77409  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackHdrFail  
               GOTO RollBackTran  
            END  
         END  
      END  
  
      -- PackDetail  
      -- Top up to existing carton and SKU  
      IF EXISTS (SELECT 1  
         FROM dbo.PackDetail WITH (NOLOCK)  
         WHERE PickSlipNo = @cPickSlipNo  
            AND LabelNo = @cLabelNo  
            AND StorerKey = @cStorerKey  
            AND SKU = @cSKU)  
      BEGIN  
         -- Update PackDetail  
         UPDATE dbo.PackDetail WITH (ROWLOCK) SET  
            Qty = Qty + @nQTY_PD,  
            Refno = CASE WHEN ISNULL( Refno, '') <> '' THEN Refno ELSE @cPickDetailKey END, 
            EditDate = GETDATE(),  
            EditWho = 'rdt.' + sUser_sName()  
         WHERE PickSlipNo = @cPickSlipNo  
            AND LabelNo = @cLabelNo  
            AND StorerKey = @cStorerkey  
            AND SKU = @cSKU  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 77410  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackDtlFail  
            GOTO RollBackTran  
         END  
      END  
      ELSE  
      BEGIN  
         -- Create new carton  
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cLabelNo)  
         BEGIN  
            INSERT INTO dbo.PackDetail  
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)  
            VALUES  
               (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, @nQTY_PD, -- CartonNo = 0 and LabelLine = '0000', trigger will auto assign  
               @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '')  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 77412  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackDtlFail  
               GOTO RollBackTran  
            END  
         END  
         ELSE  
         BEGIN  
            -- Add new SKU to existing carton  
            DECLARE @nCartonNo INT  
            DECLARE @cLabelLine NVARCHAR(5)  
  
            SELECT TOP 1 @nCartonNo = CartonNo FROM dbo.PackDetail WITH (NOLOCK)  
            WHERE PickSlipNo = @cPickSlipNo  
               AND LabelNo = @cLabelNo  
  
            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)  
            FROM PACKDETAIL WITH (NOLOCK)  
            WHERE PickSlipNo = @cPickSlipNo  
               AND LabelNo = @cLabelNo  
  
            INSERT INTO dbo.PackDetail  
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)  
            VALUES  
               (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nQTY_PD,  
               @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '')  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 77413  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackDtlFail  
               GOTO RollBackTran  
            END  
         END  
      END  

      /*--------------------------------------------------------------------------------------------------  
        
                                                Auto scan in  
        
      --------------------------------------------------------------------------------------------------*/  
      IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) 
                     WHERE PickSlipNo = @cPickSlipNo)
      BEGIN
         INSERT INTO dbo.PickingInfo  
         (PickSlipNo, ScanInDate, PickerID, ScanOutDate, AddWho)  
         VALUES  
         (@cPickSlipNo, GETDATE(), 'rdt.' + sUser_sName(), NULL, 'rdt.' + sUser_sName())  

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 77417  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SCAN IN FAIL  
            GOTO RollBackTran  
         END  
      END
      
      /*--------------------------------------------------------------------------------------------------  
        
                                                Auto pack confirm  
        
      --------------------------------------------------------------------------------------------------*/  
      DECLARE @nPackQTY INT  
        
      -- Get Pick QTY  
      SELECT @nPickQTY = ISNULL( SUM( PD.QTY), 0)  
      FROM dbo.PickDetail PD WITH (NOLOCK)   
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)  
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)  
      WHERE LPD.LoadKey = @cLoadKey  
         AND O.OrderKey = CASE WHEN @cOrderKey = '' THEN O.OrderKey ELSE @cOrderKey END  
         AND PD.Status <> '4'  
        
      -- Get Pack QTY  
      SELECT @nPackQTY = ISNULL( SUM( PD.QTY), 0)  
      FROM dbo.PackDetail PD WITH (NOLOCK)   
      WHERE PD.PickSlipNo = @cPickSlipNo  

      -- (james02)
      SELECT TOP 1 @cSOStatus = O.SOStatus  
      FROM dbo.PickDetail PD WITH (NOLOCK)   
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)  
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)  
      WHERE LPD.LoadKey = @cLoadKey  
         AND O.OrderKey = CASE WHEN @cOrderKey = '' THEN O.OrderKey ELSE @cOrderKey END  
         AND PD.Status <> '4'  
         
      -- Auto pack confirm  
      IF @nPickQTY = @nPackQTY AND @cSOStatus <> 'HOLD'   
      BEGIN  
         -- Trigger pack confirm      
         UPDATE dbo.PackHeader WITH (ROWLOCK) SET       
            STATUS = '9',       
            EditWho = 'rdt.' + sUser_sName(),      
            EditDate = GETDATE()      
         WHERE PickSlipNo = @cPickSlipNo    
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 77414  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail PackCfm  
            GOTO RollBackTran  
         END    

         IF EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)  
            WHERE PickSlipNo = @cPickSlipNo AND ScanOutDate IS NULL)  
         BEGIN  
            UPDATE dbo.PickingInfo WITH (ROWLOCK)  
               SET SCANOUTDATE = GETDATE(),  
                   EditWho = 'rdt.' + sUser_sName() 
            WHERE PickSlipNo = @cPickSlipNo  
            AND   ScanOutDate IS NULL

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 77418  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SCAN OUT FAIL  
               GOTO RollBackTran  
            END    
         END
      END  

      /*--------------------------------------------------------------------------------------------------  
        
                                                Insert Packinfo  
        
      --------------------------------------------------------------------------------------------------*/  
      
      SELECT TOP 1 @nCartonNo = CartonNo FROM dbo.PackDetail WITH (NOLOCK)  
      WHERE PickSlipNo = @cPickSlipNo  
         AND LabelNo = @cLabelNo  

      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) 
                     WHERE PickSlipNo = @cPickSlipNo
                     AND   CartonNo = @nCartonNo)
      BEGIN
         INSERT INTO dbo.PACKINFO (PickSlipNo, CartonNo, CartonType)  
         VALUES (@cPickSlipNo, @nCartonNo, @cCartonType)   
         
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 77415  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PINFO FAIL  
            GOTO RollBackTran  
         END    
      END
      ELSE
      BEGIN
         UPDATE dbo.PackInfo WITH (ROWLOCK) SET 
            CartonType = @cCartonType 
         WHERE PickSlipNo = @cPickSlipNo
         AND   CartonNo = @nCartonNo
         AND   ISNULL(CartonType, '') = ''

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 77416  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PINFO FAIL  
            GOTO RollBackTran  
         END    
      END
      
      FETCH NEXT FROM @curT INTO @cOrderKey, @cConsigneeKey, @cPickDetailKey, @nQTY_PD  
   END  

   GOTO Quit  
  
RollBackTran:  
      ROLLBACK TRAN rdt_SortAndPack_GOH_Confirm  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN  
END  

GO