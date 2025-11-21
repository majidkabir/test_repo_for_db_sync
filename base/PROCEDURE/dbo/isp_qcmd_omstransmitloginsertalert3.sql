SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: isp_QCmd_OMSTransmitLogInsertAlert3                */    
/* Creation Date: 19-May-2016                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: TKLim                                                    */    
/*                                                                      */    
/* Purpose: Submitting task to Q commander                              */    
/*                                                                      */    
/*                                                                      */    
/* Called By:  By WMS DB - During Transmitlog Insertion                 */    
/*             Generate different parameters for Execute statements     */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author     Purposes                                     */    
/* 27-Jul-2017  SHONG      Added ADDSKULOG - StorerKey in Key1          */
/*                         Jira ticket (WMS-2361)                       */
/* 08-Aug-2017  TKLIM      Add @c_APP_DB_Name param (TK02)              */  
/************************************************************************/    
CREATE PROC [dbo].[isp_QCmd_OMSTransmitLogInsertAlert3] (
            @c_Table             NVARCHAR(30)  --Transmitlog2/Transmitlog3
          , @c_TransmitLogKey    NVARCHAR(10) 
          , @c_TableName         NVARCHAR(30) 
          , @c_Key1              NVARCHAR(10) 
          , @c_Key2              NVARCHAR(5) 
          , @c_Key3              NVARCHAR(20) 
          , @c_TransmitBatch     NVARCHAR(30)   
          , @b_Debug             INT = 0            
          , @b_Success           INT             OUTPUT                      
          , @n_Err               INT             OUTPUT  
          , @c_ErrMsg            NVARCHAR(250)   OUTPUT  
          , @n_Seq               INT = 1
)  
AS   
BEGIN
   DECLARE @c_ExecStatements        NVARCHAR(4000)  
         , @c_ExecArguments         NVARCHAR(4000) 
         , @c_ExecLogStatement      NVARCHAR(4000)

   DECLARE @c_StoredProcName        NVARCHAR(1024)   
         , @c_DataStream            NVARCHAR(10)
         , @n_ThreadPerAcct         INT
         , @n_ThreadPerStream       INT
         , @n_MilisecondDelay       INT
         , @c_APP_DB_Name           NVARCHAR(20)   
         , @c_IP                    NVARCHAR(20)
         , @c_Port                  NVARCHAR(5)
         , @c_IniFilePath           NVARCHAR(200)
         , @c_StorerKey             NVARCHAR(15)                
   
   IF @c_TableName IN ('ADDSKULOG') AND @c_Table = 'TRANSMITLOG3'
      SET @c_StorerKey = @c_Key1
   ELSE 
   	SET @c_StorerKey = @c_Key3
   	
   SELECT @c_APP_DB_Name         = APP_DB_Name
        , @c_ExecStatements      = StoredProcName
        , @c_DataStream          = DataStream 
        , @n_ThreadPerAcct       = ThreadPerAcct 
        , @n_ThreadPerStream     = ThreadPerStream 
        , @n_MilisecondDelay     = MilisecondDelay 
        , @c_IP                  = IP
        , @c_Port                = Port
        , @c_IniFilePath         = IniFilePath
   FROM  [dbo].[QCmd_TransmitlogConfig] WITH (NOLOCK)
   WHERE StorerKey               = @c_StorerKey 
   AND   TableName               = @c_TableName 
   AND   PhysicalTableName       = @c_Table
   AND   [App_Name]              = 'OMS'

   IF @@ROWCOUNT = 0 
   BEGIN
      SET @n_Err = 88001
      SET @c_ErrMsg = 'NSQL (' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))  
                     + '): Configuration Not Setup in QCmd_TransmitlogConfig table ' 
      GOTO PROCESS_SUCCESS      
   END

   IF @b_Debug = 1
   BEGIN
      PRINT '[isp_QCmd_OMSTransmitLogInsertAlert3]: @c_APP_DB_Name=' + @c_APP_DB_Name
      PRINT '[isp_QCmd_OMSTransmitLogInsertAlert3]: @c_ExecStatements=' + @c_ExecStatements
      PRINT '[isp_QCmd_OMSTransmitLogInsertAlert3]: @c_DataStream=' + @c_DataStream
      PRINT '[isp_QCmd_OMSTransmitLogInsertAlert3]: @n_ThreadPerAcct=' + CAST(CAST(@n_ThreadPerAcct AS INT)AS NVARCHAR)
      PRINT '[isp_QCmd_OMSTransmitLogInsertAlert3]: @n_ThreadPerStream=' + CAST(CAST(@n_ThreadPerStream AS INT)AS NVARCHAR)
      PRINT '[isp_QCmd_OMSTransmitLogInsertAlert3]: @n_MilisecondDelay=' + CAST(CAST(@n_MilisecondDelay AS INT)AS NVARCHAR)
      PRINT '[isp_QCmd_OMSTransmitLogInsertAlert3]: @c_IP=' + @c_IP
      PRINT '[isp_QCmd_OMSTransmitLogInsertAlert3]: @c_Port=' + @c_Port
      PRINT '[isp_QCmd_OMSTransmitLogInsertAlert3]: @c_IniFilePath=' + @c_IniFilePath
      PRINT '[isp_QCmd_OMSTransmitLogInsertAlert3]: @c_TransmitLogKey=' + @c_TransmitLogKey
   END

   IF @c_ExecStatements = ''
   BEGIN
      SET @n_Err = 88002
      SET @c_ErrMsg = 'NSQL (' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))  
                     + '): Missing Execute Statement in QCmd_TransmitlogConfig table ' 
      GOTO PROCESS_FAIL      
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
                              + ' @cTable = ' + QUOTENAME(@c_Table, '''''') +    
                              + ',@cTransmitLogKey = ' + QUOTENAME(@c_TransmitLogKey, '''''') +  
                              + ',@cTableName = ' + QUOTENAME(@c_TableName, '''''') +  
                              + ',@cKey1 = ' + QUOTENAME(@c_Key1, '''''') +  
                              + ',@cKey2 = ' + QUOTENAME(@c_Key2, '''''') +  
                              + ',@cKey3 = ' + QUOTENAME(@c_Key3, '''''') +  
                              + ',@cTransmitBatch = ' + QUOTENAME(@c_TransmitBatch, '''''')          

   IF @b_Debug = 1
   BEGIN
      PRINT '@c_ExecStatements=' + @c_ExecStatements
   END

   BEGIN TRY

      EXEC [dbo].[isp_QCmd_SubmitTaskToQCommander]
           @cTaskType           = 'T'                  -- 'T' - TransmitlogKey, 'D' - Data Stream 
         , @cStorerKey          = @c_Storerkey  
         , @cDataStream         = @c_DataStream
         , @cCmdType            = 'SQL'
         , @cCommand            = @c_ExecStatements
         , @cTransmitlogKey     = @c_TransmitLogKey 
         , @nThreadPerAcct      = @n_ThreadPerAcct 
         , @nThreadPerStream    = @n_ThreadPerStream 
         , @nMilisecondDelay    = @n_MilisecondDelay
         , @nSeq                = @n_Seq
         , @cIP                 = @c_IP
         , @cPORT               = @c_Port
         , @cIniFilePath        = @c_IniFilePath
         , @cAPPDBName          = @c_APP_DB_Name      --(TK02)  
         , @bSuccess            = @b_Success     OUTPUT 
         , @nErr                = @n_Err         OUTPUT 
         , @cErrMsg             = @c_ErrMsg      OUTPUT
                  
   END TRY
   BEGIN CATCH
         SELECT @n_Err = ERROR_NUMBER(), @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL (' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + ')' +  @c_ErrMsg      
         
         IF @b_Debug = 1
         BEGIN
            PRINT '@c_ErrMsg=' + @c_ErrMsg
         END

         /*
         SET @c_ExecLogStatement = 'EXEC ' + @c_APP_DB_Name + '.dbo.isp_ITFLog'
                                 + ' @n_ITFLogKey=0'
                                 + ',@c_DataStream=' + QUOTENAME(@c_DataStream, '''')
                                 + ',@c_ITFType=''W'''
                                 + ',@n_FileKey = 0'
                                 + ',@n_AttachmentID=0'
                                 + ',@c_FileName=''isp_QCmd_OMSTransmitLogInsertAlert3'''
                                 + ',@d_LogDateStart=NULL'
                                 + ',@d_LogDateEnd=NULL'
                                 + ',@n_NoOfRecCount=0'
                                 + ',@c_RefKey1=''WSQCMD'''
                                 + ',@c_RefKey2=' + QUOTENAME(@c_TransmitLogKey, '''')
                                 + ',@c_Status=''0'''
                                 + ',@b_Success=' + CAST(CAST(@b_Success AS INT)AS NVARCHAR)
                                 + ',@n_Err=' + CAST(CAST(@n_Err AS INT)AS NVARCHAR)
                                 + ',@c_ErrMsg=''' + @c_ErrMsg + ''''

         EXEC(@c_ExecLogStatement)  
         */
   END CATCH

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