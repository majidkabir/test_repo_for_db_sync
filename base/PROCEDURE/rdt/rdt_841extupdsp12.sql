SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_841ExtUpdSP12                                   */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Ecomm Update SP                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2020-05-21  1.0  James    WMS13459. Created                          */ 
/* 2020-05-19  1.1  YeeKung  WMS-13131 Add Cartontype param(yeekung01)  */ 
/* 2021-04-01  1.2  YeeKung  WMS-16718 Add serialno and serialqty       */
/*                           Params (yeekung02)                         */ 
/* 2021-07-27  1.3  Chermain WMS-17410 Add VariableTable Param (cc01)   */
/************************************************************************/  

CREATE PROC [RDT].[rdt_841ExtUpdSP12] (  
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
   @cCartonType   NVARCHAR( 20) ='',  --(yeekung01) 
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
          ,@cGenPackDetail    NVARCHAR(1)  
          ,@b_success         INT  
          ,@cShowTrackNoScn   NVARCHAR(1)  
          ,@nRowRef           INT  
          ,@cPickDetailKey    NVARCHAR(10)
          ,@nInputKey         INT
          ,@cShipLabel        NVARCHAR( 10)
          ,@cDelNotes         NVARCHAR( 10)
          ,@cTrackingNo       NVARCHAR( 30)
          ,@cDocType          NVARCHAR( 1)
          ,@cWinPrinter       NVARCHAR(128)  
          ,@cFilePath         NVARCHAR(100)       
          ,@cPrintFilePath    NVARCHAR(100)      
          ,@cPrintCommand     NVARCHAR(MAX)    
          ,@cReportType       NVARCHAR( 10)
          ,@cFilePrefix       NVARCHAR( 30)
          ,@cPrinterName      NVARCHAR(100)   
          ,@cWinPrinterName   NVARCHAR(100)   
          ,@cFileName         NVARCHAR( 50)    
  
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
   SET @cShowTrackNoScn = ''  
  
   SET @nTranCount = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN rdt_841ExtUpdSP12  
  
   SELECT @cLabelPrinter = Printer  
         ,@cPaperPrinter = Printer_Paper
         ,@nInputKey = InputKey
         ,@cLoadKey  = V_LoadKey  
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
  
   SET @cGenPackDetail  = ''  
   SET @cGenPackDetail = rdt.RDTGetConfig( @nFunc, 'GenPackDetail', @cStorerkey)  

   IF @nStep = 2  
   BEGIN  
      SET @cGenLabelNoSP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo', @cStorerkey)  

      -- check if sku exists in tote  
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)  
                      WHERE ToteNo = @cDropID  
                      AND SKU = @cSKU  
                      AND AddWho = @cUserName  
                      AND Status IN ('0', '1') )  
      BEGIN  
         SET @nErrNo = 152751  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKuNotIntote  
         GOTO RollBackTran  
      END  

      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)  
                      WHERE ToteNo = @cDropID  
                      AND ExpectedQty > ScannedQty  
                      AND Status < '5'  
                      AND Orderkey = @cPrevOrderkey  
                      AND AddWho = @cUserName)  
          SET @cOrderkey = ''  
      ELSE  
          SET @cOrderkey = @cPrevOrderkey  
  
      IF ISNULL(RTRIM(@cOrderkey),'') = ''  
         -- processing new order  
         SELECT @cOrderkey   = MIN(RTRIM(ISNULL(Orderkey,'')))  
         FROM rdt.rdtECOMMLog WITH (NOLOCK)  
         WHERE ToteNo = @cDropID  
         AND   Status IN ('0', '1')  
         AND   Sku = @cSKU  
         AND   AddWho = @cUserName  
      ELSE  
      BEGIN  
         IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)  
                        WHERE ToteNo = @cDropID  
                        AND Orderkey = @cOrderkey  
                        AND SKU = @cSKU  
                        AND Status < '5'  
                        AND AddWho = @cUserName)  
         BEGIN  
            SET @nErrNo = 152752  
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
         SET @nErrNo = 152753  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QtyExceeded  
         GOTO RollBackTran  
      END  

      DECLARE C_ECOMMLOG1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT RowRef  
      FROM rdt.rdtEcommLog WITH (NOLOCK)  
      WHERE ToteNo      = @cDropID  
      AND   Orderkey    = @cOrderkey  
      AND   Sku         = @cSku  
      AND   Status      < '5'  
      AND   AddWho = @cUserName  
      ORDER BY RowRef  
  
      OPEN C_ECOMMLOG1  
      FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef  
      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN  
         /***************************  
         UPDATE rdtECOMMLog  
         ****************************/  
         UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)  
         SET   ScannedQty  = ScannedQty + 1,  
               Status      = '1'    -- in progress  
         WHERE RowRef = @nRowRef  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 152754  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'  
            GOTO RollBackTran  
         END  
  
         FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef  
      END  
      CLOSE C_ECOMMLOG1  
      DEALLOCATE C_ECOMMLOG1  


      IF ISNULL(RTRIM(@cPickSlipno) ,'')=''  
      BEGIN
         SELECT @cPickslipNo = PickHeaderKey
         FROM dbo.PICKHEADER WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         
         IF ISNULL(RTRIM(@cPickSlipno) ,'')=''
            SELECT @cPickslipNo = PickHeaderKey
            FROM dbo.PICKHEADER WITH (NOLOCK)
            WHERE ExternOrderKey = @cLoadKey

         IF ISNULL(RTRIM(@cPickSlipno) ,'')=''
         BEGIN
            EXECUTE dbo.nspg_GetKey  
               'PICKSLIP',  
               9,  
               @cPickslipno  OUTPUT,  
               @b_success    OUTPUT,  
               @nErrNo       OUTPUT,  
               @cErrMsg      OUTPUT  
  
            IF @nErrNo<>0  
            BEGIN  
               SET @nErrNo = 152755  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GetDetKeyFail'  
               GOTO RollBackTran  
            END
            SELECT @cPickslipno = 'P'+@cPickslipno
         END
      END
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PICKHEADER WITH (NOLOCK) WHERE PickHeaderKey = @cPickslipNo)
      BEGIN
          INSERT INTO dbo.PICKHEADER  
            (  
              PickHeaderKey  
             ,ExternOrderKey  
             ,Orderkey  
             ,PickType  
             ,Zone  
             ,TrafficCop  
            )  
          VALUES  
            (  
              @cPickslipno  
             ,''  
             ,@cOrderKey  
             ,'0'  
             ,'D'  
             ,''  
            )  
  
          IF @@ERROR<>0  
          BEGIN  
              SET @nErrNo = 152756  
              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InstPKHdrFail '  
              GOTO RollBackTran  
          END  
      END

      IF NOT EXISTS ( SELECT 1  
                  FROM   dbo.PickingInfo WITH (NOLOCK)  
                  WHERE  PickSlipNo = @cPickSlipNo)
      BEGIN  
          INSERT INTO dbo.PickingInfo  
            (  
              PickSlipNo  
             ,ScanInDate  
             ,PickerID  
             ,ScanOutDate  
             ,AddWho  
             ,TrafficCop 
            )  
          VALUES  
            (  
              @cPickSlipNo  
             ,GETDATE()  
             ,@cUserName  
             ,NULL  
             ,@cUserName  
             ,'U'
            )  
  
      IF @@ERROR<>0  
      BEGIN  
         SET @nErrNo = 152757  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ScanInFail'  
         GOTO RollBackTran  
      END  
      END  

      SET @nTotalPickQty = 0  
      SELECT @nTotalPickQty = SUM(PD.QTY)  
      FROM PICKDETAIL PD WITH (NOLOCK)  
      WHERE PD.ORDERKEY = @cOrderKey  
      AND PD.Storerkey = @cStorerkey  

      SET @nTotalPackQty = 0  
      SELECT @nTotalPackQty = SUM(ScannedQty)  
      FROM rdt.rdtEcommLog WITH (NOLOCK)  
      WHERE OrderKey = @cORderKey  

      IF @nTotalPickQty = @nTotalPackQty  
      BEGIN  
         SET @cTrackNoFlag = '1'  
         SET @cOrderKeyOut = @cOrderkey  
      END  

      IF @cGenPackDetail = '1'  
      BEGIN  
         SET @cTrackNoFlag = ''  
  
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
                     SET @nErrNo = 152758  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPickHdrFail'  
                     GOTO RollBackTran  
                  END  
                  ELSE  
                  BEGIN  
                     UPDATE dbo.PICKDETAIL WITH (ROWLOCK)  
                     SET  PICKSLIPNO = @cPickslipno,  
                          Trafficcop = NULL, 
                          EditDate = GETDATE(),
                          EditWho = SUSER_SNAME()
                     WHERE StorerKey = @cStorerKey  
                     AND   Orderkey = @cOrderKey  
                     AND   (Status IN ('3', '5') OR ShipFlag = 'P')  
                     AND   ISNULL(RTrim(Pickslipno),'') = ''  
  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 152759  
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
                  SET @nErrNo = 152760  
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
  
            IF ISNULL(RTRIM(@cDropID),'')  <> ''  
            BEGIN  
               SELECT @nSUM_PackQTY = ISNULL(SUM(PD.QTY), 0)  
               FROM dbo.PackDetail PD WITH (NOLOCK)  
               WHERE PD.StorerKey = @cStorerKey  
               AND   PD.DropID = @cDropID  
               AND   PD.PickSlipNo = @cPickSlipNo  
  
               SELECT @nSUM_PickQTY = ISNULL(SUM(Qty), 0)  
               FROM dbo.PickDetail PD WITH (NOLOCK)  
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey  
               WHERE PD.StorerKey = @cStorerKey  
               AND   PD.DropID = @cDropID  
               AND  (PD.Status = '5' OR PD.ShipFlag = 'P')  
               AND   PH.PickHeaderKey = @cPickSlipNo  
            END  
            ELSE  
            BEGIN  
               SELECT @nSUM_PackQTY = ISNULL(SUM(PD.QTY), 0)  
               FROM dbo.PackDetail PD WITH (NOLOCK)  
               WHERE PD.StorerKey = @cStorerKey  
               AND   PD.DropID = @cDropID  
               AND   PD.PickSlipNo = @cPickSlipNo  
  
               SELECT @nSUM_PickQTY = ISNULL(SUM(Qty), 0)  
              FROM dbo.PickDetail PD WITH (NOLOCK)  
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey  
               WHERE PD.StorerKey = @cStorerKey  
               AND   PD.DropID = @cDropID  
               AND   PH.PickHeaderKey = @cPickSlipNo  
            END  

            IF @nSUM_PackQTY = @nSUM_PickQTY  
            BEGIN  
               SET @nErrNo = 152761  
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
                  SET @nErrNo = 152762  
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
                     SET @nErrNo = 152763  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoTrackNoGenerated  
                     GOTO RollBackTran  
                  END  
  
                  -- INSERT INTO CartonShipmentDetail  
                  INSERT INTO CartonShipmentDetail (StorerKey, OrderKey, LoadKey, TrackingNumber)  
                  VALUES ( @cStorerKey, @cOrderKey, @cLoadKey, @cTrackNo )  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 152764  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsCtnShpmentDetFail  
                     GOTO RollBackTran  
                  END  
               END  
               ELSE  
               BEGIN  
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
                  ,Trafficcop   = NULL 
                  ,EditDate = GETDATE()
                  ,EditWho = SUSER_SNAME()
               WHERE Orderkey = @cOrderKey  
               AND Storerkey = @cStorerKey  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 152765  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdOrderFail  
                  GOTO RollBackTran  
               END  
            END  

            IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)  
                            WHERE StorerKey = @cStorerKey  
                            AND DropID = @cDropID  
                            AND ISNULL(CaseID,'')  = ''  
                            AND (Status IN ('3', '5') OR ShipFlag = 'P')) 
            BEGIN  
               UPDATE dbo.PickDetail WITH (ROWLOCK)  
               SET CASEID     = @cLabelNo
                  ,TrafficCop = NULL
                  ,EditDate = GETDATE()
                  ,EditWho = SUSER_SNAME()
               WHERE StorerKey = @cStorerKey  
               AND DropID = @cDropID  
               AND OrderKey = @cOrderKey  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 152766  
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
                        UPC      = @cTrackNo, 
                        EditDate = GETDATE(),
                        EditWho  = SUSER_SNAME(),
                        ArchiveCop = NULL
                  WHERE PickSlipNo = @cPickSlipNo  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 152767  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'  
                     GOTO RollBackTran  
                  END  
  
                  -- Check if sku overpacked (james03)  
                  IF ISNULL(RTRIM(@cDropID),'') <> ''  
                  BEGIN  
                     SELECT @nTTL_PickedQty = ISNULL(SUM(PD.QTY), 0)  
                     FROM dbo.PickDetail PD WITH (NOLOCK)  
                     JOIN dbo.PickHeader PH WITH (NOLOCK) ON PD.OrderKey = PH.OrderKey  
                     WHERE PD.StorerKey = @cStorerKey  
                        AND (PD.Status = '5' OR PD.ShipFlag = 'P')  
                        AND PD.SKU = @cPackSku  
                        AND PH.PickHeaderKey = @cPickSlipNo  
                  END  
                  ELSE  
                  BEGIN  
                     SELECT @nTTL_PickedQty = ISNULL(SUM(PD.QTY), 0)  
                     FROM dbo.PickDetail PD WITH (NOLOCK)  
                     JOIN dbo.PickHeader PH WITH (NOLOCK) ON PD.OrderKey = PH.OrderKey  
                     WHERE PD.StorerKey = @cStorerKey  
                        AND PD.SKU = @cPackSku  
                        AND PH.PickHeaderKey = @cPickSlipNo  
                  END  
  
  
                  SELECT @nTTL_PackedQty = ISNULL(SUM(QTY), 0)  
                  FROM dbo.PackDetail WITH (NOLOCK)  
                  WHERE StorerKey = @cStorerKey  
                     AND PickSlipNo = @cPickSlipNo  
                     AND SKU = @cPackSku  

                  IF @nTTL_PickedQty < (@nTTL_PackedQty + @nPackQty)  
                  BEGIN  
                     SET @nErrNo = 152768  
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
                     SET @nErrNo = 152769  
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
                        UPC = @cTrackNo, 
                        EditDate = GETDATE(),
                        EditWho  = SUSER_SNAME()
                  WHERE PickSlipNo = @cPickSlipNo AND SKU = @cPackSku AND DropID = @cDropID  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 152770        
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
                  SET @nErrNo = 152771  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPInfoFail'  
                  GOTO RollBackTran  
               END  
            END  
  
            /***************************  
            UPDATE rdtECOMMLog  
            ****************************/  
            DECLARE C_ECOMMLOG2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT RowRef  
            FROM rdt.rdtEcommLog WITH (NOLOCK)  
            WHERE ToteNo      = @cDropID  
            AND   Orderkey    = @cOrderkey  
            AND   AddWho      = @cUserName  
            AND   Status      < '5'  
            ORDER BY RowRef  
  
            OPEN C_ECOMMLOG2  
            FETCH NEXT FROM C_ECOMMLOG2 INTO  @nRowRef  
            WHILE (@@FETCH_STATUS <> -1)  
            BEGIN  
               UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)  
               SET   Status      = '9'    -- completed  
               WHERE RowRef      = @nRowRef  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 152772  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'  
                  GOTO RollBackTran  
               END  
  
               FETCH NEXT FROM C_ECOMMLOG2 INTO  @nRowRef  
            END  
            CLOSE C_ECOMMLOG2  
            DEALLOCATE C_ECOMMLOG2  

            -- check if total order fully despatched  
            SELECT @nTotalPickQty = SUM(ISNULL(PK.Qty,0))  
            FROM  dbo.PICKDETAIL PK WITH (nolock)  
            WHERE PK.Orderkey = @cOrderkey  
            AND PK.Status NOT IN ( '4' , '9' ) 
  
            SELECT @nTotalPackQty = SUM(ISNULL(PD.Qty,0))  
            FROM  dbo.PACKDETAIL PD WITH (NOLOCK)  
            JOIN  dbo.PACKHEADER PH WITH (NOLOCK) ON (PD.PickslipNo = PH.PickSlipNo AND PH.Orderkey = @cOrderkey)  
  
            -- Print Label  
            IF @nTotalPickQty = @nTotalPackQty  
            BEGIN  
               SET @nTotalPickQty = 0  
               SET @cOrderKeyOut = @cOrderkey  
  
               SET @cTrackNoFlag = '1'  
            END  
         END  
      END  

      SET @nTotalPickQty = 0  
      SELECT @nTotalPickQty = SUM(PD.QTY)  
      FROM PICKDETAIL PD WITH (NOLOCK)  
      WHERE PD.ORDERKEY = @cOrderKey  
      AND PD.Storerkey = @cStorerkey  
      AND PD.Status NOT IN ( '4' , '9' )
               
      SET @nTotalPackQty = 0  
      SELECT @nTotalPackQty = SUM(ScannedQty)  
      FROM rdt.rdtEcommLog WITH (NOLOCK)  
      WHERE OrderKey = @cOrderKey  
  
      IF @nTotalPickQty = @nTotalPackQty  
      BEGIN  
         IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                           WHERE PickSlipNo = @cPickslipNo
                           AND [Status] = '9')
         UPDATE dbo.PackHeader SET
            [Status] = '9',  
            Editdate   = GETDATE(),
            EditWho    = SUSER_SNAME()
         WHERE PickSlipNo = @cPickslipNo
                  
         IF  @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 152780  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PackCfm Fail'  
            GOTO RollBackTran  
         END  

         IF EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) 
                     WHERE PickSlipNo = @cPickslipNo 
                     AND   ISNULL( ScanOutDate, '') = '')
         BEGIN
            EXEC isp_ScanOutPickSlip
               @c_PickSlipNo = @cPickSlipNo,
               @n_err = @nErrNo OUTPUT,
               @c_errmsg = @cErrMsg OUTPUT
                     	
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 152773  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickInfoFail  
               GOTO RollBackTran  
            END  
         END
      END  
  
      SELECT @cTrackNo = TrackingNo  
      FROM dbo.Orders WITH (NOLOCK)  
      WHERE OrderKey = @cOrderKey  
               
      SET @cPickDetailKey = '' 
               
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND OrderKey = @cOrderkey 
                  GROUP BY StorerKey, OrderKey 
                  HAVING Count (DISTINCT PickDetailKey) = 1  )
      BEGIN 
         SELECT TOP 1 @cPickDetailKey = PickDetailKey
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey  
         AND OrderKey    = @cOrderkey  
         AND SKU         = @cSKU  

         -- PickDetail.CaseID = TrackNo  
         UPDATE dbo.PickDetail WITH (ROWLOCK)  
         SET CaseID     = @cLabelNo  
            ,Editdate   = GETDATE()
            ,EditWho    = SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
        
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 152774  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetailFail  
            GOTO RollBackTran  
         END  
      END  
      ELSE
      BEGIN
         DECLARE C_ECOM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT PickDetailKey
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey  
         AND OrderKey = @cOrderkey  
         AND SKU      = @cSKU  
         ORDER BY PickDetailKey
                    
         OPEN C_ECOM    
         FETCH NEXT FROM C_ECOM INTO  @cPickDetailKey
         WHILE (@@FETCH_STATUS <> -1)    
         BEGIN  
            -- PickDetail.CaseID = TrackNo  
            UPDATE dbo.PickDetail WITH (ROWLOCK)  
            SET CaseID     = @cLabelNo  
               ,Editdate   = GETDATE()
               ,EditWho    = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
                    
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 152775  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetailFail  
               GOTO RollBackTran  
            END  
                     
            FETCH NEXT FROM C_ECOM INTO  @cPickDetailKey
         END  
         CLOSE C_ECOM    
         DEALLOCATE C_ECOM  
      END
               
      SET @cLabelNo = @cTrackNo  
  
      -- Print Label  
      IF @nTotalPickQty = @nTotalPackQty  
      BEGIN  
         SET @nTotalPickQty = 0  
         SET @cOrderKeyOut = @cOrderkey  
  
         SET @cShipperKey = ''  
         SET @cOrderType = ''  
  
         SELECT @cShipperKey = ShipperKey  
               ,@cOrderType  = Type  
               ,@cSectionKey = RTRIM(SectionKey)  
               ,@cLoadKey = LoadKey
               ,@cTrackingNo = TrackingNo
               ,@cDocType = DocType
         FROM dbo.Orders WITH (NOLOCK)  
         WHERE OrderKey = @cOrderkey  
         AND StorerKey = @cStorerKey  

         IF ISNULL( @cPickSlipNo, '') = ''
            SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey  

         IF @cPickSlipNo = ''  
            SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadkey  

         -- Single packing
         SELECT TOP 1 @nCartonNo = CartonNo,
                      @cLabelNo = LabelNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickslipNo
         ORDER BY 1

         SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
         IF @cShipLabel = '0'
            SET @cShipLabel = ''
  
         IF @cShipLabel <> ''
         BEGIN
            DECLARE @tSHIPPLABEL AS VariableTable
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cPickSlipNo',   @cPickSlipNo)
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',     @cOrderKey)
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nToCartonNo',   @nCartonNo)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
               @cShipLabel,  -- Report type
               @tSHIPPLABEL, -- Report params
               'rdt_841ExtUpdSP12', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT 

            IF @nErrNo <> 0
               GOTO RollBackTran
         END
  
         SET @cDelNotes = rdt.RDTGetConfig( @nFunc, 'DelNotes', @cStorerKey)  
         IF @cDelNotes = '0'  
            SET @cDelNotes = ''  
  
         IF @cDelNotes <> ''  
         BEGIN  
            DECLARE @tDELNOTES AS VariableTable  
            INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cLoadKey',     @cLoadKey)  
            INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)  
            INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)  
            INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cTrackNo',     @cTrackNo)  
            INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@nCartonNo',    @nCartonNo)  
            INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cLabelNo',     @cLabelNo)  
  
            -- Print label  
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter,   
               @cDelNotes, -- Report type  
               @tDELNOTES, -- Report params  
               'rdt_841ExtUpdSP12',   
               @nErrNo  OUTPUT,  
               @cErrMsg OUTPUT   
  
            IF @nErrNo <> 0  
               GOTO Quit  
         END  

         IF @cTrackingNo <> '' AND @cShipperKey = 'QTS' AND @cDocType = 'E' 
         BEGIN
            SELECT @cLabelPrinter = Printer
            FROM rdt.rdtMobrec WITH (NOLOCK)
            WHERE Mobile = @nMobile

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 152776     
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Lbl Printer    
               GOTO RollBackTran    
            END

            SELECT @cWinPrinter = WinPrinter
            FROM rdt.rdtPrinter WITH (NOLOCK)  
            WHERE PrinterID = @cLabelPrinter

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 152777     
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No WinPrinter    
               GOTO RollBackTran   
            END
                  
            DECLARE @cur_Print CURSOR 
            SET @cur_Print = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
            SELECT Long, Notes, Code2, UDF01
            FROM dbo.CODELKUP WITH (NOLOCK)      
            WHERE LISTNAME = 'PrtbyShipK'      
            AND   Code = @cShipperKey
            AND   StorerKey = @cStorerKey
            ORDER BY Code
            OPEN @cur_Print
            FETCH NEXT FROM @cur_Print INTO @cFilePath, @cPrintFilePath, @cReportType, @cFilePrefix
            WHILE @@FETCH_STATUS = 0
            BEGIN
               IF CHARINDEX(',' , @cWinPrinter) > 0 
                  SET @cWinPrinterName = LEFT( @cWinPrinter , (CHARINDEX(',' , @cWinPrinter) - 1) )    
               ELSE
                  SET @cWinPrinterName = @cWinPrinter

               IF ISNULL( @cFilePath, '') = ''    
               BEGIN    
                  SET @nErrNo = 152778     
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup FilePath    
                  GOTO Quit   
               END

               SET @cFilePrefix = @cFilePrefix + CASE WHEN ISNULL( @cFilePrefix, '') <> '' THEN '_' ELSE '' END
               SET @cFileName = @cFilePrefix + RTRIM( @cTrackingNo) + '.pdf'     
               SET @cPrintCommand = '"' + @cPrintFilePath + '" "' + @cFilePath + '\' + @cFileName + '" "0" "3" "' + @cWinPrinterName + '"'                              

               DECLARE @tRDTPrintJob AS VariableTable
      
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
                  @cReportType,     -- Report type
                  @tRDTPrintJob,    -- Report params
                  'rdt_841ExtUpdSP12', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT,
                  1,
                  @cPrintCommand

	            IF @nErrNo <> 0
                  BREAK

               FETCH NEXT FROM @cur_Print INTO @cFilePath, @cPrintFilePath, @cReportType, @cFilePrefix
            END
         END

         IF @nErrNo <> 0
            GOTO RollBackTran

         SET @cSOStatus = ''  
         SELECT @cSOStatus = SOStatus  
         FROM dbo.Orders WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND OrderKey = @cOrderkey  
  
  
         UPDATE dbo.Orders WITH (ROWLOCK)  
         SET SOStatus= '0'
            ,TrafficCop = NULL
            ,Editdate   = GETDATE()
            ,EditWho    = SUSER_SNAME() 
         WHERE OrderKey = @cOrderkey  
         AND StorerKey = @cStorerKey  
  
         IF  @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 152779  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdOrdFail'  
            GOTO RollBackTran  
         END  
      END  
  
      DECLARE C_ECOMMLOG1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT RowRef  
      FROM rdt.rdtEcommLog WITH (NOLOCK)  
      WHERE ToteNo      = @cDropID  
      AND   SKU         = @cSKU  
      AND   Orderkey    = @cOrderkey  
      AND   AddWho      = @cUserName  
      AND   Status      < '5'  
      AND   ScannedQty  >= ExpectedQty  
  
      OPEN C_ECOMMLOG1  
      FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef  
      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN  
         /****************************  
            rdtECOMMLog  
         ****************************/  
         --update rdtECOMMLog  
         UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)  
         SET   Status      = '9'    -- completed  
         WHERE RowRef = @nRowRef  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 152781  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'  
            GOTO RollBackTran  
         END  
  
         FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef  
      END  
      CLOSE C_ECOMMLOG1  
      DEALLOCATE C_ECOMMLOG1  
   END  
  
   IF @nStep = 6  
   BEGIN  
      UPDATE dbo.Orders WITH (ROWLOCK) 
      SET UserDefine04 = @cTrackNo  
         ,TrafficCop   = NULL -- (ChewKP02)  
         ,Editdate     = GETDATE()
         ,EditWho      = SUSER_SNAME()
      WHERE Orderkey = @cPrevOrderkey  
      AND Storerkey = @cStorerKey  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 152782  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdOrderFail  
         GOTO RollBackTran  
      END  
  
      INSERT INTO rdt.rdtTrackLog ( Mobile, UserName, Storerkey, Orderkey, TrackNo, SKU, Qty, QtyAllocated)  
      VALUES (@nMobile, @cUserName, @cStorerkey, @cPrevOrderkey, @cDropID, @cSKU, 0 , '')  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 152783  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTrackLogFail  
         GOTO RollBackTran  
      END  

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
            SET @nErrNo = 152784  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsCtnShpmentDetFail  
            GOTO RollBackTran  
         END  
      END  

      SET @nTotalPickQty = 0  
      SELECT @nTotalPickQty = SUM(PD.QTY)  
      FROM PICKDETAIL PD WITH (NOLOCK)  
      WHERE PD.ORDERKEY = @cPrevOrderkey  
      AND PD.Storerkey = @cStorerkey  
      AND PD.Status NOT IN ( '4' , '9' ) 
  
      SET @nTotalPackQty = 0  
      SELECT @nTotalPackQty = SUM(ScannedQty)  
      FROM rdt.rdtEcommLog WITH (NOLOCK)  
      WHERE OrderKey = @cPrevOrderkey  

      IF @nTotalPickQty = @nTotalPackQty  
      BEGIN  
  
         SELECT @cPickSlipNo = PickHeaderKey  
         FROM dbo.PickHeader (NOLOCK)  
         WHERE OrderKey = @cPrevOrderkey  
  
         EXEC isp_ScanOutPickSlip
            @c_PickSlipNo = @cPickSlipNo,
            @n_err = @nErrNo OUTPUT,
            @c_errmsg = @cErrMsg OUTPUT
                  	  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 152785  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickInfoFail  
            GOTO RollBackTran  
         END  
  
      END  
      
      IF ISNULL(RTRIM(@cDropID),'')  = ''    
      BEGIN    
         -- PickDetail.CaseID = TrackNo    
         UPDATE dbo.PickDetail WITH (ROWLOCK)    
         SET CaseID     = @cTrackNo    
            ,TrafficCop = NULL
            ,Editdate   = GETDATE()
            ,EditWho    = SUSER_SNAME()
         WHERE StorerKey = @cStorerKey    
         AND OrderKey = @cPrevOrderkey    
         AND SKU      = @cSKU    
      END    
      ELSE    
      BEGIN    
         -- PickDetail.CaseID = TrackNo    
         UPDATE dbo.PickDetail WITH (ROWLOCK)    
         SET CaseID     = @cTrackNo    
            ,TrafficCop = NULL
            ,Editdate   = GETDATE()
            ,EditWho    = SUSER_SNAME()  
         WHERE StorerKey = @cStorerKey    
         AND OrderKey = @cPrevOrderkey    
         AND DropID   = @cDropID    
    
      END    

      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 152786  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetailFail  
         GOTO RollBackTran  
      END  
  
      IF @cGenPackDetail = '1'  
      BEGIN  
         SELECT @cPickSlipNo = PickSlipNo  
         FROM dbo.PackHeader (NOLOCK)  
         WHERE OrderKey = @cPrevOrderkey  
  
         -- update the existing packdetail labelno  
         UPDATE dbo.Packdetail WITH (ROWLOCK)  
         SET   UPC        = @cTrackNo
             , ArchiveCop = NULL
             , EditWho    = SUSER_SNAME()
             , EditDate   = GETDATE()   
         WHERE PickSlipNo = @cPickSlipNo  
   --      AND LabelNo = @cLabelNo  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 152787  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'  
            GOTO RollBackTran  
         END  
  
         -- check if total order fully despatched  
         SELECT @nTotalPickQty = SUM(ISNULL(PK.Qty,0))  
         FROM  dbo.PICKDETAIL PK WITH (nolock)  
         WHERE PK.Orderkey = @cOrderkey  
  
  
         SELECT @nTotalPackQty = SUM(ISNULL(PD.Qty,0))  
         FROM  dbo.PACKHEADER PH WITH (NOLOCK)  
         JOIN  dbo.PACKDETAIL PD WITH (NOLOCK) ON (PD.PickslipNo = PH.PickSlipNo)
         WHERE (PH.Orderkey = @cOrderkey)
  
         IF @nTotalPickQty = @nTotalPackQty  
         BEGIN  
            SET @cLabelNo = ''  
            SELECT Top 1  @cLabelNo = LabelNo  
            FROM dbo.PackDetail WITH (NOLOCK)  
            WHERE PickSlipNo = @cPickSlipNo  
            AND UPC = @cTrackNo  
         END  
      END  
      ELSE  
      BEGIN  
         SET @cLabelNo = @cTrackNo  
      END  
  
      -- Print Label  
      IF @nTotalPickQty = @nTotalPackQty  
      BEGIN  
         SET @nTotalPickQty = 0  
         SET @cOrderKeyOut = @cOrderkey  
  
         SET @cTrackNoFlag = '1'  
  
         SET @cShipperKey = ''  
         SET @cOrderType = ''  
  
         SELECT @cShipperKey = ShipperKey  
               ,@cOrderType  = Type  
               ,@cSectionKey = RTRIM(SectionKey)  
         FROM dbo.Orders WITH (NOLOCK)  
         WHERE OrderKey = @cPrevOrderkey  
         AND StorerKey = @cStorerKey  
  
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
            AND OrderKey = @cPrevOrderkey  

            UPDATE dbo.Orders WITH (ROWLOCK)  
               SET SOStatus= '0', 
                     TrafficCop = NULL, 
                     EditWho    = SUSER_SNAME(), 
                     EditDate   = GETDATE() 
            WHERE OrderKey = @cPrevOrderkey  
            AND StorerKey = @cStorerKey  
  
            IF  @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 152788  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdOrdFail'  
               GOTO RollBackTran  
            END  
         END  
  
         IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                         WHERE PickSlipNo = @cPickslipNo
                         AND   [Status] = '9')
         BEGIN
            UPDATE dbo.PackHeader SET   
               [Status] = '9',  
               Editdate   = GETDATE(),
               EditWho    = SUSER_SNAME()
            WHERE PickSlipNo = @cPickSlipNo  
            AND StorerKey = @cStorerKey  
  
            IF @@ERROR <>0  
            BEGIN  
               SET @nErrNo = 152789  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'  
               GOTO RollBackTran  
            END      
         END        
      END
   END        
        
   GOTO QUIT         
           
RollBackTran:        
   ROLLBACK TRAN rdt_841ExtUpdSP12 -- Only rollback change made here        
        
Quit:        
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started        
      COMMIT TRAN rdt_841ExtUpdSP12        
          
  
END  

GO