SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/**************************************************************************/  
/* Stored Procedure: lsp_Validate_DocInfo_Std                             */  
/* Creation Date: 12-NOV-2020                                             */  
/* Copyright: LFL                                                         */  
/* Written by: Wan                                                        */  
/*                                                                        */  
/* Purpose: LFWM-2427 - DocumentInfo Presave validations Stored procedure */  
/*                                                                        */  
/* Called By:                                                             */  
/*                                                                        */  
/*                                                                        */  
/* Version: 1.0                                                           */  
/*                                                                        */  
/* Data Modifications:                                                    */  
/*                                                                        */  
/* Updates:                                                               */  
/* Date        Author   Ver   Purposes                                    */ 
/* 2020-11-12  Wan      1.0   Creation                                    */
/* 2023-03-14  NJOW01   1.3   LFWM-3608 performance tuning for XML Reading*/
/**************************************************************************/   
CREATE   PROC [WM].[lsp_Validate_DocInfo_Std] (
  @c_XMLSchemaString    NVARCHAR(MAX) 
, @c_XMLDataString      NVARCHAR(MAX) 
, @b_Success            INT OUTPUT
, @n_Err                INT OUTPUT
, @c_ErrMsg             NVARCHAR(250) OUTPUT
, @n_WarningNo          INT = 0       OUTPUT
, @c_ProceedWithWarning CHAR(1) = 'N'
, @c_IsSupervisor       CHAR(1) = 'N' 
, @c_XMLDataString_Prev NVARCHAR(MAX) = ''
) AS 
BEGIN
   SET ANSI_NULLS ON
   SET ANSI_PADDING ON
   SET ANSI_WARNINGS ON   
   SET QUOTED_IDENTIFIER ON
   SET CONCAT_NULL_YIELDS_NULL ON
   SET ARITHABORT ON
  
   DECLARE     
      @x_XMLSchema         XML
   ,  @x_XMLData           XML 
   ,  @c_TableColumns      NVARCHAR(MAX) = N''
   ,  @c_ColumnName        NVARCHAR(128) = N''
   ,  @c_DataType          NVARCHAR(128) = N''
   ,  @c_TableName         NVARCHAR(30)  = N''
   ,  @c_SQL               NVARCHAR(MAX) = N''
   ,  @c_SQLSchema         NVARCHAR(MAX) = N''
   ,  @c_SQLData           NVARCHAR(MAX) = N''   
   ,  @n_Continue          INT = 1 
   ,  @n_XMLHandle         INT                  --NJOW01
   ,  @c_SQLSchema_OXML    NVARCHAR(MAX) = N''  --NJOW01
   ,  @c_TableColumns_OXML NVARCHAR(MAX) = N''  --NJOW01

   /* --NJOW01 Removed   
   IF OBJECT_ID('tempdb..#DOCINFO') IS NOT NULL
   BEGIN
      DROP TABLE #DOCINFO 
   END
   */
   
   --NJOW01 S      
   IF OBJECT_ID('tempdb..#VALDN') IS NULL
   BEGIN
      CREATE TABLE #VALDN( Rowid  INT NOT NULL IDENTITY(1,1) )   
      
      SET @x_XMLSchema = CONVERT(XML, @c_XMLSchemaString)
      SET @x_XMLData = CONVERT(XML, @c_XMLDataString)
      
      EXEC sp_xml_preparedocument @n_XMLHandle OUTPUT, @c_XMLSchemaString      
      DECLARE CUR_SCHEMA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT ColName, DataType 
         FROM OPENXML (@n_XMLHandle, '/Table/Column',1)  
         WITH (ColName  NVARCHAR(128),  
               DataType NVARCHAR(128))
                                 
      OPEN CUR_SCHEMA
      
      FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_DataType
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_TableName = ''
         IF CHARINDEX('.', @c_ColumnName) > 0 
         BEGIN
            SET @c_TableName  = LEFT(@c_ColumnName, CHARINDEX('.', @c_ColumnName))
            SET @c_ColumnName = RIGHT(@c_ColumnName, LEN(@c_ColumnName) -LEN(@c_TableName))
         END
      
         SET @c_SQLSchema  = @c_SQLSchema + @c_ColumnName + ' ' + @c_DataType + ' NULL, '
         SET @c_SQLSchema_OXML  = @c_SQLSchema_OXML + '['+@c_TableName+@c_ColumnName + '] ' + @c_DataType + ', '
         SET @c_TableColumns = @c_TableColumns + @c_ColumnName + ', '
         SET @c_TableColumns_OXML = @c_TableColumns_OXML + '[' + @c_TableName + @c_ColumnName + '], '
            
         FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_DataType
      END
      CLOSE CUR_SCHEMA
      DEALLOCATE CUR_SCHEMA
      EXEC sp_xml_removedocument @n_XMLHandle    
                    
      IF LEN(@c_SQLSchema) > 0 
      BEGIN
         SET @c_SQL = N'ALTER TABLE #VALDN  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '
            
         EXEC (@c_SQL)
      
         EXEC sp_xml_preparedocument @n_XMLHandle OUTPUT, @c_XMLDataString
      
         SET @c_SQL = N' INSERT INTO #VALDN' 
                     + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'
                     + ' SELECT ' + SUBSTRING(@c_TableColumns_OXML, 1, LEN(@c_TableColumns_OXML) - 1)
                     + ' FROM  OPENXML (@n_XMLHandle, ''Row'',1) '
                     + ' WITH (' + SUBSTRING(@c_SQLSchema_OXML, 1, LEN(@c_SQLSchema_OXML) - 1) + ')'
                        
         EXEC sp_executeSQl @c_SQL
                           , N'@n_XMLHandle INT'
                           , @n_XMLHandle                                     
         
         EXEC sp_xml_removedocument @n_XMLHandle                         
      END
   END
   --NJOW01 E                               

   /*
   CREATE TABLE #DOCINFO( Rowid  INT NOT NULL IDENTITY(1,1) )   

   SET @x_XMLSchema = CONVERT(XML, @c_XMLSchemaString)
   SET @x_XMLData = CONVERT(XML, @c_XMLDataString)

   DECLARE CUR_SCHEMA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT x.value('@ColName', 'NVARCHAR(128)') AS columnname
         ,x.value('@DataType','NVARCHAR(128)') AS datatype
   FROM @x_XMLSchema.nodes('/Table/Column') TempXML (x)
      
   OPEN CUR_SCHEMA

   FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_DataType

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_TableName = ''
      IF CHARINDEX('.', @c_ColumnName) > 0 
      BEGIN
         SET @c_TableName  = LEFT(@c_ColumnName, CHARINDEX('.', @c_ColumnName))
         SET @c_ColumnName = RIGHT(@c_ColumnName, LEN(@c_ColumnName) -LEN(@c_TableName))
      END

      SET @c_SQLSchema  = @c_SQLSchema + @c_ColumnName + ' ' + @c_DataType + ' NULL, '
      SET @c_TableColumns = @c_TableColumns + @c_ColumnName + ', '
      SET @c_SQLData = @c_SQLData + 'x.value(''@' + @c_TableName + @c_ColumnName + ''', ''' + @c_DataType + ''') AS ['  + @c_ColumnName + '], '
         
      FETCH NEXT FROM CUR_SCHEMA INTO @c_ColumnName, @c_DataType
   END
   CLOSE CUR_SCHEMA
   DEALLOCATE CUR_SCHEMA
       
   IF LEN(@c_SQLSchema) > 0 
   BEGIN
      SET @c_SQL = N'ALTER TABLE #DOCINFO  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '
         
      EXEC (@c_SQL)

      SET @c_SQL = N' INSERT INTO #DOCINFO' --+  @c_UpdateTable 
                  + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'
                  + ' SELECT ' + SUBSTRING(@c_SQLData, 1, LEN(@c_SQLData) - 1) 
                  + ' FROM @x_XMLData.nodes(''Row'') TempXML (x) '  
         
      EXEC sp_executeSQl @c_SQL
                        , N'@x_XMLData xml'
                        , @x_XMLData
      
   END
   */

   DECLARE 
         @c_Storerkey   NVARCHAR(15) = ''
      ,  @c_Key1        NVARCHAR(20) = ''
      ,  @c_Key2        NVARCHAR(20) = ''
      ,  @c_Key3        NVARCHAR(20) = ''

   SELECT TOP 1 
         @c_TableName   = DI.TableName
      ,  @c_Storerkey   = DI.Storerkey
      ,  @c_Key1        = DI.Key1
      ,  @c_key2        = DI.Key2
      ,  @c_key3        = DI.Key3
   FROM  #VALDN DI   --NJOW01

   IF EXISTS ( SELECT 1
               FROM DOCINFO DI WITH (NOLOCK)
               WHERE DI.TableName = @c_TableName
               AND   DI.StorerKey = @c_Storerkey
               AND   DI.Key1      = @c_Key1
               AND   DI.Key2      = @c_Key2
               AND   DI.Key3      = @c_Key3
               )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 558951
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + '. Duplicate DocInfo record found.'
                    + ' (lsp_Validate_DocInfo_Std)'
      GOTO EXIT_SP
   END

   EXIT_SP:
   
   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0 
   END
   ELSE
   BEGIN
      SET @b_Success = 1   
   END
END -- Procedure

GO