SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW dbo.V_DailyInventory
AS
SELECT DailyInventory.Storerkey AS Storerkey, 
	DailyInventory.Sku AS Sku, 
	UPPER(DailyInventory.Loc) AS Loc, 
	DailyInventory.ID AS ID, 
	DailyInventory.Qty AS Qty, 
	DailyInventory.InventoryDate AS InventoryDate, 
	DailyInventory.Adddate AS Adddate, 
	DailyInventory.Addwho AS Addwho, 
	DailyInventory.EditDate AS EditDate, 
	DailyInventory.EditWho AS EditWho, 
	DailyInventory.InventoryCBM AS InventoryCBM, 
	DailyInventory.InventoryPallet AS InventoryPallet, 
	DailyInventory.CommingleSku AS CommingleSku, 
	DailyInventory.SkuInventoryPallet AS SkuInventoryPallet, 
	DailyInventory.SkuChargingPallet AS SkuChargingPallet, 
	Sku.BUSR9 AS ZoneCategory,
   DailyInventory.Lot As Lot, 
	DailyInventory.QtyAllocated As QtyAllocated, 
	DailyInventory.QtyPicked As QtyPicked, 
	DailyInventory.Pallet As Pallet, 
	DailyInventory.StdCube As StdCube, 
	DailyInventory.Facility As Facility, 
	DailyInventory.HostWhCode As HostWhCode, 
	DailyInventory.LocationFlag As LocationFlag, 
	DailyInventory.Lottable01 As Lottable01, 
	DailyInventory.Lottable02 As Lottable02, 
	DailyInventory.Lottable03 As Lottable03, 
	DailyInventory.Lottable04 As Lottable04, 
	DailyInventory.Lottable05 As Lottable05, 
	DailyInventory.QtyOnhold As QtyOnhold,
	DailyInventory.Lottable06 As Lottable06,
	DailyInventory.Lottable07 As Lottable07,
	DailyInventory.Lottable08 As Lottable08,
	DailyInventory.Lottable09 As Lottable09,
	DailyInventory.Lottable10 As Lottable10,
	DailyInventory.Lottable11 As Lottable11,
	DailyInventory.Lottable12 As Lottable12,
	DailyInventory.Lottable13 As Lottable13,
	DailyInventory.Lottable14 As Lottable14,
	DailyInventory.Lottable15 As Lottable15
FROM 	DailyInventory (nolock), SKU (nolock)
WHERE DailyInventory.Storerkey = SKU.StorerKey AND 
    	 DailyInventory.Sku = SKU.Sku

GO