SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/*CN] PVH- Add Views into JREPORT UAT/PROD Catalogs for CNWMS	            */
/*https://jiralfl.atlassian.net/browse/WMS-17423               		      */				       
/*Date         Author      Ver.  Purposes								         	*/
/*02-Jul-2021  GuanYan       1.0   Created                                 */
/***************************************************************************/

CREATE   VIEW [BI].[V_PackTaskDetail] AS
SELECT *
FROM dbo.PackTaskDetail WITH (NOLOCK)

GO