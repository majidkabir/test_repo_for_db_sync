SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_PHY_missing_tag_b] 
AS 
SELECT [InventoryTag]
FROM [PHY_missing_tag_b] (NOLOCK) 

GO