SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE view [dbo].[v_Qtyonhold]
as
select lot.storerkey, 
lot.sku, 'LOT' as Type, 
loc.facility, la.lottable02, la.lottable03, la.lottable04, la.lottable05, sum(lotxlocxid.qty - lotxlocxid.qtyallocated - lotxlocxid.qtypicked) as QtyOnHold
from lot (nolock)
join lotxlocxid (nolock) on lotxlocxid.lot = lot.lot 
join loc (nolock) on loc.loc = lotxlocxid.loc 
join lotattribute la (nolock) on la.lot = lotxlocxid.lot
where lot.status = 'HOLD'
group by lot.storerkey, lot.sku, loc.facility, la.lottable02, la.lottable03, la.lottable04, la.lottable05 
having sum(lotxlocxid.qty - lotxlocxid.qtyallocated - lotxlocxid.qtypicked) <> 0 
UNION ALL

select lotxlocxid.storerkey, lotxlocxid.sku, 'LOC' as Type, loc.facility, la.lottable02, la.lottable03, la.lottable04, la.lottable05, sum(lotxlocxid.qty - lotxlocxid.qtyallocated - lotxlocxid.qtypicked) + sum( ISNULL(OA_LLL.qty,0) - ISNULL(OA_LLL.qtyallocated,0) - ISNULL(OA_LLL.qtypicked,0)) as QtyOnHold
from lotxlocxid (nolock)
join lot (nolock) on lot.lot = lotxlocxid.lot 
join loc (nolock) on lotxlocxid.loc = loc.loc
join id (nolock) on lotxlocxid.id = id.id 
join lotattribute la (nolock) on la.lot = lotxlocxid.lot
left outer join lotxlocxid OA_LLL (NOLOCK) on lotxlocxid.lot = OA_LLL.lot 
     -- and lotxlocxid.id = OA_LLL.id 
     and (OA_LLL.Qty - OA_LLL.qtyallocated - OA_LLL.qtypicked) < 0 
     and OA_LLL.loc <> lotxlocxid.loc
left outer join LOC bLOC (NOLOCK) on bLOC.LOC = OA_LLL.LOC and (bLOC.STATUS <> "HOLD" AND bLOC.LocationFlag <> "HOLD" AND bLOC.LocationFlag <> "DAMAGE")
where lot.status <> 'HOLD'
AND (LOC.STATUS = "HOLD" OR LOC.LocationFlag = "HOLD" OR LOC.LocationFlag = "DAMAGE")
and id.status = 'OK' 
group by lotxlocxid.storerkey, lotxlocxid.sku, loc.facility, la.lottable02, la.lottable03, la.lottable04, la.lottable05
having sum(lotxlocxid.qty - lotxlocxid.qtyallocated - lotxlocxid.qtypicked) <> 0 
UNION ALL
select lotxlocxid.storerkey, 
lotxlocxid.sku, 
'ID' as Type, 
loc.facility, 
la.lottable02, 
la.lottable03, 
la.lottable04, 
la.lottable05, 
sum(lotxlocxid.qty - lotxlocxid.qtyallocated - lotxlocxid.qtypicked) as QtyOnHold
from lotxlocxid (nolock)
join lot (nolock) on lot.lot = lotxlocxid.lot 
join loc (nolock) on lotxlocxid.loc = loc.loc
join id (nolock) on lotxlocxid.id = id.id 
join lotattribute la (nolock) on la.lot = lotxlocxid.lot
where lot.status <> 'HOLD'
and (loc.locationFlag <> 'HOLD' AND LOC.LocationFlag <> "DAMAGE" AND loc.Status <> 'HOLD')
and id.status = 'HOLD' 
group by lotxlocxid.storerkey, lotxlocxid.sku, loc.facility, la.lottable02, la.lottable03, la.lottable04, la.lottable05 
having sum(lotxlocxid.qty - lotxlocxid.qtyallocated - lotxlocxid.qtypicked) <> 0 


GO