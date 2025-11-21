SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_PHYSICAL] 
AS 
SELECT [Team]
, [StorerKey]
, [Sku]
, [Loc]
, [Lot]
, [Id]
, [InventoryTag]
, [Qty]
, [PackKey]
, [UOM]
, [TrafficCop]
, [Timestamp]
, [SheetNoKey]
FROM [PHYSICAL] (NOLOCK) 

GO