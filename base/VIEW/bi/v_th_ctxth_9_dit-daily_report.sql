SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 28-Dec-2021   Rungtham    1.0   Created									                     */												
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_CTXTH_9_DIT-Daily_report]
AS
SELECT DISTINCT
   AL1.BUSR7,
   AL2.Lottable02,
   AL1.SUSR2,
   Sum(AL3.ShippedQty) as 'Shipped Qty',
   Sum(AL3.OriginalQty) as 'Original Qty' ,
   Sum(AL3.ShippedQty) as 'Shipped Qty2',
   Convert(Varchar, AL6.ShipDate, 103) as 'Shipped  Date',
   convert(varchar, 
    ROW_NUMBER() OVER (PARTITION BY (AL2.Lottable02) , ( AL5.Sku ), ( Convert(Varchar, AL6.ShipDate, 103))
    ,  ( AL2.Lottable01 )
       Order By(AL2.Lottable02)
	   , (AL5.Sku), 
	   (Convert(Varchar, AL6.ShipDate, 103)
          )  
, 
   ( AL2.Lottable01 ))) as 'Lot1',
   (AL2.Lottable02) + RTrim((AL5.Sku)) + (AL2.Lottable01) + (convert(varchar, ROW_NUMBER() OVER (PARTITION BY (AL2.Lottable02), 
   ( AL5.Sku), (Convert(Varchar, AL6.ShipDate, 103)),( AL2.Lottable01)
Order By (AL2.Lottable02),( AL5.Sku ), ( Convert(Varchar, AL6.ShipDate, 103)),( AL2.Lottable01)) )) as 'Lot2',
  Max (Convert(Date, AL4.DeliveryDate)) as 'Deliver Date',
   ISNULL ( Sum(AL3.ShippedQty), 0 ) as 'Shipped Qty3',
   AL5.Sku,
   AL2.Lottable01 
FROM dbo.V_SKU AL1 WITH (NOLOCK)
JOIN dbo.V_PICKDETAIL AL5 WITH (NOLOCK) ON AL1.Sku = AL5.Sku  AND AL1.StorerKey = AL5.Storerkey 
JOIN dbo.V_LOTATTRIBUTE AL2 WITH (NOLOCK) ON AL2.StorerKey = AL5.Storerkey AND AL5.Lot = AL2.Lot 
      AND AL2.Sku = AL5.Sku 
JOIN dbo.V_ORDERS AL4  WITH (NOLOCK) ON AL4.OrderKey = AL5.OrderKey
JOIN dbo.V_ORDERDETAIL AL3 WITH (NOLOCK) ON AL5.OrderKey = AL3.OrderKey AND AL5.OrderLineNumber = AL3.OrderLineNumber AND AL3.Sku = AL5.Sku 
JOIN dbo.V_MBOL AL6 WITH (NOLOCK) ON AL6.MbolKey = AL4.MBOLKey 
WHERE

(AL3.StorerKey = 'CTXTH' 
      AND AL4.Status = '9' 
      AND AL3.ShippedQty > 0 
      AND AL5.Status = '9' 
      AND AL4.ConsigneeKey NOT IN 
      (
         'CTXCOPACK',
         'CTXQC',
         'CTXTH'
      )
      AND Convert(Varchar, AL6.ShipDate, 103) = Convert(Varchar, Getdate() - 1, 103))
   
GROUP BY
   AL1.BUSR7,
   AL2.Lottable02,
   AL1.SUSR2,
   Convert(Varchar, AL6.ShipDate, 103),
   AL5.Sku,
   AL2.Lottable01 

GO