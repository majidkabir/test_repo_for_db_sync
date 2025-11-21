SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtPrintZPL_GetTask                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 01-03-2018 1.0  Ung         Created                                  */
/************************************************************************/

CREATE PROC [RDT].[rdtPrintZPL_GetTask] (
    @cParam1      NVARCHAR(MAX)  -- rdtPrintJob.JobID
   ,@cParam2      NVARCHAR(MAX)  
   ,@cParam3      NVARCHAR(MAX)
   ,@cZPL	      NVARCHAR(MAX)  OUTPUT
   ,@cCodePage    NVARCHAR( 50)  OUTPUT
   ,@cPrinter     NVARCHAR( 128) OUTPUT
   ,@nErrNo       INT            OUTPUT
   ,@cErrMsg      NVARCHAR( 250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)

   DECLARE @nMobile        INT
   DECLARE @nFunc          INT
   DECLARE @cLangCode      NVARCHAR( 3)
   DECLARE @cStorerKey     NVARCHAR( 15)

   DECLARE @cJobID         NVARCHAR( 10)
   DECLARE @cReportType    NVARCHAR( 10)
   DECLARE @cTemplate      NVARCHAR( MAX)
   DECLARE @cTemplateSP    NVARCHAR( 40)
   DECLARE @cPrinterID     NVARCHAR( 10)
   DECLARE @cWinPrinter    NVARCHAR( 128)
   
   DECLARE @cValue01       NVARCHAR( 20)
   DECLARE @cValue02       NVARCHAR( 20)
   DECLARE @cValue03       NVARCHAR( 20)
   DECLARE @cValue04       NVARCHAR( 20)
   DECLARE @cValue05       NVARCHAR( 20)
   DECLARE @cValue06       NVARCHAR( 20)
   DECLARE @cValue07       NVARCHAR( 20)
   DECLARE @cValue08       NVARCHAR( 20)
   DECLARE @cValue09       NVARCHAR( 20)
   DECLARE @cValue10       NVARCHAR( 20)
   
   -- Param mapping
   SET @cJobID = @cParam1 
   SET @cLangCode = 'ENG'

   -- Get JobID info
   SELECT 
      @nMobile = Mobile, 
      @nFunc = 0, 
      @cStorerKey = StorerKey, 
      @cReportType = ReportID, 
      @cPrinterID = Printer, 
      @cValue01 = ISNULL( Parm1, ''), 
      @cValue02 = ISNULL( Parm2, ''), 
      @cValue03 = ISNULL( Parm3, ''), 
      @cValue04 = ISNULL( Parm4, ''), 
      @cValue05 = ISNULL( Parm5, ''), 
      @cValue06 = ISNULL( Parm6, ''), 
      @cValue07 = ISNULL( Parm7, ''), 
      @cValue08 = ISNULL( Parm8, ''), 
      @cValue09 = ISNULL( Parm9, ''), 
      @cValue10 = ISNULL( Parm10, '')
   FROM rdt.rdtPrintJob WITH (NOLOCK) 
   WHERE JobID = @cJobID

   -- Check Job ID 
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 120151
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --JobIDNotFound
      GOTO Quit
   END

   -- Get report info
   SELECT TOP 1
      @cTemplate = ISNULL( PrintTemplate, ''), 
      @cTemplateSP = ISNULL( PrintTemplateSP, '')
   FROM rdt.rdtReport WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND ReportTYpe = @cReportType
   -- rdtPrintJob does not carry Function_ID or facility
   --   AND (Function_ID = @nFunc OR Function_ID = 0)
   -- ORDER BY Function_ID DESC

   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 120152
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReportNotFound
      GOTO Quit
   END

   -- Get Printer info
   SELECT @cWinPrinter = WinPrinter FROM rdt.rdtPrinter WITH (NOLOCK) WHERE PrinterID = @cPrinterID
   
   -- Check printer
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 120153
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup Printer
      GOTO Quit
   END

   -- Chop off ",winspool..." in WinPrinter ("ZDesigner 105SLPlus-203dpi ZPL,winspool,Ne04:")
   DECLARE @i INT
   SELECT @i = CHARINDEX( ',winspool', @cWinPrinter)
   IF @i > 0
      SET @cWinPrinter = LEFT( @cWinPrinter, @i - 1) -- ("ZDesigner 105SLPlus-203dpi ZPL)
   SET @cPrinter = @cWinPrinter

   -- Execute SP to get ZPL
   IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cTemplateSP AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC ' + RTRIM( @cTemplateSP) +
         ' @nMobile, @nFunc, @cLangCode, @cStorerKey, ' + 
         ' @cValue01, @cValue02, @cValue03, @cValue04, @cValue05, @cValue06, @cValue07, @cValue08, @cValue09, @cValue10, ' +
         ' @cTemplate, @cZPL OUTPUT, @nErrNo OUTPUT, @cErrMSG OUTPUT, @cCodePage OUTPUT '

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
         '@cZPL   NVARCHAR( MAX) OUTPUT, ' +
         '@nErrNo       INT            OUTPUT, ' +
         '@cErrMsg      NVARCHAR( 20)  OUTPUT, ' + 
		 '@cCodePage    NVARCHAR( 50)  OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @cStorerKey,
         @cValue01, @cValue02, @cValue03, @cValue04, @cValue05, @cValue06, @cValue07, @cValue08, @cValue09, @cValue10,
         @cTemplate, @cZPL OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cCodePage OUTPUT
         
      IF @nErrNo <> 0
         GOTO Quit
   END
   ELSE
   BEGIN
      SET @nErrNo = 120154
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SP
      GOTO Quit
   END

Quit:

END

GO