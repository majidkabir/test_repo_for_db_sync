SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/
/* [IN] HM Add New BI View - NonItrn table on JReport									*/
/* https://jiralfl.atlassian.net/browse/WMS-16084							*/
/* Date         Author      Ver.  Purposes									*/
/* 13-Jan-2021  Guanyan       1.0   Created									*/
/****************************************************************************/
CREATE   VIEW [BI].[V_NonItrn]  AS
SELECT *
FROM dbo.NonItrn WITH (NOLOCK)

GO