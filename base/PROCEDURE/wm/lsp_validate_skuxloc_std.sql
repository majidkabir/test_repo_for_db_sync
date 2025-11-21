SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_Validate_SkuxLoc_Std                            */  
/* Creation Date: 30-JUL-2018                                            */  
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
/* Date        Author   Ver   Purposes                                   */ 
/* 2021-02-10  mingle01 1.1   Add Big Outer Begin try/Catch              */
/* 2022-01-25  Wan01    1.2   LFWM-3297 - [VN] - SCE UAT - Assign Pick   */
/*                            Location - Single Pick Face Per SKU        */
/*                            Validation Failed                          */
/* 2022-01-25  Wan01    1.2   DevOps Combine Script                      */
/* 2023-03-14  NJOW01   1.3  LFWM-3608 performance tuning for XML Reading*/
/*************************************************************************/   
CREATE   PROC [WM].[lsp_Validate_SkuxLoc_Std] (
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
      @x_XMLSchema            XML
   ,  @x_XMLData              XML 
   ,  @c_TableColumns         NVARCHAR(MAX) = N''
   ,  @c_ColumnName           NVARCHAR(128) = N''
   ,  @c_DataType             NVARCHAR(128) = N''
   ,  @c_TableName            NVARCHAR(30)  = N''
   ,  @c_SQL                  NVARCHAR(MAX) = N''
   ,  @c_SQLSchema            NVARCHAR(MAX) = N''
   ,  @c_SQLData              NVARCHAR(MAX) = N''   
   ,  @n_Continue             INT = 1 
   ,  @n_Count                INT = 1   
   ,  @c_SinglePickFacePerSKU NVARCHAR(10) = '' --(Wan01)
   ,  @n_XMLHandle         INT                  --NJOW01
   ,  @c_SQLSchema_OXML    NVARCHAR(MAX) = N''  --NJOW01
   ,  @c_TableColumns_OXML NVARCHAR(MAX) = N''  --NJOW01
   
   --(mingle01) - START
   BEGIN TRY
      /*  --NJOW01 Removed    
      IF OBJECT_ID('tempdb..#SKUxLOC') IS NOT NULL
      BEGIN
         DROP TABLE #SKUxLOC
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
         
            INSERT_REC:
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
            
            IF ISNULL(@c_XMLDataString_Prev,'') <> ''
            BEGIN
               SET @c_XMLDataString = @c_XMLDataString_Prev
               SET @c_XMLDataString_Prev = ''
               GOTO INSERT_REC
            END              
         END
      END
      --NJOW01 E      
      
      /*
      CREATE TABLE #SKUxLOC( Rowid  INT NOT NULL IDENTITY(1,1) )   

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
         SET @c_SQL = N'ALTER TABLE #SKUxLOC  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '
            
         EXEC (@c_SQL)

         INSERT_REC:
         SET @c_SQL = N' INSERT INTO #SKUxLOC' --+  @c_UpdateTable 
                     + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'
                     + ' SELECT ' + SUBSTRING(@c_SQLData, 1, LEN(@c_SQLData) - 1) 
                     + ' FROM @x_XMLData.nodes(''Row'') TempXML (x) '  
            
         EXEC sp_executeSQl @c_SQL
                           , N'@x_XMLData xml'
                           , @x_XMLData

         IF ISNULL(@c_XMLDataString_Prev,'') <> ''
         BEGIN
            SET @x_XMLData = CONVERT(XML, @c_XMLDataString)
            SET @c_XMLDataString_Prev = ''
            GOTO INSERT_REC
         END
      END
      */

      DECLARE 
            @c_Storerkey         NVARCHAR(15) = ''
         ,  @c_Sku               NVARCHAR(20) = ''
         ,  @c_Loc               NVARCHAR(10) = ''
         ,  @c_LocType           NVARCHAR(10) = ''
         ,  @c_LocType_SL        NVARCHAR(10) = ''
         ,  @c_LoseID            NCHAR(1)     = ''

         ,  @n_QtyOverAllocated  INT          = 0


      SELECT TOP 1 
            @c_Storerkey  = SL.Storerkey
         ,  @c_Sku        = SL.Sku
         ,  @c_Loc        = SL.Loc 
         ,  @c_LocType    = SL.LocationType
      FROM  #VALDN SL  --NJOW01
      ORDER BY RowId 

      --(Wan01) - START
      SELECT @c_SinglePickFacePerSKU = dbo.fnc_GetRight('', @c_Storerkey, '', 'SinglePickFacePerSKU')
      --(Wan01) - END
      
      SET @n_Count = 0
      SELECT @n_Count = 1
      FROM  SKU WITH (NOLOCK) 
      WHERE Storerkey = @c_Storerkey
      AND   Sku = @c_Sku

      IF @n_Count = 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 552301
         SET @c_errmsg = 'Invalid Storerkey: ' + RTRIM(@c_Storerkey)
                       + ',Sku: ' + RTRIM(@c_Sku)
                       + '. (lsp_Validate_SkuxLoc_Std)'
                       + ' |' +  RTRIM(@c_Storerkey) + '|' + RTRIM(@c_Sku)
         GOTO EXIT_SP
      END 

      SET @n_Count = 0
      SET @c_LoseID= ''
      SELECT @n_Count = 1
            ,@c_LoseID = LoseID
      FROM  LOC WITH (NOLOCK) 
      WHERE Loc = @c_Loc

      IF @n_Count = 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 552302
         SET @c_errmsg = 'Invalid Location: ' + RTRIM(@c_Loc)
                       + '. (lsp_Validate_SkuxLoc_Std)'
                       + ' |' +  RTRIM(@c_Loc)
         GOTO EXIT_SP
      END 

      IF @c_LocType IN ('CASE', 'PICK') AND @c_LoseID = '0'
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 552303
         SET @c_errmsg = 'Assign Pick/Case Location Not Allow'
                       + '. Please set Loc ' + RTRIM(@c_Loc) + ' to lose ID.'
                       + '( Record Line - Storerkey: ' + RTRIM(@c_Storerkey)
                       + ',Sku: ' + RTRIM(@c_Sku)
                       + ',Loc: ' + RTRIM(@c_Loc)
                       + '). (lsp_Validate_SkuxLoc_Std)'
                       + ' |' + RTRIM(@c_Loc) + '|' + RTRIM(@c_Storerkey) + '|' + RTRIM(@c_Sku) + '|' + RTRIM(@c_Loc)
         GOTO EXIT_SP
      END

      SET @n_Count = 0
      SELECT @n_Count = 1
      FROM  #VALDN SL  --NJOW01
      GROUP BY SL.Storerkey
            ,  SL.Sku
            ,  SL.Loc  
      HAVING COUNT(1) > 1
      
      IF @n_Count > 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 552304
         SET @c_errmsg = 'Duplicate record found for'
                       + ' Storerkey: ' + RTRIM(@c_Storerkey)
                       + ',Sku: ' + RTRIM(@c_Sku)
                       + ',Loc: ' + RTRIM(@c_Loc)
                       + '. (lsp_Validate_SkuxLoc_Std)'
                       + ' |' + RTRIM(@c_Storerkey) + '|' + RTRIM(@c_Sku) + '|' + RTRIM(@c_Loc)
         GOTO EXIT_SP
      END 

      SET @n_Count = 0
      SET @n_QtyOverAllocated = 0
      SET @c_LocType_SL = ''
      SELECT @n_Count = 1
            ,@n_QtyOverAllocated = SL.Qty - (SL.QtyAllocated + SL.QtyPicked)
            ,@c_LocType_SL = SL.LocationType 
      FROM   SKUxLOC SL(NOLOCK)
      WHERE  SL.StorerKey = @c_Storerkey
      AND    SL.SKU = @c_Sku
      AND    SL.LOC = @c_Loc
      
      IF @n_Count > 0 
      BEGIN
         IF @c_LocType NOT IN ('CASE', 'PICK') AND @c_LocType_SL IN ('CASE', 'PICK') AND 
            @n_QtyOverAllocated < 0
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 552305
            SET @c_errmsg = 'Qty over allocated in SKUxLOC. Generate/Update Assigned Location Reject.'
                          + ' Storerkey: ' + RTRIM(@c_Storerkey)
                          + ',Sku: ' + RTRIM(@c_Sku)
                          + ',Loc: ' + RTRIM(@c_Loc)
                          + '. (lsp_Validate_SkuxLoc_Std)'
                          + ' |' + RTRIM(@c_Storerkey) + '|' + RTRIM(@c_Sku) + '|' + RTRIM(@c_Loc)
            GOTO EXIT_SP         
         END

         SET @n_QtyOverAllocated = 0
         SELECT TOP 1 @n_QtyOverAllocated =  LLI.Qty - (LLI.QtyAllocated + LLI.QtyPicked) 
         FROM LOTxLOCxID LLI WITH (NOLOCK)
         WHERE  LLI.StorerKey = @c_Storerkey
         AND    LLI.SKU = @c_Sku
         AND    LLI.LOC = @c_Loc
         AND    LLI.Qty - (LLI.QtyAllocated + LLI.QtyPicked) < 0

         IF @c_LocType IN ('DYNPICKP', 'DYNPICKR') AND @c_LocType_SL IN ('CASE', 'PICK') AND 
            @n_QtyOverAllocated < 0
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 552306
            SET @c_errmsg = 'Qty over allocated in LOTxLOCxID. Generate/Update Assigned Location Reject.'
                          + ' Storerkey: ' + RTRIM(@c_Storerkey)
                          + ',Sku: ' + RTRIM(@c_Sku)
                          + ',Loc: ' + RTRIM(@c_Loc)
                          + '. (lsp_Validate_SkuxLoc_Std)'
                         + ' |' + RTRIM(@c_Storerkey) + '|' + RTRIM(@c_Sku) + '|' + RTRIM(@c_Loc)
            GOTO EXIT_SP         
         END
      END
      
      --(Wan01) - START
      IF @c_SinglePickFacePerSKU = '1'
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.SKUxLOC AS sul WITH (NOLOCK) 
                     WHERE sul.StorerKey = @c_Storerkey
                     AND sul.Sku = @c_Sku
                     AND sul.Loc <> @c_Loc
                     AND sul.LocationType IN ('PICK', 'CASE')
         )
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 552307
            SET @c_errmsg = 'Multi Pick Loc For Sku: ' + RTRIM(@c_Sku)+ ' is not allowed.'
                          + '. (lsp_Validate_SkuxLoc_Std)'
                         + ' |' + RTRIM(@c_Sku)
            GOTO EXIT_SP               
         END
         
         IF EXISTS ( SELECT 1 FROM dbo.SKUxLOC AS sul WITH (NOLOCK) 
                     WHERE sul.StorerKey = @c_Storerkey
                     AND sul.Sku <> @c_Sku
                     AND sul.Loc = @c_Loc
                     AND sul.LocationType IN ('PICK', 'CASE')
         )
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 552308
            SET @c_errmsg = 'Multi Sku For Pick Location: ' + RTRIM(@c_Loc)+ ' is not allowed.'
                          + '. (lsp_Validate_SkuxLoc_Std)'
                         + ' |' + RTRIM(@c_Loc)
            GOTO EXIT_SP               
         END
      END
      --(Wan01) - END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
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