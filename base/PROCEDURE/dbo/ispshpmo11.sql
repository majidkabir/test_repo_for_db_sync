SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispSHPMO11                                            */
/* Creation Date: 16-May-2023                                              */
/* Copyright: MAERSK                                                       */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-22547 - [AU] LEVIS Post MBOL Auto Move - CR                */
/*                                                                         */
/* Called By: ispPostMBOLShipWrapper                                       */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 16-May-2023  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/
CREATE   PROC [dbo].[ispSHPMO11]
(
   @c_MBOLkey   NVARCHAR(10)
 , @c_Storerkey NVARCHAR(15)
 , @b_Success   INT           OUTPUT
 , @n_Err       INT           OUTPUT
 , @c_ErrMsg    NVARCHAR(255) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Debug     INT
         , @n_Continue  INT
         , @n_StartTCnt INT

   DECLARE @n_PStatusCnt       INT
         , @n_PLoadStatusCnt   INT
         , @c_Orderkey         NVARCHAR(10)
         , @c_OrderLineNumber  NVARCHAR(5)
         , @c_SKU              NVARCHAR(30)
         , @c_OriginalQty      INT
         , @c_OpenQty          INT
         , @c_ShippedQty       INT
         , @c_PLoadKey         NVARCHAR(10)
         , @c_PLoadStatus      NVARCHAR(10)
         , @c_BlockLocation    NVARCHAR(50)
         , @n_OrdDetQty        INT
         , @n_LotLocIDQty      INT
         , @n_SumLotLocIDQty   INT
         , @c_Lot              NVARCHAR(10)
         , @c_Loc              NVARCHAR(10)
         , @c_ID               NVARCHAR(18)
         , @c_FromLoc          NVARCHAR(10)
         , @c_ToLoc            NVARCHAR(10)
         , @c_Packkey          NVARCHAR(10)
         , @c_UOM              NVARCHAR(10)
         , @c_sourcekey        NVARCHAR(20)
         , @n_QtyLeftToFulfill INT
         , @n_QtyAvailable     INT
         , @c_ExecStatements   NVARCHAR(MAX)
         , @c_ExecArguments    NVARCHAR(MAX)
         , @c_ColName          NVARCHAR(100)
         , @c_ColData          NVARCHAR(100)
         , @c_Table            NVARCHAR(100)
         , @c_Column           NVARCHAR(100)

   SET @b_Success = 1
   SET @n_Err = 0
   SET @c_ErrMsg = ''
   SET @b_Debug = '1'
   SET @n_Continue = 1
   SET @n_StartTCnt = @@TRANCOUNT

   SET @n_PStatusCnt = 0
   SET @n_PLoadStatusCnt = 0
   SET @c_PLoadKey = N''
   SET @c_PLoadStatus = N''
   SET @c_sourcekey = N''

   CREATE TABLE #T_ORD
   (
      Orderkey        NVARCHAR(10)
    , OrderLineNumber NVARCHAR(5)
    , Storerkey       NVARCHAR(15)
    , SKU             NVARCHAR(20)
   )

   SELECT @c_Storerkey = OH.StorerKey
   FROM ORDERS OH (NOLOCK)
   WHERE OH.MBOLKey = @c_MBOLkey

   --Main Process
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      DECLARE CUR_CLK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ISNULL(CL.Long, '') AS FromLoc
           , ISNULL(CL.Short, '') AS ToLoc
           , ISNULL(CL.Notes, '') AS ColName
           , ISNULL(CL.code2, '') AS ColData
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'LEVTOLOC' AND CL.Code = 'AUTOMOVE' AND CL.Storerkey = @c_Storerkey
      ORDER BY CASE WHEN CL.Notes = 'DEFAULT' THEN 2
                    ELSE 1 END
             , CL.Notes
             , CL.code2

      OPEN CUR_CLK

      FETCH NEXT FROM CUR_CLK
      INTO @c_FromLoc
         , @c_ToLoc
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
                                  + ' is not a valid column. (ispSHPMO11)'
               GOTO QUIT_SP
            END
         END

         --Cursor to find OpenQTY as @n_QtyLeftToFulfill
         SET @c_ExecStatements = N' DECLARE CURSOR_QTY CURSOR FAST_FORWARD READ_ONLY FOR ' + CHAR(13)
                               + N' SELECT DISTINCT ORDERS.StorerKey ' + CHAR(13)
                               + N'               , ORDERS.OrderKey ' + CHAR(13)
                               + N'               , ORDERDETAIL.OrderLineNumber ' + CHAR(13)
                               + N'               , ORDERDETAIL.Sku ' + CHAR(13)
                               + N'               , (ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked - ORDERDETAIL.ShippedQty) ' + CHAR(13) 
                               + N' FROM MBOLDETAIL WITH (NOLOCK) ' + CHAR(13)
                               + N' JOIN ORDERS WITH (NOLOCK) ON (MBOLDETAIL.OrderKey = ORDERS.OrderKey) ' + CHAR(13)
                               + N' JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) ' + CHAR(13)
                               + N' LEFT JOIN #T_ORD T ON (ORDERDETAIL.Storerkey = T.Storerkey AND ORDERDETAIL.Sku = T.Sku AND ORDERDETAIL.OrderKey = T.OrderKey ' + CHAR(13)
                               + N'                    AND ORDERDETAIL.OrderLineNumber = T.OrderLineNumber) ' + CHAR(13)
                               + N' WHERE MBOLDETAIL.MbolKey = @c_MBOLkey AND ORDERS.StorerKey = @c_Storerkey ' + CHAR(13)
                               + N' AND   (ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked - ORDERDETAIL.ShippedQty) > 0 ' + CHAR(13)
                               + N' AND   ORDERS.Doctype = ''N'' ' + CHAR(13) 
                               + N' AND ' + TRIM(@c_ColName) + ' = @c_ColData ' + CHAR(13) 
                               + N' AND T.Orderkey IS NULL '

         SET @c_ExecArguments = N'  @c_MBOLkey         NVARCHAR(10)  ' 
                              + N', @c_Storerkey       NVARCHAR(15)  '
                              + N', @c_ColData         NVARCHAR(100) '

         EXEC sp_executesql @c_ExecStatements
                          , @c_ExecArguments
                          , @c_MBOLkey
                          , @c_Storerkey
                          , @c_ColData

         OPEN CURSOR_QTY

         FETCH NEXT FROM CURSOR_QTY
         INTO @c_Storerkey
            , @c_Orderkey
            , @c_OrderLineNumber
            , @c_SKU
            , @n_QtyLeftToFulfill

         WHILE (@@FETCH_STATUS <> -1)
         BEGIN
            SELECT @c_Packkey = SKU.PACKKey
                 , @c_UOM = PACK.PackUOM3
            FROM SKU (NOLOCK)
            JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
            WHERE SKU.Sku = @c_SKU

            SET @c_sourcekey = TRIM(@c_Orderkey) + TRIM(@c_OrderLineNumber)

            --Nested cursor to find QtyAvailable from LotxLocxID
            DECLARE CURSOR_AVAILABLE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LOTxLOCxID.Lot
                 , LOTxLOCxID.Loc
                 , LOTxLOCxID.Id
                 , QTYAVAILABLE = (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked
                                   - LOTxLOCxID.QtyReplen)
            FROM LOTxLOCxID (NOLOCK)
            JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
            JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.Id)
            JOIN LOT (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)
            JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.Lot = LA.Lot
            JOIN SKUxLOC SL (NOLOCK) ON (   LOTxLOCxID.StorerKey = SL.StorerKey
                                        AND LOTxLOCxID.Sku = SL.Sku
                                        AND LOTxLOCxID.Loc = SL.Loc)
            WHERE (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) > 0
            AND LOTxLOCxID.StorerKey = @c_Storerkey
            AND LOTxLOCxID.Sku = @c_SKU
            AND LOC.HOSTWHCODE = 'U'
            AND LOTxLOCxID.Loc = @c_FromLoc
            AND LOTxLOCxID.Id = @c_Sourcekey

            OPEN CURSOR_AVAILABLE

            FETCH NEXT FROM CURSOR_AVAILABLE
            INTO @c_Lot
               , @c_Loc
               , @c_ID
               , @n_QtyAvailable

            WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)
            BEGIN
               IF (@n_QtyLeftToFulfill < @n_QtyAvailable) --If OpenQty < LotxLocxID.Qty, just take the OpenQty
               BEGIN
                  SET @n_QtyAvailable = @n_QtyLeftToFulfill
                  SET @n_QtyLeftToFulfill = 0
               END
               ELSE
                  SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyAvailable

               IF (@n_Continue = 1 OR @n_Continue = 2)
               BEGIN
                  EXECUTE nspItrnAddMove @n_ItrnSysId = NULL
                                       , @c_itrnkey = NULL
                                       , @c_StorerKey = @c_Storerkey
                                       , @c_Sku = @c_SKU
                                       , @c_Lot = @c_Lot
                                       , @c_FromLoc = @c_Loc
                                       , @c_FromID = @c_ID
                                       , @c_ToLoc = @c_ToLoc
                                       , @c_ToID = @c_ID
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
                                       , @c_SourceKey = @c_sourcekey
                                       , @c_SourceType = 'ispSHPMO11'
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
                                  WHERE TOR.Orderkey = @c_Orderkey
                                  AND TOR.OrderLineNumber = @c_OrderLineNumber
                                  AND TOR.Storerkey = @c_Storerkey
                                  AND TOR.SKU = @c_SKU)
                  BEGIN
                     INSERT #T_ORD (Orderkey, OrderLineNumber, Storerkey, SKU)
                     VALUES (@c_Orderkey -- Orderkey - nvarchar(10)
                           , @c_OrderLineNumber -- OrderLineNumber - nvarchar(5)
                           , @c_Storerkey -- Storerkey - nvarchar(15)
                           , @c_SKU -- SKU - nvarchar(20)
                        )
                  END
               END

               FETCH NEXT FROM CURSOR_AVAILABLE
               INTO @c_Lot
                  , @c_Loc
                  , @c_ID
                  , @n_QtyAvailable
            END
            CLOSE CURSOR_AVAILABLE
            DEALLOCATE CURSOR_AVAILABLE
            --Nested cursor to find QtyAvailable from LotxLocxID

            FETCH NEXT FROM CURSOR_QTY
            INTO @c_Storerkey
               , @c_Orderkey
               , @c_OrderLineNumber
               , @c_SKU
               , @n_QtyLeftToFulfill
         END
         CLOSE CURSOR_QTY
         DEALLOCATE CURSOR_QTY
         --Cursor to find OpenQTY as @n_QtyLeftToFulfill

         FETCH NEXT FROM CUR_CLK
         INTO @c_FromLoc
            , @c_ToLoc
            , @c_ColName
            , @c_ColData
      END
      CLOSE CUR_CLK
      DEALLOCATE CUR_CLK
   END
   --Main Process End

   QUIT_SP:

   IF OBJECT_ID('tempdb..#T_ORD') IS NOT NULL
      DROP TABLE #T_ORD

   IF CURSOR_STATUS('LOCAL', 'CURSOR_AVAILABLE') IN ( 0, 1 )
   BEGIN
      CLOSE CURSOR_AVAILABLE
      DEALLOCATE CURSOR_AVAILABLE
   END
   
   IF CURSOR_STATUS('GLOBAL', 'CURSOR_QTY') IN ( 0, 1 )
   BEGIN
      CLOSE CURSOR_QTY
      DEALLOCATE CURSOR_QTY
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_CLK') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_CLK
      DEALLOCATE CUR_CLK
   END

   IF @n_Continue = 3 -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispSHPMO11'
      RAISERROR(@c_ErrMsg, 16, 1) WITH SETERROR -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO