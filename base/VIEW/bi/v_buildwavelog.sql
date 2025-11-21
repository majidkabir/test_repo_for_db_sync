SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
--[CN] Create new BI view for Jreport https://jiralfl.atlassian.net/browse/WMS-19447
/* Date           Author      Ver.  Purposes                               */
/* 26-April-2021  JarekLim     1.0   Created                               */
/***************************************************************************/
CREATE   VIEW [BI].[V_BUILDWAVELOG]  AS
SELECT *
FROM [dbo].[BUILDWAVELOG] WITH (NOLOCK)

GO