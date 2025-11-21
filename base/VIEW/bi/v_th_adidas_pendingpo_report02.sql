SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 28-Dec-2021   Rungtham    1.0   Created									                     */
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_ADIDAS_PendingPO_Report02]
AS
SELECT DISTINCT
  AL2.ExternReceiptKey,
  AL1.DESCR,
  AL2.EditDate,
  AL3.ReceiptDate,
  AL3.StorerKey,
  AL4.AddDate,
  AL4.PODate,
  AL2.Sku,
  AL3.EditWho,
  AL4.AddWho,
  '' AS Clo1,
  '' AS Clo2,
  AL2.QtyExpected,
  AL2.QtyReceived,
  AL3.ASNStatus,
  CASE
    WHEN AL3.ASNStatus = '0' THEN 'OPEN'
    WHEN AL3.ASNStatus = '9' THEN 'CLOSED'
    WHEN AL3.ASNStatus IN ('1', '2') THEN 'Receiving in Process'
    WHEN AL3.ASNStatus = 'CANC' THEN 'CANCELLED'
    ELSE AL3.ASNStatus
  END AS status,
  AL3.Facility
FROM dbo.V_SKU AL1 WITH (NOLOCK)
JOIN dbo.V_RECEIPTDETAIL AL2 WITH (NOLOCK) ON AL2.StorerKey = AL1.StorerKey AND AL2.Sku = AL1.Sku
JOIN dbo.V_RECEIPT AL3 WITH (NOLOCK) ON AL2.ReceiptKey = AL3.ReceiptKey
JOIN dbo.V_PO AL4 WITH (NOLOCK) ON AL4.StorerKey = AL3.StorerKey AND AL3.ExternReceiptKey = AL4.ExternPOKey
WHERE
  AL2.StorerKey = 'ADIDAS'


GO