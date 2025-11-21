SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/
/* [PH] - LogiReport_Add_View in UAT Catalog_15Mar2022						*/
/* https://jiralfl.atlassian.net/browse/WMS-19207							*/
/* Date         Author      Ver.  Purposes									*/
/* 18-Mar-2022  JarekLim    1.0   Created									*/
/****************************************************************************/
CREATE   VIEW [BI].[V_RDTUser] AS
SELECT *
FROM dbo.V_RDTUser WITH (NOLOCK)

GO