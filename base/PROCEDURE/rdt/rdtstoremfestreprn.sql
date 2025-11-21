SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdtStoreMfestReprn                                    */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2014-06-05 1.0  James    SOS304122 Created                              */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdtStoreMfestReprn] (  
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
     
   DECLARE @cDataWindow    NVARCHAR( 50)  
          ,@cTargetDB      NVARCHAR( 20)  
          ,@cPrinter_Paper NVARCHAR( 10)  
          ,@cToToteNo      NVARCHAR( 18)  
          ,@cReportType    NVARCHAR( 10)  
          ,@cPrintJobName  NVARCHAR( 50)  

   SET @cToToteNo = ''

   SET @cToToteNo = @cParam1

   -- To ToteNo value must not blank
   IF ISNULL(@cToToteNo, '') = '' 
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'Tote No required'
      GOTO Quit  
   END

   IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                   WHERE StorerKey = @cStorerKey 
                   AND   DropID = @cToToteNo)
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'Tote Not Found'
      GOTO Quit  
   END

   -- Get printer info  
   SELECT @cPrinter_Paper = Printer_Paper  
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  

   IF ISNULL( @cPrinter_Paper, '') = ''
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'A4 Printer Req'
      GOTO Quit  
   END

   SET @cReportType = 'SORTMANFES'      
   SET @cPrintJobName = 'PRINT_SORTMANFES'      
      
      
   SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),      
          @cTargetDB = ISNULL(RTRIM(TargetDB), '')      
   FROM RDT.RDTReport WITH (NOLOCK)      
   WHERE StorerKey = @cStorerKey      
   AND   ReportType = @cReportType      
      
   IF ISNULL(@cDataWindow, '') = ''      
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'DW NOT SETUP'
      GOTO Quit  
   END
      
   IF ISNULL(@cTargetDB, '') = ''      
   BEGIN      
      SET @nErrNo = 1  
      SET @cErrMsg = 'TARGET DB NOT SET'
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
      @cToToteNo      
      
   IF @nErrNo <> 0      
      GOTO Quit     

Quit:  

GO