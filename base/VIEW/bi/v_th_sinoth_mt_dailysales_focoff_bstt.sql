SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_SINOTH_MT_DailySales_FOCOFF_BSTT] AS
SELECT 'OR' as 'Sales Order Type'
, '5000439' as 'Sold-to-Party Number'
, 'Sino Pacific' as 'Sold-to-Party Name'
, '5000439-01' as 'Ship-to-Party Number'
, 'Sino Pacific - Bangpa-in W/H' as 'Ship-to-Party Name'
, '' as 'Customer group2'
, '' as 'Customer group2 description'
, '' as 'Retailer Group Code (Customer gruop4)'
, '' as 'Retailer Group(Customer group4 description)'
, convert(varchar, TL.EditDate, 102)  as 'Transaction Date'
, A.Lottable06 as 'Cerebos Material Number'
, Case
	When SUBSTRING ( PD.Sku, 1, 1 ) = '0' Then '''' + PD.Sku
	Else PD.Sku End as 'Sino Material Number'
,S.NOTES1 as 'Description'
, case
	when OD.UserDefine01 = '0' then SUM(PD.Qty) else '0' end as'Quantity Sales'
, SUM(PD.Qty) as 'Quantity FOC'
, OD.UOM
, '1111' as 'Plant'
, '7100' as 'Storage'
, A.Lottable02 as 'Batch No.'
, '' as 'WBS'
, '' as 'Refer Invoice No'
, '' as 'Order Reason'
, '' as 'Distributor Order Number'
, convert(varchar, TL.AddDate, 102) as'PO Number'
, '''' + (ST.Secondary) as 'Key Account(Trade Customer)'
,'' as 'Group of Quantity Sales'
,'' as 'Group of Quantity FOC'
, Case
	when O.Type in ( 'SO','INV','PM','TRF')  then 'Show'
	when O.Type = 'TO' and O.ConsigneeKey in ('00003','00014','00015','00016','00017','00018','00019','00020','00022','00023','00024','00025','00026','00027','00028','00029') then 'Show'
	ELSE 'Noshow' end as 'Filter'
FROM dbo.ORDERS O with (nolock)
JOIN dbo.PICKDETAIL PD with (nolock) ON O.StorerKey=PD.Storerkey
		AND O.OrderKey=PD.OrderKey
JOIN dbo.PACK P with (nolock) ON PD.PackKey=P.PackKey
JOIN dbo.ORDERDETAIL OD with (nolock) ON PD.Sku=OD.Sku
		AND PD.OrderKey=OD.OrderKey
		AND PD.OrderLineNumber=OD.OrderLineNumber
		AND PD.Storerkey=OD.StorerKey
JOIN dbo.LOTATTRIBUTE A with (nolock) ON PD.Sku=A.Sku
		AND PD.Storerkey=A.StorerKey
		AND PD.Lot=A.Lot
JOIN dbo.SKU S with (nolock) ON PD.Storerkey=S.StorerKey
		AND PD.Sku=S.Sku
JOIN dbo.TRANSMITLOG3 TL with (nolock) ON O.StorerKey=TL.key3
		AND O.OrderKey=TL.key1
JOIN dbo.STORER ST with (nolock) ON O.ConsigneeKey=ST.StorerKey
WHERE ((O.Storerkey='SINOTH'
AND TL.tablename='PICKCFMLOG'
AND convert(varchar, TL.AddDate, 112)>= convert(varchar, getdate()-1, 112)
and convert(varchar, TL.AddDate, 112) <= convert(varchar, getdate(), 112)
AND TL.transmitflag='9'
AND (NOT O.Status='CANC')
AND O.Type IN ('PM', 'TRF')
AND (NOT (A.Lottable01 LIKE '%CI%'
OR A.Lottable01 LIKE '%DTR%'
OR A.Lottable01 LIKE '%FW%'
OR A.Lottable01 LIKE '%GOOD%'
OR A.Lottable01 LIKE '%Good%'
OR A.Lottable01 LIKE '%GradeB%'
OR A.Lottable01 LIKE '%REPACK%'
OR A.Lottable01 LIKE '%Repack%'
OR A.Lottable01 LIKE '%RTP%'
OR A.Lottable01 LIKE '%SNO%'
OR A.Lottable01 LIKE '%SORT%'
OR A.Lottable01 LIKE '%Sort%'
OR A.Lottable01 LIKE '%WOSN%'))
AND ST.ConsigneeFor='SINOTH'
AND O.Facility IN ('3101B', 'WN01')
AND (NOT O.OrderGroup='GT')))
Group By A.Lottable06,PD.Sku,S.NOTES1,TL.EditDate,OD.UserDefine01,OD.UOM,A.Lottable02,TL.AddDate,ST.Secondary,O.Type,O.ConsigneeKey

GO