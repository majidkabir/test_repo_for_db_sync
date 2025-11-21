SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: WM.lsp_CopyValue_InventoryQCDetail_Std              */  
/* Creation Date: 2023-02-30                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-4115 - [CN]CONVERSE_IQC_'Copy value to' support all     */
/*          details in one InventoryQCkey                                */                                                         
/*                                                                       */   
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.1                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date       Author Ver   Purposes                                      */ 
/* 2023-02-30 Wan    1.0   Created & DevOps Combine Script               */
/*************************************************************************/   
CREATE   PROCEDURE [WM].[lsp_CopyValue_InventoryQCDetail_Std]  
   @c_TableName            NVARCHAR(30) 
,  @c_ColumnName           NVARCHAR(50) 
,  @c_CopyFromKey1         NVARCHAR(30)    
,  @c_CopyFromKey2         NVARCHAR(30)   = ''
,  @c_CopyFromKey3         NVARCHAR(30)   = ''
,  @c_SearchSQL            NVARCHAR(MAX)  = ''
,  @b_Success              INT            = 1   OUTPUT    
,  @n_Err                  INT            = 0   OUTPUT
,  @c_Errmsg               NVARCHAR(255)  = ''  OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt             INT            = @@TRANCOUNT
         , @n_Continue              INT            = 1
         
         , @c_Storerkey             NVARCHAR(15)   = ''
         , @c_InsertFromSQL         NVARCHAR(MAX)  = ''
         , @c_InsertParms           NVARCHAR(4000) = ''
         , @c_WhereClause           NVARCHAR(MAX)  = ''
         
         , @c_UserName              NVARCHAR(128)  = SUSER_SNAME()  
         
         , @c_SQL                   NVARCHAR(4000) = ''
         , @c_SQLParms              NVARCHAR(4000) = ''
         
         , @c_CopyValue             NVARCHAR(4000) = ''
         , @b_Trafficop_NULL        BIT            = 1
         
         , @c_QCLineNo              NVARCHAR(5)    = ''
         
         
   BEGIN TRY
      SET @b_Success = 1
      SET @n_Err = 0 
      SET @c_Errmsg = ''
      
      SET @c_SQL = N'SELECT TOP 1 @c_CopyValue = ' + @c_ColumnName +
                 + ' , @c_Storerkey = iqd.Storerkey'
                 + ' FROM dbo.InventoryQCDetail AS iqd WITH (NOLOCK)'
                 + ' WHERE iqd.QC_Key = @c_CopyFromKey1'
                 + ' AND iqd.QCLineNo = @c_CopyFromKey2'
                 + ' ORDER BY iqd.QCLineNo'                 

      SET @c_SQLParms = N'@c_CopyValue    NVARCHAR(MAX)  OUTPUT'
                      + ',@c_Storerkey    NVARCHAR(15)   OUTPUT'    
                      + ',@c_CopyFromKey1 NVARCHAR(30)'
                      + ',@c_CopyFromKey2 NVARCHAR(30)'
  
      EXEC sp_ExecuteSQL @c_SQL
                        ,@c_SQLParms
                        ,@c_CopyValue     OUTPUT  
                        ,@c_Storerkey     OUTPUT                             
                        ,@c_CopyFromKey1  
                        ,@c_CopyFromKey2 

      IF OBJECT_ID('tempdb..#INPUTDATA','u') IS NOT NULL 
      BEGIN
         DROP TABLE #INPUTDATA 
      END
       
      SELECT * 
      INTO #INPUTDATA 
      FROM dbo.InventoryQCDetail AS iqd (NOLOCK) 
      WHERE iqd.QC_Key = @c_CopyFromKey1
      AND iqd.[Status] = '0'
      ORDER BY iqd.QCLineNo
      
      IF OBJECT_ID('tempdb..#VALDN','u') IS NOT NULL 
      BEGIN
         DROP TABLE #VALDN 
      END
      
      CREATE TABLE #VALDN (Rowid  INT NOT NULL IDENTITY(1,1) PRIMARY KEY)
 
      IF OBJECT_ID('tempdb..SCHEMA','u') IS NOT NULL 
      BEGIN
         DROP TABLE #SCHEMA
      END
      
      CREATE TABLE #SCHEMA (Column_Name NVARCHAR(80), Data_Type NVARCHAR(80))  
      
      EXEC [WM].[lsp_BuildInsertFromSQL]
         @c_WhereClause       = @c_WhereClause    
      ,  @c_TempTable         = '#VALDN'       
      ,  @c_SchemaTable       = '#SCHEMA'         
      ,  @c_BuildFromTable    = '#INPUTDATA' 
      ,  @c_UserName          = @c_UserName 
      ,  @b_Success           = @b_Success         OUTPUT    
      ,  @n_Err               = @n_Err             OUTPUT
      ,  @c_Errmsg            = @c_Errmsg          OUTPUT
      ,  @c_InsertFromSQL     = @c_InsertFromSQL   OUTPUT
      
      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3
         GOTO EXIT_SP
      END 
     
      IF EXISTS(  SELECT TOP 1 1
                  FROM CODELKUP CL (NOLOCK) 
                  JOIN CODELIST CLS (NOLOCK) ON CL.UDF01 = CLS.LISTNAME
                  JOIN CODELKUP CLSD (NOLOCK) ON CLS.ListName = CLSD.Listname
                  JOIN V_Extended_Validation V ON CLS.ListGroup = V.ValidateTable AND CL.Code = V.ValidationType
                  WHERE CL.ListName = 'VALDNCFG'
                  AND V.ValidationType <> V.ValidateTable
                  AND CLS.ListGroup = 'InventoryQCDetail'
                  AND CL.Storerkey = @c_Storerkey
               ) 
      BEGIN 
         EXEC sp_ExecuteSQL @c_InsertFromSQL
                           ,@c_InsertParms
                                 
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO EXIT_SP 
         END
           
         EXEC [WM].[lsp_Wrapup_Validation_Wrapper]    
            @c_Module            = 'IQC'  
         ,  @c_ControlObject     = 'WM.lsp_CopyValue_InventoryQCDetail_Std'  
         ,  @c_UpdateTable       = 'InventoryQCDetail'  
         ,  @c_XMLSchemaString   = ''   
         ,  @c_XMLDataString     = 'CUSTOM_VALIDATE'     
         ,  @b_Success           = @b_Success   OUTPUT          
         ,  @n_Err               = @n_Err       OUTPUT          
         ,  @c_Errmsg            = @c_Errmsg    OUTPUT  
         ,  @c_UserName          = @c_UserName  
           
         IF @b_Success = 0  
         BEGIN  
            SET @n_Continue = 3 
            GOTO EXIT_SP 
         END 
      END

      SET @c_WhereClause = N'QC_key = @c_Key1 AND QCLineNo = @c_Key2'
      SET @c_InsertParms = N'@c_Key1 NVARCHAR(30)'
                         + ',@c_Key2 NVARCHAR(30)'
   
      SET @c_InsertFromSQL = @c_InsertFromSQL + ' WHERE ' + @c_WhereClause                        
      
      SET @c_SQL = N'DECLARE CUR_SELECT CURSOR FAST_FORWARD READ_ONLY FOR'
                 + ' SELECT i.QCLineNo'
                 + ' FROM #INPUTDATA as i WITH (NOLOCK)'
                 + ' WHERE QC_Key = @c_CopyFromKey1'
                 + ' AND i.' + @c_ColumnName + ' NOT IN ( @c_CopyValue )'
                 + ' AND i.[Status] = ''0'''                 
                 + ' ORDER BY i.QCLineNo'                 
  
      SET @c_SQLParms = N'@c_CopyValue    NVARCHAR(MAX)' 
                      + ',@c_CopyFromKey1 NVARCHAR(30)'
  
      EXEC sp_ExecuteSQL @c_SQL
                        ,@c_SQLParms
                        ,@c_CopyValue          
                        ,@c_CopyFromKey1  
  
      OPEN CUR_SELECT
      
      FETCH NEXT FROM CUR_SELECT INTO @c_QCLineNo 
      WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1, 2)
      BEGIN
         SET @c_SQL = N'UPDATE #INPUTDATA '
                     + ' SET ' + @c_ColumnName + '= @c_CopyValue'
                     + IIF(@b_Trafficop_NULL = 0, '', ', Trafficcop = NULL')
                     + ' WHERE QC_Key = @c_CopyFromKey1'
                     + ' AND QCLineNo = @c_QCLineNo'

         SET @c_SQLParms = N'@c_CopyValue       NVARCHAR(MAX)' 
                         + ',@c_CopyFromKey1    NVARCHAR(30)'
                         + ',@c_QCLineNo        NVARCHAR(5)'
                            
         EXEC sp_ExecuteSQL @c_SQL
                           ,@c_SQLParms
                           ,@c_CopyValue          
                           ,@c_CopyFromKey1  
                           ,@c_QCLineNo
         
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
         END
                              
         IF @n_Continue IN (1,2)
         BEGIN         
            TRUNCATE TABLE #VALDN;

            EXEC sp_ExecuteSQL @c_InsertFromSQL
                              ,@c_InsertParms
                              ,@c_CopyFromKey1
                              ,@c_QCLineNo 
                                 
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
            END   
         END 
         
         IF @n_Continue IN (1,2)
         BEGIN
            EXEC [WM].[lsp_Wrapup_Validation_Wrapper]    
               @c_Module            = 'IQC'  
            ,  @c_ControlObject     = 'WM.lsp_CopyValue_InventoryQCDetail_Std'  
            ,  @c_UpdateTable       = 'InventoryQCDetail'  
            ,  @c_XMLSchemaString   = ''   
            ,  @c_XMLDataString     = 'STD_VALIDATE'     
            ,  @b_Success           = @b_Success   OUTPUT          
            ,  @n_Err               = @n_Err       OUTPUT          
            ,  @c_Errmsg            = @c_Errmsg    OUTPUT  
            ,  @c_UserName          = @c_UserName  
           
            IF @b_Success = 0  
            BEGIN  
               SET @n_Continue = 3  
            END  
         END
        
         IF @n_Continue IN (1,2)
         BEGIN
            SET @c_SQL = REPLACE(@c_SQL, '#INPUTDATA', @c_TableName)
                    
            SET @c_SQLParms = N'@c_CopyValue          NVARCHAR(MAX)' 
                            + ',@c_CopyFromKey1       NVARCHAR(30)'
                            + ',@c_QCLineNo  NVARCHAR(5)'
                       
            EXEC sp_ExecuteSQL @c_SQL
                              ,@c_SQLParms
                              ,@c_CopyValue          
                              ,@c_CopyFromKey1  
                              ,@c_QCLineNo
         END               
         FETCH NEXT FROM CUR_SELECT INTO @c_QCLineNo 
      END
      CLOSE CUR_SELECT
      DEALLOCATE CUR_SELECT
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
    
   IF OBJECT_ID('tempdb..#INPUTDATA','u') IS NOT NULL -- Clear temp table before quit
   BEGIN
      DROP TABLE #INPUTDATA 
   END 
      
   IF OBJECT_ID('tempdb..#VALDN','u') IS NOT NULL 
   BEGIN
      DROP TABLE #VALDN 
   END
         
   IF OBJECT_ID('tempdb..SCHEMA','u') IS NOT NULL 
   BEGIN
      DROP TABLE #SCHEMA
   END
        
   IF CURSOR_STATUS('GLOBAL', 'CUR_SELECT') IN (0 , 1) 
   BEGIN
      CLOSE CUR_SELECT
      DEALLOCATE CUR_SELECT
   END
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt       --Wan01
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'WM.lsp_CopyValue_InventoryQCDetail_Std'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO