SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


CREATE PROC [dbo].[nsp_FullPallet_ReplenishmentRpt03]
					@c_zone01           NVARCHAR(10)
,              @c_zone02           NVARCHAR(10)
,              @c_zone03           NVARCHAR(10)
,              @c_zone04           NVARCHAR(10)
,              @c_zone05           NVARCHAR(10)
,              @c_zone06           NVARCHAR(10)
,              @c_zone07           NVARCHAR(10)
,              @c_zone08           NVARCHAR(10)
,              @c_zone09           NVARCHAR(10)
,              @c_zone10           NVARCHAR(10)
,              @c_zone11           NVARCHAR(10)
,              @c_zone12           NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE        @n_continue int          /* continuation flag
   1=Continue
   2=failed but continue processsing
   3=failed do not continue processing
   4=successful but skip furthur processing */
   DECLARE @b_debug int,
   @c_Packkey NVARCHAR(10),
   @c_UOM     NVARCHAR(10), -- SOS 8935 wally 13.dec.2002 from NVARCHAR(5) to NVARCHAR(10)
   @n_pallet int,
	@n_serialno int  -- SOS21873
   SELECT @n_continue=1,   @b_debug = 0
   DECLARE @c_priority  NVARCHAR(5)
	DECLARE @c_PickCode NVARCHAR(10)

   SELECT StorerKey, SKU, LOC FromLOC, LOC ToLOC, Lot, Id, Qty, Qty QtyMoved, Qty QtyInPickLOC,
		   @c_priority Priority, Lot UOM, Lot PackKey
   INTO #REPLENISHMENT
   FROM LOTXLOCXID (NOLOCK)
   WHERE 1 = 2

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @c_currentSKU NVARCHAR(20), @c_CurrentStorer NVARCHAR(15),
      @c_currentLOC NVARCHAR(10), @c_CurrentPriority NVARCHAR(5),
      @n_currentfullcase int, @n_currentfullpallet int, @n_CurrentSeverity int,
      @c_fromLOC NVARCHAR(10), @c_fromlot NVARCHAR(10), @c_fromid NVARCHAR(18),
      @n_fromqty int, @n_remainingqty int, @n_possiblecases int ,
      @n_remainingcases int, @n_OnHandQty int, @n_fromcases int ,
      @c_ReplenishmentKey NVARCHAR(10), @n_numberofrecs int, @n_limitrecs int,
      @c_fromlot2 NVARCHAR(10),
      @b_DoneCheckOverAllocatedLots int,
      @n_SKULOCavailableqty int
      SELECT @c_currentSKU = SPACE(20), @c_CurrentStorer = SPACE(15),
      @c_currentLOC = SPACE(10), @c_CurrentPriority = SPACE(5),
      @n_currentfullcase = 0   , @n_CurrentSeverity = 9999999 ,
      @n_fromqty = 0, @n_remainingqty = 0, @n_possiblecases = 0,
      @n_remainingcases =0, @n_fromcases = 0, @n_numberofrecs = 0,
      @n_limitrecs = 5

      /* Make a temp version of SKUxLOC */
      SELECT ReplenishmentPriority, ReplenishmentSeverity, StorerKey,
		      SKU, LOC, ReplenishmentCasecnt, Pallet = 0
      INTO #TempSKUxLOC
      FROM SKUxLOC (NOLOCK)

/*
CASE WHEN SKUxLOC.Qty - (QtyAllocated+QtyPicked) < 0 AND (ABS(SKUxLOC.Qty-(QtyAllocated+QtyPicked)) % CAST(PACK.PALLET AS INT) > 0)
	  THEN (ABS(SKUxLOC.Qty-(QtyAllocated+QtyPicked))  / PACK.PALLET) + 1
	  WHEN SKUXLOC.Qty - (QtyAllocated+QtyPicked) < 0 AND (ABS(SKUxLOC.Qty-(QtyAllocated+QtyPicked)) % CAST(PACK.PALLET AS INT) <= 0)
	  THEN (ABS(SKUxLOC.Qty-(QtyAllocated+QtyPicked))  / PACK.PALLET) 
	  WHEN SKUxLOC.Qty - QtyPicked <= SKUXLOC.QtyLocationMinimum 
	  THEN 1 END,
*/
     
		WHERE 1=2
      IF (@c_zone02 = 'ALL')
      BEGIN
          INSERT #TempSKUxLOC 
          SELECT SKUxLOC.ReplenishmentPriority, 
          ReplenishmentSeverity = 
			 ISNULL(CASE WHEN SKUxLOC.Qty - (QtyAllocated+QtyPicked) < 0 
				  THEN (QtyAllocated+QtyPicked) - SKUxLOC.Qty
				  WHEN SKUxLOC.Qty - (QtyAllocated+QtyPicked) <= SKUXLOC.QtyLocationMinimum 
				  THEN ReplenishmentCasecnt
				  END, 0),
          SKUxLOC.StorerKey,
          SKUxLOC.SKU, 
          SKUxLOC.LOC, 
          ReplenishmentCasecnt = CASE WHEN PACK.CaseCnt > 0 THEN PACK.CaseCnt ELSE 1 END,
			 PALLET = ISNULL(PACK.Pallet, 0)
          FROM SKUxLOC (NOLOCK), LOC (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
          WHERE SKUxLOC.LOC = LOC.LOC
          AND  LOC.LocationFlag NOT IN ("DAMAGE", "HOLD") 
          AND  (SKUxLOC.LocationType = "PICK" or SKUxLOC.LocationType = "CASE")
			 AND  (SKUxLOC.Qty - SKUxLOC.QtyPicked - skuxloc.QtyAllocated <= SKUxLOC.QtyLocationMinimum)
          AND  LOC.FACILITY = @c_Zone01
          AND  SKUxLOC.StorerKey = SKU.StorerKey
          AND  SKUxLOC.SKU = SKU.SKU
          AND  SKU.PackKey = PACK.PACKKey
      END
      ELSE
      BEGIN
          INSERT #TempSKUxLOC 
          SELECT SKUxLOC.ReplenishmentPriority, 
          ReplenishmentSeverity = 
			 ISNULL(CASE WHEN SKUxLOC.Qty - (QtyAllocated+QtyPicked) < 0 
				  THEN (QtyAllocated+QtyPicked) - SKUxLOC.Qty
				  WHEN SKUxLOC.Qty - (QtyAllocated+QtyPicked) <= SKUXLOC.QtyLocationMinimum 
				  THEN ISNULL(ReplenishmentCasecnt, 1)
				  END, 0),
          SKUxLOC.StorerKey,
          SKUxLOC.SKU, 
          SKUxLOC.LOC, 
          ReplenishmentCasecnt = CASE WHEN PACK.CaseCnt > 0 THEN PACK.CaseCnt ELSE 1 END,
			 PALLET = ISNULL(PACK.PALLET, 0)
          FROM SKUxLOC (NOLOCK), LOC (NOLOCK), SKU (NOLOCK), PACK (NOLOCK)
          WHERE SKUxLOC.LOC = LOC.LOC
          AND  LOC.LocationFlag NOT IN ("DAMAGE", "HOLD") 
          AND  (SKUxLOC.LocationType = "PICK" or SKUxLOC.LocationType = "CASE")
        	 AND  (SKUxLOC.Qty - SKUxLOC.QtyPicked - skuxloc.QtyAllocated <= SKUxLOC.QtyLocationMinimum )
          AND  LOC.FACILITY = @c_Zone01
          AND  LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
          AND  SKUxLOC.StorerKey = SKU.StorerKey
          AND  SKUxLOC.SKU = SKU.SKU
          AND  SKU.PackKey = PACK.PACKKey
      END

      -- Added By SHONG
      -- Date: 16th JUL 2001
      -- Purpose: To Speed up the process
      -- Remove all the rows that got not inventory to replenish
      DECLARE  @c_StorerKey  NVARCHAR(15),
	            @c_SKU		  NVARCHAR(20),
	            @c_LOC        NVARCHAR(10)
      
      DECLARE CUR1 CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT StorerKey, SKU, LOC
      FROM   #tempskuxloc
      ORDER BY StorerKey, SKU, LOC
      			
      OPEN CUR1
      FETCH NEXT FROM CUR1 INTO @c_StorerKey, @c_SKU, @c_LOC
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF NOT EXISTS( SELECT 1 FROM SKUxLOC (NOLOCK), LOC (NOLOCK)
                        WHERE StorerKey = @c_StorerKey
                        AND   SKU = @c_SKU
                        AND   SKUxLOC.LOC <> @c_LOC
                        AND   LOC.LOC = SKUxLOC.LOC
                        AND   LOC.Locationflag <> 'DAMAGE'
                        AND   LOC.Locationflag <> 'HOLD'
                        AND   SKUxLOC.Qty - QtyPicked - QtyAllocated > 0
                        AND   LOC.Facility = @c_zone01)
         BEGIN
            DELETE #tempskuxloc
            WHERE Storerkey = @c_StorerKey
            AND   SKU = @c_SKU	
         END
         FETCH NEXT FROM CUR1 INTO @c_StorerKey, @c_SKU, @c_LOC
      END
      DEALLOCATE CUR1

      WHILE (1=1)
      BEGIN
         IF @c_zone02 = "ALL"
         BEGIN
            SET ROWCOUNT 1
            SELECT @c_CurrentPriority = ReplenishmentPriority
            FROM  #TempSKUxLOC
            WHERE ReplenishmentPriority > @c_CurrentPriority
            AND   ReplenishmentCasecnt > 0
            ORDER BY ReplenishmentPriority
         END
    	   ELSE
         BEGIN
            SET ROWCOUNT 1
            SELECT @c_CurrentPriority = ReplenishmentPriority
            FROM  #TempSKUxLOC
            WHERE ReplenishmentPriority > @c_CurrentPriority
            AND   ReplenishmentCasecnt > 0
            ORDER BY ReplenishmentPriority
         END
         IF @@ROWCOUNT = 0
         BEGIN
            SET ROWCOUNT 0
            BREAK
         END
         SET ROWCOUNT 0
         /* Loop through SKUxLOC for the currentSKU, current storer */
         /* to pickup the next severity */

         SELECT @n_CurrentSeverity = 999999999
         WHILE (1=1)
         BEGIN
            SET ROWCOUNT 1
            SELECT @n_CurrentSeverity = ReplenishmentSeverity
            FROM  #TempSKUxLOC
            WHERE ReplenishmentSeverity < @n_CurrentSeverity
            AND   ReplenishmentPriority = @c_CurrentPriority
            AND   ReplenishmentCasecnt > 0
            ORDER BY ReplenishmentSeverity DESC
            IF @@ROWCOUNT = 0
            BEGIN
               SET ROWCOUNT 0
               BREAK
            END
            SET ROWCOUNT 0
            /* Now - for this priority, this severity - find the next storer row */
            /* that matches */
            SELECT @c_currentSKU = SPACE(20), @c_CurrentStorer = SPACE(15),
            @c_currentLOC = SPACE(10)
            WHILE (1=1)
            BEGIN
               SET ROWCOUNT 1
               SELECT @c_CurrentStorer = StorerKey
               FROM  #TempSKUxLOC
               WHERE StorerKey > @c_CurrentStorer
               AND   ReplenishmentSeverity = @n_CurrentSeverity
               AND   ReplenishmentPriority = @c_CurrentPriority
               ORDER BY StorerKey
               IF @@ROWCOUNT = 0
               BEGIN
                  SET ROWCOUNT 0
                  BREAK
               END
               SET ROWCOUNT 0
               /* Now - for this priority, this severity, this storer - find the next SKU row */
               /* that matches */
               SELECT @c_currentSKU = SPACE(20),
		                @c_currentLOC = SPACE(10)
               WHILE (1=1)
               BEGIN
                  SET ROWCOUNT 1
                  SELECT @c_CurrentStorer = StorerKey ,
		                  @c_currentSKU = SKU,
		                  @c_currentLOC = LOC,
		                  @n_currentfullcase = ReplenishmentCasecnt,
								@n_currentfullpallet = Pallet
                  FROM #TempSKUxLOC
                  WHERE SKU > @c_currentSKU
                  AND StorerKey = @c_CurrentStorer
                  AND ReplenishmentSeverity = @n_CurrentSeverity
                  AND ReplenishmentPriority = @c_CurrentPriority
                  ORDER BY SKU
                  IF @@ROWCOUNT = 0
                  BEGIN
                     SET ROWCOUNT 0
                     BREAK
                  END
                  SET ROWCOUNT 0
						if @b_debug = 1
						begin
							select @c_storerkey 'Storer', @c_sku 'SKU', @c_loc 'LOC', @c_CurrentPriority 'priority', @n_CurrentSeverity 'Severity', @n_currentfullcase 'FullCase', @n_currentfullpallet 'FullPallet'
						end
                  /* We now have a pickLOCation that needs to be replenished! */
                  /* Figure out which LOCations in the warehouse to pull this product from */
                  SELECT @c_fromLOC = SPACE(10),  @c_fromlot = SPACE(10), @c_fromid = SPACE(18),
		                  @n_fromqty = 0, @n_possiblecases = 0,
--		                  @n_remainingqty = @n_CurrentSeverity * @n_currentfullpallet,
--		                  @n_remainingcases = @n_CurrentSeverity / @n_currentfullcase,
		                  @n_remainingqty = @n_CurrentSeverity,
		                  @n_remainingcases = @n_CurrentSeverity / @n_currentfullcase,
		                  @c_fromlot2 = SPACE(10),
		                  @b_DoneCheckOverAllocatedLots = 0,
								@n_SerialNo = 0 -- SOS21873

								-- Start SOS21873
								CREATE TABLE #LOT (SerialNo   int IDENTITY(1,1),
								Lot        NVARCHAR(10), 
								Lottable02 NVARCHAR(18),
								ExpiryDate NVARCHAR(20),
								ReceivingDate NVARCHAR(20))
								-- End SOS21873
                    		                  
                  WHILE (1=1)
                  BEGIN
							/*
							SELECT @c_PickCode = PickCode
							FROM  SKU (NOLOCK)
							WHERE StorerKey = @c_CurrentStorer
							AND   SKU = @c_CurrentSKU
							*/                  

                     /* See if there are any lots where the QTY is overalLOCated... */
                     /* if Yes then uses this lot first... */
                     -- That means that the last try at this section of code was successful therefore try again.
                     IF @b_DoneCheckOverAllocatedLots = 0
                     BEGIN
						     IF @c_zone02 = "ALL"
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_fromlot2 = LOTxLOCxID.LOT
                           FROM  LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK)
                           WHERE LOTxLOCxID.LOT > @c_fromlot2
                           AND LOTxLOCxID.StorerKey = @c_CurrentStorer
                           AND LOTxLOCxID.SKU = @c_currentSKU
                           AND LOTxLOCxID.LOC = LOC.LOC
                           AND LOC.LOCationflag <> "DAMAGE"
                           AND LOC.LOCationflag <> "HOLD"
                           AND LOTxLOCxID.qtyexpected > 0
                           AND LOTxLOCxID.LOC = @c_currentLOC
                           AND LOC.Facility = @c_zone01 -- SOS15634
                           AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
                           AND LOC.Status = 'OK' -- SOS 16944
                           ORDER BY LOTTABLE02, LOTTABLE04, LOTTABLE05
                        END
                        ELSE
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_fromlot2 = LOTxLOCxID.LOT
                           FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK)
                           WHERE LOTxLOCxID.LOT > @c_fromlot2
                           AND LOTxLOCxID.StorerKey = @c_CurrentStorer
                           AND LOTxLOCxID.SKU = @c_currentSKU
                           AND LOTxLOCxID.LOC = LOC.LOC
                           AND LOTxLOCxID.qtyexpected > 0
                           AND LOTxLOCxID.LOC = @c_currentLOC
                           AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
                           AND LOC.Facility = @c_zone01 -- SOS15634
                           AND LOC.Status = 'OK' -- SOS 16944
                           ORDER BY LOTTABLE02, LOTTABLE04, LOTTABLE05
                        END
                        
							   IF @@ROWCOUNT = 0
								BEGIN
									SELECT @b_DoneCheckOverAllocatedLots = 1
									SELECT @c_fromlot = ""
									IF @b_debug = 1
									BEGIN
									   SELECT 'Overallocation - Not Lot Available! SKU= ' + @c_currentSKU + ' LOC=' + @c_currentLOC
									END
								END
                     	ELSE
                        	SELECT @b_DoneCheckOverAllocatedLots = 1
                     END --IF @b_DoneCheckOverAllocatedLots = 0
                     

							-- Remark by June, 06.APR.04 - Start SOS21873                     
                     /*
                     /* End see if there are any lots where the QTY is overalLOCated... */
                     SET ROWCOUNT 0
                     /* If there are not lots overalLOCated in the candidate LOCation, simply pull lots into the LOCation by lot # */
                     IF @b_DoneCheckOverAllocatedLots = 1
                     BEGIN
                        /* Select any lot if no lot was over alLOCated */
                        IF @c_zone02 = "ALL"
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_fromlot = LOTxLOCxID.LOT
                           FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK)
                           WHERE LOTxLOCxID.LOT > @c_fromlot
                           AND LOTxLOCxID.StorerKey = @c_CurrentStorer
                           AND LOTxLOCxID.SKU = @c_currentSKU
                           AND LOTxLOCxID.LOC = LOC.LOC
                           AND LOC.LOCationflag <> "DAMAGE"
                           AND LOC.LOCationflag <> "HOLD"
                           AND LOTxLOCxID.qty - qtypicked - qtyalLOCated > 0
                           AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
                           AND LOTxLOCxID.LOC <> @c_currentLOC
                           AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
                           AND LOC.Facility = @c_zone01 -- SOS15634
                           AND LOC.Status = 'OK' -- SOS 16944
                           ORDER BY LOTTABLE02, LOTTABLE04, LOTTABLE05
								END
                        ELSE
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_fromlot = LOTxLOCxID.LOT
                           FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK)
                           WHERE LOTxLOCxID.LOT > @c_fromlot
                           AND LOTxLOCxID.StorerKey = @c_CurrentStorer
                           AND LOTxLOCxID.SKU = @c_currentSKU
                           AND LOTxLOCxID.LOC = LOC.LOC
                           AND LOC.LOCationflag <> "DAMAGE"
                           AND LOC.LOCationflag <> "HOLD"
                           AND LOTxLOCxID.qty - qtypicked - qtyalLOCated > 0
                           AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demand
                           AND LOTxLOCxID.LOC <> @c_currentLOC
                           AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
                           AND LOC.Facility = @c_zone01 -- SOS15634
                           AND LOC.Status = 'OK' -- SOS 16944
                           ORDER BY LOTTABLE02, LOTTABLE04, LOTTABLE05
                        END
                        IF @@ROWCOUNT = 0
                        BEGIN
                           IF @b_debug = 1
                           SELECT 'Overallocation - Not Lot Available! SKU= ' + @c_currentSKU + ' LOC=' + @c_currentLOC
                           SET ROWCOUNT 0
                           BREAK
                        END
                        SET ROWCOUNT 0
                     END
                     ELSE
                     BEGIN
                        SELECT @c_fromlot = @c_fromlot2
	                  END -- IF @b_DoneCheckOverAllocatedLots = 1
							*/

                     /* End see if there are any lots where the QTY is overalLOCated... */
                     SET ROWCOUNT 0
                     /* If there are not lots overallocated in the candidate Location, simply pull lots into the Location by lot # */
                     IF @b_DoneCheckOverAllocatedLots = 1
                     BEGIN                     
								/*
                        IF dbo.fnc_RTrim(@c_PickCode) IS NOT NULL AND dbo.fnc_RTrim(@c_PickCode) <> ''
                        BEGIN
                           INSERT INTO #LOT (Lot, Lottable02, ExpiryDate, ReceivingDate)                           
                           EXEC(@c_PickCode + " '" + @c_CurrentStorer + "',"
                                            + " '" + @c_CurrentSKU + "',"
                                            + " '" + @c_CurrentLOC + "',"
                                            + " '" + @c_zone01 + "',"
                                            + " '" + @c_fromlot2 + "'" )
                           IF @b_debug = 1
                           BEGIN
    									print "EXEC " + @c_PickCode + " '" + dbo.fnc_RTrim(@c_CurrentStorer) + "',"
                                            + " '" + dbo.fnc_RTrim(@c_CurrentSKU) + "',"
                                            + " '" + dbo.fnc_RTrim(@c_CurrentLOC) + "',"
                                            + " '" + dbo.fnc_RTrim(@c_zone01) + "',"
                                            + " '" + dbo.fnc_RTrim(@c_fromlot2) + "'"
                           END 
                        END
                        ELSE 
                        BEGIN							                       
								*/
                           INSERT INTO #LOT (Lot, LOTTABLE02, ExpiryDate, ReceivingDate) 
                           SELECT DISTINCT LOTxLOCxID.LOT, LOTTABLE02, ISNULL(CONVERT(CHAR, LOTTABLE04, 106), ''), ISNULL(CONVERT(CHAR, LOTTABLE05, 106), '')
                           FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), LOTATTRIBUTE (NOLOCK)
                           WHERE LOTxLOCxID.StorerKey = @c_CurrentStorer
                           AND LOTxLOCxID.SKU = @c_CurrentSKU
                           AND LOTxLOCxID.LOC = LOC.LOC
                           AND LOC.LocationFlag <> "DAMAGE"
                           AND LOC.LocationFlag <> "HOLD"
                           AND LOC.Status <> "HOLD"
                           AND LOC.Facility = @c_zone01
                           AND LOTxLOCxID.LOC <> @c_CurrentLOC
                           AND LOTATTRIBUTE.LOT = LOTxLOCxID.LOT
                           AND LOTxLOCxID.LOT <> ISNULL(@c_fromlot, '')
                           AND ( LOTxLOCxID.qty - (LOTxLOCxID.QtyAllocated + LOTxLOCxID.qtypicked) ) > 0 
                           ORDER BY LOTATTRIBUTE.LOTTABLE02, ISNULL(CONVERT(CHAR, LOTTABLE04, 106), ''), ISNULL(CONVERT(CHAR, LOTTABLE05, 106), '')
								   
									IF @b_debug = 1
                           BEGIN
										SELECT 'Count #Lot', count(*) FROM #LOT 
										-- SELECT 'Insert #Lot', * FROM #LOT 
                           END 
                      	-- END

								IF (SELECT COUNT(*) FROM #LOT) = 0
                        BEGIN
                           BREAK
                        END
                        SELECT @b_DoneCheckOverAllocatedLots = 2
                     END -- IF @b_DoneCheckOverAllocatedLots = 1
                     ELSE 
                     IF @b_DoneCheckOverAllocatedLots = 0
                     BEGIN
                        SELECT @b_DoneCheckOverAllocatedLots = 1
                     END 
							
                     IF @b_DoneCheckOverAllocatedLots = 2 
                     BEGIN
                        SET ROWCOUNT 1
                        SELECT @c_FromLot = LOT,
                               @n_SerialNo = SerialNo 
                        FROM   #LOT
                        WHERE  SerialNo > @n_SerialNo 
                        IF @@ROWCOUNT = 0 
                        BEGIN
                           SET ROWCOUNT 0 
                           IF @b_debug = 1
                              Print 'Not Lot Available! SKU: ' + dbo.fnc_RTrim(@c_CurrentSKU) + ' LOC: ' + dbo.fnc_RTrim(@c_CurrentLOC)
                           BREAK
                        END
                        ELSE
                        BEGIN
                           IF @b_debug = 1
                           BEGIN
                              Print '*** Lot picked from LOTxLOCxID=' + dbo.fnc_RTrim(@c_fromlot)
                           END
                        END 
                        SET ROWCOUNT 0 
                     END
							-- End SOS21873

                     SET ROWCOUNT 0
                     SELECT @c_fromLOC = SPACE(10)
                     WHILE (1=1 AND @n_remainingqty > 0)
                     BEGIN
                        IF @c_zone02 = "ALL"
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_fromLOC = LOTxLOCxID.LOC
                           FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK)
                           WHERE LOT = @c_fromlot
                           AND LOTxLOCxID.LOC = LOC.LOC
                           AND LOTxLOCxID.LOC > @c_fromLOC
                           AND StorerKey = @c_CurrentStorer
                           AND SKU = @c_currentSKU
                           AND LOTxLOCxID.LOC = LOC.LOC
                           AND LOC.LOCationflag <> "DAMAGE"
                           AND LOC.LOCationflag <> "HOLD"
                           AND LOTxLOCxID.qty - qtypicked - qtyalLOCated > 0
                           AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
                           AND LOTxLOCxID.LOC <> @c_currentLOC
                           AND LOC.Facility = @c_zone01 -- SOS15634
                           AND LOC.Status = 'OK' -- SOS 16944
                           ORDER BY LOTxLOCxID.LOC
                        END
                     ELSE
                        BEGIN
                           SET ROWCOUNT 1
                           SELECT @c_fromLOC = LOTxLOCxID.LOC
                           FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK)
                           WHERE LOT = @c_fromlot
                           AND LOTxLOCxID.LOC = LOC.LOC
                           AND LOTxLOCxID.LOC > @c_fromLOC
                           AND StorerKey = @c_CurrentStorer
                           AND SKU = @c_currentSKU
                           AND LOTxLOCxID.LOC = LOC.LOC
                           AND LOC.LOCationflag <> "DAMAGE"
                           AND LOC.LOCationflag <> "HOLD"
                           AND LOTxLOCxID.qty - qtypicked - qtyalLOCated > 0
								   AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
                           AND LOTxLOCxID.LOC <> @c_currentLOC
                           AND LOC.Facility = @c_zone01 -- SOS15634
                           AND LOC.Status = 'OK' -- SOS 16944
                           ORDER BY LOTxLOCxID.LOC

                        END
                        IF @@ROWCOUNT = 0
                        BEGIN
                           IF @b_debug = 1
                           SELECT 'Not LOC Available! SKU= ' + @c_currentSKU + ' From Lot=' + @c_fromlot

                           SET ROWCOUNT 0
                           BREAK
                        END
                        SET ROWCOUNT 0
                        SELECT @c_fromid = replicate('Z',18)
                        WHILE (1=1 AND @n_remainingqty > 0)
                        BEGIN
                           IF @c_zone02 = "ALL"
                           BEGIN
                              SET ROWCOUNT 1
                              SELECT @c_fromid = ID,
   		                           @n_OnHandQty = LOTxLOCxID.QTY - QTYPICKED - QTYALLOCATED
	                           FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK)
                              WHERE LOT = @c_fromlot
                              AND LOTxLOCxID.LOC = LOC.LOC
                              AND LOTxLOCxID.LOC = @c_fromLOC
                              AND id < @c_fromid
                              AND StorerKey = @c_CurrentStorer
                              AND SKU = @c_currentSKU
                              AND  LOC.LOCationflag <> "DAMAGE"
                              AND  LOC.LOCationflag <> "HOLD"
                              AND LOTxLOCxID.qty - qtypicked - qtyalLOCated > 0
                              AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
                              AND LOTxLOCxID.LOC <> @c_currentLOC
                              AND LOC.Facility = @c_zone01 -- SOS15634
                              AND LOC.Status = 'OK' -- SOS 16944
                              ORDER BY ID DESC
                           END
                        ELSE
                           BEGIN
                              SET ROWCOUNT 1
                              SELECT @c_fromid = ID,
                              @n_OnHandQty = LOTxLOCxID.QTY - QTYPICKED - QTYALLOCATED
                              FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK)
                              WHERE LOT = @c_fromlot
                              AND LOTxLOCxID.LOC = LOC.LOC
                              AND LOTxLOCxID.LOC = @c_fromLOC
                              AND id < @c_fromid
                              AND StorerKey = @c_CurrentStorer
                              AND SKU = @c_currentSKU
                              AND LOC.LOCationflag <> "DAMAGE"
                              AND LOC.LOCationflag <> "HOLD"
                              AND LOTxLOCxID.qty - qtypicked - qtyalLOCated > 0
                              AND LOTxLOCxID.qtyexpected = 0 -- make sure we aren't going to try to pull from a LOCation that needs stuff to satisfy existing demAND
                              AND LOTxLOCxID.LOC <> @c_currentLOC
                              AND LOC.Facility = @c_zone01 -- SOS15634
                              AND LOC.Status = 'OK' -- SOS 16944
                              ORDER BY ID DESC
                           END
                           IF @@ROWCOUNT = 0
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Stop because No Pallet Found! LOC = ' + @c_currentLOC + ' SKU = ' + @c_currentSKU + ' LOT = ' + @c_fromlot + ' From LOC = ' + @c_fromLOC
                                 + ' From ID = ' + @c_fromid
                              END
                              SET ROWCOUNT 0
                              BREAK
                           END
                           ELSE
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Pallet Found! To LOC = ' + @c_currentLOC + ' SKU = ' + @c_currentSKU + ' LOT = ' + @c_fromlot + ' From LOC = ' + @c_fromLOC
                                 + ' From ID = ' + @c_fromid
                              END
                           END

                           SET ROWCOUNT 0
                           /* We have a cANDidate FROM record */
                           /* Verify that the cANDidate ID is not on HOLD */
                           /* We could have done this in the SQL statements above */
                           /* But that would have meant a 5-way join.             */
                           /* SQL SERVER seems to work best on a maximum of a     */
                           /* 4-way join.                                         */
                           IF EXISTS(SELECT * FROM ID (NOLOCK) WHERE ID = @c_fromid
                           AND STATUS = "HOLD")
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Stop because LOCation Status = HOLD! LOC = ' + @c_currentLOC + ' SKU = ' + @c_currentSKU + ' ID = ' + @c_fromid
                              END
                              BREAK -- Get out of loop, so that next cANDidate can be evaluated
                           END
                           /* Verify that the from LOCation is not overalLOCated in SKUxLOC */
                           IF EXISTS(SELECT * FROM SKUxLOC (NOLOCK)
		                           WHERE StorerKey = @c_CurrentStorer
		                           AND SKU = @c_currentSKU
		                           AND LOC = @c_fromLOC
		                           AND QTYEXPECTED > 0
                           )
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Stop because Qty Expected > 0! LOC = ' + @c_currentLOC + ' SKU = ' + @c_currentSKU
                              END
                              BREAK -- Get out of loop, so that next cANDidate can be evaluated
                           END
                           /* Verify that the FROM LOCation is not the */
                           /* PIECE PICK LOCation for this product.    */
                           IF EXISTS(SELECT * FROM SKUxLOC (NOLOCK)
                           WHERE StorerKey = @c_CurrentStorer
                           AND SKU = @c_currentSKU
                           AND LOC = @c_fromLOC
                           AND LOCATIONTYPE = "PICK" )
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
                                 SELECT 'Stop because LOCation Type = PICK! LOC = ' + @c_currentLOC + ' SKU = ' + @c_currentSKU
                              END
                              BREAK -- Get out of loop, so that next cANDidate can be evaluated
                           END
                           /* Verify that the FROM LOCation is not the */
                           /* CASE PICK LOCation for this product.     */
                           IF EXISTS(SELECT * FROM SKUxLOC (NOLOCK)
                           WHERE StorerKey = @c_CurrentStorer
                           AND SKU = @c_currentSKU
                           AND LOC = @c_fromLOC
                           AND LOCATIONTYPE = "CASE"
                           )
                           BEGIN
                              IF @b_debug = 1
                              BEGIN
									     SELECT 'Stop because LOCation Type = CASE! LOC = ' + @c_currentLOC + ' SKU = ' + @c_currentSKU
                              END
                              BREAK -- Get out of loop, so that next cANDidate can be evaluated
                           END

                           /* At this point, get the available qty from */
                           /* the SKUxLOC record.                       */
                           /* If it's less than what was taken from the */
                           /* lotxLOCxid record, then use it.           */
                           SELECT @n_SKULOCavailableqty = QTY - QTYALLOCATED - QTYPICKED
                           FROM SKUxLOC (NOLOCK)
                           WHERE StorerKey = @c_CurrentStorer
                           AND SKU = @c_currentSKU
                           AND LOC = @c_fromLOC
                           IF @n_SKULOCavailableqty < @n_OnHandQty
                           BEGIN
                              SELECT @n_OnHandQty = @n_SKULOCavailableqty
                           END

-- select @n_OnHandQty '@n_OnHandQty', @n_SKULOCavailableqty '@n_SKULOCavailableqty'

                           /* How many cases can I get from this record? */
                           SELECT @n_possiblecases = floor(@n_OnHandQty / @n_currentfullcase)
                           SELECT @c_Packkey = PACK.PackKey,
											 @c_UOM = PACK.PackUOM3,
											 @n_pallet = PACK.pallet
                           FROM   SKU (NOLOCK), PACK (NOLOCK)
                           WHERE  SKU.PackKey = PACK.Packkey
                           AND    SKU.StorerKey = @c_CurrentStorer
                           AND    SKU.SKU = @c_currentSKU

									if @b_debug = 1
									begin
									select @c_fromlot 'fromlot', @c_fromloc 'fromloc', @n_onhandqty 'onhand', @n_pallet 'pallet', @n_remainingqty 'remaining'
									end
/*
								-- how many do we take so as to avoid breakdown of full pallet from reserve
								if (@n_onhandqty <= @n_pallet) and (@n_onhandqty <= @n_remainingqty)
								begin
								   select @n_fromqty = @n_onhandqty
								   select @n_remainingqty = @n_remainingqty - @n_fromqty
								end
								else if (@n_onhandqty <= @n_pallet) and (@n_onhandqty > @n_remainingqty)
								begin
								   select @n_fromqty = @n_remainingqty
								   select @n_remainingqty = @n_remainingqty - @n_fromqty
								end
								else if (@n_onhandqty > @n_pallet) and (@n_remainingqty = @n_pallet)
								begin
								   select @n_fromqty = @n_pallet
								   select @n_remainingqty = @n_remainingqty - @n_fromqty
								end
								else
								begin
									select @n_fromqty = 0
									select @n_remainingqty = 0
								end
*/
								if (@n_onhandqty <= @n_remainingqty)
								begin
								   select @n_fromqty = @n_onhandqty
								   select @n_remainingqty = @n_remainingqty - @n_fromqty
								end
								else if (@n_onhandqty > @n_remainingqty)
								begin
								   select @n_fromqty = @n_onhandqty
								   select @n_remainingqty = 0
								end

								if @b_debug = 1
								begin
								select @c_fromlot 'fromlot', @n_fromqty 'fromqty', @n_remainingqty 'remaining'
								end

                        IF @n_fromqty > 0
                        BEGIN
                           IF @n_continue = 1 or @n_continue = 2
                           BEGIN
                              INSERT #REPLENISHMENT (
                              StorerKey,
                              SKU,
                              FromLOC,
                              ToLOC,
                              Lot,
                              Id,
                              Qty,
                              UOM,
                              PackKey,
                              Priority,
                              QtyMoved,
                              QtyInPickLOC)
                              VALUES (
                              @c_CurrentStorer,
                              @c_currentSKU,
                              @c_fromLOC,
                              @c_currentLOC,
                              @c_fromlot,
                              @c_fromid,
                              @n_fromqty,
                              @c_UOM,
                              @c_Packkey,
                              @c_CurrentPriority,
                              0,0)
                           END
                           SELECT @n_numberofrecs = @n_numberofrecs + 1
                        END -- if from qty > 0
                        IF @b_debug = 1
                        BEGIN
                           -- select @c_currentSKU ' SKU', @c_currentLOC 'LOC', @n_fromqty 'FromQty', @c_CurrentPriority 'priority', @n_currentfullcase 'full case', @n_CurrentSeverity 'severity'
                           -- select @n_fromqty 'qty', @c_fromLOC 'fromLOC', @c_fromlot 'from lot', @n_possiblecases 'possible cases'
                           select @n_remainingqty '@n_remainingqty', @c_currentLOC + ' SKU = ' + @c_currentSKU, @c_fromlot 'from lot', @c_fromid
                        END
                        IF @c_fromid = '' OR @c_fromid IS NULL OR dbo.fnc_RTrim(dbo.fnc_LTrim(@c_FromId)) = ''
                        BEGIN
                           -- SELECT @n_remainingqty=0
                           BREAK
                        END
                     END -- SCAN LOT for ID
                     SET ROWCOUNT 0
                  END -- SCAN LOT for LOC
                  SET ROWCOUNT 0
               END -- SCAN LOT FOR LOT
					DROP TABLE #LOT -- SOS21873              
               SET ROWCOUNT 0
            END -- FOR SKU
            SET ROWCOUNT 0
         END -- FOR STORER
         SET ROWCOUNT 0
      END -- FOR SEVERITY
      SET ROWCOUNT 0
   END  -- (WHILE 1=1 on SKUxLOC FOR PRIORITY )
   SET ROWCOUNT 0
END
IF @n_continue=1 OR @n_continue=2
BEGIN
   /* Update the column QtyInPickLOC in the Replenishment Table */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      UPDATE #REPLENISHMENT 
		SET   QtyInPickLOC = SKUxLOC.Qty - SKUxLOC.QtyPicked
      FROM  SKUxLOC (NOLOCK)
      WHERE #REPLENISHMENT.StorerKey = SKUxLOC.StorerKey AND
		      #REPLENISHMENT.SKU = SKUxLOC.SKU AND
		      #REPLENISHMENT.toLOC = SKUxLOC.LOC
   END
END
/* Insert Into Replenishment Table Now */
IF @n_continue=1 OR @n_continue=2
BEGIN
   DECLARE @b_success int,
            @n_err     int,
            @c_errmsg  NVARCHAR(255)
   
   DECLARE CUR1 CURSOR FAST_FORWARD READ_ONLY FOR 
   SELECT  R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey, R.Priority, R.UOM
   FROM #REPLENISHMENT R

   OPEN CUR1
   FETCH NEXT FROM CUR1 INTO @c_FromLoc, @c_FromID, @c_CurrentLoc, @c_CurrentSKU, @n_FromQty, 
                             @c_CurrentStorer, @c_FromLot, @c_PackKey, @c_Priority, @c_UOM
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXECUTE nspg_GetKey
      "REPLENISHKEY",
      10,
      @c_ReplenishmentKey  OUTPUT,
      @b_success           OUTPUT,
      @n_err               OUTPUT,
      @c_errmsg            OUTPUT
      IF NOT @b_success = 1
      BEGIN
         BREAK
      END
      IF @b_success = 1
      BEGIN
         INSERT REPLENISHMENT (replenishmentgroup,
         ReplenishmentKey,
         StorerKey,
         Sku,
         FromLoc,
         ToLoc,
         Lot,
         Id,
         Qty,
         UOM,
         PackKey,
         Confirmed)
         VALUES ('IDS',
         @c_ReplenishmentKey,
         @c_CurrentStorer,
         @c_CurrentSku,
         @c_Fromloc,
         @c_CurrentLoc,
         @c_FromLot,
         @c_FromId,
         @n_FromQty,
         @c_UOM,
         @c_PackKey,
         "N")
         SELECT @n_err = @@ERROR
   
      END -- IF @b_success = 1
      FETCH NEXT FROM CUR1 INTO @c_FromLoc, @c_FromID, @c_CurrentLoc, @c_CurrentSKU, @n_FromQty, @c_CurrentStorer, @c_FromLot, @c_PackKey, @c_Priority, @c_UOM
   END -- While
   DEALLOCATE CUR1
END 
-- End Insert Replenishment

IF ( @c_zone02 = 'ALL')
BEGIN
   SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,
   SKU.Descr, R.Priority, L1.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey, (LT.Qty - LT.QtyAllocated - LT.QtyPicked), 
   CASE WHEN LA.Lottable03 IS NULL OR LA.Lottable03 = '' THEN LA.Lottable02 ELSE LA.Lottable03 END,
   LA.Lottable04
   FROM  REPLENISHMENT R, SKU (NOLOCK), LOC L1 (NOLOCK), PACK (NOLOCK),  LOC L2 (nolock), LOTxLOCxID LT (nolock) , LOTATTRIBUTE LA (NOLOCK)-- Pack table added by Jacob Date Jan 03, 2001
   WHERE SKU.Sku = R.Sku
   AND  SKU.StorerKey = R.StorerKey
   AND  L1.Loc = R.ToLoc
   AND  L2.Loc = R.FromLoc
   AND  LT.Lot = R.Lot
   AND  LT.Loc = R.FromLoc
   AND  LT.ID = R.ID
   AND  LT.LOT = LA.LOT
   AND  LT.SKU = LA.SKU
   AND  LT.STORERKEY = LA.STORERKEY
   AND  SKU.PackKey = PACK.PackKey
   AND  R.confirmed = 'N'
   AND  L1.Facility = @c_zone01
   ORDER BY L1.PutawayZone, R.Priority
END
ELSE
   BEGIN
   SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,
   SKU.Descr, R.Priority, L1.PutawayZone, PACK.CASECNT, PACK.PACKUOM1, PACK.PACKUOM3, R.ReplenishmentKey, (LT.Qty - LT.QtyAllocated - LT.QtyPicked), 
   CASE WHEN LA.Lottable03 IS NULL OR LA.Lottable03 = '' THEN LA.Lottable02 ELSE LA.Lottable03 END,
   LA.Lottable04
   FROM  REPLENISHMENT R, SKU (NOLOCK), LOC L1 (NOLOCK), LOC L2 (nolock) , PACK (NOLOCK) , LOTxLOCxID LT(nolock), LOTATTRIBUTE LA (NOLOCK) -- Pack table added by Jacob Date Jan 03, 2001
   WHERE SKU.Sku = R.Sku
   AND   SKU.StorerKey = R.StorerKey
   AND   L1.Loc = R.ToLoc
   AND   L2.Loc = R.FromLoc
   AND   LT.Lot = R.Lot
   AND   LT.Loc = R.FromLoc
   AND   LT.ID = R.ID
   AND   LT.LOT = LA.LOT
   AND   LT.SKU = LA.SKU
   AND   LT.STORERKEY = LA.STORERKEY
   AND   SKU.PackKey = PACK.PackKey
   AND   R.confirmed = 'N'
   AND   L1.Facility = @c_zone01
   AND   L1.putawayzone in (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
   ORDER BY L1.PutawayZone, R.Priority
   END
END

GO