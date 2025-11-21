SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-05_Order Not Pick] as
select
   convert(varchar, O.EffectiveDate, 103) as 'OrderDate',
   convert(varchar, O.OrderDate, 103) as 'RequestDate',
   O.ExternOrderKey as 'TransferOrderNo',
   O.ConsigneeKey as 'TransferToCode',
   O.C_Company as 'TransferToName',
   OD.UserDefine01 as 'Remark',
   OD.Notes as 'ReasonDesc',
   O.SequenceNo as 'PriorityTransferTo',
   O.Priority as 'Partner',
   O.Status,
   datediff(dd, O.OrderDate, GetDate()) as 'CountOfDay' 
from
   Orders O with (nolock)
JOIN OrderDetail OD with (nolock) ON O.StorerKey = OD.StorerKey 
   and O.OrderKey = OD.OrderKey 
   and O.ExternOrderKey = OD.ExternOrderKey 
JOIN SKU S with (nolock) ON OD.StorerKey = S.StorerKey 
   and OD.sku = S.sku 
where
   O.StorerKey = 'YVESR' 
   and O.Status not in 
   (
      '9',
      'CANC'
   )
   and O.SOStatus not in 
   (
      '9',
      'CANC'
   )
   and convert(varchar, O.OrderDate, 112) <= convert(varchar, GetDate() - 1, 112) 
   and O.BillToKey = 'LFWH' 
group by
   convert(varchar, O.OrderDate, 103),
   convert(varchar, O.EffectiveDate, 103),
   O.ExternOrderKey,
   O.ConsigneeKey,
   O.C_Company,
   OD.UserDefine01,
   OD.Notes,
   O.SequenceNo,
   O.Priority,
   O.Status,
   datediff(dd, O.OrderDate, GetDate()) 

GO