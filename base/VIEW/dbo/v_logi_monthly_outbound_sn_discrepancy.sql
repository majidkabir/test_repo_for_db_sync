SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_Logi_Monthly_Outbound_SN_Discrepancy]

AS

Select O.StorerKey,
       ShippedDate = MB.EditDate,
	   O.OrderKey,
	   O.ExternOrderKey,
	   OD.SKU,
	   Serialization_Status = S.BUSR7,
	   ShippedQty = SUM(OD.ShippedQty),
	   SerialNoQty = IsNull(SN.Qty, 0),
	   MasterCartonQty = P.CaseCnt,
	   Discrepancy = (Case When S.BUSR7 = 'Yes' Then SUM(OD.ShippedQty) - IsNull(SN.Qty, 0) Else 0 End),
	   ML_SN_QTY = IsNull(SN.ML_SN_QTY, 0),
	   CL_SN_QTY = IsNull(SN.CL_SN_QTY, 0),
	   _9L_SN_QTY = IsNull(SN._9L_SN_QTY, 0)

From dbo.V_MBOL MB with (nolock) Inner Join dbo.V_Orders O with (nolock) ON MB.MBOLKEY = O.MBOLKEY
     Inner Join dbo.V_OrderDetail OD with (nolock) ON OD.StorerKey = O.StorerKey and OD.OrderKey = O.OrderKey
	 Inner Join dbo.V_SKU S with (nolock) ON S.StorerKey = OD.StorerKey and S.SKU = OD.SKU

	 Left Outer Join

	 (Select SN.StorerKey, SN.OrderKey, SN.SKU,
			 ML_SN_QTY = SUM(Case When Right(SN.SerialNo, 1) = 'M' Then 1 Else 0 End),
			 CL_SN_QTY = SUM(Case When Right(SN.SerialNo, 1) = 'C' Then 1 Else 0 End),
			 _9L_SN_QTY = SUM(Case When Right(SN.SerialNo, 1) = '9' Then 1 Else 0 End),
			 SUM(SN.Qty) Qty
	 From dbo.V_SerialNo SN with (nolock)
	 Where SN.ExternStatus <> 'CANC'
	 Group By SN.StorerKey, SN.OrderKey, SN.SKU) SN ON SN.StorerKey = OD.StorerKey and SN.OrderKey = OD.OrderKey and SN.SKU = OD.SKU

	 Left Outer Join dbo.V_Pack P with (nolock) on S.PackKey = P.PackKey

Where O.StorerKey IN ('LOGITECH','LOGIEU')
And MB.Status = '9'
And MB.EditDate >= substring (convert(varchar,dateadd(month,-1,dateadd(day,-datepart(day,getdate())+1,getdate())),21),1,10)
And MB.EditDate < substring(convert(varchar,dateadd(day,-datepart(day,getdate())+1,getdate()),21),1,10)
--And MB.EditDate >= (Select Min(DateAdd(dd, 1, Convert(Date, Short))) From V_CodeLkup with (nolock)
--					Where ListName = 'LOGIFISCAL'
--					And StorerKey = O.StorerKey
--					And Short >= substring (convert(varchar,dateadd(month,-2,dateadd(day,-datepart(day,getdate())+1,getdate())),21),1,10)
--					And Short < substring (convert(varchar,dateadd(month,-1,dateadd(day,-datepart(day,getdate())+1,getdate())),21),1,10))

--And MB.EditDate < (Select Min(DateAdd(dd, 1, Convert(Date, Short))) From V_CodeLkup with (nolock)
--					Where ListName = 'LOGIFISCAL'
--					And StorerKey = O.StorerKey
--					And Short >= substring (convert(varchar,dateadd(month,-1,dateadd(day,-datepart(day,getdate())+1,getdate())),21),1,10)
--					And Short < substring (convert(varchar,dateadd(month,0,dateadd(day,-datepart(day,getdate())+1,getdate())),21),1,10))
Group By O.StorerKey,
         MB.EditDate,
		 S.BUSR7,
		 O.OrderKey,
		 O.ExternOrderKey,
	     OD.SKU,
		 SN.Qty,
		 P.CaseCnt,
		 ML_SN_QTY,
		 CL_SN_QTY,
		 _9L_SN_QTY




GO