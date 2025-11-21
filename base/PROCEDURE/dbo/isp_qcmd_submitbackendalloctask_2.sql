SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_QCmd_SubmitBackendAllocTask_2                  */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Rev   Purposes                                  */
/* 07-AUG-2018 Wan01    1.1   Fixed                                     */
/* 06-May-2020 Shong    1.2   Addding Priority to Q-Cmd Task (SWT01)    */
/************************************************************************/
CREATE PROC [dbo].[isp_QCmd_SubmitBackendAllocTask_2] ( 
	  @nAllocBatchNo BIGINT = 0 	
   , @bSuccess      INT = 1            OUTPUT
   , @nErr          INT = ''           OUTPUT
   , @cErrMsg       NVARCHAR(250) = '' OUTPUT	
	, @bDebug        INT = 0 

)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @nAllocBatchNo = 0 
      RETURN 
     
   DECLARE @cStorerKey            NVARCHAR(15),
           @cFacility             NVARCHAR(5),
           @nSuccess              INT,    
           @cErrorMsg             NVARCHAR(256),        
           @cSQLSelect            NVARCHAR(MAX),
           @cSQLCondition         NVARCHAR(MAX),               
           @cBatchNo              NVARCHAR(10), 
           @nWherePosition        INT, 
           @nGroupByPosition      INT, 
           @cTransmitLogKey       NVARCHAR(10),
           
           @nOrderCnt             INT, 
           @nErrNo                INT, 
           @cSKU                  NVARCHAR(20), 
           @nPrevAllocBatchNo     BIGINT, 
           @dOrderAddDate         DATETIME,
           @cCommand              NVARCHAR(2014), 
           @cAllocBatchNo         NVARCHAR(10), 
           @cAllocStrategy        NVARCHAR(200),
           @nNextAllocBatchNo     BIGINT,  
           @nBL_Priority          INT = 0, 
           @nTaskSeqNo            INT = 0, 
           @nRowID                INT = 0, 
           @nSafetyAllocOrders    INT = 0,
           @nTaskPriority         INT = 0,
           @nRevisePriority       INT = 0,
           @nAllocatedOrders      INT = 0, 
           @nSubmmittedTask       INT = 0,
            
           @nContinue             INT = 1,
           @nBatchNo              INT = 1,
           @nPercentage           INT = 0,
           @nBatchRetry           INT = 0,
           @nStartTranCount       INT = 0,
           @c_NoTask              CHAR(1) = 'N'   

	DECLARE @c_APP_DB_Name           NVARCHAR(20)  = ''
         , @c_DataStream            VARCHAR(10)   = ''
         , @n_ThreadPerAcct         INT           = 0
         , @n_ThreadPerStream       INT           = 0
         , @n_MilisecondDelay       INT           = 0
         , @c_IP                    NVARCHAR(20)  = ''
         , @c_PORT                  NVARCHAR(5)   = ''
         , @c_IniFilePath           NVARCHAR(200) = ''
         , @c_CmdType               NVARCHAR(10)  = ''      
         , @c_TaskType              NVARCHAR(1)   = ''  
         , @n_Priority              INT = 0 -- (SWT01)
         
         
	SELECT @c_APP_DB_Name         = APP_DB_Name
	      , @c_DataStream          = DataStream 
	      , @n_ThreadPerAcct       = ThreadPerAcct 
	      , @n_ThreadPerStream     = ThreadPerStream 
	      , @n_MilisecondDelay     = MilisecondDelay 
         , @c_IP                  = IP
         , @c_PORT                = PORT
         , @c_IniFilePath         = IniFilePath
         , @c_CmdType             = CmdType             
         , @c_TaskType            = TaskType    
         , @n_Priority            = ISNULL([Priority],0) -- (SWT01)        
	FROM  QCmd_TransmitlogConfig WITH (NOLOCK)
	WHERE TableName               = 'BACKENDALLOC'
   AND   [App_Name]					= 'WMS'
   AND   StorerKey               = 'ALL' 
   IF @c_IP = ''
   BEGIN
   	SET @nContinue = 3
   	SET @nErr = 60205
   	SET @cErrMsg = 'Q-Commander TCP Socket not setup!'
   	GOTO EXIT_SP
   END  
   
  	   	
   SET @nStartTranCount = @@TRANCOUNT
 
   WHILE @@TRANCOUNT > 0 
      COMMIT TRAN;

   SET @nRowID = 0 
            
   WHILE 1=1
   BEGIN
      -- (SWT01) Do not submit task for same SKU if it's not complete         	
   	SELECT TOP 1
   	      @cSKU = AAB.SKU, 
   	      @nAllocBatchNo = AAB.AllocBatchNo, 
   	      @nRowID = AAB.RowID, 
   	      @cAllocStrategy = AAB.StrategyKey, 
   	      @cFacility = AAB.Facility, 
   	      @cStorerKey = AAB.Storerkey
   	FROM  AutoAllocBatchJob AAB WITH (NOLOCK)   
   	WHERE AAB.[Status]='0'
   	AND   AAB.AllocBatchNo =  @nAllocBatchNo
   	AND   AAB.RowID > @nRowID
   	ORDER BY AAB.RowID
      	                  	
      IF @@ROWCOUNT > 0 
      BEGIN  
      	SET @cTransmitLogKey = CAST(@nRowID AS VARCHAR(10))
      	
      	IF EXISTS(SELECT 1 FROM TCPSocket_QueueTask AS tqt WITH(NOLOCK)
      	          WHERE tqt.TransmitLogKey = @cTransmitLogKey )
      	   CONTINUE
      	   
         SET @c_NoTask = 'N'
            	 	               	
      	BEGIN TRAN;
      	
      	SET @nBatchRetry = 0 
      	   		               	              	                     	 
         SET @cAllocBatchNo = CAST(@nAllocBatchNo AS VARCHAR(10))
               	
         IF EXISTS(SELECT 1 FROM LOT WITH (NOLOCK)
               	   WHERE LOT.StorerKey = @cStorerKey 
               	   AND   LOT.Sku = @cSKU 
               	   AND   LOT.STATUS = 'OK'
               	   AND   (LOT.QTY - LOT.QtyAllocated - LOT.QTYPicked - LOT.QtyPreAllocated ) > 0)
         BEGIN
            SET @cCommand = N'EXEC [dbo].[isp_BatchSKUProcessing]' +
                              N'  @n_AllocBatchNo = ' + @cAllocBatchNo + 
                              N', @c_Facility = ''' + @cFacility + ''' ' + 
                              N', @c_StorerKey = ''' + @cStorerKey + ''' ' + 
                              N', @c_SKU = ''' + @cSKU + ''' ' +
                              N', @c_Strategy = ''' + @cAllocStrategy + ''' ' +
                              N', @b_Success = 1 ' + 
                              N', @n_Err = 0 ' + 
                              N', @c_ErrMsg = '''' ' + 
                              N', @b_debug = 0 ' +
                              N', @n_JobRowId = ' + CAST(@nRowID AS VARCHAR(10))    --(Wan01)

            IF @bDebug = 1
            BEGIN
   			   PRINT '>>> @nRowID: ' + CAST(@nRowID AS VARCHAR(10))
               PRINT '>>> @nAllocBatchNo:   ' + CAST(@nAllocBatchNo AS VARCHAR(10))   			         
               PRINT '  > @cCommand : ' + @cCommand           
               PRINT ''       	
            END                                          	         	          
      
            BEGIN TRY
               EXEC isp_QCmd_SubmitTaskToQCommander 
                       @cTaskType         = 'O' -- D=By Datastream, T=Transmitlog, O=Others       
                     , @cStorerKey        = @cStorerKey                                            
                     , @cDataStream       = ''                                                     
                     , @cCmdType          = 'SQL'                                                  
                     , @cCommand          = @cCommand                                              
                     , @cTransmitlogKey   = @nRowID                                         
                     , @nThreadPerAcct    = @n_ThreadPerAcct                                                        
                     , @nThreadPerStream  = @n_ThreadPerStream                                                      
                     , @nMilisecondDelay  = @n_MilisecondDelay                                                      
                     , @nSeq              = 1                                                      
                     , @cIP               = @c_IP                                         
                     , @cPORT             = @c_PORT                                                
                     , @cIniFilePath      = @c_IniFilePath       
                     , @cAPPDBName        = @c_APP_DB_Name                                               
                     , @bSuccess          = @bSuccess OUTPUT  
                     , @nErr              = @nErr OUTPUT  
                     , @cErrMsg           = @cErrMsg OUTPUT
                     , @nPriority         = @n_Priority -- (SWT01)
            
               IF @nErr <> 0 AND ISNULL(@cErrMsg,'') <> ''
               BEGIN
            	   PRINT @cErrMsg           
      		                                 	 
            	   GOTO EXIT_SP 
               END              
               ELSE 
               BEGIN
               	BEGIN TRAN;
               	
                  UPDATE [dbo].[AutoAllocBatchJob] WITH (ROWLOCK)
                     SET [Status] = '1', EditDate = GETDATE()
                  WHERE RowID = @nRowID  
      	         IF @@ERROR <> 0 
      	         BEGIN
      		         ROLLBACK TRAN;
      		         GOTO EXIT_SP
      	         END
      	         ELSE
      		         COMMIT TRAN;   
      		                     		               
      		      SELECT @nSubmmittedTask = @nSubmmittedTask + 1
                  IF @bDebug = 1
                  BEGIN
   	               PRINT '>>> @nSubmmittedTask: ' + CAST(@nSubmmittedTask AS VARCHAR(10))
                  END      		                      		               	
               END       
            END TRY
            BEGIN CATCH
           	   SET @cErrMsg = ERROR_MESSAGE()
           	   PRINT @cErrMsg            
      		                                 	 
            	GOTO EXIT_SP               
            END CATCH
         END -- IF Stock Available 
         ELSE 
         BEGIN
         	BEGIN TRAN;
         	-- Update status to 6 to indicate "No Stock"
            UPDATE [dbo].[AutoAllocBatchJob]
               SET [Status] = '6', EditDate = GETDATE()
            WHERE RowID = @nRowID
            
      	   IF @@ERROR <> 0 
      	   BEGIN
      		   ROLLBACK TRAN;
      		   GOTO EXIT_SP
      	   END
      	   ELSE
      		   COMMIT TRAN;                       	
         END
               
         WHILE @@TRANCOUNT > 0 
            COMMIT TRAN;                           
      END  -- IF @@ROWCOUNT > 0  			
   	ELSE 
   		BREAK 
   END -- WHILE 1=1


   EXIT_SP:
   WHILE @@TRANCOUNT > 0 
      COMMIT TRAN;    
                     
   WHILE @@TRANCOUNT < @nStartTranCount
      BEGIN TRAN;
      
   IF @nContinue = 3
   BEGIN
   	SET @bSuccess = 0
   END 
END -- procedure

GO