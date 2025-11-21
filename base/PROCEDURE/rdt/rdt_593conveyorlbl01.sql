SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_593ConveyorLBL01                                      */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2017-04-13 1.0  Ung        WMS-1612 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_593ConveyorLBL01] (
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
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cDataWindow   NVARCHAR( 50)
   DECLARE @cTargetDB     NVARCHAR( 20)
   DECLARE @cOrderKey     NVARCHAR( 10)
   DECLARE @cDropID       NVARCHAR( 20)
   DECLARE @cPickMethod   NVARCHAR( 1)

   -- Parameter mapping
   SET @cDropID = @cParam1

   -- Check blank
   IF @cDropID = ''
   BEGIN
      SET @nErrNo = 107901
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need LabelNo
      GOTO Quit
   END

   -- Get login info
   SELECT @cLabelPrinter = Printer
   FROM rdt.rdtMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Check data window blank
   IF @cLabelPrinter = ''
   BEGIN
      SET @nErrNo = 107902
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLabelPrinter
      GOTO Quit
   END

   -- Get PickDetail info
   SELECT TOP 1
      @cOrderKey = OrderKey, 
      @cPickMethod = PickMethod
   FROM PickDetail (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND Status <> '9'
      AND DropID = @cDropID

   -- Check loose carton
   IF @cPickMethod = 'P'
   BEGIN
      SET @nErrNo = 107903
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotLooseCarton
      GOTO Quit
   END
   
   -- Get report info
   SELECT 
      @cDataWindow = DataWindow, 
      @cTargetDB = TargetDB
   FROM rdt.rdtReport WITH (NOLOCK)
   WHERE ReportType = 'CONVEYORLB'
      AND StorerKey = @cStorerKey
      AND (Function_ID = @nFunc OR Function_ID = 0)
   ORDER BY Function_ID DESC
      
   -- Check data window blank
   IF @cDataWindow = ''
   BEGIN
      SET @nErrNo = 107904
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
      GOTO Quit
   END

   -- Insert print job
   EXEC RDT.rdt_BuiltPrintJob
      @nMobile,
      @cStorerKey,
      'CONVEYORLB',       -- ReportType
      'PRINT_CONVEYORLB', -- PrintJobName
      @cDataWindow,
      @cLabelPrinter,
      @cTargetDB,
      @cLangCode,
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT,
      @cDropID,
      @cStorerKey
   
Quit:


GO