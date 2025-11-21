SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_842ExtUpdSP01                                   */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: LULU DTC Logic                                              */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2016-06-13  1.0  ChewKP   SOS#371222 Created                         */  
/* 2016-12-14  1.1  ChewKP   WMS-818 Add Split Tote Function (ChewKP01) */
/* 2017-09-12  1.2  ChewKP   WMS-2902 Support Multiple TrackingNo       */
/*                           (ChewKP02)                                 */
/* 2021-04-08  1.3  James    WMS-16024 Standarized use of TrackingNo    */
/*                           (james01)                                  */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_842ExtUpdSP01] (  
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
          --,@nTotalPickedQty   INT
          --,@nTTLScannedQty    INT
          ,@cBatchKey         NVARCHAR(10) 
          ,@cToteOrderKey     NVARCHAR(10) 
          ,@nDropIDCount      INT
          ,@cPickDetailKey    NVARCHAR(10) 
          ,@nQTYBal           INT
          ,@nPickedQty        INT

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
           --,@nPackQTY            INT
           ,@nPickQty            INT
           ,@cDropOrderKey       NVARCHAR(10) 
           ,@nInsertedCartonNo   INT
           ,@nInsertedLabelLine  INT
           ,@cTrackingNo         NVARCHAR(20) 
           ,@cCarriername        NVARCHAR(30) 
           ,@cKeyName            NVARCHAR(30) 
  
   SET @nErrNo   = 0  
   SET @cErrMsg  = ''  

  
  
   SET @nTranCount = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN rdt_842ExtUpdSP01  
  
   IF @nStep = 1 
   BEGIN
      
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
            --ROLLBACK TRAN
            SET @nErrNo = 101516
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'InvDropID'
            GOTO ROLLBACKTRAN
      END           
      
      
      UPDATE rdt.rdtECOMMLOG WITH (ROWLOCK) 
      SET Status = '9'
      , ErrMsg = 'CLEAN UP PACK'
      WHERE ToteNo = @cDropID
      AND Status < '9'
      --AND AddWho <> @cUserName
      
      IF @@ERROR <> 0 
      BEGIN
         --ROLLBACK TRAN
         SET @nErrNo = 101518
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
            SET @nErrNo = 101525
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
           AND PK.Qty > 0 -- SOS# 329265
           AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) 
         GROUP BY PK.OrderKey, PK.SKU
   
         IF @@ROWCOUNT = 0 -- No data inserted
         BEGIN
            --ROLLBACK TRAN
            SET @nErrNo = 101501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoRecToProcess'
            GOTO ROLLBACKTRAN
         END
      END 
      SET @nTotalScannedQty = 0
--      SELECT @nTotalScannedQty = SUM(QTY)
--      FROM dbo.PickDetail PD WITH (NOLOCK)
--      INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey
--      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey
--      WHERE PD.DropID = @cDropID
--      AND (PD.Status IN  ('3','5') OR PD.ShipFlag = 'P')  
--      AND PD.CaseID <> ''
--      AND O.LoadKey = @cLoadKey
--      AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) 
--      AND PH.PickHeaderKey = @cPickSlipNo 
      
      --SELECT @nTotalScannedQty = SUM(ScannedQty) 
      --FROM rdt.rdtECOMMLog WITH (NOLOCK)
      --WHERE ToteNo = @cDropID
      --AND Status = '9'
      --AND OrderKey = CASE WHEN @cDropIDType = 'SINGLES' THEN OrderKey ELSE @cOrderKey END
      --AND AddWho = @cUserName

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
      SET @cTTLPickedQty  = @nTotalPickedQty
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

      SELECT @cLabelPrinter = Printer
           , @cPaperPrinter = Printer_Paper
      FROM rdt.rdtMobrec WITH (NOLOCK)
      WHERE Mobile = @nMobile

      IF ISNULL(@cLabelPrinter,'' ) = '' 
      BEGIN
          SET @nErrNo = 101537  
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrinterReq  
          GOTO RollBackTran  
      END

      IF ISNULL(@cPaperPrinter,'' ) = '' 
      BEGIN
          SET @nErrNo = 101538  
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrinterReq  
          GOTO RollBackTran  
      END  
      -- check if sku exists in tote  
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)  
                      WHERE ToteNo = @cDropID  
                      AND SKU = @cSKU  
                      AND AddWho = @cUserName  
                      AND Status IN ('0', '1') )  
      BEGIN  
          SET @nErrNo = 101502  
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKuNotIntote  
          GOTO RollBackTran  
      END  
  
      IF EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK) 
                 GROUP BY ToteNo, SKU , Status , AddWho 
                     HAVING ToteNo = @cDropID  
                     --AND Orderkey = @cOrderkey  
                     AND SKU = @cSKU  
                     AND SUM(ExpectedQty) < SUM(ScannedQty) + 1 
                     AND Status < '5'  
                     AND AddWho = @cUserName)  
      BEGIN  
         SET @nErrNo = 101503  
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
                     --AND Orderkey = @cOrderkey  
                     AND SKU = @cSKU  
                     AND SUM(ExpectedQty) > SUM(ScannedQty) --+ 1 
                     AND Status < '5'  
                     AND AddWho = @cUserName
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
               SET @nErrNo = 101504  
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
                  SET @nErrNo = 101505  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDetFail'  
                  GOTO RollBackTran  
               END  
            END  
            
            INSERT INTO dbo.PickingInfo (PickslipNo , ScanInDate ) 
            VALUES ( @cPickSlipNo , GetDate() ) 
            
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 101517  
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
            SET @nErrNo = 101506  
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
                      --AND DropID = @cDropID )  
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
               SET @nErrNo = 101507  
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
            AND RefNo2 = ''
            ORDER BY CartonNo Desc
            --AND DropID = @cDropID
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
                  SET @nErrNo = 101523  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoLabelNoGen  
                  GOTO RollBackTran  
            END     
         END
         
         
      END  
  
      -- need to generate UPI for 1st Tote, and regenerate for subsequent tote  
      -- because the total PackQty would differ from original  
--      SELECT @nPackQty = ISNULL(SUM(ECOMM.ScannedQTY), 0)  
--      FROM   rdt.rdtECOMMLog ECOMM WITH (NOLOCK)  
--      WHERE  ToTeNo = @cDropID  
--      AND    Orderkey = @cOrderkey  
--      AND    Status < '5'  
--      AND    AddWho = @cUserName  
  
      
      DECLARE C_TOTE_DETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT RowRef , ScannedQTY
      FROM   rdt.rdtECOMMLog ECOMM WITH (NOLOCK)  
      WHERE  ToTeNo = @cDropID  
      AND    Orderkey = @cOrderkey  
      AND    SKU    = @cSKU 
      AND    Status < '5'  
      AND    AddWho = @cUserName  
      ORDER BY SKU  
  
      OPEN C_TOTE_DETAIL  
      FETCH NEXT FROM C_TOTE_DETAIL INTO  @nRowRef , @nPackQty
      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN  
         SET @cLabelLine = '00000'  
  
  
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)  
                        WHERE PickSlipNo = @cPickSlipNo  
                        AND SKU = @cSku
                        AND LabelNo = @cLabelNo  )
                           --AND DropID = @cDropID)  
         BEGIN  
  
  
            -- Insert PackDetail  
            INSERT INTO dbo.PackDetail  
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, DropID, UPC, AddWho, AddDate, EditWho, EditDate, RefNo2)  
            VALUES  
               (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, 1 ,
               @cDropID, @cDropID, '', sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), '')  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 101509  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDetFail'  
               GOTO RollBackTran  
            END  
            --ELSE  
            --BEGIN  
               --SET @nPackQty = @nPackQty + 1
            
               
            SELECT 
                    @cOrderType  = Type  
                   ,@cCarriername = ShipperKey
            FROM dbo.Orders WITH (NOLOCK)  
            WHERE OrderKey = @cOrderKey  
            AND StorerKey = @cStorerKey  
      
            SELECT @cKeyname     = Long
            FROM dbo.Codelkup WITH (NOLOCK) 
            WHERE Listname = 'AsgnTNo' 
            AND Storerkey = @cStorerkey 
            AND UDF03 = @cOrderType
            AND Short = @cCarriername
            
            IF ISNULL(@cKeyName ,'' ) <> '' 
            BEGIN 
                 
               SELECT @nInsertedCartonNo = CartonNo
                     ,@nInsertedLabelLine = LabelLine
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE PickSlipNo = @cPickSlipNo 
               AND StorerKey    = @cStorerKey
               AND LabelNo      = @cLabelNo 
               AND SKU          = @cSKU
               AND RefNo        = @cDropID
               AND DropID       = @cDropID
               ORDER BY AddDate DESC

               --SELECT @nInsertedCartonNo '@nInsertedCartonNo' , @nInsertedLabelLine '@nInsertedLabelLine' 
               
               -- (ChewKP02) 
               IF @nInsertedCartonNo = 1
               BEGIN
                  --SELECT @cTrackingNo = UserDefine04
                  SELECT @cTrackingNo = TrackingNo -- (james01)
                  FROM dbo.Orders WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND OrderKey = @cOrderKey
               END
               ELSE
               BEGIN
                 
                
                 
                 IF EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                             WHERE PickSlipNo = @cPickSlipNo 
                             AND StorerKey    = @cStorerKey
                             AND LabelNo      = @cLabelNo
                             AND ISNULL(UPC,'')  <> '' ) 
                 BEGIN
                   SELECT TOP 1 @cTrackingNo = UPC
                   FROM dbo.PackDetail WITH (NOLOCK) 
                   WHERE PickSlipNo = @cPickSlipNo 
                   AND StorerKey    = @cStorerKey
                   AND LabelNo      = @cLabelNo
                   AND ISNULL(UPC,'') <> '' 
                   
                 END
                 ELSE
                 BEGIN
                  
                    
                    
          
                       
                     
                       SELECT @cTrackingNo = MIN(TrackingNo)
                       FROM dbo.CartonTrack WITH (NOLOCK) 
                       WHERE  CarrierName = @cCarriername 
                       AND Keyname        = @cKeyname 
                       AND CarrierRef2    = ''
                       AND LabelNo        = ''
                    
                       DELETE FROM dbo.CartonTrack WITH (ROWLOCK) 
                       WHERE TrackingNo = @cTrackingNo
                       AND CarrierName  = @cCarriername
                       AND KeyName      = @cKeyname
                    
                          
                       /**update cartontrack **/
                       IF NOT EXISTS ( SELECT 1 FROM dbo.CartonTrack WITH (NOLOCK) 
                                       WHERE  CarrierName = @cCarriername 
                                       AND Keyname        = @cKeyname 
                                       AND CarrierRef2    = ''
                                       --AND LabelNo          ''
                                       AND TrackingNo     = @cTrackingNo  )
                       BEGIN
         --                 UPDATE  dbo.CartonTrack 
         --                 SET Labelno = @cOrderKey
         --                  ,  CarrierRef2 = 'GET'
         --                 WHERE  CarrierName = @cCarriername 
         --                 AND Keyname        = @cKeyname 
         --                 AND CarrierRef2    = ''
         --                 AND LabelNo        = ''
         --                 AND Trackingno = @cTrackingNo

                          INSERT INTO dbo.CartonTrack ( TrackingNo, CarrierName, KeyName, LabelNo, CarrierRef2 ) 
                          VALUES ( @cTrackingNo, @cCarriername, @cKeyname, @cOrderKey, 'GET' ) 
                       
                          IF @@ERROR <> 0 
                          BEGIN
                           SET @nErrNo = 101535     
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsCartonTrackFail'  
                           GOTO RollBackTran 
                          END
                       
                       
                       END
                       ELSE
                       BEGIN
                           SET @nErrNo = 101534      
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TrackNoInUsed'  
                           GOTO RollBackTran 
                       END
                   
                    
                 END
                 
               END
               
               
                    
                 
               /**Update packdetail**/
               UPDATE dbo.Packdetail
               SET UPC = @cTrackingNo
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE PickSlipNo = @cPickSlipNo 
               AND StorerKey    = @cStorerKey
               AND LabelNo      = @cLabelNo 
               AND SKU          = @cSKU
               AND RefNo        = @cDropID
               AND DropID       = @cDropID
               AND CartonNo     = @nInsertedCartonNo
               AND LabelLine    = @nInsertedLabelLine
               
               IF @@ERROR <> 0 
               BEGIN
                 SET @nErrNo = 101536      
                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'  
                 GOTO RollBackTran 
               END
            END
            
            
            
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
            --END  
  
  
         END --packdetail for sku/order does not exists  
         ELSE  
         BEGIN  
            UPDATE dbo.Packdetail WITH (ROWLOCK)  
            SET   QTY      = QTY + 1 --(@nPackQty + 1 ) 
                  --LabelNo  = @cLabelNo,  
                  --RefNo    = @cDropID
                  --UPC      = @cTrackNo  
            WHERE PickSlipNo = @cPickSlipNo 
            AND SKU = @cSku--AND DropID = @cDropID  
            AND LabelNo = @cLabelNo 
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 101510      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'  
               GOTO RollBackTran  
            END  
            
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
            
  
         END -- packdetail for sku/order exists  
         
         
         /***************************  
         UPDATE rdtECOMMLog  
         ****************************/  
         UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)  
         SET   ScannedQty  = ScannedQty + 1,  
               Status      = '1'    -- in progress  
         WHERE RowRef = @nRowRef
         
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 101511  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'  
            GOTO RollBackTran  
         END  
  
         
         
         FETCH NEXT FROM C_TOTE_DETAIL INTO   @nRowRef , @nPackQty     
      END --while  
      CLOSE C_TOTE_DETAIL  
      DEALLOCATE C_TOTE_DETAIL  
      
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)  
                       WHERE StorerKey = @cStorerKey  
                       AND DropID = @cDropID  
                       AND OrderKey = @cOrderKey
                       AND ISNULL(CaseID,'')  = ''  
                       AND (Status = '5' OR Status = '3' OR ShipFlag = 'P')
                       AND SKU = @cSKU )  
      BEGIN  
         -- Piece Scanning Balance always = 1
         SET @nQTYBal = 1

         -- Loop PickDetail to Split and Update by Quantity
         DECLARE C_TOTE_PICKDETAIL  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PickDetailKey, Qty 
         FROM   PickDetail PD WITH (NOLOCK)  
         WHERE  PD.DropID = @cDropID  
         AND    PD.Orderkey = @cOrderkey  
         AND    PD.SKU    = @cSKU 
         AND    Status = '5'  
         ORDER BY PickDetailKey 
         
         OPEN C_TOTE_PICKDETAIL  
         FETCH NEXT FROM C_TOTE_PICKDETAIL INTO  @cPickDetailKey , @nPickedQty 
         WHILE (@@FETCH_STATUS <> -1)  
         BEGIN  
            
            
            
             -- Exact match
            IF @nPickedQty =  @nQTYBal
            BEGIN
               
               UPDATE dbo.PickDetail WITH (ROWLOCK)  
               SET CASEID     = @cLabelNo  
                  ,DropID     = @cLabelNo
                  ,TrafficCop = NULL  
               WHERE PickDetailKey = @cPickDetailKey
            
               IF @@ERROR <> 0  
               BEGIN  
                     SET @nErrNo = 101508  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFull  
                     GOTO RollBackTran  
               END  
               
               --SET @nMVQTY = @nQTY_PD
               SET @nQTYBal = 0 -- Reduce balance
            END
            
            -- PickDetail have less
      		ELSE IF @nPickedQty <  @nQTYBal
            BEGIN
               UPDATE dbo.PickDetail WITH (ROWLOCK)  
               SET CASEID     = @cLabelNo  
                  ,DropID     = @cLabelNo
                  ,TrafficCop = NULL  
               WHERE PickDetailKey = @cPickDetailKey
            
               IF @@ERROR <> 0  
               BEGIN  
                     SET @nErrNo = 101526  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFull  
                     GOTO RollBackTran  
               END  
               
               
               SET @nQTYBal = 0 -- Reduce balance
            END
   
            -- PickDetail have more
      		ELSE IF @nPickedQty >  @nQTYBal
            BEGIN
               
   
                  -- Get new PickDetailkey
                  DECLARE @cNewPickDetailKey NVARCHAR( 10)
                  EXECUTE dbo.nspg_GetKey
                     'PICKDETAILKEY',
                     10 ,
                     @cNewPickDetailKey OUTPUT,
                     @bSuccess          OUTPUT,
                     @nErrNo            OUTPUT,
                     @cErrMsg           OUTPUT
                  IF @bSuccess <> 1
                  BEGIN
                     SET @nErrNo = 101527
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
                     GOTO RollBackTran
                  END
   
                  -- Create new a PickDetail to hold the balance
                  INSERT INTO dbo.PickDetail (
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
                     UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                     ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                     EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                     PickDetailKey,
                     QTY,
                     TrafficCop,
                     OptimizeCop)
                  SELECT
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
                     UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
                     CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                     EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                     @cNewPickDetailKey,
                     @nPickedQty - @nQTYBal, -- QTY
                     NULL, -- TrafficCop
                     '1'   -- OptimizeCop
                  FROM dbo.PickDetail WITH (NOLOCK)
         			WHERE PickDetailKey = @cPickDetailKey
         			
                  IF @@ERROR <> 0
                  BEGIN
         				SET @nErrNo = 101528
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
                     GOTO RollBackTran
                  END
   
                  -- Change orginal PickDetail with exact QTY (with TrafficCop)
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                     QTY = @nQTYBal,
                     CaseID = @cLabelNo,
                     DropID = @cLabelNo,
                     EditDate = GETDATE(),
                     EditWho  = SUSER_SNAME(),
                     Trafficcop = NULL
                  WHERE PickDetailKey = @cPickDetailKey
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 101529
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFaill
                     GOTO RollBackTran
                  END
   
--                  -- Confirm orginal PickDetail with exact QTY
--                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET
--                     --Status = '5',
--                     EditDate = GETDATE(),
--                     EditWho  = SUSER_SNAME(),
--                     TrafficCop = NULL
--                  WHERE PickDetailKey = @cPickDetailKey
--                  IF @@ERROR <> 0
--                  BEGIN
--                     SET @nErrNo = 101764
--                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
--                     GOTO RollBackTran
--                  END
   
                  
                  SET @nQTYBal = 0 -- Reduce balance
     
            END
         
            IF @nQTYBal <= 0 
            BREAK 

            FETCH NEXT FROM C_TOTE_PICKDETAIL INTO  @cPickDetailKey , @nPickedQty 
            
            
         END
         CLOSE C_TOTE_PICKDETAIL  
         DEALLOCATE C_TOTE_PICKDETAIL  
         
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
         
            SET @cPostDataCapture = rdt.RDTGetConfig( @nFunc, 'PostDataCapture', @cStorerKey)  
            IF @cPostDataCapture = '0'  
               SET @cPostDataCapture = '' 
               
            
            IF @cPostDataCapture <> ''
            BEGIN
               SET @cTaskStatus = '9' 
            END    
            --ELSE
            --BEGIN
            --   SET @cTaskStatus = '9'     
            --END
         
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
            --AND OrderKey = CASE WHEN @cDropIDType = 'SINGLES' THEN OrderKey ELSE @cOrderKey END
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
               SET @nErrNo = 101519  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'  
               GOTO RollBackTran  
            END  

            UPDATE dbo.DROPID WITH (Rowlock)
            SET   Status = '9'
                 ,Editdate = GetDate()
            WHERE DropID = @cDropID
            AND   Status < '9'
   
            IF @@ERROR <> 0
            BEGIN
                  SET @nErrNo = 101531
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIDFail'
                  GOTO ROLLBACKTRAN
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
      

   END  
   
   IF @nStep = 3
   BEGIN
       
       SELECT @cLabelPrinter = Printer
            , @cPaperPrinter = Printer_Paper
       FROM rdt.rdtMobrec WITH (NOLOCK)
       WHERE Mobile = @nMobile
       
       SELECT  
             @cDropIDType = DropIDType
       FROM dbo.DropID WITH (NOLOCK)
       WHERE DropID = @cDropID
       AND Status = '5'

      /****************************  
       PACKINFO  
      ****************************/  
      SELECT @fCartonWeight = CartonWeight
            ,@fCartonLength = CartonLength
            ,@fCartonHeight = CartonHeight
            ,@fCartonWidth  = CartonWidth 
      FROM dbo.Cartonization WITH (NOLOCK)
      WHERE CartonType = @cCartonType
      
      SELECT @cPickSlipNo = PickSlipNo 
      FROM dbo.PackHeader WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey 
      
      
      SELECT TOP 1 @nCartonNo  = CartonNo 
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND PickSlipNo = @cPickSlipNo
      AND RefNo2 = ''
      ORDER BY CartonNo Desc

      SELECT @nTotalPackedQty = SUM(Qty)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND PickSlipNo = @cPickSlipNo
      AND CartonNo = @nCartonNo
      GROUP BY CartonNo
      

      
      SET @fCartonCube = (@fCartonLength * @fCartonHeight * @fCartonWidth)/(100*100*100) 
      
 
      SET @fCartonTotalWeight = @cWeight

      IF NOT EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)
                      WHERE PickSlipNo = @cPickSlipNo
                      AND CartonNo = @nCartonNo ) 
      BEGIN
         

         INSERT INTO dbo.PackInfo(PickslipNo, CartonNo, CartonType, Refno, Weight, Cube, Qty, AddWho, AddDate, EditWho, EditDate)    
         VALUES ( @cPickSlipNo , @nCartonNo, @cCartonType, '', @fCartonTotalWeight, @fCartonCube, @nTotalPackedQty, sUser_sName(), GetDate(), sUser_sName(), GetDate()) 
         
         IF @@ERROR <> 0        
         BEGIN        
            SET @nErrNo = 101512               
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackInfoFail'       
            GOTO RollBackTran        
         END  
         
      END
      
      --ELSE
      --BEGIN
      
      --   UPDATE dbo.PackInfo WITH (ROWLOCK)
      --   SET Qty = @nTotalPackedQty
      --      ,Weight = @fCartonTotalWeight
      --   WHERE PickSlipNo = @cPickSlipNo
      --   AND CartonNo = @nCartonNo
         
      --   IF @@ERROR <> 0        
      --   BEGIN        
      --      SET @nErrNo = 95662              
      --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackInfoFail'       
      --      GOTO RollBackTran        
      --   END  
         
      --END 
      
      -- UPDATE PACKDETAIL WITH * Indicate Carton Change
      UPDATE dbo.PackDetail WITH (ROWLOCK) 
      SET RefNo2 = RefNo2 + '*'
      WHERE PickSlipNo = @cPickSlipNo
      AND CartonNo = @nCartonNo
      AND ISNULL(RefNo2,'') = ''
      
      IF @@ERROR <> 0 
      BEGIN
         SET @nErrNo = 101522  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'  
         GOTO RollBackTran  
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
      AND   Status      = '1'  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 101513  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'  
         GOTO RollBackTran  
      END  
      
  
      SELECT @cDataWindow = DataWindow,  
            @cTargetDB = TargetDB  
      FROM rdt.rdtReport WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND   ReportType = 'CARTONLBL'  
  
      SET @cShipperKey = ''  
      SET @cOrderType = ''  
  
      SELECT @cShipperKey = ShipperKey  
            ,@cOrderType  = Type  
            ,@cSectionKey = RTRIM(SectionKey)  
      FROM dbo.Orders WITH (NOLOCK)  
      WHERE OrderKey = @cOrderKey  
      AND StorerKey = @cStorerKey  
         
--      SELECT Top 1 @nMaxCartonNo = CartonNo
--      FROM dbo.PackDetail WITH (NOLOCK)
--      WHERE PickSlipNo = @cPickSlipNo 
--      AND StorerKey = @cStorerKey 
--      Order by CartonNo Desc
--      
--      SELECT Top 1 @nMinCartonNo = CartonNo
--      FROM dbo.PackDetail WITH (NOLOCK)
--      WHERE PickSlipNo = @cPickSlipNo 
--      AND StorerKey = @cStorerKey 
--      Order by CartonNo    
      
      EXEC RDT.rdt_BuiltPrintJob  
       @nMobile,  
       @cStorerKey,  
       'CARTONLBL',      -- ReportType  
       'CartonLabel',    -- PrintJobName  
       @cDataWindow,  
       @cLabelPrinter,  
       @cTargetDB,  
       @cLangCode,  
       @nErrNo  OUTPUT,  
       @cErrMsg OUTPUT,  
       @cStorerKey,   
       @cPickSlipNo, 
       @nCartonNo,
       @nCartonNo 
      
      IF @nErrNo <> 0 
         GOTO RollBackTran
      
      SET @nPackQTY = 0
      SET @nPickQTY = 0
      SELECT @nPackQTY = SUM( QTY) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
      SELECT @nPickQTY = SUM( QTY) FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey
      
      
      IF @nPackQty = @nPickQty 
      BEGIN
         -- Print Label  
         UPDATE dbo.PackHeader WITH (ROWLOCK)  
         SET Status = '9'  
         WHERE PickSlipNo = @cPickSlipNo  
         AND StorerKey = @cStorerKey  
         
             
         SELECT @cManifestDataWindow = DataWindow,  
               @cTargetDB = TargetDB  
         FROM rdt.rdtReport WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND   ReportType = 'PACKLIST'  
         
         EXEC RDT.rdt_BuiltPrintJob  
          @nMobile,  
          @cStorerKey,  
          'PACKLIST',              -- ReportType  
          'PackingList',           -- PrintJobName  
          @cManifestDataWindow,  
          @cPaperPrinter,  
          @cTargetDB,  
          @cLangCode,  
          @nErrNo  OUTPUT,  
          @cErrMsg OUTPUT,  
          @cPickSlipNo, 
          @cOrderKey,
          '',
          '',
          ''

         IF @nErrNo <> 0 
            GOTO RollBackTran
      END
         
      IF EXISTS ( SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK) WHERE ToteNo = @cDropID
                  AND Mobile = @nMobile AND Status < '5' )
      BEGIN
         
         SELECT TOP 1 @cBatchKey = BatchKey
         FROM rdt.rdtECOMMLog WITH (NOLOCK)
         WHERE ToteNo = @cDropID
         AND Status = '0'
         AND OrderKey = CASE WHEN @cDropIDType = 'SINGLES' THEN OrderKey ELSE @cOrderKey END
         AND AddWho = @cUserName
         AND Mobile = @nMobile
         
         SELECT @nTotalPickedQty  = SUM(ExpectedQty)
         FROM rdt.rdtECOMMLog WITH (NOLOCK)
         WHERE ToteNo = @cDropID
         AND Status IN ('0' , '9' )
         AND OrderKey = CASE WHEN @cDropIDType = 'SINGLES' THEN OrderKey ELSE @cOrderKey END
         AND AddWho = @cUserName
         AND Mobile = @nMobile
         AND BatchKey = @cBatchKey
         AND ISNULL(ErrMSG,'')  = ''
         
         SELECT @nTotalScannedQty = SUM(ScannedQty) 
         FROM rdt.rdtECOMMLog WITH (NOLOCK)
         WHERE ToteNo = @cDropID
         AND Status = '9'
         AND OrderKey = CASE WHEN @cDropIDType = 'SINGLES' THEN OrderKey ELSE @cOrderKey END
         AND AddWho = @cUserName
         AND ISNULL(ErrMSG,'')  = ''
         AND Mobile = @nMobile
         AND BatchKey = @cBatchKey
   
         --INSERT INTO TRACEINFO (TraceName , TimeIN , Col1, Col2, Col3, Col4, Col5  ) 
         --VALUES ( 'rdt_842ExtUpdSP01' , Getdate() , @cDropID , @nTotalPickedQty , @nTotalScannedQty , @cUserName ,@cDropIDType ) 
      
   
         SET @cOrderKey      = ''
         SET @cTrackNo       = ''    
         SET @cCartonType    = ''    
         SET @cWeight        = ''    
         SET @cTaskStatus    = '1'
         SET @cTTLPickedQty  = @nTotalPickedQty
         SET @cTTLScannedQty = @nTotalScannedQty
         
      END
      ELSE
      BEGIN
         
         UPDATE dbo.DROPID WITH (Rowlock)
         SET   Status = '9'
              ,Editdate = GetDate()
         WHERE DropID = @cDropID
         AND   Status < '9'
   
         IF @@ERROR <> 0
         BEGIN
               SET @nErrNo = 101515
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'
               GOTO ROLLBACKTRAN
         END
            
         SET @cOrderKey      = ''
         SET @cTrackNo       = ''    
         SET @cCartonType    = ''    
         SET @cWeight        = ''    
         SET @cTaskStatus    = '9'
         SET @cTTLPickedQty  = ''
         SET @cTTLScannedQty = ''
      END 




      
      
   END
  
 
   IF @nStep = 4 
   BEGIN
      
      IF @cOption = '1'
      BEGIN
          SET @nErrNo = 101520  
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidOption'  
          GOTO RollBackTran  
      END
      
      IF @cOption = '5'
      BEGIN
         SET @cOrderKey      = @cOrderKey
         SET @cTrackNo       = ''    
         SET @cCartonType    = ''    
         SET @cWeight        = ''    
         SET @cTaskStatus    = '5'
         SET @cTTLPickedQty  = ''
         SET @cTTLScannedQty = ''
         
         -- Split rdt.rdtEcommLog 
         
         /****************************
          INSERT INTO rdtECOMMLog
         ****************************/

         IF EXISTS ( SELECT 1
                     FROM rdt.rdtEcommLog WITH (NOLOCK) 
                     WHERE ToteNo      = @cDropID  
                     AND   Orderkey    = @cOrderkey  
                     AND   AddWho      = @cUserName  
                     AND   Status      = '1'  
                     AND   ExpectedQty - ScannedQty > 0 )
         BEGIN

            INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate, BatchKey)
            SELECT Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty - ScannedQty, 0, AddWho, GETDATE(), EditWho, GETDATE(), BatchKey 
            FROM rdt.rdtEcommLog WITH (NOLOCK) 
            WHERE ToteNo      = @cDropID  
            AND   Orderkey    = @cOrderkey  
            AND   AddWho      = @cUserName  
            AND   Status      = '1'  
            AND   ExpectedQty - ScannedQty > 0 
         
   
            IF @@ROWCOUNT = 0 -- No data inserted
            BEGIN
               --ROLLBACK TRAN
               SET @nErrNo = 101530
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'InsEcommFail'
               GOTO ROLLBACKTRAN
            END

            UPDATE rdt.rdtECOMMlog WITH (ROWLOCK) 
            SET ExpectedQty = ScannedQty 
               ,ErrMsg = 'Close Pack'
            WHERE ToteNo     = @cDropID  
            AND   Orderkey    = @cOrderkey  
            AND   AddWho      = @cUserName  
            AND   Status      = '1'  
            AND   ExpectedQty - ScannedQty > 0 

            IF @@ROWCOUNT = 0 -- No data inserted
            BEGIN
               --ROLLBACK TRAN
               SET @nErrNo = 101532
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UpdEcommFail'
               GOTO ROLLBACKTRAN
            END

         END
         
         
      END   
      
      IF @cOption = '9' 
      BEGIN
      
         SET @cOrderKey = '' 
         
         DECLARE C_Tote_Short CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         
         SELECT RowRef, OrderKey
         FROM rdt.rdtECOMMLog WITH (NOLOCK)  
         WHERE ToteNo = @cDropID  
         --AND SKU = CASE WHEN @cOption ='1' THEN @cSKU  ELSE SKU END
         --AND SUM(ExpectedQty) > SUM(ScannedQty) --+ 1 
         AND Status < '5'  
         --AND AddWho = @cUserName
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
      
      
      --END
      
      --IF @cOption = '9'
      --BEGIN
      --   SET @cOrderKey      = ''
      --   SET @cTrackNo       = ''    
      --   SET @cCartonType    = ''    
      --   SET @cWeight        = ''    
      --   SET @cTaskStatus    = '9'
      --   SET @cTTLPickedQty  = ''
      --   SET @cTTLScannedQty = ''
      --END
      
   END
   
   IF @nStep = 5 
   BEGIN
      
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND DropID = @cDropID 
                  AND Status < '5' ) 
      BEGIN
            --ROLLBACK TRAN
            SET @nErrNo = 101521
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
            SET @nErrNo = 101524
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
           AND PK.Qty > 0 -- SOS# 329265
           AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) 
         GROUP BY PK.OrderKey, PK.SKU
   
         IF @@ROWCOUNT = 0 -- No data inserted
         BEGIN
            --ROLLBACK TRAN
            SET @nErrNo = 101501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoRecToProcess'
            GOTO ROLLBACKTRAN
         END
      
         SET @nTotalScannedQty = 0
   --      SELECT @nTotalScannedQty = SUM(QTY)
   --      FROM dbo.PickDetail PD WITH (NOLOCK)
   --      INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey
   --      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey
   --      WHERE PD.DropID = @cDropID
   --      AND (PD.Status IN  ('3','5') OR PD.ShipFlag = 'P')  
   --      AND PD.CaseID <> ''
   --      AND O.LoadKey = @cLoadKey
   --      AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) 
   --      AND PH.PickHeaderKey = @cPickSlipNo 
         
         --SELECT @nTotalScannedQty = SUM(ScannedQty) 
         --FROM rdt.rdtECOMMLog WITH (NOLOCK)
         --WHERE ToteNo = @cDropID
         --AND Status = '9'
         --AND OrderKey = CASE WHEN @cDropIDType = 'SINGLES' THEN OrderKey ELSE @cOrderKey END
         --AND AddWho = @cUserName
   
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
   ROLLBACK TRAN rdt_842ExtUpdSP01 -- Only rollback change made here      
      
Quit:      
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
      COMMIT TRAN rdt_842ExtUpdSP01      
        
      
END  


GO