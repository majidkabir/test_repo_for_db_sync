SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdt_593ShipLabel01                                     */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2015-12-29 1.0  James    SOS353558 Created                              */ 
/* 2019-12-04 1.1  Grick    To Cater if more than 1 record in RDTReport-G01*/
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_593ShipLabel01] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- OrderKey  
   @cParam2    NVARCHAR(20),  -- Carton no
   @cParam3    NVARCHAR(20),    
   @cParam4    NVARCHAR(20),  
   @cParam5    NVARCHAR(20),  
   @nErrNo     INT OUTPUT,  
   @cErrMsg    NVARCHAR( 20) OUTPUT  
)  
AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @b_Success     INT  
     
   DECLARE @cDataWindow   NVARCHAR( 50)  
          ,@cTargetDB     NVARCHAR( 20)  
          ,@cLabelPrinter NVARCHAR( 10)  
          ,@cPaperPrinter NVARCHAR( 10)  
          ,@cOrderKey     NVARCHAR( 10)  
          ,@cLoadKey      NVARCHAR( 10)  
          ,@cShipperKey   NVARCHAR( 15) 
          ,@cStatus       NVARCHAR( 10)  
          ,@cCartonNo     NVARCHAR( 5) 
          ,@cPickSlipNo   NVARCHAR( 10)
          ,@cReportType   NVARCHAR( 10)
          ,@cPrintJobName NVARCHAR( 60)
   

   SET @cOrderKey = @cParam1
   SET @cCartonNo = ISNULL( @cParam2, '')

   -- Both value must not blank
   IF ISNULL(@cOrderKey, '') = '' 
   BEGIN
      SET @nErrNo = 59251  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --VALUE REQ
      GOTO Quit  
   END

   -- Check if it is valid OrderKey
   IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                   WHERE OrderKey = @cOrderKey 
                   AND   StorerKey = @cStorerKey)
    BEGIN  
      SET @nErrNo = 59252  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV ORDERS  
      GOTO Quit  
   END  

   SELECT @cStatus = [Status], 
          @cShipperKey = ShipperKey 
   FROM dbo.Orders WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey

   IF ISNULL( @cStatus, '') = '0'
    BEGIN  
      SET @nErrNo = 59253  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ORD NOT ALLOC
      GOTO Quit  
   END  

   IF ISNULL( @cShipperKey, '') = ''
   BEGIN  
      SET @nErrNo = 59254  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NO SHIPPER
      GOTO Quit  
   END  

   SELECT @cPickSlipNo = PickSlipNo
   FROM dbo.PackHeader WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey

   IF ISNULL( @cPickSlipNo, '') = ''
   BEGIN  
      SET @nErrNo = 59255  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NO PKSLIP NO
      GOTO Quit  
   END  

   IF ISNULL( @cCartonNo, '') <> ''
   BEGIN
      IF rdt.rdtIsValidQTY( @cCartonNo, 1) = 0
      BEGIN  
         SET @nErrNo = 59256  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV CARTON NO
         GOTO Quit  
      END  
   END

   -- Get printer info  
   SELECT   
      @cLabelPrinter = Printer,   
      @cPaperPrinter = Printer_Paper  
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
     
   /*-------------------------------------------------------------------------------  
  
                                    Print Ship Label  
  
   -------------------------------------------------------------------------------*/  
  
   -- Check label printer blank  
   IF @cLabelPrinter = ''  
   BEGIN  
      SET @nErrNo = 59257  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq  
      GOTO Quit  
   END  

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
      @cCartonNo,
      @cShipperKey

   IF @nErrNo <> 0
      GOTO Quit  

Quit:  

GO