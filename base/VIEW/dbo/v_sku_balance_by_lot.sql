SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_SKU_BALANCE_BY_LOT]
AS
select T.storerkey, T.facility, T.sku, T.style, T.size, T.descr, T.busr6, T.busr7, T.busr8
   , T.skugroup, T.price, T.cost, convert(nvarchar(max),T.notes2) as notes2, LA.Lottable03, LA.Lottable01
   , sum(qty) as qty
   , sum(qtyallocated) as qtyallocated
   , sum(qtypicked) as qtypicked
   , sum(case when T.OH_flag > 0 then OH_qty else 0 end) as qtyonhold
   , sum(qty)-sum(qtyallocated)-sum(qtypicked)-sum(case when T.OH_flag > 0 then OH_qty else 0 end) as qtyavailable
from
(
   select lli.qty, lli.qtyallocated, lli.qtypicked
      , lli.lot
      , lot.status as lot_status
      , loc.locationflag, loc.status
      , id.status as id_status
      , case when lot.status = 'HOLD' then 1
         when loc.locationflag = 'HOLD' OR loc.Status = 'HOLD' OR loc.locationflag = 'DAMAGE' then 2
         when id.status = 'HOLD' then 3
         else 0 end as OH_Flag
      , lli.qty-lli.qtyallocated-lli.qtypicked as OH_qty
      , lli.storerkey, loc.facility, lli.sku
      , sku.descr, sku.busr6, sku.busr7, sku.busr8
      , sku.skugroup, sku.price, sku.notes2, sku.cost
      , sku.style, sku.size
   from lotxlocxid as lli with (nolock)
   inner join lot as lot with (nolock)
   on lli.lot = lot.lot
   inner join loc as loc with (nolock)
   on loc.loc = lli.loc
   inner join id as id  with (nolock)
   on lli.id = id.id
   inner join sku as sku  with (nolock)
   on sku.sku = lli.sku
    AND SKU.storerkey = lli.storerkey
   --where lli.storerkey = 'SLA'
   --and loc.facility = 'BJB1'
) AS T
LEFT JOIN lotattribute as LA
on LA.Lot = T.Lot
group by T.storerkey, T.facility, T.sku, T.style, T.size, T.descr, T.busr6, T.busr7, T.busr8
   , T.skugroup, T.price, T.cost, convert(nvarchar(max),T.notes2), LA.Lottable03, LA.Lottable01


GO