SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Stored Procedure: isp_QCmd_BETTransmitLogInsertAlert                 */      
/* Creation Date: 26-Jun-2018                                           */      
/* Copyright: LF Logistics                                              */      
/* Written by: Alex Keoh                                                */      
/*                                                                      */      
/* Purpose: Submitting task to Q commander                              */      
/*                                                                      */      
/*                                                                      */      
/* Called By:  By WMS DB - During Transmitlog Insertion                 */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 1.0                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date        Author   Ver.  Purposes                                  */     
/************************************************************************/      
CREATE PROC [dbo].[isp_QCmd_BETTransmitLogInsertAlert]     
            @c_QCmdClass            NVARCHAR(10)   = ''          
          , @c_FrmTransmitlogKey    NVARCHAR(10)   = ''     
          , @c_ToTransmitlogKey     NVARCHAR(10)   = ''                    
          , @b_Debug                INT            = 0                
          , @b_Success              INT             OUTPUT                          
          , @n_Err                  INT             OUTPUT      
          , @c_ErrMsg               NVARCHAR(250)   OUTPUT      
          --, @n_PortLimit            INT            = 0     
AS     
BEGIN    
            
   SET NOCOUNT ON    
   SET ANSI_DEFAULTS OFF      
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF       
    
   DECLARE @c_ExecStatements        NVARCHAR(4000)    
         , @c_ExecArguments         NVARCHAR(4000)     
         , @c_ExecLogStatement      NVARCHAR(MAX)              
         , @n_Continue              INT          
         , @n_StartTCnt             INT        
    
   DECLARE @c_APP_DB_Name           NVARCHAR(20)    
         , @c_DataStream            VARCHAR(10)    
         , @n_ThreadPerAcct         INT     
         , @n_ThreadPerStream       INT     
         , @n_MilisecondDelay       INT     
         , @c_StorerKey             NVARCHAR(15)     
         , @c_TableName             NVARCHAR(20)     
         , @c_IP                    NVARCHAR(20)    
         , @c_PORT                  NVARCHAR(5)    
         , @c_IniFilePath           NVARCHAR(200)    
         , @c_CmdType               NVARCHAR(10)             
         , @c_TaskType              NVARCHAR(1)              
         , @c_TransmitlogKey        NVARCHAR(10)         
         , @n_Exists                INT        
         , @c_DB_QCmdClass          NVARCHAR(10)     
         , @n_NoOfTry               INT = 0     
         , @n_RecCnt_Queue          INT    
         , @n_RecCnt                INT         
         , @c_App_Name              NVARCHAR(20)            
    
         , @c_Port_FRM              NVARCHAR(5)             
         , @c_Port_LB1              NVARCHAR(5)             
         , @c_Port_LB2              NVARCHAR(5)             
         , @c_Port_LB3              NVARCHAR(5)             
         , @c_Port_LB4              NVARCHAR(5)             
         , @c_Port_LB5              NVARCHAR(5)             
         , @c_ChangePort         NVARCHAR(5)             
         , @n_Cnt                   INT                     
    
   SET @n_Continue               = 1     
   SET @n_StartTCnt              = @@TRANCOUNT      
   SET @c_ExecStatements         = ''    
   SET @c_ExecArguments          = ''    
   SET @c_ExecLogStatement       = ''    
   SET @c_APP_DB_Name            = ''    
   SET @c_DataStream             = ''    
   SET @n_ThreadPerAcct          = 0     
   SET @n_ThreadPerStream        = 0    
   SET @n_MilisecondDelay        = 0             
   SET @c_StorerKey              = ''    
   SET @c_TableName              = ''    
   SET @c_IP                     = ''    
   SET @c_PORT                   = ''    
   SET @c_IniFilePath            = ''    
   SET @c_CmdType                = ''                     
   SET @c_TaskType               = ''                     
   SET @c_TransmitlogKey         = ''         
   SET @c_DB_QCmdClass           = ''       
   SET @n_RecCnt_Queue           = 0            
   SET @n_RecCnt                 = 0    
   SET @c_App_Name               = ''                        
    
   SET @c_Port_FRM               = ''                        
   SET @c_Port_LB1               = ''                        
   SET @c_Port_LB2               = ''                        
   SET @c_Port_LB3               = ''                        
   SET @c_Port_LB4               = ''                        
   SET @c_Port_LB5               = ''                        
   SET @c_ChangePort             = ''                        
   SET @n_Cnt                    = 0                         
       
   IF OBJECT_ID('tempdb..#QCmd_Transmitlog3_Seq') IS NOT NULL    
      DROP TABLE #QCmd_Transmitlog3_Seq    
          
   CREATE TABLE #QCmd_Transmitlog3_Seq     
   ( SeqNo           INT   IDENTITY(1,1)    
   , TableName       NVARCHAR(20)    
   , StorerKey       NVARCHAR(15)      
   , TransmitlogKey  NVARCHAR(10) )    
    
   TRUNCATE TABLE #QCmd_Transmitlog3_Seq    
       
   INSERT INTO #QCmd_Transmitlog3_Seq     
   (TableName, StorerKey, Transmitlogkey)    
   SELECT T3.Tablename    
        , T3.Key3    
        , T3.Transmitlogkey    
   FROM   TransmitLog3 T3 WITH (NOLOCK)     
   JOIN   QCmd_TransmitlogConfig QTC WITH (NOLOCK)     
   ON     QTC.TableName = T3.Tablename AND QTC.StorerKey = T3.Key3     
   WHERE  T3.TransmitFlag = '0'      
   AND    QTC.QCmdClass = @c_QCmdClass    
   AND    QTC.PhysicalTableName = 'TransmitLog3'    
   AND   (QTC.[App_Name] = 'BET_OUT')  
   AND NOT EXISTS ( SELECT 1    
                  FROM   TCPSOCKET_QueueTask TQT WITH (NOLOCK)    
                    WHERE  TQT.DataStream = QTC.DataStream      
                    AND    TQT.TransmitlogKey = T3.Transmitlogkey    
                    AND    TQT.StorerKey = T3.Key3    
                    AND    TQT.[Status] IN  ('0','1') )                
   ORDER BY T3.TransmitlogKey    
    
   --INSERT INTO #QCmd_Transmitlog3_Seq     
   --(TableName, StorerKey, Transmitlogkey)    
   --SELECT T3.Tablename    
   --     , T3.Key3    
   --     , T3.Transmitlogkey    
   --FROM   TransmitLog3 T3 WITH (NOLOCK)     
   --JOIN   QCmd_TransmitlogConfig QTC WITH (NOLOCK)     
   --       ON QTC.TableName           = T3.Tablename    
   --      AND QTC.StorerKey           = T3.Key3     
   --WHERE  T3.TransmitFlag = '1'   
   --AND    QTC.QCmdClass = @c_QCmdClass    
   --AND    QTC.PhysicalTableName = 'TransmitLog3'    
   --AND    QTC.[App_Name]        = 'BET_OUT'        
   --AND    T3.EditDate <= DateAdd(mi, -120, GETDATE() )      
   --AND NOT EXISTS ( SELECT 1    
   --    FROM   TCPSOCKET_QueueTask TQT WITH (NOLOCK)    
   --      WHERE  TQT.DataStream = QTC.DataStream      
   --      AND    TQT.TransmitlogKey = T3.Transmitlogkey    
   --      AND    TQT.StorerKey = T3.Key3    
   --      AND    TQT.[Status] IN  ('0','1') )                
   --ORDER BY T3.TransmitlogKey     
    
   IF NOT EXISTS (SELECT 1 FROM #QCmd_Transmitlog3_Seq WITH (NOLOCK))    
   BEGIN    
      IF @b_debug = 1                                                         
      BEGIN                                                                                                                  
         PRINT '[isp_QCmd_BETTransmitLogInsertAlert]: Nothing to Process (#QCmd_Transmitlog3_Seq)..'                                                                     
      END     
      GOTO PROCESS_SUCCESS    
   END    
      
   --DECLARE C_ConfigCheck_Record CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   --SELECT T3.Tablename    
   --     , T3.StorerKey    
   --FROM   #QCmd_Transmitlog3_Seq T3 WITH (NOLOCK)     
   --GROUP BY T3.Tablename    
   --       , T3.StorerKey    
    
   --OPEN C_ConfigCheck_Record      
   --FETCH NEXT FROM C_ConfigCheck_Record INTO @c_TableName, @c_StorerKey    
    
   --WHILE @@FETCH_STATUS <> -1       
   --BEGIN    
   --   SET @n_Exists = 0    
   --   SET @c_DB_QCmdClass = ''    
    
   --   SELECT @n_Exists = (1)     
   --         , @c_DB_QCmdClass = ISNULL(QCmdClass,'')    
   --   FROM   QCmd_TransmitlogConfig WITH (NOLOCK)    
   --   WHERE  TableName           = @c_TableName    
   --   AND    StorerKey           = @c_StorerKey    
   --   AND    PhysicalTableName   = 'TransmitLog3'    
   --   AND    [App_Name]          = 'WS_OUT'    
    
   --   IF @n_Exists = 0    
   --   BEGIN    
   --      DELETE FROM #QCmd_Transmitlog3_Seq    
   --      WHERE Tablename = @c_TableName    
   --      AND   StorerKey = @c_StorerKey    
   --   END    
    
   --   IF @c_DB_QCmdClass <> @c_QCmdClass    
   --   BEGIN    
   --      DELETE FROM #QCmd_Transmitlog3_Seq    
   --      WHERE Tablename = @c_TableName    
   --      AND   StorerKey = @c_StorerKey    
   --   END    
     
   --   FETCH NEXT FROM C_ConfigCheck_Record INTO @c_TableName, @c_StorerKey    
   --END    
   --CLOSE C_ConfigCheck_Record    
   --DEALLOCATE C_ConfigCheck_Record    
       
    
   IF NOT EXISTS (SELECT 1 FROM #QCmd_Transmitlog3_Seq WITH (NOLOCK))    
   BEGIN    
      IF @b_debug = 1                                                                                 
      BEGIN                                                                                                                  
         PRINT '[isp_QCmd_BETTransmitLogInsertAlert]: Nothing to Process After ITFTriggerConfig And QCmd_TransmitlogConfig Check..'                                                                     
      END     
      GOTO PROCESS_SUCCESS    
   END    
    
   --SET @n_RecCnt = 0    
    
   DECLARE C_Process_Record CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT TableName, StorerKey, TransmitlogKey    
   FROM #QCmd_Transmitlog3_Seq     
   ORDER BY SeqNo    
    
   OPEN C_Process_Record      
   FETCH NEXT FROM C_Process_Record INTO @c_TableName, @c_StorerKey, @c_TransmitLogKey    
    
   WHILE @@FETCH_STATUS <> -1       
   BEGIN    
    
      SET @c_ErrMsg = ''      --(MC01)    
    
      IF @b_Debug = 1    
      BEGIN    
         PRINT '[isp_QCmd_BETTransmitLogInsertAlert]: *** @c_TableName=' + @c_TableName    
         PRINT '[isp_QCmd_BETTransmitLogInsertAlert]: @c_StorerKey=' + @c_StorerKey    
         PRINT '[isp_QCmd_BETTransmitLogInsertAlert]: @c_TransmitLogKey=' + @c_TransmitLogKey    
      END    
    
      SELECT @c_APP_DB_Name         = APP_DB_Name    
           , @c_ExecStatements      = StoredProcName    
           , @c_DataStream          = DataStream     
           , @n_ThreadPerAcct       = ThreadPerAcct     
           , @n_ThreadPerStream     = ThreadPerStream     
           , @n_MilisecondDelay     = MilisecondDelay     
           , @c_IP                  = IP                        
           , @c_Port                = Port                      
           , @c_IniFilePath         = IniFilePath               
           , @c_CmdType             = CmdType         
           , @c_App_Name            = [App_Name]                                          
      FROM  QCmd_TransmitlogConfig WITH (NOLOCK)    
      WHERE TableName               = @c_TableName     
      AND   StorerKey               = @c_StorerKey       
      AND   PhysicalTableName       = 'TransmitLog3'    
      AND  [App_Name]              = 'BET_OUT'   
      AND   QCmdClass               = @c_QCmdClass                             
    
      IF @@ROWCOUNT <> 0 --Record Found    
      BEGIN    
    
         IF @b_Debug = 1    
         BEGIN    
            PRINT '[isp_QCmd_BETTransmitLogInsertAlert]: @c_APP_DB_Name=' + @c_APP_DB_Name    
            PRINT '[isp_QCmd_BETTransmitLogInsertAlert]: @c_ExecStatements=' + @c_ExecStatements    
            PRINT '[isp_QCmd_BETTransmitLogInsertAlert]: @c_DataStream=' + @c_DataStream    
            PRINT '[isp_QCmd_BETTransmitLogInsertAlert]: @n_ThreadPerAcct=' + CAST(CAST(@n_ThreadPerAcct AS INT)AS NVARCHAR)    
            PRINT '[isp_QCmd_BETTransmitLogInsertAlert]: @n_ThreadPerStream=' + CAST(CAST(@n_ThreadPerStream AS INT)AS NVARCHAR)    
            PRINT '[isp_QCmd_BETTransmitLogInsertAlert]: @n_MilisecondDelay=' + CAST(CAST(@n_MilisecondDelay AS INT)AS NVARCHAR)    
            PRINT '[isp_QCmd_BETTransmitLogInsertAlert]: @c_Port=' + @c_Port     
         END    
    
         --SET @n_RecCnt_Queue = 0    
    
         --SELECT @n_RecCnt_Queue = Count(1)    
         --FROM   TCPSOCKET_QueueTask WITH (NOLOCK)    
         --WHERE  Port = @c_Port    
         --AND    STATUS <> 'R'    
    
         --IF @n_PortLimit <> 0 AND @n_RecCnt_Queue > @n_PortLimit    
         --BEGIN    
         --   IF @b_Debug = 1    
         --   BEGIN    
         --      PRINT '[isp_QCmd_BETTransmitLogInsertAlert]: Exceeed Port Limit. Port : ' + @c_Port    
         --   END    
         --   BREAK    
         --END    
             
         SET @n_Exists = 0    
    
         SELECT @n_Exists = (1)     
         FROM   TCPSOCKET_QueueTask WITH (NOLOCK)    
         WHERE  DataStream     = @c_DataStream     
         AND    TransmitlogKey = @c_TransmitLogKey    
         AND    StorerKey      = @c_StorerKey    
         AND    [Status]       in ('0','1')    
    
         IF @n_Exists <> 0    
         BEGIN    
            IF @b_Debug = 1    
            BEGIN    
               PRINT '[isp_QCmd_BETTransmitLogInsertAlert]: Record exists in TCPSOCKET_QueueTask, @c_TransmitLogKey=' + @c_TransmitLogKey    
            END    
    
            GOTO Get_Next_Record    
         END    
             
         IF @c_CmdType = ''    
         BEGIN     
            SET @c_CmdType = 'SQL'    
         END    
    
         IF CHARINDEX('EXEC', @c_ExecStatements) = 0    
         BEGIN    
            IF CHARINDEX('.', @c_ExecStatements) = 0    
               SET @c_ExecStatements = 'EXEC ' + @c_APP_DB_Name + '.dbo.' + LTRIM(@c_ExecStatements)    
            ELSE    
               SET @c_ExecStatements = 'EXEC ' + @c_APP_DB_Name + '.' + LTRIM(@c_ExecStatements)    
         END    
         ELSE    
         BEGIN     
            SET @c_ExecStatements = REPLACE(@c_ExecStatements, 'EXEC' , '')    
    
            IF CHARINDEX('.', @c_ExecStatements) = 0    
               SET @c_ExecStatements = 'EXEC ' + @c_APP_DB_Name + '.dbo.' + LTRIM(@c_ExecStatements)    
            ELSE    
               SET @c_ExecStatements = 'EXEC ' + @c_APP_DB_Name + '.' + LTRIM(@c_ExecStatements)    
         END    
    
         SET @c_ExecStatements = @c_ExecStatements     
                               + ',@c_TransmitlogKey=' + QUOTENAME(@c_TransmitLogKey, '''')    
    
         IF @b_Debug = 1    
         BEGIN    
            PRINT '[isp_QCmd_BETTransmitLogInsertAlert]: @c_CmdType=' + @c_CmdType    
            PRINT '[isp_QCmd_BETTransmitLogInsertAlert]: @c_ExecStatements=' + @c_ExecStatements    
         END    
  
         BEGIN TRY    
            EXEC isp_QCmd_SubmitTaskToQCommander    
                 @cTaskType           = 'T'                  -- 'T' - TransmitlogKey, 'D' - Data Stream     
               , @cStorerKey          = @c_StorerKey     
               , @cDataStream         = @c_DataStream    
               , @cCmdType            = @c_CmdType              
               , @cCommand            = @c_ExecStatements    
               , @cTransmitlogKey     = @c_TransmitLogKey     
               , @nThreadPerAcct      = @n_ThreadPerAcct     
               , @nThreadPerStream    = @n_ThreadPerStream     
               , @nMilisecondDelay    = @n_MilisecondDelay    
               , @nSeq                = 1                  
               , @cIP                 = @c_IP                   
               , @cPORT               = @c_Port                 
               , @cIniFilePath        = @c_IniFilePath          
               , @cAPPDBName          = @c_APP_DB_Name          
               , @bSuccess            = @b_Success     OUTPUT     
               , @nErr                = @n_Err         OUTPUT     
               , @cErrMsg             = @c_ErrMsg      OUTPUT    
                
         END TRY    
         BEGIN CATCH    
    
            --Need to rollback the transaction in the SP before proceed to next setup    
            --As those error been catched here are the SQL exception error which do not handled the remaining transaction    
            WHILE @@TRANCOUNT > 0    
               ROLLBACK TRAN    
    
            SELECT @n_Err = ERROR_NUMBER(), @c_ErrMsg = ERROR_MESSAGE()    
            SET @c_ErrMsg = 'NSQL (' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + ')' +  @c_ErrMsg          
          
            IF @b_Debug = 1    
            BEGIN    
               PRINT '[isp_QCmd_BETTransmitLogInsertAlert]: @c_ErrMsg=' + @c_ErrMsg    
            END     
         END CATCH       
    
         --SET @n_RecCnt = @n_RecCnt + 1    
    
         --IF @n_PortLimit <> 0 AND (@n_RecCnt_Queue + @n_RecCnt) > (@n_PortLimit - 100)    
         --BEGIN    
         --   IF @b_Debug = 1    
         --   BEGIN    
         --      PRINT '[isp_QCmd_BETTransmitLogInsertAlert]: BREAK For RecCount exceeed Port Limit. Port : ' + @c_Port    
         --   END    
         --   BREAK    
         --END    
    
      END --IF @@ROWCOUNT <> 0 --Record Found    
    
      Get_Next_Record:    
    
      FETCH NEXT FROM C_Process_Record INTO @c_TableName, @c_StorerKey, @c_TransmitLogKey    
   END    
   CLOSE C_Process_Record    
   DEALLOCATE C_Process_Record    
       
   PROCESS_SUCCESS:    
       
   RETURN 0    
       
   PROCESS_FAIL:     
   IF @n_Err <> 0    
   BEGIN    
      -- cancel transaction, undo changes    
      ROLLBACK TRANSACTION    
    
      -- report error and exit with non-zero exit code    
      RAISERROR(@c_ErrMsg , 16, 1)     
      RETURN @n_Err    
   END    
   -- commit changes and return 0 code indicating successful completion    
   COMMIT TRANSACTION    
       
   RETURN -1    
                        
END -- Procedure 

GO