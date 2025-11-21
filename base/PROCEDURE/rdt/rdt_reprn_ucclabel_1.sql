SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_Reprn_UCCLabel_1                                   */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2014-04-22 1.0  Ung      SOS306082 Created                              */
/***************************************************************************/

CREATE PROC [RDT].[rdt_Reprn_UCCLabel_1] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- DropID
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
   DECLARE @cTargetDB     NVARCHAR( 20)
   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)

   DECLARE @cDropID       NVARCHAR( 20)
   DECLARE @cPickSlipNo   NVARCHAR( 10)
   DECLARE @cReportType   NVARCHAR( 10)
   DECLARE @cOrderKey     NVARCHAR( 10)
   DECLARE @cFromCartonNo NVARCHAR( 10)
   DECLARE @cToCartonNo   NVARCHAR( 10)

   SET @cPickSlipNo = ''
   SET @cFromCartonNo = ''
   SET @cToCartonNo = ''

   -- Parameter mapping
   SET @cDropID = @cParam1
   
   -- Check blank
   IF @cDropID = ''
   BEGIN
      SET @nErrNo = 86551
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need DropID
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
      GOTO Quit
   END

   -- Get PackDetail info
   SELECT TOP 1 
      @cPickSlipNo = PickSlipNo, 
      @cFromCartonNo = CartonNo, 
      @cToCartonNo = CartonNo
   FROM dbo.PackDetail WITH (NOLOCK) 
   WHERE DropID = @cDropID
      AND StorerKey = @cStorerKey

   -- Check PickSlip valid
   IF @@ROWCOUNT <> 1
   BEGIN
      SET @nErrNo = 86552
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid DropID
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- PSNO
      GOTO Quit
   END

   -- Get PackHeader info
   SELECT @cOrderKey = OrderKey FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo

   -- Get ReporType
   IF @cOrderKey <> '' 
      SET @cReportType = 'UCCLabel'    -- Discrete
   ELSE
      SET @cReportType = 'UCCLbConso'  -- Conso

   -- Get report info
   SET @cDataWindow = ''
   SET @cTargetDB = ''
   SELECT 
      @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
      @cTargetDB = ISNULL(RTRIM(TargetDB), '')
   FROM RDT.RDTReport WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
      AND ReportType = @cReportType

   -- Get printer info
   SELECT 
      @cLabelPrinter = Printer, 
      @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   /*-------------------------------------------------------------------------------

                                    Print SKU Label

   -------------------------------------------------------------------------------*/

   -- Check label printer blank
   IF @cLabelPrinter = ''
   BEGIN
      SET @nErrNo = 86553
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
      GOTO Quit
   END
      
   -- Check data window
   IF ISNULL( @cDataWindow, '') = ''
   BEGIN
      SET @nErrNo = 86554
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
      GOTO Quit
   END

   -- Check database
   IF ISNULL( @cTargetDB, '') = ''
   BEGIN
      SET @nErrNo = 86555
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
      GOTO Quit
   END
   
   DECLARE @cPrintJobName NVARCHAR(50)
   SET @cPrintJobName = 'PRINT_' + @cReportType
   
   -- Insert print job
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
      @cPickSlipNo, 
      @cFromCartonNo, 
      @cToCartonNo
Quit:


GO