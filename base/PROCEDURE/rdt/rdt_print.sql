SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/********************************************************************************/
/* Store procedure: rdt_Print                                                   */
/* Copyright      : Maersk                                                      */
/*                                                                              */
/* Date       Rev    Author      Purposes                                       */
/* 30-05-2017 1.0    Ung         WMS-1919 Created                               */
/* 25-10-2017 1.1    SWT01       Include IP when insert into TCP Q Task         */
/*                               TransmitlogKey = JobID                         */
/* 08-05-2018 1.2    Ung         WMS-4248 Migrate print command to QCommander   */
/* 25-04-2018 1.3    Ung         WMS-4675 Use BarTender NoOfCopy                */
/* 14-08-2018 1.4    Ung         Add TCPSocket_OutLog.MessageNum                */
/*                               Update TCPSocket_QueueTask.Status = X          */
/*                               Expand param value to 30 chars                 */
/* 25-10-2018 1.5    Ung         Call isp_QCmd_UpdateQueueTaskStatus to update  */
/*                               TCPSocket_QueueTask.Status = X                 */
/* 30-10-2018 1.6    James       Add function id when insert printjob (james01) */
/* 05-11-2018 1.7    James       Add to rdtprintjob_log (james02)               */
/* 07-01-2019 1.8    Ung         Add TCPSpooler                                 */
/* 11-02-2019 1.9    ChewKP      WMS-4692 Add new ProcessType 'BARTENDERPRTSEQ' */
/*                               (ChewKP01)                                     */
/* 19-06-2019 2.0    Ung         WMS-9050 Add data window to custom map         */
/* 10-08-2021 2.1    YeeKung     WMS-17055 Add printcommand in processtype      */
/*                               (yeekung01)                                    */
/* 23-08-2021 2.2    YeeKung     WMS-17797 Modified new feature                 */
/* 15-11-2021 2.3    YeeKung     WMS-18126 Add UPS support (yeekung03)          */
/* 12-07-2022 2.4    James       WMS-20111 Add ExportFileName (james03)         */
/* 07-07-2023 2.5    YeeKung     Support Cloud Print (yeekung04)                */
/* 06-02-2024 2.6    Ung         WMS-24733 Fix move PrintJob to log table for   */
/*                               QCommander with print command                  */
/* 25-03-2024 2.7    YeeKung     WMS-25156 fix then papersize (yeekung05)       */
/* 11-06-2024 2.8    YeeKung     UWP-19905 Fix Bartender                        */
/*                                 Support ZPL/ ITDOC                           */
/* 04-11-2024 2.9    YeeKung     WMS-25928Correct Processtype with ITFDOC       */
/* 2024-12-10 3.0    YeeKung     FCR-1787 Add CMDSUMATRA Processtype (yeekung01)*/
/* 2024-12-23 3.1.0  JCH507      UWP-28606 Get WeServiceAPI URL from codelkup   */
/* 2024-12-24 3.2.0  YeeKung     UWP-28450 Fix bartender duplicate record       */
/*                               (yeekung06)                                    */
/* 2025-02-19 3.3.0  YeeKung     UWP-30389 chaneg 1 to NoofCopy (yeekung07)      */        
/********************************************************************************/

CREATE    PROC rdt.rdt_Print (
   @nMobile       INT
   ,@nFunc         INT
   ,@cLangCode     NVARCHAR( 3)
   ,@nStep         INT
   ,@nInputKey     INT
   ,@cFacility     NVARCHAR( 5)
   ,@cStorerKey    NVARCHAR( 15)
   ,@cLabelPrinter NVARCHAR( 10)
   ,@cPaperPrinter NVARCHAR( 10)
   ,@cReportType   NVARCHAR( 10)
   ,@tReportParam  VariableTable READONLY
   ,@cSourceType   NVARCHAR( 50)
   ,@nErrNo        INT           OUTPUT
   ,@cErrMsg       NVARCHAR(250) OUTPUT
   ,@nNoOfCopy     INT = NULL
   ,@cPrintCommand NVARCHAR(MAX) = ''
   ,@cExportFileName NVARCHAR( 50) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @i              INT
   DECLARE @nDefNoOfCopy   INT
   DECLARE @cPrinter       NVARCHAR( 10)
   DECLARE @cDataWindow    NVARCHAR( 50)
   DECLARE @cTargetDB      NVARCHAR( 20)
   DECLARE @cJobType       NVARCHAR( 10)
   DECLARE @cJobStatus     NVARCHAR( 1)
   DECLARE @cPaperType     NVARCHAR( 10)
   DECLARE @cProcessType   NVARCHAR( 15)
   DECLARE @cProcessSP     NVARCHAR( 50)
   DECLARE @cTemplate      NVARCHAR( MAX)
   DECLARE @cTemplateSP    NVARCHAR( 80)
   DECLARE @cPrintData     NVARCHAR( MAX)
   DECLARE @cSpoolerGroup  NVARCHAR( 20)
   DECLARE @cIPAddress     NVARCHAR( 40)
   DECLARE @cPortNo        NVARCHAR( 5)
   DECLARE @cDataReceived  NVARCHAR( 4000)
   DECLARE @cJobID         NVARCHAR( 10)
   DECLARE @nJobID         INT
   DECLARE @cIniFilePath    NVARCHAR( 200)
   DECLARE @bSuccess       INT
   DECLARE @cUserName NVARCHAR( 18)
   DECLARE @c_PrintMethod  NVARCHAR( 18)        --(yeekung03)
   DECLARE @cPaperSize     NVARCHAR( 20)

   DECLARE @cParam       NVARCHAR( 30)
   DECLARE @cParam01     NVARCHAR( 30)
   DECLARE @cParam02     NVARCHAR( 30)
   DECLARE @cParam03     NVARCHAR( 30)
   DECLARE @cParam04     NVARCHAR( 30)
   DECLARE @cParam05     NVARCHAR( 30)
   DECLARE @cParam06     NVARCHAR( 30)
   DECLARE @cParam07     NVARCHAR( 30)
   DECLARE @cParam08     NVARCHAR( 30)
   DECLARE @cParam09     NVARCHAR( 30)
   DECLARE @cParam10     NVARCHAR( 30)

   DECLARE @cValue       NVARCHAR( 30)
   DECLARE @cValue01     NVARCHAR( 30)
   DECLARE @cValue02     NVARCHAR( 30)
   DECLARE @cValue03     NVARCHAR( 30)
   DECLARE @cValue04     NVARCHAR( 30)
   DECLARE @cValue05     NVARCHAR( 30)
   DECLARE @cValue06     NVARCHAR( 30)
   DECLARE @cValue07     NVARCHAR( 30)
   DECLARE @cValue08     NVARCHAR( 30)
   DECLARE @cValue09     NVARCHAR( 30)
   DECLARE @cValue10     NVARCHAR( 30)
         ,@cStartRec          NVARCHAR(5)
         ,@cEndRec            NVARCHAR(5)
         ,@cFromSourceModule  NVARCHAR(250)
         ,@cQCmdSubmitFlag    CHAR(1)

   DECLARE @cDBName         NVARCHAR( 30)
   DECLARE @cSpoolerCommand NVARCHAR( 1024)
   DECLARE @cCommand        NVARCHAR( 1024)
   DECLARE @nQueueID        BIGINT
   DECLARE @c_ContinueNextPrint NVARCHAR(1)

   DECLARE 	@cDCropWidth   NVARCHAR(10)= '' ,
            @cDCropHeight   NVARCHAR(10)= '',
            @cIsLandScape   NVARCHAR(1) = '',
            @cIsColor   	NVARCHAR(1) = '',
            @cIsDuplex   	NVARCHAR(1) = '',
            @cIsCollate      NVARCHAR(1) = '',
            @cCloudClientPrinterID	NVARCHAR(20)

   DECLARE @cAPP_DB_Name         NVARCHAR( 20) = ''
         ,@cDataStream           VARCHAR( 10)  = ''
         ,@nThreadPerAcct        INT = 0
         ,@nThreadPerStream      INT = 0
         ,@nMilisecondDelay      INT = 0
         ,@cIP                   NVARCHAR( 20) = ''
         ,@cPORT                 NVARCHAR( 5)  = ''
         ,@cCmdType              NVARCHAR( 10) = ''
         ,@cTaskType             NVARCHAR( 1)  = ''
         ,@cPDFPreview           NVARCHAR( 20)

   DECLARE  @b_PrintOverInternet    BIT            = 0
            ,@c_PDFPreviewServer    NVARCHAR(30)   = ''
            ,@c_CountryPDFFolder    NVARCHAR(30)
            ,@cWinPrinter   	      NVARCHAR(1024)

   SET @cValue = ''
   SET @cValue01 = ''
   SET @cValue02 = ''
   SET @cValue03 = ''
   SET @cValue04 = ''
   SET @cValue05 = ''
   SET @cValue06 = ''
   SET @cValue07 = ''
   SET @cValue08 = ''
   SET @cValue09 = ''
   SET @cValue10 = ''

   SET @nErrNo = 0
   SET @cJobType = ''
   SET @cJobStatus = '0'
   SET @cPrintData = ''

   -- Get report info
   SELECT TOP 1
      @cDataWindow = DataWindow,
      @cTargetDB = TargetDB,
      @cPaperType = PaperType,
      @cProcessType = ProcessType,
      @cProcessSP = ProcessSP,
      @nDefNoOfCopy = NoOfCopy,
      @cTemplate = ISNULL( PrintTemplate, ''),
      @cTemplateSP = ISNULL( PrintTemplateSP, ''),
      @cParam01 = ISNULL( Parm1_Label, ''),
      @cParam02 = ISNULL( Parm2_Label, ''),
      @cParam03 = ISNULL( Parm3_Label, ''),
      @cParam04 = ISNULL( Parm4_Label, ''),
      @cParam05 = ISNULL( Parm5_Label, ''),
      @cParam06 = ISNULL( Parm6_Label, ''),
      @cParam07 = ISNULL( Parm7_Label, ''),
      @cParam08 = ISNULL( Parm8_Label, ''),
      @cParam09 = ISNULL( Parm9_Label, ''),
      @cParam10 = ISNULL( Parm10_Label, '')
   FROM rdt.rdtReport WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND ReportTYpe = @cReportType
      AND (Function_ID = @nFunc OR Function_ID = 0)
   ORDER BY Function_ID DESC

   -- Check report
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 110701
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReportNotSetup
      GOTO Quit
   END

   IF @nNoOfCopy IS NULL
      SET @nNoOfCopy = @nDefNoOfCopy

   -- Check login printer
   IF @cPaperType = 'LABEL'
   BEGIN
      IF @cLabelPrinter = ''
      BEGIN
         SET @nErrNo = 110702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLabelPrinter
         GOTO Quit
      END
      SET @cPrinter = @cLabelPrinter
   END
   ELSE
   BEGIN
      IF @cPaperPrinter = ''
      BEGIN
         SET @nErrNo = 110703
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPaperPrinter
         GOTO Quit
      END
      SET @cPrinter = @cPaperPrinter
   END

   -- Check if printer is a group
   IF EXISTS( SELECT TOP 1 1 FROM rdt.rdtPrinterGroup WITH (NOLOCK) WHERE PrinterGroup = @cPrinter)
   BEGIN
      DECLARE @cPrinterInGroup NVARCHAR(10)
      SET @cPrinterInGroup = ''

      -- Check if report print to a specific printer in group
      SELECT @cPrinterInGroup = PrinterID
      FROM rdt.rdtReportToPrinter WITH (NOLOCK)
      WHERE Function_ID = @nFunc
         AND StorerKey = @cStorerKey
         AND ReportType = @cReportType
         AND PrinterGroup = @cPrinter

      IF @cPrinterInGroup = ''
      BEGIN
         -- Get default printer in the group
         SELECT @cPrinterInGroup = PrinterID
         FROM rdt.rdtPrinterGroup WITH (NOLOCK)
         WHERE PrinterGroup = @cPrinter
            AND DefaultPrinter = 1

         -- Check no default printer
         IF @cPrinterInGroup = ''
         BEGIN
            SET @nErrNo = 110714
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoDefPrnInGRP
            GOTO Quit
         END
      END

      SET @cPrinter = @cPrinterInGroup
   END

   -- Get printer info
   SELECT
      @cSpoolerGroup = SpoolerGroup,
   @cWinPrinter = WinPrinter
   FROM rdt.rdtPrinter WITH (NOLOCK)
   WHERE PrinterID = @cPrinter

   -- Check printer
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 110706
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PrinterNoSetup
      GOTO Quit
   END

   -- Standard mapping process
   IF @cProcessSP = ''
   BEGIN
      SET @i = 1
      WHILE @i <= 10
      BEGIN
         -- Get param
         IF @i = 1  SET @cParam = @cParam01 ELSE
         IF @i = 2  SET @cParam = @cParam02 ELSE
         IF @i = 3  SET @cParam = @cParam03 ELSE
         IF @i = 4  SET @cParam = @cParam04 ELSE
         IF @i = 5  SET @cParam = @cParam05 ELSE
         IF @i = 6  SET @cParam = @cParam06 ELSE
         IF @i = 7  SET @cParam = @cParam07 ELSE
         IF @i = 8  SET @cParam = @cParam08 ELSE
         IF @i = 9  SET @cParam = @cParam09 ELSE
         IF @i = 10 SET @cParam = @cParam10

         -- Param is setup
         IF @cParam <> ''
         BEGIN
            -- Param is variable
            IF LEFT( @cParam, 1) = '@'
            BEGIN
               -- Get param value
               SELECT @cValue = Value FROM @tReportParam WHERE Variable = @cParam
               IF @@ROWCOUNT <> 1
               BEGIN
                  SET @nErrNo = 110704
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ParamNotMatch
                  GOTO Quit
               END
            END

            -- Param is constant
            ELSE
               SET @cValue = @cParam

            -- Set value
            IF @i = 1  SET @cValue01 = @cValue ELSE
            IF @i = 2  SET @cValue02 = @cValue ELSE
            IF @i = 3  SET @cValue03 = @cValue ELSE
            IF @i = 4  SET @cValue04 = @cValue ELSE
            IF @i = 5  SET @cValue05 = @cValue ELSE
            IF @i = 6  SET @cValue06 = @cValue ELSE
            IF @i = 7  SET @cValue07 = @cValue ELSE
            IF @i = 8  SET @cValue08 = @cValue ELSE
            IF @i = 9  SET @cValue09 = @cValue ELSE
            IF @i = 10 SET @cValue10 = @cValue
         END

         SET @i = @i + 1
      END
   END

   -- Custom mapping process
   ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cProcessSP AND type = 'P')
   BEGIN
      DECLARE @cSQL NVARCHAR(MAX)
      DECLARE @cSQLParam NVARCHAR(MAX)

      SET @cSQL = 'EXEC rdt.' + RTRIM( @cProcessSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, @cReportType, @tReportParam, ' +
         ' @cValue01 OUTPUT, @cValue02 OUTPUT, @cValue03 OUTPUT, @cValue04 OUTPUT, @cValue05 OUTPUT, ' +
         ' @cValue06 OUTPUT, @cValue07 OUTPUT, @cValue08 OUTPUT, @cValue09 OUTPUT, @cValue10 OUTPUT, ' +
         ' @cPrinter OUTPUT, @cSpoolerGroup OUTPUT, @nNoOfCopy OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cDataWindow OUTPUT,' +
         ' @cPrintCommand OUTPUT,@cProcessType OUTPUT,@c_PrintMethod OUTPUT'
      SET @cSQLParam =
         '@nMobile       INT,           ' +
         '@nFunc         INT,           ' +
         '@cLangCode     NVARCHAR( 3),  ' +
         '@nStep         INT,           ' +
         '@nInputKey     INT,           ' +
         '@cFacility     NVARCHAR( 5),  ' +
         '@cStorerKey    NVARCHAR( 15), ' +
         '@cLabelPrinter NVARCHAR( 10), ' +
         '@cPaperPrinter NVARCHAR( 10), ' +
         '@cReportType   NVARCHAR( 10), ' +
         '@tReportParam  VariableTable READONLY, ' +
         '@cValue01      NVARCHAR( 30) OUTPUT,   ' +
         '@cValue02      NVARCHAR( 30) OUTPUT,   ' +
         '@cValue03      NVARCHAR( 30) OUTPUT,   ' +
         '@cValue04      NVARCHAR( 30) OUTPUT,   ' +
         '@cValue05      NVARCHAR( 30) OUTPUT,   ' +
         '@cValue06      NVARCHAR( 30) OUTPUT,   ' +
         '@cValue07      NVARCHAR( 30) OUTPUT,   ' +
         '@cValue08      NVARCHAR( 30) OUTPUT,   ' +
         '@cValue09      NVARCHAR( 30) OUTPUT,   ' +
         '@cValue10      NVARCHAR( 30) OUTPUT,   ' +
         '@cPrinter      NVARCHAR( 10) OUTPUT,   ' +
         '@cSpoolerGroup NVARCHAR( 20) OUTPUT,   ' +
         '@nNoOfCopy     INT           OUTPUT,   ' +
         '@nErrNo        INT           OUTPUT,   ' +
         '@cErrMsg       NVARCHAR( 20) OUTPUT,   ' +
         '@cDataWindow   NVARCHAR( 50) OUTPUT,   ' +
         '@cPrintCommand NVARCHAR( MAX) OUTPUT,  ' +
         '@cProcessType  NVARCHAR( 20) OUTPUT,   '  +
         '@c_PrintMethod      NVARCHAR( 18) OUTPUT    '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, @cReportType, @tReportParam,
         @cValue01 OUTPUT, @cValue02  OUTPUT, @cValue03 OUTPUT, @cValue04 OUTPUT, @cValue05 OUTPUT,
         @cValue06 OUTPUT, @cValue07  OUTPUT, @cValue08 OUTPUT, @cValue09 OUTPUT, @cValue10 OUTPUT,
         @cPrinter OUTPUT, @cSpoolerGroup OUTPUT, @nNoOfCopy OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cDataWindow OUTPUT,
         @cPrintCommand OUTPUT,@cProcessType OUTPUT, @c_PrintMethod OUTPUT


      IF @nErrNo <> 0
         GOTO Quit
   END
   ELSE
   BEGIN
      SET @nErrNo = 110705
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad ProcessSP
      GOTO Quit
   END

   -- QCommander
   IF @cProcessType = 'QCOMMANDER'
   BEGIN

      -- Get spooler info
      SELECT
         @cIPAddress = IPAddress,
         @cPortNo = PortNo,
         @cSpoolerCommand = Command,
         @cIniFilePath = IniFilePath
      FROM rdt.rdtSpooler WITH (NOLOCK)
      WHERE SpoolerGroup = @cSpoolerGroup

      -- Check valid
      IF @@ROWCOUNT = 0 OR @cIPAddress = '' OR @cPortNo = ''
      BEGIN
         SET @nErrNo = 110707
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SpoolNot Setup
         GOTO Quit
      END

      SET @cDBName = DB_NAME()
      SET @cJobType = 'QCOMMANDER'

      IF @cPrintCommand <> ''
         SET @cJobStatus = '9'

      SET @i = 0
      WHILE @i < @nNoOfCopy
      BEGIN
         -- Insert print job
         INSERT INTO rdt.rdtPrintJob (
            JobName, ReportID, JobStatus, Datawindow, NoOfParms, Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, StorerKey,
            Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10, Function_ID, ExportFileName)
         VALUES(
            @cSourceType, @cReportType, @cJobStatus, @cDataWindow, 0, @cPrinter, 1, @nMobile, DB_NAME(), @cPrintCommand, @cJobType, @cStorerKey,
            @cValue01, @cValue02, @cValue03, @cValue04, @cValue05, @cValue06, @cValue07, @cValue08, @cValue09, @cValue10, @nFunc, @cExportFileName)
         SELECT @nJobID = SCOPE_IDENTITY(), @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 110708
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PrnJobFail
         END

         SET @cJobID = CAST( @nJobID AS NVARCHAR( 10))
         IF @cPrintCommand <> ''
            SET @cCommand = @cPrintCommand
         ELSE
            SET @cCommand = @cSpoolerCommand + ' ' + @cJobID


         -- Insert task (SWT01)
         INSERT INTO TCPSocket_QueueTask (CmdType, Cmd, StorerKey, Port, TargetDB, IP, TransmitLogKey, DataStream)
         VALUES ('CMD', @cCommand, @cStorerKey, @cPortNo, DB_NAME(), @cIPAddress, @cJobID, 'QSPOOLER')
         SELECT @nQueueID = SCOPE_IDENTITY(), @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 110709
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS QTask Fail
            GOTO Quit
         END

         -- <STX>CMD|855377|CNWMS|D:\RDTSpooler\rdtprint.exe 2668351<ETX>
         SET @cPrintData =
            '<STX>' +
               'CMD|' +
               CAST( @nQueueID AS NVARCHAR( 20)) + '|' +
               DB_NAME() + '|' +
               @cCommand +
            '<ETX>'

         -- Call Qcommander
         EXEC isp_QCmd_SendTCPSocketMsg
            @cApplication  = 'QCommander',
            @cStorerKey    = @cStorerKey,
            @cMessageNum   = @cJobID,
            @cData         = @cPrintData,
            @cIP           = @cIPAddress,
            @cPORT        = @cPortNo,
            @cIniFilePath  = @cIniFilePath,
            @cDataReceived = @cDataReceived OUTPUT,
            @bSuccess      = @bSuccess      OUTPUT,
            @nErr          = @nErrNo        OUTPUT,
            @cErrMsg       = @cErrMsg       OUTPUT
         IF @nErrNo <> 0
         BEGIN
            /*
            UPDATE TCPSocket_QueueTask SET
               Status = 'X',
               ErrMsg = @cErrMsg,
            EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE ID = @nQueueID
            */
            EXEC dbo.isp_QCmd_UpdateQueueTaskStatus
               @cTargetDB    = @cDBName,
               @nQTaskID     = @nQueueID,
               @cQStatus     = 'X',
               @cThreadID    = '',
               @cMsgRecvDate = '',
               @cQErrMsg     = ''
               -- @bSuccess     = @bSuccess OUTPUT,
               -- @nErr         = @nErrNo   OUTPUT,
               -- @cErrMsg      = @cErrMsg  OUTPUT
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 110716
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD QTask Fail
            END

            UPDATE rdt.rdtPrintJob SET
               JobStatus = 'E',
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE JobID = @nJobID
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 110717
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PrnJobFail
            END

            GOTO Quit
         END

         SET @i = @i + 1
      END
   END

   -- TCPSpooler
   ELSE IF @cProcessType = 'TCPSPOOLER'
   BEGIN


   -- SELECT @b_PrintOverInternet = IIF(cpc.PrintClientID IS NULL,0,1)
   -- FROM rdt.RDTPrinter AS rp (NOLOCK)
   -- LEFT OUTER JOIN dbo.CloudPrintConfig AS cpc WITH (NOLOCK) ON cpc.PrintClientID = rp.CloudPrintClientID
   -- WHERE rp.PrinterID = @cPrinter


   -- IF @b_PrintOverInternet = 1 SET @cCloudClientPrinterID = @cPrinter

   -- IF @b_PrintOverInternet = 1
   -- BEGIN
      --SET @cPDFPreview = 'Y'

      --SELECT TOP 1
      --	@c_PDFPreviewServer  = sc.SValue
      --	,  @c_CountryPDFFolder  = ISNULL(sc.Option1,'')
      --FROM dbo.StorerConfig AS sc (NOLOCK)
      --WHERE sc.ConfigKey = 'PDFPreviewServer'
      --	AND sc.Storerkey IN (@cStorerkey, 'ALL')
      --ORDER BY  CASE WHEN sc.Storerkey  = @cStorerkey THEN 1
      --      WHEN sc.Storerkey  = 'ALL'        THEN 2
      --      ELSE 9
      --      END

      --SET @cSpoolerGroup = ''                                                      --(Wan01)
      --SELECT TOP 1
      --	@cSpoolerGroup = rs.SpoolerGroup
      --FROM RDT.rdtSpooler AS rs WITH (NOLOCK)
      --WHERE rs.IPAddress = @c_PDFPreviewServer

      --SELECT TOP 1 @cPrinter = rp.PrinterID
      --FROM rdt.RDTPrinter AS rp WITH (NOLOCK)
      --LEFT JOIN rdt.RDTPrintJob AS rpj WITH (NOLOCK) ON rp.PrinterID = rpj.Printer
      --WHERE rp.SpoolerGroup = @cSpoolerGroup
      --GROUP BY rp.PrinterID
      --ORDER BY COUNT(rpj.Printer)
      --   ,  rp.PrinterID
   -- END

      -- Get spooler info
      SELECT
         @cIPAddress = IPAddress,
         @cPortNo = PortNo,
         @cIniFilePath = IniFilePath
      FROM rdt.rdtSpooler WITH (NOLOCK)
      WHERE SpoolerGroup = @cSpoolerGroup


      -- Check valid
      IF @@ROWCOUNT = 0 OR @cIPAddress = '' OR @cPortNo = ''
      BEGIN
         SET @nErrNo = 110718
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SpoolNot Setup
         GOTO Quit
      END

   SELECT   @cDCropWidth  = DCropWidth,
            @cDCropHeight = DCropHeight,
            @cIsLandScape = IsLandScape,
            @cIsColor     = IsColor,
            @cIsDuplex    = IsDuplex,
            @cIsCollate   = IsCollate,
               @cPaperSize   = PaperSizeWxH
      FROM rdt.rdtReportdetail (NOLOCK)
      Where reporttype = @cReportType
         AND storerkey = @cStorerKey

      SET   @cDCropWidth    = CASE WHEN ISNULL(@cDCropWidth , '') = '' THEN '' ELSE @cDCropWidth  END
      SET   @cDCropHeight   = CASE WHEN ISNULL(@cDCropHeight, '') = '' THEN '' ELSE @cDCropHeight END
      SET   @cIsLandScape   = CASE WHEN ISNULL(@cIsLandScape, '') = '' THEN '' ELSE @cIsLandScape END
      SET   @cIsColor       = CASE WHEN ISNULL(@cIsColor    , '') = '' THEN '' ELSE @cIsColor     END
      SET   @cIsDuplex      = CASE WHEN ISNULL(@cIsDuplex   , '') = '' THEN '' ELSE @cIsDuplex    END
      SET   @cIsCollate     = CASE WHEN ISNULL(@cIsDuplex   , '') = '' THEN '' ELSE @cIsDuplex    END
      SET   @cPaperSize     = CASE WHEN ISNULL(@cPaperSize  , '') = '' THEN '' ELSE @cPaperSize   END
      SET   @cCloudClientPrinterID = CASE WHEN ISNULL(@cCloudClientPrinterID  , '') = '' THEN '' ELSE @cCloudClientPrinterID   END
      SET   @cPDFPreview = CASE WHEN ISNULL(@cPDFPreview  , '') = '' THEN '' ELSE @cPDFPreview   END

      SET @cJobType = 'TCPSPOOLER'

      SET @i = 0
      WHILE @i < @nNoOfCopy
      BEGIN
         -- Insert print job
      INSERT INTO rdt.rdtPrintJob (
            JobName, ReportID, JobStatus, Datawindow, NoOfParms, Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, StorerKey,
            Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10, Function_ID, ExportFileName
            ,PaperSizeWxH,DCropWidth,DCropHeight,IsLandScape,IsColor,IsDuplex,IsCollate,CloudClientPrinterID,PDFPreview)
         VALUES(
            @cSourceType, @cReportType, @cJobStatus, @cDataWindow, 0, @cPrinter, 1, @nMobile, DB_NAME(), @cPrintCommand, @cJobType, @cStorerKey,
            @cValue01, @cValue02, @cValue03, @cValue04, @cValue05, @cValue06, @cValue07, @cValue08, @cValue09, @cValue10, @nFunc, @cExportFileName
            ,@cPaperSize,@cDCropWidth,@cDCropHeight,@cIsLandScape,@cIsColor,@cIsDuplex,@cIsCollate,@cCloudClientPrinterID,@cPDFPreview)
         SELECT @nJobID = SCOPE_IDENTITY(), @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 110719
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PrnJobFail
         END

         SET @cJobID = CAST( @nJobID AS NVARCHAR( 10))

      -- Send TCP socket message
         EXEC isp_QCmd_SendTCPSocketMsg
            @cApplication  = 'TCPSPOOLER',
            @cStorerKey    = @cStorerKey,
            @cMessageNum   = @cJobID,
            @cData         = @cJobID,
            @cIP           = @cIPAddress,
            @cPORT         = @cPortNo,
            @cIniFilePath  = @cIniFilePath,
            @cDataReceived = @cDataReceived OUTPUT,
            @bSuccess      = @bSuccess      OUTPUT,
            @nErr          = @nErrNo        OUTPUT,
            @cErrMsg       = @cErrMsg       OUTPUT
         IF @nErrNo <> 0
         BEGIN
            UPDATE rdt.rdtPrintJob SET
               JobStatus = 'E',
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE JobID = @nJobID
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 110720
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PrnJobFail
            END

            GOTO Quit
         END

         SET @i = @i + 1
      END
   END

   -- Bartender
   ELSE IF @cProcessType IN (  'BARTENDER' ,'BARTENDERPRTSEQ' )  -- (ChewKP01)
   BEGIN
      SET @cUserName = LEFT( SUSER_SNAME(), 18)

      SET @cStartRec = ''
      SET @cEndRec = ''
      SET @cFromSourceModule = ''


   SELECT   @cDCropWidth  = DCropWidth,
            @cDCropHeight = DCropHeight,
            @cIsLandScape = IsLandScape,
            @cIsColor     = IsColor,
            @cIsDuplex    = IsDuplex,
            @cIsCollate   = IsCollate,
            @cPaperSize   = PaperSizeWxH
      FROM rdt.rdtReportdetail (NOLOCK)
      Where reporttype = @cReportType
         AND Storerkey = @cStorerKey

      SET   @cDCropWidth    = CASE WHEN ISNULL(@cDCropWidth , '') = '' THEN '' ELSE @cDCropWidth  END
      SET   @cDCropHeight   = CASE WHEN ISNULL(@cDCropHeight, '') = '' THEN '' ELSE @cDCropHeight END
      SET   @cIsLandScape   = CASE WHEN ISNULL(@cIsLandScape, '') = '' THEN '' ELSE @cIsLandScape END
      SET   @cIsColor       = CASE WHEN ISNULL(@cIsColor    , '') = '' THEN '' ELSE @cIsColor     END
      SET   @cIsDuplex      = CASE WHEN ISNULL(@cIsDuplex   , '') = '' THEN '' ELSE @cIsDuplex    END
      SET   @cIsCollate     = CASE WHEN ISNULL(@cIsCollate  , '') = '' THEN '' ELSE @cIsCollate   END
      SET   @cPaperSize     = CASE WHEN ISNULL(@cPaperSize  , '') = '' THEN '' ELSE @cPaperSize   END
      SET   @cCloudClientPrinterID = CASE WHEN ISNULL(@cCloudClientPrinterID  , '') = '' THEN '' ELSE @cCloudClientPrinterID   END
      SET   @cPDFPreview = CASE WHEN ISNULL(@cPDFPreview  , '') = '' THEN '' ELSE @cPDFPreview   END


      SELECT @b_PrintOverInternet = IIF(cpc.PrintClientID IS NULL,0,1)
      FROM rdt.RDTPrinter AS rp (NOLOCK)
      LEFT OUTER JOIN dbo.CloudPrintConfig AS cpc WITH (NOLOCK) ON cpc.PrintClientID = rp.CloudPrintClientID
      WHERE rp.PrinterID = @cPrinter

      SET @cPDFPreview = 'N'

      IF @cProcessType = 'BARTENDER'
         SET @cQCmdSubmitFlag  = '1'
      ELSE IF @cProcessType = 'BARTENDERPRTSEQ'
         SET @cQCmdSubmitFlag  = '0'

      SET @cJobType = 'BARTENDER'
      SET @cJobStatus = '9'

      -- Insert print job
      INSERT INTO rdt.rdtPrintJob (
         JobName, ReportID, JobStatus, Datawindow, NoOfParms, Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, StorerKey,
         Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10, Function_ID, ExportFileName
         ,PaperSizeWxH,DCropWidth,DCropHeight,IsLandScape,IsColor,IsDuplex,IsCollate,PDFPreview,CloudClientPrinterID)
      VALUES(
         @cSourceType, @cReportType, @cJobStatus, ISNULL( @cDataWindow, ''), 0, @cPrinter, @nNoOfCopy, @nMobile, DB_NAME(), @cPrintData, @cJobType, @cStorerKey,
         @cValue01, @cValue02, @cValue03, @cValue04, @cValue05, @cValue06, @cValue07, @cValue08, @cValue09, @cValue10, @nFunc, @cExportFileName
         ,@cPaperSize,@cDCropWidth,@cDCropHeight,@cIsLandScape,@cIsColor,@cIsDuplex,@cIsCollate,@cPDFPreview,@cPrinter)
      SELECT @nJobID = SCOPE_IDENTITY()

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 110715
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PrnJobFail
         GOTO Quit
      END

      IF  @b_PrintOverInternet = 1
      BEGIN
         EXEC [dbo].[isp_UpdateRDTPrintJobStatus]
            @n_JobID      = @nJobID
            ,@c_JobStatus  = @cJobStatus
            ,@c_JobErrMsg  = ''
            ,@b_Success    = @bSuccess OUTPUT
            ,@n_Err        = @nErrNo   OUTPUT
            ,@c_ErrMsg     = @cErrMsg  OUTPUT
      END

      -- Call bartender
      EXECUTE dbo.isp_BT_GenBartenderCommand
         @cPrinter,     -- printer id
         @cReportType,  -- label type
         @cUserName,    -- user id
         @cValue01,     -- parm01
         @cValue02,     -- parm02
         @cValue03,     -- parm03
         @cValue04,     -- parm04
         @cValue05,     -- parm05
         @cValue06,     -- parm06
         @cValue07,     -- parm07
         @cValue08,     -- parm08
         @cValue09,     -- parm09
         @cValue10,     -- parm10
         @cStorerKey,   -- StorerKey
         @nNoOfCopy,    -- no of copy
         0,             -- debug
         'N',           -- return result
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT,
         @cStartRec,
         @cEndRec,
         @cFromSourceModule,
         @cQCmdSubmitFlag,
      @nJobID

      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 110710
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BarTender Fail
         GOTO Quit
      END
   END

   ELSE IF @cProcessType = 'TPPrint'  --(yeekung01)
   BEGIN
      DECLARE @b_success INT

      SELECT @cUserName = UserName
      FROM rdt.RDTMOBREC (NOLOCK)
      WHERE mobile = @nMobile

      EXEC [dbo].[isp_TPP_PrintToTPServer]
            @c_Module            = 'RDT', --PACKING, EPACKING
            @c_ReportType        = @cReportType, --UCCLABEL,
            @c_Storerkey         = @cStorerKey, --Optional, if empty get from pickslip or rdtuser
            @c_Facility          = @cFacility,  --Optional, if empty get from pickslip or rdtuser
            @c_UserName          = @cUserName, --optional, if empty get from current db user
            @c_PrinterID         = @cLabelPrinter, --optional
            @c_IsPaperPrinter    = 'N', --optional Y/N
            @c_KeyFieldName      = @cValue10,
            @c_Parm01            = @cValue01,
            @c_Parm02            = @cValue02,  --e.g. from carton no
            @c_Parm03            = '',  --e.g. to carton no
            @c_Parm04            = '',
            @c_Parm05            = '',
            @c_Parm06            = '',
            @c_Parm07            = '',
            @c_Parm08            = '',
            @c_Parm09            = '',
            @c_Parm10            = '',
            @c_SourceType        = @nFunc, --print from which function
            @c_PrintMethod       = @c_PrintMethod,
            @c_ContinueNextPrint = @c_ContinueNextPrint OUTPUT, -- Y=Continue next print N=Not continue next print mode like Bartender, Logireport, PDF and Datawindow
            @b_success           = @b_success OUTPUT,
            @n_err               = @nErrNo OUTPUT,
            @c_errmsg            = @cErrMsg OUTPUT

      GOTO Quit
   END


   ELSE IF @cProcessType = 'LogiReport'  --(yeekung01)
   BEGIN
      DECLARE @c_CompleteURL NVARCHAR(MAX)

      SELECT   @cDCropWidth  = DCropWidth,
               @cDCropHeight = DCropHeight,
               @cIsLandScape = IsLandScape,
               @cIsColor     = IsColor,
               @cIsDuplex    = IsDuplex,
               @cIsCollate   = IsCollate,
               @cPaperSize   = PaperSizeWxH
      FROM rdt.rdtReportdetail (NOLOCK)
      WHERE reporttype = @cReportType
         AND Storerkey = @cStorerKey

      SET   @cDCropWidth    = CASE WHEN ISNULL(@cDCropWidth , '') = '' THEN '' ELSE @cDCropWidth  END
      SET   @cDCropHeight   = CASE WHEN ISNULL(@cDCropHeight, '') = '' THEN '' ELSE @cDCropHeight END
      SET   @cIsLandScape   = CASE WHEN ISNULL(@cIsLandScape, '') = '' THEN '' ELSE @cIsLandScape END
      SET   @cIsColor       = CASE WHEN ISNULL(@cIsColor    , '') = '' THEN '' ELSE @cIsColor     END
      SET   @cIsDuplex      = CASE WHEN ISNULL(@cIsDuplex   , '') = '' THEN '' ELSE @cIsDuplex    END
      SET   @cIsCollate     = CASE WHEN ISNULL(@cIsCollate  , '') = '' THEN '' ELSE @cIsCollate   END
      SET   @cPaperSize     = CASE WHEN ISNULL(@cPaperSize  , '') = '' THEN '' ELSE @cPaperSize   END
      SET   @cCloudClientPrinterID = CASE WHEN ISNULL(@cCloudClientPrinterID  , '') = '' THEN '' ELSE @cCloudClientPrinterID   END
      SET   @cPDFPreview = CASE WHEN ISNULL(@cPDFPreview  , '') = '' THEN '' ELSE @cPDFPreview   END

      SET @cJobType = 'LogiReport'

      -- Insert print job
      INSERT INTO rdt.rdtPrintJob (
         JobName, ReportID, JobStatus, Datawindow, NoOfParms, Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, StorerKey,
         Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10, Function_ID, ExportFileName
         ,PaperSizeWxH,DCropWidth,DCropHeight,IsLandScape,IsColor,IsDuplex,IsCollate)
      VALUES(
         @cSourceType, @cReportType, @cJobStatus, @cDataWindow, 0, @cPrinter, @nNoOfCopy, @nMobile, DB_NAME(), @cPrintCommand, @cJobType, @cStorerKey,
         @cValue01, @cValue02, @cValue03, @cValue04, @cValue05, @cValue06, @cValue07, @cValue08, @cValue09, @cValue10, @nFunc, @cExportFileName
         ,@cPaperSize,@cDCropWidth,@cDCropHeight,@cIsLandScape,@cIsColor,@cIsDuplex,@cIsCollate)
      SELECT @nJobID = SCOPE_IDENTITY(), @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 110719
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PrnJobFail
      END

      SET @cJobID = CAST( @nJobID AS NVARCHAR( 10))

      EXEC [RDT].[rdt_GetJReportURL]
         @c_Storerkey      = @cStorerKey,
         @c_ReportType     = @cReportType,
         @c_CallFrom       = 'Jreport',
         @c_Parm01         = @cValue01,
         @c_Parm02         = @cValue02,
         @c_Parm03         = @cValue03,
         @c_Parm04         = @cValue04,
         @c_Parm05         = @cValue05,
         @c_Parm06         = @cValue06,
         @c_Parm07         = @cValue07,
         @c_Parm08         = @cValue08,
         @c_Parm09         = @cValue09,
         @c_Parm10         = @cValue10,
         @c_PrintFormat    = '2',
         @cJobID           = @cJobID,
         @b_Success        = @b_Success OUTPUT,
         @n_Err            = @nErrNo OUTPUT,
         @c_ErrMsg         = @cErrMsg OUTPUT,
         @c_CompleteURL    = @c_CompleteURL OUTPUT

      UPDATE rdt.rdtPrintJob SET
         printdata = @c_CompleteURL,
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      WHERE JobID = @nJobID


      SET @cPrintCommand = N'EXEC [dbo].[isp_CldPrt_Generic_SendRequest]' +
                           N'  @c_DataProcess = ''logireport''' +
                           N', @c_StorerKey = ''' + @cStorerKey + ''' ' +
                           N', @c_Facility = ''' + @cFacility + ''' ' +
                           N', @b_Debug = 0 ' +
                           N', @n_JobID = ''' + @cJobID + ''' ' +
                           N', @b_Success = 1 ' +
                           N', @n_Err = 0 ' +
                           N', @c_ErrMsg = '''' '

      SELECT @cAPP_DB_Name         = APP_DB_Name,
         @cDataStream          = DataStream,
         @nThreadPerAcct       = ThreadPerAcct,
         @nThreadPerStream     = ThreadPerStream,
         @nMilisecondDelay     = MilisecondDelay,
         @cIP                  = [IP],
         @cPORT                = [PORT],
         @cIniFilePath         = IniFilePath,
         @cCmdType             = CmdType,
         @cTaskType            = TaskType
      FROM   QCmd_TransmitlogConfig WITH (NOLOCK)
      WHERE  TableName = 'LOGIReport'
      AND   [App_Name] = 'WMS'
      AND    StorerKey = 'ALL'


      EXEC isp_QCmd_SubmitTaskToQCommander
            @cTaskType         = 'O' -- D=By Datastream, T=Transmitlog, O=Others
            , @cStorerKey        = @cStorerKey
            , @cDataStream       = 'LOGIReport'
            , @cCmdType          = 'WSC'
            , @cCommand          = @cPrintCommand
            , @cTransmitlogKey   = ''
            , @nThreadPerAcct    = @nThreadPerAcct
            , @nThreadPerStream  = @nThreadPerStream
            , @nMilisecondDelay  = @nMilisecondDelay
            , @nSeq              = 1
            , @cIP               = @cIP
            , @cPORT             = @cPORT
            , @cIniFilePath      = @cIniFilePath
            , @cAPPDBName        = @cAPP_DB_Name
            , @bSuccess          = @bSuccess OUTPUT
            , @nErr              = @nErrNo OUTPUT
            , @cErrMsg           = @cErrMsg OUTPUT

      IF @nErrNo <> 0
         GOTO Quit

      GOTO Quit
   END

   ELSE IF @cProcessType  IN  ('ITFDOC','CMDSUMATRA')  --(yeekung01)  
   BEGIN
      DECLARE	@cURLHost   	NVARCHAR(200),
               @cFileFolder      NVARCHAR(100),
               @cFileFolderURL   NVARCHAR(500),
               @cURLPath         NVARCHAR(200)     = '' ,
               @cURLQuery        NVARCHAR(200)     = '' ,
               @cURL      	      NVARCHAR(1000),
               @cEncrypted   	   NVARCHAR(500),
               @cFileNameURL     NVARCHAR(500)     = ''  ,
               @cNonMovetoArchive NVARCHAR(20),
               @cPrintSettings   NVARCHAR(4000),
               @cStorerConfig    NVARCHAR(4000),
               @cCodeNotes       NVARCHAR(4000),
               @cWebServiceCode  NVARCHAR(20) = 'UTLWebAPI' --V3.1

      SELECT   @cDCropWidth  = DCropWidth,
               @cDCropHeight = DCropHeight,
               @cIsLandScape = IsLandScape,
               @cIsColor     = IsColor,
               @cIsDuplex    = IsDuplex,
               @cIsCollate   = IsCollate,
               @cPaperSize   = PaperSizeWxH,
               @cFileFolder  = FileFolder,
               @cPrintSettings = PrintSettings
      FROM rdt.rdtReportdetail (NOLOCK)
      Where reporttype = @cReportType
         AND storerkey = @cStorerkey

      --V3.1 start
      --Get Notes from WMPrintType Codelist
      SELECT TOP 1 
         @cCodeNotes = Notes
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE Listname = 'WMPrintTyp'
         AND Code = @cProcessType
         AND (Storerkey = '' OR StorerKey = @cStorerKey)
      ORDER BY StorerKey DESC

      SELECT @cWebServiceCode = dbo.fnc_GetParamValueFromString('@c_WebServiceCode', @cCodeNotes, @cWebServiceCode) 
      --V3.1 end

      SELECT TOP 1 @cURLHost = ISNULL(c.Long,'')
      FROM dbo.CODELKUP AS c (NOLOCK)
      WHERE c.Listname = 'WebService' 
         AND  c.Code = @cWebServiceCode --V3.1
         AND  c.Storerkey = ''
         AND  c.Code2= '' 

      SELECT TOP 1 
         @cURLPath  = ISNULL(IIF(CHARINDEX('?',c.Long,1)=0,c.Long,''),'')
         ,@cURLQuery = ISNULL(IIF(CHARINDEX('?',c.Long,1)>0,c.Long,''),'')
      FROM dbo.CODELKUP AS c WITH (NOLOCK)
      WHERE c.Listname = 'URLCfg' 
         AND  c.Code = @cProcessType
         AND  c.Code2= 'PrintReport'         --Function
         AND  c.Storerkey = ''

      IF @cURLHost = '' OR (@cURLPath='' AND @cURLQuery='')
      BEGIN
         SET @nErrNo = 110721
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --110721URLNOTSetup
         GOTO QUIT
      END

      SET @cURL = RTRIM(@cURLHost) + RTRIM(@cURLPath) + RTRIM(@cURLQuery)

      SET @cFileFolder = @cFileFolder + IIF(RIGHT(RTRIM(@cFileFolder),1) <> '\', '\','')

      SET @cEncrypted = ''
      SET @cEncrypted = MASTER.dbo.fnc_CryptoEncrypt(@cFileFolder,'') 

      SET @cFileFolderURL = ''
      EXEC master.dbo.isp_URLEncode
         @c_InputString  = @cEncrypted 
         ,@c_OutputString = @cFileFolderURL  OUTPUT 
         ,@c_vbErrMsg     = @cErrMsg         OUTPUT        
            
      SET @cFileFolderURL = RTRIM(@cFileFolderURL) 
                                    
      SET @cFileNameURL  = CASE WHEN @cURLQuery='' THEN ''
                                 ELSE '&filename='
                              END
                           + @cExportFileName

      SET  @cNonMovetoArchive = dbo.fnc_GetParamValueFromString( '@cNonMovetoArchive', @cPrintSettings,'')

      IF @cNonMovetoArchive = '1'
         SET @cStorerConfig = ''
      ELSE
         SET @cStorerConfig = '<MoveToArchive>'
            
      SET @cPrintData = @cURL + @cFileFolderURL + @cFileNameURL + ' ' + @cStorerConfig

      --SET @cPrintCommand = 'https://utlapp-uat.lflogistics.net/GenericAPI/GetFile?src=3uHMWDXP%2BThxB1USlNZYI5bN%2F%2FlArGBXfYt%2BawswGWIaTUrTW6vuDJMXy1BdLUYrDWllLbbZpvfZLCBIEltAFbdv0uSQIYtHxm6mHJScCCo%3D&filename=FMCGB2B_LP_0000000005.PDF'

      SET  @cDCropWidth    = CASE WHEN ISNULL(@cDCropWidth , '') = '' THEN '' ELSE @cDCropWidth  END
      SET  @cDCropHeight   = CASE WHEN ISNULL(@cDCropHeight, '') = '' THEN '' ELSE @cDCropHeight END
      SET  @cIsLandScape   = CASE WHEN ISNULL(@cIsLandScape, '') = '' THEN '' ELSE @cIsLandScape END
      SET  @cIsColor       = CASE WHEN ISNULL(@cIsColor    , '') = '' THEN '' ELSE @cIsColor     END
      SET  @cIsDuplex      = CASE WHEN ISNULL(@cIsDuplex   , '') = '' THEN '' ELSE @cIsDuplex    END
      SET  @cIsCollate     = CASE WHEN ISNULL(@cIsCollate  , '') = '' THEN '' ELSE @cIsCollate   END
      SET  @cPaperSize     = CASE WHEN ISNULL(@cPaperSize  , '') = '' THEN '' ELSE @cPaperSize   END
      SET  @cCloudClientPrinterID = CASE WHEN ISNULL(@cCloudClientPrinterID  , '') = '' THEN '' ELSE @cCloudClientPrinterID   END
      SET  @cPDFPreview = CASE WHEN ISNULL(@cPDFPreview  , '') = '' THEN '' ELSE @cPDFPreview   END

      -- Insert print job
      INSERT INTO rdt.rdtPrintJob (
         JobName, ReportID, JobStatus, Datawindow, NoOfParms, Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, StorerKey,
         Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10, Function_ID, ExportFileName
         ,PaperSizeWxH,DCropWidth,DCropHeight,IsLandScape,IsColor,IsDuplex,IsCollate)
      VALUES(
         @cSourceType, @cReportType, @cJobStatus, @cDataWindow, 0, @cPrinter, @nNoOfCopy, @nMobile, DB_NAME(), @cPrintData, @cProcessType, @cStorerKey,
         @cValue01, @cValue02, @cValue03, @cValue04, @cValue05, @cValue06, @cValue07, @cValue08, @cValue09, @cValue10, @nFunc, @cExportFileName
         ,@cPaperSize,@cDCropWidth,@cDCropHeight,@cIsLandScape,@cIsColor,@cIsDuplex,@cIsCollate)
      SELECT @nJobID = SCOPE_IDENTITY(), @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 110719
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PrnJobFail
         GOTO QUIT
      END

      UPDATE rdt.rdtPrintJob SET
         jobstatus ='9',
         EditDate = GETDATE(),
         EditWho  = SUSER_SNAME()
      WHERE JobID = @nJobID

      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 110724
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PrnJobFail
         GOTO QUIT
      END

      SET @cJobStatus = '9'

      EXEC [dbo].[isp_UpdateRDTPrintJobStatus]
         @n_JobID      = @nJobID
         ,@c_JobStatus  = @cJobStatus
         ,@c_JobErrMsg  = ''
         ,@b_Success    = @bSuccess OUTPUT
         ,@n_Err        = @nErrNo   OUTPUT
         ,@c_ErrMsg     = @cErrMsg  OUTPUT

      IF @nErrNo <> 0
      BEGIN
         GOTO QUIT
      END

      GOTO Quit
   END

   ELSE IF @cProcessType = 'ZPL'  --(yeekung01)
   BEGIN

      IF @cTemplate <> '' AND @cTemplateSP <> ''
      BEGIN
         -- Execute SP to merge data and template, output print data as ZPL code
         SET @cSQL = 'EXEC ' + RTRIM( @cTemplateSP) +
         ' @nMobile, @nFunc, @cLangCode, @cStorerKey, ' +
         ' @cValue01, @cValue02, @cValue03, @cValue04, @cValue05, @cValue06, @cValue07, @cValue08, @cValue09, @cValue10, ' +
         ' @cTemplate, @cPrintData OUTPUT, @nErrNo OUTPUT, @cErrMSG OUTPUT '

         SET @cSQLParam =
         '@nMobile      INT,            ' +
         '@nFunc        INT,            ' +
         '@cLangCode    NVARCHAR( 3),   ' +
         '@cStorerKey   NVARCHAR( 15),  ' +
         '@cValue01     NVARCHAR( 20),  ' +
         '@cValue02     NVARCHAR( 20),  ' +
         '@cValue03     NVARCHAR( 20),  ' +
         '@cValue04     NVARCHAR( 20),  ' +
         '@cValue05     NVARCHAR( 20),  ' +
         '@cValue06     NVARCHAR( 20),  ' +
         '@cValue07     NVARCHAR( 20),  ' +
         '@cValue08     NVARCHAR( 20),  ' +
         '@cValue09     NVARCHAR( 20),  ' +
         '@cValue10     NVARCHAR( 20),  ' +
         '@cTemplate    NVARCHAR( MAX), ' +
         '@cPrintData   NVARCHAR( MAX) OUTPUT, ' +
         '@nErrNo       INT            OUTPUT, ' +
         '@cErrMsg      NVARCHAR( 20)  OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @cStorerKey,
         @cValue01, @cValue02, @cValue03, @cValue04, @cValue05, @cValue06, @cValue07, @cValue08, @cValue09, @cValue10,
         @cTemplate, @cPrintData OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END

      SELECT   @cDCropWidth  = DCropWidth,
               @cDCropHeight = DCropHeight,
               @cIsLandScape = IsLandScape,
               @cIsColor     = IsColor,
               @cIsDuplex    = IsDuplex,
               @cIsCollate   = IsCollate,
               @cPaperSize   = PaperSizeWxH
      FROM rdt.rdtReportdetail (NOLOCK)
      Where reporttype = @cReportType
         AND Storerkey = @cStorerKey

      SET  @cDCropWidth    = CASE WHEN ISNULL(@cDCropWidth , '') = '' THEN '' ELSE @cDCropWidth  END
      SET  @cDCropHeight   = CASE WHEN ISNULL(@cDCropHeight, '') = '' THEN '' ELSE @cDCropHeight END
      SET  @cIsLandScape   = CASE WHEN ISNULL(@cIsLandScape, '') = '' THEN '' ELSE @cIsLandScape END
      SET  @cIsColor       = CASE WHEN ISNULL(@cIsColor    , '') = '' THEN '' ELSE @cIsColor     END
      SET  @cIsDuplex      = CASE WHEN ISNULL(@cIsDuplex   , '') = '' THEN '' ELSE @cIsDuplex    END
      SET  @cIsCollate     = CASE WHEN ISNULL(@cIsCollate  , '') = '' THEN '' ELSE @cIsCollate   END
      SET  @cPaperSize     = CASE WHEN ISNULL(@cPaperSize  , '') = '' THEN '' ELSE @cPaperSize   END
      SET  @cCloudClientPrinterID = CASE WHEN ISNULL(@cCloudClientPrinterID  , '') = '' THEN '' ELSE @cCloudClientPrinterID   END
      SET  @cPDFPreview = CASE WHEN ISNULL(@cPDFPreview  , '') = '' THEN '' ELSE @cPDFPreview   END

      -- Insert print job
      INSERT INTO rdt.rdtPrintJob (
         JobName, ReportID, JobStatus, Datawindow, NoOfParms, Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, StorerKey,
         Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10, Function_ID, ExportFileName
         ,PaperSizeWxH,DCropWidth,DCropHeight,IsLandScape,IsColor,IsDuplex,IsCollate)
      VALUES(
         @cSourceType, @cReportType, @cJobStatus, @cDataWindow, 0, @cPrinter, @nNoofCopy, @nMobile, DB_NAME(), @cPrintData, @cProcessType, @cStorerKey,
         @cValue01, @cValue02, @cValue03, @cValue04, @cValue05, @cValue06, @cValue07, @cValue08, @cValue09, @cValue10, @nFunc, @cExportFileName
         ,@cPaperSize,@cDCropWidth,@cDCropHeight,@cIsLandScape,@cIsColor,@cIsDuplex,@cIsCollate)
      SELECT @nJobID = SCOPE_IDENTITY(), @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 110722
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PrnJobFail
         GOTO QUIT
      END

      UPDATE rdt.rdtPrintJob SET
         jobstatus ='9',
         EditDate = GETDATE(),
         EditWho  = SUSER_SNAME()
      WHERE JobID = @nJobID

      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 110723
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PrnJobFail
         GOTO QUIT
      END

      EXEC [dbo].[isp_UpdateRDTPrintJobStatus]
      @n_JobID      = @nJobID
      ,@c_JobStatus  = '9'
      ,@c_JobErrMsg  = ''
      ,@b_Success    = @bSuccess OUTPUT
      ,@n_Err        = @nErrNo   OUTPUT
      ,@c_ErrMsg     = @cErrMsg  OUTPUT
      ,@c_PrintData  = @cPrintData

      GOTO QUIT
   END

   -- Direct print
   ELSE IF @cTemplate <> '' AND @cTemplateSP <> ''
   BEGIN
      -- Execute SP to merge data and template, output print data as ZPL code
      SET @cSQL = 'EXEC ' + RTRIM( @cTemplateSP) +
         ' @nMobile, @nFunc, @cLangCode, @cStorerKey, ' +
         ' @cValue01, @cValue02, @cValue03, @cValue04, @cValue05, @cValue06, @cValue07, @cValue08, @cValue09, @cValue10, ' +
         ' @cTemplate, @cPrintData OUTPUT, @nErrNo OUTPUT, @cErrMSG OUTPUT '

      SET @cSQLParam =
         '@nMobile      INT,            ' +
         '@nFunc        INT,            ' +
         '@cLangCode    NVARCHAR( 3),   ' +
         '@cStorerKey   NVARCHAR( 15),  ' +
         '@cValue01     NVARCHAR( 20),  ' +
         '@cValue02     NVARCHAR( 20),  ' +
         '@cValue03     NVARCHAR( 20),  ' +
         '@cValue04     NVARCHAR( 20),  ' +
         '@cValue05     NVARCHAR( 20),  ' +
         '@cValue06     NVARCHAR( 20),  ' +
         '@cValue07     NVARCHAR( 20),  ' +
         '@cValue08     NVARCHAR( 20),  ' +
         '@cValue09     NVARCHAR( 20),  ' +
         '@cValue10     NVARCHAR( 20),  ' +
         '@cTemplate    NVARCHAR( MAX), ' +
         '@cPrintData   NVARCHAR( MAX) OUTPUT, ' +
         '@nErrNo       INT            OUTPUT, ' +
         '@cErrMsg      NVARCHAR( 20)  OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @cStorerKey,
         @cValue01, @cValue02, @cValue03, @cValue04, @cValue05, @cValue06, @cValue07, @cValue08, @cValue09, @cValue10,
         @cTemplate, @cPrintData OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

      IF @nErrNo <> 0
         GOTO Quit

      -- Save print data and trigger remote printing in RDT handle
      UPDATE rdt.rdtMobrec SET
         EditDate = GETDATE(),
         RemotePrint = 1, -- 1=On
         V_MAX = @cPrintData
      WHERE Mobile = @nMobile
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 110711
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DirectPrn Fail
         GOTO Quit
      END

      SET @cJobType = 'DIRECTPRN'
      SET @cJobStatus = '9' -- Not trigger RDTSpooler
   END

   -- RDT Spooler (command)
   ELSE IF @cPrintCommand <> ''
   BEGIN
      SET @cJobType = 'COMMAND'
      SET @cPrintData = @cPrintCommand
   END

   -- RDT Spooler (DataWindow)
   ELSE
   BEGIN
      -- Check datawindow
      IF ISNULL( @cDataWindow, '') = ''
      BEGIN
         SET @nErrNo = 110712
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DW not setup
         GOTO Quit
      END

      SET @cJobType = 'DATAWINDOW'
   END

   IF @cProcessType <> 'QCOMMANDER' AND @cProcessType <> 'TCPSPOOLER' AND @cProcessType <> 'BARTENDER'  AND @cProcessType <> 'BARTENDERPRTSEQ'  AND @cProcessType<>'TPPrint'
   BEGIN
      SET @i = 0
      WHILE @i < @nNoOfCopy
      BEGIN
         -- Insert print job
         INSERT INTO rdt.rdtPrintJob (
            JobName, ReportID, JobStatus, Datawindow, NoOfParms, Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, StorerKey,
            Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10, Function_ID, ExportFileName)
         VALUES(
            @cSourceType, @cReportType, @cJobStatus, ISNULL( @cDataWindow, ''), 0, @cPrinter, 1, @nMobile, DB_NAME(), @cPrintData, @cJobType, @cStorerKey,
            @cValue01, @cValue02, @cValue03, @cValue04, @cValue05, @cValue06, @cValue07, @cValue08, @cValue09, @cValue10, @nFunc, @cExportFileName)

         SELECT @nJobID = SCOPE_IDENTITY()
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 110713
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PrnJobFail
         END
         SET @i = @i + 1
      END
   END

   IF (@cProcessType <> 'QCOMMANDER' AND @cProcessType <> 'TCPSPOOLER') OR -- All process except QCOMMANDER, TCPSPOOLER
      (@cProcessType = 'QCOMMANDER' AND @cPrintCommand <> '')  OR            -- QCOMMANDER with print command, like print PDF
      (@cProcessType IN (  'BARTENDER' ,'BARTENDERPRTSEQ' ) AND @b_PrintOverInternet = 0)
   BEGIN
      -- rdtspooler will be phased out so should be only bartender & direct print
      -- will have jobstatus = 9. Thus deleted by below stored proc
      IF @cJobStatus = '9'
      BEGIN
         EXEC [dbo].[isp_UpdateRDTPrintJobStatus]
            @n_JobID      = @nJobID
            ,@c_JobStatus  = @cJobStatus
            ,@c_JobErrMsg  = ''
            ,@b_Success    = @bSuccess OUTPUT
            ,@n_Err        = @nErrNo   OUTPUT
            ,@c_ErrMsg     = @cErrMsg  OUTPUT

         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 110718
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PrnLogFail
         END
      END
   END

Quit:

END


GO