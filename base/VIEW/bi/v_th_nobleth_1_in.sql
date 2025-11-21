SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 12-JAN-2021   Rungtham    1.0   Created									                     */
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_NOBLETH_1_IN]
AS
SELECT DISTINCT
   AL1.type,
   AL1.date,
   AL1.wms_doc_,
   AL1.ctx_doc_,
   AL1.ship_to_from,
   AL1.name,
   AL1.sku,
   AL1.descr,
   AL1.stock_status,
   AL1.cd_,
   AL1.brand,
   AL1.received_date,
   AL1.qty,
   AL1.uom,
   AL1.lottable01,
   AL1.principal,
   AL1.lot_no,
   AL1.mfg,
   AL1.id
FROM
   ( SELECT DISTINCT
         D0AL5.StorerKey,
         D0AL1.RECType,
         convert(varchar, D0AL1.ReceiptDate, 103),
         D0AL1.ReceiptKey,
         CASE WHEN
               ( D0AL1.RECType)= 'GRN'
           THEN
               D0AL2.ExternReceiptKey
           ELSE
               D0AL1.ExternReceiptKey
         END
        , CASE WHEN
               D0AL1.CarrierKey = 'CTXTH'
            THEN
               D0AL1.CarrierKey
            ELSE
               SUBSTRING ( D0AL1.CarrierKey, 4, 10 )
         END
        , D0AL5.Company
		  , D0AL2.Sku
		  , D0AL3.DESCR
		  , UPPER(D0AL2.Lottable01)
		  , D0AL2.Lottable02
		  , D0AL2.Lottable03
		  , D0AL2.Lottable05
		  , Sum(D0AL2.QtyReceived)
		  , UPPER(D0AL4.PackUOM3)
		  , D0AL2.Lottable01
		  , D0AL2.Lottable06
		  , D0AL2.Lottable04
		  , D0AL2.Id
      FROM dbo.V_RECEIPT D0AL1
         LEFT OUTER JOIN   dbo.V_STORER D0AL5  ON (D0AL1.CarrierKey = D0AL5.StorerKey)
		   JOIN dbo.V_RECEIPTDETAIL D0AL2 on  D0AL1.ReceiptKey = D0AL2.ReceiptKey AND D0AL1.StorerKey = D0AL2.StorerKey
		   JOIN dbo.V_SKU D0AL3 on   D0AL2.Sku = D0AL3.Sku AND D0AL2.StorerKey = D0AL3.StorerKey
		   JOIN dbo.V_PACK D0AL4 on D0AL3.PACKKey = D0AL4.PackKey
      WHERE
       (D0AL1.StorerKey IN ('CITYFR', 'NOBLETH')
        AND D0AL1.ASNStatus = '9'
        AND D0AL1.EditDate >= convert(varchar, getdate() - 1, 112)
        AND D0AL1.EditDate < convert(varchar, getdate(), 112)
        AND D0AL2.QtyReceived > 0)
      GROUP BY
         D0AL5.StorerKey, D0AL1.RECType, convert(varchar, D0AL1.ReceiptDate, 103), D0AL1.ReceiptKey,
         CASE WHEN
               (D0AL1.RECType) = 'GRN'
           THEN
               D0AL2.ExternReceiptKey
           ELSE
               D0AL1.ExternReceiptKey
         END
      , CASE WHEN
               D0AL1.CarrierKey = 'CTXTH'
           THEN
               D0AL1.CarrierKey
           ELSE
               SUBSTRING ( D0AL1.CarrierKey, 4, 10 )
         END
       , D0AL5.Company
		 , D0AL2.Sku
		 , D0AL3.DESCR
		 , UPPER(D0AL2.Lottable01)
		 , D0AL2.Lottable02
		 , D0AL2.Lottable03
		 , D0AL2.Lottable05
		 , UPPER(D0AL4.PackUOM3)
		 , D0AL2.Lottable01
		 , D0AL2.Lottable06
		 , D0AL2.Lottable04
		 , D0AL2.Id
     ) AL1
	  (principal, type, date, wms_doc_, ctx_doc_, ship_to_from, name, sku, descr, stock_status, cd_, brand, received_date, qty, uom, lottable01, lot_no, mfg, id)

GO