SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/        
/* Store procedure: rdt_840ExtUpd26                                     */        
/* Purpose: After pack confirmed, send interface to get multi track no  */        
/*                                                                      */        
/* Modifications log:                                                   */        
/*                                                                      */        
/* Date       Rev  Author     Purposes                                  */        
/* 2022-12-19 1.0  James      WMS-21358. Created                        */        
/************************************************************************/        
        
CREATE   PROC [RDT].[rdt_840ExtUpd26] (        
   @nMobile     INT,        
   @nFunc       INT,        
   @cLangCode   NVARCHAR( 3),        
   @nStep       INT,        
   @nInputKey   INT,        
   @cStorerkey  NVARCHAR( 15),        
   @cOrderKey   NVARCHAR( 10),        
   @cPickSlipNo NVARCHAR( 10),        
   @cTrackNo    NVARCHAR( 20),        
   @cSKU        NVARCHAR( 20),        
   @nCartonNo   INT,        
   @cSerialNo   NVARCHAR( 30),     
   @nSerialQTY  INT,         
   @nErrNo      INT           OUTPUT,        
   @cErrMsg     NVARCHAR( 20) OUTPUT        
)        
AS        
        
   SET NOCOUNT ON        
   SET QUOTED_IDENTIFIER OFF        
   SET ANSI_NULLS OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
        
   DECLARE @nTranCount     INT
   DECLARE @bSuccess       INT
   DECLARE @nRowRef        INT
   DECLARE @nMaxCtnNo      INT
   DECLARE @cLabelNo       NVARCHAR( 20)   
   DECLARE @cTrackingNo    NVARCHAR( 40)
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @curPickD       CURSOR
   DECLARE @curPackD       CURSOR
   DECLARE @curCtnTrack    CURSOR
   DECLARE @curPackDtl     CURSOR
   DECLARE @cShipLabel        NVARCHAR( 10)  
   DECLARE @cDelNotes         NVARCHAR( 10)  
   DECLARE @nCtnNo            INT
   DECLARE @nQty              INT
   DECLARE @cLblNo            NVARCHAR( 20)
   
   DECLARE @nPickQty          INT,  
           @nPackQty          INT,  
           @nFromCartonNo     INT,  
           @nToCartonNo       INT,  
           @cOrderGroup       NVARCHAR(20),  
           @cFacility         NVARCHAR( 5),  
           @cPaperPrinter     NVARCHAR( 10),  
           @cLabelPrinter     NVARCHAR( 10),  
           @cLoadKey          NVARCHAR( 10),  
 
           @cRoute            NVARCHAR( 20),  
           @cConsigneeKey     NVARCHAR( 20),  
           @cEcomPlatform     VARCHAR(20)    

   DECLARE @cShipLabelEcom    NVARCHAR(20)
              
   SET @nTranCount = @@TRANCOUNT        
   BEGIN TRAN  -- Begin our own transaction        
   SAVE TRAN rdt_840ExtUpd26 -- For rollback or commit only our own transaction        
            
   IF @nStep = 4        
   BEGIN        
      IF @nInputKey = 1        
      BEGIN        
         IF EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                     WHERE PickSlipNo = @cPickSlipNo
                     AND   [Status] = '9')
         BEGIN
         	SELECT @nMaxCtnNo = MAX(CartonNo)
         	FROM dbo.PackDetail WITH (NOLOCK)
         	WHERE PickSlipNo = @cPickSlipNo
         	
         	IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)
         	            WHERE OrderKey = @cOrderKey
         	            AND   OrderGroup = 'VMI' 
         	            AND   ShipperKey = 'JD') AND @nMaxCtnNo > 1
         	BEGIN
         		IF NOT EXISTS ( SELECT 1 FROM dbo.TRANSMITLOG2 WITH (NOLOCK)
         		                WHERE tablename = 'WSCRSOUPDJD'
         		                AND   key1 = @cOrderKey
         		                AND   key2 = '5'
         		                AND   key3 = @cStorerkey)
               BEGIN
                  -- Insert transmitlog2 here        
                  EXECUTE ispGenTransmitLog2        
                     @c_TableName      = 'WSCRSOUPDJD',        
                     @c_Key1           = @cOrderKey,        
                     @c_Key2           = '5',        
                     @c_Key3           = @cStorerkey,        
                     @c_TransmitBatch  = '',        
                     @b_Success        = @bSuccess   OUTPUT,        
                     @n_err            = @nErrNo     OUTPUT,        
                     @c_errmsg         = @cErrMsg    OUTPUT        
        
                  IF @bSuccess <> 1        
                     GOTO RollBackTran
               END
               ELSE
               BEGIN
             	   UPDATE dbo.TRANSMITLOG2 SET 
             	      transmitflag = '0', 
             	      EditWho = SUSER_SNAME(), 
             	      EditDate = GETDATE()
             	   WHERE tablename = 'WSCRSOUPDJD'
         		   AND   key1 = @cOrderKey
         		   AND   key2 = '5'
         		   AND   key3 = @cStorerkey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 193851
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTL2 Failed'
                     GOTO RollBackTran
                  END
               END

               SELECT TOP 1 @cLabelNo = LabelNo
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               AND   CartonNo = 1
               ORDER BY 1
                  
               SELECT @cTrackingNo = TrackingNo
               FROM dbo.ORDERS WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey
                  
               SET @curPackD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT LabelLine 
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               AND   CartonNo = 1
               AND   LabelNo = @cLabelNo
               ORDER BY 1
               OPEN @curPackD
               FETCH NEXT FROM @curPackD INTO @cLabelLine
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  UPDATE dbo.PackDetail SET 
                     LabelNo = RTRIM( @cTrackingNo) + '-1', 
                     DropID = RTRIM( @cTrackingNo) + '-1',
                     EditWho = SUSER_SNAME(), 
                     EditDate = GETDATE()
                  WHERE PickSlipNo = @cPickSlipNo
                  AND   CartonNo = 1
                  AND   LabelNo = @cLabelNo
                  AND   LabelLine = @cLabelLine
                     
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 193852
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Pack Err'
                     GOTO RollBackTran
                  END
                     
                  FETCH NEXT FROM @curPackD INTO @cLabelLine
               END
               CLOSE @curPackD
               DEALLOCATE @curPackD
               
               SET @curPickD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT PickDetailKey 
               FROM dbo.PICKDETAIL WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey
               AND   DropID = @cLabelNo
               ORDER BY 1
               OPEN @curPickD
               FETCH NEXT FROM @curPickD INTO @cPickDetailKey
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  UPDATE dbo.PICKDETAIL SET 
                  	DropID = RTRIM( @cTrackingNo) + '-1', 
                     EditWho = SUSER_SNAME(), 
                     EditDate = GETDATE()
                  WHERE PickDetailKey = @cPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 193853
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Pick Err'
                     GOTO RollBackTran
                  END
                     
                  FETCH NEXT FROM @curPickD INTO @cPickDetailKey
               END
               CLOSE @curPickD
               DEALLOCATE @curPickD
               
               --SET @curCtnTrack = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               --SELECT RowRef 
               --FROM dbo.CartonTrack WITH (NOLOCK)
               --WHERE LabelNo = @cOrderKey
               --AND   TrackingNo = @cLabelNo
               --ORDER BY 1
               --OPEN @curCtnTrack
               --FETCH NEXT FROM @curCtnTrack INTO @nRowRef
               --WHILE @@FETCH_STATUS = 0
               --BEGIN
               --   UPDATE dbo.CartonTrack SET 
               --      TrackingNo = RTRIM( @cTrackingNo) + '-1', 
               --      EditWho = SUSER_SNAME(), 
               --      EditDate = GETDATE()
               --   WHERE RowRef = @nRowRef
                  
               --   IF @@ERROR <> 0
               --   BEGIN
               --      SET @nErrNo = 193854
               --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd CtnTk Err'
               --      GOTO RollBackTran
               --   END
                     
               --   FETCH NEXT FROM @curCtnTrack INTO @nRowRef
               --END
               --CLOSE @curCtnTrack
               --DEALLOCATE @curCtnTrack
               
         	   -- Update packinfo qty, tracking no
         	   SET @curPackDtl = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         	   SELECT CartonNo, LabelNo, SUM( Qty)
         	   FROM dbo.PackDetail WITH (NOLOCK)
         	   WHERE PickSlipNo = @cPickSlipNo
         	   GROUP BY CartonNo, LabelNo
         	   ORDER BY 1
         	   OPEN @curPackDtl
         	   FETCH NEXT FROM @curPackDtl INTO @nCtnNo, @cLblNo, @nQty
         	   WHILE @@FETCH_STATUS = 0
         	   BEGIN
         		   UPDATE dbo.PackInfo SET
         		      Qty = @nQty,
         		      TrackingNo = @cLblNo,
         		      EditWho = SUSER_SNAME(),
         		      EditDate = GETDATE()
         		   WHERE PickSlipNo = @cPickSlipNo
         		   AND   CartonNo = @nCtnNo
         		
         		   IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 193855
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PCKIF ERR'
                     GOTO RollBackTran
                  END

         	      FETCH NEXT FROM @curPackDtl INTO @nCtnNo, @cLblNo, @nQty
         	   END
         	   CLOSE @curPackDtl
         	   DEALLOCATE @curPackDtl
         	   
               SET @curPackD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT CartonNo, LabelNo, LabelLine
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               ORDER BY CartonNo, LabelNo, LabelLine
               OPEN @curPackD
               FETCH NEXT FROM @curPackD INTO @nCartonNo, @cLabelNo, @cLabelLine
               WHILE @@FETCH_STATUS = 0
               BEGIN
               	SET @cLblNo = LEFT( RTRIM( @cLabelNo) + '-' + RTRIM( CAST( @nMaxCtnNo AS NVARCHAR( 3))) + '-', 20)

               	UPDATE dbo.PackDetail SET 
               	   LabelNo = @cLblNo,
               	   DropID = @cLblNo,
         		      EditWho = SUSER_SNAME(),
         		      EditDate = GETDATE()
               	WHERE PickSlipNo = @cPickSlipNo
               	AND   CartonNo = @nCartonNo
               	AND   LabelNo = @cLabelNo
               	AND   LabelLine = @cLabelLine

         		   IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 193856
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PACK ERR'
                     GOTO RollBackTran
                  END
                  
                  UPDATE dbo.PackInfo SET
                     TrackingNo = @cLblNo,
         		      EditWho = SUSER_SNAME(),
         		      EditDate = GETDATE()
                  WHERE PickSlipNo = @cPickSlipNo
               	AND   CartonNo = @nCartonNo

         		   IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 193857
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PCKIF ERR'
                     GOTO RollBackTran
                  END

               	FETCH NEXT FROM @curPackD INTO @nCartonNo, @cLabelNo, @cLabelLine
               END
               CLOSE @curPackD
               DEALLOCATE @curPackD
         	END
         END

         SELECT @nPickQty = ISNULL( SUM( QTY), 0)  
         FROM dbo.PickDetail WITH (NOLOCK)  
         WHERE OrderKey = @cOrderKey  
         AND   StorerKey = @cStorerkey  
  
         SELECT @nPackQty = ISNULL( SUM( QTY), 0)  
         FROM dbo.PackDetail WITH (NOLOCK)  
         WHERE StorerKey = @cStorerkey  
         AND   PickSlipNo = @cPickSlipNo  
  
         IF @nPickQty = @nPackQty  
         BEGIN  
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
  
            -- Assign  
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
      END        
   END        
        
   GOTO CommitTrans        
        
   RollBackTran:        
         ROLLBACK TRAN rdt_840ExtUpd26        
        
   CommitTrans:        
      WHILE @@TRANCOUNT > @nTranCount        
         COMMIT TRAN             

   IF @nStep = 4
   BEGIN
   	IF @nInputKey = 1
   	BEGIN
         SELECT @cLoadKey = ISNULL(RTRIM(LoadKey),'')  
               , @cRoute = ISNULL(RTRIM(Route),'')  
               , @cConsigneeKey = ISNULL(RTRIM(ConsigneeKey),'')  
               , @cTrackNo = TrackingNo
               , @cOrderGroup = ordergroup  
               ,@cEcomPlatform = Ecom_platform
         FROM dbo.Orders WITH (NOLOCK)  
         WHERE Orderkey = @cOrderkey  
         
         -- Delivery notes only print when all items pick n pack  
         IF @nPickQty = @nPackQty  
         BEGIN  
            SELECT  
               @cLabelPrinter = Printer,  
               @cPaperPrinter = Printer_Paper  
            FROM rdt.rdtMobRec WITH (NOLOCK)  
            WHERE Mobile = @nMobile  
  
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
                  'rdt_840ExtUpd26',  
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT  
  
               IF @nErrNo <> 0  
                  GOTO QUIT  
            END  
  
            IF EXISTS (SELECT 1 FROM Codelkup (nolock)   
                        where listname='VIPORDTYPE'   
                           and storerkey=@cstorerkey  
                           and code = @cOrdergroup  
                           and short =@nFunc) --yeekung02  
            BEGIN  
               SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabels', @cStorerKey)        
               IF @cShipLabel = '0'        
                  SET @cShipLabel = ''     
            END  
            ELSE  
            BEGIN  
               SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShippLabel', @cStorerKey)        
               IF @cShipLabel = '0'        
                  SET @cShipLabel = ''     
            END  

            SET @cShipLabelEcom = rdt.RDTGetConfig( @nFunc, 'ShipLabelEC', @cStorerKey)          
            IF @cShipLabelEcom = '0'          
               SET @cShipLabelEcom = ''     

            IF @cShipLabel <> ''  
            BEGIN  
  
               SELECT @nFromCartonNo = MIN( CartonNo),  
                        @nToCartonNo = MAX( CartonNo)  
               FROM dbo.PackDetail WITH (NOLOCK)  
               WHERE PickSlipNo = @cPickSlipNo  
  
               DECLARE @tSHIPPLABEL AS VariableTable  
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',       @cOrderKey)  
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nFromCartonNo',   @nFromCartonNo)  
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nToCartonNo',     @nToCartonNo)  
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cLoadKey',        @cLoadKey)  
               
               IF @cEcomPlatform='PDD'  
               BEGIN  
                  SET @cShipLabel=@cShipLabelEcom  
  
                  DECLARE @cPrinter      NVARCHAR( 10)  
                        ,@cPrintData        NVARCHAR( MAX)  
                        ,@cWorkingFilePath  NVARCHAR( 250)  
                        ,@cFilePath         NVARCHAR( 250)  
                        ,@cFileType         NVARCHAR( 10)  
                        ,@cPrintServer      NVARCHAR( 50)  
                        ,@cPrintFilePath  NVARCHAR(250)  
                        ,@cFileName         NVARCHAR( 100)  
  
                  DECLARE @cWinPrinterName   NVARCHAR( 100),  
                             @cPrintCommand       NVARCHAR(MAX)   
  
                  SELECT @cWorkingFilePath = UDF01,  
                           @cFileType = UDF02,  
                           @cPrintServer = UDF03,  
                           @cPrintFilePath = Notes   -- foxit program  
                  FROM dbo.CODELKUP WITH (NOLOCK)        
                  WHERE LISTNAME = 'printlabel'          
                  AND   StorerKey = @cStorerKey  
                  Order By Code  
  
                  SELECT @cWinPrinterName = WinPrinter  
                  FROM rdt.rdtPrinter WITH (NOLOCK)    
                  WHERE PrinterID = @cLabelPrinter  
  
                  SET @cFileName =  RTRIM( @cTrackNo) + '.' + @cFileType  
  
                  IF CHARINDEX( 'SEND2PRINTER', @cPrintFilePath) > 0      
                     SET @cPrintCommand = '"' + @cPrintFilePath + '" "' + @cWorkingFilePath + '\' + @cFileName + '" "33" "3" "' + @cWinPrinterName + '"'    
  
                  -- Print label  
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '',  
                     @cShipLabel,  -- Report type  
                     @tSHIPPLABEL, -- Report params  
                     'rdt_840ExtInsPack06',  
                     @nErrNo  OUTPUT,  
                     @cErrMsg OUTPUT,  
                     1,  
                     @cPrintCommand  
  
                  IF @nErrNo <> 0  
                     GOTO QUIT  
               END  
               ELSE  
               BEGIN    
                  -- Print label  
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '',  
                     @cShipLabel,  -- Report type  
                     @tSHIPPLABEL, -- Report params  
                     'rdt_840ExtUpd26',  
                     @nErrNo  OUTPUT,  
                     @cErrMsg OUTPUT  
     
                  IF @nErrNo <> 0  
                     GOTO QUIT  
               END
            END  
         END  
   	END
   END
   
   Quit:
   

GO