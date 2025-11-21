SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
/************************************************************************/    
/* Store Procedure:  isp_Build_ARCHIVE_Table_PK_GENERIC                 */    
/* Creation Date: 08-DEC-2016                                           */    
/* Written by: JayLim                                                   */    
/*                                                                      */    
/* Purpose: Script out Table Index and Deploy it ARCHIVE DB             */    
/*                                                                      */    
/* Input Parameters:   @c_copyfrom_db   - source db name                */  
/*                     @c_copyto_db     - destination db name           */   
/*                     @c_schema        - target table schema           */  
/*                     @c_TableName     - target table                  */  
/*                                                                      */  
/* Usage:      Generate PK key to Archive db's table                    */    
/*                                                                      */    
/* Called By:  isp_ArchiveTable_GENERIC/isp_ArchiveTable2_GENERIC       */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Purposes                                      */    
/* 29-Dec-2016  JayLim    Bug Fix  (Jay01)                              */   
/* 09-Mar-2017 JayLim    Fix PK bug on other schema except dbo (Jay02)  */  
/************************************************************************/    
  
CREATE   PROC [dbo].[isp_Build_ARCHIVE_Table_PK_GENERIC]  
       @c_schema       NVARCHAR(10),  
       @c_copyfrom_db  NVARCHAR(50),  
       @c_copyto_db    NVARCHAR(50),    
       @c_TableName    NVARCHAR(50),  
       @b_Success      int         OUTPUT ,  
       @n_err          int         OUTPUT,     
       @c_errmsg       NVARCHAR(250)   OUTPUT    
AS    
BEGIN     
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
                   
   DECLARE @b_debug              INT,  
           @n_continue           INT,  
           @n_starttcnt          INT,  
           @c_buildstring        NVARCHAR(50),  
           @c_FullTableName      NVARCHAR(60),  
           @c_Execsttmt          NVARCHAR(max),  
           @c_constraint_name    NVARCHAR(20),  
           @c_recordcount        INT  
  
   DECLARE @c_column_name        NVARCHAR(20),  
           @c_DESC_KEY           NVARCHAR(1),  
           @c_is_padded          NVARCHAR(1),  
           @c_is_Statistic       NVARCHAR(1),  
           @c_ignore_dup_key     NVARCHAR(1),  
           @c_fill_factor        NVARCHAR(5),  
           @c_allow_row_locks    NVARCHAR(1),  
           @c_allow_page_locks   NVARCHAR(1)  
        
   IF ISNULL(OBJECT_ID('tempdb..#t_TABLE_PK_COLUMNS_DETAILS'), '') <> ''  
       BEGIN  
           DROP TABLE #t_TABLE_PK_COLUMNS_DETAILS  
       END  
  
   IF ISNULL(OBJECT_ID('tempdb..#t_TABLE_INDEX_DETAILS'), '') <> ''  
       BEGIN  
           DROP TABLE #t_TABLE_INDEX_DETAILS  
       END  
     
   CREATE TABLE #t_TABLE_PK_COLUMNS_DETAILS    
   (  
      CONSTRAINT_NAME         NVARCHAR(20) NULL,  
      COLUMN_NAME             NVARCHAR(20) NULL,  
      DESC_KEY                NVARCHAR(1) NULL  
   )  
  
   CREATE TABLE #t_TABLE_INDEX_DETAILS  
   (  
      TABLE_Object_ID         NVARCHAR(20) NULL,  
      TABLE_INDEX_NAME        NVARCHAR(20) NULL,  
      INDEX_is_padded         NVARCHAR(1) NULL,  
      INDEX_is_statistics     NVARCHAR(1) NULL,  
      INDEX_ignore_dup_key    NVARCHAR(1) NULL,  
      INDEX_fill_factor       NVARCHAR(5) NULL,  
      INDEX_allow_row_locks   NVARCHAR(1) NULL,  
      INDEX_allow_page_locks  NVARCHAR(1) NULL  
   )  
                       
   -- initial variable value               
   SET @n_starttcnt = @@TRANCOUNT   
   SET @n_continue = 1   
   SET @b_success = 0  
   SET @n_err = 0  
   SET @c_errmsg = ''   
   SET @b_debug = 0  
   SET @c_FullTableName = @c_schema + '.' + @c_TableName  
   SET @c_constraint_name = ''  
   SET @c_recordcount = 0  
  
  
/******************************** Source & destination db checking (start) ***************************************************/  
   SELECT @c_buildstring = LTRIM(RTRIM(@c_copyfrom_db)) + '.' + LTRIM(RTRIM(@c_schema)) +'.' + LTRIM(RTRIM(@c_tablename))    
   IF OBJECT_ID( @c_buildstring) IS NULL OR OBJECT_ID( @c_buildstring) = ''   
   BEGIN     
      SELECT @n_continue = 3  -- Error when table not exists in source database  
      SELECT @n_err =   73301    
      SELECT @c_errmsg =  'NSQL' + CONVERT(CHAR(5),@n_err) + ':' + @c_buildstring +     
            ' does  not exist (isp_Build_ARCHIVE_Table_PK_GENERIC)'    
   END    
  
   SELECT @c_buildstring = LTRIM(RTRIM(@c_copyto_db)) + '.' + LTRIM(RTRIM(@c_schema)) +'.' + LTRIM(RTRIM(@c_tablename))   
   IF OBJECT_ID(@c_buildstring) IS NULL AND OBJECT_ID(@c_buildstring) = ''    
   BEGIN     
      SELECT @n_continue = 4  -- No need to continue if table not exists in destination database    
   END   
/******************************** Source & destination db checking (end) ****************************************************/  
  
/******************************** PREPARE & APPEND VARIABLE VALUE (start) ***************************************************/  
   IF @n_continue=1 OR @n_continue=2  
   BEGIN  
        
      INSERT INTO #t_TABLE_PK_COLUMNS_DETAILS  
      (  [CONSTRAINT_NAME]  
       , [COLUMN_NAME]  
       , [DESC_KEY]  
      )  
      SELECT constraint_name, column_name, is_descending_key   
      FROM   
      (  SELECT KU.constraint_name  
              , KU.column_name  
         FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS TC  
         INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS KU   
            ON (TC.CONSTRAINT_NAME = KU.CONSTRAINT_NAME)  
         WHERE TC.CONSTRAINT_TYPE = 'PRIMARY KEY'   
         AND KU.table_name= @c_TableName  
         AND TC.table_schema = @c_Schema  
         AND KU.constraint_schema = @c_Schema  
      ) t1   
      LEFT JOIN   
      (  SELECT ix.name AS 'Name_Constraint'  
              , col.name  
              , ixc.is_descending_key  
         FROM sys.tables tb   
         INNER JOIN sys.indexes ix   
            ON (tb.[object_id]=ix.[object_id])  
         INNER JOIN sys.index_columns ixc   
            ON (ix.[object_id]=ixc.[object_id] and ix.index_id= ixc.index_id)  
         INNER JOIN sys.columns col   
            ON (ixc.[object_id] =col.[object_id]  and ixc.column_id=col.column_id)  
         WHERE ix.is_primary_key=1   
         AND schema_name(tb.[schema_id])= @c_Schema   
         AND tb.name= @c_TableName   
      ) t2   
      ON  t1.column_name = t2.name AND t1.constraint_name = t2.Name_constraint  
  
      IF @b_debug =1   
      BEGIN  
         SELECT * FROM #t_TABLE_PK_COLUMNS_DETAILS  
      END  
  
      SET @c_constraint_name = (SELECT TOP 1 Constraint_Name FROM #t_TABLE_PK_COLUMNS_DETAILS)  
  
      IF @c_constraint_name IS NULL OR  @c_constraint_name = ''  
      BEGIN  
         SET @n_continue = 3  
         SELECT @c_errmsg = 'PRIMARY KEY does not EXISTS'  
      END  
   END  
  
   IF @n_continue=1 OR @n_continue=2  
   BEGIN  
  
      INSERT INTO #t_TABLE_INDEX_DETAILS   
      (  [TABLE_Object_ID]  
       , [TABLE_INDEX_NAME]    
       , [INDEX_is_padded]  
       , [INDEX_is_statistics]  
       , [INDEX_ignore_dup_key]  
       , [INDEX_fill_factor]  
       , [INDEX_allow_row_locks]  
       , [INDEX_allow_page_locks]  
      )  
      SELECT b.[object_id]  
           , b.name  
           , b.is_padded  
           , INDEXPROPERTY(a.[Object_id], b.name, 'IsStatistics')  
           , b.[ignore_dup_key]  
           , b.[fill_factor]  
           , b.[allow_row_locks]  
           , b.[allow_page_locks]  
      FROM sys.tables a   
      INNER JOIN sys.indexes b ON (a.[object_id] = b.[object_id])  
      WHERE a.[object_id] = OBJECT_ID(@c_FullTableName)   
      AND b.name = RTRIM(LTRIM(@c_constraint_name))  
  
      IF @b_debug =1   
      BEGIN  
         SELECT * FROM #t_TABLE_INDEX_DETAILS  
         SELECT @c_constraint_name AS 'Constraint_Name'  
      END  
  
      IF ((SELECT 1 FROM #t_TABLE_INDEX_DETAILS )='' OR (SELECT 1 FROM #t_TABLE_INDEX_DETAILS ) IS NULL)  
      BEGIN  
         SET @n_continue = 3 -- error due to primary key not exists  
         SELECT @c_errmsg = 'PK CONSTRAINT does not EXISTS'  
      END  
  
   END   
/******************************** PREPARE & APPEND VARIABLE VALUE (end) *****************************************************/  
/******************************** BUILD PRIMARY KEY CREATE STRING (start) ***************************************************/  
   IF @n_continue=1 OR @n_continue=2  
   BEGIN  
  
    SET @c_Execsttmt = N'USE ['+@c_copyto_db+'] '  
                       +'ALTER TABLE ['+@c_Schema+'].['+@c_TableName+'] '  
                       +'ADD CONSTRAINT ['+@c_constraint_name+'] PRIMARY KEY CLUSTERED ('  
      
    SELECT @c_recordcount = (SELECT COUNT(1) FROM #t_TABLE_PK_COLUMNS_DETAILS)  
  
    DECLARE READ_PK_COLUMN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
    SELECT RTRIM(LTRIM(COLUMN_NAME)),DESC_KEY  
    FROM #t_TABLE_PK_COLUMNS_DETAILS  
  
    OPEN  READ_PK_COLUMN  
    FETCH NEXT FROM READ_PK_COLUMN INTO @c_column_name , @c_DESC_KEY  
  
    WHILE (@@FETCH_STATUS = 0)  
    BEGIN  
      SET @c_Execsttmt = @c_Execsttmt   
                    + '[' + @c_column_name + ']'  
                    + CASE WHEN @c_DESC_KEY = 1 AND @c_recordcount > 1 THEN ' DESC, '  
                           WHEN @c_DESC_KEY = 0 AND @c_recordcount > 1 THEN ' ASC, '  
                           WHEN @c_DESC_KEY = 1 AND @c_recordcount = 1 THEN ' DESC '  
                           ELSE ' ASC ' END   
        
      SET @c_recordcount =  (@c_recordcount - 1)  
  
      IF @b_debug =1  
      BEGIN  
         SELECT @c_column_name AS 'column_name'  
              , @c_DESC_KEY AS 'DESC_KEY'  
              , @c_recordcount AS 'RecordCount'  
  
      END  
      FETCH NEXT FROM READ_PK_COLUMN INTO @c_column_name , @c_DESC_KEY  
    END  
    CLOSE READ_PK_COLUMN  
    DEALLOCATE READ_PK_COLUMN  
  
    SELECT @c_is_padded       = INDEX_is_padded  
         , @c_is_statistic    = INDEX_is_statistics  
         , @c_ignore_dup_key  = INDEX_ignore_dup_key  
         , @c_fill_factor     = INDEX_fill_factor  
         , @c_allow_row_locks = INDEX_allow_row_locks  
         , @c_allow_page_locks= INDEX_allow_page_locks  
     FROM #t_TABLE_INDEX_DETAILS  
  
    SET @c_Execsttmt = @c_Execsttmt   
                     + N') WITH ('  
                     + CASE WHEN @c_is_padded=0 THEN 'PAD_INDEX = OFF, ' ELSE 'PAD_INDEX = ON, ' END  
                     + CASE WHEN @c_is_statistic=0 THEN 'STATISTICS_NORECOMPUTE = OFF, ' ELSE 'STATISTICS_NORECOMPUTE = ON, ' END  
                     + 'SORT_IN_TEMPDB = OFF, '  
                     + CASE WHEN @c_ignore_dup_key=0 THEN 'IGNORE_DUP_KEY = OFF, ' ELSE 'IGNORE_DUP_KEY = ON, 'END  
                     + 'ONLINE = OFF, '  
                     + CASE WHEN @c_allow_row_locks=0 THEN 'ALLOW_ROW_LOCKS = OFF, ' ELSE 'ALLOW_ROW_LOCKS = ON, ' END  
                     + CASE WHEN @c_allow_page_locks=0 THEN 'ALLOW_PAGE_LOCKS = OFF, ' ELSE 'ALLOW_PAGE_LOCKS = ON 'END  
                     + CASE WHEN @c_fill_factor=0 THEN '' ELSE ', FILLFACTOR = '+@c_fill_factor END + ' ) ' --(Jay01)  
  
  
     EXECUTE sp_executesql @c_Execsttmt  
       
     IF @@ERROR <> 0  
     BEGIN  
      SET @n_continue = 3  
     END  
  
     IF(@b_debug = 1)  
     BEGIN  
         PRINT @c_Execsttmt  
     END  
  
   END  
/******************************** BUILD PRIMARY KEY CREATE STRING (end) *****************************************************/  
  
   IF @n_continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_success = 0    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
      ELSE    
      BEGIN    
         WHILE @@TRANCOUNT > @n_starttcnt    
         BEGIN    
            COMMIT TRAN    
         END    
      END    
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_Build_ARCHIVE_Table_PK_GENERIC'     
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SELECT @b_success = 1    
      WHILE @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN    
   END    
END  
  
  

GO