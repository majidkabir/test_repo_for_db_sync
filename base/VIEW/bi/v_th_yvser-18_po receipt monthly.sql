SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-18_PO receipt Monthly] as 
select convert(varchar, h.UserDefine06, 103) as PostingDate, 
		convert(varchar, h.PODate, 103) as OrderDate, 
		convert(varchar, h.EffectiveDate, 103) as ExpectedReceiptDate, 
		convert(varchar, d.EditDate, 103) as ReceiptDate, 
	   h.ExternPOKey as DocumentNo, 
	   h.SellersReference as BuyFromVendorNo, 
	   h.SellerName as BuyFromVendorName, 
	   'LFWH' as ReceiptToLocation, 
	   h.UserDefine02 as OurReferencesNo, 
	   h.UserDefine03 as BLno, 
	   h.Notes as Remark, 
	   h.POKey as RefLFDocument
from PO h with (nolock)
JOIN Receipt d with (nolock) ON h.StorerKey = d.Storerkey 
	and h.ExternPOKey = d.ExternReceiptKey
where h.StorerKey = 'YVESR'
and d.Status = '9' and d.ASNStatus = '9' and d.RecType <> 'GRN' 
and d.EditDate between  DATEADD(MONTH, DATEDIFF(MONTH,0,DATEADD(MONTH,-1,getdate()) ),0) and  DATEADD(d,-1, DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE()),0))
group by convert(varchar, h.UserDefine06, 103), convert(varchar, h.PODate, 103), convert(varchar, h.EffectiveDate, 103), 
       convert(varchar, d.EditDate, 103), h.ExternPOKey, h.SellersReference, h.SellerName, h.UserDefine02, h.UserDefine03, h.Notes, h.POKey

GO