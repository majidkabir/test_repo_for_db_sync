SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_QCmd_IMLTransmitLogInsertAlert                 */  
/* Creation Date: 10-Jun-2016                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: MCTang                                                   */  
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
/* Date         Author     Purposes                                     */  
/* 17-Apr-2017  MCTang     Enhacement for new std PORT (MC01)           */
/* 06-Jun-2017  MCTang     Re-do Grouping                               */
/************************************************************************/  
CREATE PROC [dbo].[isp_QCmd_IMLTransmitLogInsertAlert] 
            @c_QCmdClass         NVARCHAR(10) = ''         
          , @b_Debug             INT          = 0            
          , @b_Success           INT             OUTPUT                      
          , @n_Err               INT             OUTPUT  
          , @c_ErrMsg            NVARCHAR(250)   OUTPUT  

AS 
BEGIN
        
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF   

	DECLARE @c_ExecStatements        NVARCHAR(4000)
         , @c_ExecArguments         NVARCHAR(4000)  
         , @n_Continue              INT      
         , @n_StartTCnt             INT    

	DECLARE @c_APP_DB_Name           NVARCHAR(20)
         , @c_DataStream            VARCHAR(10)
         --, @c_StoredProcName        NVARCHAR(1024)
         , @n_ThreadPerAcct         INT 
         , @n_ThreadPerStream       INT 
         , @n_MilisecondDelay       INT 
         --, @dt_StartTime            DateTime
         --, @dt_EndTime	           Datetime
         , @c_StorerKey             NVARCHAR(15) 
         , @c_TableName             NVARCHAR(20) 
         , @c_IP                    NVARCHAR(20)
         , @c_PORT                  NVARCHAR(5)
         , @c_IniFilePath           NVARCHAR(200)
         , @c_CmdType               NVARCHAR(10)         --(MC01)
         , @c_TaskType              NVARCHAR(1)          --(MC01)
         , @c_TransmitlogKey        NVARCHAR(10)         --(MC01)

   SET @n_Continue               = 1 
   SET @n_StartTCnt              = @@TRANCOUNT 
   --SET @dt_StartTime             = GETDATE()  
   SET @c_ExecStatements         = ''
   SET @c_ExecArguments          = ''
   SET @c_APP_DB_Name            = ''
   SET @c_DataStream             = ''
   --SET @c_StoredProcName         = ''
   SET @n_ThreadPerAcct          = 0 
   SET @n_ThreadPerStream        = 0
   SET @n_MilisecondDelay        = 0         
   SET @c_StorerKey              = ''
   SET @c_TableName              = ''
   SET @c_IP                     = ''
   SET @c_PORT                   = ''
   SET @c_IniFilePath            = ''
   SET @c_CmdType                = ''                 --(MC01)
   SET @c_TaskType               = ''                 --(MC01)
   SET @c_TransmitlogKey         = ''                 --(MC01)
   
   /*
   IF OBJECT_ID('tempdb..#QCmd_Transmitlog3') IS NOT NULL
      DROP TABLE #QCmd_Transmitlog3
      
   CREATE TABLE #QCmd_Transmitlog3 
   ( SeqNo           INT   IDENTITY(1,1)
   , TableName       NVARCHAR(20)
   , StorerKey       NVARCHAR(15) ) 
   */

   IF OBJECT_ID('tempdb..#QCmd_Transmitlog3_Seq') IS NOT NULL
      DROP TABLE #QCmd_Transmitlog3_Seq
      
   CREATE TABLE #QCmd_Transmitlog3_Seq 
   ( SeqNo           INT   IDENTITY(1,1)
   , TableName       NVARCHAR(20)
   , StorerKey       NVARCHAR(15)  
   , TransmitlogKey  NVARCHAR(10) )

   /*
   -- Cant group T3 records, need to get the seq
   TRUNCATE TABLE #QCmd_Transmitlog3

   INSERT INTO #QCmd_Transmitlog3 
   (TableName, StorerKey)
   SELECT   T3.Tablename
          , T3.Key3
   FROM     TransmitLog3 T3 WITH (NOLOCK) 
   WHERE    T3.TransmitFlag = '0' 
   ORDER BY T3.Transmitlogkey

   IF NOT EXISTS (SELECT 1 FROM #QCmd_Transmitlog3 WITH (NOLOCK))
   BEGIN
      IF @b_debug = 1                                                                                                    
      BEGIN                                                                                                              
         SELECT 'Nothing to Process..'                                                                 
      END 
      GOTO PROCESS_SUCCESS
   END

   IF @b_Debug = 1
   BEGIN
      SELECT 'T3', * FROM #QCmd_Transmitlog3 (NOLOCK)
   END

   -- Group the T3 records with seq
   TRUNCATE TABLE #QCmd_Transmitlog3_Seq

   DECLARE C_Sorting_Record CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT TableName
        , StorerKey
   FROM #QCmd_Transmitlog3 
   ORDER BY SeqNo

   OPEN C_Sorting_Record  
   FETCH NEXT FROM C_Sorting_Record INTO @c_TableName, @c_StorerKey

   WHILE @@FETCH_STATUS <> -1   
   BEGIN

      IF NOT EXISTS (SELECT 1 FROM #QCmd_Transmitlog3_Seq WITH (NOLOCK)  
                     WHERE TableName = @c_TableName 
                     AND   StorerKey = @c_StorerKey )
      BEGIN
         INSERT INTO #QCmd_Transmitlog3_Seq
         (TableName, StorerKey)
         VALUES
         (@c_TableName, @c_StorerKey)
      END

      FETCH NEXT FROM C_Sorting_Record INTO @c_TableName, @c_StorerKey
   END
   CLOSE C_Sorting_Record
   DEALLOCATE C_Sorting_Record

   IF @b_Debug = 1
   BEGIN
      SELECT 'SEQ', * FROM #QCmd_Transmitlog3_Seq (NOLOCK)
   END
   */

   TRUNCATE TABLE #QCmd_Transmitlog3_Seq

   INSERT INTO #QCmd_Transmitlog3_Seq 
   (TableName, StorerKey, Transmitlogkey)
   SELECT   T3.Tablename
          , T3.Key3
          , MIN(T3.Transmitlogkey)
   FROM     TransmitLog3 T3 WITH (NOLOCK) 
   WHERE    T3.TransmitFlag = '0' 
   AND      T3.TableName <> 'ADDSKULOG'
   GROUP BY T3.TableName
          , T3.Key3

   INSERT INTO #QCmd_Transmitlog3_Seq 
   (TableName, StorerKey, Transmitlogkey)
   SELECT   T3.Tablename
          , T3.Key1
          , MIN(T3.Transmitlogkey)
   FROM     TransmitLog3 T3 WITH (NOLOCK) 
   WHERE    T3.TransmitFlag = '0' 
   AND      T3.TableName = 'ADDSKULOG'
   GROUP BY T3.TableName
          , T3.Key1

   IF NOT EXISTS (SELECT 1 FROM #QCmd_Transmitlog3_Seq WITH (NOLOCK))
   BEGIN
      IF @b_debug = 1                                                                                                    
      BEGIN                                                                                                              
         SELECT 'Nothing to Process..'                                                                 
      END 
      GOTO PROCESS_SUCCESS
   END
  
   DECLARE C_Process_Record CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT TableName, StorerKey
   FROM #QCmd_Transmitlog3_Seq 
   ORDER BY SeqNo

   OPEN C_Process_Record  
   FETCH NEXT FROM C_Process_Record INTO @c_TableName, @c_StorerKey

   WHILE @@FETCH_STATUS <> -1   
   BEGIN

	   SELECT @c_APP_DB_Name         = APP_DB_Name
	        , @c_ExecStatements      = StoredProcName
	        , @c_DataStream          = DataStream 
	        , @n_ThreadPerAcct       = ThreadPerAcct 
	        , @n_ThreadPerStream     = ThreadPerStream 
	        , @n_MilisecondDelay     = MilisecondDelay 
           , @c_IP                  = IP
           , @c_PORT                = PORT
           , @c_IniFilePath         = IniFilePath
           , @c_CmdType             = CmdType            --MC01
           , @c_TaskType            = TaskType           --MC01
	   FROM  QCmd_TransmitlogConfig WITH (NOLOCK)
	   WHERE TableName               = @c_TableName  
	   AND   StorerKey               = @c_StorerKey 
      AND   PhysicalTableName       = 'TRANSMITLOG3'
      AND   [App_Name]					= 'IML_OUT'
      AND   QCmdClass               = @c_QCmdClass

	   IF @@ROWCOUNT <> 0 --Record Found
      BEGIN

         --IF NOT EXISTS (SELECT 1 
         --               FROM  QCmd_TransmitlogConfig QCD WITH (NOLOCK) 
         --               JOIN  TransmitLog3 T3 WITH (NOLOCK) 
         --               ON   (QCD.TableName = T3.TableName AND QCD.StorerKey = T3.Key3 AND T3.TransmitFlag = '1')
         --               WHERE QCD.PhysicalTableName = 'TRANSMITLOG3'
         --               AND   QCD.[APP_NAME]        = 'IML_OUT'
         --               AND   QCD.QCmdClass         = @c_QCmdClass
         --               AND   QCD.DataStream        = @c_DataStream )
         --BEGIN

            --MC01 - S
            IF @c_CmdType = ''
            BEGIN 
               SET @c_CmdType = 'SQL'
            END

            IF @c_TaskType = ''
            BEGIN
               SET @c_TaskType = 'D'
            END
            --MC01 - E

            --MC01 - S
            /*
            IF CHARINDEX('EXEC', @c_ExecStatements) = 0
            BEGIN
               SET @c_ExecStatements = 'EXEC ' + @c_APP_DB_Name + '.dbo.' + LTRIM(@c_ExecStatements)
            END
            ELSE
            BEGIN 
               SET @c_ExecStatements = REPLACE(@c_ExecStatements, 'EXEC' , '')
               SET @c_ExecStatements = 'EXEC ' + @c_APP_DB_Name + '.dbo.' + LTRIM(@c_ExecStatements)
            END
            */

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
            --MC01 - E

            IF @b_Debug = 1
            BEGIN
               SELECT '@c_CmdType : ' + @c_CmdType 
               SELECT @c_ExecStatements
            END

            IF @c_TaskType = 'D'  --(MC01)
            BEGIN
               BEGIN TRY
                  EXEC isp_QCmd_SubmitTaskToQCommander
                       @cTaskType           = 'D'                  -- 'T' - TransmitlogKey, 'D' - Data Stream 
                     , @cStorerKey          = @c_StorerKey 
                     , @cDataStream         = @c_DataStream
                     --, @cCmdType            = 'SQL'
                     , @cCmdType            = @c_CmdType --(MC01)
                     , @cCommand            = @c_ExecStatements
                     , @cTransmitlogKey     = '' 
                     , @nThreadPerAcct      = @n_ThreadPerAcct 
                     , @nThreadPerStream    = @n_ThreadPerStream 
                     , @nMilisecondDelay    = @n_MilisecondDelay  
	                  , @nSeq					  = 1
                     , @cIP                 = @c_IP
                     , @cPORT               = @c_PORT
                     , @cIniFilePath        = @c_IniFilePath
                     , @cAPPDBName          = @c_APP_DB_Name --(MC01)
                     , @bSuccess            = @b_Success     OUTPUT 
                     , @nErr                = @n_Err         OUTPUT 
                     , @cErrMsg             = @c_ErrMsg      OUTPUT
               	
               END TRY
               BEGIN CATCH
      	            SELECT @n_Err = ERROR_NUMBER(), @c_ErrMsg = ERROR_MESSAGE()
                     SET @c_ErrMsg = 'NSQL (' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + ')' +  @c_ErrMsg		     
               END CATCH	
            END   --IF @c_TaskType = 'D' 
            ELSE
            BEGIN
               DECLARE C_T3_Record CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT   T3.Transmitlogkey
               FROM     TransmitLog3 T3 WITH (NOLOCK) 
               WHERE    T3.TableName    = @c_TableName
               AND      T3.TransmitFlag = '0' 
               AND      CASE T3.TableName WHEN 'ADDSKULOG' THEN T3.Key1 ELSE T3.Key3 END = @c_StorerKey
               ORDER BY T3.Transmitlogkey

               OPEN C_T3_Record  
               FETCH NEXT FROM C_T3_Record INTO @c_Transmitlogkey

               WHILE @@FETCH_STATUS <> -1   
               BEGIN
                  BEGIN TRY
                     EXEC isp_QCmd_SubmitTaskToQCommander
                          @cTaskType           = 'T'                  -- 'T' - TransmitlogKey, 'D' - Data Stream 
                        , @cStorerKey          = @c_StorerKey 
                        , @cDataStream         = @c_DataStream
                        , @cCmdType            = @c_CmdType 
                        , @cCommand            = @c_ExecStatements
                        , @cTransmitlogKey     = @c_Transmitlogkey 
                        , @nThreadPerAcct      = @n_ThreadPerAcct 
                        , @nThreadPerStream    = @n_ThreadPerStream 
                        , @nMilisecondDelay    = @n_MilisecondDelay  
	                     , @nSeq					  = 1
                        , @cIP                 = @c_IP
                        , @cPORT               = @c_PORT
                        , @cIniFilePath        = @c_IniFilePath
                        , @cAPPDBName          = @c_APP_DB_Name 
                        , @bSuccess            = @b_Success     OUTPUT 
                        , @nErr                = @n_Err         OUTPUT 
                        , @cErrMsg             = @c_ErrMsg      OUTPUT
               	
                  END TRY
                  BEGIN CATCH
      	               SELECT @n_Err = ERROR_NUMBER(), @c_ErrMsg = ERROR_MESSAGE()
                        SET @c_ErrMsg = 'NSQL (' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + ')' +  @c_ErrMsg		     
                  END CATCH


                  FETCH NEXT FROM C_T3_Record INTO @c_Transmitlogkey
               END
               CLOSE C_T3_Record
               DEALLOCATE C_T3_Record
            END
         --END --IF NOT EXISTS (SELECT 1 
      END --IF @@ROWCOUNT <> 0 --Record Found

      FETCH NEXT FROM C_Process_Record INTO @c_TableName, @c_StorerKey
   END
   CLOSE C_Process_Record
   DEALLOCATE C_Process_Record
   
   --SET @dt_EndTime = GETDATE()  
   --EXECUTE dbo.isp_ITFLog 
   --         @n_ITFLogKey      = 0
   --      ,  @c_DataStream     = @c_DataStream
   --      ,  @c_ITFType        = 'QCM'
   --      ,  @n_FileKey        = 0
   --      ,  @n_AttachmentID   = 0
   --      ,  @c_FileName       = ''
   --      ,  @d_LogDateStart   = @dt_StartTime 
   --      ,  @d_LogDateEnd     = @dt_EndTime
   --      ,  @n_NoOfRecCount   = 0
   --      ,  @c_RefKey1        = @c_TransmitLogKey
   --      ,  @c_RefKey2        = ''
   --      ,  @c_Status         = ''
   --      ,  @b_Success        = @b_Success   OUTPUT
   --      ,  @n_Err            = @n_Err       OUTPUT
   --      ,  @c_ErrMsg         = @c_ErrMsg    OUTPUT

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