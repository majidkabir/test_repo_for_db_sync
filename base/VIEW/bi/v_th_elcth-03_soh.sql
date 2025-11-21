SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_ELCTH-03_SOH] as
SELECT
   X.Lot,
   X.Loc,
   X.Id as 'ID1',
   Case
      when
         X.StorerKey = 'ELCTH'
      then
         'AFF'
      when
         X.StorerKey = 'ELCEEM'
      then
         'EEM'
      else
         'N/A'
   end as 'Storer'
, S.DESCR, X.Sku, X.Qty, X.QtyAllocated, X.QtyPicked, X.QtyExpected, X.QtyReplen,
   Case
      when
         A.Lottable01 = 'X'
      then
         'QI'
      when
         A.Lottable01 = 'U'
      then
         'Unrestricted'
      when
         A.Lottable01 = 'R'
      then
         'Restricted'
      when
         A.Lottable01 = 'S'
      then
         'Blocked'
      when
         A.Lottable01 = 'T'
      then
         'Return'
      else
         'N/A'
   end as 'Store Status'
, A.Lottable02 as 'lot02', A.Lottable03, A.Lottable04 as 'lot04', L.CommingleLot, L.CommingleSku, A.Lottable05, L.LocationType, L.PutawayZone, L.LoseId, L.HOSTWHCODE, P.CaseCnt, P.PackUOM1, P.Pallet, P.PalletTI, P.PalletHI, S.ShelfLife, S.SKUGROUP, P.PackUOM5, L.LogicalLocation, L.Facility, X.Id, A.Lottable02, P.PackUOM3 as'UOM', P.PackUOM8, P.OtherUnit1, P.PackUOM9, P.OtherUnit2,
GETDATE() as 'Date' , A.Lottable04, DATEDIFF ( dy,
   (
      GETDATE()
   )
,
   (
      A.Lottable04
   )
) as 'Aging', X.StorerKey, P.PackUOM3
FROM dbo.LOTxLOCxID X with (nolock)
JOIN dbo.LOC L with (nolock) ON X.Loc = L.Loc
JOIN dbo.LOTATTRIBUTE A with (nolock) ON X.Lot = A.Lot
JOIN dbo.SKU S with (nolock) ON X.Sku = S.Sku
      AND X.StorerKey = S.StorerKey
JOIN dbo.PACK P with (nolock) ON S.PACKKey = P.PackKey
WHERE X.StorerKey = 'ELCTH'
AND X.Qty > 0
AND L.Facility = '3101E'

GO