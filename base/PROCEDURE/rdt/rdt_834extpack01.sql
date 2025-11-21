SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store procedure: rdt_834ExtPack01                                    */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Pick and pack confirm                                       */    
/*                                                                      */    
/* Called from: rdtfnc_CartonPack                                       */    
/*                                                                      */    
/* Date         Rev  Author   Purposes                                  */    
/* 2019-05-29   1.0  James    WMS9064. Created                          */    
/* 2019-08-29   1.1  Ung      WMS-9064 Add CartonManifest               */    
/* 2019-10-23   1.2  James    Bug fix (james01)                         */    
/* 2021-04-16   1.3  James    WMS-16024 Standarized use of TrackingNo   */
/*                            (james02)                                 */
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_834ExtPack01] (    
   @nMobile          INT,    
   @nFunc            INT,    
   @cLangCode        NVARCHAR( 3),    
   @cStorerKey       NVARCHAR( 15),    
   @cFacility        NVARCHAR( 5),     
   @tCfmPack         VariableTable READONLY,     
   @cPrintPackList   NVARCHAR( 1)   OUTPUT,    
   @cPickSlipNo      NVARCHAR( 10)  OUTPUT,    
   @nCartonNo        INT            OUTPUT,    
   @nErrNo           INT            OUTPUT,    
   @cErrMsg          NVARCHAR( 20)  OUTPUT    
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
    
   DECLARE @nTranCount     INT    
   DECLARE @cUOM           NVARCHAR( 10)    
   DECLARE @cZone          NVARCHAR( 10)    
   DECLARE @cPH_LoadKey    NVARCHAR( 10)    
   DECLARE @cLoadKey       NVARCHAR( 10)    
   DECLARE @nQTY_PD        INT    
   DECLARE @bSuccess       INT    
   DECLARE @n_err          INT    
   DECLARE @c_errmsg       NVARCHAR( 20)    
   DECLARE @cShipperKey    NVARCHAR( 15)    
   DECLARE @cPickConfirmStatus NVARCHAR( 1)    
   DECLARE @cSQL           NVARCHAR( MAX)    
   DECLARE @cSQLParam      NVARCHAR( MAX)    
   DECLARE @cRoute         NVARCHAR( 20)    
   DECLARE @cOrderRefNo    NVARCHAR( 18)    
   DECLARE @cConsigneekey  NVARCHAR( 15)    
   DECLARE @cLabelNo       NVARCHAR( 20)    
   DECLARE @cLabelLine     NVARCHAR( 5)    
   DECLARE @nRowCount      INT    
   DECLARE @cShipLabel     NVARCHAR( 10)    
   DECLARE @cCartonManifest NVARCHAR( 10)    
   DECLARE @cDelNotes      NVARCHAR( 10)    
   DECLARE @cPaperPrinter  NVARCHAR( 10)    
   DECLARE @cLabelPrinter  NVARCHAR( 10)    
   DECLARE @nQty           INT    
   DECLARE @nCtnQty        INT    
   DECLARE @nPackedQty     INT    
   DECLARE @nSum_Picked    INT    
   DECLARE @nSum_Packed    INT    
   DECLARE @cGenLabelNo_SP NVARCHAR( 20)    
   DECLARE @cDocLabel      NVARCHAR( 20)    
   DECLARE @cDocValue      NVARCHAR( 20)    
   DECLARE @cCtnLabel      NVARCHAR( 20)    
   DECLARE @cCtnValue      NVARCHAR( 20)    
   DECLARE @cOrderKey      NVARCHAR( 10)    
   DECLARE @cSKU           NVARCHAR( 20)    
   DECLARE @cPrintShipLbl  NVARCHAR( 60)    
   DECLARE @cUserName      NVARCHAR( 18)    
   DECLARE @cUpdatePickDetail NVARCHAR( 1)    
   DECLARE @cPickDetailKey NVARCHAR( 10)    
   DECLARE @cOrderLineNumber  NVARCHAR( 5)    
   DECLARE @tGenLabelNo    VARIABLETABLE    
   DECLARE @nStep          INT    
   DECLARE @nInputKey      INT    
   DECLARE @cITF           NVARCHAR( 60)    
   DECLARE @cTrackingNo    NVARCHAR( 20)    
   DECLARE @cExternOrderKey   NVARCHAR( 20)    
   DECLARE @cDocType       NVARCHAR( 1)    
   DECLARE @cPackConfirm   NVARCHAR( 1)    
    
    
   SET @nErrNo = 0    
   SET @cPrintPackList = 'N'    
    
   SELECT @cLabelPrinter = Printer,    
          @cPaperPrinter = Printer_Paper,    
          @cUserName = UserName    
   FROM RDT.RDTMOBREC WITH (NOLOCK)    
   WHERE Mobile = @nMobile    
    
   -- Variable mapping    
   SELECT @cDocLabel = Value FROM @tCfmPack WHERE Variable = '@cDocLabel'    
   SELECT @cDocValue = Value FROM @tCfmPack WHERE Variable = '@cDocValue'    
   SELECT @cCtnLabel = Value FROM @tCfmPack WHERE Variable = '@cCtnLabel'    
   SELECT @cCtnValue = Value FROM @tCfmPack WHERE Variable = '@cCtnValue'    
    
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)    
   IF @cPickConfirmStatus = '0'    
      SET @cPickConfirmStatus = '5'    
    
   SET @cUpdatePickDetail = rdt.RDTGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)     
    
   SELECT TOP 1 @cOrderKey = OrderKey,     
                @cOrderLineNumber = OrderLineNumber    
   FROM dbo.PickDetail PD WITH (NOLOCK)    
   WHERE StorerKey = @cStorerKey    
   AND   DropID = @cCtnValue    
   ORDER BY 1    
    
   SELECT @cLoadkey = LoadKey,     
          @cShipperKey = ShipperKey,    
          --@cTrackingNo = UserDefine04,    
          @cTrackingNo = TrackingNo,   -- (james02)
          @cExternOrderKey = ExternOrderKey,    
          @cDocType = DocType    
   FROM dbo.Orders WITH (NOLOCK)    
   WHERE OrderKey = @cOrderKey    
    
   SET @cPrintShipLbl = ''    
   SET @cITF = ''    
   SELECT @cPrintShipLbl = UDF01,     
          @cITF = UDF04    
   FROM dbo.CODELKUP WITH (NOLOCK)     
   WHERE ListName = 'BRCOURTYPE'    
   AND   Code = @cShipperKey    
   AND   StorerKey = @cStorerKey    
    
    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN    
   SAVE TRAN rdt_834ExtPack01    
    
   SET @cPickSlipNo = ''      
   SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey      
    
   IF @cPickSlipNo = ''      
      SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadkey      
    
   IF ISNULL( @cPickSlipNo, '') = ''    
   BEGIN    
      SET @nErrNo = 139301    
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --PickSlip req    
      GOTO RollBackTran      
   END    
    
   -- Insert PickingInfo    
   IF NOT EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickslipNo)    
   BEGIN    
      -- Scan in pickslip    
      EXEC dbo.isp_ScanInPickslip    
         @c_PickSlipNo  = @cPickSlipNo,    
         @c_PickerID    = @cUserName,    
         @n_err         = @nErrNo      OUTPUT,    
         @c_errmsg      = @cErrMsg     OUTPUT    
    
      IF @nErrNo <> 0    
      BEGIN    
         SET @nErrNo = 139313    
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Fail scan-in    
         GOTO RollBackTran    
      END    
   END    
    
   SELECT @cZone = Zone    
   FROM dbo.PickHeader WITH (NOLOCK)         
   WHERE PickHeaderKey = @cPickSlipNo      
    
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
         SET @nErrNo = 139302    
         SET @cErrMsg = rdt.rdtgetmessage( 66040, @cLangCode, 'DSP') --'InsPackHdrFail'    
         GOTO RollBackTran    
      END     
   END    
    
   SELECT @nPackedQty = ISNULL( SUM( Qty), 0)    
   FROM dbo.PackDetail WITH (NOLOCK)     
   WHERE PickSlipNo = @cPickSlipNo    
   AND   RefNo = @cCtnValue    
    
   SELECT @nQty = ISNULL( SUM( Qty), 0)    
   FROM dbo.PickDetail PD WITH (NOLOCK)    
   WHERE StorerKey = @cStorerKey    
   AND   DropID = @cCtnValue    
   AND   Status <> '4'    
   AND   Status < '5'    
   AND   UOM = '2'    
    
   IF @nPackedQty > @nQty    
   BEGIN    
      SET @nErrNo = 139315    
      SET @cErrMsg = rdt.rdtgetmessage( 66040, @cLangCode, 'DSP') --'Over Pack'    
      GOTO RollBackTran    
   END     
    
   DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT PickDetailKey, SKU, Qty    
   FROM dbo.PickDetail PD WITH (NOLOCK)    
   WHERE StorerKey = @cStorerKey    
   AND   DropID = @cCtnValue    
   AND   Status <> '4'    
   AND   Status < '5'    
   AND   UOM = '2'    
   ORDER BY 1    
   OPEN curPD    
   FETCH NEXT FROM curPD INTO @cPickDetailKey, @cSKU, @nQTY_PD    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      IF @cUpdatePickDetail = '1'    
      BEGIN    
        -- Exact match    
         IF @nQTY_PD = @nQty    
         BEGIN    
            -- Confirm PickDetail    
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
               Status = @cPickConfirmStatus    
            WHERE PickDetailKey = @cPickDetailKey    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 137153    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'    
               GOTO RollBackTran    
            END    
    
            SET @nQty = 0 -- Reduce balance    
         END    
         -- PickDetail have less    
         ELSE IF @nQTY_PD < @nQty    
         BEGIN    
            -- Confirm PickDetail    
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
               Status = @cPickConfirmStatus    
            WHERE PickDetailKey = @cPickDetailKey    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 137154    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'    
               GOTO RollBackTran    
            END    
            ELSE    
    
            SET @nQty = 0 -- Reduce balance    
         END    
         -- PickDetail have more, need to split    
         ELSE IF @nQTY_PD > @nQty    
         BEGIN    
            DECLARE @cNewPickDetailKey NVARCHAR( 10)    
            EXECUTE dbo.nspg_GetKey    
               'PICKDETAILKEY',    
               10 ,    
               @cNewPickDetailKey OUTPUT,    
               @bSuccess          OUTPUT,    
               @n_err             OUTPUT,    
               @c_errmsg          OUTPUT    
    
            IF @bSuccess <> 1    
            BEGIN    
               SET @nErrNo = 137155    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'GetDetKeyFail'    
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
               @nQTY_PD - @nQty, -- QTY    
               NULL, --TrafficCop,    
               '1'  --OptimizeCop    
            FROM dbo.PickDetail WITH (NOLOCK)    
            WHERE PickDetailKey = @cPickDetailKey    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 137156    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins PDtl Fail'    
               GOTO RollBackTran    
            END    
    
            IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)    
            BEGIN    
               INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)      
               VALUES (@cNewPickDetailKey, @cPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadkey)      
    
               IF @@ERROR <> 0      
               BEGIN      
                  SET @nErrNo = 137157      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail      
                  GOTO RollBackTran      
               END      
            END    
    
            -- Change orginal PickDetail with exact QTY (with TrafficCop)    
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
               QTY = @nQty,    
               EditDate = GETDATE(),    
               EditWho  = SUSER_SNAME(),    
               Trafficcop = NULL    
            WHERE PickDetailKey = @cPickDetailKey    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 137158    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'    
               GOTO RollBackTran    
            END    
    
            -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop    
            -- Change orginal PickDetail with exact QTY (with TrafficCop)    
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
               Status = @cPickConfirmStatus    
            WHERE PickDetailKey = @cPickDetailKey    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 137168    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'    
               GOTO RollBackTran    
            END    
    
            SET @nQty = 0 -- Reduce balance    
         END    
      END    
    
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)     
         WHERE PickSlipNo = @cPickSlipNo    
         AND   RefNo = @cCtnValue)    
      BEGIN    
         IF @cDocType = 'E'    
         BEGIN    
            -- Get current carton no    
            DECLARE @nCurrCartonNo INT    
            SELECT @nCurrCartonNo = ISNULL( MAX( CartonNo), 1)    
            FROM PackDetail WITH (NOLOCK)    
            WHERE PickSlipNo = @cPickslipNo    
               AND QTY > 0    
                
            EXEC isp_EPackCtnTrack03    
                @c_PickSlipNo = @cPickslipNo    
               ,@n_CartonNo   = @nCurrCartonNo -- Current CartonNo    
               ,@c_CTNTrackNo = @cLabelNo OUTPUT    
               ,@b_Success    = @bSuccess OUTPUT    
               ,@n_err        = @nErrNo   OUTPUT    
               ,@c_errmsg     = @cErrMsg  OUTPUT    
         END    
         ELSE    
         BEGIN    
            SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo_SP', @cStorerkey)    
            IF @cGenLabelNo_SP = '0'    
               SET @cGenLabelNo_SP = ''    
                
            IF @cGenLabelNo_SP <> ''    
            BEGIN    
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenLabelNo_SP AND type = 'P')      
               BEGIN    
                  SET @cSQL = 'EXEC dbo.' + RTRIM( @cGenLabelNo_SP) +    
                     ' @cPickslipNo, ' +      
                     ' @nCartonNo,   ' +      
                     ' @cLabelNo     OUTPUT '      
                  SET @cSQLParam =    
                     ' @cPickslipNo  NVARCHAR(10),       ' +      
                     ' @nCartonNo    INT,                ' +      
                     ' @cLabelNo     NVARCHAR(20) OUTPUT '      
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                     @cPickslipNo,     
                     @nCartonNo,     
                     @cLabelNo OUTPUT    
               END    
            END    
            ELSE    
            BEGIN       
               EXEC isp_GenUCCLabelNo    
                  @cStorerKey,    
                  @cLabelNo      OUTPUT,     
                  @bSuccess      OUTPUT,    
                  @nErrNo        OUTPUT,    
                  @cErrMsg       OUTPUT    
               IF @nErrNo <> 0    
               BEGIN    
                  SET @nErrNo = 137704    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail    
                  GOTO RollBackTran    
               END    
            END    
         END    
    
         INSERT INTO dbo.PackDetail    
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate)    
         VALUES    
            (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSKU, @nQTY_PD,    
            @cCtnValue, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 139304    
            SET @cErrMsg = rdt.rdtgetmessage( 66035, @cLangCode, 'DSP') --'InsPackDtlFail'    
    GOTO RollBackTran    
         END     
    
         -- 1 label 1 carton no    
        SELECT TOP 1 @nCartonNo = CartonNo    
         FROM dbo.PackDetail WITH (NOLOCK)     
         WHERE PickSlipNo = @cPickSlipNo    
         AND   LabelNo = @cLabelNo    
         ORDER BY 1     
      END -- DropID not exists    
      ELSE    
      BEGIN    
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)     
            WHERE PickSlipNo = @cPickSlipNo    
            AND   RefNo = @cCtnValue    
            AND   SKU = @cSKU)    
         BEGIN    
            SET @nCartonNo = 0    
    
            SET @cLabelNo = ''    
    
            SELECT @nCartonNo = CartonNo,     
                   @cLabelNo = LabelNo     
            FROM dbo.PackDetail WITH (NOLOCK)    
            WHERE Pickslipno = @cPickSlipNo    
            AND   RefNo = @cCtnValue    
    
            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)    
            FROM dbo.PackDetail WITH (NOLOCK)    
            WHERE Pickslipno = @cPickSlipNo    
            AND   CartonNo = @nCartonNo    
            AND   RefNo = @cCtnValue    
    
            INSERT INTO dbo.PackDetail    
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate)    
            VALUES    
               (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nQTY_PD,    
               @cCtnValue, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 139314    
               SET @cErrMsg = rdt.rdtgetmessage( 66036, @cLangCode, 'DSP') --'InsPackDtlFail'    
               GOTO RollBackTran    
            END     
         END    
         ELSE    
         BEGIN    
            -- 1 label 1 carton no    
            SELECT TOP 1 @nCartonNo = CartonNo,    
                         @cLabelNo = LabelNo,    
                         @cLabelLine = LabelLine    
            FROM dbo.PackDetail WITH (NOLOCK)     
            WHERE PickSlipNo = @cPickSlipNo    
            AND   RefNo = @cCtnValue    
            AND   SKU = @cSKU    
            ORDER BY 1     
    
            UPDATE dbo.PackDetail WITH (ROWLOCK) SET    
               QTY = QTY + @nQTY_PD,    
               EditWho = SUSER_SNAME(),    
               EditDate = GETDATE()    
            WHERE PickSlipNo = @cPickSlipNo    
            AND   CartonNo = @nCartonNo    
            AND   LabelNo = @cLabelNo    
            AND   LabelLine = @cLabelLine    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 139305    
               SET @cErrMsg = rdt.rdtgetmessage( 66037, @cLangCode, 'DSP') --'UpdPackDtlFail'    
               GOTO RollBackTran    
            END    
         END    
      END   -- DropID exists and SKU exists (update qty only)    
    
      -- PackInfo    
      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)    
      BEGIN    
         INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, UCCNo, QTY)    
         VALUES (@cPickSlipNo, @nCartonNo, @cCtnValue, @nQTY_PD)    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 139306    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail    
            GOTO RollBackTran    
         END    
      END    
      ELSE    
      BEGIN    
         UPDATE dbo.PackInfo SET    
            UCCNo = @cCtnValue,     
            EditDate = GETDATE(),     
            EditWho = SUSER_SNAME(),     
            TrafficCop = NULL    
         WHERE PickSlipNo = @cPickSlipNo    
            AND CartonNo = @nCartonNo    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 139307    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail    
            GOTO RollBackTran    
         END    
      END    
    
      IF @cUpdatePickDetail = '1' AND @nQty = 0    
         BREAK    
    
      FETCH NEXT FROM curPD INTO @cPickDetailKey, @cSKU, @nQTY_PD    
   END    
   CLOSE curPD    
   DEALLOCATE curPD    
    
   SET @nSum_Picked = 0    
    
   SET @nSum_Packed = 0    
   SELECT @nSum_Packed = ISNULL( SUM( Qty), 0)    
   FROM dbo.PackDetail PD WITH (NOLOCK)     
   WHERE PickSlipNo = @cPickSlipNo    
    
   SET @nSum_Picked = 0    
    
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
         SELECT @nSum_Picked = SUM( QTY)     
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)    
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)    
         WHERE RKL.PickSlipNo = @cPickSlipNo    
             
         IF @nSum_Picked <> @nSum_Packed    
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
         SELECT @nSum_Picked = SUM( PD.QTY)     
         FROM dbo.PickDetail PD WITH (NOLOCK)     
         WHERE PD.OrderKey = @cOrderKey    
             
         IF @nSum_Picked <> @nSum_Packed    
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
         SELECT @nSum_Picked = SUM( PD.QTY)     
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)     
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)    
         WHERE LPD.LoadKey = @cLoadKey    
             
         IF @nSum_Picked <> @nSum_Packed    
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
         SELECT @nSum_Picked = SUM( PD.QTY)     
         FROM PickDetail PD WITH (NOLOCK)     
         WHERE PD.PickSlipNo = @cPickSlipNo    
             
         IF @nSum_Picked <> @nSum_Packed    
            SET @cPackConfirm = 'N'    
      END    
   END    
    
   -- Insert carton track    
   --IF NOT EXISTS ( SELECT 1 FROM dbo.CartonTrack WITH (NOLOCK) WHERE TrackingNo = @cLabelNo AND CarrierName = @cTrackingNo)    
   --BEGIN    
   --   INSERT INTO dbo.CartonTrack     
   --      (TrackingNo, CarrierName, KeyName, Labelno, Carrierref1, Carrierref2)     
   --   VALUES     
  --      (@cLabelNo, @cTrackingNo, @cStorerKey, @cLabelNo, @cOrderKey, @cExternOrderKey)    
   --   IF @@ERROR <> 0    
   --   BEGIN    
   --      SET @nErrNo = 139308    
   --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins CtnTrk Fail    
   --      GOTO RollBackTran    
   --   END    
   --END    
    
   IF @cPackConfirm = 'Y'    
   BEGIN    
      DECLARE @curPackDtl CURSOR;    
      SET @curPackDtl = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
      SELECT DISTINCT LabelNo FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo;    
      OPEN @curPackDtl;    
      FETCH NEXT FROM @curPackDtl    
      INTO @cLabelNo;    
      WHILE @@Fetch_Status = 0    
      BEGIN    
          -- Carton track    
          INSERT INTO CartonTrack (TrackingNo, CarrierName, KeyName, LabelNo, CarrierRef1, CarrierRef2)    
          VALUES    
          (@cLabelNo, @cTrackingNo, @cStorerKey, @cLabelNo, @cOrderKey, @cExternOrderKey);    
          IF @nErrNo <> 0    
          BEGIN    
              SET @nErrNo = 140451;    
              SET @cErrMsg = RDT.rdtGetMessage(@nErrNo, @cLangCode, 'DSP'); -- INS CTNTrkFail    
              GOTO RollBackTran;    
          END;    
          FETCH NEXT FROM @curPackDtl    
          INTO @cLabelNo;    
      END;    
    
      SET @cPrintPackList = 'Y'    
    
      UPDATE dbo.PackHeader WITH (ROWLOCK) SET     
         [Status] = '9'    
      WHERE PickSlipNo = @cPickSlipNo    
      AND   [Status] < '9'    
    
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 139309    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail    
         GOTO RollBackTran    
      END    
    
      SET @nErrNo = 0    
      EXEC isp_ScanOutPickSlip    
         @c_PickSlipNo  = @cPickSlipNo,    
         @n_err         = @nErrNo OUTPUT,    
         @c_errmsg      = @cErrMsg OUTPUT    
    
      IF @nErrNo <> 0    
      BEGIN    
         SET @nErrNo = 139310    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan Out Fail    
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
  
      IF @cITF = 'ITF'    
      BEGIN    
         UPDATE dbo.Orders WITH (ROWLOCK) SET    
            SOStatus = 'PENDGET'    
         WHERE OrderKey = @cOrderKey    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 139311    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd SOStat Fail    
            GOTO RollBackTran    
         END    
      END    
      ELSE    
      BEGIN    
         UPDATE dbo.Orders WITH (ROWLOCK) SET    
            SOStatus = '5'    
         WHERE OrderKey = @cOrderKey    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 139312    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd SOStat Fail    
            GOTO RollBackTran    
         END    
      END    
   END    
    
   GOTO Quit    
    
   RollBackTran:    
      ROLLBACK TRAN rdt_834ExtPack01    
    
   Quit:    
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
         COMMIT TRAN rdt_834ExtPack01    
    
   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)    
   IF @cShipLabel = '0'    
      SET @cShipLabel = ''    
    
   IF @cShipLabel <> ''    
   BEGIN    
      IF @cPrintShipLbl = 'Y'    
      BEGIN    
         SET @nErrNo = 0    
         DECLARE @tSHIPPLABEL AS VariableTable    
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)    
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cUCCNo',       @cDocValue)    
    
         -- Print label    
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 2, 1, @cFacility, @cStorerkey, @cLabelPrinter, '',     
            @cShipLabel, -- Report type    
            @tSHIPPLABEL, -- Report params    
            'rdt_834ExtPack01',     
            @nErrNo  OUTPUT,    
            @cErrMsg OUTPUT     
      END    
   END    
    
   SET @cCartonManifest = rdt.RDTGetConfig( @nFunc, 'CartonManifest', @cStorerKey)    
   IF @cCartonManifest = '0'    
      SET @cCartonManifest = ''    
          
   -- Carton manifest    
   IF @cCartonManifest <> ''    
   BEGIN    
      -- Common params    
      DECLARE @tCartonManifest AS VariableTable    
      INSERT INTO @tCartonManifest (Variable, Value) VALUES     
         ( '@cPickSlipNo',    @cPickSlipNo),     
         ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))    
    
      -- Print label    
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 2, 1, @cFacility, @cStorerKey, @cLabelPrinter, '',     
         @cCartonManifest, -- Report type    
         @tCartonManifest, -- Report params    
         'rdt_834ExtPack01',     
         @nErrNo  OUTPUT,    
         @cErrMsg OUTPUT    
   END    
       
Fail:    
    
END 

GO