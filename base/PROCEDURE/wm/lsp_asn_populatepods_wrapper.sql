SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: lsp_ASN_PopulatePODs_Wrapper                        */
/* Creation Date: 2020-11-17                                            */
/* Copyright: LFL                                                       */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-2247 - UAT CN ASN  Populated from PO Module shows Other*/
/*        : Attributes is required Order Detail are missing in Inbound  */
/*        : module                                                      */
/*                                                                      */
/* Called By: SCE                                                       */
/*          :                                                           */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 2020-11-17  Wan      1.0   Created                                   */
/* 2021-06-25  Wan01    1.1   1)LFWM-2864 - UAT - TW  Missing ExternLineNo*/
/*                            and ExternReceiptkey when Populate PO Detail*/
/*                            in ASNReceipt module                      */
/*                            2)Fixed populate to ASN & Detail by PO2ASNMAP*/
/*                            3)Fixed missing lottabel09                */
/* 2021-07-20  Wan02    1.2   LFWM-2854 - UAT - TW  Receipt - Populate  */
/*                            from PO ( 1 PO 1 ASN ) in SCE does not    */
/*                            support codelkup 'PO2ASNMAP'               */
/* 2020-08-11  Wan03    1.3   LFWM-2962 - Populate Order details -Populate*/
/*                            SO Detail fail.                           */
/* 2021-09-23  LZG      1.4   JSM-21916 - Allowed PO population continue*/
/*                            after warning (ZG01)                      */
/* 2021-20-26  NJOW01   1.5   DEVOPS combine script                     */
/* 2021-20-26  NJOW01   1.6   WMS-17224 fix pokeylist delimiter pass to */
/*                            sub-stored proc.                          */
/* 2021-12-21  Wan04    1.7   LFWM-3210 - SCE UAT SG ASN Should Not     */
/*                            Populate Same POKey+POLinenumber          */
/* 2024-12-04  Wan05    1.7   UWP-27816 - Populate All for PO Line      */
/************************************************************************/
CREATE   PROC [WM].[lsp_ASN_PopulatePODs_Wrapper]
      @c_ReceiptKey           NVARCHAR(10)
   ,  @c_POKeyList            NVARCHAR(4000) = ''  -- PO Keys seperated by '|'; for eg '0000128313|0000128314|0000128314' => 0000128314 to twice as pass 2 polinenumber ; IF @c_WarningNo = 1, Get Overdue pass & Y response Orderkey & Line to pass to continue populate
   ,  @c_POLineNumberList     NVARCHAR(4000) = ''  -- POLineNumber seperated by '|'; for eg '00001|00001|00002'
   ,  @b_PopulateFromArchive  INT = 0              -- Pass in 1 if Populate ORderkey from Archive DB
   ,  @b_Success              INT = 1           OUTPUT
   ,  @n_err                  INT = 0           OUTPUT
   ,  @c_ErrMsg               NVARCHAR(255)= '' OUTPUT
   ,  @n_WarningNo            INT          = 0  OUTPUT
   ,  @c_ProceedWithWarning   CHAR(1)      = 'N'
   ,  @c_UserName             NVARCHAR(128)= ''
   ,  @n_ErrGroupKey          INT          = 0  OUTPUT
   ,  @c_SearchSQL            NVARCHAR(MAX)= ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   -- 1) Log All Validation Errors into WM.WMS_Error_list as ERROR write type and return fail (b_success = 0) before process, Java to get the error message from
   --    WM.WMS_Error_list table
   -- 2) Start Populate POs logic If validation checks are passed. during population process, any errors will log into WM.WMS_Error_list as ERROR write type
   --  , quit population proess and return fail (@b_success = 0). Java to get the message from WM.WMS_Error_list table
   -- 3) Log Message/information into  WM.WMS_Error_list as Message write type and return success (b_success = 1) in SP when Populate successfully, Java to get the message from
   --    WM.WMS_Error_list table
   DECLARE  @n_StartTCnt               INT = @@TRANCOUNT
         ,  @n_Continue                INT = 1
         ,  @n_Cnt                     INT = 0
         ,  @n_RowRef_PH               INT = 0
         ,  @n_RowRef_PD               INT = 0
         ,  @n_RowRef_RH               INT = 0
         ,  @n_RowRef_RD               INT = 0
         ,  @n_RowRef_PH_Last          INT = 0
         ,  @n_RowCnt_RH               INT = 0
         ,  @n_RowCnt_RD               INT = 0
         ,  @n_PopulatedOrderCnt       INT = 0
         ,  @n_ToPopulateOrderCnt      INT = 0
         ,  @n_PopulateReturnMaxOrder  INT = 0
         ,  @n_ReceiptLineNumber       INT = 0
         ,  @c_SQL                     NVARCHAR(4000) = ''
         ,  @c_SQL1                    NVARCHAR(4000) = ''
         ,  @c_SQLParms              NVARCHAR(4000) = ''
         ,  @c_SQL_INS_FIELDS          NVARCHAR(4000) = ''        --(Wan01)
         ,  @c_SQL_UPD_FIELDS          NVARCHAR(4000) = ''        --(Wan01)
         ,  @c_SQLSchema               NVARCHAR(4000) = ''
         ,  @c_TableColumns            NVARCHAR(4000) = ''
         ,  @c_TableColumns_SELECT     NVARCHAR(4000) = ''
         ,  @c_Table                   NVARCHAR(60) = ''
         ,  @c_TempTableName           NVARCHAR(50) = ''          --(Wan03)
         ,  @c_TableName               NVARCHAR(50)   = 'RECEIPTDETAIL'
         ,  @c_SourceType              NVARCHAR(50)   = 'lsp_ASN_PopulatePODs_Wrapper'
         ,  @c_Refkey1                 NVARCHAR(20)   = ''        --(Wan05)
         ,  @c_Refkey2                 NVARCHAR(20)   = ''        --(Wan05)
         ,  @c_Refkey3                 NVARCHAR(20)   = ''        --(Wan05)
         ,  @c_WriteType               NVARCHAR(20)   = ''
         ,  @n_LogWarningNo            INT            = 0         --(Wan05)
         ,  @c_DBName                  NVARCHAR(30)   = ''
         ,  @c_ArchiveDB               NVARCHAR(30)   = ''
         ,  @c_IsArch                  CHAR(1)        = 'N'
         ,  @c_POStatus                NVARCHAR(10)   = ''
         ,  @c_POExternStatus          NVARCHAR(10)   = ''
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
         ,  @c_UserDefine01            NVARCHAR(30)   = ''
         ,  @c_UserDefine02            NVARCHAR(30)   = ''
         ,  @c_UserDefine03            NVARCHAR(30)   = ''
         ,  @c_UserDefine04            NVARCHAR(30)   = ''
         ,  @c_UserDefine05            NVARCHAR(30)   = ''
         ,  @dt_UserDefine06           NVARCHAR(30)   = ''
         ,  @dt_UserDefine07           NVARCHAR(30)   = ''
         ,  @c_UserDefine08            NVARCHAR(30)   = ''
         ,  @c_UserDefine09            NVARCHAR(30)   = ''
         ,  @c_UserDefine10            NVARCHAR(30)   = ''
         ,  @c_POKey                   NVARCHAR(10)   = ''
         ,  @c_POLineNumber            NVARCHAR(5)    = ''
         ,  @c_ReceiptLineNumber       NVARCHAR(5)    = ''
         ,  @c_ExternPOKey             NVARCHAR(30)   = ''
         ,  @c_ExternLineNo            NVARCHAR(20)   = ''
         ,  @c_Sku                     NVARCHAR(20)   = ''
         ,  @c_Altsku                  NVARCHAR(20)   = ''
         ,  @c_ToLoc                   NVARCHAR(10)   = ''
         ,  @c_PutawayLoc              NVARCHAR(10)   = ''
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
         ,  @c_SubReasonCode           NVARCHAR(10)   = ''
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
         ,  @c_SourceKey               NVARCHAR(50)   = ''
         ,  @c_SourceType_LARule       NVARCHAR(50)   = ''
         ,  @c_Code                    NVARCHAR(30)   = ''
         ,  @c_Code2                   NVARCHAR(30)   = ''
         ,  @c_UpdateCol               NVARCHAR(60)   = ''
         ,  @c_ReturnSQL               NVARCHAR(MAX)  = ''
         ,  @c_ReceiptLoc              NVARCHAR(10)   = ''
         ,  @c_ReturnLoc               NVARCHAR(10)   = ''
         ,  @c_ReceiptInspectionLoc    NVARCHAR(10)   = ''
         ,  @c_XDockReceiptLoc         NVARCHAR(10)   = ''
         ,  @c_AllowPopulateSamePOLine NVARCHAR(30)   = ''                 --(Wan04)
         ,  @c_DefaultLOC              NVARCHAR(30)   = ''
         ,  @c_DefaultRcptLOC          NVARCHAR(30)   = ''
         ,  @c_DefaultReturnPickFace   NVARCHAR(30)   = ''
         ,  @c_POKeyListParam          NVARCHAR(4000) = ''  --NJOW01
         ,  @c_POLineNumberListParam   NVARCHAR(4000) = ''  --NJOW01
         ,  @c_SelectSQL               NVARCHAR(500)  = ''                 --(Wan05)
         ,  @CUR_SCHEMA                CURSOR
         ,  @CUR_COLMAP                CURSOR
         ,  @CUR_ERRLIST               CURSOR                              --(Wan05)
   DECLARE @tCODELKUP TABLE
         (  RowRef         INT   IDENTITY(1,1) Primary Key
         ,  ColName        NVARCHAR(30)  NULL DEFAULT('')
         ,  DefaultValue   NVARCHAR(250) NULL DEFAULT('')
         )
   DECLARE  @t_WMSErrorList TABLE                                          --(Wan05) - START
         (  RowID             INT            IDENTITY(1,1)
         ,  TableName         NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  SourceType        NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  Refkey1           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey2           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey3           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  WriteType         NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  LogWarningNo      INT            NOT NULL DEFAULT(0)
         ,  ErrCode           INT            NOT NULL DEFAULT(0)
         ,  Errmsg            NVARCHAR(255)  NOT NULL DEFAULT('')
         )                                                                 --(Wan05) - END
   SET @b_Success = 1
   SET @n_Err     = 0
   IF @b_PopulateFromArchive = 1 SET @c_IsArch = 'Y'
   SET @n_Err = 0
   IF SUSER_SNAME() <> @c_UserName
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
   END
   SET @n_ErrGroupKey = 0
   BEGIN TRY
      IF OBJECT_ID('tempdb..#tSearchPO', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tSearchPO
      END
      CREATE TABLE #tSearchPO
         (  RowRef         INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
         ,  POKey          NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  POLineNumber   NVARCHAR(10)   NOT NULL DEFAULT('')
         )
      IF @c_POKeyList = '' OR @c_POLineNumberList = ''                              --(Wan05) - START
      BEGIN
         SET @c_SelectSQL = N'SELECT PODETAIL.POKey, PODETAIL.POLineNumber'
         SELECT @c_SearchSQL = dbo.fnc_ParseSearchSQL(@c_SearchSQL, @c_SelectSQL)
         IF @c_SearchSQL = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err      = 559010
            SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(6), @n_Err)
                            + ': Empty Search Criteria found. (lsp_ASN_PopulatePODs_Wrapper)'
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, '', '', 'ERROR', 0, @n_Err, @c_Errmsg)
            GOTO EXIT_SP
         END
         INSERT INTO #tSearchPO (POKey, POLineNumber)
         EXEC sp_ExecuteSQL @c_SearchSQL
      END                                                                           --(Wan05) - END
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
      IF OBJECT_ID('tempdb..#tPOH', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tPOH
      END
      CREATE TABLE #tPOH
         (  RowRef      INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
         ,  PORefKey    NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  Receiptkey  NVARCHAR(10)   NOT NULL DEFAULT('')
         )
      IF @c_POKeyList > '' AND @c_POLineNumberList > ''                             --(Wan05) - START
      BEGIN
         INSERT INTO #tPOH (PORefKey, Receiptkey)
         SELECT T.[Value], @c_Receiptkey FROM string_split (@c_POKeyList, '|') T
      END                                                                           --(Wan05) - END
       IF OBJECT_ID('tempdb..#tPOD', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tPOD
      END
      CREATE TABLE #tPOD
         (  RowRef         INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
         ,  PORefLineNo    NVARCHAR(5)    NOT NULL DEFAULT('')
         )
      IF @c_POKeyList > '' AND @c_POLineNumberList > ''                             --(Wan05) - START
      BEGIN
         INSERT INTO #tPOD (PORefLineNo)
         SELECT T.[Value] FROM string_split (@c_POLineNumberList, '|') T
      END
      ELSE
      BEGIN
         INSERT INTO #tPOD (PORefLineNo)
         SELECT POLineNumber
         FROM #tSearchPO
         ORDER BY RowRef
         INSERT INTO #tPOH (PORefKey, Receiptkey)
         SELECT POKey, @c_ReceiptKey
         FROM #tSearchPO
         ORDER BY RowRef
      END                                                                           --(Wan05) - END
      IF OBJECT_ID('tempdb..#tRECEIPT', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tRECEIPT
      END
      IF OBJECT_ID('tempdb..#tRECEIPTDETAIL', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tRECEIPTDETAIL
      END
      IF OBJECT_ID('tempdb..#tPO', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tPO
      END
      IF OBJECT_ID('tempdb..#tPODETAIL', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tPODETAIL
      END
      CREATE TABLE #tRECEIPT (RowRef INT IDENTITY(1,1) PRIMARY KEY)
      CREATE TABLE #tRECEIPTDETAIL (RowRef INT IDENTITY(1,1) PRIMARY KEY)
      CREATE TABLE #tPO (RowRef INT IDENTITY(1,1) PRIMARY KEY)
      CREATE TABLE #tPODETAIL (RowRef INT IDENTITY(1,1) PRIMARY KEY)
      SET @CUR_SCHEMA = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Tab.Table_Name
      FROM INFORMATION_SCHEMA.TABLES Tab WITH (NOLOCK)
      WHERE Tab.Table_Name IN ('PO', 'PODETAIL', 'RECEIPT', 'RECEIPTDETAIL')
      ORDER BY CASE WHEN Tab.Table_Name = 'PO' THEN 4
                    WHEN Tab.Table_Name = 'PODETAIL' THEN 2
                    WHEN Tab.Table_Name = 'RECEIPT' THEN 6
                    WHEN Tab.Table_Name = 'RECEIPTDETAIL' THEN 8
                    END
      OPEN @CUR_SCHEMA
      FETCH NEXT FROM @CUR_SCHEMA INTO @c_Table
      WHILE @@FETCH_STATUS <> - 1
      BEGIN
         --(Wan03) - START
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
         SET @c_TableColumns_SELECT = ''
         SET @c_TableColumns_SELECT = RTRIM(ISNULL(CONVERT(NVARCHAR(4000),
                              ( SELECT TABLE_NAME + '.' + col.column_name + ','
                                 FROM INFORMATION_SCHEMA.COLUMNS Col WITH (NOLOCK)
                                 WHERE Table_Name = @c_Table
   ORDER BY Col.ORDINAL_POSITION
                                 FOR XML PATH(''), TYPE
                              )
                              ),''))
         SET @c_TableColumns = ''
         SET @c_TableColumns = RTRIM(ISNULL(CONVERT(NVARCHAR(4000),
                              ( SELECT col.column_name + ','
                                 FROM INFORMATION_SCHEMA.COLUMNS Col WITH (NOLOCK)
                                 WHERE Table_Name = @c_Table
                                 ORDER BY Col.ORDINAL_POSITION
                                 FOR XML PATH(''), TYPE
                              )
                              ),''))
         IF @c_TableColumns_SELECT <> ''
         BEGIN
            SET @c_TableColumns_SELECT = SUBSTRING(@c_TableColumns_SELECT, 1, LEN(@c_TableColumns_SELECT) - 1)
         END
         IF @c_TableColumns <> ''
         BEGIN
            SET @c_TableColumns = SUBSTRING(@c_TableColumns, 1, LEN(@c_TableColumns) - 1)
         END
         */
         --(Wan03) - END
         IF @c_Table = 'PODETAIL' AND @c_TableColumns <> ''
         BEGIN
            SET @c_SQL = N'INSERT INTO #tPODETAIL  (' + @c_TableColumns + ')'
                        + ' SELECT ' + @c_TableColumns_SELECT
                        + ' FROM #tPOH H'
                        + ' JOIN #tPOD D ON H.RowRef = D.RowRef'
                        + ' JOIN ' + RTRIM(@c_DBName) + 'dbo.PODETAIL WITH (NOLOCK)'
                        +                              ' ON  H.PORefKey= PODETAIL.POKey'
                        +                              ' AND D.PORefLineNo= PODETAIL.POLineNumber'
                        + ' WHERE PODETAIL.QtyReceived < PODETAIL.QtyOrdered'
                        + ' ORDER BY PODETAIL.POKey, PODETAIL.POLineNumber'
            EXEC sp_ExecuteSQL @c_SQL
         END
         IF @c_Table = 'PO' AND @c_TableColumns <> ''
         BEGIN
            SET @c_SQL = N'INSERT INTO #tPO ( ' + @c_TableColumns + ' )'
                        + ' SELECT ' + @c_TableColumns_SELECT +
                        + ' FROM ' + RTRIM(@c_DBName) + 'dbo.PO PO WITH (NOLOCK)'
                        + ' WHERE EXISTS (SELECT 1 FROM #tPODETAIL PD WHERE PO.POKey = PD.POKey)'
            EXEC sp_ExecuteSQL @c_SQL
         END
         IF @c_Table = 'RECEIPT' AND @c_TableColumns <> ''
         BEGIN
            SET @c_SQL = N'INSERT INTO #tRECEIPT  (' + @c_TableColumns + ')'
            SET @c_SQL1= ' SELECT ' + @c_TableColumns_SELECT
                        + ' FROM RECEIPT WITH (NOLOCK)'
                        + ' WHERE EXISTS (SELECT 1 FROM #tPOH H WHERE RECEIPT.Receiptkey = H.Receiptkey)'
            EXEC ( @c_SQL + @c_SQL1 )
            SET @n_RowRef_RH = @@IDENTITY
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
                        FROM #tPO PO WITH (NOLOCK)
                        )
         BEGIN
            SET @n_Continue = 3
            SET @n_Err      = 559001
            SET @c_errmsg   = 'No PO to found to populate to ASN #: ' + @c_Receiptkey + '. (lsp_ASN_PopulatePODs_Wrapper)'
            --(Wan05) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, '', '', 'ERROR', 0, @n_Err, @c_Errmsg)
            --EXEC [WM].[lsp_WriteError_List]
            --   @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
            --,  @c_TableName   = @c_TableName
            --,  @c_SourceType  = @c_SourceType
            --,  @c_Refkey1     = @c_Receiptkey
            --,  @c_Refkey2     = ''
            --,  @c_Refkey3     = ''
            --,  @c_WriteType   = 'ERROR'
            --,  @n_err2        = @n_err
            --,  @c_errmsg2     = @c_errmsg
            --,  @b_Success     = @b_Success
            --,  @n_err         = @n_err
            --,  @c_errmsg      = @c_errmsg
            --(Wan05) - END
         END
         SET @n_RowRef_PH = 0
         WHILE 1 = 1
         BEGIN
            SET @c_POKey = ''
            SET @c_POStatus = ''
            SET @c_POExternStatus = ''
            SELECT TOP 1
                   @c_POKey = PO.POkey
                  ,@c_POStatus = PO.[Status]
                  ,@c_POExternStatus = PO.ExternStatus
                  ,@n_RowRef_PH = PO.RowRef
            FROM #tPO PO WITH (NOLOCK)
            WHERE PO.RowRef > @n_RowRef_PH
            ORDER BY PO.RowRef
            IF @@ROWCOUNT = 0 OR @c_POKey = ''
            BEGIN
               BREAK
            END
            IF @c_POStatus IN  ('9', 'CANCELLED', 'CLOSED')  OR @c_POExternStatus IN  ('9', 'CANC')
            BEGIN
               SET @n_Continue = 3
               SET @n_Err      = 559002
               SET @c_errmsg   = 'Population Fail due to PO #: ' + @c_POKey + ' is CLOSED OR CANCELLED. (lsp_ASN_PopulatePODs_Wrapper)'
               --(Wan05) - START
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
               VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_POKey, '', 'ERROR', 0, @n_Err, @c_Errmsg)
               --EXEC [WM].[lsp_WriteError_List]
               --   @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
               --,  @c_TableName   = @c_TableName
               --,  @c_SourceType  = @c_SourceType
               --,  @c_Refkey1     = @c_Receiptkey
               --,  @c_Refkey2     = @c_POKey
               --,  @c_Refkey3     = ''
               --,  @c_WriteType   = 'ERROR'
               --,  @n_err2        = @n_err
               --,  @c_errmsg2     = @c_errmsg
               --,  @b_Success     = @b_Success
               --,  @n_err         = @n_err
               --,  @c_errmsg      = @c_errmsg
               --(Wan05) - END
            END
         END
         SET @n_RowRef_PD = 0
         WHILE 1 = 1
         BEGIN
            SET @c_POKey = ''
            SET @c_POLineNumber = ''
            SELECT TOP 1
                    @n_RowRef_PD = PD.RowRef
                  , @c_POkey     = PD.POKey
                  , @c_POLineNumber = PD.POLineNumber
            FROM #tPODETAIL PD
            WHERE PD.RowRef > @n_RowRef_PD
            AND   PD.Facility NOT IN ( @c_Facility )
            AND   PD.Facility <> ''
            AND   PD.Facility IS NOT NULL
            ORDER BY PD.RowRef
            IF @@ROWCOUNT = 0 OR @c_POKey = ''
            BEGIN
               BREAK
            END
            SET @n_Continue = 3
            SET @n_Err      = 559003
            SET @c_errmsg   = 'Population Fail due to Different PODetail Facility found. PO #: ' + @c_POKey + ', POLineNumber: ' + @c_POLineNumber
                            + '. (lsp_ASN_PopulatePODs_Wrapper)'
            --(Wan05) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_POKey, @c_POLineNumber, 'ERROR', 0, @n_Err, @c_Errmsg)
            --EXEC [WM].[lsp_WriteError_List]
            --   @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
            --,  @c_TableName   = @c_TableName
            --,  @c_SourceType  = @c_SourceType
            --,  @c_Refkey1     = @c_Receiptkey
            --,  @c_Refkey2     = @c_POKey
            --,  @c_Refkey3     = @c_POLineNumber
            --,  @c_WriteType   = 'ERROR'
            --,  @n_err2        = @n_err
            --,  @c_errmsg2     = @c_errmsg
            --,  @b_Success     = @b_Success
            --,  @n_err         = @n_err
            --,  @c_errmsg      = @c_errmsg
            --(Wan05) - END
         END
         --NJOW01
         SET @c_POKeyListParam = REPLACE(@c_POKeyList,'|',',')
         SET @c_POLineNumberListParam = REPLACE(@c_POLineNumberList,'|',',')
         BEGIN TRY
            EXEC [dbo].[isp_PrePopulatePO_Wrapper]
                 @c_Receiptkey  = @c_Receiptkey
               , @c_POKeys       = @c_POKeyListParam         --NJOW01
               , @c_POLineNumbers= @c_POLineNumberListParam  --NJOW01
               , @b_Success      = @b_Success      OUTPUT
               , @n_Err          = @n_Err          OUTPUT
               , @c_ErrMsg       = @c_ErrMsg       OUTPUT
         END TRY
         BEGIN CATCH
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @n_Err = 559004
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_PrePopulatePO_Wrapper. (lsp_ASN_PopulatePODs_Wrapper)'
                        + '(' + @c_ErrMsg + ')'
            IF (XACT_STATE()) = -1
            BEGIN
               ROLLBACK TRAN
               WHILE @@TRANCOUNT < @n_StartTCnt
               BEGIN
                  BEGIN TRAN
               END
            END
         END CATCH
         IF @b_Success = 0 OR @n_Err > 0
         BEGIN
            SET @n_Continue = 3
            --(Wan05) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, '', '', 'ERROR', 0, @n_Err, @c_Errmsg)
            --EXEC [WM].[lsp_WriteError_List]
            --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
            --   ,  @c_TableName   = @c_TableName
            --   ,  @c_SourceType  = @c_SourceType
            --   ,  @c_Refkey1     = @c_ReceiptKey
            --   ,  @c_Refkey2     = ''
            --   ,  @c_Refkey3     = ''
            --   ,  @c_WriteType   = 'ERROR'
            --   ,  @n_err2        = @n_err
            --   ,  @c_errmsg2     = @c_errmsg
            --   ,  @b_Success     = @b_Success   --2020-09-15
            --   ,  @n_err         = @n_err       --2020-09-15
            --   ,  @c_errmsg      = @c_errmsg    --2020-09-15
            --(Wan05) - END
         END
         IF @n_Continue = 3
         BEGIN
            GOTO EXIT_SP
         END
      END
      -- Get Storerconfig
      SET @c_DefaultLOC = '0'
      SET @c_DefaultReturnPickFace = '0'
      SET @c_DefaultRcptLOC = ''
      SELECT @c_DefaultLOC     = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'DefaultLOC')
      SELECT @c_DefaultReturnPickFace = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'DefaultReturnPickFace')
      SELECT @c_DefaultRcptLOC = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, @c_Sku, 'DefaultRcptLOC')
      IF @c_DefaultRcptLOC = '0'
      BEGIN
         SET @c_DefaultRcptLOC = ''
      END
      SELECT TOP 1
            @n_RowRef_PH_Last = PH.RowRef
      FROM #tPO PH
      WHERE PH.RowRef > @n_RowRef_PH
      ORDER BY PH.RowRef DESC
      SET @n_RowRef_PH = 0
      WHILE 1 = 1
      BEGIN
         SET @c_POKey = ''
         SELECT TOP 1
                @c_POKey           = PO.POKey
               ,@c_Carrierkey      = CASE WHEN @c_Carrierkey   = '' THEN LEFT(ISNULL(PO.SellerName,''),15) ELSE @c_Carrierkey  END
               ,@c_CarrierAddress1 = CASE WHEN @c_Carrierkey   = '' THEN ISNULL(PO.SellerAddress1,'') ELSE @c_CarrierAddress1  END
               ,@c_CarrierAddress2 = CASE WHEN @c_Carrierkey   = '' THEN ISNULL(PO.SellerAddress2,'') ELSE @c_CarrierAddress2  END
               ,@c_UserDefine01    = CASE WHEN @c_UserDefine01 = '' THEN ISNULL(PO.UserDefine01,'') ELSE @c_UserDefine01  END
               ,@c_UserDefine02    = CASE WHEN @c_UserDefine02 = '' THEN ISNULL(PO.UserDefine02,'') ELSE @c_UserDefine02  END
               ,@c_UserDefine03    = CASE WHEN @c_UserDefine03 = '' THEN ISNULL(PO.UserDefine03,'') ELSE @c_UserDefine03  END
               ,@c_UserDefine04    = CASE WHEN @c_UserDefine04 = '' THEN ISNULL(PO.UserDefine04,'') ELSE @c_UserDefine04  END
               ,@c_UserDefine05    = CASE WHEN @c_UserDefine05 = '' THEN ISNULL(PO.UserDefine05,'') ELSE @c_UserDefine05  END
               ,@dt_UserDefine06   = CASE WHEN @dt_UserDefine06 IS NULL THEN PO.UserDefine06 ELSE @dt_UserDefine06 END
               ,@dt_UserDefine07   = CASE WHEN @dt_UserDefine07 IS NULL THEN PO.UserDefine07 ELSE @dt_UserDefine07 END
               ,@c_UserDefine08    = CASE WHEN @c_UserDefine08 = '' THEN ISNULL(PO.UserDefine08,'') ELSE @c_UserDefine08  END
               ,@c_UserDefine09    = CASE WHEN @c_UserDefine09 = '' THEN ISNULL(PO.UserDefine09,'') ELSE @c_UserDefine09  END
               ,@c_UserDefine10    = CASE WHEN @c_UserDefine10 = '' THEN ISNULL(PO.UserDefine10,'') ELSE @c_UserDefine10  END
               ,@n_RowRef_PH = PO.RowRef
         FROM #tPO PO
         WHERE PO.RowRef > @n_RowRef_PH
         ORDER BY PO.RowRef
         IF @@ROWCOUNT = 0 OR @c_POKey = ''
         BEGIN
            BREAK
         END
         SET @c_ExternPOKey = ''
         SELECT TOP 1 @c_ExternPOKey = ISNULL(PD.ExternPOkey,'')
         FROM #tPODETAIL PD WITH (NOLOCK)
         WHERE PD.POKey = @c_POKey
         AND PD.ExternPOkey <> ''
         ORDER BY PD.RowRef
         SET @c_ExternReceiptkey = CASE WHEN @c_ExternReceiptkey = '' THEN @c_ExternPOKey
                                        WHEN @c_ExternReceiptkey <> @c_ExternPOKey THEN ''
                                        ELSE @c_ExternReceiptkey
                                        END
         UPDATE #tRECEIPT
            SET  ExternReceiptkey   = @c_ExternReceiptkey
               , Carrierkey         = @c_Carrierkey
               , CarrierAddress1    = @c_CarrierAddress1
               , CarrierAddress2    = @c_CarrierAddress2
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
         WHERE RowRef = @n_RowRef_RH
         --(Wan01) - START
         SET @c_SQL_UPD_FIELDS =
              N' ExternReceiptKey = T.ExternReceiptKey'
             +', ReceiptGroup = T.ReceiptGroup'
             +', ReceiptDate = T.ReceiptDate'
             +', POKey = T.POKey'
             +', CarrierKey = T.CarrierKey'
             +', CarrierName = T.CarrierName'
             +', CarrierAddress1 = T.CarrierAddress1'
             +', CarrierAddress2 = T.CarrierAddress2'
             +', CarrierCity = T.CarrierCity'
             +', CarrierState = T.CarrierState'
             +', CarrierZip = T.CarrierZip'
             +', CarrierReference = T.CarrierReference'
             +', WarehouseReference = T.WarehouseReference'
             +', OriginCountry = T.OriginCountry'
             +', DestinationCountry = T.DestinationCountry'
             +', VehicleNumber = T.VehicleNumber'
             +', VehicleDate = T.VehicleDate'
             +', PlaceOfLoading = T.PlaceOfLoading'
             +', PlaceOfDischarge = T.PlaceOfDischarge'
             +', PlaceofDelivery = T.PlaceofDelivery'
             +', IncoTerms = T.IncoTerms'
             +', TermsNote = T.TermsNote'
             +', ContainerKey= T.ContainerKey'
             +', Signatory = T.Signatory'
             +', PlaceofIssue = T.PlaceofIssue'
             +', Status = T.[Status]'
             +', Notes = T.Notes'
             +', EffectiveDate = T.EffectiveDate'
             +', ContainerType = T.ContainerType'
             +', ContainerQty = T.ContainerQty'
             +', BilledContainerQty = T.BilledContainerQty'
             +', RECType = T.RECType'
             +', ASNStatus = T.ASNStatus'
             +', ASNReason = T.ASNReason'
             +', MBOLKey = T.MBOLKey'
             +', Appointment_No = T.Appointment_No'
             +', LoadKey = T.LoadKey'
             +', xDockFlag = T.xDockFlag'
             +', UserDefine01 = T.UserDefine01'
             +', PROCESSTYPE = T.PROCESSTYPE'
             +', UserDefine02 = T.UserDefine02'
             +', UserDefine03 = T.UserDefine03'
             +', UserDefine04 = T.UserDefine04'
             +', UserDefine05 = T.UserDefine05'
             +', UserDefine06 = T.UserDefine06'
             +', UserDefine07 = T.UserDefine07'
             +', UserDefine08 = T.UserDefine08'
             +', UserDefine09 = T.UserDefine09'
             +', UserDefine10 = T.UserDefine10'
             +', DOCTYPE = T.DOCTYPE'
             +', RoutingTool = T.RoutingTool'
             +', CTNTYPE1 = T.CTNTYPE1'
             +', CTNTYPE2 = T.CTNTYPE2'
             +', CTNTYPE3 = T.CTNTYPE3'
             +', CTNTYPE4 = T.CTNTYPE4'
             +', CTNTYPE5 = T.CTNTYPE5'
             +', CTNTYPE6 = T.CTNTYPE6'
             +', CTNTYPE7 = T.CTNTYPE7'
             +', CTNTYPE8 = T.CTNTYPE8'
             +', CTNTYPE9 = T.CTNTYPE9'
             +', CTNTYPE10 = T.CTNTYPE10'
             +', PACKTYPE1 = T.PACKTYPE1'
             +', PACKTYPE2 = T.PACKTYPE2'
             +', PACKTYPE3 = T.PACKTYPE3'
             +', PACKTYPE4 = T.PACKTYPE4'
             +', PACKTYPE5 = T.PACKTYPE5'
             +', PACKTYPE6 = T.PACKTYPE6'
             +', PACKTYPE7 = T.PACKTYPE7'
             +', PACKTYPE8 = T.PACKTYPE8'
             +', PACKTYPE9 = T.PACKTYPE9'
             +', PACKTYPE10 = T.PACKTYPE10'
             +', CTNCNT1 = T.CTNCNT1'
             +', CTNCNT2 = T.CTNCNT2'
             +', CTNCNT3 = T.CTNCNT3'
             +', CTNCNT4 = T.CTNCNT4'
             +', CTNCNT5 = T.CTNCNT5'
             +', CTNCNT6 = T.CTNCNT6'
             +', CTNCNT7 = T.CTNCNT7'
             +', CTNCNT8 = T.CTNCNT8'
             +', CTNCNT9 = T.CTNCNT9'
             +', CTNCNT10 = T.CTNCNT10'
             +', CTNQTY1 = T.CTNQTY1'
             +', CTNQTY2 = T.CTNQTY2'
             +', CTNQTY3 = T.CTNQTY3'
             +', CTNQTY4 = T.CTNQTY4'
             +', CTNQTY5 = T.CTNQTY5'
             +', CTNQTY6 = T.CTNQTY6'
             +', CTNQTY7 = T.CTNQTY7'
             +', CTNQTY8 = T.CTNQTY8'
             +', CTNQTY9 = T.CTNQTY9'
             +', CTNQTY10= T.CTNQTY10'
             +', NoOfMasterCtn = T.NoOfMasterCtn'
             +', NoOfTTLUnit = T.NoOfTTLUnit'
             +', NoOfPallet = T.NoOfPallet'
             +', Weight = T.[Weight]'
             +', WeightUnit = T.WeightUnit'
             +', Cube = T.[Cube]'
             +', CubeUnit = T.CubeUnit'
             +', GIS_ControlNo = T.GIS_ControlNo'
             +', Cust_ISA_ControlNo = T.Cust_ISA_ControlNo'
             +', Cust_GIS_ControlNo = T.Cust_GIS_ControlNo'
             +', GIS_ProcessTime = T.GIS_ProcessTime'
             +', Cust_EDIAckTime = T.Cust_EDIAckTime'
             +', FinalizeDate = T.FinalizeDate'
             +', SellerName = T.SellerName'
             +', SellerCompany = T.SellerCompany'
             +', SellerAddress1 = T.SellerAddress1'
             +', SellerAddress2 = T.SellerAddress2'
             +', SellerAddress3 = T.SellerAddress3'
             +', SellerAddress4 = T.SellerAddress4'
             +', SellerCity = T.SellerCity'
             +', SellerState = T.SellerState'
             +', SellerZip = T.SellerZip'
             +', SellerCountry = T.SellerCountry'
             +', SellerContact1 = T.SellerContact1'
             +', SellerContact2 = T.SellerContact2'
             +', SellerPhone1 = T.SellerPhone1'
             +', SellerPhone2 = T.SellerPhone2'
             +', SellerEmail1 = T.SellerEmail1'
             +', SellerEmail2 = T.SellerEmail2'
             +', SellerFax1 = T.SellerFax1'
             +', SellerFax2 = T.SellerFax2'
             +', HoldChannel = T.HoldChannel'
             +', TrackingNo = T.TrackingNo'
         --(Wan01) - END
         -- Call Custom Header Mapping - START
         SET @c_ListName = 'PO2ASNMAP'
         SET @CUR_COLMAP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Code  = CL.Code
               ,Code2 = CL.Code2
         FROM CODELKUP CL WITH (NOLOCK)
         WHERE CL.ListName = @c_ListName
         AND   CL.Short = 'H'
         AND   CL.Storerkey = @c_Storerkey
         UNION                                                                                     --(Wan01)
         SELECT Code  = CL.Code
               ,Code2 = CL.Code2
         FROM CODELKUP CL WITH (NOLOCK)
         WHERE CL.ListName = @c_ListName
         AND   CL.Short = 'H'
         AND   CL.Storerkey = @c_Storerkey
         AND  @c_DocType IN (SELECT LTRIM(RTRIM(ss.value)) FROM STRING_SPLIT(CL.UDF03,',') AS ss)  --(Wan01)
         ORDER BY CL.Code
         OPEN @CUR_COLMAP
         FETCH NEXT FROM @CUR_COLMAP INTO @c_Code, @c_Code2
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @c_ReturnSQL = ''
            SET @c_UpdateCol = ''
            BEGIN TRY
               EXEC [WM].[lsp_Populate_GetDocFieldsMap]
                  @c_SourceTable       =  'PO'
               ,  @c_Sourcekey         =  @c_POkey
               ,  @c_SourceLineNumber  =  ''
               ,  @c_ListName          =  @c_ListName
               ,  @c_Code   =  @c_Code
               ,  @c_Storerkey         =  @c_Storerkey
               ,  @c_Code2             =  @c_Code2
               ,  @c_DBName            =  @c_DBName
               ,  @c_UpdateCol         =  @c_UpdateCol   OUTPUT
               ,  @c_ReturnSQL         =  @c_ReturnSQL   OUTPUT
            END TRY
            BEGIN CATCH
               SET @n_Continue = 3
               SET @n_Err = 559005
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing lsp_Populate_GetDocFieldsMap - Header. (lsp_ASN_PopulatePODs_Wrapper)'
                              + '(' + @c_ErrMsg + ')'
               --(Wan05) - START
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo
                                          , ErrCode, ErrMsg)
               VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_POKey, '', 'ERROR', 0, @n_Err, @c_Errmsg)
               --EXEC [WM].[lsp_WriteError_List]
               --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
               --   ,  @c_TableName   = @c_TableName
               --   ,  @c_SourceType  = @c_SourceType
               --   ,  @c_Refkey1     = @c_Receiptkey
               --   ,  @c_Refkey2     = @c_POKey
               --   ,  @c_Refkey3     = ''
               --   ,  @c_WriteType   = 'ERROR'
               --   ,  @n_err2        = @n_err
               --   ,  @c_errmsg2     = @c_errmsg
               --   ,  @b_Success     = @b_Success   --2020-09-15
               --   ,  @n_err         = @n_err       --2020-09-15
               --   ,  @c_errmsg      = @c_errmsg    --2020-09-15
               --(Wan05) - END
               GOTO EXIT_SP
            END CATCH
            SET @c_UpdateCol = RTRIM(LTRIM(@c_UpdateCol))         --(Wan01)
            IF @c_ReturnSQL <> ''
            BEGIN
               --(Wan02) - START
               --SET @c_SQL = REPLACE(@c_ReturnSQL, ' FromValue', ' Top 1 FromValue')
               SET @c_SQL = @c_ReturnSQL
               -- Direct mapping
               IF CHARINDEX('WHERE', @c_ReturnSQL ) = 0
               BEGIN
                  SET @c_SQL = REPLACE(@c_SQL, ' PO ', ' #tPO PO ')
                  SET @c_SQL = REPLACE(@c_SQL, ' PODETAIL ', ' #tPODETAIL PODETAIL ')
                  IF CHARINDEX('#tPO', @c_SQL) > 0
                     BEGIN
                        SET @c_SQL = @c_SQL + ' WHERE PO.RowRef = @n_RowRef_PH'
                     END
               END
               --IF CHARINDEX(' FROM ',@c_ReturnSQL) > 0
               --BEGIN
               --   IF CHARINDEX('WHERE', @c_ReturnSQL ) = 0
               --   BEGIN
               --      SET @c_SQL = @c_SQL + ' WHERE'
               --   END
               --   ELSE
               --   BEGIN
               --      SET @c_SQL = @c_SQL + ' AND'
               --   END
               --   SET @c_SQL = @c_SQL + ' PO.RowRef = @n_RowRef_PH'
               --END
               --(Wan02) - END
               IF @c_SQL <> ''
               BEGIN
                  SET @c_SQL = 'UPDATE #tRECEIPT'
                             + ' SET ' + @c_UpdateCol + ' = (' + @c_SQL + ')'
                             + ' WHERE RowRef = @n_RowRef_RH'
                  SET @c_SQLParms = '@n_RowRef_PH  INT'
                                  +',@n_RowRef_RH  INT'
                                  +',@c_PoKey      NVARCHAR(18)'        --(Wan02)
                  EXEC sp_ExecuteSQL @c_SQL
                           , @c_SQLParms
                           , @n_RowRef_PH
                           , @n_RowRef_RH
                           , @c_PoKey                                  --(Wan02)
               END
            END
            --(Wan02) - END
            --(Wan01) - START
            IF CHARINDEX(', ' + @c_UpdateCol, ',' + @c_SQL_UPD_FIELDS, 1) = 0
            BEGIN
               SET @c_SQL_UPD_FIELDS = @c_SQL_UPD_FIELDS + N', ' + @c_UpdateCol + N' = T.' + @c_UpdateCol    --use T alias insert from #tReceipt T
            END
            --(Wan01) - END
            FETCH NEXT FROM @CUR_COLMAP INTO @c_Code, @c_Code2
         END
         CLOSE @CUR_COLMAP
         DEALLOCATE @CUR_COLMAP
         -- Call Custom Header Mapping - END
         SET @n_RowRef_PD = 0
         WHILE 1 = 1
         BEGIN
            SET @c_POLineNumber = ''
            SET @c_ExternLineNo = ''
            SET @c_Sku          = ''
            SET @c_AltSku       = ''
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
            SELECT Top 1
                   @n_RowRef_PD = PD.RowRef
                  ,@c_POLineNumber = PD.POLineNumber
                  ,@c_ExternLineNo = PD.ExternLineNo              --(Wan04)
                  ,@c_Sku          = PD.Sku
                  ,@c_Lottable01   = PD.Lottable01
                  ,@c_Lottable02   = PD.Lottable02
                  ,@c_Lottable03   = PD.Lottable03
                  ,@dt_Lottable04  = PD.Lottable04
                  ,@dt_Lottable05  = PD.Lottable05
                  ,@c_Lottable06   = PD.Lottable06
                  ,@c_Lottable07   = PD.Lottable07
                  ,@c_Lottable08   = PD.Lottable08
                  ,@c_Lottable09   = PD.Lottable09
                  ,@c_Lottable10   = PD.Lottable10
                  ,@c_Lottable11   = PD.Lottable11
                  ,@c_Lottable12   = PD.Lottable12
                  ,@dt_Lottable13  = PD.Lottable13
                  ,@dt_Lottable14  = PD.Lottable14
                  ,@dt_Lottable15  = PD.Lottable15
            FROM #tPODETAIL PD
            WHERE PD.POKey = @c_POKey
            AND PD.RowRef > @n_RowRef_PD
            ORDER BY PD.RowRef
            IF @@ROWCOUNT = 0 OR @c_POLineNumber = ''
            BEGIN
               BREAK
            END
            --(Wan04) - START
            SET @c_AllowPopulateSamePOLine = '0'
            SELECT @c_AllowPopulateSamePOLine = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, @c_Sku, 'AllowPopulateSamePOLine')
            IF @c_AllowPopulateSamePOLine = '0'
            BEGIN
               IF EXISTS ( SELECT 1
                           FROM RECEIPTDETAIL RD (NOLOCK)
                           WHERE RD.POkey = @c_POKey
                           AND RD.ExternLineNo = @c_ExternLineNo
                           AND RD.Receiptkey = @c_ReceiptKey
                         )
               BEGIN
                  CONTINUE
               END
            END
            --(Wan04) - END
            SET @c_ReceiptLoc = ''
            SET @c_ReturnLoc  = ''
            SET @c_ReceiptInspectionLoc = ''
            SET @c_XDockReceiptLoc = ''
            SELECT @c_ReceiptLoc = ISNULL(ReceiptLoc,'')
                  ,@c_ReturnLoc  = ISNULL(ReturnLoc,'')
                  ,@c_XDockReceiptLoc      = ISNULL(XDockReceiptLoc,'')
                  ,@c_ReceiptInspectionLoc = ISNULL(ReceiptInspectionLoc,'')
                  ,@c_Lottable01Label = ISNULL(Lottable01Label,'')
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
                  ,@c_AltSku          = ISNULL(AltSku,'')
            FROM SKU WITH (NOLOCK)
            WHERE Storerkey = @c_Storerkey
            AND Sku = @c_Sku
            SET @c_Toloc = ''
            IF @c_DefaultLOC > '0'
            BEGIN
               SET @c_Toloc = CASE WHEN @c_Doctype = 'A' THEN ISNULL(@c_ReceiptLoc,'')
                                   WHEN @c_Doctype = 'R' AND ISNULL(@c_ReturnLoc,'') <> '' THEN ISNULL(@c_ReturnLoc,'')
                                   WHEN @c_DocType = 'X' THEN ISNULL(@c_XDockReceiptLoc, '')
                                   ELSE ''
                                   END
            END
            IF @c_Toloc = '' AND @c_DefaultRcptLOC <> ''
            BEGIN
               SET @c_Toloc = @c_DefaultRcptLOC
            END
            SET @c_Putawayloc = ''
            IF @c_DefaultReturnPickFace = '1' AND @c_Rectype <> 'NORMAL'
            BEGIN
               SELECT TOP 1 @c_Putawayloc = SL.Loc
               FROM SKUxLOC SL WITH (NOLOCK)
               JOIN LOC L WITH (NOLOCK) ON SL.Loc = L.Loc AND L.Facility = @c_Facility
               WHERE SL.Storerkey = @c_Storerkey
               AND   SL.Sku = @c_Sku
               AND   SL.LocationType IN ( 'CASE', 'PICK' )
            END
            --SET @c_ReceiptLineNumber = RIGHT( '00000' + CONVERT(NVARCHAR(5), CONVERT(INT, @c_ReceiptLineNumber) + 1), 5 )
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
                                           WHEN @n_Cnt = 9  THEN 'Lottable09'    --(Wan01)   Fixed missing lottabel09
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
                                           WHEN @n_Cnt = 9  THEN @c_Lottable09   --(Wan01)   Fixed missing lottabel09
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
                                           WHEN @n_Cnt = 9  THEN @c_Lottable09Label --(Wan01)   Fixed Missing lottable09
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
                  SET @c_SourceKey         = @c_ReceiptKey --+ @c_ReceiptLineNumber
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
                        ,  @c_Lottable01        = @c_Lottable01ReturnValue    OUTPUT
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
                        ,  @c_SourceType        = @c_SourceType_LARule        --2020-08-26 - fixed
                  END TRY
                  BEGIN CATCH
                     SET @n_Err = 559006
                     SET @c_ErrMsg = ERROR_MESSAGE()
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing ispLottableRule_Wrapper. (lsp_ASN_PopulatePODs_Wrapper)'
                                    + '(' + @c_ErrMsg + ')'
                  END CATCH
                  IF @b_Success = 0 OR @n_Err <> 0
                  BEGIN
                     --SET @n_Continue = 3   -- ZG01
                     --(Wan05) - START
                     INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType
                                                , LogWarningNo, ErrCode, ErrMsg)
                     VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_POKey, '', 'WARNING', 0, @n_Err, @c_Errmsg)
                     --EXEC [WM].[lsp_WriteError_List]
                     --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                     --   ,  @c_TableName   = @c_TableName
                     --   ,  @c_SourceType  = @c_SourceType
                     --   ,  @c_Refkey1     = @c_Receiptkey
                     --   ,  @c_Refkey2     = @c_POKey
                     --   ,  @c_Refkey3     = ''
                     --   --,  @c_WriteType   = 'ERROR'    -- ZG01
                     --   ,  @c_WriteType   = 'WARNING'    -- ZG01
                     --   ,  @n_err2        = @n_err
                     --   ,  @c_errmsg2     = @c_errmsg
                     --   ,  @b_Success     = @b_Success   --2020-09-15
                     --   ,  @n_err         = @n_err       --2020-09-15
                     --   ,  @c_errmsg      = @c_errmsg    --2020-09-15
                     --(Wan05) - END
                     --GOTO EXIT_SP    -- ZG01
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
            SET @c_Lottable01   = ISNULL(@c_Lottable01,'')  --2020-09-14
            SET @c_Lottable02   = ISNULL(@c_Lottable02,'')  --2020-09-14
            SET @c_Lottable03   = ISNULL(@c_Lottable03,'')  --2020-09-14
            SET @c_Lottable06   = ISNULL(@c_Lottable06,'')  --2020-09-14
            SET @c_Lottable07   = ISNULL(@c_Lottable07,'')  --2020-09-14
            SET @c_Lottable08   = ISNULL(@c_Lottable08,'')  --2020-09-14
            SET @c_Lottable09   = ISNULL(@c_Lottable09,'')  --2020-09-14
            SET @c_Lottable10   = ISNULL(@c_Lottable10,'')  --2020-09-14
            SET @c_Lottable11   = ISNULL(@c_Lottable11,'')  --2020-09-14
            SET @c_Lottable12   = ISNULL(@c_Lottable12,'')  --2020-09-14
            SET @c_Altsku       = ISNULL(@c_Altsku,'')      --2020-08-13
            SET @c_ToLoc        = ISNULL(@c_ToLoc,'')       --2020-09-15
            --SET @c_ExternLineNo = ISNULL(@c_ExternLineNo,'')--2020-09-15
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
               ,  @c_ReceiptLineNumber
               ,  PD.Storerkey
               ,  PD.Sku
               ,  @c_AltSku
               ,  Packkey = ISNULL(PD.Packkey,'')
               ,  UOM     = ISNULL(PD.UOM,'')
               ,  QtyExpected = PD.QtyOrdered - PD.QtyReceived
               ,  FreeGoodQtyExpected = 0
               ,  ToLoc = @c_ToLoc
               ,  PD.ToID
               ,  PutawayLoc = @c_Putawayloc
               ,  ExternReceiptKey = ISNULL(PD.ExternPOKey,'')
               ,  POKey       = ISNULL(PD.POKey,'')
               ,  POLineNumber= ISNULL(PD.POLineNumber,'')
               ,  ExternPOKey = ISNULL(PD.ExternPOKey,'')
               ,  ExternLineNo= ISNULL(PD.ExternLineNo,'')
               ,  Vesselkey = ''
               ,  Voyagekey = ''
               ,  @c_Lottable01
               ,  @c_Lottable02
               ,  @c_Lottable03
               ,  @dt_Lottable04
               ,  @dt_Lottable05
               ,  @c_Lottable06
               ,  @c_Lottable07
               ,  @c_Lottable08
               ,  @c_Lottable09
               ,  @c_Lottable10
               ,  @c_Lottable11
               ,  @c_Lottable12
               ,  @dt_Lottable13
               ,  @dt_Lottable14
               ,  @dt_Lottable15
               ,  PD.UserDefine01
               ,  PD.UserDefine02
               ,  PD.UserDefine03
               ,  PD.UserDefine04
               ,  PD.UserDefine05
               ,  PD.UserDefine06
               ,  PD.UserDefine07
               ,  PD.UserDefine08
               ,  PD.UserDefine09
               ,  PD.UserDefine10
               ,  SubReasonCode = ''
               ,  PD.Channel
            FROM #tPODETAIL PD
            WHERE PD.RowRef = @n_RowRef_PD
            SET @n_RowRef_RD = @@IDENTITY
            --(Wan01) - START
            SET @c_SQL_INS_FIELDS =
                 N', Storerkey'
                + ', Sku'
                + ', AltSku'
                + ', Packkey'
                + ', UOM'
                + ', QtyExpected'
                + ', FreeGoodQtyExpected'
                + ', ToLoc'
                + ', ToID'
                + ', PutawayLoc'
                + ', ExternReceiptKey'
                + ', POKey'
                + ', POLineNumber'
                + ', ExternPOKey'
                + ', ExternLineNo'
                + ', Vesselkey'
                + ', Voyagekey'
                + ', Lottable01'
                + ', Lottable02'
                + ', Lottable03'
                + ', Lottable04'
                + ', Lottable05'
                + ', Lottable06'
                + ', Lottable07'
                + ', Lottable08'
                + ', Lottable09'
                + ', Lottable10'
                + ', Lottable11'
                + ', Lottable12'
                + ', Lottable13'
                + ', Lottable14'
                + ', Lottable15'
                + ', UserDefine01'
                + ', UserDefine02'
                + ', UserDefine03'
                + ', UserDefine04'
                + ', UserDefine05'
                + ', UserDefine06'
                + ', UserDefine07'
                + ', UserDefine08'
                + ', UserDefine09'
                + ', UserDefine10'
                + ', SubReasonCode'
                + ', Channel'
            --(Wan01) - END
            -- Call Custom Detail Mapping - START
            SET @c_ListName = 'PO2ASNMAP'
            SET @CUR_COLMAP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Code  = CL.Code
                  ,Code2 = CL.Code2
            FROM CODELKUP CL WITH (NOLOCK)
            WHERE CL.ListName = @c_ListName
            AND   CL.Short = 'D'
            AND   CL.Storerkey = @c_Storerkey
            AND   CL.UDF03 = ''
            UNION                                                                                     --(Wan01)
            SELECT Code  = CL.Code
                  ,Code2 = CL.Code2
            FROM CODELKUP CL WITH (NOLOCK)
            WHERE CL.ListName = @c_ListName
            AND   CL.Short = 'D'
            AND   CL.Storerkey = @c_Storerkey
            AND  @c_DocType IN (SELECT LTRIM(RTRIM(ss.value)) FROM STRING_SPLIT(CL.UDF03,',') AS ss)  --(Wan01)
            ORDER BY CL.Code
            OPEN @CUR_COLMAP
            FETCH NEXT FROM @CUR_COLMAP INTO @c_Code, @c_Code2
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SET @c_ReturnSQL = ''
               SET @c_UpdateCol = ''
               BEGIN TRY
                  EXEC [WM].[lsp_Populate_GetDocFieldsMap]
                     @c_SourceTable       =  'PODETAIL'
                  ,  @c_Sourcekey         =  @c_POkey
                  ,  @c_SourceLineNumber  =  @c_POLineNumber
                  ,  @c_ListName          =  @c_ListName
                  ,  @c_Code              =  @c_Code
                  ,  @c_Storerkey         =  @c_Storerkey
                  ,  @c_Code2             =  @c_Code2
                  ,  @c_DBName            =  @c_DBName
                  ,  @c_UpdateCol         =  @c_UpdateCol   OUTPUT
                  ,  @c_ReturnSQL         =  @c_ReturnSQL   OUTPUT
               END TRY
               BEGIN CATCH
                  SET @n_Continue = 3
                  SET @n_Err = 559007
                  SET @c_ErrMsg = ERROR_MESSAGE()
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing lsp_Populate_GetDocFieldsMap - DETAIL. (lsp_ASN_PopulatePODs_Wrapper)'
                                 + '(' + @c_ErrMsg + ')'
                  --(Wan05) - START
                  INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
                  VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_POKey, '', 'ERROR', 0, @n_Err, @c_Errmsg)
                  --EXEC [WM].[lsp_WriteError_List]
                  --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                  --   ,  @c_TableName   = @c_TableName
                  --   ,  @c_SourceType  = @c_SourceType
                  --   ,  @c_Refkey1     = @c_Receiptkey
                  --   ,  @c_Refkey2     = @c_POKey
                  --   ,  @c_Refkey3     = ''
                  --   ,  @c_WriteType   = 'ERROR'
                  --   ,  @n_err2        = @n_err
                  --   ,  @c_errmsg2     = @c_errmsg
                  --   ,  @b_Success     = @b_Success   --2020-09-15
                  --   ,  @n_err         = @n_err       --2020-09-15
                  --   ,  @c_errmsg      = @c_errmsg    --2020-09-15
                  --(Wan05) - END
                  GOTO EXIT_SP
               END CATCH
               SET @c_UpdateCol = RTRIM(LTRIM(@c_UpdateCol))      -- Wan01
               IF @c_ReturnSQL <> ''
               BEGIN
                  --(Wan02) - START
                  --SET @c_SQL = REPLACE(@c_ReturnSQL, ' FromValue', ' Top 1 FromValue')
                  SET @c_SQL = @c_ReturnSQL
                  -- Direct mapping
                  IF CHARINDEX('WHERE', @c_ReturnSQL ) = 0
                  BEGIN
                     SET @c_SQL = REPLACE(@c_SQL, ' PO ', ' #tPO PO ')
                     SET @c_SQL = REPLACE(@c_SQL, ' PODETAIL ', ' #tPODETAIL PODETAIL ')
                     IF CHARINDEX('#tPODETAIL', @c_SQL) > 0
                            SET @c_SQL = @c_SQL + ' WHERE PODETAIL.RowRef = @n_RowRef_PD'
                  END
                  --IF CHARINDEX(' FROM ', @c_ReturnSQL) > 0
                  --BEGIN
                  --   IF CHARINDEX('WHERE', @c_ReturnSQL) = 0
                  --   BEGIN
                  --      SET @c_SQL = @c_SQL + ' WHERE'
                  --   END
                  --   ELSE
                  --   BEGIN
                  --      SET @c_SQL = @c_SQL + ' AND'
                  --   END
                  --   SET @c_SQL = @c_SQL + ' PODETAIL.RowRef = @n_RowRef_PD'
                  --END
                  --(Wan02) - END
                  IF @c_SQL <> ''
                  BEGIN
                     SET @c_SQL = 'UPDATE #tRECEIPTDETAIL'
                                + ' SET ' + @c_UpdateCol + ' = (' + @c_SQL + ')'
                                + ' WHERE RowRef = @n_RowRef_RD'
                     SET @c_SQLParms = '@n_RowRef_PD     INT'
                                     +',@n_RowRef_RD     INT'
                                     +',@c_PoKey         NVARCHAR(18)'        --(Wan02)
                                     +',@c_POLineNumber  NVARCHAR(5)'         --(Wan02)
                     EXEC sp_ExecuteSQL @c_SQL
                              , @c_SQLParms
                              , @n_RowRef_PD
                              , @n_RowRef_RD
                              , @c_PoKey                                     --(Wan02)
                              , @c_POLineNumber                              --(Wan02)
                  END
               END
               --(Wan01) - START
               IF CHARINDEX(', ' + @c_UpdateCol, @c_SQL_INS_FIELDS, 1) = 0
               BEGIN
                  SET @c_SQL_INS_FIELDS = @c_SQL_INS_FIELDS + N', '   + @c_UpdateCol
               END
               --(Wan01) - END
               FETCH NEXT FROM @CUR_COLMAP INTO @c_Code, @c_Code2
            END
            CLOSE @CUR_COLMAP
            DEALLOCATE @CUR_COLMAP
         END
      END
      SET @n_RowCnt_RH = 0
      SET @n_RowCnt_RD = 0
      BEGIN TRAN
      IF EXISTS ( SELECT 1 FROM #tRECEIPT H JOIN #tRECEIPTDETAIL D ON H.ReceiptKey = D.Receiptkey )
      BEGIN
         BEGIN TRY
            --(Wan01) - START
            SET @c_SQL_UPD_FIELDS
            = N' UPDATE RECEIPT WITH (ROWLOCK) SET'
            + @c_SQL_UPD_FIELDS
            + ' FROM #tRECEIPT T'
            + ' JOIN RECEIPT RH ON (T.ReceiptKey = RH.ReceiptKey)'
            + ' WHERE T.RowRef = @n_RowRef_RH'
            SET @c_SQLParms = N'@n_RowRef_RH INT'
            EXEC sp_ExecuteSQL @c_SQL_UPD_FIELDS
                              ,@c_SQLParms
                              ,@n_RowRef_RH
            --(Wan01) - END
            SET @n_RowCnt_RH = @@ROWCOUNT
         END TRY
         BEGIN CATCH
            ROLLBACK TRAN
            WHILE @@TRANCOUNT < @n_StartTCnt
            BEGIN
               BEGIN TRAN
            END
            SET @n_Continue = 3
            SET @n_Err = 559008
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': UPDATE RECEIPT Table Fail. (lsp_ASN_PopulatePODs_Wrapper)'
                           + '(' + @c_ErrMsg + ')'
            --(Wan05) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_POKey, '', 'ERROR', 0, @n_Err, @c_Errmsg)
            --EXEC [WM].[lsp_WriteError_List]
            --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
            --   ,  @c_TableName   = @c_TableName
            --   ,  @c_SourceType  = @c_SourceType
            --   ,  @c_Refkey1     = @c_Receiptkey
            --   ,  @c_Refkey2     = @c_POKey
            --   ,  @c_Refkey3     = ''
            --   ,  @c_WriteType   = 'ERROR'
            --   ,  @n_err2        = @n_err
            --   ,  @c_errmsg2     = @c_errmsg
            --   ,  @b_Success     = @b_Success
            --   ,  @n_err         = @n_err
            --   ,  @c_errmsg      = @c_errmsg
            --(Wan05) - END
         END CATCH
         SET @n_ReceiptLineNumber = 0
         SELECT TOP 1 @n_ReceiptLineNumber = CONVERT(INT, RD.ReceiptLineNumber)
         FROM RECEIPTDETAIL RD WITH (NOLOCK)
         WHERE RD.ReceiptKey = @c_ReceiptKey
         ORDER BY RD.ReceiptLineNumber DESC
         BEGIN TRY
            --(Wan01) - START
            SET @c_SQL_INS_FIELDS
            = N'INSERT INTO RECEIPTDETAIL ( Receiptkey, ReceiptLineNumber'
            + @c_SQL_INS_FIELDS
            + ')'
            +' SELECT Receiptkey'
            +',RIGHT( ''00000'' + CONVERT(NVARCHAR(5), (ROW_NUMBER() OVER (ORDER BY RowRef)) + @n_ReceiptLineNumber), 5 )'
            + @c_SQL_INS_FIELDS
            +' FROM #tRECEIPTDETAIL'
            +' ORDER BY RowRef'
            SET @c_SQLParms = N'@n_ReceiptLineNumber INT'
            EXEC sp_ExecuteSQL @c_SQL_INS_FIELDS
                              ,@c_SQLParms
                              ,@n_ReceiptLineNumber
            --(Wan01) - END
            SET @n_RowCnt_RD = @@ROWCOUNT
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
            SET @n_Err = 559009
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': INSERT RECEIPTDETAIL Table Fail. (lsp_ASN_PopulatePODs_Wrapper)'
                           + '(' + @c_ErrMsg + ')'
            --(Wan05) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, '', '', 'ERROR', 0, @n_Err, @c_Errmsg)
            --EXEC [WM].[lsp_WriteError_List]
            --   @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
            --,  @c_TableName   = @c_TableName
            --,  @c_SourceType  = @c_SourceType
            --,  @c_Refkey1     = @c_Receiptkey
            --,  @c_Refkey2     = ''
            --,  @c_Refkey3     = ''
            --,  @c_WriteType   = 'ERROR'
            --,  @n_err2        = @n_err
            --,  @c_errmsg2     = @c_errmsg
            --,  @b_Success     = @b_Success
            --,  @n_err         = @n_err
            --,  @c_errmsg      = @c_errmsg
            --(Wan05) - END
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
         IF @n_Continue = 1 AND @n_RowCnt_RH > 0 AND @n_RowCnt_RD > 0
         BEGIN
            SET @c_errmsg = 'PO Lines populates to ASN successully.'
            --(Wan05) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, '', '', 'MESSAGE', 0, @n_Err, @c_Errmsg)
            --EXEC [WM].[lsp_WriteError_List]
            --   @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
            --,  @c_TableName   = @c_TableName
            --,  @c_SourceType  = @c_SourceType
            --,  @c_Refkey1     = @c_Receiptkey
            --,  @c_Refkey2     = ''
            --,  @c_Refkey3     = ''
            --,  @c_WriteType   = 'MESSAGE'
            --,  @n_err2        = @n_err
            --,  @c_errmsg2     = @c_errmsg
            --,  @b_Success     = @b_Success
            --,  @n_err         = @n_err
            --,  @c_errmsg      = @c_errmsg
            --(Wan05) - END
            GOTO EXIT_SP
         END
      END
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      --Log Error to WMS_Error_List
      --(Wan05) - START
      INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
      VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_POKey, '', 'ERROR', 0, @n_Err, @c_Errmsg)
      --EXEC [WM].[lsp_WriteError_List]        --(Wan02)
      --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
      --   ,  @c_TableName   = @c_TableName
      --   ,  @c_SourceType  = @c_SourceType
      --   ,  @c_Refkey1     = @c_Receiptkey
      --   ,  @c_Refkey2     = @c_POKey
      --   ,  @c_Refkey3     = ''
      --   ,  @c_WriteType   = 'ERROR'
      --   ,  @n_err2        = @n_err
      --   ,  @c_errmsg2     = @c_errmsg
      --   ,  @b_Success     = @b_Success
      --   ,  @n_err         = @n_err
      --   ,  @c_errmsg      = @c_errmsg
      --(Wan05) - END
      GOTO EXIT_SP
   END CATCH
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_ASN_PopulatePODs_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   --(Wan05) - START
   SET @CUR_ERRLIST = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   twl.TableName
         ,  twl.SourceType
         ,  twl.Refkey1
         ,  twl.Refkey2
         ,  twl.Refkey3
         ,  twl.WriteType
         ,  twl.LogWarningNo
         ,  twl.ErrCode
         ,  twl.Errmsg
   FROM @t_WMSErrorList AS twl
   ORDER BY twl.RowID
   OPEN @CUR_ERRLIST
   FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName
                                     , @c_SourceType
                                     , @c_Refkey1
                                     , @c_Refkey2
                                     , @c_Refkey3
                                     , @c_WriteType
                                     , @n_LogWarningNo
                                     , @n_Err
                                     , @c_Errmsg
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXEC [WM].[lsp_WriteError_List]
         @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
      ,  @c_TableName   = @c_TableName
      ,  @c_SourceType  = @c_SourceType
      ,  @c_Refkey1     = @c_Refkey1
      ,  @c_Refkey2     = @c_Refkey2
      ,  @c_Refkey3     = @c_Refkey3
      ,  @n_LogWarningNo= @n_LogWarningNo
      ,  @c_WriteType   = @c_WriteType
      ,  @n_err2        = @n_err
      ,  @c_errmsg2     = @c_errmsg
      ,  @b_Success     = @b_Success
      ,  @n_err         = @n_err
      ,  @c_errmsg      = @c_errmsg
      FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName
                                        , @c_SourceType
                                        , @c_Refkey1
                                        , @c_Refkey2
                                        , @c_Refkey3
                                        , @c_WriteType
                                        , @n_LogWarningNo
                                        , @n_Err
                                        , @c_Errmsg
   END
   CLOSE @CUR_ERRLIST
   DEALLOCATE @CUR_ERRLIST
   --(Wan05) - END
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   REVERT
END

GO