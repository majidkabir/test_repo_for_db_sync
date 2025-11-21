SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_TRUECTH-SOH_BDC02] AS
SELECT
   X.StorerKey AS 'Client',
   S.SKUGROUP,
   X.Sku,
   S.DESCR,
   X.QtyAllocated,
   X.QtyPicked,
   L.Status,
   P.PackUOM1 AS 'Carton UOM',
   P.CaseCnt,
   P.PackUOM3 AS 'Pick UOM(Smallest)',
   P.PackUOM9 AS 'UOM(forSAP)',
   P.OtherUnit2,
   S.CLASS,
   X.Qty,
   A.Lottable02 AS 'BatchNo.',
   A.Lottable04 AS 'Expiry Date',
   A.Lottable05 AS 'Receipt Date',
   L.Loc,
   Case
      when
         (
            L.Status
         )
         = 'HOLD'
      then
(X.Qty) - (
         Case
            when
               (
                  L.Loc
               )
               = 'TCOVER7020'
            then
(X.Qty) - (X.QtyAllocated) - (X.QtyPicked)
            else
               '0'
         end
)
         Else
            '0'
   End AS 'Qty on Receiving Location'
,
   Case
      when
         (
            L.Loc
         )
         = 'TCOVER7020'
      then
(X.Qty) - (X.QtyAllocated) - (X.QtyPicked)
      else
         '0'
   end AS 'AvailableQty'
FROM
   dbo.LOTxLOCxID X with (nolock)
JOIN dbo.SKU S with (nolock) ON X.StorerKey = S.StorerKey
      AND X.Sku = S.Sku
JOIN dbo.LOC L with (nolock) ON X.Loc = L.Loc
JOIN dbo.LOTATTRIBUTE A with (nolock) ON X.Lot = A.Lot
      AND X.StorerKey = A.StorerKey
      AND X.Sku = A.Sku
JOIN dbo.PACK P with (nolock) ON S.PACKKey = P.PackKey
WHERE
   (
(X.StorerKey = 'TRUECTH'
      AND L.Facility = 'BDC02')
   )

GO