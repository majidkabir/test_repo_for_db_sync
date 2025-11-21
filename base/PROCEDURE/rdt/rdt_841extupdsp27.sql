SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/              
/* Store procedure: rdt_841ExtUpdSP27                                   */              
/* Copyright      : LF                                                  */              
/*                                                                      */              
/* Purpose: Ecomm Update SP                                             */              
/*                                                                      */              
/* Modifications log:                                                   */              
/* Date        Rev  Author    Purposes                                  */              
/* 2022-07-12  1.0  James     WMS-20110. Created (dup rdt_841ExtUpdSP22)*/      
/* 2022-09-06  1.1  James     LIT request to use running no instead of  */  
/*                            tracking no as label no (james01)         */  
/* 2022-12-29  1.2  James     WMS-21433 Only shipperkey = KERRY can     */
/*                            print kerry label (james02)               */
/************************************************************************/              
            
CREATE   PROC [RDT].[rdt_841ExtUpdSP27] (              
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
                
   DECLARE @cAPP_DB_Name         NVARCHAR( 20) = ''        
   DECLARE @cDataStream          VARCHAR( 10)  = ''        
   DECLARE @nThreadPerAcct       INT = 0        
   DECLARE @nThreadPerStream     INT = 0        
   DECLARE @nMilisecondDelay     INT = 0        
   DECLARE @cIP                  NVARCHAR( 20) = ''        
   DECLARE @cPORT                NVARCHAR( 5)  = ''        
   DECLARE @cPORT2               NVARCHAR( 5)  = ''        
   DECLARE @cIniFilePath         NVARCHAR( 200)= ''        
   DECLARE @cCmdType             NVARCHAR( 10) = ''        
   DECLARE @cTaskType            NVARCHAR( 1)  = ''            
   DECLARE @cOrderLineNumber     NVARCHAR( 5)  = ''      
   DECLARE @nContinue            INT = 0      
   DECLARE @cCommand             NVARCHAR( 1000) = ''      
   DECLARE @nMinCartonNo         INT        
   DECLARE @nMaxCartonNo         INT        
   DECLARE @nUpdTrackNo          INT = 0  
     
   DECLARE @tOutBoundList     VariableTable                        
   DECLARE @tOutBoundList2    VariableTable         
   DECLARE @tShipLabel        VariableTable       
   DECLARE @tShippLabel       VariableTable  
         
   SET @cAssignPackLabelToOrd = rdt.RDTGetConfig( @nFunc, 'AssignPackLabelToOrd', @cStorerKey)        
         
             
   SET @nTranCount = @@TRANCOUNT          
   BEGIN TRAN            
   SAVE TRAN rdt_841ExtUpdSP27            
          
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
          SET @nErrNo = 188217        
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
            SET @nErrNo = 188218        
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
         SET @nErrNo = 188219        
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
               SET @nErrNo = 188201              
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
               SET @nErrNo = 188202              
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
            SET @nErrNo = 188203              
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
            SET @nErrNo = 188204                  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackHDRFail                  
            GOTO RollBackTran                  
         END                  
      END             
      
      --SELECT @cTrackingNo = TrackingNo          
      --FROM dbo.Orders WITH (NOLOCK)          
      --WHERE OrderKey = @cOrderkey          
          
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
         SET @nErrNo = 188220                  
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
            SET @nErrNo = 188205                  
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
                  SET @nErrNo = 188206                  
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
               SET @nErrNo = 188207                  
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
               SET @nErrNo = 188208                  
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
         INSERT INTO dbo.PackInfo(PickslipNo, CartonNo, CartonType, Refno, AddWho, AddDate, EditWho, EditDate,qty, Weight)                
         SELECT DISTINCT PD.PickSlipNo, PD.CartonNo, @cDropIDType, RefNo, sUser_sName(), GETDATE(), sUser_sName(), GETDATE(),PD.qty, @fWeight              
         FROM   PACKHEADER PH WITH (NOLOCK)                
         JOIN   PACKDETAIL PD WITH (NOLOCK) ON (PH.PickslipNo = PD.PickSlipNo)                
         WHERE  PH.Orderkey = @cOrderkey               
         AND    PD.pickslipno= @cPickSlipNo          
                
         IF @@ERROR <> 0                
         BEGIN                
        SET @nErrNo = 188209                
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
            SET @nErrNo = 188210              
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
       --DECLARE CUR_UPDCaseID CURSOR LOCAL READ_ONLY FAST_FORWARD FOR             
       --  SELECT PickDetailKey            
       --  FROM dbo.PickDetail WITH (NOLOCK)            
       --  WHERE OrderKey = @cOrderKey            
       --  AND   SKU = @cSKU            
       --  AND   CaseID = ''            
       --  AND  (Status < 5 OR ShipFlag = 'P')             
       --  OPEN CUR_UPDCaseID            
       --  FETCH NEXT FROM CUR_UPDCaseID INTO @cPickDetailKey            
       --  WHILE @@FETCH_STATUS = 0            
       --  BEGIN            
       --     UPDATE dbo.PickDetail SET            
       --        CaseID = @cLabelNo,            
       --        TrafficCop = NULL             
       --     WHERE PickDetailKey = @cPickDetailKey            
            
       --     IF @@ERROR <> 0            
       --     BEGIN              
       --        SET @nErrNo = 188211              
       --        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Caseid Fail            
       --        GOTO RollBackTran              
       --     END             
      
       --     FETCH NEXT FROM CUR_UPDCaseID INTO @cPickDetailKey            
       --  END            
       --  CLOSE CUR_UPDCaseID            
       --  DEALLOCATE CUR_UPDCaseID          
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
                 
         SET @cOrderkeyOUT=@cOrderkey     --(quick fix)        
      END              
            
      --INSERT INTO traceInfo (TraceName,Col1,Col2,Col3,Col4,TimeIn)      
      -- VALUES ('cc841ext19',@nTotalPickQty,@nTotalPackQty, @cTrackNoFlag,@cOrderKey,GETDATE())      
            
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
            SET @nErrNo = 188215              
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
         SELECT @cOrderkey   = MIN(RTRIM(ISNULL(ECOMM.Orderkey,'')))        
         FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)        
         WHERE ECOMM.ToteNo = @cDropID        
         AND   ECOMM.Sku = @cSKU        
         AND   ECOMM.AddWho = @cUserName        
         AND   Ecomm.status = '9'      
         AND   (ECOMM.batchKey = '' OR ECOMM.batchKey = '1')      
         --AND   ECOMM.Status      < '5'        
               
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
                  
         UPDATE rdt.rdtECOMMLog SET      
            batchKey = @cTrackNo      
         WHERE ToteNo = @cDropID        
         AND   Sku = @cSKU        
         AND   AddWho = @cUserName        
         AND   status = '9'      
         AND   (batchKey = '' OR batchKey = '1')      
                  
      --   /***************************              
      --UPDATE rdtECOMMLog              
      --****************************/              
            
      --DECLARE C_ECOMMLOG1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
      --SELECT RowRef              
      --FROM rdt.rdtEcommLog WITH (NOLOCK)              
      --WHERE SKU         = @cSKU              
      --AND   Orderkey    = @cOrderkey              
      --AND   AddWho      = @cUserName              
      --AND   Status      < '5'              
      --AND   ScannedQty  >= ExpectedQty              
              
      --OPEN C_ECOMMLOG1              
      --FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef              
      --WHILE (@@FETCH_STATUS <> -1)              
      --BEGIN              
              
      --   /****************************              
      --      rdtECOMMLog              
      --   ****************************/              
      --   --update rdtECOMMLog              
      --   UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)              
      --   SET   Status      = '9'    -- completed              
      --   WHERE RowRef = @nRowRef              
              
      --   IF @@ERROR <> 0              
      --   BEGIN              
      --      SET @nErrNo = 188215              
      --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'              
      --      GOTO RollBackTran              
      --   END              
              
      --   FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef              
              
      --END              
      --CLOSE C_ECOMMLOG1              
      --DEALLOCATE C_ECOMMLOG1             
                  
      END        
   END        
        
   IF @nStep=7        
   BEGIN          
     SELECT @cWeight = Value FROM @tExtUpd WHERE Variable = '@cWeight'      
      --INSERT INTO traceInfo (TraceName,Col1)      
      --VALUES ('cc841ExpUpSt7',@cWeight)      
      --GOTO QUit      
        
      SET @cWeight = ISNULL(@cWeight,0)      
       
      SET @fWeight = CAST( @cWeight AS FLOAT)        
          
      IF ISNULL( @cPrevOrderkey, '') = ''          
         --target the correct orderKey      
         SELECT @cOrderKey   = MIN(RTRIM(ISNULL(Orderkey,'')))        
         FROM rdt.rdtECOMMLog WITH (NOLOCK)        
         WHERE ToteNo = @cDropID        
         AND   Sku = @cSKU        
         AND   AddWho = @cUserName        
         AND   STATUS = '9'      
         AND   batchKey = ''      
      ELSE    
         SET @cOrderKey = @cPrevOrderkey    
             
      SET @nCartonNo = 1            
          
      IF ISNULL( @cPickSlipno ,'') = ''              
      BEGIN              
         SELECT @cPickslipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderkey            
      END          
          
      IF EXISTS (SELECT 1 FROM PACKINFO (NOLOCK) WHERE PICKSLIPNO=@cPickslipNo)          
      BEGIN          
          
         DECLARE @nLength FLOAT,          
                 @nWidth FLOAT,          
                 @nHeight FLOAT          
                       
         IF @fWeight = 0      
         BEGIN      
          SELECT @fWeight=STDGROSSWGT          
            FROM sku (NOLOCK)           
            WHERE sku =@cSKU         
         END      
                 
         SELECT @nLength=CartonLength,          
                @nCube =Cube,          
                @nWidth=CartonWidth,          
                @nHeight=CartonHeight          
         FROM cartonization (NOLOCK)          
         WHERE cartontype=@cCartonType          
          
          
         select @cTrackingNo=trackingno          
         from cartontrack (nolock)           
         where labelno =@cOrderkey          
  
       SELECT   
          @cShipperKey = ShipperKey,   
          @cSOStatus = SOStatus  
       FROM dbo.ORDERS WITH (NOLOCK)  
       WHERE OrderKey = @cOrderKey  
  
         IF @cSOStatus = 'PENDCANC'  
         BEGIN              
            SET @nErrNo = 188221             
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PENDCANC'              
            GOTO RollBackTran                 
         END   
           
         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)  
                     WHERE LISTNAME = 'PMADDTRK'  
                     AND   Code = @cShipperKey)  
          SET @nUpdTrackNo = 1  
            
         UPDATE PACKINFO WITH(ROWLOCK)          
         SET CARTONTYPE=@cCartonType,          
             Weight=@fWeight,          
             CUBE=@nCube,          
             Length=@nLength,          
             Height=@nHeight,          
             Width=@nWidth,          
             QTY ='1',          
             RefNo=@cTrackingNo,  
             TrackingNo = CASE WHEN @nUpdTrackNo = 0 THEN TrackingNo ELSE @cTrackingNo END          
         WHERE PICKSLIPNO=@cPickslipNo          
          
         IF @@ERROR <> 0              
         BEGIN              
            SET @nErrNo = 188216             
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
      SELECT @nTotalPackQty = SUM(Qty)    
      FROM dbo.PackDetail WITH (NOLOCK)     
      WHERE PickSlipNo = @cPickslipNo    
          
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
            SET @nErrNo = 188212          
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
               SET @nErrNo = 188213          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- AutoMBOLPack               
               GOTO RollBackTran            
            END             
         END          
                    
         SET @cTrackNoFlag = '1'              
                 
         SET @cOrderkeyOUT=@cOrderkey     --(quick fix)        
               
         SELECT       
            @cOrderRefNo = ExternOrderkey,  
            @dOrderDate = OrderDate, 
            @cShipperKey = ShipperKey       
         FROM Orders WITH (NOLOCK)       
         WHERE OrderKey = @cOrderkey        
  
         UPDATE dbo.PackHeader WITH (ROWLOCK) SET             
            Status = '9',      
            OrderRefNo = @cOrderRefNo           
         WHERE PickSlipNo = @cPickSlipNo             
                       
         IF @@ERROR <> 0             
         BEGIN            
            SET @nErrNo = 188214              
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Pack Cfm Fail'              
            GOTO RollBackTran              
         END            
               
         SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'SHIPLABEL', @cStorerkey)          
         IF @cShipLabel = '0'          
            SET @cShipLabel = ''          
        
         IF @cShipLabel <> '' AND @cShipperKey = 'KERRY' -- (james02)       
         BEGIN        
            SET @cFileName = 'LBL_' + RTRIM( @cOrderRefNo) + '_' +   
                              RTRIM( @cTrackingNo) + '_' +  
                            CONVERT( VARCHAR( 8), @dOrderDate, 112) + '_1' + '.pdf'  
  
            INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cStorerKey',   @cStorerKey)          
            INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)        
            INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@nCartonNo',    @nCartonNo)        
                   
            -- Print label          
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',           
               @cShipLabel, -- Report type          
               @tShipLabel, -- Report params          
               'rdt_841ExtUpdSP27',           
               @nErrNo  OUTPUT,          
               @cErrMsg OUTPUT,   
               NULL,   
               '',   
               @cFileName              
         END       
  
         SET @cShippLabel = rdt.RDTGetConfig( @nFunc, 'SHIPPLABEL', @cStorerkey)          
         IF @cShippLabel = '0'          
            SET @cShippLabel = ''          
  
         IF @cShippLabel <> ''        
         BEGIN        
            INSERT INTO @tShippLabel (Variable, Value) VALUES ( '@cStorerKey',   @cStorerKey)          
            INSERT INTO @tShippLabel (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)        
            INSERT INTO @tShippLabel (Variable, Value) VALUES ( '@nCartonNo',    @nCartonNo)        
                   
            -- Print label          
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,           
               @cShippLabel, -- Report type          
               @tShippLabel, -- Report params          
               'rdt_841ExtUpdSP27',           
               @nErrNo  OUTPUT,          
               @cErrMsg OUTPUT,   
               NULL,   
               ''  
         END       
           
         SET @cShipOrdAfterPackCfm = rdt.RDTGetConfig( @nFunc, 'ShipOrdAfterPackCfm', @cStorerKey)      
               
         IF EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND [Status] = '9')      
         BEGIN      
            IF @cShipOrdAfterPackCfm = '1'      
            BEGIN      
               SELECT @cMBOLKey = MBOLKey      
               FROM dbo.ORDERS WITH (NOLOCK)      
               WHERE OrderKey = @cOrderKey      
         
               IF ISNULL( @cMBOLKey, '') = ''      
               BEGIN      
                  SET @nErrNo = 176403      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No MBOLKEY'      
                  GOTO RollBackTran      
               END      
               SELECT         
                  @nMinCartonNo = MIN( CartonNo),        
                  @nMaxCartonNo = MAX( CartonNo)        
               FROM dbo.PackDetail WITH (NOLOCK)        
               WHERE PickSlipNo = @cPickSlipNo       
                     
               SET @nErrNo = 0        
               EXEC [dbo].[isp_PrintCartonLabel_Interface]              
                            @c_Pickslipno   = @cPickSlipNo                 
                        ,   @n_CartonNo_Min = @nMaxCartonNo    -- set 2 values same as iml only need 1 carton no                  
                        ,   @n_CartonNo_Max = @nMaxCartonNo            
                        ,   @b_Success      = @bSuccess OUTPUT            
                        ,   @n_Err          = @nErrNo   OUTPUT            
                        ,   @c_ErrMsg       = @cErrMsg  OUTPUT         
                              
               IF @nErrNo <> 0      
                  GOTO RollBackTran      
            END      
         END      
      END              
                 
      SET @cTrackNoFlag = '1'        
            
      UPDATE  rdt.rdtECOMMLog WITH (ROWLOCK)  SET      
         batchKey = '1'      
      WHERE ToteNo = @cDropID        
      AND   Sku = @cSKU        
      AND   AddWho = @cUserName        
      AND   STATUS = '9'      
      AND   batchKey = ''      
   END          
          
           
   GOTO QUIT           
               
RollBackTran:                    
   ROLLBACK TRAN rdt_841ExtUpdSP27 -- Only rollback change made here                    
                    
Quit:                    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started                    
      COMMIT TRAN rdt_841ExtUpdSP27                  
            
                   
END                 

GO