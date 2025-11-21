SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdtCtnManifestReprn                                    */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2014-01-23 1.0  James      SOS297732 Created                            */
/* 2014-03-19 1.1  James      Swap input parameter (james01)               */
/* 2023-10-05 1.2  James    WMS-23652 Able to print carton manifest by any */
/*                          packheader status by CODELKUP filter (james02) */
/***************************************************************************/

CREATE   PROC [RDT].[rdtCtnManifestReprn] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- OrderKey
   @cParam2    NVARCHAR(20),  -- Drop ID
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
          ,@cPaperPrinter NVARCHAR( 10)
          ,@cOrderKey     NVARCHAR( 10)
          ,@cDropID       NVARCHAR( 20)
          ,@cPickSlipNo   NVARCHAR( 10)
          ,@cPrintTemplateSP  NVARCHAR( 40)

   DECLARE @nByPassCheckPHStatus INT = 0
   
   -- Parameter mapping
   -- Note: Can pass in OrderKey only for printing whole pickslip
   --       Or pass in OrderKey + DropID for printing specific carton
   -- (james01)
   SET @cDropID = @cParam1
   SET @cOrderKey = @cParam2

   -- Check if both value blank
   IF ISNULL(@cOrderKey, '') = '' AND ISNULL(@cDropID, '') = ''
   BEGIN
      SET @nErrNo = 84501
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --VALUE REQ
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
      GOTO Quit
   END

   -- Check if it is valid orderkey
   IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                   WHERE OrderKey = @cOrderKey
                   AND   StorerKey = @cStorerKey)
    BEGIN
      SET @nErrNo = 84502
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV ORDERKEY
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
      GOTO Quit
   END

   IF EXISTS ( SELECT 1
               FROM dbo.CODELKUP WITH (NOLOCK)
               WHERE LISTNAME = 'REPORTCFG'
               AND   Code = 'BypassPackSTS'
               AND   Short = 'Y'
               AND   Storerkey = @cStorerKey)
      SET @nByPassCheckPHStatus = 1

   -- Check if pack confirmed
   IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                   WHERE OrderKey = @cOrderKey
                   AND [Status] = '9')
   BEGIN
   	IF @nByPassCheckPHStatus = 0
   	BEGIN
         SET @nErrNo = 84503
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --PACK NOT CONF
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
         GOTO Quit
      END
   END

   -- Get Pickslip
   SELECT @cPickSlipNo = PickSlipNo
   FROM dbo.PackHeader WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey
   AND   StorerKey = @cStorerKey
   AND   (( @nByPassCheckPHStatus = 1 AND [Status] = [Status]) OR (@nByPassCheckPHStatus = 0 AND [Status] = '9'))

   IF ISNULL(@cDropID, '') <> ''
   BEGIN
      -- Check if it is valid dropid
      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                      WHERE PickSlipNo = @cPickSlipNo
                      AND   DropID =  @cDropID
                      AND   StorerKey = @cStorerKey)
       BEGIN
         SET @nErrNo = 84504
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INV DROP ID
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Param2
         GOTO Quit
      END
   END

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
      SET @nErrNo = 84505
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
      GOTO Quit
   END

   -- Get report info
   SET @cDataWindow = ''
   SET @cTargetDB = ''
   SELECT
      @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
      @cTargetDB = ISNULL(RTRIM(TargetDB), ''),
      @cPrintTemplateSP = ISNULL(RTRIM(PrintTemplateSP), '')
   FROM RDT.RDTReport WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND ReportType = 'CTNMANFEST'

   -- Check data window
   IF ISNULL( @cDataWindow, '') = ''
   BEGIN
      SET @nErrNo = 84506
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
      GOTO Quit
   END

   -- Check database
   IF ISNULL( @cTargetDB, '') = ''
   BEGIN
      SET @nErrNo = 84507
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
      GOTO Quit
   END

   IF EXISTS ( SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   ReportType = 'CTNMANFEST'
               AND   ISNULL( PrintTemplate, '') = '') AND ISNULL( @cPrintTemplateSP, '') <> ''
   BEGIN
      SET @nErrNo = 84508
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PrintTPXSETUP
      GOTO Quit
   END

   IF ISNULL(@cDropID, '') = ''
      -- Insert print job
      EXEC RDT.rdt_BuiltPrintJob
         @nMobile,
         @cStorerKey,
         'CTNMANFEST',       -- ReportType
         'PRINT_CTNMANFEST', -- PrintJobName
         @cDataWindow,
         @cLabelPrinter,
         @cTargetDB,
         @cLangCode,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT,
         @cOrderKey,
         ''
   ELSE
         -- Insert print job
      EXEC RDT.rdt_BuiltPrintJob
         @nMobile,
         @cStorerKey,
         'CTNMANFEST',       -- ReportType
         'PRINT_CTNMANFEST', -- PrintJobName
         @cDataWindow,
         @cLabelPrinter,
         @cTargetDB,
         @cLangCode,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT,
         @cOrderKey,
         @cDropID
Quit:

GO