SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
--[CN] Create new BI view for Jreport https://jiralfl.atlassian.net/browse/WMS-20516
/* Date         Author      Ver.  Purposes                                 */
/* 12-Aug-2022  Gywong      1.0   Created IN TH                            */
/* 11-Nov-2022  JarekLIM    1.0   Created IN KR https://jiralfl.atlassian.net/browse/WMS-21163 */
/* 27-Dec-2022  JAREKLIM    1.1   Created IN JP https://jiralfl.atlassian.net/browse/WMS-21382 */
/***************************************************************************/

CREATE    VIEW [BI].[V_RDTPrintJob_Log]  AS  
SELECT *
FROM RDT.RDTPrintJob_Log WITH (NOLOCK)

GO