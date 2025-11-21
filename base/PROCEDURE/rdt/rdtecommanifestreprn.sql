SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdtEcomManifestReprn                                   */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2014-09-07 1.0  James    SOS317664 Created                              */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdtEcomManifestReprn] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- OrderKey  
   @cParam2    NVARCHAR(20),  
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
     
   DECLARE @cDataWindow       NVARCHAR( 50)  
          ,@cTargetDB         NVARCHAR( 20)  
          ,@cPrinter_Paper    NVARCHAR( 10)  
          ,@cIncoTerm         NVARCHAR( 10)  
          ,@cOrderKey         NVARCHAR( 10) 
          ,@cPickSlipNo       NVARCHAR( 10) 
          ,@nCartonNo         INT  
          ,@cLabelNo          NVARCHAR( 20) 
          ,@cReportType       NVARCHAR( 10)  
          ,@cPrintJobName     NVARCHAR( 50) 
          ,@cDocumentFilePath NVARCHAR( 1000) 
          ,@cToteNo           NVARCHAR( 18)


   SET @cOrderKey = ''
   SET @cToteNo = ''

   SET @cOrderKey = @cParam1
   SET @cToteNo = @cParam2

   -- To ToteNo value must not blank
   IF ISNULL( @cOrderKey, '') = '' AND ISNULL( @cToteNo, '') = ''
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'Value Required'
      GOTO Quit  
   END

   -- Get printer info  
   SELECT @cPrinter_Paper = Printer_Paper 
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  

   IF ISNULL( @cPrinter_Paper, '') = ''
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'A4 Prnter Req'
      GOTO Quit  
   END

   IF ISNULL( @cOrderKey, '') = ''
   BEGIN
      SELECT TOP 1 @cOrderKey = OrderKey 
      FROM dbo.PickDetailPD  WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey 
      WHERE PD.StorerKey = @cStorerKey
      AND   PD.DropID = @cToteNo
      AND   PD.[Status] = '5'
      AND   O.UserDefine05 <> '' --ECOMM
   END

   -- To ToteNo value must not blank
   IF ISNULL( @cOrderKey, '') = '' 
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'No OrderKey Found'
      GOTO Quit  
   END

   SET @cReportType = 'BAGMANFEST'                
   SET @cPrintJobName = 'PRINT_BAGMANFEST'        
        
   SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
          @cTargetDB = ISNULL(RTRIM(TargetDB), '')   
   FROM RDT.RDTReport WITH (NOLOCK)   
   WHERE StorerKey = @cStorerKey  
   AND ReportType = @cReportType                  
        
   IF ISNULL(RTRIM(@cDataWindow),'') = ''    
   BEGIN    
      SET @nErrNo = 1    
      SET @cErrMsg = 'Manfst NOT Setup'    
      GOTO Quit    
   END    
    
   IF ISNULL(RTRIM(@cTargetDB),'') = ''    
   BEGIN    
      SET @nErrNo = 1    
      SET @cErrMsg = 'No Target DB'  
      GOTO Quit    
   END    
     
   SET @nErrNo = 0  
   EXEC RDT.rdt_BuiltPrintJob   
      @nMobile,  
      @cStorerKey,  
      @cReportType,  
      @cPrintJobName,  
      @cDataWindow,  
      @cPrinter_Paper,  
      @cTargetDB,  
      @cLangCode,  
      @nErrNo  OUTPUT,  
      @cErrMsg OUTPUT,  
      @cStorerKey,  
      @cOrderkey,
      ' '         
     
   IF @nErrNo <> 0             
      GOTO Quit  

Quit:  

GO