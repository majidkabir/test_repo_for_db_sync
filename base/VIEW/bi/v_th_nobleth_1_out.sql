SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 12-JAN-2021   Rungtham    1.0   Created									                     */
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_NOBLETH_1_OUT]
AS
SELECT
   AL2.type,
   AL2.date,
   AL2.wms_doc_,
   AL2.ctx_doc_,
   AL2.ship_to_from,
   AL2.name,
   AL2.sku,
   AL2.descr,
   AL2.stock_status,
   AL2.cd_,
   AL2.brand,
   AL2.received_date,
   AL2.qty,
   AL2.uom,
   AL2.lottable01,
   AL2.principal,
   AL2.lot_no,
   AL2.mfg,
   AL2.id
FROM
   ( SELECT DISTINCT
         D1AL3.StorerKey,
         CASE WHEN
           (CASE WHEN D1AL5.ConsigneeKey = 'CTXTH'
               THEN D1AL5.ConsigneeKey
             ELSE SUBSTRING(D1AL5.ConsigneeKey, 4, 10)
              END)
          IN ('0908', '0919')
          THEN 'TESCO'
          WHEN (CASE WHEN D1AL5.ConsigneeKey = 'CTXTH'
                   THEN D1AL5.ConsigneeKey
                ELSE SUBSTRING(D1AL5.ConsigneeKey, 4, 10)
                END)
                IN ('CTXTH' , 'COPACK')
                THEN 'PDL'
                ELSE 'OTHERS'
          END
         , convert(varchar, D1AL5.EditDate, 103)
			, D1AL5.OrderKey
			, D1AL5.ExternOrderKey
			, CASE WHEN
               D1AL5.ConsigneeKey = 'CTXTH'
            THEN
               D1AL5.ConsigneeKey
            ELSE
               Substring(D1AL5.ConsigneeKey, 4, 10)
            END
         , D1AL3.Company
			, D1AL6.Sku
			, D1AL1.DESCR
			, Upper(D1AL4.Lottable01)
			, D1AL4.Lottable02
			, D1AL4.Lottable03
			, D1AL4.Lottable05
			, sum (D1AL6.Qty * - 1)
			, Upper(D1AL2.PackUOM3)
			, D1AL4.Lottable01
			, D1AL4.Lottable06
			, D1AL4.Lottable04
			, D1AL6.ID
      FROM dbo.V_STORER D1AL3
		 LEFT OUTER JOIN  dbo.V_ORDERS D1AL5 ON (D1AL5.ConsigneeKey = D1AL3.StorerKey)
       LEFT OUTER JOIN  dbo.V_PICKDETAIL D1AL6 ON (D1AL5.OrderKey = D1AL6.OrderKey )
		 JOIN dbo.V_SKU D1AL1 on D1AL6.Sku = D1AL1.Sku AND D1AL6.Storerkey = D1AL1.StorerKey
		 JOIN dbo.V_PACK D1AL2 on D1AL1.PACKKey = D1AL2.PackKey
		 JOIN dbo.V_LOTATTRIBUTE D1AL4 on  D1AL4.Sku = D1AL6.Sku AND D1AL6.Lot = D1AL4.Lot AND D1AL6.Storerkey = D1AL4.StorerKey
      WHERE
      (D1AL5.StorerKey IN ('CITYFR', 'NOBLETH')
       AND  D1AL5.EditDate >= convert(varchar, getdate() - 1, 112)
       and  D1AL5.EditDate < convert(varchar, getdate(), 112)
       AND D1AL5.Status = '9')
      GROUP BY
         D1AL3.StorerKey,
         CASE WHEN
          ( CASE WHEN D1AL5.ConsigneeKey = 'CTXTH'
                THEN
                  D1AL5.ConsigneeKey
                ELSE
                  Substring(D1AL5.ConsigneeKey, 4, 10)
            END)
           IN('0908', '0919')
          THEN 'TESCO'
           WHEN (CASE WHEN
                        D1AL5.ConsigneeKey = 'CTXTH'
                   THEN
                        D1AL5.ConsigneeKey
                   ELSE
                        Substring(D1AL5.ConsigneeKey, 4, 10)
                  END)
            IN ('CTXTH' , 'COPACK')
            THEN 'PDL'
            ELSE
               'OTHERS'
           END
          , convert(varchar, D1AL5.EditDate, 103)
			 , D1AL5.OrderKey, D1AL5.ExternOrderKey
			 , CASE WHEN
               D1AL5.ConsigneeKey = 'CTXTH'
            THEN
               D1AL5.ConsigneeKey
            ELSE
               Substring(D1AL5.ConsigneeKey, 4, 10)
           END
          , D1AL3.Company
			 , D1AL6.Sku
			 , D1AL1.DESCR
			 , Upper(D1AL4.Lottable01)
			 , D1AL4.Lottable02
			 , D1AL4.Lottable03
			 , D1AL4.Lottable05
			 , Upper(D1AL2.PackUOM3)
			 , D1AL4.Lottable01
			 , D1AL4.Lottable06
			 , D1AL4.Lottable04
			 , D1AL6.ID
     ) AL2
	  (principal, type, date, wms_doc_, ctx_doc_, ship_to_from, name, sku, descr, stock_status, cd_, brand, received_date, qty, uom, lottable01, lot_no, mfg, id)

GO