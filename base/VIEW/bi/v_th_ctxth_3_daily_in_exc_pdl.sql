SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 12-JAN-2021   Rungtham    1.0   Created									                     */												
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_CTXTH_3_DAILY_IN_EXC_PDL]
AS
SELECT DISTINCT
   AL1.RECType as'Type',
   convert(varchar, AL1.ReceiptDate, 103) as 'DATE'
  ,AL1.ReceiptKey as 'WMS Doc#'
  ,CASE WHEN (AL1.RECType) = 'GRN' 
      THEN AL2.ExternReceiptKey 
      ELSE AL1.ExternReceiptKey 
   END as 'CTX Doc#'
  ,CASE WHEN AL1.CarrierKey = 'CTXTH' 
      THEN AL1.CarrierKey 
      ELSE SUBSTRING ( AL1.CarrierKey, 4, 10 ) 
   END as 'Ship to/from'
  , AL5.Company as 'Name'
  , AL2.Sku as 'SKU'
  , AL3.DESCR as 'Descr'
  , UPPER(AL2.Lottable01) as 'Stock Satus'
  , AL2.Lottable02 as 'CD#'
  , AL2.Lottable03 as 'Brand'
  , AL2.Lottable05 as 'Received Date'
  , Sum(AL2.QtyReceived) as 'Qty'
  , UPPER(AL4.PackUOM3) as 'UOM' 
FROM dbo.V_RECEIPT AL1 
   LEFT OUTER JOIN  dbo.V_STORER AL5   ON (AL1.CarrierKey = AL5.StorerKey) 
   JOIN dbo.V_RECEIPTDETAIL AL2 on  AL1.ReceiptKey = AL2.ReceiptKey  AND AL1.StorerKey = AL2.StorerKey 
   JOIN dbo.V_SKU AL3 on AL2.Sku = AL3.Sku  AND AL2.StorerKey = AL3.StorerKey 
   JOIN dbo.V_PACK AL4 on AL3.PACKKey = AL4.PackKey
WHERE
(AL1.StorerKey = 'CTXTH' 
      AND AL1.ASNStatus = '9' 
      AND AL1.EditDate >= convert(varchar, getdate() - 1, 112) 
      and AL1.EditDate < convert(varchar, getdate(), 112) 
      AND AL2.QtyReceived > 0 
      AND AL1.Facility = 'FC')
GROUP BY
   AL1.RECType, convert(varchar, AL1.ReceiptDate, 103), AL1.ReceiptKey, 
   CASE WHEN (AL1.RECType) = 'GRN' 
      THEN AL2.ExternReceiptKey 
      ELSE AL1.ExternReceiptKey 
   END
, CASE WHEN AL1.CarrierKey = 'CTXTH' 
     THEN AL1.CarrierKey 
     ELSE SUBSTRING ( AL1.CarrierKey, 4, 10 ) 
   END
, AL5.Company, AL2.Sku, AL3.DESCR, UPPER(AL2.Lottable01), AL2.Lottable02, AL2.Lottable03, AL2.Lottable05, UPPER(AL4.PackUOM3)

GO