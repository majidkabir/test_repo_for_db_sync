SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593UCCLabel02                                      */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2017-02-27 1.0  James    WMS1204. Created                               */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593UCCLabel02] (
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
          ,@cUCCNo         NVARCHAR( 20)
          ,@cLabelNo       NVARCHAR( 20)
          ,@cPickSlipNo    NVARCHAR( 10)
          ,@cDataWindow    NVARCHAR( 50)  
          ,@cTargetDB      NVARCHAR( 20)   
          ,@cReportType    NVARCHAR(10) 
          ,@cCaseID        NVARCHAR( 20)
          ,@cUOM           NVARCHAR( 10)
          ,@nCartonNo      INT
          ,@cChkStatus     NVARCHAR(1)

   -- Parameter mapping
   SET @cUCCNo = @cParam1
   
   -- Check blank
   IF @cUCCNo = ''
   BEGIN
      SET @nErrNo = 106401
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UCC required
      GOTO Quit
   END

   -- Get UCC info
   SET @cChkStatus = ''
   SELECT @cChkStatus = Status
   FROM dbo.UCC WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   UCCNo = @cUCCNo
   
   -- Check UCC valid
   IF ISNULL( @cChkStatus, '') = ''
   BEGIN
      SET @nErrNo = 106402
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UCC not exists
      GOTO Quit
   END
   
   -- Check UCC picked/replenish
   IF @cChkStatus IN ('5', '6')
   BEGIN
      SET @nErrNo = 106403
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UCCPick/replen
      GOTO Quit
   END

   -- Get login info
   SELECT @cLabelPrinter = Printer
   FROM rdt.rdtMobrec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   -- Check label printer blank
   IF @cLabelPrinter = ''
   BEGIN
      SET @nErrNo = 106404
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
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
   AND   ReportType = 'UCCLABEL'
   AND   ( Function_ID = @nFunc OR Function_ID = 0)

   -- Check data window
   IF ISNULL( @cDataWindow, '') = ''
   BEGIN
      SET @nErrNo = 106405
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
      GOTO Quit
   END
   
   -- Check database
   IF ISNULL( @cTargetDB, '') = ''
   BEGIN
      SET @nErrNo = 106406
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
      GOTO Quit
   END

   -- Insert print job
   SET @nErrNo = 0                    

   EXEC RDT.rdt_BuiltPrintJob                     
      @nMobile,                    
      @cStorerKey,                    
      'UCCLABEL',                    
      'PRINT_UCCLABEL',                    
      @cDataWindow,                    
      @cLabelPrinter,                    
      @cTargetDB,                    
      @cLangCode,                    
      @nErrNo  OUTPUT,                     
      @cErrMsg OUTPUT,                    
      @cUCCNo,
      @cStorerKey

Quit:


GO