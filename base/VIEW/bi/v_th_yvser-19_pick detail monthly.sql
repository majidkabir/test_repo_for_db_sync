SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-19_Pick detail monthly] as 
select convert(varchar, h.DeliveryDate, 103) as DeliveryDate, 
		convert(varchar, h.OrderDate, 103) as RequestDate, 
		convert(varchar, h.EditDate, 103) as ShippedDate, 
		h.ExternOrderKey as DocumentNo, 
		h.OrderKey as RefLFDocumentNo, 
	    d.SKU as ItemNo, 
	   sku.Descr as ItemName, 
	   sku.Busr1 as Inventoryposting, 
	   sku.Busr3 as DivisionCode, 
	   d.OriginalQty as RequestQty,
	   d.ShippedQty as QuantityShipped, 
	   d.OriginalQty-d.ShippedQty as Variance, 
	   (d.ShippedQty*100)/(Case when d.OriginalQty = 0 then 0.0001 
								when d.OriginalQty is null then 0.0001 
						    else d.OriginalQty end) as PctPerformance,
	   h.ConsigneeKey as TransferToCode, 
	   h.C_Company as TransferToName
from Orders h with (nolock)
JOIN OrderDetail d with (nolock) ON h.StorerKey = d.StorerKey 
	and h.OrderKey = d.OrderKey 
	and h.ExternOrderKey = d.ExternOrderKey 
JOIN SKU sku with (nolock) ON d.StorerKey = sku.StorerKey 
	and d.sku = sku.sku
where h.StorerKey = 'YVESR'
and h.Status = '9' and h.SOStatus = '9' and d.Status = '9'
and h.EditDate between  DATEADD(MONTH, DATEDIFF(MONTH,0,DATEADD(MONTH,-1,getdate()) ),0) and  DATEADD(d,-1, DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE()),0))

GO