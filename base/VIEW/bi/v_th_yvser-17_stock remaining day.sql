SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-17_Stock Remaining Day] as 
select x.ValueDate, x.InventoryPosting, x.GroupDivisionCode, x.ItemCategory, x.ProductGroup, 
	   x.ItemNo, x.FranceCode, x.Description,
	   (Case When x.Facility = 'KT01' then 'KTWH'
			 When x.Facility = 'BDC02' then 'BNWH'
			 When x.Facility = 'LKB01' then 'LKWH'
		else 'UNKNOW' end) as LocationWarehouse,
	   sum(x.TotalQty) as TotalQty,
	   sum(x.VitualQty) as VitualQty,
	   sum(x.TotalWarehouse) as NetWarehouse,
	   sum(x.StockExpire) as Expire, 
	   sum(x.StockSpoil) as Spoil,
	   sum(x.RemainingLT9M) as "<9M",
	   sum(x.RemainingEQ9MLT12M) as "9M<X<12M",
	   sum(x.RemainingEQ12MLT24M) as "12M<X<24M",
	   sum(x.RemainingEQ24M) as ">24M"
from (
	select sku.Busr1 as InventoryPosting, sku.Busr3 as GroupDivisionCode, sku.Busr4 as ItemCategory, 
	   sku.Busr5 as ProductGroup, Convert(varchar, GetDate(), 103) as ValueDate, sku.sku as ItemNo, 
	   sku.ManufacturerSku as FranceCode, sku.Descr as Description, loc.Facility,
	   sum(soh.Qty) as TotalQty,
	   0 as VitualQty,
	   0 as TotalWarehouse,
	   0 as StockExpire, 
	   0 as StockSpoil,
	   0 as RemainingLT9M, 
	   0 as RemainingEQ9MLT12M,
	   0 as RemainingEQ12MLT24M,
	   0 as RemainingEQ24M
	from SKU sku with (nolock)
	join LOTxLOCxID soh with (nolock) ON sku.StorerKey = soh.StorerKey and sku.sku = soh.sku
	join LOTAttribute att with (nolock) ON soh.StorerKey = att.Storerkey and soh.sku = att.sku and soh.lot = att.lot
	join LOC loc with (nolock) ON soh.loc = loc.loc 
	where sku.StorerKey = 'YVESR'
	and soh.qty <> 0
	group by sku.Busr1, sku.Busr3, sku.Busr4, sku.Busr5, sku.sku, sku.ManufacturerSku, sku.Descr, loc.Facility
	union 
	select sku.Busr1 as InventoryPosting, sku.Busr3 as GroupDivisionCode, sku.Busr4 as ItemCategory, 
	   sku.Busr5 as ProductGroup, Convert(varchar, GetDate(), 103) as ValueDate, sku.sku as ItemNo, 
	   sku.ManufacturerSku as FranceCode, sku.Descr as Description, loc.Facility,
	   0 as TotalQty,
	   sum(soh.Qty) as VitualQty,
	   0 as TotalWarehouse,
	   0 as StockExpire, 
	   0 as StockSpoil,
	   0 as RemainingLT9M, 
	   0 as RemainingEQ9MLT12M,
	   0 as RemainingEQ12MLT24M,
	   0 as RemainingEQ24M
	from SKU sku with (nolock)
	join LOTxLOCxID soh with (nolock) ON sku.StorerKey = soh.StorerKey and sku.sku = soh.sku
	join LOTAttribute att with (nolock) ON soh.StorerKey = att.Storerkey and soh.sku = att.sku and soh.lot = att.lot
	join LOC loc with (nolock) ON soh.loc = loc.loc
	where sku.StorerKey = 'YVESR'
	and loc.loc in ('LOSSWH','VARCOUNT','VARRECIMP','VARRECLOC','VARRETURN')
	and soh.qty <> 0
	group by sku.Busr1, sku.Busr3, sku.Busr4, sku.Busr5, sku.sku, sku.ManufacturerSku, sku.Descr, loc.Facility
	union 
	select sku.Busr1 as InventoryPosting, sku.Busr3 as GroupDivisionCode, sku.Busr4 as ItemCategory, 
	   sku.Busr5 as ProductGroup, Convert(varchar, GetDate(), 103) as ValueDate, sku.sku as ItemNo, 
	   sku.ManufacturerSku as FranceCode, sku.Descr as Description, loc.Facility,
	   0 as TotalQty,
	   0 as VitualQty,
	   sum(soh.Qty) as TotalWarehouse,
	   0 as StockExpire, 
	   0 as StockSpoil,
	   0 as RemainingLT9M, 
	   0 as RemainingEQ9MLT12M,
	   0 as RemainingEQ12MLT24M,
	   0 as RemainingEQ24M
	from SKU sku with (nolock)
	join LOTxLOCxID soh with (nolock) ON sku.StorerKey = soh.StorerKey and sku.sku = soh.sku
	join LOTAttribute att with (nolock) ON soh.StorerKey = att.Storerkey and soh.sku = att.sku and soh.lot = att.lot
	join LOC loc with (nolock) ON soh.loc = loc.loc
	where sku.StorerKey = 'YVESR'
	and loc.loc not in ('SPOILSTG','EXPSTG','LOSSWH','VARCOUNT','VARRECIMP','VARRECLOC','VARRETURN')
	and soh.qty <> 0
	group by sku.Busr1, sku.Busr3, sku.Busr4, sku.Busr5, sku.sku, sku.ManufacturerSku, sku.Descr, loc.Facility
	union 
	select sku.Busr1 as InventoryPosting, sku.Busr3 as GroupDivisionCode, sku.Busr4 as ItemCategory, 
	   sku.Busr5 as ProductGroup, Convert(varchar, GetDate(), 103) as ValueDate, sku.sku as ItemNo, 
	   sku.ManufacturerSku as FranceCode, sku.Descr as Description, loc.Facility, 
	   0 as TotalQty,
	   0 as VitualQty,
	   0 as TotalWarehouse,
	   sum(soh.Qty) as StockExpire, 
	   0 as StockSpoil,
	   0 as RemainingLT9M, 
	   0 as RemainingEQ9MLT12M,
	   0 as RemainingEQ12MLT24M,
	   0 as RemainingEQ24M
	from SKU sku with (nolock)
	join LOTxLOCxID soh with (nolock) ON sku.StorerKey = soh.StorerKey and sku.sku = soh.sku
	join LOTAttribute att with (nolock) ON soh.StorerKey = att.Storerkey and soh.sku = att.sku and soh.lot = att.lot
	join LOC loc with (nolock) ON soh.loc = loc.loc
	where sku.StorerKey = 'YVESR'
	and loc.loc in ('EXPSTG') 
	and soh.qty <> 0
	group by sku.Busr1, sku.Busr3, sku.Busr4, sku.Busr5, sku.sku, sku.ManufacturerSku, sku.Descr, loc.Facility
	union 
	select sku.Busr1 as InventoryPosting, sku.Busr3 as GroupDivisionCode, sku.Busr4 as ItemCategory, 
	   sku.Busr5 as ProductGroup, Convert(varchar, GetDate(), 103) as ValueDate, sku.sku as ItemNo, 
	   sku.ManufacturerSku as FranceCode, sku.Descr as Description, loc.Facility,  
	   0 as TotalQty,
	   0 as VitualQty,
	   0 as TotalWarehouse,
	   0 as StockExpire, 
	   sum(soh.Qty) as StockSpoil,
	   0 as RemainingLT9M, 
	   0 as RemainingEQ9MLT12M,
	   0 as RemainingEQ12MLT24M,
	   0 as RemainingEQ24M
	from SKU sku with (nolock)
	join LOTxLOCxID soh with (nolock) ON sku.StorerKey = soh.StorerKey and sku.sku = soh.sku
	join LOTAttribute att with (nolock) ON soh.StorerKey = att.Storerkey and soh.sku = att.sku and soh.lot = att.lot
	join LOC loc with (nolock) ON soh.loc = loc.loc
	where sku.StorerKey = 'YVESR'
	and loc.loc in ('SPOILSTG') 
	and soh.qty <> 0
	group by sku.Busr1, sku.Busr3, sku.Busr4, sku.Busr5, sku.sku, sku.ManufacturerSku, sku.Descr, loc.Facility
	union 
	select sku.Busr1 as InventoryPosting, sku.Busr3 as GroupDivisionCode, sku.Busr4 as ItemCategory, 
	   sku.Busr5 as ProductGroup, Convert(varchar, GetDate(), 103) as ValueDate, sku.sku as ItemNo, 
	   sku.ManufacturerSku as FranceCode, sku.Descr as Description, loc.Facility,  
	   0 as TotalQty,
	   0 as VitualQty,
	   0 as TotalWarehouse,
	   0 as StockExpire, 
	   0 as StockSpoil, 
	   sum(soh.Qty) as RemainingLT9M, 
	   0 as RemainingEQ9MLT12M,
	   0 as RemainingEQ12MLT24M,
	   0 as RemainingEQ24M
	from SKU sku with (nolock)
	join LOTxLOCxID soh with (nolock) ON sku.StorerKey = soh.StorerKey and sku.sku = soh.sku
	join LOTAttribute att with (nolock) ON soh.StorerKey = att.Storerkey and soh.sku = att.sku and soh.lot = att.lot
	join LOC loc with (nolock) ON soh.loc = loc.loc
	where sku.StorerKey = 'YVESR'
	and loc.loc not in ('SPOILSTG','EXPSTG','LOSSWH','VARCOUNT','VARRECIMP','VARRECLOC','VARRETURN')
	and soh.qty <> 0
	and att.Lottable04 < GetDate()+270 
	and convert(date, att.Lottable04, 112) <> '19000101'
	group by sku.Busr1, sku.Busr3, sku.Busr4, sku.Busr5, sku.sku, sku.ManufacturerSku, sku.Descr, loc.Facility
	union 
	select sku.Busr1 as InventoryPosting, sku.Busr3 as GroupDivisionCode, sku.Busr4 as ItemCategory, 
	   sku.Busr5 as ProductGroup, Convert(varchar, GetDate(), 103) as ValueDate, sku.sku as ItemNo, 
	   sku.ManufacturerSku as FranceCode, sku.Descr as Description, loc.Facility, 
	   0 as TotalQty,
	   0 as VitualQty,
	   0 as TotalWarehouse,
	   0 as StockExpire, 
	   0 as StockSpoil, 
	   0 as RemainingLT9M, 
	   sum(soh.Qty) as RemainingEQ9MLT12M,
	   0 as RemainingEQ12MLT24M,
	   0 as RemainingEQ24M
	from SKU sku with (nolock)
	join LOTxLOCxID soh with (nolock) ON sku.StorerKey = soh.StorerKey and sku.sku = soh.sku
	join LOTAttribute att with (nolock) ON soh.StorerKey = att.Storerkey and soh.sku = att.sku and soh.lot = att.lot
	join LOC loc with (nolock) ON soh.loc = loc.loc
	where sku.StorerKey = 'YVESR'
	and loc.loc not in ('SPOILSTG','EXPSTG','LOSSWH','VARCOUNT','VARRECIMP','VARRECLOC','VARRETURN')
	and soh.qty <> 0
	and att.Lottable04 >= GetDate()+270 and att.Lottable04 < GetDate()+360
	and convert(date, att.Lottable04, 112) <> '19000101'
	group by sku.Busr1, sku.Busr3, sku.Busr4, sku.Busr5, sku.sku, sku.ManufacturerSku, sku.Descr, loc.Facility
	union 
	select sku.Busr1 as InventoryPosting, sku.Busr3 as GroupDivisionCode, sku.Busr4 as ItemCategory, 
	   sku.Busr5 as ProductGroup, Convert(varchar, GetDate(), 103) as ValueDate, sku.sku as ItemNo, 
	   sku.ManufacturerSku as FranceCode, sku.Descr as Description, loc.Facility, 
	   0 as TotalQty,
	   0 as VitualQty,
	   0 as TotalWarehouse,
	   0 as StockExpire, 
	   0 as StockSpoil,
	   0 as RemainingLT9M, 
	   0 as RemainingEQ9MLT12M,
	   sum(soh.Qty) as RemainingEQ12MLT24M,
	   0 as RemainingEQ24M
	from SKU sku with (nolock)
	join LOTxLOCxID soh with (nolock) ON sku.StorerKey = soh.StorerKey and sku.sku = soh.sku
	join LOTAttribute att with (nolock) ON soh.StorerKey = att.Storerkey and soh.sku = att.sku and soh.lot = att.lot
	join LOC loc with (nolock) ON soh.loc = loc.loc
	where sku.StorerKey = 'YVESR'
	and loc.loc not in ('SPOILSTG','EXPSTG','LOSSWH','VARCOUNT','VARRECIMP','VARRECLOC','VARRETURN')  
	and soh.qty <> 0
	and att.Lottable04 >= GetDate()+360 and att.Lottable04 < GetDate()+720
	and convert(date, att.Lottable04, 112) <> '19000101'
	group by sku.Busr1, sku.Busr3, sku.Busr4, sku.Busr5, sku.sku, sku.ManufacturerSku, sku.Descr, loc.Facility 
	union 
	select sku.Busr1 as InventoryPosting, sku.Busr3 as GroupDivisionCode, sku.Busr4 as ItemCategory, 
	   sku.Busr5 as ProductGroup, Convert(varchar, GetDate(), 103) as ValueDate, sku.sku as ItemNo, 
	   sku.ManufacturerSku as FranceCode, sku.Descr as Description, loc.Facility,  
	   0 as TotalQty,
	   0 as VitualQty,
	   0 as TotalWarehouse,
	   0 as StockExpire, 
	   0 as StockSpoil,
	   0 as RemainingLT9M, 
	   0 as RemainingEQ9MLT12M,
	   0 as RemainingEQ12MLT24M,
	   sum(soh.Qty) as RemainingEQ24M
	from SKU sku with (nolock)
	join LOTxLOCxID soh with (nolock) ON sku.StorerKey = soh.StorerKey and sku.sku = soh.sku
	join LOTAttribute att with (nolock) ON soh.StorerKey = att.Storerkey and soh.sku = att.sku and soh.lot = att.lot
	join LOC loc with (nolock) ON soh.loc = loc.loc
	where sku.StorerKey = 'YVESR'
	and loc.loc not in ('SPOILSTG','EXPSTG','LOSSWH','VARCOUNT','VARRECIMP','VARRECLOC','VARRETURN')
	and soh.qty <> 0
	and att.Lottable04 >= GetDate()+720
	and convert(date, att.Lottable04, 112) <> '19000101'
	group by sku.Busr1, sku.Busr3, sku.Busr4, sku.Busr5, sku.sku, sku.ManufacturerSku, sku.Descr, loc.Facility 	
	union 
	select sku.Busr1 as InventoryPosting, sku.Busr3 as GroupDivisionCode, sku.Busr4 as ItemCategory, 
	   sku.Busr5 as ProductGroup, Convert(varchar, GetDate(), 103) as ValueDate, sku.sku as ItemNo, 
	   sku.ManufacturerSku as FranceCode, sku.Descr as Description, loc.Facility,  
	   0 as TotalQty,
	   0 as VitualQty,
	   0 as TotalWarehouse,
	   0 as StockExpire, 
	   0 as StockSpoil,
	   0 as RemainingLT9M, 
	   0 as RemainingEQ9MLT12M,
	   0 as RemainingEQ12MLT24M,
	   sum(soh.Qty) as RemainingEQ24M
	from SKU sku with (nolock)
	join LOTxLOCxID soh with (nolock) ON sku.StorerKey = soh.StorerKey and sku.sku = soh.sku
	join LOTAttribute att with (nolock) ON soh.StorerKey = att.Storerkey and soh.sku = att.sku and soh.lot = att.lot
	join LOC loc with (nolock) ON soh.loc = loc.loc
	where sku.StorerKey = 'YVESR'
	and loc.loc not in ('SPOILSTG','EXPSTG','LOSSWH','VARCOUNT','VARRECIMP','VARRECLOC','VARRETURN')
	and soh.qty <> 0
	and COALESCE(att.Lottable04, convert(date, '19000101', 112)) = '19000101'
	group by sku.Busr1, sku.Busr3, sku.Busr4, sku.Busr5, sku.sku, sku.ManufacturerSku, sku.Descr, loc.Facility 	
) x where x.ItemNo like '%'
group by x.InventoryPosting, x.GroupDivisionCode, x.ItemCategory, x.ProductGroup, x.ValueDate,
			 x.ItemNo, x.FranceCode, x.Description, x.Facility

GO