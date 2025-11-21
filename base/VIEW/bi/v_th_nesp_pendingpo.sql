SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--[TH] - JReport_Add_View in PRD Catalog https://jiralfl.atlassian.net/browse/WMS-18581
/* Date          Author      Ver.  Purposes									                     */
/* 15-DEC-2021   GYWONG      1.0   Created									                     */
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_NESP_PendingPO]
AS
SELECT DISTINCT
   AL1.AddDate,
   AL1.StorerKey,
   AL1.POKey,
   AL1.ExternPOKey,
   AL1.[Status] as POExternstatus,
   AL1.ExternStatus,
   AL1.PoGroup,
   AL2.ReceiptKey,
   AL2.[Status] as ReceiptStatus,
   AL2.ASNStatus,
   AL1.PODate,
   AL1.SellersReference,
   AL1.BuyersReference,
   AL1.OtherReference,
   AL1.POType,
   AL1.SellerName,
   AL1.SellerAddress1,
   AL1.SellerAddress2,
   AL1.SellerAddress3,
   AL1.SellerAddress4,
   AL1.SellerCity,
   AL1.SellerState,
   AL1.SellerZip,
   AL1.OpenQty,
   AL1.Notes

FROM dbo.PO AL1 WITH (NOLOCK)
LEFT OUTER JOIN dbo.RECEIPT AL2 WITH (NOLOCK) ON (AL1.POKey = AL2.POKey)
WHERE
AL1.StorerKey = 'UA'
AND AL1.Status NOT IN ('9','CANC')


GO