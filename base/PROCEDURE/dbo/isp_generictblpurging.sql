SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/            
/* Store Procedure:  isp_GenericTBLPurging                              */            
/* Creation Date: 14-Feb-2018                                           */            
/* Copyright: IDS                                                       */            
/* Written by: TLTING                                                   */            
/*                                                                      */            
/* Purpose:  A generic purging base on TBL_PURGECONFIG - DataPurge      */            
/*           Calling script like isp_RecordsPurging2                    */            
/*                                                                      */            
/* Input Parameters:  Setup in TBL_PURGECONFIG                          */        
/*                                                                      */            
/* Usage:  Purge older records with the same batch of tables,           */            
/*         (same interface) at one time.                                */            
/*                                                                      */            
/* Called By:  Set under Scheduler Jobs.                                */            
/*                                                                      */            
/* PVCS Version: 1.0                                                    */            
/*                                                                      */            
/* Version: 5.4                                                         */            
/*                                                                      */            
/* Data Modifications:                                                  */            
/*                                                                      */            
/* Updates:                                                             */            
/* Date         Author  Ver  Purposes                                   */            
/* 08-Feb-2014  TLTING  1.0  Initial version                            */  
/* 02-Nov-2018  CJKHOR  1.1  Log SQL and Log Error                      */   
/* 15-Jul-2020  TLTING  1.2  trancount check                            */     
/************************************************************************/            
   
  
/*  
INSERT INTO TBL_PURGECONFIG (Item, TBLName, [Description], Threshold, Date_Col, Condition, PurgeGroup )  
VALUES ('WS_TEMP_TRACELOG','dbo.WS_TEMP_TRACELOG','Purge WS_TEMP_TRACELOG', 90,'StartDate','','IMLTrace')  
    
  
 exec [dbo].[isp_GenericTBLPurging] 'IMLTrace', 1  
  
  
*/  
       
CREATE PROC [dbo].[isp_GenericTBLPurging]      
( @cPurgeGroup    Nvarchar(30) = '',  
  @b_debug         INT         = 0   
          )           
AS            
BEGIN            
   SET NOCOUNT ON            
   SET ANSI_NULLS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
            
   DECLARE @b_success       INT            
         , @cTableName      NVARCHAR(100)            
         , @cExecStatements NVARCHAR(2000)  
         , @dStart DATETIME  
         , @dEnd DATETIME  
         , @nDuration INT      
         , @DB NVARCHAR(128)  
         , @Schema NVARCHAR(128)                 
         , @Proc  NVARCHAR(128)     
         , @Id INT = ISNULL(TRY_CAST(SUBSTRING(REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR,GETDATE(),126),'-',''),'T',''),':',''),3,10) AS INT),0)     
         , @n_err INT  
         , @c_errmsg NVARCHAR(255)   
         , @RowCnt INT = 0   
         , @SQLId INT  
         , @TranCnt INT = 0   
         
      DECLARE @cDays       NVARCHAR(5),        
              @cDateCol    NVARCHAR(50),          
              @cCondition  NVARCHAR(1000)  
                
   SELECT  @b_success       = 1            
         , @cTableName      = ''       
         , @cExecStatements = ''  
   SELECT @TranCnt = @@TRANCOUNT


   IF @b_debug is NULL  
      SET @b_debug = 0  
  
   SELECT  @DB=DB_NAME()    , @Schema=OBJECT_SCHEMA_NAME(@@PROCID), @Proc=ISNULL(OBJECT_NAME(@@PROCID),'')  
  
   IF ISNULL(RTRIM(@cPurgeGroup), '') = ''  
   BEGIN  
      DECLARE C_ITEM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR       
      SELECT ISNULL(RTRIM(TBLName), ''),  Threshold,   
            ISNULL(RTRIM(Date_Col), ''), ISNULL(RTRIM(Condition), '')   
      FROM    dbo.TBL_PURGECONFIG with (NOLOCK)  
      WHERE PurgeGroup IS NULL OR PurgeGroup = ''  
   END  
   ELSE      
   BEGIN      
      DECLARE C_ITEM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR       
      SELECT ISNULL(RTRIM(TBLName), ''),  CAST(Threshold AS NVARCHAR),   
            ISNULL(RTRIM(Date_Col), ''), ISNULL(RTRIM(Condition), '')   
      FROM    dbo.TBL_PURGECONFIG with (NOLOCK)  
      WHERE  PurgeGroup = RTRIM(@cPurgeGroup)  
   END  
   
   OPEN C_ITEM   
  
   FETCH NEXT FROM C_ITEM INTO @cTableName, @cDays, @cDateCol, @cCondition   
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
   SET @cExecStatements = ''  
   SET @cExecStatements = N'EXEC isp_RecordsPurging2 ''' + @cTableName                 
      + ''', '''', '''', '''', '''', ' + @cDays + ', ''' + @cDateCol  + ''', "' + @cCondition + '"'  
     
   IF @b_debug  = 1  
   BEGIN        
      PRINT @cExecStatements  
   END       
    
   BEGIN TRY  
      SET @dStart = GETDATE()  
      EXEC sp_ExecuteSql @cExecStatements  
      SET @RowCnt = @@ROWCOUNT  
   END TRY  
   BEGIN CATCH  
      EXEC ispLogError  @DB, @Schema, @Proc, @Id, @c_ErrMsg OUTPUT, @n_Err OUTPUT, '',0,0, @cTableName  
   END CATCH  
   SET @nDuration = DATEDIFF(s, @dStart, GETDATE())  
   EXEC ispLogQuery @DB, @Schema, @Proc, @Id, @cExecStatements, @nDuration, @RowCnt, @cTableName, @SQLId OUTPUT  
     
   FETCH NEXT FROM C_ITEM INTO @cTableName, @cDays, @cDateCol, @cCondition   
  
   END     
   CLOSE C_ITEM  
   DEALLOCATE C_ITEM  
   
   IF @@TRANCOUNT > @TranCnt
      COMMIT TRAN

END -- procedure
 

GO