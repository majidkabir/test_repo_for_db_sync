SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/        
/* Store procedure: rdt_841ExtUpdSP16                                   */        
/* Copyright      : LF                                                  */        
/*                                                                      */        
/* Purpose: Ecomm Update SP                                             */        
/*                                                                      */        
/* Modifications log:                                                   */        
/* Date        Rev  Author   Purposes                                   */        
/* 2021-04-08  1.0  James    WMS-16779 Created                          */  
/* 2021-05-25  1.1  James    WMS-17083 Move pack cfm to step 7 (james01)*/  
/* 2021-04-16  1.2  James    WMS-16024 Standarized use of TrackingNo    */        
/*                           (james02)                                  */        
/* 2021-06-04  1.3 James     WMS-17180 Add config to determine whether  */
/*                           use Udf04 or TrackingNo as system          */
/*                           tracking no (james03)                      */
/*                           Add Serial No param                        */
/* 2021-07-27  1.4  Chermain WMS-17410 Add VariableTable Param (cc01)   */
/************************************************************************/        
      
CREATE PROC [RDT].[rdt_841ExtUpdSP16] (        
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
          ,@cSOStatus         NVARCHAR(10)        
          ,@cGenPackDetail    NVARCHAR(1)        
          ,@cShowTrackNoScn   NVARCHAR(1)        
          ,@nRowRef           INT        
          ,@cPickDetailKey    NVARCHAR(10)      
          ,@cBarcode          NVARCHAR(60)       
          ,@cDecodeLabelNo    NVARCHAR(20)      
          ,@cPackSwapLot_SP   NVARCHAR(20)       
          ,@cSQL              NVARCHAR(1000)           
          ,@cSQLParam         NVARCHAR(1000)            
          ,@cType             NVARCHAR(10)       
          ,@cGenLabelNo_SP    NVARCHAR(20)      
          ,@cRoute            NVARCHAR( 10)         
          ,@cConsigneeKey     NVARCHAR( 15)      
          ,@nInputKey         INT       
          ,@cAutoMBOLPack     NVARCHAR( 1)   -- (james01)  
          ,@cUseUdf04AsTrackNo   NVARCHAR( 1)   -- (james03)
    
   DECLARE @nWeight FLOAT,    
           @nCube   FLOAT,
           @cOrderKey NVARCHAR(20)
    
   DECLARE @cTrackingNo NVARCHAR(20)    
    
   DECLARE @tOutBoundList AS VariableTable                  
   DECLARE @tOutBoundList2 AS VariableTable       
    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN      
   SAVE TRAN rdt_841ExtUpdSP16      
    
   SELECT @cLabelPrinter = Printer        
      ,@cPaperPrinter = Printer_Paper        
      ,@cBarCode      = I_Field04      
      ,@cLoadKey      = V_LoadKey      
      ,@nInputKey     = InputKey      
   FROM rdt.rdtMobRec WITH (NOLOCK)        
   WHERE Mobile = @nMobile        
        
   SET @cGenPackDetail  = ''        
   SET @cGenPackDetail = rdt.RDTGetConfig( @nFunc, 'GenPackDetail', @cStorerkey)        
   
   -- (james03)
   SET @cUseUdf04AsTrackNo = rdt.RDTGetConfig( @nFunc, 'UseUdf04AsTrackNo', @cStorerKey)

   IF @nStep = 2        
   BEGIN        
      SET @nCartonNo = 0   
      
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
      
      IF ISNULL( @cPickSlipno ,'') = ''        
      BEGIN        
         SELECT @cPickslipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderkey      
      
         IF ISNULL( @cPickSlipno ,'') = ''      
         BEGIN      
            EXECUTE dbo.nspg_GetKey        
               'PICKSLIP',        
               9,        
               @cPickslipno   OUTPUT,        
               @bsuccess      OUTPUT,        
               @nErrNo        OUTPUT,        
               @cErrMsg       OUTPUT        
        
            IF @nErrNo<>0        
            BEGIN        
               SET @nErrNo = 167101        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetPKSlip#Fail      
               GOTO RollBackTran        
            END        
        
            SELECT @cPickslipno = 'P'+ @cPickslipno        
        
            INSERT INTO dbo.PICKHEADER       
            (  PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, TrafficCop)        
            VALUES        
            ( @cPickslipno, '', @cOrderKey, '0', 'D', '')        
        
            IF @@ERROR<>0        
            BEGIN        
               SET @nErrNo = 167102        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InstPKHdrFail      
               GOTO RollBackTran        
            END        
         END      
      END --ISNULL(@cPickSlipno, '') = ''        
            
            
      IF NOT EXISTS ( SELECT 1        
                      FROM dbo.PickingInfo WITH (NOLOCK)        
                      WHERE PickSlipNo = @cPickSlipNo)        
      BEGIN        
         INSERT INTO dbo.PickingInfo        
         ( PickSlipNo  ,ScanInDate  ,PickerID  ,ScanOutDate  ,AddWho  ,TrafficCop )        
         VALUES        
         ( @cPickSlipNo, GETDATE(), @cUserName, NULL, @cUserName, '')        
        
         IF @@ERROR<>0        
         BEGIN        
            SET @nErrNo = 167103        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan In Fail        
            GOTO RollBackTran        
         END        
      END        
      
      -- Create PackHeader if not yet created            
      IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)            
      BEGIN            
         SELECT @cRoute = ISNULL(RTRIM(Route),''),      
                @cConsigneeKey = ISNULL(RTRIM(ConsigneeKey),'')            
         FROM dbo.Orders WITH (NOLOCK)            
         WHERE Orderkey = @cOrderkey            
                  
         INSERT INTO dbo.PACKHEADER            
         (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey, OrderRefNo, TtlCnts, [STATUS],estimatetotalctn)             
         VALUES            
         (@cPickSlipNo, @cStorerkey, @cOrderkey, @cLoadKey, @cRoute, @cConsigneeKey, '', 0, '0','1')             
                  
          IF @@ERROR <> 0            
          BEGIN            
            SET @nErrNo = 167104            
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackHDRFail            
            GOTO RollBackTran            
         END            
      END       

      SELECT @cTrackingNo = TrackingNo    
      FROM dbo.CartonTrack WITH (NOLOCK)    
      WHERE LabelNo = @cOrderkey    
    
      IF NOT EXISTS (SELECT 1           
                     FROM dbo.CartonTrack WITH (NOLOCK)    
                     WHERE LabelNo = @cOrderkey    
                     AND CarrierName ='SN')    
      BEGIN    
    
         SET @cTrackingNo=@cTrackingNo+'-1'    
    
         INSERT INTO dbo.CartonTrack(TrackingNo, CarrierName, KeyName, LabelNo, CarrierRef1, CarrierRef2)    
         SELECT @cTrackingNo,CarrierName, KeyName + '_child', LabelNo, CarrierRef1, CarrierRef2    
         FROM dbo.CartonTrack WITH (NOLOCK)    
         WHERE LabelNo = @cOrderkey    
      END    
    
      -- Update PackDetail.Qty if it is already exists            
      IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)            
                 WHERE StorerKey = @cStorerkey            
                 AND PickSlipNo = @cPickSlipNo            
                 AND CartonNo = @nCartonNo            
                 AND SKU = @cSKU        
                 AND UPC = @cBarcode) -- different 2D barcode split to different packdetail line        
      BEGIN            
         UPDATE dbo.PackDetail WITH (ROWLOCK) SET             
            Qty = Qty + 1,        
            Refno=@cTrackingNo,    
            dropid=@cTrackingNo,    
            EditDate = GETDATE(),            
            EditWho = 'rdt.' + sUser_sName()        
         WHERE StorerKey = @cStorerkey            
         AND PickSlipNo = @cPickSlipNo            
         AND CartonNo = @nCartonNo            
         AND SKU = @cSKU            
         AND UPC = @cBarcode        
                  
         IF @@ERROR <> 0            
         BEGIN            
            SET @nErrNo = 167105            
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPKDET Failed            
            GOTO RollBackTran            
         END            
      END            
      ELSE     -- Insert new PackDetail            
      BEGIN            
         -- Check if same carton exists before. Diff sku can scan into same carton            
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)            
                    WHERE StorerKey = @cStorerkey            
                    AND PickSlipNo = @cPickSlipNo            
                    AND CartonNo = @nCartonNo)            
         BEGIN          
            SET @cLabelNo = ''      
      
            SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo_SP', @cStorerkey)       
            IF @cGenLabelNo_SP = '0'      
               SET @cGenLabelNo_SP = ''      
      
            IF @cGenLabelNo_SP <> '' AND       
               EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenLabelNo_SP AND type = 'P')      
            BEGIN      
               SET @nErrNo = 0      
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cGenLabelNo_SP) +           
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, ' +       
                  ' @cTrackNo, @cSKU, @cLabelNo OUTPUT, @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '          
               SET @cSQLParam =          
                  '@nMobile                   INT,           ' +      
                  '@nFunc                     INT,           ' +      
                  '@cLangCode                 NVARCHAR( 3),  ' +      
                  '@nStep                     INT,           ' +      
                  '@nInputKey                 INT,           ' +      
                  '@cStorerkey                NVARCHAR( 15), ' +      
                  '@cOrderKey                 NVARCHAR( 10), ' +      
                  '@cPickSlipNo               NVARCHAR( 10), ' +      
                  '@cTrackNo                  NVARCHAR( 20), ' +      
                  '@cSKU                      NVARCHAR( 20), ' +      
                  '@cLabelNo                  NVARCHAR( 20) OUTPUT, ' +      
                  '@nCartonNo                 INT           OUTPUT, ' +      
                  '@nErrNo                    INT           OUTPUT, ' +      
                  '@cErrMsg                   NVARCHAR( 20) OUTPUT  '       
                     
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,           
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo,       
                  @cTrackNo, @cSKU, @cLabelNo OUTPUT, @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT       
      
               IF @nErrNo <> 0      
               BEGIN          
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')      
                  GOTO RollBackTran          
               END          
            END      
            ELSE      
            BEGIN      
               -- Get new LabelNo       
               EXECUTE isp_GenUCCLabelNo            
                        @cStorerkey,            
                        @cLabelNo      OUTPUT,            
                        @bSuccess      OUTPUT,            
                        @nErrNo        OUTPUT,            
                        @cErrMsg       OUTPUT            
         
               IF @bSuccess <> 1            
               BEGIN            
                  SET @nErrNo = 167106            
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get Label Fail       
                  GOTO RollBackTran            
               END            
            END      

             IF EXISTS (SELECT 1           
                        FROM dbo.CartonTrack WITH (NOLOCK)     
                        WHERE LabelNo = @cOrderkey   
                        AND   CarrierName = 'SN')    
            BEGIN    
               SET @cLabelNo=@cTrackingNo    
            END    
      
            -- CartonNo = 0 & LabelLine = '0000', trigger will auto assign            
            INSERT INTO dbo.PackDetail            
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID, UPC)            
            VALUES            
               (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerkey, @cSKU, 1,            
               @cTrackingNo, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(),@cTrackingNo , @cBarcode)           
        
            IF @@ERROR <> 0           
            BEGIN            
               SET @nErrNo = 167107            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins PKDET Fail      
               GOTO RollBackTran            
            END            
         END            
         ELSE            
         BEGIN            
            SET @cLabelNo = ''            
            SET @cLabelLine = ''            
                     
            SELECT TOP 1 @cLabelNo = LabelNo FROM dbo.PackDetail WITH (NOLOCK)             
            WHERE StorerKey = @cStorerkey            
            AND PickSlipNo = @cPickSlipNo            
            AND CartonNo = @nCartonNo            
         
            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)              
            FROM PACKDETAIL WITH (NOLOCK)              
            WHERE StorerKey = @cStorerkey            
            AND PickSlipNo = @cPickSlipNo            
            AND CartonNo = @nCartonNo         
                
            -- need to use the existing labelno            
            INSERT INTO dbo.PackDetail            
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID, UPC)            
            VALUES            
               (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerkey, @cSKU, 1,            
               @cTrackingNo, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cTrackingNo, @cBarcode)            
        
            IF @@ERROR <> 0          
            BEGIN            
               SET @nErrNo = 167108            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins PKDET Fail      
               GOTO RollBackTran            
            END            
         END            
      END        
          
      /****************************          
      PACKINFO          
      ****************************/          
      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)          
      BEGIN          
         INSERT INTO dbo.PackInfo(PickslipNo, CartonNo, CartonType, Refno, AddWho, AddDate, EditWho, EditDate,qty)          
         SELECT DISTINCT PD.PickSlipNo, PD.CartonNo, @cDropIDType, RefNo, sUser_sName(), GETDATE(), sUser_sName(), GETDATE(),PD.qty         
         FROM   PACKHEADER PH WITH (NOLOCK)          
         JOIN   PACKDETAIL PD WITH (NOLOCK) ON (PH.PickslipNo = PD.PickSlipNo)          
         WHERE  PH.Orderkey = @cOrderkey         
         AND    PD.pickslipno= @cPickSlipNo    
          
         IF @@ERROR <> 0          
         BEGIN          
            SET @nErrNo = 167109          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPInfoFail'          
            GOTO RollBackTran          
         END          
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
            SET @nErrNo = 167110        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Ecomm Fail        
            GOTO RollBackTran        
         END        
        
         FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef        
        
      END        
      CLOSE C_ECOMMLOG1        
      DEALLOCATE C_ECOMMLOG1        
      
      DECLARE CUR_UPDCaseID CURSOR LOCAL READ_ONLY FAST_FORWARD FOR       
      SELECT PickDetailKey      
      FROM dbo.PickDetail WITH (NOLOCK)      
      WHERE OrderKey = @cOrderKey      
      AND   SKU = @cSKU      
      AND   CaseID = ''      
      AND  (Status < 5 OR ShipFlag = 'P')       
      OPEN CUR_UPDCaseID      
      FETCH NEXT FROM CUR_UPDCaseID INTO @cPickDetailKey      
      WHILE @@FETCH_STATUS = 0      
      BEGIN      
         UPDATE dbo.PickDetail SET      
            CaseID = @cLabelNo,      
            TrafficCop = NULL       
         WHERE PickDetailKey = @cPickDetailKey      
      
         IF @@ERROR <> 0      
         BEGIN        
            SET @nErrNo = 167111        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Caseid Fail      
            GOTO RollBackTran        
         END       
      
         FETCH NEXT FROM CUR_UPDCaseID INTO @cPickDetailKey      
      END      
      CLOSE CUR_UPDCaseID      
      DEALLOCATE CUR_UPDCaseID      
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
           
         SET @cOrderkeyOUT=@cOrderkey     --(quick fix)  
      END        
      
      /***************************        
      UPDATE rdtECOMMLog        
      ****************************/        
      
      DECLARE C_ECOMMLOG1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
      SELECT RowRef        
      FROM rdt.rdtEcommLog WITH (NOLOCK)        
      WHERE SKU         = @cSKU        
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
            SET @nErrNo = 167115        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'        
            GOTO RollBackTran        
         END        
        
         FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef        
        
      END        
      CLOSE C_ECOMMLOG1        
      DEALLOCATE C_ECOMMLOG1       
        
      --(cc01)   
      EXEC RDT.rdt_STD_EventLog      
         @cActionType   = '3',       
         @cUserID       = @cUserName,      
         @nMobileNo     = @nMobile,      
         @nFunctionID   = @nFunc,      
         @cFacility     = @cFacility,      
         @cStorerKey    = @cStorerKey,      
         @cSKU          = @cSKU,     
         @cPickSlipNo   = @cPickSlipNo,          
         @cDropID       = @cDropID,  
         @cOrderKey     = @cOrderkey  
   END        
    
   IF @nStep = 6    
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         -- (james03)
         IF @cUseUdf04AsTrackNo = '1'
            UPDATE dbo.Orders SET   
               UserDefine04 = @cTrackNo,
               EditWho = @cUserName,  
               EditDate = GETDATE()  
            WHERE OrderKey = @cOrderkey  
         ELSE         
            UPDATE dbo.Orders SET   
               TrackingNo = @cTrackNo,
               EditWho = @cUserName,  
               EditDate = GETDATE()  
            WHERE OrderKey = @cOrderkey  
  
         IF @@ERROR <> 0  
            GOTO RollBackTran  
      END  
   END  
  
   IF (@nStep='7')    
   BEGIN    
    
      IF ISNULL( @cPickSlipno ,'') = ''        
      BEGIN        
         SELECT @cPickslipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderkey      
      END    
    
      IF EXISTS (SELECT 1 FROM PACKINFO (NOLOCK) WHERE PICKSLIPNO=@cPickslipNo)    
      BEGIN    
    
         DECLARE @nLength FLOAT,    
                 @nWidth FLOAT,    
                 @nHeight FLOAT    
    
         SELECT @nWeight=STDGROSSWGT    
         FROM sku (NOLOCK)     
         WHERE sku =@cSKU     
    
         SELECT @nLength=CartonLength,    
                @nCube =Cube,    
                @nWidth=CartonWidth,    
                @nHeight=CartonHeight    
         FROM cartonization (NOLOCK)    
         WHERE cartontype=@cCartonType    
    
    
         select @cTrackingNo=trackingno    
         from cartontrack (nolock)     
         where labelno =@cOrderkey    
    
         UPDATE PACKINFO WITH(ROWLOCK)    
         SET CARTONTYPE=@cCartonType,    
             Weight=@nWeight,    
             CUBE=@nCube,    
             Length=@nLength,    
             Height=@nHeight,    
             Width=@nWidth,    
             QTY ='1',    
             RefNo=@cTrackingNo    
         WHERE PICKSLIPNO=@cPickslipNo    
    
         IF @@ERROR <> 0        
         BEGIN        
            SET @nErrNo = 167116       
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackInfoFail'        
            GOTO RollBackTran           
      END   
           
         UPDATE dbo.PackHeader SET   
            CtnTyp1 = @cCartonType,   
            EditWho = @cUserName,   
            EditDate = GETDATE()  
         WHERE PickSlipNo = @cPickslipNo  
           
         IF @@ERROR <> 0  
            GOTO RollBackTran  
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
            SET @nErrNo = 167112    
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
               SET @nErrNo = 167113    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- AutoMBOLPack         
               GOTO RollBackTran      
            END       
         END    
              
         SET @cTrackNoFlag = '1'        
           
         SET @cOrderkeyOUT=@cOrderkey     --(quick fix)  
      
         UPDATE dbo.PackHeader WITH (ROWLOCK)       
            SET Status = '9'     
         WHERE PickSlipNo = @cPickSlipNo       
                 
         IF @@ERROR <> 0       
         BEGIN      
            SET @nErrNo = 167114        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Pack Cfm Fail'        
            GOTO RollBackTran        
         END      
      END        
           
      SET @cTrackNoFlag = '1'  
   END    
    
     
   GOTO QUIT     
         
RollBackTran:              
   ROLLBACK TRAN rdt_841ExtUpdSP16 -- Only rollback change made here              
              
Quit:              
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started              
      COMMIT TRAN rdt_841ExtUpdSP16            
                
END           

GO