SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_NUTRA_Stock_Balance] AS
SELECT
   X.Sku,
   S.DESCR,
   A.Lottable04,
   A.Lottable05,
   S.ALTSKU,
   S.ShelfLife,
   S.BUSR1,
   A.Lottable02,
   X.Qty,
   GETDATE() AS 'Today',
  DATEDIFF ( dy,
   (
      GETDATE()
   )
,
   (
      A.Lottable04
   )
) AS 'RemainingLife(Days)',
   Case
      when
         L.LocationFlag in
         (
            'HOLD',
            'DMG'
         )
      then
         'HOLD'
      Else
         'GOOD'
   End AS 'ProductQuality/Status'
,
   Case
      when
         X.Loc in
         (
            'FBTHOLD'
         )
      then
         'HOLD QC Check'
      when
         X.Loc in
         (
            'FBTDMG'
         )
      then
         'Damage Product'
      when
         X.Loc like 'THAW%'
      then
         'Pending Thaw Process'
      else
         ' '
   end AS 'HoldReason'
, X.Loc, P.PackKey, P.CaseCnt, X.QtyAllocated, X.QtyPicked,
   Case
      when
         (
            Case
               when
                  L.LocationFlag in
                  (
                     'HOLD', 'DMG'
                  )
               then
                  'HOLD'
               Else
                  'GOOD'
            End
         )
         = 'HOLD'
      then
(X.Qty / '1' )
      Else
         '0'
   end AS 'Qtyhold:EA'
FROM
   dbo.LOTxLOCxID X with (nolock)
JOIN dbo.LOTATTRIBUTE A with (nolock) ON X.StorerKey = A.StorerKey
      AND X.Lot = A.Lot
      AND X.Sku = A.Sku
JOIN dbo.SKU S with (nolock) ON X.StorerKey = S.StorerKey
      AND X.Sku = S.Sku
JOIN dbo.PACK P with (nolock) ON S.PACKKey = P.PackKey
JOIN dbo.LOC L with (nolock) ON X.Loc = L.Loc
WHERE
   (
(X.StorerKey = 'NUTRA'
      AND X.Qty > 0
      AND L.Facility = 'BDC02')
   )

GO