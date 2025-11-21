SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store procedure: rdt_840ExtUpd03                                     */    
/* Purpose: Print H&M label                                             */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2016-06-10 1.0  James      SOS#368195. Created                       */    
/* 2017-11-27 1.1  James      Add scaninlog trigger (james01)           */    
/* 2020-05-18 1.3  James      WMS-13418 Skip print DN for ordertype     */    
/*                            SSG (james02)                             */   
/* 2020-01-04 1.4  YeeKung    WMS-15773 Add expectedqty=packqty         */
/*                            (yeekung01)                               */  
/* 2021-04-01 1.5  YeeKung    WMS-16717 Add serialno and serialqty      */
/*                            Params (yeekung01)                        */  
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_840ExtUpd03] (    
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
    
   DECLARE @nTranCount     INT,     
           @cReportType    NVARCHAR( 10),    
           @cPrintJobName  NVARCHAR( 50),    
           @cDataWindow    NVARCHAR( 50),    
           @cTargetDB      NVARCHAR( 20),    
           @cOrderType     NVARCHAR( 10),    
           @cPaperPrinter  NVARCHAR( 10),    
           @cLabelPrinter  NVARCHAR( 10),    
           @nOriginalQty   INT,     
           @nPickQty       INT,     
           @nExpectedQty   INT,    
           @nPackedQty     INT,     
           @nCtnCount      INT,     
           @nCtnNo         INT,     
           @b_success      INT,     
           @n_err          INT,     
           @c_errmsg       NVARCHAR( 20)    
    
    
   DECLARE @cPackByTrackNotUpdUPC      NVARCHAR(1),     
           @cTempBarcode               NVARCHAR( 20),    
           @cCheckDigit                NVARCHAR( 1),    
           @cOrderBoxBarcode           NVARCHAR( 20),    
           @cShipperKey                NVARCHAR( 15),    
           @cOrdType                   NVARCHAR( 10), -- (james01)    
           @bSuccess                   INT,    
           @cAuthority_ScanInLog       NVARCHAR( 1)    
    
   SET @nTranCount = @@TRANCOUNT        
    
   BEGIN TRAN        
   SAVE TRAN rdt_840ExtUpd03    
    
   IF @nInputKey = 1    
   BEGIN    
      IF @nStep = 1  -- (james01)    
      BEGIN    
         IF ISNULL( @cPickSlipNo, '') = ''    
         BEGIN    
            SET @nErrNo = 101305    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NO PKSLIP'    
            GOTO RollBackTran    
         END    
    
         IF ISNULL( @cOrderKey, '') = ''    
         BEGIN    
            SELECT @cOrderKey = OrderKey    
            FROM dbo.PickHeader WITH (NOLOCK)    
            WHERE PickHeaderKey = @cPickSlipNo    
    
            IF ISNULL( @cOrderKey, '') = ''    
            BEGIN    
               SET @nErrNo = 101306    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NO ORDERKEY'    
               GOTO RollBackTran    
            END    
         END    
    
         SET @cOrdType = ''    
         SELECT @cOrdType = [Type]    
         FROM dbo.Orders WITH (NOLOCK)    
         WHERE OrderKey = @cOrderKey    
    
         UPDATE dbo.ORDERS WITH (ROWLOCK) SET    
            STATUS = '3',    
            EditWho = sUser_sName(),    
            EditDate = GetDate()    
         WHERE OrderKey = @cOrderKey    
         AND Status < '3'    
    
         IF @@ERROR <> 0    
         BEGIN    
       SET @nErrNo = 101307    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd OdHdr Fail'    
            GOTO RollBackTran    
         END    
    
         UPDATE dbo.ORDERDETAIL WITH (ROWLOCK) SET    
            STATUS = '3',    
            EditWho = sUser_sName(),    
            EditDate = GetDate(),    
            TrafficCop = NULL    
         WHERE OrderKey = @cOrderKey    
         AND   STATUS < '3'    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 101308    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd OdDtl Fail'    
            GOTO RollBackTran    
         END    
    
         UPDATE dbo.LOADPLANDETAIL WITH (ROWLOCK) SET    
            STATUS = '3',    
            EditWho = sUser_sName(),    
            EditDate = GetDate(),    
            TrafficCop = NULL    
         WHERE OrderKey = @cOrderKey    
         AND STATUS < '5'    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 101309    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd LpDtl Fail'    
            GOTO RollBackTran    
         END    
    
         -- Check if pickslip already scan in and not yet insert transmitlog3 then start insert    
         -- (if orders.doctype = 'E' then scan in will not fire trigger and hence no transmitlog3 record)    
         IF EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)    
                     WHERE PickSlipNo = @cPickSlipNo    
                     AND   ScanInDate IS NOT NULL    
                     AND   TrafficCop = 'U')    
         AND @cOrdType NOT IN ( 'R','S')  -- Move orders no need scaninlog    
         BEGIN    
            IF NOT EXISTS ( SELECT 1 FROM dbo.TransmitLog3 WITH (NOLOCK)    
                            WHERE TableName = 'ScanInLog'    
                            AND   Key1 = @cOrderKey    
                            AND   Key3 = @cStorerkey)    
            BEGIN    
               EXECUTE dbo.nspGetRight    
                  @c_Facility    = '',    
                  @c_StorerKey   = @cStorerKey,    
                  @c_SKU         = '',    
                  @c_ConfigKey   = 'ScanInLog',    
                  @b_success     = @bSuccess                OUTPUT,    
                  @c_authority   = @cAuthority_ScanInLog    OUTPUT,    
                  @n_err         = @nErrNo                  OUTPUT,    
                  @c_errmsg      = @cErrmsg                 OUTPUT    
    
               IF @bSuccess <> 1    
               BEGIN    
                  SET @nErrNo = 101310    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'nspGetRightErr'    
                  GOTO RollBackTran    
               End    
    
               IF @cAuthority_ScanInLog = '1'    
               BEGIN    
                  EXEC dbo.ispGenTransmitLog3    
                     @c_TableName      = 'ScanInLog',    
                     @c_Key1           = @cOrderKey,    
                     @c_Key2           = '' ,    
                     @c_Key3           = @cStorerKey,    
                     @c_TransmitBatch  = '',    
                     @b_success        = @bSuccess    OUTPUT,    
                     @n_err            = @nErrNo      OUTPUT,    
                     @c_errmsg         = @cErrMsg     OUTPUT    
    
                  IF @bSuccess <> 1    
                  BEGIN    
                     SET @nErrNo = 101311    
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenTLog3 Fail'    
                     GOTO RollBackTran    
                  End    
               END    
            END    
         END    
      END    
   END    
  
   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 4  
      BEGIN  
         SELECT @cOrderKey = OrderKey  
         FROM dbo.PackHeader WITH (NOLOCK)   
         WHERE PickSlipNo = @cPickSlipNo  
         AND   [Status] = '9'  
  
         IF ISNULL(@cOrderKey, '') = ''  
         BEGIN  
            SET @nErrNo = 101301  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need orderkey  
            GOTO RollBackTran                    
         END  
  
         SET @cOrdType = ''  
         SELECT @cOrdType = [Type]  
         FROM dbo.Orders WITH (NOLOCK)  
         WHERE OrderKey = @cOrderKey  
           
         SELECT     
            @cLabelPrinter = Printer,     
            @cPaperPrinter = Printer_Paper    
         FROM rdt.rdtMobRec WITH (NOLOCK)    
         WHERE Mobile = @nMobile    


         --(yeekung01)
         SET @nExpectedQty = 0        
         SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)        
         WHERE Orderkey = @cOrderkey        
            AND Storerkey = @cStorerkey        
            AND Status < '9'        
           
         SET @nPackedQty = 0        
         SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)        
         WHERE PickSlipNo = @cPickSlipNo        
            AND Storerkey = @cStorerkey        
    
         -- all SKU and qty has been packed, Update the carton barcode to the PackDetail.UPC for each carton        
         IF @nExpectedQty = @nPackedQty        
         BEGIN  
            -- Only customer order need print below label  
            IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)   
                        JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)  
                        WHERE C.ListName = 'HMORDTYPE'  
                        AND   C.Short = 'S'  
                        AND   O.OrderKey = @cOrderkey  
                        AND   O.StorerKey = @cStorerKey)  
            BEGIN  
               IF EXISTS (SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)  
                    WHERE StorerKey = @cStorerKey  
                    AND   ReportType = 'DELNOTES'  
                    AND   1 = CASE WHEN Function_ID = @nFunc OR Function_ID = 0 THEN 1  
                              ELSE 0 END) AND @cOrdType <> 'SSG'  -- james02)  
               BEGIN  
                  -- Printing process  
                  -- Print the delivery notes  
                  IF ISNULL(@cPaperPrinter, '') = ''  
                  BEGIN  
                     SET @nErrNo = 101302  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPaperPrinter  
                     GOTO RollBackTran                    
                  END  
  
                  SET @cReportType = 'DELNOTES'  
                  SET @cPrintJobName = 'PRINT_DELIVERYNOTES'  
  
                  SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
                         @cTargetDB = ISNULL(RTRIM(TargetDB), '')  
                  FROM RDT.RDTReport WITH (NOLOCK)  
                  WHERE StorerKey = @cStorerKey  
                  AND   ReportType = @cReportType  
  
                  IF ISNULL(@cDataWindow, '') = ''  
                  BEGIN  
                     SET @nErrNo = 101303  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup  
                     GOTO RollBackTran                    
                  END  
  
                  IF ISNULL(@cTargetDB, '') = ''  
                  BEGIN  
                     SET @nErrNo = 101304  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set  
                     GOTO RollBackTran                    
                  END  
  
                  SET @nErrNo = 0                      
                  EXEC RDT.rdt_BuiltPrintJob                       
                     @nMobile,                      
                     @cStorerKey,                      
                     'DELNOTES',                      
                     'PRINT_DELIVERYNOTES',                      
                     @cDataWindow,                      
                     @cPaperPrinter,                      
                     @cTargetDB,                      
                     @cLangCode,                      
                     @nErrNo  OUTPUT,                       
                     @cErrMsg OUTPUT,                      
                     @cOrderKey,   
                     ''  
                  IF @nErrNo <> 0  
                     GOTO RollBackTran                    
               END  
            END  
         END
      END  
   END  
     
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      IF @nStep = 3 -- CartonNo, SKU    
      BEGIN    
         IF NOT EXISTS ( SELECT 1     
                         FROM dbo.CODELKUP C WITH (NOLOCK)     
                         JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)    
                         WHERE C.ListName = 'HMORDTYPE'    
                         AND   O.OrderKey = @cOrderkey    
                         AND   O.StorerKey = @cStorerKey    
                         AND   C.Short = 'S')    
            GOTO Quit    
    
         SET @cPackByTrackNotUpdUPC = ''    
         SET @cPackByTrackNotUpdUPC = rdt.RDTGetConfig( @nFunc, 'PackByTrackNotUpdUPC', @cStorerKey)    
    
         IF ISNULL( @cPickSlipNo, '') = ''    
            SELECT @cPickSlipNo = PickHeaderKey     
            FROM dbo.PickHeader WITH (NOLOCK)     
            WHERE OrderKey = @cOrderkey    
    
    
         -- 1 orders 1 tracking no        
         -- discrete pickslip, 1 ordes 1 pickslipno        
         SET @nExpectedQty = 0        
         SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)        
         WHERE Orderkey = @cOrderkey        
            AND Storerkey = @cStorerkey        
            AND Status < '9'        
           
         SET @nPackedQty = 0        
         SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)        
         WHERE PickSlipNo = @cPickSlipNo        
            AND Storerkey = @cStorerkey        
    
         -- all SKU and qty has been packed, Update the carton barcode to the PackDetail.UPC for each carton        
         IF @nExpectedQty = @nPackedQty        
         BEGIN        
            SELECT @nCtnCount = ISNULL(COUNT( DISTINCT CartonNo), 0)        
            FROM dbo.PackDetail WITH ( NOLOCK)         
            WHERE Storerkey = @cStorerKey        
               AND PickSlipNo = @cPickSlipNo        
                    
            IF @nCtnCount > 0        
            BEGIN        
               DECLARE CUR_PACKDTL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR         
               SELECT DISTINCT CartonNo FROM dbo.PackDetail WITH (NOLOCK)        
               WHERE Storerkey = @cStorerKey        
                  AND PickSlipNo = @cPickSlipNo        
               ORDER BY CartonNo        
               OPEN CUR_PACKDTL        
               FETCH NEXT FROM CUR_PACKDTL INTO @nCtnNo        
               WHILE @@FETCH_STATUS <> -1        
               BEGIN        
                  -- Generateorder box barcode        
                  SET @cTempBarcode = ''        
                  SET @cTempBarcode = '021'         
                  SET @cTempBarcode = RTRIM(@cTempBarcode) + RTRIM(@cOrderKey)         
                  SET @cTempBarcode = RTRIM(@cTempBarcode) + RIGHT( '00' + CAST( @nCtnNo AS NVARCHAR( 2)), 2)        
                  SET @cTempBarcode = RTRIM(@cTempBarcode) + RIGHT( '000' + CAST( @nCtnCount AS NVARCHAR( 3)), 3)         
                  SET @cTempBarcode = RTRIM(@cTempBarcode) + '1'        
                  SET @cCheckDigit = dbo.fnc_CalcCheckDigit_M10(RTRIM(@cTempBarcode), 0)        
                  SET @cOrderBoxBarcode = RTRIM(@cTempBarcode) + @cCheckDigit        
                          
                  UPDATE dbo.PackDetail WITH (ROWLOCK) SET         
                     UPC = CASE WHEN @cPackByTrackNotUpdUPC = '1' THEN UPC ELSE @cOrderBoxBarcode END,         
                     ArchiveCop = NULL,         
                     EditWho = 'rdt.' + sUser_sName(),         
                     EditDate = GETDATE()         
                  WHERE PickSlipNo = @cPickSlipNo        
                     AND CartonNo = @nCtnNo        
              
                  IF @@ERROR <> 0        
                  BEGIN     
                     CLOSE CUR_PACKDTL        
                     DEALLOCATE CUR_PACKDTL        
    
                     GOTO RollBackTran      
                  END        
    
                  FETCH NEXT FROM CUR_PACKDTL INTO @nCtnNo        
               END        
               CLOSE CUR_PACKDTL        
               DEALLOCATE CUR_PACKDTL        
            END    
         END    
      END       
   END    
    
   GOTO Quit    
       
   RollBackTran:      
         ROLLBACK TRAN rdt_840ExtUpd03      
   Quit:      
      WHILE @@TRANCOUNT > @nTranCount      
         COMMIT TRAN      

GO