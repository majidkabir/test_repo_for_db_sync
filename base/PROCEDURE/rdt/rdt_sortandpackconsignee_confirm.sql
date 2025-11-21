SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Store procedure: rdt_SortAndPackConsignee_Confirm                    */      
/* Copyright: IDS                                                       */      
/* Purpose: Merge UCC pallet                                            */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date       Ver  Author     Purposes                                  */      
/* 2020-11-05 1.0  Chermaine  WMS-15185 Created                         */     
/* 2021-06-30 1.1  James      WMS-17406 Add rdt_STD_EventLog (james01)  */  
/************************************************************************/      
      
CREATE PROCEDURE [RDT].[rdt_SortAndPackConsignee_Confirm]      
   @nMobile       INT,      
   @nFunc         INT,      
   @cLangCode     NVARCHAR( 3),      
   @cLoadKey      NVARCHAR( 10),      
   @cStorerKey    NVARCHAR( 15),      
   @cSKU          NVARCHAR( 20),      
   @cUCCNo        NVARCHAR( 20),      
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
   DECLARE @cPickStatus    NVARCHAR( 1)    
   DECLARE @cOrderKey      NVARCHAR( 10)    
   DECLARE @cConsigneeKey  NVARCHAR( 15)    
   DECLARE @cPackByType    NVARCHAR( 10)    
   DECLARE @cPackData      NVARCHAR( 1)    
   DECLARE @cWaveKey       NVARCHAR( 10)  
   DECLARE @cUserName      NVARCHAR( 18)    
   DECLARE @cBatchkey      NVARCHAR( 10)  
   DECLARE @cFacility      NVARCHAR( 5)  
     
   SET @nErrNo = 0      
   SET @cErrMsg = ''      
   SET @nPickQTY = @nQTY      
      
   DECLARE @tPD TABLE       
   (      
      PickDetailKey NVARCHAR(10) NOT NULL,      
      OrderKey      NVARCHAR(10) NOT NULL,      
      ConsigneeKey  NVARCHAR(15) NOT NULL,      
      QTY           INT          NOT NULL,      
      PackData      NVARCHAR( 1) NOT NULL     
   )      
      
   --SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerKey)    
   ----IF @cPickStatus = 0    
   ----BEGIN    
   ---- SET @cPickStatus = 3    
   ----END    
  
   SELECT   
      @cWaveKey = V_String1,   
      @cBatchkey= V_String2,  
      @cUserName = UserName,  
      @cFacility = Facility  
   FROM rdt.RDTMOBREC WITH (NOLOCK)  
   WHERE Mobile = @nMobile      
      
/*--------------------------------------------------------------------------------------------------      
      
                                           PickDetail line      
      
--------------------------------------------------------------------------------------------------*/      
   DECLARE @nTranCount INT      
   SET @nTranCount = @@TRANCOUNT      
   BEGIN TRAN      
   SAVE TRAN rdt_SortAndPackConsignee_Confirm      
      
   DECLARE @curPD CURSOR      
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT O.OrderKey, O.ConsigneeKey, PD.PickDetailKey, PD.QTY, ISNULL(W.Userdefine01,'0')     
      FROM dbo.PickDetail PD WITH (NOLOCK)      
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)    
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)      
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)      
         JOIN dbo.Wave W WITH (NOLOCK) ON (W.waveKey = PD.WaveKey)    
      WHERE LPD.LoadKey = @cLoadKey      
      AND PD.StorerKey = @cStorerKey      
         AND PD.SKU = @cSKU      
         AND PD.QTY > 0      
         AND PD.Status < '5'    
         AND PD.Status <> '4'     
         --AND O.ConsigneeKey = @cConsigneeKey      
         --AND O.OrderKey = @cOrderKey       
      ORDER BY PD.PickDetailKey      
      
   OPEN @curPD      
   FETCH NEXT FROM @curPD INTO @cOrderKey, @cConsigneeKey, @cPickDetailKey, @nQTY_PD, @cPackData    
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
            SET @nErrNo = 161051      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail      
            GOTO RollBackTran      
         END      
      
         INSERT INTO @tPD (PickDetailKey, OrderKey, ConsigneeKey, QTY, PackData) VALUES (@cPickDetailKey, @cOrderKey, @cConsigneeKey, @nQTY_PD, @cPackData)      
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
            SET @nErrNo = 161052      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail      
            GOTO RollBackTran      
         END      
      
         INSERT INTO @tPD (PickDetailKey, OrderKey, ConsigneeKey, QTY, PackData) VALUES (@cPickDetailKey, @cOrderKey, @cConsigneeKey, @nQTY_PD, @cPackData)     
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
            SET @nErrNo = 161053      
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
            Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,      
            DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,      
            @nQTY_PD - @nPickQty, -- QTY      
            NULL, --TrafficCop,      
            '1'  --OptimizeCop      
         FROM dbo.PickDetail WITH (NOLOCK)      
         WHERE PickDetailKey = @cPickDetailKey      
         IF @@ERROR <> 0      
         BEGIN      
            SET @nErrNo = 161054      
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
            SET @nErrNo = 161055      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail      
            GOTO RollBackTran      
         END      
      
         -- Pick confirm original line      
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET      
            Status = '5'      
         WHERE PickDetailKey = @cPickDetailKey      
         IF @@ERROR <> 0      
         BEGIN      
            SET @nErrNo = 161056      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail      
            GOTO RollBackTran      
         END      
      
         INSERT INTO @tPD (PickDetailKey, OrderKey, ConsigneeKey, QTY, PackData) VALUES (@cPickDetailKey, @cOrderKey, @cConsigneeKey, @nPickQty, @cPackData)      
         SET @nPickQty = 0 -- Reduce balance      
         BREAK      
      END      
      FETCH NEXT FROM @curPD INTO @cOrderKey, @cConsigneeKey, @cPickDetailKey, @nQTY_PD, @cPackData     
   END      
--select * from @tPD      
   IF @nPickQty <> 0      
   BEGIN      
      SET @nErrNo = 161057      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset Fail      
      GOTO RollBackTran      
   END      
  
   EXEC RDT.rdt_STD_EventLog  
      @cActionType   = '3', -- Picking    
      @cUserID       = @cUserName,    
      @nMobileNo     = @nMobile,    
      @nFunctionID   = @nFunc,    
      @cFacility     = @cFacility,    
      @cStorerKey    = @cStorerKey,    
      @cWaveKey      = @cWaveKey,    
      @cLabelNo      = @cLabelNo,  
      @cUCC          = @cUCCNo,    
      @cRefNo3       = @cBatchkey,  
      @nQTY          = @nQTY,  
      @cSKU          = @cSKU,  
      @cLoadKey      = @cLoadKey,  
      @cCartonType   = @cCartonType  
  
      
/*--------------------------------------------------------------------------------------------------      
      
                                      PackHeader, PackDetail line      
      
--------------------------------------------------------------------------------------------------*/      
   DECLARE @curT CURSOR      
   SET @curT = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT OrderKey, ConsigneeKey, PickDetailKey, QTY, PackData      
      FROM @tPD      
   OPEN @curT      
   FETCH NEXT FROM @curT INTO @cOrderKey, @cConsigneeKey, @cPickDetailKey, @nQTY_PD, @cPackData      
   WHILE @@FETCH_STATUS = 0      
   BEGIN      
      IF @cPackData = '1' --generate packHeader n detail line    
      BEGIN    
         -- Get PickSlipNo (PickHeader)      
         SET @cPickSlipNo = ''      
         SELECT @cPickSlipNo = PickHeaderKey      
         FROM dbo.PickHeader WITH (NOLOCK)      
         WHERE ExternOrderKey = @cLoadKey      
      
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
                     SET @nErrNo = 161058      
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
                  SET @nErrNo = 161059      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPKHdrFail      
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
               SET @nErrNo = 161060      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackDtlFail      
               GOTO RollBackTran      
            END      
         END      
         ELSE      
         BEGIN      
            -- Create new carton      
            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cLabelNo)      
            BEGIN      
   /*      
               -- Get new LabelNo      
               EXECUTE isp_GenUCCLabelNo      
                  @cStorerKey,      
                  @cLabelNo     OUTPUT,      
                  @b_Success    OUTPUT,      
                  @nErrNo       OUTPUT,      
                  @cErrMsg      OUTPUT      
               IF @b_Success <> 1      
               BEGIN      
                  SET @nErrNo = 77411      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GET LABEL Fail      
                  GOTO RollBackTran      
               END      
   */      
               INSERT INTO dbo.PackDetail      
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)      
               VALUES      
                  (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, @nQTY_PD, -- CartonNo = 0 and LabelLine = '0000', trigger will auto assign      
                  @cPickDetailKey, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '')      
               IF @@ERROR <> 0      
               BEGIN      
                  SET @nErrNo = 161061      
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
                  SET @nErrNo = 161062      
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
               SET @nErrNo = 161063      
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
         IF (@nPickQTY = @nPackQTY) AND @cSOStatus <> 'HOLD'   -- (james02)    
         BEGIN      
    -- Trigger pack confirm          
            UPDATE dbo.PackHeader WITH (ROWLOCK) SET           
               STATUS = '9',           
               EditWho = 'rdt.' + sUser_sName(),          
               EditDate = GETDATE()          
            WHERE PickSlipNo = @cPickSlipNo        
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 161064      
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
                  SET @nErrNo = 161065      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SCAN OUT FAIL      
                  GOTO RollBackTran      
               END        
            END    
         END      
    
         /*--------------------------------------------------------------------------------------------------      
            
                                                   Insert Packinfo      
            
         --------------------------------------------------------------------------------------------------*/      
          
         DECLARE @nPackDetailQty INT    
             
         SELECT @nCartonNo = CartonNo, @nPackDetailQty = SUM(QTY)     
         FROM dbo.PackDetail WITH (NOLOCK)      
         WHERE PickSlipNo = @cPickSlipNo      
         AND LabelNo = @cLabelNo    
         GROUP BY pickslipNo,LabelNo,cartonNo    
             
         --SELECT TOP 1 @nCartonNo = CartonNo FROM dbo.PackDetail WITH (NOLOCK)      
         --WHERE PickSlipNo = @cPickSlipNo      
         --   AND LabelNo = @cLabelNo      
            
         --SELECT @nPackDetailQty = SUM(QTY) FROM packDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo  AND LabelNo = @cLabelNo AND CartonNo = @nCartonNo     
    
         IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)     
                        WHERE PickSlipNo = @cPickSlipNo    
                        AND   CartonNo = @nCartonNo)    
         BEGIN    
            INSERT INTO dbo.PACKINFO (PickSlipNo, CartonNo, CartonType, QTY)      
            VALUES (@cPickSlipNo, @nCartonNo, @cCartonType, @nPackDetailQty)       
             
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 161066      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PINFO FAIL      
               GOTO RollBackTran      
            END        
         END    
         ELSE    
         BEGIN    
            UPDATE dbo.PackInfo WITH (ROWLOCK) SET     
               QTY = @nPackDetailQty    
            WHERE PickSlipNo = @cPickSlipNo    
            AND   CartonNo = @nCartonNo    
    
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 161067      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PINFO FAIL      
               GOTO RollBackTran      
            END        
         END       
      END      
      FETCH NEXT FROM @curT INTO @cOrderKey, @cConsigneeKey, @cPickDetailKey, @nQTY_PD, @cPackData      
   END      
    
   GOTO Quit      
      
RollBackTran:      
      ROLLBACK TRAN rdt_SortAndPackConsignee_Confirm      
Quit:      
   WHILE @@TRANCOUNT > @nTranCount      
      COMMIT TRAN      
END  

GO