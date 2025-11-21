SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_PHY_A2B_LOT] 
AS 
SELECT [StorerKey]
, [Sku]
, [Loc]
, [Lot]
, [QtyTeamA]
, [QtyTeamB]
FROM [PHY_A2B_LOT] (NOLOCK) 

GO