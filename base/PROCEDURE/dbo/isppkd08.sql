SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispPKD08                                           */
/* Creation Date: 16-May-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22539 - [AU] LEVIS AUTO MOVE SHORT PICK                 */
/*                                                                      */
/* Called By: isp_PickDetailTrigger_Wrapper from Pickdetail Trigger     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 16-May-2023  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/

CREATE   PROC [dbo].[ispPKD08]
   @c_Action    NVARCHAR(10)
 , @c_Storerkey NVARCHAR(15)
 , @b_Success   INT           OUTPUT
 , @n_Err       INT           OUTPUT
 , @c_ErrMsg    NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT
         , @n_StartTCnt       INT
         , @c_ExecStatements  NVARCHAR(MAX)
         , @c_ExecArguments   NVARCHAR(MAX)
         , @c_ColName         NVARCHAR(100)
         , @c_ColData         NVARCHAR(100)
         , @c_Table           NVARCHAR(100)
         , @c_Column          NVARCHAR(100)
         , @c_SKU             NVARCHAR(20)
         , @c_Lot             NVARCHAR(10)
         , @c_Loc             NVARCHAR(10)
         , @c_ID              NVARCHAR(30)
         , @n_QtyAvailable    INT
         , @c_Packkey         NVARCHAR(20)
         , @c_UOM             NVARCHAR(20)
         , @c_ToLoc           NVARCHAR(20)
         , @c_Pickdetailkey   NVARCHAR(10)
         , @c_Orderkey        NVARCHAR(10)
         , @c_OrderLineNumber NVARCHAR(5)
         , @c_ToID            NVARCHAR(50)

   SELECT @n_Continue = 1
        , @n_StartTCnt = @@TRANCOUNT
        , @n_Err = 0
        , @c_ErrMsg = ''
        , @b_Success = 1

   IF @c_Action NOT IN ( 'INSERT', 'UPDATE', 'DELETE' )
      GOTO QUIT_SP

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END

   IF @c_Action = 'DELETE'
   BEGIN
      CREATE TABLE #T_ORD
      (
         Pickdetailkey        NVARCHAR(10)
      )

      DECLARE CUR_CLK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ISNULL(CL.Code, '') AS ToLoc
           , ISNULL(CL.Long, '') AS ColName
           , ISNULL(CL.code2, '') AS ColData
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'SHORTPKLOC' AND CL.Storerkey = @c_Storerkey
      ORDER BY CASE WHEN CL.Long = 'DEFAULT' THEN 2
                    ELSE 1 END
             , CL.Long
             , CL.code2

      OPEN CUR_CLK

      FETCH NEXT FROM CUR_CLK
      INTO @c_ToLoc
         , @c_ColName
         , @c_ColData

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_ColName = 'DEFAULT'
         BEGIN
            SET @c_ColName = N'1'
            SET @c_ColData = N'1'
         END
         ELSE
         BEGIN
            SELECT @c_Table = FDS.ColValue
            FROM dbo.fnc_DelimSplit('.', @c_ColName) FDS
            WHERE FDS.SeqNo = 1

            SELECT @c_Column = FDS.ColValue
            FROM dbo.fnc_DelimSplit('.', @c_ColName) FDS
            WHERE FDS.SeqNo = 2

            IF NOT EXISTS (  SELECT 1
                             FROM INFORMATION_SCHEMA.COLUMNS
                             WHERE TABLE_NAME = @c_Table AND COLUMN_NAME = @c_Column)
            BEGIN
               SELECT @n_Continue = 3
               SELECT @n_Err = 35100
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5), @n_Err) + ': ' + @c_ColName
                                  + ' is not a valid column. (ispPKD08)'
               GOTO QUIT_SP
            END
         END

         IF NOT EXISTS ( SELECT 1
                         FROM LOC (NOLOCK)
                         WHERE LOC = @c_ToLoc)
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_Err = 35105
            SELECT @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5), @n_Err) + ': ' + @c_ToLoc
                               + ' is not a valid Loc. (ispPKD08)'
            GOTO QUIT_SP
         END

         SET @c_ExecStatements = N' DECLARE CUR_PD CURSOR FAST_FORWARD READ_ONLY FOR ' + CHAR(13)
                               + N' SELECT PICKDETAIL.Pickdetailkey, PICKDETAIL.SKU, PICKDETAIL.Lot, PICKDETAIL.Loc, PICKDETAIL.ID, ' + CHAR(13)
                               + N'        PICKDETAIL.Qty, PACK.Packkey, PACK.PackUOM3, PICKDETAIL.Orderkey, PICKDETAIL.OrderLineNumber ' + CHAR(13) 
                               + N' FROM #DELETED PICKDETAIL ' + CHAR(13)
                               + N' JOIN ORDERS (NOLOCK) ON PICKDETAIL.OrderKey = ORDERS.OrderKey ' + CHAR(13)
                               + N' JOIN SKU (NOLOCK) ON PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.SKU = SKU.SKU ' + CHAR(13) 
                               + N' JOIN PACK (NOLOCK) ON PACK.PACKKey = SKU.PACKKey ' + CHAR(13)
                               + N' LEFT JOIN #T_ORD T ON (PICKDETAIL.Pickdetailkey = T.Pickdetailkey) ' + CHAR(13)
                               + N' WHERE PICKDETAIL.StorerKey = @c_Storerkey AND PICKDETAIL.Qty > 0 ' + CHAR(13)
                               + N' AND PICKDETAIL.[Status] = ''4'' ' + CHAR(13)
                               + N' AND ' + TRIM(@c_ColName) + N' = @c_ColData ' + CHAR(13)
                               + N' AND T.Pickdetailkey IS NULL '
                               + N' ORDER BY PICKDETAIL.Pickdetailkey '

         SET @c_ExecArguments = N'  @c_Storerkey      NVARCHAR(15)  ' 
                              + N', @c_ColData        NVARCHAR(100) '
                              + N', @c_ToLoc          NVARCHAR(20) '

         EXEC sp_executesql @c_ExecStatements
                          , @c_ExecArguments
                          , @c_Storerkey
                          , @c_ColData
                          , @c_ToLoc

         OPEN CUR_PD

         FETCH NEXT FROM CUR_PD
         INTO @c_Pickdetailkey
            , @c_SKU
            , @c_Lot
            , @c_Loc
            , @c_ID
            , @n_QtyAvailable
            , @c_Packkey
            , @c_UOM
            , @c_Orderkey
            , @c_OrderLineNumber

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @c_ToID = TRIM(@c_Orderkey) + TRIM(@c_OrderLineNumber)

            EXECUTE nspItrnAddMove @n_ItrnSysId = NULL
                                 , @c_itrnkey = NULL
                                 , @c_StorerKey = @c_Storerkey
                                 , @c_Sku = @c_SKU
                                 , @c_Lot = @c_Lot
                                 , @c_FromLoc = @c_Loc
                                 , @c_FromID = @c_ID
                                 , @c_ToLoc = @c_ToLoc
                                 , @c_ToID = @c_ToID
                                 , @c_Status = ''
                                 , @c_lottable01 = ''
                                 , @c_lottable02 = ''
                                 , @c_lottable03 = ''
                                 , @d_lottable04 = NULL
                                 , @d_lottable05 = NULL
                                 , @c_lottable06 = ''
                                 , @c_lottable07 = ''
                                 , @c_lottable08 = ''
                                 , @c_lottable09 = ''
                                 , @c_lottable10 = ''
                                 , @c_lottable11 = ''
                                 , @c_lottable12 = ''
                                 , @d_lottable13 = NULL
                                 , @d_lottable14 = NULL
                                 , @d_lottable15 = NULL
                                 , @n_casecnt = 0
                                 , @n_innerpack = 0
                                 , @n_qty = @n_QtyAvailable
                                 , @n_pallet = 0
                                 , @f_cube = 0
                                 , @f_grosswgt = 0
                                 , @f_netwgt = 0
                                 , @f_otherunit1 = 0
                                 , @f_otherunit2 = 0
                                 , @c_SourceKey = @c_Pickdetailkey
                                 , @c_SourceType = 'ispPKD08'
                                 , @c_PackKey = @c_Packkey
                                 , @c_UOM = @c_UOM
                                 , @b_UOMCalc = 1
                                 , @d_EffectiveDate = NULL
                                 , @b_Success = @b_Success OUTPUT
                                 , @n_err = @n_Err OUTPUT
                                 , @c_errmsg = @c_ErrMsg OUTPUT

            IF @b_Success <> 1
            BEGIN
               SELECT @n_Continue = 3
               GOTO QUIT_SP
            END

            IF NOT EXISTS ( SELECT 1
                            FROM #T_ORD TOR
                            WHERE TOR.Pickdetailkey = @c_Pickdetailkey)
            BEGIN
               INSERT #T_ORD (Pickdetailkey)
               VALUES (@c_Pickdetailkey)
            END

            FETCH NEXT FROM CUR_PD
            INTO @c_Pickdetailkey
               , @c_SKU
               , @c_Lot
               , @c_Loc
               , @c_ID
               , @n_QtyAvailable
               , @c_Packkey
               , @c_UOM
               , @c_Orderkey
               , @c_OrderLineNumber
         END
         CLOSE CUR_PD
         DEALLOCATE CUR_PD

         FETCH NEXT FROM CUR_CLK
         INTO @c_ToLoc
            , @c_ColName
            , @c_ColData
      END
      CLOSE CUR_CLK
      DEALLOCATE CUR_CLK
   END

   QUIT_SP:

   IF OBJECT_ID('tempdb..#T_ORD') IS NOT NULL
      DROP TABLE #T_ORD

   IF CURSOR_STATUS('GLOBAL', 'CUR_PD') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_PD
      DEALLOCATE CUR_PD
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_CLK') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_CLK
      DEALLOCATE CUR_CLK
   END

   IF @n_Continue = 3 -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
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
      EXECUTE dbo.nsp_logerror @n_Err, @c_ErrMsg, 'ispPKD08'
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO