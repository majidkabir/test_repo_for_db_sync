SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdt_593Print10                                         */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2016-10-28 1.0  James    WMS621-Created                                 */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_593Print10] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- Label no  
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
          ,@cCartonNo     NVARCHAR( 20) 
          ,@cFacility     NVARCHAR( 5) 
          ,@cReportType   NVARCHAR( 10)
          ,@cPrintJobName NVARCHAR( 60)
   

   SET @cCartonNo = @cParam1

   SELECT @cFacility = Facility, 
          @cLabelPrinter = Printer
   FROM rdt.rdtMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   -- Both value must not blank
   IF ISNULL(@cCartonNo, '') = '' 
   BEGIN
      SET @nErrNo = 105101  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --CARTON NO REQ
      GOTO Quit  
   END

   -- Check if it is valid carton label
   IF NOT EXISTS ( SELECT 1 FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
                   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                   WHERE LLI.StorerKey = @cStorerKey
                   AND   LLI.ID = @cCartonNo
                   AND   LLI.Qty > 0
                   AND   LOC.Facility = @cFacility)
    BEGIN  
      SET @nErrNo = 105102  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV CARTON NO  
      GOTO Quit  
   END  

   /*-------------------------------------------------------------------------------  
  
                                    Print Pallet Label  
  
   -------------------------------------------------------------------------------*/  
  
   SET @cReportType = 'PALLETLBL3'
   SET @cPrintJobName = 'PRINT_PALLETLABEL'

   SELECT   
      @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
      @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
   FROM RDT.RDTReport WITH (NOLOCK)   
   WHERE StorerKey = @cStorerKey  
      AND ReportType = @cReportType  

   -- Check label printer blank  
   IF @cLabelPrinter = ''  
   BEGIN  
      SET @nErrNo = 105103  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LABELPRNTERREQ  
      GOTO Quit  
   END  

   -- Check data window blank  
   IF @cDataWindow = ''  
   BEGIN  
      SET @nErrNo = 105104  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup  
      GOTO Quit  
   END  

   -- Check target db blank  
   IF @cTargetDB = ''  
   BEGIN  
      SET @nErrNo = 105105  
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
      @cLabelPrinter,                    
      @cTargetDB,                    
      @cLangCode,                    
      @nErrNo  OUTPUT,                     
      @cErrMsg OUTPUT,                    
      @cCartonNo,
      @cStorerKey

   IF @nErrNo <> 0
      GOTO Quit  

Quit:  

GO