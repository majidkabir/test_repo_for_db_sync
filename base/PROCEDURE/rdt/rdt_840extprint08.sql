SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_840ExtPrint08                                   */  
/* Purpose: Print label after pick = pack                               */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2020-03-25 1.0  James      WMS-12366. Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_840ExtPrint08] (  
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
   @nErrNo      INT           OUTPUT,   
   @cErrMsg     NVARCHAR( 20) OUTPUT  
)  
AS  
  
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @cPaperPrinter     NVARCHAR( 10),  
           @cLabelPrinter     NVARCHAR( 10),  
           @cUserName         NVARCHAR( 18),  
           @cLoadKey          NVARCHAR( 10),  
           @cShipperKey       NVARCHAR( 10),  
           @cFacility         NVARCHAR( 5),  
           @nExpectedQty      INT,  
           @nPackedQty        INT,  
           @nIsMoveOrder      INT,  
           @cDocType          NVARCHAR( 1),  
           @cShipLabel        NVARCHAR( 10),  
           @cPackList         NVARCHAR( 10),  
           @nShortPack        INT = 0,  
           @nOriginalQty      INT = 0,  
           @nPackQty          INT = 0  
  
   SELECT @cLabelPrinter = Printer,  
          @cFacility = Facility  
   FROM RDT.RDTMOBREC WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
  
   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 4  
      BEGIN  
         SELECT @cLoadKey = ISNULL(RTRIM(LoadKey), ''),  
                @cShipperKey = ISNULL(RTRIM(ShipperKey), '')  
         FROM dbo.Orders WITH (NOLOCK)  
         WHERE Storerkey = @cStorerkey  
         AND   Orderkey = @cOrderkey  

   DECLARE @cDataWindow   NVARCHAR( 50)    
          ,@cTargetDB     NVARCHAR( 20)    
          ,@cStatus       NVARCHAR( 10)    
          ,@cCartonNo     NVARCHAR( 5)   
          ,@cReportType   NVARCHAR( 10)  
          ,@cPrintJobName NVARCHAR( 60) 
          
         -- Get report info    
         SET @cDataWindow = ''    
         SET @cTargetDB = ''    
  
         IF EXISTS ( SELECT 1  
                     FROM dbo.PackDetail PD WITH (NOLOCK)  
                     JOIN dbo.PackInfo PIF WITH (NOLOCK)   
                        ON ( PD.PickSlipNo = PIF.PickSlipNo AND PD.CartonNo = PIF.CartonNo)  
                     WHERE PD.PickSlipNo = @cPickSlipNo  
                     AND   EXISTS ( SELECT 1 FROM dbo.CODELKUP CLK WITH (NOLOCK)   
                                    WHERE PIF.CartonType = CLK.Short   
                                    AND   CLK.ListName = 'HMCarton'  
                                    AND   CLK.UDF01= @cShipperKey  
                                    AND   CLK.UDF02= 'Letter'   
                                    AND   CLK.StorerKey = @cStorerKey))  
         BEGIN  
            SET @cReportType = 'LETTERHM'  
            SET @cPrintJobName = 'PRINT_LETTERHM'  
         END  
         ELSE  
         BEGIN  
            SET @cReportType = 'SHIPLBLHM'  
            SET @cPrintJobName = 'PRINT_SHIPPLABEL'  
         END  
  INSERT INTO TRACEINFO (TraceName, TimeIn, COL1, Col2, Col3, Col4, Col5) VALUES
  ('ABJP', GETDATE(), @cStorerKey, @cOrderKey, @nCartonNo, @cShipperKey, @nCartonNo)
         SELECT     
            @cDataWindow = ISNULL(RTRIM(DataWindow), ''),    
            @cTargetDB = ISNULL(RTRIM(TargetDB), '')   
         FROM RDT.RDTReport WITH (NOLOCK)     
         WHERE StorerKey = @cStorerKey    
            AND ReportType = @cReportType    
            AND (Function_ID = @nFunc OR Function_ID = 0)    
         ORDER BY Function_ID DESC --G01  
          
         -- Insert print job  (james15)  
         SET @nErrNo = 0                      
         EXEC RDT.rdt_BuiltPrintJob                       
            @nMobile,                      
            @cStorerKey,                      
            @cReportType,                      
            @cPrintJobName,                      
            @cDataWindow,                      
            @cLabelPrinter,                      
            @cTargetDB,                      
            @cLangCode,                      
            @nErrNo  OUTPUT,                       
            @cErrMsg OUTPUT,                      
            @cStorerKey,  
            @cOrderKey,  
            @nCartonNo,  
            @cShipperKey  
/*
         SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)  
         IF @cShipLabel = '0'  
            SET @cShipLabel = ''  
        
         IF @cShipLabel <> ''  
         BEGIN  
            DECLARE @tSHIPPLABEL AS VariableTable  
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cLoadKey',     @cLoadKey)  
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)  
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cShipperKey',  @cShipperKey)  
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nQty',         0)  
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nCartonNo',    @nCartonNo)  
            INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cStorerKey',   @cStorerkey)  
  
            -- Print label  
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '',   
               @cShipLabel, -- Report type  
               @tSHIPPLABEL, -- Report params  
               'rdt_840ExtPrint08',   
               @nErrNo  OUTPUT,  
               @cErrMsg OUTPUT   
         END  
         */
      END   -- IF @nStep = 4  
   END   -- @nInputKey = 1  
  
Quit:  

GO