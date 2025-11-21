SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdtStoreLabelReprn                                    */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2014-06-05 1.0  James    SOS304122 Created                              */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdtStoreLabelReprn] (  
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
     
   DECLARE @cDataWindow   NVARCHAR( 50)  
          ,@cTargetDB     NVARCHAR( 20)  
          ,@cLabelPrinter NVARCHAR( 10)  
          ,@cPaperPrinter NVARCHAR( 10)  
          ,@cToToteNo     NVARCHAR( 18)  
          ,@cOrderKey     NVARCHAR( 10) 
          ,@cTrackNo      NVARCHAR( 20) 
          ,@cPickSlipNo   NVARCHAR( 10)
          ,@cLabelNo      NVARCHAR( 20) 
          ,@cPrintJobName NVARCHAR( 50) 
          ,@cReportType   NVARCHAR( 10)
          ,@nCartonNo     INT 
          ,@bSuccess      INT 

   SET @cToToteNo = ''

   SET @cToToteNo = @cParam1

   -- To ToteNo value must not blank
   IF ISNULL(@cToToteNo, '') = '' 
   BEGIN
      SET @cErrMsg = 'VALUE REQ'
      GOTO Quit  
   END

   -- Get printer info  
   SELECT @cLabelPrinter = Printer 
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  

   IF ISNULL( @cLabelPrinter, '') = ''
   BEGIN
      SET @cErrMsg = 'Label Prnter Req'
      GOTO Quit  
   END

   SELECT @cOrderKey = PH.OrderKey, @cPickSlipNo = PH.PickSlipNo 
   FROM dbo.PackHeader PH WITH (NOLOCK) 
   JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipno = PD.PickSlipNo)
   WHERE PH.StorerKey = @cStorerKey
   AND   PD.DropID = @cToToteNo

   -- Check if it is valid Sacks/Tote
   IF ISNULL( @cOrderKey, '') = ''
    BEGIN  
      SET @cErrMsg = 'Invalid Sacks'
      GOTO Quit  
   END  

   IF EXISTS ( SELECT 1 
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE PickSlipNo = @cPickSlipNo
               AND   DropID = @cToToteNo
               AND   LabelNo = '') 
   BEGIN  
      SET @cErrMsg = 'Label Not Found'
      GOTO Quit  
   END
      
   SET @cReportType = 'SORTLABEL'      
   SET @cPrintJobName = 'PRINT_SORTLABEL'      

   -- Get report info  
   SET @cDataWindow = ''  
   SET @cTargetDB = ''  

   SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),      
          @cTargetDB = ISNULL(RTRIM(TargetDB), '')      
   FROM RDT.RDTReport WITH (NOLOCK)      
   WHERE StorerKey = @cStorerKey      
   AND   ReportType = @cReportType      

   IF ISNULL(@cDataWindow, '') = ''  
   BEGIN  
      SET @cErrMsg = 'No Data Window Found'
      GOTO Quit  
   END

   IF ISNULL(@cTargetDB, '') = '' 
   BEGIN  
      SET @cErrMsg = 'No Target DB Found'
      GOTO Quit  
   END
   
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
      @cToToteNo      

   GOTO Quit  

Quit:  

GO