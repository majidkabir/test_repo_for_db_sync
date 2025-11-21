SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_QCmd_WSTransmitLogSubmitTask                   */  
/* Creation Date: 11-Nov-2016                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: KTLow                                                    */  
/*                                                                      */  
/* Purpose: Pull From Transmitlog2 and Submitting to Q commander        */  
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
/* Date         Author   Purposes                                       */ 
/* 14-Nov-2016  KTLow    Add Paramter for Processing Range (KT01)       */
/* 22-Nov-2016  KHChan   Remove date filtering (KH01)                   */
/* 23-Nov-2016  SoongYi  Transmitlog2 Filtering (SY01)                  */
/* 01-Feb-2017  KTLow    Change to dynamic database setting (KT02)      */
/* 13-Mar-2017  KTLow    Rollback Trans Count When Hit Exception Error  */
/*                       (KT03)                                         */
/* 10-Oct-2017  MCTang   Remove isp_QCmd_WSTransmitLogInsertAlert (MC01)*/
/************************************************************************/  
CREATE PROC [dbo].[isp_QCmd_WSTransmitLogSubmitTask] (
            @b_Debug               INT = 0 
          , @b_Success            INT            OUTPUT                      
          , @n_Err               INT            OUTPUT  
          , @c_ErrMsg            NVARCHAR(250)   OUTPUT  
          , @c_FrmTransmitlogKey   NVARCHAR(10)   = '' --(KT01)
          , @c_ToTransmitlogKey   NVARCHAR(10)   = '' --(KT01)
)
AS 
BEGIN
        
   DECLARE @c_ExecStatements        NVARCHAR(4000)
         , @c_ExecArguments         NVARCHAR(4000)  
         , @c_ExecLogStatement      NVARCHAR(MAX)
         , @n_Continue              INT      
         , @n_StartTCnt             INT    
         , @n_Exists                INT
         , @c_TransmitlogKey        NVARCHAR(10)
         , @c_TableName             NVARCHAR(30)
         , @c_Key1                  NVARCHAR(10)
         , @c_Key2                  NVARCHAR(5)
         , @c_Key3                  NVARCHAR(15)
         , @c_TransmitBatch         NVARCHAR(30)
         , @c_QCommd_SPName         NVARCHAR(1024)
         , @c_FilterKey3            NVARCHAR(15) --(SY01)
         , @c_FilterTableName       NVARCHAR(30) --(SY01)   
         , @c_App_DB_Name           NVARCHAR(20) --(KT02)
         , @c_DataStream            NVARCHAR(10) --(KT02)

   SET @c_ExecStatements         = ''
   SET @c_ExecArguments          = ''
   SET @c_ExecLogStatement       = ''
   SET @n_Continue               = 1 
   SET @n_StartTCnt              = @@TRANCOUNT   
   SET @n_Exists                 = 0
   SET @c_TransmitlogKey         = ''
   SET @c_TableName              = ''
   SET @c_Key3                   = ''
   SET @c_QCommd_SPName          = ''
   SET @c_FilterKey3             = '' --(SY01)
   SET @c_FilterTableName        = '' --(SY01)
   SET @c_App_DB_Name            = '' --(KT02)
   SET @c_DataStream             = '' --(KT02)

   --(SY01) - Start
   DECLARE C_TL2_QCmdFilter_Loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Key3
         , Tablename
   FROM dbo.Transmitlog2 WITH (NOLOCK)
   WHERE TransmitFlag = '0'
         AND (TableName <> 'ULVPODITF' AND TableName <> 'WSErrorResend') 
   ORDER BY Key3
          , Tablename
   OPEN C_TL2_QCmdFilter_Loop    
   FETCH NEXT FROM C_TL2_QCmdFilter_Loop INTO @c_FilterKey3
                                            , @c_FilterTableName
   WHILE @@FETCH_STATUS <> -1  
   BEGIN 
   --(SY01) - End
      IF @c_FrmTransmitlogKey = '' AND @c_ToTransmitlogKey = '' --(KT01)
      BEGIN
         DECLARE C_TL2_QCmdProcess_Loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TL.TransmitlogKey  --(SY01) - Start
         FROM dbo.Transmitlog2 TL WITH (NOLOCK)
         LEFT JOIN dbo.TCPSOCKET_QueueTask TP WITH (NOLOCK)
         ON TL.Key3 = TP.StorerKey 
         AND TL.TransmitlogKey = TP.TransmitlogKey
         AND TP.[Status] in ('0','1')
         WHERE TL.TransmitFlag = '0'
         AND (TP.Transmitlogkey = '' OR TP.Transmitlogkey IS NULL) 
         AND TL.Key3 = @c_FilterKey3 
         AND TL.TableName = @c_FilterTableName
         --AND AddDate >= '2016-11-11 00:00:00' --(KH01)
         --AND (TableName <> 'ULVPODITF' AND TableName <> 'WSErrorResend') --(SY01) - End
         ORDER BY TL.TransmitlogKey
      END
      ELSE IF @c_FrmTransmitlogKey <> '' AND @c_ToTransmitlogKey = '' --(KT01)
      BEGIN
         DECLARE C_TL2_QCmdProcess_Loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TL.TransmitlogKey  --(SY01) - Start
         FROM dbo.Transmitlog2 TL WITH (NOLOCK)
         LEFT JOIN dbo.TCPSOCKET_QueueTask TP WITH (NOLOCK)
         ON TL.Key3 = TP.StorerKey 
         AND TL.TransmitlogKey = TP.TransmitlogKey
         AND TP.[Status] in ('0','1')
         WHERE TL.TransmitFlag = '0'
         AND (TP.Transmitlogkey = '' OR TP.Transmitlogkey IS NULL) 
         AND TL.TransmitlogKey >= @c_FrmTransmitlogKey --(KT01) 
         AND TL.Key3 = @c_FilterKey3 
         AND TL.TableName = @c_FilterTableName
         --AND AddDate >= '2016-11-11 00:00:00' --(KH01)
         --AND (TableName <> 'ULVPODITF' AND TableName <> 'WSErrorResend') --(SY01) - End
         ORDER BY TL.TransmitlogKey
      END
      ELSE IF @c_FrmTransmitlogKey = '' AND @c_ToTransmitlogKey <> '' --(KT01)
      BEGIN
         DECLARE C_TL2_QCmdProcess_Loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TL.TransmitlogKey --(SY01) - Start
         FROM dbo.Transmitlog2 TL WITH (NOLOCK)
         LEFT JOIN dbo.TCPSOCKET_QueueTask TP WITH (NOLOCK)
         ON TL.Key3 = TP.StorerKey 
         AND TL.TransmitlogKey = TP.TransmitlogKey
         AND TP.[Status] in ('0','1')
         WHERE TL.TransmitFlag = '0'
         AND (TP.Transmitlogkey = '' OR TP.Transmitlogkey IS NULL) 
         AND TL.TransmitlogKey <= @c_ToTransmitlogKey --(KT01)  
         AND TL.Key3 = @c_FilterKey3 
         AND TL.TableName = @c_FilterTableName
         --AND AddDate >= '2016-11-11 00:00:00' --(KH01)
         --AND (TableName <> 'ULVPODITF' AND TableName <> 'WSErrorResend') --(SY01) - End
         ORDER BY TL.TransmitlogKey
      END
      ELSE
      BEGIN
         DECLARE C_TL2_QCmdProcess_Loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TL.TransmitlogKey   --(SY01) - Start
         FROM dbo.Transmitlog2 TL WITH (NOLOCK)
         LEFT JOIN dbo.TCPSOCKET_QueueTask TP WITH (NOLOCK)
         ON TL.Key3 = TP.StorerKey 
         AND TL.TransmitlogKey = TP.TransmitlogKey
         AND TP.[Status] in ('0','1')
         WHERE TL.TransmitFlag = '0'
         AND (TP.Transmitlogkey = '' OR TP.Transmitlogkey IS NULL) 
         AND (TL.TransmitlogKey >= @c_FrmTransmitlogKey AND TL.TransmitlogKey <= @c_ToTransmitlogKey) --(KT01)
         AND TL.Key3 = @c_FilterKey3 
         AND TL.TableName = @c_FilterTableName 
         --AND AddDate >= '2016-11-11 00:00:00' --(KH01)
         --AND (TableName <> 'ULVPODITF' AND TableName <> 'WSErrorResend') --(SY01) - End
         ORDER BY TL.TransmitlogKey
      END

      OPEN C_TL2_QCmdProcess_Loop    
      FETCH NEXT FROM C_TL2_QCmdProcess_Loop INTO @c_TransmitlogKey   
      WHILE @@FETCH_STATUS <> -1    
      BEGIN
         SET @c_TableName = ''
         SET @c_Key3 = ''

         SELECT @c_TableName = RTRIM(TableName)
               ,@c_Key1 = RTRIM(Key1)
               ,@c_Key2 = RTRIM(Key2)
               ,@c_Key3 = RTRIM(Key3)
               ,@c_TransmitBatch = RTRIM(TransmitBatch)
         FROM dbo.Transmitlog2 WITH (NOLOCK)
         WHERE TransmitlogKey = @c_TransmitlogKey

         SET @n_Exists = 0
         SET @c_QCommd_SPName = ''  

         SELECT @n_Exists = (1)
               ,@c_QCommd_SPName = QCommanderSP        
         FROM   ITFTriggerConfig WITH (NOLOCK)
         WHERE  TargetTable         = 'TRANSMITLOG2' 
         AND    Tablename           = @c_TableName 
         AND    StorerKey           = @c_Key3
         AND   (QCommanderSP IS NOT NULL AND QCommanderSP <> '')

         IF @b_Debug = 1
         BEGIN
            PRINT '@c_TableName=' + @c_TableName
            PRINT '@c_Key1=' + @c_Key1
            PRINT '@c_Key2=' + @c_Key2
            PRINT '@c_Key3=' + @c_Key3
            PRINT '@c_TransmitBatch=' + @c_TransmitBatch
         END

         IF @n_Exists = 1 AND ISNULL(@c_QCommd_SPName, '') <> ''
            AND ISNULL(RTRIM(@c_QCommd_SPName), '') <> 'isp_QCmd_WSTransmitLogInsertAlert'    --(MC01)
         BEGIN
            --(KT02) - Start
            /***************************************************/
            /* Get Interface DB Name (Start)                   */
            /***************************************************/
            SET @c_App_DB_Name = ''
            SET @c_DataStream = ''
            SELECT @c_App_DB_Name = ISNULL(RTRIM(App_DB_Name), '')
                  ,@c_DataStream = ISNULL(RTRIM(DataStream), '')
            FROM QCmd_TransmitlogConfig WITH (NOLOCK)
            WHERE StorerKey = @c_Key3
                  AND PhysicalTableName = 'TRANSMITLOG2'
                  AND TableName = @c_TableName
                  AND [App_Name] = 'WS_OUT'
            /***************************************************/
            /* Get Interface DB Name (End)                     */
            /***************************************************/
            --(KT02) - End

            IF @b_Debug = 1
            BEGIN
               PRINT 'Submit to Queue Commander'
               PRINT '@c_QCommd_SPName=' + @c_QCommd_SPName
            END

            SET @b_Success = 0
            SET @n_Err = 0
            SET @c_ErrMsg = ''

            BEGIN TRY
               SET @c_ExecStatements = N'EXEC @c_QCommd_SPName '
                                     + ' @c_Table            = ''TRANSMITLOG2'''
                                     + ',@c_TransmitLogKey   = @c_TransmitLogKey'
                                     + ',@c_TableName         = @c_TableName'
                                     + ',@c_Key1            = @c_Key1'
                                     + ',@c_Key2            = @c_Key2'
                                     + ',@c_Key3            = @c_Key3'
                                     + ',@c_TransmitBatch   = @c_TransmitBatch'  
                                     + ',@b_Debug            = @b_debug'
                                     + ',@b_Success         = @b_Success   OUTPUT'
                                     + ',@n_Err               = @n_Err       OUTPUT'
                                     + ',@c_ErrMsg            = @c_ErrMsg    OUTPUT'                            

               SET @c_ExecArguments = N'@c_QCommd_SPName    NVARCHAR(125)'
                                    + ',@c_TransmitLogKey   NVARCHAR(10)'
                                    + ',@c_TableName        NVARCHAR(30)'
                                    + ',@c_Key1             NVARCHAR(10)'
                                    + ',@c_Key2             NVARCHAR(5)'
                                    + ',@c_Key3             NVARCHAR(20)'
                                    + ',@c_TransmitBatch    NVARCHAR(30)' 
                                    + ',@b_debug            INT'   
                                    + ',@b_Success          INT             OUTPUT'                      
                                    + ',@n_Err              INT             OUTPUT' 
                                    + ',@c_ErrMsg           NVARCHAR(250)   OUTPUT' 
                     
               EXEC sp_ExecuteSql @c_ExecStatements 
                                , @c_ExecArguments 
                                , @c_QCommd_SPName
                                , @c_TransmitLogKey
                                , @c_TableName
                                , @c_Key1
                                , @c_Key2
                                , @c_Key3
                                , @c_TransmitBatch   
                                , @b_debug                           
                                , @b_Success         OUTPUT                       
                                , @n_Err             OUTPUT  
                                , @c_ErrMsg          OUTPUT
            END TRY
            BEGIN CATCH
               --(KT02) - Start
               --Need to rollback the transaction in the SP before proceed to next setup
               --As those error been catched here are the SQL exception error which do not handled the remaining transaction
               WHILE @@TRANCOUNT > 0
                  ROLLBACK TRAN
               --(KT02) - End

               SELECT @n_Err = ERROR_NUMBER(), @c_ErrMsg = ERROR_MESSAGE()
               SET @c_ErrMsg = 'NSQL (' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + ')' +  @c_ErrMsg   
            END CATCH

            IF @c_ErrMsg <> ''
            BEGIN
               IF @b_Debug = 1
               BEGIN
                  PRINT '@c_ErrMsg=' + @c_ErrMsg
                  PRINT '@c_App_DB_Name=' + @c_App_DB_Name
                  PRINT '@c_DataStream=' + @c_DataStream
                  PRINT '@c_TransmitLogKey=' + @c_TransmitLogKey
               END

               --(KT02) - Start
               --EXEC CNDTSITF.dbo.isp_ITFLog @n_ITFLogKey = 0
                                         -- , @c_DataStream = 'TL2'
                                         -- , @c_ITFType = 'W'
                                         -- , @n_FileKey = 0
                                         -- , @n_AttachmentID = 0
                                         -- , @c_FileName = 'isp_QCmd_WSTransmitLogSubmitTask'
                                         -- , @d_LogDateStart = NULL
                                         -- , @d_LogDateEnd = NULL
                                         -- , @n_NoOfRecCount = 0
                                         -- , @c_RefKey1 = 'WSQCMD'
                                         -- , @c_RefKey2 = @c_TransmitLogKey
                                         -- , @c_Status = '0'
                                         -- , @b_Success = @b_Success
                                         -- , @n_Err = @n_Err
                                         -- , @c_ErrMsg = @c_ErrMsg

               IF @c_App_DB_Name <> ''
               BEGIN
                  SET @c_ExecLogStatement = 'EXEC ' + @c_APP_DB_Name + '.dbo.isp_ITFLog'
                                          + ' @n_ITFLogKey=0'
                                          + ',@c_DataStream=' + QUOTENAME(@c_DataStream, '''')
                                          + ',@c_ITFType=''W'''
                                          + ',@n_FileKey = 0'
                                          + ',@n_AttachmentID=0'
                                          + ',@c_FileName=''isp_QCmd_WSTransmitLogSubmitTask'''
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
               END
               --(KT02) - End               
            END
         END --IF @n_Exists = 1 AND ISNULL(@c_QCommd_SPName, '') <> ''
   
         FETCH NEXT FROM C_TL2_QCmdProcess_Loop INTO @c_TransmitlogKey  
      END -- WHILE @@FETCH_STATUS <> -1    
      CLOSE C_TL2_QCmdProcess_Loop    
      DEALLOCATE C_TL2_QCmdProcess_Loop  
   
   --(SY01) - Start
      FETCH NEXT FROM C_TL2_QCmdFilter_Loop INTO @c_FilterKey3, @c_FilterTableName   
   END -- WHILE @@FETCH_STATUS <> -1    
   CLOSE C_TL2_QCmdFilter_Loop    
   DEALLOCATE C_TL2_QCmdFilter_Loop  
   --(SY01) - END

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