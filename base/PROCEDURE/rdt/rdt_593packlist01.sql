SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593PackList01                                      */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2017-02-27 1.0  James    WMS1204. Created                               */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593PackList01] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- ASN
   @cParam2    NVARCHAR(20),  -- ID
   @cParam3    NVARCHAR(20),  -- SKU/UPC
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cLabelPrinter  NVARCHAR( 10)
          ,@cPaperPrinter  NVARCHAR( 10)
          ,@cPickSlipNo    NVARCHAR( 10)
          ,@cDataWindow    NVARCHAR( 50)  
          ,@cTargetDB      NVARCHAR( 20)   
          ,@cReportType    NVARCHAR(10) 


   -- Parameter mapping
   SET @cPickSlipNo = @cParam1
   
   -- Check blank
   IF @cPickSlipNo = ''
   BEGIN
      SET @nErrNo = 108101
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --PKSlipNo req
      GOTO Quit
   END

   IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND PickSlipNo = @cPickSlipNo)
   BEGIN
      SET @nErrNo = 108102
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid PKSlip
      GOTO Quit
   END

   -- Get login info
   SELECT @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobrec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   -- Check paper printer blank
   IF @cPaperPrinter = ''
   BEGIN
      SET @nErrNo = 108103
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrnterReq
      GOTO Quit
   END

   -- Get packing list report info
   SET @cDataWindow = ''
   SET @cTargetDB = ''
   SELECT 
      @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
      @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
   FROM RDT.RDTReport WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   ReportType = 'PACKLIST'
   AND   ( Function_ID = @nFunc OR Function_ID = 0)

   -- Check data window
   IF ISNULL( @cDataWindow, '') = ''
   BEGIN
      SET @nErrNo = 108104
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
      GOTO Quit
   END
   
   -- Check database
   IF ISNULL( @cTargetDB, '') = ''
   BEGIN
      SET @nErrNo = 108105
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
      GOTO Quit
   END

   EXEC RDT.rdt_BuiltPrintJob
      @nMobile,
      @cStorerKey,
      'PACKLIST',       -- ReportType
      'PRINT_PACKLIST', -- PrintJobName
      @cDataWindow,
      @cPaperPrinter,
      @cTargetDB,
      @cLangCode,
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT, 
      @cPickSlipNo

Quit:


GO