SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--[TH] - JReport_Add_View in PRD Catalog https://jiralfl.atlassian.net/browse/WMS-18581
/* Date          Author      Ver.  Purposes									                     */
/* 15-DEC-2021   GYWONG      1.0   Created									                     */
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_NESP_PendingPO_ASN]
AS
SELECT DISTINCT
   AL1.AddDate,
   AL1.StorerKey,
   AL1.ReceiptKey,
   AL1.ExternReceiptKey,
   AL1.POKey,
   AL1.CarrierKey,
   AL1.CarrierName,
   AL1.CarrierAddress1,
   AL1.CarrierAddress2,
   AL1.CarrierCity,
   AL1.OpenQty

FROM dbo.RECEIPT AL1 WITH (NOLOCK)
WHERE
AL1.StorerKey = 'UA'
AND AL1.Facility = 'BDC02'
AND AL1.Status NOT IN ('9','CANC')
AND AL1.ASNStatus NOT IN ('9','CANC')

GO