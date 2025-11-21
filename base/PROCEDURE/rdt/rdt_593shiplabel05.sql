SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593ShipLabel05                                     */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2017-02-27 1.0  James    WMS1204. Created                               */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593ShipLabel05] (
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

   -- Parameter mapping
   SET @cCaseID = @cParam1

   -- Check blank
   IF @cCaseID = ''
   BEGIN
      SET @nErrNo = 108051
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --CaseID required
      GOTO Quit
   END

   SET @cUOM = ''
   SET @cPickSlipNo = ''
   SELECT @cUOM = UOM, @cPickSlipNo = PickSlipNo
   FROM dbo.PickDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   CaseID = @cCaseID

   --IF ISNULL( @cUOM, '') = ''
   --BEGIN
   --   SELECT @cUOM = UOM, @cPickSlipNo = PickSlipNo
   --   FROM dbo.PickDetail WITH (NOLOCK)
   --   WHERE StorerKey = @cStorerKey
   --   AND   DropID = @cCaseID
   --END

   IF ISNULL( @cUOM, '') = ''
   BEGIN
      SET @nErrNo = 108052
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid CaseID
      GOTO Quit
   END

   -- Get CartonNo
   --IF @cUOM = 2
   --   SELECT TOP 1 @nCartonNo = CartonNo, 
   --                  @cLabelNo = LabelNo
   --   FROM dbo.PackDetail WITH (NOLOCK) 
   --   WHERE PickSlipNo = @cPickSlipNo 
   --   AND   DropID = @cCaseID
   --ELSE
   SELECT TOP 1 @nCartonNo = CartonNo, 
                  @cLabelNo = LabelNo
   FROM dbo.PackDetail WITH (NOLOCK) 
   WHERE PickSlipNo = @cPickSlipNo 
   AND   LabelNo = @cCaseID

   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 108056
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --No Pack Rec
      GOTO Quit
   END

   -- Get login info
   SELECT @cLabelPrinter = Printer
   FROM rdt.rdtMobrec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   -- Check label printer blank
   IF @cLabelPrinter = ''
   BEGIN
      SET @nErrNo = 108053
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
   AND   ReportType = 'SHIPPLABEL'
   AND   ( Function_ID = @nFunc OR Function_ID = 0)

   -- Check data window
   IF ISNULL( @cDataWindow, '') = ''
   BEGIN
      SET @nErrNo = 108054
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
      GOTO Quit
   END
   
   -- Check database
   IF ISNULL( @cTargetDB, '') = ''
   BEGIN
      SET @nErrNo = 108055
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
      GOTO Quit
   END

   EXEC RDT.rdt_BuiltPrintJob
      @nMobile,
      @cStorerKey,
      'SHIPPLABEL',       -- ReportType
      'PRINT_SHIPPLABEL', -- PrintJobName
      @cDataWindow,
      @cLabelPrinter,
      @cTargetDB,
      @cLangCode,
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT, 
      @cPickSlipNo, 
      @nCartonNo,    -- Start CartonNo
      @nCartonNo,    -- End CartonNo
      @cLabelNo,     -- Start LabelNo
      @cLabelNo      -- End LabelNo

Quit:


GO