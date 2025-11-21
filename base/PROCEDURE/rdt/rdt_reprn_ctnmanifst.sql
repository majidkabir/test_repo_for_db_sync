SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_Reprn_CtnManifst                                   */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2014-03-20 1.0  Ung      SOS306082 Created                              */
/***************************************************************************/

CREATE PROC [RDT].[rdt_Reprn_CtnManifst] (
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

   DECLARE @b_Success     INT
   
   DECLARE @cDataWindow   NVARCHAR( 50)
   DECLARE @cTargetDB     NVARCHAR( 20)
   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)

   DECLARE @cPickSlipNo   NVARCHAR( 10)
   DECLARE @cChkStorerKey NVARCHAR( 15)
   DECLARE @cReportType   NVARCHAR( 10)
   DECLARE @cOrderKey     NVARCHAR( 10)

   -- Parameter mapping
   SET @cPickSlipNo = @cParam1

   -- Check blank
   IF @cPickSlipNo = ''
   BEGIN
      SET @nErrNo = 86501
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need PSNO
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
      GOTO Quit
   END

   -- Get PickSlip info
   SELECT 
      @cChkStorerKey = StorerKey, 
      @cOrderKey = OrderKey
   FROM dbo.PackHeader WITH (NOLOCK) 
   WHERE PickSlipNo = @cPickSlipNo

   -- Check PickSlip valid
   IF @@ROWCOUNT <> 1
   BEGIN
      SET @nErrNo = 86502
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --PSNO not exist
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- PSNO
      GOTO Quit
   END

   -- Check diff storer
   IF @cChkStorerKey <> @cStorerKey
   BEGIN
      SET @nErrNo = 86503
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff storer
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- PSNO
      GOTO Quit
   END

   -- Get ReporType
   IF @cOrderKey <> '' 
      SET @cReportType = 'CtnManifst' -- Discrete
   ELSE
      SET @cReportType = 'CtnMnfGrp'  -- Conso

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
      SET @nErrNo = 86504
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
      GOTO Quit
   END

   -- Get report info
   SET @cDataWindow = ''
   SET @cTargetDB = ''
   SELECT 
      @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
      @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
   FROM RDT.RDTReport WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
      AND ReportType = @cReportType
      
   -- Check data window
   IF ISNULL( @cDataWindow, '') = ''
   BEGIN
      SET @nErrNo = 86505
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
      GOTO Quit
   END

   -- Check database
   IF ISNULL( @cTargetDB, '') = ''
   BEGIN
      SET @nErrNo = 86506
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
      @cPickSlipNo
Quit:


GO