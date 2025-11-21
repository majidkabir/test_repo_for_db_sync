SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: WM.lsp_CopyValue_Receiptdetail_Std                  */  
/* Creation Date: 2023-02-12                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-3648 - [CN]NIKE_TradeReturnASNReceipt_Copy value to     */
/*          support all details in one receiptkey                        */                                                          
/*                                                                       */   
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.3                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date       Author Ver   Purposes                                      */ 
/* 2023-02-12 Wan    1.0   Created & DevOps Combine Script               */
/* 2023-03-28 Wan01  1.1   Fixed Update before validation and double     */
/*                         update & Fixed Error #                        */
/* 2023-05-12 Wan02  1.2   Fix Where Clause Issue-Mulitple From Tables   */
/* 2023-06-13 Wan03  1.3   LFWM-4249-SCE PH Copy value to all row (ASN)Bug*/
/*************************************************************************/   
CREATE   PROCEDURE [WM].[lsp_CopyValue_Receiptdetail_Std]  
   @c_TableName            NVARCHAR(30) 
,  @c_ColumnName           NVARCHAR(50) 
,  @c_CopyFromKey1         NVARCHAR(30)    
,  @c_CopyFromKey2         NVARCHAR(30)   = ''
,  @c_CopyFromKey3         NVARCHAR(30)   = ''
,  @c_SearchSQL            NVARCHAR(MAX)  = ''                                      --(Wan02)
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
         , @c_InsertFromSQL         NVARCHAR(MAX)  = ''                             --(Wan03)
         , @c_InsertParms           NVARCHAR(4000) = ''                             --(Wan03)
         , @c_WhereClause           NVARCHAR(MAX)  = ''                             --(Wan03)
           
         , @c_SQL                   NVARCHAR(4000) = ''
         , @c_SQLParms              NVARCHAR(4000) = ''
         , @c_SQL_LA                NVARCHAR(1000) = ''
         
         , @c_CopyValue             NVARCHAR(4000) = ''
         , @b_Trafficop_NULL        BIT            = 1
         , @c_TrafficCop            NVARCHAR(1)    = 'S'                            --(Wan03)
         , @c_UserName              NVARCHAR(128)  = SUSER_SNAME()
                  
         , @c_SPName                NVARCHAR(60)   = ''
         , @c_UDF01                 NVARCHAR(60)   = ''
         , @c_SourceType            NVARCHAR(20)   = 'RECEIPT'
         , @c_Sourcekey             NVARCHAR(15)   = ''
         , @c_ReceiptLineNumber     NVARCHAR(5)    = ''
         
         , @c_Facility              NVARCHAR(5)    = ''
         , @c_Storerkey             NVARCHAR(15)   = ''
         , @c_Sku                   NVARCHAR(20)   = ''
         
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
         
         , @c_ValidateLotLabelExist NVARCHAR(10)   = ''   
         
   BEGIN TRY
      SET @b_Success = 1
      SET @n_Err = 0 
      SET @c_Errmsg = ''
     
      SELECT  @c_Facility   = r.Facility
            , @c_Storerkey  = r.Storerkey
            , @c_SourceType = CASE r.Doctype WHEN 'R' THEN 'TRADERETURN'
                                             WHEN 'X' THEN 'XDOCK'
                                             ELSE 'RECEIPT'
                                             END
      FROM dbo.RECEIPT AS r (NOLOCK)
      WHERE receiptkey = @c_CopyFromKey1
      
      SET @c_SQL = N'SELECT TOP 1 @c_CopyValue = ' + @c_ColumnName +
                 + ' FROM dbo.ReceiptDetail as rd WITH (NOLOCK)'
                 + ' WHERE rd.ReceiptKey = @c_CopyFromKey1'
                 + ' AND rd.ReceiptLineNumber = @c_CopyFromKey2'
                 + ' ORDER BY rd.ReceiptLineNumber'                 

      SET @c_SQLParms = N'@c_CopyValue    NVARCHAR(MAX)  OUTPUT' 
                      + ',@c_CopyFromKey1 NVARCHAR(30)'
                      + ',@c_CopyFromKey2 NVARCHAR(30)'
  
      EXEC sp_ExecuteSQL @c_SQL
                        ,@c_SQLParms
                        ,@c_CopyValue     OUTPUT     
                        ,@c_CopyFromKey1  
                        ,@c_CopyFromKey2 

      IF OBJECT_ID('tempdb..#INPUTDATA','u') IS NOT NULL 
      BEGIN
         DROP TABLE #INPUTDATA 
      END
       
      SELECT * 
      INTO #INPUTDATA 
      FROM dbo.RECEIPTDETAIL AS r (NOLOCK) 
      WHERE r.ReceiptKey = @c_CopyFromKey1
      AND r.ReceiptLineNumber <> @c_CopyFromKey2
      AND r.FinalizeFlag <> 'Y'
      ORDER BY r.ReceiptLineNumber

      IF OBJECT_ID('tempdb..#VALDN','u') IS NOT NULL                                --(Wan03) - START 
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
                  AND CLS.ListGroup = 'ReceiptDetail'
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
            @c_Module            = 'Receipt'  
         ,  @c_ControlObject     = 'WM.lsp_CopyValue_Receiptdetail_Std'  
         ,  @c_UpdateTable       = 'ReceiptDetail'  
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

      SET @c_WhereClause = N'Receiptkey = @c_Key1 AND ReceiptLineNumber = @c_Key2'
      SET @c_InsertParms = N'@c_Key1 NVARCHAR(30)'
                         + ',@c_Key2 NVARCHAR(30)'
   
      SET @c_InsertFromSQL = @c_InsertFromSQL + ' WHERE ' + @c_WhereClause          --(Wan03) - END                        

      SET @c_SQL = N'DECLARE CUR_SELECT CURSOR FAST_FORWARD READ_ONLY FOR'
                 + ' SELECT i.ReceiptLineNumber'
                 + ' , i.Storerkey'  
                 + ' , i.Sku'   
                 --+ ' , i.Lottable01' 
                 --+ ' , i.Lottable02'  
                 --+ ' , i.Lottable03' 
                 --+ ' , i.Lottable04'  
                 --+ ' , i.Lottable05' 
                 --+ ' , i.Lottable06'  
                 --+ ' , i.Lottable07' 
                 --+ ' , i.Lottable08' 
                 --+ ' , i.Lottable09' 
                 --+ ' , i.Lottable10' 
                 --+ ' , i.Lottable11' 
                 --+ ' , i.Lottable12'  
                 --+ ' , i.Lottable13' 
                 --+ ' , i.Lottable14'  
                 --+ ' , i.Lottable15'                                                                                                                                                        
                 + ' FROM #INPUTDATA as i WITH (NOLOCK)'
                 + ' WHERE i.ReceiptKey = @c_CopyFromKey1'
                 + ' AND i.' + @c_ColumnName + ' NOT IN ( @c_CopyValue )'
                 + ' AND i.FinalizeFlag <> ''Y'''                 
                 + ' ORDER BY i.ReceiptLineNumber'                 
  
      SET @c_SQLParms = N'@c_CopyValue    NVARCHAR(MAX)' 
                      + ',@c_CopyFromKey1 NVARCHAR(30)'
  
      EXEC sp_ExecuteSQL @c_SQL
                        ,@c_SQLParms
                        ,@c_CopyValue          
                        ,@c_CopyFromKey1  
  
      OPEN CUR_SELECT
      
      FETCH NEXT FROM CUR_SELECT INTO 
            @c_ReceiptLineNumber, @c_Storerkey, @c_Sku
         --,  @c_Lottable01Value, @c_Lottable02Value, @c_Lottable03Value, @dt_Lottable04Value, @dt_Lottable05Value
         --,  @c_Lottable06Value, @c_Lottable07Value, @c_Lottable08Value, @c_Lottable09Value, @c_Lottable10Value 
         --,  @c_Lottable11Value, @c_Lottable12Value, @dt_Lottable13Value, @dt_Lottable14Value, @dt_Lottable15Value 

      WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1, 2)
      BEGIN
         IF @c_ColumnName LIKE 'Lottable%'
         BEGIN
            SET @c_Sourcekey = RTRIM(@c_CopyFromKey1) + LTRIM(@c_ReceiptLineNumber)
            --call isp_GetLottablesRoles to get SP   
            EXEC dbo.isp_GetLottablesRoles
                  @c_ListName       = @c_ColumnName  
                , @c_Storerkey      = @c_Storerkey  
                , @c_Sku            = @c_Sku              
                , @c_Source         = N'RECEIPT_ITEMCHANGED'            
                , @c_SPName         = @c_SPName          OUTPUT       
                , @c_LottableLabel  = @c_LottableLabel   OUTPUT
                , @c_UDF01          = @c_UDF01           OUTPUT  
                , @b_Success        = 1
                
            IF EXISTS ( SELECT 1 FROM dbo.syscolumns sc
                        JOIN dbo.sysobjects so ON  sc.id = so.id  
                        WHERE so.[name] = 'RECEIPT' 
                        AND sc.[name] = @c_UDF01
            )
            BEGIN 
               SET @c_SQL = N'SELECT @c_Sourcekey = r.' + LTRIM(RTRIM(@c_UDF01))
                          + ' FROM dbo.RECEIPT AS r WITH (NOLOCK)'
                          + ' WHERE r.Receiptkey = @c_CopyFromKey1' 
               SET @c_SQLParms = N'@c_Sourcekey    NVARCHAR(15)   OUTPUT' 
                               + ',@c_CopyFromKey1 NVARCHAR(30)'   
                               
               EXEC sp_ExecuteSQL @c_SQL
                                 ,@c_SQLParms
                                 ,@c_Sourcekey     OUTPUT
                                 ,@c_CopyFromKey1                     
            END
            
            IF @c_LottableLabel = ''
            BEGIN
               SELECT @c_ValidateLotLabelExist = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '','ValidateLotLabelExist')
               
               IF @c_ValidateLotLabelExist = '1'                  --Wan01 (2023-03-20)
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 561401                             --Wan01 (2023-03-20)               
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) 
                                + ': ' + @c_ColumnName + ' Label Not Yet Setup In SKU: ' + @c_Sku
                                + ' (lsp_CopyValue_Receiptdetail_Std) |' + @c_ColumnName + '|' + @c_Sku
               END
            END
            
            IF @n_Continue IN (1,2)
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
               
               SET @c_Lottable01 = ''                                               --(Wan03)
               SET @c_Lottable02 = ''                                               --(Wan03)
               SET @c_Lottable03 = ''                                               --(Wan03)
               SET @dt_Lottable04= NULL                                             --(Wan03)
               SET @dt_Lottable05= NULL                                             --(Wan03)
               SET @c_Lottable06 = ''                                               --(Wan03)
               SET @c_Lottable07 = ''                                               --(Wan03)
               SET @c_Lottable08 = ''                                               --(Wan03)
               SET @c_Lottable09 = ''                                               --(Wan03)
               SET @c_Lottable10 = ''                                               --(Wan03)
               SET @c_Lottable11 = ''                                               --(Wan03)
               SET @c_Lottable12 = ''                                               --(Wan03)
               SET @dt_Lottable13= NULL                                             --(Wan03)
               SET @dt_Lottable14= NULL                                             --(Wan03)
               SET @dt_Lottable15= NULL                                             --(Wan03)
               
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
                  IF @c_Lottable01 <> ''  AND @c_ColumnName <> 'Lottable01'         --(Wan03) - START
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
                     SET @c_SQL_LA = @c_SQL_LA + ', Lottable15 = @dt_Lottable15'    --(Wan05) - END
               END                 
            END
         END
      
         IF @n_Continue IN (1,2)
         BEGIN
            SET @c_SQL = N'UPDATE #INPUTDATA '
                       + ' SET ' + @c_ColumnName + '= @c_CopyValue'
                       + IIF(@b_Trafficop_NULL = 0, '', ', Trafficcop = NULL')
                       + IIF(@c_SQL_LA <> '', @c_SQL_LA, '')
                       + ' WHERE ReceiptKey = @c_CopyFromKey1'
                       + ' AND ReceiptLineNumber = @c_ReceiptLineNumber'

            SET @c_SQLParms = N'@c_CopyValue          NVARCHAR(MAX)' 
                            + ',@c_CopyFromKey1       NVARCHAR(30)'
                            + ',@c_ReceiptLineNumber  NVARCHAR(5)'
                            + ',@c_Lottable01         NVARCHAR(18)'
                            + ',@c_Lottable02         NVARCHAR(18)'
                            + ',@c_Lottable03         NVARCHAR(18)'
                            + ',@dt_Lottable04        DATETIME'
                            + ',@dt_Lottable05        DATETIME'
                            + ',@c_Lottable06         NVARCHAR(30)'
                            + ',@c_Lottable07         NVARCHAR(30)'
                            + ',@c_Lottable08         NVARCHAR(30)'
                            + ',@c_Lottable09         NVARCHAR(30)'
                            + ',@c_Lottable10         NVARCHAR(30)'
                            + ',@c_Lottable11         NVARCHAR(30)'
                            + ',@c_Lottable12         NVARCHAR(30)'
                            + ',@dt_Lottable13        DATETIME'
                            + ',@dt_Lottable14        DATETIME'
                            + ',@dt_Lottable15        DATETIME'

            EXEC sp_ExecuteSQL @c_SQL
                              ,@c_SQLParms
                              ,@c_CopyValue          
                              ,@c_CopyFromKey1  
                              ,@c_ReceiptLineNumber
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
                              
            SET @c_TrafficCop = 'S'                                                 --(Wan01) - START
            IF @c_SQL_LA <> '' 
            BEGIN
               SET @c_TrafficCop = NULL
            END   
            UPDATE #INPUTDATA  
               SET TrafficCop  = @c_TrafficCop           
            WHERE Receiptkey = @c_CopyFromKey1
            AND ReceiptLineNumber = @c_ReceiptLineNumber   
         END  
 
         IF @n_Continue IN (1,2)                   
         BEGIN         
            TRUNCATE TABLE #VALDN;

            EXEC sp_ExecuteSQL @c_InsertFromSQL
                              ,@c_InsertParms
                              ,@c_CopyFromKey1
                              ,@c_ReceiptLineNumber 
                                 
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
            END    
         END 
        
         IF @n_Continue IN (1,2)
         BEGIN         
            --EXEC WM.lsp_BuildInputData4Validation                                 
            --   @c_WhereClause    = 'Receiptkey = @c_Key1 AND ReceiptLineNumber = @c_Key2'
            --,  @c_Key1           = @c_CopyFromKey1
            --,  @c_Key2           = @c_ReceiptLineNumber
            --,  @c_Key3           = ''
            --,  @c_UpdateTable    = @c_TableName
            --,  @b_Success        = @b_Success  OUTPUT    
            --,  @n_Err            = @n_Err      OUTPUT
            --,  @c_Errmsg         = @c_Errmsg   OUTPUT
         
            EXEC [WM].[lsp_Wrapup_Validation_Wrapper]    
                  @c_Module            = 'Receipt'  
               ,  @c_ControlObject     = 'WM.lsp_CopyValue_Receiptdetail_Std'  
               ,  @c_UpdateTable       = 'RECEIPTDETAIL'  
               ,  @c_XMLSchemaString   = ''   
               ,  @c_XMLDataString     = 'STD_VALIDATE'     
               ,  @b_Success           = @b_Success   OUTPUT          
               ,  @n_Err               = @n_Err       OUTPUT          
               ,  @c_Errmsg            = @c_Errmsg    OUTPUT  
               ,  @c_UserName          = @c_UserName                                --(Wan03) - END
             
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
                            + ',@c_ReceiptLineNumber  NVARCHAR(5)'
                            + ',@c_Lottable01         NVARCHAR(18)'
                            + ',@c_Lottable02         NVARCHAR(18)'
                            + ',@c_Lottable03         NVARCHAR(18)'
                            + ',@dt_Lottable04        DATETIME'
                            + ',@dt_Lottable05        DATETIME'
                            + ',@c_Lottable06         NVARCHAR(30)'
                            + ',@c_Lottable07         NVARCHAR(30)'
                            + ',@c_Lottable08         NVARCHAR(30)'
                            + ',@c_Lottable09         NVARCHAR(30)'
                            + ',@c_Lottable10         NVARCHAR(30)'
                            + ',@c_Lottable11         NVARCHAR(30)'
                            + ',@c_Lottable12         NVARCHAR(30)'
                            + ',@dt_Lottable13        DATETIME'
                            + ',@dt_Lottable14        DATETIME'
                            + ',@dt_Lottable15        DATETIME'

            EXEC sp_ExecuteSQL @c_SQL
                              ,@c_SQLParms
                              ,@c_CopyValue          
                              ,@c_CopyFromKey1  
                              ,@c_ReceiptLineNumber
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
         FETCH NEXT FROM CUR_SELECT INTO 
               @c_ReceiptLineNumber, @c_Storerkey, @c_Sku
            --,  @c_Lottable01Value, @c_Lottable02Value, @c_Lottable03Value, @dt_Lottable04Value, @dt_Lottable05Value
            --,  @c_Lottable06Value, @c_Lottable07Value, @c_Lottable08Value, @c_Lottable09Value, @c_Lottable10Value 
            --,  @c_Lottable11Value, @c_Lottable12Value, @dt_Lottable13Value, @dt_Lottable14Value, @dt_Lottable15Value 

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
         
   IF OBJECT_ID('tempdb..SCHEMA','u') IS NOT NULL                                   --(Wan03) - START
   BEGIN
      DROP TABLE #SCHEMA
   END
      
   IF CURSOR_STATUS('GLOBAL', 'CUR_SELECT') IN (0 , 1) 
   BEGIN
      CLOSE CUR_SELECT
      DEALLOCATE CUR_SELECT
   END                                                                              --(Wan03) - END
   
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'WM.lsp_CopyValue_Receiptdetail_Std'
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