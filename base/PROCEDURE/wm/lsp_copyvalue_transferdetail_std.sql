SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
                                                                                                                                                                                         
/*************************************************************************/                                                                                                                   
/* Stored Procedure: WM.lsp_CopyValue_Transferdetail_Std                 */                                                                                                                   
/* Creation Date: 2023-03-08                                             */                                                                                                                   
/* Copyright: LFL                                                        */                                                                                                                   
/* Written by:                                                           */                                                                                                                   
/*                                                                       */                                                                                                                   
/* Purpose: LFWM-3608 - [CN]NIKE_TRANSFER_Copy value to                  */                                                                                                                   
/*          support all details in one transfer                          */                                                                                                                   
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
CREATE   PROCEDURE [WM].[lsp_CopyValue_Transferdetail_Std]                                                                                                                                   
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
         
         , @c_InsertFromSQL         NVARCHAR(MAX)  = ''                              
         , @c_InsertParms           NVARCHAR(4000) = ''                             
         , @c_WhereClause           NVARCHAR(MAX)  = ''                                                                                                                                 
                                                                                                                                                                                
         , @c_SQL                   NVARCHAR(4000) = ''                                                                                                                         
         , @c_SQLParms              NVARCHAR(4000) = ''                                                                                                                         
         , @c_SQL_LA                NVARCHAR(1000) = ''                                                                                                                         
                                                                                                                                                                                
         , @c_CopyValue             NVARCHAR(4000) = ''                                                                                                                         
         , @b_Trafficop_NULL        BIT            = 1 
         , @c_TrafficCop            NVARCHAR(1)    = 'S'                                                                                                                                                                  
         , @c_UserName              NVARCHAR(128)  = SUSER_SNAME()                                                                                                                            
                                                                                                                                                                                              
         , @c_SPName                NVARCHAR(60)   = ''                                                                                                                                       
         , @c_UDF01                 NVARCHAR(60)   = ''                                                                                                                                       
         , @c_SourceType            NVARCHAR(20)   = 'TRANSFER'                                                                                                                                
         , @c_Sourcekey             NVARCHAR(15)   = ''                                                                                                                                       
         , @c_TransferLineNumber    NVARCHAR(5)    = ''                                                                                                                                       
                                                                                                                                                                                              
         , @c_Facility              NVARCHAR(5)    = ''                                                                                                                                       
         , @c_Storerkey             NVARCHAR(15)   = '' 
         , @c_FromLot               NVARCHAR(10)  = ''                                                                                                                                                                      
         , @c_Sku                   NVARCHAR(20)   = ''                                                                                                                                       
                                                                                                                                                                                              
         , @c_ToLottableLabel       NVARCHAR(20)   = ''                                                                                                                                       
         , @c_ToLottable01Value     NVARCHAR(18)   = ''                                                                                                                                       
         , @c_ToLottable02Value     NVARCHAR(18)   = ''                                                                                                                                       
         , @c_ToLottable03Value     NVARCHAR(18)   = ''                                                                                                                                       
         , @dt_ToLottable04Value    DATETIME                                                                                                                                                  
         , @dt_ToLottable05Value    DATETIME                                                                                                                                                  
         , @c_ToLottable06Value     NVARCHAR(30)   = ''                                                                                                                                       
         , @c_ToLottable07Value     NVARCHAR(30)   = ''                                                                                                                                       
         , @c_ToLottable08Value     NVARCHAR(30)   = ''                                                                                                                                       
         , @c_ToLottable09Value     NVARCHAR(30)   = ''                                                                                                                                       
         , @c_ToLottable10Value     NVARCHAR(30)   = ''                                                                                                                                       
         , @c_ToLottable11Value     NVARCHAR(30)   = ''                                                                                                                                       
         , @c_ToLottable12Value     NVARCHAR(30)   = ''                                                                                                                                       
         , @dt_ToLottable13Value    DATETIME                                                                                                                                                  
         , @dt_ToLottable14Value    DATETIME                                                                                                                                                  
         , @dt_ToLottable15Value    DATETIME                                                                                                                                                  
                                                                                                                                                                                            
         , @c_ToLottable01          NVARCHAR(18)   = ''                                                                                                                                       
         , @c_ToLottable02          NVARCHAR(18)   = ''                                                                                                                                       
         , @c_ToLottable03          NVARCHAR(18)   = ''                                                                                                                                       
         , @dt_ToLottable04         DATETIME                                                                                                                                                  
         , @dt_ToLottable05         DATETIME                                                                                                                                                  
         , @c_ToLottable06          NVARCHAR(30)   = ''                                                                                                                                       
         , @c_ToLottable07          NVARCHAR(30)   = ''                                                                                                                                       
         , @c_ToLottable08          NVARCHAR(30)   = ''                                                                                                                                       
         , @c_ToLottable09          NVARCHAR(30)   = ''                                                                                                                                       
         , @c_ToLottable10          NVARCHAR(30)   = ''                                                                                                                                       
         , @c_ToLottable11          NVARCHAR(30)   = ''                                                                                                                                       
         , @c_ToLottable12          NVARCHAR(30)   = ''                                                                                                                                       
         , @dt_ToLottable13         DATETIME                                                                                                                                                  
         , @dt_ToLottable14         DATETIME                                                                                                                                                  
         , @dt_ToLottable15         DATETIME                                                                                                                                                  
         , @n_WarningNo             INT            = 0  
         
         , @c_ListName              NVARCHAR(10)   = ''                                                                                                                                               
                                                                                                                                                                                              
         , @c_ValidateLotLabelExist NVARCHAR(10)   = ''                                                                                                                                       
         
   BEGIN TRY                                                                                                                                                                                  
      SET @b_Success = 1                                                                                                                                                                      
      SET @n_Err = 0                                                                                                                                                                          
      SET @c_Errmsg = ''    
      
      IF @c_ColumnName IN ('ToLot') OR                                              
         @c_ColumnName LIKE 'lottable%' OR
         (@c_ColumnName LIKE 'From%' AND @c_ColumnName NOT IN ('FromChannel'))
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 561501
         SET @c_Errmsg = 'NSQL' + CONVERT(CHAR(6),@n_Err) 
                       + ': Column: ' + @c_ColumnName + ' is not allow to copy'
                       + '. (lsp_CopyValue_Transferdetail_Std) |' + @c_ColumnName
         GOTO EXIT_SP              
      END                                                                                                                                                                          
                                                                                                                                                                             
      SELECT  @c_Facility   = t.Facility                                                                                                                                                      
            , @c_Storerkey  = t.FromStorerKey                                                                                                                                                     
            , @c_SourceType = 'TRANSFER'            
      FROM dbo.Transfer AS t (NOLOCK)                                                                                                                                                          
      WHERE Transferkey = @c_CopyFromKey1                                                                                                                                                      
                                                                                                                                                                                              
      SET @c_SQL = N'SELECT TOP 1 @c_CopyValue = ' + @c_ColumnName +                                                                                                                          
                 + ' FROM dbo.TransferDetail as td WITH (NOLOCK)'                                                                                                                              
                 + ' WHERE td.TransferKey = @c_CopyFromKey1'                                                                                                                                   
                 + ' AND td.TransferLineNumber = @c_CopyFromKey2'                                                                                                                              
                 + ' ORDER BY td.TransferLineNumber'                                                                                                                                                             
                                                                                                                                                                                              
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
      FROM dbo.TransferDETAIL AS td (NOLOCK)                                                                                                                                                    
      WHERE td.TransferKey = @c_CopyFromKey1                                                                                                                                                    
      AND td.TransferLineNumber <> @c_CopyFromKey2                                                                                                                                              
      AND td.Status <> '9'                                                                                                                                                               
      ORDER BY td.TransferLineNumber  
                                                                                                                                                                
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
                  AND CLS.ListGroup = 'TransferDetail'
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
            @c_Module            = 'Transfer'  
         ,  @c_ControlObject     = 'WM.lsp_CopyValue_Transferdetail_Std'  
         ,  @c_UpdateTable       = 'TransferDetail'  
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

      SET @c_WhereClause = N'TransferKey = @c_Key1 AND TransferLineNumber = @c_Key2'
      SET @c_InsertParms = N'@c_Key1 NVARCHAR(30)'
                         + ',@c_Key2 NVARCHAR(30)'                                  
   
      SET @c_InsertFromSQL = @c_InsertFromSQL + ' WHERE ' + @c_WhereClause                            
                                                                                                                                                                               
      SET @c_SQL = N'DECLARE CUR_SELECT CURSOR FAST_FORWARD READ_ONLY FOR'                                                                                               
                 + ' SELECT i.TransferLineNumber'  
                 + ' , i.FromLot'                                                                                                                                                                                                    
                 + ' , i.ToStorerkey'                                                                                                                                                                                                      
                 + ' , i.ToSku'                                                     
                 + ' , Tolottablelabel=' + CASE WHEN @c_ColumnName LIKE 'ToLottable%'    
                                                THEN 's.' + RIGHT(RTRIM(@c_ColumnName),LEN(@c_ColumnName)-2) + 'Label'
                                                ELSE '''''' END                                                                                     --                                                                                                                                           
                 + ' FROM #INPUTDATA as i WITH (NOLOCK)'
                 + ' JOIN dbo.SKU as s WITH (NOLOCK) ON s.Storerkey = i.ToStorerkey AND s.Sku = i.ToSku' --2023-05-25                                                                                                                                      
                 + ' WHERE i.TransferKey = @c_CopyFromKey1'                                                                                                                                    
                 + ' AND i.' + @c_ColumnName + ' NOT IN ( @c_CopyValue )'                                                                                                                     
                 + ' AND i.Status <> ''9'''                                                                                                                                             
                 + ' ORDER BY i.TransferLineNumber'                                                                                                                                            
                                                                                                                                                                                              
      SET @c_SQLParms = N'@c_CopyValue    NVARCHAR(MAX)'                                                                                                                                      
                      + ',@c_CopyFromKey1 NVARCHAR(30)'                                                                                                                                       
                                                                                                                                                                                              
      EXEC sp_ExecuteSQL @c_SQL                                                                                                                                                               
                        ,@c_SQLParms                                                                                                                                                          
                        ,@c_CopyValue                                                                                                                                                         
                        ,@c_CopyFromKey1                                                                                                                                                      
                                                                                                                                                                                              
      OPEN CUR_SELECT                                                                                                                                                                         
                                                                                                                                                                                              
      FETCH NEXT FROM CUR_SELECT INTO                                                                                                                                                         
            @c_TransferLineNumber, @c_FromLot, @c_Storerkey, @c_Sku, @c_ToLottableLabel                                                                                                                                                   
                                                                                                                                                                                              
      WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1, 2)                                                                                                                                    
      BEGIN 
         IF @c_ColumnName LIKE 'Lottable%' AND @c_FromLot <> ''                     
         BEGIN
            GOTO NEXT_REC
         END                                                                                                                                    
                                                                                                                                                                                                                             
         IF @c_ColumnName LIKE 'ToLottable%' AND @c_ToLottableLabel <> ''                                                                                                                                            
         BEGIN                                                                                                                                                                                
            SET @c_Sourcekey = RTRIM(@c_CopyFromKey1) + LTRIM(@c_TransferLineNumber)                                                                                                           
            --call isp_GetLottablesRoles to get SP
            SET @c_ListName = SUBSTRING(@c_ColumnName,3,LEN(@c_ColumnName)-2)                                                                                                                                                    
            EXEC dbo.isp_GetLottablesRoles                                                                                                                                                    
                  @c_ListName        = @c_ListName                                                                                                                                          
                , @c_Storerkey       = @c_Storerkey                                                                                                                                            
                , @c_Sku             = @c_Sku                                                                                                                                                  
                , @c_Source          = N'TRANSFER_ITEMCHANGED'                                                                                                                                  
                , @c_SPName          = @c_SPName          OUTPUT                                                                                                                               
                , @c_LottableLabel   = @c_ToLottableLabel OUTPUT                                                                                                                                                  
                , @c_UDF01           = @c_UDF01           OUTPUT                                                                                                                               
                , @b_Success         = 1                                                                                                                                                       
                                                                                                                                                                                              
            IF EXISTS ( SELECT 1 FROM dbo.syscolumns sc                                                                                                                                       
                        JOIN dbo.sysobjects so ON  sc.id = so.id                                                                                                                              
                        WHERE so.[name] = 'Transfer'                                                                                                                                           
                        AND sc.[name] = @c_UDF01                                                                                                                                              
            )                                                                                                                                                                                 
            BEGIN                                                                                                                                                                             
               SET @c_SQL = N'SELECT @c_Sourcekey = t.' + LTRIM(RTRIM(@c_UDF01))                                                                                                              
                          + ' FROM dbo.Transfer AS t WITH (NOLOCK)'                                                                                                                            
                          + ' WHERE t.Transferkey = @c_CopyFromKey1'                                                                                                                           
               SET @c_SQLParms = N'@c_Sourcekey    NVARCHAR(15)   OUTPUT'                                                                                                                     
                               + ',@c_CopyFromKey1 NVARCHAR(30)'                                                                                                                              
                                                                                                                                                                                              
               EXEC sp_ExecuteSQL @c_SQL                                                                                                                                                      
                                 ,@c_SQLParms                                                                                                                                                 
                                 ,@c_Sourcekey     OUTPUT                                                                                                                                     
                                 ,@c_CopyFromKey1                                                                                                                                             
            END                                                                                                                                                                               
                                                                                                                                                                                              
            IF @n_Continue IN (1,2)                                                                                                                                                           
            BEGIN                                                                                                                                                                             
               IF @c_ColumnName = 'ToLottable01' SET @c_ToLottable01Value = @c_CopyValue                                                                                                          
               IF @c_ColumnName = 'ToLottable02' SET @c_ToLottable02Value = @c_CopyValue                                                                                                          
               IF @c_ColumnName = 'ToLottable03' SET @c_ToLottable03Value = @c_CopyValue                                                                                                          
               IF @c_ColumnName = 'ToLottable04' SET @dt_ToLottable04Value= @c_CopyValue                                                                                                          
               IF @c_ColumnName = 'ToLottable05' SET @dt_ToLottable05Value= @c_CopyValue                                                                                                          
               IF @c_ColumnName = 'ToLottable06' SET @c_ToLottable06Value = @c_CopyValue                                                                                                          
               IF @c_ColumnName = 'ToLottable07' SET @c_ToLottable07Value = @c_CopyValue                                                                                                          
               IF @c_ColumnName = 'ToLottable08' SET @c_ToLottable08Value = @c_CopyValue                                                                                                          
               IF @c_ColumnName = 'ToLottable09' SET @c_ToLottable09Value = @c_CopyValue                                                                                                          
               IF @c_ColumnName = 'ToLottable10' SET @c_ToLottable10Value = @c_CopyValue                                                                                                          
               IF @c_ColumnName = 'ToLottable11' SET @c_ToLottable11Value = @c_CopyValue                                                                                                          
               IF @c_ColumnName = 'ToLottable12' SET @c_ToLottable12Value = @c_CopyValue                                                                                                          
               IF @c_ColumnName = 'ToLottable13' SET @dt_ToLottable13Value= @c_CopyValue                                                                                                          
               IF @c_ColumnName = 'ToLottable14' SET @dt_ToLottable14Value= @c_CopyValue                                                                                                          
               IF @c_ColumnName = 'ToLottable15' SET @dt_ToLottable15Value= @c_CopyValue                                                                                                          
                                                                                                                                                                                              
               EXEC WM.lspLottableRule_Wrapper                                                                                                                                                
                  @c_SPName    = ''                                                                                                                                                           
               ,  @c_Listname  = @c_ListName                                                                                                                                                                       
               ,  @c_Storerkey = @c_Storerkey                                                                                                                                                 
               ,  @c_Sku       = @c_Sku                                                                                                                                                       
               ,  @c_LottableLabel    = @c_ToLottableLabel                                                                                                                                       
               ,  @c_Lottable01Value  = @c_ToLottable01Value                                                                                                                                     
               ,  @c_Lottable02Value  = @c_ToLottable02Value                                                                                                                                     
               ,  @c_Lottable03Value  = @c_ToLottable03Value                                                                                                                                     
               ,  @dt_Lottable04Value = @dt_ToLottable04Value                                                                                                                                    
               ,  @dt_Lottable05Value = @dt_ToLottable05Value                                                                                                                                    
               ,  @c_Lottable06Value  = @c_ToLottable06Value                                                                                                                                     
               ,  @c_Lottable07Value  = @c_ToLottable07Value                                                                                                                                     
               ,  @c_Lottable08Value  = @c_ToLottable08Value                                                                                                                                     
               ,  @c_Lottable09Value  = @c_ToLottable09Value                                                                                                                                     
               ,  @c_Lottable10Value  = @c_ToLottable10Value                                                                                                                                     
               ,  @c_Lottable11Value  = @c_ToLottable11Value                                                                                                                                     
               ,  @c_Lottable12Value  = @c_ToLottable12Value                                                                                                                                     
               ,  @dt_Lottable13Value = @dt_ToLottable13Value                                                                                                                                    
               ,  @dt_Lottable14Value = @dt_ToLottable14Value                                                                                                                                    
               ,  @dt_Lottable15Value = @dt_ToLottable15Value                                                                                                                                    
               ,  @c_Lottable01  = @c_ToLottable01    OUTPUT                                                                                                                                     
               ,  @c_Lottable02  = @c_ToLottable02    OUTPUT                                                                                                                                     
               ,  @c_Lottable03  = @c_ToLottable03    OUTPUT                                                                                                                                     
               ,  @dt_Lottable04 = @dt_ToLottable04   OUTPUT                                                                                                                                     
               ,  @dt_Lottable05 = @dt_ToLottable05   OUTPUT                                                                                                                                     
               ,  @c_Lottable06  = @c_ToLottable06    OUTPUT                                                                                                                                     
               ,  @c_Lottable07  = @c_ToLottable07    OUTPUT                                                                                                                                     
               ,  @c_Lottable08  = @c_ToLottable08    OUTPUT                                                                                                                                     
               ,  @c_Lottable09  = @c_ToLottable09    OUTPUT                                                                                                                                     
               ,  @c_Lottable10  = @c_ToLottable10    OUTPUT                                                                                                                                     
               ,  @c_Lottable11  = @c_ToLottable11    OUTPUT                                                                                                                                     
               ,  @c_Lottable12  = @c_ToLottable12    OUTPUT                                                                                                                                     
               ,  @dt_Lottable13 = @dt_ToLottable13  OUTPUT                                                                                                                                     
               ,  @dt_Lottable14 = @dt_ToLottable14  OUTPUT                                                                                                                                     
               ,  @dt_Lottable15 = @dt_ToLottable15  OUTPUT                                                                                                                                     
               ,  @b_Success     = @b_Success      OUTPUT                                                                                                                                     
               ,  @n_Err         = @n_Err          OUTPUT                                                                                                                                     
               ,  @c_Errmsg      = @c_Errmsg       OUTPUT                                                                                                                                     
               ,  @c_Sourcekey   = @c_Sourcekey                                                                                                                                               
               ,  @c_Sourcetype  = @c_SourceType                                                                                                                                              
               ,  @c_type        = N''                                                                                                                                                        
               ,  @c_PrePost     = N''                                                                                                                                                        
               ,  @c_UserName    = @c_UserName                                                                                                                                                
               ,  @n_WarningNo   = @n_WarningNo    OUTPUT                                                                                                                                     
               ,  @c_ProceedWithWarning = ''                                                                                                                                                  
               ,  @c_UpdateTable = N''                                                                                                                                                        
                                                                                                                                                                                              
               IF @n_Err <> 0                                                                                                                                                                 
               BEGIN                                                                                                                                                                          
                  SET @n_Continue = 3                                                                                                                                                         
               END                                                                                                                                                                            
                                                                                                                                                                                              
               IF @n_Continue IN (1,2)                                                                                                                                                        
               BEGIN                                                                                                                                                                          
                  SET @c_SQL_LA = ''                                                                                                                                                          
                  IF @c_ToLottable01 <> ''  AND @c_ColumnName <> 'ToLottable01'                                                                                                   
                     SET @c_SQL_LA = @c_SQL_LA + ', ToLottable01 = @c_ToLottable01'                                                                                                               
                  IF @c_ToLottable02 <> ''  AND @c_ColumnName <> 'ToLottable02'                                                                                                   
                     SET @c_SQL_LA = @c_SQL_LA + ', ToLottable02 = @c_ToLottable02'                                                                                                               
                  IF @c_ToLottable03 <> ''  AND @c_ColumnName <> 'ToLottable03'                                                                                                   
                     SET @c_SQL_LA = @c_SQL_LA + ', ToLottable03 = @c_ToLottable03'                                                                                                                        
                  IF @dt_ToLottable04 IS NOT NULL AND 
                     CONVERT(NVARCHAR(10),@dt_ToLottable04,121) <> '1900-01-01' AND 
                     @c_ColumnName <> 'ToLottable04'                                                                                                   
                     SET @c_SQL_LA = @c_SQL_LA + ', ToLottable04 = @dt_ToLottable04'                                                                                                              
                  IF @dt_ToLottable05 IS NOT NULL AND 
                     CONVERT(NVARCHAR(10),@dt_ToLottable05,121) <> '1900-01-01' AND 
                     @c_ColumnName <> 'ToLottable05'                                                                                                   
                     SET @c_SQL_LA = @c_SQL_LA + ', ToLottable05 = @dt_ToLottable05'                                                                                                              
                  IF @c_ToLottable06 <> ''  AND @c_ColumnName <> 'ToLottable06'                                                                                                   
                     SET @c_SQL_LA = @c_SQL_LA + ', ToLottable06 = @c_ToLottable06'                                                                                                               
                  IF @c_ToLottable07 <> ''  AND @c_ColumnName <> 'ToLottable07'                                                                                                   
                     SET @c_SQL_LA = @c_SQL_LA + ', ToLottable07 = @c_ToLottable07'                                                                                                               
                  IF @c_ToLottable08 <> ''  AND @c_ColumnName <> 'ToLottable08'                                                                                                   
                     SET @c_SQL_LA = @c_SQL_LA + ', ToLottable08 = @c_ToLottable08'                                                                                                               
                  IF @c_ToLottable09 <> ''  AND @c_ColumnName <> 'ToLottable09'                                                                                                   
                     SET @c_SQL_LA = @c_SQL_LA + ', ToLottable09 = @c_ToLottable09'                                                                                                               
                  IF @c_ToLottable10 <> ''  AND @c_ColumnName <> 'ToLottable10'                                                                                                   
                     SET @c_SQL_LA = @c_SQL_LA + ', ToLottable10 = @c_ToLottable10'                                                                                                               
                  IF @c_ToLottable11 <> ''  AND @c_ColumnName <> 'ToLottable11'                                                                                                   
                     SET @c_SQL_LA = @c_SQL_LA + ', ToLottable11 = @c_ToLottable11'                                                                                                               
                  IF @c_ToLottable12 <> ''  AND @c_ColumnName <> 'ToLottable12'                                                                                                   
                     SET @c_SQL_LA = @c_SQL_LA + ', ToLottable12 = @c_ToLottable12'                                                                                                               
                  IF @dt_ToLottable13 IS NOT NULL AND 
                     CONVERT(NVARCHAR(10),@dt_ToLottable13,121) <> '1900-01-01' AND
                     @c_ColumnName <> 'ToLottable13'                                                                                                   
                     SET @c_SQL_LA = @c_SQL_LA + ', ToLottable13 = @dt_ToLottable13'                                                                                                              
                  IF @dt_ToLottable14 IS NOT NULL AND 
                     CONVERT(NVARCHAR(10),@dt_ToLottable14,121) <> '1900-01-01' AND
                     @c_ColumnName <> 'ToLottable14'                                                                                                   
                     SET @c_SQL_LA = @c_SQL_LA + ', ToLottable14 = @dt_ToLottable14'                                                                                                              
                  IF @dt_ToLottable15 IS NOT NULL AND 
                     CONVERT(NVARCHAR(10),@dt_ToLottable15,121) <> '1900-01-01' AND
                     @c_ColumnName <> 'ToLottable15'                                                                                                   
                     SET @c_SQL_LA = @c_SQL_LA + ', ToLottable15 = @dt_ToLottable15'                                                                                                              
               END                                                                                                                                                                            
            END                                                                                                                                                                               
         END                                                                                                                                                                                  
                                                                                                                                                                                              
         IF @n_Continue IN (1,2)                                                                                                                                                              
         BEGIN                                                                                                                                                                                
            SET @c_SQL = N'UPDATE #INPUTDATA '                                                                                                                                                
                       + ' SET ' + @c_ColumnName + '= @c_CopyValue'                                                                                                                           
                       + IIF(@b_Trafficop_NULL = 0, '', ', Trafficcop = NULL')                                                                                                                
                       + IIF(@c_SQL_LA <> '', @c_SQL_LA, '')                                                                                                                                  
                       + ' WHERE TransferKey = @c_CopyFromKey1'                                                                                                                                
                       + ' AND TransferLineNumber = @c_TransferLineNumber'                                                                                                                      
                                                                                                                                                                                              
            SET @c_SQLParms = N'@c_CopyValue          NVARCHAR(MAX)'                                                                                                                          
                            + ',@c_CopyFromKey1       NVARCHAR(30)'                                                                                                                           
                            + ',@c_TransferLineNumber NVARCHAR(5)'                                                                                                                            
                            + ',@c_ToLottable01       NVARCHAR(18)'                                                                                                                           
                            + ',@c_ToLottable02       NVARCHAR(18)'                                                                                                                           
                            + ',@c_ToLottable03       NVARCHAR(18)'                                                                                                                           
                            + ',@dt_ToLottable04      DATETIME'                                                                                                                               
                            + ',@dt_ToLottable05      DATETIME'                                                                                                                               
                            + ',@c_ToLottable06       NVARCHAR(30)'                                                                                                                           
                            + ',@c_ToLottable07       NVARCHAR(30)'                                                                                                                           
                            + ',@c_ToLottable08       NVARCHAR(30)'                                                                                                                           
                            + ',@c_ToLottable09       NVARCHAR(30)'                                                                                                                           
                            + ',@c_ToLottable10       NVARCHAR(30)'                                                                                                                           
                            + ',@c_ToLottable11       NVARCHAR(30)'                                                                                                                           
                            + ',@c_ToLottable12       NVARCHAR(30)'                                                                                                                           
                            + ',@dt_ToLottable13      DATETIME'                                                                                                                               
                            + ',@dt_ToLottable14      DATETIME'                                                                                                                               
                            + ',@dt_ToLottable15      DATETIME'                                                                                                                               
                                                                                                                                                                                              
            EXEC sp_ExecuteSQL @c_SQL                                                                                                                                                         
                              ,@c_SQLParms                                                                                                                                                                           
                              ,@c_CopyValue                                                                                                                                                   
                              ,@c_CopyFromKey1                                                                                                                                                
                              ,@c_TransferLineNumber                                                                                                                                           
                              ,@c_ToLottable01                                                                                                                                                  
                              ,@c_ToLottable02                                                                                                                                                  
                              ,@c_ToLottable03                                                                                                                                                  
                              ,@dt_ToLottable04                                                                                                                                                 
                              ,@dt_ToLottable05                                                                                                                                                 
                              ,@c_ToLottable06                                                                                                                                                  
                              ,@c_ToLottable07                                                                                                                                                  
                              ,@c_ToLottable08                                                                                                                                                  
                              ,@c_ToLottable09                                                                                                                                                  
                              ,@c_ToLottable10                                                                                                                                                  
                              ,@c_ToLottable11                                                                                                                                                  
                              ,@c_ToLottable12                                                                                                                                                  
                              ,@dt_ToLottable13                                                                                                                                                 
                              ,@dt_ToLottable14                                                                                                                                                 
                              ,@dt_ToLottable15      
                              
            SET @c_TrafficCop = 'S'                                                 
            
            IF @c_SQL_LA <> '' 
            BEGIN
               SET @c_TrafficCop = NULL
            END  

            UPDATE #INPUTDATA  
               SET TrafficCop  = @c_TrafficCop           
            WHERE TransferKey = @c_CopyFromKey1
            AND TransferLineNumber = @c_TransferLineNumber                                                                                                                                                                                                  
         END                                                                                                                                                                                  
                                                                                                                                                                                              
         IF @n_Continue IN (1,2)                                                                                                                                                                                                         
         BEGIN                                                                                                                                                                                
            TRUNCATE TABLE #VALDN;

            EXEC sp_ExecuteSQL @c_InsertFromSQL
                              ,@c_InsertParms
                              ,@c_CopyFromKey1
                              ,@c_TransferLineNumber  
                                 
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
            END                                                                                                                                                                               
         END   
         
         IF @n_Continue IN (1,2)
         BEGIN
            EXEC [WM].[lsp_Wrapup_Validation_Wrapper]    
               @c_Module            = 'Transfer'  
            ,  @c_ControlObject     = 'WM.lsp_CopyValue_Transferdetail_Std'  
            ,  @c_UpdateTable       = 'Transferdetail'  
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
                                                                                                                                                                                              
            SET @c_SQLParms = N'@c_CopyValue             NVARCHAR(MAX)'                                                                                                                          
                            + ',@c_CopyFromKey1          NVARCHAR(30)'                                                                                                                           
                            + ',@c_TransferLineNumber    NVARCHAR(5)'                                                                                                                            
                            + ',@c_ToLottable01          NVARCHAR(18)'                                                                                                                           
                            + ',@c_ToLottable02          NVARCHAR(18)'                                                                                                                           
                            + ',@c_ToLottable03          NVARCHAR(18)'                                                                                                                           
                            + ',@dt_ToLottable04         DATETIME'                                                                                                                               
                            + ',@dt_ToLottable05         DATETIME'                                                                                                                               
                            + ',@c_ToLottable06          NVARCHAR(30)'                                                                                                                           
                            + ',@c_ToLottable07          NVARCHAR(30)'                                                                                                                           
                            + ',@c_ToLottable08          NVARCHAR(30)'                                                                                                                           
                            + ',@c_ToLottable09          NVARCHAR(30)'                                                                                                                           
                            + ',@c_ToLottable10          NVARCHAR(30)'                                                                                                                           
                            + ',@c_ToLottable11          NVARCHAR(30)'                                                                                                                           
                            + ',@c_ToLottable12          NVARCHAR(30)'                                                                                                                           
                            + ',@dt_ToLottable13         DATETIME'                                                                                                                               
                            + ',@dt_ToLottable14         DATETIME'                                                                                                                               
                            + ',@dt_ToLottable15         DATETIME'                                                                                                                               
                                                                                                                                                                                              
            EXEC sp_ExecuteSQL @c_SQL                                                                                                                                                         
                              ,@c_SQLParms                                                                                                                                                    
                              ,@c_CopyValue                                                                                                                                                   
                              ,@c_CopyFromKey1                                                                                                                                                
                              ,@c_TransferLineNumber                                                                                                                                           
                              ,@c_ToLottable01                                                                                                                                                  
                              ,@c_ToLottable02                                                                                                                                                  
                              ,@c_ToLottable03                                                                                                                                                  
                              ,@dt_ToLottable04                                                                                                                                                 
                              ,@dt_ToLottable05                                                                                                                                                 
                              ,@c_ToLottable06                                                                                                                                                  
                              ,@c_ToLottable07                                                                                                                                                  
                              ,@c_ToLottable08                                                                                                                                                  
                              ,@c_ToLottable09                                                                                                                                                  
                              ,@c_ToLottable10                                                                                                                                                  
                              ,@c_ToLottable11                                                                                                                                                  
                              ,@c_ToLottable12                                                                                                                                                  
                              ,@dt_ToLottable13                                                                                                                                                 
                              ,@dt_ToLottable14                                                                                                                                                 
                              ,@dt_ToLottable15                                                                                                                                                 
         END  
               
         NEXT_REC:                                                                                    --2023-05-23                                                                                                                                                                          
         FETCH NEXT FROM CUR_SELECT INTO                                                                                                                                                      
               @c_TransferLineNumber, @c_FromLot, @c_Storerkey, @c_Sku, @c_ToLottableLabel            --2023-05-25                                                                                                                                       
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
   END                                                                                 
                                                                                                                                                                                         
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'WM.lsp_CopyValue_Transferdetail_Std'                                                                                                            
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