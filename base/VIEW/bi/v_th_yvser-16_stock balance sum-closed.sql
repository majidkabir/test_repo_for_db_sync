SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-16_Stock Balance SUM-Closed] as 
select x.InventoryPosting, x.GroupDivisionCode, x.ItemCategory, x.ProductGroup, x.ValueDate,
    x.ItemNo, x.FranceCode, x.Description, 
    sum(x.ReceiveLabelling) as 'Receive & Labelling',
    sum(x.Specialbin) as 'Special bin',
	sum(x.allocated_n_Picked)  as 'Allocated + Picked qty',
    iif (sum(x.TotalWarehouse) - sum(x.allocated_n_Picked) - sum(x.ReceiveLabelling + x.Specialbin)<='0','0',
	sum(x.TotalWarehouse) - sum(x.allocated_n_Picked) - sum(x.ReceiveLabelling + x.Specialbin))  as 'SellableQty',
    sum(x.TotalWarehouse) as TotalWH,
    sum(x.TotalWarehouse) - sum(x.Specialbin)  as 'TotalWH-Specialbin',
    sum(x.RemainingDayMorethan540) as RemainingDayMorethan540,
    sum(x.RemainingDayLessthan540) as RemainingDayLessthan540,
    sum(x.RemainingDayLessthan180) as RemainingDayLessthan180,
    Y.StockTrackingLot
from (
 select sku.Busr1 as InventoryPosting, sku.Busr3 as GroupDivisionCode, sku.Busr4 as ItemCategory, 
    sku.Busr5 as ProductGroup, Convert(varchar, GetDate(), 103) as ValueDate, sku.sku as ItemNo, 
    sku.ManufacturerSku as FranceCode, sku.Descr as Description, 
    0 as TotalWarehouse,
    0 as StockSpoilExpireVariance, 
    0 as RemainingDayMorethan540, 
    0 as RemainingDayLessthan540,
    0 as RemainingDayLessthan180,
    0 as ReceiveLabelling,
    0 as Specialbin,
	sum(soh.QtyAllocated)+sum(soh.QtyPicked) as allocated_n_Picked
 from SKU sku with (nolock)
 JOIN LOTxLOCxID soh with (nolock) ON sku.StorerKey = soh.StorerKey and sku.sku = soh.sku
 JOIN LOTAttribute att with (nolock) ON soh.StorerKey = att.Storerkey and soh.sku = att.sku and soh.lot = att.lot
 JOIN LOC loc with (nolock) ON soh.loc = loc.loc 
 where sku.StorerKey = 'YVESR'
 group by sku.Busr1, sku.Busr3, sku.Busr4, sku.Busr5, sku.sku, sku.ManufacturerSku, sku.Descr
 union 
 select sku.Busr1 as InventoryPosting, sku.Busr3 as GroupDivisionCode, sku.Busr4 as ItemCategory, 
    sku.Busr5 as ProductGroup, Convert(varchar, GetDate(), 103) as ValueDate, sku.sku as ItemNo, 
    sku.ManufacturerSku as FranceCode, sku.Descr as Description, 
    sum(soh.Qty) as TotalWarehouse,
    0 as StockSpoilExpireVariance, 
    0 as RemainingDayMorethan540, 
    0 as RemainingDayLessthan540,
    0 as RemainingDayLessthan180,
    0 as ReceiveLabelling,
    0 as Specialbin,
	0 as allocated_n_Picked
 from SKU sku with (nolock)
 JOIN LOTxLOCxID soh with (nolock) ON sku.StorerKey = soh.StorerKey and sku.sku = soh.sku
 JOIN LOTAttribute att with (nolock) ON soh.StorerKey = att.Storerkey and soh.sku = att.sku and soh.lot = att.lot
 JOIN LOC loc with (nolock) ON soh.loc = loc.loc 
 where sku.StorerKey = 'YVESR'
 group by sku.Busr1, sku.Busr3, sku.Busr4, sku.Busr5, sku.sku, sku.ManufacturerSku, sku.Descr
 union 
 select sku.Busr1 as InventoryPosting, sku.Busr3 as GroupDivisionCode, sku.Busr4 as ItemCategory, 
    sku.Busr5 as ProductGroup, Convert(varchar, GetDate(), 103) as ValueDate, sku.sku as ItemNo, 
    sku.ManufacturerSku as FranceCode, sku.Descr as Description, 
    0 as TotalWarehouse,
    sum(soh.Qty) as StockSpoilExpireVariance, 
    0 as RemainingDayMorethan540, 
    0 as RemainingDayLessthan540,
    0 as RemainingDayLessthan180,
    0 as ReceiveLabelling,
    0 as Specialbin,
	0 as allocated_n_Picked
 from SKU sku with (nolock)
 JOIN LOTxLOCxID soh with (nolock) ON sku.StorerKey = soh.StorerKey and sku.sku = soh.sku
 JOIN LOTAttribute att with (nolock) ON soh.StorerKey = att.Storerkey and soh.sku = att.sku and soh.lot = att.lot
 JOIN LOC loc with (nolock) ON soh.loc = loc.loc
 where sku.StorerKey = 'YVESR'
 and loc.loc in (select lk.Code from CODELKUP lk with (nolock) where lk.StorerKey = 'YVESR' and lk.ListName = 'YREXSOH')
 group by sku.Busr1, sku.Busr3, sku.Busr4, sku.Busr5, sku.sku, sku.ManufacturerSku, sku.Descr
 union 
 select sku.Busr1 as InventoryPosting, sku.Busr3 as GroupDivisionCode, sku.Busr4 as ItemCategory, 
    sku.Busr5 as ProductGroup, Convert(varchar, GetDate(), 103) as ValueDate, sku.sku as ItemNo, 
    sku.ManufacturerSku as FranceCode, sku.Descr as Description, 
    0 as TotalWarehouse,
    0 as StockSpoilExpireVariance, 
    sum(soh.Qty) as RemainingDayMorethan540, 
    0 as RemainingDayLessthan540,
    0 as RemainingDayLessthan180,
    0 as ReceiveLabelling,
    0 as Specialbin,
	0 as allocated_n_Picked
 from SKU sku with (nolock)
 JOIN LOTxLOCxID soh with (nolock) ON sku.StorerKey = soh.StorerKey and sku.sku = soh.sku
 JOIN LOTAttribute att with (nolock) ON soh.StorerKey = att.Storerkey and soh.sku = att.sku and soh.lot = att.lot
 JOIN LOC loc with (nolock) ON soh.loc = loc.loc
 where sku.StorerKey = 'YVESR'
 and loc.loc not in (select lk.Code from CODELKUP lk with (nolock) where lk.StorerKey = 'YVESR' and lk.ListName = 'YREXSOH')
 and att.Lottable04 >= GetDate()+540 and sku.Lottable02Label = 'BATCH_NO'
 group by sku.Busr1, sku.Busr3, sku.Busr4, sku.Busr5, sku.sku, sku.ManufacturerSku, sku.Descr
 union 
 select sku.Busr1 as InventoryPosting, sku.Busr3 as GroupDivisionCode, sku.Busr4 as ItemCategory, 
    sku.Busr5 as ProductGroup, Convert(varchar, GetDate(), 103) as ValueDate, sku.sku as ItemNo, 
    sku.ManufacturerSku as FranceCode, sku.Descr as Description, 
    0 as TotalWarehouse,
    0 as StockSpoilExpireVariance, 
    0 as RemainingDayMorethan540,
    sum(soh.Qty) as RemainingDayLessthan540,     
    0 as RemainingDayLessthan180,
    0 as ReceiveLabelling,
    0 as Specialbin,
	0 as allocated_n_Picked
 from SKU sku with (nolock)
 JOIN LOTxLOCxID soh with (nolock) ON sku.StorerKey = soh.StorerKey and sku.sku = soh.sku
 JOIN LOTAttribute att with (nolock) ON soh.StorerKey = att.Storerkey and soh.sku = att.sku and soh.lot = att.lot
 JOIN LOC loc with (nolock) ON soh.loc = loc.loc
 where sku.StorerKey = 'YVESR'
 and loc.loc not in (select lk.Code from CODELKUP lk with (nolock) where lk.StorerKey = 'YVESR' and lk.ListName = 'YREXSOH')
 and att.Lottable04 < GetDate()+540 and att.Lottable04 >= GetDate()+180 and sku.Lottable02Label = 'BATCH_NO'
 group by sku.Busr1, sku.Busr3, sku.Busr4, sku.Busr5, sku.sku, sku.ManufacturerSku, sku.Descr
 union 
 select sku.Busr1 as InventoryPosting, sku.Busr3 as GroupDivisionCode, sku.Busr4 as ItemCategory, 
    sku.Busr5 as ProductGroup, Convert(varchar, GetDate(), 103) as ValueDate, sku.sku as ItemNo, 
    sku.ManufacturerSku as FranceCode, sku.Descr as Description, 
    0 as TotalWarehouse,
    0 as StockSpoilExpireVariance, 
    0 as RemainingDayMorethan540, 
    0 as RemainingDayLessthan540,
    sum(soh.Qty) as RemainingDayLessthan180,
    0 as ReceiveLabelling,
    0 as Specialbin,
	0 as allocated_n_Picked
 from SKU sku with (nolock)
 JOIN LOTxLOCxID soh with (nolock) ON sku.StorerKey = soh.StorerKey and sku.sku = soh.sku
 JOIN LOTAttribute att with (nolock) ON soh.StorerKey = att.Storerkey and soh.sku = att.sku and soh.lot = att.lot
 JOIN LOC loc with (nolock) ON soh.loc = loc.loc
 where sku.StorerKey = 'YVESR'
 and loc.loc not in (select lk.Code from CODELKUP lk with (nolock) where lk.StorerKey = 'YVESR' and lk.ListName = 'YREXSOH')
 and att.Lottable04 < GetDate()+180 and sku.Lottable02Label = 'BATCH_NO'
 group by sku.Busr1, sku.Busr3, sku.Busr4, sku.Busr5, sku.sku, sku.ManufacturerSku, sku.Descr
 union
 select sku.Busr1 as InventoryPosting, sku.Busr3 as GroupDivisionCode, sku.Busr4 as ItemCategory, 
    sku.Busr5 as ProductGroup, Convert(varchar, GetDate(), 103) as ValueDate, sku.sku as ItemNo, 
    sku.ManufacturerSku as FranceCode, sku.Descr as Description, 
    0 as TotalWarehouse,
    0 as StockSpoilExpireVariance, 
    0 as RemainingDayMorethan540, 
    0 as RemainingDayLessthan540,
    0 as RemainingDayLessthan180,
    sum(soh.qty) as ReceiveLabelling,
    0 as Specialbin,
	0 as allocated_n_Picked
 from SKU sku with (nolock)
 JOIN LOTxLOCxID soh with (nolock) ON sku.StorerKey = soh.StorerKey and sku.sku = soh.sku
 JOIN LOTAttribute att with (nolock) ON soh.StorerKey = att.Storerkey and soh.sku = att.sku and soh.lot = att.lot
 JOIN LOC loc with (nolock) ON soh.loc = loc.loc 
 where sku.StorerKey = 'YVESR'
 and loc.loc in(select loc from loc with (nolock) where loc like'AKQ%' and hostwhcode ='YVESR' or loc in('RECEIVESTG','RETURNSTG','YRRWCPK','YRFGCPK'))
 group by sku.Busr1, sku.Busr3, sku.Busr4, sku.Busr5, sku.sku, sku.ManufacturerSku, sku.Descr
 union
 select sku.Busr1 as InventoryPosting, sku.Busr3 as GroupDivisionCode, sku.Busr4 as ItemCategory, 
    sku.Busr5 as ProductGroup, Convert(varchar, GetDate(), 103) as ValueDate, sku.sku as ItemNo, 
    sku.ManufacturerSku as FranceCode, sku.Descr as Description, 
    0 as TotalWarehouse,
    0 as StockSpoilExpireVariance, 
    0 as RemainingDayMorethan540, 
    0 as RemainingDayLessthan540,
    0 as RemainingDayLessthan180,
    0 as ReceiveLabelling,
    sum(soh.qty) as Specialbin,
	0 as allocated_n_Picked
 from SKU sku with (nolock)
 JOIN LOTxLOCxID soh with (nolock) ON sku.StorerKey = soh.StorerKey and sku.sku = soh.sku
 JOIN LOTAttribute att with (nolock) ON soh.StorerKey = att.Storerkey and soh.sku = att.sku and soh.lot = att.lot
 JOIN LOC loc with (nolock) ON soh.loc = loc.loc
 where sku.StorerKey = 'YVESR'
 and loc.loc in ('DMGSTG','EXPSTG','FDASTG','NEAREXPSTG','QASTG','QUARANTINE','SPOILSTG','VARRECIMP','VARRETURN','YVESFL0101','YVESFL0102','YVESFL0103','YVESFL0104','YVESFL0105')
 group by sku.Busr1, sku.Busr3, sku.Busr4, sku.Busr5, sku.sku, sku.ManufacturerSku, sku.Descr
) x
left join
(
select y.sku
,case when y.busr7 ='Yes' and y.busr8 ='Yes' then 'Y' else 'N' end as StockTrackingLot
from sku as y with (nolock)
where y.storerkey ='YVESR' 
)Y on  x.itemno = y.sku
group by x.InventoryPosting, x.GroupDivisionCode, x.ItemCategory, x.ProductGroup, x.ValueDate,
  x.ItemNo, x.FranceCode, x.Description,y.sku,y.StockTrackingLot

GO