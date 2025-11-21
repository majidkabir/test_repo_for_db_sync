SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_PHY_A2B_ID] 
AS 
SELECT [StorerKey]
, [Sku]
, [Loc]
, [Id]
, [QtyTeamA]
, [QtyTeamB]
FROM [PHY_A2B_ID] (NOLOCK) 

GO