SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [dbo].[nspDailyInventory]  AS  
BEGIN  
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
     
    DECLARE 
	@d_inventorydate datetime

    SELECT @d_inventorydate = CONVERT(smalldatetime, CONVERT(char(8), GETDATE() - 1, 112), 112)

 /* Just in case this sp have been run twice, so have to delete first before insert */  
    PRINT 'Delete from DailyInventory'
    DELETE FROM DailyInventory WHERE datediff (day, getdate() - 1, inventorydate) = 0  
  
    PRINT 'Insert into  DailyInventory'
    INSERT INTO DailyInventory (Storerkey, Sku, Loc, Id, Qty, InventoryDate)  
    SELECT storerkey, sku, loc, id, sum(qty - qtypicked), @d_inventorydate
    FROM lotxlocxid (nolock) 
    GROUP BY storerkey, sku, loc, id  
  
    PRINT 'Update Location InventoryCBM in DailyInventory'
    Select lli.Loc, Sum(lli.qty*s.stdcube) InventoryCBM
    Into #LocCBM
    from lotxlocxid lli (nolock), Sku s (nolock)
    where lli.storerkey = s.storerkey and lli.sku = s.sku
    group by lli.Loc

    UPDATE DailyInventory
    SET InventoryCBM = #LocCBM.InventoryCBM
    FROM #LocCBM
    Where DailyInventory.Loc = #LocCBM.Loc and 
	  inventorydate = @d_inventorydate

    PRINT 'Update Location InventoryPallet in DailyInventory'
    SELECT  di.inventorydate, di.loc, 
            inventorypallet = sum(case when p.pallet = 0 and (di.qty*s.stdcube)/1.6 < 0.001 then 0.001
			  	   when p.pallet = 0 and (di.qty*s.stdcube)/1.6 >=0.001 then (di.qty*s.stdcube)/1.6
				   when p.pallet > 0 and (di.qty/p.pallet) < 0.001 then 0.001
				   else di.qty/p.pallet end)
    INTO #LocInvPallet
    FROM dailyinventory di (nolock), sku s (nolock), pack p (nolock), loc l (nolock)
    WHERE di.storerkey = s.storerkey and di.sku = s.sku and
          s.packkey = p.packkey and di.loc = l.loc and 
          di.inventorydate = @d_inventorydate
    GROUP BY di.inventorydate, di.loc

    UPDATE DailyInventory
    SET InventoryPallet = #LocInvPallet.InventoryPallet
    FROM #LocInvPallet
    WHERE DailyInventory.loc = #LocInvPallet.Loc and
	  DailyInventory.Inventorydate = #LocInvPallet.Inventorydate and
	  DailyInventory.InventoryDate = @d_inventorydate

    PRINT 'Update Location Commingle Sku Flag in DailyInventory'
    SELECT  di.inventorydate, di.loc, 
            CommingleSku = case 
			   when Count(distinct lli.sku) <=1 then '0' 
                           else '1' end
    INTO #LocCommingleSku
    FROM dailyinventory di (nolock), lotxlocxid lli (nolock)
    WHERE di.loc = lli.loc and 
          di.inventorydate = @d_inventorydate
    GROUP BY di.inventorydate, di.loc

    UPDATE DailyInventory
    SET CommingleSku = #LocCommingleSku.CommingleSku
    FROM #LocCommingleSku
    WHERE DailyInventory.loc = #LocCommingleSku.Loc and
	  DailyInventory.Inventorydate = #LocCommingleSku.Inventorydate and
	  DailyInventory.InventoryDate = @d_inventorydate

    PRINT 'Update Sku InventoryPallet in DailyInventory'
    SELECT  di.inventorydate, di.storerkey, di.sku, di.loc, di.id,
            skuinventorypallet = case when p.pallet = 0 and (di.qty*s.stdcube)/1.6 < 0.001 then 0.001
			  	   when p.pallet = 0 and (di.qty*s.stdcube)/1.6 >=0.001 then (di.qty*s.stdcube)/1.6
				   when p.pallet > 0 and (di.qty/p.pallet) < 0.001 then 0.001
				   else di.qty/p.pallet end
    INTO #InvPallet
    FROM dailyinventory di (nolock), sku s (nolock), pack p (nolock), loc l (nolock)
    WHERE di.storerkey = s.storerkey and di.sku = s.sku and
          s.packkey = p.packkey and di.loc = l.loc and 
          di.inventorydate = @d_inventorydate and di.qty > 0

    UPDATE DailyInventory
    SET SkuInventoryPallet = #InvPallet.SkuInventoryPallet
    FROM #InvPallet
    WHERE DailyInventory.storerkey = #InvPallet.storerkey and
	  DailyInventory.Sku = #InvPallet.sku and
	  DailyInventory.id = #InvPallet.id and
	  DailyInventory.loc = #InvPallet.Loc and
	  DailyInventory.Inventorydate = #InvPallet.Inventorydate and
	  DailyInventory.InventoryDate = @d_inventorydate

PRINT 'Update Sku ChargingPallet in DailyInventory'

    SELECT di.inventorydate, di.storerkey, di.sku, di.loc, di.id, 
	   LocInventoryCBM = di.inventorycbm,
	   LocInventoryPallet = di.inventorypallet, 
	   l.cubiccapacity,
	   di.comminglesku, 
	   InventoryPallet = di.SkuInventoryPallet, 
	   CapacityPallet = l.chargingpallet
    INTO #Chargingpallet
    FROM dailyinventory di, sku s, loc l
    WHERE di.storerkey = s.storerkey and di.sku = s.sku and di.loc = l.loc and
	  di.qty > 0 and di.inventorydate = @d_inventorydate

    UPDATE DailyInventory
    set SkuChargingpallet = 
	case when isnull(cp.cubiccapacity, 0) = 0 then cp.InventoryPallet
	     when cp.LocInventoryCBM > cp.CubicCapacity and cp.CommingleSku = 1 then cp.InventoryPallet
	     when cp.LocInventoryCBM > cp.CubicCapacity and cp.CommingleSku = 0 and cp.CapacityPallet > 1 then cp.InventoryPallet
	     when cp.LocInventoryCBM > cp.CubicCapacity and cp.CommingleSku = 0 and cp.CapacityPallet <=1 and cp.InventoryPallet > cp.CapacityPallet then cp.InventoryPallet
	     when cp.LocInventoryCBM > cp.CubicCapacity and cp.CommingleSku = 0 and cp.CapacityPallet <=1 and cp.InventoryPallet <= cp.CapacityPallet then cp.CapacityPallet 
	     when cp.LocInventoryCBM <= cp.CubicCapacity and cp.CommingleSku = 1 and (cp.CapacityPallet > 1 or cp.CapacityPallet = 0) then cp.InventoryPallet
	     when cp.LocInventoryCBM <= cp.CubicCapacity and cp.CommingleSku = 1 and (cp.CapacityPallet <= 1 or cp.CapacityPallet > 0) then Round(cp.InventoryPallet/cp.LocInventoryPallet*cp.CapacityPallet, 3)
	     when cp.LocInventoryCBM <= cp.CubicCapacity and cp.CommingleSku = 0 and cp.CapacityPallet > 1 then cp.InventoryPallet
	     when cp.LocInventoryCBM <= cp.CubicCapacity and cp.CommingleSku = 0 and cp.CapacityPallet <= 1 and cp.InventoryPallet > cp.CapacityPallet then cp.InventoryPallet
	     when cp.LocInventoryCBM <= cp.CubicCapacity and cp.CommingleSku = 0 and cp.CapacityPallet <= 1 and cp.InventoryPallet <= cp.CapacityPallet then cp.CapacityPallet
	end
     from #chargingpallet cp
     WHERE DailyInventory.storerkey = cp.storerkey and
	  DailyInventory.Sku = cp.sku and
	  DailyInventory.id = cp.id and
	  DailyInventory.loc = cp.Loc and
	  DailyInventory.Inventorydate = cp.Inventorydate and
	  DailyInventory.InventoryDate = @d_inventorydate 

 	DELETE FROM Locbak WHERE datediff (day, getdate() - 1, inventorydate) = 0

	INSERT INTO Locbak (Loc, Locationtype, PutawayZone, InventoryDate)
	SELECT Loc, Locationtype, PutawayZone, GETDATE() - 1  
	  FROM loc (Nolock) 
END  

GO