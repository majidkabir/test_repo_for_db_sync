SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store procedure: rdt_Reprn_Barcode                                      */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2014-05-23 1.0  Ung      Created                                        */
/* 2020-02-24 1.1  Leong    INC1049672 - Revise BT Cmd parameters.         */
/***************************************************************************/

CREATE PROC [RDT].[rdt_Reprn_Barcode] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- Barcode
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

   DECLARE @cBarcode      NVARCHAR( 20)

   -- Screen mapping
   SET @cBarcode = @cParam1

   -- Check barcode
   IF @cBarcode = ''
   BEGIN
      SET @nErrNo = 88701
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Barcode
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
      GOTO Quit
   END
/*
   -- Get report info
   SET @cDataWindow = ''
   SET @cTargetDB = ''
   SELECT
      @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
      @cTargetDB = ISNULL(RTRIM(TargetDB), '')
   FROM RDT.RDTReport WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND ReportType = 'BARCODE'

   -- Get printer info
   SELECT
      @cLabelPrinter = Printer,
      @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Check label printer blank
   IF @cLabelPrinter = ''
   BEGIN
      SET @nErrNo = 88702
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
      GOTO Quit
   END

   -- Check data window
   IF ISNULL( @cDataWindow, '') = ''
   BEGIN
      SET @nErrNo = 88703
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
      GOTO Quit
   END

   -- Check database
   IF ISNULL( @cTargetDB, '') = ''
   BEGIN
      SET @nErrNo = 88704
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
      GOTO Quit
   END

   -- Insert print job
   EXEC RDT.rdt_BuiltPrintJob
      @nMobile,
      @cStorerKey,
      'BARCODE',
      'PRINT_BARCODE',
      @cDataWindow,
      @cLabelPrinter,
      @cTargetDB,
      @cLangCode,
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT,
      @cBarcode
*/
   DECLARE @cUserName NVARCHAR(18)
   SET @cUserName = SUSER_SNAME()

   -- Insert print job
   EXECUTE dbo.isp_BT_GenBartenderCommand
      @cPrinterID     = @cLabelPrinter,   -- printer id
      @c_LabelType    = 'CODELABEL',      -- label type
      @c_userid       = @cUserName,       -- user id
      @c_Parm01       = @cBarCode,        -- parm01
      @c_Parm02       = '',               -- parm02
      @c_Parm03       = '',               -- parm03
      @c_Parm04       = '',               -- parm04
      @c_Parm05       = '',               -- parm05
      @c_Parm06       = '',               -- parm06
      @c_Parm07       = '',               -- parm07
      @c_Parm08       = '',               -- parm08
      @c_Parm09       = '',               -- parm09
      @c_Parm10       = '',               -- parm10
      @c_StorerKey    = '',               -- StorerKey
      @c_NoCopy       = '1',              -- no of copy
      @b_Debug        = 0,                -- debug
      @c_Returnresult = 'N',              -- return result
      @n_err          = @nErrNo        OUTPUT,
      @c_errmsg       = @cErrMsg       OUTPUT

Quit:


GO