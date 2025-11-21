SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_PHY_A2B_TAG] 
AS 
SELECT [StorerKey]
, [Sku]
, [Loc]
, [Id]
, [InventoryTag]
, [QtyTeamA]
, [QtyTeamB]
FROM [PHY_A2B_TAG] (NOLOCK) 

GO