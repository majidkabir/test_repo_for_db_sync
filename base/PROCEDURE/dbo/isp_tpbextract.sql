SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_TPBExtract                                     */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: Main Program for Datamart Extraction                        */      
/*                                                                      */      
/* Called By:                                                           */      
/*                                                                      */      
/* PVCS Version: 1.3                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author    Ver.  Purposes                                */      
/* 2-May-2018   TLTING    1.1   Retrigger flag parameter                */ 
/* 08-Jun-18    TLTING    1.2   Auto rerun miss billdate                */
/* 21-Aug-18    TLTING    1.3   Bug fix - rerun miss extraction         */
/* 26-Sept-19   kocy      1.4   Support data extraction date range      */
/*                               (DataDuration)                         */
/* 19-Nov-19    TLTING01  1.5   Bug fix - duration and billdate         */
/************************************************************************/  
CREATE PROC [dbo].[isp_TPBExtract]   
 @n_TPB_def_Schedule int,   
 @n_ErrNo        int = 0 OUTPUT,  
 @c_ErrMsg       Nvarchar(215) = '' OUTPUT,
 @n_debug        INT = 0   
AS  
BEGIN  
    SET CONCAT_NULL_YIELDS_NULL OFF    
    SET QUOTED_IDENTIFIER OFF      
    SET ANSI_NULLS OFF    
    SET NOCOUNT ON    
   
   DECLARE @n_trancount    INT     
   DECLARE @n_TPB_Key BIGINT, @c_TPB_code NVARCHAR(125), @c_Category NVARCHAR(50), @c_SQL NVARCHAR(4000)
   , @c_SQLArgument NVARCHAR(4000)
   DECLARE @n_WMS_BatchNo BIGINT
   , @cExecStatements NVARCHAR(4000)
   , @cExecArguments NVARCHAR(4000)
   , @nErrSeverity INT
   , @nErrState INT
   , @n_RecCOUNT INT
   , @n_TotalRecCOUNT BIGINT
   , @dt_today DATETIME
   , @n_lastBatchkey INT
   , @d_lastBillDate  DATE
   , @d_BillDate  DATE
   , @n_DataDuration INT

   
   SET @n_trancount = @@TRANCOUNT    
   SET @n_ErrNo = 0   
   SET @n_lastBatchkey = 0
   SET @dt_today = CONVERT(DATETIME, CONVERT(CHAR(11), GETDATE(), 112))
 
 
   INSERT INTO dbo.TPB_Data_Batch DEFAULT VALUES     
   SET @n_WMS_BatchNo = @@IDENTITY     


   DECLARE CUR_DES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT TPB_Key,   
             TPB_code,  
             Category,    
             [SQL],
             ISNULL(RTRIM(SQLArgument),''),
             ISNULL(DataDuration, 30)      --kocy
      FROM dbo.TPB_Config WITH (NOLOCK)   
      WHERE TPB_def_schedule =  @n_TPB_def_Schedule   
      AND   [Enabled] = 1  AND [SQL]  <> ''
      ORDER BY TPB_Key 
     
   OPEN CUR_DES  
  
   FETCH NEXT FROM CUR_DES INTO @n_TPB_Key, @c_TPB_code, @c_Category, @c_SQL, @c_SQLArgument, @n_DataDuration 
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN      
    
      SELECT @nErrSeverity = '', @c_ErrMsg = '', @n_ErrNo = 0   
	 

      SELECT @n_lastBatchkey = MAX( TEH_Batch_Key )
      FROM dbo.TPB_EXTRACTION_HISTORY (NOLOCK)
         WHERE TEH_TPB_Key =  @n_TPB_Key
         AND TEH_ROW_Count is not NULL   -- tlting

      
      SET @d_LastBillDate = '19000101'

      SELECT @d_LastBillDate = CONVERT(DATETIME, CONVERT(CHAR(11), BillDate ) ) 
      FROM dbo.TPB_EXTRACTION_HISTORY  (NOLOCK)
      WHERE   TEH_Batch_Key  = @n_lastBatchkey
      AND	  TEH_TPB_Key        = @n_TPB_Key
      
      IF @n_debug = 1
      BEGIN
         PRINT 'TPB CONFIG - '
         PRINT 'TPB_Key- ' + CAST(@n_TPB_Key AS NVARCHAR)+ ' , TPB_code- ' + @c_TPB_code + ' ,Category-' + @c_Category
         PRINT 'SQL - ' + @c_SQL
         PRINT 'SQLArgument-' + @c_SQLArgument
		 PRINT 'LastBatchkey-' + cast(@n_lastBatchkey as nvarchar)
		 PRINT 'LastBillDate-' + cast(@d_LastBillDate as nvarchar)
      END

      /* if lastbilldate never been run, set the initial billdate at least a months, default = 30  */    --kocy
      IF @d_LastBillDate IS NULL OR @d_LastBillDate = '19000101'
      BEGIN
         SET @d_BillDate = dateadd(day, -@n_DataDuration, @dt_today )   
      END 
      ELSE
      BEGIN 
      /* otherwise, set the billdate to be (today - previous billdate) as last billdate  */
         SET @n_DataDuration =  datediff(day, @d_LastBillDate, @dt_today - 1 )  --TLTING01
         --Select @n_DataDuration
         --SET @d_BillDate = CONVERT (DATETIME, CONVERT(CHAR(11),DATEADD(day, -@n_DataDuration, @dt_today ),112 ))
         --TLTING01
         SET @d_BillDate = DATEADD(day, 1, CONVERT(DATETIME, CONVERT(CHAR(11), @d_LastBillDate, 112))   )

      END

      IF @n_debug =1
      BEGIN
        PRINT 'No.DaysDuration=' + cast(@n_DataDuration as nvarchar)
        PRINT 'TodayDate - '+ cast(@dt_today as nvarchar)
      END
      
      WHILE @d_BillDate < @dt_today 
      BEGIN
		  IF @n_debug = 1
		  BEGIN

			 PRINT 'BillDate-' + cast(@d_BillDate as nvarchar)
		  END

         BEGIN TRAN
         SET @cExecStatements = @c_SQL 

         SET @cExecArguments = ISNULL(@c_SQLArgument , '' )
            
         BEGIN TRY 
         
               EXEC sp_ExecuteSql  @cExecStatements  
                              , @cExecArguments  
                              , @n_WMS_BatchNo 
                              , @n_TPB_Key
                              , @d_BillDate
                              , @n_RecCOUNT OUTPUT
                              , @n_debug  
         END TRY
         BEGIN CATCH  
            SET @n_ErrNo        = ERROR_NUMBER()
            SET @c_ErrMsg     = ERROR_MESSAGE() + ' Msg: ' +  cast(@n_TPB_Key as nvarchar) +'-'+ @c_TPB_code +' -'+ @c_SQL
            SET @nErrSeverity = ERROR_SEVERITY();
            SET @nErrState    = ERROR_STATE();
            RAISERROR ( @c_ErrMsg, @nErrSeverity, @nErrState );
            ROLLBACK TRAN
         END CATCH
   
         IF @n_ErrNo = 0  -- tlting01
         BEGIN
  
            COMMIT TRAN 
                             
            INSERT dbo.TPB_EXTRACTION_HISTORY (TEH_Batch_Key,TEH_TPB_Key,TEH_Row_Count, Billdate )
            VALUES (@n_WMS_BatchNo, @n_TPB_Key, @n_RecCOUNT, @d_BillDate)    
         END
         ELSE
         BEGIn
         
            execute dbo.nsp_logerror @n_ErrNo, @c_errmsg, 'isp_TPBExtract ' 
            Break
         END 
		   SET @d_BillDate = dateadd(day, 1, @d_BillDate )

      END

      NEXT_Record_DES:

      FETCH NEXT FROM CUR_DES INTO @n_TPB_Key, @c_TPB_code, @c_Category, @c_SQL, @c_SQLArgument, @n_DataDuration 
   END  
   CLOSE CUR_DES  
   DEALLOCATE CUR_DES  
   
   SELECT @n_TotalRecCOUNT = COUNT(1)
   FROM [dbo].[WMS_TPB_BASE] (NOLOCK)
   WHERE BatchNo = @n_WMS_BatchNo 
   AND [STATUS] <> '5'
   
   IF @n_debug = 1
   BEGIN
      PRINT 'WMS_BatchNo-' + CAST(@n_WMS_BatchNo AS NVARCHAR) + ' ,TotalRecCOUNT-' + CAST(@n_TotalRecCOUNT AS NVARCHAR )
   END
    

   UPDATE dbo.TPB_Data_Batch
   SET Batch_RecRow = @n_TotalRecCOUNT, [Status] = '0'
   WHERE Batch_Key = @n_WMS_BatchNo

     
   EXIT_PROC:  
   IF @n_ErrNo <> 0   
   BEGIN  
      WHILE @@TRANCOUNT > 0    
      BEGIN    
         ROLLBACK TRAN    
      END     
 
      execute dbo.nsp_logerror @n_ErrNo, @c_errmsg, 'isp_TPBExtract'         
  
	  RAISERROR (@c_errmsg, 16, 1) WITH LOG		--SQL2012
     RETURN   
   END   
   ELSE  
   BEGIN   
      WHILE @@TRANCOUNT > 0   
         COMMIT TRAN   
   END   
  
END -- Procedure

GO