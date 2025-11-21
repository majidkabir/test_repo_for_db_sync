SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: lsp_ASN_PopulatePOs_Wrapper                         */
/* Creation Date: 2019-05-07                                            */
/* Copyright: LFL                                                       */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-1819 - Populate PO Header                              */
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
/* 2020-09-14  Wan01    1.1   Fixed Lottables Nullable                  */
/* 2020-09-15  Wan01    1.2   Fixed Nullable column insert into detail  */
/* 28-Dec-2020 SWT01    1.3   Adding Begin Try/Catch                    */
/* 15-Jan-2021 Wan02    1.4   Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2021-06-08  Wan03    1.5   LFWM-2831-UAT - TW Missing ExternReceiptKey*/
/*                            in detail lines when Populate PO to Receipt*/
/*                            1 PO - 1 ASN                              */
/* 2021-06-25  Wan04    1.6   LFWM-2854 - UAT - TW  Receipt - Populate  */
/*                            from PO ( 1 PO 1 ASN ) in SCE does not    */
/*                            support codelkup 'PO2ASNMAP               */
/* 2021-09-23  LZG      1.7   JSM-21916 - Allowed PO population continue*/
/*                            after warning (ZG01)                      */
/* 2021-20-26  NJOW01   1.8   DEVOPS combine script                     */
/* 2021-20-26  NJOW01   1.9   WMS-17224 fix pokeylist delimiter pass to */
/*                            sub-stored proc.                          */
/* 2021-12-21  Wan05    2.0   LFWM-3210 - SCE UAT SG ASN Should Not     */
/*                            Populate Same POKey+POLinenumber          */
/* 2023-03-01  Wan06    3.0   LFWM-3874 - [CN] SCE populate all for PO  */
/* 2023-09-06  USH07    3.0   UWP-22179 - NoSamePO2DiffASN maintained   */
/*                                                                      */
/************************************************************************/
CREATE   PROC [WM].[lsp_ASN_PopulatePOs_Wrapper]
      @c_ReceiptKey           NVARCHAR(10)
   ,  @c_POKeyList            NVARCHAR(MAX) = ''   --Wan06-- PO Keys seperated by '|' 
   ,  @c_PopulateType         NVARCHAR(10)   = ''  -- Populate type, '1PO1ASN' if 1 PO to 1 ASN. 'MPO1ASN' if Many PO to 1 ASN
   ,  @b_PopulateFromArchive  INT = 0              -- Pass in 1 if Populate PO from Archive DB
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
         ,  @n_RowRef_PH               INT = 0
         ,  @n_RowRef_PD               INT = 0
         ,  @n_RowRef_RH               INT = 0
         ,  @n_RowRef_RD               INT = 0
         ,  @b_UnMatchFacility         BIT = 0

         ,  @c_DBName                  NVARCHAR(30)   = ''
         ,  @c_ArchiveDB               NVARCHAR(30)   = ''

         ,  @c_Facility                NVARCHAR(5)    = ''
         ,  @c_Storerkey               NVARCHAR(15)   = ''
         ,  @c_NewReceiptkey           NVARCHAR(10)   = ''
         ,  @c_ExternReceiptkey        NVARCHAR(30)   = ''
         ,  @c_DocType                 NVARCHAR(10)   = ''
         ,  @c_Rectype                 NVARCHAR(10)   = ''
         ,  @c_WarehouseReference      NVARCHAR(18)   = ''
         ,  @c_UserDefine01            NVARCHAR(30)   = ''
         ,  @c_ReceiptLineNumber       NVARCHAR(5)    = ''
         ,  @c_ToLoc                   NVARCHAR(10)   = ''
         ,  @c_PutawayLoc              NVARCHAR(10)   = ''
         ,  @c_VesselKey               NVARCHAR(18)   = ''
         ,  @c_VoyageKey               NVARCHAR(18)   = ''
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

         ,  @c_POType                  NVARCHAR(10)   = ''
         ,  @c_POkey                   NVARCHAR(10)   = ''
         ,  @c_POLineNumber            NVARCHAR(5)    = ''
         ,  @c_ExternPOKey             NVARCHAR(30)   = ''
         ,  @c_ExternLineNo            NVARCHAR(20)   = ''
         ,  @c_Sku                     NVARCHAR(20)   = ''
         ,  @c_Altsku                  NVARCHAR(20)   = ''  --2020-08-13

         ,  @c_Code                    NVARCHAR(30)   = ''
         ,  @c_Code2                   NVARCHAR(30)   = ''
         ,  @c_UpdateCol               NVARCHAR(60)   = ''
         ,  @c_ReturnSQL               NVARCHAR(MAX)  = ''
         ,  @c_SQL                     NVARCHAR(4000) = ''
         ,  @c_SQLParms                NVARCHAR(4000) = ''

         ,  @c_SQL_INS_FIELDS          NVARCHAR(4000) = ''     --(Wan04)
         ,  @c_SQL_UPD_FIELDS          NVARCHAR(4000) = ''        --(Wan04)

         ,  @c_SQLSchema_Prior         NVARCHAR(4000) = ''
         ,  @c_SQLSchema               NVARCHAR(4000) = ''
         ,  @c_TableColumns_Prior      NVARCHAR(4000) = ''
         ,  @c_TableColumns            NVARCHAR(4000) = ''
         ,  @c_Table                   NVARCHAR(60) = ''
         ,  @c_Table_Prior             NVARCHAR(60) = ''
         ,  @c_ColumnName              NVARCHAR(128)  = ''
         ,  @c_DataType                NVARCHAR(128)  = ''
         ,  @c_ColLength               NVARCHAR(5)    = ''

         ,  @c_TableName               NVARCHAR(50)   = 'RECEIPTDETAIL'
         ,  @c_SourceType              NVARCHAR(50)   = 'lsp_ASN_PopulatePOs_Wrapper'

         ,  @c_SourceKey               NVARCHAR(50)   = ''
         ,  @c_SourceType_LARule       NVARCHAR(50)   = ''

         ,  @c_ReceiptLoc              NVARCHAR(10)   = ''
         ,  @c_ReturnLoc               NVARCHAR(10)   = ''
         ,  @c_ReceiptInspectionLoc    NVARCHAR(10)   = ''
         ,  @c_XDockReceiptLoc         NVARCHAR(10)   = ''

         ,  @c_UpdExPOKey2ExASNKey     NVARCHAR(30)   = ''
         ,  @c_AllowPopulateSamePOLine NVARCHAR(30)   = ''
         ,  @c_UCCTracking             NVARCHAR(30)   = ''
         ,  @c_DefaultLOC              NVARCHAR(30)   = ''
         ,  @c_DefaultRcptLOC          NVARCHAR(30)   = ''
         ,  @c_QCLocation              NVARCHAR(30)   = ''
         ,  @c_DefaultReturnPickFace   NVARCHAR(30)   = ''
         ,  @c_POKeyListParam          NVARCHAR(MAX) = '' --NJOW01      --Wan06

         ,  @CUR_SCHEMA                CURSOR
         ,  @CUR_INVALIDPO             CURSOR
         ,  @CUR_COLMAP                CURSOR

   SET @b_Success = 1
   SET @n_Err     = 0

   IF SUSER_SNAME() <> @c_UserName        --(Wan02) - START
   BEGIN
      EXEC [WM].[lsp_SetUser]
            @c_UserName = @c_UserName  OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT

      IF @n_Err <> 0
      BEGIN
         GOTO EXIT_SP
      END

      EXECUTE AS LOGIN = @c_UserName      --(Wan02) - END
   END

   BEGIN TRY -- SWT01 - Begin Outer Begin Try

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
            ,@c_WarehouseReference = RH.WarehouseReference
            ,@c_UserDefine01 = RH.UserDefine01
      FROM RECEIPT RH WITH (NOLOCK)
      WHERE RH.ReceiptKey = @c_ReceiptKey

      /*-------------------------------------------------------*/
      /* BUILD TEMP TABLES & INSERT DATA - START               */
      /*-------------------------------------------------------*/
      IF OBJECT_ID('tempdb..#tPOs', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tPOs
      END


      CREATE TABLE #tPOs
         (  RowRef      INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
         ,  PORefKey    NVARCHAR(10)   NOT NULL DEFAULT('')
         )

      INSERT INTO #tPOs (PORefKey)
      SELECT DISTINCT T.[Value] FROM string_split (@c_POKeyList, '|') T

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
      SELECT col.Table_Name
            ,col.column_name
            ,col.data_type
            ,Col.CHARACTER_MAXIMUM_LENGTH
      FROM INFORMATION_SCHEMA.COLUMNS Col WITH (NOLOCK)
      WHERE col.Table_Name IN ('PO', 'PODETAIL', 'RECEIPT', 'RECEIPTDETAIL')
      ORDER BY CASE WHEN Col.Table_Name = 'PO' THEN 2
                    WHEN Col.Table_Name = 'PODETAIL' THEN 4
                    WHEN Col.Table_Name = 'RECEIPT' THEN 6
                    WHEN Col.Table_Name = 'RECEIPTDETAIL' THEN 8
                    END
            ,  Col.ORDINAL_POSITION
      OPEN @CUR_SCHEMA

      FETCH NEXT FROM @CUR_SCHEMA INTO @c_Table, @c_ColumnName, @c_datatype, @c_ColLength

      WHILE 1 = 1
      BEGIN
         IF @c_Table_Prior <> @c_Table OR @@FETCH_STATUS = -1
         BEGIN
            IF @c_SQLSchema_Prior <> '' AND @c_TableColumns_Prior <> ''
            BEGIN
               SET @c_SQLSchema_Prior = SUBSTRING(@c_SQLSchema_Prior, 1, LEN(@c_SQLSchema_Prior) - 1)
               SET @c_SQL = N'ALTER TABLE #t' + @c_Table_Prior + ' ADD ' + @c_SQLSchema_Prior

               EXEC sp_ExecuteSQL @c_SQL
               SET @c_TableColumns_Prior = SUBSTRING(@c_TableColumns_Prior, 1, LEN(@c_TableColumns_Prior) - 1)
               IF @c_Table_Prior = 'PO'
               BEGIN
                  SET @c_SQL = N'INSERT INTO #tPO ( ' + @c_TableColumns_Prior + ' )'
                             + ' SELECT ' + @c_TableColumns_Prior + ' FROM #tPOs T'
                             + ' JOIN ' + RTRIM(@c_DBName) + 'dbo.PO PO WITH (NOLOCK) ON PO.POKey = T.PORefKey'
                             + ' WHERE PO.[Status] NOT IN (''9'', ''CANCELLED'', ''CLOSED'')'
                             + ' AND PO.ExternStatus NOT IN (''9'', ''CANC'')'

                  EXEC sp_ExecuteSQL @c_SQL
                                    ,@c_SQLParms
               END

               IF @c_Table_Prior = 'PODETAIL'
               BEGIN
                  SET @c_SQL = N'INSERT INTO #tPODETAIL  (' + @c_TableColumns_Prior + ')'
                             + ' SELECT ' + @c_TableColumns_Prior
                             + ' FROM #tPOs T'
                             + ' JOIN ' + RTRIM(@c_DBName) + 'dbo.PODETAIL PD WITH (NOLOCK)'
                             +                               ' ON T.PORefKey= PD.POKey'
                             + ' WHERE ((PD.Facility = @c_Facility AND @c_Facility <> '''') OR'
                             + ' (PD.Facility = '''' OR PD.Facility IS NULL))'
                             + ' AND PD.QtyReceived <= PD.QtyOrdered'
                             + ' ORDER BY PD.POKey, PD.POLineNumber'
                  SET @c_SQLParms = N'@c_Facility NVARCHAR(5)'

                  EXEC sp_ExecuteSQL @c_SQL
                                    ,@c_SQLParms
                                    ,@c_Facility

               END
            END

            IF @@FETCH_STATUS = -1
            BEGIN
               BREAK
            END

            SET @c_SQLSchema = ''
            SET @c_TableColumns = ''
         END
         SET @c_datatype = @c_datatype + CASE @c_datatype WHEN 'numeric' THEN '(15,5)'
                                                          WHEN 'nvarchar' THEN '(' + @c_ColLength + ')'
                                                          ELSE '' END
         IF @c_datatype <> 'timestamp'
         BEGIN
            SET @c_SQLSchema  = @c_SQLSchema + @c_ColumnName + ' ' + @c_datatype + ' NULL, '
            SET @c_TableColumns = @c_TableColumns + @c_ColumnName + ', '
         END

         SET @c_Table_Prior = @c_Table
         SET @c_SQLSchema_Prior = @c_SQLSchema
         SET @c_TableColumns_Prior  = @c_TableColumns
         FETCH NEXT FROM @CUR_SCHEMA INTO @c_Table, @c_ColumnName, @c_datatype, @c_ColLength
      END
      CLOSE @CUR_SCHEMA
      DEALLOCATE @CUR_SCHEMA

      /*-------------------------------------------------------*/
      /* BUILD TEMP TABLES & INSERT DATA - END                 */
      /*-------------------------------------------------------*/
      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo < 1
      BEGIN
         SET @n_WarningNo = 1
         SET @c_ErrMsg = 'Do you want to proceed Populate PO ?'
         SET @b_UnMatchFacility = 0

         SET @CUR_INVALIDPO = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.POKey FROM #tPOs PO
         JOIN PODETAIL PD WITH (NOLOCK) ON PO.PORefKey = PD.POKey
         WHERE (PD.Facility <> '' AND PD.Facility <> @c_Facility)
         GROUP BY PD.POKey       --(Wan04)
         ORDER BY PD.POKey

         OPEN @CUR_INVALIDPO

         FETCH NEXT FROM @CUR_INVALIDPO INTO @c_pokey

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @b_UnMatchFacility = 1
            SET @c_errmsg = 'PO ' + @c_POkey + ' contains unmatch facility detail record(s).'
            EXEC [WM].[lsp_WriteError_List]
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_Receiptkey
               ,  @c_Refkey2     = @c_POKey
               ,  @c_Refkey3     = ''
               ,  @c_WriteType   = 'WARNING'
               ,  @n_err2        = @n_err
               ,  @c_errmsg2     = @c_errmsg
               ,  @b_Success     = @b_Success   --2020-09-15
               ,  @n_err         = @n_err       --2020-09-15
               ,  @c_errmsg      = @c_errmsg    --2020-09-15

            FETCH NEXT FROM @CUR_INVALIDPO INTO @c_pokey
         END
         CLOSE @CUR_INVALIDPO
         DEALLOCATE @CUR_INVALIDPO

         IF @b_UnMatchFacility = 1
         BEGIN
            SET @c_ErrMsg = 'Do you want to proceed Populate PO that Matches ASN Facility ?'
         END

         EXEC [WM].[lsp_WriteError_List]
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_Receiptkey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = ''
            ,  @c_WriteType   = 'QUESTION'
            ,  @n_err2        = @n_err
            ,  @c_errmsg2     = @c_errmsg
            ,  @b_Success     = @b_Success   --2020-09-15
            ,  @n_err         = @n_err       --2020-09-15
            ,  @c_errmsg      = @c_errmsg    --2020-09-15

         GOTO EXIT_SP
      END

      /*SET @c_POKeyList = ''
      SET @c_POKeyList = RTRIM(ISNULL(CONVERT(VARCHAR(4000),            --2020-09-21
                                          (  SELECT RTRIM(T.PORefKey) + '/ '
                                             FROM #tPOs T
                                             ORDER BY T.RowRef
                                             FOR XML PATH(''), TYPE
                                          )
                                       ),''))*/

      --NJOW01
      SET @c_POKeyListParam = ''
      SET @c_POKeyListParam = RTRIM(ISNULL(CONVERT(NVARCHAR(MAX),            --Wan06
                                          (  SELECT RTRIM(T.PORefKey) + ','
                                             FROM #tPOs T
                                             ORDER BY T.RowRef
                                             FOR XML PATH(''), TYPE
                                          )
                                       ),''))
      SET @c_POKeyListParam = LEFT(@c_POKeyListParam , LEN(@c_POKeyListParam ) - 1)

      BEGIN TRY
         EXEC [dbo].[isp_PrePopulatePO_Wrapper]
              @c_Receiptkey   = @c_Receiptkey
            , @c_POKeys       = @c_POKeyListParam  --NJOW01
            , @c_POLineNumbers= ''
            , @b_Success      = @b_Success      OUTPUT
            , @n_Err          = @n_Err          OUTPUT
            , @c_ErrMsg       = @c_ErrMsg       OUTPUT
      END TRY

      BEGIN CATCH
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @n_Err = 556801
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_PrePopulatePO_Wrapper. (lsp_ASN_PopulatePOs_Wrapper)'
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
         EXEC [WM].[lsp_WriteError_List]
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_ReceiptKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = ''
            ,  @c_WriteType   = 'ERROR'
            ,  @n_err2        = @n_err
            ,  @c_errmsg2     = @c_errmsg
            ,  @b_Success     = @b_Success   --2020-09-15
            ,  @n_err         = @n_err       --2020-09-15
            ,  @c_errmsg      = @c_errmsg    --2020-09-15

         GOTO EXIT_SP
      END

      -- Get Storerconfig
      SELECT @c_UpdExPOKey2ExASNKey     = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'UpdExPOKey2ExASNKey')
      SELECT @c_UCCTracking = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'UCCTracking')
      SELECT @c_DefaultRcptLOC = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, @c_Sku, 'DefaultRcptLOC')

      IF @c_DefaultRcptLOC = '0'
      BEGIN
         SET @c_DefaultRcptLOC = ''
      END

      SELECT @c_VesselKey = CL.Code
      FROM CODELKUP CL WITH (NOLOCK)
      WHERE CL.ListName = 'STDWHSEID'
      AND CL.Long = '1'

      SELECT @c_VoyageKey = CL.Code
      FROM CODELKUP CL WITH (NOLOCK)
      WHERE CL.ListName = 'STDWHSEID'
      AND CL.Long = '1'

      SET @n_RowRef_PH = 0

      WHILE 1 = 1
      BEGIN
         SET @c_POKey = ''
         SET @c_POType= ''
         SELECT TOP 1
                @c_POKey = PO.POKey
               ,@c_POType= PO.POType
               ,@n_RowRef_PH = PO.RowRef
         FROM #tPO PO
         WHERE PO.RowRef > @n_RowRef_PH
         ORDER BY PO.RowRef

         IF @@ROWCOUNT = 0 OR @c_POKey = ''
         BEGIN
            BREAK
         END

         --(Wan03) = START
         IF @n_RowRef_PH > 1
         BEGIN
            SET @c_ExternReceiptkey = ''
         END
         --(Wan03) = END

         SET @c_ExternPOKey = ''
         SELECT TOP 1 @c_ExternPOKey = ISNULL(PD.ExternPOkey,'')
         FROM #tPODETAIL PD WITH (NOLOCK)
         WHERE PD.POkey = @c_POKey
         ORDER BY PD.POLineNumber

         IF @c_UpdExPOKey2ExASNKey = '1' AND @c_ExternPOKey <> ''
         BEGIN
            SET @c_ExternReceiptkey = CASE WHEN @c_ExternReceiptkey = '' THEN @c_ExternPOKey
                     WHEN @c_ExternReceiptkey <> @c_ExternPOKey THEN ''
                                           ELSE ''
                                           END
         END

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
            , SellerName
            , SellerCompany
            , SellerAddress1
            , SellerAddress2
            , SellerAddress3
            , SellerAddress4
            , SellerContact1
            , SellerContact2
            , SellerPhone1
            , SellerPhone2
            , SellerEmail1
            , SellerEmail2
            , SellerFax1
            , SellerFax2
            , SellerCountry
            , SellerCity
            , SellerState
            , SellerZip
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
             )
         SELECT
              Receiptkey = CASE WHEN @n_RowRef_PH = 1 THEN @c_Receiptkey ELSE '' END
            , Storerkey = @c_Storerkey
            , Facility  = @c_Facility
            , ExternReceiptkey = @c_ExternReceiptkey
            , RecType = CASE WHEN ISNULL(CL.Short,'') <> '' THEN ISNULL(CL.Short,'') ELSE @c_Rectype END --2020-08-13
            , DocType = @c_Doctype
            , WarehouseReference = @c_WarehouseReference
            , SellerName = LEFT(PO.SellerName,15)                                                        --2020-08-13
            , PO.SellerAddress1
            , PO.SellerAddress2
            , PO.SellerName
            , PO.SellerCompany
            , PO.SellerAddress1
            , PO.SellerAddress2
            , PO.SellerAddress3
            , PO.SellerAddress4
            , PO.SellerContact1
            , PO.SellerContact2
            , PO.SellerPhone
            , PO.SellerPhone2
            , PO.SellerEmail1
            , PO.SellerEmail2
            , PO.SellerFax1
            , PO.SellerFax2
            , PO.SellerCountry
            , PO.SellerCity
            , PO.SellerState
            , PO.SellerZip
            , PO.UserDefine01
            , PO.UserDefine02
            , PO.UserDefine03
            , PO.UserDefine04
            , PO.UserDefine05
            , PO.UserDefine06
            , PO.UserDefine07
            , PO.UserDefine08
            , PO.UserDefine09
            , PO.UserDefine10
         FROM #tPO PO
         LEFT JOIN CODELKUP CL WITH (NOLOCK) ON  CL.ListName = 'PO2ASNTYPE'
                                             AND CL.Code = PO.POType
         WHERE PO.RowRef = @n_RowRef_PH

         SET @n_RowRef_RH = @@IDENTITY

         --(Wan04) - START
         SET @c_SQL_INS_FIELDS =
                N', Storerkey'
               + ', Facility'
               + ', ExternReceiptkey'
               + ', RecType'
               + ', DocType'
               + ', WarehouseReference'
               + ', Carrierkey'
               + ', CarrierAddress1'
               + ', CarrierAddress2'
               + ', SellerName'
               + ', SellerCompany'
               + ', SellerAddress1'
               + ', SellerAddress2'
               + ', SellerAddress3'
               + ', SellerAddress4'
               + ', SellerContact1'
               + ', SellerContact2'
               + ', SellerPhone1'
               + ', SellerPhone2'
               + ', SellerEmail1'
               + ', SellerEmail2'
          + ', SellerFax1'
               + ', SellerFax2'
               + ', SellerCountry'
               + ', SellerCity'
               + ', SellerState'
               + ', SellerZip'
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

         SET @c_SQL_UPD_FIELDS =
                N' ExternReceiptkey   = T.ExternReceiptkey'
               +', RecType            = T.RecType'
               +', WarehouseReference = T.WarehouseReference'
               +', Carrierkey         = T.Carrierkey'
               +', CarrierAddress1    = T.CarrierAddress1'
               +', CarrierAddress2    = T.CarrierAddress2'
               +', SellerName         = T.SellerName'
               +', SellerCompany      = T.SellerCompany'
               +', SellerAddress1     = T.SellerAddress1'
               +', SellerAddress2     = T.SellerAddress2'
               +', SellerAddress3     = T.SellerAddress3'
               +', SellerAddress4     = T.SellerAddress4'
               +', SellerContact1     = T.SellerContact1'
               +', SellerContact2     = T.SellerContact2'
               +', SellerPhone1       = T.SellerPhone1'
               +', SellerPhone2       = T.SellerPhone2'
               +', SellerEmail1       = T.SellerEmail1'
               +', SellerEmail2       = T.SellerEmail2'
               +', SellerFax1         = T.SellerFax1'
               +', SellerFax2         = T.SellerFax2'
               +', SellerCountry      = T.SellerCountry'
               +', SellerCity         = T.SellerCity'
               +', SellerState        = T.SellerState'
               +', SellerZip          = T.SellerZip'
               +', UserDefine01       = T.UserDefine01'
               +', UserDefine02       = T.UserDefine02'
               +', UserDefine03       = T.UserDefine03'
               +', UserDefine04       = T.UserDefine04'
               +', UserDefine05       = T.UserDefine05'
               +', UserDefine06       = T.UserDefine06'
               +', UserDefine07       = T.UserDefine07'
               +', UserDefine08       = T.UserDefine08'
               +', UserDefine09       = T.UserDefine09'
               +', UserDefine10       = T.UserDefine10'
         --(Wan04) - END
         --
         -- Call Custom Header Mapping - START
         SET @c_ListName = 'PO2ASNMAP'
         SET @CUR_COLMAP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Code  = CL.Code
               ,Code2 = CL.Code2
         FROM CODELKUP CL WITH (NOLOCK)
         WHERE CL.ListName = @c_ListName
         AND   CL.Short = 'H'
         AND   CL.Storerkey = @c_Storerkey
         UNION                                                                                     --(Wan04)
         SELECT Code  = CL.Code
               ,Code2 = CL.Code2
         FROM CODELKUP CL WITH (NOLOCK)
         WHERE CL.ListName = @c_ListName
         AND   CL.Short = 'H'
         AND   CL.Storerkey = @c_Storerkey
         AND  @c_DocType IN (SELECT LTRIM(RTRIM(ss.value)) FROM STRING_SPLIT(CL.UDF03,',') AS ss)  --(Wan04)
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
               ,  @c_Code              =  @c_Code
               ,  @c_Storerkey         =  @c_Storerkey
               ,  @c_Code2             =  @c_Code2
               ,  @c_DBName            =  @c_DBName
               ,  @c_UpdateCol         =  @c_UpdateCol   OUTPUT
               ,  @c_ReturnSQL         =  @c_ReturnSQL   OUTPUT
            END TRY

            BEGIN CATCH
               SET @n_Continue = 3
               SET @n_Err = 556802
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing lsp_Populate_GetDocFieldsMap - Header. (lsp_ASN_PopulatePOs_Wrapper)'
                              + '(' + @c_ErrMsg + ')'

               EXEC [WM].[lsp_WriteError_List]
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_Receiptkey
                  ,  @c_Refkey2     = @c_POKey
                  ,  @c_Refkey3     = ''
                  ,  @c_WriteType   = 'ERROR'
                  ,  @n_err2        = @n_err
                  ,  @c_errmsg2     = @c_errmsg
                  ,  @b_Success     = @b_Success   --2020-09-15
                  ,  @n_err         = @n_err       --2020-09-15
                  ,  @c_errmsg      = @c_errmsg    --2020-09-15

               GOTO EXIT_SP
            END CATCH

            SET @c_UpdateCol = RTRIM(LTRIM(@c_UpdateCol))         --(Wan04)

            IF @c_ReturnSQL <> ''
            BEGIN
               --(Wan04) - START - 2021-07-20
               --SET @c_SQL = REPLACE(@c_ReturnSQL, ' FromValue', ' TOP 1 FromValue')
               SET @c_SQL = @c_ReturnSQL

               -- Direct mapping
               IF CHARINDEX('WHERE', @c_ReturnSQL ) = 0
               BEGIN
                  SET @c_SQL = REPLACE(@c_SQL, ' PO ', ' #tPO PO ')
                  SET @c_SQL = REPLACE(@c_SQL, ' PODETAIL ', ' #tPODETAIL PODETAIL ')
                  IF CHARINDEX('#tPO', @c_SQL) > 0
                         SET @c_SQL = @c_SQL + ' WHERE PO.RowRef = @n_RowRef_PH'
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
               --(Wan04) - END - 2021-07-20
               IF @c_SQL <> ''
               BEGIN
                  SET @c_SQL = 'UPDATE #tRECEIPT'
                             + ' SET ' + @c_UpdateCol + ' = (' + @c_SQL + ')'
                             + ' WHERE RowRef = @n_RowRef_RH'

                  SET @c_SQLParms = '@n_RowRef_PH  INT'
                                  +',@n_RowRef_RH  INT'
                                  +',@c_PoKey      NVARCHAR(18)'        --(Wan04)

                  EXEC sp_ExecuteSQL @c_SQL
                           , @c_SQLParms
                           , @n_RowRef_PH
                           , @n_RowRef_RH
                           , @c_PoKey                                  --(Wan04)
               END
            END

            --(Wan04) - START
            IF CHARINDEX(', ' + @c_UpdateCol, @c_SQL_INS_FIELDS, 1) = 0
            BEGIN
               SET @c_SQL_INS_FIELDS = @c_SQL_INS_FIELDS + N', '   + @c_UpdateCol
            END
            IF CHARINDEX(', ' + @c_UpdateCol, ',' + @c_SQL_UPD_FIELDS, 1) = 0
            BEGIN
               SET @c_SQL_UPD_FIELDS = @c_SQL_UPD_FIELDS + N', ' + @c_UpdateCol + N' = T.' + @c_UpdateCol    --use T alias insert from #tReceipt T
            END
--(Wan04) - END

            FETCH NEXT FROM @CUR_COLMAP INTO @c_Code, @c_Code2
         END
         CLOSE @CUR_COLMAP
         DEALLOCATE @CUR_COLMAP
         -- Call Custom Header Mapping - END

         SET @c_NewReceiptKey = @c_Receiptkey
         IF @n_RowRef_RH > 1 AND @c_PopulateType = '1PO1ASN'
         BEGIN
            SET @c_NewReceiptKey = ''
            BEGIN TRY
               EXECUTE nspg_GetKey
                        'RECEIPT'
                        , 10
                        , @c_NewReceiptKey   OUTPUT
                        , @b_success         OUTPUT
                        , @n_err             OUTPUT
                        , @c_ErrMsg          OUTPUT
            END TRY
            BEGIN CATCH
               SET @n_Err     = 556803
               SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                              + ': Error Executing nspg_GetKey - Receipt. (lsp_ASN_PopulatePOs_Wrapper)'
            END CATCH

            IF @b_success <> 1 OR @n_Err <> 0
            BEGIN
               SET @n_Continue = 3

               EXEC [WM].[lsp_WriteError_List]
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_Receiptkey
                  ,  @c_Refkey2     = @c_POKey
                  ,  @c_Refkey3     = ''
                  ,  @c_WriteType   = 'ERROR'
                  ,  @n_err2        = @n_err
                  ,  @c_errmsg2     = @c_errmsg
                  ,  @b_Success     = @b_Success   --2020-09-15
                  ,  @n_err         = @n_err       --2020-09-15
                  ,  @c_errmsg      = @c_errmsg    --2020-09-15

               GOTO EXIT_SP
            END
         END

         BEGIN TRAN
         IF NOT EXISTS (SELECT 1 FROM RECEIPT RH WITH (NOLOCK) WHERE RH.Receiptkey = @c_NewReceiptKey)
         BEGIN
            BEGIN TRY
               --(Wan04) - START
               SET @c_SQL_INS_FIELDS
               = N'INSERT INTO RECEIPT ( Receiptkey'
               + @c_SQL_INS_FIELDS
               + ')'
               +' SELECT @c_NewReceiptkey'
               + @c_SQL_INS_FIELDS
               +' FROM #tRECEIPT'
               +' WHERE RowRef = @n_RowRef_RH'

               SET @c_SQLParms = N'@c_NewReceiptkey   NVARCHAR(10)'
                               + ',@n_RowRef_RH       INT'

               EXEC sp_ExecuteSQL @c_SQL_INS_FIELDS
                                 ,@c_SQLParms
                                 ,@c_NewReceiptkey
                                 ,@n_RowRef_RH
               --(Wan04) - END
            END TRY
            BEGIN CATCH
               --2020-09-15 - START
               ROLLBACK TRAN

               WHILE @@TRANCOUNT < @n_StartTCnt
               BEGIN
                  BEGIN TRAN
               END
               --2020-09-15 - END

               SET @n_Continue = 3
               SET @n_Err = 556804
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': INSERT RECEIPT Table Fail. (lsp_ASN_PopulatePOs_Wrapper)'
                              + '(' + @c_ErrMsg + ')'

               EXEC [WM].[lsp_WriteError_List]
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_Receiptkey
                  ,  @c_Refkey2     = @c_POKey
                  ,  @c_Refkey3     = ''
                  ,  @c_WriteType   = 'ERROR'
                  ,  @n_err2        = @n_err
                  ,  @c_errmsg2     = @c_errmsg
                  ,  @b_Success     = @b_Success   --2020-09-15
                  ,  @n_err         = @n_err       --2020-09-15
                  ,  @c_errmsg      = @c_errmsg    --2020-09-15

               --2020-09-15 - START
               --IF (XACT_STATE()) = -1
               --BEGIN
               --   ROLLBACK TRAN

               --   WHILE @@TRANCOUNT < @n_StartTCnt
               --   BEGIN
               --      BEGIN TRAN
               --   END
               --END
               --2020-09-15 - END
            END CATCH

         END
         ELSE
         BEGIN
            BEGIN TRY
               --(Wan04) - START
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
               --(Wan04) - END
            END TRY
            BEGIN CATCH
               --2020-09-15 - START
               ROLLBACK TRAN

               WHILE @@TRANCOUNT < @n_StartTCnt
               BEGIN
                  BEGIN TRAN
               END
               --2020-09-15 - END

               SET @n_Continue = 3
               SET @n_Err = 556805
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': UPDATE RECEIPT Table Fail. (lsp_ASN_PopulatePOs_Wrapper)'
                              + '(' + @c_ErrMsg + ')'

               EXEC [WM].[lsp_WriteError_List]
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_Receiptkey
                  ,  @c_Refkey2     = @c_POKey
                  ,  @c_Refkey3     = ''
                  ,  @c_WriteType   = 'ERROR'
                  ,  @n_err2        = @n_err
                  ,  @c_errmsg2     = @c_errmsg
                  ,  @b_Success     = @b_Success   --2020-09-15
                  ,  @n_err         = @n_err       --2020-09-15
                  ,  @c_errmsg      = @c_errmsg    --2020-09-15

               --2020-09-15 - START
               --IF (XACT_STATE()) = -1
               --BEGIN
               --   ROLLBACK TRAN

               --   WHILE @@TRANCOUNT < @n_StartTCnt
               --   BEGIN
               --      BEGIN TRAN
               --   END
               --END
               --2020-09-15 - END
            END CATCH

         END

         SET @c_ReceiptLineNumber = ''
         SELECT TOP 1 @c_ReceiptLineNumber = RD.ReceiptLineNumber
         FROM RECEIPTDETAIL RD WITH (NOLOCK)
         WHERE RD.Receiptkey = @c_NewReceiptkey
         ORDER BY RD.ReceiptLineNumber DESC

         SET @n_RowRef_PD = 0
         WHILE 1 = 1
         BEGIN
            SET @c_POLineNumber = ''
            SET @c_ExternLineNo = ''
            SET @c_Sku          = ''
            SET @c_AltSku       = ''                        --2020-08-13
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
                  ,@c_ExternLineNo = PD.ExternLineNo
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

            SET @c_AllowPopulateSamePOLine = '0'
            SELECT @c_AllowPopulateSamePOLine = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, @c_Sku, 'AllowPopulateSamePOLine')

            IF @c_AllowPopulateSamePOLine = '0'                         --(Wan05)
            BEGIN
               IF EXISTS ( SELECT 1
                           FROM RECEIPTDETAIL RD (NOLOCK)
                           WHERE RD.POkey = @c_POKey
                           AND RD.ExternLineNo = @c_ExternLineNo
                           AND RD.ReceiptKey = @c_NewReceiptkey         --(Wan05)
                         )
               BEGIN
                  CONTINUE
               END
            END

            SET @c_DefaultLOC = '0'
            SELECT @c_DefaultLOC     = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, @c_Sku, 'DefaultLOC')
            SET @c_QCLocation = '0'
            SELECT @c_QCLocation     = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, @c_Sku, 'QCLocation')
            SET @c_DefaultReturnPickFace = '0'
            SELECT @c_DefaultReturnPickFace = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, @c_Sku, 'DefaultReturnPickFace')

            SET @c_ReceiptLoc = ''
            SET @c_ReturnLoc  = ''
            SET @c_ReceiptInspectionLoc = ''
            SET @c_XDockReceiptLoc = ''

            SELECT @c_ReceiptLoc = ISNULL(ReceiptLoc,'')
                  ,@c_ReturnLoc  = ISNULL(ReturnLoc,'')
              ,@c_XDockReceiptLoc = ISNULL(XDockReceiptLoc,'')
                  ,@c_ReceiptInspectionLoc = ISNULL(ReceiptInspectionLoc,'')
                  ,@c_Lottable01Label = Lottable01Label
                  ,@c_Lottable02Label = Lottable02Label
                  ,@c_Lottable03Label = Lottable03Label
                  ,@c_Lottable04Label = Lottable04Label
                  ,@c_Lottable05Label = Lottable05Label
                  ,@c_Lottable06Label = Lottable06Label
                  ,@c_Lottable07Label = Lottable07Label
                  ,@c_Lottable08Label = Lottable08Label
                  ,@c_Lottable09Label = Lottable09Label
                  ,@c_Lottable10Label = Lottable10Label
                  ,@c_Lottable11Label = Lottable11Label
                  ,@c_Lottable12Label = Lottable12Label
                  ,@c_Lottable13Label = Lottable13Label
                  ,@c_Lottable14Label = Lottable14Label
                  ,@c_Lottable15Label = Lottable15Label
                  ,@c_AltSku          = AltSku                       --2020-08-13
            FROM SKU WITH (NOLOCK)
            WHERE Storerkey = @c_Storerkey
            AND Sku = @c_Sku

            SET @c_Toloc = ''
            IF @c_DefaultLOC = '0'
            BEGIN
               SET @c_Toloc = @c_DefaultRcptLOC
            END
            ELSE
            BEGIN
               SET @c_Toloc = CASE WHEN @c_Doctype = 'A' THEN ISNULL(@c_ReceiptLoc,'')
                                   WHEN @c_Doctype = 'R' AND ISNULL(@c_ReturnLoc,'') <> '' THEN ISNULL(@c_ReturnLoc,'')
                                   WHEN @c_DocType = 'X' THEN ISNULL(@c_XDockReceiptLoc, '')
                                   ELSE ''
                                   END
            END

            SET @c_Putawayloc = ''
            IF @c_Doctype = 'R'
            BEGIN
               SELECT TOP 1 @c_Putawayloc = SL.Loc
               FROM SKUxLOC SL WITH (NOLOCK)
               JOIN LOC L WITH (NOLOCK) ON SL.Loc = L.Loc AND L.Facility = @c_Facility
               WHERE SL.Storerkey = @c_Storerkey
               AND   SL.Sku = @c_Sku
               AND   SL.LocationType IN ( 'CASE', 'PICK' )

               IF @c_DefaultReturnPickFace = '1'
               BEGIN
                  IF @c_Rectype IN ('RGR', 'RET')
                  BEGIN
                     SET @c_SubReasonCode = 'NONE'
                  END

                  IF @c_Toloc = ''
                  BEGIN
                     SET @c_Putawayloc = @c_Toloc
                  END
               END

               IF @c_QCLocation = '1' AND @c_Toloc = ''
               BEGIN
                  SET @c_ToLoc =  @c_ReceiptInspectionLoc
               END
            END

            SET @c_ReceiptLineNumber = RIGHT( '00000' + CONVERT(NVARCHAR(5), CONVERT(INT, @c_ReceiptLineNumber) + 1), 5 )

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
                  SET @c_SourceKey         = @c_ReceiptKey + @c_ReceiptLineNumber
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
                     SET @n_Err = 556806
                     SET @c_ErrMsg = ERROR_MESSAGE()
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing ispLottableRule_Wrapper. (lsp_ASN_PopulatePOs_Wrapper)'
                                    + '(' + @c_ErrMsg + ')'
                  END CATCH

                  IF @b_Success = 0 OR @n_Err <> 0
                  BEGIN
                     --SET @n_Continue = 3   -- ZG01

                     EXEC [WM].[lsp_WriteError_List]
                           @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                        ,  @c_TableName   = @c_TableName
                        ,  @c_SourceType  = @c_SourceType
                        ,  @c_Refkey1     = @c_Receiptkey
                        ,  @c_Refkey2     = @c_POKey
                        ,  @c_Refkey3     = ''
                        --,  @c_WriteType   = 'ERROR'    -- ZG01
                        ,  @c_WriteType   = 'WARNING'    -- ZG01
                        ,  @n_err2        = @n_err
                        ,  @c_errmsg2     = @c_errmsg
                        ,  @b_Success     = @b_Success   --2020-09-15
                        ,  @n_err         = @n_err       --2020-09-15
                        ,  @c_errmsg      = @c_errmsg    --2020-09-15

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
            SET @c_ExternLineNo = ISNULL(@c_ExternLineNo,'')--2020-09-15

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
                  @c_NewReceiptKey
               ,  @c_ReceiptLineNumber
               ,  PD.Storerkey
               ,  PD.Sku
               ,  @c_AltSku                        --2020-08-13
               ,  ISNULL(PD.Packkey,'')            --2020-09-15
               ,  ISNULL(PD.UOM,'')                --2020-09-15
               ,  QtyExpected = CASE WHEN @c_POType = 'FREEDGOODS' THEN 0 ELSE PD.QtyOrdered - PD.QtyReceived END
               ,  FreeGoodQtyExpected = CASE WHEN @c_POType = 'FREEDGOODS' THEN PD.QtyOrdered - PD.QtyReceived ELSE 0 END
               ,  ToLoc = @c_ToLoc
               ,  PD.ToID
               ,  PutawayLoc = @c_Putawayloc
               ,  ISNULL(PD.ExternPOKey,'')        --2020-09-15
               ,  ISNULL(PD.POKey,'')              --2020-09-15
               ,  ISNULL(PD.POLineNumber,'')       --2020-09-15
               ,  ExternPOKey = CASE WHEN @c_ExternLineNo <> '' THEN PD.ExternPOKey ELSE '' END
               ,  ExternLineNo= @c_ExternLineNo
               ,  Vesselkey = @c_Vesselkey
               ,  Voyagekey = @c_Voyagekey
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
               ,  SubReasonCode = @c_SubReasonCode
               ,  PD.Channel
            FROM #tPODETAIL PD
            WHERE PD.RowRef = @n_RowRef_PD

            SET @n_RowRef_RD = @@IDENTITY

            --(Wan04) - START
            SET @c_SQL_INS_FIELDS =
           N', ReceiptLineNumber'
                + ', Storerkey'
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
            --(Wan04) - END

            -- Call Custom Detail Mapping - START
            SET @c_ListName = 'PO2ASNMAP'

            SET @CUR_COLMAP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Code  = CL.Code
                  ,Code2 = CL.Code2
            FROM CODELKUP CL WITH (NOLOCK)
            WHERE CL.ListName = @c_ListName
            AND   CL.Short = 'D'
            AND   CL.Storerkey = @c_Storerkey
            UNION                                                                                     --(Wan04)
            SELECT Code  = CL.Code
                  ,Code2 = CL.Code2
            FROM CODELKUP CL WITH (NOLOCK)
            WHERE CL.ListName = @c_ListName
            AND   CL.Short = 'D'
            AND   CL.Storerkey = @c_Storerkey
            AND  @c_DocType IN (SELECT LTRIM(RTRIM(ss.value)) FROM STRING_SPLIT(CL.UDF03,',') AS ss)  --(Wan04)
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
                  SET @n_Err = 556807
                  SET @c_ErrMsg = ERROR_MESSAGE()
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing lsp_Populate_GetDocFieldsMap - DETAIL. (lsp_ASN_PopulatePOs_Wrapper)'
                                 + '(' + @c_ErrMsg + ')'

                  EXEC [WM].[lsp_WriteError_List]
                        @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                     ,  @c_TableName   = @c_TableName
                     ,  @c_SourceType  = @c_SourceType
                     ,  @c_Refkey1     = @c_Receiptkey
                     ,  @c_Refkey2     = @c_POKey
                     ,  @c_Refkey3     = ''
                     ,  @c_WriteType   = 'ERROR'
                     ,  @n_err2        = @n_err
                     ,  @c_errmsg2     = @c_errmsg
                     ,  @b_Success     = @b_Success   --2020-09-15
                     ,  @n_err         = @n_err       --2020-09-15
                     ,  @c_errmsg      = @c_errmsg    --2020-09-15

                  GOTO EXIT_SP
               END CATCH

               SET @c_UpdateCol  = RTRIM(LTRIM(@c_UpdateCol))  --(Wan04)

               IF @c_ReturnSQL <> ''
               BEGIN
                  -- (Wan04) - START 2021-07-20
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
                  --
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
                  -- (Wan04) - END 2021-07-20

                  IF @c_SQL <> ''
                  BEGIN
                     SET @c_SQL = 'UPDATE #tRECEIPTDETAIL'
                                + ' SET ' + @c_UpdateCol + ' = (' + @c_SQL + ')'
                                + ' WHERE RowRef = @n_RowRef_RD'

                     SET @c_SQLParms = '@n_RowRef_PD     INT'
                                     +',@n_RowRef_RD     INT'
                                     +',@c_PoKey         NVARCHAR(18)'        --(Wan04)
                                     +',@c_POLineNumber  NVARCHAR(5)'         --(Wan04)

                     EXEC sp_ExecuteSQL @c_SQL
                              , @c_SQLParms
                              , @n_RowRef_PD
                              , @n_RowRef_RD
                              , @c_PoKey                                     --(Wan04)
                              , @c_POLineNumber                              --(Wan04)
                  END
               END
               --(Wan04) - START
               IF CHARINDEX(', ' + @c_UpdateCol, @c_SQL_INS_FIELDS, 1) = 0
               BEGIN
                  SET @c_SQL_INS_FIELDS = @c_SQL_INS_FIELDS + N', '   + @c_UpdateCol
               END
               --(Wan04) - END
               FETCH NEXT FROM @CUR_COLMAP INTO @c_Code, @c_Code2
            END
            CLOSE @CUR_COLMAP
            DEALLOCATE @CUR_COLMAP

         -- Call Custom Detail Mapping - END
            BEGIN TRY
               --(Wan04) - START
               SET @c_SQL_INS_FIELDS
               = N'INSERT INTO RECEIPTDETAIL ( Receiptkey'
               + @c_SQL_INS_FIELDS
               + ')'
               +' SELECT Receiptkey'
               + @c_SQL_INS_FIELDS
               +' FROM #tRECEIPTDETAIL'
               +' WHERE RowRef = @n_RowRef_RD'

               SET @c_SQLParms = N'@n_RowRef_RD INT'

               EXEC sp_ExecuteSQL @c_SQL_INS_FIELDS
                                 ,@c_SQLParms
                 ,@n_RowRef_RD

               --(Wan04) - END

            END TRY
            BEGIN CATCH
               --2020-09-15 - START
                IF (XACT_STATE()) = -1                --(USH07- Start)
               	BEGIN
               			ROLLBACK TRAN
               	END                                   --(USH07- End)

               WHILE @@TRANCOUNT < @n_StartTCnt
               BEGIN
                  BEGIN TRAN
               END
               --2020-09-15 - END

               SET @n_Continue = 3
               SET @n_Err = 556808
               SET @c_ErrMsg = ERROR_MESSAGE()

               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': INSERT RECEIPTDETAIL Table Fail. (lsp_ASN_PopulatePOs_Wrapper)'
                              + '(' + @c_ErrMsg + ')'

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

               --2020-09-15 - START
               --IF (XACT_STATE()) = -1
               --BEGIN
               --   ROLLBACK TRAN

               --   WHILE @@TRANCOUNT < @n_StartTCnt
               --   BEGIN
               --      BEGIN TRAN
               --   END
               --END
               --2020-09-15 - END
               GOTO EXIT_SP
            END CATCH
         END

         IF @n_Continue = 3
         BEGIN
            ROLLBACK TRAN
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > 0
            COMMIT TRAN
         END
      END
   END TRY

   BEGIN CATCH
      SET @n_Continue = 3                 --(Wan02)
      SET @c_ErrMsg   = ERROR_MESSAGE()   --(Wan02)
                                          --
      --      --Log Error to WMS_Error_List
      EXEC [WM].[lsp_WriteError_List]     --(Wan04)
            @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
         ,  @c_TableName   = @c_TableName
         ,  @c_SourceType  = @c_SourceType
         ,  @c_Refkey1     = @c_Receiptkey
         ,  @c_Refkey2     = @c_POKey
         ,  @c_Refkey3     = ''
         ,  @c_WriteType   = 'ERROR'
         ,  @n_err2        = @n_err
         ,  @c_errmsg2     = @c_errmsg
         ,  @b_Success     = @b_Success
         ,  @n_err         = @n_err
         ,  @c_errmsg      = @c_errmsg
      GOTO EXIT_SP
   END CATCH -- (SWT01) - End Big Outer Begin try.. end Try Begin Catch.. End Catch

EXIT_SP:

   IF OBJECT_ID('tempdb..#tPOs', 'U') IS NOT NULL
   BEGIN
      DROP TABLE #tPOs
   END

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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_ASN_PopulatePOs_Wrapper'
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