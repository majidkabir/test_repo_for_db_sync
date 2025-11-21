SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/****** Object:  StoredProcedure [dbo].[isp_ExcelLoader_LoadSTGTable]    Script Date: 10/11/2019 2:38:35 PM ******/  
CREATE PROC [dbo].[isp_ExcelLoader_LoadSTGTable] (    
  @json           NVARCHAR(MAX) = ''  
, @c_TableName      NVARCHAR(255) = ''  
, @SQL            NVARCHAR(MAX) = '' OUTPUT  
) AS   
BEGIN    
   DECLARE  @SQL1 NVARCHAR(MAX)  
  
   SET @SQL = ''  
   SET @SQL1 = ''  
  
   DECLARE @FirstRow NVARCHAR(MAX)=(SELECT TOP 1 Value FROM OPENJSON(@json,'$.MainData.Data'))  
  
   DECLARE @Columns TABLE (  
       Position INT IDENTITY PRIMARY KEY,  
       ColumnName sysname NOT NULL UNIQUE,  
       JSONDataType INT NULL,  
       SQLDataType VARCHAR(30) NULL  
   )  
  
   DECLARE @DbColumns TABLE(  
      ColumnName  NVARCHAR(255),  
      DataType    NVARCHAR(255),  
      [MaxLength] INT,  
      IsNullable  BIT  
   )  
  
   INSERT INTO @DbColumns (ColumnName,DataType,[MaxLength],IsNullable)  
  ( SELECT UPPER(c.[name]) 'Column Name'  
         , UPPER(t.[Name]) 'Data type'  
         , CASE WHEN t.[Name] = 'nvarchar' THEN IIF(c.max_length = -1, c.max_length, (c.max_length / 2))   
                WHEN t.[Name] IN('VARCHAR', 'CHAR', 'NTEXT', 'NCHAR') THEN c.max_length ELSE 0 END 'MaxLength'   
         , c.is_nullable  
   FROM sys.columns c   
   INNER JOIN sys.types t ON c.user_type_id = t.user_type_id   
   WHERE c.object_id = OBJECT_ID(@c_TableName))  
  
   --INSERT INTO @Columns (ColumnName, JSONDataType, SQLDataType)  
   --SELECT [Key], Type,   
   --    CASE Type   
   --        WHEN 1 THEN 'nvarchar(1000)'  
   --        WHEN 2 THEN 'float'  
   --        WHEN 3 THEN 'bit'  
   --    END  
   --FROM OPENJSON(@FirstRow)  
  
   --SET @SQL='('+(  
   --    SELECT CHAR(13)+CHAR(10)+CHAR(9)+'['+c.ColumnName+'] ' + c.SQLDataType--+dbC.DataType   
   --    --+ CASE WHEN dbC.[MaxLength] <> 0 THEN '(' + CAST(dbC.[MaxLength] AS NVARCHAR(20)) + ')' ELSE '' END  
   --    + CASE WHEN c.Position<COUNT(1) OVER () THEN ',' ELSE '' END  
   --    FROM @Columns c  
   --    --JOIN @DbColumns dbC  
   --    --ON RTRIM(c.ColumnName) = RTRIM(dbC.ColumnName)  
   --    ORDER BY c.Position  
   --    FOR XML PATH(''), TYPE  
   --).value('.','nvarchar(max)')  
   --+CHAR(13)+CHAR(10)+')'  

   INSERT INTO @Columns (ColumnName, JSONDataType, SQLDataType)  
   SELECT [Key], Type,   
       CASE Type   
           WHEN 0 THEN 'NULL'  
           WHEN 1 THEN 'nvarchar(1000)'  
           WHEN 2 THEN 'float'  
           WHEN 3 THEN 'bit'  
       END  
   FROM OPENJSON(@FirstRow)  
  
   SET @SQL='('+(  
       SELECT CHAR(13)+CHAR(10)+CHAR(9)+'['+c.ColumnName+'] ' + CASE 
               WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'char'     THEN ' CHAR('+CAST(sysC.max_length AS NVARCHAR(5) )+')'
               WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'nchar'    THEN ' NCHAR('+CAST(sysC.max_length AS NVARCHAR(5) )+')' 
               WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'varchar'  THEN ' VARCHAR('+CAST(sysC.max_length AS NVARCHAR(5) )+')' 
               WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'nvarchar' THEN ' NVARCHAR('+CAST(sysC.max_length/2 AS NVARCHAR(5) )+')' 
               --WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'uniqueidentifier' THEN ' CONVERT(UNIQUEIDENTIFIER, ' + c.ColumnName + ')' 
               --WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'text'     THEN ' TEXT = ''''' 
               --WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'ntext'    THEN ' NTEXT = ''''' 
               WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'binary'   THEN ' BINARY('+CAST(sysC.max_length AS NVARCHAR(5) )+')' 
               WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'varbinary'THEN ' VARBINARY('+CAST(sysC.max_length AS NVARCHAR(5) )+')' 
               WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'decimal'THEN ' DECIMAL('+CAST(sysC.precision AS NVARCHAR(5) )+',' + CAST(sysC.scale AS NVARCHAR(5) ) + ')' 
               WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'numeric'THEN ' NUMERIC('+CAST(sysC.precision AS NVARCHAR(5) )+',' + CAST(sysC.scale AS NVARCHAR(5) ) + ')' 
               --WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'image'    THEN ' IMAGE = ''''' 
               --WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'datetime' THEN ' DATETIME' 
               --WHEN ISNULL(RTRIM(LOWER(t.[name])),'') = 'date'     THEN ' DATE' 
               ELSE ' ' + UPPER(t.[name])
               END--+dbC.DataType   
       --+ CASE WHEN dbC.[MaxLength] <> 0 THEN '(' + CAST(dbC.[MaxLength] AS NVARCHAR(20)) + ')' ELSE '' END  
        + CASE WHEN c.Position=MAX(c.Position) OVER () THEN '' ELSE ',' END  
       FROM @Columns c  
       INNER JOIN sys.columns sysC WITH (NOLOCK) ON c.ColumnName = sysC.[name] 
       INNER JOIN sys.types t WITH (NOLOCK) ON sysC.user_type_id = t.user_type_id   
      WHERE sysC.object_id = OBJECT_ID(@c_TableName)
       --JOIN @DbColumns dbC  
       --ON RTRIM(c.ColumnName) = RTRIM(dbC.ColumnName)  
       ORDER BY c.Position 
       FOR XML PATH(''), TYPE  
   ).value('.','nvarchar(max)')  
   +CHAR(13)+CHAR(10)+')'  
  
   SET @SQL1='('+(  
       SELECT CHAR(13)+CHAR(10)+CHAR(9)+'['+c.ColumnName+']' + CASE WHEN c.Position=MAX(c.Position) OVER () THEN '' ELSE ',' END  
       FROM @Columns c  
       JOIN @DbColumns dbC  
       ON RTRIM(c.ColumnName) = RTRIM(dbC.ColumnName)  
       ORDER BY c.Position  
       FOR XML PATH(''), TYPE  
   ).value('.','nvarchar(max)')  
   +CHAR(13)+CHAR(10)+')'  
  
   SET @SQL='INSERT INTO '+@c_TableName+ ' ' +@SQL1+CHAR(13)+CHAR(10)  
   +'SELECT * FROM OPENJSON(@json,''$.MainData.Data'') WITH'+@SQL  
  
END  

GO