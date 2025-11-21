SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
  
  
  
  
  
  
  
  
CREATE VIEW [dbo].[V_OWLPLAN]  
AS  
Select Distinct orderdetail.ExternOrderkey, orderdetail.ExternOrderkey ExternOrderkey2, orderdetail.ExternOrderkey ExternOrderKey3,  
ExternlineNo = CASE WHEN Isnull(Exe2Ow.NewLineNo,'') = '' THEN orderdetail.ExternLineNo Else NewLineNo End,  
orderdetail.Sku As Sku, orderdetail.UOM As UOM, orderdetail.Storerkey As Storerkey, '' As Lottable02, orderdetail.Status,  
'' As PickCode, OrderDetail.LoadKey, 0 As Qty, '' As Loc, LoadPlan.lpuserdefdate01 As Deliverydate, '' As NewLineNo, TL.TableName, Orders.Userdefine08 As DiscreteFlag, 'C' As ActionCode, TL.Adddate As TLDate  
From OrderDetail With (nolock)  
Inner Join TransmitLog TL With (nolock) On TL.Key1 = orderkey And TL.TableName = 'OWLPLAN' and TL.TransmitFlag = 9  
Left Outer Join Exe2OW_allocpickship Exe2Ow With (nolock) On (Exe2Ow.ExternOrderkey = Orderdetail.ExternOrderkey And Exe2Ow.ExternLineNo = Orderdetail.ExternLineno)  
Join Orders (NOLOCK) On (Orders.Orderkey = Orderdetail.Orderkey)  
Join LoadPlan With (nolock) On (Loadplan.Loadkey = Orders.Loadkey)  
WHERE 1 = CASE When Orders.Userdefine08 <> 'Y' AND Exe2Ow.NewLineNo <> '' Then 2 ELSE 1 END  
Group By orderdetail.ExternOrderKey, orderdetail.ExternLineNo, orderdetail.SKU, OrderDetail.UOM, orderdetail.Storerkey, orderdetail.Status,OrderDetail.LoadKey,TL.TableName, Loadplan.lpuserdefdate01, Orders.Userdefine08, NewLineNo, ActionCode, TL.AddDate  
 
  
  
  
  
  
  
GO