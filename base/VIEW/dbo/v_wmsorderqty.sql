SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
  
  
  
  
  
  
  
  
CREATE view [dbo].[V_WMSOrderQTY]  
AS  
select externorderkey, externlineno, sku,   
CASE UOM WHEN Packuom1 THEN (qtyallocated+qtypicked+shippedqty) / casecnt  
         WHEN Packuom2 Then (qtyallocated+qtypicked+shippedqty) / innerpack  
         WHEN Packuom3 Then (qtyallocated+qtypicked+shippedqty)  
         WHEN Packuom4 Then (qtyallocated+qtypicked+shippedqty) / pallet  
END AS 'Qty'  
from orderdetail (nolock)  
   JOIN PACK (NOLOCK) ON (PACK.PackKey = OrderDetail.PackKey)  
   JOIN TransmitLog (NOLOCK) ON (TransmitLog.Key1 = OrderDetail.OrderKey AND   
                                 TransmitLog.TransmitFlag = '9' AND  
                                 TransmitLog.TableName = 'OWORDALLOC')  
  
  
  
  
  
  
GO