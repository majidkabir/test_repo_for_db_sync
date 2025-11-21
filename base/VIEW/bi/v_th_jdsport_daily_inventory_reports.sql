SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_JDSPORT_Daily_Inventory_Reports] AS
SELECT
   S.StorerKey,
   L.HOSTWHCODE,
   S.MANUFACTURERSKU,
   S.ALTSKU,
   S.RETAILSKU,
   L.Facility,
   S.Style,
   S.Color,
   S.Size,
   S.SKUGROUP,
   S.SkuStatus,
   S.PACKKey,
   P.CaseCnt,
   P.PackUOM3,
   X.Id,
   L.LocationType,
   L.LocationCategory,
   L.Status,
   L.PutawayZone,
   L.PickZone,
   S.Sku,
   X.Lot,
   X.Loc,
   S.DESCR,
   X.Qty,
   X.QtyAllocated,
   X.QtyPicked,
   Case
      when
         S.SKUGROUP = 'T'
      Then
         'T_Textiles'
      when
         S.SKUGROUP = 'F'
      Then
         'F_Footwear'
      when
         S.SKUGROUP = 'W'
      then
         'W_Accessories'
      else
         ' '
   end AS 'Prodgroup'
, S.BUSR6, S.BUSR2, A.Lottable03 AS 'Manufacture', P.PackUOM3 AS 'Base UOM',
   (
      X.Qty
   )
   - ((X.QtyAllocated) + (X.QtyPicked))AS 'QtyAvailable', A.Lottable01, A.Lottable02, A.Lottable09, A.Lottable06, A.Lottable04, P.PackUOM1, A.Lottable03, A.Lottable05, A.Lottable07, A.Lottable08, A.Lottable10
FROM
   dbo.LOTxLOCxID X  with (nolock)
RIGHT OUTER JOIN dbo.SKU S with (nolock) ON X.Sku = S.Sku
	  AND X.StorerKey = S.StorerKey
JOIN dbo.LOTATTRIBUTE A with (nolock) ON X.StorerKey = A.StorerKey
      AND X.Lot = A.Lot
	  AND X.Sku = A.Sku
JOIN dbo.LOC L with (nolock) ON X.Loc = L.Loc
JOIN dbo.PACK P with (nolock) ON S.PACKKey = P.PackKey
WHERE
   (
(S.StorerKey = 'JDSPORTS'
      AND X.Qty > 0)
   )

GO