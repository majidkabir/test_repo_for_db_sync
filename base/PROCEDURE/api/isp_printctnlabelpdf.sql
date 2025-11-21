SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_PrintCtnLabelPDF                                */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: ToucPad Custom print                                        */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author    Purposes                                  */
/* 2021-05-19  1.0  Chermaine TPS-576 Created                           */
/************************************************************************/
CREATE   PROC [API].[isp_PrintCtnLabelPDF] (
	@cStorerKey       NVARCHAR( 15),
	@cFacility        NVARCHAR( 5),
   @cUserName        NVARCHAR( 18),
   @cPickslipNo      NVARCHAR( 30),
   @cOrderKey        NVARCHAR( 10),
   @cLabelPrinter    NVARCHAR( 30),
   @cPaperPrinter    NVARCHAR( 30),
   @nErrNo           INT OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cCartonLabel         NVARCHAR( 10)
   DECLARE @cPackList            NVARCHAR( 10)

   DECLARE
   	@cPrintSP         NVARCHAR(50),
      @cPathList        NVARCHAR(250),
      @cShipperList     NVARCHAR(150),
      @cConfigKey       NVARCHAR(30),
      @cPrinter         NVARCHAR(50),
      @cDimension       NVARCHAR(50),
      @cPdfFolder       NVARCHAR(150),
      @cArchiveFolder   NVARCHAR(150),
      @cShipperkey      NVARCHAR(15),
      @cShort           NVARCHAR(10),
      @cPrinterID       NVARCHAR(20),
      @cWinPrinter      NVARCHAR(128),
      @cWinPrinterName  NVARCHAR(100),
      @cReportType      NVARCHAR( 10),
      @cPrinterInGroup  NVARCHAR( 10),
      @cPrintFilePath   NVARCHAR(100),
      @cFilePath        NVARCHAR(100),
      @cFilePrefix      NVARCHAR( 30),
      @cFileName        NVARCHAR( 50),
      @cPrintCommand    NVARCHAR(MAX),
      @tRDTPrintJob      VariableTable

   DECLARE @tPathList TABLE (
      pathKey NVARCHAR(250)
   )

   SET @nErrNo   = 0
   SET @cErrMsg  = ''
   SET @cConfigKey = 'PACKUCC2PDF'
   SET @cReportType = 'TPCtnLbl'

   IF @cOrderKey <> ''
   BEGIN
   	SELECT @cShipperkey FROM ORDERS WITH (NOLOCK) WHERE Orderkey = @cOrderKey
   END

   --if pack by loadKey dont hav orderKey
   IF @cOrderKey = ''
   BEGIN
   	SELECT @cOrderKey    = ORDERS.OrderKey
           , @cShipperkey  = LTRIM(RTRIM(ISNULL(ORDERS.ShipperKey,'')))
      FROM PACKHEADER (NOLOCK)
      JOIN ORDERS (NOLOCK) ON PACKHEADER.Orderkey = ORDERS.Orderkey
      WHERE PACKHEADER.PickSlipNo = @cPickslipNo
   END


   /********* Printer **********/
   --define printer by codelkup
   SELECT @cShort = ISNULL(CL.Short,'')
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'MOMOLABEL'
   AND CL.Storerkey = @cStorerkey
   AND CL.Code = @cShipperkey

   IF @cShort = 'STORE'
   BEGIN
      SET @cPrinterID = @cLabelPrinter
   END
   ELSE IF @cShort = 'HOME'
   BEGIN
      SET @cPrinterID = @cPaperPrinter
   END

   ---- PDF use foxit then need use the winspool printer name
   --SELECT @cPrinterInGroup = PrinterID
   --FROM rdt.rdtReportToPrinter WITH (NOLOCK)
   --WHERE Function_ID = @nFunc
   --AND   StorerKey = @cStorerKey
   --AND   ReportType = @cReportType
   --AND   PrinterGroup = @cPrinterID

   SELECT @cWinPrinter = WinPrinter
   FROM rdt.rdtPrinter WITH (NOLOCK)
   --WHERE PrinterID = CASE WHEN ISNULL( @cPrinterInGroup, '') <> '' THEN @cPrinterInGroup ELSE @cPrinterID END
   WHERE PrinterID = @cPrinterID

   IF CHARINDEX(',' , @cWinPrinter) > 0
   BEGIN
      --SET @cPrinterName = @cPrinterInGroup
      SET @cWinPrinterName = LEFT( @cWinPrinter , (CHARINDEX(',' , @cWinPrinter) - 1) )
   END
   ELSE
   BEGIN
      --SET @cPrinterName =  @cPrinterInGroup
      SET @cWinPrinterName = @cWinPrinter
   END

   /********* pdf folder Path **********/
   SELECT
      @cPrintSP = option1,
      @cShipperKey = Option2,
      @cPathList = option5
   FROM storerConfig WITH (NOLOCK)
   where configKey = @cConfigKey
   AND storerKey = @cStorerKey

   INSERT INTO @tPathList
   SELECT LTRIM(RTRIM(ColValue)) FROM dbo.fnc_delimsplit ('@',@cPathList)

   --Folder Path
   SELECT @cPdfFolder = RIGHT(pathKey,LEN(pathKey)-CHARINDEX('=', pathKey)) FROM @tPathList WHERE pathKey LIKE 'c_PdfFolder%'
   SELECT @cArchiveFolder = RIGHT(pathKey,LEN(pathKey)-CHARINDEX('=', pathKey)) FROM @tPathList WHERE pathKey LIKE 'c_ArchiveFolder%'
   SELECT @cPrinter = RIGHT(pathKey,LEN(pathKey)-CHARINDEX('=', pathKey)) FROM @tPathList WHERE pathKey LIKE 'c_printer%'
   SELECT @cDimension = RIGHT(pathKey,LEN(pathKey)-CHARINDEX('=', pathKey)) FROM @tPathList WHERE pathKey LIKE 'c_Dimension%'

   SELECT
      @cPrintFilePath = Notes,
      @cFilePrefix = UDF01
   FROM codelkup WITH (NOLOCK)
   WHERE listName ='TPCtnLbl'
   AND Storerkey = @cStorerKey

   --SELECT
   --   @cPrintFilePath = Notes,
   --   @cFilePath = Code2,
   --   @cFilePrefix = UDF01
   --FROM dbo.CODELKUP WITH (NOLOCK)
   --WHERE LISTNAME = 'PrtbyShipK'
   --AND   Code = @cShipperKey
   --AND   StorerKey = @cStorerKey


   IF ISNULL( @cPdfFolder, '') <> ''
   BEGIN
      SET @cFilePrefix = @cFilePrefix + CASE WHEN ISNULL( @cFilePrefix, '') <> '' THEN '_' ELSE '' END
      SET @cFileName = @cFilePrefix + @cStorerkey+ '_' + RTRIM( @cOrderKey) + '.PDF'
      SET @cPrintCommand = '"' + @cPrintFilePath + '" "' + @cPdfFolder + '\' + @cFileName + '" "26" "2" "' + @cWinPrinterName + '"'

      DELETE FROM @tRDTPrintJob

      -- Print label (pass in shipperkey as label printer. then rdt_print will look for correct printer id)
      EXEC RDT.rdt_Print 0, '838', 'ENG', 0, 1, '', @cStorerKey, @cLabelPrinter, @cPaperPrinter,
         @cReportType,     -- Report type
         @tRDTPrintJob,    -- Report params
         'isp_PrintCtnLabelPDF',
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT,
         1,
         @cPrintCommand

         --IF @nErrNo <> 0 SET @cErrMsg = @cPrinterName
   END
   Quit:
END


GO