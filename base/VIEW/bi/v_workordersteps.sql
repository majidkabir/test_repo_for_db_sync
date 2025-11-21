SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/*[TW] LOR Create new BI view for Jreport										      */
/*https://jiralfl.atlassian.net/browse/WMS-16997               		      */
/*Date         Author      Ver.  Purposes								         	*/
/*11-May-2021  GuanYan     1.0   Created                                   */
/***************************************************************************/
CREATE   VIEW [BI].[V_WorkOrderSteps] AS
SELECT *
FROM dbo.WorkOrderSteps WITH (NOLOCK)

GO