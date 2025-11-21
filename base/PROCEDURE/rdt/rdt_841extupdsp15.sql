SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/          
/* Store procedure: rdt_841ExtUpdSP15                                   */          
/* Copyright      : LF                                                  */          
/*                                                                      */          
/* Purpose: Ecomm Update SP                                             */          
/*                                                                      */          
/* Modifications log:                                                   */          
/* Date        Rev  Author   Purposes                                   */          
/* 2021-01-04  1.0  James    WMS-15988. Created                         */     
/* 2021-03-03  1.1  James    WMS-15988 Enhance labelno creation(james01)*/  
/* 2021-04-16  1.2  James    WMS-16024 Standarized use of TrackingNo    */  
/*                           (james02)                                  */  
/* 2021-04-01  1.3  YeeKung  WMS-16718 Add serialno and serialqty       */
/*                           Params (yeekung02)                         */  
/* 2021-07-27  1.4  Chermain WMS-17410 Add VariableTable Param (cc01)   */
/************************************************************************/          
        
CREATE   PROC [RDT].[rdt_841ExtUpdSP15] (          
   @nMobile     INT,          
   @nFunc       INT,          
   @cLangCode   NVARCHAR( 3),          
   @cUserName   NVARCHAR( 15),          
   @cFacility   NVARCHAR( 5),          
   @cStorerKey  NVARCHAR( 15),          
   @cDropID     NVARCHAR( 20),          
   @cSKU        NVARCHAR( 20),          
   @nStep       INT,          
   @cPickslipNo NVARCHAR( 10),          
   @cPrevOrderkey NVARCHAR(10),          
   @cTrackNo     NVARCHAR( 20),          
   @cTrackNoFlag NVARCHAR(1)   OUTPUT,          
   @cOrderKeyOut NVARCHAR(10)  OUTPUT,          
   @nErrNo       INT           OUTPUT,          
   @cErrMsg      NVARCHAR( 20) OUTPUT,    
   @cCartonType  NVARCHAR( 20) ='',  --(yeekung01)        
   @cSerialNo    NVARCHAR( 30),   
   @nSerialQTY   INT,
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
   SAVE TRAN rdt_841ExtUpdSP15          
          
          
   SELECT @cLabelPrinter = Printer          
         ,@cPaperPrinter = Printer_Paper          
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
          SET @nErrNo = 161755          
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
            SET @nErrNo = 161756          
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
         SET @nErrNo = 161757          
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
            SET @nErrNo = 161758          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'          
            GOTO RollBackTran          
         END          
          
         FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef          
          
      END          
      CLOSE C_ECOMMLOG1          
      DEALLOCATE C_ECOMMLOG1          
          
              
          
      IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Orderkey = @cOrderkey)        
      BEGIN        
        IF NOT EXISTS (SELECT 1 FROM dbo.PickHeader WITH (NOLOCK) WHERE Orderkey = @cOrderkey)        
        BEGIN       
          
            IF ISNULL(RTRIM(@cPickSlipno) ,'')=''          
            BEGIN          
                EXECUTE dbo.nspg_GetKey          
                'PICKSLIP',          
                9,          
                @cPickslipno OUTPUT,          
                @b_success OUTPUT,          
                @nErrNo OUTPUT,          
                @cErrMsg OUTPUT          
                
                IF @nErrNo<>0          
                BEGIN          
                    SET @nErrNo = 161779          
                    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GetDetKeyFail'          
                    GOTO RollBackTran          
                
                END          
                
                SELECT @cPickslipno = 'P'+@cPickslipno          
                
                
                
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
                    SET @nErrNo = 161780          
                    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InstPKHdrFail '          
                    GOTO RollBackTran          
                
                END          
                
                
            END --ISNULL(@cPickSlipno, '') = ''      
         END  
      END  
          
          
      IF NOT EXISTS ( SELECT 1          
                      FROM   dbo.PickingInfo WITH (NOLOCK)          
                      WHERE  PickSlipNo = @cPickSlipNo          )          
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
               SET @nErrNo = 161781          
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
                     SET @nErrNo = 161759          
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
                     --AND   Status = '5' -- (ChewKP01)             
                     AND   (Status IN ('3', '5') OR ShipFlag = 'P')          
                     AND   ISNULL(RTrim(Pickslipno),'') = ''          
          
                     IF @@ERROR <> 0          
                     BEGIN          
                        SET @nErrNo = 161760          
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
                  SET @nErrNo = 161761          
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
                  AND PD.DropID = @cDropID          
                  AND PD.PickSlipNo = @cPickSlipNo          
          
               SELECT @nSUM_PickQTY = ISNULL(SUM(Qty), 0)          
               FROM dbo.PickDetail PD WITH (NOLOCK)          
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey          
               WHERE PD.StorerKey = @cStorerKey          
                 AND PD.DropID = @cDropID          
                 AND (PD.Status IN ('3', '5') OR PD.ShipFlag = 'P')     -- Need FBR CKPXXX    
                 AND PH.PickHeaderKey = @cPickSlipNo          
    
                 --select @cDropID '@cDropID' , @cPickSlipNo '@cPickSlipNo' , @nSUM_PackQTY '@nSUM_PackQTY' , @nSUM_PickQTY '@nSUM_PickQTY'    
            END          
            ELSE          
            BEGIN          
               SELECT @nSUM_PackQTY = ISNULL(SUM(PD.QTY), 0)          
               FROM dbo.PackDetail PD WITH (NOLOCK)          
               WHERE PD.StorerKey = @cStorerKey          
                  --AND PD.DropID = @cDropID          
                  AND PD.PickSlipNo = @cPickSlipNo          
          
               SELECT @nSUM_PickQTY = ISNULL(SUM(Qty), 0)          
              FROM dbo.PickDetail PD WITH (NOLOCK)          
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey          
               WHERE PD.StorerKey = @cStorerKey          
                 --AND PD.DropID = @cDropID          
                 --AND PD.Status = '5'          
                 AND PH.PickHeaderKey = @cPickSlipNo          
            END          
          
          
            IF @nSUM_PackQTY = @nSUM_PickQTY          
            BEGIN          
               SET @nErrNo = 161751          
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
          
--               SET @cExecStatements = N'EXEC dbo.' + RTRIM( @cGenLabelNoSP) +          
--                                     '   @cPickslipNo           ' +          
--                                       ' , @nCartonNo             ' +          
--                                       ' , @cLabelNo     OUTPUT   '          
--          
--          
--               SET @cExecArguments =          
--                         N'@cPickslipNo  nvarchar(10),       ' +          
--                          '@nCartonNo    int,                ' +          
--                          '@cLabelNo     nvarchar(20) OUTPUT '          
--          
--          
--          
--               EXEC sp_executesql @cExecStatements, @cExecArguments,          
--                                    @cPickslipNo          
--                                  , @nCartonNo          
--                                  , @cLabelNo      OUTPUT          
--          
--               
               SELECT @cShipperKey = ShipperKey  
               FROM dbo.ORDERS WITH (NOLOCK)  
               WHERE OrderKey = @cOrderKey  
                 
               IF EXISTS ( SELECT 1   
                     FROM dbo.CODELKUP CLK WITH (NOLOCK)   
                     WHERE CLK.LISTNAME = 'CARTNTRACK'  
                     AND   CLK.Code = @cShipperKey  
                     AND   CLK.Storerkey = @cStorerkey)  
               BEGIN  
                  --SELECT @cTrackNo = UserDefine04          
                  SELECT @cTrackNo = TrackingNo -- (james02)  
                  FROM dbo.Orders WITH (NOLOCK)        
                  WHERE OrderKey = @cOrderkey          
                       
                  SET @cLabelNo = ISNULL(@cTrackNo ,'')         
               END  
               ELSE  
               BEGIN  
                  -- Get new LabelNo  
                  EXECUTE isp_GenUCCLabelNo  
                           @cStorerKey,  
                           @cLabelNo     OUTPUT,  
                           @bSuccess     OUTPUT,  
                           @nErrNo       OUTPUT,  
                           @cErrMsg      OUTPUT  
  
                  IF @bSuccess <> 1  
                  BEGIN  
                     SET @nErrNo = 161790  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Fail'  
                     GOTO RollBackTran  
                  END  
               END  
                                                 
               IF ISNULL(@cLabelNo,'')  = ''          
               BEGIN          
                     SET @nErrNo = 161771          
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoLabelNoGen          
                     GOTO RollBackTran          
               END          
          
               -- Generate TrackingNo          
--               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = ISNULL(RTRIM(@cGenTrackNoSP),'') AND type = 'P')          
--               BEGIN          
--          
--                  SET @cExecStatements = N'EXEC dbo.' + RTRIM( @cGenTrackNoSP) +          
--                                          '   @cPickslipNo           ' +          
--                                          ' , @nCartonNo             ' +          
--                                          ' , @cLabelNo              ' +          
--                                          ' , @cTrackNo     OUTPUT   '          
--          
--          
--    SET @cExecArguments =          
--                            N'@cPickslipNo  nvarchar(10),       ' +          
--                             '@nCartonNo    int,                ' +          
--                             '@cLabelNo     nvarchar(20) , ' +          
--                             '@cTrackNo     nvarchar(20) OUTPUT '          
--          
--          
--          
--                  EXEC sp_executesql @cExecStatements, @cExecArguments,          
--                                       @cPickslipNo          
--                                     , @nCartonNo          
--                                     , @cLabelNo          
--                                     , @cTrackNo      OUTPUT          
--          
--          
--          
--                  IF ISNULL(@cTrackNo,'')  = ''          
--                  BEGIN          
--                        SET @nErrNo = 161773          
--                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoTrackNoGenerated          
--                        GOTO RollBackTran          
--                  END          
--          
--                  -- INSERT INTO CartonShipmentDetail          
--                  INSERT INTO CartonShipmentDetail (StorerKey, OrderKey, LoadKey, TrackingNumber)          
--                  VALUES ( @cStorerKey, @cOrderKey, @cLoadKey, @cTrackNo )          
--          
--                  IF @@ERROR <> 0          
--                  BEGIN          
--                        SET @nErrNo = 161774          
--                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsCtnShpmentDetFail          
--                        GOTO RollBackTran          
--                  END          
--          
--          
--          
--               END          
--               ELSE          
--               BEGIN          
--   --                 SET @nErrNo = 161772          
--   --                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenTrackNoSPNotFound'          
--   --                 GOTO RollBackTran          
--                      SELECT @cTrackNo = UserDefine04          
--                      FROM dbo.Orders WITH (NOLOCK)          
--                      WHERE OrderKey = @cOrderkey          
--               END          
            END          
            ELSE          
            BEGIN          
               --SELECT @cTrackNo = UserDefine04          
               SELECT @cTrackNo = TrackingNo -- (james02)  
               FROM dbo.Orders WITH (NOLOCK)          
               WHERE OrderKey = @cOrderkey          
                              
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
   --         FROM dbo.PACKHEADER PH WITH (NOLOCK)          
   --         WHERE PH.Orderkey = @cOrderkey          
          
          
            SELECT @nPackQty = ISNULL(SUM(ECOMM.ScannedQTY), 0)          
            FROM   rdt.rdtECOMMLog ECOMM WITH (NOLOCK)          
            WHERE  ToTeNo = @cDropID          
            AND    Orderkey = @cOrderkey          
            AND    Status < '5'          
            AND    AddWho = @cUserName          
          
          
          
--            IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)          
--                                  WHERE StorerKey = @cStorerKey          
--                                  AND OrderKey = @cOrderKey          
--                                  AND ISNULL(UserDefine04,'')  = '' )          
--            BEGIN          
--               UPDATE dbo.Orders WITH (ROWLOCK)          
--               SET UserDefine04 = @cLabelNo          
--                  ,Trafficcop   = NULL -- (ChewKP02)        
--                  ,EditDate = GETDATE()        
--                  ,EditWho = SUSER_SNAME()        
--               WHERE Orderkey = @cOrderKey          
--               AND Storerkey = @cStorerKey          
--          
--               IF @@ERROR <> 0          
--               BEGIN          
--                     SET @nErrNo = 161775          
--                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdOrderFail          
--                     GOTO RollBackTran          
--               END          
--            END          
          
          
            IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)          
                            WHERE StorerKey = @cStorerKey          
                            AND DropID = @cDropID          
                            AND ISNULL(CaseID,'')  = ''          
                            --AND Status = '5' ) -- (ChewKP01)             
                            AND (Status IN ('3', '5') OR ShipFlag = 'P')) -- (ChewKP01)            
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
                     SET @nErrNo = 161776          
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
                     SET @nErrNo = 161762          
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
                        AND (PD.Status IN ('3', '5') OR PD.ShipFlag = 'P')  -- Need FBR CKP XXX      
                        AND PD.SKU = @cPackSku          
                        AND PH.PickHeaderKey = @cPickSlipNo          
                  END          
                  ELSE          
                  BEGIN          
                     SELECT @nTTL_PickedQty = ISNULL(SUM(PD.QTY), 0)          
                     FROM dbo.PickDetail PD WITH (NOLOCK)          
                     JOIN dbo.PickHeader PH WITH (NOLOCK) ON PD.OrderKey = PH.OrderKey          
                     WHERE PD.StorerKey = @cStorerKey          
                        --AND PD.Status = '5'          
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
                     SET @nErrNo = 161763          
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
                     SET @nErrNo = 161764          
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
               FROM PACKHEADER PH WITH (NOLOCK)          
               JOIN   PACKDETAIL PD WITH (NOLOCK) ON (PH.PickslipNo = PD.PickSlipNo)          
               WHERE  PH.Orderkey = @cOrderkey          
          
               IF @@ERROR <> 0          
               BEGIN          
                  SET @nErrNo = 161765          
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
                  SET @nErrNo = 161766          
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
            JOIN  dbo.PACKHEADER PH WITH (NOLOCK) ON (PD.PickslipNo = PH.PickSlipNo )          
            WHERE PD.StorerKey = @cStorerKey        
            AND   PH.Orderkey = @cOrderkey        
          
            -- Print Label          
            IF @nTotalPickQty = @nTotalPackQty          
            BEGIN          
               SELECT @cPickSlipNo = PickHeaderKey          
               FROM dbo.PickHeader (NOLOCK)          
               WHERE OrderKey = @cOrderKey          
          
               UPDATE dbo.PackHeader WITH (ROWLOCK)          
               SET Status = '9'          
                   ,Editdate   = GETDATE()        
                   ,EditWho    = SUSER_SNAME()        
               WHERE PickSlipNo = @cPickSlipNo          
               AND StorerKey = @cStorerKey          
          
               IF @@ERROR <> 0          
               BEGIN          
                   SET @nErrNo = 161788          
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPackHdrFail          
                   GOTO RollBackTran          
               END          
                        
                       
          
               -- Print Label via BarTender --          
               SET @cRDTBartenderSP = ''          
               SET @cRDTBartenderSP = rdt.RDTGetConfig( @nFunc, 'RDTBartenderSP', @cStorerkey)          
               IF @cRDTBartenderSP = '0'          
                  SET @cRDTBartenderSP = ''          
          
          
               IF @cRDTBartenderSP <> ''          
               BEGIN          
          
                     IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRDTBartenderSP AND type = 'P')          
                     BEGIN          
          
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
               ELSE        
               BEGIN   
                  -- Common params ofr printing        
                  DECLARE @tSHIPPLABEL       VariableTable        
                  DECLARE @tDelNotes         VariableTable  
                  DECLARE @tDelNotesN        VariableTable  
                  DECLARE @tRtnNotes         VariableTable  
                  DECLARE @tRtnNotesN         VariableTable  
                  DECLARE @cShipLabel        NVARCHAR( 10)          
                  DECLARE @cDelNotes         NVARCHAR( 10)          
                  DECLARE @cDelNotesN        NVARCHAR( 10)  
                  DECLARE @cRtnNotes         NVARCHAR( 10)          
                  DECLARE @cRtnNotesN        NVARCHAR( 10)  
                  DECLARE @cOrdType          NVARCHAR( 1)  
                  DECLARE @cUserDefine03     NVARCHAR( 20)  
                  DECLARE @cC_ISOCntryCode   NVARCHAR( 10)  
  
                  SELECT @cOrdType = DocType,  
                         @cUserDefine03 = UserDefine03,  
                         @cC_ISOCntryCode = C_ISOCntryCode,  
                         @cFacility = Facility,  
                         @cShipperKey = ShipperKey  
                  FROM dbo.Orders WITH (NOLOCK)   
                  WHERE OrderKey = @cOrderKey  
            
                  SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)          
                  IF @cShipLabel = '0'          
                     SET @cShipLabel = ''        
  
                  IF @cOrdType = 'E' AND EXISTS (  
                     SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)  
                     WHERE LISTNAME = 'CartnTrack'  
                     AND   Code = @cShipperKey  
                     AND   Storerkey = @cStorerkey)  
                  BEGIN  
                     IF @cShipLabel <> ''          
                     BEGIN          
                        SELECT TOP 1 @nCartonNo = CartonNo          
                        FROM dbo.PackDetail WITH (NOLOCK)          
                        WHERE PickSlipNo = @cPickSlipNo          
                        AND   DropID = @cDropID          
                        ORDER BY 1          
          
                        SET @nErrNo = 0          
                        INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',       @cOrderKey)          
                        INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nFromCartonNo',   @nCartonNo)        
                        INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nToCartonNo',     @nCartonNo)            
                             
                        -- Print label          
                        EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerkey, @cLabelPrinter, '',           
                           @cShipLabel, -- Report type          
                           @tSHIPPLABEL, -- Report params          
                           'rdt_841ExtUpdSP15',           
                           @nErrNo  OUTPUT,          
                           @cErrMsg OUTPUT           
  
                        IF @nErrNo <> 0          
                        BEGIN          
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')           
                           GOTO RollBackTran          
                        END           
                     END          
                  END  
                       
                  IF @cOrdType = 'E' AND @cUserDefine03 <> 'FF'   
                  BEGIN  
                     SELECT @cPaperPrinter = Printer_Paper  
                     FROM rdt.RDTMOBREC WITH (NOLOCK)  
                     WHERE Mobile = @nMobile  
  
                     IF @cC_ISOCntryCode = 'KR'  
                     BEGIN  
                        SET @cDelNotes = rdt.RDTGetConfig( @nFunc, 'DelNotes', @cStorerKey)          
                        IF @cDelNotes = '0'          
                        SET @cDelNotes = ''        
  
                        SET @cRtnNotes = rdt.RDTGetConfig( @nFunc, 'RtnNotes', @cStorerKey)          
                        IF @cRtnNotes = '0'          
                        SET @cRtnNotes = ''        
  
                        IF @cDelNotes <> ''  
                        BEGIN  
                           INSERT INTO @tDelNotes (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)    
                           INSERT INTO @tDelNotes (Variable, Value) VALUES ( '@cC_ISOCntryCode', @cC_ISOCntryCode)  
                           INSERT INTO @tDelNotes (Variable, Value) VALUES ( '@cFacility', @cFacility)  
   
                          -- Print label    
                          EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,     
                             @cDelNotes, -- Report type    
                            @tDelNotes, -- Report params    
                             'rdt_841ExtUpdSP15',     
                             @nErrNo  OUTPUT,    
                             @cErrMsg OUTPUT    
                        END  
  
                        IF @cRtnNotes <> ''  
                        BEGIN  
                           INSERT INTO @tRtnNotes (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)    
                           INSERT INTO @tRtnNotes (Variable, Value) VALUES ( '@cC_ISOCntryCode', @cC_ISOCntryCode)  
                           INSERT INTO @tRtnNotes (Variable, Value) VALUES ( '@cFacility', @cFacility)  
  
                          -- Print label    
                          EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,     
                             @cRtnNotes, -- Report type    
                             @tRtnNotes, -- Report params    
                             'rdt_841ExtUpdSP15',     
                             @nErrNo  OUTPUT,    
                             @cErrMsg OUTPUT    
                        END  
                     END  
                     ELSE  
                     BEGIN  
                        SET @cDelNotesN = rdt.RDTGetConfig( @nFunc, 'DelNotesN', @cStorerKey)          
                        IF @cDelNotesN = '0'          
                        SET @cDelNotesN = ''        
  
                        SET @cRtnNotesN = rdt.RDTGetConfig( @nFunc, 'RtnNotesN', @cStorerKey)          
                        IF @cRtnNotesN = '0'          
                        SET @cRtnNotesN = ''        
  
                        IF @cDelNotesN <> ''  
                        BEGIN  
                           INSERT INTO @tDelNotesN (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)    
                           INSERT INTO @tDelNotesN (Variable, Value) VALUES ( '@cC_ISOCntryCode', @cC_ISOCntryCode)  
                           INSERT INTO @tDelNotesN (Variable, Value) VALUES ( '@cFacility', @cFacility)  
   
                          -- Print label    
                          EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,     
                             @cDelNotesN, -- Report type    
                             @tDelNotesN, -- Report params    
                             'rdt_841ExtUpdSP15',     
                             @nErrNo  OUTPUT,    
                             @cErrMsg OUTPUT    
                        END  
  
                        IF @cRtnNotesN <> ''  
                        BEGIN  
                           INSERT INTO @tRtnNotesN (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)    
                           INSERT INTO @tRtnNotesN (Variable, Value) VALUES ( '@cC_ISOCntryCode', @cC_ISOCntryCode)  
                           INSERT INTO @tRtnNotesN (Variable, Value) VALUES ( '@cFacility', @cFacility)  
  
                          -- Print label    
                          EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,     
                             @cRtnNotesN, -- Report type    
                             @tRtnNotesN, -- Report params    
                             'rdt_841ExtUpdSP15',     
                             @nErrNo  OUTPUT,    
                             @cErrMsg OUTPUT    
                        END  
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
               WHERE OrderKey = @cOrderkey          
               AND StorerKey = @cStorerKey          
          
          
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
                     SET @nErrNo = 161789          
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdOrdFail'          
                     GOTO RollBackTran          
                  END          
          
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
        
          
               IF @cPaperPrinter <> 'PDF' AND @cPaperPrinter <> '' --JYHBIN        
               BEGIN        
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
                           
        
               END        
                       
                       
               SET @nTotalPickQty = 0          
               SET @cOrderKeyOut = @cOrderkey          
          
               SET @cTrackNoFlag = '1'          
            END          
          
          
          
         END          
          
   END          
      ELSE          
      BEGIN          
          
            SET @cShowTrackNoScn = rdt.RDTGetConfig( @nFunc, 'ShowTrackNoScn', @cStorerKey)          
          
            IF @cShowTrackNoScn <> '1'          
            BEGIN          
          
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
          
                  SELECT @cPickSlipNo = PickHeaderKey          
                  FROM dbo.PickHeader (NOLOCK)          
                  WHERE OrderKey = @cOrderKey          
          
                  EXEC isp_ScanOutPickSlip        
                     @c_PickSlipNo = @cPickSlipNo,        
                     @n_err = @nErrNo OUTPUT,        
                     @c_errmsg = @cErrMsg OUTPUT        
                              
                  --Update dbo.PickingInfo          
                  --SET ScanOutDate = GetDate()          
                  --WHERE PickSlipNo = @cPickSlipNo          
          
                  IF @@ERROR <> 0          
                  BEGIN          
                     SET @nErrNo = 161786          
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickInfoFail          
                     GOTO RollBackTran          
                  END          
          
               END          
          
               --SELECT @cTrackNo = UserDefine04          
               SELECT @cTrackNo = TrackingNo -- (james02)  
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
                    SET CaseID     = @cTrackNo          
                  ,TrafficCop = NULL        
                       ,Editdate   = GETDATE()        
                       ,EditWho    = SUSER_SNAME()        
                    WHERE StorerKey = @cStorerKey          
                    AND PickDetailKey = @cPickDetailKey        
                
                    IF @@ERROR <> 0          
                    BEGIN          
                          SET @nErrNo = 161785          
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
                     SET CaseID     = @cTrackNo          
                        ,TrafficCop = NULL        
                        ,Editdate   = GETDATE()        
                        ,EditWho = SUSER_SNAME()        
                     WHERE StorerKey = @cStorerKey          
                     AND PickDetailKey = @cPickDetailKey        
                
                     IF @@ERROR <> 0          
                     BEGIN          
                           SET @nErrNo = 161785          
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
          
          
                  -- Print Label via BarTender --          
                  SET @cRDTBartenderSP = ''          
                  SET @cRDTBartenderSP = rdt.RDTGetConfig( @nFunc, 'RDTBartenderSP', @cStorerkey)          
          
          
                  IF @cRDTBartenderSP <> ''          
         BEGIN          
          
                        IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRDTBartenderSP AND type = 'P')          
                        BEGIN          
          
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
                  WHERE OrderKey = @cOrderkey          
                  AND StorerKey = @cStorerKey          
          
          
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
                        SET @nErrNo = 161787          
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdOrdFail'          
                        GOTO RollBackTran          
                     END          
          
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
        
          
                  IF @cPaperPrinter <> 'PDF' AND @cPaperPrinter <> '' --JYHBIN        
                  BEGIN        
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
                              
        
                  END        
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
                  SET @nErrNo = 161766          
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'          
                  GOTO RollBackTran          
               END          
          
               FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef          
          
            END          
            CLOSE C_ECOMMLOG1          
            DEALLOCATE C_ECOMMLOG1          
          
          
          
          
      END          
          
          
          
   END          
          
--   IF @nStep = 6          
--   BEGIN          
--          
--          
--      UPDATE dbo.Orders WITH (ROWLOCK)         
--      SET UserDefine04 = @cTrackNo          
--         ,TrafficCop   = NULL -- (ChewKP02)          
--         ,Editdate     = GETDATE()        
--         ,EditWho      = SUSER_SNAME()        
--      WHERE Orderkey = @cPrevOrderkey          
--      AND Storerkey = @cStorerKey          
--          
--    IF @@ERROR <> 0          
--      BEGIN          
--            SET @nErrNo = 161768          
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdOrderFail          
--            GOTO RollBackTran          
--      END          
--          
--      INSERT INTO rdt.rdtTrackLog ( Mobile, UserName, Storerkey, Orderkey, TrackNo, SKU, Qty, QtyAllocated)          
--      VALUES (@nMobile, @cUserName, @cStorerkey, @cPrevOrderkey, @cDropID, @cSKU, 0 , '')          
--          
--      IF @@ERROR <> 0          
--      BEGIN          
--            SET @nErrNo = 161769          
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTrackLogFail          
--            GOTO RollBackTran          
--      END          
--          
--      --Insert into Traceinfo (tracename , timein , col1 ,col2 , col3 , col4 , col5 )          
--      --Values ( 'Step6' , getdate(), @cTrackNo , @cPrevOrderkey , @cPickSlipNo, '' ,'' )          
--          
--      IF NOT EXISTS ( SELECT 1 FROM dbo.CartonShipmentDetail WITH (NOLOCK)          
--                      WHERE TrackingNumber = @cTrackNo          
--                      AND StorerKey = @cStorerKey          
--                      AND OrderKey = @cPrevOrderkey )          
--      BEGIN          
--         -- INSERT INTO CartonShipmentDetail          
--         INSERT INTO CartonShipmentDetail (StorerKey, OrderKey, LoadKey, TrackingNumber)          
--         VALUES ( @cStorerKey, @cPrevOrderkey, @cLoadKey, @cTrackNo )          
--          
--         IF @@ERROR <> 0          
--         BEGIN          
--               SET @nErrNo = 161777          
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsCtnShpmentDetFail          
--               GOTO RollBackTran          
--         END          
--      END          
--          
--          
--          
--          
--      SET @nTotalPickQty = 0          
--      SELECT @nTotalPickQty = SUM(PD.QTY)          
--      FROM PICKDETAIL PD WITH (NOLOCK)          
--      WHERE PD.ORDERKEY = @cPrevOrderkey          
--      AND PD.Storerkey = @cStorerkey          
--      AND PD.Status NOT IN ( '4' , '9' )         
--          
--      SET @nTotalPackQty = 0          
--      SELECT @nTotalPackQty = SUM(ScannedQty)          
--      FROM rdt.rdtEcommLog WITH (NOLOCK)          
--      WHERE OrderKey = @cPrevOrderkey          
--          
--          
--          
--      IF @nTotalPickQty = @nTotalPackQty          
--      BEGIN          
--          
--         SELECT @cPickSlipNo = PickHeaderKey          
--         FROM dbo.PickHeader (NOLOCK)          
--         WHERE OrderKey = @cPrevOrderkey          
--          
--         EXEC isp_ScanOutPickSlip        
--            @c_PickSlipNo = @cPickSlipNo,        
--            @n_err = @nErrNo OUTPUT,        
--            @c_errmsg = @cErrMsg OUTPUT        
--                             
--         --Update dbo.PickingInfo WITH (ROWLOCK)        
--         --SET ScanOutDate = GetDate()          
--         --WHERE PickSlipNo = @cPickSlipNo          
--          
--         IF @@ERROR <> 0          
--         BEGIN          
--            SET @nErrNo = 161782          
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickInfoFail          
--            GOTO RollBackTran          
--         END          
--          
--      END          
--              
--      IF ISNULL(RTRIM(@cDropID),'')  = ''            
--      BEGIN            
--         -- PickDetail.CaseID = TrackNo            
--         UPDATE dbo.PickDetail WITH (ROWLOCK)            
--         SET CaseID     = @cTrackNo            
--            ,TrafficCop = NULL        
--            ,Editdate   = GETDATE()        
--            ,EditWho    = SUSER_SNAME()        
--         WHERE StorerKey = @cStorerKey            
--         AND OrderKey = @cPrevOrderkey            
--         AND SKU      = @cSKU            
--      END            
--      ELSE            
--      BEGIN            
--         -- PickDetail.CaseID = TrackNo            
--         UPDATE dbo.PickDetail WITH (ROWLOCK)            
--         SET CaseID     = @cTrackNo            
--            ,TrafficCop = NULL        
--            ,Editdate   = GETDATE()        
--            ,EditWho    = SUSER_SNAME()          
--         WHERE StorerKey = @cStorerKey            
--         AND OrderKey = @cPrevOrderkey            
--         AND DropID   = @cDropID            
--            
--      END            
--          
--          
--      IF @@ERROR <> 0          
--      BEGIN          
--            SET @nErrNo = 161784          
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetailFail          
--            GOTO RollBackTran          
--      END          
--          
--          
--          
--      IF @cGenPackDetail = '1'          
--      BEGIN          
--          
--         SELECT @cPickSlipNo = PickSlipNo          
--         FROM dbo.PackHeader (NOLOCK)          
--         WHERE OrderKey = @cPrevOrderkey          
--          
--         -- update the existing packdetail labelno          
--         UPDATE dbo.Packdetail WITH (ROWLOCK)          
--         SET   UPC        = @cTrackNo        
--             , ArchiveCop = NULL        
--             , EditWho    = SUSER_SNAME()        
--             , EditDate   = GETDATE()           
--         WHERE PickSlipNo = @cPickSlipNo          
--   --      AND LabelNo = @cLabelNo          
--          
--         IF @@ERROR <> 0          
--         BEGIN          
--  SET @nErrNo = 161762          
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'          
--            GOTO RollBackTran          
--         END          
--          
--         -- check if total order fully despatched          
--         SELECT @nTotalPickQty = SUM(ISNULL(PK.Qty,0))          
--         FROM  dbo.PICKDETAIL PK WITH (nolock)          
--         WHERE PK.Orderkey = @cOrderkey          
--          
--          
--         SELECT @nTotalPackQty = SUM(ISNULL(PD.Qty,0))          
--         FROM  dbo.PACKHEADER PH WITH (NOLOCK)          
--         JOIN  dbo.PACKDETAIL PD WITH (NOLOCK) ON (PD.PickslipNo = PH.PickSlipNo)        
--         WHERE (PH.Orderkey = @cOrderkey)        
--          
--         IF @nTotalPickQty = @nTotalPackQty          
--         BEGIN          
--                    
--          
--            SET @cLabelNo = ''          
--            SELECT Top 1  @cLabelNo = LabelNo          
--            FROM dbo.PackDetail WITH (NOLOCK)          
--            WHERE PickSlipNo = @cPickSlipNo          
--            AND UPC = @cTrackNo          
--          
--         END          
--      END          
--      ELSE          
--      BEGIN          
--         SET @cLabelNo = @cTrackNo          
--      END          
--          
--          
--      -- Print Label          
--      IF @nTotalPickQty = @nTotalPackQty          
--      BEGIN          
--         SET @nTotalPickQty = 0          
--         SET @cOrderKeyOut = @cOrderkey          
--          
--         SET @cTrackNoFlag = '1'          
--          
--         -- Print Label via BarTender --          
--         SET @cRDTBartenderSP = ''          
--         SET @cRDTBartenderSP = rdt.RDTGetConfig( @nFunc, 'RDTBartenderSP', @cStorerkey)          
--          
--          
--         IF @cRDTBartenderSP <> ''          
--         BEGIN          
--          
--               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRDTBartenderSP AND type = 'P')          
--               BEGIN          
--          
--          
--                  SET @cExecStatements = N'EXEC rdt.' + RTRIM( @cRDTBartenderSP) +          
--                                          '   @nMobile               ' +          
--                                          ' , @nFunc                 ' +          
--                                          ' , @cLangCode             ' +          
--                                          ' , @cFacility             ' +          
--                                          ' , @cStorerKey            ' +          
--                                          ' , @cLabelPrinter         ' +          
--                                          ' , @cDropID               ' +          
--                                          ' , @cLoadKey              ' +          
--                                          ' , @cLabelNo              ' +          
--                                          ' , @cUserName             ' +          
--                                          ' , @nErrNo       OUTPUT   ' +          
--                                          ' , @cErrMSG      OUTPUT   '          
--          
--          
--                  SET @cExecArguments =          
--                             N'@nMobile     int,                   ' +          
--                             '@nFunc       int,                    ' +          
--                             '@cLangCode   nvarchar(3),            ' +          
--                             '@cFacility   nvarchar(5),            ' +          
--                             '@cStorerKey  nvarchar(15),           ' +          
--                             '@cLabelPrinter     nvarchar(10),     ' +          
--                             '@cDropID     nvarchar(20),           ' +          
--                             '@cLoadKey    nvarchar(10),           ' +          
--                             '@cLabelNo    nvarchar(20),           ' +          
--                             '@cUserName   nvarchar(18),           ' +          
--                             '@nErrNo      int  OUTPUT,            ' +          
--                             '@cErrMsg     nvarchar(1024) OUTPUT   '          
--          
--          
--          
--                  EXEC sp_executesql @cExecStatements, @cExecArguments,          
--                              @nMobile          
--                                      , @nFunc          
--                                      , @cLangCode          
--                                      , @cFacility          
--                                      , @cStorerKey          
--                                      , @cLabelPrinter          
--                                      , @cDropID          
--  , @cLoadKey          
--                                      , @cLabelNo          
--                                      , @cUserName          
--                                      , @nErrNo       OUTPUT          
--                                      , @cErrMSG      OUTPUT          
--          
--                   IF @nErrNo <> 0          
--                   BEGIN          
--                      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidCarton'          
--                      GOTO RollBackTran          
--                   END          
--          
--          
--               END          
--          
--          
--          
--         END          
--          
--         SELECT @cDataWindow = DataWindow,          
--               @cTargetDB = TargetDB          
--         FROM rdt.rdtReport WITH (NOLOCK)          
--         WHERE StorerKey = @cStorerKey          
--         AND   ReportType = 'BAGMANFEST'          
--          
--         SET @cShipperKey = ''          
--         SET @cOrderType = ''          
--          
--         SELECT @cShipperKey = ShipperKey          
--               ,@cOrderType  = Type          
--               ,@cSectionKey = RTRIM(SectionKey)          
--         FROM dbo.Orders WITH (NOLOCK)          
--         WHERE OrderKey = @cPrevOrderkey          
--         AND StorerKey = @cStorerKey          
--          
--         --INSERT INTO TRACEINFO (TraceName, TimeIn, Step1 , Step2, Step3 )          
--         --VALUES ( 'rdt_841ExtUpdSP15', GetDate() , '1' , @cOrderKey, @cOrderType )          
--          
--         -- Build PrintJob for RDT Spooler --          
--         IF @cOrderType = 'TMALL'          
--         BEGIN          
--          
--            -- Trigger WebService --          
--            EXEC  [isp_WS_UpdPackOrdSts]          
--              @cOrderKey          
--            , @cStorerKey          
--            , @bSuccess OUTPUT          
--            , @nErrNo    OUTPUT          
--            , @cErrMsg   OUTPUT          
--          
--         END          
--         ELSE          
--         BEGIN          
--            SET @cSOStatus = ''          
--            SELECT @cSOStatus = SOStatus          
--            FROM dbo.Orders WITH (NOLOCK)          
--            WHERE StorerKey = @cStorerKey          
--            AND OrderKey = @cPrevOrderkey          
--          
--            --INSERT INTO TRACEINFO (TraceName, TimeIn, Step1 , Step2, Step3 )          
--            --VALUES ( 'rdt_841ExtUpdSP15', GetDate() , '1.1' , @cOrderKey, @cSOStatus )          
--          
--   -- P01)          
--   --         IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)          
--   --                     WHERE OrderKey = @cOrderKey          
--   --                     AND StorerKey = @cStorerKey          
--   --                     AND SOStatus <> '0' )          
--   --         BEGIN          
--               --INSERT INTO TRACEINFO (TraceName, TimeIn, Step1 , Step2, Step3, Step4 )          
--               --VALUES ( 'rdt_841ExtUpdSP15', GetDate() , '1.2' , @cOrderKey, @cSOStatus, @cStorerKey )          
--          
--               UPDATE dbo.Orders WITH (ROWLOCK)          
--                  SET SOStatus= '0',         
--                      TrafficCop = NULL,         
--                      EditWho    = SUSER_SNAME(),         
--                      EditDate   = GETDATE()         
--               WHERE OrderKey = @cPrevOrderkey          
--               AND StorerKey = @cStorerKey          
--          
--               IF  @@ERROR <> 0          
--               BEGIN          
--                  SET @nErrNo = 161778          
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdOrdFail'          
--                  GOTO RollBackTran          
--               END          
--   --         END          
--   --         ELSE          
--   --         BEGIN      --   --            INSERT INTO TRACEINFO (TraceName, TimeIn, Step1 , Step2, Step3, Step4 )          
--   --            VALUES ( 'rdt_841ExtUpdSP15', GetDate() , '1.3' , @cOrderKey, @cSOStatus, @cStorerKey )          
--   --         END          
--         END          
--          
--         IF EXISTS ( SELECT 1 FROM dbo.CodeLkup WITH (NOLOCK)          
--                         WHERE ListName = 'DTCPrinter' )          
--         BEGIN          
--          
--          
--            -- Get Printer Information          
--            SELECT @cPrinter01 = RTRIM(Code)          
--                  ,@cBrand01   = RTRIM(Short)          
--                  ,@cPrinter02 = RTRIM(UDF01)          
--                  ,@cBrand02   = RTRIM(UDF02)          
--            FROM dbo.CodeLkup WITH (NOLOCK)          
--            WHERE ListName = 'DTCPrinter'          
--            AND RTRIM(Code) = ISNULL(RTRIM(@cPaperPrinter),'')          
--          
--          
--            IF @cSectionKey = @cBrand01          
--            BEGIN          
--               SET @cPaperPrinter = @cPrinter01          
--            END          
--            ELSE IF @cSectionKey = @cBrand02          
--            BEGIN          
--               SET @cPaperPrinter = @cPrinter02          
--            END          
--          
--         END          
--          
--         IF @cPaperPrinter <> 'PDF' AND @cPaperPrinter <> '' --JYHBIN        
--         BEGIN        
--            EXEC RDT.rdt_BuiltPrintJob          
--             @nMobile,          
--             @cStorerKey,          
--             'BAGMANFEST',              -- ReportType          
--             'ANF_CUSTOMERMANIFEST',    -- PrintJobName          
--             @cDataWindow,          
--             @cPaperPrinter,          
--             @cTargetDB,          
--             @cLangCode,          
--             @nErrNo  OUTPUT,          
--             @cErrMsg OUTPUT,          
--             @cPrevOrderkey,          
--             @cLabelNo         
--                     
--        
--         END                            
--         
--                    
--                      
--                         
--          UPDATE dbo.PackHeader WITH (ROWLOCK)          
--          SET Status = '9'          
--             ,Editdate   = GETDATE()        
--             ,EditWho    = SUSER_SNAME()        
--          WHERE PickSlipNo = @cPickSlipNo          
--          AND StorerKey = @cStorerKey          
--          
--          IF @@ERROR <>0          
--          BEGIN          
--             SET @nErrNo = 161783          
--             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'          
--             GOTO RollBackTran          
--          END              
--                      
--      END                
--                    
--                
--                      
--                            
--   END                
                
   GOTO QUIT                 
                   
RollBackTran:                
   ROLLBACK TRAN rdt_841ExtUpdSP15 -- Only rollback change made here                
                
Quit:                
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started                
      COMMIT TRAN rdt_841ExtUpdSP15                
                  
          
END   

GO