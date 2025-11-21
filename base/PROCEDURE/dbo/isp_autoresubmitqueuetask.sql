SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store procedure: isp_AutoResubmitQueueTask                           */      
/* Creation Date: 11 Oct 2017                                           */      
/* Copyright: LFL                                                       */      
/* Written by: TKLIM                                                    */      
/*                                                                      */      
/* Purpose: To resend TCPSocket message to QueueCommander which failed  */      
/*           to send earlier                                            */      
/*                                                                      */      
/* Called By: SQL Job                                                   */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 1.0                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Date         Author    Ver.  Purposes                                */      
/* 11-Oct-2017  TKLIM     1.0   Initial                                 */      
/* 26-Oct-2017  TKLIM     1.0   Bug Fix                                 */      
/* 27-Sep-2018  TKLIM     1.0   Set status to 0 after send Socket Msg   */      
/* 28-Jun-2019  TKLIM     1.0   Add Priority (TK01)                     */      
/* 01-Oct-2019  TKLIM     1.0   Fixed Typo (TK02)                       */        
/* 18-Oct-2019  TKLIM     1.0   Add support WSC (TK02)                  */        
/************************************************************************/      
        
CREATE PROC [dbo].[isp_AutoResubmitQueueTask]      
            @cSourceDB           NVARCHAR(15)        
          , @cSourceDBSchema     NVARCHAR(15)         
          , @bSuccess            INT            OUTPUT         
          , @nErr                INT            OUTPUT         
          , @cErrMsg             NVARCHAR(256)  OUTPUT        
        
AS          
BEGIN          
      
   SET NOCOUNT ON           
   SET ANSI_NULLS OFF          
   SET QUOTED_IDENTIFIER OFF           
   SET CONCAT_NULL_YIELDS_NULL OFF          
           
   DECLARE @cExecStatement    NVARCHAR(4000)        
         , @cExecArguments    NVARCHAR(4000)         
         , @cDataReceived     NVARCHAR(4000)        
         , @cData             NVARCHAR(4000)         
         , @cStatusR          NVARCHAR(1)      
         , @cAddDate          NVARCHAR(30)      
         , @cIniFilePath      NVARCHAR(200)      
               
         , @cID               NVARCHAR(10)      
         , @cCmdType          NVARCHAR(10)      
         , @cTargetDB         NVARCHAR(30)      
         , @cCMD              NVARCHAR(1024)      
         , @cStorerKey        NVARCHAR(15)      
         , @cIP               NVARCHAR(20)       
         , @cPORT             NVARCHAR(5)        
         , @nPriority         INT        
      
   SET @cStatusR = 'R'      
   SET @cAddDate = DATEADD(minute, -10, GETDATE())      
   SET @cIniFilePath = 'C:\COMObject\GenericTCPSocketClient\config.ini'      
      
   SET @cExecStatement = N'DECLARE CUR_QueueTask CURSOR FAST_FORWARD READ_ONLY FOR '      
                        + ' SELECT  CAST(ID as NVARCHAR(20)), CmdType, TargetDB, CMD, StorerKey, IP, Port, Priority'    --(TK01)   
                        + ' FROM ' + @cSourceDB + '.' + @cSourceDBSchema + '.TCPSocket_QueueTask WITH (NOLOCK) '      
                        + ' WHERE ISNULL(RTRIM(Port),'''') <> '''' '      
                        --+ ' AND ISNULL(RTRIM(StorerKey),'''') <> '''' '      
                        + ' AND ISNULL(RTRIM(CmdType),'''') <> '''' '      
                        + ' AND ISNULL(RTRIM(TargetDB),'''') <> '''' '      
                        + ' AND ISNULL(RTRIM(CMD),'''') <> '''' '      
                        + ' AND ISNULL(RTRIM(IP),'''') <> '''' '      
                        + ' AND Status = @cStatusR '       
                        + ' AND AddDate < @cAddDate '    
                        + ' ORDER BY ID ASC '    
      
   SET @cExecArguments =  N'@cStatusR     NVARCHAR(1)'       
                        + ', @cAddDate    NVARCHAR(30)'      
      
   EXEC sp_ExecuteSql @cExecStatement       
                     , @cExecArguments        
                     , @cStatusR       
                     , @cAddDate      
                             
   OPEN CUR_QueueTask       
   FETCH NEXT FROM CUR_QueueTask INTO @cID, @cCmdType, @cTargetDB, @cCMD, @cStorerKey, @cIP, @cPort, @nPriority   --(TK01)
   WHILE @@FETCH_STATUS <> -1      
   BEGIN      
      
      IF @cCmdType IN ('CMD','WSC')    --(TK03)
         SET @cData = @cCmdType + '|' +  @cID + '|' + @cTargetDB + '|' + @cCMD + '|' + CONVERT(NVARCHAR(1),ISNULL(@nPriority,0))    --(TK01) --(TK02) 
      ELSE     --SQL, TCL      
         SET @cData = @cCmdType + '|' +  @cID + '|' + @cTargetDB + '|' + 'EXEC ' + @cTargetDB + '..isp_QCmd_ExecuteSQL @cTargetDB=''' + @cSourceDB + ''', @nQTaskID=' + @cID + '|' + CONVERT(NVARCHAR(1),ISNULL(@nPriority,0))   --(TK01)  --(TK02)
      
      
      EXEC isp_QCmd_SendTCPSocketMsg        
            @cApplication     = 'QCommander'        
          , @cStorerKey       = @cStorerKey         
          , @cMessageNum      = ''        
          , @cData            = @cData        
          , @cIP              = @cIP                 
          , @cPORT            = @cPORT               
          , @cIniFilePath     = 'C:\COMObject\GenericTCPSocketClient\config.ini'        
          , @cDataReceived    = @cDataReceived  OUTPUT      
          , @bSuccess         = @bSuccess       OUTPUT      
          , @nErr             = @nErr           OUTPUT      
          , @cErrMsg          = @cErrMsg        OUTPUT      
      
      IF @bSuccess = 1
      BEGIN
         SET @cExecStatement = N'UPDATE ' + @cSourceDB + '.' + @cSourceDBSchema + '.TCPSocket_QueueTask WITH (ROWLOCK)'      
                             + ' SET Status = ''0'' '
                             + ' WHERE ID = @cID '
                             + ' AND Status = @cStatusR '       

         SET @cExecArguments =  N'@cStatusR  NVARCHAR(1)'       
                             + ', @cID      NVARCHAR(20)'      
      
         EXEC sp_ExecuteSql @cExecStatement       
                           , @cExecArguments        
                           , @cStatusR       
                           , @cID      
      END

      FETCH NEXT FROM CUR_QueueTask INTO @cID, @cCmdType, @cTargetDB, @cCMD, @cStorerKey, @cIP, @cPort, @nPriority   --(TK01)      
         
   END      
   CLOSE CUR_QueueTask    
   DEALLOCATE CUR_QueueTask    
    
   RETURN          
           
END -- procedure          
      

GO