SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_ASN_PopulateSOs_Wrapper                         */                                                                                  
/* Creation Date: 2020-11-04                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-2313 - UAT - TW  Populate from Order and Populate from */
/*          Order Detail are missing in Inbound module                  */
/*                                                                      */
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.5                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */ 
/* 2020-11-04  Wan      1.0   Created                                   */ 
/* 2020-11-30  Wan01    1.1   Add Big Outer Begin Try..End Try to enable*/
/*                            Revert when Raise error                   */
/* 2021-01-05  Wan02    1.2   Remove debug 'select * from #tRECEIPTDETAIL'*/
/*                            Execute Login if current login<>@c_Username*/
/* 2021-12-17  Wan03    1.3   LFWM-3236 - UATRG Trade return not able to*/
/*                            populate Order                            */
/* 2021-12-17  Wan03    1.3   DevOps Combine Script                     */
/* 2021-03-14  Wan04    1.3   LFWM-3382 - UAT  Australia  Return module */
/*                            populates wrong Lottable03                */
/* 2022-08-23  Wan05    1.4   LFWM-3701 - PH SCE UAT -Trade Return issue*/
/*                            (Populate Via Order)                      */
/* 2023-04-14  Wan06    1.5   LFWM-4192 - SCEUATSGPopulate Carrierkey   */
/*                            from Orders in Trade Return               */
/************************************************************************/                                                                                  
CREATE   PROC [WM].[lsp_ASN_PopulateSOs_Wrapper]                                                                                                                     
      @c_ReceiptKey           NVARCHAR(10)         
   ,  @c_OrderKeyList         NVARCHAR(MAX) = ''   --(Wan06) -- Order Keys seperated by '|' if multiple orders to populate
   ,  @b_Success              INT = 1           OUTPUT  
   ,  @n_err                  INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)= '' OUTPUT   
   ,  @n_WarningNo            INT          = 0  OUTPUT
   ,  @c_ProceedWithWarning   CHAR(1)      = 'N'                
   ,  @c_UserName             NVARCHAR(128)= ''  
   ,  @n_ErrGroupKey          INT          = 0  OUTPUT                                                                                                                          
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt               INT = @@TRANCOUNT  
         ,  @n_Continue                INT = 1

         ,  @n_Cnt                     INT = 0
         ,  @n_RowRef_OH               INT = 0
         ,  @n_RowRef_OD               INT = 0 
         ,  @n_RowRef_RH               INT = 0
         ,  @n_RowRef_RD               INT = 0   
         ,  @n_RowRef_OH_Last          INT = 0 
         ,  @n_RowRef_CL               INT = 0

         ,  @n_ReceiptLineNumber       INT = 0

         ,  @c_SQL                     NVARCHAR(MAX)  = ''           --(Wan06)
         ,  @c_SQL1                    NVARCHAR(MAX)  = ''           --(Wan06)
         ,  @c_SQLParms                NVARCHAR(4000) = ''

         ,  @c_SQLSchema               NVARCHAR(4000) = ''
         ,  @c_TableColumns_Select     NVARCHAR(4000) = ''
         ,  @c_TableColumns            NVARCHAR(4000) = ''
         ,  @c_Table                   NVARCHAR(60) = ''
         
         ,  @c_TempTableName           NVARCHAR(50) = ''             --(Wan03) 

         ,  @c_TableName               NVARCHAR(50)   = 'RECEIPTDETAIL'
         ,  @c_SourceType              NVARCHAR(50)   = 'lsp_ASN_PopulateSOs_Wrapper'
         ,  @c_WriteType               NVARCHAR(10)   = ''

         ,  @c_DBName                  NVARCHAR(30)   = ''   
         ,  @c_ArchiveDB               NVARCHAR(30)   = ''
         ,  @c_IsArch                  CHAR(1)        = 'N' 

         ,  @c_Facility                NVARCHAR(5)    = ''
         ,  @c_Storerkey               NVARCHAR(15)   = ''
         ,  @c_ExternReceiptkey        NVARCHAR(30)   = ''
         ,  @c_DocType                 NVARCHAR(10)   = ''
         ,  @c_Rectype                 NVARCHAR(10)   = ''
         ,  @c_WarehouseReference      NVARCHAR(18)   = ''
         ,  @c_Carrierkey              NVARCHAR(15)   = ''
         ,  @c_CarrierName             NVARCHAR(45)   = ''           --(Wan06)       
         ,  @c_CarrierAddress1         NVARCHAR(45)   = ''
         ,  @c_CarrierAddress2         NVARCHAR(45)   = ''
         ,  @c_CarrierCity             NVARCHAR(45)   = ''
         ,  @c_CarrierState            NVARCHAR(45)   = ''
         ,  @c_CarrierZip              NVARCHAR(10)   = ''

         ,  @c_UserDefine01            NVARCHAR(30)   = ''
         ,  @c_UserDefine02            NVARCHAR(30)   = ''
         ,  @c_UserDefine03            NVARCHAR(30)   = ''
         ,  @c_UserDefine04            NVARCHAR(30)   = ''
         ,  @c_UserDefine05            NVARCHAR(30)   = ''
         ,  @dt_UserDefine06           DATETIME       
         ,  @dt_UserDefine07           DATETIME
         ,  @c_UserDefine08            NVARCHAR(30)   = ''
         ,  @c_UserDefine09            NVARCHAR(30)   = ''
         ,  @c_UserDefine10            NVARCHAR(30)   = ''

         ,  @c_OD_UserDefine06         NVARCHAR(30)   = ''
         ,  @c_OD_UserDefine07         NVARCHAR(30)   = ''

         ,  @c_ToLoc                   NVARCHAR(10)   = ''
         ,  @c_PutawayLoc              NVARCHAR(10)   = ''

         ,  @c_Orderkey                NVARCHAR(10)   = '' 
         ,  @c_ExternOrderkey          NVARCHAR(30)   = ''
         ,  @c_Consigneekey            NVARCHAR(15)   = ''
         ,  @c_OrderLineNumber         NVARCHAR(5)   = ''
         ,  @c_Sku                     NVARCHAR(20)   = ''
         ,  @c_SubReasonCode           NVARCHAR(10)   = ''
         ,  @c_Lottable01              NVARCHAR(18)   = ''  
         ,  @c_Lottable02              NVARCHAR(18)   = ''  
         ,  @c_Lottable03              NVARCHAR(18)   = ''  
         ,  @dt_Lottable04             DATETIME       = NULL  
         ,  @dt_Lottable05             DATETIME       = NULL  
         ,  @c_Lottable06              NVARCHAR(30)   = ''  
         ,  @c_Lottable07              NVARCHAR(30)   = ''  
         ,  @c_Lottable08              NVARCHAR(30)   = ''  
         ,  @c_Lottable09              NVARCHAR(30)   = ''  
         ,  @c_Lottable10              NVARCHAR(30)   = ''  
         ,  @c_Lottable11              NVARCHAR(30)   = ''  
         ,  @c_Lottable12              NVARCHAR(30)   = ''  
         ,  @dt_Lottable13             DATETIME       = NULL  
         ,  @dt_Lottable14             DATETIME       = NULL  
         ,  @dt_Lottable15             DATETIME       = NULL  

         ,  @c_ReceiptLoc              NVARCHAR(10)   = ''
         ,  @c_ReturnLoc               NVARCHAR(10)   = ''
         ,  @c_XDockReceiptLoc         NVARCHAR(10)   = ''

         ,  @c_ColName                 NVARCHAR(30)   = ''
         ,  @c_DefaultValue            NVARCHAR(250)  = ''

         ,  @c_SourceKey               NVARCHAR(50)   = ''  
         ,  @c_SourceType_LARule       NVARCHAR(50)   = ''
         ,  @c_ListName                NVARCHAR(10)   = ''  
         ,  @c_SPName                  NVARCHAR(60)   = ''  
         ,  @c_UDF01                   NVARCHAR(60)   = ''  
         ,  @c_LottableLabel           NVARCHAR(20)   = ''  
         ,  @c_Lottable01Label         NVARCHAR(20)   = ''  
         ,  @c_Lottable02Label         NVARCHAR(20)   = ''  
         ,  @c_Lottable03Label         NVARCHAR(20)   = ''  
         ,  @c_Lottable04Label         NVARCHAR(20)   = ''  
         ,  @c_Lottable05Label         NVARCHAR(20)   = ''  
         ,  @c_Lottable06Label         NVARCHAR(20)   = ''  
         ,  @c_Lottable07Label         NVARCHAR(20)   = ''  
         ,  @c_Lottable08Label         NVARCHAR(20)   = ''  
         ,  @c_Lottable09Label         NVARCHAR(20)   = ''  
         ,  @c_Lottable10Label         NVARCHAR(20)   = ''  
         ,  @c_Lottable11Label         NVARCHAR(20)   = ''  
         ,  @c_Lottable12Label         NVARCHAR(20)   = ''  
         ,  @c_Lottable13Label         NVARCHAR(20)   = ''  
         ,  @c_Lottable14Label         NVARCHAR(20)   = ''  
         ,  @c_Lottable15Label         NVARCHAR(20)   = ''  
         ,  @c_LottableValue           NVARCHAR(18)   = ''  
         ,  @dt_LottableValue          DATETIME       = NULL  
         ,  @c_Lottable01Value         NVARCHAR(18)   = ''  
         ,  @c_Lottable02Value         NVARCHAR(18)   = ''  
         ,  @c_Lottable03Value         NVARCHAR(18)   = ''  
         ,  @dt_Lottable04Value        DATETIME       = NULL  
         ,  @dt_Lottable05Value        DATETIME       = NULL  
         ,  @c_Lottable06Value         NVARCHAR(30)   = ''  
         ,  @c_Lottable07Value         NVARCHAR(30)   = ''  
         ,  @c_Lottable08Value         NVARCHAR(30)   = ''  
         ,  @c_Lottable09Value         NVARCHAR(30)   = ''  
         ,  @c_Lottable10Value         NVARCHAR(30)   = ''  
         ,  @c_Lottable11Value         NVARCHAR(30)   = ''  
         ,  @c_Lottable12Value         NVARCHAR(30)   = ''  
         ,  @dt_Lottable13Value        DATETIME       = NULL  
         ,  @dt_Lottable14Value        DATETIME       = NULL  
         ,  @dt_Lottable15Value        DATETIME       = NULL  
         ,  @c_Lottable01ReturnValue   NVARCHAR(18)   = ''  
         ,  @c_Lottable02ReturnValue   NVARCHAR(18)   = ''  
         ,  @c_Lottable03ReturnValue   NVARCHAR(18)   = ''  
         ,  @dt_Lottable04ReturnValue  DATETIME       = NULL  
         ,  @dt_Lottable05ReturnValue  DATETIME       = NULL  
         ,  @c_Lottable06ReturnValue   NVARCHAR(30)   = ''  
         ,  @c_Lottable07ReturnValue   NVARCHAR(30)   = ''  
         ,  @c_Lottable08ReturnValue   NVARCHAR(30)   = ''  
         ,  @c_Lottable09ReturnValue   NVARCHAR(30)   = ''  
         ,  @c_Lottable10ReturnValue   NVARCHAR(30)   = ''  
         ,  @c_Lottable11ReturnValue   NVARCHAR(30)   = ''  
         ,  @c_Lottable12ReturnValue   NVARCHAR(30)   = ''  
         ,  @dt_Lottable13ReturnValue  DATETIME       = NULL  
         ,  @dt_Lottable14ReturnValue  DATETIME       = NULL  
         ,  @dt_Lottable15ReturnValue  DATETIME       = NULL 

         ,  @c_DefaultRcptLOC          NVARCHAR(30)   = ''
         ,  @c_ByPassAutoSubReaseon    NVARCHAR(30)   = ''
         ,  @c_GenConsignee2Carrierkey NVARCHAR(30)   = ''
         ,  @c_TRPopulateLot01         NVARCHAR(30)   = ''   
         ,  @c_TRPopulateLot03         NVARCHAR(30)   = ''
         ,  @c_TRPopulateLot06         NVARCHAR(30)   = ''
         ,  @c_TRPopulateLot07         NVARCHAR(30)   = ''
         ,  @c_TRPopulateLot08         NVARCHAR(30)   = ''
         ,  @c_TRPopulateLot09         NVARCHAR(30)   = ''
         ,  @c_TRPopulateLot10         NVARCHAR(30)   = ''
         ,  @c_TRPopulateLot11         NVARCHAR(30)   = ''
         ,  @c_TRPopulateLot12         NVARCHAR(30)   = ''
         ,  @c_TRPopulateLot13         NVARCHAR(30)   = ''
         ,  @c_TRPopulateLot14         NVARCHAR(30)   = ''
         ,  @c_TRPopulateLot15         NVARCHAR(30)   = ''

         ,  @CUR_SCHEMA                CURSOR
         ,  @CUR_ORD                   CURSOR

   DECLARE @tCODELKUP TABLE
         (  RowRef         INT   IDENTITY(1,1) Primary Key
         ,  ColName        NVARCHAR(30)  NULL DEFAULT('')
         ,  DefaultValue   NVARCHAR(250) NULL DEFAULT('')
         )

   SET @b_Success = 1
   SET @n_Err     = 0

   IF SUSER_SNAME() <> @c_UserName  --(Wan02)
   BEGIN
      EXEC [WM].[lsp_SetUser] 
            @c_UserName = @c_UserName  OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                   
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END 

      EXECUTE AS LOGIN = @c_UserName
   END         --(Wan02)
   BEGIN TRY   --(Wan01) 
      SET @n_ErrGroupKey = 0

      SET @c_Facility = ''
      SET @c_Storerkey= ''
      SELECT @c_Facility = RH.Facility
            ,@c_Storerkey= RH.Storerkey
            ,@c_ExternReceiptkey = ISNULL(RH.ExternReceiptKey,'')
            ,@c_DocType  = RH.DocType
            ,@c_Rectype  = RH.RecType
            ,@c_WarehouseReference = ISNULL(RH.WarehouseReference,'')
            ,@c_Carrierkey      = ISNULL(RH.Carrierkey,'')
            ,@c_CarrierName     = ISNULL(RH.CarrierName,'')             --(Wan06)
            ,@c_CarrierAddress1 = ISNULL(RH.CarrierAddress1,'')
            ,@c_CarrierAddress2 = ISNULL(RH.CarrierAddress2,'')
            ,@c_CarrierCity     = ISNULL(RH.CarrierCity,'')
            ,@c_CarrierState    = ISNULL(RH.CarrierState,'')
            ,@c_CarrierZip      = ISNULL(RH.CarrierZip,'')
            ,@c_UserDefine01    = ISNULL(RH.UserDefine01,'')
            ,@c_UserDefine02    = ISNULL(RH.UserDefine02,'')
            ,@c_UserDefine03    = ISNULL(RH.UserDefine03,'')
            ,@c_UserDefine04    = ISNULL(RH.UserDefine04,'')
            ,@c_UserDefine05    = ISNULL(RH.UserDefine05,'')
            ,@dt_UserDefine06   = RH.UserDefine06
            ,@dt_UserDefine07   = RH.UserDefine07
            ,@c_UserDefine08    = ISNULL(RH.UserDefine08,'')
            ,@c_UserDefine09    = ISNULL(RH.UserDefine09,'')
            ,@c_UserDefine10    = ISNULL(RH.UserDefine10,'')
      FROM RECEIPT RH WITH (NOLOCK)
      WHERE RH.ReceiptKey = @c_ReceiptKey

      /*-------------------------------------------------------*/
      /* BUILD TEMP TABLES & INSERT DATA - START               */
      /*-------------------------------------------------------*/
      IF OBJECT_ID('tempdb..#tSO', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tSO
      END 

      CREATE TABLE #tSO 
         (  RowRef         INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
         ,  OrderRefKey    NVARCHAR(10)   NOT NULL DEFAULT('')
         )

      INSERT INTO #tSO (OrderRefKey)
      SELECT DISTINCT T.[Value] FROM string_split (@c_OrderkeyList, '|') T
      
      IF OBJECT_ID('tempdb..#tRECEIPT', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tRECEIPT
      END  

      IF OBJECT_ID('tempdb..#tRECEIPTDETAIL', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tRECEIPTDETAIL
      END 

      IF OBJECT_ID('tempdb..#tORDERS', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tORDERS
      END  

      IF OBJECT_ID('tempdb..#tORDERDETAIL', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tORDERDETAIL
      END 
   
      IF OBJECT_ID('tempdb..#tPICKDETAIL', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tPICKDETAIL
      END   

      IF OBJECT_ID('tempdb..#tLOTATTRIBUTE', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tLOTATTRIBUTE
      END  

      CREATE TABLE #tRECEIPT (RowRef INT IDENTITY(1,1) PRIMARY KEY)   
      CREATE TABLE #tRECEIPTDETAIL (RowRef INT IDENTITY(1,1) PRIMARY KEY)
      CREATE TABLE #tORDERS (RowRef INT IDENTITY(1,1) PRIMARY KEY)
      CREATE TABLE #tORDERDETAIL (RowRef INT IDENTITY(1,1) PRIMARY KEY)
      CREATE TABLE #tPICKDETAIL (RowRef INT IDENTITY(1,1) PRIMARY KEY)
      CREATE TABLE #tLOTATTRIBUTE (RowRef INT IDENTITY(1,1) PRIMARY KEY)

      SET @CUR_SCHEMA = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Tab.Table_Name
      FROM INFORMATION_SCHEMA.TABLES Tab WITH (NOLOCK)
      WHERE Tab.Table_Name IN ('ORDERS', 'ORDERDETAIL', 'RECEIPT', 'RECEIPTDETAIL', 'PICKDETAIL', 'LOTATTRIBUTE')
      ORDER BY CASE WHEN Tab.Table_Name = 'ORDERS' THEN 2
                    WHEN Tab.Table_Name = 'ORDERDETAIL' THEN 4
                    WHEN Tab.Table_Name = 'RECEIPT' THEN 6
                    WHEN Tab.Table_Name = 'RECEIPTDETAIL' THEN 8
                    WHEN Tab.Table_Name = 'PICKDETAIL'    THEN 10
                    WHEN Tab.Table_Name = 'LOTATTRIBUTE'  THEN 12
                    END
      OPEN @CUR_SCHEMA

      FETCH NEXT FROM @CUR_SCHEMA INTO @c_Table

      WHILE @@FETCH_STATUS <> - 1
      BEGIN
         SET @c_SQLSchema = ''
         --(Wan03) - START
         SET @c_TempTableName = '#t' + @c_Table
         EXEC isp_BuildTmpTableColFrTable                                                                                                                    
            @c_TempTableName    =  @c_TempTableName
         ,  @c_OrginalTableName =  @c_Table             
         ,  @c_TableColumnNames =  @c_TableColumns_Select   OUTPUT
         ,  @c_ColumnNames      =  @c_TableColumns          OUTPUT 

         /*
         SET @c_SQLSchema  = RTRIM(ISNULL(CONVERT(NVARCHAR(4000), 
                              ( SELECT 
                              col.column_name 
                              + ' ' 
                              + col.data_type 
                              + CASE WHEN col.data_type = 'nvarchar' THEN '( ' + CAST(Col.CHARACTER_MAXIMUM_LENGTH AS NVARCHAR)+ ' )' 
                                     WHEN col.data_type = 'numeric'  THEN '(15,5)' 
                                     ELSE '' 
                                     END
                              + CASE WHEN col.data_type = 'timstamp' THEN '' ELSE ' NULL,' END 
                              FROM INFORMATION_SCHEMA.COLUMNS Col WITH (NOLOCK)
                              WHERE Table_Name = @c_Table
                              ORDER BY Col.ORDINAL_POSITION
                              FOR XML PATH(''), TYPE 
                              )
                             ),''))  

         IF @c_SQLSchema <> '' AND @c_Table <> ''
         BEGIN
            SET @c_SQLSchema = SUBSTRING(@c_SQLSchema, 1, LEN(@c_SQLSchema) - 1) 
            SET @c_SQL = N'ALTER TABLE #t' + @c_Table + ' ADD ' + @c_SQLSchema

            EXEC sp_ExecuteSQL @c_SQL
         END
         */
         --(Wan03) - END
         SET @c_TableColumns_Select = ''
         SET @c_TableColumns_Select = RTRIM(ISNULL(CONVERT(NVARCHAR(4000), 
                              (  SELECT TABLE_NAME + '.' + col.column_name + ','
                                 FROM INFORMATION_SCHEMA.COLUMNS Col WITH (NOLOCK)
                                 WHERE Table_Name = @c_Table
                                 ORDER BY Col.ORDINAL_POSITION
                                 FOR XML PATH(''), TYPE 
                              )
                              ),''))  


         IF @c_TableColumns_Select <> ''
         BEGIN
            SET @c_TableColumns_Select = SUBSTRING(@c_TableColumns_Select, 1, LEN(@c_TableColumns_Select) - 1) 
         END

         SET @c_TableColumns = ''
         SET @c_TableColumns = RTRIM(ISNULL(CONVERT(NVARCHAR(4000), 
                              (  SELECT col.column_name + ','
                                 FROM INFORMATION_SCHEMA.COLUMNS Col WITH (NOLOCK)
                                 WHERE Table_Name = @c_Table
                                 ORDER BY Col.ORDINAL_POSITION
                                 FOR XML PATH(''), TYPE 
                              )
                              ),''))  

         IF @c_TableColumns <> ''
         BEGIN
            SET @c_TableColumns = SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1) 
         END

         IF @c_Table = 'ORDERS' AND @c_TableColumns <> ''
         BEGIN
            SET @c_SQL = N'INSERT INTO #tORDERS ( ' + @c_TableColumns + ' )'
            SET @c_SQL1= N' SELECT ' + @c_TableColumns_Select 
                        + ' FROM #tSO T' 
                        + ' JOIN ' + RTRIM(@c_DBName) + 'dbo.ORDERS ORDERS WITH (NOLOCK) ON (T.OrderRefKey = ORDERS.Orderkey) '
                        + ' WHERE ORDERS.[Status] = ''9''' 
                        + ' AND EXISTS (  SELECT 1 FROM ' + RTRIM(@c_DBName) + 'dbo.ORDERDETAIL OD WITH (NOLOCK)'
                        +               ' WHERE OD.OrderKey = ORDERS.OrderKey'
                        +               ' AND OD.ShippedQty > 0 )'

            EXEC ( @c_SQL + @c_SQL1 )
         END

         IF @c_Table = 'ORDERDETAIL'  AND @c_TableColumns <> ''
         BEGIN
            SET @c_SQL = N'INSERT INTO #tORDERDETAIL  (' + @c_TableColumns + ')'
                        + ' SELECT ' + @c_TableColumns_Select 
                        + ' FROM #tSO T'
                        + ' JOIN ' + RTRIM(@c_DBName) + 'dbo.ORDERDETAIL WITH (NOLOCK)'
                        +                               ' ON T.OrderRefKey= ORDERDETAIL.Orderkey'
                        + ' WHERE ORDERDETAIL.ShippedQty > 0'
                        + ' ORDER BY ORDERDETAIL.OrderKey, ORDERDETAIL.OrderLineNumber'
            EXEC sp_ExecuteSQL @c_SQL
         END

         IF @c_Table = 'PICKDETAIL' AND @c_TableColumns <> ''
         BEGIN
            SET @c_SQL = N'INSERT INTO #tPICKDETAIL  (' + @c_TableColumns + ')'
                        + ' SELECT ' + @c_TableColumns_Select 
                        + ' FROM #tORDERDETAIL RD'
                        + ' JOIN ' + RTRIM(@c_DBName) + 'dbo.PICKDETAIL PICKDETAIL WITH (NOLOCK)'
                        +                               ' ON RD.Orderkey= PICKDETAIL.Orderkey'
                        +                               ' AND RD.OrderLineNumber = PICKDETAIL.OrderLineNumber'

            EXEC sp_ExecuteSQL @c_SQL
 
         END

         IF @c_Table = 'LOTATTRIBUTE' AND @c_TableColumns <> ''
         BEGIN
            SET @c_SQL = N'INSERT INTO #tLOTATTRIBUTE  (' + @c_TableColumns + ')'
                        + ' SELECT ' + @c_TableColumns_Select 
                        + ' FROM #tPICKDETAIL PD'
                        + ' JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.Lot= PD.Lot'
       
            EXEC sp_ExecuteSQL @c_SQL
         END

         FETCH NEXT FROM @CUR_SCHEMA INTO @c_Table
      END
      CLOSE @CUR_SCHEMA
      DEALLOCATE @CUR_SCHEMA
   
      /*-------------------------------------------------------*/
      /* BUILD TEMP TABLES & INSERT DATA - END                 */
      /*-------------------------------------------------------*/

      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo < 1
      BEGIN
         IF NOT EXISTS (SELECT 1
                        FROM #tORDERS OH WITH (NOLOCK) 
                        )
         BEGIN
            SET @n_Continue = 3
            SET @n_Err      = 558901
            SET @c_errmsg   = 'No Order to found to populate. (lsp_ASN_PopulateSOs_Wrapper)'

            EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_Receiptkey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = ''
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success   
            ,  @n_err         = @n_err       
            ,  @c_errmsg      = @c_errmsg    
         END 

         IF EXISTS ( SELECT 1
                     FROM #tORDERS OH WITH (NOLOCK) 
                     WHERE OH.Facility <> @c_Facility
                     OR OH.Storerkey <> @c_Storerkey
                   )
         BEGIN
            SET @n_Continue = 3
            SET @n_Err      = 558902
            SET @c_errmsg   = 'Found Mismatch facility & Storerkey between Orders and Receipt. (lsp_ASN_PopulateSOs_Wrapper)'

            EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_Receiptkey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = ''
            ,  @c_WriteType   = 'ERROR' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success   
            ,  @n_err         = @n_err       
            ,  @c_errmsg      = @c_errmsg    
         END 

         IF @n_Continue = 3
         BEGIN
            GOTO EXIT_SP
         END
      END 
    
     -- Get Storerconfig
      SET @c_GenConsignee2Carrierkey= dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'GenConsigneekey2Carrierkey')
      SET @c_ByPassAutoSubReaseon   = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ByPassAutoSubReaseon')
      SET @c_DefaultRcptLOC         = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'DefaultRcptLOC')  
      SET @c_TRPopulateLot01        = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'TRPOPULATELOT01')  
      SET @c_TRPopulateLot03        = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'TRPOPULATELOT03')  
      SET @c_TRPopulateLot06        = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'TRPOPULATELOT06')  
      SET @c_TRPopulateLot07        = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'TRPOPULATELOT07') 
      SET @c_TRPopulateLot08        = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'TRPOPULATELOT08') 
      SET @c_TRPopulateLot09        = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'TRPOPULATELOT09') 
      SET @c_TRPopulateLot10        = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'TRPOPULATELOT10') 
      SET @c_TRPopulateLot11        = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'TRPOPULATELOT11')
      SET @c_TRPopulateLot12        = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'TRPOPULATELOT12')
      SET @c_TRPopulateLot13        = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'TRPOPULATELOT13')
      SET @c_TRPopulateLot14        = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'TRPOPULATELOT14')
      SET @c_TRPopulateLot15        = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'TRPOPULATELOT15')

      SET @c_SubReasonCode = 'GRN'
      IF @c_ByPassAutoSubReaseon = '1' 
      BEGIN
         SET @c_SubReasonCode = ''
      END

      IF @c_DefaultRcptLOC <> ''
      BEGIN
         SELECT @c_ToLoc = Loc 
         FROM LOC (NOLOCK) 
         WHERE LOC = @c_DefaultRcptLOC
      END 

      SELECT TOP 1 
            @n_RowRef_OH_Last = OH.RowRef
      FROM #tORDERS OH
      WHERE OH.RowRef > @n_RowRef_OH
      ORDER BY OH.RowRef DESC

      SET @n_RowRef_OH = 0
      WHILE 1 = 1
      BEGIN
         SELECT TOP 1 
                 @n_RowRef_OH  = OH.RowRef
               , @c_Orderkey   = OH.Orderkey
               , @c_Consigneekey   = ISNULL(OH.Consigneekey,'')
               , @c_ExternOrderkey = ISNULL(OH.ExternOrderkey,'')
               , @c_UserDefine01   = ISNULL(OH.UserDefine01,'')         --(Wan05) Found Not Populate From Orders as Exceed             
               , @c_UserDefine02   = ISNULL(OH.UserDefine02,'')         --(Wan05) Found Not Populate From Orders as Exceed
               , @c_UserDefine03   = ISNULL(OH.UserDefine03,'')         --(Wan05) Found Not Populate From Orders as Exceed
               , @c_UserDefine04   = ISNULL(OH.UserDefine04,'')         --(Wan05) Found Not Populate From Orders as Exceed
               , @c_UserDefine05   = ISNULL(OH.UserDefine05,'')         --(Wan05) Found Not Populate From Orders as Exceed
               , @dt_UserDefine06  = OH.UserDefine06                    --(Wan05) Found Not Populate From Orders as Exceed
               , @dt_UserDefine07  = OH.UserDefine07                    --(Wan05) Found Not Populate From Orders as Exceed
               , @c_UserDefine08   = ISNULL(OH.UserDefine08,'')         --(Wan05) Found Not Populate From Orders as Exceed
               , @c_UserDefine09   = ISNULL(OH.UserDefine09,'')         --(Wan05) Found Not Populate From Orders as Exceed
               , @c_UserDefine10   = ISNULL(OH.UserDefine10,'')         --(Wan05) Found Not Populate From Orders as Exceed  
         FROM #tORDERS OH
         WHERE OH.RowRef > @n_RowRef_OH
         ORDER BY OH.RowRef 

         IF @@ROWCOUNT = 0 OR @n_RowRef_OH = 0
         BEGIN
            BREAK
         END

         IF @n_RowRef_OH = @n_RowRef_OH_Last 
         BEGIN
            IF @c_GenConsignee2Carrierkey = '1'  
            BEGIN
               --IF @c_Consigneekey <> ''                                        --(Wan06) - START
               --BEGIN
                  SET @c_Carrierkey = @c_Consigneekey  
                  SET @c_CarrierName     = ''                                      
                  SET @c_CarrierAddress1 = ''
                  SET @c_CarrierAddress2 = ''
                  SET @c_CarrierCity     = ''
                  SET @c_CarrierState    = ''
                  SET @c_CarrierZip      = ''                        
                  SELECT 
                         @c_CarrierName     = ISNULL(ST.Company,'')               
                     ,   @c_CarrierAddress1 = ISNULL(ST.Address1,'')
                     ,   @c_CarrierAddress2 = ISNULL(ST.Address2,'')
                     ,   @c_CarrierCity     = ISNULL(ST.City,'')
                     ,   @c_CarrierState    = ISNULL(ST.[State],'')
                     ,   @c_CarrierZip      = ISNULL(ST.Zip,'')
                  FROM STORER ST WITH (NOLOCK)
                  WHERE ST.Storerkey = @c_Consigneekey 
               --END                                                             --(Wan06) - END 
            END
            ELSE
            BEGIN
               SELECT @c_Carrierkey = ISNULL(MH.CarrierAgent,'')
               FROM ORDERS OH WITH (NOLOCK)
               JOIN MBOLDETAIL MD WITH (NOLOCK) ON OH.Orderkey = MD.Orderkey
               JOIN MBOL MH  WITH (NOLOCK) ON MH.MbolKey = MD.MbolKey
               WHERE OH.Orderkey = @c_Orderkey
            END
         END

         SET @c_ExternReceiptkey = CASE WHEN @c_ExternReceiptkey = '' THEN @c_ExternOrderkey
                                        WHEN @c_ExternReceiptkey <> @c_ExternOrderkey THEN ''
                                        ELSE @c_ExternReceiptkey
                                        END
         IF NOT EXISTS (SELECT 1 FROM #tRECEIPT)
         BEGIN                                 
            INSERT INTO #tRECEIPT
               ( ReceiptKey  
               , Storerkey  
               , Facility  
               , ExternReceiptkey  
               , RecType  
               , DocType  
               , WarehouseReference  
               , Carrierkey   
               , CarrierName                                         --(Wan06)
               , CarrierAddress1   
               , CarrierAddress2   
               , CarrierCity   
               , CarrierState
               , CarrierZip
               , UserDefine01
               , UserDefine02
               , UserDefine03
               , UserDefine04
               , UserDefine05
               , UserDefine06
               , UserDefine07
               , UserDefine08
               , UserDefine09
               , UserDefine10
               , POkey
                  )  
            SELECT
                 Receiptkey= @c_Receiptkey 
               , Storerkey = @c_Storerkey  
               , Facility  = @c_Facility  
               , ExternReceiptkey = @c_ExternReceiptkey
               , RecType   = @c_Rectype  
               , DocType   = @c_Doctype  
               , WarehouseReference = @c_WarehouseReference   
               , Carrierkey         = @c_Carrierkey 
               , CarrierName        = @c_CarrierName                 --(Wan06)
               , CarrierAddress1    = @c_CarrierAddress1
               , CarrierAddress2    = @c_CarrierAddress2
               , CarrierCity        = @c_CarrierCity
               , CarrierState       = @c_CarrierState
               , CarrierZip         = @c_CarrierZip
               , UserDefine01       = @c_UserDefine01
               , UserDefine02       = @c_UserDefine02
               , UserDefine03       = @c_UserDefine03
               , UserDefine04       = @c_UserDefine04
               , UserDefine05       = @c_UserDefine05
               , UserDefine06       = @dt_UserDefine06
               , UserDefine07       = @dt_UserDefine07
               , UserDefine08       = @c_UserDefine08
               , UserDefine09       = @c_UserDefine09
               , UserDefine10       = @c_UserDefine10
               , POKey              = @c_Orderkey
         
            SET @n_RowRef_RH = @@IDENTITY  
         END
         ELSE
         BEGIN
            UPDATE #tRECEIPT 
               SET  ExternReceiptkey   = @c_ExternReceiptkey
                  , Carrierkey         = @c_Carrierkey
                  , CarrierName        = @c_CarrierName              --(Wan06) 
                  , CarrierAddress1    = @c_CarrierAddress1
                  , CarrierAddress2    = @c_CarrierAddress2
                  , CarrierCity        = @c_CarrierCity
                  , CarrierState       = @c_CarrierState
                  , CarrierZip         = @c_CarrierZip
                  , POKey              = @c_Orderkey
                  , UserDefine01       = @c_UserDefine01             --(Wan05) Found Not Populate From Orders as Exceed
                  , UserDefine02       = @c_UserDefine02             --(Wan05) Found Not Populate From Orders as Exceed
                  , UserDefine03       = @c_UserDefine03             --(Wan05) Found Not Populate From Orders as Exceed
                  , UserDefine04       = @c_UserDefine04             --(Wan05) Found Not Populate From Orders as Exceed
                  , UserDefine05       = @c_UserDefine05             --(Wan05) Found Not Populate From Orders as Exceed
                  , UserDefine06       = @dt_UserDefine06            --(Wan05) Found Not Populate From Orders as Exceed
                  , UserDefine07       = @dt_UserDefine07            --(Wan05) Found Not Populate From Orders as Exceed
                  , UserDefine08       = @c_UserDefine08             --(Wan05) Found Not Populate From Orders as Exceed
                  , UserDefine09       = @c_UserDefine09             --(Wan05) Found Not Populate From Orders as Exceed
                  , UserDefine10       = @c_UserDefine10             --(Wan05) Found Not Populate From Orders as Exceed     
            WHERE RowRef = @n_RowRef_RH
         END
     
         SET @n_RowRef_OD = 0
         WHILE 1 = 1
         BEGIN
            SELECT Top 1
                   @n_RowRef_OD    = OD.RowRef
                  ,@c_Sku          = OD.Sku
                  ,@c_OD_UserDefine06 = CASE WHEN ISDATE(OD.UserDefine06) = 1 THEN OD.UserDefine06 ELSE NULL END
                  ,@c_OD_UserDefine07 = CASE WHEN ISDATE(OD.UserDefine07) = 1 THEN OD.UserDefine07 ELSE NULL END
            FROM #tORDERDETAIL OD
            WHERE OD.OrderKey = @c_Orderkey
            AND OD.RowRef > @n_RowRef_OD
            ORDER BY OD.RowRef
         
            IF @@ROWCOUNT = 0 OR @n_RowRef_OD = 0
            BEGIN
               BREAK
            END
   
            SET @c_ReceiptLoc = ''  
            SET @c_ReturnLoc  = ''  
            SET @c_XDockReceiptLoc = ''  
  
            SELECT @c_ReceiptLoc = ISNULL(ReceiptLoc,'')  
                  ,@c_ReturnLoc  = ISNULL(ReturnLoc,'')  
                  ,@c_XDockReceiptLoc = ISNULL(XDockReceiptLoc,'')  
            FROM SKU WITH (NOLOCK)  
            WHERE Storerkey = @c_Storerkey  
            AND Sku = @c_Sku  
  
            SET @c_Toloc = CASE WHEN @c_Doctype = 'A' AND  @c_ReceiptLoc <> '' THEN @c_ReceiptLoc  
                                WHEN @c_Doctype = 'R' AND  @c_ReturnLoc  <> '' THEN @c_ReturnLoc 
                                WHEN @c_DocType = 'X' AND  @c_XDockReceiptLoc <> ''THEN @c_XDockReceiptLoc 
                                ELSE ''  
                                END  

            INSERT INTO #tRECEIPTDETAIL
               (  ReceiptKey
               ,  ReceiptLineNumber
               ,  Storerkey  
               ,  Sku
               ,  AltSku
               ,  Packkey  
               ,  UOM
               ,  QtyExpected
               ,  FreeGoodQtyExpected
               ,  ToLoc
               ,  ToID
               ,  PutawayLoc  
               ,  ExternReceiptKey
               ,  POKey
               ,  POLineNumber
               ,  ExternPOKey
               ,  ExternLineNo
               ,  Vesselkey
               ,  Voyagekey
               ,  Lottable01
               ,  Lottable02
               ,  Lottable03
               ,  Lottable04
               ,  Lottable05
               ,  Lottable06
               ,  Lottable07
               ,  Lottable08
               ,  Lottable09
               ,  Lottable10
               ,  Lottable11
               ,  Lottable12
               ,  Lottable13
               ,  Lottable14
               ,  Lottable15
               ,  UserDefine01 
               ,  UserDefine02   
               ,  UserDefine03
               ,  UserDefine04   
               ,  UserDefine05 
               ,  UserDefine06   
               ,  UserDefine07
               ,  UserDefine08  
               ,  UserDefine09
               ,  UserDefine10 
               ,  SubReasonCode
               ,  Channel
               )
            SELECT
                  @c_ReceiptKey
               ,  @n_RowRef_OD      --Since Receiptlineumber not used, stored #TORderdetail.rowref to get orderkey and orderlinenumber later 
               ,  OD.Storerkey  
               ,  OD.Sku
               ,  AltSku = ISNULL(OD.ManufacturerSku,'')                  
               ,  OD.Packkey            
               ,  OD.UOM               
               ,  QtyExpected = ISNULL(SUM(PD.Qty),0)
               ,  FreeGoodQtyExpected = 0
               ,  ToLoc = @c_ToLoc
               ,  ToID  = ''
               ,  PutawayLoc = @c_Putawayloc
               ,  ExternReceiptkey = @c_ExternReceiptkey
               ,  POKey = ''             
               ,  POLineNumber = ''
               ,  ExternPOKey = ISNULL(OD.ExternPOKey,'')
               ,  ExternLineNo= ISNULL(OD.ExternLineNo,'')
               ,  Vesselkey = ''
               ,  Voyagekey = ''
               ,  Lottable01 = CASE WHEN @c_TRPopulateLot01 = '1' THEN ISNULL(LA.Lottable01,'') ELSE '' END
               ,  Lottable02 = ISNULL(LA.Lottable02,'')
               ,  Lottable03 = ISNULL(LA.Lottable03,'')
               ,  LA.Lottable04
               ,  NULL
               ,  Lottable06  = CASE WHEN @c_TRPopulateLot06 = '1' THEN ISNULL(LA.Lottable06,'') ELSE '' END
               ,  Lottable07  = CASE WHEN @c_TRPopulateLot07 = '1' THEN ISNULL(LA.Lottable07,'') ELSE '' END
               ,  Lottable08  = CASE WHEN @c_TRPopulateLot08 = '1' THEN ISNULL(LA.Lottable08,'') ELSE '' END
               ,  Lottable09  = CASE WHEN @c_TRPopulateLot09 = '1' THEN ISNULL(LA.Lottable09,'') ELSE '' END
               ,  Lottable10  = CASE WHEN @c_TRPopulateLot10 = '1' THEN ISNULL(LA.Lottable10,'') ELSE '' END
               ,  Lottable11  = CASE WHEN @c_TRPopulateLot11 = '1' THEN ISNULL(LA.Lottable11,'') ELSE '' END
               ,  Lottable12  = CASE WHEN @c_TRPopulateLot12 = '1' THEN ISNULL(LA.Lottable12,'') ELSE '' END
               ,  Lottable13  = CASE WHEN @c_TRPopulateLot13 = '1' THEN ISNULL(LA.Lottable13,'') ELSE '' END
               ,  Lottable14  = CASE WHEN @c_TRPopulateLot14 = '1' THEN ISNULL(LA.Lottable14,'') ELSE '' END
               ,  Lottable15  = CASE WHEN @c_TRPopulateLot15 = '1' THEN ISNULL(LA.Lottable15,'') ELSE '' END
               ,  UserDefine01 = ISNULL(OD.UserDefine01,'') 
               ,  UserDefine02 = ISNULL(OD.UserDefine02,'')   
               ,  UserDefine03 = ISNULL(OD.UserDefine03,'')
               ,  UserDefine04 = ISNULL(OD.UserDefine04,'')   
               ,  UserDefine05 = ISNULL(OD.UserDefine05,'') 
               ,  UserDefine06 = @c_OD_UserDefine06
               ,  UserDefine07 = @c_OD_UserDefine07 
               ,  UserDefine08 = ISNULL(OD.UserDefine08,'')  
               ,  UserDefine09 = ISNULL(OD.UserDefine09,'')
               ,  ''
               ,  SubReasonCode = @c_SubReasonCode
               ,  Channel = ISNULL(OD.Channel,'') 
            FROM #tORDERDETAIL OD 
            JOIN #tPICKDETAIL PD  ON OD.Orderkey = PD.Orderkey
                                  AND OD.OrderLineNumber = PD.OrderLineNumber
            JOIN #tLOTATTRIBUTE LA ON PD.Lot = LA.Lot
            WHERE OD.RowRef = @n_RowRef_OD
            GROUP BY OD.Storerkey  
               ,  OD.Sku
               ,  ISNULL(OD.ManufacturerSku,'')                  
               ,  OD.Packkey           
               ,  OD.UOM  
               ,  ISNULL(OD.ExternPOKey,'')              
               ,  ISNULL(OD.ExternLineNo,'')
               ,  ISNULL(LA.Lottable01,'')
               ,  ISNULL(LA.Lottable02,'')
               ,  ISNULL(LA.Lottable03,'')
               ,  LA.Lottable04
               ,  ISNULL(LA.Lottable06,'')
               ,  ISNULL(LA.Lottable07,'')
               ,  ISNULL(LA.Lottable08,'')
               ,  ISNULL(LA.Lottable09,'')
               ,  ISNULL(LA.Lottable10,'')
               ,  ISNULL(LA.Lottable11,'')
               ,  ISNULL(LA.Lottable12,'')
               ,  LA.Lottable13
               ,  LA.Lottable14
               ,  LA.Lottable15
               ,  ISNULL(OD.UserDefine01,'') 
               ,  ISNULL(OD.UserDefine02,'')   
               ,  ISNULL(OD.UserDefine03,'')
               ,  ISNULL(OD.UserDefine04,'')   
               ,  ISNULL(OD.UserDefine05,'') 
               ,  ISNULL(OD.UserDefine08,'')  
               ,  ISNULL(OD.UserDefine09,'')
               ,  ISNULL(OD.Channel,'') 
         END
      END

      -- Call Default Value for Return ONLY- END - START
      IF @c_DocType = 'R'
      BEGIN
         INSERT INTO @tCODELKUP ( ColName, DefaultValue )
         SELECT ColName = CL.Code
            ,   DefaultValue = ISNULL(CL.Long,'')
         FROM CODELKUP CL (NOLOCK) 
         WHERE CL.ListName = 'RTNDETDEF'
         AND  CL.Storerkey = @c_Storerkey

         IF NOT EXISTS ( SELECT 1 FROM @tCODELKUP )
         BEGIN
            INSERT INTO @tCODELKUP ( ColName, DefaultValue )
            SELECT ColName = CL.Code
               ,   DefaultValue = ISNULL(CL.Long,'')
            FROM CODELKUP CL (NOLOCK) 
            WHERE CL.ListName = 'RTNDETDEF'
         END

         SET @n_RowRef_CL = 0
         WHILE 1 = 1
         BEGIN
            SELECT TOP 1                                 --(Wan04)
                   @n_RowRef_CL     = T.RowRef
                  ,@c_ColName       = T.ColName
                  ,@c_DefaultValue  = T.DefaultValue
            FROM @tCODELKUP T 
            WHERE T.RowRef > @n_RowRef_CL 
            ORDER BY T.RowRef

            IF @@ROWCOUNT = 0 OR @n_RowRef_CL = 0
            BEGIN
               BREAK
            END

            SET @c_SQL = N'UPDATE #tRECEIPTDETAIL SET ' + @c_ColName + ' = @c_DefaultValue '
            SET @c_SQLParms = N'@c_DefaultValue NVARCHAR(250)'
          
            EXEC sp_ExecuteSQL  @c_SQL
                              , @c_SQLParms
                              , @c_DefaultValue    
         END
      END
      -- Call Default Value - END

      -- Get Sku Lottables - START
      SET @c_Sku = ''
      WHILE 1 = 1
      BEGIN 
         SELECT TOP 1 @c_Sku = RD.Sku
         FROM #tRECEIPTDETAIL RD
         WHERE RD.Sku > @c_Sku
         GROUP BY RD.Sku
         ORDER BY RD.SKU 

         IF @@ROWCOUNT = 0 OR @c_Sku = ''
         BEGIN
            BREAK
         END

         SELECT @c_Lottable01Label = ISNULL(Lottable01Label,'')  
               ,@c_Lottable02Label = ISNULL(Lottable02Label,'')  
               ,@c_Lottable03Label = ISNULL(Lottable03Label,'')  
               ,@c_Lottable04Label = ISNULL(Lottable04Label,'')  
               ,@c_Lottable05Label = ISNULL(Lottable05Label,'')  
               ,@c_Lottable06Label = ISNULL(Lottable06Label,'')  
               ,@c_Lottable07Label = ISNULL(Lottable07Label,'')  
               ,@c_Lottable08Label = ISNULL(Lottable08Label,'')  
               ,@c_Lottable09Label = ISNULL(Lottable09Label,'')  
               ,@c_Lottable10Label = ISNULL(Lottable10Label,'')  
               ,@c_Lottable11Label = ISNULL(Lottable11Label,'')  
               ,@c_Lottable12Label = ISNULL(Lottable12Label,'')  
               ,@c_Lottable13Label = ISNULL(Lottable13Label,'')  
               ,@c_Lottable14Label = ISNULL(Lottable14Label,'')  
               ,@c_Lottable15Label = ISNULL(Lottable15Label,'')  
         FROM SKU WITH (NOLOCK)  
         WHERE Storerkey = @c_Storerkey  
         AND Sku = @c_Sku  

         SET @n_RowRef_RD = 0
         WHILE 1 = 1
         BEGIN
            SELECT TOP 1 @n_RowRef_RD = RD.RowRef
                  ,@n_RowRef_OD   = CONVERT( INT, RD.ReceiptLineNumber )
                  ,@c_Lottable01  = RD.Lottable01  
                  ,@c_Lottable02  = RD.Lottable02  
                  ,@c_Lottable03  = RD.Lottable03  
                  ,@dt_Lottable04 = RD.Lottable04  
                  ,@dt_Lottable05 = RD.Lottable05  
                  ,@c_Lottable06  = RD.Lottable06  
                  ,@c_Lottable07  = RD.Lottable07  
                  ,@c_Lottable08  = RD.Lottable08  
                  ,@c_Lottable09  = RD.Lottable09  
                  ,@c_Lottable10  = RD.Lottable10  
                  ,@c_Lottable11  = RD.Lottable11  
                  ,@c_Lottable12  = RD.Lottable12  
                  ,@dt_Lottable13 = RD.Lottable13  
                  ,@dt_Lottable14 = RD.Lottable14  
                  ,@dt_Lottable15 = RD.Lottable15  
            FROM #tRECEIPTDETAIL RD
            WHERE RD.Sku = @c_Sku
            AND   RD.RowRef > @n_RowRef_RD
            ORDER BY RD.RowRef

            IF @@ROWCOUNT = 0 OR @n_RowRef_RD = 0
            BEGIN
               BREAK
            END

            SELECT @c_Orderkey = OD.RowRef
                  ,@c_OrderLineNumber = OD.OrderLineNumber
            FROM #tORDERDETAIL OD 
            WHERE OD.RowRef = @n_RowRef_OD

            SET @c_Lottable01Value = @c_Lottable01  
            SET @c_Lottable02Value = @c_Lottable02  
            SET @c_Lottable03Value = @c_Lottable03  
            SET @dt_Lottable04Value= @dt_Lottable04  
            SET @dt_Lottable05Value= @dt_Lottable05   
            SET @c_Lottable06Value = @c_Lottable06  
            SET @c_Lottable07Value = @c_Lottable07  
            SET @c_Lottable08Value = @c_Lottable08  
            SET @c_Lottable09Value = @c_Lottable09  
            SET @c_Lottable10Value = @c_Lottable10  
            SET @c_Lottable11Value = @c_Lottable11  
            SET @c_Lottable12Value = @c_Lottable12  
            SET @dt_Lottable13Value= @dt_Lottable13  
            SET @dt_Lottable14Value= @dt_Lottable14  
            SET @dt_Lottable15Value= @dt_Lottable15  

            SET @n_Cnt = 1  
            WHILE @n_Cnt <= 15  
            BEGIN  
               SET @c_ListName      = CASE WHEN @n_Cnt = 1  THEN 'Lottable01'  
                                           WHEN @n_Cnt = 2  THEN 'Lottable02'  
                                           WHEN @n_Cnt = 3  THEN 'Lottable03'  
                                           WHEN @n_Cnt = 4  THEN 'Lottable04'  
                                           WHEN @n_Cnt = 5  THEN 'Lottable05'  
                                           WHEN @n_Cnt = 6  THEN 'Lottable06'  
                                           WHEN @n_Cnt = 7  THEN 'Lottable07'  
                                           WHEN @n_Cnt = 8  THEN 'Lottable08'  
                                           WHEN @n_Cnt = 10 THEN 'Lottable10'  
                                           WHEN @n_Cnt = 11 THEN 'Lottable11'  
                                           WHEN @n_Cnt = 12 THEN 'Lottable12'  
                                           WHEN @n_Cnt = 13 THEN 'Lottable13'  
                                           WHEN @n_Cnt = 14 THEN 'Lottable14'  
                                           WHEN @n_Cnt = 15 THEN 'Lottable15'  
                                           END  
  
               SET @c_LottableValue = CASE WHEN @n_Cnt = 1  THEN @c_Lottable01  
                                           WHEN @n_Cnt = 2  THEN @c_Lottable02  
                                           WHEN @n_Cnt = 3  THEN @c_Lottable03  
                                           WHEN @n_Cnt = 6  THEN @c_Lottable06  
                                           WHEN @n_Cnt = 7  THEN @c_Lottable07  
                                           WHEN @n_Cnt = 8  THEN @c_Lottable08  
                                           WHEN @n_Cnt = 10 THEN @c_Lottable10  
                                           WHEN @n_Cnt = 11 THEN @c_Lottable11  
                                           WHEN @n_Cnt = 12 THEN @c_Lottable12  
                                           ELSE ''  
                                           END  
               SET @dt_LottableValue =CASE WHEN @n_Cnt = 4  THEN @dt_Lottable04  
                                           WHEN @n_Cnt = 5  THEN @dt_Lottable05  
                                           WHEN @n_Cnt = 13 THEN @dt_Lottable13  
                                           WHEN @n_Cnt = 14 THEN @dt_Lottable14  
                                           WHEN @n_Cnt = 15 THEN @dt_Lottable15  
                                           ELSE NULL  
                                           END  
  
               SET @c_LottableLabel = CASE WHEN @n_Cnt = 1  THEN @c_Lottable01Label  
                                                    WHEN @n_Cnt = 2  THEN @c_Lottable02Label  
                                                    WHEN @n_Cnt = 3  THEN @c_Lottable03Label  
                                                    WHEN @n_Cnt = 4  THEN @c_Lottable04Label  
                                                    WHEN @n_Cnt = 5  THEN @c_Lottable05Label  
                                                    WHEN @n_Cnt = 6  THEN @c_Lottable06Label  
                                                    WHEN @n_Cnt = 7  THEN @c_Lottable07Label  
                                                    WHEN @n_Cnt = 8  THEN @c_Lottable08Label  
                                                    WHEN @n_Cnt = 10 THEN @c_Lottable10Label  
                                                    WHEN @n_Cnt = 11 THEN @c_Lottable11Label  
                                                    WHEN @n_Cnt = 12 THEN @c_Lottable12Label  
                                                    WHEN @n_Cnt = 13 THEN @c_Lottable13Label  
                                                    WHEN @n_Cnt = 14 THEN @c_Lottable14Label  
                                                    WHEN @n_Cnt = 15 THEN @c_Lottable15Label  
                                                    END  
               SET @c_SPName = ''  
               SET @c_UDF01 = ''  
               IF (@n_Cnt IN (1,2,3,6,7,8,9,10,11,12) AND @c_LottableValue = '') OR  
                  (@n_Cnt IN (4,5,13,14,15) AND (@dt_LottableValue = '1900-01-01' OR @dt_LottableValue IS NULL))  
               BEGIN  
                  SELECT TOP 1   
                           @c_SPName = ISNULL(CL.Long,'')    
                        ,  @c_UDF01  = ISNULL(CL.UDF01,'')        
                  FROM CODELKUP CL WITH (NOLOCK)  
                  WHERE CL.ListName = @c_ListName  
                  AND CL.Code = @c_LottableLabel  
                  AND CL.Short IN ('PRE', 'BOTH')    
                  AND ((CL.Storerkey = @c_Storerkey AND @c_Storerkey <> '') OR (CL.Storerkey = ''))  
                  ORDER BY CL.Storerkey DESC      
               END    
  
               IF  @c_SPName <> '' AND EXISTS (SELECT 1 FROM SYS.Objects WHERE Name = @c_SPName AND [Type] = 'p')  
               BEGIN  
                  SET @c_SourceKey = @c_ReceiptKey + CONVERT(NVARCHAR(5), @n_RowRef_RD) 
                  SET @c_SourceType_LARule = CASE WHEN @c_DocType = 'A' THEN 'RECEIPT'  
                                                  WHEN @c_DocType = 'R' THEN 'TRADERETURN'  
                                                  WHEN @c_DocType = 'X' THEN 'XDOCK'   
                                                  END  
                  BEGIN TRY  
                     SET @b_Success = 1  
                     EXEC dbo.ispLottableRule_Wrapper   
                           @c_SPName            = @c_SPName  
                        ,  @c_Listname          = @c_Listname  
                        ,  @c_Storerkey         = @c_Storerkey  
                        ,  @c_Sku               = @c_Sku  
                        ,  @c_LottableLabel     = @c_LottableLabel  
                        ,  @c_Lottable01Value   = @c_Lottable01Value   
                        ,  @c_Lottable02Value   = @c_Lottable02Value   
                        ,  @c_Lottable03Value   = @c_Lottable03Value   
                        ,  @dt_Lottable04Value  = @dt_Lottable04Value  
                        ,  @dt_Lottable05Value  = @dt_Lottable05Value  
                        ,  @c_Lottable06Value   = @c_Lottable06Value   
                        ,  @c_Lottable07Value   = @c_Lottable07Value   
                        ,  @c_Lottable08Value   = @c_Lottable08Value   
                        ,  @c_Lottable09Value   = @c_Lottable09Value   
                        ,  @c_Lottable10Value   = @c_Lottable10Value   
                        ,  @c_Lottable11Value   = @c_Lottable11Value   
                        ,  @c_Lottable12Value   = @c_Lottable12Value   
                        ,  @dt_Lottable13Value  = @dt_Lottable13Value  
                        ,  @dt_Lottable14Value  = @dt_Lottable14Value  
                        ,  @dt_Lottable15Value  = @dt_Lottable15Value  
                        ,  @c_Lottable01        = @c_Lottable01ReturnValue OUTPUT  
                        ,  @c_Lottable02        = @c_Lottable02ReturnValue    OUTPUT  
                        ,  @c_Lottable03        = @c_Lottable03ReturnValue    OUTPUT  
                        ,  @dt_Lottable04       = @dt_Lottable04ReturnValue   OUTPUT  
                        ,  @dt_Lottable05       = @dt_Lottable05ReturnValue   OUTPUT  
                        ,  @c_Lottable06        = @c_Lottable06ReturnValue    OUTPUT  
                        ,  @c_Lottable07        = @c_Lottable07ReturnValue    OUTPUT  
                        ,  @c_Lottable08        = @c_Lottable08ReturnValue    OUTPUT  
                        ,  @c_Lottable09        = @c_Lottable09ReturnValue    OUTPUT  
                        ,  @c_Lottable10        = @c_Lottable10ReturnValue    OUTPUT  
                        ,  @c_Lottable11        = @c_Lottable11ReturnValue    OUTPUT  
                        ,  @c_Lottable12        = @c_Lottable12ReturnValue    OUTPUT  
                        ,  @dt_Lottable13       = @dt_Lottable13ReturnValue   OUTPUT  
                        ,  @dt_Lottable14       = @dt_Lottable14ReturnValue   OUTPUT  
                        ,  @dt_Lottable15       = @dt_Lottable15ReturnValue   OUTPUT  
                        ,  @b_Success           = @b_Success                  OUTPUT    
                        ,  @n_err               = @n_err                      OUTPUT                                                                                                               
                        ,  @c_ErrMsg            = @c_ErrMsg                   OUTPUT   
                        ,  @c_SourceKey         = @c_SourceKey                    
                        ,  @c_SourceType        = @c_SourceType_LARule                       
                  END TRY  
                  BEGIN CATCH  
                     SET @n_Err = 558903  
                     SET @c_ErrMsg = ERROR_MESSAGE()  
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing ispLottableRule_Wrapper. (lsp_ASN_PopulateSOs_Wrapper)'     
                                    + '(' + @c_ErrMsg + ')'   
                  END CATCH  
  
                  IF @b_Success = 0 OR @n_Err <> 0  
                  BEGIN  
                     SET @n_Continue = 3  
  
                     EXEC [WM].[lsp_WriteError_List]   
                           @i_iErrGroupKey= @n_ErrGroupKey OUTPUT   
                        ,  @c_TableName   = @c_TableName  
                        ,  @c_SourceType  = @c_SourceType  
                        ,  @c_Refkey1     = @c_Receiptkey  
                        ,  @c_Refkey2     = @c_OrderKey  
                        ,  @c_Refkey3     = @c_OrderLineNumber
                        ,  @c_WriteType   = 'ERROR'   
                        ,  @n_err2        = @n_err   
                        ,  @c_errmsg2     = @c_errmsg   
                        ,  @b_Success     = @b_Success     
                        ,  @n_err         = @n_err         
                        ,  @c_errmsg      = @c_errmsg     
  
                     GOTO EXIT_SP  
                  END  
  
                  IF @n_Cnt = 1    
                     SET @c_Lottable01 = @c_Lottable01ReturnValue  
                  IF @n_Cnt = 2    
                     SET @c_Lottable02 = @c_Lottable02ReturnValue  
                  IF @n_Cnt = 3   
                     SET @c_Lottable03 = @c_Lottable03ReturnValue  
                  IF @n_Cnt = 4    
                     SET @dt_Lottable04= @dt_Lottable04ReturnValue  
                  IF @n_Cnt = 5    
                     SET @dt_Lottable05= @dt_Lottable05ReturnValue  
                  IF @n_Cnt = 6    
                     SET @c_Lottable06 = @c_Lottable06ReturnValue  
                  IF @n_Cnt = 7    
                     SET @c_Lottable07 = @c_Lottable07ReturnValue  
                  IF @n_Cnt = 8   
                     SET @c_Lottable08 = @c_Lottable08ReturnValue  
                  IF @n_Cnt = 9   
                     SET @c_Lottable09 = @c_Lottable09ReturnValue  
                  IF @n_Cnt = 10   
                     SET @c_Lottable10 = @c_Lottable10ReturnValue  
                  IF @n_Cnt = 11    
                     SET @c_Lottable11 = @c_Lottable11ReturnValue  
                  IF @n_Cnt = 12    
                     SET @c_Lottable12 = @c_Lottable12ReturnValue  
                  IF @n_Cnt = 13    
                     SET @dt_Lottable13= @dt_Lottable13ReturnValue  
                  IF @n_Cnt = 14    
                     SET @dt_Lottable14= @dt_Lottable14ReturnValue  
                  IF @n_Cnt = 15    
                     SET @dt_Lottable15= @dt_Lottable15ReturnValue  
               END  
              
               SET @n_Cnt = @n_Cnt + 1   
            END  
           
            SET @c_Lottable01   = ISNULL(@c_Lottable01,'')    
            SET @c_Lottable02   = ISNULL(@c_Lottable02,'')   
            SET @c_Lottable03   = ISNULL(@c_Lottable03,'')   
            SET @c_Lottable06   = ISNULL(@c_Lottable06,'')    
            SET @c_Lottable07   = ISNULL(@c_Lottable07,'')    
            SET @c_Lottable08   = ISNULL(@c_Lottable08,'')    
            SET @c_Lottable09   = ISNULL(@c_Lottable09,'')    
            SET @c_Lottable10   = ISNULL(@c_Lottable10,'')    
            SET @c_Lottable11   = ISNULL(@c_Lottable11,'')    
            SET @c_Lottable12   = ISNULL(@c_Lottable12,'')  
         
            UPDATE #tRECEIPTDETAIL 
               SET Lottable01 = @c_Lottable01 
               ,   Lottable02 = @c_Lottable02
               ,   Lottable03 = @c_Lottable03
               ,   Lottable04 = @dt_Lottable04
               ,   Lottable05 = @dt_Lottable05
               ,   Lottable06 = @c_Lottable06
               ,   Lottable07 = @c_Lottable07
               ,   Lottable08 = @c_Lottable08
               ,   Lottable09 = @c_Lottable09
               ,   Lottable10 = @c_Lottable10
               ,   Lottable11 = @c_Lottable11
               ,   Lottable12 = @c_Lottable12
               ,   Lottable13 = @dt_Lottable13
               ,   Lottable14 = @dt_Lottable14
               ,   Lottable15 = @dt_Lottable15
            WHERE RowRef = @n_RowRef_RD
         END
      END
      -- Get Sku Lottables - END

      --Update Data to RECEIPT & RECEITPTDETAIL - START  
      BEGIN TRAN   
      BEGIN TRY
         UPDATE RECEIPT 
            SET ExternReceiptKey = T.ExternReceiptKey
               ,CarrierKey       = T.Carrierkey
               , CarrierName     = T.CarrierName                     --(Wan06) 
               ,CarrierAddress1  = T.CarrierAddress1
               ,CarrierAddress2  = T.CarrierAddress2
               ,CarrierCity      = T.CarrierCity
               ,CarrierState     = T.CarrierState
               ,CarrierZip       = T.CarrierZip
               ,POKey            = T.POKey                     --(Wan05)
               ,UserDefine01     = T.UserDefine01              --(Wan05) Found Not Populate From Orders as Exceed
               ,UserDefine02     = T.UserDefine02              --(Wan05) Found Not Populate From Orders as Exceed
               ,UserDefine03     = T.UserDefine03              --(Wan05) Found Not Populate From Orders as Exceed
               ,UserDefine04     = T.UserDefine04              --(Wan05) Found Not Populate From Orders as Exceed
               ,UserDefine05     = T.UserDefine05              --(Wan05) Found Not Populate From Orders as Exceed
               ,UserDefine06     = T.UserDefine06              --(Wan05) Found Not Populate From Orders as Exceed
               ,UserDefine07     = T.UserDefine07              --(Wan05) Found Not Populate From Orders as Exceed
               ,UserDefine08     = T.UserDefine08              --(Wan05) Found Not Populate From Orders as Exceed
               ,UserDefine09     = T.UserDefine09              --(Wan05) Found Not Populate From Orders as Exceed
               ,UserDefine10     = T.UserDefine10              --(Wan05) Found Not Populate From Orders as Exceed                 
         FROM #tRECEIPT T
         JOIN RECEIPT ON T.Receiptkey = RECEIPT.Receiptkey
      END TRY

      BEGIN CATCH
         IF @@TRANCOUNT > 0
         BEGIN
            ROLLBACK TRAN
         END

         WHILE @@TRANCOUNT < @n_StartTCnt
         BEGIN
            BEGIN TRAN
         END

         SET @n_Continue = 3
         SET @n_Err = 558904
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': UPDATE RECEIPT Table Fail. (lsp_ASN_PopulateSOs_Wrapper)'   
                        + '(' + @c_ErrMsg + ')' 

         EXEC [WM].[lsp_WriteError_List] 
            @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
         ,  @c_TableName   = @c_TableName
         ,  @c_SourceType  = @c_SourceType
         ,  @c_Refkey1     = @c_Receiptkey
         ,  @c_Refkey2     = ''
         ,  @c_Refkey3     = ''
         ,  @c_WriteType   = @c_WriteType
         ,  @n_err2        = @n_err 
         ,  @c_errmsg2     = @c_errmsg 
         ,  @b_Success     = @b_Success   
         ,  @n_err         = @n_err       
         ,  @c_errmsg      = @c_errmsg  
               
         GOTO EXIT_SP
      END CATCH

      SET @n_ReceiptLineNumber = 0
      SELECT TOP 1 @n_ReceiptLineNumber = CONVERT(INT, RD.ReceiptLineNumber)
      FROM RECEIPTDETAIL RD WITH (NOLOCK)
      WHERE RD.ReceiptKey = @c_ReceiptKey
      ORDER BY RD.ReceiptLineNumber DESC

      BEGIN TRY
         INSERT INTO RECEIPTDETAIL
               (  ReceiptKey
               ,  ReceiptLineNumber
               ,  Storerkey  
               ,  Sku
               ,  AltSku
               ,  Packkey  
               ,  UOM
               ,  QtyExpected
               ,  FreeGoodQtyExpected
               ,  ToLoc
               ,  ToID
               ,  PutawayLoc  
               ,  ExternReceiptKey
               ,  POKey
               ,  POLineNumber
               ,  ExternPOKey
               ,  ExternLineNo
               ,  Vesselkey
               ,  Voyagekey
               ,  Lottable01
               ,  Lottable02
               ,  Lottable03
               ,  Lottable04
               ,  Lottable05
               ,  Lottable06
               ,  Lottable07
               ,  Lottable08
               ,  Lottable09
               ,  Lottable10
               ,  Lottable11
               ,  Lottable12
               ,  Lottable13
               ,  Lottable14
               ,  Lottable15
               ,  UserDefine01 
               ,  UserDefine02   
               ,  UserDefine03
               ,  UserDefine04   
               ,  UserDefine05 
               ,  UserDefine06   
               ,  UserDefine07
               ,  UserDefine08  
               ,  UserDefine09
               ,  UserDefine10 
               ,  SubReasonCode 
               ,  Channel
               )
         SELECT   T.ReceiptKey
               ,  ReceiptLineNumber = RIGHT( '00000' + CONVERT( NVARCHAR(5), @n_ReceiptLineNumber + RowRef ), 5 )
               ,  T.Storerkey  
               ,  T.Sku
               ,  T.AltSku
               ,  T.Packkey  
               ,  T.UOM
               ,  T.QtyExpected
               ,  T.FreeGoodQtyExpected
               ,  T.ToLoc
               ,  T.ToID
               ,  T.PutawayLoc  
               ,  T.ExternReceiptKey
               ,  T.POKey
               ,  T.POLineNumber
               ,  T.ExternPOKey
               ,  T.ExternLineNo
               ,  T.Vesselkey
               ,  T.Voyagekey
               ,  T.Lottable01
               ,  T.Lottable02
               ,  T.Lottable03
               ,  T.Lottable04
               ,  T.Lottable05
               ,  T.Lottable06
               ,  T.Lottable07
               ,  T.Lottable08
               ,  T.Lottable09
               ,  T.Lottable10
               ,  T.Lottable11
               ,  T.Lottable12
               ,  T.Lottable13
               ,  T.Lottable14
               ,  T.Lottable15
               ,  T.UserDefine01 
               ,  T.UserDefine02   
               ,  T.UserDefine03
               ,  T.UserDefine04   
               ,  T.UserDefine05 
               ,  T.UserDefine06   
               ,  T.UserDefine07
               ,  T.UserDefine08  
               ,  T.UserDefine09
               ,  T.UserDefine10 
               ,  T.SubReasonCode 
               ,  T.Channel
         FROM #tRECEIPTDETAIL T
         ORDER BY T.RowRef
      END TRY
      BEGIN CATCH
         IF @@TRANCOUNT > 0
         BEGIN
            ROLLBACK TRAN
         END

         WHILE @@TRANCOUNT < @n_StartTCnt
         BEGIN
            BEGIN TRAN
         END

         SET @n_Continue = 3
         SET @n_Err = 558905
         SET @c_ErrMsg = ERROR_MESSAGE()

         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': INSERT RECEIPTDETAIL Table Fail. (lsp_ASN_PopulateSOs_Wrapper)'   
                        + '(' + @c_ErrMsg + ')' 

         EXEC [WM].[lsp_WriteError_List] 
            @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
         ,  @c_TableName   = @c_TableName
         ,  @c_SourceType  = @c_SourceType
         ,  @c_Refkey1     = @c_Receiptkey
         ,  @c_Refkey2     = ''
         ,  @c_Refkey3     = ''
         ,  @c_WriteType   = @c_WriteType
         ,  @n_err2        = @n_err 
         ,  @c_errmsg2     = @c_errmsg 
         ,  @b_Success     = @b_Success   
         ,  @n_err         = @n_err       
         ,  @c_errmsg      = @c_errmsg  
               
         GOTO EXIT_SP
      END CATCH
      --Update Data to RECEIPT & RECEITPTDETAIL - END 

      IF @n_Continue = 3
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > 0
         COMMIT TRAN
      END
   END TRY

   BEGIN CATCH
      SET @n_continue = 3
      SET @c_ErrMsg = 'Populate SO fail. (lsp_ASN_PopulateSOs_Wrapper) ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '
      GOTO EXIT_SP
   END CATCH   --(Wan01) - END
EXIT_SP:
   IF OBJECT_ID('tempdb..#tRECEIPT', 'U') IS NOT NULL                --(Wan06) - START
   BEGIN
      DROP TABLE #tRECEIPT
   END  

   IF OBJECT_ID('tempdb..#tRECEIPTDETAIL', 'U') IS NOT NULL
   BEGIN
      DROP TABLE #tRECEIPTDETAIL
   END 

   IF OBJECT_ID('tempdb..#tORDERS', 'U') IS NOT NULL
   BEGIN
      DROP TABLE #tORDERS
   END  

   IF OBJECT_ID('tempdb..#tORDERDETAIL', 'U') IS NOT NULL
   BEGIN
      DROP TABLE #tORDERDETAIL
   END 
   
   IF OBJECT_ID('tempdb..#tPICKDETAIL', 'U') IS NOT NULL
   BEGIN
      DROP TABLE #tPICKDETAIL
   END   

   IF OBJECT_ID('tempdb..#tLOTATTRIBUTE', 'U') IS NOT NULL
   BEGIN
      DROP TABLE #tLOTATTRIBUTE
   END                                                               --(Wan06) - START
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt             --(Wan06)
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_ASN_PopulateSOs_Wrapper'
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
         
   REVERT
END

GO