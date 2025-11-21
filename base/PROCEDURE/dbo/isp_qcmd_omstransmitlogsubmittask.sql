SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_QCmd_OMSTransmitLogSubmitTask                  */  
/* Creation Date: 11-Nov-2016                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: KTLow                                                    */  
/*                                                                      */  
/* Purpose: Pull From TRANSMITLOG and Submitting to Q commander         */  
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
/* 05-Jan-2017  TKLIM    Increase Key1,2,3 variable size (TK01)         */    
/************************************************************************/  
CREATE PROC [dbo].[isp_QCmd_OMSTransmitLogSubmitTask] (
            @b_Debug             INT = 0 
          , @b_Success           INT            OUTPUT                      
          , @n_Err               INT            OUTPUT  
          , @c_ErrMsg            NVARCHAR(250)  OUTPUT  
          , @c_FrmTransmitlogKey NVARCHAR(10)   = ''
          , @c_ToTransmitlogKey  NVARCHAR(10)   = ''
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
         , @c_Key1                  NVARCHAR(20)
         , @c_Key2                  NVARCHAR(20)
         , @c_Key3                  NVARCHAR(30)
         , @c_TransmitBatch         NVARCHAR(30)
         , @c_QCommd_SPName         NVARCHAR(1024)
         , @c_StorerKey             NVARCHAR(15)
         , @c_FilterTableName       NVARCHAR(30)
         , @c_PhysicalTableName     NVARCHAR(100) 

   SET @c_ExecStatements            = ''
   SET @c_ExecArguments             = ''
   SET @c_ExecLogStatement          = ''
   SET @n_Continue                  = 1 
   SET @n_StartTCnt                 = @@TRANCOUNT   
   SET @n_Exists                    = 0
   SET @c_TransmitlogKey            = ''
   --SET @c_TableName                 = ''
   SET @c_QCommd_SPName             = ''
   SET @c_StorerKey                 = ''
   SET @c_FilterTableName           = ''

   IF @c_FrmTransmitlogKey = '' 
      SET @c_FrmTransmitlogKey = '0'
       
   IF @c_ToTransmitlogKey = ''
      SET @c_ToTransmitlogKey = 'ZZZZZZZZZZ'
   
   DECLARE C_TL2_QCmdFilter_Loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Key3, Tablename, PhysicalTableName= 'TRANSMITLOG2'
   FROM TRANSMITLOG2 WITH (NOLOCK) 
   WHERE TableName <> ''
   AND   Key1 <> ''
   AND   Key3 <> ''
   AND   TransmitFlag = '0' 
   AND   TransmitlogKey BETWEEN @c_FrmTransmitlogKey AND @c_ToTransmitlogKey
   AND   EXISTS(SELECT 1 
                FROM  QCmd_TransmitlogConfig qtc WITH (NOLOCK)
	             WHERE qtc.PhysicalTableName = 'TRANSMITLOG2'
                AND   qtc.[App_Name] = 'OMS'
                AND   qtc.StorerKey  = TRANSMITLOG2.key3
                AND   qtc.TableName  = TRANSMITLOG2.tablename)
   UNION ALL
   SELECT DISTINCT Key1, Tablename, PhysicalTableName= 'TRANSMITLOG3'
   FROM TRANSMITLOG3 WITH (NOLOCK) 
   WHERE TableName <> ''
   AND   Key1 <> ''
   AND   Key3 <> ''
   AND   TransmitFlag = '0' 
   AND   TransmitlogKey BETWEEN @c_FrmTransmitlogKey AND @c_ToTransmitlogKey
   AND   EXISTS(SELECT 1 
                FROM  QCmd_TransmitlogConfig qtc WITH (NOLOCK)
	             WHERE qtc.PhysicalTableName = 'TRANSMITLOG3'
                AND   qtc.[App_Name] = 'OMS'
                AND   qtc.StorerKey  = TRANSMITLOG3.key1
                AND   qtc.TableName  = TRANSMITLOG3.tablename
                AND   qtc.TableName IN ('ADDSKULOG'))                      
   ORDER BY Key3, Tablename
   OPEN C_TL2_QCmdFilter_Loop    
   	
   FETCH NEXT FROM C_TL2_QCmdFilter_Loop INTO @c_StorerKey
                                            , @c_FilterTableName
                                            , @c_PhysicalTableName
   WHILE @@FETCH_STATUS <> -1  
   BEGIN 
      IF @b_Debug = 1
      BEGIN
         PRINT '[isp_QCmd_OMSTransmitLogInsertAlert]: @c_StorerKey=' + @c_StorerKey
               + ', @c_FilterTableName=' + @c_FilterTableName
      END

      IF @c_PhysicalTableName = 'TRANSMITLOG2'  
      BEGIN
         DECLARE C_TL2_QCmdProcess_Loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TL.TransmitlogKey
         FROM TRANSMITLOG2 TL WITH (NOLOCK)
         WHERE TL.TransmitFlag = '0' 
           AND TL.Key3 = @c_StorerKey 
           AND TL.TableName = @c_FilterTableName 
           AND TL.TransmitlogKey BETWEEN @c_FrmTransmitlogKey AND @c_ToTransmitlogKey
           AND NOT EXISTS(SELECT 1 FROM TCPSOCKET_QueueTask TP WITH (NOLOCK)
                          WHERE TL.Key3 = TP.StorerKey 
                            AND TL.TransmitlogKey = TP.TransmitlogKey
                            AND TP.[Status] in ('0','1'))
         ORDER BY TL.TransmitlogKey
      END
      ELSE IF @c_PhysicalTableName = 'TRANSMITLOG3' AND @c_FilterTableName NOT IN ('ADDSKULOG')  
      BEGIN
         DECLARE C_TL2_QCmdProcess_Loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TL.TransmitlogKey
         FROM TRANSMITLOG3 TL WITH (NOLOCK)
         WHERE TL.TransmitFlag = '0' 
           AND TL.Key3 = @c_StorerKey 
           AND TL.TableName = @c_FilterTableName 
           AND TL.TransmitlogKey BETWEEN @c_FrmTransmitlogKey AND @c_ToTransmitlogKey
           AND NOT EXISTS(SELECT 1 FROM TCPSOCKET_QueueTask TP WITH (NOLOCK)
                          WHERE TL.Key3 = TP.StorerKey 
                            AND TL.TransmitlogKey = TP.TransmitlogKey
                            AND TP.[Status] in ('0','1'))
         ORDER BY TL.TransmitlogKey
      END
      ELSE IF @c_PhysicalTableName = 'TRANSMITLOG3' AND @c_FilterTableName IN ('ADDSKULOG')  
      BEGIN
         DECLARE C_TL2_QCmdProcess_Loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TL.TransmitlogKey
         FROM TRANSMITLOG3 TL WITH (NOLOCK)
         WHERE TL.TransmitFlag = '0' 
           AND TL.Key1 = @c_StorerKey 
           AND TL.TableName = @c_FilterTableName 
           AND TL.TransmitlogKey BETWEEN @c_FrmTransmitlogKey AND @c_ToTransmitlogKey
           AND NOT EXISTS(SELECT 1 FROM TCPSOCKET_QueueTask TP WITH (NOLOCK)
                          WHERE TL.Key1 = TP.StorerKey 
                            AND TL.TransmitlogKey = TP.TransmitlogKey
                            AND TP.[Status] in ('0','1'))
         ORDER BY TL.TransmitlogKey
      END      	

      OPEN C_TL2_QCmdProcess_Loop    
      FETCH NEXT FROM C_TL2_QCmdProcess_Loop INTO @c_TransmitlogKey   
      WHILE @@FETCH_STATUS <> -1    
      BEGIN
         IF @b_Debug = 1
         BEGIN
            PRINT '[isp_QCmd_OMSTransmitLogInsertAlert]: @c_TransmitlogKey=' 
                  + @c_TransmitlogKey 
         END

         SET @c_Key1 = ''
         SET @c_Key2 = ''
         SET @c_Key3 = ''
         SET @c_TransmitBatch = ''

         IF @c_PhysicalTableName = 'TRANSMITLOG2'
         BEGIN
            SELECT @c_Key1 = RTRIM(Key1)
                  ,@c_Key2 = RTRIM(Key2)
                  ,@c_Key3 = RTRIM(Key3)
                  ,@c_TransmitBatch = RTRIM(TransmitBatch)
            FROM TRANSMITLOG2 WITH (NOLOCK)
            WHERE TransmitlogKey = @c_TransmitlogKey         	
         END 
         ELSE IF @c_PhysicalTableName = 'TRANSMITLOG3'
         BEGIN
            SELECT @c_Key1 = RTRIM(Key1)
                  ,@c_Key2 = RTRIM(Key2)
                  ,@c_Key3 = RTRIM(Key3)
                  ,@c_TransmitBatch = RTRIM(TransmitBatch)
            FROM TRANSMITLOG3 WITH (NOLOCK)
            WHERE TransmitlogKey = @c_TransmitlogKey         	
         END 

         SET @n_Exists = 0
         SET @c_QCommd_SPName = ''  

         SELECT @n_Exists = (1)
               ,@c_QCommd_SPName = QCommanderSP        
         FROM   ITFTriggerConfig WITH (NOLOCK)
         WHERE  TargetTable         = @c_PhysicalTableName
         AND    Tablename           = @c_FilterTableName 
         AND    StorerKey           = @c_StorerKey
         AND   (QCommanderSP IS NOT NULL AND QCommanderSP <> '')

         IF @b_Debug = 1
         BEGIN
            PRINT '@c_Key1=' + @c_Key1
            PRINT '@c_Key2=' + @c_Key2
            PRINT '@c_Key3=' + @c_Key3
            PRINT '@c_TransmitBatch=' + @c_TransmitBatch
         END

         IF @n_Exists = 1 AND ISNULL(@c_QCommd_SPName, '') <> ''
         BEGIN
            IF @b_Debug = 1
            BEGIN
               PRINT 'Submit to Queue Commander'
            END

            SET @b_Success = 0
            SET @n_Err = 0
            SET @c_ErrMsg = ''

            BEGIN TRY
               SET @c_ExecStatements = N'EXEC @c_QCommd_SPName '
                                     + ' @c_Table				= @c_PhysicalTableName '
                                     + ',@c_TransmitLogKey	= @c_TransmitLogKey'
                                     + ',@c_TableName			= @c_TableName'
                                     + ',@c_Key1				= @c_Key1'
                                     + ',@c_Key2				= @c_Key2'
                                     + ',@c_Key3				= @c_Key3'
                                     + ',@c_TransmitBatch	= @c_TransmitBatch'  
											    + ',@b_Debug				= @b_debug'
                                     + ',@b_Success			= @b_Success   OUTPUT'
                                     + ',@n_Err					= @n_Err       OUTPUT'
                                     + ',@c_ErrMsg				= @c_ErrMsg    OUTPUT'                            

               SET @c_ExecArguments = N'@c_QCommd_SPName     NVARCHAR(125)'
                                    + ',@c_PhysicalTableName NVARCHAR(100)'
                                    + ',@c_TransmitLogKey    NVARCHAR(10)'
                                    + ',@c_TableName         NVARCHAR(30)'
                                    + ',@c_Key1              NVARCHAR(10)'
                                    + ',@c_Key2              NVARCHAR(5)'
                                    + ',@c_Key3              NVARCHAR(20)'
                                    + ',@c_TransmitBatch     NVARCHAR(30)' 
											   + ',@b_debug				 INT'   
                                    + ',@b_Success           INT             OUTPUT'                      
                                    + ',@n_Err               INT             OUTPUT' 
                                    + ',@c_ErrMsg            NVARCHAR(250)   OUTPUT' 
                        
               EXEC sp_ExecuteSql @c_ExecStatements 
                                , @c_ExecArguments 
                                , @c_QCommd_SPName
                                , @c_PhysicalTableName 
                                , @c_TransmitLogKey 
                                , @c_FilterTableName
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
                  SELECT @n_Err = ERROR_NUMBER(), @c_ErrMsg = ERROR_MESSAGE()
                  SET @c_ErrMsg = 'NSQL (' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + ')' +  @c_ErrMsg   
            END CATCH

            IF @c_ErrMsg <> ''
            BEGIN
               IF @b_Debug = 1
               BEGIN
                  PRINT '@c_ErrMsg=' + @c_ErrMsg
               END
            END
         END --IF @n_Exists = 1 AND ISNULL(@c_QCommd_SPName, '') <> ''
   
         FETCH NEXT FROM C_TL2_QCmdProcess_Loop INTO @c_TransmitlogKey  
      END -- WHILE @@FETCH_STATUS <> -1    
      CLOSE C_TL2_QCmdProcess_Loop    
      DEALLOCATE C_TL2_QCmdProcess_Loop  
   

      FETCH NEXT FROM C_TL2_QCmdFilter_Loop INTO @c_StorerKey, @c_FilterTableName, @c_PhysicalTableName   
   END -- WHILE @@FETCH_STATUS <> -1    
   CLOSE C_TL2_QCmdFilter_Loop    
   DEALLOCATE C_TL2_QCmdFilter_Loop  

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