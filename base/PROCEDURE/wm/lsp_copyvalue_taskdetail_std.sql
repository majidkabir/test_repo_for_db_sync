SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
                                                                                                                                                                                            
/*************************************************************************/                                                                                                                   
/* Stored Procedure: WM.lsp_CopyValue_Taskdetail_Std                     */                                                                                                                   
/* Creation Date: 2023-03-08                                             */                                                                                                                   
/* Copyright: LFL                                                        */                                                                                                                   
/* Written by:                                                           */                                                                                                                   
/*                                                                       */                                                                                                                   
/* Purpose: LFWM-3964 - CN Carter Task Copy value to support copy by     */ 
/*          conditions.                                                  */
/*                                                                       */                                                                                                                   
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
/* 2023-03-08 NJOW     1.0   Created & DevOps Combine Script             */                                                                                                                   
/*************************************************************************/                                                                                                                   
CREATE   PROCEDURE [WM].[lsp_CopyValue_Taskdetail_Std]                                                                                                                                   
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
         
         , @n_POS_From              INT            = 0
         , @n_POS_To                INT            = 0                                                                                                      
                                                       
         , @c_InsertFromSQL         NVARCHAR(MAX)  = ''
         , @c_InsertParms           NVARCHAR(4000) = ''
         , @c_WhereClause           NVARCHAR(MAX)  = '' 
                                                                                                                                               
         , @c_SQL                   NVARCHAR(MAX)  = ''                                                                                                                                       
         , @c_SQLParms              NVARCHAR(4000) = ''                                                                                                                                       
         , @c_SQL_LA                NVARCHAR(1000) = ''                                                                                                                                       
                                                                                                                                                                                              
         , @c_CopyValue             NVARCHAR(4000) = ''                                                                                                                                       
         , @b_Trafficop_NULL        BIT            = 1                                                                                                                                        
         , @c_UserName              NVARCHAR(128)  = SUSER_SNAME()                                                                                                                            
                                                                                                                                                                                              
         , @c_SPName                NVARCHAR(60)   = ''                                                                                                                                       
         , @c_UDF01                 NVARCHAR(60)   = ''                                                                                                                                       
         , @c_SourceType            NVARCHAR(20)   = 'TASKDETAIL'                                                                                                                                
         , @c_Sourcekey             NVARCHAR(15)   = ''                                                                                                                                       
                                                                                                                                                                                              
         , @c_Facility              NVARCHAR(5)    = ''                                                                                                                                       
         , @c_Storerkey             NVARCHAR(15)   = ''                                                                                                                                       
         , @c_Sku                   NVARCHAR(20)   = ''       
         , @c_Taskdetailkey         NVARCHAR(10)   = ''   
         
         , @c_SelectSQL             NVARCHAR(MAX)  = '' 
         , @c_WhereCondition        NVARCHAR(MAX)  = ''                                                                                                                                 
                                                                                                                                                                                              
         , @n_WarningNo             INT            = 0                  
                                                                                                                                                                                                                                                                                                                                                                                            
   BEGIN TRY 
                                                                                                                                                                                 
      SET @b_Success = 1                                                                                                                                                                      
      SET @n_Err = 0                                                                                                                                                                          
      SET @c_Errmsg = ''   
      
      IF @c_ColumnName IN ('Taskdetailkey')                                         --2022-05-22  
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 561701
         SET @c_Errmsg = 'NSQL' + CONVERT(CHAR(6),@n_Err) 
                       + ': Column: ' + @c_ColumnName + ' is not allow to copy'
                       + '. (lsp_CopyValue_Taskdetail_Std) |' + @c_ColumnName
         GOTO EXIT_SP              
      END                                                                                                                                                                   
                                                                                                                                                                                              
      SELECT  @c_Storerkey  = t.StorerKey                                                                                                                                                     
            , @c_SourceType = 'TASKDETAIL'            
      FROM dbo.Taskdetail AS t (NOLOCK)                                                                                                                                                          
      WHERE t.Taskdetailkey = @c_CopyFromKey1  
      
      IF OBJECT_ID('tempdb..#MASTER','u') IS NOT NULL                               --2023-05-22 - START
      BEGIN
         DROP TABLE #MASTER
      END
     
      CREATE TABLE #MASTER ( TaskDetailKey NVARCHAR(10) NOT NULL DEFAULT('') )

      SELECT @c_SearchSQL = dbo.fnc_ParseSearchSQL(@c_SearchSQL, 'SELECT TASKDETAIL.TaskDetailkey') 
      
      IF @c_SearchSQL = ''
      BEGIN
         GOTO EXIT_SP
      END                                                                              --2022-05-22
      
      INSERT INTO #MASTER ( TaskdetailKey ) 
      EXEC sp_ExecuteSQL @c_SearchSQL
                
      SET @c_SQL = N'SELECT TOP 1 @c_CopyValue = ' + @c_ColumnName +                                                                                                                          
                 + ' FROM dbo.TaskDetail as td WITH (NOLOCK)'                                                                                                                              
                 + ' WHERE td.TaskdetailKey = @c_CopyFromKey1'                                                                                                                                   
                                                                                                                                                                                              
      SET @c_SQLParms = N'@c_CopyValue    NVARCHAR(MAX)  OUTPUT'                                                                                                                              
                      + ',@c_CopyFromKey1 NVARCHAR(30)'                                                                                                                                       
                      + ',@c_CopyFromKey2 NVARCHAR(30)'                                                                                                                                       
                                                                                                                                                                                              
      EXEC sp_ExecuteSQL @c_SQL                                                                                                                                                               
                        ,@c_SQLParms                                                                                                                                                          
                        ,@c_CopyValue     OUTPUT                                                                                                                                              
                        ,@c_CopyFromKey1                                                                                                                                                      
                        ,@c_CopyFromKey2                           
                     
      SELECT * 
      INTO #INPUTDATA
      FROM TASKDETAIL WITH (NOLOCK)                                                 --2023-05-22                                  
      WHERE 1=2                                                                                                                                             
                                                                                                                                                                                              
      IF OBJECT_ID('tempdb..#VALDN','u') IS NOT NULL                                --2023-05-22 - START
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
                  AND CLS.ListGroup = 'TaskDetail'
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
            @c_Module            = 'TaskDetail'  
         ,  @c_ControlObject     = 'WM.lsp_CopyValue_Taskdetail_Std'  
         ,  @c_UpdateTable       = 'Taskdetail'  
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

      SET @c_WhereClause = N'Taskdetailkey = @c_Key1' 
      SET @c_InsertParms = N'@c_Key1 NVARCHAR(30)'

      SET @c_InsertFromSQL = @c_InsertFromSQL + ' WHERE ' + @c_WhereClause          --2023-05-22 - END                                                                                                                                                     

      SET @c_SQL = N'INSERT INTO #INPUTDATA'                      
                 + ' SELECT TOP 20000 TASKDETAIL.*'                                                                                                                                                                               
                 + ' FROM TASKDETAIL (NOLOCK)'                                                                                                                                                   
                 + ' WHERE TASKDETAIL.TaskdetailKey <> @c_CopyFromKey1'  
                 + ' AND EXISTS (SELECT 1 FROM #MASTER m '                          --2023-05-22
                 +             ' WHERE m.Taskdetailkey = TASKDETAIL.Taskdetailkey)' --2023-05-22                                                                                                                                              
                 + ' AND TASKDETAIL.Status NOT IN (''9'',''X'')'                    --2023-04-18 
                 + ' ORDER BY TASKDETAIL.Taskdetailkey'       

      SET @c_SQLParms = N'@c_CopyFromKey1 NVARCHAR(30)'  
                                                                                                                                                                             
      EXEC sp_ExecuteSQL @c_SQL                                                                                                                                                               
                        ,@c_SQLParms                                                                                                                                                          
                        ,@c_CopyFromKey1  
                                                                                                                                                                                                                                                                                                                                                                                                    
      SET @c_SQL = N'DECLARE CUR_SELECT CURSOR FAST_FORWARD READ_ONLY FOR'                                                                                                                    
                 + ' SELECT i.Taskdetailkey'                                                                                                                                              
                 + ' FROM #INPUTDATA as i WITH (NOLOCK)'                                                                                                                                      
                 + ' WHERE i.' + @c_ColumnName + ' NOT IN ( @c_CopyValue )'                                                                                                                     
                 + ' AND i.Status NOT IN (''9'',''X'')'                                    --2023-04-18                                                                                                                                                                                        
                 + ' ORDER BY i.Taskdetailkey'                                                                                                                                            
                                                                                                                                                                                              
      SET @c_SQLParms = N'@c_CopyValue    NVARCHAR(MAX)'                                                                                                                                      
                      + ',@c_CopyFromKey1 NVARCHAR(30)'                                                                                                                                       
                                                                                                                                                                                              
      EXEC sp_ExecuteSQL @c_SQL                                                                                                                                                               
                        ,@c_SQLParms                                                                                                                                                          
                        ,@c_CopyValue                                                                                                                                                         
                        ,@c_CopyFromKey1                                                                                                                                                      
                                                                                                                                                                                              
      OPEN CUR_SELECT                                                                                                                                                                         
                                                                                                                                                                                              
      FETCH NEXT FROM CUR_SELECT INTO @c_Taskdetailkey
                                                                                                                                                                                                  
      WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1, 2)                                                                                                                                    
      BEGIN                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     
         IF @n_Continue IN (1,2)                                                                                                                                                              
         BEGIN                                                                                                                                                                                
            SET @c_SQL = N'UPDATE #INPUTDATA '                                                                                                                                                
                       + ' SET ' + @c_ColumnName + '= @c_CopyValue'                                                                                                                           
                       + IIF(@b_Trafficop_NULL = 0, '', ', Trafficcop = NULL')                                                                                                                
                       + IIF(@c_SQL_LA <> '', @c_SQL_LA, '')                                                                                                                                  
                       + ' WHERE Taskdetailkey = @c_Taskdetailkey'                                                                                                                                
                                                                                                                                                                                              
            SET @c_SQLParms = N'@c_CopyValue          NVARCHAR(MAX)'                                                                                                                          
                            + ',@c_Taskdetailkey      NVARCHAR(10)'                                                                                                                           
                                                                                                                                                                                              
            EXEC sp_ExecuteSQL @c_SQL                                                                                                                                                         
                              ,@c_SQLParms                                                                                                                                                                           
                              ,@c_CopyValue                                                                                                                                                   
                              ,@c_Taskdetailkey                                                                                                                                                
         END  
                                                                                                                                                                                         
         IF @n_Continue IN (1,2)                                                                                                                                                              
         BEGIN 
            TRUNCATE TABLE #VALDN;

            EXEC sp_ExecuteSQL @c_InsertFromSQL
                              ,@c_InsertParms
                              ,@c_Taskdetailkey
                                 
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
            END 
         END
                                                                                                                                                                                                          
         IF @n_Continue IN (1,2)                                                                                                                                                              
         BEGIN                                                                                                                                                                                                      
            EXEC [WM].[lsp_Wrapup_Validation_Wrapper]    
               @c_Module            = 'TaskDetail'  
            ,  @c_ControlObject     = 'WM.lsp_CopyValue_Taskdetail_Std'  
            ,  @c_UpdateTable       = 'TASKDETAIL'  
            ,  @c_XMLSchemaString   = ''   
            ,  @c_XMLDataString     = 'STD_VALIDATE'     
            ,  @b_Success           = @b_Success   OUTPUT          
            ,  @n_Err               = @n_Err       OUTPUT          
            ,  @c_Errmsg            = @c_Errmsg    OUTPUT  
            ,  @c_UserName          = @c_UserName                                   --2023-05-22 - END 
        
            IF @b_Success = 0                                                                                                                                                                 
            BEGIN                                                                                                                                                                             
               SET @n_Continue = 3                                                                                                                                                            
            END 
         END                                                                                                                                                                                  
                                                                                                                                                                                        
         IF @n_Continue IN (1,2)                                                    --2023-04-18 - START                                                                                                                                                           
         BEGIN                                                                                                                                                                                
            SET @c_SQL = REPLACE(@c_SQL, '#INPUTDATA', @c_TableName)                                                                                                                          
                                                                                                                                                                                              
            SET @c_SQLParms = N'@c_CopyValue          NVARCHAR(MAX)'                                                                                                                          
                            + ',@c_Taskdetailkey      NVARCHAR(10)'                                                                                                                           
                                                                                                                                                                                                     
            EXEC sp_ExecuteSQL @c_SQL                                                                                                                                                         
                              ,@c_SQLParms                                                                                                                                                    
                              ,@c_CopyValue                                                                                                                                                   
                              ,@c_Taskdetailkey                                                                                                                                                
         END                                                                        --2023-04-18 - END
                                                                                                                                                                                   
         FETCH NEXT FROM CUR_SELECT INTO @c_Taskdetailkey                                                                                                                                                                                                                                                                                                                                                   
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
   
   IF OBJECT_ID('tempdb..#MASTER','u') IS NOT NULL                                  --2023-05-22 - START
   BEGIN
      DROP TABLE #MASTER 
   END
   
   IF OBJECT_ID('tempdb..#INPUTDATA','u') IS NOT NULL                               
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
   END                                                                              --2023-05-22 - END                                                                                                                                                            
                                                                                                                                                                                              
   IF CURSOR_STATUS('GLOBAL', 'CUR_SELECT') IN (0 , 1)                                                                                                                                        
   BEGIN                                                                                                                                                                                      
      CLOSE CUR_SELECT                                                                                                                                                                        
      DEALLOCATE CUR_SELECT                                                                                                                                                                   
   END                                                                                                                                                                                        
                                                                                                                                                                                              
   IF @n_Continue=3  -- Error Occured - Process And Return                                                                                                                                    
   BEGIN                                                                                                                                                                                      
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
      SET @n_WarningNo = 0                                                                                                                                                                    
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'WM.lsp_CopyValue_Taskdetail_Std'                                                                                                            
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