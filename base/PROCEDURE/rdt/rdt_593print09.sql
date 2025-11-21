SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdt_593Print09                                         */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2016-10-28 1.0  James    Created                                        */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_593Print09] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- OrderKey  
   @cParam2    NVARCHAR(20),  -- Label no
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

   -- Both value must not blank
   IF ISNULL(@cOrderKey, '') = '' 
   BEGIN
      SET @nErrNo = 105001  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ORDERKEY REQ
      GOTO Quit  
   END

   -- Check if it is valid OrderKey
   IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                   WHERE OrderKey = @cOrderKey 
                   AND   StorerKey = @cStorerKey)
    BEGIN  
      SET @nErrNo = 105002  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV ORDERS  
      GOTO Quit  
   END  

   SELECT @cStatus = [Status]
   FROM dbo.Orders WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey

   IF ISNULL( @cStatus, '') = '0'
    BEGIN  
      SET @nErrNo = 105003  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ORD NOT ALLOC
      GOTO Quit  
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
  


   SET @cReportType = 'BAGMANFEST'
   SET @cPrintJobName = 'PRINT_BAGMANFEST'

   SELECT   
      @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
      @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
   FROM RDT.RDTReport WITH (NOLOCK)   
   WHERE StorerKey = @cStorerKey  
      AND ReportType = @cReportType  

   -- Check label printer blank  
   IF @cPaperPrinter = ''  
   BEGIN  
      SET @nErrNo = 105004  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrnterReq  
      GOTO Quit  
   END  

   -- Check data window blank  
   IF @cDataWindow = ''  
   BEGIN  
      SET @nErrNo = 105005  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup  
      GOTO Quit  
   END  

   -- Check target db blank  
   IF @cTargetDB = ''  
   BEGIN  
      SET @nErrNo = 105006  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set  
      GOTO Quit  
   END  

   -- Insert print job 
   SET @nErrNo = 0                    
   EXEC RDT.rdt_BuiltPrintJob                     
      @nMobile,                    
      @cStorerKey,                    
      @cReportType,                    
      @cPrintJobName,                    
      @cDataWindow,                    
      @cPaperPrinter,                    
      @cTargetDB,                    
      @cLangCode,                    
      @nErrNo  OUTPUT,                     
      @cErrMsg OUTPUT,                    
      @cOrderKey,
      ''

   IF @nErrNo <> 0
      GOTO Quit  

Quit:  

GO