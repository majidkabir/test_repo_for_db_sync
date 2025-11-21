SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
--[TH] - JReport_Add_View in PRD Catalog  https://jiralfl.atlassian.net/browse/WMS-18745
/* Date         Author      Ver.  Purposes									                  */
/* 12-Jan-2022  gywong      1.0   Created									                     */
/***************************************************************************************/
CREATE   VIEW [BI].[V_TH_DIVERSEY_INBOUND]
AS
SELECT
  CONVERT(date, AL1.ReceiptDate) as ReceiptDate,
  AL1.ExternReceiptKey,
  AL1.AddDate,
  AL1.DOCTYPE,
  AL1.Status,
  AL2.Sku,
  AL3.DESCR,
  QtyExpected=SUM(AL2.QtyExpected),
  QtyReceived=SUM(AL2.QtyReceived),
  OpenQty=SUM(AL1.OpenQty),
  AL1.StorerKey

FROM dbo.RECEIPT AL1 WITH (NOLOCK)
LEFT OUTER JOIN dbo.RECEIPTDETAIL AL2 WITH (NOLOCK) ON AL1.StorerKey = AL2.StorerKey AND AL1.ReceiptKey = AL2.ReceiptKey
LEFT OUTER JOIN dbo.SKU AL3 WITH (NOLOCK) ON AL2.StorerKey = AL3.StorerKey AND AL2.Sku = AL3.Sku

WHERE AL1.StorerKey IN ('06700', '06701')
AND AL1.Status IN ('0', '9')
AND AL1.AddDate >= CONVERT (DATE,DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) )
AND AL1.AddDate <= CONVERT (DATE,DATEADD (DD, 1,GETDATE()))

GROUP BY CONVERT(date, AL1.ReceiptDate),
         AL1.ExternReceiptKey,
         AL1.AddDate,
         AL1.DOCTYPE,
         AL1.Status,
         AL2.Sku,
         AL3.DESCR,
         AL1.StorerKey
--ORDER BY 1, 2

GO