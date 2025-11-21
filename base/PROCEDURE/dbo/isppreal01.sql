SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispPreAL01                                         */
/* Creation Date: 23-Apr-2014                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 306662-Substitute sku qty calculation on openqty            */
/*                                                                      */
/* Called By: StorerConfig.ConfigKey = PreAllocationSP                  */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Rev   Purposes                                  */
/* 23-04-2014   NJOW    1.0   Initial Version                           */
/* 23-05-2013   NJOW01  1.1   Change sort by size desc                  */
/* 13-06-2014   NJOW02  1.2   fix sort by lottable05                    */
/* 04-08-2014   NJOW03  1.3   306662-Sort size by ASC/DESC based on     */
/*                            sku.busr5 setting                         */
/************************************************************************/

 CREATE PROC [dbo].[ispPreAL01]
     @c_OrderKey         NVARCHAR(10)
   , @c_LoadKey          NVARCHAR(10)
   , @b_Success     INT           OUTPUT
   , @n_Err         INT           OUTPUT
   , @c_ErrMsg      NVARCHAR(250) OUTPUT
   , @b_debug       INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE  @n_Continue    INT,
            @n_StartTCnt   INT -- Holds the current transaction count

   DECLARE  @c_Busr4              NVARCHAR(30),
            @c_FirstSku           NCHAR(1),
            @n_EnteredQty         INT,
            @n_QtyAvailable       INT,
            @n_QtyLeftTofulfill   INT,
            @n_QtyToAllocate      INT,
            @c_OrderLineNumber    NVARCHAR(5),
            @c_OrderLineNumberUpd NVARCHAR(5),
            @d_Lottable05         DATETIME --NJOW02

   CREATE TABLE #TMP_SKUBAL (Orderkey NVARCHAR(10) NULL,
                             OrderLineNumber NVARCHAR(5) NULL,
                             QtyAvailable INT NULL,
                             Lottable05 DATETIME NULL)

   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0
   SELECT @c_ErrMsg=''

   IF @n_Continue=1 OR @n_Continue=2
   BEGIN
      IF ISNULL(RTRIM(@c_OrderKey),'') = ''
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_Err = 63500
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Orderkey is Blank (ispPreAL01)'
         GOTO EXIT_SP
      END
   END -- @n_Continue =1 or @n_Continue = 2


   DECLARE CUR_MASTERSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT SKU.Busr4 --Tesco sku
      FROM ORDERS O (NOLOCK)
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
      JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
      WHERE ISNULL(SKU.Busr4,'') <> ''
      AND O.Orderkey = @c_Orderkey
      GROUP BY SKU.Busr4
      HAVING COUNT(DISTINCT SKU.Sku) > 1 AND SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) = 0  --Substitute sku and related sku not allocated
      ORDER BY SKU.Busr4

   OPEN CUR_MASTERSKU

   FETCH NEXT FROM CUR_MASTERSKU INTO @c_busr4

   WHILE @@FETCH_STATUS <> -1
   BEGIN
   	  IF @b_debug = 1
   	     SELECT '@c_busr4', @c_busr4

   	  --NJOW02
    	UPDATE ORDERDETAIL WITH (ROWLOCK)
      SET OpenQty = 0
      FROM ORDERDETAIL
      JOIN SKU (NOLOCK) ON ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku
     	WHERE ORDERDETAIL.Orderkey = @c_Orderkey
      AND SKU.Busr4 = @c_Busr4

      DELETE FROM #TMP_SKUBAL

      INSERT INTO #TMP_SKUBAL
         SELECT OD.Orderkey, OD.OrderLineNumber,
                SUM(LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED) AS QtyAvailable,
                LA.Lottable05 --NJOW02
                --MIN(LA.Lottable05) AS Lottable05
         FROM ORDERS O (NOLOCK)
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
         JOIN LOTxLOCxID LLI (NOLOCK) ON O.Storerkey = LLI.Storerkey AND OD.Sku = LLI.Sku
         JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
         JOIN LOT (NOLOCK) ON LA.LOT = LOT.Lot
         JOIN LOC (NOLOCK) ON LLI.LOC = LOC.LOC AND O.Facility = LOC.Facility
         JOIN ID (NOLOCK) ON LLI.ID = ID.ID
         WHERE O.Orderkey = @c_Orderkey
         AND SKU.Busr4 = @c_Busr4
         AND (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED) > 0
         AND LOT.STATUS = 'OK'
         AND LOC.STATUS = 'OK'
         AND LOC.LocationFlag = 'NONE'
         AND ID.STATUS = 'OK'
         GROUP By OD.Orderkey, OD.OrderLineNumber,
                  LA.Lottable05 --NJOW02

      DECLARE CUR_SUBSTITUTE_SKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT OD.OrderLineNumber, OD.EnteredQty, ISNULL(#TMP_SKUBAL.QtyAvailable,0),
                CASE WHEN #TMP_SKUBAL.Lottable05 IS NULL THEN CAST('29991231' AS DATETIME) ELSE #TMP_SKUBAL.Lottable05 END AS Lottable05 --NJOW02
         FROM ORDERDETAIL OD (NOLOCK)
         JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
         LEFT JOIN #TMP_SKUBAL ON OD.Orderkey = #TMP_SKUBAL.Orderkey AND OD.OrderLineNumber = #TMP_SKUBAL.OrderLineNumber
         WHERE OD.Orderkey = @c_Orderkey
         AND SKU.Busr4 = @c_Busr4
         ORDER BY CASE WHEN #TMP_SKUBAL.Lottable05 IS NULL THEN CAST('29991231' AS DATETIME) ELSE #TMP_SKUBAL.Lottable05 END,
                  CASE WHEN SKU.Busr5 = 'ASC' THEN SKU.Size ELSE '' END ASC, --NJOW03
                  CASE WHEN SKU.Busr5 = 'DESC' OR ISNULL(SKU.Busr5,'') = '' THEN SKU.Size ELSE '' END DESC, --NJOW03
                  SKU.Sku --sort by sku with old lot

      OPEN CUR_SUBSTITUTE_SKU

      FETCH NEXT FROM CUR_SUBSTITUTE_SKU INTO @c_OrderLineNumber, @n_EnteredQty, @n_QtyAvailable,
                                              @d_Lottable05 --NJOW02

   	  SELECT @c_FirstSku = 'Y'
   	  SELECT @n_QtyLeftTofulfill = 0
      WHILE @@FETCH_STATUS <> -1
      BEGIN
      	 SELECT @c_OrderLineNumberUpd = @c_OrderLineNumber

      	 IF @b_debug = 1
   	        SELECT '@c_OrderLineNumber', @c_OrderLineNumber, '@n_EnteredQty', @n_EnteredQty, '@n_QtyAvailable', @n_QtyAvailable

      	 IF @c_FirstSku = 'Y'
      	 BEGIN
      	 	  SELECT @n_QtyLeftTofulfill = @n_EnteredQty  --get from first sku only
         	  IF @b_debug = 1
         	     SELECT '@c_FirstSku', @c_FirstSku, '@n_QtyLeftTofulfill', @n_QtyLeftTofulfill
      	 	  SELECT @c_FirstSku = 'N'
      	 END

      	 IF @n_QtyLeftTofulfill = 0 -- no more qty to fulfill set 0 to openqty
      	 BEGIN
      	 	  SELECT @n_QtyToAllocate = 0
      	 END
      	 ELSE IF @n_QtyAvailable >= @n_QtyLeftTofulfill -- enough stock to fulfill set remain to openqty
      	 BEGIN
      	 	  SELECT @n_QtyToAllocate = @n_QtyLeftTofulfill
      	 	  SELECT @n_QtyLeftTofulfill = 0
      	 END
      	 ELSE IF @n_QtyAvailable > 0 AND @n_QtyAvailable < @n_QtyLeftTofulfill  --partial stock to fulfill set available to openqty
      	 BEGIN
      	 	  SELECT @n_QtyToAllocate = @n_QtyAvailable
      	 	  SELECT @n_QtyLeftTofulfill = @n_QtyLeftTofulfill - @n_QtyAvailable
      	 END
      	 ELSE
      	 BEGIN --no more stock set remain qty to openqty (zero stock item will sort at last)
      	 	  SELECT @n_QtyToAllocate = @n_QtyLeftTofulfill
      	 	  SELECT @n_QtyLeftTofulfill = 0
      	 END

      	 IF @b_debug = 1
         	  SELECT '@n_QtyToAllocate', @n_QtyToAllocate, '@n_QtyLeftTofulfill', @n_QtyLeftTofulfill

      	 UPDATE ORDERDETAIL WITH (ROWLOCK)
      	 SET OpenQty = OpenQty + @n_QtyToAllocate --NJOW02
      	 --SET OpenQty = @n_QtyToAllocate
      	 WHERE Orderkey = @c_Orderkey
      	 AND OrderLineNumber = @c_OrderLineNumberUpd
      	 --AND OpenQty <> @n_QtyToAllocate

         FETCH NEXT FROM CUR_SUBSTITUTE_SKU INTO @c_OrderLineNumber, @n_EnteredQty, @n_QtyAvailable,
                                                 @d_Lottable05 --NJOW02
      END
      CLOSE CUR_SUBSTITUTE_SKU
      DEALLOCATE CUR_SUBSTITUTE_SKU

      IF @n_QtyLeftTofulfill > 0 --if reach last line and still have qty to fulfill, add remain qty to openqty
      BEGIN
         SELECT @n_QtyToAllocate = @n_QtyToAllocate + @n_QtyLeftTofulfill
         SELECT @n_QtyLeftTofulfill = 0
         IF @b_debug = 1
            SELECT 'Last Line With Qty Remain', '@n_QtyToAllocate', @n_QtyToAllocate, '@n_QtyLeftTofulfill', @n_QtyLeftTofulfill

      	 UPDATE ORDERDETAIL WITH (ROWLOCK)
         SET OpenQty = OpenQty + @n_QtyToAllocate --NJOW02
      	 --SET OpenQty = @n_QtyToAllocate
      	 WHERE Orderkey = @c_Orderkey
      	 AND OrderLineNumber = @c_OrderLineNumberUpd
      	 --AND OpenQty <> @n_QtyToAllocate
      END

      FETCH NEXT FROM CUR_MASTERSKU INTO @c_busr4
   END
   CLOSE CUR_MASTERSKU
   DEALLOCATE CUR_MASTERSKU


EXIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPreAL01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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

END -- Procedure


GO