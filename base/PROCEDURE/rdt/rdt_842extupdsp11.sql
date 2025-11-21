SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/        
/* Store procedure: rdt_842ExtUpdSP11                                   */        
/* Copyright      : LF                                                  */        
/*                                                                      */        
/* Purpose: MosaicO DTC Logic                                           */        
/*                                                                      */        
/* Modifications log:                                                   */        
/* Date        Rev  Author   Purposes                                   */        
/* 2021-10-14  1.0  James    WMS-18115. Created                         */        
/* 2021-11-23  1.1  James    Update PackDetail.DropID = LabelNo(james01)*/      
/* 2023-05-10  1.2  James    WMS-22534 Add exec middleware (james02)    */    
/* 2023-06-08  1.3  James    Remove iml trigger (james03)               */  
/* 2023-09-13  1.4  James    WMS-23588 Add orderkey param into carton   */
/*                           label printing (james04)                   */
/************************************************************************/        
CREATE   PROC [RDT].[rdt_842ExtUpdSP11] (        
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
           ,@fCartonLength  FLOAT        
           ,@fCartonHeight       FLOAT        
           ,@fCartonWidth        FLOAT        
           ,@fStdGrossWeight     FLOAT        
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
           ,@cFilePath           NVARCHAR(100)             
           ,@cProcessType        NVARCHAR( 15)         
           ,@cWinPrinter         NVARCHAR(128)        
           ,@cPrinterName        NVARCHAR(100)            
           ,@cPrintFilePath      NVARCHAR(100)           
           ,@cPrinterInGroup     NVARCHAR( 10)               
           ,@cReportType         NVARCHAR( 10)          
           ,@cFileName           NVARCHAR( 50)          
           ,@cWinPrinterName     NVARCHAR(100)           
           ,@cPrintCommand       NVARCHAR(MAX)                     
           ,@cPaperType          NVARCHAR( 10)                      
           ,@cFilePrefix         NVARCHAR( 30)        
           ,@tCartonLabel        VariableTable      
           ,@tRDTPrintJob        VariableTable      
           ,@tDatawindow         VariableTable      
           ,@tSHIPLabel          VariableTable      
      
   DECLARE @cCartonLabel         NVARCHAR( 10)      
   DECLARE @cPackList            NVARCHAR( 10)      
   DECLARE @nOrderCnt            INT      
   DECLARE @cTransmitlogKey      NVARCHAR( 10)      
   DECLARE @fSKU_Weight          FLOAT      
   DECLARE @fSKU_Cube            FLOAT      
   DECLARE @b_Success            INT    
   DECLARE @n_Err                INT    
   DECLARE @c_ErrMsg             NVARCHAR( 20)    
      
   SET @nErrNo   = 0        
   SET @cErrMsg  = ''        
        
   SET @nTranCount = @@TRANCOUNT        
        
   BEGIN TRAN        
   SAVE TRAN rdt_842ExtUpdSP11        
        
   IF @nStep = 1        
   BEGIN        
      IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)        
                     WHERE StorerKey = @cStorerKey        
                     AND   DropID = @cDropID        
                     AND   CaseID = ''        
                     AND   [Status] = '5' )        
      BEGIN        
         SET @nErrNo = 177101        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Inv DropID'        
         GOTO ROLLBACKTRAN        
      END        
      
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)        
                  WHERE StorerKey = @cStorerKey        
                  AND   DropID = @cDropID        
                  AND   Qty > 0      
                  AND   [Status] <> '4'         
                  AND   [Status] < '5' )        
      BEGIN        
         SET @nErrNo = 177102        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'PickNotComplete'        
         GOTO ROLLBACKTRAN        
      END        
               
      DECLARE @curDelEcomLog  CURSOR      
      SET @curDelEcomLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR      
      SELECT RowRef FROM rdt.rdtECOMMLog WITH (NOLOCK)      
      WHERE ToteNo = @cDropID        
      AND Status < '9'        
      OPEN @curDelEcomLog      
      FETCH NEXT FROM @curDelEcomLog INTO @nRowRef      
      WHILE @@FETCH_STATUS = 0      
      BEGIN      
         UPDATE rdt.rdtECOMMLOG WITH (ROWLOCK)        
         SET Status = '9'        
         , ErrMsg = 'CLEAN UP PACK'         
         WHERE RowRef = @nRowRef      
        
         IF @@ERROR <> 0        
         BEGIN        
            SET @nErrNo = 177103        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UpdEcommFail'        
            GOTO ROLLBACKTRAN        
         END        
      
         FETCH NEXT FROM @curDelEcomLog INTO @nRowRef      
      END      
            
      SELECT @nOrderCnt = COUNT( DISTINCT OrderKey)      
      FROM dbo.PickDetail WITH (NOLOCK)      
      WHERE StorerKey = @cStorerKey        
      AND   DropID = @cDropID        
      AND   Qty > 0      
      AND   [Status] <> '4'      
      
      IF @nOrderCnt = 1      
         SET @cDropIDType = 'MULTIS'      
      ELSE      
         SET @cDropIDType = 'SINGLE'      
      
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
      AND PK.Qty > 0       
      AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' )      
      AND O.ECOM_SINGLE_Flag = 'S'      
      GROUP BY PK.OrderKey, PK.SKU        
        
      IF @@ROWCOUNT = 0 -- No data inserted        
      BEGIN        
         SET @nErrNo = 177104        
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
        
      SET @cOrderKey      = CASE WHEN @cDropIDType = 'MULTIS' THEN @cOrderKey ELSE '' END        
      SET @cTrackNo       = ''        
      SET @cCartonType    = ''        
      SET @cWeight        = ''        
      SET @cTaskStatus    = CASE WHEN @nOrderCnt > 1 THEN '1' ELSE '9' END        
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
      IF @cGenLabelNoSP = '0'      
         SET @cGenLabelNoSP = ''      
      
      SELECT @cLabelPrinter = Printer        
           , @cPaperPrinter = Printer_Paper        
      FROM rdt.rdtMobrec WITH (NOLOCK)        
      WHERE Mobile = @nMobile        
      
      -- check if sku exists in tote        
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)        
                      WHERE ToteNo = @cDropID        
                      AND SKU = @cSKU        
               AND AddWho = @cUserName        
                      AND Status IN ('0', '1') )        
      BEGIN        
         SET @nErrNo = 177105        
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
         SET @nErrNo = 177106        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Qty Exceeded        
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
      AND    SUM(ExpectedQty) > SUM(ScannedQty)         
      AND    [STATUS] < '5'        
      AND    AddWho = @cUserName        
      ORDER BY [STATUS] Desc        
        
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
               @cPickSlipNo   OUTPUT,        
               @bsuccess      OUTPUT,        
               @nerrNo        OUTPUT,        
               @cerrmsg       OUTPUT        
        
               SET @cPickSlipNo = 'P' + @cPickSlipNo        
            END        
        
            INSERT INTO dbo.PICKHEADER (PickHeaderKey, Storerkey, Orderkey, PickType, Zone, TrafficCop, AddWho, AddDate, EditWho, EditDate)        
            VALUES (@cPickSlipNo, @cStorerkey, @cOrderKey, '0', 'D', '', sUser_sName(), GETDATE(), sUser_sName(), GETDATE())        
        
            IF @@ERROR <> 0        
            BEGIN        
               SET @nErrNo = 177107        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPickHdrFail'        
               GOTO RollBackTran        
            END        
            ELSE        
            BEGIN        
               UPDATE dbo.PICKDETAIL WITH (ROWLOCK) SET        
                  PickSlipNo = @cPickSlipNo,        
                  EditWho = SUSER_SNAME(),      
                  EditDate = GETDATE()        
               WHERE StorerKey = @cStorerKey        
               AND   Orderkey = @cOrderKey        
               AND   (Status = '5' OR ShipFlag = 'P')        
               AND   ISNULL(RTrim(PickSlipNo),'') = ''        
        
               IF @@ERROR <> 0        
               BEGIN        
                  SET @nErrNo = 177108        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDetFail'        
                  GOTO RollBackTran        
               END        
            END        
        
            INSERT INTO dbo.PickingInfo (PickSlipNo , ScanInDate )        
            VALUES ( @cPickSlipNo , GetDate() )        
        
            IF @@ERROR <> 0        
            BEGIN        
               SET @nErrNo = 177109        
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
            SET @nErrNo = 177110        
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
         IF @cGenLabelNoSP = ''      
         BEGIN      
            -- Get new LabelNo                  
            EXECUTE isp_GenUCCLabelNo                  
               @cStorerkey = @cStorerKey,                  
               @cLabelNo   = @cLabelNo   OUTPUT,                  
               @b_Success  = @bsuccess   OUTPUT,                  
               @n_err      = @nErrNo     OUTPUT,                  
               @c_errmsg   = @cErrMsg    OUTPUT                  
         END      
         ELSE      
         BEGIN      
            SET @cExecStatements = N'EXEC dbo.' + RTRIM( @cGenLabelNoSP) +        
                                    '   @cPickSlipNo           ' +        
                                    ' , @nCartonNo             ' +        
                                    ' , @cLabelNo     OUTPUT   '        
        
            SET @cExecArguments =        
                      N'@cPickSlipNo  nvarchar(10),       ' +        
                       '@nCartonNo    int,                ' +        
                       '@cLabelNo     nvarchar(20) OUTPUT '        
        
            EXEC sp_executesql @cExecStatements, @cExecArguments,        
                                 @cPickSlipNo        
                               , @nCartonNo        
                               , @cLabelNo      OUTPUT        
         END      
                 
         IF ISNULL(@cLabelNo,'')  = ''        
         BEGIN        
            SET @nErrNo = 177111        
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
         END        
         ELSE        
         BEGIN        
            IF @cGenLabelNoSP = ''      
            BEGIN      
               -- Get new LabelNo                  
               EXECUTE isp_GenUCCLabelNo                  
                  @cStorerkey = @cStorerKey,                  
                  @cLabelNo   = @cLabelNo   OUTPUT,                  
                  @b_Success  = @bsuccess   OUTPUT,                  
                  @n_err      = @nErrNo     OUTPUT,                  
                  @c_errmsg   = @cErrMsg    OUTPUT                  
            END      
            ELSE      
            BEGIN      
               SET @cExecStatements = N'EXEC dbo.' + RTRIM( @cGenLabelNoSP) +        
             '   @cPickSlipNo           ' +        
                                       ' , @nCartonNo             ' +        
                                       ' , @cLabelNo     OUTPUT   '        
        
               SET @cExecArguments =        
                         N'@cPickSlipNo  nvarchar(10),       ' +        
                          '@nCartonNo    int,                ' +        
                          '@cLabelNo     nvarchar(20) OUTPUT '        
        
               EXEC sp_executesql @cExecStatements, @cExecArguments,        
                                    @cPickSlipNo        
                                  , @nCartonNo        
                                  , @cLabelNo      OUTPUT        
            END      
                  
            IF ISNULL(@cLabelNo,'') = ''        
            BEGIN        
               SET @nErrNo = 177112        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoLabelNoGen        
               GOTO RollBackTran        
            END        
         END        
      END        
        
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
         BEGIN        
            -- Insert PackDetail        
            INSERT INTO dbo.PackDetail        
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, DropID, UPC, AddWho, AddDate, EditWho, EditDate, RefNo2)        
            VALUES        
               (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, 1 ,        
               @cDropID, @cLabelNo, '', sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), '')        
        
            IF @@ERROR <> 0        
            BEGIN        
               SET @nErrNo = 177113        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDetFail'        
               GOTO RollBackTran        
            END        
      
            -- (james01)      
            SELECT TOP 1 @nCartonNo = CartonNo      
            FROM dbo.PackDetail WITH (NOLOCK)      
            WHERE PickSlipNo = @cPickSlipNo      
            AND   LabelNo = @cLabelNo      
            ORDER BY 1      
        
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
         END --packdetail for sku/order does not exists        
         ELSE        
         BEGIN        
            UPDATE dbo.Packdetail WITH (ROWLOCK) SET        
               Qty = Qty + 1,      
               EditWho = SUSER_SNAME(),      
               EditDate = GETDATE()      
            WHERE PickSlipNo = @cPickSlipNo        
            AND   SKU = @cSku      
        
            IF @@ERROR <> 0        
            BEGIN        
               SET @nErrNo = 177114        
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
            SET @nErrNo = 177115        
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
                  SET @nErrNo = 177116        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFull        
                  GOTO RollBackTran        
               END        
        
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
                  SET @nErrNo = 177117        
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
                  SET @nErrNo = 177118        
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
                  SET @nErrNo = 177119        
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
                  SET @nErrNo = 177120        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFaill        
                  GOTO RollBackTran        
               END        
        
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
      
      SELECT @cShipperKey = ShipperKey      
      FROM dbo.Orders WITH (NOLOCK)        
      WHERE OrderKey = @cOrderKey        
        
      -- Prepare for TaskStatus        
      IF @nTotalPickQty = @nTotalPackQty        
      BEGIN        
         UPDATE dbo.PackHeader WITH (ROWLOCK) SET        
            Status = '9'        
         WHERE PickSlipNo = @cPickSlipNo        
      
         IF @@ERROR <> 0        
         BEGIN        
            SET @nErrNo = 177121        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PackCfm Fail'        
            GOTO RollBackTran        
         END       
         /*      
         SELECT TOP 1 @nCartonNo = CartonNo      
         FROM dbo.PackDetail WITH (NOLOCK)      
         WHERE PickSlipNo = @cPickSlipNo      
         ORDER BY 1      
               
         SET @bSuccess = 1          
         EXEC ispGenTransmitLog2          
             @c_TableName        = 'WSCRSOREQILS'          
            ,@c_Key1             = @cOrderKey          
            ,@c_Key2             = @nCartonNo          
            ,@c_Key3             = @cStorerkey          
            ,@c_TransmitBatch    = ''          
            ,@b_Success          = @bSuccess    OUTPUT          
            ,@n_err              = @nErrNo      OUTPUT          
            ,@c_errmsg           = @cErrMsg     OUTPUT          
          
         IF @bSuccess <> 1          
         BEGIN      
            SET @nErrNo = 177130        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsTL2Log Err'        
            GOTO RollBackTran          
         END      
               
         SELECT @cTransmitlogKey = TransmitlogKey      
         FROM dbo.TRANSMITLOG2 WITH (NOLOCK)      
         WHERE tablename = 'WSCRSOREQILS'      
         AND   key1 = @cOrderKey      
         AND   key2 = @nCartonNo      
         AND   key3 = @cStorerkey      
         AND   AddWho = @cUserName      
         ORDER BY 1 DESC      
               
         SET @bSuccess = 1      
         EXEC isp_QCmd_WSTransmitLogInsertAlert       
             @c_QCmdClass           = ''       
            ,@c_FrmTransmitlogKey   = @cTransmitlogKey       
            ,@c_ToTransmitlogKey    = @cTransmitlogKey       
            ,@b_Debug               = 0      
            ,@b_Success             = @bSuccess       
            ,@n_Err                 = @nErrNo OUTPUT      
            ,@c_ErrMsg              = @cErrMsg OUTPUT      
      
         IF @bSuccess <> 1          
         BEGIN      
            SET @nErrNo = 177131        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QCmdLog Err'        
            GOTO RollBackTran          
         END      
         */      
         UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)        
         SET   Status      = '9'    -- completed        
         WHERE ToteNo      = @cDropID        
         AND   Orderkey    = @cOrderkey        
         AND   AddWho      = @cUserName        
         AND   Status      = '1'        
        
         IF @@ERROR <> 0        
         BEGIN        
            SET @nErrNo = 177122        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'        
            GOTO RollBackTran        
         END        
      
         SET @cPostDataCapture = rdt.RDTGetConfig( @nFunc, 'PostDataCapture', @cStorerKey)        
         IF @cPostDataCapture = '0'        
            SET @cPostDataCapture = ''        
      
         -- Need capture carton, print later      
         IF @cPostDataCapture = ''      
         BEGIN      
            SET @cCartonLabel = rdt.RDTGetConfig( @nFunc, 'CartonLbl', @cStorerkey)      
            IF @cCartonLabel = '0'      
               SET @cCartonLabel = ''      
      
            IF @cCartonLabel <> ''      
            BEGIN      
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)          
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)           
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)           
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@nToCartonNo', @nCartonNo)          
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cFromLabelNo', @cLabelNo)           
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cToLabelNo', @cLabelNo)          
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)          
                 
               -- Print label          
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',           
                  @cCartonLabel, -- Report type          
                  @tCartonLabel, -- Report params          
                  'rdt_842ExtUpdSP11',           
                  @nErrNo  OUTPUT,          
                  @cErrMsg OUTPUT          
                  
               IF @nErrNo <> 0      
                  GOTO RollBackTran      
            END      
         END      
      
         IF @cPostDataCapture <> ''        
         BEGIN      
            SET @cTaskStatus = '9'      
            SET @cCartonType = rdt.RDTGetConfig( @nFunc, 'DefaultCtnType', @cStorerKey)      
            IF @cCartonType = '0'      
               SET @cCartonType = ''      
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
               UPDATE dbo.DROPID WITH (Rowlock)        
               SET   Status = '9'        
                    ,Editdate = GetDate()        
               WHERE DropID = @cDropID        
               AND   Status < '9'        
        
               IF @@ERROR <> 0        
               BEGIN        
                  SET @nErrNo = 177123        
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
               SET @nErrNo = 177124        
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
               SET @nErrNo = 177125        
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
      
       SELECT @cDropIDType = DropIDType        
       FROM dbo.DropID WITH (NOLOCK)        
       WHERE DropID = @cDropID        
       AND Status = '5'        
        
     /****************************        
       PACKINFO        
      ****************************/        
      SELECT       
         @fCartonHeight = CZ.CartonHeight,      
         @fCartonLength = CartonLength,      
         @fCartonWidth = CartonWidth,       
         @fCartonWeight = CartonWeight,      
         @fCartonCube = [Cube]      
      FROM dbo.CARTONIZATION CZ WITH (NOLOCK)      
      JOIN dbo.STORER ST WITH (NOLOCK) ON ( ST.CartonGroup = CZ.CartonizationGroup)      
      WHERE ST.StorerKey = @cStorerKey      
      AND   CZ.CartonType = @cCartonType      
        
      SELECT @cPickSlipNo = PickSlipNo        
      FROM dbo.PackHeader WITH (NOLOCK)        
      WHERE OrderKey = @cOrderKey        
        
      SELECT TOP 1 @nCartonNo  = CartonNo,      
                   @cLabelNo = LabelNo,      
                   @cTrackingNo = UPC      
      FROM dbo.PackDetail WITH (NOLOCK)        
      WHERE PickSlipNo = @cPickSlipNo        
      ORDER BY CartonNo Desc        
      
      IF @nCartonNo = 1      
         SELECT @cTrackingNo = TrackingNo      
         FROM dbo.Orders WITH (NOLOCK)      
         WHERE OrderKey = @cOrderkey      
      
      SELECT @nTotalPackedQty = SUM( Qty)        
      FROM dbo.PackDetail WITH (NOLOCK)        
      WHERE StorerKey = @cStorerKey        
      AND PickSlipNo = @cPickSlipNo        
      AND CartonNo = @nCartonNo        
      GROUP BY CartonNo        
        
      SELECT @fSKU_Weight = STDGROSSWGT,      
             @fSKU_Cube = STDCUBE      
      FROM dbo.SKU WITH (NOLOCK)      
      WHERE StorerKey = @cStorerKey      
      AND   Sku = @cSKU      
            
      SET @fCartonWeight = @fCartonWeight + ( @fSKU_Weight * @nTotalPackedQty)       
      SET @fCartonCube = @fCartonCube + ( @fSKU_Cube * @nTotalPackedQty)      
        
      IF NOT EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)                              
                      WHERE PickSlipNo = @cPickSlipNo        
                      AND CartonNo = @nCartonNo )        
      BEGIN        
         INSERT INTO dbo.PackInfo(      
            PickSlipNo, CartonNo, CartonType, Qty,       
            Length, Width, Height, [Weight], CUBE,       
            AddWho, AddDate, EditWho, EditDate)        
         VALUES       
         ( @cPickSlipNo , @nCartonNo, @cCartonType, @nTotalPackedQty,       
         @fCartonLength, @fCartonWidth, @fCartonHeight, @fCartonWeight, @fCartonCube,       
         'rdt' + sUser_sName(), GetDate(), 'rdt' + sUser_sName(), GetDate())            
         IF @@ERROR <> 0        
         BEGIN        
            SET @nErrNo = 177126        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackInfoFail'        
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
      AND   Status      = '1'        
        
      IF @@ERROR <> 0        
      BEGIN        
         SET @nErrNo = 177127        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'        
         GOTO RollBackTran        
      END        
      
      SELECT @cShipperKey = ShipperKey      
      FROM dbo.Orders WITH (NOLOCK)        
      WHERE OrderKey = @cOrderKey        
      
      SET @cCartonLabel = rdt.RDTGetConfig( @nFunc, 'CartonLbl', @cStorerkey)      
      IF @cCartonLabel = '0'      
         SET @cCartonLabel = ''      
      
      IF @cCartonLabel <> ''      
      BEGIN      
         INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)          
         INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)           
         INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)           
         INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@nToCartonNo', @nCartonNo)          
         INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cFromLabelNo', @cLabelNo)           
         INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cToLabelNo', @cLabelNo)          
         INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)

         -- Print label          
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',           
            @cCartonLabel, -- Report type          
            @tCartonLabel, -- Report params          
            'rdt_842ExtUpdSP11',           
            @nErrNo  OUTPUT,          
            @cErrMsg OUTPUT          
                  
         IF @nErrNo <> 0      
            GOTO RollBackTran      
      END      
            
      SET @nPackQTY = 0        
      SET @nPickQTY = 0        
      SELECT @nPackQTY = ISNULL( SUM( QTY), 0) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo        
      SELECT @nPickQTY = ISNULL( SUM( QTY), 0) FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey        
        
      IF @nPackQty = @nPickQty        
      BEGIN        
         -- Print Label        
         UPDATE dbo.PackHeader WITH (ROWLOCK)        
         SET Status = '9'        
         WHERE PickSlipNo = @cPickSlipNo        
         AND StorerKey = @cStorerKey        
      
         IF @@ERROR <> 0        
         BEGIN        
            SET @nErrNo = 177128        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PackCfm Fail'        
            GOTO RollBackTran        
         END       
      
         SELECT TOP 1 @nCartonNo = CartonNo      
         FROM dbo.PackDetail WITH (NOLOCK)      
         WHERE PickSlipNo = @cPickSlipNo      
         ORDER BY 1    
             
         /*    (james03)  
         SET @bSuccess = 1          
         EXEC ispGenTransmitLog2          
             @c_TableName        = 'WSCRSOREQILS'          
            ,@c_Key1             = @cOrderKey          
            ,@c_Key2             = @nCartonNo          
            ,@c_Key3             = @cStorerkey          
            ,@c_TransmitBatch    = ''          
            ,@b_Success          = @bSuccess    OUTPUT          
            ,@n_err              = @nErrNo      OUTPUT          
            ,@c_errmsg           = @cErrMsg     OUTPUT          
          
         IF @bSuccess <> 1          
         BEGIN      
            SET @nErrNo = 177132        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsTL2Log Err'        
            GOTO RollBackTran          
         END      
               
         SELECT @cTransmitlogKey = TransmitlogKey      
         FROM dbo.TRANSMITLOG2 WITH (NOLOCK)      
         WHERE tablename = 'WSCRSOREQILS'      
         AND   key1 = @cOrderKey      
         AND   key2 = @nCartonNo      
         AND   key3 = @cStorerkey      
         AND   AddWho = @cUserName      
         ORDER BY 1 DESC      
               
         SET @bSuccess = 1      
         EXEC isp_QCmd_WSTransmitLogInsertAlert       
             @c_QCmdClass           = ''       
            ,@c_FrmTransmitlogKey   = @cTransmitlogKey       
            ,@c_ToTransmitlogKey    = @cTransmitlogKey       
            ,@b_Debug               = 0      
            ,@b_Success             = @bSuccess       
            ,@n_Err                 = @nErrNo OUTPUT      
            ,@c_ErrMsg              = @cErrMsg OUTPUT      
      
         IF @bSuccess <> 1          
         BEGIN      
            SET @nErrNo = 177133        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QCmdLog Err'        
            GOTO RollBackTran          
         END      
         */      
         SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PackList', @cStorerkey)      
         IF @cPackList = '0'      
            SET @cPackList = ''      
               
         IF @cPackList <> ''      
         BEGIN      
            DECLARE @tPackList AS VariableTable          
            INSERT INTO @tPackList (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)          
            INSERT INTO @tPackList (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)           
            INSERT INTO @tPackList (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)           
           
            -- Print label          
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',           
               @cPackList, -- Report type          
               @tPackList, -- Report params          
               'rdt_842ExtUpdSP11',           
               @nErrNo  OUTPUT,          
               @cErrMsg OUTPUT          
                  
            IF @nErrNo <> 0      
               GOTO RollBackTran      
         END      
      END        
    
    
      EXEC [dbo].[isp_Carrier_Middleware_Interface]            
         @c_OrderKey    = @cOrderKey         
      , @c_Mbolkey     = ''      
      , @c_FunctionID  = @nFunc          
      , @n_CartonNo    = 0      
      , @n_Step        = @nStep      
      , @b_Success     = @b_Success OUTPUT            
      , @n_Err         = @n_Err     OUTPUT            
      , @c_ErrMsg      = @c_ErrMsg  OUTPUT            
       
      IF @b_Success = 0    
      BEGIN    
         SET @nErrNo = 177141    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Exec ITF Fail    
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
               SET @nErrNo = 177129        
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
          SET @nErrNo = 177134        
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidOption'        
          GOTO RollBackTran        
      END        
        
      IF @cOption = '5'        
      BEGIN        
        
        IF @cOrderKey <> ''        
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
               SET @nErrNo = 177135        
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
               SET @nErrNo = 177136        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UpdEcommFail'        
               GOTO ROLLBACKTRAN        
            END        
        
         END        
        
         SET @cTaskStatus = '9'      
        
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
               SET @nErrNo = 177137        
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
   /*      
   IF @nStep = 5        
   BEGIN        
        
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)        
                  WHERE StorerKey = @cStorerKey        
                  AND DropID = @cDropID        
                  AND Status < '5' )        
      BEGIN        
            SET @nErrNo = 177137        
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
            SET @nErrNo = 177139        
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
           AND O.Type IN  ( SELECT CL.Code FROM dbo.      
           P CL WITH (NOLOCK)        
                           WHERE CL.ListName = 'ECOMTYPE'        
                           AND CL.StorerKey = CASE WHEN CL.StorerKey = '' THEN '' ELSE O.StorerKey END)        
           AND PK.Qty > 0       
           AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' )        
         GROUP BY PK.OrderKey, PK.SKU        
        
         IF @@ROWCOUNT = 0 -- No data inserted        
         BEGIN        
            SET @nErrNo = 177140        
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
   */      
   GOTO QUIT        
        
RollBackTran:        
   ROLLBACK TRAN rdt_842ExtUpdSP11 -- Only rollback change made here        
        
Quit:        
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started        
      COMMIT TRAN rdt_842ExtUpdSP11        
        
END      

GO