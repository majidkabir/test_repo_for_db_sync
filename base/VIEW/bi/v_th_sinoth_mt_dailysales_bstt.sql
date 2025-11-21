SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--TH-SINOTH-Revise Script at views V_TH_SINOTH_MT_DailySales_BSTT in THWMS PROD
-- https://jiralfl.atlassian.net/browse/WMS-18627
/* Date          Author      Ver.  Purposes									                     */
/* 05-FEB-2021   Natt        1.0   Created									                     */
/* 21-DEC-2021   Natt        1.1   Modified									                     */
/******************************************************************************************/
CREATE    VIEW [BI].[V_TH_SINOTH_MT_DailySales_BSTT] AS
SELECT 'OR' AS 'Sales Order Type'
, '5000439' AS 'Sold-to-Party Number'
, 'Sino Pacific' AS 'Sold-to-Party Name'
, '5000439-01' AS 'Ship-to-Party Number'
, 'Sino Pacific - Bangpa-in W/H' AS 'Ship-to-Party Name'
, '' AS 'Customer group2'
, '' AS 'Customer group2 description'
, '' AS 'Retailer Group Code (Customer gruop4)'
, '' AS 'Retailer Group(Customer group4 description)'
, CONVERT(VARCHAR, TL.EditDate, 102)  AS 'Transaction Date'
, A.Lottable06 AS 'Cerebos Material Number'
, CASE
	WHEN SUBSTRING ( PD.Sku, 1, 1 ) = '0' THEN '''' + PD.Sku
	ELSE PD.Sku END AS 'Sino Material Number'
,S.NOTES1 AS 'Description'
, CASE
  WHEN  OD.UserDefine01 = '0' THEN  (PD.Qty) ELSE  '0' END as'Quantity Sales'
, CASE
  WHEN OD.UserDefine01 = '1' THEN  (PD.Qty) ELSE '0' END  as'Quantity FOC'
, OD.UOM
, '1111' AS 'Plant'
, '7100' AS 'Storage'
, A.Lottable02 AS 'Batch No.'
, '' AS 'WBS'
, '' AS 'Refer Invoice No'
, '' AS 'Order Reason'
, '' AS 'Distributor Order Number'
, CONVERT(VARCHAR, TL.AddDate, 102) AS'PO Number'
, '''' + (ST.Secondary) AS 'Key Account(Trade Customer)'
,'' AS 'Group of Quantity Sales'
,'' AS 'Group of Quantity FOC'
, CASE
	WHEN O.Type IN ( 'SO','INV','PM','TRF')  THEN 'Show'
	WHEN O.Type = 'TO' AND O.ConsigneeKey IN ('00003','00014','00015','00016','00017','00018','00019','00020','00022','00023','00024','00025','00026','00027','00028','00029') THEN 'Show'
	ELSE 'Noshow' END AS 'Filter'
FROM dbo.ORDERS O WITH (NOLOCK)
RIGHT OUTER JOIN dbo.ORDERDETAIL OD ON O.OrderKey=OD.OrderKey
		AND O.StorerKey=OD.StorerKey
		AND O.ExternOrderKey=OD.ExternOrderKey
JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON OD.OrderKey=PD.OrderKey
		AND OD.Storerkey=PD.StorerKey
		AND OD.Sku=PD.Sku
		AND OD.OrderLineNumber=PD.OrderLineNumber
JOIN dbo.PACK P WITH (NOLOCK) ON PD.PackKey=P.PackKey
JOIN dbo.LOTATTRIBUTE A WITH (NOLOCK) ON PD.Sku=A.Sku
		AND PD.Storerkey=A.StorerKey
		AND PD.Lot=A.Lot
JOIN dbo.SKU S WITH (NOLOCK) ON PD.Storerkey=S.StorerKey
		AND PD.Sku=S.Sku
JOIN dbo.TRANSMITLOG3 TL WITH (NOLOCK) ON O.StorerKey=TL.key3
		AND O.OrderKey=TL.key1
JOIN dbo.STORER ST WITH (NOLOCK) ON O.ConsigneeKey=ST.StorerKey
WHERE ((PD.Storerkey='SINOTH'
AND TL.tablename='PICKCFMLOG'
AND CONVERT(VARCHAR, TL.AddDate, 112)>= CONVERT(VARCHAR, GETDATE()-1, 112)
AND CONVERT(VARCHAR, TL.AddDate, 112) < CONVERT(VARCHAR, GETDATE(), 112)
AND TL.transmitflag='9'
AND (NOT O.Status='CANC')
AND O.Type NOT  IN ('COPACK', 'PM', 'TRF')
AND (NOT (A.Lottable01 LIKE '%CI%'
OR A.Lottable01 LIKE '%DTR%'
OR A.Lottable01 LIKE '%FW%'
OR A.Lottable01 LIKE '%GOOD%'
OR A.Lottable01 LIKE '%Good%'
OR A.Lottable01 LIKE '%GradeB%'
OR A.Lottable01 LIKE '%REPACK%'
OR A.Lottable01 LIKE '%Repack%'
OR A.Lottable01 LIKE '%RTP%'
OR A.Lottable01 LIKE '%SORT%'
OR A.Lottable01 LIKE '%Sort%'
OR A.Lottable01 LIKE '%WOSN%'))
AND ST.ConsigneeFor IN ('SINOTH', 'SINOXD')
AND O.Facility IN ('3101B', 'WN01')
AND (NOT O.OrderGroup='GT')))

GO