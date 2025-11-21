SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_ids_inventory_balance] 
AS 
SELECT [exportdate]
, [storerkey]
, [sku]
, [lot]
, [id]
, [loc]
, [putawayzone]
, [qty]
, [qtyallocated]
, [qtypicked]
FROM [ids_inventory_balance] (NOLOCK) 

GO