SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [dbo].[isp_ExcelLoader_Build_SQL_Update] (    
  @TargetTable    NVARCHAR(200) = ''  
 ,@SourceTable    NVARCHAR(200) = ''  
 ,@PrimaryKey     NVARCHAR(2000) = ''  
 ,@SQL            NVARCHAR(MAX) = '' OUTPUT  
) AS   
BEGIN  
 DECLARE   
        @ColumnName     SYSNAME  
       ,@FirstTime      BIT = 0  
   
   DECLARE CUR_COLUMNS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT c.COLUMN_NAME   
   FROM INFORMATION_SCHEMA.[COLUMNS] AS c WITH(NOLOCK)  
   WHERE c.TABLE_NAME = PARSENAME(@TargetTable,1)  
   AND   c.COLUMN_NAME NOT IN (SELECT LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT( @PrimaryKey, ','))   
  
   OPEN CUR_COLUMNS  
  
   FETCH FROM CUR_COLUMNS INTO @ColumnName  
  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
    IF EXISTS(SELECT 1   
              FROM INFORMATION_SCHEMA.[COLUMNS] AS c WITH(NOLOCK)  
                WHERE c.TABLE_NAME = PARSENAME(@SourceTable, 1)  
                AND c.COLUMN_NAME=@ColumnName)  
      BEGIN  
       IF ISNULL(@SQL,'') = ''  
       BEGIN  
          SET @SQL = 'UPDATE TG' + CHAR(13) +   
                     ' SET TG.[' + @ColumnName + '] = ST.[' + @ColumnName + ']' + CHAR(13)       
       END  
       ELSE   
       BEGIN  
        SET @SQL = @SQL + ', TG.[' + @ColumnName + '] = ST.[' + @ColumnName + ']' + CHAR(13)      
       END  
      END   
    FETCH FROM CUR_COLUMNS INTO @ColumnName  
   END  
  
   CLOSE CUR_COLUMNS  
   DEALLOCATE CUR_COLUMNS  
  
   SET @SQL = @SQL + ' FROM ' + @TargetTable + ' TG WITH (NOLOCK) ' + CHAR(13)  
                   + ' JOIN ' + @SourceTable + ' ST WITH (NOLOCK) ON '  
   SET @FirstTime = 1  
  
   DECLARE CUR_PRIMARY_KEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT( @PrimaryKey, ',')  
  
   OPEN CUR_PRIMARY_KEY  
   FETCH NEXT FROM CUR_PRIMARY_KEY INTO @ColumnName  
  
   WHILE @@FETCH_STATUS = 0   
   BEGIN  
    IF @FirstTime = 1  
    BEGIN  
     SET @SQL = @SQL + ' ST.['+ @ColumnName + '] = TG.[' + @ColumnName + ']' + CHAR(13)   
     SET @FirstTime = 0   
    END       
    ELSE   
    BEGIN  
     SET @SQL = @SQL + ' AND ST.['+ @ColumnName + '] = TG.[' + @ColumnName + ']' + CHAR(13)   
    END    
    FETCH NEXT FROM CUR_PRIMARY_KEY INTO @ColumnName  
   END                   
END  

GO