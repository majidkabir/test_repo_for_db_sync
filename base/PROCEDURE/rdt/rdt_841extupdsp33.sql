SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/              
/* Store procedure: rdt_841ExtUpdSP33                                   */              
/* Copyright      : LF                                                  */              
/*                                                                      */              
/* Purpose: Ecomm Update SP                                             */              
/*                                                                      */              
/* Modifications log:                                                   */              
/* Date        Rev  Author    Purposes                                  */              
/* 2023-03-07  1.0  yeekung   WMS-21863. Created (dup rdt_841ExtUpdSP27)*/      
/************************************************************************/              
            
CREATE   PROC [RDT].[rdt_841ExtUpdSP33] (              
   @nMobile       INT,              
   @nFunc         INT,              
   @cLangCode     NVARCHAR( 3),              
   @cUserName     NVARCHAR( 18),              
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
   @cCartonType   NVARCHAR( 20) = '',               
   @cSerialNo     NVARCHAR( 30) = '',       
   @nSerialQTY    INT = 0,      
   @tExtUpd       VariableTable READONLY       
) AS              
BEGIN              
   SET NOCOUNT ON              
   SET ANSI_NULLS OFF              
   SET QUOTED_IDENTIFIER OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF             
             
      DECLARE       
         @nTranCount        INT              
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
          ,@cPrinter          NVARCHAR(10)               
          ,@cLoadKey          NVARCHAR(10)              
          ,@cPaperPrinter     NVARCHAR(10)              
          ,@cDataWindow       NVARCHAR(50)              
          ,@cTargetDB         NVARCHAR(20)              
          ,@cOrderType        NVARCHAR(10)              
          ,@cShipperKey       NVARCHAR(10)              
          ,@cSOStatus         NVARCHAR(10)              
          ,@cGenPackDetail    NVARCHAR(1)              
          ,@cShowTrackNoScn   NVARCHAR(1)      
          ,@cCheckPaperType   NVARCHAR(1)      
          ,@cPaperType        NVARCHAR(10)                  
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
          ,@cAutoMBOLPack     NVARCHAR( 1)         
          ,@fWeight           FLOAT         
          ,@nCube             FLOAT          
          ,@cTrackingNo       NVARCHAR( 20)        
          ,@cShipLabel        NVARCHAR( 10)        
          ,@cWeight           NVARCHAR( 10)      
          ,@cOrderkey         NVARCHAR( 10)      
          ,@cOrderRefNo       NVARCHAR( 18)      
          ,@cMBOLKey          NVARCHAR( 10)      
          ,@cUseUdf04AsTrackNo      NVARCHAR( 1)         
          ,@cShipOrdAfterPackCfm    NVARCHAR( 1)      
          ,@cAssignPackLabelToOrd   NVARCHAR( 1)        
          ,@cFileName         NVARCHAR( 50)  
          ,@dOrderDate        DATETIME  
          ,@cShippLabel       NVARCHAR( 10)
          ,@cPackList         NVARCHAR(10)
          ,@cReportType       NVARCHAR(10)
          ,@cPrinter02        NVARCHAR(10)
          ,@cBrand01          NVARCHAR(10)
          ,@cBrand02          NVARCHAR(10)
          ,@cPrinter01        NVARCHAR(10)
          ,@cSectionKey       NVARCHAR(10)
                    
     
   DECLARE @tPackList         VariableTable                         
   DECLARE @tShippLabel       VariableTable  



   SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PackList', @cStorerkey)

   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
   IF @cShipLabel = '0'
      SET @cShipLabel = ''
         
   SET @cAssignPackLabelToOrd = rdt.RDTGetConfig( @nFunc, 'AssignPackLabelToOrd', @cStorerKey)        
         
             
   SET @nTranCount = @@TRANCOUNT          
   BEGIN TRAN            
   SAVE TRAN rdt_841ExtUpdSP33            
          
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
      SET @nCartonNo = 1             
            
      -- check if sku exists in tote        
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)        
                      WHERE ToteNo = @cDropID        
                      AND SKU = @cSKU        
                      AND AddWho = @cUserName        
                      AND Status IN ('0', '1') )        
      BEGIN        
          SET @nErrNo = 197601        
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
         FROM rdt.rdtECOMMLog E WITH (NOLOCK)        
         WHERE ToteNo = @cDropID        
         AND   Status IN ('0', '1')        
         AND   Sku = @cSKU        
         AND   AddWho = @cUserName        
         AND   NOT EXISTS ( SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)  
                            WHERE E.Orderkey = PD.OrderKey  
                            AND   PD.[Status] = '5')  
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
            SET @nErrNo = 197602        
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
         SET @nErrNo = 197603        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QtyExceeded        
         GOTO RollBackTran        
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
               SET @nErrNo = 197604              
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
               SET @nErrNo = 197605              
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
            SET @nErrNo = 197606              
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
            SET @nErrNo = 197607                  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackHDRFail                  
            GOTO RollBackTran                  
         END                  
      END             
      
      SELECT @cTrackingNo = TrackingNo,
             @cLoadkey = Loadkey,
             @cShipperKey = shipperkey
      FROM dbo.Orders WITH (NOLOCK)          
      WHERE OrderKey = @cOrderkey          
          
      SET @nTotalPickQty = 0              
      SELECT @nTotalPickQty = SUM(PD.QTY)              
      FROM PICKDETAIL PD WITH (NOLOCK)              
      WHERE PD.ORDERKEY = @cOrderKey              
      AND PD.Storerkey = @cStorerkey                 
                  
      SET @nTotalPackQty = 0              
      SELECT @nTotalPackQty = SUM(Qty)    
      FROM dbo.PackDetail WITH (NOLOCK)     
      WHERE PickSlipNo = @cPickslipNo    
          
      IF @nTotalPackQty >= @nTotalPickQty    
      BEGIN                  
         SET @nErrNo = 197608                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Packed                  
         GOTO RollBackTran                  
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
            --Refno=@cTrackingNo,          
            --dropid=@cTrackingNo,          
            EditDate = GETDATE(),                  
            EditWho = 'rdt.' + sUser_sName()              
         WHERE StorerKey = @cStorerkey                  
         AND PickSlipNo = @cPickSlipNo                  
         AND CartonNo = @nCartonNo                  
         AND SKU = @cSKU                  
         AND UPC = @cBarcode              
                        
         IF @@ERROR <> 0                  
         BEGIN                  
            SET @nErrNo = 197609                  
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
            
            SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo', @cStorerkey)             
            IF @cGenLabelNo_SP = '0'            
               SET @cGenLabelNo_SP = ''       
               
            IF @cGenLabelNo_SP <>''
            BEGIN

               SET @cExecStatements = N'EXEC dbo.' + RTRIM( @cGenLabelNo_SP) +
                                       ' @cPickslipNo           ' +
                                       ' , @nCartonNo             ' +
                                       ' , @cLabelNo     OUTPUT   '


               SET @cExecArguments =
                         N' @cPickslipNo    NVARCHAR(10)          ' +
                          ' , @nCartonNo    INT'                    +
                          ' , @cLabelNo     NVARCHAR(20)   OUTPUT'



               EXEC sp_executesql @cExecStatements, @cExecArguments,
                                    @cPickslipNo
                                  , @nCartonNo
                                  , @cLabelNo      OUTPUT
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
                  SET @nErrNo = 197610                  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get Label Fail             
                  GOTO RollBackTran                  
               END                  
            END            
      
            --SET @cLabelNo=@cTrackingNo          
            
            -- CartonNo = 0 & LabelLine = '0000', trigger will auto assign                  
            INSERT INTO dbo.PackDetail                  
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID, UPC)                  
            VALUES                  
               (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerkey, @cSKU, 1,                  
               @cLabelNo, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(),@cLabelNo , @cBarcode)                 
              
            IF @@ERROR <> 0                 
            BEGIN                  
               SET @nErrNo = 197611                  
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
               @cLabelNo, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cLabelNo, @cBarcode)                  
              
            IF @@ERROR <> 0                
            BEGIN                  
               SET @nErrNo = 197612                  
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
         INSERT INTO dbo.PackInfo(PickslipNo, CartonNo, CartonType, Refno, AddWho, AddDate, EditWho, EditDate,qty, Weight,trackingno)                
         SELECT DISTINCT PD.PickSlipNo, PD.CartonNo, @cDropIDType, RefNo, sUser_sName(), GETDATE(), sUser_sName(), GETDATE(),PD.qty, @fWeight,@cTrackingno              
         FROM   PACKHEADER PH WITH (NOLOCK)                
         JOIN   PACKDETAIL PD WITH (NOLOCK) ON (PH.PickslipNo = PD.PickSlipNo)                
         WHERE  PH.Orderkey = @cOrderkey               
         AND    PD.pickslipno= @cPickSlipNo          
                
         IF @@ERROR <> 0                
         BEGIN                
        SET @nErrNo = 197613                
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
            SET @nErrNo = 197614              
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Ecomm Fail              
            GOTO RollBackTran              
         END              
              
         FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef              
              
      END              
      CLOSE C_ECOMMLOG1              
      DEALLOCATE C_ECOMMLOG1              
            
      IF @cAssignPackLabelToOrd = '1'       
      BEGIN      
       -- Update packdetail.labelno = pickdetail.caseid        
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
      END      
             
             
      SET @nTotalPickQty = 0              
      SELECT @nTotalPickQty = SUM(PD.QTY)              
      FROM PICKDETAIL PD WITH (NOLOCK)              
      WHERE PD.ORDERKEY = @cOrderKey              
      AND PD.Storerkey = @cStorerkey                 
                  
      SET @nTotalPackQty = 0              
      SELECT @nTotalPackQty = SUM(Qty)    
      FROM dbo.PackDetail WITH (NOLOCK)     
      WHERE PickSlipNo = @cPickslipNo             
            
             
        
      IF @nTotalPickQty = @nTotalPackQty              
      BEGIN    
      
         UPDATE dbo.PackHeader WITH (ROWLOCK) SET             
            Status = '9'         
         WHERE PickSlipNo = @cPickSlipNo
               AND StorerKey = @cStorerKey        
                       
         IF @@ERROR <> 0             
         BEGIN            
            SET @nErrNo = 197615              
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Pack Cfm Fail'              
            GOTO RollBackTran              
         END            
      
         -- Print Label via BarTender --
         SET @cRDTBartenderSP = ''
         SET @cRDTBartenderSP = rdt.RDTGetConfig( @nFunc, 'RDTBartenderSP', @cStorerkey)
         IF @cRDTBartenderSP = '0'
            SET @cRDTBartenderSP = ''
         SET @cTrackNoFlag = '1' 
         
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
            IF @cShipLabel <> ''
            BEGIN
               SELECT TOP 1 @nCartonNo = CartonNo
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               AND   DropID = @cDropID
               ORDER BY 1

               SET @nErrNo = 0
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',       @cOrderKey)
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cLoadkey',   @cLoadkey)
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cShipperkey',     @cShipperkey)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerkey, @cLabelPrinter, '',
                  @cShipLabel, -- Report type
                  @tSHIPPLABEL, -- Report params
                  'rdt_841ExtUpdSP33',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO RollBackTran
               END
            END
         END

            
         SET @cShipperKey = ''
         SET @cOrderType = ''

         SELECT @cShipperKey = ShipperKey
               ,@cOrderType  = Type
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
               SET @nErrNo = 197616
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
         
         IF @cPaperPrinter <> 'PDF' AND @cPackList <> ''
         BEGIN

            SET @nErrNo = 0
            INSERT INTO @tPackList (Variable, Value) VALUES ( '@cPickslipNo', @cPickslipNo)
            INSERT INTO @tPackList (Variable, Value) VALUES ( '@cOrderKey',   @cOrderkey)
            INSERT INTO @tPackList (Variable, Value) VALUES ( '@cLabelNo',   @cLabelNo)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerkey,'', @cPaperPrinter,
               @cPackList, -- Report type
               @tPackList, -- Report params
               'rdt_841ExtUpdSP33',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT 
         END

         SET @nTotalPickQty = 0
         SET @cOrderKeyOut = @cOrderkey

         SET @cTrackNoFlag = '1'
                
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
            SET @nErrNo = 197617              
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'              
            GOTO RollBackTran              
         END              
              
         FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef              
              
      END              
      CLOSE C_ECOMMLOG1              
      DEALLOCATE C_ECOMMLOG1             
   
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
           
   GOTO QUIT           
               
RollBackTran:                    
   ROLLBACK TRAN rdt_841ExtUpdSP33 -- Only rollback change made here                    
                    
Quit:                    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started                    
      COMMIT TRAN rdt_841ExtUpdSP33                  
            
                   
END                 

GO