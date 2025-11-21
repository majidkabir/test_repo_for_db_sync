SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
--[AU] Add new BI View - V_rdtSTDEventLog https://jiralfl.atlassian.net/browse/WMS-15703
/* Date         Author      Ver.  Purposes                                 */
/* 16-Nov-2020  KHLim       1.0   Created                                  */
/***************************************************************************/
CREATE   VIEW [BI].[V_rdtSTDEventLog]  AS
SELECT *
FROM RDT.rdtSTDEventLog WITH (NOLOCK)

GO