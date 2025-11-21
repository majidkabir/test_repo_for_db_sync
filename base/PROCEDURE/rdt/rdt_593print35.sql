SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_593Print35                                      */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2022-04-01  1.0  Ung      WMS-19306 Created                          */
/* 2022-11-08  1.1  Ung      WMS-21157 Add ResubmitInterval             */
/************************************************************************/

CREATE   PROC [RDT].[rdt_593Print35] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 2),
   @cParam1    NVARCHAR(20),  -- LoadKey
   @cParam2    NVARCHAR(20),  -- CartonType
   @cParam3    NVARCHAR(20),
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cCartonType NVARCHAR( 10)

   -- Param mapping
   SET @cLoadKey = @cParam1
   SET @cCartonType = @cParam2
   
   -- Check blank
   IF @cLoadKey = ''
   BEGIN
      SET @nErrNo = 185101
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LoadKey\
      EXEC rdt.rdtSetFocusField @nMobile, 2
      GOTO Quit
   END

   -- Check Load valid
   IF NOT EXISTS( SELECT 1 FROM dbo.LoadPlanDetail WITH (NOLOCK) WHERE LoadKey = @cLoadKey)
   BEGIN
      SET @nErrNo = 185102
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Load NotExist
            EXEC rdt.rdtSetFocusField @nMobile, 2
      GOTO Quit
   END

   -- Check blank
   IF @cCartonType = ''
   BEGIN
      SET @nErrNo = 185103
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedCartonType
      EXEC rdt.rdtSetFocusField @nMobile, 4
      GOTO Quit
   END

   -- Check carton type valid
   IF NOT EXISTS( SELECT 1 
      FROM dbo.Cartonization C WITH (NOLOCK) 
         JOIN dbo.Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)
      WHERE S.StorerKey = @cStorerKey
         AND C.CartonType = @cCartonType)
   BEGIN
      SET @nErrNo = 185104
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CartonType
      EXEC rdt.rdtSetFocusField @nMobile, 4
      GOTO Quit
   END


   /***********************************************************************************************
                                             Submit a job
   ***********************************************************************************************/
   DECLARE @bSuccess       INT  
   DECLARE @cCR            NCHAR(1) = NCHAR(13) -- Carriage return
   DECLARE @cLF            NCHAR(1) = NCHAR(10) -- Line feed
   DECLARE @cNotes         NVARCHAR( 4000)
   DECLARE @cIPAddress     NVARCHAR( 40) = ''
   DECLARE @cPortNo        NVARCHAR( 5) = ''
   DECLARE @cIniFilePath   NVARCHAR( 200) = ''
   DECLARE @cCommand       NVARCHAR( 1024)
   DECLARE @cPrintData     NVARCHAR( 1024)
   DECLARE @nQueueID       BIGINT
   DECLARE @tConfig        VariableTable

   -- Get storer config
   DECLARE @cIntervalInMin NVARCHAR(2)
   SET @cIntervalInMin = rdt.RDTGetConfig( @nFunc, 'ResubmitInterval', @cStorerKey)

   -- Check resubmit interval
   IF rdt.rdtIsValidQTY( @cIntervalInMin, 1) = 1
   BEGIN
      -- Get Load info
      DECLARE @dUserDefine06 DATETIME
      SELECT @dUserDefine06 = ISNULL( UserDefine06, 0) 
      FROM LoadPlan WITH (NOLOCK)
      WHERE LoadKey = @cLoadKey
   
      -- Check job just submitted
      IF DATEDIFF( mi, @dUserDefine06, GETDATE()) <= CAST( @cIntervalInMin AS INT)
      BEGIN
         SET @nErrNo = 185108
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --JobJustSubmit
         GOTO Quit
      END
   END

   -- Get report info
   SELECT @cNotes = ISNULL( Notes, '')
   FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTLBLRPT' 
      AND StorerKey = @cStorerKey
      AND Code = @cOption
   
   -- Replace CR with LF (due to STRING_SPLIT only accept 1 char delimeter)
   SET @cNotes = REPLACE( @cNotes, @cCR, '')

   -- Abstract data from CodeLKUP.Notes
   INSERT INTO @tConfig (Variable, Value)
   SELECT 
      SUBSTRING( Value, 1, CHARINDEX( '=', Value) - 1),          --ConfigKey
      SUBSTRING( Value, CHARINDEX( '=', Value) + 1, LEN( Value)) --SValue
   FROM STRING_SPLIT( @cNotes, @cLF)
   WHERE CHARINDEX( '=', Value) > 0 -- Filter out lines without delimeter

   SELECT @cIPAddress = Value FROM @tConfig WHERE Variable = 'IPAddress'
   SELECT @cPortNo = Value FROM @tConfig WHERE Variable = 'PortNo'
   SELECT @cIniFilePath = Value FROM @tConfig WHERE Variable = 'IniFilePath'

   -- Check QCommander setup
   IF @cIPAddress = '' OR @cPortNo = '' OR @cIniFilePath = ''
   BEGIN
      SET @nErrNo = 185105
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need IP & Port
      GOTO Quit
   END
   
   -- Construct the T-SQL command
   SET @cCommand = 
      'EXEC [rdt].[rdt_593Print35_LoadPickPack]' + 
         ' @cLoadKey = ''' + @cLoadKey + ''',' + 
         ' @cCartonType = ''' + @cCartonType + ''''
   
   -- Insert task  
   INSERT INTO TCPSocket_QueueTask (CmdType, Cmd, StorerKey, Port, TargetDB, IP, TransmitLogKey, DataStream)             
   VALUES ('SQL', @cCommand, @cStorerKey, @cPortNo, DB_NAME(), @cIPAddress, '593', 'RDT')  
   SELECT @nQueueID = SCOPE_IDENTITY(), @nErrNo = @@ERROR  
   IF @nErrNo <> 0  
   BEGIN  
      SET @nErrNo = 185106  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS QTask Fail  
      GOTO Quit  
   END  
     
   -- <STX>SQL|326876358|CNWMS|EXEC CNWMS..isp_QCmd_ExecuteSQL @cTargetDB='CNWMS', @nQTaskID=326876358, @cPort='30801'<ETX>
   SET @cCommand =   
      '<STX>' +   
         'SQL|' +   
         CAST( @nQueueID AS NVARCHAR( 20)) + '|' +   
         DB_NAME() + '|' +   
         'EXEC ' +  DB_NAME() + '..' + 'isp_QCmd_ExecuteSQL' + 
            ' @cTargetDB=''' + DB_NAME() + '''' + 
            ', @nQTaskID=' + CAST( @nQueueID AS NVARCHAR( 20)) + 
            ', @cPort=''' + @cPortNo + '''' + 
      '<ETX>'  

   -- Call Qcommander  
   EXEC isp_QCmd_SendTCPSocketMsg  
      @cApplication  = 'QCommander',  
      @cStorerKey    = @cStorerKey,   
      @cMessageNum   = @nQueueID,  
      @cData         = @cCommand,  
      @cIP           = @cIPAddress,   
      @cPORT         = @cPortNo,   
      @cIniFilePath  = @cIniFilePath,   
      @cDataReceived = '', --@cDataReceived OUTPUT,  
      @bSuccess      = @bSuccess      OUTPUT,   
      @nErr          = @nErrNo        OUTPUT,   
      @cErrMsg       = @cErrMsg       OUTPUT  
   IF @nErrNo <> 0  
   BEGIN  
      DECLARE @cDBName NVARCHAR( 30) = DB_NAME()
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
         SET @nErrNo = 185107  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD QTask Fail  
         GOTO Quit
      END  
   END
  
   UPDATE LoadPlan SET
      UserDefine06 = GETDATE(), 
      EditDate = GETDATE(), 
      EditWho = SUSER_SNAME(),  
      TrafficCop = NULL 
   WHERE LoadKey = @cLoadKey
   IF @@ERROR <> 0
   BEGIN  
      SET @nErrNo = 185109 
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Load Fail 
      GOTO Quit
   END 
  
Quit:

END


GO