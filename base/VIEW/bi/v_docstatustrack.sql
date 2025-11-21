SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/*[TW] SPZ Create new BI view for Jreport	                                 */
/*https://jiralfl.atlassian.net/browse/WMS-17442               		      */
/*Date         Author      Ver.  Purposes								         	*/
/*07-Jul-2021  GuanYan       1.0   Created                                 */
/***************************************************************************/
CREATE   VIEW [BI].[V_DocStatusTrack] AS
SELECT *
FROM dbo.DocStatusTrack WITH (NOLOCK)

GO