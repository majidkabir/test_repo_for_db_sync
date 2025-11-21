SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
-- Purpose: Pls Create view on DB THWMS(PROD) https://jiralfl.atlassian.net/browse/WMS-19109
/* Updates:																   */
/* Date         Author      Ver.	Purposes							   */
/* 08-Mar-2021  JarekLim    1.0		Created								   */
/***************************************************************************/
CREATE   VIEW [BI].[V_TH_ELCTH_03_SOTracking_Auto] as
SELECT
   LTrim(AL2.ExternOrderKey) as 'Externorderkey',
   AL2.ConsigneeKey as 'Shiptocode',
   AL2.Type,
   AL1.Company as 'Shiptoname',
   AL2.DeliveryDate,
   AL1.Address1,
   AL1.Address2,
   AL1.Address3,
   AL1.Address4,
   AL1.City,
   AL1.State,
   AL1.Zip,
   case
      when
         AL2.Status = '0'
      then
         'OPEN'
      when
         AL2.Status = '1'
      then
         'PICKING'
      when
         AL2.Status = '2'
      then
         'PICKING'
      when
         AL2.Status = '3'
      then
         'PICKING'
      when
         AL2.Status = '5'
      then
         'PICKED'
      when
         AL2.Status = '9'
      then
         'SHIPPED'
      when
         AL2.Status = 'CANC'
      then
         'CANCEL'
      else
         'OPEN'
   end as 'SOSTATUS'
, AL2.Facility, AL2.AddDate, AL2.BuyerPO, AL2.EditDate  as 'Status Timing'
FROM
   BI.V_STORER AL1 with (nolock)
   join BI.V_ORDERS AL2 with (nolock) on  AL2.ConsigneeKey = AL1.StorerKey
WHERE
   (
(AL1.ConsigneeFor = 'ELCTH'
      AND AL2.StorerKey = 'ELCTH'
      AND AL2.Facility = '3101E'
      AND
      (
         NOT AL2.Type = 'COPACK'
      )
)
   )


GO