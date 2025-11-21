SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_840ExtPrint31                                   */
/* Purpose: FCR-869 HUDA - 840 Extended Print                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2024-10-21 1.0  LJQ006     FCR-869 Created                           */
/************************************************************************/

CREATE   PROC [RDT].[rdt_840ExtPrint31] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cStorerkey  NVARCHAR( 15),
   @cOrderKey   NVARCHAR( 10),
   @cPickSlipNo NVARCHAR( 10),
   @cTrackNo    NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @nCartonNo   INT,
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @cPaperPrinter          NVARCHAR( 10),
      @cLabelPrinter          NVARCHAR( 10),
      @cUserName              NVARCHAR( 18),
      @cFacility              NVARCHAR( 5),
      @nRtnCnt                INT = 0,
      @cCartonNo              NVARCHAR(10),
      @cLabelName             NVARCHAR(30),
      @cLabelNo               NVARCHAR(20),
      @cSourceType            NVARCHAR(10),
      @cReportType            NVARCHAR( 10),
      @cCondition             NVARCHAR(4000),
      @cFilePath              NVARCHAR(250),
      @cFileName              NVARCHAR(250),
      @cPrinterType           NVARCHAR(30),
      @cLabelSize             NVARCHAR(60),
      @tReportParams          VariableTable,
      @cExternOrderKey        NVARCHAR( 50),
      @cPrinter               NVARCHAR( 10),
      @cRptDesc               NVARCHAR( 60),
      @cRptPaperType          NVARCHAR( 10),          --'LABEL' / 'PAPER'
      @nRptNoOfCopy           INT,
      @cRptDataWindow         NVARCHAR( 50),
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
      @cWebRequestURL         NVARCHAR( MAX),
      @c_VbErrMsg             NVARCHAR( MAX),
      @cJobStatus             NVARCHAR(1) = '9',
      @nJobID                 INT,
      @b_Success              INT
      
   DECLARE 
      @nExpectedQty           INT,
      @nPackedQty             INT,
      @cExcludeShortPick      NVARCHAR(1),    
      @cPickConfirmStatus     NVARCHAR(1)   
           
   DECLARE 
      @nRowCount         INT,
      @nRowID            INT,
      @cSQL        NVARCHAR( MAX),
      @cSQLParam   NVARCHAR( MAX)
   
   DECLARE @tPrintCodeCfg TABLE (
      RowId       INT,
      LabelName   NVARCHAR(30), 
      SourceType  NVARCHAR(10), 
      Condition   NVARCHAR(4000), 
      LabelSize   NVARCHAR(60), 
      FilePath    NVARCHAR(250), 
      FileName    NVARCHAR(250), 
      PrinterType NVARCHAR(30)
   )

   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper,
          @cFacility = Facility,
          @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @cExcludeShortPick = rdt.RDTGetConfig( @nFunc, 'ExcludeShortPick', @cStorerKey)    
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)    
   IF @cPickConfirmStatus = '0'  
      SET @cPickConfirmStatus = ''

   SET @nExpectedQty = -1    
      SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)    
      WHERE Orderkey = @cOrderkey    
      AND   Storerkey = @cStorerkey    
      AND   Status < '9'
      AND  (( @cExcludeShortPick = '1' AND [Status] <> '4') OR   
            ( @cPickConfirmStatus <> '' AND [Status] = @cPickConfirmStatus) OR   
            ( [Status] = [Status]))    
          
   SET @nPackedQty = -2    
   SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)    
   WHERE PickSlipNo = @cPickSlipNo

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 4
      BEGIN
         IF @nPackedQty <> @nExpectedQty
         BEGIN
            GOTO Quit
         END
         -- fetch codelkup into table variable
         DELETE FROM @tPrintCodeCfg
         INSERT INTO @tPrintCodeCfg(RowId, LabelName, SourceType, Condition, LabelSize, FilePath, FileName, PrinterType)
            SELECT RANK() OVER(ORDER BY Code) AS RowId, Code, Short, Notes, UDF01, Notes2, UDF03, code2 
            FROM dbo.CODELKUP WITH (NOLOCK) 
            WHERE LISTNAME = 'PACKPRTCON'
               AND StorerKey = @cStorerKey 
           
         SELECT @nRowCount = COUNT(1) FROM @tPrintCodeCfg
         SELECT @nRowCount = ISNULL(@nRowCount, 0), @nRowID = 0

         -- loop each cfg and customize print behavior
         WHILE @nRowID < @nRowCount
         BEGIN
         
            SELECT @nRowID = @nRowID + 1
            SELECT 
               @cLabelName    = LabelName, 
               @cSourceType   = ISNULL(SourceType,''), 
               @cCondition    = ISNULL(Condition,''), 
               @cLabelSize    = ISNULL(LabelSize,''), 
               @cFilePath     = ISNULL(FilePath,''), 
               @cFileName     = ISNULL(FileName,''), 
               @cPrinterType  = PrinterType
            FROM @tPrintCodeCfg WHERE RowId=@nRowID
            
            SELECT @cReportType = @cLabelName
            
            
            IF ISNULL(@cCondition,'') = '' OR CHARINDEX('all',@cCondition) > 0
            BEGIN
               SET @cCondition = ''
            END

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
               SET @nErrNo = 226851
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP')      -- Invalid Condition
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @cErrMsg, @cLabelName, @cCondition, @cSQLErrorMessage
               GOTO Quit
            END CATCH
            
            IF @nRtnCnt > 0
            BEGIN
               -- label and bartender
               IF @cSourceType IN ('BTD', 'logi')
               BEGIN
                  IF @cSourceType = 'BTD'
                  BEGIN
                     -- param required: 1.LabelNo 2.ReceiptKey + ToID 4.OrderKey
                     SELECT TOP 1 @cLabelNo = LabelNo 
                     FROM dbo.PackDetail WITH(NOLOCK) 
                     WHERE PickSlipNo = @cPickSlipNo
                        AND StorerKey = @cStorerKey
                     
                     SET @cCartonNo = '1'
                     DELETE FROM @tReportParams;
                     
                     IF @cReportType IN ('GlobalBox', 'LocalBox')
                     BEGIN
                        INSERT INTO @tReportParams (Variable, Value) VALUES
                           ( '@cLabelNo', @cLabelNo)
                     END
                     ELSE IF @cReportType = 'SHIPLBLFN'
                     BEGIN
                        INSERT INTO @tReportParams (Variable, Value) VALUES
                           ( '@cOrderKey', @cOrderKey)
                     END
                  END
                  IF @cSourceType = 'logi'
                  BEGIN
                     DELETE FROM @tReportParams;
                     INSERT INTO @tReportParams (Variable, Value) VALUES 
                        ( '@cOrderKey', @cOrderKey)
                  END
                  
                  BEGIN
                     -- Print label
                     EXEC RDT.rdt_Print 
                        @nMobile, 
                        @nFunc, 
                        @cLangCode, 
                        @nStep, 
                        @nInputKey, 
                        @cFacility, 
                        @cStorerKey, 
                        @cLabelPrinter, 
                        @cPaperPrinter,
                        @cReportType, -- Report type
                        @tReportParams, -- Report params
                        'rdt_840ExtPrint31',
                        @nErrNo  OUTPUT,
                        @cErrMsg OUTPUT
                     IF @nErrNo <> 0
                        GOTO Quit
                  END
               END
               
               -- PDF print scenario - Cloud Print
               IF @cSourceType = 'SFTP'
               BEGIN
                  -- check url prefix cfg
                  SELECT @cWebRequestURL = WebRequestURL
                  FROM WebServiceCfg WITH (NOLOCK)
                  WHERE DataProcess = 'FNGETFILE'
                     AND ActiveFlag = 1
                  -- URL prifix verify
                  IF ISNULL(@cWebRequestURL, '') = ''
                  BEGIN
                     SET @nErrNo = 226852
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- MissWebSrvc
                     GOTO Quit
                  END
                  -- build file path
                  SELECT @cFilePath=ltrim(rtrim(@cFilePath))
                  IF RIGHT(@cFilePath,1) IN ('\','/')
                  BEGIN
                     SELECT @cPrintDataFile = @cFilePath 
                        + REPLACE(REPLACE(@cFileName,'<code>',@cLabelName),'<ExternOrderkey>',@cExternOrderKey)
                  END
                  ELSE BEGIN
                     SELECT @cPrintDataFile = @cFilePath 
                        + '/' + REPLACE(REPLACE(@cFileName,'<code>',@cLabelName),'<ExternOrderkey>',@cExternOrderKey)
                  END
                  -- encrypt file path
                  BEGIN TRY
                     SELECT @cPrintDataFileEncrypt = MASTER.DBO.fnc_CryptoEncrypt(@cPrintDataFile, '')           --refer from rdt_593PrntCldFile01
                  END TRY
                  BEGIN CATCH
                     SET @nErrNo = 226853
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Failed to encrypt file path
                     BREAK
                  END CATCH
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
                     SET @nErrNo = 226854
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Miss Cloud Printer ID
                     EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @cErrMsg, @cReportType
                     BREAK
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
                     SET @nErrNo = 226855
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PrinterNotExists
                     GOTO Quit
                  END

                  IF ISNULL(@cCloudClientPrinterID, '') = ''
                  BEGIN
                     SET @nErrNo = 226856
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
                     'rdt_840ExtPrint31', @cReportType, @cJobStatus, @cRptDataWindow, @cExternOrderKey, @cPrinter, @nRptNoOfCopy, @nMobile, DB_NAME(), @cPrintDataFileFull, 'LogiReport', @cStorerKey,
                     @nFunc, @cPaperSize, @cDCropWidth, @cDCropHeight, @cIsLandScape, @cIsColor, @cIsDuplex, @cIsCollate)

                  SELECT @nJobID = SCOPE_IDENTITY(), @nErrNo = @@ERROR

                  IF @nErrNo <> 0
                  BEGIN
                     SET @nErrNo = 226857
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
                     SET @nErrNo = 226858
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SubCldPrtFail
                     GOTO Quit
                  END
               END
            END
         END  -- loop each cfg 
      END   -- IF @nStep = 4
   END   -- @nInputKey = 1
Quit:

GO