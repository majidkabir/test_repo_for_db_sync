SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--TH-SINOTH-Add Views in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18650
/* Date          Author      Ver.  Purposes									                     */
/* 28-Dec-2021   JarekLim    1.0   Created									                     */
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_SINOTH_GT_DailySales_FOCOFF_BSTT]
AS
SELECT 'OR' as 'Sales Order Type'
 , '5000439' as 'Sold-to-Party Number'
 , 'Sino Pacific' as 'Sold-to-Party Name'
 , '5000439-01' as 'Ship-to-Party Number'
 , 'Sino Pacific - Bangpa-in W/H' as 'Ship-to-Party Name'
 , '' as 'Customer group2'
 , '' as 'Customer group2 description'
 , '' as 'Retailer Group Code (Customer gruop4)'
 , '' as 'Retailer Group(Customer group4 description)'
 , convert(varchar, AL7.EditDate, 102)  as 'Transaction Date'
 , AL4.Lottable06 as 'Cerebos Material Number'
 , Case
 	 WHEN SUBSTRING ( AL3.Sku, 1, 1 ) = '0' Then '''' + AL3.Sku
 	 ELSE AL3.Sku End as 'Sino Material Number'
 ,AL1.NOTES1 as 'Description'
 , CASE
 	 WHEN AL6.UserDefine01 = '0' then  (AL3.Qty) else '0' end as'Quantity Sales'
 , CASE
 	 WHEN AL6.UserDefine01 = '1' then  (AL3.Qty) else '0' end as'Quantity FOC'
 , AL6.UOM
 , '1111' as 'Plant'
 , '7100' as 'Storage'
 , AL4.Lottable02 as 'Batch No.'
 , '' as 'WBS'
 , '' as 'Refer Invoice No'
 , '' as 'Order Reason'
 , '' as 'Distributor Order Number'
 , convert(varchar, AL7.AddDate, 102) as'PO Number'
 , '''' + (AL8.Secondary) as 'Key Account(Trade Customer)'
 ,'' as 'Group of Quantity Sales'
 ,'' as 'Group of Quantity FOC'
 , Case
 	 WHEN AL5.Type in ( 'SO','INV','PM','TRF')  then 'Show'
 	 WHEN AL5.Type = 'TO' and AL5.ConsigneeKey in ('00003','00014','00015','00016','00017','00018','00019','00020','00022','00023','00024','00025','00026','00027','00028','00029') then 'Show'
 	 ELSE 'Noshow' end as 'Filter'
FROM dbo.V_SKU AL1 WITH (NOLOCK)
JOIN dbo.V_PICKDETAIL AL3 WITH (NOLOCK) ON AL3.Storerkey=AL1.StorerKey AND AL3.Sku=AL1.Sku
JOIN dbo.V_PACK AL2 WITH (NOLOCK) ON AL3.PackKey=AL2.PackKey
JOIN dbo.V_LOTATTRIBUTE AL4 WITH (NOLOCK) ON AL3.Lot=AL4.Lot AND AL3.Sku=AL4.Sku AND AL3.Storerkey=AL4.StorerKey
JOIN dbo.V_ORDERS AL5 WITH (NOLOCK) ON AL5.StorerKey=AL3.Storerkey AND AL5.OrderKey=AL3.OrderKey
JOIN dbo.V_ORDERDETAIL AL6 WITH (NOLOCK) ON AL3.OrderKey=AL6.OrderKey AND AL3.OrderLineNumber=AL6.OrderLineNumber AND AL3.Storerkey=AL6.StorerKey AND AL3.Sku=AL6.Sku
JOIN dbo.V_TRANSMITLOG3 AL7 WITH (NOLOCK) ON AL5.StorerKey=AL7.key3 AND AL5.OrderKey=AL7.key1
JOIN dbo.V_STORER AL8 WITH (NOLOCK) ON AL5.ConsigneeKey=AL8.StorerKey
WHERE
(AL3.Storerkey='SINOTH'
AND AL7.tablename='PICKCFMLOG'
AND AL7.AddDate >= convert(varchar, getdate()-1, 112)
AND AL7.AddDate < convert(varchar, getdate(), 112)
--AND convert(varchar, AL7.AddDate, 112) >= convert(varchar, getdate()-1, 112)
--and convert(varchar, AL7.AddDate, 112) < convert(varchar, getdate(), 112)
AND AL7.transmitflag='9'
AND AL5.Status <> 'CANC'
--AND (NOT AL5.Status='CANC')
AND AL5.Type IN ('PM', 'TRF')
AND (NOT (AL4.Lottable01 LIKE '%CI%'
OR AL4.Lottable01 LIKE '%DTR%'
OR AL4.Lottable01 LIKE '%FW%'
OR AL4.Lottable01 LIKE '%GOOD%'
OR AL4.Lottable01 LIKE '%Good%'
OR AL4.Lottable01 LIKE '%GradeB%'
OR AL4.Lottable01 LIKE '%REPACK%'
OR AL4.Lottable01 LIKE '%Repack%'
OR AL4.Lottable01 LIKE '%RTP%'
OR AL4.Lottable01 LIKE '%SNO%'
OR AL4.Lottable01 LIKE '%SORT%'
OR AL4.Lottable01 LIKE '%Sort%'
OR AL4.Lottable01 LIKE '%WOSN%'))
AND AL8.ConsigneeFor='SINOTH'
AND AL5.Facility IN ('3101B', 'WN01')
AND (NOT AL5.OrderGroup='MT'))

GO