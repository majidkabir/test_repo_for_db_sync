SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_PhysicalParameters] 
AS 
SELECT [PhysicalParmKey]
, [StorerKeyMin]
, [StorerKeyMax]
, [SkuMin]
, [SkuMax]
FROM [PhysicalParameters] (NOLOCK) 

GO