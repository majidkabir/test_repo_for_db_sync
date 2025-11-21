SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_BuiltPrintJob                                         */
/* Copyright      : IDS                                                       */
/*                                                                            */
/* Purpose: Built Print Job                                                   */
/*                                                                            */
/* Called from: Any RDT module that require insert into RDT.RDTPrintJob       */
/*                                                                            */
/* Exceed version: 5.4                                                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 11-Nov-2009 1.0  James       Created                                       */
/* 29-Jun-2010 1.1  Vicky       Take out debug Statement                      */
/* 29-Jun-2010 1.2  Vicky       For newly add in Parameter, should pass       */
/*                              in blank as default so that will not          */
/*                              affect existing SP that is calling this       */
/*                              (Vicky01)                                     */
/* 24-Nov-2011 1.3  Ung         Fix parameter sequence                        */
/* 18-Sep-2013 1.4  ChewKP      Add Features Remote Printing (ChewKP01)       */
/* 07-Apr-2014 1.5  James       Enable printing to bartender (james01)        */
/* 12-May-2014 1.6  James       Insert into RDT.RDTPrintJob for               */
/*                              bartender (james01)                           */
/* 28-May-2014 1.7  James       Get bartender printer name based on           */
/*                              customized sp (james02)                       */
/* 10-Jun-2014 1.8  James       Add function id (james03)                     */
/* 19-Aug-2014 1.9  Ung         Not overwrite err from RemotePrint SP         */
/* 02-Sep-2015 2.0  Ung         SOS351302 Add NoOfCopy param                  */
/* 06-Oct-2015 2.1  ChewKP      SOS#353352 Add Command Print                  */
/*                              (ChewKP02)                                    */
/* 10-Feb-2017 2.2  Ung         Add QCommander                                */
/*                              Clean up source                               */
/* 21-Sep-2017 2.3  Ung         Add Facility                                  */
/* 11-Oct-2017 2.4  Ung         Update TCPSocket_QueueTask.Status = X         */
/* 25-Oct-2017 2.5  SWT01       Include IP when insert into TCP Q Task        */
/*                              TransmitlogKey = JobID                        */
/* 08-Mar-2018 2.6  Ung         WMS-4248 print command to QCommander          */
/* 14-Aug-2018 2.7  Ung         Add JobID to QCmd and TCP                     */
/* 25-Oct-2018 2.8  Ung         Call isp_QCmd_UpdateQueueTaskStatus to update */
/*                              TCPSocket_QueueTask.Status = X                */
/* 30-Oct-2018 2.9  James       Add function id when insert printjob (james04)*/
/* 05-Nov-2018 3.0  James       Add to rdtprintjob_log (james05)              */
/* 06-Sep-2018 3.1  Ung         WMS-5843 Add back no print check              */
/* 07-Jan-2019 3.2  Ung         Add TCPSpooler                                */
/* 24-Feb-2020 3.3  Leong       INC1049672 - Revise BT Cmd parameters.        */
/******************************************************************************/

CREATE PROC [RDT].[rdt_BuiltPrintJob] (
   @nMobile       INT,
   @cStorerKey    NVARCHAR( 15),
   @cReportType   NVARCHAR( 10),
   @cPrintJobName NVARCHAR( 50),
   @cDataWindow   NVARCHAR( 50),
   @cPrinter      NVARCHAR( 50),
   @cTargetDB     NVARCHAR( 20),
   @cLangCode     NVARCHAR( 3),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT,
   @cByRef1       NVARCHAR( 20) = '',
   @cByRef2       NVARCHAR( 20) = '',
   @cByRef3       NVARCHAR( 20) = '',
   @cByRef4       NVARCHAR( 20) = '',
   @cByRef5       NVARCHAR( 20) = '',
   @cByRef6       NVARCHAR( 20) = '',
   @cByRef7       NVARCHAR( 20) = '',
   @cByRef8       NVARCHAR( 20) = '',
   @cByRef9       NVARCHAR( 20) = '',
   @cByRef10      NVARCHAR( 20) = '',
   @cNoOfCopy     NVARCHAR( 5)  = '1',
   @cPrintCommand NVARCHAR(MAX) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cSQL              NVARCHAR( MAX)
   DECLARE @cSQLParam         NVARCHAR( MAX)
   DECLARE @nFunc             INT
   DECLARE @cStatus           NVARCHAR( 1)
   DECLARE @cProcessType      NVARCHAR( 15)
   DECLARE @cPrintTemplate    NVARCHAR( MAX)
   DECLARE @cPrintTemplateSP  NVARCHAR( 80)
   DECLARE @cPrintData        NVARCHAR( MAX)
   DECLARE @cUserName         NVARCHAR( 18)
   DECLARE @cJobType          NVARCHAR( 10)
   DECLARE @cSpoolerGroup     NVARCHAR( 20)
   DECLARE @cFacility         NVARCHAR( 5)
   DECLARE @cIPAddress        NVARCHAR( 40)
   DECLARE @cPortNo           NVARCHAR( 5)
   DECLARE @cIniFilePath      NVARCHAR( 200)
   DECLARE @cDataReceived     NVARCHAR( 4000)
   DECLARE @cJobID            NVARCHAR( 10)
   DECLARE @nJobID            INT
   DECLARE @bSuccess          INT

   SET @cStatus      = '0'
   SET @cPrintData   = ''
   SET @cJobType     = ''
   SET @nErrNo       = 0

   -- Get session info
   SELECT
      @nFunc = Func,
      @cUserName = UserName,
      @cFacility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Get report info
   SELECT TOP 1
      @cProcessType = ProcessType,
      @cPrintTemplate = ISNULL( PrintTemplate, ''),
      @cPrintTemplateSP = ISNULL( PrintTemplateSP, '')
   FROM rdt.rdtReport WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND ReportTYpe = @cReportType
      AND (Facility = @cFacility OR Facility = '')
      AND (Function_ID = @nFunc OR Function_ID = 0)
   ORDER BY Facility DESC, Function_ID DESC

   -- Check report
   IF @@ROWCOUNT = 0
   BEGIN
      -- Remark for backward compatibility. Some module calls rdt_BuiltPrintJob blindly and rely on rdt.rdtReport setup/not setup to decide print/not print
      -- SET @nErrNo = 86451
      -- SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReportNotSetup
      GOTO Quit
   END

   -- Get printer info
   SELECT
      @cSpoolerGroup = SpoolerGroup
   FROM rdt.rdtPrinter WITH (NOLOCK)
   WHERE PrinterID = @cPrinter

   -- Check printer
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 86452
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PrinterNoSetup
      GOTO Quit
   END

   -- QCommander
   IF @cProcessType = 'QCOMMANDER'
   BEGIN
      DECLARE @cDBName       NVARCHAR( 30)
      DECLARE @cCommand      NVARCHAR( 1024)
      DECLARE @nQueueID      BIGINT

      -- Get spooler info
      SELECT
         @cIPAddress = IPAddress,
         @cPortNo = PortNo,
         @cCommand = Command,
         @cIniFilePath = IniFilePath
      FROM rdt.rdtSpooler WITH (NOLOCK)
      WHERE SpoolerGroup = @cSpoolerGroup

      -- Check valid
      IF @@ROWCOUNT = 0 OR @cIPAddress = '' OR @cPortNo = '' OR @cCommand = '' OR @cIniFilePath = ''
      BEGIN
         SET @nErrNo = 86453
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SpoolNot Setup
         GOTO Quit
      END

      SET @cDBName = DB_NAME()
      SET @cJobType = 'QCOMMANDER'

      IF @cPrintCommand <> ''
         SET @cStatus = '9'

      -- Insert print job
      INSERT INTO rdt.rdtPrintJob (
         JobName, ReportID, JobStatus, Datawindow, NoOfParms, Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, StorerKey,
         Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10, Function_ID)
      VALUES(
         @cPrintJobName, @cReportType, @cStatus, @cDataWindow, 0, @cPrinter, @cNoOfCopy, @nMobile, DB_NAME(), @cPrintCommand, @cJobType, @cStorerKey,
         @cByRef1, @cByRef2, @cByRef3, @cByRef4, @cByRef5, @cByRef6, @cByRef7, @cByRef8, @cByRef9, @cByRef10, @nFunc)
      SELECT @nJobID = SCOPE_IDENTITY(), @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 86454
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PrnJobFail
      END

      SET @cJobID = CAST( @nJobID AS NVARCHAR( 10))
      IF @cPrintCommand <> ''
         SET @cCommand = @cPrintCommand
      ELSE
         SET @cCommand = @cCommand + ' ' +  @cJobID

      -- Insert task (SWT01)
      INSERT INTO TCPSocket_QueueTask (CmdType, Cmd, StorerKey, Port, TargetDB, IP, TransmitLogKey, DataStream)
      VALUES ('CMD', @cCommand, @cStorerKey, @cPortNo, DB_NAME(), @cIPAddress, @cJobID, 'QSPOOLER')
      SELECT @nQueueID = SCOPE_IDENTITY(), @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 86455
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
         @cPORT         = @cPortNo,
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
            SET @nErrNo = 86460
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD QTask Fail
         END

         UPDATE rdt.rdtPrintJob SET
            JobStatus = 'E',
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE JobID = @nJobID
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 86461
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PrnJobFail
         END
         GOTO Quit
      END
   END

   -- TCPSpooler
   ELSE IF @cProcessType = 'TCPSPOOLER'
   BEGIN
      -- Get spooler info
      SELECT
         @cIPAddress = IPAddress,
         @cPortNo = PortNo,
         @cIniFilePath = IniFilePath
      FROM rdt.rdtSpooler WITH (NOLOCK)
      WHERE SpoolerGroup = @cSpoolerGroup

      -- Check valid
      IF @@ROWCOUNT = 0 OR @cIPAddress = '' OR @cPortNo = '' OR @cIniFilePath = ''
      BEGIN
         SET @nErrNo = 86463
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SpoolNot Setup
         GOTO Quit
      END

      SET @cJobType = 'TCPSPOOLER'

      IF @cPrintCommand <> ''
         SET @cStatus = '9'

      -- Insert print job
      INSERT INTO rdt.rdtPrintJob (
         JobName, ReportID, JobStatus, Datawindow, NoOfParms, Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, StorerKey,
         Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10, Function_ID)
      VALUES(
         @cPrintJobName, @cReportType, @cStatus, @cDataWindow, 0, @cPrinter, @cNoOfCopy, @nMobile, DB_NAME(), @cPrintCommand, @cJobType, @cStorerKey,
         @cByRef1, @cByRef2, @cByRef3, @cByRef4, @cByRef5, @cByRef6, @cByRef7, @cByRef8, @cByRef9, @cByRef10, @nFunc)
      SELECT @nJobID = SCOPE_IDENTITY(), @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 86464
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
            SET @nErrNo = 86465
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PrnJobFail
         END
         GOTO Quit
      END
   END

   -- Bartender
   -- ELSE IF @cProcessType = 'BARTENDER'
   ELSE IF EXISTS( SELECT 1 FROM dbo.BartenderLabelCfg WITH (NOLOCK) WHERE LabelType = @cReportType AND StorerKey = @cStorerKey)
   BEGIN
      -- Get printer
      DECLARE @cGetPrinterSP NVARCHAR( 20)
      SET @cGetPrinterSP = rdt.RDTGetConfig( @nFunc, 'GetPrinterSP', @cStorerKey)
      IF @cGetPrinterSP NOT IN ( '', '0')
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetPrinterSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC ' + RTRIM( @cGetPrinterSP) + ' @nMobile, @cStorerKey, @cReportType, @cPrinter OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT, ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cReportType     NVARCHAR( 10), ' +
               '@cPrinter        NVARCHAR( 50) OUTPUT'
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @nMobile, @cStorerKey, @cReportType, @cPrinter OUTPUT
         END
      END

      -- Check if printer setup
      IF ISNULL( @cPrinter, '') = ''
      BEGIN
         SET @nErrNo = 86461
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NO Printer
         GOTO Quit
      END

      -- Call bartender
      EXECUTE dbo.isp_BT_GenBartenderCommand
         @cPrinterID     = @cPrinter,        -- printer id
         @c_LabelType    = @cReportType,     -- label type
         @c_userid       = @cUserName,       -- user id
         @c_Parm01       = @cByRef1,         -- parm01
         @c_Parm02       = @cByRef2,         -- parm02
         @c_Parm03       = @cByRef3,         -- parm03
         @c_Parm04       = @cByRef4,         -- parm04
         @c_Parm05       = @cByRef5,         -- parm05
         @c_Parm06       = @cByRef6,         -- parm06
         @c_Parm07       = @cByRef7,         -- parm07
         @c_Parm08       = @cByRef8,         -- parm08
         @c_Parm09       = @cByRef9,         -- parm09
         @c_Parm10       = @cByRef10,        -- parm10
         @c_StorerKey    = @cStorerKey,      -- StorerKey
         @c_NoCopy       = @cNoOfCopy,       -- no of copy
         @b_Debug        = 0,                -- debug
         @c_Returnresult = 'N',              -- return result
         @n_err          = @nErrNo        OUTPUT,
         @c_errmsg       = @cErrMsg       OUTPUT

      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 86456
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BarTender Fail
         GOTO Quit
      END

      SET @cPrintJobName = 'isp_BT_GenBartenderCommand'
      SET @cJobType = 'BARTENDER'
      SET @cStatus = '9'
   END

   -- Direct print
   ELSE IF @cPrintTemplate <> '' AND @cPrintTemplateSP <> ''
   BEGIN
      -- Execute SP to merge data and template, output print data as ZPL code
      SET @cSQL = 'EXEC ' + RTRIM( @cPrintTemplateSP) +
         ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cByRef1, @cByRef2, @cByRef3, @cByRef4, @cByRef5, @cByRef6, @cByRef7, @cByRef8, @cByRef9, @cByRef10, ' +
         ' @cPrintTemplate, @cPrintData OUTPUT, @nErrNo OUTPUT, @cErrMSG OUTPUT '

      SET @cSQLParam =
         '@nMobile         INT,            ' +
         '@nFunc           INT,            ' +
         '@cLangCode       NVARCHAR( 3),   ' +
         '@cStorerKey      NVARCHAR( 15),  ' +
         '@cByRef1         NVARCHAR( 20),  ' +
         '@cByRef2         NVARCHAR( 20),  ' +
         '@cByRef3         NVARCHAR( 20),  ' +
         '@cByRef4         NVARCHAR( 20),  ' +
         '@cByRef5         NVARCHAR( 20),  ' +
         '@cByRef6         NVARCHAR( 20),  ' +
         '@cByRef7         NVARCHAR( 20),  ' +
         '@cByRef8         NVARCHAR( 20),  ' +
         '@cByRef9         NVARCHAR( 20),  ' +
         '@cByRef10        NVARCHAR( 20),  ' +
         '@cPrintTemplate  NVARCHAR( MAX), ' +
         '@cPrintData      NVARCHAR( MAX) OUTPUT, ' +
         '@nErrNo          INT            OUTPUT, ' +
         '@cErrMsg         NVARCHAR( 20)  OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @cStorerKey,
         @cByRef1, @cByRef2, @cByRef3, @cByRef4, @cByRef5, @cByRef6, @cByRef7, @cByRef8, @cByRef9, @cByRef10,
         @cPrintTemplate, @cPrintData OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

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
         SET @nErrNo = 86457
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DirectPrn Fail
         GOTO Quit
      END

      SET @cJobType = 'DIRECTPRN'
      SET @cStatus = '9' -- Not trigger RDTSpooler
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
         SET @nErrNo = 86458
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DW not setup
         GOTO Quit
      END

      SET @cJobType = 'DATAWINDOW'
   END

   IF @cProcessType <> 'QCOMMANDER' AND @cProcessType <> 'TCPSPOOLER'
   BEGIN
      -- Insert print job
      INSERT INTO rdt.rdtPrintJob (
         JobName, ReportID, JobStatus, Datawindow, NoOfParms, Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, StorerKey,
         Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10, Function_ID)
      VALUES(
         @cPrintJobName, @cReportType, @cStatus, ISNULL( @cDataWindow, ''), 0, @cPrinter, @cNoOfCopy, @nMobile, DB_NAME(), @cPrintData, @cJobType, @cStorerKey,
         @cByRef1, @cByRef2, @cByRef3, @cByRef4, @cByRef5, @cByRef6, @cByRef7, @cByRef8, @cByRef9, @cByRef10, @nFunc)

      SELECT @nJobID = SCOPE_IDENTITY()

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 86459
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PrnJobFail
      END

      -- rdtspooler will be phased out so should be only bartender & direct print
      -- will have jobstatus = 9. Thus need deleted by below stored proc
      IF @cStatus = '9'
      BEGIN
         EXEC [dbo].[isp_UpdateRDTPrintJobStatus]
             @n_JobID      = @nJobID
            ,@c_JobStatus  = @cStatus
            ,@c_JobErrMsg  = ''
            ,@b_Success    = @bSuccess   OUTPUT
            ,@n_Err        = @nErrNo  OUTPUT
            ,@c_ErrMsg     = @cErrMsg  OUTPUT

         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 86462
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PrnLogFail
         END
      END
   END

Quit:

END

GO