SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/**************************************************************************/  
/* Stored Procedure: lsp_Validate_Adjustment_Std                          */  
/* Creation Date: 30-JUL-2018                                             */  
/* Copyright: LFL                                                         */  
/* Written by: Wan                                                        */  
/*                                                                        */  
/* Purpose:                                                               */  
/*                                                                        */  
/* Called By:                                                             */  
/*                                                                        */  
/*                                                                        */  
/* Version: 1.0                                                           */  
/*                                                                        */  
/* Data Modifications:                                                    */  
/*                                                                        */  
/* Updates:                                                               */  
/* Date         Author   Ver  Purposes                                    */ 
/* 2021-02-10   mingle01 1.1  Add Big Outer Begin try/Catch               */
/* 2023-03-14   NJOW01   1.2  LFWM-3608 performance tuning for XML Reading*/
/**************************************************************************/   
CREATE   PROC [WM].[lsp_Validate_Adjustment_Std] (
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
        /* --NJOW01 Removed      
      IF OBJECT_ID('tempdb..#ADJUSTMENT') IS NOT NULL
      BEGIN
         DROP TABLE #ADJUSTMENT
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
      CREATE TABLE #ADJUSTMENT( Rowid  INT NOT NULL IDENTITY(1,1) )   

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
         SET @c_SQL = N'ALTER TABLE #ADJUSTMENT  ADD  ' + SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) + ' '
            
         EXEC (@c_SQL)

         SET @c_SQL = N' INSERT INTO #ADJUSTMENT' --+  @c_UpdateTable 
                     + ' ( ' + SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) + ' )'
                     + ' SELECT ' + SUBSTRING(@c_SQLData, 1, LEN(@c_SQLData) - 1) 
                     + ' FROM @x_XMLData.nodes(''Row'') TempXML (x) '  
            
         EXEC sp_executeSQl @c_SQL
                           , N'@x_XMLData xml'
                           , @x_XMLData
         
      END
      */

      DECLARE 
            @c_AdjustmentKey        NVARCHAR(10) = ''
         ,  @c_Facility             NVARCHAR(5)  = ''
         ,  @c_Storerkey            NVARCHAR(15) = ''
         ,  @c_finalizedflag_Ins    NVARCHAR(10) = ''
         ,  @c_finalizedflag_Del    NVARCHAR(10) = ''

         ,  @c_AdjStatusControl     NVARCHAR(30) = ''
         ,  @c_FinalizeAdjustment   NVARCHAR(30) = ''

      SELECT TOP 1 
            @c_AdjustmentKey  = ADJ.AdjustmentKey
         ,  @c_Facility   = ADJ.Facility
         ,  @c_Storerkey  = ADJ.Storerkey
         ,  @c_finalizedflag_Ins = ADJ.finalizedflag
      FROM  #VALDN ADJ  --NJOW01

      SELECT @c_finalizedflag_Del = ADJ.finalizedflag
      FROM ADJUSTMENT ADJ WITH (NOLOCK)
      WHERE ADJ.AdjustmentKey = @c_AdjustmentKey

      BEGIN TRY
         EXECUTE dbo.nspGetRight 
               @c_facility  = @c_Facility
            ,  @c_storerkey = @c_Storerkey 
            ,  @c_sku       = NULL
            ,  @c_configkey = 'AdjStatusControl'
            ,  @b_Success   = @b_Success           OUTPUT
            ,  @c_authority = @c_AdjStatusControl  OUTPUT
            ,  @n_err       = @n_err               OUTPUT
            ,  @c_errmsg    = @c_errmsg            OUTPUT 
      END TRY

      BEGIN CATCH
         SET @n_err = 551951
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing nspGetRight - AdjStatusControl'
                        + '. (lsp_Validate_Adjustment_Std)'
      END CATCH

      IF @b_success = 0 OR @n_Err <> 0        
      BEGIN        
         SET @n_continue = 3      
         GOTO EXIT_SP
      END 

      SET @c_FinalizeAdjustment = '0'
      SELECT @c_FinalizeAdjustment = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'FinalizeAdjustment')

      IF @c_AdjStatusControl = '1' AND @c_FinalizeAdjustment = '0'
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 551952
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Storer Config FinalizeAdjustment is required to turn on when AdjStatusControl is turn on'
                        + '. (lsp_Validate_Adjustment_Std)'
         GOTO EXIT_SP
      END
      
      IF @c_finalizedflag_Ins = ''
      BEGIN
         SET @c_finalizedflag_Ins = 'N'
      END

      IF @c_finalizedflag_Del = ''
      BEGIN
         SET @c_finalizedflag_Del = 'N'
      END

      IF @c_finalizedflag_Ins = @c_finalizedflag_Del
      BEGIN
         GOTO EXIT_SP
      END

      IF @c_AdjStatusControl = '0'
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 551953
         SET @c_errmsg = 'Disallow to change Finalize Status. (lsp_Validate_Adjustment_Std)'
         GOTO EXIT_SP
      END

      IF @c_AdjStatusControl = '1'
      BEGIN
         IF @c_IsSupervisor <> 'Y'
         BEGIN
            IF @c_finalizedflag_Del IN ('A', 'R')
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 551954
               SET @c_errmsg = 'User is disallow to reverse an approved/rejected document. (lsp_Validate_Adjustment_Std)'
               GOTO EXIT_SP
            END   
            
            IF @c_finalizedflag_Ins IN ('A', 'R')
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 551955
               SET @c_errmsg = 'Only Supervisor can Approve/Reject document. (lsp_Validate_Adjustment_Std)'
               GOTO EXIT_SP
            END

            IF @c_finalizedflag_Ins = 'N' AND @c_finalizedflag_Ins = 'S' 
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 551956
               SET @c_errmsg = 'User is disallow to reverse submitted document to open. (lsp_Validate_Adjustment_Std)'
               GOTO EXIT_SP
            END                          
         END
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