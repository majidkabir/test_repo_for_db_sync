SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_QCmd_ExecuteSQL                                */  
/* Creation Date: 17-Feb-2017                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Submitting task to Q commander                              */
/*          Duplicate from isp_SendTCPSocketMsg                         */  
/*                                                                      */  
/*                                                                      */  
/* Called By:  Generic SP Execute                                       */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author     Purposes                                     */ 
/* 04-Aug-2017  SHONG      Move Record to TCPSocket_QueueTask_Log       */
/*                         instead of update                            */
/* 25-Oct-2017  SHONG      Include new Column "IP" when insert          */
/* 26-Oct-2017  TKLIM      Add support to Status 'R' for retry (TK01)   */
/* 29-Oct-2017  TKLIM      Add param @cPort for optional filter (TK02)  */
/* 31-Oct-2017  TKLIM      Add @cThreadID @cMsgRecvDate for log (TK03)  */
/* 08-Nov-2018  SHONG      Skip Update on Status 1 (SWT01)              */  
/* 09-Nov-2017  TKLIM      Add support to Status 'T' for transfer (TK04)*/
/* 09-Nov-2017  TKLIM      Skip Update status 1 for Bartender (TK05)    */
/* 02-Apr-2019  TKLIM      Added Priority (TK06)                        */
/* 09-Oct-2020  TLTING01   Tuning add Hashvalue                         */
/************************************************************************/  
CREATE PROC [dbo].[isp_QCmd_ExecuteSQL]
   @cTargetDB        NVARCHAR(30),
   @nQTaskID         BIGINT, 
   @cPort            NVARCHAR(6) = '',          --(TK02)
   @cThreadID        NVARCHAR(20) = '',         --(TK03)
   @cMsgRecvDate     NVARCHAR(30) = '',         --(TK03)
   @bSuccess         INT=1            OUTPUT, 
   @nErr             INT=0            OUTPUT, 
   @cErrMsg          NVARCHAR(256)='' OUTPUT

AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   
   DECLARE @cQCmdType        NVARCHAR(20),
           @cQCmd            NVARCHAR(1024),
           @cDatastream      NVARCHAR(10),
           @nRowCount        INT, 
           @cStorerKey       NVARCHAR(15), 
           @cSQLStatement    NVARCHAR(4000),
           @cSQLParms        NVARCHAR(4000), 
           @cQStatus         NVARCHAR(1),
           @cQErrMsg         NVARCHAR(256),
           @nQNoOfTry        INT,                                    
           @cTableSchema     NVARCHAR(200), 
           @cGoToLabel       VARCHAR(200), 
           @dThreadStartTime DATETIME, 
           @nStartTranCount  INT = 0 ,
           @nHashValue       TINYINT
           
   SET @cTargetDB = ISNULL(@cTargetDB, '')
   SET @cTableSchema = ''
   SET @cGoToLabel = ''
   SET @nStartTranCount = @@TRANCOUNT 
   SET @cThreadID = ISNULL(RTRIM(@cThreadID),'')
  
   IF ISNULL(RTRIM(@cMsgRecvDate),'') = '' 
      SET @cMsgRecvDate = CONVERT(VARCHAR(23), GETDATE(), 121)

   /*******************************************
    *  Getting Schema Name for TCPSocket_QueueTask, 
    *  For OMS this table schema is IML
    *******************************************/
   SET @cSQLStatement = N'SELECT TOP 1 @cTableSchema = TBL.TABLE_SCHEMA ' + 
                         ' FROM	' + QUOTENAME(@cTargetDB) + '.[INFORMATION_SCHEMA].[TABLES] TBL ' + 
                         ' WHERE tbl.TABLE_NAME = ''TCPSocket_QueueTask'' '
   EXEC master.sys.sp_ExecuteSQL @cSQLStatement, N'@cTableSchema   NVARCHAR(200) OUTPUT',  @cTableSchema OUTPUT

   /*******************************************
    * Get Datails from Queue Task
    *******************************************/
   SET @cSQLStatement = N'SELECT @cQCmdType = tqt.CmdType' 
                      + N' , @cQCmd = tqt.Cmd' 
                      + N' , @cDatastream = tqt.[Datastream]'
                      + N' , @cQStatus = tqt.[Status]' 
                      + N' , @nQNoOfTry = tqt.[Try]'
                      + N' , @nHashValue = tqt.HashValue '  --TLTING01
                      + N' FROM ' + QUOTENAME(@cTargetDB) + '.' + QUOTENAME(@cTableSchema) + '.[TCPSocket_QueueTask] AS tqt WITH (NOLOCK)'
                      + N' WHERE tqt.ID = @nQTaskID' 
   --(TK02) - S
   IF ISNULL(RTRIM(@cPort),'') <> ''
   BEGIN
      SET @cSQLStatement = @cSQLStatement + N' AND tqt.Port = @cPort'
   END

   SET @cSQLStatement = @cSQLStatement + N' ;SET @nRowCount = @@ROWCOUNT '
   --(TK02) - E

   SET @cSQLParms = N'@nQTaskID     BIGINT'
                  + N',@cPort       NVARCHAR(6)'           --(TK02)
                  + N',@nHashValue  TINYINT OUTPUT '      --TLTING01
                  + N',@cQCmdType   NVARCHAR(20) OUTPUT'
                  + N',@cQCmd       NVARCHAR(1024) OUTPUT'
                  + N',@cDatastream NVARCHAR(10) OUTPUT'     --(TK05)
                  + N',@cQStatus    NVARCHAR(1) OUTPUT' 
                  + N',@nQNoOfTry   INT OUTPUT'
                  + N',@nRowCount   INT OUTPUT'
                   
   
   EXEC master.sys.sp_ExecuteSQL @cSQLStatement, @cSQLParms,
        @nQTaskID, 
        @cPort,               --(TK02)
        @nHashValue  OUTPUT,        --TLTING01
        @cQCmdType   OUTPUT,
        @cQCmd       OUTPUT,
        @cDatastream OUTPUT,  --(TK05)
        @cQStatus    OUTPUT,
        @nQNoOfTry   OUTPUT,
        @nRowCount   OUTPUT
   
   IF @nRowCount = 0
   BEGIN
   	/* No Record Found, Do Nothing! */
   	GOTO QUIT_PROC
   END
   
   SET @dThreadStartTime = GETDATE()
   
   IF @cQStatus IN ('9','5')
   BEGIN
   	/* Already Executed, Do Nothing! */
   	GOTO QUIT_PROC 
   END
   
   IF @cQCmdType IN ('CMD')
   BEGIN
   	SET @cQStatus = '9'
   	GOTO UPDATE_QUEUE_TASK
   END 
   
   IF @cQStatus IN ('0','1','R','T') --(TK01) (TK04) - Add support status R and T
   BEGIN
   	SET @cQStatus  = '1'
   	SET @cQErrMsg  = ''
   	SET @nQNoOfTry = 1

      -- Added By SHONG (Do not want to update) (SWT01)  
      IF @cDatastream = 'BARTENDER'    --(TK05)
         GOTO START_PROCESS  

   END      
   SET @cGoToLabel = 'START_PROCESS'
   
   GOTO UPDATE_QUEUE_TASK

   START_PROCESS:

   SET @cGoToLabel = ''       --Reset to blank to avoid infinite loop
   IF @cQCmdType IN ('SQL','TCL') 
   BEGIN
      SET @cSQLStatement = @cQCmd

      BEGIN TRY
         EXEC sp_executesql @cSQLStatement
   	   SET @cQStatus = '9'

         WHILE @@TRANCOUNT > 0 
            COMMIT TRAN;
   	   
      END TRY
      BEGIN CATCH   	 
   		SELECT @cQErrMsg = 'Error: (' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ') - ' + ERROR_MESSAGE()  
   	   SET @cQStatus = '5'
   	   
   	   IF @@TRANCOUNT > 0 
   	      ROLLBACK TRAN 
      END CATCH      	
   END
   
   UPDATE_QUEUE_TASK:

   IF @cQStatus = '1'
   BEGIN
   	SET @cSQLStatement = 
      N'UPDATE ' + QUOTENAME(@cTargetDB) + '.' + QUOTENAME(@cTableSchema) + '.' + '[TCPSocket_QueueTask] WITH (ROWLOCK) ' + 
      N' SET [Status] = @cQStatus ' +
      N', EditDate = Getdate(), EditWho = sUser_sName() '  + 
   	N', Try = ISNULL(Try,0) + 1, ThreadStartTime = Getdate(), ThreadEndTime= NULL' + 
   	N' WHERE ID = @nQTaskID ' + 
      N' AND HashValue = @nHashValue ' +    --TLTING01
      N'SET @nRowCount = @@ROWCOUNT '   
   END
   ELSE 
   BEGIN
      SET @cSQLStatement = 
         N'BEGIN TRANSACTION; ' + CHAR(13) + 
         N'INSERT INTO ' + QUOTENAME(@cTargetDB) + '.' + QUOTENAME(@cTableSchema) + '.' + '[TCPSocket_QueueTask_Log] ' + 
         N'( ID, CmdType, Cmd, StorerKey, ThreadPerAcct, ThreadPerStream, MilisecondDelay, DataStream, TransmitLogKey, '+ 
	      N'[Status], ThreadId, ThreadStartTime, ThreadEndTime, ErrMsg, [Try], SEQ, Port, TargetDB, ' + 
	      N'AddDate, AddWho, EditDate, EditWho, ArchiveCop, TrafficCop, IP, MsgRecvDate, Priority ) ' +      	--TK06 TK03
         N'SELECT ID, CmdType, Cmd, StorerKey, ThreadPerAcct, ThreadPerStream, ' +
	      N'MilisecondDelay, DataStream, TransmitLogKey, ' + 
	      N'[Status] = @cQStatus, ' +
	      N'ThreadId = @cThreadID, ThreadStartTime = @dThreadStartTime, ThreadEndTime = Getdate(), ' +    --TK03
	      N'ErrMsg = CASE WHEN @cQStatus = ''5'' THEN @cQErrMsg ELSE '''' END, ' +   
	      N'[Try], SEQ, Port, TargetDB, ' + 
	      N'AddDate, AddWho,' +
	      N'EditDate = Getdate(), EditWho = sUser_sName(), ' + 
	      N'ArchiveCop, TrafficCop, IP, MsgRecvDate = @cMsgRecvDate, Priority ' +    --TK06 TK03
         N'FROM ' + QUOTENAME(@cTargetDB) + '.' + QUOTENAME(@cTableSchema) + '.' + '[TCPSocket_QueueTask] WITH (NOLOCK) ' + 
         N'WHERE ID = @nQTaskID ' + CHAR(13) +
         N' AND HashValue = @nHashValue; ' + CHAR(13) +
         N'SET @nRowCount = @@ROWCOUNT; ' + CHAR(13) + 
         N'IF @@ERROR = 0 AND @nRowCount = 1 ' + CHAR(13) + 
         N'BEGIN ' + CHAR(13) + 
         N'   DELETE FROM ' + QUOTENAME(@cTargetDB) + '.' + QUOTENAME(@cTableSchema) + '.' + '[TCPSocket_QueueTask] ' + CHAR(13) +
         N'   WHERE ID = @nQTaskID ' + CHAR(13) +
         N'   AND HashValue = @nHashValue; ' + CHAR(13) +
         N'   COMMIT TRANSACTION; ' + CHAR(13) + 
         N'END '+ CHAR(13) +
         N'ELSE '+ CHAR(13) +
         N'BEGIN ' + CHAR(13) +
         N'   IF @@TRANCOUNT > 0 ' + CHAR(13) +
         N'      ROLLBACK TRANSACTION; '+ CHAR(13) + 
         N'END '+ CHAR(13)    	
   END 
      
   SET @cSQLParms = N'@nQTaskID  BIGINT, @cQStatus  NVARCHAR(1), @cQErrMsg NVARCHAR(256), @cThreadID NVARCHAR(20), @cMsgRecvDate NVARCHAR(30), @nRowCount INT OUTPUT, @dThreadStartTime DATETIME '   	--TK03
                        + ' , @nHashValue TINYINT '                    

   EXEC master.sys.sp_ExecuteSQL @cSQLStatement, @cSQLParms, @nQTaskID, @cQStatus, @cQErrMsg, @cThreadID, @cMsgRecvDate, @nRowCount OUTPUT, @dThreadStartTime   
               , @nHashValue  

   WHILE @@TRANCOUNT < @nStartTranCount
      BEGIN TRAN
          
   IF @cGoToLabel = 'START_PROCESS' 
      GOTO START_PROCESS
   
   QUIT_PROC:
   
END -- procedure


GO