SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_840ExtUpd02                                     */  
/* Purpose: If Orders.UserDefine04 already have value and               */  
/*        i. There are same value, no need update to Orders.UserDefine04*/  
/*        ii. There are different value, prompt ôINV TRACK NOö          */  
/*        iii. else update Orders.UserDefine04 is it is blank value     */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2015-10-29 1.0  James      SOS356004 - Created                       */  
/* 2020-08-03 1.1  James      WMS-14457 Renew tracking no for certain   */  
/*                            carton type (james01)                     */  
/* 2020-12-17 1.2  James      WMS-15901 Add PreDelNote print (james02)  */  
/* 2021-04-01 1.3  YeeKung    WMS-16717 Add serialno and serialqty      */  
/*                            Params (yeekung01)                        */  
/* 2021-04-16 1.4  James      WMS-16024 Standarized use of TrackingNo   */  
/*                            (james03)                                 */  
/* 2022-07-05 1.5  James      WMS-20115 Assign trackno to packinfo for  */  
/*                            certain ordergroup (james04)              */  
/* 2022-10-11 1.6  James      WMS-20920 Change stamp tracking no to     */  
/*                            packinfo carton by carton (james05)       */  
/* 2022-11-01 1.7  James      Bug fix add orderkey filter (james06)     */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_840ExtUpd02] (  
   @nMobile     INT,  
   @nFunc       INT,   
   @cLangCode   NVARCHAR( 3),   
   @nStep       INT,   
   @nInputKey   INT,   
   @cStorerkey  NVARCHAR( 15),   
   @cOrderKey   NVARCHAR( 10),   
   @cPickSlipNo NVARCHAR( 10),   
   @cTrackNo    NVARCHAR( 20),   
   @cSKU        NVARCHAR( 20),   
   @nCartonNo   INT,  
   @cSerialNo   NVARCHAR( 30),   
   @nSerialQTY  INT,     
   @nErrNo      INT           OUTPUT,   
   @cErrMsg     NVARCHAR( 20) OUTPUT  
)  
AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @cUserDefine04     NVARCHAR( 20)  
   DECLARE @cCartonType       NVARCHAR( 10)  
   DECLARE @cCarrierName      NVARCHAR( 30)     
   DECLARE @cKeyName          NVARCHAR( 30)  
   DECLARE @cNewTrackingNo    NVARCHAR( 20)  
   DECLARE @cCurTrackingNo    NVARCHAR( 20)  
   DECLARE @cShipperKey       NVARCHAR( 15)  
   DECLARE @cLabelPrinter     NVARCHAR( 10)  
   DECLARE @cFacility         NVARCHAR( 5)  
   DECLARE @cPickDetailKey    NVARCHAR( 10)  
   DECLARE @cLabelNo          NVARCHAR( 20)  
   DECLARE @cLabelLine        NVARCHAR( 5)  
   DECLARE @cShipLabel        NVARCHAR( 10)  
   DECLARE @cNekopostLabel    NVARCHAR( 10)  
   DECLARE @nTranCount        INT  
  
   DECLARE @cPreDelNote       NVARCHAR( 10)  -- (james02)  
   DECLARE @cPaperPrinter     NVARCHAR( 10)  -- (james02)  
   DECLARE @cOrderGroup       NVARCHAR( 20)  
   DECLARE @cTrackingNo       NVARCHAR( 20)  
   DECLARE @nPackInfCtnNo     INT = 0  
   DECLARE @curPackInfo       CURSOR  
  
   SELECT @cCartonType = I_Field04,  
          @cFacility = Facility,   
          @cLabelPrinter = Printer,  
          @cPaperPrinter = Printer_Paper   
   FROM rdt.RDTMOBREC WITH (NOLOCK)   
   WHERE Mobile = @nMobile  
        
   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 1  
      BEGIN  
         IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)  
                     WHERE StorerKey = @cStorerkey  
                     AND   DocType = 'E'  
                     AND   UserDefine01 = 'VC30'  
                     AND   OrderKey = @cOrderKey)  -- (james06)  
         BEGIN  
            SET @cPreDelNote = rdt.RDTGetConfig( @nFunc, 'PreDelNote', @cStorerKey)  
            IF @cPreDelNote = '0'  
               SET @cPreDelNote = ''     
  
            IF @cPreDelNote <> ''  
            BEGIN    
               DECLARE @tDELNOTES AS VariableTable    
               INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)    
               INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cLoadKey',     '')    
               INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cType',        '')    
    
               -- Print label    
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter,     
                  @cPreDelNote,  -- Report type    
                  @tDELNOTES,    -- Report params    
                  'rdt_840ExtUpd02',     
                  @nErrNo     OUTPUT,    
                  @cErrMsg    OUTPUT     
            END    
         END  
      END  
        
      IF @nStep = 2  
      BEGIN  
         IF ISNULL( @cTrackNo, '') = ''  
         BEGIN  
            SET @nErrNo = 94801  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NO TRACK NO'  
            GOTO Quit  
         END  
                       
         --SELECT @cUserDefine04 = UserDefine04   
         SELECT @cUserDefine04 = TrackingNo -- (james02)  
         FROM dbo.Orders WITH (NOLOCK)   
         WHERE Orderkey = @cOrderKey  
         AND   Storerkey = @cStorerKey  
  
         IF ISNULL( @cUserDefine04, '') <> ''  
         BEGIN  
            IF @cUserDefine04 <> @cTrackNo  
            BEGIN  
               SET @nErrNo = 94802  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INV TRACK NO'  
               GOTO Quit  
            END  
         END  
         ELSE  
         BEGIN  
            UPDATE dbo.Orders WITH (ROWLOCK) SET  
               --UserDefine04 = @cTrackNo, TrafficCop = NULL  
               TrackingNo = @cTrackNo, TrafficCop = NULL -- (james03)  
            WHERE Orderkey = @cOrderKey  
            AND   Storerkey = @cStorerKey  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 94803  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Track Fail'  
               GOTO Quit  
            END  
         END  
      END   -- @nStep = 2  
        
      IF @nStep = 4  
      BEGIN  
         SELECT   
            @cShipperKey = ShipperKey,   
            @cOrderGroup = OrderGroup  
         FROM dbo.ORDERS WITH (NOLOCK)  
         WHERE OrderKey = @cOrderKey  
  
         SET @nTranCount = @@TRANCOUNT  
         BEGIN TRAN  -- Begin our own transaction  
         SAVE TRAN rdt_840ExtUpd02 -- For rollback or commit only our own transaction  
  
         -- (james04)/(james05)  
         -- Reset tracking no  
         SET @cTrackingNo = ''  
  
         IF @nCartonNo = 1  
          SELECT @cTrackingNo = TrackingNo  
          FROM dbo.ORDERS WITH (NOLOCK)  
          WHERE OrderKey = @cOrderKey  
         ELSE  
         BEGIN  
          SELECT @cTrackingNo = LabelNo  
          FROM dbo.PackDetail WITH (NOLOCK)  
          WHERE PickSlipNo = @cPickSlipNo  
          AND   CartonNo = @nCartonNo  
         END  
         --SELECT @cTrackingNo = TrackingNo  
         --FROM dbo.CartonTrack WITH (NOLOCK)  
         --WHERE LabelNo = @cOrderKey  
         --AND   CarrierRef1 = @cOrderKey + CAST( @nPackInfCtnNo AS NVARCHAR( 1))  
                
         UPDATE dbo.PackInfo SET  
          TrackingNo = @cTrackingNo,   
          EditWho = SUSER_SNAME(),   
          EditDate = GETDATE()  
         WHERE PickSlipNo = @cPickSlipNo  
         AND   CartonNo = @nCartonNo  
  
         IF @@ERROR <> 0    
         BEGIN        
            SET @nErrNo = 94828        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PACKINF Er'        
            GOTO RollBackTran        
         END   
           
         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)   
                     WHERE LISTNAME = 'FJNekoPack'  
                     AND   Storerkey = @cStorerkey  
                     AND   Code = @cCartonType)  
         BEGIN  
            SELECT @cCarrierName = short,     
                   @cKeyName = Long    
            FROM dbo.Codelkup WITH (NOLOCK)    
            WHERE Listname = 'AsgnTNo'     
            AND   Code = '3'     
            AND   StorerKey = @cStorerKey    
    
            SELECT @cNewTrackingNo = MIN( TrackingNo)    
            FROM dbo.CartonTrack WITH (NOLOCK)    
            WHERE CarrierName = @cCarrierName     
            AND   Keyname = @cKeyName     
            AND   ISNULL( CarrierRef2, '') = ''    
  
            IF ISNULL( @cNewTrackingNo, '') = ''    
            BEGIN        
               SET @nErrNo = 94804        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NO TRACKING #'        
               GOTO RollBackTran        
            END     
  
            SELECT @cCurTrackingNo = LabelNo  
            FROM dbo.PackDetail WITH (NOLOCK)  
            WHERE PickSlipNo = @cPickSlipNo  
            AND   CartonNo = @nCartonNo  
              
            -- Lock new Tracking no    
            UPDATE dbo.CartonTrack WITH (ROWLOCK) SET     
               LabelNo = @cOrderKey,      
               Carrierref2 = 'GET'    
            WHERE CarrierName = @cCarrierName     
            AND   Keyname = @cKeyName     
            AND   CarrierRef2 = ''    
            AND   TrackingNo = @cNewTrackingNo    
    
            IF @@ERROR <> 0    
            BEGIN        
               SET @nErrNo = 94805        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ASSIGN TRACK# Err'        
               GOTO RollBackTran        
            END     
              
            -- Release current tracking no  
            UPDATE dbo.CartonTrack WITH (ROWLOCK) SET     
               LabelNo = '',      
               Carrierref2 = ''    
            WHERE CarrierName = @cCarrierName     
            AND   Keyname = @cKeyName     
            AND   CarrierRef2 = 'GET'    
            AND   TrackingNo = @cCurTrackingNo  
            AND   LabelNo = @cOrderKey    
    
            IF @@ERROR <> 0    
            BEGIN        
               SET @nErrNo = 94806        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'RELEASE TRACK# Err'        
               GOTO RollBackTran        
            END     
  
            UPDATE dbo.ORDERS SET   
               TrackingNo = @cNewTrackingNo,   
               UserDefine04 = @cNewTrackingNo,   
               ShipperKey = @cCarrierName,  
               EditDate = GETDATE(),  
               EditWho = SUSER_SNAME()  
            WHERE OrderKey = @cOrderKey  
  
            IF @@ERROR <> 0    
            BEGIN        
               SET @nErrNo = 94807        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD Orders Err'        
               GOTO RollBackTran        
            END     
  
            DECLARE @cur_UpdPickDtl CURSOR   
            SET @cur_UpdPickDtl = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
            SELECT PickDetailKey  
            FROM dbo.PICKDETAIL WITH (NOLOCK)  
            WHERE OrderKey = @cOrderKey   
            AND   CaseID = @cCurTrackingNo  
            AND   Storerkey = @cStorerkey  
            AND   [Status] < '9'  
            OPEN @cur_UpdPickDtl  
            FETCH NEXT FROM @cur_UpdPickDtl INTO @cPickDetailKey  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
                 
               UPDATE dbo.PICKDETAIL SET   
                  CaseID = @cNewTrackingNo,  
                  EditDate = GETDATE(),  
                  EditWho = SUSER_SNAME()  
               WHERE PickDetailKey = @cPickDetailKey  
  
               IF @@ERROR <> 0    
               BEGIN        
                  SET @nErrNo = 94808        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PKDTL Err'        
                  GOTO RollBackTran        
               END     
  
               FETCH NEXT FROM @cur_UpdPickDtl INTO @cPickDetailKey  
            END  
  
            DECLARE @cur_UpdPackDtl CURSOR   
            SET @cur_UpdPackDtl = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
            SELECT LabelNo, LabelLine  
            FROM dbo.PACKDETAIL WITH (NOLOCK)  
            WHERE PickSlipNo = @cPickSlipNo   
            AND   CartonNo = @nCartonNo  
            OPEN @cur_UpdPackDtl  
            FETCH NEXT FROM @cur_UpdPackDtl INTO @cLabelNo, @cLabelLine  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
                 
               UPDATE dbo.PACKDETAIL SET   
                  LabelNo = @cNewTrackingNo,  
                  EditDate = GETDATE(),  
                  EditWho = SUSER_SNAME()  
               WHERE PickSlipNo = @cPickSlipNo  
               AND   CartonNo = @nCartonNo  
               AND   LabelNo = @cLabelNo  
               AND   LabelLine = @cLabelLine  
  
               IF @@ERROR <> 0    
               BEGIN        
                  SET @nErrNo = 94809        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PKDTL Err'        
                  GOTO RollBackTran        
               END     
  
               FETCH NEXT FROM @cur_UpdPackDtl INTO @cLabelNo, @cLabelLine  
            END  
  
            SET @cNekopostLabel = rdt.RDTGetConfig( @nFunc, 'NekopostLabel', @cStorerKey)  
            IF @cNekopostLabel = '0'  
               SET @cNekopostLabel = ''  
  
            IF @cNekopostLabel <> ''  
            BEGIN  
               DECLARE @tNekopost AS VariableTable  
               INSERT INTO @tNekopost (Variable, Value) VALUES ( '@cStorerKey',  @cStorerKey)  
               INSERT INTO @tNekopost (Variable, Value) VALUES ( '@cOrderKey',   @cOrderKey)  
               INSERT INTO @tNekopost (Variable, Value) VALUES ( '@nCartonNo',   @nCartonNo)  
               INSERT INTO @tNekopost (Variable, Value) VALUES ( '@cShipperKey',  @cCarrierName)  
  
               -- Print label  
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 2, 1, @cFacility, @cStorerkey, @cLabelPrinter, '',   
                  @cNekopostLabel, -- Report type  
                  @tNekopost, -- Report params  
                  'rdt_840ExtUpd02',   
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT   
  
               IF @nErrNo <> 0  
                  GOTO RollBackTran  
            END  
  
         END  
         ELSE  
         BEGIN  
            SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'FJShipLabel', @cStorerKey)  
            IF @cShipLabel = '0'  
               SET @cShipLabel = ''  
  
            IF @cShipLabel <> ''  
            BEGIN  
               DECLARE @tSHIPPLABEL AS VariableTable  
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cStorerKey',  @cStorerKey)  
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',   @cOrderKey)  
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nCartonNo',   @nCartonNo)  
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cShipperKey',  @cShipperKey)  
  
               -- Print label  
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 2, 1, @cFacility, @cStorerkey, @cLabelPrinter, '',   
                  @cShipLabel, -- Report type  
                  @tSHIPPLABEL, -- Report params  
                  'rdt_840ExtUpd02',   
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT  
                 
               IF @nErrNo <> 0  
                  GOTO RollBackTran  
            END  
         END  
  
         COMMIT TRAN rdt_840ExtUpd02  
  
         GOTO Commit_Tran  
  
         RollBackTran:  
            ROLLBACK TRAN rdt_840ExtUpd02 -- Only rollback change made here  
         Commit_Tran:  
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
               COMMIT TRAN  
      END  
   END  
  
   Quit:    

GO