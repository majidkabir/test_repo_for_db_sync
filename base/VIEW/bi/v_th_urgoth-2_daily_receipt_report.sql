SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
--TH-Create VIEW on Database (THWMS) on PROD  https://jiralfl.atlassian.net/browse/WMS-18766
/* Date         Author      Ver.  Purposes									                  */
/* 14-Jan-2022  gywong      1.0   Created									                     */
/***************************************************************************************/
CREATE   VIEW [BI].[V_TH_URGOTH-2_Daily_Receipt_Report]
AS
SELECT
   AL1.StorerKey,
   convert(varchar, AL4.EditDate, 103) AS 'Receipt Date',
   AL1.CarrierName,
   AL1.CarrierKey,
   AL4.Sku,
   AL2.DESCR,
   AL4.UOM,
   AL1.ExternReceiptKey,
   Sum(AL4.QtyExpected) AS 'Qty Expected',
   Sum(AL4.QtyReceived) AS 'Qty Received',
   AL4.EditDate,
   AL4.Pallet,
   AL4.ToId,
   AL1.ReceiptKey,
   AL1.POKey,
   AL1.CarrierAddress1,
   AL1.CarrierAddress2,
   AL1.WarehouseReference,
   AL1.CarrierReference,
   AL4.Lottable01,
   AL4.Lottable02,
   AL4.Lottable03,
   AL4.Lottable04,
   AL4.Lottable05

FROM dbo.V_RECEIPT AL1 WITH (NOLOCK)
JOIN dbo.V_RECEIPTDETAIL AL4 WITH (NOLOCK) ON AL1.ReceiptKey = AL4.ReceiptKey and AL1.StorerKey = AL4.StorerKey
JOIN dbo.V_SKU AL2 WITH (NOLOCK) ON AL4.StorerKey = AL2.StorerKey and  AL4.Sku = AL2.Sku

WHERE AL1.StorerKey = 'URGOTH'
AND AL1.Status = '9'
AND AL4.QtyReceived > 0
AND  AL1.EditDate >= convert(varchar, getdate() - 1, 112)
AND  AL1.EditDate < convert(varchar, getdate(), 112)

GROUP BY
   AL1.StorerKey,
   convert(varchar, AL4.EditDate, 103),
   AL1.CarrierName,
   AL1.CarrierKey,
   AL4.Sku,
   AL2.DESCR,
   AL4.UOM,
   AL1.ExternReceiptKey,
   AL4.EditDate,
   AL4.Pallet,
   AL4.ToId,
   AL1.ReceiptKey,
   AL1.POKey,
   AL1.CarrierAddress1,
   AL1.CarrierAddress2,
   AL1.WarehouseReference,
   AL1.CarrierReference,
   AL4.Lottable01,
   AL4.Lottable02,
   AL4.Lottable03,
   AL4.Lottable04,
   AL4.Lottable05

GO