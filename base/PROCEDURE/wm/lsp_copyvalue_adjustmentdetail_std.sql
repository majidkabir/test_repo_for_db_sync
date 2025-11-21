SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: WM.lsp_CopyValue_Adjustmentdetail_Std               */  
/* Creation Date: 2023-03-30                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-4116 - [CN]CONVERSE_ADJ_'Copy value to support all      */
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
/* Date       Author Ver   Purposes                                      */ 
/* 2023-03-30 Wan    1.0   Created & DevOps Combine Script               */
/*************************************************************************/   
CREATE   PROCEDURE [WM].[lsp_CopyValue_Adjustmentdetail_Std]  
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
         , @b_TrafficCop_NULL       BIT            = 1
         , @c_TrafficCop            NVARCHAR(1)    = 'S'
         
         , @c_UserName              NVARCHAR(128)  = SUSER_SNAME()
                  
         , @c_SPName                NVARCHAR(60)   = ''
         , @c_UDF01                 NVARCHAR(60)   = ''
         , @c_SourceType            NVARCHAR(20)   = 'ADJ'
         , @c_Sourcekey             NVARCHAR(15)   = ''
         , @c_AdjustmentLineNumber  NVARCHAR(5)    = ''
         
         , @c_Facility              NVARCHAR(5)    = ''
         , @c_Storerkey             NVARCHAR(15)   = ''
         , @c_Sku                   NVARCHAR(20)   = ''
         , @c_Lot                   NVARCHAR(10)   = ''         
         
         , @c_LottableLabel         NVARCHAR(20)   = ''
         , @c_Lottable01Value       NVARCHAR(18)   = ''
         , @c_Lottable02Value       NVARCHAR(18)   = ''
         , @c_Lottable03Value       NVARCHAR(18)   = ''
         , @dt_Lottable04Value      DATETIME
         , @dt_Lottable05Value      DATETIME
         , @c_Lottable06Value       NVARCHAR(30)   = ''
         , @c_Lottable07Value       NVARCHAR(30)   = ''
         , @c_Lottable08Value       NVARCHAR(30)   = ''
         , @c_Lottable09Value       NVARCHAR(30)   = ''
         , @c_Lottable10Value       NVARCHAR(30)   = ''
         , @c_Lottable11Value       NVARCHAR(30)   = ''
         , @c_Lottable12Value       NVARCHAR(30)   = ''
         , @dt_Lottable13Value      DATETIME
         , @dt_Lottable14Value      DATETIME
         , @dt_Lottable15Value      DATETIME
         
         , @c_Lottable01            NVARCHAR(18)   = ''
         , @c_Lottable02            NVARCHAR(18)   = ''
         , @c_Lottable03            NVARCHAR(18)   = ''
         , @dt_Lottable04           DATETIME
         , @dt_Lottable05           DATETIME
         , @c_Lottable06            NVARCHAR(30)   = ''
         , @c_Lottable07            NVARCHAR(30)   = ''
         , @c_Lottable08            NVARCHAR(30)   = ''
         , @c_Lottable09            NVARCHAR(30)   = ''
         , @c_Lottable10            NVARCHAR(30)   = ''
         , @c_Lottable11            NVARCHAR(30)   = ''
         , @c_Lottable12            NVARCHAR(30)   = ''
         , @dt_Lottable13           DATETIME
         , @dt_Lottable14           DATETIME
         , @dt_Lottable15           DATETIME
         , @n_WarningNo             INT            = 0  
         
   BEGIN TRY
      SET @b_Success = 1
      SET @n_Err = 0 
      SET @c_Errmsg = ''

      IF @c_ColumnName NOT IN ('id', 'reasoncode', 'channel') AND
         @c_ColumnName NOT LIKE 'userdefine%' AND
         @c_ColumnName NOT LIKE 'lottable%'
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 561451
         SET @c_Errmsg = 'NSQL' + CONVERT(CHAR(6),@n_Err) 
                       + ': Column: ' + @c_ColumnName + ' is not allow to copy'
                       + '. (lsp_CopyValue_Adjustmentdetail_Std) |' + @c_ColumnName
         GOTO EXIT_SP              
      END

      SET @c_SQL = N'SELECT TOP 1 @c_CopyValue = ' + @c_ColumnName +
                 + ' , @c_Storerkey = a.Storerkey'
                 + ' FROM dbo.ADJUSTMENTDETAIL AS a WITH (NOLOCK)'
                 + ' WHERE a.AdjustmentKey = @c_CopyFromKey1'
                 + ' AND a.AdjustmentLineNumber = @c_CopyFromKey2'
                 + ' ORDER BY a.AdjustmentLineNumber'                 

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
      FROM dbo.ADJUSTMENTDETAIL AS a (NOLOCK) 
      WHERE a.AdjustmentKey = @c_CopyFromKey1
      AND a.AdjustmentLineNumber <> @c_CopyFromKey2
      ORDER BY a.AdjustmentLineNumber
      
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
                  AND CLS.ListGroup = 'AdjustmentDetail'
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
            @c_Module            = 'Adjustment'  
         ,  @c_ControlObject     = 'WM.lsp_CopyValue_Adjustmentdetail_Std'  
         ,  @c_UpdateTable       = 'AdjustmentDetail'  
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

      SET @c_WhereClause = N'Adjustmentkey = @c_Key1 AND AdjustmentLineNumber = @c_Key2'
      SET @c_InsertParms = N'@c_Key1 NVARCHAR(30)'
                         + ',@c_Key2 NVARCHAR(30)'
   
      SET @c_InsertFromSQL = @c_InsertFromSQL + ' WHERE ' + @c_WhereClause                        
                     
      SET @c_SQL = N'DECLARE CUR_SELECT CURSOR FAST_FORWARD READ_ONLY FOR'
                 + ' SELECT i.AdjustmentLineNumber'
                 + ' , i.Storerkey'  
                 + ' , i.Sku'   
                 + ' , i.Lot'                  
                 + ' , lottablelabel=' + CASE WHEN @c_ColumnName LIKE 'Lottable%' THEN 's.' + RTRIM(@c_ColumnName) + 'Label'
                                              ELSE '''''' END  
                 + ' FROM #INPUTDATA as i WITH (NOLOCK)'
                 + ' JOIN dbo.SKU as s WITH (NOLOCK) ON s.Storerkey = i.Storerkey AND s.Sku = i.Sku'
                 + ' WHERE i.Adjustmentkey = @c_CopyFromKey1'
                 + ' AND i.' + @c_ColumnName + ' NOT IN ( @c_CopyValue )'           
                 + ' ORDER BY i.AdjustmentLineNumber'                 
  
      SET @c_SQLParms = N'@c_CopyValue    NVARCHAR(MAX)' 
                      + ',@c_CopyFromKey1 NVARCHAR(30)'
  
      EXEC sp_ExecuteSQL @c_SQL
                        ,@c_SQLParms
                        ,@c_CopyValue          
                        ,@c_CopyFromKey1  
  
      OPEN CUR_SELECT
      
      FETCH NEXT FROM CUR_SELECT INTO 
            @c_AdjustmentLineNumber, @c_Storerkey, @c_Sku, @c_Lot, @c_LottableLabel

      WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1, 2)
      BEGIN
         IF @c_ColumnName LIKE 'Lottable%' AND @c_Lot <> ''
         BEGIN
            GOTO NEXT_REC
         END
         
         IF @c_ColumnName LIKE 'Lottable%' AND @c_LottableLabel <> '' 
         BEGIN
            IF @c_ColumnName = 'Lottable01' SET @c_Lottable01Value = @c_CopyValue
            IF @c_ColumnName = 'Lottable02' SET @c_Lottable02Value = @c_CopyValue
            IF @c_ColumnName = 'Lottable03' SET @c_Lottable03Value = @c_CopyValue
            IF @c_ColumnName = 'Lottable04' SET @dt_Lottable04Value= @c_CopyValue
            IF @c_ColumnName = 'Lottable05' SET @dt_Lottable05Value= @c_CopyValue
            IF @c_ColumnName = 'Lottable06' SET @c_Lottable06Value = @c_CopyValue   
            IF @c_ColumnName = 'Lottable07' SET @c_Lottable07Value = @c_CopyValue
            IF @c_ColumnName = 'Lottable08' SET @c_Lottable08Value = @c_CopyValue
            IF @c_ColumnName = 'Lottable09' SET @c_Lottable09Value = @c_CopyValue
            IF @c_ColumnName = 'Lottable10' SET @c_Lottable10Value = @c_CopyValue
            IF @c_ColumnName = 'Lottable11' SET @c_Lottable11Value = @c_CopyValue
            IF @c_ColumnName = 'Lottable12' SET @c_Lottable12Value = @c_CopyValue  
            IF @c_ColumnName = 'Lottable13' SET @dt_Lottable13Value= @c_CopyValue
            IF @c_ColumnName = 'Lottable14' SET @dt_Lottable14Value= @c_CopyValue  
            IF @c_ColumnName = 'Lottable15' SET @dt_Lottable15Value= @c_CopyValue
            
            SET @c_Lottable01 = ''                                               
            SET @c_Lottable02 = ''                                               
            SET @c_Lottable03 = ''                                               
            SET @dt_Lottable04= NULL                                             
            SET @dt_Lottable05= NULL                                             
            SET @c_Lottable06 = ''                                               
            SET @c_Lottable07 = ''                                               
            SET @c_Lottable08 = ''                                               
            SET @c_Lottable09 = ''                                               
            SET @c_Lottable10 = ''                                               
            SET @c_Lottable11 = ''                                               
            SET @c_Lottable12 = ''                                               
            SET @dt_Lottable13= NULL                                             
            SET @dt_Lottable14= NULL                                             
            SET @dt_Lottable15= NULL                                             
                                                                                   
            EXEC WM.lspLottableRule_Wrapper
               @c_SPName    = ''                           
            ,  @c_Listname  = @c_ColumnName
            ,  @c_Storerkey = @c_Storerkey
            ,  @c_Sku       = @c_Sku                           
            ,  @c_LottableLabel   = @c_LottableLabel                    
            ,  @c_Lottable01Value = @c_Lottable01Value                  
            ,  @c_Lottable02Value = @c_Lottable02Value                  
            ,  @c_Lottable03Value = @c_Lottable03Value                  
            ,  @dt_Lottable04Value= @dt_Lottable04Value                
            ,  @dt_Lottable05Value= @dt_Lottable05Value                
            ,  @c_Lottable06Value = @c_Lottable06Value                  
            ,  @c_Lottable07Value = @c_Lottable07Value                  
            ,  @c_Lottable08Value = @c_Lottable08Value                  
            ,  @c_Lottable09Value = @c_Lottable09Value                  
            ,  @c_Lottable10Value = @c_Lottable10Value                  
            ,  @c_Lottable11Value = @c_Lottable11Value                  
            ,  @c_Lottable12Value = @c_Lottable12Value                  
            ,  @dt_Lottable13Value= @dt_Lottable13Value 
            ,  @dt_Lottable14Value= @dt_Lottable14Value 
            ,  @dt_Lottable15Value= @dt_Lottable15Value 
            ,  @c_Lottable01 = @c_Lottable01    OUTPUT
            ,  @c_Lottable02 = @c_Lottable02    OUTPUT
            ,  @c_Lottable03 = @c_Lottable03    OUTPUT
            ,  @dt_Lottable04= @dt_Lottable04   OUTPUT
            ,  @dt_Lottable05= @dt_Lottable05   OUTPUT
            ,  @c_Lottable06 = @c_Lottable06    OUTPUT
            ,  @c_Lottable07 = @c_Lottable07    OUTPUT
            ,  @c_Lottable08 = @c_Lottable08    OUTPUT
            ,  @c_Lottable09 = @c_Lottable09    OUTPUT
            ,  @c_Lottable10 = @c_Lottable10    OUTPUT
            ,  @c_Lottable11 = @c_Lottable11    OUTPUT
            ,  @c_Lottable12 = @c_Lottable12    OUTPUT
            ,  @dt_Lottable13 = @dt_Lottable13  OUTPUT
            ,  @dt_Lottable14 = @dt_Lottable14  OUTPUT
            ,  @dt_Lottable15 = @dt_Lottable15  OUTPUT
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
               IF @c_Lottable01 <> ''  AND @c_ColumnName <> 'Lottable01' 
                  SET @c_SQL_LA = @c_SQL_LA + ', Lottable01 = @c_Lottable01'
               IF @c_Lottable02 <> ''  AND @c_ColumnName <> 'Lottable02' 
                  SET @c_SQL_LA = @c_SQL_LA + ', Lottable02 = @c_Lottable02'
               IF @c_Lottable03 <> ''  AND @c_ColumnName <> 'Lottable03' 
                  SET @c_SQL_LA = @c_SQL_LA + ', Lottable03 = @c_Lottable03'
               IF @dt_Lottable04 IS NOT NULL AND 
                  CONVERT(NVARCHAR(10),@dt_Lottable04,121) <> '1900-01-01' AND 
                  @c_ColumnName <> 'Lottable04' 
                  SET @c_SQL_LA = @c_SQL_LA + ', Lottable04 = @dt_Lottable04'
               IF @dt_Lottable05 IS NOT NULL AND 
                  CONVERT(NVARCHAR(10),@dt_Lottable05,121) <> '1900-01-01' AND 
                  @c_ColumnName <> 'Lottable05' 
                  SET @c_SQL_LA = @c_SQL_LA + ', Lottable05 = @dt_Lottable05'
               IF @c_Lottable06 <> ''  AND @c_ColumnName <> 'Lottable06' 
                  SET @c_SQL_LA = @c_SQL_LA + ', Lottable06 = @c_Lottable06'
               IF @c_Lottable07 <> ''  AND @c_ColumnName <> 'Lottable07' 
                  SET @c_SQL_LA = @c_SQL_LA + ', Lottable07 = @c_Lottable07'
               IF @c_Lottable08 <> ''  AND @c_ColumnName <> 'Lottable08' 
                  SET @c_SQL_LA = @c_SQL_LA + ', Lottable08 = @c_Lottable08'
               IF @c_Lottable09 <> ''  AND @c_ColumnName <> 'Lottable09' 
                  SET @c_SQL_LA = @c_SQL_LA + ', Lottable09 = @c_Lottable09'
               IF @c_Lottable10 <> ''  AND @c_ColumnName <> 'Lottable10' 
                  SET @c_SQL_LA = @c_SQL_LA + ', Lottable10 = @c_Lottable10'           
               IF @c_Lottable11 <> ''  AND @c_ColumnName <> 'Lottable11' 
                  SET @c_SQL_LA = @c_SQL_LA + ', Lottable11 = @c_Lottable11'
               IF @c_Lottable12 <> ''  AND @c_ColumnName <> 'Lottable12' 
                  SET @c_SQL_LA = @c_SQL_LA + ', Lottable12 = @c_Lottable12'
               IF @dt_Lottable13 IS NOT NULL AND 
                  CONVERT(NVARCHAR(10),@dt_Lottable13,121) <> '1900-01-01' AND 
                  @c_ColumnName <> 'Lottable13'  
                  SET @c_SQL_LA = @c_SQL_LA + ', Lottable13 = @dt_Lottable13'
               IF @dt_Lottable14 IS NOT NULL AND 
                  CONVERT(NVARCHAR(10),@dt_Lottable14,121) <> '1900-01-01' AND 
                  @c_ColumnName <> 'Lottable14' 
                  SET @c_SQL_LA = @c_SQL_LA + ', Lottable14 = @dt_Lottable14'
               IF @dt_Lottable15 IS NOT NULL AND 
                  CONVERT(NVARCHAR(10),@dt_Lottable15,121) <> '1900-01-01' AND 
                  @c_ColumnName <> 'Lottable15' 
                  SET @c_SQL_LA = @c_SQL_LA + ', Lottable15 = @dt_Lottable15'
            END                 
         END
      
         IF @n_Continue IN (1,2)
         BEGIN
            SET @c_SQL = N'UPDATE #INPUTDATA '
                       + ' SET ' + @c_ColumnName + '= @c_CopyValue'
                       + IIF(@b_TrafficCop_NULL = 0, '', ', TrafficCop = NULL')
                       + IIF(@c_SQL_LA <> '', @c_SQL_LA, '')
                       + ' WHERE Adjustmentkey = @c_CopyFromKey1'
                       + ' AND AdjustmentLineNumber = @c_AdjustmentLineNumber'

            SET @c_SQLParms = N'@c_CopyValue             NVARCHAR(MAX)' 
                            + ',@c_CopyFromKey1          NVARCHAR(30)'
                            + ',@c_AdjustmentLineNumber  NVARCHAR(5)'
                            + ',@c_Lottable01            NVARCHAR(18)'
                            + ',@c_Lottable02            NVARCHAR(18)'
                            + ',@c_Lottable03            NVARCHAR(18)'
                            + ',@dt_Lottable04           DATETIME'
                            + ',@dt_Lottable05           DATETIME'
                            + ',@c_Lottable06            NVARCHAR(30)'
                            + ',@c_Lottable07            NVARCHAR(30)'
                            + ',@c_Lottable08            NVARCHAR(30)'
                            + ',@c_Lottable09            NVARCHAR(30)'
                            + ',@c_Lottable10            NVARCHAR(30)'
                            + ',@c_Lottable11            NVARCHAR(30)'
                            + ',@c_Lottable12            NVARCHAR(30)'
                            + ',@dt_Lottable13           DATETIME'
                            + ',@dt_Lottable14           DATETIME'
                            + ',@dt_Lottable15           DATETIME'

            EXEC sp_ExecuteSQL @c_SQL
                              ,@c_SQLParms
                              ,@c_CopyValue          
                              ,@c_CopyFromKey1  
                              ,@c_AdjustmentLineNumber
                              ,@c_Lottable01  
                              ,@c_Lottable02  
                              ,@c_Lottable03  
                              ,@dt_Lottable04 
                              ,@dt_Lottable05 
                              ,@c_Lottable06  
                              ,@c_Lottable07  
                              ,@c_Lottable08  
                              ,@c_Lottable09  
                              ,@c_Lottable10  
                              ,@c_Lottable11  
                              ,@c_Lottable12  
                              ,@dt_Lottable13 
                              ,@dt_Lottable14 
                              ,@dt_Lottable15 
            
            SET @c_TrafficCop = 'S'
            IF @c_SQL_LA <> '' 
            BEGIN
               SET @c_TrafficCop = NULL
            END   
            UPDATE #INPUTDATA  
               SET TrafficCop  = @c_TrafficCop           
            WHERE Adjustmentkey = @c_CopyFromKey1
            AND AdjustmentLineNumber = @c_AdjustmentLineNumber             
         END  
         
         IF @n_Continue IN (1,2)
         BEGIN         
            TRUNCATE TABLE #VALDN;

            EXEC sp_ExecuteSQL @c_InsertFromSQL
                              ,@c_InsertParms
                              ,@c_CopyFromKey1
                              ,@c_AdjustmentLineNumber 
                                 
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
            END    
         END 
        
         IF @n_Continue IN (1,2)
         BEGIN
            EXEC [WM].[lsp_Wrapup_Validation_Wrapper]    
               @c_Module            = 'Adjustment'  
            ,  @c_ControlObject     = 'WM.lsp_CopyValue_Adjustmentdetail_Std'  
            ,  @c_UpdateTable       = 'ADJUSTMENTDETAIL'  
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
                            + ',@c_AdjustmentLineNumber  NVARCHAR(5)'
                            + ',@c_Lottable01            NVARCHAR(18)'
                            + ',@c_Lottable02            NVARCHAR(18)'
                            + ',@c_Lottable03            NVARCHAR(18)'
                            + ',@dt_Lottable04           DATETIME'
                            + ',@dt_Lottable05           DATETIME'
                            + ',@c_Lottable06            NVARCHAR(30)'
                            + ',@c_Lottable07            NVARCHAR(30)'
                            + ',@c_Lottable08            NVARCHAR(30)'
                            + ',@c_Lottable09            NVARCHAR(30)'
                            + ',@c_Lottable10            NVARCHAR(30)'
                            + ',@c_Lottable11            NVARCHAR(30)'
                            + ',@c_Lottable12            NVARCHAR(30)'
                            + ',@dt_Lottable13           DATETIME'
                            + ',@dt_Lottable14           DATETIME'
                            + ',@dt_Lottable15           DATETIME'

            EXEC sp_ExecuteSQL @c_SQL
                              ,@c_SQLParms
                              ,@c_CopyValue          
                              ,@c_CopyFromKey1  
                              ,@c_AdjustmentLineNumber
                              ,@c_Lottable01  
                              ,@c_Lottable02  
                              ,@c_Lottable03  
                              ,@dt_Lottable04 
                              ,@dt_Lottable05 
                              ,@c_Lottable06  
                              ,@c_Lottable07  
                              ,@c_Lottable08  
                              ,@c_Lottable09  
                              ,@c_Lottable10  
                              ,@c_Lottable11  
                              ,@c_Lottable12  
                              ,@dt_Lottable13 
                              ,@dt_Lottable14 
                              ,@dt_Lottable15 
         END 
         NEXT_REC:              
         FETCH NEXT FROM CUR_SELECT INTO 
               @c_AdjustmentLineNumber, @c_Storerkey, @c_Sku, @c_Lot, @c_LottableLabel

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
      SET @n_WarningNo = 0
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'WM.lsp_CopyValue_Adjustmentdetail_Std'
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