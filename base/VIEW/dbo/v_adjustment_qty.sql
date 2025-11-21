SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_Adjustment_Qty]
as
select a.facility, a.customerrefno, a.effectivedate, a.adjustmenttype, ad.storerkey, ad.sku, ad.lot, s.skugroup,
	ad.qty,
             pos_adj_qty = case when ad.qty > 0 then ad.qty else 0 end,
	neg_adj_qty = case when ad.qty < 0 then ad.qty else 0 end
from adjustmentdetail ad (nolock), adjustment a (nolock), sku s (nolock)
where a.adjustmentkey = ad.adjustmentkey and ad.storerkey = s.storerkey and ad.sku = s.sku





GO