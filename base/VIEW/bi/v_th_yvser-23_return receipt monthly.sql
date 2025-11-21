SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-23_Return Receipt Monthly] as 
select convert(varchar, h.FinalizeDate, 103) as ReceiptDate,
	 h.ExternReceiptKey as DocumentNo, 
	 h.ReceiptKey as LFRefNo,
	 h.CarrierKey as TransferFromCode, 
	 h.CarrierName as TransferFromName, 
	 h.SellerName as TransferToCode, 
	 h.SellerCompany as TransferToName,
	 d.Sku as ItemCode,
	 sku.Descr as ItemName, 
	 sum(d.QtyExpected) as RequestReturnQty, 
	 sum(d.QtyReceived) as ReceivedQty,
	 d.UOM as UnitOfMeasure,
	 d.Lottable02 as BatchLOT,
	 d.Lottable03 as MFGDate, 
	 convert(varchar, d.Lottable04, 103) as EXPDate
from Receipt h with (nolock)
JOIN ReceiptDetail d with (nolock) ON h.StorerKey = d.Storerkey 
	and h.ExternReceiptKey = d.ExternReceiptKey 
	and h.ReceiptKey = d.ReceiptKey
JOIN SKU sku with (nolock) ON d.StorerKey = sku.StorerKey 
	and d.Sku = sku.Sku
where h.StorerKey = 'YVESR' and h.ASNStatus = '9' and h.RecType = 'GRN' and h.DocType = 'R' 
and  h.FinalizeDate between  DATEADD(MONTH, DATEDIFF(MONTH,0,DATEADD(MONTH,-1,getdate()) ),0) and  DATEADD(d,-1, DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE()),0))
group by convert(varchar, h.FinalizeDate, 103), h.ExternReceiptKey, h.ReceiptKey,
	   h.CarrierKey, h.CarrierName, h.SellerName, h.SellerCompany, d.Sku, sku.Descr, d.UOM, 
	   d.Lottable02, d.Lottable03, convert(varchar, d.Lottable04, 103)

GO