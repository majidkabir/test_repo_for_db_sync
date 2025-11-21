SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_IDSCNDailyInventory] 
AS 
SELECT [Storerkey]
, [Sku]
, [Loc]
, [Lot]
, [Id]
, [Qty]
, [Lottable02]
, [Lottable04]
, [AddDate]
, [Addwho]
, [EditDate]
, [EditWho]
, [InventoryDate]
FROM [IDSCNDailyInventory] (NOLOCK) 

GO