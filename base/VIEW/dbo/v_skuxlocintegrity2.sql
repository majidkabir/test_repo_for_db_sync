SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_SKUxLOCIntegrity2]
as
Select SKUxLOCIntegrity.SeqNo
,SKUxLOCIntegrity.Facility
,SKUxLOCIntegrity.Loc
,SKUxLOCIntegrity.StorerKey
,SKUxLOCIntegrity.SKU
,SKUxLOCIntegrity.ParentSKU
,SKUxLOCIntegrity.ID
,SKUxLOCIntegrity.Qty
,SKUxLOCIntegrity.EntryValue
,SKUxLOCIntegrity.Code
,SKUxLOCIntegrity.QtyCount
, skuxloc.QtyAllocated
, skuxloc.QtyPicked
from SKUxLOCIntegrity  (NOLOCK)
JOIN   skuxloc (NOLOCK) ON skuxloc.storerkey = SKUxLOCIntegrity.storerkey
AND skuxloc.sku = SKUxLOCIntegrity.EntryValue AND skuxloc.loc = SKUxLOCIntegrity.loc



GO