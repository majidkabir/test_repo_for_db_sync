SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 12-JAN-2021   Rungtham    1.0   Created									                     */												
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_CTXTH_10_DIT_Weekly_Report]
AS
SELECT DISTINCT
   AL1.Size,
   AL2.Lottable02,
   AL1.SUSR2,
   AL3.OriginalQty,
   AL3.ShippedQty,
   AL3.ShippedQty as 'shippedqty2',
   Convert(Date, AL4.DeliveryDate) as 'DeliveryDate',
   convert(varchar, ROW_NUMBER() OVER (PARTITION BY (AL2.Lottable02), AL5.Sku, Convert(Date, AL4.DeliveryDate), AL2.Lottable01 
   Order By  AL2.Lottable02,AL5.Sku, Convert(Date, AL4.DeliveryDate), AL2.Lottable01) ) as 'lot1',
   ( AL2.Lottable02)+ RTrim((AL5.Sku)) + (AL2.Lottable01) + (convert(varchar, ROW_NUMBER() OVER (PARTITION BY (AL2.Lottable02), 
   ( AL5.Sku),( Convert(Date, AL4.DeliveryDate)),( AL2.Lottable01)Order By
   (AL2.Lottable02),(  AL5.Sku),(  Convert(Date, AL4.DeliveryDate)),(AL2.Lottable01)) )) as 'lot2',
   Max (Convert(Date, AL4.DeliveryDate)) as 'DeliverDate',
   ISNULL ( AL3.ShippedQty, 0 ) as 'Shipped Qty3',
   AL5.Sku,
   AL2.Lottable01 
FROM
   dbo.V_SKU AL1 
   join dbo.V_PICKDETAIL AL5 on   AL1.Sku = AL5.Sku  AND AL1.StorerKey = AL5.Storerkey 
   join dbo.V_LOTATTRIBUTE AL2 on AL2.StorerKey = AL5.Storerkey  AND AL2.Sku = AL5.Sku AND AL5.Lot = AL2.Lot 
   join dbo.V_ORDERDETAIL AL3 on AL5.OrderKey = AL3.OrderKey    AND AL5.OrderLineNumber = AL3.OrderLineNumber  AND AL3.Sku = AL5.Sku 
   join dbo.V_ORDERS AL4 on AL3.OrderKey = AL4.OrderKey 
   join dbo.V_MBOL AL6 on AL6.MbolKey = AL4.MBOLKey 
   join 
   (   SELECT DISTINCT
         SUBSTRING ( D6AL1.Color, 1, 2 ),
         D6AL1.Style,
         D6AL1.Measurement,
         D6AL1.BUSR7,
         D6AL3.Lottable02,
         CASE WHEN D6AL3.Lottable01 = 'H' 
            THEN 'Awaiting' 
          Else
           CASE WHEN D6AL3.Lottable01 = 'S' 
              THEN 'Release' 
             Else
               CASE WHEN D6AL3.Lottable01 = 'R' 
                 THEN 'Resort' 
              ELSE D6AL3.Lottable01 
                END
            END
         END
         , Sum(D6AL2.Qty)
			, D6AL1.SUSR2
			, Convert(Varchar, ROW_NUMBER() OVER ( PARTITION BY (D6AL3.Lottable02) ORDER BY (D6AL1.BUSR7) ) )
			, ( D6AL3.Lottable02) + (D6AL1.BUSR7) + (Convert(Varchar, ROW_NUMBER() OVER ( PARTITION BY (D6AL3.Lottable02) ORDER BY (D6AL1.BUSR7) ) ))
			, D6AL3.StorerKey
			, D6AL3.Sku
			, D6AL3.Lottable01
			, D6AL3.Lottable02
			, D6AL1.NetWgt 
      FROM dbo.V_SKU D6AL1
		  JOIN dbo.V_LOTxLOCxID D6AL2 on  D6AL2.Sku = D6AL1.Sku AND D6AL2.StorerKey = D6AL1.StorerKey 
		  JOIN dbo.V_LOTATTRIBUTE D6AL3 on D6AL2.Sku = D6AL3.Sku  AND D6AL2.StorerKey = D6AL3.StorerKey  and D6AL2.Lot = D6AL3.Lot 
		  JOIN dbo.V_LOC D6AL4 on D6AL4.Loc = D6AL2.Loc
      WHERE
		(D6AL2.StorerKey = 'CTXTH' 
            AND D6AL4.Facility = 'FC' 
            AND D6AL3.Lottable01 IN 
            ('H', 'R', 'S')
            AND  D6AL2.EditDate > Convert(Varchar, Getdate() - 7, 112) 
            AND  D6AL2.EditDate <= Convert(Varchar, Getdate(), 112))
      GROUP BY
         SUBSTRING ( D6AL1.Color, 1, 2 ), D6AL1.Style, D6AL1.Measurement, D6AL1.BUSR7, D6AL3.Lottable02, 
         CASE WHEN D6AL3.Lottable01 = 'H' 
            THEN 'Awaiting' 
           Else
            CASE WHEN D6AL3.Lottable01 = 'S' 
               THEN 'Release' 
              ELSE 
				   CASE WHEN D6AL3.Lottable01 = 'R' 
                THEN 'Resort' 
                ELSE D6AL3.Lottable01 
               END
             END
         END
       , D6AL1.SUSR2
		 , (D6AL3.Lottable02)
       , (D6AL1.BUSR7)
       , (D6AL3.Lottable02)
       , (D6AL1.BUSR7)
       , D6AL3.StorerKey
		 , D6AL3.Sku
		 , D6AL3.Lottable01
		 , D6AL3.Lottable02
		 , D6AL1.NetWgt 
      HAVING SUM(D6AL2.Qty) = 0 ) AL7
   (color, item_description, selling_uom, size, po_, inspection_result, stock_balance__6, recommend_stora7, inboundno, rowpo_in, storerkey, sku, lottable01, lottable02, netwgt) 
ON AL7.storerkey = AL5.Storerkey AND AL7.sku = AL5.Sku AND AL7.lottable02 = AL2.Lottable02
WHERE
   (AL3.StorerKey = 'CTXTH' 
      AND AL4.Status = '9' 
      AND AL3.ShippedQty > 0 
      AND AL5.Status = '9' 
      AND AL4.ConsigneeKey NOT IN 
      ('CTXCOPACK', 'CTXQC', 'CTXTH')
      AND AL4.ConsigneeKey LIKE 'CTX%' 
      AND AL4.Type = '3' 
      AND  AL6.ShipDate > Convert(Varchar, DATEADD(month, - 6, Getdate()), 112) 
      and  AL6.ShipDate <= Convert(Varchar, Getdate(), 112))
GROUP BY
   AL1.Size, AL2.Lottable02, AL1.SUSR2, AL3.OriginalQty, AL3.ShippedQty, AL3.ShippedQty, Convert(Date, AL4.DeliveryDate), ISNULL ( AL3.ShippedQty, 0 ), AL5.Sku, AL2.Lottable01 

GO