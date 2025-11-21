SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store Procedure:  isp_RecordsPurging                                */      
/* Creation Date: 14-Dec-2005                                           */      
/* Copyright: IDS                                                       */      
/* Written by: June                                                     */      
/*                                                                      */      
/* Purpose:  Purge records from the existing temp tables for more than  */      
/*           specific days in order to reduce the performance issues.   */      
/*           Get from isp_RecordsPurging, diff is it has one pass-in    */      
/*           date column. Not all tables have adddate col.              */      
/*                                                                      */      
/* Input Parameters:  @cTableName1   - 1st Table to process             */      
/*                    @cTableName2   - 2nd Table to process             */      
/*                    @cTableName3   - 3rd Table to process             */      
/*                    @cTableName4   - 4th Table to process             */      
/*                    @cTableName5   - 5th Table to process             */      
/*                    @nDays         - # of days to to keep             */      
/*                    @cDateCol      - date column name                 */      
/*                    e.g. 'LogDate' in ErrLog table                    */      
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
/* Date         Author    Purposes                                      */      
/* 08-Dec-2005  June      Bug fixes - Null adddate                      */  
/* 12-Nov-2010  TLTING    Purge by Primary key                          */    
/* 28-Jun-2012  TLTING    Delete by ArchiveCop if column exists         */ 
/*  2-Jul-2012  TLTING    Default value for parameter @cDateCol         */
/************************************************************************/      

CREATE PROC [dbo].[isp_RecordsPurging]      
     @cTableName1 NVARCHAR(30)      
   , @cTableName2 NVARCHAR(30)      
   , @cTableName3 NVARCHAR(30)      
   , @cTableName4 NVARCHAR(30)      
   , @cTableName5 NVARCHAR(30)      
   , @nDays       INT      
   , @cDateCol    NVARCHAR(30)  = 'Adddate'     
AS      
BEGIN      
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE @b_debug         INT      
         , @c_key           NVARCHAR(10)      
         , @b_success       INT      
         , @cTableName      NVARCHAR(30)      
         , @cExecStatements NVARCHAR(2000)      
         , @nCounter        INT      
         , @cMaxAddDate     NVARCHAR(8)      
         , @cAddDate        NVARCHAR(8)  
         , @cArchiveCopFlag NVARCHAR(1)     
         
   SELECT  @b_success       = 1      
         , @c_key           = ''      
         , @cTableName      = ''      
         , @cExecStatements = ''      
         , @nCounter        = 0       
         , @cMaxAddDate     = ''       
         , @cAddDate        = ''      
         , @b_debug         = 0     
         , @cArchiveCopFlag = '' 
      
   CREATE TABLE [#TempTables] (      
         [RowID] [varchar] (2) NULL ,      
         [TableName] [varchar] (30) NULL )      
      
 -- Check and insert into temp table if parameters of TableName having values.      
IF (@cTableName1 <> '') AND (@cTableName1 IS NOT NULL)      
BEGIN      
   INSERT INTO #TempTables (RowID, TableName) VALUES ('1', @cTableName1)      
END      
      
IF (@cTableName2 <> '') AND (@cTableName2 IS NOT NULL)      
BEGIN      
   INSERT INTO #TempTables (RowID, TableName) VALUES ('2', @cTableName2)      
END      
      
IF (@cTableName3 <> '') AND (@cTableName3 IS NOT NULL)      
BEGIN      
   INSERT INTO #TempTables (RowID, TableName) VALUES ('3', @cTableName3)      
END      
      
IF (@cTableName4 <> '') AND (@cTableName4 IS NOT NULL)      
BEGIN      
   INSERT INTO #TempTables (RowID, TableName) VALUES ('4', @cTableName4)      
END      
      
IF (@cTableName5 <> '') AND (@cTableName5 IS NOT NULL)      
BEGIN      
   INSERT INTO #TempTables (RowID, TableName) VALUES ('5', @cTableName5)      
END      

     
 -- Cursor Start      
DECLARE TempTables CURSOR READ_ONLY FAST_FORWARD FOR      
   SELECT TableName FROM #TempTables (NOLOCK) ORDER BY RowID      
   OPEN TempTables      
   FETCH NEXT FROM TempTables INTO @cTableName      


   WHILE @@fetch_status <> -1 
   BEGIN      
      IF @b_debug = 1      
      BEGIN      
         SELECT * FROM #TempTables (NOLOCK)      
         SELECT 'Start processing cursor TempTables... ' , master.dbo.fnc_GetCharASCII(13) ,      
         '@cTableName to get minimum date : ' , @cTableName      
      END      
      

      IF EXISTS ( SELECT 1 FROM  INFORMATION_SCHEMA.TABLES T
                  JOIN INFORMATION_SCHEMA.COLUMNS C ON C.Table_Catalog = T.Table_Catalog
                                    AND C.Table_Schema = T.Table_Schema 
                                    AND C.Table_Name = T.Table_Name
                  Where C.column_name = 'ArchiveCop'
                  AND T.Table_Name    = @cTableName )
      BEGIN

         SET @cArchiveCopFlag = '1'
      END
            
       -- Get the Minimum date for records purging - Start  
       SELECT @cMaxAddDate = '' ,   
          @cAddDate = '' ,   
          @nCounter = 0    
         SELECT @cExecStatements = N'SELECT DISTINCT @cMaxAddDate = MAX(CONVERT(CHAR(8), AddDate, 112)) '   
               + ' FROM ' + RTrim(LTrim(@cTableName)) + ' (NOLOCK) '  
         EXEC sp_executesql @cExecStatements, N'@cMaxAddDate NVARCHAR(8) OUTPUT ', @cMaxAddDate OUTPUT   
        
       IF @b_debug = 1  
       BEGIN  
            SELECT '@cMaxAddDate : ' , @cMaxAddDate   
       END  
        
       -- Loop to get the Minimum date for specific working days prior to the Maximum date.  
       WHILE @nCounter < @nDays  
       BEGIN  
            SELECT @cExecStatements = N'SELECT @cAddDate = MAX(CONVERT(CHAR(8), AddDate, 112)) '   
                + ' FROM ' + RTrim(LTrim(@cTableName)) + ' (NOLOCK) '  
                + ' WHERE CONVERT(CHAR(8), AddDate, 112) < "' + @cMaxAddDate + '" '   
            EXEC sp_executesql @cExecStatements, N'@cAddDate NVARCHAR(8) OUTPUT ', @cAddDate OUTPUT   
        
        -- Add by June  
        IF @cAddDate IS NULL  
         BREAK  
        -- End - June  
        
        SELECT @cMaxAddDate = @cAddDate   
        
        IF @b_debug = 1  
        BEGIN  
             SELECT '@cAddDate : ' , @cAddDate   
        END  
        
        SET @nCounter = @nCounter + 1   
       END -- WHILE @nCounter < @nDays  
       -- Get the Minimum date for records purging - End  
            
      IF (ISNULL(RTRIM(@cMaxAddDate), '') = '')  
      BEGIN          
         BREAK
      END
      
      DECLARE @cPrimaryKey NVARCHAR(128),
              @cSQL1       NVARCHAR(MAX),
              @cSQL2       NVARCHAR(MAX),
              @cSQL3       NVARCHAR(MAX),
              @nRowId      INT,
              @cFetchSQL   NVARCHAR(MAX),
              @cWhereSQL   NVARCHAR(MAX)              

      IF OBJECT_ID('tempdb..#PrimaryKey') IS NOT NULL 
         DROP TABLE #PrimaryKey

      CREATE TABLE #PrimaryKey (ColName sysname, SeqNo int, RowID int IDENTITY )
      
      INSERT INTO #PrimaryKey (ColName, SeqNo)
      EXEC ispPrimaryKeyColumns @cTableName

      IF EXISTS(SELECT 1 FROM #PrimaryKey) 
      BEGIN
         SELECT @cSQL1 = ' SET NOCOUNT ON ' + master.dbo.fnc_GetCharASCII(13)
         SELECT @cSQL1 = @cSQL1 + ' DECLARE @key1 NVARCHAR(20), @key2 NVARCHAR(20), @key3 NVARCHAR(20), @key4 NVARCHAR(20)' + master.dbo.fnc_GetCharASCII(13)
         SELECT @cSQL1 = @cSQL1 + ' DECLARE @key5 NVARCHAR(20), @key6 NVARCHAR(20), @key7 NVARCHAR(20), @key8 NVARCHAR(20)' + master.dbo.fnc_GetCharASCII(13)
         SELECT @cSQL1 = @cSQL1 + ' DECLARE C_RECORDS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR' + master.dbo.fnc_GetCharASCII(13)
         SELECT @cSQL1 = @cSQL1 + '    SELECT ' 
         SELECT @cFetchSQL = ' FETCH NEXT FROM C_RECORDS INTO '
         SELECT @cWhereSQL = ' WHERE ' 

         DECLARE C_PrimaryKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT ColName, RowID  
         FROM   #PrimaryKey 
         ORDER BY RowID 

         OPEN C_PrimaryKey 
   
         FETCH NEXT FROM C_PrimaryKey INTO @cPrimaryKey, @nRowId

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT @cSQL1 = @cSQL1 + CASE WHEN @nRowId > 1 THEN ',' ELSE '' END + ' ' + RTRIM(@cPrimaryKey)   
            SELECT @cFetchSQL = @cFetchSQL + CASE WHEN @nRowId > 1 THEN ',' ELSE '' END + '@Key' + RTRIM(CAST(@nRowId as NVARCHAR(2)))                   
            
            SELECT @cWhereSQL = @cWhereSQL + CASE WHEN @nRowId > 1 THEN ' AND ' ELSE '' END  + RTRIM(@cPrimaryKey) + ' = @Key' 
               + RTRIM(CAST(@nRowId as NVARCHAR(2))) 
                  
            FETCH NEXT FROM C_PrimaryKey INTO @cPrimaryKey, @nRowId 
         END 
         
         CLOSE C_PrimaryKey
         DEALLOCATE C_PrimaryKey 

         SELECT @cSQL1 = @cSQL1 + ' FROM ' + RTRIM(@cTableName) + ' (NOLOCK) ' + 
                                  ' WHERE ' + RTRIM(@cDateCol) + ' < ''' + @cMaxAddDate + ''''  + master.dbo.fnc_GetCharASCII(13) 
                                    
         SELECT @cSQL1 = @cSQL1 + ' OPEN C_RECORDS ' + master.dbo.fnc_GetCharASCII(13)
         SELECT @cSQL1 = @cSQL1 + @cFetchSQL + master.dbo.fnc_GetCharASCII(13)               
         SELECT @cSQL1 = @cSQL1 + ' WHILE @@FETCH_STATUS <> -1 ' + master.dbo.fnc_GetCharASCII(13)         
         SELECT @cSQL1 = @cSQL1 + ' BEGIN ' + master.dbo.fnc_GetCharASCII(13)       
         SELECT @cSQL2 =          '    BEGIN TRAN ' + master.dbo.fnc_GetCharASCII(13)  
         
         IF @cArchiveCopFlag = '1'
         BEGIN
            SELECT @cSQL2 = @cSQL2 + '    UPDATE ' + RTRIM(@cTableName) + ' SET ArchiveCop = ''9'' ' + @cWhereSQL + master.dbo.fnc_GetCharASCII(13)
         END
                  
         SELECT @cSQL2 = @cSQL2 + '    DELETE FROM ' + RTRIM(@cTableName) + @cWhereSQL + master.dbo.fnc_GetCharASCII(13)   
         SELECT @cSQL2 = @cSQL2 + '    WHILE @@TRANCOUNT > 0 COMMIT TRAN ' + master.dbo.fnc_GetCharASCII(13)           
--- 
         SELECT @cSQL2 = @cSQL2 + '   ' + @cFetchSQL + master.dbo.fnc_GetCharASCII(13) 
         SELECT @cSQL2 = @cSQL2 + ' END ' + master.dbo.fnc_GetCharASCII(13)  
         SELECT @cSQL2 = @cSQL2 + ' CLOSE C_RECORDS ' + master.dbo.fnc_GetCharASCII(13)  
         SELECT @cSQL2 = @cSQL2 + ' DEALLOCATE C_RECORDS ' + master.dbo.fnc_GetCharASCII(13) 
   
         IF (@b_debug = 1)
         BEGIN
            print @cSQL1 + 
                  @cSQL2 
         END
         EXEC( @cSQL1 + @cSQL2 )
         
      END -- Primary Key Exists 
      ELSE
      BEGIN

         IF @cArchiveCopFlag = '1'
         BEGIN
            SELECT @cSQL1 = N' SET ROWCOUNT 100 ' + master.dbo.fnc_GetCharASCII(13) +    
                              ' WHILE 1=1 ' + master.dbo.fnc_GetCharASCII(13) +     
                              ' BEGIN ' + master.dbo.fnc_GetCharASCII(13) +     
                              '    BEGIN TRAN ' + master.dbo.fnc_GetCharASCII(13) +     
                              '    UPDATE ' + RTRIM(LTRIM(@cTableName)) + ' ' + master.dbo.fnc_GetCharASCII(13) +   
                              '    SET ArchiveCop = ''9'' ' + master.dbo.fnc_GetCharASCII(13) +        
                              '    WHERE ' + RTRIM(LTRIM(@cDateCol)) + ' < ''' + @cMaxAddDate  + '''' + master.dbo.fnc_GetCharASCII(13) +                                                                 
                              '    DELETE ' + RTRIM(LTRIM(@cTableName)) + ' ' + master.dbo.fnc_GetCharASCII(13) +      
                              '    WHERE ' + RTRIM(LTRIM(@cDateCol)) + ' < ''' + @cMaxAddDate  + '''' + master.dbo.fnc_GetCharASCII(13) +      
                              '    IF @@ROWCOUNT = 0 ' + master.dbo.fnc_GetCharASCII(13) +     
                              '    BEGIN ' + master.dbo.fnc_GetCharASCII(13) +     
                              '       COMMIT TRAN ' + master.dbo.fnc_GetCharASCII(13) +                                                           
                              '       BREAK ' + master.dbo.fnc_GetCharASCII(13) +     
                              '    END ' + master.dbo.fnc_GetCharASCII(13) +     
                              '    COMMIT TRAN ' + master.dbo.fnc_GetCharASCII(13) +                                                                                      
                              ' END ' + master.dbo.fnc_GetCharASCII(13) +     
                              ' SET ROWCOUNT 0 '               
         END
         ELSE
         BEGIN            
            SELECT @cSQL1 = N' SET ROWCOUNT 100 ' + master.dbo.fnc_GetCharASCII(13) +    
                              ' WHILE 1=1 ' + master.dbo.fnc_GetCharASCII(13) +     
                              ' BEGIN ' + master.dbo.fnc_GetCharASCII(13) +     
                              '    BEGIN TRAN ' + master.dbo.fnc_GetCharASCII(13) +     
                              '    DELETE ' + RTRIM(LTRIM(@cTableName)) + ' ' + master.dbo.fnc_GetCharASCII(13) +      
                              '    WHERE ' + RTRIM(LTRIM(@cDateCol)) + ' < ''' + @cMaxAddDate  + '''' + master.dbo.fnc_GetCharASCII(13) +      
                              '    IF @@ROWCOUNT = 0 ' + master.dbo.fnc_GetCharASCII(13) +     
                              '    BEGIN ' + master.dbo.fnc_GetCharASCII(13) +     
                              '       COMMIT TRAN ' + master.dbo.fnc_GetCharASCII(13) +                                                           
                              '       BREAK ' + master.dbo.fnc_GetCharASCII(13) +     
                              '    END ' + master.dbo.fnc_GetCharASCII(13) +     
                              '    COMMIT TRAN ' + master.dbo.fnc_GetCharASCII(13) +                                                                                      
                              ' END ' + master.dbo.fnc_GetCharASCII(13) +     
                              ' SET ROWCOUNT 0 '     
         END
                                      
         IF @b_debug = 1                                                    
         BEGIN      
            SELECT 'Purging records older than = ', @cMaxAddDate, master.dbo.fnc_GetCharASCII(13), @cSQL1      
            print @cSQL1
         END      
         EXEC( @cSQL1 )         
      END                
         
      FETCH NEXT FROM TempTables INTO @cTableName      
   END -- WHILE @@fetch_status <> -1      
      
   IF @b_debug = 1      
   BEGIN      
      SELECT 'End Cursor ! '      
   END      
      
   CLOSE TempTables      
   DEALLOCATE TempTables      
   -- Cursor End      
   DROP TABLE #TempTables      
END -- procedure

GO