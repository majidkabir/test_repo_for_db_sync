SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/  
/* Store procedure: rdt_855ExtUpd01                                        */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date        Rev  Author      Purposes                                   */  
/* 08-Mar-2017 1.0  James       WMS1219. Created                           */  
/* 28-Jul-2017 1.1  James       WMS2562. Check pickdetail status based     */  
/*                              on storerconfig (james01)                  */  
/* 29-Nov-2017 1.2  James       Remove packinglist printed scn (james02)   */  
/* 30-Jul-2018 1.3  James       Perf tuning (james03)                      */    
/* 07-Nov-2018 1.4  James       INC0459184 - Filter func id when           */    
/*                              retrieve datawindow (james04)              */    
/* 15-Aug-2018 1.5  Ung         WMS-6022 Add pack confirm for conso        */  
/* 19-Nov-2018 1.6  Ung         WMS-6932 Add ID param                      */  
/* 29-Mar-2019 1.7  James       WMS-8002 Add TaskDetailKey param (james05) */  
/* 03-Jul-2019 1.8  Ung         Fix runtime error when ESC                 */  
/* 06-Jul-2021 1.9  YeeKung     WMS-17278 Add Reasonkey (yeekung01)        */
/* 26-Aug-2021 2.0  James       WMS-17703 Add ORDSKULBL printing (james06) */  
/*                              Add rdtReportToPrinter function            */  
/***************************************************************************/  
  
CREATE   PROC [RDT].[rdt_855ExtUpd01] (  
   @nMobile      INT,   
   @nFunc        INT,   
   @cLangCode    NVARCHAR( 3),   
   @nStep        INT,   
   @nInputKey    INT,   
   @cStorerKey   NVARCHAR( 15),    
   @cRefNo       NVARCHAR( 10),   
   @cPickSlipNo  NVARCHAR( 10),   
   @cLoadKey     NVARCHAR( 10),   
   @cOrderKey    NVARCHAR( 10),   
   @cDropID      NVARCHAR( 20),   
   @cSKU         NVARCHAR( 20),    
   @nQty         INT,    
   @cOption      NVARCHAR( 1),    
   @nErrNo       INT           OUTPUT,    
   @cErrMsg      NVARCHAR( 20) OUTPUT,   
   @cID          NVARCHAR( 18) = '',  
   @cTaskDetailKey   NVARCHAR( 10) = '',
   @cReasonCode  NVARCHAR(20) OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nTranCount       INT,  
           @cCaseID           NVARCHAR( 20),  
           @cLastCarton       NVARCHAR( 1),  
           @cCartonNo         NVARCHAR( 10),  
           @cWeight           NVARCHAR( 10),  
           @cCube             NVARCHAR( 10),  
           @cCartonType       NVARCHAR( 10),  
           @cLabelPrinter     NVARCHAR( 10),  
           @cPaperPrinter     NVARCHAR( 10),  
           @cDataWindow       NVARCHAR( 50),  
           @cTargetDB         NVARCHAR( 20),  
           @cPickDetailKey    NVARCHAR( 10),  
           @cUserName         NVARCHAR( 18),  
           @cLabelNo          NVARCHAR( 20),  
           @cLabelLine        NVARCHAR( 5),  
           @nCartonNo         INT,  
           @nPPA_QTY          INT,  
           @nPD_QTY           INT,  
           @nPAD_QTY          INT,  
           @nExpectedQty      INT,  
           @nPackedQty        INT,  
           @cPickConfirmStatus   NVARCHAR( 1),  
           @cSkipChkPSlipMustScanOut NVARCHAR( 1),  
           @cOrdSkuLbl        NVARCHAR( 10),  
           @tOrdSkuLbl        VARIABLETABLE,  
           @cLabelPrinter1    NVARCHAR( 10),  
           @cLabelPrinter2    NVARCHAR( 10)  
     
   DECLARE @fWeight        FLOAT  
   DECLARE @fCube          FLOAT  
  
   SET @cPickConfirmStatus = rdt.rdtGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
   SET @cSkipChkPSlipMustScanOut = rdt.rdtGetConfig( @nFunc, 'SkipChkPSlipMustScanOut', @cStorerKey)  
   -- Check scan-out, PickDetail.Status must = 5  
   IF @cSkipChkPSlipMustScanOut = '0'  
      SET @cPickConfirmStatus = '5'  
  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_855ExtUpd01 -- For rollback or commit only our own transaction  
  
   IF @nFunc = 855  
   BEGIN  
      IF @nStep = 3  
      BEGIN  
         IF @nInputKey = 1 -- ENTER        
         BEGIN  
            SELECT @cUserName = UserName,  
                   @cLabelPrinter = Printer,  
                   @cPaperPrinter = Printer_Paper  
             FROM RDT.RDTMobRec WITH (NOLOCK)   
             WHERE Mobile = @nMobile  
  
            /*-------------------------------------------------------------------------------  
  
                                           Orders, PickDetail  
  
            -------------------------------------------------------------------------------*/  
            -- Get PPA QTY  
            SELECT @nPPA_QTY = ISNULL( SUM( CQTY), 0)  
            FROM rdt.rdtPPA WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
               AND DropID = @cDropID  
               AND SKU = @cSKU  
  
            -- Get Pickdetail QTY  
            SELECT @nPD_QTY = ISNULL( SUM( QTY), 0)  
            FROM dbo.PickDetail WITH (NOLOCK)   
            WHERE CaseID = @cDropID  
            AND   StorerKey = @cStorerKey  
            AND   SKU = @cSKU  
            AND   [Status] >= @cPickConfirmStatus  
            AND   [Status] < '9'  
  
            IF @nPPA_QTY > @nPD_QTY  
               GOTO Quit  
  
            -- Get Orders info  
            SELECT TOP 1 @cOrderKey = OrderKey,   
                         @cPickDetailKey = PickDetailKey,  
                         @cPickSlipNo = PickSlipNo   
                         --@cSKU = SKU  
            FROM dbo.PickDetail WITH (NOLOCK)   
            WHERE CaseID = @cDropID  
            AND   StorerKey = @cStorerKey  
  
            IF ISNULL( @cPickSlipNo, '') = ''  
            BEGIN  
               SET @nErrNo = 106766  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Pickslip No  
               GOTO RollBackTran  
            END  
  
            -- Get Packdetail QTY  
            SELECT @nPAD_QTY = ISNULL( SUM( QTY), 0)  
            FROM dbo.PackDetail WITH (NOLOCK)   
            WHERE PickSlipNo = @cPickSlipNo   
            AND   LabelNo = @cDropID  
            AND   SKU = @cSKU  
  
            IF @nPAD_QTY >= @nPD_QTY  
               GOTO Quit  
  
            -- Get PickHeader info  
            SELECT  
               @cOrderKey = OrderKey,   
               @cLoadKey = ExternOrderKey  
            FROM dbo.PickHeader WITH (NOLOCK)  
            WHERE PickHeaderKey = @cPickSlipNo  
  
            SELECT @cCartonNo = Seqno,  
                   @fWeight = CurrWeight,  
                   @fCube = CurrCube,  
                   @cCartonType = CartonType  
            FROM dbo.CartonList CL WITH (NOLOCK)  
            JOIN dbo.CartonListDetail CLD WITH (NOLOCK) ON ( CL.CartonKey = CLD.CartonKey)  
            WHERE PickDetailKey = @cPickDetailKey  
  
            IF @@ROWCOUNT = 0  
            BEGIN  
               SET @nErrNo = 106767  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No CartonList  
               GOTO RollBackTran  
            END  
  
            IF ISNULL( @cCartonNo, '') = ''  
            BEGIN  
               SET @nErrNo = 106768  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Carton No  
               GOTO RollBackTran  
            END  
  
            SET @nCartonNo = CAST( @cCartonNo AS INT)  
  
            -- Check PackHeader exist  
            IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)  
            BEGIN  
               -- Insert PackHeader  
               INSERT INTO dbo.PackHeader   
                  (PickSlipNo, StorerKey, LoadKey, OrderKey)   
               VALUES  
                  (@cPickSlipNo, @cStorerKey, @cLoadKey, @cOrderKey)  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 106751  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackHdrFail  
       GOTO RollBackTran  
               END  
            END  
  
            -- Check PickingInfo exist  
            IF NOT EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)  
            BEGIN  
               -- Insert PackHeader  
               INSERT INTO dbo.PickingInfo   
                  (PickSlipNo, ScanInDate, PickerID)   
               VALUES   
                  (@cPickSlipNo, GETDATE(), @cUserName)  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 106752  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPKInfoFail  
                  GOTO RollBackTran  
               END  
            END  
  
            /*-------------------------------------------------------------------------------  
  
                                              PackDetail  
  
            -------------------------------------------------------------------------------*/  
            -- Check PackDetail exist  
            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cDropID)  
            BEGIN  
               -- Insert PackDetail  
               INSERT INTO dbo.PackDetail  
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)  
               VALUES  
                  (@cPickSlipNo, @nCartonNo, @cDropID, '00001', @cStorerKey, @cSKU, @nQTY, @cDropID,  
                  'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 106753  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail  
                  GOTO RollBackTran  
               END  
            END  
            ELSE  
            BEGIN  
               -- Same pickslip, labelno but different sku  
               IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)   
                              WHERE StorerKey = @cStorerKey  
                              AND   PickSlipNo = @cPickSlipNo   
                              AND   LabelNo = @cDropID  
                              AND   SKU = @cSKU)  
               BEGIN  
                  SET @nCartonNo = 0  
  
                  SELECT TOP 1 @nCartonNo = CartonNo  
                  FROM dbo.PackDetail WITH (NOLOCK)  
                  WHERE Pickslipno = @cPickSlipNo  
                     AND StorerKey = @cStorerKey  
                     AND LabelNo = @cDropID  
  
                  -- Get next Label No  
                  SELECT @cLabelLine =   
                     RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)  
                  FROM dbo.PackDetail WITH (NOLOCK)  
                  WHERE PickSlipNo = @cPickSlipNo  
                  AND   CartonNo = @nCartonNo  
                          
                  -- Insert PackDetail  
                  INSERT INTO dbo.PackDetail  
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, AddWho, AddDate, EditWho, EditDate)  
                  VALUES  
                     (@cPickSlipNo, @nCartonNo, @cDropID, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cDropID,  
                     'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 106770  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail  
                     GOTO RollBackTran  
                  END  
               END  
               ELSE  
               BEGIN  
                  UPDATE dbo.PackDetail WITH (ROWLOCK) SET  
                     QTY = QTY + @nQTY,  
                     EditWho = SUSER_SNAME(),  
                     EditDate = GETDATE()  
                  WHERE StorerKey = @cStorerKey  
                     AND PickSlipNo = @cPickSlipNo  
                    AND LabelNo = @cDropID  
                     AND SKU = @cSKU  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 106771  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'  
                     GOTO RollBackTran  
                  END  
               END   -- DropID exists and SKU exists (update qty only)  
            END  
  
            -- Check PackInfo Exists  
            IF NOT EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)  
                            WHERE PickSlipNo = @cPickSlipNo  
                            AND   CartonNo = @nCartonNo)  
            BEGIN  
  
               -- Insert PackInfo  
               INSERT INTO dbo.PackInfo   
                  (PickSlipNo, CartonNo, Weight, Cube, CartonType)  
               VALUES  
                  (@cPickSlipNo, @nCartonNo, @fWeight, @fCube, @cCartonType)  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 106754  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackInfoFail  
                  GOTO RollBackTran  
               END  
            END  
  
            -- Insert DropID  
            IF NOT EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cDropID)  
            BEGIN  
               -- Insert DropID  
               INSERT INTO dbo.DropID   
                  (DropID, LabelPrinted, ManifestPrinted, Status)   
               VALUES   
                  (@cDropID, '0', '0', '9')  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 106758  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsDropIDFail  
                  GOTO RollBackTran  
               END  
            END  
  
            -- Get PPA QTY  
            SELECT @nPPA_QTY = ISNULL( SUM( CQTY), 0)  
            FROM rdt.rdtPPA WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
               AND DropID = @cDropID  
  
            -- Get Pickdetail QTY  
            SELECT @nPD_QTY = ISNULL( SUM( QTY), 0)  
            FROM dbo.PickDetail WITH (NOLOCK)   
            WHERE CaseID = @cDropID  
            AND   StorerKey = @cStorerKey  
            AND   [Status] >= @cPickConfirmStatus  
            AND   [Status] < '9'  
  
            IF @nPPA_QTY = @nPD_QTY  
            BEGIN  
               -- Check label printer blank  
               IF @cLabelPrinter = ''  
               BEGIN  
                  SET @nErrNo = 106755  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq  
                  GOTO RollBackTran  
               END  
  
               -- Get packing list report info  
               SET @cDataWindow = ''  
               SET @cTargetDB = ''  
               SELECT   
                  @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
                  @cTargetDB = ISNULL(RTRIM(TargetDB), '')   
               FROM RDT.RDTReport WITH (NOLOCK)   
               WHERE StorerKey = @cStorerKey  
               AND   ReportType = 'SHIPPLABEL'  
               AND   ( Function_ID = @nFunc OR Function_ID = 0)      
                 
               -- Check data window  
               IF ISNULL( @cDataWindow, '') = ''  
               BEGIN  
                  SET @nErrNo = 106756  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup  
                  GOTO RollBackTran  
               END  
        
               -- Check database  
               IF ISNULL( @cTargetDB, '') = ''  
               BEGIN  
                  SET @nErrNo = 106757  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set  
                  GOTO RollBackTran  
               END  
                 
               -- Get CartonNo  
               SELECT TOP 1 @nCartonNo = CartonNo,   
                            @cLabelNo = LabelNo  
               FROM dbo.PackDetail WITH (NOLOCK)   
               WHERE PickSlipNo = @cPickSlipNo   
               AND   LabelNo = @cDropID  
  
               SELECT @cLabelPrinter1 = PrinterID  
               FROM rdt.rdtReportToPrinter WITH (NOLOCK)  
               WHERE Function_ID = @nFunc  
               AND   StorerKey = @cStorerKey  
               AND   PrinterGroup = @cLabelPrinter  
               AND   ReportType = 'SHIPPLABEL'  
                 
               -- Insert print job  
               EXEC RDT.rdt_BuiltPrintJob  
                  @nMobile,  
                  @cStorerKey,  
                  'SHIPPLABEL',       -- ReportType  
                  'PRINT_SHIPPLABEL', -- PrintJobName  
                  @cDataWindow,  
                  @cLabelPrinter1,  
                  @cTargetDB,  
                  @cLangCode,  
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT,   
                  @cPickSlipNo,   
                  @nCartonNo,  -- Start CartonNo  
                  @nCartonNo,  -- End CartonNo  
                  @cLabelNo,   -- Start LabelNo  
                  @cLabelNo    -- End LabelNo  
  
               IF @nErrNo <> 0  
                  GOTO RollBackTran  
  
               -- Update DropID  
               UPDATE dbo.DropID WITH (ROWLOCK) SET  
                  LabelPrinted = '1'  
               WHERE DropID = @cDropID  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 106759  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DropIDFail  
                  GOTO RollBackTran  
               END  
            END  
  
            -- Check paper printer blank  
            IF @cPaperPrinter = ''  
            BEGIN  
               SET @nErrNo = 106760  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrnterReq  
               GOTO RollBackTran  
            END  
  
            -- Get packing list report info  
            SET @cDataWindow = ''  
            SET @cTargetDB = ''  
            SELECT   
               @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
               @cTargetDB = ISNULL(RTRIM(TargetDB), '')   
            FROM RDT.RDTReport WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey  
            AND   ReportType = 'PACKLIST'  
            AND   ( Function_ID = @nFunc OR Function_ID = 0)      
                 
            -- Check data window  
            IF ISNULL( @cDataWindow, '') = ''  
            BEGIN  
               SET @nErrNo = 106761  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup  
               GOTO RollBackTran  
            END  
        
            -- Check database  
            IF ISNULL( @cTargetDB, '') = ''  
            BEGIN  
               SET @nErrNo = 106762  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set  
               GOTO RollBackTran  
            END  
              
            -- Check last carton  
            /*  
            Last carton logic:  
            1. If not fully pack (PickDetail.Status = 0 or 4), definitely not last carton  
            2. If all carton pack and scanned (all PackDetail and DropID records tally), it is last carton  
            */  
            -- 1. Check outstanding PickDetail  
            --IF EXISTS( SELECT TOP 1 1   
            --            FROM dbo.PickDetail WITH (NOLOCK)   
            --            WHERE PickSlipNo = @cPickSlipNo   
            --            AND Status IN ('0', '4'))  
            --   SET @cLastCarton = 'N'   
            --ELSE  
            SET @nExpectedQty = 0  
              
            -- Discrete   
            IF @cOrderKey <> ''  
               SELECT @nExpectedQty = ISNULL(SUM(Qty), 0)   
               FROM PickDetail WITH (NOLOCK)  
               WHERE Orderkey = @cOrderkey  
               AND   Storerkey = @cStorerkey  
               AND   [Status] >= @cPickConfirmStatus  
               AND   Status <> '4'  
              
            -- Conso  
  ELSE IF @cLoadKey <> ''  
               SELECT @nExpectedQty = ISNULL(SUM( PD.QTY), 0)   
               FROM LoadPlanDetail LPD WITH (NOLOCK)  
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)  
               WHERE LPD.LoadKey = @cLoadKey  
               AND   PD.Storerkey = @cStorerkey  
               AND   PD.Status >= @cPickConfirmStatus  
               AND   PD.Status <> '4'  
  
            SET @nPackedQty = 0  
            SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)  
            WHERE PickSlipNo = @cPickSlipNo  
            AND   Storerkey = @cStorerkey  
  
            IF @nExpectedQty <> @nPackedQty  
               SET @cLastCarton = 'N'   
            ELSE  
            BEGIN  
               SET @cLastCarton = 'Y'   
  
               IF EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)     
                           WHERE PickSlipNo = @cPickSlipNo    
                           AND   [Status] < '9')    
               BEGIN    
                  UPDATE dbo.PackHeader WITH (ROWLOCK) SET   
                     [Status] = '9',   
                     EditDate = GETDATE(),   
                     EditWho = SUSER_SNAME()  
                  WHERE PickSlipNo = @cPickSlipNo  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 106769  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail  
                     GOTO RollBackTran  
                  END  
               END  
            END    
  
            -- Insert print job  
            IF @cLastCarton = 'Y'  
            BEGIN  
               EXEC RDT.rdt_BuiltPrintJob  
                  @nMobile,  
                  @cStorerKey,  
                  'PACKLIST',       -- ReportType  
                  'PRINT_PACKLIST', -- PrintJobName  
                  @cDataWindow,  
                  @cPaperPrinter,  
                  @cTargetDB,  
                  @cLangCode,  
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT,   
                  @cPickSlipNo  
  
               IF @nErrNo <> 0  
                  GOTO RollBackTran  
  
               -- Prompt message  
               SET @nErrNo = 106764  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackLstPrinted  
               --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg  
               SET @nErrNo = 0  
               --SET @cErrMsg = ''  
  
               -- Update DropID  
               UPDATE dbo.DropID SET  
                  ManifestPrinted = '1'  
               WHERE DropID = @cDropID  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 106765  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DropIDFail  
                  GOTO RollBackTran  
               END  
            END  
  
            -- Get Orders info  
            SELECT TOP 1 @cOrderKey = OrderKey  
            FROM dbo.PickDetail WITH (NOLOCK)   
            WHERE CaseID = @cDropID  
            AND   StorerKey = @cStorerKey  
            ORDER BY 1  
                          
            -- (james06)  
            SET @cOrdSkuLbl = rdt.rdtGetConfig( @nFunc, 'OrdSkuLbl', @cStorerKey)  
            IF @cOrdSkuLbl = '0'    
               SET @cOrdSkuLbl = ''  
                   
            IF @cOrdSkuLbl <> ''  
            BEGIN  
               --INSERT INTO traceinfo (TraceName, TimeIn, Col1, Col2, Col3) VALUES ('855', GETDATE(), @cOrderKey, @cDropID, @cSKU)  
               IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)  
                           WHERE OrderKey = @cOrderKey  
                           AND   DocType = 'N')  
               BEGIN  
                  IF EXISTS ( SELECT 1 FROM dbo.ORDERDETAIL WITH (NOLOCK)  
                              WHERE OrderKey = @cOrderKey  
                              AND   Sku = @cSKU  
                              AND   ISNULL( ExtendedPrice, 0) > 0   
                              AND   ISNULL( UnitPrice, 0) > 0)  
                  BEGIN  
                     IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)             
                                 JOIN dbo.Orders O WITH (NOLOCK)   
                                    ON (C.Long = O.ConsigneeKey AND C.StorerKey = O.StorerKey)            
                                 WHERE C.ListName = 'NKLABREF'            
                                 AND   O.OrderKey = @cOrderkey            
                                 AND   O.StorerKey = @cStorerKey)    
                     BEGIN  
                        SELECT @cLabelPrinter2 = PrinterID  
                        FROM rdt.rdtReportToPrinter WITH (NOLOCK)  
                        WHERE Function_ID = @nFunc  
                        AND   StorerKey = @cStorerKey  
                        AND   PrinterGroup = @cLabelPrinter  
                        AND   ReportType = @cOrdSkuLbl                       
                          
                        INSERT INTO @tOrdSkuLbl (Variable, Value) VALUES ( '@cStorerKey',    @cStorerKey)  
                        INSERT INTO @tOrdSkuLbl (Variable, Value) VALUES ( '@cSKU',          @cSKU)  
                        INSERT INTO @tOrdSkuLbl (Variable, Value) VALUES ( '@cOrderkey',     @cOrderkey)    
             
                        -- Print label    
                        EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter2, '',      
                           @cOrdSkuLbl, -- Report type    
                           @tOrdSkuLbl, -- Report params    
                           'rdt_855ExtUpd01',     
                           @nErrNo  OUTPUT,    
                           @cErrMsg OUTPUT,     
                           @nQty       -- No of copy  
                    
                        IF @nErrNo <> 0  
                           GOTO RollBackTran  
                     END  
                  END  
               END  
            END  
         END  
      END  
   END  
   --COMMIT TRAN rdt_855ExtUpd01  
  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_855ExtUpd01  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO