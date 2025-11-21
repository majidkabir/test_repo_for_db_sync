SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
--[[KR] Create SP in BI schema for LogiReport  https://jiralfl.atlassian.net/browse/WMS-22303
/* Date           Author      Ver.  Purposes                                 */
/* 28-April-2023  JAREKLIM    1.1   Created                                 */
/***************************************************************************/
--
CREATE     VIEW [BI].[V_REFKEYLOOKUP]
AS
SELECT *
FROM [DBO].[REFKEYLOOKUP] WITH (NOLOCK)

GO