SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_593Print40                                            */
/*                                                                            */
/* Copyright: Maersk                                                          */
/*                                                                            */
/* Purpose: Cloud PDF printing for ForeverNew                                 */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2024-06-20 1.0  JACKC      FCR-348 Created                                 */
/* 2024-08-13 1.1  JACKC      FCR-716 Retrieve print data by OrderKey         */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_593Print40] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(60),  -- ExternalOrderKey
   @cParam2    NVARCHAR(60),
   @cParam3    NVARCHAR(60),
   @cParam4    NVARCHAR(60),
   @cParam5    NVARCHAR(60),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   -- business variable
   DECLARE  @cOrderType       NVARCHAR( 10),
            @cOrderKey        NVARCHAR( 10),
            @cExternOrderKey  NVARCHAR( 50),
            @cPrinter         NVARCHAR( 10),

   --printing variable  
            @b_Success              INT,
            @n_Err                  INT,
            @c_ErrMsg               NVARCHAR( 250),
            @cLabelPrinter          NVARCHAR( 10),
            @cPaperPrinter          NVARCHAR( 10),
            @cReportType            NVARCHAR( 10),
            @cRptDesc               NVARCHAR( 60),
            @cRptProcessType        NVARCHAR( 15),
            @cRptPaperType          NVARCHAR( 10),
            @nRptNoOfCopy           INT,
            @cTargetDB              NVARCHAR( 20),
            @cDataWindow            NVARCHAR( 50),
            @cPrintData             NVARCHAR( MAX),
            @cWebRequestURL         NVARCHAR( 500),
            @cCloudClientPrinterID  NVARCHAR( 100),
            @cDCropWidth            NVARCHAR( 10)= '' ,
            @cDCropHeight           NVARCHAR( 10)= '',
            @cIsLandScape           NVARCHAR( 1) = '',
            @cIsColor               NVARCHAR( 1) = '',
            @cIsDuplex              NVARCHAR( 1) = '',
            @cIsCollate             NVARCHAR( 1) = '',
            @cPaperSize             NVARCHAR( 20),
            @cPDFPreview            NVARCHAR( 20),

   --Print Job
            @cJobStatus    NVARCHAR(1) = '9',
            @nJobID        INT,

            @cFacility     NVARCHAR(5),
            @bDebugFlag    BINARY = 0

   
   -- Get Default Printer
   SELECT   @cLabelPrinter = ISNULL(Printer,'')
            ,@cPaperPrinter = ISNULL(Printer_Paper,'')
            ,@cFacility = ISNULL(Facility, '')
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nFunc = 593
   BEGIN
      IF @nStep = 2
      BEGIN
         SET @cExternOrderKey = @cParam1

         -- Check blank
         IF @cExternOrderKey = ''
         BEGIN
            SET @nErrNo = 217101
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- External Order required
            GOTO Quit
         END
      
         -- Get order info
         SELECT @cOrderKey = OrderKey
               ,@cOrderType = ISNULL([Type], '')
         FROM ORDERS WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND ExternOrderKey = @cExternOrderKey
            AND Facility = @cFacility

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 217102
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Order Not Found
            GOTO Quit
         END

         IF @cOrderType <> 'B2C'
         BEGIN
            SET @nErrNo = 217103
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid Order Type
            GOTO Quit
         END

         -- Get report type
         /*SELECT @cReportType = ISNULL(code2, '')
         FROM CODELKUP WITH (NOLOCK)
         WHERE LISTNAME = 'RDTLBLRPT'
            AND Storerkey = @cStorerKey
            AND Code = @cOption
         
         IF @cReportType = ''
         BEGIN
            SET @nErrNo = 217104
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- MissReportInCODE
            GOTO Quit
         END*/

         --Check Web Service cfg
         SELECT @cWebRequestURL = WebRequestURL
         FROM WebServiceCfg WITH (NOLOCK)
         WHERE DataProcess = 'FNGETFILE'
            AND ActiveFlag = 1

         IF ISNULL(@cWebRequestURL, '') = ''
         BEGIN
            SET @nErrNo = 217108
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- MissWebSrvc
            GOTO Quit
         END

         ----------------------------------------------------Main Logic----------------------------------------------------

         DECLARE @tReport TABLE
         (
               RowRef      INT IDENTITY( 1, 1),
               ReportType  NVARCHAR(10)
         )

         INSERT INTO @tReport (ReportType)
         SELECT 'SHIPLABEL'
         UNION ALL
         SELECT 'INVOICE'

         DECLARE  @nCounter   INT = 1,
                  @nMaxRow    INT = 0    

         IF @bDebugFlag = 1
         BEGIN
            SELECT 'ReportList'
            SELECT * From @tReport
         END

         -- Go through all report
         SELECT @nMaxRow = COUNT(1)
         FROM @tReport

         IF @nMaxRow = 0
         BEGIN
            SET @nErrNo = 217112
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoReportPrint
            GOTO Quit
         END

         -- Print each report
         WHILE @nCounter <= @nMaxRow
         BEGIN
            -- Get Report Type
            SET @cPrintData = '' --V1.1 clear PrintData value by Jackc

            SELECT @cReportType = ReportType
            FROM @tReport
            WHERE RowRef = @nCounter

            IF @bDebugFlag = 1
               SELECT 'Loop', @nCounter AS Counter, @cReportType AS ReportType

            IF ISNULL(@cReportType, '') = ''
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Empty report type, jump to next'
               CONTINUE
            END

            --Get Report info
            SELECT @cRptPaperType = PaperType
                  ,@cRptDesc  = RptDesc
                  ,@cRptProcessType = ProcessType
                  ,@nRptNoOfCopy = NoOfCopy
                  ,@cTargetDB = TargetDB
            FROM rdt.RDTReport WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND ReportType = @cReportType
               AND ProcessType = 'CLOUDPRINT'
               AND Function_ID = @nFunc

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 217105
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Report Not Found
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
               SET @nErrNo = 217106
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PrinterNotExists
               GOTO Quit
            END

            IF ISNULL(@cCloudClientPrinterID, '') = ''
            BEGIN
               SET @nErrNo = 217107
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- MissCldPrntID
               GOTO Quit
            END


            -- Get the PDF path
            IF @bDebugFlag = 1
               SELECT 'Get File Path from DocInfo', @cExternOrderKey AS ExtOrdKey, @cReportType AS ReportType

            SELECT @cPrintData = [data]
            FROM DocInfo WITH (NOLOCK)
            WHERE TableName = 'EXTORDDOC'
               AND Key1 = @cOrderKey --V1.1 FCR-716 by Jackc
               AND Key2 = @cReportType
               AND Key3 = (CASE WHEN @cRptPaperType = 'LABEL' THEN 'LABEL' ELSE 'PAPER' END) 
               AND StorerKey = @cStorerKey

            IF ISNULL(@cPrintData, '') = ''
            BEGIN
               SET @nErrNo = 217109
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- GetFilePathFail
               GOTO Quit
            END

            --Build URL
            SET @cPrintData = @cWebRequestURL + @cPrintData

            IF @bDebugFlag = 1
               SELECT 'URL', @cPrintData

            --Prepare print job data
            SELECT   @cDCropWidth  =  DCropWidth
                     ,@cDCropHeight = DCropHeight
                     ,@cIsLandScape = IsLandScape
                     ,@cIsColor     = IsColor    
                     ,@cIsDuplex    = IsDuplex   
                     ,@cIsCollate   = IsCollate  
                     ,@cPaperSize   = PaperSizeWxH  
            FROM rdt.rdtReportdetail (NOLOCK)
            Where reporttype = @cReportType
               AND Storerkey = @cStorerKey
               AND Function_ID = @nFunc

            SET   @cDCropWidth    = CASE WHEN ISNULL(@cDCropWidth , '') = '' THEN '' ELSE @cDCropWidth  END
            SET   @cDCropHeight   = CASE WHEN ISNULL(@cDCropHeight, '') = '' THEN '' ELSE @cDCropHeight END
            SET   @cIsLandScape   = CASE WHEN ISNULL(@cIsLandScape, '') = '' THEN '' ELSE @cIsLandScape END
            SET   @cIsColor       = CASE WHEN ISNULL(@cIsColor    , '') = '' THEN '' ELSE @cIsColor     END
            SET   @cIsDuplex      = CASE WHEN ISNULL(@cIsDuplex   , '') = '' THEN '' ELSE @cIsDuplex    END
            SET   @cIsCollate     = CASE WHEN ISNULL(@cIsCollate  , '') = '' THEN '' ELSE @cIsCollate   END
            SET   @cPaperSize     = CASE WHEN ISNULL(@cPaperSize  , '') = '' THEN '' ELSE @cPaperSize   END
            SET   @cCloudClientPrinterID = CASE WHEN ISNULL(@cCloudClientPrinterID  , '') = '' THEN '' ELSE @cCloudClientPrinterID   END

            -- Insert print job
            IF @bDebugFlag = 1
               SELECT 'Create Print Job', @cReportType AS RptType, @cPrinter AS Printer, @nRptNoOfCopy AS NoOfCopy, @cPrintData AS PrintData,
                        @cDCropHeight AS width, @cDCropHeight AS height, @cIsLandScape AS IsLandScape, @cIsDuplex AS IsDuplex, @cIsColor AS IsColor,
                        @cIsCollate AS IsCollate, @cPaperSize AS PaperSize, @cCloudClientPrinterID AS CloudClientID

            INSERT INTO rdt.rdtPrintJob (
               JobName, ReportID, JobStatus, Datawindow, Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, StorerKey,
               Function_ID, PaperSizeWxH, DCropWidth, DCropHeight, IsLandScape, IsColor, IsDuplex, IsCollate)
            VALUES(
               'rdt_593Print40', @cReportType, @cJobStatus, @cDataWindow, @cPrinter, @nRptNoOfCopy, @nMobile, DB_NAME(), @cPrintData, 'LogiReport', @cStorerKey,
               @nFunc, @cPaperSize, @cDCropWidth, @cDCropHeight, @cIsLandScape, @cIsColor, @cIsDuplex, @cIsCollate)

            SELECT @nJobID = SCOPE_IDENTITY(), @nErrNo = @@ERROR

            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 2171010
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PrnJobFail
               GOTO Quit
            END

            --Submit to cloud print task
            EXEC isp_UpdateRDTPrintJobStatus
                  @n_JobID = @nJobID,
                  @c_JobStatus = @cJobStatus,
                  @c_JobErrMsg = '',
                  @b_Success = @b_Success OUTPUT,
                  @n_Err  = @nErrNo OUTPUT,
                  @c_ErrMsg = @cErrMsg OUTPUT,
                  @c_PrintData = @cPrintData

            IF @bDebugFlag = 1
               SELECT 'Submit to cloud print', @nJobID AS JobID, @cJobStatus AS JobStatus, @b_Success AS bSuccess, @nErrNo AS ErrNo, @cErrMsg AS ErrMsg

            IF @b_Success <> 1
            BEGIN
               SET @nErrNo = 217111
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SubCldPrtFail
               GOTO Quit
            END

            SET @nCounter = @nCounter + 1

         END -- end while
      END -- step2
   END -- 593

Quit:

END -- END SP

GO