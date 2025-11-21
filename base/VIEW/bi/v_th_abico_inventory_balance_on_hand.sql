SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
--TH-Create VIEW on Database (THWMS) on PROD  https://jiralfl.atlassian.net/browse/WMS-18766
/* Date         Author      Ver.  Purposes									                  */
/* 14-Jan-2022  gywong      1.0   Created									                     */
/***************************************************************************************/
CREATE   VIEW [BI].[V_TH_ABICO_Inventory_Balance_On_Hand]
AS
SELECT
   X.StorerKey,
   L.Facility,
   X.Sku,
   S.SUSR3,
   S.DESCR,
   X.Lot,
   X.Loc,
   X.Id,
   Sum ( X.Qty ) AS 'QTY',
   Sum ( X.QtyAllocated ) AS 'QtyAllocated',
   Sum ( X.QtyPicked ) AS 'QtyPicked',
   P.Pallet,
   A.Lottable02,
   A.Lottable03,
   convert(varchar, A.Lottable04, 103) + ' ' + convert(varchar, A.Lottable04, 24) AS 'Expried',
   S.BUSR7,
   S.ALTSKU,
   P.CaseCnt,
   SUM ( X.QtyExpected ) AS 'QtyExpected',
   convert(varchar, A.Lottable05, 103) + ' ' + convert(varchar, A.Lottable05, 24) AS 'ReceiptDate',
   A.Lottable01
FROM dbo.LOTxLOCxID X WITH (nolock)
JOIN dbo.SKU S with (nolock) ON X.StorerKey = S.StorerKey AND X.Sku = S.Sku
JOIN dbo.PACK P with (nolock) ON S.PackKey = P.PACKKey
JOIN dbo.LOTATTRIBUTE A with (nolock) ON X.Lot = A.Lot AND X.StorerKey = A.StorerKey
JOIN dbo.LOC L with (nolock) ON X.Loc = L.Loc

WHERE X.StorerKey = 'ABICO'

GROUP BY
   X.StorerKey,
   L.Facility,
   X.Sku,
   S.SUSR3,
   S.DESCR,
   X.Lot,
   X.Loc,
   X.Id,
   P.Pallet,
   A.Lottable02,
   A.Lottable03,
   convert(varchar, A.Lottable04, 103) + ' ' + convert(varchar, A.Lottable04, 24),
   S.BUSR7,
   S.ALTSKU,
   P.CaseCnt,
   convert(varchar, A.Lottable05, 103) + ' ' + convert(varchar, A.Lottable05, 24),
   A.Lottable01

GO