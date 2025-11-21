SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_PHY_outofrange_tag_a] 
AS 
SELECT [InventoryTag]
FROM [PHY_outofrange_tag_a] (NOLOCK) 

GO