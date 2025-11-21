SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-13_Pick Sum by ITEM] as 
select xx.PostingDate, xx.ItemNo, xx.ItemName,xx.posting_group,xx.Division_code, sum(xx.RequestQty) as RequestQty,
	   sum(xx.ShippedQty) as ShippedQty, sum(xx.RequestQty)-sum(xx.ShippedQty) as Variance,
	   Concat((sum(xx.ShippedQty)*100)/sum(xx.RequestQty),'%') as PctFulfillment
from (

select convert(varchar, h.EditDate, 103) as PostingDate, 
	   d.SKU as ItemNo, sku.Descr as ItemName,sku.Busr1 as posting_group  ,sku.Busr3 as Division_code, d.OriginalQty as RequestQty,
	   d.ShippedQty as ShippedQty, d.OriginalQty-d.ShippedQty as Variance
	   
from Orders h with (nolock)
JOIN OrderDetail d with (nolock) ON h.StorerKey = d.StorerKey 
	and h.OrderKey = d.OrderKey 
	and h.ExternOrderKey = d.ExternOrderKey 
JOIN SKU sku with (nolock) ON d.StorerKey = sku.StorerKey 
	and d.sku = sku.sku
where h.StorerKey = 'YVESR'
and h.Status = '9' and h.SOStatus = '9' and d.Status = '9'
and convert(varchar, h.EditDate, 103) = convert(varchar, GetDate()-1, 103)
and h.type in ('0','B2S') 

)  xx group by xx.PostingDate, xx.ItemNo, xx.ItemName,xx.posting_group,xx.Division_code


GO