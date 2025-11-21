SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Store procedure: rdt_841ExtUpdSP03                                   */        
/* Copyright      : LF                                                  */        
/*                                                                      */        
/* Purpose: Eagle Replen To Logic                                       */        
/*                                                                      */        
/* Modifications log:                                                   */        
/* Date        Rev  Author   Purposes                                   */        
/* 2015-09-26  1.0  ChewKP   SOS#353352 Created                         */        
/* 2015-10-28  1.1  ChewKP   SOS#355775 Add Orders.PrintFlag validation */  
/*                           (ChewKP01)                                 */
/* 2020-05-19  1.2  YeeKung  WMS-13131 Add Cartontype param(yeekung01)  */   
/* 2020-09-05  1.3  James    WMS-15010 Add AutoMBOLPack (james01)       */
/* 2021-04-01  1.4  YeeKung  WMS-16718 Add serialno and serialqty       */
/*                           Params (yeekung02)                         */
/* 2021-07-27  1.5  Chermain WMS-17410 Add VariableTable Param (cc01)   */
/************************************************************************/        
        
CREATE PROC [RDT].[rdt_841ExtUpdSP03] (        
   @nMobile       INT,        
   @nFunc         INT,        
   @cLangCode     NVARCHAR( 3),        
   @cUserName     NVARCHAR( 15),        
   @cFacility     NVARCHAR( 5),        
   @cStorerKey    NVARCHAR( 15),        
   @cDropID       NVARCHAR( 20),        
   @cSKU          NVARCHAR( 20),      
   @nStep         INT,      
   @cPickslipNo   NVARCHAR( 10),      
   @cPrevOrderkey NVARCHAR(10),      
   @cTrackNo      NVARCHAR( 20),    
   @cTrackNoFlag  NVARCHAR(1)   OUTPUT,      
   @cOrderKeyOut  NVARCHAR(10)  OUTPUT,    
   @nErrNo        INT           OUTPUT,        
   @cErrMsg       NVARCHAR( 20) OUTPUT,  -- screen limitation, 20 char max   
   @cCartonType   NVARCHAR( 20) ='',      --(yeekung01)
   @cSerialNo     NVARCHAR( 30), 
   @nSerialQTY    INT,
   @tExtUpd       VariableTable READONLY 
) AS        
BEGIN        
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
      
   DECLARE @nTranCount        INT      
          ,@nSUM_PackQTY      INT      
          ,@nSUM_PickQTY      INT      
          ,@cOrderKey         NVARCHAR(10)      
          ,@bsuccess          INT         
          ,@nCartonNo         INT      
          ,@cLabelLine        NVARCHAR( 5)        
          ,@cLabelNo          NVARCHAR(20)        
          ,@cPackSku          NVARCHAR(20)        
          ,@nPackQty          INT        
          ,@nTotalPackQty     INT        
          ,@nTotalPickQty     INT        
          ,@nTTL_PickedQty    INT                     
          ,@nTTL_PackedQty    INT          
          ,@cDropIDType       NVARCHAR(10)       
          ,@cGenTrackNoSP     NVARCHAR(30)       
          ,@cGenLabelNoSP     NVARCHAR(30)      
          ,@cExecStatements   NVARCHAR(4000)         
          ,@cExecArguments    NVARCHAR(4000)      
          ,@cRDTBartenderSP   NVARCHAR(30)      
          ,@cLabelPrinter     NVARCHAR(10)      
          ,@cLoadKey          NVARCHAR(10)      
          ,@cPaperPrinter     NVARCHAR(10)      
          ,@cDataWindow       NVARCHAR(50)      
          ,@cTargetDB         NVARCHAR(20)       
          ,@cOrderType        NVARCHAR(10)      
          ,@cShipperKey       NVARCHAR(10)      
          ,@cWCS              NVARCHAR(1)      
          ,@cPrinter02        NVARCHAR(10)    
          ,@cBrand01          NVARCHAR(10)    
          ,@cBrand02          NVARCHAR(10)    
          ,@cPrinter01        NVARCHAR(10)    
          ,@cSectionKey       NVARCHAR(10)      
          ,@cSOStatus         NVARCHAR(10)    
          ,@cFileName         NVARCHAR( 50)          
          ,@cFilePath         NVARCHAR( 30)       
          ,@cPrintFilePath    NVARCHAR(100)      
          ,@cPrintCommand     NVARCHAR(MAX)    
          ,@cWinPrinter       NVARCHAR(128)  
          ,@cPrinterName      NVARCHAR(100)   
          ,@cAutoMBOLPack     NVARCHAR( 1)   -- (james01)
       
         
         
   SET @nErrNo   = 0        
   SET @cErrMsg  = ''       
   SET @cWCS     = ''      
   SET @cTrackNoFlag = '0'    
   SET @cOrderKeyOut = ''    
   SET @cBrand01     = ''    
   SET @cBrand02     = ''    
   SET @cPrinter02   = ''    
   SET @cPrinter01   = ''    
   SET @cSectionKey  = ''      
       
         
   SELECT @cWCS = SValue       
   FROM dbo.StorerConfig WITH (NOLOCK)      
   WHERE ConfigKey = 'WCS'       
   AND StorerKey = @cStorerKey      
         
         
   SET @nTranCount = @@TRANCOUNT      
         
   BEGIN TRAN      
   SAVE TRAN rdt_841ExtUpdSP03      
         
  
      
   SELECT @cLabelPrinter = Printer       
         ,@cPaperPrinter = Printer_Paper      
   FROM rdt.rdtMobRec WITH (NOLOCK)      
   WHERE Mobile = @nMobile      
         
         
   IF @nStep = 2      
   BEGIN      
      
      SET @cGenLabelNoSP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo', @cStorerkey)          
             
            
      IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = ISNULL(RTRIM(@cGenLabelNoSP),'') AND type = 'P')        
      BEGIN      
                    
            SET @nErrNo = 94670      
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'GenLblSPNotFound'      
            --SET @cErrMsg = 'GenLblSPNotFound'      
            GOTO RollBackTran      
      END      
      
            
      -- check if sku exists in tote        
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)       
                      WHERE ToteNo = @cDropID       
                      AND SKU = @cSKU         
                      AND AddWho = @cUserName       
                      AND Status IN ('0', '1') )        
      BEGIN        
          SET @nErrNo = 94655        
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKuNotIntote        
          GOTO RollBackTran          
      END       
            
            
            
             
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)       
                      WHERE ToteNo = @cDropID       
                      AND ExpectedQty > ScannedQty       
                      AND Status < '5'        
                      AND Orderkey = @cPrevOrderkey         
                      AND AddWho = @cUserName)      
      BEGIN          
          SET @cOrderkey = ''        
      END        
      ELSE        
      BEGIN        
          SET @cOrderkey = @cPrevOrderkey        
      END       
            
      
            
      IF ISNULL(RTRIM(@cOrderkey),'') = ''        
      BEGIN        
         -- processing new order        
         SELECT @cOrderkey   = MIN(RTRIM(ISNULL(Orderkey,'')))        
         FROM rdt.rdtECOMMLog WITH (NOLOCK)         
         WHERE ToteNo = @cDropID         
         AND   Status IN ('0', '1')        
         AND   Sku = @cSKU                  
         AND   AddWho = @cUserName      
      
      END        
      ELSE        
      BEGIN        
         IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)       
                        WHERE ToteNo = @cDropID         
                        AND Orderkey = @cOrderkey       
                        AND SKU = @cSKU       
                        AND Status < '5'       
                        AND AddWho = @cUserName)        
         BEGIN        
            SET @nErrNo = 94656        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInOrder        
            GOTO RollBackTran           
         END              
      END        
            
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)       
                     WHERE ToteNo = @cDropID         
                     AND Orderkey = @cOrderkey       
                     AND SKU = @cSKU       
                     AND ExpectedQty > ScannedQty        
                     AND Status < '5'       
                     AND AddWho = @cUserName)        
      BEGIN        
         SET @nErrNo = 94657        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QtyExceeded        
         GOTO RollBackTran          
      END       
            
      
      /***************************        
      UPDATE rdtECOMMLog        
      ****************************/        
      UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)        
      SET   ScannedQty  = ScannedQty + 1,        
            Status      = '1'    -- in progress        
      WHERE ToteNo      = @cDropID        
      AND   Orderkey    = @cOrderkey        
      AND   Sku         = @cSku        
      AND   Status      < '5'        
      AND   AddWho = @cUserName      
         
      IF @@ERROR <> 0        
      BEGIN        
         SET @nErrNo = 94658        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'        
         GOTO RollBackTran           
      END        
            
      /****************************        
       CREATE PACK DETAILS         
      ****************************/        
      -- check is order fully despatched for this tote        
      
      
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)       
                     WHERE ToteNo = @cDropID         
                     AND Orderkey = @cOrderkey       
                     AND ExpectedQty > ScannedQty       
                     AND Status < '5'      
                     AND AddWho = @cUserName)        
      BEGIN        
      
            
      
         IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Orderkey = @cOrderkey)        
         BEGIN        
       
      
            IF NOT EXISTS (SELECT 1 FROM dbo.PickHeader WITH (NOLOCK) WHERE Orderkey = @cOrderkey)        
            BEGIN        
               /****************************        
                PICKHEADER        
               ****************************/        
      
           
               IF ISNULL(@cPickSlipNo,'') = ''        
               BEGIN        
                  EXECUTE dbo.nspg_GetKey        
                  'PICKSLIP',        
                  9,        
                  @cPickslipno OUTPUT,        
                  @bsuccess   OUTPUT,        
                  @nerrNo     OUTPUT,        
                  @cerrmsg    OUTPUT        
               
                  SET @cPickslipno = 'P' + @cPickslipno        
               END        
      
                     
           
               INSERT INTO dbo.PICKHEADER (PickHeaderKey, Storerkey, Orderkey, PickType, Zone, TrafficCop, AddWho, AddDate, EditWho, EditDate)        
               VALUES (@cPickSlipNo, @cStorerkey, @cOrderKey, '0', 'D', '', sUser_sName(), GETDATE(), sUser_sName(), GETDATE())        
               IF @@ERROR <> 0        
               BEGIN        
                  SET @nErrNo = 94659        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPickHdrFail'        
                  GOTO RollBackTran        
               END        
               ELSE        
               BEGIN        
                  UPDATE dbo.PICKDETAIL WITH (ROWLOCK)        
                  SET  PICKSLIPNO = @cPickslipno,         
                       Trafficcop = NULL        
                  WHERE StorerKey = @cStorerKey      
                  AND   Orderkey = @cOrderKey        
                  AND   Status = '5'        
                  AND   ISNULL(RTrim(Pickslipno),'') = ''        
           
                  IF @@ERROR <> 0        
                  BEGIN        
                     SET @nErrNo = 94660        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDetFail'        
                     GOTO RollBackTran        
                  END        
               END        
            END -- pickheader does not exist        
           
            /****************************        
             PACKHEADER        
            ****************************/        
              
                  
            INSERT INTO dbo.PackHeader         
            (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, AddWho, AddDate, EditWho, EditDate)         
            SELECT O.Route, O.OrderKey,SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey, O.Storerkey,         
                  PH.PickHeaderkey, sUser_sName(), GETDATE(), sUser_sName(), GETDATE()        
            FROM  dbo.PickHeader PH WITH (NOLOCK)        
            JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)        
            WHERE PH.Orderkey = @cOrderkey        
           
            IF @@ERROR <> 0        
            BEGIN        
               SET @nErrNo = 94661        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CreatePHdrFail'        
               GOTO RollBackTran        
            END        
    
            SELECT @cPickSlipNo = MIN(RTRIM(ISNULL(PickHeaderKey,'')))        
            FROM   dbo.PickHeader PH WITH (NOLOCK)        
            WHERE  Orderkey = @cOrderkey        
    
                
         END -- packheader does not exist        
         ELSE      
         BEGIN      
    
               
               SELECT @cPickSlipNo = MIN(RTRIM(ISNULL(PickHeaderKey,'')))        
               FROM   dbo.PickHeader PH WITH (NOLOCK)        
               WHERE  Orderkey = @cOrderkey        
      
         END      
               
         SELECT @cLoadKey  = LoadKey       
               ,@cOrderKey = OrderKey      
         FROM dbo.PackHeader WITH (NOLOCK)      
         WHERE PickSlipNo = @cPickSlipNo      
                  
               
         SELECT @nSUM_PackQTY = 0, @nSUM_PickQTY = 0        
               
         SELECT @nSUM_PackQTY = ISNULL(SUM(PD.QTY), 0)         
         FROM dbo.PackDetail PD WITH (NOLOCK)         
         WHERE PD.StorerKey = @cStorerKey        
            AND PD.DropID = @cDropID        
            AND PD.PickSlipNo = @cPickSlipNo      
               
         SELECT @nSUM_PickQTY = ISNULL(SUM(Qty), 0)         
         FROM dbo.PickDetail PD WITH (NOLOCK)        
         INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey     
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey   
         WHERE PD.StorerKey = @cStorerKey        
           AND PD.DropID = @cDropID        
           AND PD.Status IN ( '0', '5' )     
           AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC')  
           AND PH.PickHeaderKey = @cPickSlipNo      
               
      
               
         IF @nSUM_PackQTY = @nSUM_PickQTY        
         BEGIN                  
            SET @nErrNo = 94651                  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ToteCompleted                  
            GOTO RollBackTran                    
         END         
      
         /****************************        
          PACKDETAIL        
         ****************************/        
         SET @cLabelNo = 0         
         SET @nCartonNo = 0        
               
               
         IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)             
                                WHERE PickSlipNo = @cPickSlipNo )       
         BEGIN      
                  
            SET @cExecStatements = N'EXEC dbo.' + RTRIM( @cGenLabelNoSP) +        
                                    '   @cPickslipNo           ' +                           
                                    ' , @nCartonNo             ' +       
                                    ' , @cLabelNo     OUTPUT   '       
                                        
                    
            SET @cExecArguments =         
                      N'@cPickslipNo  nvarchar(10),       ' +        
                       '@nCartonNo    int,                ' +            
                       '@cLabelNo     nvarchar(20) OUTPUT '            
                       
                         
                   
            EXEC sp_executesql @cExecStatements, @cExecArguments,         
                                 @cPickslipNo                       
                               , @nCartonNo      
                               , @cLabelNo      OUTPUT      
                               
                              
                 
            IF ISNULL(@cLabelNo,'')  = ''       
            BEGIN      
        SET @nErrNo = 94671                  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoLabelNoGen                  
                  GOTO RollBackTran                 
            END      
                  
  
         END      
         ELSE       
         BEGIN          
            SELECT @cLabelNo = LabelNo       
                  ,@cTrackNo = UPC      
            FROM dbo.PackDetail WITH (NOLOCK)      
            WHERE PickSlipNo = @cPickSlipNo      
      
            SELECT @cLoadKey = LoadKey       
            FROM dbo.PackHeader WITH (NOLOCK)      
            WHERE PickSlipNo = @cPickSlipNo      
                 
         END      
               
         -- need to generate UPI for 1st Tote, and regenerate for subsequent tote        
         -- because the total PackQty would differ from original        
      
               
               
         SELECT @nPackQty = ISNULL(SUM(ECOMM.ScannedQTY), 0)        
         FROM   rdt.rdtECOMMLog ECOMM WITH (NOLOCK)        
         WHERE  ToTeNo = @cDropID        
         AND    Orderkey = @cOrderkey        
         AND    Status < '5'        
         AND    AddWho = @cUserName        
      
      
      
         IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)         
                               WHERE StorerKey = @cStorerKey      
                               AND OrderKey = @cOrderKey       
                               AND ISNULL(UserDefine04,'')  = '' )       
         BEGIN      
            UPDATE dbo.Orders WITH (ROWLOCK)       
            SET UserDefine04 = @cTrackNo      
               ,Trafficcop   = NULL -- (ChewKP02)    
            WHERE Orderkey = @cOrderKey      
            AND Storerkey = @cStorerKey      
                  
            IF @@ERROR <> 0       
            BEGIN      
                  SET @nErrNo = 94675                 
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdOrderFail                  
                  GOTO RollBackTran        
            END      
         END      
      
      
         IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)       
                         WHERE StorerKey = @cStorerKey      
                         AND DropID = @cDropID      
                         AND ISNULL(CaseID,'')  = ''      
                         AND Status = '5' )       
         BEGIN      
                  
            UPDATE dbo.PickDetail WITH (ROWLOCK)      
            SET CASEID     = @cLabelNo      
               ,TrafficCop = NULL      
            WHERE StorerKey = @cStorerKey      
            AND DropID = @cDropID      
            AND OrderKey = @cOrderKey      
      
            IF @@ERROR <> 0       
            BEGIN      
                  SET @nErrNo = 94676                 
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFull                  
                  GOTO RollBackTran        
            END      
         END      
               
    
               
         DECLARE C_TOTE_DETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
         SELECT ECOMM.SKU, ECOMM.ScannedQTY        
         FROM   rdt.rdtECOMMLog ECOMM WITH (NOLOCK)        
         WHERE  ToTeNo = @cDropID        
         AND    Orderkey = @cOrderkey        
         AND    Status < '5'        
         AND    AddWho = @cUserName        
         ORDER BY SKU        
               
         OPEN C_TOTE_DETAIL        
         FETCH NEXT FROM C_TOTE_DETAIL INTO  @cPackSku , @nPackQty         
         WHILE (@@FETCH_STATUS <> -1)        
         BEGIN        
            SET @cLabelLine = '00000'        
               
               
            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)       
                           WHERE PickSlipNo = @cPickSlipNo       
                              AND SKU = @cPackSku       
                              AND DropID = @cDropID)        
            BEGIN        
               -- update the existing packdetail labelno        
               UPDATE dbo.Packdetail WITH (ROWLOCK)        
               SET   LabelNo  = @cLabelNo,        
                     RefNo    = @cLabelNo,        
                     UPC      = @cTrackNo      
               WHERE PickSlipNo = @cPickSlipNo        
               
               IF @@ERROR <> 0        
               BEGIN        
                  SET @nErrNo = 94662        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'        
                  GOTO RollBackTran        
               END        
               
               -- Check if sku overpacked (james03)      
               SELECT @nTTL_PickedQty = ISNULL(SUM(PD.QTY), 0)      
               FROM dbo.PickDetail PD WITH (NOLOCK)      
               JOIN dbo.PickHeader PH WITH (NOLOCK) ON PD.OrderKey = PH.OrderKey      
               WHERE PD.StorerKey = @cStorerKey      
                  AND PD.Status IN ( '0', '5')     
                  AND PD.SKU = @cPackSku      
                  AND PH.PickHeaderKey = @cPickSlipNo      
               
               
               
               SELECT @nTTL_PackedQty = ISNULL(SUM(QTY), 0)      
               FROM dbo.PackDetail WITH (NOLOCK)      
               WHERE StorerKey = @cStorerKey      
                  AND PickSlipNo = @cPickSlipNo      
                  AND SKU = @cPackSku      
       
               
               IF @nTTL_PickedQty < (@nTTL_PackedQty + @nPackQty)      
               BEGIN        
                  SET @nErrNo = 94663        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OVER PACKED'        
                  GOTO RollBackTran        
               END      
               
               -- Insert PackDetail        
               INSERT INTO dbo.PackDetail        
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, DropID, UPC, AddWho, AddDate, EditWho, EditDate)        
               VALUES        
                  (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cPackSku, @nPackQty,        
                  @cLabelNo, @cDropID, @cTrackNo, sUser_sName(), GETDATE(), sUser_sName(), GETDATE())        
              
               IF @@ERROR <> 0        
               BEGIN        
                  SET @nErrNo = 94664        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDetFail'        
                  GOTO RollBackTran        
               END        
               ELSE        
               BEGIN        
                  EXEC RDT.rdt_STD_EventLog          
                    @cActionType = '8', -- Packing         
                    @cUserID     = @cUserName,          
                    @nMobileNo   = @nMobile,          
                    @nFunctionID = @nFunc,          
                    @cFacility   = @cFacility,          
                    @cStorerKey  = @cStorerkey,          
                    @cSKU        = @cPackSku,        
                    @nQty        = @nPackQty,        
                    @cRefNo1     = @cDropID,        
                    @cRefNo2     = @cLabelNo,        
                    @cRefNo3     = @cPickSlipNo         
               END        
         
              
            END --packdetail for sku/order does not exists        
            ELSE        
            BEGIN        
               UPDATE dbo.Packdetail WITH (ROWLOCK)        
               SET   QTY      = QTY + @nPackQty,        
                     LabelNo  = @cLabelNo,        
                     RefNo    = @cLabelNo,      
                     UPC      = @cTrackNo      
               WHERE PickSlipNo = @cPickSlipNo AND SKU = @cPackSku AND DropID = @cDropID       
              
               IF @@ERROR <> 0        
               BEGIN        
                  SET @nErrNo = 69907        --(Kc07)        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'       
                  GOTO RollBackTran        
               END        
         
               ELSE        
               BEGIN        
                  EXEC RDT.rdt_STD_EventLog          
                    @cActionType = '8', -- Packing         
                    @cUserID     = @cUserName,          
                    @nMobileNo   = @nMobile,          
                    @nFunctionID = @nFunc,          
                    @cFacility   = @cFacility,          
                    @cStorerKey  = @cStorerkey,          
                    @cSKU        = @cPackSku,        
                    @nQty        = @nPackQty,        
                    @cRefNo1     = @cDropID,        
                    @cRefNo2     = @cLabelNo,        
                    @cRefNo3     = @cPickSlipNo         
               END        
         
            END -- packdetail for sku/order exists        
            FETCH NEXT FROM C_TOTE_DETAIL INTO  @cPackSku , @nPackQty         
         END --while        
         CLOSE C_TOTE_DETAIL        
         DEALLOCATE C_TOTE_DETAIL             
              
         /****************************        
          PACKINFO        
         ****************************/        
         IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)        
         BEGIN        
            INSERT INTO dbo.PackInfo(PickslipNo, CartonNo, CartonType, Refno, AddWho, AddDate, EditWho, EditDate)        
            SELECT DISTINCT PD.PickSlipNo, PD.CartonNo, @cDropIDType, RefNo, sUser_sName(), GETDATE(), sUser_sName(), GETDATE()       
            FROM   PACKHEADER PH WITH (NOLOCK)        
            JOIN   PACKDETAIL PD WITH (NOLOCK) ON (PH.PickslipNo = PD.PickSlipNo)        
            WHERE  PH.Orderkey = @cOrderkey        
              
            IF @@ERROR <> 0        
            BEGIN        
               SET @nErrNo = 94665        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPInfoFail'        
               GOTO RollBackTran                     
            END        
         END        
               
         /****************************        
          rdtECOMMLog        
         ****************************/        
         --update rdtECOMMLog        
         UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)        
         SET   Status      = '9'    -- completed        
         WHERE ToteNo      = @cDropID        
         AND   Orderkey    = @cOrderkey        
         AND   AddWho      = @cUserName        
         AND   Status      < '5'        
              
         IF @@ERROR <> 0        
         BEGIN        
            SET @nErrNo = 94666             
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'        
            GOTO RollBackTran                  
         END        
               
         -- check if total order fully despatched        
         SELECT @nTotalPickQty = SUM(ISNULL(PK.Qty,0))         
         FROM  dbo.PICKDETAIL PK WITH (nolock)        
         WHERE PK.Orderkey = @cOrderkey        
            
                       
         SELECT @nTotalPackQty = SUM(ISNULL(PD.Qty,0))        
         FROM  dbo.PACKDETAIL PD WITH (NOLOCK)        
         JOIN  dbo.PACKHEADER PH WITH (NOLOCK) ON (PD.PickslipNo = PH.PickSlipNo AND PH.Orderkey = @cOrderkey)        
               
         -- Print Label      
         IF @nTotalPickQty = @nTotalPackQty        
         BEGIN        
            SET @nTotalPickQty = 0       
            SET @cOrderKeyOut = @cOrderkey    
                
            SET @cTrackNoFlag = '1'    
                
            -- Print Label via BarTender --          
            SET @cRDTBartenderSP = ''              
            SET @cRDTBartenderSP = rdt.RDTGetConfig( @nFunc, 'RDTBartenderSP', @cStorerkey)          
                
            -- (james01)
            SET @nErrNo = 0
            EXEC nspGetRight  
                  @c_Facility   = @cFacility    
               ,  @c_StorerKey  = @cStorerKey   
               ,  @c_sku        = ''         
               ,  @c_ConfigKey  = 'AutoMBOLPack'   
               ,  @b_Success    = @bSuccess             OUTPUT  
               ,  @c_authority  = @cAutoMBOLPack        OUTPUT   
               ,  @n_err        = @nErrNo               OUTPUT  
               ,  @c_errmsg     = @cErrMsg              OUTPUT  
  
            IF @nErrNo <> 0   
            BEGIN  
               SET @nErrNo = 94681  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetRightFail       
               GOTO RollBackTran    
            END  
  
            IF @cAutoMBOLPack = '1'  
            BEGIN  
               SET @nErrNo = 0
               EXEC dbo.isp_QCmd_SubmitAutoMbolPack  
                 @c_PickSlipNo= @cPickSlipNo  
               , @b_Success   = @bSuccess    OUTPUT      
               , @n_Err       = @nErrNo      OUTPUT      
               , @c_ErrMsg    = @cErrMsg     OUTPUT   
           
               IF @nErrNo <> 0   
               BEGIN  
                  SET @nErrNo = 94682  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- AutoMBOLPack       
                  GOTO RollBackTran    
               END     
            END  
                  
            UPDATE dbo.PackHeader WITH (ROWLOCK)       
            SET Status = '9'      
            WHERE PickSlipNo = @cPickSlipNo       
            AND StorerKey = @cStorerKey      
               
       
            IF @cRDTBartenderSP <> ''          
            BEGIN          
                         
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRDTBartenderSP AND type = 'P')          
                  BEGIN          
                                    
                     SET @cLabelNo = ''           
                     SELECT Top 1  @cLabelNo = LabelNo         
                     FROM dbo.PackDetail WITH (NOLOCK)        
                     WHERE PickSlipNo = @cPickSlipNo        
                     AND DropID = @cDropID       
            
               
                               
                     SET @cExecStatements = N'EXEC rdt.' + RTRIM( @cRDTBartenderSP) +           
                                             '   @nMobile               ' +            
                                             ' , @nFunc                 ' +                             
                                             ' , @cLangCode             ' +                
                                             ' , @cFacility             ' +                
                                             ' , @cStorerKey            ' +             
                                             ' , @cLabelPrinter         ' +             
                                             ' , @cDropID               ' +          
                                             ' , @cLoadKey              ' +         
                                             ' , @cLabelNo              ' +          
                                             ' , @cUserName             ' +           
                                             ' , @nErrNo       OUTPUT   ' +          
                                             ' , @cErrMSG      OUTPUT   '           
                   
                                
                     SET @cExecArguments =           
                                N'@nMobile     int,                   ' +          
                                '@nFunc       int,                    ' +              
                                '@cLangCode   nvarchar(3),            ' +              
                                '@cFacility   nvarchar(5),            ' +              
                                '@cStorerKey  nvarchar(15),           ' +              
                                '@cLabelPrinter     nvarchar(10),     ' +             
                                '@cDropID     nvarchar(20),           ' +              
                                '@cLoadKey    nvarchar(10),           ' +        
                                '@cLabelNo    nvarchar(20),           ' +                                   
                                '@cUserName   nvarchar(18),           ' +          
                                '@nErrNo      int  OUTPUT,            ' +          
                                '@cErrMsg     nvarchar(1024) OUTPUT   '           
                                          
                          
                               
                     EXEC sp_executesql @cExecStatements, @cExecArguments,           
                                           @nMobile                         
                                         , @nFunc                                           
                                         , @cLangCode                              
                                         , @cFacility                 
                                         , @cStorerKey             
                                         , @cLabelPrinter                      
                                         , @cDropID          
                                         , @cLoadKey        
                                         , @cLabelNo        
                                         , @cUserName          
                                         , @nErrNo       OUTPUT             
                                         , @cErrMSG      OUTPUT       
                                
                      IF @nErrNo <> 0              
                      BEGIN              
                         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidCarton'          
                         GOTO RollBackTran              
                      END            
                 
                              
                  END          
                            
                            
                     
            END      
                  
            SELECT @cDataWindow = DataWindow,         
                  @cTargetDB = TargetDB         
            FROM rdt.rdtReport WITH (NOLOCK)         
            WHERE StorerKey = @cStorerKey        
            AND   ReportType = 'BAGMANFEST'        
         
            SET @cShipperKey = ''      
            SET @cOrderType = ''      
                  
            SELECT @cShipperKey = ShipperKey      
                  ,@cOrderType  = Type      
                  ,@cSectionKey = RTRIM(SectionKey)    
            FROM dbo.Orders WITH (NOLOCK)      
            WHERE OrderKey = @cOrderKey      
            AND StorerKey = @cStorerKey      
                
            --INSERT INTO TRACEINFO (TraceName, TimeIn, Step1 , Step2, Step3 )     
            --VALUES ( 'rdt_841ExtUpdSP03', GetDate() , '1' , @cOrderKey, @cOrderType )      
                
            -- Build PrintJob for RDT Spooler --      
            IF @cOrderType = 'TMALL'      
            BEGIN      
                     
               -- Trigger WebService --       
               EXEC  [isp_WS_UpdPackOrdSts]        
                 @cOrderKey         
               , @cStorerKey         
               , @bSuccess OUTPUT        
               , @nErrNo    OUTPUT        
               , @cErrMsg   OUTPUT            
                   
            END    
            ELSE    
            BEGIN    
               SET @cSOStatus = ''    
               SELECT @cSOStatus = SOStatus     
               FROM dbo.Orders WITH (NOLOCK)     
               WHERE StorerKey = @cStorerKey    
               AND OrderKey = @cOrderKey    
                   
                 
   
                   
               UPDATE dbo.Orders WITH (ROWLOCK)     
               SET SOStatus= '0', TrafficCop = NULL    
               WHERE OrderKey = @cOrderKey    
               AND StorerKey = @cStorerKey     
                   
               IF  @@ERROR <> 0     
               BEGIN    
                  SET @nErrNo = 94678             
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdOrdFail'        
                  GOTO RollBackTran         
               END    
   
            END    
                 
                   
               EXEC RDT.rdt_BuiltPrintJob          
                @nMobile,          
                @cStorerKey,          
                'BAGMANFEST',              -- ReportType          
                'ANF_CUSTOMERMANIFEST',    -- PrintJobName          
                @cDataWindow,          
                @cPaperPrinter,          
                @cTargetDB,          
                @cLangCode,          
                @nErrNo  OUTPUT,          
                @cErrMsg OUTPUT,           
                @cOrderkey,         
                @cLabelNo      
--            END      
    
            -- (ChewKP01)   
            IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)  
                        WHERE OrderKey = @cOrderKey  
                        AND PrintFlag = '1' )   
            BEGIN        
               -- Check if it is Metapack printing    
               SELECT @cFilePath = Long, @cPrintFilePath = Notes     
               FROM dbo.CODELKUP WITH (NOLOCK)      
               WHERE LISTNAME = 'CaiNiao'      
               AND   Code = 'WayBill'    
               --AND   StorerKey = @cStorerKey     
                 
               SELECT @cWinPrinter = WinPrinter  
               FROM rdt.rdtPrinter WITH (NOLOCK)  
               WHERE PrinterID = @cLabelPrinter  
                 
               SET @cPrinterName = LEFT( @cWinPrinter , (CHARINDEX(',' , @cWinPrinter) - 1) )  
                   
               IF ISNULL( @cFilePath, '') <> ''    
               BEGIN    
                  SET @cFileName = 'WB_' + RTRIM( @cOrderKey) + '.pdf'     
                  SET @cPrintCommand = '"' + @cPrintFilePath + '" /t "' + @cFilePath + '\' + @cFileName + '" "' + @cPrinterName + '"'                              
                      
                    
                  EXEC RDT.rdt_BuiltPrintJob          
                   @nMobile,          
                   @cStorerKey,          
                   'WAYBILL',              -- ReportType          
                   'WAYBILL',    -- PrintJobName          
                   @cFileName,          
                   @cLabelPrinter,          
                   @cTargetDB,          
                   @cLangCode,          
                   @nErrNo  OUTPUT,          
                   @cErrMsg OUTPUT,           
                   '',         
                   '',      
                   '',    
                   '',    
                   '',    
                   '',    
                   '',    
                   '',    
                   '',    
                   '',    
                   '1',    
                   @cPrintCommand    
       
                   UPDATE dbo.Orders WITH (ROWLOCK)   
                   SET PrintFlag = '2'  
                      ,TrafficCop = NULL   
                   WHERE OrderKey = @cOrderKey   
                     
                   IF @@ERROR <> 0   
                   BEGIN  
                      SET @nErrNo = 94680          
                      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdOrdFail'        
                      GOTO RollBackTran         
                   END  
                     
               END   -- @cFilePath    
            END   
            ELSE   
            BEGIN  
                SET @nErrNo = -1       
                SET @cErrMsg = @cOrderKey --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'WayBillNotFound'        
            END  
  
         END      
       
                  
      END      
   END      
         
    
     
   GOTO QUIT       
         
RollBackTran:      
   ROLLBACK TRAN rdt_841ExtUpdSP03 -- Only rollback change made here      
      
Quit:      
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
      COMMIT TRAN rdt_841ExtUpdSP03      
        
      
END        
  

GO