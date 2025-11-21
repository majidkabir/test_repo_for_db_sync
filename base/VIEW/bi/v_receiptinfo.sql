SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
--[KR] - JReport_Add_View in PRD Catalog_20210128 https://jiralfl.atlassian.net/browse/WMS-16274
/* Date         Author      Ver.  Purposes                                 */
/* 01-Feb-2021  KHLim       1.0   Created                                  */
/***************************************************************************/
CREATE   VIEW [BI].[V_ReceiptInfo]  AS
SELECT *
FROM dbo.ReceiptInfo WITH (NOLOCK)

GO