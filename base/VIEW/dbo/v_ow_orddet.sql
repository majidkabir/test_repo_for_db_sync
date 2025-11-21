SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
  
  
  
  
  
  
  
CREATE View [dbo].[V_OW_OrdDet]  
As   
Select orderdetail.Storerkey,   
      orderdetail.orderkey,    
      orderdetail.ExternOrderkey,   
      orderdetail.ExternLineNo,  
      orderdetail.SKU,   
      OrderDetail.UOM,   
      Case WHEN OrderDetail.UOM = Pack.PackUOM1 Then IsNull((QtyAllocated+QtyPicked+ShippedQty/Pack.CaseCnt), 0)  
           WHEN OrderDetail.UOM = Pack.PackUOM2 Then IsNull((QtyAllocated+QtyPicked+ShippedQty/Pack.InnerPack),0)  
           WHEN OrderDetail.UOM = Pack.PackUOM4 Then IsNull((QtyAllocated+QtyPicked+ShippedQty/Pack.Pallet),0)  
           Else (QtyAllocated+QtyPicked+ShippedQty)   
      End As Qty  
From OrderDetail With (nolock)  
Inner Join Pack With (nolock)   
         On (OrderDetail.Packkey = Pack.PackKey)  
Inner Join StorerConfig (nolock)  
         On (Orderdetail.StorerKey = StorerConfig.StorerKey AND StorerConfig.ConfigKey = 'OWITF'  
             and StorerConfig.sValue = '1')  
Where OrderDetail.AddDate > '01 May 2002'  
  
  
  
  
  
  
  
GO