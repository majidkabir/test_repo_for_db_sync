SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_ASN_PopulateSODs_Wrapper                        */                                                                                  
/* Creation Date: 2020-11-01                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-2313 - UAT - TW  Populate from Order and Populate from */
/*          Order Detail are missing in Inbound module                  */
/*                                                                      */
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.4                                                   */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */ 
/* 2020-11-01  Wan      1.0   Created                                   */ 
/* 2020-11-30  Wan01    1.1   Fixed not Getting Default Value from Codelkup*/ 
/* 2020-12-03  Wan02    1.2   LFWM-2474 - PROD  Australia  Qty Expected */
/*                            is incorrect and addwho was changed to    */
/*                            WMConnect                                 */
/* 15-Jan-2021 Wan03    1.3   Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2020-08-11  Wan04    1.4   LFWM-2962 - Populate Order details -Populate*/
/*                            SO Detail fail.                           */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_ASN_PopulateSODs_Wrapper]                                                                                                                     
      @c_ReceiptKey           NVARCHAR(10)         
   ,  @c_OrderKeyList         NVARCHAR(4000) = ''  -- Order Keys seperated by '|'; for eg '0000128313|0000128314|0000128314' => 0000128314 to twice as pass 2 orderlinenumber ; IF @c_WarningNo = 1, Get Overdue pass & Y response Orderkey & Line to pass to continue populate
   ,  @c_OrderLineNumberList  NVARCHAR(4000) = ''  -- OrderLineNumber seperated by '|'; for eg '00001|00001|00002'
   ,  @b_PopulateFromArchive  INT = 0              -- Pass in 1 if Populate ORderkey from Archive DB
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

         ,  @n_PopulatedOrderCnt       INT = 0
         ,  @n_ToPopulateOrderCnt      INT = 0
         ,  @n_PopulateReturnMaxOrder  INT = 0
         ,  @n_ReceiptLineNumber       INT = 0

         ,  @c_SQL                     NVARCHAR(4000) = ''
         ,  @c_SQL1                    NVARCHAR(4000) = ''
         ,  @c_SQLParms                NVARCHAR(4000) = ''

         ,  @c_SQLSchema               NVARCHAR(MAX) = ''
         ,  @c_TableColumns_Select     NVARCHAR(4000) = ''
         ,  @c_TableColumns            NVARCHAR(4000) = ''
         ,  @c_Table                   NVARCHAR(60) = ''
         ,  @c_TempTableName           NVARCHAR(50) = ''          --(Wan04)

         ,  @c_TableName               NVARCHAR(50)   = 'RECEIPTDETAIL'
         ,  @c_SourceType              NVARCHAR(50)   = 'lsp_ASN_PopulateSODs_Wrapper'
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
         ,  @c_CarrierAddress1         NVARCHAR(45)   = ''
         ,  @c_CarrierAddress2         NVARCHAR(45)   = ''
         ,  @c_CarrierCity             NVARCHAR(45)   = ''
         ,  @c_CarrierState            NVARCHAR(45)   = ''
         ,  @c_CarrierZip              NVARCHAR(10)   = ''

         ,  @c_OD_UserDefine06         NVARCHAR(30)   = ''
         ,  @c_OD_UserDefine07         NVARCHAR(30)   = ''

         ,  @c_ToLoc                   NVARCHAR(10)   = ''
         ,  @c_PutawayLoc              NVARCHAR(10)   = ''

         ,  @c_Orderkey                NVARCHAR(10)   = '' 
         ,  @c_ExternOrderkey          NVARCHAR(30)   = ''
         ,  @c_Consigneekey            NVARCHAR(15)   = ''
         ,  @c_OrderLineNumber         NVARCHAR(5)    = ''
         ,  @c_ExternPOKey             NVARCHAR(30)   = ''
         ,  @c_ExternLineNo            NVARCHAR(20)   = ''
         ,  @c_Sku                     NVARCHAR(20)   = ''
         ,  @c_Altsku                  NVARCHAR(20)   = ''  
         
         ,  @c_ColName                 NVARCHAR(30)   = ''
         ,  @c_DefaultValue            NVARCHAR(250)  = ''

         ,  @c_PopulateReturnMaxOrder  NVARCHAR(30)   = ''
         ,  @c_Overdue_Return_Alert    NVARCHAR(30)   = ''
         ,  @c_GenConsignee2Carrierkey NVARCHAR(30)   = ''
         ,  @c_DefaultReturnPickFace   NVARCHAR(30)   = ''
         ,  @c_OverdueMsg              NVARCHAR(255)  = ''

         ,  @CUR_SCHEMA                CURSOR
         ,  @CUR_ORD                   CURSOR

   DECLARE @tCODELKUP TABLE
         (  RowRef         INT   IDENTITY(1,1) Primary Key
         ,  ColName        NVARCHAR(30)  NULL DEFAULT('')
         ,  DefaultValue   NVARCHAR(250) NULL DEFAULT('')
         )

   SET @b_Success = 1
   SET @n_Err     = 0

   IF @b_PopulateFromArchive = 1 SET @c_IsArch = 'Y' 
               
   SET @n_Err = 0 
   IF SUSER_SNAME() <> @c_UserName       --(Wan03) - START
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
   END                                   --(Wan03) - END

   BEGIN TRY -- Wan01 - Begin Outer Begin Try
      SET @n_ErrGroupKey = 0

      IF @b_PopulateFromArchive = 1
      BEGIN
         SET @c_ArchiveDB = ''          
         SELECT @c_ArchiveDB = ISNULL(RTRIM(NSQLValue),'') 
         FROM NSQLCONFIG WITH (NOLOCK)          
         WHERE ConfigKey='ArchiveDBName' 
      
         IF @c_ArchiveDB <> '' 
         BEGIN
            SET @c_DBName = @c_ArchiveDB  + '.'
         END                     
      END

      SET @c_Facility = ''
      SET @c_Storerkey= ''
      SELECT @c_Facility = RH.Facility
            ,@c_Storerkey= RH.Storerkey
            ,@c_ExternReceiptkey = ISNULL(RH.ExternReceiptKey,'')
            ,@c_DocType  = RH.DocType
            ,@c_Rectype  = RH.RecType
            ,@c_WarehouseReference = ISNULL(RH.WarehouseReference,'')
            ,@c_Carrierkey      = ISNULL(RH.Carrierkey,'')
            ,@c_CarrierAddress1 = ISNULL(RH.CarrierAddress1,'')
            ,@c_CarrierAddress2 = ISNULL(RH.CarrierAddress2,'')
            ,@c_CarrierCity     = ISNULL(RH.CarrierCity,'')
            ,@c_CarrierState    = ISNULL(RH.CarrierState,'')
            ,@c_CarrierZip      = ISNULL(RH.CarrierZip,'')
      FROM RECEIPT RH WITH (NOLOCK)
      WHERE RH.ReceiptKey = @c_ReceiptKey

      IF @c_Rectype IN ('NORMAL', 'RPO', 'RRB', 'TBLRRP')     --Exceed not allow these type to populate by orderdetail
      BEGIN
         GOTO EXIT_SP
      END 

      /*-------------------------------------------------------*/
      /* BUILD TEMP TABLES & INSERT DATA - START               */
      /*-------------------------------------------------------*/
      DECLARE @tSOH TABLE 
         (  RowRef      INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
         ,  OrderRefKey NVARCHAR(10)   NOT NULL DEFAULT('')
         )
   
      INSERT INTO @tSOH (OrderRefKey)
      SELECT T.[Value] FROM string_split (@c_OrderkeyList, '|') T

      DECLARE @tSOD TABLE 
         (  RowRef         INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
         ,  OrderRefLineNo NVARCHAR(5)    NOT NULL DEFAULT('')
         )
   
      INSERT INTO @tSOD (OrderRefLineNo)
      SELECT T.[Value] FROM string_split (@c_OrderLineNumberList, '|') T

      IF OBJECT_ID('tempdb..#tSO', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tSO
      END 

      CREATE TABLE #tSO  
         (  RowRef         INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
         ,  OrderRefKey    NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  OrderRefLineNo NVARCHAR(5)    NOT NULL DEFAULT('')
         )

      INSERT INTO #tSO ( OrderRefKey, OrderRefLineNo )
      SELECT H.OrderRefKey
         ,   ISNULL(D.OrderRefLineNo,'')
      FROM @tSOH H
      LEFT JOIN @tSOD D ON H.RowRef = D.RowRef
      GROUP BY H.OrderRefKey
            ,  ISNULL(D.OrderRefLineNo,'')
      ORDER BY MIN(H.RowRef)


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
         --(Wan04) - START
         SET @c_TempTableName = '#t' + @c_Table
         EXEC isp_BuildTmpTableColFrTable                                                                                                                    
            @c_TempTableName    =  @c_TempTableName
         ,  @c_OrginalTableName =  @c_Table             
         ,  @c_TableColumnNames =  @c_TableColumns_Select   OUTPUT
         ,  @c_ColumnNames      =  @c_TableColumns          OUTPUT 
         /*
         SET @c_SQLSchema = ''
         SET @c_SQLSchema  = RTRIM(ISNULL(CONVERT(NVARCHAR(4000), 
                              ( SELECT 
                              col.column_name 
                              + ' ' 
                              + col.data_type 
                              + CASE WHEN col.data_type = 'nvarchar' THEN '( ' + CAST(Col.CHARACTER_MAXIMUM_LENGTH AS NVARCHAR)+ ' )' 
                                     WHEN col.data_type = 'numeric'  THEN '(15,5)' 
                                     ELSE '' 
                                     END
                              + CASE WHEN col.data_type = 'timestamp' THEN '' ELSE ' NULL,' END 
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
         */
         --(Wan04) - END         

         IF @c_Table = 'ORDERS' AND @c_TableColumns <> ''
         BEGIN
            SET @c_SQL = N'INSERT INTO #tORDERS ( ' + @c_TableColumns + ' )'
            SET @c_SQL1= N' SELECT ' + @c_TableColumns_Select 
                        + ' FROM ' + RTRIM(@c_DBName) + 'dbo.ORDERS ORDERS WITH (NOLOCK) '
                        + ' WHERE ORDERS.[Status] = ''9''' 
                        + ' AND EXISTS (  SELECT 1 FROM #tSO T' 
                        +               ' JOIN ' + RTRIM(@c_DBName) + 'dbo.ORDERDETAIL OD WITH (NOLOCK)'
                        +                               ' ON T.OrderRefKey = OD.Orderkey'
                        +                               ' AND T.OrderRefLineNo = OD.OrderLineNumber'
                        +               ' WHERE T.OrderRefKey = ORDERS.OrderKey ' 
                        +               ' AND OD.ShippedQty > 0)'
            EXEC ( @c_SQL + @c_SQL1 )
         END

         IF @c_Table = 'ORDERDETAIL'  AND @c_TableColumns <> ''
         BEGIN
            SET @c_SQL = N'INSERT INTO #tORDERDETAIL  (' + @c_TableColumns + ')'
                        + ' SELECT ' + @c_TableColumns_Select 
                        + ' FROM #tSO T'
                        + ' JOIN ' + RTRIM(@c_DBName) + 'dbo.ORDERDETAIL WITH (NOLOCK)'
                        +                               ' ON T.OrderRefKey= ORDERDETAIL.Orderkey'
                        +                               ' AND T.OrderRefLineNo = ORDERDETAIL.OrderLineNumber'
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
                        --(Wan02) - START
                        + ' FROM LOTATTRIBUTE WITH (NOLOCK)'                                          
                        + ' WHERE EXISTS (SELECT 1 FROM #tPICKDETAIL PD WHERE LOTATTRIBUTE.Lot= PD.Lot)'
                        --+ ' FROM #tPICKDETAIL PD'
                        --+ ' JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.Lot= PD.Lot'
                        --(Wan02) - END
       
            IF @b_PopulateFromArchive = 1
            BEGIN
               SET @c_SQL = @c_SQL + N' UNION '
                        + ' SELECT ' + @c_TableColumns_Select 
                        --(Wan02) - START
                        + ' FROM ' + RTRIM(@c_DBName) + 'dbo.LOTATTRIBUTE WITH (NOLOCK)'
                        + ' WHERE EXISTS (SELECT 1 FROM #tPICKDETAIL PD'
                        +               ' LEFT JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LA.Lot= PD.Lot'
                        +               ' WHERE LA.Lot IS NULL'
                        +               ' AND LOTATTRIBUTE.Lot= PD.Lot'
                        +               ' )'
                        --+ ' FROM #tPICKDETAIL PD'
                        --+ ' JOIN ' + RTRIM(@c_DBName) + 'dbo.LOTATTRIBUTE LOTATTRIBUTE WITH (NOLOCK)'
                        --+                               ' ON LOTATTRIBUTE.Lot= PD.Lot'
                        --+ ' LEFT JOIN LOTATTRIBUTE LA WITH (NOLOCK)'
                        --+                               ' ON LA.Lot= PD.Lot'
                        --+ ' WHERE LA.Lot IS NULL'
                        --(Wan02) - END

            END
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
            SET @n_Err      = 558851
            SET @c_errmsg   = 'No Order to found to populate. (lsp_ASN_PopulateSODs_Wrapper)'

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
            SET @n_Err      = 558852
            SET @c_errmsg   = 'Found Mismatch facility & Storerkey between Orders and Receipt. (lsp_ASN_PopulateSODs_Wrapper)'

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

         SELECT @c_PopulateReturnMaxOrder = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'PopulateReturnMaxOrder')
      
         IF ISNUMERIC(@c_PopulateReturnMaxOrder) = 1 
         BEGIN
            SET @n_PopulateReturnMaxOrder = CONVERT(INT, @c_PopulateReturnMaxOrder)
         END

         IF @n_PopulateReturnMaxOrder > 0
         BEGIN 
            SELECT @n_PopulatedOrderCnt = COUNT(DISTINCT OH.Orderkey)
            FROM RECEIPTDETAIL RD WITH (NOLOCK)
            JOIN ORDERS OH WITH (NOLOCK) ON  RD.ExternReceiptKey = OH.ExternOrderkey 
                                         AND RD.Storerkey = OH.Storerkey
            WHERE RD.ReceiptKey = @c_ReceiptKey 

            SELECT @n_ToPopulateOrderCnt = COUNT(DISTINCT T.OrderRefkey)
            FROM @tSOH T

            IF @n_PopulatedOrderCnt + @n_ToPopulateOrderCnt > @n_PopulateReturnMaxOrder
            BEGIN
               SET @n_Continue = 3
               SET @n_Err      = 558853
               SET @c_errmsg   = 'Access Max Order per receiptkey. (lsp_ASN_PopulateSODs_Wrapper)'

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
         END

         IF @n_Continue = 3
         BEGIN
            GOTO EXIT_SP
         END
      
         SELECT @c_Overdue_Return_Alert = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'Overdue_Return_Alert')

         IF @c_Overdue_Return_Alert = '1' 
         BEGIN
            SET @CUR_ORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RowRef
               ,   Orderkey  
            FROM   #tORDERS 
   
            OPEN @CUR_ORD
   
            FETCH NEXT FROM @CUR_ORD INTO @n_RowRef_OH, @c_Orderkey 
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SET @c_WriteType = ''
               SET @b_Success = 1
               SET @n_Err     = 0
               SET @c_ErrMsg  = ''
               SET @c_OverdueMsg = ''

               BEGIN TRY
                  EXEC isp_OverdueReturnAlert
                        @c_Storerkey= @c_Storerkey
                     ,  @c_Facility = @c_Facility
                     ,  @c_Orderkey = @c_Orderkey
                     ,  @c_IsArch   = @c_IsArch
                     ,  @b_Success  = @b_Success      OUTPUT
                     ,  @n_Err      = @n_Err          OUTPUT
                     ,  @c_ErrMsg   = @c_ErrMsg       OUTPUT
                     ,  @c_Option5  = @c_OverdueMsg   OUTPUT
               END TRY

               BEGIN CATCH
                  SET @b_Success = 0
                  --SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_OverdueReturnAlert'
                  --              + '. (lsp_ASN_PopulateSODs_Wrapper)'

                  IF (XACT_STATE()) = -1  
                  BEGIN
                     ROLLBACK TRAN

                     WHILE @@TRANCOUNT < @n_StartTCnt
                     BEGIN
                        BEGIN TRAN
                     END
                  END
               END CATCH

               IF @b_Success = 0 --AND @c_ErrMsg <> ''
               BEGIN
                  IF @c_OverdueMsg = ''
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_Err      = 558854
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_OverdueReturnAlert'
                                   + '. (lsp_ASN_PopulateSODs_Wrapper)' 
                                   + CASE WHEN @c_ErrMsg = '' THEN '' ELSE ' ( ' + @c_ErrMsg + ' )' END
                     SET @c_WriteType = 'ERROR'
                  END
                  ELSE IF @c_OverdueMsg <> ''
                  BEGIN
                     SET @n_WarningNo = 1
                     SET @c_WriteType = 'WARNING'
                     SET @c_ErrMsg = @c_OverdueMsg + '. Do you still want to populate?'
                  END 
               END
               ELSE
               BEGIN
                  SET @c_WriteType = 'PROCEED'
                  SET @c_ErrMsg = 'Overdue validation pass'
               END

               IF @c_WriteType <> ''
               BEGIN
                  SET @n_RowRef_OD = 0
                  WHILE 1 = 1
                  BEGIN
                     SET @c_OrderLineNumber = ''
                     SELECT TOP 1 
                             @n_RowRef_OD = OD.RowRef
                           , @c_OrderLineNumber = OD.OrderLineNumber
                     FROM #tORDERDETAIL OD
                     WHERE OD.RowRef > @n_RowRef_OD
                     AND   OD.Orderkey = @c_Orderkey
                     ORDER BY OD.RowRef 

                     IF @@ROWCOUNT = 0 OR @c_OrderLineNumber = ''
                     BEGIN
                        BREAK
                     END
                     EXEC [WM].[lsp_WriteError_List] 
                        @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
                     ,  @c_TableName   = @c_TableName
                     ,  @c_SourceType  = @c_SourceType
                     ,  @c_Refkey1     = @c_Receiptkey
                     ,  @c_Refkey2     = @c_Orderkey
                     ,  @c_Refkey3     = @c_OrderLineNumber
                     ,  @c_WriteType   = @c_WriteType
                     ,  @n_err2        = @n_err 
                     ,  @c_errmsg2     = @c_errmsg 
                     ,  @b_Success     = @b_Success   
                     ,  @n_err         = @n_err       
                     ,  @c_errmsg      = @c_errmsg  
                  END
               END
               FETCH NEXT FROM @CUR_ORD INTO @n_RowRef_OH, @c_Orderkey 
            END 
            CLOSE @CUR_ORD
            DEALLOCATE @CUR_ORD

            IF @n_WarningNo = 1
            BEGIN
               SET @n_Continue = 1
               GOTO EXIT_SP
            END

            IF NOT EXISTS (SELECT 1 FROM WM.WMS_Error_List (NOLOCK) Where ErrGroupKey = @n_ErrGroupKey AND WriteType = 'PROCEED')
            BEGIN
               SET @n_Continue = 3
               GOTO EXIT_SP
            END
         END
      END -- @n_WarningNo < 1

      -- Get Storerconfig
      SET @c_GenConsignee2Carrierkey = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'GenConsigneekey2Carrierkey')

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
         FROM #tORDERS OH
         WHERE OH.RowRef > @n_RowRef_OH
         ORDER BY OH.RowRef 

         IF @@ROWCOUNT = 0 OR @n_RowRef_OH = 0
         BEGIN
            BREAK
         END

         IF @c_GenConsignee2Carrierkey = '1' AND @n_RowRef_OH = @n_RowRef_OH_Last
         BEGIN
            IF @c_Consigneekey <> ''
            BEGIN
               SELECT @c_Carrierkey      = @c_Consigneekey
                  ,   @c_CarrierAddress1 = ISNULL(ST.Address1,'')
                  ,   @c_CarrierAddress2 = ISNULL(ST.Address2,'')
                  ,   @c_CarrierCity     = ISNULL(ST.City,'')
                  ,   @c_CarrierState    = ISNULL(ST.[State],'')
                  ,   @c_CarrierZip      = ISNULL(ST.Zip,'')
               FROM STORER ST WITH (NOLOCK)
               WHERE ST.Storerkey = @c_Consigneekey 
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
               , CarrierAddress1   
               , CarrierAddress2   
               , CarrierCity   
               , CarrierState
               , CarrierZip
                  )  
            SELECT
                 Receiptkey= @c_Receiptkey 
               , Storerkey = @c_Storerkey  
               , Facility  = @c_Facility  
               , ExternReceiptkey = @c_ExternReceiptkey
               , RecType = @c_Rectype  
               , DocType = @c_Doctype  
               , WarehouseReference = @c_WarehouseReference   
               , Carrierkey         = @c_Carrierkey 
               , CarrierAddress1    = @c_CarrierAddress1
               , CarrierAddress2    = @c_CarrierAddress2
               , CarrierCity        = @c_CarrierCity
               , CarrierState       = @c_CarrierState
               , CarrierZip         = @c_CarrierZip

            SET @n_RowRef_RH = @@IDENTITY  
         END
         ELSE
         BEGIN
            UPDATE #tRECEIPT 
               SET  ExternReceiptkey   = @c_ExternReceiptkey
                  , Carrierkey         = @c_Carrierkey 
                  , CarrierAddress1    = @c_CarrierAddress1
                  , CarrierAddress2    = @c_CarrierAddress2
                  , CarrierCity        = @c_CarrierCity
                  , CarrierState       = @c_CarrierState
                  , CarrierZip         = @c_CarrierZip
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

            SET @c_Putawayloc = ''
            IF @c_DefaultReturnPickFace = '1' AND @c_Rectype NOT IN ('NORMAL')
            BEGIN
               SET @c_Putawayloc = ''
               SELECT TOP 1 @c_Putawayloc = SL.Loc
               FROM SKUxLOC SL WITH (NOLOCK) 
               JOIN LOC L WITH (NOLOCK) ON SL.Loc = L.Loc AND L.Facility = @c_Facility
               WHERE SL.Storerkey = @c_Storerkey
               AND   SL.Sku = @c_Sku
               AND   SL.LocationType IN ( 'CASE', 'PICK' )
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
               ,  '' 
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
               ,  @c_ExternOrderkey
               ,  POKey = ''             
               ,  POLineNumber = ''
               ,  ExternPOKey = ISNULL(OD.ExternPOKey,'')
               ,  ExternLineNo= ISNULL(OD.ExternLineNo,'')
               ,  Vesselkey = ''
               ,  Voyagekey = ''
               ,  Lottable01 = ISNULL(LA.Lottable01,'')
               ,  Lottable02 = ISNULL(LA.Lottable02,'')
               ,  Lottable03 = ISNULL(LA.Lottable03,'')
               ,  LA.Lottable04
               ,  LA.Lottable05
               ,  Lottable06 = ISNULL(LA.Lottable06,'')
               ,  Lottable07 = ISNULL(LA.Lottable07,'')
               ,  Lottable08 = ISNULL(LA.Lottable08,'')
               ,  Lottable09 = ISNULL(LA.Lottable09,'')
               ,  Lottable10 = ISNULL(LA.Lottable10,'')
               ,  Lottable11 = ISNULL(LA.Lottable11,'')
               ,  Lottable12 = ISNULL(LA.Lottable12,'')
               ,  LA.Lottable13
               ,  LA.Lottable14
               ,  LA.Lottable15
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
               ,  ''
               ,  Channel = ISNULL(OD.Channel,'') 
            FROM #tORDERDETAIL OD 
            LEFT JOIN #tPICKDETAIL PD  ON OD.Orderkey = PD.Orderkey
                                      AND OD.OrderLineNumber = PD.OrderLineNumber
                                      AND (PD.ShipFlag = 'Y' OR PD.[Status] = '9')
            LEFT JOIN #tLOTATTRIBUTE LA ON PD.Lot = LA.Lot
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
               ,  LA.Lottable05
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

      -- Call Default Value - END - START
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
         SELECT TOP 1 @n_RowRef_CL = T.RowRef      --(Wan01)
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
      -- Call Default Value - END

      UPDATE #tRECEIPTDETAIL SET ToLoc = CASE WHEN PutawayLoc <> '' THEN PutawayLoc ELSE ToLoc END 
    
      BEGIN TRAN
      -- Update Data to Receipt & ReceiptDetail - START  
      BEGIN TRY
         UPDATE RECEIPT 
            SET ExternReceiptKey = T.ExternReceiptKey
               ,CarrierKey       = T.Carrierkey
               ,CarrierAddress1  = T.CarrierAddress1
               ,CarrierAddress2  = T.CarrierAddress2
               ,CarrierCity      = T.CarrierCity
               ,CarrierState     = T.CarrierState
               ,CarrierZip       = T.CarrierZip
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
         SET @n_Err = 558855
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': UPDATE RECEIPT Table Fail. (lsp_ASN_PopulateSODs_Wrapper)'   
                        + '(' + @c_ErrMsg + ')' 

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
         SET @n_Err = 558856
         SET @c_ErrMsg = ERROR_MESSAGE()

         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': INSERT RECEIPTDETAIL Table Fail. (lsp_ASN_PopulateSODs_Wrapper)'   
                        + '(' + @c_ErrMsg + ')' 

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
               
         GOTO EXIT_SP
      END CATCH
      -- Update Data to Receipt & ReceiptDetail - END   

      IF @n_Continue = 3
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > 0
            COMMIT TRAN
      END

      IF @n_Continue = 1
      BEGIN
         SET @c_errmsg = 'OrderLines populate to ASN successfully.'

         EXEC [WM].[lsp_WriteError_List] 
            @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
         ,  @c_TableName   = @c_TableName
         ,  @c_SourceType  = @c_SourceType
         ,  @c_Refkey1     = @c_Receiptkey
         ,  @c_Refkey2     = ''
         ,  @c_Refkey3     = ''
         ,  @c_WriteType   = 'MESSAGE'
         ,  @n_err2        = @n_err 
         ,  @c_errmsg2     = @c_errmsg 
         ,  @b_Success     = @b_Success   
         ,  @n_err         = @n_err       
         ,  @c_errmsg      = @c_errmsg  

         SET @n_WarningNo = 0
      END
   END TRY

   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = 'Populate SO Detail fail. (lsp_ASN_PopulateSODs_Wrapper) ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '
      GOTO EXIT_SP
   END CATCH -- (Wan01) - End Big Outer Begin try.. end Try Begin Catch.. End Catch
EXIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_ASN_PopulateSODs_Wrapper'
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