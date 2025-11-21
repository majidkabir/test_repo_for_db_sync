SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_Validate_Loc_Std                                */  
/* Creation Date: 20-OCT-2020                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose:                                                              */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver  Purposes                                    */ 
/* 12-OCT-2020 Wan      1.0  Created                                     */
/* 2021-02-25  Wan01    1.1  Add Big Outer Try/Catch                     */         
/* 2023-03-14  NJOW01   1.2  LFWM-3608 performance tuning for XML Reading*/
/*************************************************************************/   
CREATE   PROC [WM].[lsp_Validate_Loc_Std] (
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

   --(Wan01) - START
   BEGIN TRY
      /*  --NJOW01 Removed    
      IF OBJECT_ID('tempdb..#LOC') IS NOT NULL
      BEGIN
         DROP TABLE #LOC 
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
      CREATE TABLE #LOC( Rowid  INT NOT NULL IDENTITY(1,1) )   

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
         SET @c_SQL = N'ALTER TABLE #LOC  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '
         
         EXEC (@c_SQL)

         SET @c_SQL = N' INSERT INTO #LOC' --+  @c_UpdateTable 
                     + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'
                     + ' SELECT ' + SUBSTRING(@c_SQLData, 1, LEN(@c_SQLData) - 1) 
                     + ' FROM @x_XMLData.nodes(''Row'') TempXML (x) '  
         
         EXEC sp_executeSQl @c_SQL
                           , N'@x_XMLData xml'
                           , @x_XMLData
      END
      */

      DECLARE 
            @c_Loc                  NVARCHAR(10) = ''
         ,  @c_Facility             NVARCHAR(5)  = ''
         ,  @c_LocAisle             NVARCHAR(10) = ''
         ,  @c_LocLevel             INT = 0
         ,  @c_PutawayZone          NVARCHAR(10) = ''
         ,  @c_HostWHCode           NVARCHAR(10) = ''
         ,  @c_Facility_DB          NVARCHAR(5)  = ''
         ,  @c_LocAisle_DB          NVARCHAR(10) = ''
         ,  @c_LocLevel_DB          INT = 0
         ,  @c_PutawayZone_DB       NVARCHAR(10) = ''
         ,  @c_HostWHCode_DB        NVARCHAR(10) = ''
         ,  @c_CCKey                NVARCHAR(10) = ''

      SELECT TOP 1 
            @c_Loc         = L.Loc
         ,  @c_Facility    = L.Facility
         ,  @c_LocAisle    = ISNULL(L.LocAisle,'')
         ,  @c_LocLevel    = L.LocLevel
         ,  @c_PutawayZone = L.PutawayZone
         ,  @c_HostWHCode  = ISNULL(L.HostWHCode,'')
      FROM  #VALDN L  --NJOW01
   
      SET @c_CCKey = ''
      SELECT @c_CCKey = CCD.CCKey 
      FROM CCDETAIL CCD WITH (NOLOCK) 
      WHERE CCD.Loc = @c_Loc
      AND CCD.FinalizeFlag = 'N'
      AND CCD.FinalizeFlag_Cnt2 = 'N'
      AND CCD.FinalizeFlag_Cnt3 = 'N'

      IF @c_CCKey <> ''
      BEGIN
         SELECT @c_Facility_DB   = L.Facility
            ,  @c_LocAisle_DB    = ISNULL(L.LocAisle,'')
            ,  @c_LocLevel_DB    = L.LocLevel
            ,  @c_PutawayZone_DB = L.PutawayZone
            ,  @c_HostWHCode_DB  = ISNULL(L.HostWHCode,'')
         FROM LOC L WITH (NOLOCK)
         WHERE L.Loc = @c_Loc  

         IF @c_Facility <> @c_Facility_DB OR @c_LocAisle <> @c_LocAisle_DB OR 
            @c_LocLevel <> @c_LocLevel_DB OR @c_PutawayZone_DB <> @c_PutawayZone OR @c_HostWHCode_DB <> @c_HostWHCode
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 558701
            SET @c_errmsg = 'Location is involved in Cycle Count Reference #: ' + @c_CCKey
                          + '. (lsp_Validate_Loc_Std) |' + @c_CCKey
            GOTO EXIT_SP
         END
      END
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(Wan01) - END
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