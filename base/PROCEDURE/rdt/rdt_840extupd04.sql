SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
     
/************************************************************************/  
/* Store procedure: rdt_840ExtUpd04                                     */  
/* Purpose: Pack confirm                                                */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2016-06-24 1.0  James      Created                                   */  
/* 2017-10-26 1.1  James      Move printing label out from transaction  */  
/*                            block (james01)                           */  
/* 2018-11-15 1.2  Ung        INC0470522 Fix no packing also print out  */  
/* 2020-09-05 1.3  James      WMS-15010 Add AutoMBOLPack (james02)      */  
/* 2021-04-01 1.4  YeeKung    WMS-16717 Add serialno and serialqty      */  
/*                            Params (yeekung01)                        */  
/* 2021-08-17 1.5  SYCHUA     JSM-14729 Add function_id filter when     */  
/*                            retrieving RDT.RDTReport (SY01)           */  
/* 2021-08-17 1.6  YeeKung    WMS-19465 Support TPPrint (yeekung02)     */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_840ExtUpd04] (  
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
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nTranCount     INT,  
           @nExpectedQty   INT,  
           @nPackedQty     INT,  
           @cReportType    NVARCHAR( 10),  
           @cPrintJobName  NVARCHAR( 50),  
           @cDataWindow    NVARCHAR( 50),  
           @cTargetDB      NVARCHAR( 20),  
           @cPrinter       NVARCHAR( 10),  
           @cPrinter_Paper NVARCHAR( 10),  
           @cLoadKey       NVARCHAR( 10),  
           @cShipperKey    NVARCHAR( 15),  
           @bSuccess       INT,           -- (james02)  
           @cFacility      NVARCHAR( 5),  -- (james02)  
           @cAutoMBOLPack  NVARCHAR( 1)   -- (james02)  
  
  
   DECLARE @tSHIPPLABEL VariableTable  
   DECLARE @tPackList  VariableTable  
    
   SELECT @cFacility = Facility  
   FROM RDT.RDTMOBREC WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
  
   IF @nStep = 3  
   BEGIN  
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
  
      -- all SKU and qty has been packed, pack confirm it  
      IF @nExpectedQty = @nPackedQty  
      BEGIN  
         -- Pack confirm  
         IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND [Status] < '9')  
         BEGIN  
            SET @nTranCount = @@TRANCOUNT  
            BEGIN TRAN  
            SAVE TRAN rdt_840ExtUpd04  
  
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
               ROLLBACK TRAN rdt_840ExtUpd04  
               WHILE @@TRANCOUNT > @nTranCount  
                  COMMIT TRAN  
  
               SET @nErrNo = 101656  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetRightFail  
               GOTO Quit  
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
                  ROLLBACK TRAN rdt_840ExtUpd04  
                  WHILE @@TRANCOUNT > @nTranCount  
                     COMMIT TRAN  
  
                  SET @nErrNo = 101657  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- AutoMBOLPack  
                  GOTO Quit  
               END  
            END  
  
            UPDATE dbo.PackHeader SET  
               STATUS = '9',  
               EditWho = 'rdt.' + SUSER_SNAME(),  
               EditDate = GETDATE()  
            WHERE PickSlipNo = @cPickSlipNo  
            IF @@ERROR <> 0  
            BEGIN  
               ROLLBACK TRAN rdt_840ExtUpd04  
               WHILE @@TRANCOUNT > @nTranCount  
                  COMMIT TRAN  
  
               SET @nErrNo = 101651  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Packcfm fail  
               GOTO Quit  
            END  
  
            COMMIT TRAN rdt_840ExtUpd04  
            WHILE @@TRANCOUNT > @nTranCount  
               COMMIT TRAN  
         END  
  
         -- User scanned something  
         IF EXISTS (SELECT 1 FROM rdt.rdtTrackLog WITH (NOLOCK)  
                    WHERE AddWho = SUSER_SNAME())  
         BEGIN  
            SELECT @cPrinter = Printer,  
                   @cPrinter_Paper = Printer_Paper  
            FROM RDT.RDTMOBREC WITH (NOLOCK)  
            WHERE Mobile = @nMobile  
  
            -- Print only if rdt report is setup (james05)  
            IF EXISTS (SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)  
                        WHERE StorerKey = @cStorerKey  
                        AND   ReportType = 'PACKLIST'  
                        AND   1 = CASE WHEN Function_ID = @nFunc OR Function_ID = 0 THEN 1  
                                    ELSE 0 END)  
            BEGIN  
               SET @cReportType = 'PACKLIST'  
               SET @cPrintJobName = 'PRINT_PACKLIST'  
  
               SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
                        @cTargetDB = ISNULL(RTRIM(TargetDB), '')  
               FROM RDT.RDTReport WITH (NOLOCK)  
               WHERE StorerKey = @cStorerKey  
               AND   ReportType = @cReportType  
               AND   Function_ID = @nFunc     --SY01  
  
               --IF ISNULL(@cDataWindow, '') = ''  
               --BEGIN  
               --   SET @nErrNo = 101652  
               --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSETUP  
               --   GOTO Quit  
               --END  
  
               --IF ISNULL(@cTargetDB, '') = ''  
               --BEGIN  
               --   SET @nErrNo = 101653  
               --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TGETDB NOT SET  
               --   GOTO Quit  
               --END  
  
               --SET @nErrNo = 0  
               --EXEC RDT.rdt_BuiltPrintJob  
               --   @nMobile,  
               --   @cStorerKey,  
               --   @cReportType,  
               --   @cPrintJobName,  
               --   @cDataWindow,  
               --   @cPrinter_Paper,  
               --   @cTargetDB,  
               --   @cLangCode,  
               --   @nErrNo  OUTPUT,  
               --   @cErrMsg OUTPUT,  
               --   @cStorerKey,  
               --   @cOrderKey  
  
               --IF @nErrNo <> 0  
               --BEGIN  
               --   SET @nErrNo = 101654  
               --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSERTPRTFAIL  
               --   GOTO Quit  
               --END  
                 
               --(yeekung02)  
               INSERT INTO @tPackList (Variable, Value) VALUES ( '@cStorerKey',   @cStorerKey)  
               INSERT INTO @tPackList (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)  
  
               -- Print label  
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerkey, @cPrinter, @cPrinter_Paper,   
                  @cReportType, -- Report type  
                  @tPackList, -- Report params  
                  'rdt_841ExtUpdSP04',   
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT,  
                  '1',  
                  ''   
  
            END   -- end print  
  
            -- Print only if rdt report is setup (james08)  
            IF EXISTS (SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)  
                        WHERE StorerKey = @cStorerKey  
                        AND   ReportType = 'SHIPPLABEL'  
                        AND   1 = CASE WHEN Function_ID = @nFunc OR Function_ID = 0 THEN 1  
                                    ELSE 0 END)  
            BEGIN  
               SELECT @cLoadKey = ISNULL(RTRIM(LoadKey), ''),  
                        @cShipperKey = ISNULL(RTRIM(ShipperKey), '')  
               FROM dbo.Orders WITH (NOLOCK)  
               WHERE Storerkey = @cStorerkey  
               AND   Orderkey = @cOrderkey  
  
               IF ISNULL( @cShipperKey, '') = ''  
               BEGIN  
                  SET @nErrNo = 101655  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV SHIPPERKEY  
                  GOTO Quit  
               END  
  
               --(yeekung02)  
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cLoadKey',       @cLoadKey)  
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cShipperKey',    @cShipperKey)  
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',      @cOrderKey)   
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cTrackNo',       @cTrackNo)    
  
               -- Print label  
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerkey, @cPrinter, @cPrinter_Paper,   
                  'SHIPPLABEL', -- Report type  
                  @tSHIPPLABEL, -- Report params  
                  'rdt_841ExtUpdSP04',   
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT,  
                  '1',  
                  ''   
            END  
         END  
      END  
   END  
  
Quit:  

GO