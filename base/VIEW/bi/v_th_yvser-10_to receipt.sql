SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-10_TO receipt] as
select
   convert(varchar, rcd.Lottable05, 103) as 'PostingDate',
   convert(varchar, h.OrderDate, 103) as 'RequestDate',
   h.ExternOrderKey as 'DocumentNo',
   h.BillToKey as 'TransferFromCode',
   h.B_Company as 'TransferFromName',
   h.ConsigneeKey as 'TransferToCode',
   h.C_Company as 'TransferToName',
   d.UserDefine01 as 'Remark',
   d.Notes as 'Reason',
   h.OrderKey as 'RefLFDocumentNo' 
from
   orders h with (nolock)
JOIN orderDetail d with (nolock) ON h.StorerKey = d.StorerKey 
   and h.OrderKey = d.OrderKey 
   and h.ExternOrderKey = d.ExternOrderKey 
JOIN receiptDetail rcd with (nolock) ON d.StorerKey = rcd.StorerKey 
   and d.ExternOrderKey = rcd.ExternReceiptKey 
   and d.Sku = rcd.Sku 
JOIN receipt rch with (nolock) ON rcd.StorerKey = rch.StorerKey 
   and rcd.ReceiptKey = rch.ReceiptKey 
   and rcd.ExternReceiptKey = rch.ExternReceiptKey 
where
   h.StorerKey = 'YVESR' 
   and h.ConsigneeKey = 'LFWH' 
   and rch.ASNStatus = '9' 
   and convert(date, OrderDate, 103) = convert(date, GetDate() - 1, 103) 
group by
   convert(varchar, rcd.Lottable05, 103),
   convert(varchar, h.OrderDate, 103),
   h.ExternOrderKey,
   h.ConsigneeKey,
   h.C_Company,
   h.BillToKey,
   h.B_Company,
   d.UserDefine01,
   d.Notes,
   h.OrderKey 

GO