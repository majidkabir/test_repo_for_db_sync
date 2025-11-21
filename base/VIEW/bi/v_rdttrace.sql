SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
--[PH] - JReport_Add_View  https://jiralfl.atlassian.net/browse/WMS-15961
/* Date         Author      Ver.  Purposes                                 */
/* 23-Dec-2020  KHLim       1.0   Created                                  */
/***************************************************************************/
CREATE   VIEW [BI].[V_RDTTrace]  AS
SELECT *
FROM RDT.RDTTrace WITH (NOLOCK)

GO