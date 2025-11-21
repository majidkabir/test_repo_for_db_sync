SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_867ExtUpdSP03                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pick and pack confirm                                       */
/*                                                                      */
/* Called from: rdtfnc_PickByTrackNo                                    */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2020-05-22   1.0  James    WMS-13481. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_867ExtUpdSP03] (
   @nMobile        INT,
   @nFunc          INT,
   @nStep          INT, 
   @cLangCode      NVARCHAR( 3), 
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @cOrderKey      NVARCHAR( 10),
   @cSKU           NVARCHAR( 20),
   @cTracKNo       NVARCHAR( 18),
   @cSerialNo      NVARCHAR( 30),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT    
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT
   DECLARE @cZone          NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @bSuccess       INT
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @nQty           INT
   DECLARE @cGenLabelNo_SP NVARCHAR( 20)
   DECLARE @cPSType        NVARCHAR( 10)
   DECLARE @cSKUStatus     NVARCHAR( 10) = ''
   DECLARE @cPickFilter    NVARCHAR( MAX) = ''
   DECLARE @nSKUCnt        INT
   DECLARE @nSum_Picked    INT = 0
   DECLARE @nSum_Packed    INT = 0
   DECLARE @cPackDetailCartonID  NVARCHAR( 20)  
   DECLARE @nCartonNo      INT
   DECLARE @nInputKey      INT
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cLabelNo       NVARCHAR( 20)  
   DECLARE @cCartonID      NVARCHAR( 20)
   DECLARE @cShipperKey    NVARCHAR( 15)
   DECLARE @cOrderType     NVARCHAR( 1)
   DECLARE @cShipLabel     NVARCHAR( 1)
   DECLARE @cDelNotes         NVARCHAR( 10)
   DECLARE @cTrackingNo       NVARCHAR( 30)
   DECLARE @cDocType          NVARCHAR( 1)
   DECLARE @cWinPrinter       NVARCHAR(128)  
   DECLARE @cFilePath         NVARCHAR(100)       
   DECLARE @cPrintFilePath    NVARCHAR(100)      
   DECLARE @cPrintCommand     NVARCHAR(MAX)    
   DECLARE @cReportType       NVARCHAR( 10)
   DECLARE @cFilePrefix       NVARCHAR( 30)
   DECLARE @cWinPrinterName   NVARCHAR(100)   
   DECLARE @cFileName         NVARCHAR( 50)    
   DECLARE @cLabelPrinter     NVARCHAR(10)  
   DECLARE @cPaperPrinter     NVARCHAR(10)  
   DECLARE @cOption           NVARCHAR( 1)
          
   SET @nErrNo = 0

   SELECT @nInputKey = InputKey,
          @cLabelPrinter = Printer,  
          @cPaperPrinter = Printer_Paper,
          @cOption = I_Field01
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_867ExtUpdSP03
   
   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cShipperKey = ShipperKey  
               ,@cOrderType  = Type  
               ,@cLoadKey = LoadKey
               ,@cTrackingNo = TrackingNo
               ,@cDocType = DocType
         FROM dbo.Orders WITH (NOLOCK)  
         WHERE OrderKey = @cOrderkey  
         AND StorerKey = @cStorerKey  

         -- Storer configure  
         SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
         IF @cPickConfirmStatus IN ( '', '0')
            SET @cPickConfirmStatus = '5'

         SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo_SP', @cStorerKey) 
         IF @cGenLabelNo_SP = '0'
            SET @cGenLabelNo_SP = ''  

         SET @cPackDetailCartonID = rdt.RDTGetConfig( @nFunc, 'PackDetailCartonID', @cStorerKey)  
         IF @cPackDetailCartonID = '0' -- DropID/LabelNo/RefNo/RefNo2/UPC/NONE  
            SET @cPackDetailCartonID = 'DropID'  
      
         SET @cPSType = ''

         SET @cPickSlipNo = ''  
         SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey  

         IF @cPickSlipNo = ''  
            SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadkey  

         IF ISNULL( @cPickSlipNo, '') = ''
         BEGIN
            SET @nErrNo = 153001
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --PickSlip req
            GOTO RollBackTran  
         END

         SET @nQty = 1

         SET @nSum_Picked = 0
         SET @nSum_Packed = 0
         
         SELECT @nSum_Picked = ISNULL( SUM( QTY), 0)      
         FROM rdt.rdtTrackLog WITH (NOLOCK)      
         WHERE ORDERKEY = @cOrderKey      
         AND   Storerkey = @cStorerkey      
         AND   SKU = @cSKU

         SELECT @nSum_Packed = ISNULL( SUM( Qty), 0)
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND   SKU = @cSKU

         IF (@nSum_Packed + @nQty) > @nSum_Picked
         BEGIN
            SET @nErrNo = 153003
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Pack
            GOTO RollBackTran
         END

  
         /***********************************************************************************************  
                                                    Standard confirm  
         ***********************************************************************************************/  
         BEGIN TRAN  
         SAVE TRAN rdt_867ExtUpdSP03  
  
         -- Scan-in  
         IF NOT EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickslipNo)  
         BEGIN  
            SET @cUserName = SUSER_SNAME()  
        
            -- Scan in pickslip  
            EXEC dbo.isp_ScanInPickslip  
               @c_PickSlipNo  = @cPickSlipNo,  
               @c_PickerID    = @cUserName,  
               @n_err         = @nErrNo      OUTPUT,  
               @c_errmsg      = @cErrMsg     OUTPUT  
  
            IF @nErrNo <> 0  
            BEGIN  
               SET @nErrNo = 153004  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail scan-in  
               GOTO RollBackTran  
            END  
         END  
  
         -- PackHeader  
         IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)  
         BEGIN  
            INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, LoadKey)  
            VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey, @cLoadKey)  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 153005  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPHdrFail  
               GOTO RollBackTran  
            END  
         END  
  
         /***********************************************************************************************  
                                                    PackDetail  
         ***********************************************************************************************/  
  
         DECLARE @cDropID  NVARCHAR( 20) = ''  
         DECLARE @cRefNo   NVARCHAR( 20) = ''  
         DECLARE @cRefNo2  NVARCHAR( 30) = ''  
         DECLARE @cUPC     NVARCHAR( 30) = ''  
  
         SET @cLabelNo = ''  

         SELECT TOP 1 @cCartonID = Dropid
         FROM dbo.PICKDETAIL WITH (NOLOCK)
         WHERE Storerkey = @cStorerKey
         AND   OrderKey = @cOrderKey
         ORDER BY 1
   
         IF @cPackDetailCartonID = 'LabelNo' SET @cLabelNo = @cCartonID ELSE  
         IF @cPackDetailCartonID = 'DropID'  SET @cDropID  = @cCartonID ELSE  
         IF @cPackDetailCartonID = 'RefNo'   SET @cRefNo   = @cCartonID ELSE  
         IF @cPackDetailCartonID = 'RefNo2'  SET @cRefNo2  = @cCartonID ELSE  
         IF @cPackDetailCartonID = 'UPC'     SET @cUPC     = @cCartonID  

         -- Generate labelNo  
         IF @cLabelNo = ''  
         BEGIN  
            IF @cGenLabelNo_SP <> ''  
            BEGIN  
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenLabelNo_SP AND type = 'P')    
               BEGIN  
                  SET @cSQL = 'EXEC dbo.' + RTRIM( @cGenLabelNo_SP) +  
                     ' @cPickslipNo, ' +    
                     ' @nCartonNo,   ' +    
                     ' @cLabelNo     OUTPUT '    
                  SET @cSQLParam =  
                     ' @cPickslipNo  NVARCHAR(10),       ' +    
                     ' @nCartonNo    INT,                ' +    
                     ' @cLabelNo     NVARCHAR(20) OUTPUT '    
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                     @cPickslipNo,   
                     @nCartonNo,   
                     @cLabelNo OUTPUT  
               END  
            END  
            ELSE  
            BEGIN     
               EXEC isp_GenUCCLabelNo  
                  @cStorerKey,  
                  @cLabelNo      OUTPUT,   
                  @bSuccess      OUTPUT,  
                  @nErrNo        OUTPUT,  
                  @cErrMsg       OUTPUT  
               IF @nErrNo <> 0  
               BEGIN  
                  SET @nErrNo = 153006  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail  
                  GOTO RollBackTran  
               END  
            END  
  
            IF @cLabelNo = ''  
            BEGIN  
               SET @nErrNo = 153007  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail  
               GOTO RollBackTran  
            END  
         END  
         
         IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                         WHERE PickSlipNo = @cPickSlipNo) 
         BEGIN
            SET @nCartonNo = 0  
            SET @cLabelLine = '00000'  
  
            -- Insert PackDetail  
            INSERT INTO dbo.PackDetail  
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, RefNo, RefNo2, UPC,   
               AddWho, AddDate, EditWho, EditDate)  
            VALUES  
               (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cDropID, @cRefNo, @cRefNo2, @cUPC,
               'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())  

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 153008  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail  
               GOTO RollBackTran  
            END  
         END
         ELSE
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                            WHERE PickSlipNo = @cPickSlipNo
                            AND   SKU = @cSKU)
            BEGIN
               -- 1 carton per orders
               SELECT TOP 1 @nCartonNo = CartonNo, 
                            @cLabelNo = LabelNo
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               ORDER BY 1
  
               SELECT @cLabelLine = 
                  RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)  
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
  
               -- Insert PackDetail  
               INSERT INTO dbo.PackDetail  
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, RefNo, RefNo2, UPC,   
                  AddWho, AddDate, EditWho, EditDate)  
               VALUES  
                  (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cDropID, @cRefNo, @cRefNo2, @cUPC,
                  'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())  

               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 153012  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail  
                  GOTO RollBackTran  
               END  
            END
            ELSE
            BEGIN
               -- 1 carton per orders
               SELECT TOP 1 @nCartonNo = CartonNo, 
                            @cLabelNo = LabelNo,
                            @cLabelLine = LabelLine
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               AND   SKU = @cSKU
               ORDER BY 1

               UPDATE dbo.PackDetail SET
                  Qty = Qty + @nQTY
               WHERE PickSlipNo = @cPickSlipNo
               AND   CartonNo = @nCartonNo
               AND   LabelNo = @cLabelNo
               AND   LabelLine = @cLabelLine
            
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 153013  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail  
                  GOTO RollBackTran  
               END  
            END
         END
         
         -- Get system assigned CartonoNo and LabelNo  
         IF @nCartonNo = 0  
         BEGIN  
            -- If insert cartonno = 0, system will auto assign max cartonno  
            SELECT TOP 1   
               @nCartonNo = CartonNo,   
               @cLabelNo = LabelNo  
            FROM PackDetail WITH (NOLOCK)  
            WHERE PickSlipNo = @cPickSlipNo  
               AND SKU = @cSKU  
               AND AddWho = 'rdt.' + SUSER_SNAME()  
            ORDER BY CartonNo DESC -- max cartonno  
         END  
  
 
         /***********************************************************************************************  
                                                    Pack confirm  
         ***********************************************************************************************/  
         -- Pack confirm  
         IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status <> '9')  
         BEGIN  
            -- Pack confirm  
            EXEC rdt.rdt_Pack_PackConfirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey  
               ,@cPickSlipNo  
               ,'' --@cFromDropID  
               ,'' --@cPackDtlDropID  
               ,'' --@cPrintPackList OUTPUT  
               ,@nErrNo         OUTPUT  
               ,@cErrMsg        OUTPUT  
            IF @nErrNo <> 0  
               GOTO RollBackTran  

            IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                              WHERE PickSlipNo = @cPickSlipNo
                              AND   [Status] = '9')
            BEGIN
               COMMIT TRAN rdt_867ExtUpdSP03  
               GOTO Quit    
            END
               
            -- Single carton packing
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
                  'rdt_867ExtUpdSP03', 
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
                  'rdt_867ExtUpdSP03',   
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT   
  
               IF @nErrNo <> 0  
                  GOTO RollBackTran  
            END  

            IF @cTrackingNo <> '' AND @cShipperKey = 'QTS' AND @cDocType = 'E' 
            BEGIN
               SELECT @cLabelPrinter = Printer
               FROM rdt.rdtMobrec WITH (NOLOCK)
               WHERE Mobile = @nMobile

               IF @@ROWCOUNT = 0
               BEGIN
                  SET @nErrNo = 153009     
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Lbl Printer    
                  GOTO RollBackTran    
               END

               SELECT @cWinPrinter = WinPrinter
               FROM rdt.rdtPrinter WITH (NOLOCK)  
               WHERE PrinterID = @cLabelPrinter

               IF @@ROWCOUNT = 0
               BEGIN
                  SET @nErrNo = 153010     
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
                     SET @nErrNo = 153011     
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup FilePath    
                     GOTO RollBackTran   
                  END

                  SET @cFilePrefix = @cFilePrefix + CASE WHEN ISNULL( @cFilePrefix, '') <> '' THEN '_' ELSE '' END
                  SET @cFileName = @cFilePrefix + RTRIM( @cTrackingNo) + '.pdf'     
                  SET @cPrintCommand = '"' + @cPrintFilePath + '" "' + @cFilePath + '\' + @cFileName + '" "0" "3" "' + @cWinPrinterName + '"'                              

                  DECLARE @tRDTPrintJob AS VariableTable
      
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
                     @cReportType,     -- Report type
                     @tRDTPrintJob,    -- Report params
                     'rdt_867ExtUpdSP03', 
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
         END  
      END
   END

   IF @nStep = 5
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @cOption = '1'
         BEGIN
            SET @cPickSlipNo = ''  
            SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey  

            IF @cPickSlipNo = ''  
               SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadkey  

            SET @nErrNo = 0
            DECLARE @curPD CURSOR 
            SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT CartonNo, LabelNo, LabelLine
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            OPEN @curPD
            FETCH NEXT FROM @curPD INTO @nCartonNo, @cLabelNo, @cLabelLine
            WHILE @@FETCH_STATUS = 0
            BEGIN
               DELETE FROM PackDetail 
               WHERE PickSlipNo = @cPickSlipNo 
               AND CartonNo = @nCartonNo 
               AND LabelNo = @cLabelNo 
               AND LabelLine = @cLabelLine
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 153002
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Del PackDt Err
                  BREAK  
               END
         
               FETCH NEXT FROM @curPD INTO @nCartonNo, @cLabelNo, @cLabelLine
            END
            
            IF @nErrNo <> 0
               GOTO RollBackTran
         END
      END   
   END


   COMMIT TRAN rdt_867ExtUpdSP03  
   GOTO Quit  
  
   RollBackTran:  
      ROLLBACK TRAN rdt_867ExtUpdSP03  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN

   Fail:
END

GO