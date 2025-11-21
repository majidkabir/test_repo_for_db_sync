SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_540SAPCfm01                                     */  
/* Copyright: IDS                                                       */  
/* Purpose: IDX Sort And Pack Confirm                                   */  
/*                                                                      */  
/* Called from: rdtfnc_SortAndPack                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Ver  Author   Purposes                                   */  
/* 2017-Mar-23 1.0  James    WMS907.Created                             */ 
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_540SAPCfm01]  
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
   @cUCCNo        NVARCHAR(20) = ''  -- (Chee01)

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
      SELECT @cActQty = I_Field06
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
   SAVE TRAN rdt_540SAPCfm01  
  
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
         AND O.OrderKey = CASE WHEN @cPackByType = 'CONSO' THEN O.OrderKey ELSE @cOrderKey END  
         AND (( @cPackByType = 'CONSO') OR ( O.OrderKey = @cOrderKey))
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
            DropID = @cDropID
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
            DropID = @cDropID
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
            DropID = @cDropID
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
      IF @cPackByType = 'CONSO'  
         SET @cOrderKey = ''  
  
      SET @cPSNO = ''

      -- Get PickSlipNo (PickHeader)  
      SELECT @cPSNO = PickHeaderKey  
      FROM dbo.PickHeader WITH (NOLOCK)  
      WHERE ExternOrderKey = @cLoadKey  
      AND   ((@cOrderKey = '') OR ( OrderKey = @cOrderKey))

      IF ISNULL( @cPSNO, '') = ''  
         -- Get PickSlipNo (PackHeader)  
         SELECT @cPSNO = PickSlipNo  
         FROM dbo.PackHeader WITH (NOLOCK)  
         WHERE LoadKey = @cLoadKey  
         AND   ((@cOrderKey = '') OR ( OrderKey = @cOrderKey))
         AND   ConsigneeKey = @cConsigneeKey

      IF @cPSNO <> ''  
         SET @cPickSlipNo = @cPSNO  
      ELSE  
      BEGIN  
         SET @cPickSlipNo = ''  

         -- New PickSlipNo  
         EXECUTE nspg_GetKey  
            'PICKSLIP',  
            9,  
            @cPickSlipNo OUTPUT,  
            @b_success   OUTPUT,  
            @nErrNo      OUTPUT,  
            @cErrMsg     OUTPUT  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 107459  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail  
            GOTO RollBackTran  
         END  
         SET @cPickSlipNo = 'P' + RTRIM( @cPickSlipNo)  
      END

      -- PackHeader  
      IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)  
      BEGIN  
         -- Insert PackHeader  
         INSERT INTO dbo.PackHeader  
            (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey, OrderRefNo, TtlCnts, [STATUS])  
         VALUES  
            (@cPickSlipNo, @cStorerkey, @cOrderkey, @cLoadKey, '99', @cConsigneeKey, '', 0, '0')  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 107460  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackHdrFail  
            GOTO RollBackTran  
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
            SET @nErrNo = 107461  
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
               @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID)  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 107462  
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
               @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID)  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 107463  
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
            SET @nErrNo = 107464  
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
      AND   (( @cOrderKey = '') OR ( O.OrderKey = @cOrderKey) ) 
      AND   PD.Status <> '4'  
        
      -- Get Pack QTY  
      SELECT @nPackQTY = ISNULL( SUM( PD.QTY), 0)  
      FROM dbo.PackDetail PD WITH (NOLOCK)   
      WHERE PD.PickSlipNo = @cPickSlipNo  
     
      -- Auto pack confirm  
      IF (@nPickQTY = @nPackQTY) AND @cAutoPackConfirm = '1'
      BEGIN  
         -- Trigger pack confirm      
         UPDATE dbo.PackHeader WITH (ROWLOCK) SET       
            STATUS = '9',       
            EditWho = 'rdt.' + sUser_sName(),      
            EditDate = GETDATE()      
         WHERE PickSlipNo = @cPickSlipNo    
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 107465  
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
               SET @nErrNo = 107466  
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
         INSERT INTO dbo.PACKINFO (PickSlipNo, CartonNo, CartonType, Qty)  
         VALUES (@cPickSlipNo, @nCartonNo, @cCartonType, @nQTY_PD)   
         
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 107467  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PINFO FAIL  
            GOTO RollBackTran  
         END    
      END
      -- Commented because packdetail add trigger already update
      /*ELSE
      BEGIN
         UPDATE dbo.PackInfo WITH (ROWLOCK) SET 
            CartonType = @cCartonType, 
            Qty = Qty + @nQTY_PD
         WHERE PickSlipNo = @cPickSlipNo
         AND   CartonNo = @nCartonNo
         AND   ISNULL(CartonType, '') = ''

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 107468  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PINFO FAIL  
            GOTO RollBackTran  
         END    
      END
      */

      /*--------------------------------------------------------------------------------------------------  
        
                                                Insert DropID  
        
      --------------------------------------------------------------------------------------------------*/  
      
      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cLabelNo)
      BEGIN
         INSERT INTO dbo.DropID 
         (DropID, LabelPrinted, ManifestPrinted, DropIDType, [Status], PickSlipNo, LoadKey, UDF01)
         VALUES 
         (@cLabelNo, '0', '0', @cCartonType, '0', @cPickSlipNo, @cLoadKey, @cConsigneeKey)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 107468
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DID FAIL'
            GOTO RollBackTran
         END
      END


      IF NOT EXISTS ( SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) 
                      WHERE DropID = @cLabelNo 
                      AND   ChildID = @cSKU)
      BEGIN
         INSERT INTO dbo.DropIDDetail 
         (DropID, ChildID)
         VALUES 
         (@cLabelNo, @cSKU)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 107469
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS DDTL FAIL'
            GOTO RollBackTran
         END
      END

      FETCH NEXT FROM @curT INTO @cOrderKey, @cConsigneeKey, @cPickDetailKey, @nQTY_PD  
   END  

   GOTO Quit  
  
RollBackTran:  
      ROLLBACK TRAN rdt_540SAPCfm01  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN  
END  

GO