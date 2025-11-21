SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 28-Dec-2021   Rungtham   1.0   Created									                     */
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_ADIDAS_Daily_Return_Receipt0003]
AS
SELECT DISTINCT
  AL2.ReceiptKey,
  AL2.ExternReceiptKey,
  AL2.Sku,
  AL2.ExternLineNo,
  AL1.RETAILSKU,
  AL1.DESCR,
  AL2.QtyExpected,
  AL2.BeforeReceivedQty,
  AL2.UOM,
  'adidas'as Storer,
  AL1.Color,
  AL1.Size,
  AL2.EditDate,
  AL3.Facility,
  AL2.ToLoc,
  (AL2.BeforeReceivedQty) - (AL2.QtyExpected) as PickQTY,
  AL1.MANUFACTURERSKU,
  AL3.ReceiptDate,
  LOWER(AL3.StorerKey) as StorerKey,
  AL3.RECType,
  AL1.SKUGROUP,
  AL3.FinalizeDate,
  AL1.Style,
  AL1.BUSR10,
  '' as xx,
  AL3.AddDate
FROM dbo.V_SKU AL1 WITH (NOLOCK)
JOIN dbo.V_RECEIPTDETAIL AL2 WITH (NOLOCK) ON AL2.StorerKey = AL1.StorerKey AND AL2.Sku = AL1.Sku
JOIN dbo.V_RECEIPT AL3 WITH (NOLOCK) ON AL2.ReceiptKey = AL3.ReceiptKey
WHERE
AL2.StorerKey = 'ADIDAS'
AND AL3.FinalizeDate > CONVERT(nvarchar, GETDATE() - 2, 102)
AND AL3.FinalizeDate <= CONVERT(nvarchar, GETDATE() - 1, 102)
AND AL3.RECType = '0003'
AND AL3.DOCTYPE = 'R'

GO