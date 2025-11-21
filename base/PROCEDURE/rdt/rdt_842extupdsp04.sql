SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_842ExtUpdSP04                                   */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: VF- VANS DTC Logic                                          */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2018-10-18  1.0  James    WMS-6262 Created                           */  
/* 2020-06-17  1.1  James    WMS-13504 Printing process fix (james01)   */
/* 2021-04-16  1.2  James    WMS-16024 Standarized use of TrackingNo    */
/*                           (james02)                                  */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_842ExtUpdSP04] (  
   @nMobile        INT,              
   @nFunc          INT,              
   @cLangCode      NVARCHAR(3),      
   @nStep          INT,              
   @cUserName      NVARCHAR( 18),     
   @cFacility      NVARCHAR( 5),      
   @cStorerKey     NVARCHAR( 15),     
   @cDropID        NVARCHAR( 20),     
   @cSKU           NVARCHAR( 20),     
   @cOption        NVARCHAR( 1),      
   @cOrderKey      NVARCHAR( 10) OUTPUT,    
   @cTrackNo       NVARCHAR( 20) OUTPUT,    
   @cCartonType    NVARCHAR( 10) OUTPUT, 
   @cWeight        NVARCHAR( 20) OUTPUT,   
   @cTaskStatus    NVARCHAR( 20) OUTPUT,   
   @cTTLPickedQty  NVARCHAR( 10) OUTPUT, 
   @cTTLScannedQty NVARCHAR( 10) OUTPUT, 
   @nErrNo         INT OUTPUT,    
   @cErrMsg        NVARCHAR( 20) OUTPUT  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nTranCount        INT  
          ,@nSUM_PackQTY      INT  
          ,@nSUM_PickQTY      INT  
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
          ,@cPaperPrinter     NVARCHAR(10)  
          ,@cDataWindow       NVARCHAR(50)  
          ,@cTargetDB         NVARCHAR(20)  
          ,@cOrderType        NVARCHAR(10)  
          ,@cShipperKey       NVARCHAR(10)  
          ,@cPrinter02        NVARCHAR(10)  
          ,@cBrand01          NVARCHAR(10)  
          ,@cBrand02          NVARCHAR(10)  
          ,@cPrinter01        NVARCHAR(10)  
          ,@cSectionKey       NVARCHAR(10)  
          ,@cSOStatus         NVARCHAR(10)  
          ,@cPickSlipNo       NVARCHAR(10)
          ,@cLoadKey          NVARCHAR(10)
          ,@nTotalScannedQty  INT
          ,@nTotalPickedQty   INT
          ,@nRowRef           INT
          ,@cPostDataCapture  NVARCHAR(5)
          ,@cBatchKey         NVARCHAR(10) 
          ,@cToteOrderKey     NVARCHAR(10) 
          ,@nDropIDCount      INT
          ,@cExternOrderKey   NVARCHAR(30)

   DECLARE  @fCartonWeight       FLOAT
           ,@fCartonLength       FLOAT
           ,@fCartonHeight       FLOAT
           ,@fCartonWidth        FLOAT
           ,@fStdGrossWeight     FLOAT
           ,@fCartonTotalWeight  FLOAT
           ,@fCartonCube         FLOAT
           ,@nTotalPackedQty     INT
           ,@cManifestDataWindow NVARCHAR(50) 
           ,@nMaxCartonNo        INT
           ,@nMinCartonNo        INT
           ,@fTTLWeight          FLOAT
           ,@nPickQty            INT
           ,@cDropOrderKey       NVARCHAR(10) 
           ,@cFilePath           NVARCHAR(100)       
           ,@cPrintFilePath      NVARCHAR(100)      
           ,@cPrintCommand       NVARCHAR(MAX)    
           ,@cWinPrinter         NVARCHAR(128)  
           ,@cPrinterName        NVARCHAR(100)   
           ,@cWinPrinterName     NVARCHAR(100)   
           ,@cFileName           NVARCHAR( 50)          
           ,@cPrinterInGroup     NVARCHAR( 10)          
           ,@cPaperType          NVARCHAR( 10)

   DECLARE @cTrackingNo    NVARCHAR( 20)
   DECLARE @cReportType    NVARCHAR( 10)
   DECLARE @cProcessType   NVARCHAR( 15)

   SET @nErrNo   = 0  
   SET @cErrMsg  = ''  
  
   SET @nTranCount = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN rdt_842ExtUpdSP04  
  
   IF @nStep = 1 
   BEGIN
      SET @cOrderKey = '' 

      SELECT   @cPickSlipNo = PickSlipNo
             , @cDropIDType = DropIDType
             , @cLoadKey    = LoadKey
      FROM dbo.DropID WITH (NOLOCK)
      WHERE DropID = @cDropID
      AND Status = '5'
      
      EXECUTE dbo.nspg_GetKey  
               'RDTECOMM',  
               10,  
               @cBatchKey  OUTPUT,  
               @bsuccess   OUTPUT,  
               @nerrNo     OUTPUT,  
               @cerrmsg    OUTPUT  

      IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey 
                     AND DropID = @cDropID
                     AND CASEID = '' 
                     AND Status = '5' ) 
      BEGIN
         SET @nErrNo = 130451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'InvDropID'
         GOTO ROLLBACKTRAN
      END           
      
      
      UPDATE rdt.rdtECOMMLOG WITH (ROWLOCK) 
      SET Status = '9'
      , ErrMsg = 'CLEAN UP PACK'
      WHERE ToteNo = @cDropID
      AND Status < '9'
      
      IF @@ERROR <> 0 
      BEGIN
         SET @nErrNo = 130452
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UpdEcommFail'
         GOTO ROLLBACKTRAN
      END          
      
      IF @cDropIDType = 'MULTIS'
      BEGIN
         SET @cDropOrderKey = ''
         
         SELECT Top 1 @cDropOrderKey = PD.OrderKey 
         FROM dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey 
         WHERE PD.StorerKey =  @cStorerKey
         AND PD.DropID = @cDropID
         AND PD.Status < '9' 
         AND O.LoadKey = @cLoadKey 
         Order by PD.Editdate Desc
         
         IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND OrderKey = @cDropOrderKey
                     AND Status < '5' ) 
         BEGIN
            SET @nErrNo = 130453
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'PickNotComplete'
            GOTO ROLLBACKTRAN
         END 
         
         SET @nDropIDCount = 0 
         
         SELECT Top 1 @cToteOrderKey = OrderKey 
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         AND DropID = @cDropID
         AND CASEID = '' 
         AND Status = '5'
         
         SELECT @nDropIDCount = Count(DISTINCT DropID ) 
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         AND OrderKey = @cToteOrderKey
         AND CASEID = '' 
         AND Status = '5'
      END
      ELSE 
      BEGIN
         SET @nDropIDCount = 1 
      END
      
      IF @nDropIDCount = 1 
      BEGIN
         /****************************
          INSERT INTO rdtECOMMLog
         ****************************/
         INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate, BatchKey)
         SELECT @nMobile, @cDropID, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE(), @cBatchKey 
         FROM dbo.PICKDETAIL PK WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey
         WHERE PK.DROPID = @cDropID
           AND (PK.Status IN ('3', '5') OR PK.ShipFlag = 'P')       
           AND PK.CaseID = ''
           AND O.Type IN  ( SELECT CL.Code FROM dbo.CodeLKUP CL WITH (NOLOCK) 
                           WHERE CL.ListName = 'ECOMTYPE'
                           AND CL.StorerKey = CASE WHEN CL.StorerKey = '' THEN '' ELSE O.StorerKey END) 
           AND PK.Qty > 0 
           AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) 
         GROUP BY PK.OrderKey, PK.SKU
   
         IF @@ROWCOUNT = 0 -- No data inserted
         BEGIN
            SET @nErrNo = 130454
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoRecToProcess'
            GOTO ROLLBACKTRAN
         END
      END 

      SET @nTotalScannedQty = 0

      SELECT @nTotalPickedQty  = SUM(ExpectedQty)
      FROM rdt.rdtECOMMLog WITH (NOLOCK)
      WHERE ToteNo = @cDropID
      AND Status = '0'
      AND OrderKey = CASE WHEN ISNULL(@cOrderKey,'')  = '' THEN OrderKey ELSE @cOrderKey END
      AND AddWho = @cUserName
      AND Mobile = @nMobile

      SELECT @cOrderKey = OrderKey 
      FROM rdt.rdtEcommLog WITH (NOLOCK)
      WHERE ToteNo = @cDropID 
      AND Status = '0' 
      AND AddWho = @cUserName
      AND Mobile = @nMobile
      
      SET @cOrderKey      = CASE WHEN @cDropIDType = 'MULTIS' THEN @cOrderKey ELSE '' END
      SET @cTrackNo       = ''    
      SET @cCartonType    = ''    
      SET @cWeight        = ''    
      SET @cTaskStatus    = CASE WHEN @nDropIDCount > 1 THEN '1' ELSE '9' END
      SET @cTTLPickedQty  = ISNULL(@nTotalPickedQty,0) 
      SET @cTTLScannedQty = '0'
   END
  
   IF @nStep = 2     
   BEGIN  
      SET @cOrderKey      = ''
      SET @cTrackNo       = ''    
      SET @cCartonType    = ''    
      SET @cWeight        = ''    
      SET @cTaskStatus    = ''
      SET @cTTLPickedQty  = ''
      SET @cTTLScannedQty = ''

      SET @cGenLabelNoSP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo', @cStorerkey)  

      -- check if sku exists in tote  
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)  
                      WHERE ToteNo = @cDropID  
                      AND SKU = @cSKU  
                      AND AddWho = @cUserName  
                      AND Status IN ('0', '1') )  
      BEGIN  
         SET @nErrNo = 130455  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKuNotIntote  
         GOTO RollBackTran  
      END  
  
      IF EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK) 
                 GROUP BY ToteNo, SKU , Status , AddWho 
                 HAVING ToteNo = @cDropID  
                 AND    SKU = @cSKU  
                 AND    SUM(ExpectedQty) < SUM(ScannedQty) + 1 
                 AND    Status < '5'  
                 AND    AddWho = @cUserName)  
      BEGIN  
         SET @nErrNo = 130456  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QtyExceeded  
         GOTO RollBackTran  
      END  

      /****************************  
       CREATE PACK DETAILS  
      ****************************/  
      -- check is order fully despatched for this tote  
      SELECT TOP 1 @cOrderkey   = RTRIM(ISNULL(Orderkey,''))
      FROM rdt.rdtECOMMLog WITH (NOLOCK)  
      GROUP BY ToteNo, SKU , Status , AddWho, OrderKey 
      HAVING ToteNo = @cDropID  
      AND    SKU = @cSKU  
      AND    SUM(ExpectedQty) > SUM(ScannedQty) --+ 1 
      AND    Status < '5'  
      AND    AddWho = @cUserName
      ORDER BY Status Desc   
  
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
               SET @nErrNo = 130457  
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
                  SET @nErrNo = 130458  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDetFail'  
                  GOTO RollBackTran  
               END  
            END  
            
            INSERT INTO dbo.PickingInfo (PickslipNo , ScanInDate ) 
            VALUES ( @cPickSlipNo , GetDate() ) 
            
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 130459  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPickInfoFail'  
               GOTO RollBackTran  
            END
         END -- pickheader does not exist  
         ELSE
         BEGIN
            SELECT @cPickSlipNo = PickHeaderKey 
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
         END
  
         /****************************  
          PACKHEADER  
         ****************************/  
         INSERT INTO dbo.PackHeader  
         (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, AddWho, AddDate, EditWho, EditDate)  
         SELECT O.Route, O.OrderKey, O.LoadKey, O.LoadKey, O.ConsigneeKey, O.Storerkey,  
               PH.PickHeaderkey, sUser_sName(), GETDATE(), sUser_sName(), GETDATE()  
         FROM  dbo.PickHeader PH WITH (NOLOCK)  
         JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)  
         WHERE PH.Orderkey = @cOrderkey  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 130460  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CreatePHdrFail'  
            GOTO RollBackTran  
         END  
         
         SELECT @cLoadKey = LoadKey
         FROM dbo.PackHeader WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo 
      END -- packheader does not exist  
      ELSE  
      BEGIN  
         SELECT @cPickSlipNo = RTRIM(ISNULL(PickSlipNo,''))
               ,@cLoadKey    = RTRIM(ISNULL(@cLoadKey,''))
         FROM   dbo.PackHeader PH WITH (NOLOCK)  
         WHERE  Orderkey = @cOrderkey  
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
            SET @nErrNo = 130461  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoLabelNoGen  
            GOTO RollBackTran  
         END  
      END  
      ELSE  
      BEGIN  
         
         IF EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                     WHERE PickSlipNo = @cPickSlipNo
                     AND RefNo2 = '' )
         BEGIN
            SELECT TOP 1 @cLabelNo = LabelNo  
            FROM dbo.PackDetail WITH (NOLOCK)  
            WHERE PickSlipNo = @cPickSlipNo  
            AND   RefNo2 = ''
            ORDER BY CartonNo Desc
         END
         ELSE 
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
            
            IF ISNULL(@cLabelNo,'') = ''  
            BEGIN  
               SET @nErrNo = 130462  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoLabelNoGen  
               GOTO RollBackTran  
            END     
         END
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
         SET @nErrNo = 130463        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'        
         GOTO RollBackTran           
      END   

      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)       
                     WHERE ToteNo = @cDropID         
                     AND   Orderkey = @cOrderkey       
                     AND   ExpectedQty > ScannedQty       
                     AND   Status < '5'      
                     AND   AddWho = @cUserName)       
      BEGIN               
         DECLARE C_TOTE_DETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT RowRef , ScannedQTY, SKU
         FROM   rdt.rdtECOMMLog ECOMM WITH (NOLOCK)  
         WHERE  ToTeNo = @cDropID  
         AND    Orderkey = @cOrderkey  
         AND    Status < '5'  
         AND    AddWho = @cUserName  
         ORDER BY SKU  
     
         OPEN C_TOTE_DETAIL  
         FETCH NEXT FROM C_TOTE_DETAIL INTO  @nRowRef , @nPackQty, @cSKU 
         WHILE (@@FETCH_STATUS <> -1)  
         BEGIN  
            SET @cLabelLine = '00000'  

            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)  
                           WHERE PickSlipNo = @cPickSlipNo  
                           AND SKU = @cSku  
                           AND DropID = @cDropID)  
            BEGIN  
               -- Insert PackDetail  
               INSERT INTO dbo.PackDetail  
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, DropID, UPC, AddWho, AddDate, EditWho, EditDate, RefNo2)  
               VALUES  
                  (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nPackQty ,
                  @cLabelNo, @cDropID, '', sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), '')  
             
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 130464  
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
                    @cSKU        = @cSku,  
                    @nQty        = @nPackQty ,  
                    @cRefNo1     = @cDropID,  
                    @cRefNo2     = @cLabelNo,  
                    @cRefNo3     = @cPickSlipNo  
               END  
            END --packdetail for sku/order does not exists  
            ELSE  
            BEGIN  
               UPDATE dbo.Packdetail WITH (ROWLOCK)  
               SET   QTY      = QTY + 1 --(@nPackQty + 1 ) 
               WHERE PickSlipNo = @cPickSlipNo 
               AND   SKU = @cSku

               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 130465      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'  
                  GOTO RollBackTran  
               END  
               ELSE
               BEGIN
                  EXEC RDT.rdt_STD_EventLog  
                    @cActionType = '8', -- Packing  
                    @cUserID     = @cUserName,  
                    @nMobileNo   = @nMobile,  
                    @nFunction   = @nFunc,  
                    @cFacility   = @cFacility,  
                    @cStorerKey  = @cStorerkey,  
                    @cSKU        = @cPackSku,  
                    @nQty        = @nPackQty,  
                    @cRefNo1     = @cDropID,  
                    @cRefNo2     = @cLabelNo,  
                    @cRefNo3     = @cPickSlipNo  
               END
            END -- packdetail for sku/order exists  

            FETCH NEXT FROM C_TOTE_DETAIL INTO   @nRowRef , @nPackQty, @cSKU
         END --while  
         CLOSE C_TOTE_DETAIL  
         DEALLOCATE C_TOTE_DETAIL  
         
         IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)  
                          WHERE StorerKey = @cStorerKey  
                          AND DropID = @cDropID  
                          AND OrderKey = @cOrderKey
                          AND ISNULL(CaseID,'')  = ''  
                          AND (Status = '5' OR Status = '3' OR ShipFlag = 'P'))
         BEGIN  
            UPDATE dbo.PickDetail WITH (ROWLOCK)  
            SET CASEID     = @cLabelNo  
               ,TrafficCop = NULL  
            WHERE StorerKey = @cStorerKey  
            AND DropID = @cDropID 
            AND Status IN ( '3', '5' ) 
            AND OrderKey = @cOrderKey  
         
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 130466  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFull  
               GOTO RollBackTran  
            END  
         END  
      END
      
      -- check if total order fully despatched  
      SELECT @nTotalPickQty = SUM(ISNULL(PK.Qty,0))  
      FROM  dbo.PICKDETAIL PK WITH (nolock)  
      WHERE PK.StorerKey = @cStorerKey
      AND PK.Orderkey = @cOrderkey  

      SELECT @nTotalPackQty = SUM(ISNULL(PD.Qty,0))  
      FROM  dbo.PACKDETAIL PD WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey
      AND PickSlipNo = @cPickSlipNo 

      -- Prepare for TaskStatus 
      IF @nTotalPickQty = @nTotalPackQty
      BEGIN
         SELECT @cLabelPrinter = Printer
               ,@cPaperPrinter = Printer_Paper
         FROM rdt.rdtMobrec WITH (NOLOCK)
         WHERE Mobile = @nMobile
             
         SELECT @cDropIDType = DropIDType
         FROM dbo.DropID WITH (NOLOCK)
         WHERE DropID = @cDropID
         AND Status = '5'
            
         IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)         
                     WHERE StorerKey = @cStorerKey      
                     AND OrderKey = @cOrderKey       
                     --AND ISNULL(UserDefine04,'')  = '' )       
                     AND ISNULL(TrackingNo,'')  = '' ) -- (james01)
         BEGIN      
            UPDATE dbo.Orders WITH (ROWLOCK)       
            --SET UserDefine04 = @cTrackNo 
            SET TrackingNo = @cTrackNo -- (james01)
               ,Trafficcop   = NULL   
            WHERE Orderkey = @cOrderKey      
            AND Storerkey = @cStorerKey      
                       
            IF @@ERROR <> 0       
            BEGIN      
               SET @nErrNo = 130467                 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdOrderFail                  
               GOTO RollBackTran        
            END      
         END   
            
         -- Print Label  
         UPDATE dbo.PackHeader WITH (ROWLOCK)  
         SET Status = '9'  
         WHERE PickSlipNo = @cPickSlipNo  
         AND StorerKey = @cStorerKey  

         SELECT @cShipperKey = ShipperKey      
               ,@cOrderType  = Type      
               ,@cSectionKey = RTRIM(SectionKey)    
               ,@cLoadKey    = LoadKey
               ,@cExternOrderKey = ExternOrderKey
         FROM dbo.Orders WITH (NOLOCK)      
         WHERE OrderKey = @cOrderKey      
         AND StorerKey = @cStorerKey  

         -- Trigger WebService --       
         --IF @cOrderType = 'TMALL'
         IF EXISTS ( SELECT 1 FROM dbo.CodeLKUP CL WITH (NOLOCK) 
                     WHERE CL.ListName = 'ECOMTYPE'
                     --AND CL.StorerKey = @cStorerKey
                     AND CL.Code = @cOrderType ) 
         BEGIN
            EXEC  [isp_WS_UpdPackOrdSts]        
                     @cOrderKey         
                  , @cStorerKey         
                  , @bSuccess OUTPUT        
                  , @nErrNo    OUTPUT        
                  , @cErrMsg   OUTPUT           
         END    
         ELSE
         BEGIN
            UPDATE dbo.Orders WITH (ROWLOCK)       
            SET SOStatus= '0'     
               ,Trafficcop   = NULL 
            WHERE Orderkey = @cOrderKey      
            AND Storerkey = @cStorerKey      
                       
            IF @@ERROR <> 0       
            BEGIN      
               SET @nErrNo = 130468                 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdOrderFail                  
               GOTO RollBackTran        
            END      
         END  

         SET @cTrackingNo = ''
         SELECT @cTrackingNo = ISNULL(TrackingNo ,'') 
         FROM dbo.Orders WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey 
         
         IF EXISTS ( SELECT 1 FROM dbo.CartonTrack WITH (NOLOCK)
                     WHERE TrackingNo = @cTrackingNo )
         BEGIN
            UPDATE dbo.CartonTrack WITH (ROWLOCK) 
               SET UDF01 = 'Y'
            WHERE TrackingNo = @cTrackingNo 

            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 130478  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdCtnTrackFail  
               GOTO RollBackTran  
            END
         END
            
         UPDATE dbo.Orders WITH (ROWLOCK)   
         SET PrintFlag = '2'  
            ,TrafficCop = NULL   
         WHERE OrderKey = @cOrderKey   
                    
         IF @@ERROR <> 0   
         BEGIN  
            SET @nErrNo = 130469          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdOrdFail'        
            GOTO RollBackTran         
         END  
         ELSE
         BEGIN  
            SET @nErrNo = 0       
            SET @cErrMsg = 'WB' + @cOrderKey 
         END  
           
         -- UPDATE PACKDETAIL WITH * Indicate Carton Change
         UPDATE dbo.PackDetail WITH (ROWLOCK) 
            SET RefNo2 = RefNo2 + '*'
               ,UPC = @cTrackNo 
         WHERE PickSlipNo = @cPickSlipNo
         AND   CartonNo = @nCartonNo
         AND   ISNULL(RefNo2,'') = ''
            
         IF @@ERROR <> 0 
         BEGIN
            SET @nErrNo = 130470  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'  
            GOTO RollBackTran  
         END
           
         /****************************  
         rdtECOMMLog  
         ****************************/  
         UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)  
         SET   Status      = '9'    -- completed  
         WHERE ToteNo      = @cDropID  
         AND   Orderkey    = @cOrderkey  
         AND   AddWho      = @cUserName  
         AND   Status      = '1'  
        
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 130471  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'  
            GOTO RollBackTran  
         END  

         IF NOT EXISTS ( SELECT 1 
                        FROM rdt.rdtECOMMLOG WITH (NOLOCK) 
                        WHERE ToteNo = @cDropID
                        AND   Status IN (  '0' ,'1' ) 
                        AND   ExpectedQty <>  ScannedQty
                        AND   AddWho = @cUserName ) 
         BEGIN               
            UPDATE dbo.DROPID WITH (Rowlock)
            SET Status = '9'
               ,Editdate = GetDate()
            WHERE DropID = @cDropID
            AND   Status < '9'
      
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 130472
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDroIDFail'
               GOTO ROLLBACKTRAN
            END

            SET @cPostDataCapture = rdt.RDTGetConfig( @nFunc, 'PostDataCapture', @cStorerKey)  
            IF @cPostDataCapture = '0'  
               SET @cPostDataCapture = '' 

            IF @cPostDataCapture = ''
            BEGIN
               SET @cTaskStatus = '9' 
                  
               SELECT @cTrackNo = ISNULL(TrackingNo ,'') 
               FROM dbo.Orders WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   OrderKey = @cOrderKey 
            END    
         END
         ELSE
         BEGIN
            SELECT TOP 1 @cBatchKey = BatchKey
            FROM rdt.rdtECOMMLog WITH (NOLOCK)
            WHERE ToteNo = @cDropID
            AND Status IN ( '0', '1' ) 
            AND AddWho = @cUserName
            AND Mobile = @nMobile
               
            SELECT @nTotalPickedQty  = SUM(ExpectedQty)
            FROM rdt.rdtECOMMLog WITH (NOLOCK)
            WHERE ToteNo = @cDropID
            AND Status IN ('0' , '1', '9' )
            AND OrderKey = CASE WHEN @cDropIDType = 'SINGLES' THEN OrderKey ELSE @cOrderKey END
            AND AddWho = @cUserName
            AND Mobile = @nMobile
            AND BatchKey = @cBatchKey
            AND ISNULL(ErrMSG,'')  = ''
               
            SELECT @nTotalScannedQty = SUM(ScannedQty) 
            FROM rdt.rdtECOMMLog WITH (NOLOCK)
            WHERE ToteNo = @cDropID
            AND Status IN ( '1', '9' ) 
            AND OrderKey = CASE WHEN @cDropIDType = 'SINGLES' THEN OrderKey ELSE @cOrderKey END
            AND AddWho = @cUserName
            AND ISNULL(ErrMSG,'')  = ''
            AND Mobile = @nMobile
            AND BatchKey = @cBatchKey

            SET @cOrderKey      = CASE WHEN @cDropIDType = 'SINGLES' THEN '' ELSE @cOrderKey END
            SET @cTrackNo       = ''    
            SET @cCartonType    = ''    
            SET @cWeight        = ''    
            SET @cTaskStatus    = '1'
            SET @cTTLPickedQty  = @nTotalPickedQty
            SET @cTTLScannedQty = @nTotalScannedQty
         END
      END
      ELSE
      BEGIN
         IF EXISTS ( SELECT 1 FROM rdt.rdtECOMMLOG WITH (NOLOCK) 
                           WHERE ToteNo = @cDropID
                           AND Status IN (  '0' ,'1' ) 
                           AND ExpectedQty <>  ScannedQty
                           AND AddWho = @cUserName ) 
         BEGIN 
            SELECT TOP 1 @cBatchKey = BatchKey
            FROM rdt.rdtECOMMLog WITH (NOLOCK)
            WHERE ToteNo = @cDropID
            AND Status IN ( '0', '1' ) 
            AND AddWho = @cUserName
            AND Mobile = @nMobile
            
            SELECT @nTotalPickedQty  = SUM(ExpectedQty)
            FROM rdt.rdtECOMMLog WITH (NOLOCK)
            WHERE ToteNo = @cDropID
            AND Status IN ('0' , '1', '9' )
            AND OrderKey = CASE WHEN @cDropIDType = 'SINGLES' THEN OrderKey ELSE @cOrderKey END
            AND AddWho = @cUserName
            AND Mobile = @nMobile
            AND BatchKey = @cBatchKey
            AND ISNULL(ErrMSG,'')  = ''
            
            SELECT @nTotalScannedQty = SUM(ScannedQty) 
            FROM rdt.rdtECOMMLog WITH (NOLOCK)
            WHERE ToteNo = @cDropID
            AND Status IN ( '1', '9' ) 
            AND OrderKey = CASE WHEN @cDropIDType = 'SINGLES' THEN OrderKey ELSE @cOrderKey END
            AND AddWho = @cUserName
            AND ISNULL(ErrMSG,'')  = ''
            AND Mobile = @nMobile
            AND BatchKey = @cBatchKey

            SET @cOrderKey      = CASE WHEN @cDropIDType = 'SINGLES' THEN '' ELSE @cOrderKey END
            SET @cTrackNo       = ''    
            SET @cCartonType    = ''    
            SET @cWeight        = ''    
            SET @cTaskStatus    = '1'
            SET @cTTLPickedQty  = @nTotalPickedQty
            SET @cTTLScannedQty = @nTotalScannedQty
         END
         ELSE
         BEGIN
            UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)  
            SET   Status      = '9'    -- completed  
            WHERE ToteNo      = @cDropID  
            AND   Orderkey    = @cOrderkey  
            AND   AddWho      = @cUserName  
            AND   Status      = '1'  
        
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 130473  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'  
               GOTO RollBackTran  
            END  
            
            SET @cOrderKey      = CASE WHEN @cDropIDType = 'SINGLES' THEN '' ELSE @cOrderKey END
            SET @cTrackNo       = ''    
            SET @cCartonType    = ''    
            SET @cWeight        = ''    
            SET @cTaskStatus    = '5'
            SET @cTTLPickedQty  = 0
            SET @cTTLScannedQty = 0
         END
      END

      -- Commit tran before printing
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
         COMMIT TRAN rdt_842ExtUpdSP04   

      IF @nTotalPickQty = @nTotalPackQty
      BEGIN
         SELECT @cDataWindow = DataWindow,         
               @cTargetDB = TargetDB         
         FROM rdt.rdtReport WITH (NOLOCK)         
         WHERE StorerKey = @cStorerKey        
         AND   ReportType = 'BAGMANFEST'        
            
         SET @cShipperKey = ''      
         SET @cOrderType = ''      

         EXEC RDT.rdt_BuiltPrintJob          
               @nMobile,          
               @cStorerKey,          
               'BAGMANFEST',              -- ReportType          
               'BAGMANFEST',              -- PrintJobName          
               @cDataWindow,          
               @cPaperPrinter,          
               @cTargetDB,          
               @cLangCode,          
               @nErrNo  OUTPUT,          
               @cErrMsg OUTPUT,           
               @cOrderkey,         
               @cLabelNo      
          
         IF ISNULL( @cOrderKey, '') = ''
            SELECT @cOrderKey = OrderKey
            FROM dbo.PackHeader WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo

         SELECT @cShipperKey = ShipperKey,
                @cTrackingNo = TrackingNo,
                @cExternOrderKey = ExternOrderKey
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         DECLARE Cur_Print CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT Long, Notes, Code2
         FROM dbo.CODELKUP WITH (NOLOCK)      
         WHERE LISTNAME = 'PrtbyShipK'      
         AND   Code = @cShipperKey 
         AND   StorerKey = @cStorerKey
         OPEN CUR_Print
         FETCH NEXT FROM CUR_Print INTO @cFilePath, @cPrintFilePath, @cReportType
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Make sure we have setup the printer id
            -- Record searched based on func + storer + reporttype + printergroup (shipperkey)
            SELECT @cPrinterInGroup = PrinterID
            FROM rdt.rdtReportToPrinter WITH (NOLOCK)
            WHERE Function_ID = @nFunc
            AND   StorerKey = @cStorerKey
            AND   ReportType = @cReportType
            AND   PrinterGroup = @cLabelPrinter

            -- Determine print type (command/bartender)
            SELECT @cProcessType = ProcessType,
                   @cPaperType = PaperType
            FROM rdt.RDTREPORT WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   ReportType = @cReportType
            AND  (Function_ID = @nFunc OR Function_ID = 0)
            ORDER BY Function_ID DESC

            ---- If no setup then we user printer from rdt user login
            --IF ISNULL( @cPrinterInGroup, '') = ''
            -- PDF use foxit then need use the winspool printer name
            IF @cReportType LIKE 'PDFWBILL%'  
            BEGIN
               SELECT @cWinPrinter = WinPrinter  
               FROM rdt.rdtPrinter WITH (NOLOCK)  
               WHERE PrinterID = CASE WHEN ISNULL( @cPrinterInGroup, '') <> '' THEN @cPrinterInGroup ELSE @cLabelPrinter END

               IF CHARINDEX(',' , @cWinPrinter) > 0 
               BEGIN
                  SET @cPrinterName = @cPrinterInGroup
                  SET @cWinPrinterName = LEFT( @cWinPrinter , (CHARINDEX(',' , @cWinPrinter) - 1) )
               END
               ELSE
               BEGIN
                  -- no comma, check valid printer name, some have values HK_ZebraZT510_203_001
                  IF EXISTS ( SELECT 1 FROM rdt.rdtPrinter WITH (NOLOCK) WHERE PrinterID = @cPrinterInGroup)
                  BEGIN
                     SET @cPrinterName =  @cPrinterInGroup
                     SET @cWinPrinterName = @cWinPrinter
                  END
               END
            END
            BEGIN
               IF @cPaperType = 'LABEL'
                  SET @cPrinterName = @cLabelPrinter
               ELSE
                  SET @cPrinterName = @cPaperPrinter
            END

            IF ISNULL( @cFilePath, '') <> ''    
            BEGIN    
               SET @cFileName = 'THG_' + RTRIM( @cExternOrderKey) + '.pdf'     
               SET @cPrintCommand = '"' + @cPrintFilePath + '" /t "' + @cFilePath + '\' + @cFileName + '" "' + @cWinPrinterName + '"'                              

               DECLARE @tRDTPrintJob AS VariableTable
      
               -- Print label (pass in shipperkey as label printer. then rdt_print will look for correct printer id)
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinterName, '', 
                  @cReportType,     -- Report type
                  @tRDTPrintJob,    -- Report params
                  'rdt_842ExtUpdSP04', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT,
                  1,
                  @cPrintCommand

               --IF @nErrNo <> 0 SET @cErrMsg = @cPrinterName
            END
            ELSE
            BEGIN
               --INSERT INTO TraceInfo (TraceName, TimeIn, COL1, COL2, Col3, Col4, Col5, Step1) VALUES
               --('VANS', GETDATE(), @cStorerKey, @cOrderKey, @cTrackingNo, @cLabelNo, @nCartonNo, @cReportType)
               -- Common params
               DECLARE @tSHIPLabel AS VariableTable
               DELETE FROM @tSHIPLabel
               INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)
               INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey) 
               INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@cTrackingNo', @cTrackingNo) 
               INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cLabelNo', @cLabelNo)
               INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@nCartonNo', @nCartonNo)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinterName, '', 
                  @cReportType, -- Report type
                  @tSHIPLabel, -- Report params
                  'rdt_842ExtUpdSP04', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
            END

	         IF @nErrNo <> 0
               BREAK

            FETCH NEXT FROM CUR_Print INTO @cFilePath, @cPrintFilePath, @cReportType
         END
         CLOSE CUR_Print
         DEALLOCATE CUR_Print
      END

      GOTO Quit_SP
   END  

   IF @nStep = 4 
   BEGIN
      IF @cOption IN ('1', '5') 
      BEGIN
         SET @nErrNo = 130474  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidOption'  
         GOTO RollBackTran  
      END
      
      IF @cOption = '9' 
      BEGIN
      
         SET @cOrderKey = '' 
         
         DECLARE C_Tote_Short CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         
         SELECT RowRef, OrderKey
         FROM rdt.rdtECOMMLog WITH (NOLOCK)  
         WHERE ToteNo = @cDropID  
         AND Status < '5'  
         ORDER BY RowRef   
         
         OPEN C_Tote_Short  
         FETCH NEXT FROM C_Tote_Short INTO  @nRowRef, @cOrderKey 
         WHILE (@@FETCH_STATUS <> -1)  
         BEGIN           
            
            UPDATE rdt.rdtEcommLog WITH (ROWLOCK) 
            SET Status = CASE WHEN @cOption = '1' THEN '5' ELSE '9' END
               , ErrMsg = CASE WHEN @cOption = '1' THEN 'Short Pack' ELSE 'Exit Pack' END
            WHERE RowRef = @nRowRef
            
            IF @@ERROR <> 0  
            BEGIN
               SET @nErrNo = 101514  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'  
               GOTO RollBackTran  
            END
            
   
            EXEC RDT.rdt_STD_EventLog  
                  @cActionType = '8', -- Packing  
                  @cUserID     = @cUserName,  
                  @nMobileNo   = @nMobile,  
                  @nFunctionID = @nFunc,  
                  @cFacility   = @cFacility,  
                  @cStorerKey  = @cStorerkey,  
                  @cSKU        = @cSku,  
                  @cRefNo1     = 'SHORT PACK',  
                  @cOrderKey   = @cOrderKey  
            
            FETCH NEXT FROM C_Tote_Short INTO  @nRowRef, @cOrderKey      
            
         END
         CLOSE C_Tote_Short  
         DEALLOCATE C_Tote_Short  
         
         
         SET @cOrderKey      = ''
         SET @cTrackNo       = ''    
         SET @cCartonType    = ''    
         SET @cWeight        = ''    
         SET @cTaskStatus    = '9'
         SET @cTTLPickedQty  = ''
         SET @cTTLScannedQty = ''
      END      
   END
   
   IF @nStep = 5 
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND DropID = @cDropID 
                  AND Status < '5' ) 
      BEGIN
         SET @nErrNo = 130475
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'PickNotDone'
         GOTO ROLLBACKTRAN
      END
      
      SELECT   @cPickSlipNo = PickSlipNo
               , @cDropIDType = DropIDType
               , @cLoadKey    = LoadKey
      FROM dbo.DropID WITH (NOLOCK)
      WHERE DropID = @cDropID
      AND Status = '5'
      
      IF @cDropIDType = 'MULTIS'
      BEGIN
         SET @cDropOrderKey = ''
         
         SELECT Top 1 @cDropOrderKey = PD.OrderKey 
         FROM dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey 
         WHERE PD.StorerKey =  @cStorerKey
         AND PD.DropID = @cDropID
         AND PD.Status < '9' 
         AND O.LoadKey = @cLoadKey 
         Order by PD.Editdate Desc
         
         IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND OrderKey = @cDropOrderKey
                     AND Status < '5' ) 
         BEGIN
            SET @nErrNo = 130476
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'PickNotComplete'
            GOTO ROLLBACKTRAN
         END 
      END
      
      EXECUTE dbo.nspg_GetKey  
               'RDTECOMM',  
               10,  
               @cBatchKey  OUTPUT,  
               @bsuccess   OUTPUT,  
               @nerrNo     OUTPUT,  
               @cerrmsg    OUTPUT  

      IF @cDropIDType = 'MULTIS' AND @cOption = '1' 
      BEGIN
         /****************************
         INSERT INTO rdtECOMMLog
         ****************************/
         INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate, BatchKey)
         SELECT @nMobile, @cDropID, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE(), @cBatchKey 
         FROM dbo.PICKDETAIL PK WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey
         WHERE PK.DROPID = @cDropID
            AND (PK.Status IN ('3', '5') OR PK.ShipFlag = 'P')       
            AND PK.CaseID = ''
            AND O.Type IN  ( SELECT CL.Code FROM dbo.CodeLKUP CL WITH (NOLOCK) 
                           WHERE CL.ListName = 'ECOMTYPE'
                           AND CL.StorerKey = CASE WHEN CL.StorerKey = '' THEN '' ELSE O.StorerKey END) 
            AND PK.Qty > 0 
            AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) 
         GROUP BY PK.OrderKey, PK.SKU
   
         IF @@ROWCOUNT = 0 -- No data inserted
         BEGIN
            SET @nErrNo = 130477
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoRecToProcess'
            GOTO ROLLBACKTRAN
         END
      
         SET @nTotalScannedQty = 0

         SELECT @nTotalPickedQty  = SUM(ExpectedQty)
         FROM rdt.rdtECOMMLog WITH (NOLOCK)
         WHERE ToteNo = @cDropID
         AND Status = '0'
         AND OrderKey = CASE WHEN ISNULL(@cOrderKey,'')  = '' THEN OrderKey ELSE @cOrderKey END
         AND AddWho = @cUserName
         AND Mobile = @nMobile
         
         SELECT @cOrderKey = OrderKey 
         FROM rdt.rdtEcommLog WITH (NOLOCK)
         WHERE ToteNo = @cDropID 
         AND Status = '0' 
         AND AddWho = @cUserName
         AND Mobile = @nMobile

         SET @cOrderKey      = @cOrderKey
         SET @cTrackNo       = ''    
         SET @cCartonType    = ''    
         SET @cWeight        = ''    
         SET @cTaskStatus    = '1' 
         SET @cTTLPickedQty  = @nTotalPickedQty
         SET @cTTLScannedQty = '0'
      END 
      ELSE
      BEGIN
         SET @cOrderKey      = ''
         SET @cTrackNo       = ''    
         SET @cCartonType    = ''    
         SET @cWeight        = ''    
         SET @cTaskStatus    = '9' 
         SET @cTTLPickedQty  = '0'
         SET @cTTLScannedQty = '0'
      END
   END   
   
   GOTO QUIT       
         
   RollBackTran:      
      ROLLBACK TRAN rdt_842ExtUpdSP04 -- Only rollback change made here      
      
   Quit:      
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
         COMMIT TRAN rdt_842ExtUpdSP04      
        
   Quit_SP:   
END  

GO