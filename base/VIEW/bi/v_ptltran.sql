SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
-- [PH] - LogiReport_Add_View in UAT Catalog_06May2022 https://jiralfl.atlassian.net/browse/WMS-19626

CREATE   VIEW [BI].[V_PTLTran] AS 
SELECT * 
   FROM PTL.[PTLTran] WITH (NOLOCK)  

GO