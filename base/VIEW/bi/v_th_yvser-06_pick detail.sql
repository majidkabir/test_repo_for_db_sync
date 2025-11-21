SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-06_Pick detail] as
select distinct convert(varchar, h.DeliveryDate, 103) as DeliveryDate,
convert(varchar, h.OrderDate, 103) as RequestDate,
       convert(varchar, h.EditDate, 103) as ShippedDate,
	   h.ExternOrderKey as DocumentNo,
	   h.OrderKey as RefLFDocumentNo,
       d.SKU as ItemNo,
	   sku.Descr as ItemName,
	   sku.Busr1 as postinggroup  ,
	   sku.Busr3 as DivisionCode,
          sum(pd.qty) as QuantityShipped, 
          lt.lottable02 as batch,
		  lt.lottable04 as ExpDate,
        h.ConsigneeKey as TransferToCode,
		h.C_Company as TransferToName
from pickdetail pd with (nolock)
left join OrderDetail d with (nolock) on pd.OrderKey=d.OrderKey and pd.sku=d.sku and pd.orderlinenumber=d.orderlinenumber
left join Orders h with (nolock) on h.OrderKey = pd.orderkey and h.orderkey=d.orderkey
left join SKU sku with (nolock) on d.sku=sku.sku and d.storerkey=sku.storerkey and pd.sku=sku.sku and pd.storerkey=sku.storerkey
left join Lotattribute lt with (nolock) on lt.lot=pd.lot and lt.storerkey=pd.storerkey and lt.sku = pd.sku and lt.storerkey=h.storerkey 
where h.StorerKey = 'YVESR' and h.Status = '9' and h.SOStatus = '9' and d.Status = '9' and pd.status='9'
and convert(varchar, h.EditDate, 103) = convert(varchar, GetDate()-1, 103)
--and pd.orderkey='0021715721' and pd.sku='67390'
and h.type in ('0','B2S')

 

group by convert(varchar, h.DeliveryDate, 103) , convert(varchar, h.OrderDate, 103) ,
       convert(varchar, h.EditDate, 103) , h.ExternOrderKey , h.OrderKey,d.SKU , sku.descr,sku.Busr1 ,sku.Busr3,
          lt.lottable02,lt.lottable04,h.ConsigneeKey , h.C_Company 


GO