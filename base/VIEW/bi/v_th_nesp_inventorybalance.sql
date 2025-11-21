SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************************/
--[TH] - JReport_Add_View in PRD Catalog https://jiralfl.atlassian.net/browse/WMS-18581
/* Date          Author      Ver.  Purposes									                     */
/* 15-DEC-2021   GYWONG      1.0   Created									                     */
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_NESP_InventoryBalance]
AS
SELECT
   AL1.StorerKey,
   AL1.ReceiptKey,
   AL1.ExternReceiptKey,
   AL1.WarehouseReference,
   AL2.Id,
   AL2.QtyExpected,
   AL2.QtyReceived,
   AL2.ToLot,
   AL2.ToId,
   AL1.ASNStatus
FROM dbo.RECEIPT AL1 WITH (NOLOCK)
JOIN dbo.RECEIPTDETAIL AL2 WITH (NOLOCK) ON AL1.ReceiptKey = AL2.ReceiptKey AND AL1.StorerKey = AL2.StorerKey
WHERE
AL1.StorerKey = 'NESP'
AND AL1.ASNStatus = '9'


GO