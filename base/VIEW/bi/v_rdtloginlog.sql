SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/
/* [PH] - LogiReport_Add_View in UAT Catalog_09Mar2022						*/
/* https://jiralfl.atlassian.net/browse/WMS-19129							*/
/* Date         Author      Ver.  Purposes									*/
/* 11-Mar-2022  JarekLim    1.0   Created									*/
/****************************************************************************/
CREATE   VIEW [BI].[V_RDTLoginLog] AS
SELECT *
FROM RDT.RDTLoginLog WITH (NOLOCK)

GO