SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
--[CN] Create new BI view for Jreport https://jiralfl.atlassian.net/browse/WMS-15982
/* Date         Author      Ver.  Purposes                                 */
/* 06-Jan-2021  KHLim       1.0   Created                                  */
/***************************************************************************/
CREATE   VIEW [BI].[V_RDTReport]  AS
SELECT *
FROM RDT.RDTReport WITH (NOLOCK)

GO