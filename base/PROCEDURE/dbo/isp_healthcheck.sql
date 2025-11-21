SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/
/* Store procedure: isp_HealthCheck                                          */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: Backend Task to check Table Integrity                            */
/*          Called By SQL Scheduler                                          */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2010-06-15 1.1  TLTING   CAST Quantity Sum  (tlting01            )        */
/* 2010-08-17 1.1  Shong    DO NOT Check Archive..ITRN IF Not Exists         */
/*                          (Shong01)                                        */
/*                                                                           */
/*****************************************************************************/


CREATE PROC [dbo].[isp_HealthCheck]
as 
begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

	print '************************************************'
	print ' '
	select 'Database'= convert(char(20), db_name()), 'Current date' = getdate()
	print '************************************************'
	print '************************************************'
	
	select sku, storerkey, qty = sum(Cast (qty as BigInt) ) into #temp_sum1
	from skuxloc (nolock)
	where qty > 0
	group by storerkey,sku
	
	select sku, storerkey, qty = sum(Cast (qty as BigInt) ) into #temp_sum11
	from lotxlocxid (nolock)
	where qty > 0
	group by storerkey,sku
	
	select a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,
		sum_skuxloc =a.qty, sum_lotxlocxid = b.qty into #info1
	from #temp_sum1 a FULL OUTER JOIN #temp_sum11 b on a.sku = b.sku and a.storerkey = b.storerkey
	where  a.qty <> b.qty
	   or a.sku is null or b.sku is null 
	   or a.storerkey is null or b.storerkey is null
	
	if exists (select 1 from #info1)
   begin 
     select '<1> comparing sum(Qty by Storerkey,Sku) of SKUxLOC and sum(Qty by Storerkey,Sku) in LOTxLOCxID '
	  select * from #info1
   end 
	drop table #info1
	drop table #temp_sum1
	drop table #temp_sum11
	
	
	select loc, qty = sum(Cast (qty as BigInt) ) into #temp_sum2 
	from skuxloc (nolock)
	where qty > 0
	group by loc
	
	select loc, qty = sum(Cast (qty as BigInt) ) into #temp_sum21 
	from lotxlocxid (nolock)
	where qty > 0
	group by loc
	
	select a_loc = a.loc, b_loc = b.loc, sum_skuxloc = a.qty, sum_lotxlocxid = b.qty into #info2
	from #temp_sum2 a FULL OUTER JOIN #temp_sum21 b ON a.loc = b.loc
	where a.qty <> b.qty
	   or a.loc is null or b.loc is null
	
	if exists (select 1 from #info2)
   begin
	   select '<2> comparing sum(Qty by Loc) of SKUxLOC and sum(Qty by Loc) in LOTxLOCxID '
	   select * from #info2
   end

	drop table #info2
	drop table #temp_sum2
	drop table #temp_sum21
	
	
	
	
	select sku, storerkey, qty = sum(Cast (qty as BigInt) ) into #temp_sum3 
	from lot (nolock)
	where qty > 0
	group by storerkey, sku
	
	select sku, storerkey, qty = sum(Cast (qty as BigInt) ) into #temp_sum31 
	from skuxloc (nolock)
	where qty > 0
	group by storerkey,sku
	
	select a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,  
		sum_lot = a.qty, sum_skuxloc = b.qty into #info3
	from #temp_sum3 a FULL OUTER JOIN #temp_sum31 b ON a.sku = b.sku and a.storerkey = b.storerkey
	where a.qty <> b.qty
	or a.sku is null or b.sku is null or a.storerkey is null or b.storerkey is null
	
	if exists (select 1 from #info3)
   begin
      select '<3> comparing sum (Qty by Storerkey,Sku) of LOT and sum(Qty by Storerkey,Sku) in SKUxLOC '
		select * from #info3
   end

	drop table #info3
	drop table #temp_sum3
	drop table #temp_sum31


	-- '<4> comparing LOT and sum(Qty by Lot) in LOTxLOCxID '
	
	select lot, qty = sum(Cast (qty as BigInt) ) into #temp_sum4 
	from lotxlocxid (nolock)
	where qty > 0
	group by lot
	
	select a_lot = b.lot, b_lot = a.lot,  lot_qty =  b.qty , sum_lotxlocxid = a.qty into #info4
	from #temp_sum4 a FULL OUTER JOIN lot b (nolock) ON a.lot = b.lot
	where b.qty > 0 and ( a.qty <> b.qty
	  or a.lot is null or b.lot is null)
	
	if exists (select 1 from #info4)
   begin
      select '<4> comparing LOT and sum(Qty by Lot) in LOTxLOCxID '
		select * from #info4
   end

	drop table #info4
	drop table #temp_sum4
	
	
-- 	select '<5> comparing id (qty) and sum(qty by id) lotxlocxid '
-- 	
-- 	select id, qty = sum(qty) into #temp_sum5 
-- 	from lotxlocxid (nolock)
-- 	where qty > 0
-- 	group by id
-- 	
-- 	select a_id = b.id, b_id = a.id, id_qty = b.qty,  sum_lotxlocxid = a.qty into #info5
-- 	from #temp_sum5 a FULL OUTER JOIN id b (nolock) ON a.id = b.id
-- 	where b.qty > 0 and (a.qty <> b.qty or a.id is null or b.id is null)
-- 	
-- 	if exists (select 1 from #info5)
-- 		select * from #info5
-- 	drop table #info5
-- 	drop table #temp_sum5
	
	
	-- '<6> comparing lot and sum(QtyAllocated by lot) in lotxlocxid '
	
	select lot, QtyAllocated = sum(CAST(QtyAllocated as BigInt)) into #temp_sum6 
	from lotxlocxid (nolock)
	where QtyAllocated > 0
	group by lot
	
	select a_lot = b.lot, b_lot = a.lot,  lot_QtyAllocated = b.QtyAllocated,  sum_lotxlocxid = a.QtyAllocated into #info6
	from #temp_sum6 a FULL OUTER JOIN lot b (nolock) ON a.lot = b.lot
	where b.QtyAllocated > 0 and (a.QtyAllocated <> b.QtyAllocated or a.lot is null or b.lot is null)
	
	if exists (select 1 from #info6)
   begin
      select '<6> comparing lot and sum(QtyAllocated by lot) in lotxlocxid '
		select * from #info6
   end

	drop table #info6
	drop table #temp_sum6
	
	
	-- '<7> comparing lot (QtyAllocated by storerkey, sku) and sum( QtyAllocated by storerkey, sku) skuxloc '
	
	select storerkey, sku, QtyAllocated = sum(CAST(QtyAllocated as BigInt)) into #temp_sum7 
	from lot (nolock)
	where QtyAllocated > 0
	group by storerkey, sku
	
	select storerkey, sku, QtyAllocated = sum(CAST(QtyAllocated as BigInt)) into #temp_sum71 
	from skuxloc (nolock)
	where QtyAllocated > 0
	group by storerkey, sku
	
	select a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,  
	   sum_lot = a.QtyAllocated,  sum_skuxloc = b.QtyAllocated into #info7
	from #temp_sum7 a FULL OUTER JOIN #temp_sum71 b ON a.storerkey = b.storerkey and a.sku = b.sku
	where a.QtyAllocated <> b.QtyAllocated
	   or a.storerkey is null or b.storerkey is null
	   or a.sku is null or b.sku is null
	
	if exists (select 1 from #info7)
   begin
      select '<7> comparing lot (QtyAllocated by storerkey, sku) and sum( QtyAllocated by storerkey, sku) skuxloc '
		select * from #info7
   end

	drop table #info7
	drop table #temp_sum7
	drop table #temp_sum71
	
	
	-- '<8> comparing sum( QtyAllocated by storer,sku ) of lotxlocxid and sum( QtyAllocated by storer,sku) skuxloc '
	
	select storerkey, sku, QtyAllocated = sum(CAST(QtyAllocated as BigInt)) into #temp_sum8 
	from lotxlocxid (nolock)
	where QtyAllocated > 0
	group by storerkey, sku
	
	select storerkey, sku, QtyAllocated = sum(CAST(QtyAllocated as BigInt)) into #temp_sum81 
	from skuxloc (nolock)
	where QtyAllocated > 0
	group by storerkey, sku
	
	select a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,  
	sum_lotxlocxid = a.QtyAllocated, sum_skuxloc = b.QtyAllocated  into #info8
	from #temp_sum8 a FULL OUTER JOIN #temp_sum81 b ON a.storerkey = b.storerkey and a.sku = b.sku
	where a.QtyAllocated <> b.QtyAllocated
	   or a.storerkey is null or b.storerkey is null
	   or a.sku is null or b.sku is null
	
	if exists (select 1 from #info8)
   begin
      select '<8> comparing sum( QtyAllocated by storer,sku ) of lotxlocxid and sum( QtyAllocated by storer,sku) skuxloc '
		select * from #info8
   end

	drop table #info8
	drop table #temp_sum8
	drop table #temp_sum81
	
	
	-- '<9> comparing lot and sum(QtyPicked by lot) in lotxlocxid '
	
	select lot, QtyPicked = sum(CAST(QtyPicked as BigInt)) into #temp_sum9 
	from lotxlocxid (nolock)
	where QtyPicked > 0
	group by lot
	
	select a_lot = b.lot, b_lot = a.lot, sum_lot = b.QtyPicked ,  sum_lotxlocxid = a.QtyPicked  into #info9
	from #temp_sum9 a FULL OUTER JOIN lot b (nolock) ON a.lot = b.lot
	where b.QtyPicked > 0 
	  and (a.QtyPicked <> b.QtyPicked or a.lot is null or b.lot is null)
	
	if exists (select 1 from #info9)
   begin
      select '<9> comparing lot and sum(QtyPicked by lot) in lotxlocxid '
		select * from #info9
   end

	drop table #info9
	drop table #temp_sum9
	
	
	-- '<10> comparing sum( QtyPicked by storerkey, sku ) lotxlocxid and sum( QtyPicked by storerkey, sku ) skuxloc '
	
	select storerkey, sku, QtyPicked = sum(CAST(QtyPicked as BigInt)) into #temp_sum10 
	from lotxlocxid (nolock)
	where QtyPicked > 0
	group by storerkey, sku
	
	select storerkey, sku, Qtypicked = sum(CAST(QtyPicked as BigInt)) into #temp_sum101 
	from skuxloc (nolock)
	where QtyPicked > 0
	group by storerkey, sku
	
	select a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku, 
	  sum_lotxlocxid = a.QtyPicked , sum_skuxloc = b.QtyPicked  into #info10
	from #temp_sum10 a FULL OUTER JOIN #temp_sum101 b ON a.storerkey = b.storerkey and a.sku = b.sku
	where a.QtyPicked <> b.QtyPicked
	   or a.storerkey is null or b.storerkey is null or a.sku is null or b.sku is null
	
	if exists (select 1 from #info10)
   begin
      select '<10> comparing sum( QtyPicked by storerkey, sku ) lotxlocxid and sum( QtyPicked by storerkey, sku ) skuxloc '
		select * from #info10
   end

	drop table #info10
	drop table #temp_sum10
	drop table #temp_sum101
	
	
	-- '<12> comparing  sum(Qty by storer,sku) of pickdetail (status = 0..4) and sum(QtyAllocated by storer,sku) of lotxlocxid '
	
	select storerkey, sku, QtyAllocated = sum(CAST(Qty As BigInt)) into #temp_sum12 
	from pickdetail (nolock)
	where status in ('0', '1', '2', '3', '4') and qty > 0
	group by storerkey, sku
	
	select storerkey, sku, QtyAllocated = sum(CAST(QtyAllocated as BigInt)) into #temp_sum121 
	from lotxlocxid (nolock)
	where QtyAllocated > 0
	group by storerkey, sku
	
	select a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,
	  sum_pickdetail = a.QtyAllocated, sum_lotxlocxid = b.QtyAllocated into #info12
	from #temp_sum12 a FULL OUTER JOIN #temp_sum121 b ON a.storerkey = b.storerkey and a.sku = b.sku
	where a.QtyAllocated <> b.QtyAllocated
	   or a.storerkey is null or b.storerkey is null or a.sku is null or b.sku is null
	
	if exists (select 1 from #info12)
   begin
      select '<12> comparing  sum(Qty by storer,sku) of pickdetail (status = 0..4) and sum(QtyAllocated by storer,sku) of lotxlocxid '
		select * from #info12
   end

	drop table #info12
	drop table #temp_sum12
	drop table #temp_sum121
	
	
	-- '<13> comparing  sum(Qty by storer,sku) of pickdetail (status = 0..4) and sum(QtyAllocated by storer,sku) of skuxloc '
	
	select storerkey, sku, QtyAllocated = sum(CAST(Qty As BigInt)) into #temp_sum13 
	from pickdetail (nolock)
	where status in ('0', '1', '2', '3', '4') and qty > 0
	group by storerkey, sku
	
	select storerkey, sku, QtyAllocated = sum(CAST(QtyAllocated as BigInt)) into #temp_sum131 
	from skuxloc (nolock)
	where QtyAllocated > 0
	group by storerkey, sku
	
	select a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,
	  sum_pickdetail = a.QtyAllocated, sum_skuxloc = b.QtyAllocated  into #info13
	from #temp_sum13 a FULL OUTER JOIN #temp_sum131 b ON a.storerkey = b.storerkey and a.sku = b.sku
	where a.QtyAllocated <> b.QtyAllocated
	   or a.storerkey is null or b.storerkey is null or a.sku is null or b.sku is null
	
	if exists (select 1 from #info13)
   begin
      select '<13> comparing  sum(Qty by storer,sku) of pickdetail (status = 0..4) and sum(QtyAllocated by storer,sku) of skuxloc '
		select * from #info13
   end

	drop table #info13
	drop table #temp_sum13
	drop table #temp_sum131
	
	
	-- '<14> comparing  sum(Qty by storer,sku) of pickdetail (status = 0..4) and sum(QtyAllocated by storer,sku) of lot '
	
	select storerkey, sku, QtyAllocated = sum(CAST(Qty As BigInt)) into #temp_sum14 
	from pickdetail (nolock)
	where status in ('0', '1', '2', '3', '4') and qty > 0
	group by storerkey, sku
	
	select storerkey, sku, QtyAllocated = sum(CAST(QtyAllocated as BigInt)) into #temp_sum141 
	from lot (nolock)
	where QtyAllocated > 0
	group by storerkey, sku
	
	select a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,
	  sum_pickdetial =  a.QtyAllocated ,sum_lot = b.QtyAllocated into #info14
	from #temp_sum14 a FULL OUTER JOIN #temp_sum141 b ON a.storerkey = b.storerkey and a.sku = b.sku
	where a.QtyAllocated <> b.QtyAllocated
	   or a.storerkey is null or b.storerkey is null or a.sku is null or b.sku is null
	
	if exists (select 1 from #info14)
   begin
      select '<14> comparing  sum(Qty by storer,sku) of pickdetail (status = 0..4) and sum(QtyAllocated by storer,sku) of lot '
		select * from #info14
   end

	drop table #info14
	drop table #temp_sum14
	drop table #temp_sum141
	
	
	-- '<15> comparing  sum(Qty by storer,sku) of pickdetail (status = 5..8) and sum(QtyPicked by storer,sku) of lotxlocxid '
	
	select storerkey, sku, QtyPicked = sum(CAST(Qty As BigInt)) into #temp_sum15 
	from pickdetail (nolock)
	where status in ('5', '6', '7', '8') and qty > 0
	group by storerkey, sku
	
	select storerkey, sku, QtyPicked = sum(CAST(QtyPicked as BigInt)) into #temp_sum151 
	from lotxlocxid (nolock)
	where QtyPicked > 0
	group by storerkey, sku
	
	select a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,
	  sum_pickdetail = a.QtyPicked, sum_lotxlocxid = b.QtyPicked  into #info15
	from #temp_sum15 a FULL OUTER JOIN #temp_sum151 b ON a.storerkey = b.storerkey and a.sku = b.sku
	where a.QtyPicked <> b.QtyPicked
	   or a.storerkey is null or b.storerkey is null or a.sku is null or b.sku is null
	
	if exists (select 1 from #info15)
   begin
      select '<15> comparing  sum(Qty by storer,sku) of pickdetail (status = 5..8) and sum(QtyPicked by storer,sku) of lotxlocxid '
		select * from #info15
   end

	drop table #info15
	drop table #temp_sum15
	drop table #temp_sum151
	
	
	-- select '<16> comparing  sum(Qty by storer,sku) of pickdetail (status = 5..8) and sum(QtyPicked by storer,sku) of skuxloc '
	
	select storerkey, sku, QtyPicked = sum(CAST(Qty As BigInt)) into #temp_sum16 
	from pickdetail (nolock)
	where status in ('5', '6', '7', '8') and qty > 0
	group by storerkey, sku
	
	select storerkey, sku, QtyPicked = sum(CAST(QtyPicked As BigInt)) into #temp_sum161 
	from skuxloc (nolock)
	where QtyPicked > 0
	group by storerkey, sku
	
	select a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,
	  sum_pickdetail_picked = a.QtyPicked,  sum_skuxloc = b.QtyPicked into #info16
	from #temp_sum16 a FULL OUTER JOIN #temp_sum161 b ON a.storerkey = b.storerkey and a.sku = b.sku
	where a.QtyPicked <> b.QtyPicked
	   or a.storerkey is null or b.storerkey is null or a.sku is null or b.sku is null
	
	if exists (select 1 from #info16)
   begin
      select '<16> comparing  sum(Qty by storer,sku) of pickdetail (status = 5..8) and sum(QtyPicked by storer,sku) of skuxloc '
		select * from #info16
   end 
	drop table #info16
	drop table #temp_sum16
	drop table #temp_sum161
	
	
	-- '<17> comparing  sum(Qty by storer,sku) of pickdetail (status = 5..8) and sum(QtyPicked by storer,sku) of lot '
	
	select storerkey, sku, QtyPicked = sum(CAST(Qty As BigInt)) into #temp_sum17 
	from pickdetail (nolock)
	where status in ('5', '6', '7', '8') and Qty > 0
	group by storerkey, sku
	
	select storerkey, sku, QtyPicked = sum(CAST(QtyPicked as BigInt)) into #temp_sum171 
	from lot (nolock)
	where QtyPicked > 0
	group by storerkey, sku
	
	select a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,
	  sum_pickdetail_picked = a.QtyPicked, sum_lot = b.QtyPicked  into #info17
	from #temp_sum17 a FULL OUTER JOIN #temp_sum171 b ON a.storerkey = b.storerkey and a.sku = b.sku
	where a.QtyPicked <> b.QtyPicked
	   or a.storerkey is null or b.storerkey is null or a.sku is null or b.sku is null
	
	if exists (select 1 from #info17)
   begin
      select '<17> comparing  sum(Qty by storer,sku) of pickdetail (status = 5..8) and sum(QtyPicked by storer,sku) of lot '
		select * from #info17
   end

	drop table #info17
	drop table #temp_sum17
	drop table #temp_sum171
	
	
	-- '<18> comparing sum(qty by orderkey) in pickdetail (status = 0..4) with sum(qtyallocated by orderkey) in orderdetail'
	
	select Orderkey, QtyAllocated = sum(CAST(Qty As BigInt)) into #temp_sum18 
	from pickdetail (nolock)
	where status in ('0', '1', '2', '3', '4') and Qty > 0
	group by orderkey
	
	select Orderkey, QtyAllocated = sum(CAST(QtyAllocated as BigInt)) into #temp_sum181 
	from orderdetail (nolock)
	where QtyAllocated > 0
	group by orderkey
	
	select a_orderkey = a.orderkey, b_orderkey = b.orderkey, 
	   sum_pickdetail_allocated = a.Qtyallocated , sum_orderdetail = b.Qtyallocated into #info18
	from #temp_sum18 a FULL OUTER JOIN #temp_sum181 b ON a.orderkey = b.orderkey
	where a.Qtyallocated <> b.Qtyallocated
	   or a.orderkey is null or b.orderkey is null
	
	if exists (select 1 from #info18)
   begin
      select '<18> comparing sum(qty by orderkey) in pickdetail (status = 0..4) with sum(qtyallocated by orderkey) in orderdetail'
		select * from #info18
   end 
	drop table #info18
	drop table #temp_sum18
	drop table #temp_sum181
	
	
	-- '<19> comparing sum(qty by orderkey) in pickdetail (status = 5..8) with sum(qtypicked by orderkey) in orderdetail'
	
	select Orderkey, qtypicked = sum(CAST(Qty As BigInt)) into #temp_sum19 
	from pickdetail (nolock)
	where status in ('5', '6', '7', '8') and qty > 0
	group by orderkey
	
	select orderkey, qtypicked = sum(CAST(qtypicked as BigInt)) into #temp_sum191 
	from orderdetail (nolock)
	where QtyPicked > 0
	group by orderkey
	
	select a_orderkey = a.orderkey,  b_orderkey = b.orderkey, 
	  sum_pickdetail_picked = a.qtypicked, sum_orderdetail = b.qtypicked  into #info19
	from #temp_sum19 a FULL OUTER JOIN #temp_sum191 b ON a.orderkey = b.orderkey
	where a.qtypicked <> b.qtypicked
	   or a.orderkey is null or b.orderkey is null
	
	if exists (select 1 from #info19)
   begin
      select '<19> comparing sum(qty by orderkey) in pickdetail (status = 5..8) with sum(qtypicked by orderkey) in orderdetail'
		select * from #info19
   end
	drop table #info19
	drop table #temp_sum19
	drop table #temp_sum191
	
	
	-- '<20> comparing sum(qty by orderkey) in pickdetail (status = 9) with sum(qtyshipped by orderkey) in orderdetail'
	
	select Orderkey, QtyShipped = sum(CAST(Qty As BigInt)) into #temp_sum20 
	from pickdetail (nolock)
	where status ='9' and Qty > 0
	group by orderkey
	
	select  Orderkey, QtyShipped = sum(CAST(ShippedQty as BigInt)) into #temp_sum201 
	from orderdetail (nolock)
	where ShippedQty > 0
	group by orderkey
	
	select a_orderkey = a.orderkey, b_orderkey = b.orderkey, 
	   sum_pickdetail_shipped = a.qtyShipped, sum_orderdetail = b.qtyShipped into #info20
	from #temp_sum20 a FULL OUTER JOIN #temp_sum201 b ON a.orderkey = b.orderkey
	where a.QtyShipped <> b.QtyShipped
	   or a.orderkey is null or b.orderkey is null
	
	if exists (select 1 from #info20)
   begin
      select '<20> comparing sum(qty by orderkey) in pickdetail (status = 9) with sum(qtyshipped by orderkey) in orderdetail'
		select * from #info20
   end 

	drop table #info20
	drop table #temp_sum20
	drop table #temp_sum201
	
	
	-- '<21> comparing sum(qtypreallocated by orderkey) in preallocatepickdetail with sum(qtypreallocated by orderkey) in orderdetail'
	
	select Orderkey, qtypreallocated = sum(CAST(Qty As BigInt)) into #temp_sum212 
	from preallocatepickdetail (nolock)
	where Qty > 0
	group by orderkey
	
	select orderkey, qtypreallocated = sum(CAST(qtypreallocated as BigInt)) into #temp_sum211 
	from orderdetail (nolock)
	where qtypreallocated > 0
	group by orderkey
	
	select a_orderkey = a.orderkey, b_orderkey = b.orderkey, 
	  sum_preallocatepickdetail = a.qtypreallocated, sum_orderdetail = b.qtypreallocated  into #info21
	from #temp_sum212 a FULL OUTER JOIN #temp_sum211 b ON a.orderkey = b.orderkey
	where a.qtypreallocated <> b.qtypreallocated
	   or a.orderkey is null or b.orderkey is null
	
	if exists (select 1 from #info21)
   begin
      select '<21> comparing sum(qtypreallocated by orderkey) in preallocatepickdetail with sum(qtypreallocated by orderkey) in orderdetail'
		select * from #info21
   end

	drop table #info21
	drop table #temp_sum212
	drop table #temp_sum211
	
	
	-- select '<22> comparing LOT and sum(qtypreallocated by Lot) in PreallocatePickdetail'
	
	select lot, qtypreallocated = sum(CAST(Qty As BigInt)) into #temp_sum22 
	from preallocatepickdetail (nolock)
	where qty > 0
	group by lot
	
	select lot, qtypreallocated into #temp_sum221
	from lot (nolock)
	where qtypreallocated > 0
	
	select PreallocatePickDetail_Lot = a.lot, LOT_Lot = b.lot,
	  lot_qtypreallocated = b.qtypreallocated, sum_preallocatepickdetail = a.qtypreallocated into #info22
	from #temp_sum22 a FULL OUTER JOIN #temp_sum221 b ON a.lot = b.lot
	where a.qtypreallocated <> b.qtypreallocated
	 or a.lot is null or b.lot is null
	
	if exists (select 1 from #info22)
   begin
      select '<22> comparing LOT and sum(qtypreallocated by Lot) in PreallocatePickdetail'
		select * from #info22
   end

	drop table #info22
	drop table #temp_sum22
	drop table #temp_sum221

	-- '<23> comparing RECEIPTDETAIL (live DB) and ITRN (live DB + archive DB) (Check for records not in ITRN but FinalizeFlag = Y)'
   /* -- SOS45086
      Note:
      1. Receipt and itrn can have different archiving settings (archiveparameter)
         For e.g. Receipt keep for 60 day but itrn only keep for 30 days. 
         So we need to compare receipt with itrn in archive also
      2. It is possible to have multiple sets of archive setting (for different storer)
         Each set can have different retain days. So we are taking the min from itrn
         to just check the most recent data (for better performance)
         
      Assumption:
      1. Live DB : Archive DB = 1:1
      2. ArchiveParameters.ArchiveDataBaseName is set correctly
   */
   declare @nMinItrnNumberofDaysToRetain int
   declare @cArchiveDB NVARCHAR( 30)

   select @nMinItrnNumberofDaysToRetain = min( ItrnNumberofDaysToRetain)
   from archiveparameters (nolock)

   set rowcount 1
   select @cArchiveDB = ArchiveDataBaseName
   from archiveparameters (nolock)
   set rowcount 0

   -- (Shong01)
   IF OBJECT_ID(RTRIM(@cArchiveDB) + '..itrn') IS NULL
   BEGIN
      PRINT '    Skip this process, ' + RTRIM(@cArchiveDB) + '..ITRN Table Not Found' 
      RETURN 
   END
      

   if (@cArchiveDB IS NULL OR @cArchiveDB = '') OR
      (@nMinItrnNumberofDaysToRetain IS NULL OR @nMinItrnNumberofDaysToRetain < 1)
      select 'incorrect archiveparameters setting'
   else
   begin
   	select r.receiptkey, r.receiptlinenumber, r.sku, r.qtyreceived, r.beforereceivedqty, r.finalizeflag
      into #temp23
   	from receiptdetail r (nolock)
   	left outer join itrn i (nolock) on i.sourcekey = r.receiptkey + r.receiptlinenumber 
   	and  i.trantype = 'DP' and i.sourcetype like 'ntrReceiptDetail%'
   	where r.finalizeflag = 'Y' and QtyReceived > 0 
   	and   i.sourcekey is null
   	and   datediff(day, r.editdate, getdate() ) < @nMinItrnNumberofDaysToRetain
   	and   datediff(minute, r.editdate, getdate() ) > 5

      declare @cSQL nvarchar(max)
      set @cSQL = 
      	'select r.receiptkey, r.receiptlinenumber, r.sku, r.qtyreceived, r.beforereceivedqty ' + 
         'into #info23 ' + 
      	'from #temp23 r (nolock) ' + 
      	'left outer join ' + @cArchiveDB + '..itrn i (nolock) on i.sourcekey = r.receiptkey + r.receiptlinenumber ' + 
      	'and  i.trantype = ''DP'' and i.sourcetype like ''ntrReceiptDetail%'' ' + 
         'where i.sourcekey is null ' + 
   
      	'if exists (select 1 from #info23) ' + 
         'begin ' + 
         'select ''<23> comparing RECEIPTDETAIL (live DB) and ITRN (live DB + archive DB) (Check for records not in ITRN but FinalizeFlag = Y)'' ' +
   		'select * from #info23 ' + 
         'end ' + 
         'drop table #info23 '

      execute sp_executesql @cSQL

      drop table #temp23
   end
end


GO