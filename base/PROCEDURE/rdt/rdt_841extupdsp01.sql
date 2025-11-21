SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_841ExtUpdSP01                                   */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: ANF Replen To Logic                                         */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2014-06-24  1.0  ChewKP   Created                                    */  
/* 2014-10-02  1.1  ChewKP   Insert TraceInfo to Track Update SOStatus  */  
/* 2014-10-08  1.2  ChewKP   DTC Order Update SOStatus = '0' (ChewKP01) */  
/* 2014-12-10  1.3  ChewKP   Performance Tuning (ChewKP02)              */  
/* 2015-08-24  1.4  Ung      SOS350720 Add BackendPickConfirm           */ 
/* 2015-10-15  1.5  ChewKP   SOS#349748 - Allow Pickdetail.Status = '3' */
/*                           for DTC (ChewKP01)                         */    
/* 2016-05-9   1.6  ChewKP   Performance Tuning (ChewKP04)              */
/* 2017-10-26  1.7  ChewKP   Swap printing sequence with Pack confirm   */
/*                           (ChewKP05)                                 */
/* 2020-05-19  1.8  YeeKung  WMS-13131 Add Cartontype param(yeekung01)  */
/* 2020-09-05  1.9  James    WMS-15010 Add AutoMBOLPack (james01)       */
/* 2021-04-01  2.0  YeeKung  WMS-16718 Add serialno and serialqty       */
/*                           Params (yeekung02)                         */
/* 2021-07-27  2.1  Chermain WMS-17410 Add VariableTable Param (cc01)   */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_841ExtUpdSP01] (  
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
   @cCartonType   NVARCHAR( 20) ='',
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
          ,@nRowRef           INT
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
   SAVE TRAN rdt_841ExtUpdSP01  
  
   SET @cGenTrackNoSP = rdt.RDTGetConfig( @nFunc, 'GenerateTrackNo', @cStorerKey)  
   IF @cGenTrackNoSP = '0'  
   BEGIN  
        SET @cGenTrackNoSP = ''  
   END  
  
   SELECT @cLabelPrinter = Printer  
         ,@cPaperPrinter = Printer_Paper  
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
  
  
   IF @nStep = 2     
   BEGIN  
  
      SET @cGenLabelNoSP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo', @cStorerkey)  
  
--     SELECT @cGenLabelNoSP = SValue  
--     FROM dbo.StorerConfig WITH (NOLOCK)  
--     WHERE StorerKey = @cStorerKey  
--     AND ConfigKey = 'GenLabelNo_SP'  
--  
--  
      IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = ISNULL(RTRIM(@cGenLabelNoSP),'') AND type = 'P')  
      BEGIN  
  
            SET @nErrNo = 90570  
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
          SET @nErrNo = 90555  
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
            SET @nErrNo = 90556  
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
         SET @nErrNo = 90557  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QtyExceeded  
         GOTO RollBackTran  
      END  
  
  
      /***************************  
      UPDATE rdtECOMMLog  
      ****************************/  
      -- (ChewKP04) 
      DECLARE C_ECOMMUPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT RowRef  
      FROM   rdt.rdtECOMMLog ECOMM WITH (NOLOCK)    
      WHERE ToteNo      = @cDropID    
      AND   Orderkey    = @cOrderkey    
      AND   Sku         = @cSku    
      AND   Status      < '5'    
      AND   AddWho = @cUserName  
      ORDER BY RowRef
      
      OPEN C_ECOMMUPD  
      FETCH NEXT FROM C_ECOMMUPD INTO  @nRowRef
      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN  
                           
         UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)    
         SET   ScannedQty  = ScannedQty + 1,    
               Status      = '1'    -- in progress    
         WHERE RowRef = @nRowRef
        
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 90558    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'    
            GOTO RollBackTran       
         END    
         
         FETCH NEXT FROM C_ECOMMUPD INTO  @nRowRef
         
      END
      CLOSE C_ECOMMUPD  
      DEALLOCATE C_ECOMMUPD  
  
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
  
  
               --pickheader record missing  
--               SELECT @cPickSlipNo = MIN(RTRIM(ISNULL(Pickslipno,'')))  
--               FROM   dbo.PICKDETAIL PD WITH (NOLOCK)  
--               WHERE  Orderkey = @cOrderkey  
--               AND    Status = '5'  
  
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
                  SET @nErrNo = 90559  
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
                  AND   (Status = '5' OR ShipFlag = 'P')  
                  AND   ISNULL(RTrim(Pickslipno),'') = ''  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 90560  
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
               SET @nErrNo = 90561  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CreatePHdrFail'  
               GOTO RollBackTran  
            END  
  
            SELECT @cPickSlipNo = MIN(RTRIM(ISNULL(PickHeaderKey,'')))  
            FROM   dbo.PickHeader PH WITH (NOLOCK)  
            WHERE  Orderkey = @cOrderkey  
  
  
         END -- packheader does not exist  
         ELSE  
         BEGIN  
--               SELECT @cPickSlipNo = MIN(RTRIM(ISNULL(Pickslipno,'')))  
--               FROM   dbo.PICKDETAIL PD WITH (NOLOCK)  
--               WHERE  Orderkey = @cOrderkey  
--               AND    Status = '5'  
  
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
         WHERE PD.StorerKey = @cStorerKey  
           AND PD.DropID = @cDropID  
           AND (PD.Status = '5' OR PD.Status = '3' OR PD.ShipFlag = 'P')  
           AND PH.PickHeaderKey = @cPickSlipNo  
  
  
  
         IF @nSUM_PackQTY = @nSUM_PickQTY  
         BEGIN  
            SET @nErrNo = 90551  
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
                  SET @nErrNo = 90571  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoLabelNoGen  
                  GOTO RollBackTran  
            END  
  
  -- Generate TrackingNo  
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = ISNULL(RTRIM(@cGenTrackNoSP),'') AND type = 'P')  
            BEGIN  
  
               SET @cExecStatements = N'EXEC dbo.' + RTRIM( @cGenTrackNoSP) +  
                                       '   @cPickslipNo           ' +  
                                       ' , @nCartonNo             ' +  
                                       ' , @cLabelNo              ' +  
                                       ' , @cTrackNo     OUTPUT   '  
  
  
               SET @cExecArguments =  
                         N'@cPickslipNo  nvarchar(10),       ' +  
                          '@nCartonNo    int,                ' +  
                          '@cLabelNo     nvarchar(20) , ' +  
                          '@cTrackNo     nvarchar(20) OUTPUT '  
  
  
  
               EXEC sp_executesql @cExecStatements, @cExecArguments,  
                                    @cPickslipNo  
                                  , @nCartonNo  
                                  , @cLabelNo  
                                  , @cTrackNo      OUTPUT  
  
  
  
               IF ISNULL(@cTrackNo,'')  = ''  
               BEGIN  
                     SET @nErrNo = 90573  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoTrackNoGenerated  
                     GOTO RollBackTran  
               END  
  
               -- INSERT INTO CartonShipmentDetail  
               INSERT INTO CartonShipmentDetail (StorerKey, OrderKey, LoadKey, TrackingNumber)  
               VALUES ( @cStorerKey, @cOrderKey, @cLoadKey, @cTrackNo )  
  
               IF @@ERROR <> 0  
               BEGIN  
                     SET @nErrNo = 90574  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsCtnShpmentDetFail  
                     GOTO RollBackTran  
               END  
  
  
  
            END  
            ELSE  
            BEGIN  
--                 SET @nErrNo = 90572  
--                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenTrackNoSPNotFound'  
--                 GOTO RollBackTran  
                   SELECT @cTrackNo = UserDefine04  
                   FROM dbo.Orders WITH (NOLOCK)  
                   WHERE OrderKey = @cOrderkey  
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
--         SELECT TOP 1 @cPickSlipNo  = PH.PickSlipNo  
--         FROM  dbo.PACKHEADER PH WITH (NOLOCK)  
--         WHERE PH.Orderkey = @cOrderkey  
  
  
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
                  SET @nErrNo = 90575  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdOrderFail  
                  GOTO RollBackTran  
            END  
         END  
  
         
         IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)  
                         WHERE StorerKey = @cStorerKey  
                         AND DropID = @cDropID  
                         AND ISNULL(CaseID,'')  = ''  
                         AND (Status = '5' OR Status = '3' OR ShipFlag = 'P'))  
         BEGIN  
            
            UPDATE dbo.PickDetail WITH (ROWLOCK)  
            SET CASEID     = @cLabelNo  
               ,TrafficCop = NULL  
            WHERE StorerKey = @cStorerKey  
            AND DropID = @cDropID  
            AND OrderKey = @cOrderKey  
  
            IF @@ERROR <> 0  
            BEGIN  
                  SET @nErrNo = 90576  
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
                  SET @nErrNo = 90562  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'  
                  GOTO RollBackTran  
               END  
  
               -- Check if sku overpacked (james03)  
               SELECT @nTTL_PickedQty = ISNULL(SUM(PD.QTY), 0)  
               FROM dbo.PickDetail PD WITH (NOLOCK)  
               JOIN dbo.PickHeader PH WITH (NOLOCK) ON PD.OrderKey = PH.OrderKey  
               WHERE PD.StorerKey = @cStorerKey  
                  AND (PD.Status = '5' OR PD.Status = '3' OR PD.ShipFlag = 'P')  
                  AND PD.SKU = @cPackSku  
                  AND PH.PickHeaderKey = @cPickSlipNo  
  
  
  
               SELECT @nTTL_PackedQty = ISNULL(SUM(QTY), 0)  
               FROM dbo.PackDetail WITH (NOLOCK)  
               WHERE StorerKey = @cStorerKey  
                  AND PickSlipNo = @cPickSlipNo  
                  AND SKU = @cPackSku  
  
  
               IF @nTTL_PickedQty < (@nTTL_PackedQty + @nPackQty)  
               BEGIN  
                  SET @nErrNo = 90563  
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
                  SET @nErrNo = 90564  
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
               SET @nErrNo = 90565  
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
            SET @nErrNo = 90566  
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
            --VALUES ( 'rdt_841ExtUpdSP01', GetDate() , '1' , @cOrderKey, @cOrderType )  
  
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
  
               --INSERT INTO TRACEINFO (TraceName, TimeIn, Step1 , Step2, Step3 )  
               --VALUES ( 'rdt_841ExtUpdSP01', GetDate() , '1.1' , @cOrderKey, @cSOStatus )  
  
-- (ChewKP01)  
--               IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)  
--                           WHERE OrderKey = @cOrderKey  
--                           AND StorerKey = @cStorerKey  
--                           AND SOStatus <> '0' )  
--               BEGIN  
                  --INSERT INTO TRACEINFO (TraceName, TimeIn, Step1 , Step2, Step3, Step4 )                    --VALUES ( 'rdt_841ExtUpdSP01', GetDate() , '1.2' , @cOrderKey, @cSOStatus, @cStorerKey )  
  
                  UPDATE dbo.Orders WITH (ROWLOCK)  
                  SET SOStatus= '0', TrafficCop = NULL  
                  WHERE OrderKey = @cOrderKey  
                  AND StorerKey = @cStorerKey  
  
                  IF  @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 90578  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdOrdFail'  
                     GOTO RollBackTran  
                  END  
--               END  
--               ELSE  
--               BEGIN  
--                  INSERT INTO TRACEINFO (TraceName, TimeIn, Step1 , Step2, Step3, Step4 )  
--                  VALUES ( 'rdt_841ExtUpdSP01', GetDate() , '1.3' , @cOrderKey, @cSOStatus, @cStorerKey )  
--               END  
            END  
  
            IF EXISTS ( SELECT 1 FROM dbo.CodeLkup WITH (NOLOCK)  
                            WHERE ListName = 'DTCPrinter' )  
            BEGIN  
  
  
               -- Get Printer Information  
               SELECT @cPrinter01 = RTRIM(Code)  
                     ,@cBrand01   = RTRIM(Short)  
                     ,@cPrinter02 = RTRIM(UDF01)  
                     ,@cBrand02   = RTRIM(UDF02)  
               FROM dbo.CodeLkup WITH (NOLOCK)  
               WHERE ListName = 'DTCPrinter'  
               AND RTRIM(Code) = ISNULL(RTRIM(@cPaperPrinter),'')  
  
  
               IF @cSectionKey = @cBrand01  
               BEGIN  
                  SET @cPaperPrinter = @cPrinter01  
               END  
               ELSE IF @cSectionKey = @cBrand02  
               BEGIN  
                  SET @cPaperPrinter = @cPrinter02  
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
            
--            IF @nErrNo <> 0
--            BEGIN
--               GOTO RollBackTran  
--            END

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
               SET @nErrNo = 90579  
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
                  SET @nErrNo = 90580  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- AutoMBOLPack       
                  GOTO RollBackTran    
               END     
            END  
        
            -- (ChewKP05) 
            UPDATE dbo.PackHeader WITH (ROWLOCK)  
            SET Status = '9'  
            WHERE PickSlipNo = @cPickSlipNo  
            AND StorerKey = @cStorerKey  
  
  
  
  
--         DELETE FROM rdt.rdtECOMMLog WITH (ROWLOCK) WHERE ToteNo = @cDropID AND AddWho = @cUserName  
--  
--         IF @@ERROR <> 0  
--         BEGIN  
--            SET @nErrNo = 90554  
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelEcommLogFail  
--            GOTO RollBackTran  
--         END  
  
         END  
  
         IF @cWCS = '1'  
         BEGIN  
            UPDATE dbo.WCSRouting WITH (ROWLOCK)  
            SET Status = '9'  
            WHERE ToteNo = @cDropID  
            AND Status = '0'  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 90552  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdWCSFail  
               GOTO RollBackTran  
            END  
  
  
            UPDATE dbo.WCSRoutingDetail WITH (ROWLOCK)  
            SET Status = '9'  
            WHERE ToteNo = @cDropID  
            AND Status = '0'  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 90553  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdWCSDetFail  
               GOTO RollBackTran  
            END  
         END  
  
      END  
   END  
  
   IF @nStep = 6  
   BEGIN  
  
      UPDATE dbo.Orders  
      SET UserDefine04 = @cTrackNo  
         ,TrafficCop   = NULL -- (ChewKP02)  
      WHERE Orderkey = @cPrevOrderkey  
      AND Storerkey = @cStorerKey  
  
      IF @@ERROR <> 0  
      BEGIN  
            SET @nErrNo = 90568  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdOrderFail  
            GOTO RollBackTran  
      END  
  
      INSERT INTO rdt.rdtTrackLog ( Mobile, UserName, Storerkey, Orderkey, TrackNo, SKU, Qty, QtyAllocated)  
      VALUES (@nMobile, @cUserName, @cStorerkey, @cPrevOrderkey, @cDropID, @cSKU, 0 , '')  
  
      IF @@ERROR <> 0  
      BEGIN  
            SET @nErrNo = 90569  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTrackLogFail  
            GOTO RollBackTran  
      END  
  
      --Insert into Traceinfo (tracename , timein , col1 ,col2 , col3 , col4 , col5 )  
      --Values ( 'Step6' , getdate(), @cTrackNo , @cPrevOrderkey , @cPickSlipNo, '' ,'' )  
  
      IF NOT EXISTS ( SELECT 1 FROM dbo.CartonShipmentDetail WITH (NOLOCK)  
                      WHERE TrackingNumber = @cTrackNo  
                      AND StorerKey = @cStorerKey  
                      AND OrderKey = @cPrevOrderkey )  
      BEGIN  
         -- INSERT INTO CartonShipmentDetail  
         INSERT INTO CartonShipmentDetail (StorerKey, OrderKey, LoadKey, TrackingNumber)  
         VALUES ( @cStorerKey, @cPrevOrderkey, @cLoadKey, @cTrackNo )  
  
         IF @@ERROR <> 0  
         BEGIN  
               SET @nErrNo = 90577  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsCtnShpmentDetFail  
               GOTO RollBackTran  
         END  
      END  
  
      -- update the existing packdetail labelno  
      UPDATE dbo.Packdetail WITH (ROWLOCK)  
      SET   UPC      = @cTrackNo  
      WHERE PickSlipNo = @cPickSlipNo  
--      AND LabelNo = @cLabelNo  
      
      IF @@ERROR <> 0        
      BEGIN        
         SET @nErrNo = 90562        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'        
         GOTO RollBackTran        
      END        
          
       
      
            
                  
   END      
      
   GOTO QUIT       
         
RollBackTran:      
   ROLLBACK TRAN rdt_841ExtUpdSP01 -- Only rollback change made here      
      
Quit:      
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
      COMMIT TRAN rdt_841ExtUpdSP01      
        
      
END  

GO