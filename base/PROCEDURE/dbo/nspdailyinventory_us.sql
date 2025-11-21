SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspDailyInventory_std                              */
/* CreatiON Date: 04.Dec.2006                                           */
/* Copyright: IDS                                                       */
/* Written by: June                                                     */
/*                                                                      */
/* Purpose: Copy FROM nspDailyInventory2 & modify according to SOS51750	*/
/*                                                                      */
/* Called By: SQL Schedule Job                                          */
/*                                                                      */
/* PVCS VersiON: 1.2                                                    */
/*                                                                      */
/* VersiON: 5.4                                                         */
/*                                                                      */
/* Data ModificatiONs:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[nspDailyInventory_US]  AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE  @d_inventorydate datetime
			  ,@c_Storerkey   NVARCHAR(15)
			  ,@b_success     NVARCHAR(1)
			  ,@c_authority NVARCHAR(1)
			  ,@n_err			int
			  ,@c_errmsg	 NVARCHAR(60)
			  ,@b_debug		 NVARCHAR(1)

   SET @d_inventorydate = CONVERT(smalldatetime, CONVERT(char(8), GETDATE() - 1, 112), 112)
	SET @b_debug = 0
   
   /* Just in case this sp have been run twice, so have to delete first before insert */
	IF @b_debug = 1
	BEGIN	
	   PRINT 'Delete FROM DailyInventory'
	END
   DELETE FROM DailyInventory WHERE datediff (day, getdate() - 1, inventorydate) = 0

	/* Get Storerkey & Check DailyInventory Storer CONfigkey Setting */
	DECLARE Storer_cur CURSOR FAST_FORWARD READ_ONLY FOR
		SELECT Storerkey
		FROM   STORER (NOLOCK)
		WHERE  Type = '1'
		Order by Storerkey
	
	OPEN Storer_cur
	FETCH NEXT FROM Storer_cur INTO @c_Storerkey

	WHILE (@@FETCH_STATUS <> -1)
	BEGIN
		SELECT @b_success = 0
		EXECUTE dbo.nspGetRight '', 	-- Facility
					@c_Storerkey,     	-- Storerkey
					NULL,         			-- Sku
					'DailyInventory',    -- CONfigkey
					@b_success    output,
					@c_authority  output, 
					@n_err        output,
					@c_errmsg     output

		IF @b_debug = 1
		BEGIN	
		   PRINT '@c_Storerkey - ' + RTRIM(@c_Storerkey) + ' @c_authority - ' + RTRIM(@c_authority)
		END

		-- Follow nspDailyInventory2 calculatiON
		IF @b_success = 1 AND @c_authority = '1'
		BEGIN
			/******************************************************
					***		nspDailyInventory2	***
		    ******************************************************/
			IF @b_debug = 2
			BEGIN	
			   PRINT 'Insert into  DailyInventory - Use nspDailyInventory2 calculation !'
			END

		   INSERT INTO DailyInventory (Storerkey, Sku, Loc, Id, Qty, InventoryDate, Lot, QtyAllocated, QtyPicked, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, QtyONhold)
		   SELECT storerkey, sku, loc, ' ', sum(qty - qtypicked), @d_inventorydate, ' ', SUM(QtyAllocated), SUM(QtyPicked), '', '', '', '', '', 0
		   FROM   lotxlocxid (NOLOCK)
			WHERE  Storerkey = @c_Storerkey
		   GROUP BY storerkey, sku, loc
		   -- HAVING sum(qty - qtypicked) > 0 --Larry : to capture those qty not yet ship
		
		   PRINT 'Update LocatiON InventoryCBM in DailyInventory'
		   SELECT di.Loc, Sum(di.qty*s.stdcube) InventoryCBM
		   INTO  #LocCBM
		   FROM  DailyInventory di (NOLOCK), Sku s (NOLOCK)
		   WHERE di.storerkey = s.storerkey AND di.sku = s.sku
		   AND   di.inventorydate = @d_inventorydate
			AND   di.Storerkey = @c_Storerkey
		   GROUP BY di.Loc
		
		   UPDATE DailyInventory
		   SET 	 InventoryCBM = #LocCBM.InventoryCBM
		   FROM   #LocCBM
		   WHERE  DailyInventory.Loc = #LocCBM.Loc 
		   AND    inventorydate = @d_inventorydate
			AND    Storerkey = @c_Storerkey
		
		   PRINT 'Update LocatiON InventoryPallet in DailyInventory'
		   SELECT  di.inventorydate, di.loc,
					  inventorypallet = sum(case WHEN p.pallet = 0 AND (di.qty*s.stdcube)/1.6 < 0.001 THEN 0.001
				   	WHEN 	p.pallet = 0 AND (di.qty*s.stdcube)/1.6 >=0.001 THEN (di.qty*s.stdcube)/1.6
				   	WHEN p.pallet > 0 AND (di.qty/p.pallet) < 0.001 THEN 0.001 else di.qty/p.pallet end),
					  Facility = ISNULL(l.Facility, ' '), l.HostWhCode, l.LocatiONFlag
		   INTO 	#LocInvPallet
		   FROM 	dailyinventory di (NOLOCK), sku s (NOLOCK), pack p (NOLOCK), loc l (NOLOCK)
		   WHERE di.storerkey = s.storerkey 
			AND 	di.sku = s.sku 
			AND	s.packkey = p.packkey 
			AND 	di.loc = l.loc 
			AND	di.inventorydate = @d_inventorydate
			AND   di.Storerkey = @c_Storerkey
		   GROUP BY di.inventorydate, di.loc, l.Facility, l.HostWhCode, l.LocatiONFlag
		
		   UPDATE DailyInventory
		   SET 	InventoryPallet = #LocInvPallet.InventoryPallet,
					Facility = #LocInvPallet.Facility,
					HostWhCode = #LocInvPallet.HostWhCode,
					LocatiONFlag = #LocInvPallet.LocatiONFlag
		   FROM 	#LocInvPallet
		   WHERE DailyInventory.loc = #LocInvPallet.Loc 
			AND	DailyInventory.Inventorydate = #LocInvPallet.Inventorydate 
			AND	DailyInventory.InventoryDate = @d_inventorydate
			AND   DailyInventory.Storerkey = @c_Storerkey

		   PRINT 'Update LocatiON Commingle Sku Flag in DailyInventory'
		   SELECT  di.inventorydate, di.loc,
					 CommingleSku = case WHEN Count(distinct di.sku) <=1 THEN '0' else '1' end
		   INTO 	#LocCommingleSku
		   FROM 	dailyinventory di (NOLOCK)
		   WHERE di.qty > 0 AND di.inventorydate = @d_inventorydate
			AND   di.Storerkey = @c_Storerkey
		   GROUP BY di.inventorydate, di.loc
		
		   UPDATE DailyInventory
		   SET 	CommingleSku = #LocCommingleSku.CommingleSku
		   FROM 	#LocCommingleSku
		   WHERE DailyInventory.loc = #LocCommingleSku.Loc 
			AND	DailyInventory.Inventorydate = #LocCommingleSku.Inventorydate 
			AND	DailyInventory.InventoryDate = @d_inventorydate
			AND   DailyInventory.Storerkey = @c_Storerkey

		   PRINT 'Update Sku InventoryPallet in DailyInventory'
		   SELECT di.inventorydate, di.storerkey, di.sku, di.loc, di.id,
				    skuinventorypallet = case WHEN p.pallet = 0 AND (di.qty*s.stdcube)/1.6 < 0.001 THEN 0.001
					   WHEN p.pallet = 0 AND (di.qty*s.stdcube)/1.6 >=0.001 THEN (di.qty*s.stdcube)/1.6
					   WHEN p.pallet > 0 AND (di.qty/p.pallet) < 0.001 THEN 0.001 else di.qty/p.pallet end,
					p.Pallet, s.StdCube
		   INTO  #InvPallet
		   FROM  dailyinventory di (NOLOCK), sku s (NOLOCK), pack p (NOLOCK), loc l (NOLOCK)
		   WHERE di.storerkey = s.storerkey 
			AND 	di.sku = s.sku 
			AND	s.packkey = p.packkey 
			AND 	di.loc = l.loc 
			AND	di.inventorydate = @d_inventorydate 
			AND 	di.qty > 0
			AND   di.Storerkey = @c_Storerkey
		
		   UPDATE DailyInventory
		   SET 	SkuInventoryPallet = #InvPallet.SkuInventoryPallet,
					Pallet  = #InvPallet.Pallet,
					StdCube = #InvPallet.StdCube
		   FROM 	#InvPallet
		   WHERE DailyInventory.storerkey = #InvPallet.storerkey 
			AND	DailyInventory.Sku = #InvPallet.sku 
			AND	DailyInventory.id = #InvPallet.id 
			AND	DailyInventory.loc = #InvPallet.Loc 	
			AND	DailyInventory.Inventorydate = #InvPallet.Inventorydate 
			AND	DailyInventory.InventoryDate = @d_inventorydate
			AND   DailyInventory.Storerkey = @c_Storerkey
		
		   PRINT 'Update Sku ChargingPallet in DailyInventory'		
		   SELECT di.inventorydate, di.storerkey, di.sku, di.loc, di.id,
				   LocInventoryCBM = di.inventorycbm,
				   LocInventoryPallet = di.inventorypallet,
				   l.cubiccapacity,
				   di.comminglesku,
				   InventoryPallet = di.SkuInventoryPallet,
				   CapacityPallet = l.chargingpallet
		   INTO 	#Chargingpallet
		   FROM  dailyinventory di, sku s, loc l
		   WHERE di.storerkey = s.storerkey AND di.sku = s.sku AND di.loc = l.loc 
			AND	di.qty > 0 
			AND 	di.inventorydate = @d_inventorydate
			AND   di.Storerkey = @c_Storerkey				
		
		   UPDATE DailyInventory
		   SET    SkuChargingpallet =
		   CASE WHEN ISNULL(cp.cubiccapacity, 0) = 0 AND cp.InventoryPallet > 0.2
		 		  THEN Ceiling(cp.InventoryPallet)
				   WHEN ISNULL(cp.cubiccapacity, 0) = 0 AND cp.InventoryPallet <= 0.2
				   THEN cp.InventoryPallet
				   WHEN cp.LocInventoryCBM > cp.CubicCapacity AND cp.CommingleSku = 1 AND
				   (cp.CapacityPallet > 1 or cp.CapacityPallet = 0 ) AND
				   (cp.CapacityPallet = 0 AND cp.InventoryPallet > 1)
				   THEN Ceiling(cp.InventoryPallet)
				   WHEN cp.LocInventoryCBM > cp.CubicCapacity AND cp.CommingleSku = 1 AND
				   (cp.CapacityPallet > 1 or cp.CapacityPallet = 0 ) AND
				   not (cp.CapacityPallet = 0 AND cp.InventoryPallet > 1)
				   THEN Round(cp.InventoryPallet/cp.LocInventoryPallet*Ceiling(cp.LocInventoryPallet),3)
				   WHEN cp.LocInventoryCBM > cp.CubicCapacity AND cp.CommingleSku = 1 AND
				   (cp.CapacityPallet <= 1 AND cp.CapacityPallet > 0) AND
				   cp.LocInventoryPallet <= cp.CapacityPallet
				   THEN Round(cp.InventoryPallet/cp.LocInventoryPallet*cp.CapacityPallet,3)
				   WHEN cp.LocInventoryCBM > cp.CubicCapacity AND cp.CommingleSku = 1 AND
				   (cp.CapacityPallet <= 1 or cp.CapacityPallet > 0) AND
				   cp.LocInventoryPallet > cp.CapacityPallet
				   THEN Round(cp.InventoryPallet/cp.LocInventoryPallet*Ceiling(cp.LocInventoryPallet),3)
				   WHEN cp.LocInventoryCBM > cp.CubicCapacity AND cp.CommingleSku = 0 AND
				   (cp.CapacityPallet > 1 or cp.CapacityPallet = 0) AND
				   cp.InventoryPallet <= 0.2
				   THEN cp.InventoryPallet
				   WHEN cp.LocInventoryCBM > cp.CubicCapacity AND cp.CommingleSku = 0 AND
				   (cp.CapacityPallet > 1 or cp.CapacityPallet = 0) AND
				   cp.InventoryPallet > 0.2
				   THEN Ceiling(cp.InventoryPallet)
				   WHEN cp.LocInventoryCBM > cp.CubicCapacity AND cp.CommingleSku = 0 AND
				   (cp.CapacityPallet > 0 AND cp.CapacityPallet <=1) AND
				   cp.InventoryPallet > cp.CapacityPallet
				   THEN cp.InventoryPallet
				   WHEN cp.LocInventoryCBM > cp.CubicCapacity AND cp.CommingleSku = 0 AND
				   (cp.CapacityPallet > 0 AND cp.CapacityPallet <=1) AND
				   cp.InventoryPallet <= cp.CapacityPallet
				   THEN cp.CapacityPallet
				   WHEN cp.LocInventoryCBM <= cp.CubicCapacity AND cp.CommingleSku = 1 AND
				   (cp.CapacityPallet > 1 or cp.CapacityPallet = 0) AND
				   (cp.CapacityPallet = 0 AND cp.InventoryPallet > 1)
				   THEN Ceiling(cp.InventoryPallet)
				   WHEN cp.LocInventoryCBM <= cp.CubicCapacity AND cp.CommingleSku = 1 AND
				   (cp.CapacityPallet > 1 or cp.CapacityPallet = 0) AND
				   not (cp.CapacityPallet = 0 AND cp.InventoryPallet > 1)
				   THEN Round(cp.InventoryPallet/cp.LocInventoryPallet*Ceiling(cp.LocInventoryPallet),3)
				   WHEN cp.LocInventoryCBM <= cp.CubicCapacity AND cp.CommingleSku = 1 AND
				   not (cp.CapacityPallet > 1 or cp.CapacityPallet = 0)
				   THEN Round(cp.InventoryPallet/cp.LocInventoryPallet*cp.CapacityPallet, 3)
				   WHEN cp.LocInventoryCBM <= cp.CubicCapacity AND cp.CommingleSku = 0 AND
				   cp.CapacityPallet > 1 AND cp.InventoryPallet <= 0.2
				   THEN cp.InventoryPallet
				   WHEN cp.LocInventoryCBM <= cp.CubicCapacity AND cp.CommingleSku = 0 AND
				   cp.CapacityPallet > 1 AND cp.InventoryPallet > 0.2
				   THEN Ceiling(cp.InventoryPallet)
				   WHEN cp.LocInventoryCBM <= cp.CubicCapacity AND cp.CommingleSku = 0 AND
				   cp.CapacityPallet <= 1 AND cp.InventoryPallet > cp.CapacityPallet
				   THEN cp.InventoryPallet
				   WHEN cp.LocInventoryCBM <= cp.CubicCapacity AND cp.CommingleSku = 0 AND
				   cp.CapacityPallet <= 1 AND cp.InventoryPallet <= cp.CapacityPallet
				   THEN cp.CapacityPallet
			END
			FROM  #chargingpallet cp
			WHERE DailyInventory.storerkey = cp.storerkey 
			AND	DailyInventory.Sku = cp.sku 
			AND	DailyInventory.id = cp.id 
			AND	DailyInventory.loc = cp.Loc 
			AND	DailyInventory.Inventorydate = cp.Inventorydate 
			AND	DailyInventory.InventoryDate = @d_inventorydate
			AND   DailyInventory.Storerkey = @c_Storerkey				

			DROP TABLE #LocCBM
			DROP TABLE #LocInvPallet
			DROP TABLE #LocCommingleSku
			DROP TABLE #InvPallet
			DROP TABLE #Chargingpallet
		END
		ELSE
		BEGIN 
			/******************************************************
					***		Snapshot FROM LotxLocxID ***
		    ******************************************************/
			IF @b_debug = 2
			BEGIN	
			   PRINT 'Insert into  DailyInventory - Use LotxLocxID !'
			END

		   INSERT INTO DailyInventory (Storerkey, Sku, Loc, Id, Qty, InventoryDate,
							InventoryCBM, InventoryPallet, CommingleSKU, SKUInventoryPallet, SKUChargingPallet,				
							Lot, QtyAllocated, QtyPicked, Pallet, StdCube,
							Facility, HostWhCode, LocatiONFlag, 
							Lottable01, Lottable02, Lottable03, Lottable04, Lottable05)			
		   SELECT lll.storerkey, lll.sku, lll.loc, lll.ID, sum(lll.qty - lll.qtypicked), @d_inventorydate, 
							0, 0, '', 0, 0, 
							lll.Lot, SUM(lll.QtyAllocated), SUM(lll.QtyPicked), p.Pallet, s.StdCube, 
							ISNULL(l.Facility, ' '), l.HostWhCode, l.LocatiONFlag, 
							la.Lottable01, la.Lottable02, la.Lottable03, la.Lottable04, la.Lottable05
		   FROM   lotxlocxid lll (NOLOCK), loc l (NOLOCK), sku s (NOLOCK), pack p (NOLOCK), lotattribute la (NOLOCK)		
			WHERE lll.loc = l.loc
			AND   lll.Storerkey = s.storerkey
			AND   lll.Sku = s.sku
			AND   s.Packkey = p.Packkey
			AND   lll.Lot = la.lot
			AND   lll.Storerkey   = @c_Storerkey			
		   GROUP BY lll.storerkey, lll.sku, lll.loc, lll.ID, lll.Lot, p.Pallet, s.StdCube, 
							l.Facility, l.HostWhCode, l.LocatiONFlag, 
							la.Lottable01, la.Lottable02, la.Lottable03, la.Lottable04, la.Lottable05
		   HAVING sum(lll.qty - lll.qtypicked) > 0

			-- Start : Find QtyONhold 
			SELECT lot.storerkey, lot.sku, lotxlocxid.loc, la.lottable01, la.lottable02, la.lottable03, la.lottable04, la.lottable05, sum(lotxlocxid.qty - lotxlocxid.qtyallocated - lotxlocxid.qtypicked) as QtyONHold
			INTO   #QtyOnhold
			FROM lot (NOLOCK)
			JOIN lotxlocxid (NOLOCK) ON lotxlocxid.lot = lot.lot 
			JOIN loc (NOLOCK) ON loc.loc = lotxlocxid.loc 
			JOIN lotattribute la (NOLOCK) ON la.lot = lotxlocxid.lot
			WHERE lot.status = 'HOLD'
			AND   lotxlocxid.Storerkey = @c_Storerkey
			GROUP BY lot.storerkey, lot.sku, lotxlocxid.loc, la.lottable01, la.lottable02, la.lottable03, la.lottable04, la.lottable05 
			HAVING sum(lotxlocxid.qty - lotxlocxid.qtyallocated - lotxlocxid.qtypicked) <> 0 

			UNION ALL			
			SELECT lotxlocxid.storerkey, lotxlocxid.sku, lotxlocxid.loc, la.lottable01, la.lottable02, la.lottable03, la.lottable04, la.lottable05, sum(lotxlocxid.qty - lotxlocxid.qtyallocated - lotxlocxid.qtypicked) + sum( ISNULL(OA_LLL.qty,0) - ISNULL(OA_LLL.qtyallocated,0) - ISNULL(OA_LLL.qtypicked,0)) as QtyONHold
			FROM lotxlocxid (NOLOCK)
			JOIN lot (NOLOCK) ON lot.lot = lotxlocxid.lot 
			JOIN loc (NOLOCK) ON lotxlocxid.loc = loc.loc
			JOIN id (NOLOCK) ON lotxlocxid.id = id.id 
			JOIN lotattribute la (NOLOCK) ON la.lot = lotxlocxid.lot
			LEFT OUTER JOIN lotxlocxid OA_LLL (NOLOCK) ON lotxlocxid.lot = OA_LLL.lot 
			     -- and lotxlocxid.id = OA_LLL.id 
			     and (OA_LLL.Qty - OA_LLL.qtyallocated - OA_LLL.qtypicked) < 0 
			     and OA_LLL.loc <> lotxlocxid.loc
			LEFT OUTER JOIN LOC bLOC (NOLOCK) ON bLOC.LOC = OA_LLL.LOC and (bLOC.STATUS <> "HOLD" AND bLOC.LocatiONFlag <> "HOLD" AND bLOC.LocatiONFlag <> "DAMAGE")
			WHERE lot.status <> 'HOLD'
			AND (LOC.STATUS = "HOLD" OR LOC.LocatiONFlag = "HOLD" OR LOC.LocatiONFlag = "DAMAGE")
			AND id.status = 'OK' 
			AND la.Storerkey = @c_Storerkey
			GROUP BY lotxlocxid.storerkey, lotxlocxid.sku, lotxlocxid.loc, la.lottable01, la.lottable02, la.lottable03, la.lottable04, la.lottable05
			HAVING sum(lotxlocxid.qty - lotxlocxid.qtyallocated - lotxlocxid.qtypicked) <> 0 

			UNION ALL
			SELECT lotxlocxid.storerkey, lotxlocxid.sku, lotxlocxid.loc, la.lottable01, la.lottable02, la.lottable03, la.lottable04, la.lottable05, sum(lotxlocxid.qty - lotxlocxid.qtyallocated - lotxlocxid.qtypicked) as QtyONHold
			FROM lotxlocxid (NOLOCK)
			JOIN lot (NOLOCK) ON lot.lot = lotxlocxid.lot 
			JOIN loc (NOLOCK) ON lotxlocxid.loc = loc.loc
			JOIN id (NOLOCK) ON lotxlocxid.id = id.id 
			JOIN lotattribute la (NOLOCK) ON la.lot = lotxlocxid.lot
			WHERE lot.status <> 'HOLD'
			AND (loc.locatiONFlag <> 'HOLD' AND LOC.LocatiONFlag <> "DAMAGE" AND loc.Status <> 'HOLD')
			AND id.status = 'HOLD' 
			AND lotxlocxid.storerkey = @c_storerkey
			GROUP BY lotxlocxid.storerkey, lotxlocxid.sku, lotxlocxid.loc, la.lottable01, la.lottable02, la.lottable03, la.lottable04, la.lottable05 
			HAVING sum(lotxlocxid.qty - lotxlocxid.qtyallocated - lotxlocxid.qtypicked) <> 0 
			-- End : Find QtyONhold 

		   UPDATE DailyInventory
		   SET 	QtyOnhold = #QtyOnhold.QtyOnhold
		   FROM 	#QtyOnhold
		   WHERE DailyInventory.Storerkey = #QtyOnhold.Storerkey 
			AND   DailyInventory.Sku = #QtyOnhold.Sku 
			AND   DailyInventory.Loc = #QtyOnhold.Loc
			AND   DailyInventory.Lottable01 = #QtyOnhold.Lottable01
			AND   DailyInventory.Lottable02 = #QtyOnhold.Lottable02
			AND   DailyInventory.Lottable03 = #QtyOnhold.Lottable03
			AND   DailyInventory.Lottable04 = #QtyOnhold.Lottable04
			AND   DailyInventory.Lottable05 = #QtyOnhold.Lottable05
			AND	DailyInventory.InventoryDate = @d_inventorydate
			AND   DailyInventory.Storerkey = @c_Storerkey

			DROP TABLE #QtyOnhold
		END		

		FETCH NEXT FROM Storer_cur INTO @c_Storerkey
	END -- While

	CLOSE Storer_cur
	DEALLOCATE Storer_cur
END

GO