SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: lsp_GetItrn_Wrapper                                     */
/* Creation Date: 2022-03-22                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-3353 - SCE PROD - PH - Additional Column For Inventory */
/*          Transaction Module                                          */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.7                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2022-03-22  Wan      1.0   Created & DevOps Combine Script           */
/* 2022-05-28  Wan      1.0   LFWM-3555 UAT - HK| 11353 SCE Inventory   */
/*                            Transaction issue                         */
/* 2022-06-14  Wan      1.0   LFWM-3552 TW - UAT | Cannot trace         */
/*                            Transaction from Archive db               */
/* 2022-08-19  Wan01    1.1   LFWM-3695 - UAT-PHSCE hit the error when  */
/*                            populate from Archive DB via Inventory    */
/*                            Transaction module                        */
/* 2022-11-09  Wan02    1.2   LFWM-3783 - Inventory Transactions        */
/*                            Enhancement                               */
/* 2022-11-16  Wan03    1.3   LFWM-3821 - PROD  AU  ALL - Invalid column*/
/*                            name ExternReferenceKey                   */
/* 2023-02-10  LZG      1.4   LFWM-3938 (ZG01):                         */
/*                            1. Join LotAttribute for lottable values  */
/*                            2. Join Pack for UOMQty calculation       */
/* 2023-05-24  Wan04    1.5   LFWM-4283 - PROD - PH Alcon - SCE Inventory*/   
/*                            Transaction Module                        */
/* 2023-06-14  SPChin   1.6   JSM-156017 - Bug Fixed                    */
/* 2023-03-14  Wan05    1.7   LFWM-3954 - Philippines All Customer LFSCE*/
/*                            WM Inventory Transaction CR               */
/************************************************************************/
CREATE   PROC [WM].[lsp_GetItrn_Wrapper]
   @c_WhereClause       NVARCHAR(MAX)                 --Contain WHERE for eg. WHERE ITRN.Storerkey = ''NIKEPH''
,  @c_SortPreference    NVARCHAR(MAX) = ''            --Only sort column. Multiple Sort Columns are seperated to be , (comma)
,  @b_ArchiveDB         INT = 0
,  @b_Success           INT = 1             OUTPUT
,  @n_Err               INT = 0             OUTPUT
,  @c_ErrMsg            NVARCHAR(255) = ''  OUTPUT
,  @c_UserName          NVARCHAR(128) = ''
,  @c_SearchCondition   NVARCHAR(MAX) = ''            --(Wan03) Search Condition from RETURN Result table (Temp)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @n_StartTCnt       INT   = @@TRANCOUNT
         , @n_Continue        INT   = 1
         
         , @b_GetArchiveDB    BIT   = 0               --(Wan02)
         , @n_MaxLimit        INT   = 10000           --(Wan02)
         , @n_TotalItrn       INT   = 0               --(Wan02)
         , @n_GetNoOfRec      INT   = 0               --(Wan02)

         --, @d_CutOfDate       DATETIME       = DATEADD(MONTH, - 12, CONVERT(NVARCHAR(10),GETDATE(),121))
         , @c_DBName          NVARCHAR(60)   = ''
         , @c_AddColumns      NVARCHAR(1000) = ''

         , @c_TranType        NVARCHAR(10)   = ''
         , @c_TxnSourceType   NVARCHAR(50)   = ''

         , @c_SQL             NVARCHAR(MAX)  = ''
         , @c_SQLParms        NVARCHAR(2000) = ''
         , @c_SortBy          NVARCHAR(MAX)  = ''

         , @CUR_ITRN          CURSOR

   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   SET @c_WhereClause = ISNULL(@c_WhereClause,'')

   BEGIN TRY
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
   
      IF OBJECT_ID('tempdb..#TMP_ITRN','u') IS NOT NULL
      BEGIN
         DROP TABLE #TMP_ITRN;
      END
      
      CREATE TABLE #TMP_ITRN
      (  RowID                INT            NOT NULL IDENTITY(1,1)  PRIMARY KEY
      ,  ItrnKey              NVARCHAR(10)   NOT NULL
      ,  TranType             NVARCHAR(10)   NOT NULL
      ,  SourceKey            NVARCHAR(20)   NULL
      ,  SourceType           NVARCHAR(30)   NULL
      ,  SourceTypeDesc       NVARCHAR(30)   NULL                                   --(Wan05)  
      ,  StorerKey            NVARCHAR(15)   NOT NULL
      ,  Sku                  NVARCHAR(20)   NOT NULL
      ,  FromLoc              NVARCHAR(10)   NOT NULL
      ,  FromID               NVARCHAR(18)   NOT NULL
      ,  ToLoc                NVARCHAR(10)   NOT NULL
      ,  ToID                 NVARCHAR(18)   NOT NULL
      ,  Qty                  INT            NULL
      ,  LOTTABLE01           NVARCHAR(18)   NOT NULL
      ,  LOTTABLE02           NVARCHAR(18)   NOT NULL
      ,  LOTTABLE03           NVARCHAR(18)   NOT NULL
      ,  LOTTABLE04           DATETIME       NULL
      ,  LOTTABLE05           DATETIME       NULL
      ,  LOTTABLE06           NVARCHAR(30)   NOT NULL
      ,  LOTTABLE07           NVARCHAR(30)   NOT NULL
      ,  LOTTABLE08           NVARCHAR(30)   NOT NULL
      ,  LOTTABLE09           NVARCHAR(30)   NOT NULL
      ,  LOTTABLE10           NVARCHAR(30)   NOT NULL
      ,  LOTTABLE11           NVARCHAR(30)   NOT NULL
      ,  LOTTABLE12           NVARCHAR(30)   NOT NULL
      ,  LOTTABLE13           DATETIME       NULL
      ,  LOTTABLE14           DATETIME       NULL
      ,  LOTTABLE15           DATETIME       NULL
      ,  Lot                  NVARCHAR(18)   NOT NULL
      ,  PackKey              NVARCHAR(18)   NULL
      ,  UOMQty               INT            NULL
      ,  AddDate              DATETIME       NOT NULL
      ,  AddWho               NVARCHAR(128)  NOT NULL
      ,  EditDate             DATETIME       NOT NULL
      ,  EditWho              NVARCHAR(128)  NOT NULL
      ,  [Status]             NVARCHAR(18)   NULL
      ,  UOM                  NVARCHAR(18)   NULL
      ,  Channel              NVARCHAR(20)   NULL
      ,  Channel_ID           BIGINT         NULL
      ,  FromFacility         NVARCHAR(5)    NULL     DEFAULT ('')
      ,  ToFacility           NVARCHAR(5)    NULL     DEFAULT ('')
      ,  SkuDescr             NVARCHAR(60)   NULL     DEFAULT ('')
      ,  Style                NVARCHAR(20)   NOT NULL DEFAULT ('')
      ,  Color                NVARCHAR(10)   NOT NULL DEFAULT ('')
      ,  Size                 NVARCHAR(10)   NULL     DEFAULT ('')
      ,  Measurement          NVARCHAR(5)    NULL     DEFAULT ('')
      ,  ReferenceKey         NVARCHAR(20)   NOT NULL DEFAULT ('')
      ,  ExternReferenceKey   NVARCHAR(50)   NULL     DEFAULT ('')
      ,  ExternReferenceType  NVARCHAR(30)   NULL     DEFAULT ('')
      ,  Remarks              NVARCHAR(255)  NULL     DEFAULT ('')
      ,  TxnSourceType        NVARCHAR(30)   NOT NULL DEFAULT ('')
      ,  TxnKey               NVARCHAR(10)   NOT NULL DEFAULT ('')
      ,  CaseQty              FLOAT          NOT NULL DEFAULT (0.00)                --(Wan05)
      ,  InnerPackQty         FLOAT          NOT NULL DEFAULT (0.00)                --(Wan05)
      ,  Rowfocusindicatorcol CHAR(1)        NOT NULL DEFAULT ('')
      ,  PalletType           NVARCHAR(30)   NOT NULL
      )

      CREATE INDEX IDX_TRNX ON #TMP_ITRN (TxnSourceType, TxnKey)
      

      SELECT @c_DBName = ISNULL(RTRIM(n.NSQLValue),'')
      FROM dbo.NSQLCONFIG AS n (NOLOCK)
      WHERE n.ConfigKey='ArchiveDBName'
      
      SET @c_DBName = @c_DBName + IIF(@c_DBName = '','','.')               --LFWM-3552

      --(Wan02) - START
      SET @b_GetArchiveDB = @b_ArchiveDB
      
      WHILE 1 = 1
      BEGIN
         SET @n_GetNoOfRec = @n_MaxLimit - @n_TotalItrn
         
         SET @c_SQL = N'SELECT TOP (@n_GetNoOfRec)'
                    +'  ITRN.ItrnKey'
                    +', ITRN.TranType'
                    +', ITRN.SourceKey'
                    +', ITRN.SourceType'
                    +', ITRN.StorerKey'
                    +', ITRN.Sku'
                    +', ITRN.FromLoc'
                    +', ITRN.FromID'
                    +', ITRN.ToLoc'
                    +', ITRN.ToID'
                    +', ITRN.Qty'
                    -- +', ITRN.LOTTABLE01'  --(ZG01)
                    -- +', ITRN.LOTTABLE02'
                    -- +', ITRN.LOTTABLE03'
                    -- +', ITRN.LOTTABLE04'
                    -- +', ITRN.LOTTABLE05'
                    -- +', ITRN.LOTTABLE06'
                    -- +', ITRN.LOTTABLE07'
                    -- +', ITRN.LOTTABLE08'
                    -- +', ITRN.LOTTABLE09'
                    -- +', ITRN.LOTTABLE10'
                    -- +', ITRN.LOTTABLE11'
                    -- +', ITRN.LOTTABLE12'
                    -- +', ITRN.LOTTABLE13'
                    -- +', ITRN.LOTTABLE14'
                    -- +', ITRN.LOTTABLE15'
                    +', LotAttribute.LOTTABLE01'       --(ZG01)                     --(Wan04)
                    +', LotAttribute.LOTTABLE02'                                    --(Wan04)
                    +', LotAttribute.LOTTABLE03'                                    --(Wan04)
                    +', LotAttribute.LOTTABLE04'                                    --(Wan04)
                    +', LotAttribute.LOTTABLE05'                                    --(Wan04)
                    +', LotAttribute.LOTTABLE06'                                    --(Wan04)
                    +', LotAttribute.LOTTABLE07'                                    --(Wan04)
                    +', LotAttribute.LOTTABLE08'                                    --(Wan04)
                    +', LotAttribute.LOTTABLE09'                                    --(Wan04)
                    +', LotAttribute.LOTTABLE10'                                    --(Wan04)
                    +', LotAttribute.LOTTABLE11'                                    --(Wan04)
                    +', LotAttribute.LOTTABLE12'                                    --(Wan04)
                    +', LotAttribute.LOTTABLE13'                                    --(Wan04)
                    +', LotAttribute.LOTTABLE14'                                    --(Wan04)
                    +', LotAttribute.LOTTABLE15'                                    --(Wan04)
                    +', ITRN.Lot'
                    +', ITRN.PackKey'
                    --+', ITRN.UOMQty'                   --(ZG01)
                    +', ITRN.Qty / (CASE ITRN.UOM'       --(ZG01)
                    +'  WHEN PACK.PACKUOM1 THEN PACK.CaseCnt'
                    +'  WHEN PACK.PACKUOM2 THEN PACK.InnerPack'
                    +'  WHEN PACK.PACKUOM3 THEN 1'
                    +'  WHEN PACK.PACKUOM4 THEN PACK.Pallet'
                    +'  WHEN PACK.PACKUOM5 THEN PACK.Cube'
                    +'  WHEN PACK.PACKUOM6 THEN PACK.GrossWgt'
                    +'  WHEN PACK.PACKUOM7 THEN PACK.NetWgt'
                    +'  WHEN PACK.PACKUOM8 THEN PACK.OtherUnit1'
                    +'  WHEN PACK.PACKUOM9 THEN PACK.OtherUnit2 END) ''UOMQty'''
                    +', ITRN.AddDate'
                    +', ITRN.AddWho'
                    +', ITRN.EditDate'
                    +', ITRN.EditWho'
                    +', ITRN.[Status]'
                    +', ITRN.UOM'
                    +', ITRN.Channel'
                    +', ITRN.Channel_ID'
                    +', ITRN.PalletType'
                    + ' FROM ' + IIF(@b_GetArchiveDB = 0, '', @c_DBName) + 'dbo.ITRN WITH (NOLOCK)'         --(Wan02)
                    + ' JOIN dbo.LotAttribute WITH (NOLOCK) ON LotAttribute.Lot = ITRN.Lot'                           --(Wan04)--(ZG01)
                    + ' JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.Storerkey = ITRN.Storerkey AND SKU.Sku = ITRN.Sku'
                    + ' JOIN dbo.PACK WITH (NOLOCK) ON PACK.PackKey = SKU.PackKey'                          --(ZG01)
                    + ' JOIN dbo.LOC TOLOC WITH (NOLOCK) ON TOLOC.Loc = ITRN.ToLoc'
                    + ' LEFT OUTER JOIN dbo.LOC FROMLOC WITH (NOLOCK)  ON FROMLOC.Loc = ITRN.FromLoc'       --LFWM-3555
                    + ' ' + @c_WhereClause
                    + ' ORDER BY ITRN.adddate DESC'
                    + ' OPTION(RECOMPILE) '
                    
         SET @c_SQLParms = N'@n_GetNoOfRec   INT'
 
         INSERT INTO #TMP_ITRN
            (
               ItrnKey
            ,  TranType
            ,  SourceKey
            ,  SourceType
            ,  StorerKey
            ,  Sku
            ,  FromLoc
            ,  FromID
            ,  ToLoc
            ,  ToID
            ,  Qty
            ,  LOTTABLE01
            ,  LOTTABLE02
            ,  LOTTABLE03
            ,  LOTTABLE04
            ,  LOTTABLE05
            ,  LOTTABLE06
            ,  LOTTABLE07
            ,  LOTTABLE08
            ,  LOTTABLE09
            ,  LOTTABLE10
            ,  LOTTABLE11
            ,  LOTTABLE12
            ,  LOTTABLE13
            ,  LOTTABLE14
            ,  LOTTABLE15
            ,  Lot
            ,  PackKey
            ,  UOMQty
            ,  AddDate
            ,  AddWho
            ,  EditDate
            ,  EditWho
            ,  [Status]
            ,  UOM
            ,  Channel
            ,  Channel_ID
            , PalletType
            )
         EXEC sp_ExecuteSQL @c_SQL
                           ,@c_SQLParms
                           --,@d_CutOfDate
                           ,@n_GetNoOfRec
         
         SET @n_TotalITRN = @@ROWCOUNT

         IF @b_GetArchiveDB = 0
         BEGIN
            BREAK
         END
   
         IF @n_TotalITRN >= @n_MaxLimit
         BEGIN
            BREAK
         END
         
         SET @b_GetArchiveDB = 0
      END
      --(Wan02) - END
      
      UPDATE ti
         SET ti.FromFacility = ISNULL(l1.Facility,'')
            ,ti.ToFacility = ISNULL(l2.Facility,'')
            ,ti.SKUDescr = ISNULL(s.DESCR,'')
            ,ti.Style = ISNULL(s.Style,'')
            ,ti.Color = ISNULL(s.Color,'')
            ,ti.Size = ISNULL(s.Size,'')
            ,ti.Measurement = ISNULL(s.Measurement,'')
            ,ti.TxnKey = CASE WHEN ti.SourceType IN ('ntrPickDetailUpdate'
                                                , 'ntrReceiptDetailUpdate', 'ntrReceiptDetailAdd'
                                                , 'ntrAdjustmentDetailUpdate', 'ntrAdjustmentDetailAdd'
                                                , 'ntrTransferDetailUpdate'
                                                , 'ntrInventoryQCDetailUpdate'
                                                , 'ntrKitDetailAdd' , 'ntrKitDetailUpdate'
                                                , ''
                                                )
                              THEN LEFT(ti.SourceKey, 10)
                              WHEN SourceType LIKE 'CC Deposit%'
                              THEN LEFT(ti.SourceKey, 10)
                              WHEN SourceType LIKE 'CC Withdrawal%'
                              THEN LEFT(ti.SourceKey, 10)
                              ELSE ti.TxnKey
                              END
            ,ti.TxnSourceType = CASE WHEN ti.SourceType IN ( 'ntrPickDetailUpdate'
                                                        , 'ntrReceiptDetailUpdate', 'ntrReceiptDetailAdd'
                                                        , 'ntrAdjustmentDetailUpdate', 'ntrAdjustmentDetailAdd'
                                                        , 'ntrTransferDetailUpdate'
                                                        , 'ntrInventoryQCDetailUpdate'
                                                        , 'ntrKitDetailAdd', 'ntrKitDetailUpdate'
                                                        , ''
                                                        )
                                     THEN ti.SourceType
                                     WHEN SourceType LIKE 'CC Deposit%'
                                     THEN 'CC Deposit'
                                     WHEN SourceType LIKE 'CC Withdrawal%'
                                     THEN 'CC Withdrawal'
                                     ELSE ''
                                     END
            , ti.SourceTypeDesc = CASE WHEN ti.SourceType = 'ntrPickDetailUpdate'                        --(Wan05)                  
                                       THEN 'Orders'
                                       WHEN ti.SourceType IN ('ntrReceiptDetailUpdate', 'ntrReceiptDetailAdd')
                                       THEN 'Receipt'
                                       WHEN ti.SourceType IN ('ntrAdjustmentDetailUpdate', 'ntrAdjustmentDetailAdd')
                                       THEN 'Adjustment'
                                       WHEN ti.SourceType =  'ntrTransferDetailUpdate'
                                       THEN 'Transfer'
                                       WHEN ti.SourceType = 'WSPUTAWAY'
                                       THEN 'Put-Away'
                                       WHEN ti.SourceType = 'ntrReplenishmentUpdate'
                                       THEN 'Replenishment'
                                       WHEN ti.SourceType =  'ntrInventoryQCDetailUpdate'
                                       THEN 'IQC'
                                       WHEN ti.SourceType IN ('ntrKitDetailAdd', 'ntrKitDetailUpdate')
                                       THEN 'Kitting'
                                       WHEN ti.SourceType LIKE 'CC Deposit%' 
                                       THEN 'Count'
                                       WHEN ti.SourceType LIKE 'CC Withdrawal%' 
                                       THEN 'Count'
                                       WHEN TranType = 'MV'                                              
                                       THEN 'Inventory Move'
                                       END                
            , ti.Caseqty = CASE WHEN p.Casecnt > 0 THEN FLOOR(ti.Qty / p.Casecnt) ELSE 0.00 END          --(Wan05)
            , ti.InnerPackQty = CASE WHEN p.InnerPack > 0 THEN FLOOR(ti.Qty / p.InnerPack) ELSE 0.00 END --(Wan05)
      FROM #TMP_ITRN ti
      LEFT OUTER JOIN dbo.SKU AS s WITH (NOLOCK)  ON ti.Storerkey = s.StorerKey AND ti.Sku = s.Sku
      LEFT OUTER JOIN dbo.LOC AS l1 WITH (NOLOCK) ON l1.loc = ti.FromLoc
      LEFT OUTER JOIN dbo.LOC AS l2 WITH (NOLOCK) ON l2.loc = ti.ToLoc
      LEFT JOIN dbo.PACK AS p WITH (NOLOCK) ON p.Packkey = s.PACKKey                                     --(Wan05)
      
      SET @CUR_ITRN = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ti.TxnSourceType
            ,ti.TranType
      FROM #TMP_ITRN AS ti
      WHERE ti.TxnSourceType <> ''
      AND   ti.TxnKey <> ''
      GROUP BY ti.TxnSourceType
            ,  ti.TranType
      ORDER BY TxnSourceType
   
      OPEN @CUR_ITRN
   
      FETCH NEXT FROM @CUR_ITRN INTO @c_TxnSourceType, @c_TranType
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_TxnSourceType = 'ntrPickDetailUpdate'
         BEGIN
            UPDATE ti
            SET ti.ReferenceKey = o.Orderkey
               ,ti.ExternReferenceKey = ISNULL(o.ExternOrderkey,'')
               ,ti.ExternReferenceType = o.[Type]
               ,ti.Remarks = o.C_Company
            FROM #TMP_ITRN ti
            JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.PickDetailKey = ti.TxnKey
            JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = p.OrderKey
            WHERE ti.SourceType = @c_TxnSourceType
            AND ti.ReferenceKey = ''
            AND ti.TxnKey <> ''

            IF @c_DBName <> '' AND EXISTS (SELECT 1 FROM #TMP_ITRN ti WHERE ti.SourceType = @c_TxnSourceType AND ti.ReferenceKey = '' AND ti.TxnKey <> '')
            BEGIN
               SET @c_SQL = N'UPDATE ti'
                          + ' SET ti.ReferenceKey = o.Orderkey'
                          + '    ,ti.ExternReferenceKey = ISNULL(o.ExternOrderkey,'''')'
                          + '    ,ti.ExternReferenceType = o.[Type]'
                          + '    ,ti.Remarks = o.C_Company'
                          + ' FROM #TMP_ITRN ti'
                          + ' JOIN ' + @c_DBName + 'dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.PickDetailKey = ti.TxnKey'
                          + ' JOIN ' + @c_DBName + 'dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = p.OrderKey'
                          + ' WHERE ti.SourceType = @c_TxnSourceType'
                          + ' AND ti.ReferenceKey = '''''
                          + ' AND ti.TxnKey <> '''''

               SET @c_SQLParms = N'@c_TxnSourceType NVARCHAR(30)'

               EXEC sp_ExecuteSQL @c_SQL
                                 ,@c_SQLParms
                                 ,@c_TxnSourceType
            END
         END

         IF @c_TxnSourceType IN ('ntrReceiptDetailUpdate', 'ntrReceiptDetailAdd')
         BEGIN
            UPDATE ti
            SET ti.ReferenceKey = r.ReceiptKey
               ,ti.ExternReferenceKey = ISNULL(r.ExternReceiptkey,'')
               ,ti.ExternReferenceType = r.RecType
               ,ti.Remarks = ISNULL(CONVERT(NVARCHAR(255), r.Notes),'')
            FROM #TMP_ITRN ti
            JOIN dbo.RECEIPT AS r WITH (NOLOCK) ON r.ReceiptKey = ti.TxnKey
            WHERE ti.SourceType = @c_TxnSourceType
            AND ti.ReferenceKey = ''
            AND ti.TxnKey <> ''

            IF @c_DBName <> '' AND EXISTS (SELECT 1 FROM #TMP_ITRN ti WHERE ti.SourceType = @c_TxnSourceType AND ti.ReferenceKey = '' AND ti.TxnKey <> '')
            BEGIN
               SET @c_SQL = N'UPDATE ti'
                          + ' SET ti.ReferenceKey = r.ReceiptKey'
                          + '    ,ti.ExternReferenceKey = ISNULL(r.ExternReceiptkey,'''')'
                          + '    ,ti.ExternReferenceType = r.RecType'
                          + '    ,ti.Remarks = ISNULL(CONVERT(NVARCHAR(255), r.Notes),'''')'
                          + ' FROM #TMP_ITRN ti'
                          + ' JOIN ' + @c_DBName + 'dbo.RECEIPT AS r WITH (NOLOCK) ON r.ReceiptKey = ti.TxnKey'
                          + ' WHERE ti.SourceType = @c_TxnSourceType'
                          + ' AND ti.ReferenceKey = '''''
                          + ' AND ti.TxnKey <> '''''

               SET @c_SQLParms = N'@c_TxnSourceType NVARCHAR(30)'

               EXEC sp_ExecuteSQL @c_SQL
                                 ,@c_SQLParms
                                 ,@c_TxnSourceType
            END
         END

         IF @c_TxnSourceType IN ('ntrAdjustmentDetailUpdate', 'ntrAdjustmentDetailAdd')
         BEGIN
            UPDATE ti
            SET ti.ReferenceKey = a.AdjustmentKey
               ,ti.ExternReferenceKey = ISNULL(a.CustomerRefNo,'')
               ,ti.ExternReferenceType = a.AdjustmentType
               ,ti.Remarks = ISNULL(CONVERT(NVARCHAR(255), a.Remarks),'')
            FROM #TMP_ITRN ti
            JOIN dbo.ADJUSTMENT AS a WITH (NOLOCK) ON a.AdjustmentKey = ti.TxnKey
            WHERE ti.SourceType = @c_TxnSourceType
            AND ti.ReferenceKey = ''
            AND ti.TxnKey <> ''

            IF @c_DBName <> '' AND EXISTS (SELECT 1 FROM #TMP_ITRN ti WHERE ti.SourceType = @c_TxnSourceType AND ti.ReferenceKey = '' AND ti.TxnKey <> '')
            BEGIN
               SET @c_SQL = N'UPDATE ti'
                          + ' SET ti.ReferenceKey = a.AdjustmentKey'
                          + '    ,ti.ExternReferenceKey = ISNULL(a.CustomerRefNo,'''')'
                          + '    ,ti.ExternReferenceType = a.AdjustmentType'
                          + '    ,ti.Remarks = ISNULL(CONVERT(NVARCHAR(255), a.Remarks),'''')'
                          + ' FROM #TMP_ITRN ti'
                          + ' JOIN ' + @c_DBName + 'dbo.ADJUSTMENT AS a WITH (NOLOCK) ON a.AdjustmentKey = ti.TxnKey'
                          + ' WHERE ti.SourceType = @c_TxnSourceType'
                          + ' AND ti.ReferenceKey = '''''
                          + ' AND ti.TxnKey <> '''''

               SET @c_SQLParms = N'@c_TxnSourceType NVARCHAR(30)'

               EXEC sp_ExecuteSQL @c_SQL
                                 ,@c_SQLParms
                                 ,@c_TxnSourceType
            END
         END

         IF @c_TxnSourceType = 'ntrTransferDetailUpdate'
         BEGIN
            UPDATE ti
            SET ti.ReferenceKey = t.TransferKey
               ,ti.ExternReferenceKey = ISNULL(t.CustomerRefNo,'')
               ,ti.ExternReferenceType = t.[Type]
               ,ti.Remarks = ISNULL(CONVERT(NVARCHAR(255), t.Remarks),'')
            FROM #TMP_ITRN ti
            JOIN dbo.[TRANSFER] AS t WITH (NOLOCK) ON t.TransferKey = ti.TxnKey
            WHERE ti.SourceType = @c_TxnSourceType
            AND ti.ReferenceKey = ''
            AND ti.TxnKey <> ''

            IF @c_DBName <> '' AND EXISTS (SELECT 1 FROM #TMP_ITRN ti WHERE ti.SourceType = @c_TxnSourceType AND ti.ReferenceKey = '' AND ti.TxnKey <> '')
            BEGIN
               SET @c_SQL = N'UPDATE ti'
                          + ' SET ti.ReferenceKey = t.TransferKey'
                          + '    ,ti.ExternReferenceKey = ISNULL(t.CustomerRefNo,'''')'
                          + '    ,ti.ExternReferenceType = t.[Type]'
                          + '    ,ti.Remarks = ISNULL(CONVERT(NVARCHAR(255), t.Remarks),'''')'
                          + ' FROM #TMP_ITRN ti'
                          + ' JOIN ' + @c_DBName + 'dbo.[TRANSFER] AS t WITH (NOLOCK) ON t.TransferKey = ti.TxnKey'
                          + ' WHERE ti.SourceType = @c_TxnSourceType'
                          + ' AND ti.ReferenceKey = '''''
                          + ' AND ti.TxnKey <> '''''

               SET @c_SQLParms = N'@c_TxnSourceType NVARCHAR(30)'

               EXEC sp_ExecuteSQL @c_SQL
                                 ,@c_SQLParms
                                 ,@c_TxnSourceType
            END
         END
      
         IF @c_TxnSourceType = 'ntrInventoryQCDetailUpdate'
         BEGIN
            UPDATE ti
            SET ti.ReferenceKey = iq.QC_Key
               ,ti.ExternReferenceKey = ISNULL(iq.Refno,'')
               ,ti.ExternReferenceType = iq.Reason
               ,ti.Remarks = ISNULL(CONVERT(NVARCHAR(255), iq.Notes),'')
            FROM #TMP_ITRN ti
            JOIN dbo.InventoryQC AS iq WITH (NOLOCK) ON iq.QC_Key = ti.TxnKey
            WHERE ti.SourceType = @c_TxnSourceType
            AND ti.ReferenceKey = ''
            AND ti.TxnKey <> ''

            IF @c_DBName <> '' AND EXISTS (SELECT 1 FROM #TMP_ITRN ti WHERE ti.SourceType = @c_TxnSourceType AND ti.ReferenceKey = '' AND ti.TxnKey <> '')
            BEGIN
               SET @c_SQL = N'UPDATE ti'
                          + ' SET ti.ReferenceKey = iq.QC_Key'
                          + '    ,ti.ExternReferenceKey = ISNULL(iq.Refno,'''')'
                          + '    ,ti.ExternReferenceType = iq.Reason'
                          + '    ,ti.Remarks = ISNULL(CONVERT(NVARCHAR(255), iq.Notes),'''')'
                          + ' FROM #TMP_ITRN ti'
                          + ' JOIN ' + @c_DBName + 'dbo.InventoryQC AS iq WITH (NOLOCK) ON iq.QC_Key = ti.TxnKey' --(Wan01)
                          + ' WHERE ti.SourceType = @c_TxnSourceType'
                          + ' AND ti.ReferenceKey = '''''
                          + ' AND ti.TxnKey <> '''''

               SET @c_SQLParms = N'@c_TxnSourceType NVARCHAR(30)'

               EXEC sp_ExecuteSQL @c_SQL
                                 ,@c_SQLParms
                                 ,@c_TxnSourceType
            END
         END

         IF @c_TxnSourceType IN ( 'ntrKitDetailAdd' , 'ntrKitDetailUpdate' )
         BEGIN
            UPDATE ti
            SET ti.ReferenceKey = k.KITKey
               ,ti.ExternReferenceKey = ISNULL(k.ExternKitKey,'')
               ,ti.ExternReferenceType = k.[Type]
               ,ti.Remarks = ISNULL(CONVERT(NVARCHAR(255), k.Remarks),'')
            FROM #TMP_ITRN ti
            JOIN dbo.KIT AS k WITH (NOLOCK) ON k.KITKey = ti.TxnKey
            WHERE ti.SourceType = @c_TxnSourceType
            AND ti.ReferenceKey = ''
            AND ti.TxnKey <> ''

            IF @c_DBName <> '' AND EXISTS (SELECT 1 FROM #TMP_ITRN ti WHERE ti.SourceType = @c_TxnSourceType AND ti.ReferenceKey = '' AND ti.TxnKey <> '')
            BEGIN
               SET @c_SQL = N'UPDATE ti'
                          + ' SET ti.ReferenceKey = k.KITKey'
                          + '    ,ti.ExternReferenceKey = ISNULL(k.ExternKitKey,'''')'
                          + '    ,ti.ExternReferenceType =  k.[Type]'
                          + '    ,ti.Remarks = ISNULL(CONVERT(NVARCHAR(255), k.Remarks),'''')'
                          + ' FROM #TMP_ITRN ti'
                          + ' JOIN ' + @c_DBName + 'dbo.KIT AS k WITH (NOLOCK) ON k.KITKey = ti.TxnKey'  --(Wan01)
                          + ' WHERE ti.SourceType = @c_TxnSourceType'
                          + ' AND ti.ReferenceKey = '''''
                         + ' AND ti.TxnKey <> '''''

               SET @c_SQLParms = N'@c_TxnSourceType NVARCHAR(30)'

               EXEC sp_ExecuteSQL @c_SQL
                                 ,@c_SQLParms
                                 ,@c_TxnSourceType
            END
         END

         IF @c_TxnSourceType IN ( 'CC Deposit' , 'CC Withdrawal' )
         BEGIN
            UPDATE ti
            SET ti.ReferenceKey = stsp.StockTakeKey
               ,ti.ExternReferenceKey = stsp.Storerkey
               ,ti.ExternReferenceType= stsp.Facility
               ,ti.Remarks = ''
            FROM #TMP_ITRN ti
            JOIN dbo.StockTakeSheetParameters AS stsp WITH (NOLOCK) ON stsp.StockTakeKey = ti.TxnKey
            WHERE ti.SourceType = @c_TxnSourceType
            AND ti.ReferenceKey = ''
            AND ti.TxnKey <> ''
        
            IF @c_DBName <> '' AND EXISTS (SELECT 1 FROM #TMP_ITRN ti WHERE ti.SourceType = @c_TxnSourceType AND ti.ReferenceKey = '' AND ti.TxnKey <> '')
            BEGIN
               SET @c_SQL = N'UPDATE ti'
                          + ' SET ti.ReferenceKey = stsp.StockTakeKey'
                          + '    ,ti.ExternReferenceKey = stsp.Storerkey'
                          + '    ,ti.ExternReferenceType = stsp.Facility'
                          + '    ,ti.Remarks = '''''
                          + ' FROM #TMP_ITRN ti'
                          + ' JOIN ' + @c_DBName + 'dbo.StockTakeSheetParameters AS stsp WITH (NOLOCK) ON stsp.StockTakeKey = ti.TxnKey'
                          + ' WHERE ti.SourceType = @c_TxnSourceType'
                          + ' AND ti.ReferenceKey = '''''
                          + ' AND ti.TxnKey <> '''''

               SET @c_SQLParms = N'@c_TxnSourceType NVARCHAR(30)'

               EXEC sp_ExecuteSQL @c_SQL
                                 ,@c_SQLParms
                                 ,@c_TxnSourceType
            END
         END
      
         FETCH NEXT FROM @CUR_ITRN INTO @c_TxnSourceType, @c_TranType
      END
      CLOSE @CUR_ITRN
      DEALLOCATE @CUR_ITRN
      
      SET @c_SortPreference = ISNULL(@c_SortPreference,'')
      IF @c_SortPreference = ''
      BEGIN
         SET @c_SortPreference = N' ORDER BY ITRN.RowID ASC'               --(Wan05)
      END
      ELSE
      BEGIN
         SET @c_SortPreference = N' ORDER BY ' +  @c_SortPreference
      END

      SET @c_SQL  = N'SELECT'
                  +'  ITRN.AddDate'
                  +', ITRN.TranType'
                  +', ITRN.SourceKey'
                  +', ITRN.SourceType'
                  +', ITRN.StorerKey'
                  +', ITRN.Sku'
                  +', ITRN.FromLoc'
                  +', ITRN.FromID'
                  +', ITRN.ToLoc'
                  +', ITRN.ToID'
                  +', ITRN.Qty'
                  +', ITRN.LOTTABLE01'
                  +', ITRN.LOTTABLE02'
                  +', ITRN.LOTTABLE03'
                  +', ITRN.LOTTABLE04'
                  +', ITRN.LOTTABLE05'
                  +', ITRN.LOTTABLE06'
                  +', ITRN.LOTTABLE07'
                  +', ITRN.LOTTABLE08'
                  +', ITRN.LOTTABLE09'
                  +', ITRN.LOTTABLE10'
                  +', ITRN.LOTTABLE11'
                  +', ITRN.LOTTABLE12'
                  +', ITRN.LOTTABLE13'
                  +', ITRN.LOTTABLE14'
                  +', ITRN.LOTTABLE15'
                  +', ITRN.Lot'
                  +', ITRN.PackKey'
                  +', ITRN.UOMQty'
                  +', ITRN.AddWho'
                  +', ITRN.EditDate'
                  +', ITRN.EditWho'
                  +', ITRN.ItrnKey'
                  +', ITRN.[Status]'
                  +', ITRN.UOM'
                  +', ITRN.Channel'
                  +', ITRN.Channel_ID'
                  +', ITRN.FromFacility'
                  +', ITRN.ToFacility'
                  +', ITRN.SkuDescr'
                  +', ITRN.Style'
                  +', ITRN.Color'
                  +', ITRN.Size'
                  +', ITRN.Measurement'
                  +', ITRN.ReferenceKey'
                  +', ITRN.ExternReferenceKey'
                  +', ITRN.ExternReferenceType'
                  +', ITRN.Remarks'
                  +', ITRN.Rowfocusindicatorcol'
                  +', ITRN.SourceTypeDesc'                                          --(Wan05)  
                  +', ITRN.CaseQty'                                                 --(Wan05)
                  +', ITRN.InnerPackQty'                                            --(Wan05)     
                  +', ITRN.PalletType'
                  + ' FROM #TMP_ITRN AS ITRN'
                  + ' JOIN #TMP_ITRN AS LotAttribute ON LotAttribute.RowID = ITRN.RowID'      --(Wan04)   
                  + ' JOIN #TMP_ITRN AS SKU ON SKU.RowID = ITRN.RowID'                        --(Wan04)
                  + ' JOIN dbo.LOC TOLOC WITH (NOLOCK) ON TOLOC.Loc = ITRN.ToLoc'                  --JSM-156017 --(Wan04)   
                  + ' LEFT OUTER JOIN dbo.LOC FROMLOC WITH (NOLOCK) ON FROMLOC.Loc = ITRN.FromLoc' --JSM-156017 --(Wan04)   
                  + ' ' + @c_SearchCondition             --(Wan03)
                  + @c_SortPreference

      EXEC (@c_SQL)
      
      IF @@ROWCOUNT = 10000
      BEGIN
         SET @c_ErrMsg = 'SCE returns up to limit 10000 records'
      END
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
EXIT_SP:
   IF OBJECT_ID('tempdb..#TMP_ITRN','u') IS NOT NULL                                --(Wan05)
   BEGIN
      DROP TABLE #TMP_ITRN;
   END
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_GetItrn_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   REVERT
END -- procedure

GO