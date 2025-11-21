SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/
/* [IN] HM Add New BI View - NonInv table on JReport									*/
/* https://jiralfl.atlassian.net/browse/WMS-16084							*/
/* Date         Author      Ver.  Purposes									*/
/* 13-Jan-2021  KHLim       1.0   Created									*/
/****************************************************************************/
CREATE   VIEW [BI].[V_NonInv]  AS
SELECT *
FROM dbo.NonInv WITH (NOLOCK)

GO