SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_593PrintCldFile02                                     */
/*                                                                            */
/* Copyright: Maersk                                                          */
/*                                                                            */
/* Purpose: PDF Reprint for HUDA Beauty                                       */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev    Author     Purposes                                      */
/* 2024-11-05 1.0.0  JCH507     FCR-870 Created                               */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_593PrintCldFile02] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 2),
   @cParam1    NVARCHAR(60),
   @cParam2    NVARCHAR(60),
   @cParam3    NVARCHAR(60), 
   @cParam4    NVARCHAR(60), 
   @cParam5    NVARCHAR(60),
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @bDebugFlag        BINARY = 0,
      @cOrderKey         NVARCHAR(10),
      @cExternOrderKey   NVARCHAR(10),
      @cLabelName        NVARCHAR(30),
      @cReportType       NVARCHAR(10),
      @cSourceType       NVARCHAR(10), 
      @cCondition        NVARCHAR(4000), 
      @cLabelSize        NVARCHAR(60), 
      @cFilePath         NVARCHAR(250), 
      @cFileName         NVARCHAR(250), 
      @cPrinterType      NVARCHAR(30),
      @nRowCount         INT,

      @cSQL              NVARCHAR(MAX),
      @cSQLParam         NVARCHAR(MAX),
      @cWebRequestURL    NVARCHAR( MAX),
      @cPrintDataFile         NVARCHAR( MAX),
      @cPrintDataFileEncrypt  NVARCHAR( MAX),
      @cPrintDataFileEncode   NVARCHAR( MAX),
      @cPrintDataFileFull     NVARCHAR( MAX),
      @cCloudClientPrinterID  NVARCHAR( 100),
      @cDCropWidth            NVARCHAR( 10)= '' ,
      @cDCropHeight           NVARCHAR( 10)= '',
      @cIsLandScape           NVARCHAR( 1) = '',
      @cIsColor               NVARCHAR( 1) = '',
      @cIsDuplex              NVARCHAR( 1) = '',
      @cIsCollate             NVARCHAR( 1) = '',
      @cPaperSize             NVARCHAR( 20),
      @cPDFPreview            NVARCHAR( 20),
      @cJobStatus             NVARCHAR(1) = '9',
      @nJobID                 INT,
      @cLabelPrinter          NVARCHAR( 10),
      @cPaperPrinter          NVARCHAR( 10),
      @cRptDesc               NVARCHAR( 60),
      @cPrinter               NVARCHAR( 10),
      @cRptPaperType          NVARCHAR( 10),
      @nRptNoOfCopy           INT,
      @cRptDataWindow         NVARCHAR( 50),
      @b_Success              INT,
      @c_VbErrMsg             NVARCHAR( MAX),
      @nRtnCnt                INT

   -- fetch extern order key 
   SET @cOrderKey = @cParam1
   SELECT TOP 1 @cExternOrderKey = ExternOrderKey FROM dbo.ORDERS WITH(NOLOCK) WHERE OrderKey = @cOrderKey
   
   -- fetch print code data
   SELECT 
      @cLabelName = Code, 
      @cSourceType = Short, 
      @cCondition = Notes, 
      @cLabelSize = UDF01, 
      @cFilePath = UDF02, 
      @cFileName = UDF03, 
      @cPrinterType = code2
   FROM
   dbo.CODELKUP WITH(NOLOCK)
   WHERE LISTNAME = 'PACKPRTCON'
      AND StorerKey = @cStorerKey
      AND Short = 'SFTP'
      AND Code IN (
         SELECT 
            code2 
         FROM dbo.CODELKUP WITH(NOLOCK) 
         WHERE LISTNAME = 'RDTLBLRPT' 
            AND StorerKey = @cStorerKey
            AND ISNULL(code2, '') <> ''
            AND Long = 'rdt_593PrintCldFile02'
            AND Code = @cOption
      )

   SELECT @nRowCount = @@ROWCOUNT
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 228501
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- FETCH CODE FAILED
   END
   
   SELECT @cReportType = @cLabelName
   
   IF ISNULL(@cCondition,'') = '' OR CHARINDEX('all',@cCondition) > 0
   BEGIN
      SET @cCondition = ''
   END
   -- build sql
   SET @cSQL = 'SELECT @nRtnCnt = COUNT(1) FROM dbo.ORDERS orders WITH (NOLOCK) WHERE orders.OrderKey = @cOrderKey '
      + CASE WHEN @cCondition <> '' THEN 'AND ' + @cCondition ELSE '' END
   SET @cSQLParam = '@nRtnCnt INT OUTPUT, @cOrderKey NVARCHAR(10)'
   BEGIN TRY
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
         @nRtnCnt = @nRtnCnt OUTPUT,
         @cOrderKey = @cOrderKey
   END TRY
   BEGIN CATCH
      DECLARE @cSQLErrorMessage NVARCHAR(MAX)
      SELECT @cSQLErrorMessage = ERROR_MESSAGE()
      SET @nErrNo = 228502
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP')      -- Invalid Condition
      EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @cErrMsg, @cLabelName, @cCondition, @cSQLErrorMessage
      GOTO Quit
   END CATCH
   -- check url prefix cfg
   SELECT @cWebRequestURL = WebRequestURL
   FROM WebServiceCfg WITH (NOLOCK)
   WHERE DataProcess = 'FNGETFILE'
      AND ActiveFlag = 1
   -- URL prifix verify
   IF ISNULL(@cWebRequestURL, '') = ''
   BEGIN
      SET @nErrNo = 228503
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- MissWebSrvc
      GOTO Quit
   END
   -- build file path
   SELECT @cFilePath=LTRIM(RTRIM(@cFilePath))
   IF RIGHT(@cFilePath,1) IN ('\','/')
   BEGIN
      SELECT @cPrintDataFile = @cFilePath 
         + REPLACE(REPLACE(@cFileName,'<code>',@cLabelName),'<ExternOrderkey>',@cExternOrderKey)
   END
   ELSE BEGIN
      SELECT @cPrintDataFile = @cFilePath 
         + '/' + REPLACE(REPLACE(@cFileName,'<code>',@cLabelName),'<ExternOrderkey>',@cExternOrderKey)
   END

   IF @bDebugFlag = 1
   BEGIN
      SELECT @cPrintDataFile = 'C:\\targetdir\\filename.PDF'
   END
   -- encrypt file path
   BEGIN TRY
      SELECT @cPrintDataFileEncrypt = MASTER.DBO.fnc_CryptoEncrypt(@cPrintDataFile, '')
   END TRY
   BEGIN CATCH
      SET @nErrNo = 228504
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Failed to encrypt file path
   END CATCH
   IF @nErrNo <> 0
   BEGIN
      GOTO Quit
   END
   -- encode url
   EXEC MASTER.DBO.isp_URLEncode
      @c_InputString = @cPrintDataFileEncrypt,
      @c_OutputString = @cPrintDataFileEncode OUTPUT,
      @c_VbErrMsg = @c_VbErrMsg OUTPUT
   -- build whole uri
   SET @cPrintDataFileFull = @cWebRequestURL + @cPrintDataFileEncode
   SELECT TOP 1
      @cRptDataWindow = DataWindow,                
      @cRptPaperType = PaperType,
      @nRptNoOfCopy = NoOfCopy
   FROM rdt.rdtReport WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND ReportTYpe = @cReportType
      AND (Function_ID = @nFunc OR Function_ID = 0)
   ORDER BY Function_ID DESC
   
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 228505
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Miss Cloud Printer ID
      EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @cErrMsg, @cReportType
      GOTO Quit
   END
   
   IF @cRptPaperType = 'LABEL'
      SET @cPrinter = @cLabelPrinter
   ELSE
      SET @cPrinter = @cPaperPrinter                  
   --Verify printer
   SELECT @cCloudClientPrinterID= CloudPrintClientID
      FROM rdt.rdtprinter WITH (NOLOCK) 
      WHERE PrinterID = @cPrinter
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 228506
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PrinterNotExists
      GOTO Quit
   END
   IF ISNULL(@cCloudClientPrinterID, '') = ''
   BEGIN
      SET @nErrNo = 228507
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- MissCldPrntID
      GOTO Quit
   END
   
   --Prepare print job data
   SELECT   @cDCropWidth  =  DCropWidth
            ,@cDCropHeight = DCropHeight
            ,@cIsLandScape = IsLandScape
            ,@cIsColor     = IsColor    
            ,@cIsDuplex    = IsDuplex   
            ,@cIsCollate   = IsCollate  
            ,@cPaperSize   = PaperSizeWxH  
   FROM rdt.rdtReportdetail (NOLOCK)
   WHERE reporttype = @cReportType
      AND Storerkey = @cStorerKey
      AND Function_ID = @nFunc
   SET @cDCropWidth    = CASE WHEN ISNULL(@cDCropWidth , '') = '' THEN '' ELSE @cDCropWidth  END
   SET @cDCropHeight   = CASE WHEN ISNULL(@cDCropHeight, '') = '' THEN '' ELSE @cDCropHeight END
   SET @cIsLandScape   = CASE WHEN ISNULL(@cIsLandScape, '') = '' THEN '' ELSE @cIsLandScape END
   SET @cIsColor       = CASE WHEN ISNULL(@cIsColor    , '') = '' THEN '' ELSE @cIsColor     END
   SET @cIsDuplex      = CASE WHEN ISNULL(@cIsDuplex   , '') = '' THEN '' ELSE @cIsDuplex    END
   SET @cIsCollate     = CASE WHEN ISNULL(@cIsCollate  , '') = '' THEN '' ELSE @cIsCollate   END
   SET @cPaperSize     = CASE WHEN ISNULL(@cPaperSize  , '') = '' THEN '' ELSE @cPaperSize   END
   SET @cCloudClientPrinterID = CASE WHEN ISNULL(@cCloudClientPrinterID  , '') = '' THEN '' ELSE @cCloudClientPrinterID   END
   
   INSERT INTO rdt.rdtPrintJob (
      JobName, ReportID, JobStatus, Datawindow, Parm1, Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, StorerKey,
      Function_ID, PaperSizeWxH, DCropWidth, DCropHeight, IsLandScape, IsColor, IsDuplex, IsCollate)
   VALUES(
      'rdt_539PrintCldFile02', @cReportType, @cJobStatus, @cRptDataWindow, @cExternOrderKey, @cPrinter, @nRptNoOfCopy, @nMobile, DB_NAME(), @cPrintDataFileFull, 'LogiReport', @cStorerKey,
      @nFunc, @cPaperSize, @cDCropWidth, @cDCropHeight, @cIsLandScape, @cIsColor, @cIsDuplex, @cIsCollate)
   SELECT @nJobID = SCOPE_IDENTITY(), @nErrNo = @@ERROR
   IF @nErrNo <> 0
   BEGIN
      SET @nErrNo = 228508
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PrnJobFail
      GOTO Quit
   END
   --Submit to cloud print task
   EXEC isp_UpdateRDTPrintJobStatus
         @n_JobID = @nJobID,
         @c_JobStatus = @cJobStatus,  --9
         @c_JobErrMsg = '',
         @b_Success = @b_Success OUTPUT,
         @n_Err  = @nErrNo OUTPUT,
         @c_ErrMsg = @cErrMsg OUTPUT,
         @c_PrintData = @cPrintDataFileFull
   IF @b_Success <> 1
   BEGIN
      SET @nErrNo = 228509
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SubCldPrtFail
      GOTO Quit
   END


   Quit:
END

GO