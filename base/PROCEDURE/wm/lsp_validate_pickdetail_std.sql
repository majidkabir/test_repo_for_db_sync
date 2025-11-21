SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************ */  
/* Stored Procedure: lsp_Validate_Pickdetail_Std                          */  
/* Creation Date: 29-Mar-2018                                             */  
/* Copyright: LFL                                                         */  
/* Written by: Wan                                                        */  
/*                                                                        */  
/* Purpose:                                                               */  
/*                                                                        */  
/* Called By:                                                             */  
/*                                                                        */  
/*                                                                        */  
/* Version: 1.3                                                           */  
/*                                                                        */  
/* Data Modifications:                                                    */  
/*                                                                        */  
/* Updates:                                                               */  
/* Date         Author   Ver  Purposes                                    */ 
/* 2021-02-10   mingle01 1.1  Add Big Outer Begin try/Catch               */
/* 2023-03-14   NJOW01   1.2  LFWM-3608 performance tuning for XML Reading*/
/* 2023-07-11   Wan01    1.3  LFWM-4131 -PROD - CN Pick Management channel*/
/*                            id bug                                      */
/**************************************************************************/   
CREATE   PROCEDURE [WM].[lsp_Validate_Pickdetail_Std] (
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
   
   --(mingle01) - START
   BEGIN TRY
      /*  --NJOW01 Removed    
      IF OBJECT_ID('tempdb..#PICKDETAIL') IS NOT NULL
      BEGIN
         DROP TABLE #PICKDETAIL
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
      CREATE TABLE #PICKDETAIL( Rowid  INT NOT NULL IDENTITY(1,1) )   

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
         SET @c_SQL = N'ALTER TABLE #PICKDETAIL  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '
            
         EXEC (@c_SQL)

         SET @c_SQL = N' INSERT INTO #PICKDETAIL' --+  @c_UpdateTable 
                     + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'
                     + ' SELECT ' + SUBSTRING(@c_SQLData, 1, LEN(@c_SQLData) - 1) 
                     + ' FROM @x_XMLData.nodes(''Row'') TempXML (x) '  
            
         EXEC sp_executeSQl @c_SQL
                           , N'@x_XMLData xml'
                           , @x_XMLData
         
      END
      */

      DECLARE 
            @c_OrderKey          NVARCHAR(10) = ''
         ,  @c_Lot               NVARCHAR(10) = ''
         ,  @c_Loc               NVARCHAR(10) = ''
         ,  @c_ID                NVARCHAR(18) = ''        
         ,  @n_Qty               INT          = 0 
         
         ,  @c_OrderLineNumber   NVARCHAR(5) = ''                                   --(Wan01)
         ,  @c_Sku               NVARCHAR(20)= ''                                   --(Wan01)
         ,  @c_Sku_OD            NVARCHAR(20)= ''                                   --(Wan01)

            
      SELECT  
            @c_OrderKey  = PD.OrderKey
         ,  @c_Lot = PD.Lot
         ,  @c_Loc = PD.Loc 
         ,  @c_ID  = PD.ID
         ,  @n_Qty = PD.Qty 
         ,  @c_OrderLineNumber = PD.OrderLineNumber                                 --(Wan01)
         ,  @c_Sku = PD.Sku                                                         --(Wan01)
      FROM  #VALDN PD  --NJOW01
      
      SET @b_Success = 1
      SET @n_Err = 0 
      SET @c_Errmsg = ''
      
      IF @c_Orderkey <> '' AND @c_OrderLineNumber <> ''                             --(Wan01)
      BEGIN
         SELECT @c_Sku_OD = o.Sku FROM dbo.ORDERDETAIL AS o (NOLOCK) 
         WHERE o.OrderKey = @c_OrderKey AND o.OrderLineNumber = @c_OrderLineNumber
         
         IF @c_Sku_OD = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 561851
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6),@n_Err) + ':Order Line #: ' + @c_OrderLineNumber
                          + ' Not Found. (lsp_Validate_Pickdetail_Std) |' + @c_OrderLineNumber
            GOTO EXIT_SP
         END
         
         IF @c_Sku <> @c_Sku_OD 
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 561852
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6),@n_Err) + ':Sku: ' + @c_Sku
                          + ' not belong to Order Line #: ' + @c_OrderLineNumber
                          + '. (lsp_Validate_Pickdetail_Std) |' + @c_Sku + '|' + @c_OrderLineNumber
            GOTO EXIT_SP
         END
      END 
      
      IF @c_Lot <> '' AND @c_Loc <> '' 
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.LOTxLOCxID AS ltlci (NOLOCK) 
                        WHERE ltlci.Lot = @c_Lot
                        AND ltlci.Loc = @c_Loc
                        AND ltlci.Id = @c_ID
         )
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 561853
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6),@n_Err) + ': Invalid Inventory Found'
                          + '. Lot: ' + @c_Lot + ', Loc: ' + @c_Loc + ', ID: ' + @c_ID
                          + '. (lsp_Validate_Pickdetail_Std) |' + @c_Lot + '|' + @c_Loc + '|' + @c_ID
            GOTO EXIT_SP         
         END 
      END                                                                           --(Wan01) - END
      

      EXEC isp_ValidatePickdetail
            @c_OrderKey          = @c_OrderKey   
         ,  @c_Lot               = @c_Lot        
         ,  @c_Loc               = @c_Loc        
         ,  @c_ID                = @c_ID         
         ,  @n_Qty               = @n_Qty        
         ,  @b_ReturnCode        = @b_Success      OUTPUT  -- 0 = OK, -1 = Error, 1 = Warning 
         ,  @n_err               = @n_err          OUTPUT        
         ,  @c_errmsg            = @c_errmsg       OUTPUT      
         ,  @n_WarningNo         = @n_WarningNo    OUTPUT
         ,  @c_ProceedWithWarning= @c_ProceedWithWarning             

      IF @b_Success <> 0
      BEGIN
         SET @n_Continue = 3
         GOTO EXIT_SP
      END          
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