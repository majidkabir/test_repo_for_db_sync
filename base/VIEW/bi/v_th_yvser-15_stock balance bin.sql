SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-15_Stock Balance BIN] as 
select convert(varchar, GetDate()-1, 103) as 'ValueDate', soh.sku as 'ItemNo', sku.manufacturersku as 'FranceCode',
       sku.Descr as 'ItemName', 
	   (Case When loc.Facility = 'KT01' then 'KTWH'
			 When loc.Facility = 'BDC02' then 'BNWH'
			 When loc.Facility = 'LKB01' then 'LKWH'
		else 'UNKNOW' end) as 'Location', 
	   loc.PutawayZone as 'ZoneCode', (Case when (loc.Descr is null or len(loc.Descr) < 2) then 'OTHER' else loc.Descr end) as 'BinTypeCode',
	   (Case When soh.loc in (select lk.Code from V_CODELKUP lk where lk.StorerKey = 'YVESR' and lk.ListName = 'YREXSOH' and lk.code not in ('SPOILSTG','EXPSTG')) then 'Yes'
	     else 'No' end) as 'BlockMovement', 
	   (Case When soh.loc in ('SPOILSTG','EXPSTG') then 'Yes' else 'No' end) as 'SpoilExpire', 
	   soh.loc as 'BINCode', 
	   (Case when sku.Lottable02label = 'BATCH_NO' then att.Lottable02 else '' end) as 'LotNo', 
	   (Case when sku.Lottable02label = 'BATCH_NO' then convert(varchar, att.Lottable03, 103) else '' end) as 'MFGDate',
	   (Case when sku.Lottable02label = 'BATCH_NO' then convert(varchar, att.Lottable04, 103) else '' end) as 'EXPDate', 
	   (Case when sku.Lottable02label = 'BATCH_NO' then datediff(dd, GetDate(), att.Lottable04) else '' end) as 'RemainingDay', 
	   sum(soh.Qty) as 'Qty', 
	   sku.IB_UOM as 'UnitOfMeasureCode'
from LOTxLOCxID soh with (nolock)
JOIN LOTAttribute att with (nolock) ON soh.StorerKey = att.StorerKey
	and soh.sku = att.sku 
	and soh.lot = att.lot 
JOIN SKU sku with (nolock) ON soh.StorerKey = sku.StorerKey
	and soh.sku = sku.sku 
JOIN LOC loc with (nolock) ON soh.loc = loc.loc
where soh.StorerKey = 'YVESR'
and soh.Qty > 0
group by soh.sku, sku.manufacturersku, sku.Descr, loc.Facility, loc.PutawayZone, loc.Descr,
	   soh.loc, att.Lottable02, convert(varchar, att.Lottable03, 103), convert(varchar, att.Lottable04, 103), 	   
	   datediff(dd, GetDate(), att.Lottable04), sku.IB_UOM, sku.Lottable02label

GO