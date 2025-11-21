SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/ 
/* Object Name: isp_CC_vs_System                                           */
/* Modification History:                                                   */  
/*                                                                         */  
/* Called By:  Exceed                                                      */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Date         Author    Ver.  Purposes                                   */
/* 05-Aug-2002            1.0   Initial revision                           */
/* 15-Oct-2004  mohit     1.1   CHANGE CURSOR TYPE                         */
/* 15-Dec-2004  tlting    1.2   Add Drop object                            */
/***************************************************************************/    
CREATE PROCEDURE [dbo].[isp_CC_vs_System] @c_StorerKey nvarchar(15)
AS
BEGIN
  SET NOCOUNT ON
  SET QUOTED_IDENTIFIER OFF
  SET CONCAT_NULL_YIELDS_NULL OFF
  SELECT
    SKU.SKUGROUP,
    SKU.SKU,
    SKU.DESCR,
    LOTxLOCxID.LOC,
    LOTATTRIBUTE.LOTTABLE01,
    LOTATTRIBUTE.LOTTABLE04,
    SYSQTY = SUM(LOTxLOCxID.QTY),
    CCQTY = 0,
    FUJIQTY = 0 INTO #COMPARE
  FROM SKU(NOLOCK),
       LOTxLOCxID(NOLOCK),
       LOTATTRIBUTE(NOLOCK)
  WHERE SKU.STORERKEY = @c_StorerKey
  AND SKU.STORERKEY = LOTxLOCxID.STORERKEY
  AND SKU.SKU = LOTxLOCxID.SKU
  AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
  AND LOTxLOCxID.QTY > 0
  GROUP BY SKU.SKUGROUP,
           SKU.SKU,
           SKU.DESCR,
           LOTxLOCxID.LOC,
           LOTATTRIBUTE.LOTTABLE01,
           LOTATTRIBUTE.LOTTABLE04
  DECLARE CUR1 CURSOR FAST_FORWARD READ_ONLY FOR
  SELECT
    SKU.SKUGROUP,
    SKU.SKU,
    SKU.DESCR,
    CCDETAIL.LOC,
    ISNULL(CCDETAIL.LOTTABLE01, ''),
    CCDETAIL.LOTTABLE04,
    SUM(QTY)
  FROM SKU(NOLOCK),
       CCDETAIL(NOLOCK)
  WHERE SKU.STORERKEY = @c_StorerKey
  AND SKU.STORERKEY = CCDETAIL.STORERKEY
  AND SKU.SKU = CCDETAIL.SKU
  AND CCDETAIL.QTY > 0
  GROUP BY SKU.SKUGROUP,
           SKU.SKU,
           SKU.DESCR,
           CCDETAIL.LOC,
           CCDETAIL.LOTTABLE01,
           CCDETAIL.LOTTABLE04
  OPEN CUR1
  DECLARE @c_SKUGroup nvarchar(10),
          @c_SKU nvarchar(20),
          @c_DESCR nvarchar(60),
          @c_LOC nvarchar(10),
          @c_Lottable01 nvarchar(18),
          @d_Lottable04 datetime,
          @n_Qty int
  FETCH NEXT FROM CUR1 INTO @c_SKUGroup, @c_SKU, @c_DESCR, @c_LOC, @c_Lottable01, @d_Lottable04, @n_Qty
  WHILE @@FETCH_STATUS <> -1
  BEGIN
    IF EXISTS (SELECT
        SKU
      FROM #COMPARE
      WHERE SKU = @c_SKU
      AND LOC = @c_LOC
      AND Lottable01 = @c_Lottable01
      AND Lottable04 = @d_Lottable04)
    BEGIN
      UPDATE #COMPARE
      SET CCQty = CCQty + @n_Qty
      WHERE SKU = @c_SKU
      AND LOC = @c_LOC
      AND Lottable01 = @c_Lottable01
      AND Lottable04 = @d_Lottable04
    END
    ELSE
    BEGIN
      INSERT INTO #COMPARE (SKU, SKUGroup, Descr, LOC, Lottable01, Lottable04, SysQty, CCQty, FUJIQty)
        VALUES (@c_SKU, @c_SKUGroup, @c_Descr, @c_LOC, @c_Lottable01, @d_Lottable04, 0, @n_Qty, 0)
    END
    FETCH NEXT FROM CUR1 INTO @c_SKUGroup, @c_SKU, @c_DESCR, @c_LOC, @c_Lottable01, @d_Lottable04, @n_Qty
  END
  CLOSE CUR1
  DEALLOCATE CUR1

  SELECT *
  FROM #COMPARE
  ORDER BY SKUGROUP, SKU, LOC
  DROP TABLE #COMPARE
END


GO