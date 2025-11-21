SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_ids_lp_nested_orderkey] 
AS 
SELECT [orderkey]
, [storerkey]
FROM [ids_lp_nested_orderkey] (NOLOCK) 

GO