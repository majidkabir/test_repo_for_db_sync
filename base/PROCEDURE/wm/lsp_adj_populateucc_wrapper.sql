SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: lsp_ADJ_PopulateUCC_Wrapper                         */
/* Creation Date: 2025-06-16                                            */
/* Copyright: LFL                                                       */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: FCR-4814 - AU  Populate UCC quantity in UCC adjustment     */
/*                                                                      */
/* Called By: SCE                                                       */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 2025-06-16  USH022   1.0   Created & DevOps Combine Script           */
/* 2025-10-06  SSA01    1.1   UWP-42142 -Enhanced session management    */
/*                             and cleanup.                             */
/************************************************************************/
CREATE   PROC [WM].[lsp_ADJ_PopulateUCC_Wrapper]
   @c_AdjustmentKey        NVARCHAR(10)
,  @c_SearchSQL            NVARCHAR(MAX)              --Select Statement for Populate Search button
,  @b_Success              INT            = 1  OUTPUT
,  @n_Err                  INT            = 0  OUTPUT
,  @c_ErrMsg               NVARCHAR(255)  = '' OUTPUT
,  @c_UserName             NVARCHAR(128)  = ''
,  @n_ErrGroupKey          INT            = 0  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_StartTCnt                  INT            = @@TRANCOUNT
         ,  @n_Continue                   INT            = 1
         ,  @c_SelectSQL                  NVARCHAR(1000) = ''

         ,  @n_AdjLineNo                  INT            = 0
         ,  @c_Facility                   NVARCHAR(10)   = ''
         ,  @c_AdjustmentLineNumber       NVARCHAR(5)    = ''
         ,  @c_Storerkey                  NVARCHAR(10)   = ''
         ,  @c_Sku                        NVARCHAR(20)   = ''
         ,  @c_Packkey                    NVARCHAR(10)   = ''
         ,  @c_PackUOM3                   NVARCHAR(20)   = ''
         ,  @n_Qty                        INT            = 0
         ,  @c_lot                        NVARCHAR(10)   = ''
         ,  @c_Loc                        NVARCHAR(10)   = ''
         ,  @c_ID                         NVARCHAR(18)   = ''
         ,  @c_Lottable01                 NVARCHAR(18)   = ''
         ,  @c_Lottable02                 NVARCHAR(18)   = ''
         ,  @c_Lottable03                 NVARCHAR(18)   = ''
         ,  @dt_Lottable04                DATETIME       = NULL
         ,  @dt_Lottable05                DATETIME       = NULL
         ,  @c_Lottable06                 NVARCHAR(30)   = ''
         ,  @c_Lottable07                 NVARCHAR(30)   = ''
         ,  @c_Lottable08                 NVARCHAR(30)   = ''
         ,  @c_Lottable09                 NVARCHAR(30)   = ''
         ,  @c_Lottable10                 NVARCHAR(30)   = ''
         ,  @c_Lottable11                 NVARCHAR(30)   = ''
         ,  @c_Lottable12                 NVARCHAR(30)   = ''
         ,  @dt_Lottable13                DATETIME       = NULL
         ,  @dt_Lottable14                DATETIME       = NULL
         ,  @dt_Lottable15                DATETIME       = NULL
         ,  @c_UCCNo                      NVARCHAR(20)   = ''

         ,  @c_Channel_Default            NVARCHAR(20)   = ''
         ,  @c_Channel                    NVARCHAR(20)   = ''
         ,  @c_ChannelInventoryMgmt       NVARCHAR(10)   = ''
         ,  @c_FinalizeAdjustment         NVARCHAR(10)   = ''
         ,  @c_AdjStatusControl           NVARCHAR(10)   = ''

         ,  @c_TableName                  NVARCHAR(50)   = 'AdjustmentDetail'
         ,  @c_SourceType                 NVARCHAR(50)   = 'lsp_ADJ_PopulateUCC_Wrapper'
         ,  @c_Refkey1                    NVARCHAR(20)   = ''
         ,  @c_Refkey2                    NVARCHAR(20)   = ''
         ,  @c_Refkey3                    NVARCHAR(20)   = ''
         ,  @c_WriteType                  NVARCHAR(50)   = ''
         ,  @n_LogWarningNo               INT            = 0

         ,  @CUR_UCC                      CURSOR
         ,  @CUR_ERRLIST                  CURSOR

     DECLARE  @t_WMSErrorList TABLE
         (  RowID             INT            IDENTITY(1,1)
         ,  TableName         NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  SourceType        NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  Refkey1           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey2           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey3           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  WriteType         NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  LogWarningNo      INT            NOT NULL DEFAULT(0)
         ,  ErrCode           INT            NOT NULL DEFAULT(0)
         ,  Errmsg            NVARCHAR(255)  NOT NULL DEFAULT('')
         )

   SET @b_Success = 1
   SET @n_Err     = 0
   SET @c_ErrMsg  = ''

   SET @n_ErrGroupKey = 0

   SET @n_Err = 0
   -- (SSA01) - START
   DECLARE @b_ExecuteAs BIT = 0
   IF SUSER_SNAME() <> @c_UserName
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT,  @b_ExecuteAs = @b_ExecuteAs OUTPUT

      IF @n_Err <> 0
      BEGIN
         GOTO EXIT_SP
      END

      IF @b_ExecuteAs = 1
         EXECUTE AS LOGIN = @c_UserName
   END
   --(SSA01) - END

   BEGIN TRY
      SELECT @c_Facility = a.Facility
            ,@c_Storerkey= a.Storerkey
      FROM dbo.ADJUSTMENT AS a (NOLOCK)
      WHERE a.AdjustmentKey = @c_Adjustmentkey

      SELECT @c_FinalizeAdjustment = fsgr.Authority FROM dbo.fnc_SelectGetRight (@c_Facility, @c_Storerkey,'','FinalizeAdjustment') AS fsgr
      SELECT @c_AdjStatusControl = fsgr.Authority FROM dbo.fnc_SelectGetRight (@c_Facility, @c_Storerkey,'','AdjStatusControl') AS fsgr

      IF @c_FinalizeAdjustment IN (0,'') AND @c_AdjStatusControl IN (0,'')
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 561951
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Storer is setup using Auto Finalize Adjusment.'
                         + ' Unconfirm Populated record will be finalized. Action Abort. (lsp_ADJ_PopulateUCC_Wrapper)'

         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
         VALUES (@c_TableName, @c_SourceType, @c_AdjustmentKey, '', '', 'ERROR', 0, @n_Err, @c_Errmsg)

         GOTO EXIT_SP
      END

      SELECT @c_ChannelInventoryMgmt = fsgr.Authority FROM dbo.fnc_SelectGetRight (@c_Facility, @c_Storerkey,'','ChannelInventoryMgmt') AS fsgr

      IF @c_ChannelInventoryMgmt = '1'
      BEGIN
         SELECT TOP 1 @c_Channel_Default = c.Code
         FROM dbo.CODELKUP AS c WITH (NOLOCK)
         WHERE c.ListName = 'Channel'
         AND c.Storerkey IN ('', @c_Storerkey)
         ORDER BY CASE WHEN c.Storerkey = @c_Storerkey THEN 1
                        ELSE 9
                        END
               ,  c.Code
      END

      IF OBJECT_ID('tempdb..#tUCC', 'U') IS NOT NULL
      BEGIN
         DROP TABLE #tUCC
      END

      CREATE TABLE #tUCC
         (  UCC_RowRef  INT            NOT NULL             PRIMARY KEY
         ,  UCCNo       NVARCHAR(20)   NOT NULL DEFAULT('')
         )

      SET @c_SelectSQL = 'SELECT UCC.UCC_RowRef, UCC.UCCNo'
      SELECT @c_SearchSQL = dbo.fnc_ParseSearchSQL(@c_SearchSQL, @c_SelectSQL)

      IF @c_SearchSQL = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 561952
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Empty Search Criteria found. (lsp_ADJ_PopulateUCC_Wrapper)'

         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
         VALUES (@c_TableName, @c_SourceType, @c_AdjustmentKey, '', '', 'ERROR', 0, @n_Err, @c_Errmsg)
         GOTO EXIT_SP
      END

      INSERT INTO #tUCC ( UCC_RowRef, UCCNo )
      EXEC sp_ExecuteSQL @c_SearchSQL

      SELECT TOP 1 @n_AdjLineNo = CONVERT(INT, a.AdjustmentLineNumber)
      FROM dbo.ADJUSTMENTDETAIL AS a (NOLOCK)
      WHERE a.AdjustmentKey = @c_Adjustmentkey
      ORDER BY a.AdjustmentLineNumber DESC

      BEGIN TRAN

      SET @CUR_UCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT u.StorerKey
            ,u.Sku
            ,s.Packkey
            ,p.PackUOM3
            ,u.lot
            ,u.loc
            ,u.id
            ,u.Qty
            ,u.UCCNo
            ,l.Lottable01
            ,l.Lottable02
            ,l.Lottable03
            ,l.Lottable04
            ,l.Lottable05
            ,l.Lottable06
            ,l.Lottable07
            ,l.Lottable08
,l.Lottable09
            ,l.Lottable10
            ,l.Lottable11
            ,l.Lottable12
            ,l.Lottable13
            ,l.Lottable14
            ,l.Lottable15
      FROM #tUCC AS tu
      JOIN dbo.UCC AS u WITH (NOLOCK) ON u.UCC_RowRef = tu.UCC_RowRef
      JOIN dbo.LOTxLOCxID AS ltlci (NOLOCK) ON  ltlci.Lot = u.Lot
                                            AND ltlci.Loc = u.Loc
                                            AND ltlci.Id  = u.ID
      JOIN dbo.LOTATTRIBUTE AS l (NOLOCK) ON l.Lot = ltlci.Lot
      JOIN dbo.SKU AS s (NOLOCK) ON s.StorerKey = l.StorerKey AND s.Sku = l.Sku
      JOIN dbo.PACK AS p (NOLOCK) ON p.PackKey= s.PACKKey
      JOIN dbo.SKUxLOC AS sul WITH (NOLOCK) ON sul.StorerKey = s.StorerKey AND sul.SKU = s.SKU AND sul.LOC = u.LOC
      WHERE u.[Status] = '1'
      AND sul.LocationType NOT IN ('PICK', 'CASE')
      ORDER BY tu.UCC_RowRef

      OPEN @CUR_UCC
      FETCH NEXT FROM  @CUR_UCC INTO @c_Storerkey
                                    ,@c_Sku
                                    ,@c_Packkey
                                    ,@c_PackUOM3
                                    ,@c_Lot
                                    ,@c_Loc
                                    ,@c_ID
                                    ,@n_Qty
                                    ,@c_UCCNo
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
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_ChannelInventoryMgmt = '1'
         BEGIN
            SET @c_Channel = ''
            SELECT @c_Channel = fsci.Channel
            FROM dbo.fnc_SelectChannelInv(@c_Facility, @c_Storerkey, @c_Sku, @c_Channel
                                         ,@c_Lot, @n_Qty
                                         ) AS fsci

            IF @c_Channel = ''
            BEGIN
               SET @c_Channel = @c_Channel_Default
            END
         END

         SET @n_AdjLineNo = @n_AdjLineNo + 1
         SET @c_AdjustmentLineNumber = RIGHT('00000' + CONVERT(NVARCHAR(5), @n_AdjLineNo),5)

         INSERT INTO dbo.ADJUSTMENTDETAIL
             (
                 AdjustmentKey
             ,   AdjustmentLineNumber
             ,   StorerKey
             ,   Sku
             ,   Lot
             ,   Loc
             ,   Id
             ,   ReasonCode
             ,   UOM
             ,   PackKey
             ,   Qty
             ,   CaseCnt
             ,   InnerPack
             ,   Pallet
             ,   Cube
             ,   GrossWgt
             ,   NetWgt
             ,   OtherUnit1
             ,   OtherUnit2
             ,   ItrnKey
             ,   EffectiveDate
             ,   UserDefine01
             ,   UserDefine02
             ,   UserDefine03
             ,   UserDefine04
             ,   UserDefine05
             ,   UserDefine06
             ,   UserDefine07
             ,   UserDefine08
             ,   UserDefine09
             ,   UserDefine10
             ,   FinalizedFlag
             ,   Lottable01
             ,   Lottable02
             ,   Lottable03
             ,   Lottable04
         ,   Lottable05
             ,   Lottable06
             ,   Lottable07
             ,   Lottable08
             ,   Lottable09
             ,   Lottable10
             ,   Lottable11
             ,   Lottable12
             ,   Lottable13
             ,   Lottable14
             ,   Lottable15
             ,   UCCNo
             ,   Channel
             ,   Channel_ID
             )
         VALUES
             (   @c_AdjustmentKey
             ,   @c_AdjustmentLineNumber
             ,   @c_Storerkey
             ,   @c_Sku
             ,   @c_Lot
             ,   @c_Loc
             ,   @c_ID
             ,   ''                          --ReasonCode
             ,   @c_PackUOM3
             ,   @c_PackKey
             ,   @n_Qty
             ,   0.00                        --CaseCnt
             ,   0.00                        --InnerPack
             ,   0.00                        --Pallet
             ,   0.00                        --CUBE
             ,   0.00                        --GrossWgt
             ,   0.00                        --NetWgt
             ,   0.00                        --OtherUnit1
             ,   0.00                        --OtherUnit2
             ,   ''                          --ItrnKey
             ,   GETDATE()                   --EffectiveDate
             ,   ''                          --UserDefine01
             ,   ''                          --UserDefine02
             ,   ''                          --UserDefine03
             ,   ''                          --UserDefine04
             ,   ''                          --UserDefine05
             ,   ''                          --UserDefine06
             ,   ''                          --UserDefine07
             ,   ''                          --UserDefine08
             ,   ''                          --UserDefine09
             ,   ''                          --UserDefine10
             ,   'N'                         --FinalizedFlag
             ,   @c_Lottable01
             ,   @c_Lottable02
             ,   @c_Lottable03
             ,   @dt_Lottable04
             ,   @dt_Lottable05
             ,   @c_Lottable06
             ,   @c_Lottable07
             ,   @c_Lottable08
             ,   @c_Lottable09
             ,   @c_Lottable10
             ,   @c_Lottable11
             ,   @c_Lottable12
             ,   @dt_Lottable13
             ,   @dt_Lottable14
             ,   @dt_Lottable15
             ,   @c_UCCNo                    --UCCNo
             ,   @c_Channel                  --Channel
             ,   0                           --Channel_ID
             )

         FETCH NEXT FROM  @CUR_UCC INTO @c_Storerkey
                                     ,  @c_Sku
                                     ,  @c_Packkey
                                     ,  @c_PackUOM3
                                     ,  @c_Lot
                                     ,  @c_Loc
                                     ,  @c_ID
                                     ,  @n_Qty
                                     ,  @c_UCCNo
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
      END
      CLOSE @CUR_UCC
      DEALLOCATE @CUR_UCC
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg   = ERROR_MESSAGE()

      INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
      VALUES (@c_TableName, @c_SourceType, @c_AdjustmentKey, '', '', 'ERROR', 0, @n_Err, @c_Errmsg)
      GOTO EXIT_SP
   END CATCH
EXIT_SP:
   IF (XACT_STATE()) = -1
   BEGIN
      SET @n_Continue = 3
      ROLLBACK TRAN
   END

   IF OBJECT_ID('tempdb..#tUCC', 'U') IS NOT NULL
   BEGIN
      DROP TABLE #tUCC
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_ADJ_PopulateUCC_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

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

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

  IF @b_ExecuteAs = 1              -- (SSA01)
      REVERT

   EXEC [WM].[lsp_ResetUser] -- (SSA01)
END

GO