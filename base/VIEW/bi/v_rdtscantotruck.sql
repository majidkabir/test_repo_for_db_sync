SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
--[PH] - JReport_Add_View  https://jiralfl.atlassian.net/browse/WMS-12567
/* Date         Author      Ver.  Purposes                                 */
/* 23-Dec-2020  KHLim       1.1   https://jiralfl.atlassian.net/browse/WMS-15961 */
/***************************************************************************/
--
CREATE   VIEW [BI].[V_rdtScanToTruck]
AS
SELECT *
FROM [RDT].[rdtScanToTruck] WITH (NOLOCK)

GO