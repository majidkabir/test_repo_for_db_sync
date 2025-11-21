SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_ALLACOUNT_MBOL_Status_v1] AS
SELECT
   ST.SUSR2,
   O.StorerKey,
   case
(O.StorerKey)
      when
         '06700'
      then
         'Diversey Hygiene'
      when
         '06700N'
      then
         'Diversey Hygiene'
      when
         '31170'
      then
         'LF Asia Consumer'
      when
         '31231'
      then
         'LF Asia Healthcare'
      when
         '31171'
      then
         'LF Asia Licensed Brands'
      else
         ST.Company
   end AS 'Company'
, convert(datetime, convert(char(8), O.DeliveryDate, 112)) AS 'Deliverytime',
 case (O.Status)
when  '0'
then '0-Normal'
when '1'
then '1-Partially'
when '2'
then '2-Fully Allocate'
when '3'
then '3-In Process'
when '5'
then '5-Picked'
when '9'
then '9-Shipped'
when 'CANC'
then 'CANCLE'
end AS 'OrderOfStatus'
, COUNT (DISTINCT O.OrderKey) AS 'NoOfOrders', MIN( convert(datetime, convert(char(8), O.AddDate, 112))) AS 'AddDate'
FROM dbo.STORER ST with (nolock)
JOIN dbo.ORDERS O with (nolock) on ST.StorerKey = O.StorerKey
WHERE O.AddDate >= convert(varchar(10), getdate() - 30, 120)
      AND O.AddDate < convert(varchar(10), getdate() - 1, 120)
GROUP BY
   ST.SUSR2, O.StorerKey,
   case
(O.StorerKey)
      when
         '06700'
      then
         'Diversey Hygiene'
      when
         '06700N'
      then
         'Diversey Hygiene'
      when
         '31170'
      then
         'LF Asia Consumer'
      when
         '31231'
      then
         'LF Asia Healthcare'
      when
         '31171'
      then
         'LF Asia Licensed Brands'
      else
         ST.Company
   end
, convert(datetime, convert(char(8), O.DeliveryDate, 112)), O.Status

GO