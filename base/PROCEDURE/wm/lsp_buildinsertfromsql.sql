SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_BuildInsertFromSQL                              */  
/* Creation Date: 2023-05-19                                             */  
/* Copyright: Maersk                                                     */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-4116 - [CN]CONVERSE_ADJ_Ã­â–’Copy value toÃ­â–‘ support all   */     
/*          details in one Adjustmentkey                                 */                                                       
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date       Author   Ver   Purposes                                    */ 
/* 2023-05-19 Wan      1.0   Created & DevOps Combine Script             */
/*************************************************************************/   
CREATE   PROCEDURE [WM].[lsp_BuildInsertFromSQL]
   @c_WhereClause       NVARCHAR(MAX)    
,  @c_TempTable         NVARCHAR(50)
,  @c_SchemaTable       NVARCHAR(50)   = ''      
,  @c_BuildFromTable    NVARCHAR(30)  
,  @c_UserName          NVARCHAR(128)  = ''    
,  @b_Success           INT            = 1   OUTPUT      
,  @n_Err               INT            = 0   OUTPUT  
,  @c_Errmsg            NVARCHAR(255)  = ''  OUTPUT  
,  @c_InsertFromSQL     NVARCHAR(MAX)  = ''  OUTPUT
AS  
BEGIN  
   SET ANSI_NULLS ON
   SET ANSI_PADDING ON
   SET ANSI_WARNINGS ON   
   SET QUOTED_IDENTIFIER ON
   SET CONCAT_NULL_YIELDS_NULL ON
   SET ARITHABORT ON

   DECLARE 
           @n_StartTCnt       INT            = @@TRANCOUNT
         , @n_Continue        INT            = 1
         
         , @c_db              NVARCHAR(10)   = ''
         , @c_ObjectName      NVARCHAR(60)   = ''         
         , @c_Columns         NVARCHAR(MAX)  = ''  
         , @c_Columns_Build   NVARCHAR(MAX)  = ''

         , @c_SQL             NVARCHAR(MAX)  = ''
         , @c_SQLParms        NVARCHAR(1000) = ''

   DECLARE @t_VARTAB AS VariableTable  
                 
   DECLARE @t_TableCol  TABLE
         ( RowID        INT            IDENTITY(1,1)
         , ColName      NVARCHAR(80)   NOT NULL DEFAULT('')
         , DataType     NVARCHAR(30)   NOT NULL DEFAULT('')
         )  
  
   SET @c_InsertFromSQL = ''

   BEGIN TRY
      SET @c_ObjectName = @c_BuildFromTable
      
      IF LEFT(LTRIM(@c_BuildFromTable),1)= '#'
      BEGIN
         SET @c_db = 'TempDb.'
         SET @c_ObjectName = @c_db + '.' + @c_ObjectName
      END 
 
      SET @c_SQL = N'SELECT c.[COLUMN_NAME] AS ''ColName'' ' 
              +', c.[DATA_TYPE] + CASE WHEN c.[DATA_TYPE] LIKE ''n%char'' THEN ''('' + CAST(c.Character_Maximum_Length AS NVARCHAR) + '')'''  
              +                      ' WHEN c.[DATA_TYPE] LIKE ''%char''  THEN ''('' + CAST(c.Character_Maximum_Length AS NVARCHAR) + '')'''
              +                      ' WHEN c.[DATA_TYPE] IN (''decimal'',''numeric'')'  
              +                      ' THEN ''(''+ CAST(c.Numeric_Precision AS NVARCHAR) + '','' + CAST(c.Numeric_Scale AS NVARCHAR) + '')'''
              +                      ' ELSE '''''  
              +                      ' END'  
              +' AS ''DataType'''
              +' FROM ' + @c_db + 'INFORMATION_SCHEMA.COLUMNS c '  
              +' JOIN ' + @c_db + 'dbo.SysObjects AS s ON s.[name] = c.TABLE_NAME'     -- Use SysObjects to get unique temp table name  
              +' WHERE s.id = OBJECT_ID(''' + @c_ObjectName + ''')'                     
              +' AND   c.[DATA_TYPE] <> ''TimeStamp'' '  
              +' ORDER BY c.ordinal_position'  
      INSERT INTO @t_TableCol (ColName, DataType) 
      EXEC sp_ExecuteSQL @c_SQL
      
      IF @@ROWCOUNT = 0
      BEGIN
         SET @n_Continue = 3
      END
            
      IF @n_Continue IN (1,2)
      BEGIN
         SELECT @c_Columns_Build = STRING_AGG( CONVERT(NVARCHAR(MAX),ttc.ColName + ' ' + ttc.DataType + ' NULL')
                                 , ',' )
               WITHIN GROUP (ORDER BY ttc.RowID ASC)
         FROM @t_TableCol AS ttc
         
         IF @c_Columns_Build = ''
         BEGIN
            SET @n_Continue = 3
         END
      END
      
      IF @n_Continue IN (1,2)
      BEGIN
         SET @c_SQL = N'ALTER TABLE ' + @c_TempTable + ' ADD ' + @c_Columns_Build
            
         EXEC sp_ExecuteSQL @c_SQL
         
         SELECT @c_Columns = STRING_AGG ( CONVERT(NVARCHAR(MAX),ttc.ColName), ',' )
         WITHIN GROUP (ORDER BY ttc.RowID ASC)
         FROM @t_TableCol AS ttc
  
         IF @c_Columns = '' --OR @c_Columns_Data = ''
         BEGIN
            SET @n_Continue = 3
         END   
      END  

      IF @n_Continue = 1 AND @c_SchemaTable <> ''
      BEGIN
         INSERT INTO @t_VARTAB (Variable, [Value])
         SELECT ttc.ColName, ttc.DataType FROM @t_TableCol AS ttc
         ORDER BY ttc.RowID

         SET @c_SQL = N'INSERT INTO ' + @c_SchemaTable + '(Column_Name, Data_Type)'
                    + ' SELECT ttc.Variable, ttc.Value'
                    + ' FROM @t_VARTAB AS ttc'        
         SET @c_SQLParms = N'@t_VARTAB  VARIABLETABLE READONLY'

         EXEC sp_ExecuteSQL @c_SQL
                         ,  @c_SQLParms
                         ,  @t_VARTAB 
                         
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
         END                                       
      END
      
      IF @n_Continue IN (1,2)
      BEGIN     
         SET @c_InsertFromSQL = N'INSERT INTO ' + @c_TempTable + '(' + @c_Columns + ')'
                              + ' SELECT ' + @c_Columns
                              + ' FROM ' + @c_BuildFromTable 
                              + CASE WHEN @c_WhereClause = '' THEN ''
                                     ELSE ' WHERE ' + @c_WhereClause
                                     END
      END
      
   END TRY
   BEGIN CATCH
      SET @n_continue = 3 
      SET @c_errmsg = ERROR_MESSAGE()
      GOTO EXIT_SP      
   END CATCH 
        
   EXIT_SP:  

   IF (XACT_STATE()) = -1  
   BEGIN
      SET @n_Continue = 3 
      ROLLBACK TRAN
   END  
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @c_InsertFromSQL = ''
      SET @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, '[lsp_BuildInsertFromSQL]'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

END

GO