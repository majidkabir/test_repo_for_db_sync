SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_SINOTH_SOTracking] AS
SELECT AL1.externorderkey
, AL1.shiptocode
, AL1.type
, AL1.shiptoname
, AL1.deliverydate
, AL1.address1
, AL1.address2
, AL1.address3
, AL1.address4
, AL1.city
, AL1.state
, AL1.zip
, AL1.sostatus
, AL1.facility
FROM (
SELECT LTrim(O.ExternOrderKey)
, O.ConsigneeKey
, O.Type
, ST.Company
, CONVERT(varchar(8)
, O.DeliveryDate, 112)
, ST.Address1
, ST.Address2
, ST.Address3
, ST.Address4
, ST.City
, ST.State
, ST.Zip
, case
	when O.Status = '0' and O.ConsigneeKey <>  'SN00001' then 'OPEN'
	when O.Status = '1' and O.ConsigneeKey <>  'SN00001'  then 'PICKING'
	when O.Status = '2' and O.ConsigneeKey <>  'SN00001'  then 'PICKING'
	when O.Status = '3' and O.ConsigneeKey <>  'SN00001' then 'PICKING'
	when O.Status = '5' and O.ConsigneeKey <>  'SN00001' then 'INVOICE'
	when O.Status = '9' and O.ConsigneeKey <>  'SN00001'  then 'INVOICE'
	when O.Status = 'CANC' and O.ConsigneeKey <>  'SN00001'  then 'CANCEL'
	else 'Transfer' end
, O.Facility
FROM dbo.ORDERS O with (nolock)
JOIN dbo.TRANSMITLOG3 TL with (nolock) ON O.StorerKey=TL.key3
		AND O.OrderKey=TL.key1
JOIN dbo.STORER ST with (nolock) ON O.ConsigneeKey=ST.StorerKey
WHERE ((O.Facility IN ('3101','3101F','BPFZ1','BPI04','CNX01')
AND TL.tablename='PICKCFMLOG'
AND convert(varchar, TL.EditDate, 112)>= convert(varchar, getdate()-1, 112)
and convert(varchar, TL.EditDate, 112) < convert(varchar, getdate(), 112)
AND TL.transmitflag='9' AND (NOT O.Status='CANC')
AND (NOT O.Type='COPACK')
AND ST.ConsigneeFor='SINOTH')))
AL1 (externorderkey, shiptocode, type, shiptoname, deliverydate, address1, address2, address3, address4, city, state, zip, sostatus, facility)

UNION ALL

SELECT AL2.externorderkey
, AL2.shiptocode
, AL2.type
, AL2.shiptoname
, AL2.deliverydate
, AL2.address1
, AL2.address2
, AL2.address3
, AL2.address4
, AL2.city
, AL2.state
, AL2.zip
, AL2.sostatus
, AL2.facility
FROM (
SELECT LTrim(O.ExternOrderKey)
, O.ConsigneeKey
, O.Type
, ST.Company
, CONVERT(varchar(8)
, O.DeliveryDate, 112)
, ST.Address1
, ST.Address2
, ST.Address3
, ST.Address4
, ST.City
, ST.State
, ST.Zip
, case
	when O.Status = '0' and O.ConsigneeKey <>  'SN00001' then 'OPEN'
	when O.Status = '1' and O.ConsigneeKey <>  'SN00001'  then 'PICKING'
	when O.Status = '2' and O.ConsigneeKey <>  'SN00001'  then 'PICKING'
	when O.Status = '3' and O.ConsigneeKey <>  'SN00001' then 'PICKING'
	when O.Status = '5' and O.ConsigneeKey <>  'SN00001' then 'INVOICE'
	when O.Status = '9' and O.ConsigneeKey <>  'SN00001'  then 'INVOICE'
	when O.Status = 'CANC' and O.ConsigneeKey <>  'SN00001'  then 'CANCEL'
	else 'Transfer' end
, O.Facility
FROM dbo.ORDERS O with (nolock)
JOIN dbo.STORER ST with (nolock) ON O.ConsigneeKey=ST.StorerKey
WHERE ((ST.ConsigneeFor='SINOTH'
AND O.StorerKey='SINOTH'
AND O.Facility IN ('3101','3101F','BPFZ1','BPI04','CNX01')
AND (NOT O.Type='COPACK')
AND O.Status IN ('0', '1', '2', '3', 'CANC'))))
AL2 (externorderkey, shiptocode, type, shiptoname, deliverydate, address1, address2, address3, address4, city, state, zip, sostatus, facility)

GO