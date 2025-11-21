SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-20_Pick SUM by ITEM Monthly] as 
select xx.PostingDate, 
		xx.ItemNo, 
		xx.ItemName, 
		xx.DivisionCode,
		xx.Inventoryposting,
		sum(xx.RequestQty) as RequestQty,
		sum(xx.ShippedQty) as ShippedQty, 
		sum(xx.RequestQty)-sum(xx.ShippedQty) as Variance,
		Concat((sum(xx.ShippedQty)*100)/sum(xx.RequestQty),'%') as PctFulfillment
from (
	select x.ShippedDate as PostingDate, x.DocumentNo as TransferOrderNo, x.TransferToCode as DestinationNo,
	   x.TransferToName as DestinationName, x.ItemNo, x.ItemName,x.DivisionCode,x.Inventoryposting 
	   ,sum(x.RequestQty) as RequestQty,sum(x.QuantityShipped) as ShippedQty
	from (
	select convert(varchar, h.DeliveryDate, 103) as DeviDate, convert(varchar, h.OrderDate, 103) as RequestDate, 
	   convert(varchar, h.EditDate, 103) as ShippedDate, h.ExternOrderKey as DocumentNo, h.OrderKey as RefLFDocumentNo, 
	   d.SKU as ItemNo, sku.Descr as ItemName, sku.Busr3 as DivisionCode, d.OriginalQty as RequestQty,
	   d.ShippedQty as QuantityShipped, d.OriginalQty-d.ShippedQty as Variance, (d.ShippedQty*100)/d.OriginalQty as PctPerformance,
	   h.ConsigneeKey as TransferToCode, h.C_Company as TransferToName ,sku.BUSR1 as Inventoryposting  
	from Orders h with (nolock)
	JOIN OrderDetail d with (nolock) ON h.StorerKey = d.StorerKey 
		and h.OrderKey = d.OrderKey 
		and h.ExternOrderKey = d.ExternOrderKey 
	JOIN SKU sku with (nolock) ON d.StorerKey = sku.StorerKey 
		and d.sku = sku.sku
	where h.StorerKey = 'YVESR'
	and h.Status = '9' and h.SOStatus = '9' and d.status = '9'
	and h.EditDate between  DATEADD(MONTH, DATEDIFF(MONTH,0,DATEADD(MONTH,-1,getdate()) ),0) and  DATEADD(d,-1, DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE()),0))
	) x group by x.ShippedDate, x.DocumentNo, x.TransferToCode,x.TransferToName, x.ItemNo, x.ItemName,x.DivisionCode,x.Inventoryposting
) xx group by xx.PostingDate, xx.ItemNo, xx.ItemName,xx.Inventoryposting,xx.DivisionCode

GO