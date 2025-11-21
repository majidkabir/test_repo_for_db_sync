SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/
/* [TW] LogiReport Create Views in BI Schema								*/
/* https://jiralfl.atlassian.net/browse/WMS-18479							*/
/* Date         Author      Ver.  Purposes									*/
/* 29-Nov-2021  BLLim       1.0   Created									*/
/****************************************************************************/
CREATE   VIEW [BI].[V_RDTWATTEAMLOG]  AS
SELECT *
FROM RDT.RDTWATTEAMLOG WITH (NOLOCK)

GO