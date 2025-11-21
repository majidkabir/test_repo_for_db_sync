SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdtAEODspLblnPackLst                                   */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2013-07-02   1.0  Ung      SOS282743 Created                            */
/***************************************************************************/

CREATE PROC [RDT].[rdtAEODspLblnPackLst] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- Carton ID
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

   DECLARE @cDataWindow   NVARCHAR( 50)
   DECLARE @cTargetDB     NVARCHAR( 20)
   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)

   DECLARE @cPickSlipNo   NVARCHAR( 10)
   DECLARE @cStatus       NVARCHAR( 1)
   DECLARE @nCartonNo     INT

   SET @cPickSlipNo = ''
   SET @cStatus = ''

   -- Check blank
   IF @cParam1 = ''
   BEGIN
      SET @nErrNo = 81551
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Need Carton ID
      EXEC rdt.rdtSetFocusField @nMobile, 2 --Param1
      GOTO Quit
   END

   -- Get carton info
   SELECT TOP 1 
      @cPickSlipNo = PH.PickSlipNo, 
      @cStatus = Status, 
      @nCartonNo = CartonNo
   FROM dbo.PackHeader PH WITH (NOLOCK) 
      JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
   WHERE PH.StorerKey = @cStorerKey
      AND PD.DropID = @cParam1 -- CartonID

   -- Carton ID valid
   IF @cPickSlipNo = ''
   BEGIN
      SET @nErrNo = 81552
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Bad CartonID
      GOTO Quit
   END

   -- Check order status
   IF @cStatus <> '9'
   BEGIN
      SET @nErrNo = 81553
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NotPackConfirm
      GOTO Quit
   END

   -- Get printer info
   SELECT 
      @cLabelPrinter = Printer, 
      @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   /*-------------------------------------------------------------------------------

                                  Print dispatch label

   -------------------------------------------------------------------------------*/
   -- Check label printer blank
   IF @cLabelPrinter = ''
   BEGIN
      SET @nErrNo = 81554
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
      AND ReportType = 'DESPATCHTK'
      
   -- Check data window
   IF ISNULL( @cDataWindow, '') = ''
   BEGIN
      SET @nErrNo = 81555
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
      GOTO Quit
   END

   -- Check database
   IF ISNULL( @cTargetDB, '') = ''
   BEGIN
      SET @nErrNo = 81556
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
      GOTO Quit
   END
      
   -- Insert print job
   EXEC RDT.rdt_BuiltPrintJob
      @nMobile,
      @cStorerKey,
      'DESPATCHTK',       -- ReportType
      'PRINT_DESPATCHTK', -- PrintJobName
      @cDataWindow,
      @cLabelPrinter,
      @cTargetDB,
      @cLangCode,
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT, 
      @cStorerKey, 
      @cPickSlipNo, 
      @nCartonNo,  -- Start CartonNo
      @nCartonNo   -- End CartonNo

   /*-------------------------------------------------------------------------------

                                  Print packing list

   -------------------------------------------------------------------------------*/
   -- Last carton
   IF (SELECT MAX( CartonNo) FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo) = @nCartonNo
   BEGIN
      -- Check paper printer blank
      IF @cPaperPrinter = ''
      BEGIN
         SET @nErrNo = 81557
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
         AND ReportType = 'PACKLIST'
         
      -- Check data window
      IF ISNULL( @cDataWindow, '') = ''
      BEGIN
         SET @nErrNo = 81558
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
         GOTO Quit
      END
   
      -- Check database
      IF ISNULL( @cTargetDB, '') = ''
      BEGIN
         SET @nErrNo = 81559
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
         GOTO Quit
      END
   
      -- Insert print job
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
   END
Quit:


GO