SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/
/* Store procedure: isp_HealthCheck_ByStorer                                 */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: Backend Task to check TABLE Integrity                            */
/*          Called By SQL Scheduler                                          */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2010-06-15 1.1  TLTING   CAST Quantity SUM  (tlting01            )        */
/* 2010-08-17 1.1  Shong    DO NOT Check Archive..ITRN IF Not EXISTS         */
/*                          (Shong01)                                        */
/*                                                                           */
/*****************************************************************************/

CREATE PROC [dbo].[isp_HealthCheck_ByStorer]
   @c_StorerKey NVARCHAR(15)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   PRINT '************************************************'
   PRINT ' '
   SELECT 'Database'= CONVERT(CHAR(20), db_name()), 'Current Date' = GETDATE()
   PRINT '************************************************'
   PRINT '************************************************'

   SELECT Sku, StorerKey, Qty = SUM(CAST (Qty AS BIGINT) ) INTO #temp_sum1
   FROM SKUxLOC (NOLOCK)
   WHERE Qty > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey,Sku

   SELECT Sku, StorerKey, Qty = SUM(CAST (Qty AS BIGINT) ) INTO #temp_sum11
   FROM LOTxLOCxID (NOLOCK)
   WHERE Qty > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey,Sku

   SELECT a_storerkey = a.StorerKey, a_sku = a.Sku, b_storerkey = b.StorerKey, b_sku = b.Sku,
      sum_skuxloc =a.Qty, sum_lotxlocxid = b.Qty INTO #info1
   FROM #temp_sum1 a FULL OUTER JOIN #temp_sum11 b ON a.Sku = b.Sku AND a.StorerKey = b.StorerKey
   WHERE  a.Qty <> b.Qty
      OR a.Sku IS NULL OR b.Sku IS NULL
      OR a.StorerKey IS NULL OR b.StorerKey IS NULL

   IF EXISTS (SELECT 1 FROM #info1)
   BEGIN
     SELECT '<1> comparing SUM(Qty by StorerKey,Sku) of SKUxLOC AND SUM(Qty by StorerKey,Sku) IN LOTxLOCxID'
     SELECT * FROM #info1
   END
   DROP TABLE #info1
   DROP TABLE #temp_sum1
   DROP TABLE #temp_sum11

   --------------------------------------------------------------------------------------------------------

   SELECT Loc, Qty = SUM(CAST (Qty AS BIGINT) ) INTO #temp_sum2
   FROM SKUxLOC (NOLOCK)
   WHERE Qty > 0
   AND StorerKey = @c_StorerKey
   GROUP BY Loc

   SELECT Loc, Qty = SUM(CAST (Qty AS BIGINT) ) INTO #temp_sum21
   FROM LOTxLOCxID (NOLOCK)
   WHERE Qty > 0
   AND StorerKey = @c_StorerKey
   GROUP BY Loc

   SELECT a_loc = a.Loc, b_loc = b.Loc, sum_skuxloc = a.Qty, sum_lotxlocxid = b.Qty INTO #info2
   FROM #temp_sum2 a FULL OUTER JOIN #temp_sum21 b ON a.Loc = b.Loc
   WHERE a.Qty <> b.Qty
      OR a.Loc IS NULL OR b.Loc IS NULL

   IF EXISTS (SELECT 1 FROM #info2)
   BEGIN
      SELECT '<2> comparing SUM(Qty by Loc) of SKUxLOC AND SUM(Qty by Loc) IN LOTxLOCxID '
      SELECT * FROM #info2
   END

   DROP TABLE #info2
   DROP TABLE #temp_sum2
   DROP TABLE #temp_sum21

   --------------------------------------------------------------------------------------------------------
   
   SELECT Sku, StorerKey, Qty = SUM(CAST (Qty AS BIGINT) ) INTO #temp_sum3
   FROM Lot (NOLOCK)
   WHERE Qty > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey, Sku

   SELECT Sku, StorerKey, Qty = SUM(CAST (Qty AS BIGINT) ) INTO #temp_sum31
   FROM SKUxLOC (NOLOCK)
 WHERE Qty > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey,Sku

   SELECT a_storerkey = a.StorerKey, a_sku = a.Sku, b_storerkey = b.StorerKey, b_sku = b.Sku,
      sum_lot = a.Qty, sum_skuxloc = b.Qty INTO #info3
   FROM #temp_sum3 a FULL OUTER JOIN #temp_sum31 b ON a.Sku = b.Sku AND a.StorerKey = b.StorerKey
   WHERE a.Qty <> b.Qty
   OR a.Sku IS NULL OR b.Sku IS NULL OR a.StorerKey IS NULL OR b.StorerKey IS NULL

   IF EXISTS (SELECT 1 FROM #info3)
   BEGIN
      SELECT '<3> comparing SUM (Qty by StorerKey,Sku) of Lot AND SUM(Qty by StorerKey,Sku) IN SKUxLOC '
      SELECT * FROM #info3
   END

   DROP TABLE #info3
   DROP TABLE #temp_sum3
   DROP TABLE #temp_sum31

   --------------------------------------------------------------------------------------------------------
   
   SELECT Lot, Qty = SUM(CAST (Qty AS BIGINT) ) INTO #temp_sum4
   FROM LOTxLOCxID (NOLOCK)
   WHERE Qty > 0
   AND StorerKey = @c_StorerKey
   GROUP BY Lot

   SELECT a_lot = b.Lot, b_lot = a.Lot,  lot_qty =  b.Qty , sum_lotxlocxid = a.Qty INTO #info4
   FROM #temp_sum4 a FULL OUTER JOIN Lot b (NOLOCK) ON a.Lot = b.Lot
   WHERE b.Qty > 0 AND b.StorerKey = @c_StorerKey
   AND ( a.Qty <> b.Qty
   OR a.Lot IS NULL OR b.Lot IS NULL)

   IF EXISTS (SELECT 1 FROM #info4)
   BEGIN
      SELECT '<4> comparing Lot AND SUM(Qty by Lot) IN LOTxLOCxID '
      SELECT * FROM #info4
   END

   DROP TABLE #info4
   DROP TABLE #temp_sum4

   --------------------------------------------------------------------------------------------------------

   SELECT Lot, QtyAllocated = SUM(CAST(QtyAllocated AS BIGINT)) INTO #temp_sum6
   FROM LOTxLOCxID (NOLOCK)
   WHERE QtyAllocated > 0
   AND StorerKey = @c_StorerKey
   GROUP BY Lot

   SELECT a_lot = b.Lot, b_lot = a.Lot,  lot_QtyAllocated = b.QtyAllocated,  sum_lotxlocxid = a.QtyAllocated INTO #info6
   FROM #temp_sum6 a FULL OUTER JOIN Lot b (NOLOCK) ON a.Lot = b.Lot
   WHERE b.QtyAllocated > 0 AND b.StorerKey = @c_StorerKey
   AND (a.QtyAllocated <> b.QtyAllocated OR a.Lot IS NULL OR b.Lot IS NULL)

   IF EXISTS (SELECT 1 FROM #info6)
   BEGIN
      SELECT '<5> comparing Lot AND SUM(QtyAllocated by Lot) IN LOTxLOCxID '
      SELECT * FROM #info6
   END

   DROP TABLE #info6
   DROP TABLE #temp_sum6

   --------------------------------------------------------------------------------------------------------
   
   SELECT StorerKey, Sku, QtyAllocated = SUM(CAST(QtyAllocated AS BIGINT)) INTO #temp_sum7
   FROM Lot (NOLOCK)
   WHERE QtyAllocated > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey, Sku

   SELECT StorerKey, Sku, QtyAllocated = SUM(CAST(QtyAllocated AS BIGINT)) INTO #temp_sum71
   FROM SKUxLOC (NOLOCK)
   WHERE QtyAllocated > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey, Sku

   SELECT a_storerkey = a.StorerKey, a_sku = a.Sku, b_storerkey = b.StorerKey, b_sku = b.Sku,
      sum_lot = a.QtyAllocated,  sum_skuxloc = b.QtyAllocated INTO #info7
   FROM #temp_sum7 a FULL OUTER JOIN #temp_sum71 b ON a.StorerKey = b.StorerKey AND a.Sku = b.Sku
   WHERE a.QtyAllocated <> b.QtyAllocated
      OR a.StorerKey IS NULL OR b.StorerKey IS NULL
      OR a.Sku IS NULL OR b.Sku IS NULL

   IF EXISTS (SELECT 1 FROM #info7)
   BEGIN
      SELECT '<6> comparing Lot (QtyAllocated by StorerKey, Sku) AND SUM( QtyAllocated by StorerKey, Sku) SKUxLOC '
      SELECT * FROM #info7
   END

   DROP TABLE #info7
   DROP TABLE #temp_sum7
   DROP TABLE #temp_sum71

   --------------------------------------------------------------------------------------------------------

   SELECT StorerKey, Sku, QtyAllocated = SUM(CAST(QtyAllocated AS BIGINT)) INTO #temp_sum8
   FROM LOTxLOCxID (NOLOCK)
   WHERE QtyAllocated > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey, Sku

   SELECT StorerKey, Sku, QtyAllocated = SUM(CAST(QtyAllocated AS BIGINT)) INTO #temp_sum81
   FROM SKUxLOC (NOLOCK)
   WHERE QtyAllocated > 0
 AND StorerKey = @c_StorerKey
   GROUP BY StorerKey, Sku

   SELECT a_storerkey = a.StorerKey, a_sku = a.Sku, b_storerkey = b.StorerKey, b_sku = b.Sku,
   sum_lotxlocxid = a.QtyAllocated, sum_skuxloc = b.QtyAllocated  INTO #info8
   FROM #temp_sum8 a FULL OUTER JOIN #temp_sum81 b ON a.StorerKey = b.StorerKey AND a.Sku = b.Sku
   WHERE a.QtyAllocated <> b.QtyAllocated
      OR a.StorerKey IS NULL OR b.StorerKey IS NULL
      OR a.Sku IS NULL OR b.Sku IS NULL

   IF EXISTS (SELECT 1 FROM #info8)
   BEGIN
      SELECT '<7> comparing SUM( QtyAllocated by storer,Sku ) of LOTxLOCxID AND SUM( QtyAllocated by storer,Sku) SKUxLOC '
      SELECT * FROM #info8
   END

   DROP TABLE #info8
   DROP TABLE #temp_sum8
   DROP TABLE #temp_sum81

   --------------------------------------------------------------------------------------------------------
   
   SELECT Lot, QtyPicked = SUM(CAST(QtyPicked AS BIGINT)) INTO #temp_sum9
   FROM LOTxLOCxID (NOLOCK)
   WHERE QtyPicked > 0
   AND StorerKey = @c_StorerKey
   GROUP BY Lot

   SELECT a_lot = b.Lot, b_lot = a.Lot, sum_lot = b.QtyPicked ,  sum_lotxlocxid = a.QtyPicked  INTO #info9
   FROM #temp_sum9 a FULL OUTER JOIN Lot b (NOLOCK) ON a.Lot = b.Lot
   WHERE b.QtyPicked > 0
   AND StorerKey = @c_StorerKey
   AND (a.QtyPicked <> b.QtyPicked OR a.Lot IS NULL OR b.Lot IS NULL)

   IF EXISTS (SELECT 1 FROM #info9)
   BEGIN
      SELECT '<8> comparing Lot AND SUM(QtyPicked by Lot) IN LOTxLOCxID '
      SELECT * FROM #info9
   END

   DROP TABLE #info9
   DROP TABLE #temp_sum9

   --------------------------------------------------------------------------------------------------------
   
   SELECT StorerKey, Sku, QtyPicked = SUM(CAST(QtyPicked AS BIGINT)) INTO #temp_sum10
   FROM LOTxLOCxID (NOLOCK)
   WHERE QtyPicked > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey, Sku

   SELECT StorerKey, Sku, Qtypicked = SUM(CAST(QtyPicked AS BIGINT)) INTO #temp_sum101
   FROM SKUxLOC (NOLOCK)
   WHERE QtyPicked > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey, Sku

   SELECT a_storerkey = a.StorerKey, a_sku = a.Sku, b_storerkey = b.StorerKey, b_sku = b.Sku,
     sum_lotxlocxid = a.QtyPicked , sum_skuxloc = b.QtyPicked  INTO #info10
   FROM #temp_sum10 a FULL OUTER JOIN #temp_sum101 b ON a.StorerKey = b.StorerKey AND a.Sku = b.Sku
   WHERE a.QtyPicked <> b.QtyPicked
      OR a.StorerKey IS NULL OR b.StorerKey IS NULL OR a.Sku IS NULL OR b.Sku IS NULL

   IF EXISTS (SELECT 1 FROM #info10)
   BEGIN
      SELECT '<9> comparing SUM( QtyPicked by StorerKey, Sku ) LOTxLOCxID AND SUM( QtyPicked by StorerKey, Sku ) SKUxLOC '
      SELECT * FROM #info10
   END

   DROP TABLE #info10
   DROP TABLE #temp_sum10
   DROP TABLE #temp_sum101

   --------------------------------------------------------------------------------------------------------
   
   SELECT StorerKey, Sku, QtyAllocated = SUM(CAST(Qty AS BIGINT)) INTO #temp_sum12
   FROM PickDetail (NOLOCK)
   WHERE Status IN ('0', '1', '2', '3', '4') AND Qty > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey, Sku

   SELECT StorerKey, Sku, QtyAllocated = SUM(CAST(QtyAllocated AS BIGINT)) INTO #temp_sum121
   FROM LOTxLOCxID (NOLOCK)
   WHERE QtyAllocated > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey, Sku

   SELECT a_storerkey = a.StorerKey, a_sku = a.Sku, b_storerkey = b.StorerKey, b_sku = b.Sku,
     sum_pickdetail = a.QtyAllocated, sum_lotxlocxid = b.QtyAllocated INTO #info12
   FROM #temp_sum12 a FULL OUTER JOIN #temp_sum121 b ON a.StorerKey = b.StorerKey AND a.Sku = b.Sku
   WHERE a.QtyAllocated <> b.QtyAllocated
      OR a.StorerKey IS NULL OR b.StorerKey IS NULL OR a.Sku IS NULL OR b.Sku IS NULL

   IF EXISTS (SELECT 1 FROM #info12)
   BEGIN
      SELECT '<10> comparing  SUM(Qty by storer,Sku) of PickDetail (Status = 0..4) AND SUM(QtyAllocated by storer,Sku) of LOTxLOCxID '
      SELECT * FROM #info12
   END

   DROP TABLE #info12
   DROP TABLE #temp_sum12
   DROP TABLE #temp_sum121

   --------------------------------------------------------------------------------------------------------
   
   SELECT StorerKey, Sku, QtyAllocated = SUM(CAST(Qty AS BIGINT)) INTO #temp_sum13
   FROM PickDetail (NOLOCK)
   WHERE Status IN ('0', '1', '2', '3', '4') AND Qty > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey, Sku

   SELECT StorerKey, Sku, QtyAllocated = SUM(CAST(QtyAllocated AS BIGINT)) INTO #temp_sum131
   FROM SKUxLOC (NOLOCK)
   WHERE QtyAllocated > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey, Sku

   SELECT a_storerkey = a.StorerKey, a_sku = a.Sku, b_storerkey = b.StorerKey, b_sku = b.Sku,
     sum_pickdetail = a.QtyAllocated, sum_skuxloc = b.QtyAllocated  INTO #info13
   FROM #temp_sum13 a FULL OUTER JOIN #temp_sum131 b ON a.StorerKey = b.StorerKey AND a.Sku = b.Sku
   WHERE a.QtyAllocated <> b.QtyAllocated
      OR a.StorerKey IS NULL OR b.StorerKey IS NULL OR a.Sku IS NULL OR b.Sku IS NULL

   IF EXISTS (SELECT 1 FROM #info13)
   BEGIN
      SELECT '<11> comparing  SUM(Qty by storer,Sku) of PickDetail (Status = 0..4) AND SUM(QtyAllocated by storer,Sku) of SKUxLOC '
      SELECT * FROM #info13
   END

   DROP TABLE #info13
   DROP TABLE #temp_sum13
   DROP TABLE #temp_sum131

   --------------------------------------------------------------------------------------------------------
   
   SELECT StorerKey, Sku, QtyAllocated = SUM(CAST(Qty AS BIGINT)) INTO #temp_sum14
   FROM PickDetail (NOLOCK)
   WHERE Status IN ('0', '1', '2', '3', '4') AND Qty > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey, Sku

   SELECT StorerKey, Sku, QtyAllocated = SUM(CAST(QtyAllocated AS BIGINT)) INTO #temp_sum141
   FROM Lot (NOLOCK)
   WHERE QtyAllocated > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey, Sku

   SELECT a_storerkey = a.StorerKey, a_sku = a.Sku, b_storerkey = b.StorerKey, b_sku = b.Sku,
     sum_pickdetial =  a.QtyAllocated ,sum_lot = b.QtyAllocated INTO #info14
   FROM #temp_sum14 a FULL OUTER JOIN #temp_sum141 b ON a.StorerKey = b.StorerKey AND a.Sku = b.Sku
   WHERE a.QtyAllocated <> b.QtyAllocated
      OR a.StorerKey IS NULL OR b.StorerKey IS NULL OR a.Sku IS NULL OR b.Sku IS NULL

   IF EXISTS (SELECT 1 FROM #info14)
   BEGIN
      SELECT '<12> comparing  SUM(Qty by storer,Sku) of PickDetail (Status = 0..4) AND SUM(QtyAllocated by storer,Sku) of Lot '
      SELECT * FROM #info14
   END

   DROP TABLE #info14
   DROP TABLE #temp_sum14
   DROP TABLE #temp_sum141

   --------------------------------------------------------------------------------------------------------
   
   SELECT StorerKey, Sku, QtyPicked = SUM(CAST(Qty AS BIGINT)) INTO #temp_sum15
   FROM PickDetail (NOLOCK)
   WHERE Status IN ('5', '6', '7', '8') AND Qty > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey, Sku

   SELECT StorerKey, Sku, QtyPicked = SUM(CAST(QtyPicked AS BIGINT)) INTO #temp_sum151
   FROM LOTxLOCxID (NOLOCK)
   WHERE QtyPicked > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey, Sku

   SELECT a_storerkey = a.StorerKey, a_sku = a.Sku, b_storerkey = b.StorerKey, b_sku = b.Sku,
     sum_pickdetail = a.QtyPicked, sum_lotxlocxid = b.QtyPicked  INTO #info15
   FROM #temp_sum15 a FULL OUTER JOIN #temp_sum151 b ON a.StorerKey = b.StorerKey AND a.Sku = b.Sku
   WHERE a.QtyPicked <> b.QtyPicked
      OR a.StorerKey IS NULL OR b.StorerKey IS NULL OR a.Sku IS NULL OR b.Sku IS NULL

   IF EXISTS (SELECT 1 FROM #info15)
   BEGIN
      SELECT '<13> comparing  SUM(Qty by storer,Sku) of PickDetail (Status = 5..8) AND SUM(QtyPicked by storer,Sku) of LOTxLOCxID '
      SELECT * FROM #info15
   END

   DROP TABLE #info15
   DROP TABLE #temp_sum15
   DROP TABLE #temp_sum151

   --------------------------------------------------------------------------------------------------------

   SELECT StorerKey, Sku, QtyPicked = SUM(CAST(Qty AS BIGINT)) INTO #temp_sum16
   FROM PickDetail (NOLOCK)
   WHERE Status IN ('5', '6', '7', '8') AND Qty > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey, Sku

   SELECT StorerKey, Sku, QtyPicked = SUM(CAST(QtyPicked AS BIGINT)) INTO #temp_sum161
   FROM SKUxLOC (NOLOCK)
   WHERE QtyPicked > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey, Sku

   SELECT a_storerkey = a.StorerKey, a_sku = a.Sku, b_storerkey = b.StorerKey, b_sku = b.Sku,
     sum_pickdetail_picked = a.QtyPicked,  sum_skuxloc = b.QtyPicked INTO #info16
   FROM #temp_sum16 a FULL OUTER JOIN #temp_sum161 b ON a.StorerKey = b.StorerKey AND a.Sku = b.Sku
   WHERE a.QtyPicked <> b.QtyPicked
      OR a.StorerKey IS NULL OR b.StorerKey IS NULL OR a.Sku IS NULL OR b.Sku IS NULL

   IF EXISTS (SELECT 1 FROM #info16)
   BEGIN
      SELECT '<14> comparing  SUM(Qty by storer,Sku) of PickDetail (Status = 5..8) AND SUM(QtyPicked by storer,Sku) of SKUxLOC '
      SELECT * FROM #info16
   END
   DROP TABLE #info16
   DROP TABLE #temp_sum16
   DROP TABLE #temp_sum161

   --------------------------------------------------------------------------------------------------------

   SELECT StorerKey, Sku, QtyPicked = SUM(CAST(Qty AS BIGINT)) INTO #temp_sum17
   FROM PickDetail (NOLOCK)
   WHERE Status IN ('5', '6', '7', '8') AND Qty > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey, Sku

   SELECT StorerKey, Sku, QtyPicked = SUM(CAST(QtyPicked AS BIGINT)) INTO #temp_sum171
   FROM Lot (NOLOCK)
   WHERE QtyPicked > 0
   AND StorerKey = @c_StorerKey
   GROUP BY StorerKey, Sku

   SELECT a_storerkey = a.StorerKey, a_sku = a.Sku, b_storerkey = b.StorerKey, b_sku = b.Sku,
     sum_pickdetail_picked = a.QtyPicked, sum_lot = b.QtyPicked  INTO #info17
   FROM #temp_sum17 a FULL OUTER JOIN #temp_sum171 b ON a.StorerKey = b.StorerKey AND a.Sku = b.Sku
   WHERE a.QtyPicked <> b.QtyPicked
      OR a.StorerKey IS NULL OR b.StorerKey IS NULL OR a.Sku IS NULL OR b.Sku IS NULL

   IF EXISTS (SELECT 1 FROM #info17)
   BEGIN
      SELECT '<15> comparing  SUM(Qty by storer,Sku) of PickDetail (Status = 5..8) AND SUM(QtyPicked by storer,Sku) of Lot '
      SELECT * FROM #info17
   END

   DROP TABLE #info17
   DROP TABLE #temp_sum17
   DROP TABLE #temp_sum171

   --------------------------------------------------------------------------------------------------------

   SELECT Orderkey, QtyAllocated = SUM(CAST(Qty AS BIGINT)) INTO #temp_sum18
   FROM PickDetail (NOLOCK)
   WHERE Status IN ('0', '1', '2', '3', '4') AND Qty > 0
   AND StorerKey = @c_StorerKey
   GROUP BY orderkey

   SELECT Orderkey, QtyAllocated = SUM(CAST(QtyAllocated AS BIGINT)) INTO #temp_sum181
   FROM orderdetail (NOLOCK)
   WHERE QtyAllocated > 0
   AND StorerKey = @c_StorerKey
   GROUP BY orderkey

   SELECT a_orderkey = a.orderkey, b_orderkey = b.orderkey,
      sum_pickdetail_allocated = a.Qtyallocated , sum_orderdetail = b.Qtyallocated INTO #info18
   FROM #temp_sum18 a FULL OUTER JOIN #temp_sum181 b ON a.orderkey = b.orderkey
   WHERE a.Qtyallocated <> b.Qtyallocated
      OR a.orderkey IS NULL OR b.orderkey IS NULL

   IF EXISTS (SELECT 1 FROM #info18)
   BEGIN
      SELECT '<16> comparing SUM(Qty by orderkey) IN PickDetail (Status = 0..4) with SUM(qtyallocated by orderkey) IN orderdetail'
      SELECT * FROM #info18
   END
   DROP TABLE #info18
   DROP TABLE #temp_sum18
   DROP TABLE #temp_sum181

   --------------------------------------------------------------------------------------------------------

   SELECT Orderkey, qtypicked = SUM(CAST(Qty AS BIGINT)) INTO #temp_sum19
   FROM PickDetail (NOLOCK)
   WHERE Status IN ('5', '6', '7', '8') AND Qty > 0
   AND StorerKey = @c_StorerKey
   GROUP BY orderkey

   SELECT orderkey, qtypicked = SUM(CAST(qtypicked AS BIGINT)) INTO #temp_sum191
   FROM orderdetail (NOLOCK)
   WHERE QtyPicked > 0
   AND StorerKey = @c_StorerKey
   GROUP BY orderkey

   SELECT a_orderkey = a.orderkey,  b_orderkey = b.orderkey,
     sum_pickdetail_picked = a.qtypicked, sum_orderdetail = b.qtypicked  INTO #info19
   FROM #temp_sum19 a FULL OUTER JOIN #temp_sum191 b ON a.orderkey = b.orderkey
   WHERE a.qtypicked <> b.qtypicked
      OR a.orderkey IS NULL OR b.orderkey IS NULL

   IF EXISTS (SELECT 1 FROM #info19)
   BEGIN
      SELECT '<17> comparing SUM(Qty by orderkey) IN PickDetail (Status = 5..8) with SUM(qtypicked by orderkey) IN orderdetail'
      SELECT * FROM #info19
   END
   DROP TABLE #info19
   DROP TABLE #temp_sum19
   DROP TABLE #temp_sum191

   --------------------------------------------------------------------------------------------------------

   SELECT Orderkey, QtyShipped = SUM(CAST(Qty AS BIGINT)) INTO #temp_sum20
   FROM PickDetail (NOLOCK)
   WHERE Status ='9' AND Qty > 0
   AND StorerKey = @c_StorerKey
   GROUP BY orderkey

   SELECT  Orderkey, QtyShipped = SUM(CAST(ShippedQty AS BIGINT)) INTO #temp_sum201
   FROM orderdetail (NOLOCK)
   WHERE ShippedQty > 0
   AND StorerKey = @c_StorerKey
   GROUP BY orderkey

   SELECT a_orderkey = a.orderkey, b_orderkey = b.orderkey,
      sum_pickdetail_shipped = a.qtyShipped, sum_orderdetail = b.qtyShipped INTO #info20
   FROM #temp_sum20 a FULL OUTER JOIN #temp_sum201 b ON a.orderkey = b.orderkey
   WHERE a.QtyShipped <> b.QtyShipped
      OR a.orderkey IS NULL OR b.orderkey IS NULL

   IF EXISTS (SELECT 1 FROM #info20)
   BEGIN
      SELECT '<20> comparing SUM(Qty by orderkey) IN PickDetail (Status = 9) with SUM(qtyshipped by orderkey) IN orderdetail'
      SELECT * FROM #info20
   END

   DROP TABLE #info20
   DROP TABLE #temp_sum20
   DROP TABLE #temp_sum201

   --------------------------------------------------------------------------------------------------------

   SELECT Orderkey, QtyPreAllocated = SUM(CAST(Qty AS BIGINT)) INTO #temp_sum212
   FROM preallocatepickdetail (NOLOCK)
   WHERE Qty > 0
   AND StorerKey = @c_StorerKey
   GROUP BY orderkey

   SELECT orderkey, QtyPreAllocated = SUM(CAST(QtyPreAllocated AS BIGINT)) INTO #temp_sum211
   FROM orderdetail (NOLOCK)
   WHERE QtyPreAllocated > 0
   AND StorerKey = @c_StorerKey
   GROUP BY orderkey

   SELECT a_orderkey = a.orderkey, b_orderkey = b.orderkey,
     sum_preallocatepickdetail = a.QtyPreAllocated, sum_orderdetail = b.QtyPreAllocated  INTO #info21
   FROM #temp_sum212 a FULL OUTER JOIN #temp_sum211 b ON a.orderkey = b.orderkey
   WHERE a.QtyPreAllocated <> b.QtyPreAllocated
      OR a.orderkey IS NULL OR b.orderkey IS NULL

   IF EXISTS (SELECT 1 FROM #info21)
   BEGIN
      SELECT '<18> comparing SUM(QtyPreAllocated by orderkey) IN preallocatepickdetail with SUM(QtyPreAllocated by orderkey) IN orderdetail'
      SELECT * FROM #info21
   END

   DROP TABLE #info21
   DROP TABLE #temp_sum212
   DROP TABLE #temp_sum211

   --------------------------------------------------------------------------------------------------------

   SELECT Lot, QtyPreAllocated = SUM(CAST(Qty AS BIGINT)) INTO #temp_sum22
   FROM preallocatepickdetail (NOLOCK)
   WHERE Qty > 0
   AND StorerKey = @c_StorerKey
   GROUP BY Lot

   SELECT Lot, QtyPreAllocated INTO #temp_sum221
   FROM Lot (NOLOCK)
   WHERE QtyPreAllocated > 0
   AND StorerKey = @c_StorerKey

   SELECT PreallocatePickDetail_Lot = a.Lot, LOT_Lot = b.Lot,
     lot_qtypreallocated = b.QtyPreAllocated, sum_preallocatepickdetail = a.QtyPreAllocated INTO #info22
   FROM #temp_sum22 a FULL OUTER JOIN #temp_sum221 b ON a.Lot = b.Lot
   WHERE a.QtyPreAllocated <> b.QtyPreAllocated
    OR a.Lot IS NULL OR b.Lot IS NULL

   IF EXISTS (SELECT 1 FROM #info22)
   BEGIN
      SELECT '<19> comparing Lot AND SUM(QtyPreAllocated by Lot) IN PreallocatePickdetail'
      SELECT * FROM #info22
   END

   DROP TABLE #info22
   DROP TABLE #temp_sum22
   DROP TABLE #temp_sum221

END

GO