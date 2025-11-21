SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 28-Dec-2021   Rungtham    1.0   Created									                     */												
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_CTXTH_2_PDL_InOut report_in]
AS
SELECT DISTINCT
   case
      when
         (
            AL1.ExternReceiptKey
         )
         like 'CD%' 
      then
         'IMPORT' 
      when
         (
            AL1.ExternReceiptKey
         )
         like '%LF%' 
      then
         'OTHER' 
      ELSE
         'PDL' 
   END as 'Type'
, convert(varchar, AL1.EditDate, 103) as 'Date' , AL1.ReceiptKey as 'WMS Doc#', AL1.ExternReceiptKey as 'CTX Doc#', AL2.UserDefine01 as 'Document No#', 
   case
      when
         AL1.CarrierKey = 'CTXTH' 
      then
         AL1.CarrierKey 
      ELSE
         SUBSTRING ( AL1.CarrierKey, 4, 10 ) 
   END as 'Ship to/from'
, AL5.Company as 'Name', AL2.Sku as 'Sku', AL3.DESCR as 'Descr', UPPER(AL2.Lottable01) as 'Stock Status', AL2.Lottable02 as 'CD#', AL2.Lottable03 as 'Brand', 
 AL2.Lottable05 as 'Received Date', Sum(AL2.QtyReceived) as 'Qty', UPPER(AL4.PackUOM3) as 'UOM', AL4.OtherUnit2 as 'Qty Conversion to Piece', AL3.Style as 'Item Group Descr', AL1.Signatory as 'Job#' 
FROM
   dbo.V_RECEIPTDETAIL AL2 WITH (NOLOCK)
JOIN dbo.V_SKU AL3 WITH (NOLOCK) ON AL2.Sku = AL3.Sku AND AL2.StorerKey = AL3.StorerKey 
JOIN dbo.V_PACK AL4 WITH (NOLOCK) ON AL3.PACKKey = AL4.PackKey
JOIN dbo.V_RECEIPT AL1 WITH (NOLOCK) ON AL1.ReceiptKey = AL2.ReceiptKey 
      AND AL1.StorerKey = AL2.StorerKey 
   LEFT OUTER JOIN
      dbo.V_STORER AL5 WITH (NOLOCK)
      ON (AL1.CarrierKey = AL5.StorerKey) 
WHERE
(AL1.StorerKey = 'CTXTH' 
      AND AL1.ASNStatus = '9' 
      AND AL1.EditDate >= convert(varchar, getdate() - 1, 112) 
      and AL1.EditDate < convert(varchar, getdate(), 112) 
      AND AL2.QtyReceived > 0 
      AND AL1.CarrierKey = 'CTXTH')
GROUP BY
   case
      when
         (
            AL1.ExternReceiptKey
         )
         like 'CD%' 
      then
         'IMPORT' 
      when
         (
            AL1.ExternReceiptKey
         )
         like '%LF%' 
      then
         'OTHER' 
      ELSE
         'PDL' 
   END
, convert(varchar, AL1.EditDate, 103), AL1.ReceiptKey, AL1.ExternReceiptKey, AL2.UserDefine01, 
   case
      when
         AL1.CarrierKey = 'CTXTH' 
      then
         AL1.CarrierKey 
      ELSE
         SUBSTRING ( AL1.CarrierKey, 4, 10 ) 
   END
, AL5.Company, AL2.Sku, AL3.DESCR, UPPER(AL2.Lottable01), AL2.Lottable02, AL2.Lottable03, AL2.Lottable05, UPPER(AL4.PackUOM3), AL4.OtherUnit2, AL3.Style, AL1.Signatory

GO