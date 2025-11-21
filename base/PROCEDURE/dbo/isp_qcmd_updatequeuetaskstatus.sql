SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_QCmd_UpdateQueueTaskStatus                     */  
/* Creation Date: 25-Feb-2017                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: TKLIM                                                    */  
/*                                                                      */  
/* Purpose: Update status into TCPSocket_QueueTask table                */  
/*                                                                      */  
/* Called By: QCommander program                                        */  
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
/* 08-Aug-2017  TKLIM      Get ThreadStartdate time from existing record*/
/* 13-Aug-2018  TKLIM      Update MsgRecvDate                           */
/* 15-Aug-2018  TKLIM      Update ThreadID                              */
/* 30-Aug-2018  TKLIM      Bug Fix ThreadID                             */
/* 08-Nov-2018  TKLIM      Update ThreadStartTime = GETDATE() when NULL */
/* 10-Nov-2018  TKLIM      Add param ThreadStartTime & ThreadEndTime    */
/* 06-Dec-2018  TKLIM      Set ThreadStartTime & ThreadEndTime = null   */
/* 02-Apr-2019  TKLIM      Added Priority (TK06)                        */
/* 09-Oct-2020  TLTING     Tuning add HashValue                         */
/* 09-Oct-2020  TKLIM      Bug Fix @nRowCount not declared              */
/************************************************************************/  
CREATE PROC [dbo].[isp_QCmd_UpdateQueueTaskStatus]
   @cTargetDB        NVARCHAR(30),
   @nQTaskID         BIGINT, 
   @cQStatus         NVARCHAR(1),
   @cThreadID        NVARCHAR(20),
   @cMsgRecvDate     NVARCHAR(30),
   @dThreadStartTime DATETIME = null,
   @dThreadEndTime   DATETIME = null,
   @cQErrMsg         NVARCHAR(256),
   @bSuccess         INT=1            OUTPUT, 
   @nErr             INT=0            OUTPUT, 
   @cErrMsg          NVARCHAR(256)='' OUTPUT

AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE 
           @nRowCount         INT, 
           @cSQLStatement     NVARCHAR(4000),
           @cSQLParms         NVARCHAR(4000), 
           @cTableSchema      NVARCHAR(200)

   DECLARE @nHashValue     TINYINT
           
   SET @cTargetDB = ISNULL(@cTargetDB, '')
   SET @cTableSchema = ''
   
   /*******************************************
    *  Getting Schema Name for TCPSocket_QueueTask, 
    *  For OMS this table schema is IML
    *******************************************/
   SET @cSQLStatement = N'SELECT TOP 1 @cTableSchema = TBL.TABLE_SCHEMA ' + 
                         ' FROM ' + QUOTENAME(@cTargetDB) + '.[INFORMATION_SCHEMA].[TABLES] TBL ' +     
                         ' WHERE tbl.TABLE_NAME = ''TCPSocket_QueueTask'' '
   EXEC master.sys.sp_ExecuteSQL @cSQLStatement, N'@cTableSchema   NVARCHAR(200) OUTPUT',  @cTableSchema OUTPUT

   /*******************************************
   * Get Datails from Queue Task
   *******************************************/
   SET @cSQLStatement = N'SELECT  @nHashValue = tqt.HashValue '  --tltingxx
                      + N' FROM ' + QUOTENAME(@cTargetDB) + '.' + QUOTENAME(@cTableSchema) + '.[TCPSocket_QueueTask] AS tqt WITH (NOLOCK)'
                      + N' WHERE tqt.ID = @nQTaskID' 
   

   SET @cSQLStatement = @cSQLStatement + N' ;SET @nRowCount = @@ROWCOUNT '
   --(TK02) - E

   SET @cSQLParms = N'@nQTaskID     BIGINT'
                  + N',@nHashValue  TINYINT OUTPUT '      --tltingxx
                  + N',@nRowCount   INT OUTPUT '         --TK07
                   
   
   EXEC master.sys.sp_ExecuteSQL @cSQLStatement, @cSQLParms,
         @nQTaskID, 
         @nHashValue OUTPUT,      --tltingxx
         @nRowCount OUTPUT        --TK07
       
   
   IF @nRowCount = 0
   BEGIN
   	/* No Record Found, Do Nothing! */
   	GOTO QUIT_PROC
   END


   /*******************************************
    *  Start update QueueTask table
    *******************************************/

   IF @cQStatus = '1'
   BEGIN
      SET @cSQLStatement = 
         N'UPDATE ' + QUOTENAME(@cTargetDB) + '.' + QUOTENAME(@cTableSchema) + '.' + '[TCPSocket_QueueTask] WITH (ROWLOCK) ' + 
         N' SET [Status] = @cQStatus ' +
         N', EditDate = Getdate(), EditWho = sUser_sName() '  + 
         N', Try = ISNULL(Try,0) + 1, ThreadStartTime = Getdate(), ThreadEndTime= NULL' + 
         N', ThreadID = @cThreadID '  + 
         N', MsgRecvDate = @cMsgRecvDate '  +
         N' WHERE ID = @nQTaskID; ' + 
         N'SET @nRowCount = @@ROWCOUNT '
   END
   ELSE 
   BEGIN
      SET @cSQLStatement = 
         N'BEGIN TRANSACTION; ' + CHAR(13) + 
         N'INSERT INTO ' + QUOTENAME(@cTargetDB) + '.' + QUOTENAME(@cTableSchema) + '.' + '[TCPSocket_QueueTask_Log] ' + 
         N'( ID, CmdType, Cmd, StorerKey, ThreadPerAcct, ThreadPerStream, MilisecondDelay, DataStream, TransmitLogKey, '+ 
         N'[Status], ThreadId, ThreadStartTime, ThreadEndTime, ErrMsg, [Try], SEQ, Port, TargetDB, ' + 
         N'AddDate, AddWho, EditDate, EditWho, ArchiveCop, TrafficCop, IP, MsgRecvDate, Priority ) ' +         --(TK06) 
            	
         N'SELECT ID, CmdType, Cmd, StorerKey, ThreadPerAcct, ThreadPerStream, ' +
         N'MilisecondDelay, DataStream, TransmitLogKey, ' + 
         N'[Status] = @cQStatus, ' +
         --N'ThreadId, ThreadStartTime = @dThreadStartTime, ThreadEndTime = Getdate(), ' +
	      N'ThreadId = @cThreadID, ' +
         N' ThreadStartTime = CASE WHEN ISNULL(RTRIM(@dThreadStartTime),'''') = '''' THEN GETDATE() ELSE @dThreadStartTime END, ' + 
         N' ThreadEndTime = CASE WHEN ISNULL(RTRIM(@dThreadEndTime),'''') = '''' THEN GETDATE() ELSE @dThreadEndTime END, ' + 
         N'ErrMsg = CASE WHEN @cQStatus = ''9'' THEN '''' ELSE @cQErrMsg END, ' +
         N'[Try], SEQ, Port, TargetDB, ' + 
         N'AddDate, AddWho,' +
         N'EditDate = Getdate(), EditWho = sUser_sName(), ' + 
	      N'ArchiveCop, TrafficCop, IP, @cMsgRecvDate, Priority  ' +     --(TK06)
         N'FROM ' + QUOTENAME(@cTargetDB) + '.' + QUOTENAME(@cTableSchema) + '.' + '[TCPSocket_QueueTask] WITH (NOLOCK) ' + 
         N'WHERE ID = @nQTaskID ' + CHAR(13) +
         N'   AND  HashValue =  @nHashValue; ' + CHAR(13) +
         N'SET @nRowCount = @@ROWCOUNT; ' + CHAR(13) + 
         N'IF @@ERROR = 0 AND @nRowCount = 1 ' + CHAR(13) + 
         N'BEGIN ' + CHAR(13) + 
         N'   DELETE FROM ' + QUOTENAME(@cTargetDB) + '.' + QUOTENAME(@cTableSchema) + '.' + '[TCPSocket_QueueTask] ' + CHAR(13) +
         N'   WHERE ID = @nQTaskID ' + CHAR(13) +
         N'   AND  HashValue =  @nHashValue; ' + CHAR(13) +
         N'   COMMIT TRANSACTION; ' + CHAR(13) + 
         N'END '+ CHAR(13) +
         N'ELSE '+ CHAR(13) +
         N'BEGIN ' + CHAR(13) +
         N'   ROLLBACK TRANSACTION; '+ CHAR(13) + 
         N'END '+ CHAR(13)
   END 
      
   SET @cSQLParms = N'@nQTaskID  BIGINT'
                  + ', @cQStatus NVARCHAR(1)'
                  + ', @cQErrMsg NVARCHAR(256)'
                  + ', @cThreadID NVARCHAR(20)'
                  + ', @cMsgRecvDate NVARCHAR(30)'
                  + ', @dThreadStartTime DATETIME'
                  + ', @dThreadEndTime   DATETIME'
                  + ', @nHashValue TINYINT '
                  + ', @nRowCount INT OUTPUT' 
                  

   EXEC master.sys.sp_ExecuteSQL @cSQLStatement
               , @cSQLParms
               , @nQTaskID
               , @cQStatus
               , @cQErrMsg
               , @cThreadID
               , @cMsgRecvDate
               , @dThreadStartTime
               , @dThreadEndTime
               , @nHashValue
               , @nRowCount OUTPUT 
    

   QUIT_PROC:

END -- procedure

GO