SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_593CartonLBL03                                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2017-04-27 1.0  Ung        WMS-1612 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_593CartonLBL03] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- LabelNo
   @cParam2    NVARCHAR(20),
   @cParam3    NVARCHAR(20),
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cDataWindow   NVARCHAR( 50)
   DECLARE @cTargetDB     NVARCHAR( 20)
   DECLARE @cPickSlipNo   NVARCHAR( 10)
   DECLARE @cLabelNo      NVARCHAR( 20)
   DECLARE @nCartonNo     INT
   DECLARE @cPickMethod   NVARCHAR( 1)
   DECLARE @cFacility     NVARCHAR( 5)

   -- Parameter mapping
   SET @cLabelNo = @cParam1

   -- Check blank
   IF @cLabelNo = ''
   BEGIN
      SET @nErrNo = 108001
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LabelNo
      GOTO Quit
   END

   -- Get login info
   SELECT 
      @cLabelPrinter = Printer, 
      @cFacility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Check label printer
   IF @cLabelPrinter = ''
   BEGIN
      SET @nErrNo = 108002
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLabelPrinter
      GOTO Quit
   END

   -- Get report info
   SELECT 
      @cDataWindow = DataWindow, 
      @cTargetDB = TargetDB
   FROM rdt.rdtReport WITH (NOLOCK)
   WHERE ReportType = 'CARTONLBL'
      AND StorerKey = @cStorerKey
      AND (Function_ID = @nFunc OR Function_ID = 0)
   ORDER BY Function_ID DESC
   
   -- Check data window blank
   IF @cDataWindow = ''
   BEGIN
      SET @nErrNo = 108003
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
      GOTO Quit
   END

   -- Get PickDetail info
   SELECT TOP 1
      @cPickMethod = PickMethod
   FROM PickDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND Status <> '9'
      AND CaseID = @cLabelNo

   -- Check LabelNo valid
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 108004
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLabelNo
      GOTO Quit
   END

/*
   -- Check FCP
   IF @cPickMethod <> 'P'
   BEGIN
      SET @nErrNo = 108005
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not FCP carton
      GOTO Quit
   END
*/

   -- Get PackDetail info
   SELECT TOP 1
      @cPickSlipNo = PickSlipNo, 
      @nCartonNo = CartonNo
   FROM PackDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND LabelNo = @cLabelNo

   -- Insert print job
   SET @nErrNo = 0
   EXEC RDT.rdt_BuiltPrintJob
      @nMobile,
      @cStorerKey,
      'CARTONLBL',       -- ReportType
      'PRINT_CARTONLBL', -- PrintJobName
      @cDataWindow,
      @cLabelPrinter,
      @cTargetDB,
      @cLangCode,
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT,
      @cPickSlipNo, 
      @nCartonNo,
      @nCartonNo
  
Quit:
      

GO